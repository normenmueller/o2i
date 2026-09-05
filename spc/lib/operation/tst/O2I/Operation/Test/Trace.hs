{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Trace
  ( tests
  , fixtureModelInput
  , withFixtureEnvironment
  , notationRejectedDraft
  , profileRejectedDraft
  , structureRejectedDraft
  , semanticsRejectedDraft
  , traceContractDraft
  , readinessContractDraft
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Foldable (toList)
import Data.IORef
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Resolution (compiledProfileDescriptor)
import O2I.Operation.Acquisition (InputSource, fileInput)
import O2I.Operation.Acquisition.Internal (acquireWith)
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import qualified O2I.Operation.Human.Diagnostic as HumanDiagnostic
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import O2I.Operation.Profile
import O2I.Operation.Provenance
  ( SourceRole(..)
  , mkSourceReference
  , sourceIdentityRole
  )
import O2I.Operation.Schema (schemaVariantText)
import O2I.Operation.Test.AdapterSupport (compileCompleteAdapter)
import qualified O2I.Operation.Test.HumanFailureCorrespondence as FailureCorrespondence
import qualified O2I.Operation.Test.ReportEnvelope as ReportEnvelope
import O2I.Operation.Trace (runTrace)
import qualified O2I.Operation.Trace.Human as Human
import O2I.Operation.Trace.Machine
import O2I.Operation.Trace.Request
import O2I.Operation.Trace.Result
import O2I.Operation.Trace.Runtime.Internal (runTraceWith)
import O2I.Operation.View (viewByName)
import qualified O2I.Trace as CoreTrace
import OperationReportPublicObserver
  ( ObservedReportContract
  , ObservedReportOperation(..)
  )
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "Trace operation"
    [ testCase "keeps the exact supplement-free request" exactRequest
    , testCase "acquires exactly the sole model source" soleAcquisition
    , testCase "rejects every prerequisite at its exact stage" prerequisites
    , testCase "rejects a prepared model with no asserted root" noRootRejected
    , testCase "rejects one partial root" partialRejected
    , testCase "rejects mixed complete and partial roots" mixedRejected
    , testCase "accepts only all-complete roots" completeAccepted
    , testCase
        "continues through Semantics unavailability"
        semanticsUnavailableContinues
    , testCase
        "keeps Semantics rejection as a prerequisite result"
        semanticsRejectedPrerequisite
    , testCase
        "keeps pre-preparation failure outside the machine envelope"
        failedMachineDocument
    , testCase
        "keeps impossible owner failures outside the machine envelope"
        internalFailureDocument
    , testCase
        "projects every real terminal branch with its complete context"
        humanBranches
    ]

exactRequest :: Assertion
exactRequest = do
  model <- fixtureModelInput
  adapter <- requireRight (mkAdapterId "amx")
  let request = traceRequest model (viewByName "Binding") (Just adapter)
  traceAdapterId request @?= Just adapter
  foldTraceRequest (\_ _ selected -> selected @?= Just adapter) request

soleAcquisition :: Assertion
soleAcquisition = do
  reference <- requireRight (mkSourceReference "memory-model")
  model <- requireRight (fileInput reference "memory-model")
  observed <- newIORef []
  result <-
    withFixtureEnvironment emptyTraceDraft $ \adapters profiles ->
      runTraceWith
        (acquireWith
           (\path -> modifyIORef' observed (<> [path]) >> pure ByteString.empty)
           (ioError (userError "unexpected Trace stdin read")))
        adapters
        profiles
        (traceRequest model (viewByName "Binding") Nothing)
  readIORef observed >>= (@?= ["memory-model"])
  foldTraceResult
    (const (assertFailure "sole acquisition failed"))
    (\_ _ -> pure ())
    (\_ _ -> pure ())
    (\_ _ -> pure ())
    result

prerequisites :: Assertion
prerequisites =
  mapM_
    (\(stage, draft, coreExpected) ->
       assertPrerequisite stage draft coreExpected)
    [ (notationTracePrerequisite, notationRejectedDraft, False)
    , (profileTracePrerequisite, profileRejectedDraft, False)
    , (structureTracePrerequisite, structureRejectedDraft, True)
    , (semanticsTracePrerequisite, semanticsRejectedDraft, True)
    ]

assertPrerequisite ::
     TracePrerequisite -> Draft.ProfileDraft -> Bool -> Assertion
assertPrerequisite expected draft coreExpected = do
  result <- runFixture draft
  foldTraceResult
    (const (assertFailure "prerequisite fixture failed"))
    (\stage _ -> stage @?= expected)
    (\_ _ -> assertFailure "prerequisite fixture reached rejected Trace")
    (\_ _ -> assertFailure "prerequisite fixture reached accepted Trace")
    result
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireDocument tool result
  schemaVariantText (traceResultDocumentVariant document)
    @?= "trace-prerequisite-rejected"
  let encoded = encodeTraceResultDocument document
  assertTraceSchema encoded
  assertCoreProvenance coreExpected encoded

noRootRejected :: Assertion
noRootRejected = do
  result <- runFixture emptyTraceDraft
  foldTraceResult
    (const (assertFailure "no-root fixture failed"))
    (\_ _ -> assertFailure "no-root fixture rejected a prerequisite")
    (\_ _ -> pure ())
    (\_ _ -> assertFailure "no-root fixture was accepted")
    result
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireDocument tool result
  schemaVariantText (traceResultDocumentVariant document) @?= "trace-rejected"
  let first = encodeTraceResultDocument document
      second = encodeTraceResultDocument document
  first @?= second
  assertTraceSchema first
  assertCoreProvenance True first
  assertRequestShape first

partialRejected :: Assertion
partialRejected = do
  result <-
    runFixture (traceContractDraft (Just "vision-orients-strategy") False)
  foldTraceResult
    (const (assertFailure "partial fixture failed"))
    (\_ _ -> assertFailure "partial fixture rejected a prerequisite")
    (\assessment _ ->
       map CoreTrace.rootTraceDisposition (CoreTrace.traceRootTraces assessment)
         @?= [CoreTrace.RootTracePartial])
    (\_ _ -> assertFailure "partial fixture was accepted")
    result
  assertCompletedDocument "trace-rejected" result

mixedRejected :: Assertion
mixedRejected = do
  result <- runFixture (traceContractDraft Nothing True)
  foldTraceResult
    (const (assertFailure "mixed fixture failed"))
    (\_ _ -> assertFailure "mixed fixture rejected a prerequisite")
    (\assessment _ ->
       sort
         (map
            CoreTrace.rootTraceDisposition
            (CoreTrace.traceRootTraces assessment))
         @?= [CoreTrace.RootTraceComplete, CoreTrace.RootTracePartial])
    (\_ _ -> assertFailure "mixed fixture was accepted")
    result
  assertCompletedDocument "trace-rejected" result

completeAccepted :: Assertion
completeAccepted = do
  result <- runFixture (traceContractDraft Nothing False)
  foldTraceResult
    (const (assertFailure "complete fixture failed"))
    (\_ _ -> assertFailure "complete fixture rejected a prerequisite")
    (\_ _ -> assertFailure "complete fixture was rejected")
    (\assessment _ ->
       map CoreTrace.rootTraceDisposition (CoreTrace.traceRootTraces assessment)
         @?= [CoreTrace.RootTraceComplete])
    result
  assertCompletedDocument "trace-accepted" result

assertCompletedDocument :: Text -> TraceResult -> Assertion
assertCompletedDocument expected result = do
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireDocument tool result
  schemaVariantText (traceResultDocumentVariant document) @?= expected
  let encoded = encodeTraceResultDocument document
  assertTraceSchema encoded
  assertCoreProvenance True encoded

semanticsUnavailableContinues :: Assertion
semanticsUnavailableContinues = do
  result <- runFixture (traceDraftFrom [("strategy", "Grouping", "Strategy")])
  foldTraceResult
    (const (assertFailure "unavailable fixture failed"))
    (\_ _ -> assertFailure "Semantics unavailability stopped Trace")
    (\_ _ -> pure ())
    (\_ _ -> pure ())
    result

semanticsRejectedPrerequisite :: Assertion
semanticsRejectedPrerequisite = do
  result <- runFixture (traceDraftFrom [("need", "Grouping", "Need")])
  foldTraceResult
    (const (assertFailure "semantic rejection fixture failed"))
    (\stage _ -> stage @?= semanticsTracePrerequisite)
    (\_ _ -> assertFailure "semantic rejection reached Core Trace")
    (\_ _ -> assertFailure "semantic rejection was accepted")
    result

failedMachineDocument :: Assertion
failedMachineDocument = do
  model <-
    do
      reference <- requireRight (mkSourceReference "missing-model")
      requireRight
        (fileInput reference ("tst" </> "fixtures" </> "trace-missing.amx"))
  result <-
    withFixtureEnvironment emptyTraceDraft $ \adapters profiles ->
      runTrace
        adapters
        profiles
        (traceRequest model (viewByName "Binding") Nothing)
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  assertTraceFailureCorrespondence tool result
  case traceResultDocument tool result of
    Left _ -> pure ()
    Right _ -> assertFailure "command failure acquired a Trace envelope"

internalFailureDocument :: Assertion
internalFailureDocument = do
  model <- fixtureModelInput
  result <-
    withFixtureEnvironment emptyTraceDraft $ \adapters profiles ->
      runTraceWith
        (\_ ordinal input ->
           acquireWith
             (const (pure ByteString.empty))
             (pure ByteString.empty)
             AssessmentRole
             ordinal
             input)
        adapters
        profiles
        (traceRequest model (viewByName "Binding") Nothing)
  foldTraceResult
    (\failure ->
       foldTraceFailure
         (const (assertFailure "internal failure became common"))
         (foldTraceInternalFailure
            (\identity -> sourceIdentityRole identity @?= AssessmentRole)
            (const (assertFailure "unexpected adapter failure"))
            (const (assertFailure "unexpected notation failure"))
            (const (assertFailure "unexpected Profile failure"))
            (const (assertFailure "unexpected identity failure"))
            (const (assertFailure "unexpected scope failure"))
            (const (assertFailure "unexpected Structure failure"))
            (const (assertFailure "unexpected provenance failure"))
            (const (assertFailure "unexpected input failure"))
            (const (assertFailure "unexpected semantic failure")))
         failure)
    (\_ _ -> assertFailure "internal failure became prerequisite rejection")
    (\_ _ -> assertFailure "internal failure reached rejected Trace")
    (\_ _ -> assertFailure "internal failure reached accepted Trace")
    result
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  assertTraceFailureCorrespondence tool result
  case traceResultDocument tool result of
    Left _ -> pure ()
    Right _ -> assertFailure "owner failure acquired a Trace envelope"

assertTraceFailureCorrespondence :: ToolDescriptor -> TraceResult -> Assertion
assertTraceFailureCorrespondence tool result =
  Human.foldHumanTraceReport
    (\failureValue -> do
       raw <- observeRawTraceFailure result
       human <- observeHumanTraceFailure failureValue
       human @?= raw)
    (\_ _ -> unexpectedTraceFailure "Trace prerequisite in failed fixture")
    (\_ _ -> unexpectedTraceFailure "Trace rejection in failed fixture")
    (\_ _ -> unexpectedTraceFailure "Trace acceptance in failed fixture")
    (Human.traceHumanReport tool result)

observeRawTraceFailure :: TraceResult -> IO [[Text]]
observeRawTraceFailure =
  foldTraceResult
    (foldTraceFailure
       (pure . (: []) . FailureCorrespondence.observeRawCommonFailure)
       (foldTraceInternalFailure
          (pure . (: []) . FailureCorrespondence.observeRawSourceIdentity)
          (\_ -> unexpectedTraceFailure "unexpected Trace adapter failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace notation failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace Profile failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace identity failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace scope failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace Structure failure")
          (\_ -> unexpectedTraceFailure "unexpected Trace provenance failure")
          (pure
             . map FailureCorrespondence.observeRawSupplementalInputDefect
             . NonEmpty.toList)
          (\_ -> unexpectedTraceFailure "unexpected Trace semantic failure")))
    (\_ _ -> unexpectedTraceFailure "Trace prerequisite in failed fixture")
    (\_ _ -> unexpectedTraceFailure "Trace rejection in failed fixture")
    (\_ _ -> unexpectedTraceFailure "Trace acceptance in failed fixture")

observeHumanTraceFailure :: Human.HumanTraceFailure -> IO [[Text]]
observeHumanTraceFailure =
  Human.foldHumanTraceFailure
    (pure . (: []) . FailureCorrespondence.observeHumanCommonFailure)
    (pure . (: []) . FailureCorrespondence.observeHumanSourceIdentity)
    (\_ -> unexpectedTraceFailure "unexpected Human Trace adapter failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace notation failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace Profile failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace identity failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace scope failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace Structure failure")
    (\_ -> unexpectedTraceFailure "unexpected Human Trace provenance failure")
    (pure
       . map FailureCorrespondence.observeHumanSupplementalInputDefect
       . NonEmpty.toList)
    (\_ -> unexpectedTraceFailure "unexpected Human Trace semantic failure")

unexpectedTraceFailure :: String -> IO value
unexpectedTraceFailure message = assertFailure message >> fail "unreachable"

humanBranches :: Assertion
humanBranches = do
  model <-
    do
      reference <- requireRight (mkSourceReference "missing-model")
      requireRight
        (fileInput reference ("tst" </> "fixtures" </> "trace-missing.amx"))
  failed <-
    withFixtureEnvironment emptyTraceDraft $ \adapters profiles ->
      runTrace
        adapters
        profiles
        (traceRequest model (viewByName "Binding") Nothing)
  prerequisite <- runFixture notationRejectedDraft
  rejected <- runFixture emptyTraceDraft
  accepted <- runFixture (traceContractDraft Nothing False)
  tool <- ReportEnvelope.hostileTool
  assertHuman tool "failed" ReportEnvelope.contractsWithoutCore failed
  assertHuman
    tool
    "prerequisite"
    ReportEnvelope.contractsWithoutCore
    prerequisite
  assertHuman tool "rejected" ReportEnvelope.contractsWithCore rejected
  assertHuman tool "accepted" ReportEnvelope.contractsWithCore accepted
  where
    assertHuman ::
         ToolDescriptor
      -> Text
      -> NonEmpty ObservedReportContract
      -> TraceResult
      -> Assertion
    assertHuman tool expected contracts result =
      Human.foldHumanTraceReport
        (\failureValue -> do
           expected @?= "failed"
           raw <- observeRawTraceFailure result
           human <- observeHumanTraceFailure failureValue
           human @?= raw)
        (\_ context -> do
           expected @?= "prerequisite"
           assertContext tool result contracts context)
        (\_ context -> do
           expected @?= "rejected"
           assertContext tool result contracts context)
        (\assessment context -> do
           expected @?= "accepted"
           Human.foldHumanTraceAssessment
             (\_ roots -> length roots @?= 1)
             assessment
           assertContext tool result contracts context)
        (Human.traceHumanReport tool result)
    assertContext ::
         ToolDescriptor
      -> TraceResult
      -> NonEmpty ObservedReportContract
      -> Human.HumanTraceContext
      -> Assertion
    assertContext tool result contracts context = do
      document <- requireDocument tool result
      Human.foldHumanTraceContext
        (\envelope request modelSource view diagnostics -> do
           ReportEnvelope.assertPreparedEnvelope
             traceResultSchema
             (traceResultDocumentVariant document)
             ObservedTraceReportOperation
             contracts
             envelope
           Human.foldHumanTraceRequest
             (\modelInput selector adapter -> do
                HumanValue.foldHumanInputSource
                  (\reference path -> do
                     reference @?= "model"
                     path @?= "tst" </> "fixtures" </> "owner-model.amx")
                  (const (assertFailure "Trace model became standard input"))
                  modelInput
                HumanValue.foldHumanViewSelector
                  (@?= "Binding")
                  (const (assertFailure "Trace request changed selector kind"))
                  selector
                HumanValue.foldHumanAdapterSelection
                  (pure ())
                  (const
                     (assertFailure "Trace request changed adapter selection"))
                  adapter)
             request
           let tuple =
                 HumanValue.foldHumanSourceIdentity $ \role ordinal reference digest ->
                   ( HumanValue.foldHumanSourceRole
                       "model"
                       "supplemental"
                       "readiness"
                       "assessment"
                       role
                   , ordinal
                   , reference
                   , digest)
               retained = tuple modelSource
           retained
             @?= tuple
                   (HumanDiagnostic.humanDiagnosticDocumentModelSource
                      diagnostics)
           case retained of
             (role, ordinal, reference, digest) -> do
               role @?= ("model" :: Text)
               ordinal @?= 0
               reference @?= "model"
               assertBool "Trace source digest is empty" (digest /= "")
           HumanValue.foldHumanViewDescriptor
             (\_ identity _ _ ->
                HumanValue.foldHumanIdentityOutcome
                  (pure ())
                  (const (pure ()))
                  (\_ _ -> pure ())
                  (\_ _ -> pure ())
                  identity)
             view)
        context

fixtureModelInput :: IO InputSource
fixtureModelInput = do
  reference <- requireRight (mkSourceReference "model")
  requireRight
    (fileInput reference ("tst" </> "fixtures" </> "owner-model.amx"))

runFixture :: Draft.ProfileDraft -> IO TraceResult
runFixture draft = do
  model <- fixtureModelInput
  withFixtureEnvironment draft $ \adapters profiles ->
    runTrace
      adapters
      profiles
      (traceRequest model (viewByName "Binding") Nothing)

withFixtureEnvironment ::
     Draft.ProfileDraft
  -> (AdapterCollection -> ProfileInventory -> IO result)
  -> IO result
withFixtureEnvironment draft consume = do
  adapter <- traceAdapter draft
  adapters <- requireRight (compileAdapterCollection (adapter :| []))
  profiles <-
    foldProfileInventoryCompilation
      (const (assertFailure "Profile inventory rejected" >> fail "unreachable"))
      pure
      (compileProfileInventory [compiledProfileDescriptor])
  consume adapters profiles

traceAdapter :: Draft.ProfileDraft -> IO Adapter
traceAdapter draft = do
  identifier <- requireRight (mkAdapterId "amx")
  descriptor <-
    requireRight
      (mkAdapterDescriptor
         identifier
         "Trace test adapter"
         "1.0.0"
         "archimate-3.2")
  compileCompleteAdapter descriptor [] $ \_ ->
    Right
      (adapterBehavior (const recognitionMatch) (const (decodedDraft draft)))

emptyTraceDraft :: Draft.ProfileDraft
emptyTraceDraft = traceDraftFrom []

notationRejectedDraft :: Draft.ProfileDraft
notationRejectedDraft =
  traceDraft
    [("strategy", "Driver", "Strategy"), ("need", "Grouping", "Need")]
    []
    [Draft.childRecordMember (typedElement "model" "Grouping" "Strategy")]

profileRejectedDraft :: Draft.ProfileDraft
profileRejectedDraft =
  traceDraftFrom
    [("strategy", "Driver", "Strategy"), ("need", "Grouping", "Need")]

structureRejectedDraft :: Draft.ProfileDraft
structureRejectedDraft =
  traceDraftFrom
    [ ("strategy", "Grouping", "Strategy")
    , ("driver", "Driver", "Driver")
    , ("need", "Grouping", "Need")
    ]

semanticsRejectedDraft :: Draft.ProfileDraft
semanticsRejectedDraft = traceDraftFrom [("need", "Grouping", "Need")]

traceDraftFrom :: [(Text, Text, Text)] -> Draft.ProfileDraft
traceDraftFrom elements = traceDraft elements [] []

traceDraft ::
     [(Text, Text, Text)]
  -> [(Text, Text, Bool, Text, Text, Text)]
  -> [Draft.DraftMember Draft.ModelRootRole]
  -> Draft.ProfileDraft
traceDraft elements relationships extras =
  Draft.profileDraft
    (Draft.modelRootDraft
       (draftIdentity "model")
       (draftLocation "model")
       (draftProperty "model-profile" "o2i.profile" "o2i.archimate-profile@0.3"
          : map (Draft.childRecordMember . uncurry3 typedElement) elements
              <> map
                   (Draft.childRecordMember . uncurry6 typedRelationship)
                   relationships
              <> extras
              <> [ Draft.childRecordMember
                     (Draft.viewDraft
                        (draftIdentity "binding-view")
                        (draftLocation "binding-view")
                        (Draft.nameFieldMember
                           [ Draft.draftTextScalar
                               "Binding"
                               (draftLocation "view-name")
                           ]
                           (draftLocation "view-name-field")
                           : map
                               (Draft.childRecordMember . viewNode . first3)
                               elements
                               <> map
                                    (Draft.childRecordMember . viewConnection)
                                    relationships))
                 ]))

traceContractDraft :: Maybe Text -> Bool -> Draft.ProfileDraft
traceContractDraft missing includeSecondRoot =
  traceDraft elements relationships []
  where
    elements =
      traceElements
        <> if includeSecondRoot
             then [ ("interventionTwo", "Grouping", "Intervention")
                  , ("needTwo", "Grouping", "Need")
                  , ("needDriverTwo", "Driver", "Driver")
                  , ("needObjectiveTwo", "Goal", "Objective")
                  ]
             else []
    relationships =
      filter
        (\(identifier, _, _, _, _, _) -> Just identifier /= missing)
        traceRelationships
        <> traceOwnerships
        <> if includeSecondRoot
             then [ association
                      "intervention-two-addresses-need-two"
                      "addresses"
                      "interventionTwo"
                      "needTwo"
                  , ownership
                      "need-driver-at-need-two"
                      "needTwo"
                      "needDriverTwo"
                  , ownership
                      "need-objective-at-need-two"
                      "needTwo"
                      "needObjectiveTwo"
                  , association
                      "need-driver-two-grounds-need-objective-two"
                      "grounds"
                      "needDriverTwo"
                      "needObjectiveTwo"
                  , association
                      "situation-surfaces-need-two"
                      "surfaces"
                      "situation"
                      "needTwo"
                  , association
                      "situation-anchor-anchors-need-driver-two"
                      "anchors"
                      "situationAnchor"
                      "needDriverTwo"
                  , influence
                      "strategy-key-result-translates-into-need-objective-two"
                      "translates-into"
                      "strategyKeyResult"
                      "needObjectiveTwo"
                  , realization
                      "intervention-key-result-substantiates-need-objective-two"
                      "substantiates"
                      "interventionKeyResult"
                      "needObjectiveTwo"
                  ]
             else []

readinessContractDraft :: Maybe Text -> Draft.ProfileDraft
readinessContractDraft missing =
  traceDraft
    (traceElements <> [("strategyPrinciple", "Principle", "Principle")])
    (filter
       (\(identifier, _, _, _, _, _) -> Just identifier /= missing)
       (traceRelationships
          <> [ association
                 "strategy-principle-guides-strategy-action"
                 "guides"
                 "strategyPrinciple"
                 "strategyAction"
             ])
       <> traceOwnerships
       <> [ ownership
              "strategy-principle-at-strategy"
              "strategy"
              "strategyPrinciple"
          ])
    []

traceElements :: [(Text, Text, Text)]
traceElements =
  [ ("vision", "Grouping", "Vision")
  , ("strategy", "Grouping", "Strategy")
  , ("need", "Grouping", "Need")
  , ("intervention", "Grouping", "Intervention")
  , ("measure", "Grouping", "Measure")
  , ("situation", "Grouping", "Situation")
  , ("visionObjective", "Goal", "Objective")
  , ("strategyDriver", "Driver", "Driver")
  , ("strategyObjective", "Goal", "Objective")
  , ("strategyAction", "CourseOfAction", "Action")
  , ("strategyKeyResult", "Outcome", "KeyResult")
  , ("needDriver", "Driver", "Driver")
  , ("needObjective", "Goal", "Objective")
  , ("interventionAction", "CourseOfAction", "Action")
  , ("interventionKeyResult", "Outcome", "KeyResult")
  , ("measurePerformanceDimension", "Grouping", "PerformanceDimension")
  , ("measureKpi", "Assessment", "KPI")
  , ("situationAnchor", "Capability", "BusinessCapability")
  ]

traceRelationships :: [(Text, Text, Bool, Text, Text, Text)]
traceRelationships =
  [ association "intervention-addresses-need" "addresses" "intervention" "need"
  , association "strategy-qualifies-need" "qualifies" "strategy" "need"
  , association
      "strategy-directs-intervention"
      "directs"
      "strategy"
      "intervention"
  , association "vision-orients-strategy" "orients" "vision" "strategy"
  , association "strategy-frames-measure" "frames" "strategy" "measure"
  , association
      "intervention-sets-target-for-measure"
      "sets-target-for"
      "intervention"
      "measure"
  , association
      "intervention-changes-situation"
      "changes"
      "intervention"
      "situation"
  , association "measure-measures-situation" "measures" "measure" "situation"
  , association "situation-surfaces-need" "surfaces" "situation" "need"
  , association
      "need-driver-grounds-need-objective"
      "grounds"
      "needDriver"
      "needObjective"
  , influence
      "strategy-key-result-translates-into-need-objective"
      "translates-into"
      "strategyKeyResult"
      "needObjective"
  , association
      "strategy-driver-grounds-strategy-objective"
      "grounds"
      "strategyDriver"
      "strategyObjective"
  , association
      "vision-objective-orients-strategy-objective"
      "orients"
      "visionObjective"
      "strategyObjective"
  , realization
      "strategy-key-result-substantiates-strategy-objective"
      "substantiates"
      "strategyKeyResult"
      "strategyObjective"
  , association
      "strategy-action-contributes-to-strategy-key-result"
      "contributes-to"
      "strategyAction"
      "strategyKeyResult"
  , association
      "strategy-action-guides-intervention-action"
      "guides"
      "strategyAction"
      "interventionAction"
  , association
      "intervention-action-contributes-to-intervention-key-result"
      "contributes-to"
      "interventionAction"
      "interventionKeyResult"
  , association
      "intervention-key-result-contributes-to-strategy-key-result"
      "contributes-to"
      "interventionKeyResult"
      "strategyKeyResult"
  , realization
      "intervention-key-result-substantiates-need-objective"
      "substantiates"
      "interventionKeyResult"
      "needObjective"
  , influence
      "strategy-driver-indicates-measure-performance-dimension"
      "indicates"
      "strategyDriver"
      "measurePerformanceDimension"
  , influence
      "strategy-key-result-determines-measure-performance-dimension"
      "determines"
      "strategyKeyResult"
      "measurePerformanceDimension"
  , aggregation
      "measure-performance-dimension-contains-measure-kpi"
      "contains"
      "measurePerformanceDimension"
      "measureKpi"
  , association
      "intervention-key-result-sets-target-for-measure-kpi"
      "sets-target-for"
      "interventionKeyResult"
      "measureKpi"
  , association
      "measure-kpi-measures-situation-anchor"
      "measures"
      "measureKpi"
      "situationAnchor"
  , association
      "intervention-action-changes-same-situation-anchor"
      "changes"
      "interventionAction"
      "situationAnchor"
  , association
      "situation-anchor-anchors-need-driver"
      "anchors"
      "situationAnchor"
      "needDriver"
  , aggregation
      "situation-is-constituted-by-same-situation-anchor"
      "is-constituted-by"
      "situation"
      "situationAnchor"
  ]

traceOwnerships :: [(Text, Text, Bool, Text, Text, Text)]
traceOwnerships =
  [ ownership "vision-objective-at-vision" "vision" "visionObjective"
  , ownership "strategy-driver-at-strategy" "strategy" "strategyDriver"
  , ownership "strategy-objective-at-strategy" "strategy" "strategyObjective"
  , ownership "strategy-action-at-strategy" "strategy" "strategyAction"
  , ownership "strategy-key-result-at-strategy" "strategy" "strategyKeyResult"
  , ownership "need-driver-at-need" "need" "needDriver"
  , ownership "need-objective-at-need" "need" "needObjective"
  , ownership
      "intervention-action-at-intervention"
      "intervention"
      "interventionAction"
  , ownership
      "intervention-key-result-at-intervention"
      "intervention"
      "interventionKeyResult"
  , ownership
      "measure-performance-dimension-at-measure"
      "measure"
      "measurePerformanceDimension"
  , ownership "measure-kpi-at-measure" "measure" "measureKpi"
  ]

association ::
     Text -> Text -> Text -> Text -> (Text, Text, Bool, Text, Text, Text)
association identifier label source target =
  (identifier, "AssociationRelationship", True, label, source, target)

influence ::
     Text -> Text -> Text -> Text -> (Text, Text, Bool, Text, Text, Text)
influence identifier label source target =
  (identifier, "InfluenceRelationship", False, label, source, target)

realization ::
     Text -> Text -> Text -> Text -> (Text, Text, Bool, Text, Text, Text)
realization identifier label source target =
  (identifier, "RealizationRelationship", False, label, source, target)

aggregation ::
     Text -> Text -> Text -> Text -> (Text, Text, Bool, Text, Text, Text)
aggregation identifier label source target =
  (identifier, "AggregationRelationship", False, label, source, target)

ownership :: Text -> Text -> Text -> (Text, Text, Bool, Text, Text, Text)
ownership identifier source target =
  ( identifier
  , "CompositionRelationship"
  , False
  , "contextualizes"
  , source
  , target)

typedElement :: Text -> Text -> Text -> Draft.ElementDraft
typedElement identifier archiMateType o2iType =
  Draft.elementDraft
    (draftIdentity identifier)
    (draftLocation identifier)
    [ Draft.typeFieldMember
        [ Draft.draftTextScalar
            archiMateType
            (draftLocation (identifier <> "-type"))
        ]
        (draftLocation (identifier <> "-type-field"))
    , draftProperty (identifier <> "-o2i-type") "o2i.type" o2iType
    , draftProperty (identifier <> "-commitment") "o2i.commitment" "asserted"
    ]

typedRelationship ::
     Text -> Text -> Bool -> Text -> Text -> Text -> Draft.RelationshipDraft
typedRelationship identifier archiMateType directed label source target =
  Draft.relationshipDraft
    (draftIdentity identifier)
    (draftLocation identifier)
    [ Draft.typeFieldMember
        [ Draft.draftTextScalar
            archiMateType
            (draftLocation (identifier <> "-type"))
        ]
        (draftLocation (identifier <> "-type-field"))
    , Draft.directedFieldMember
        [ Draft.draftBooleanScalar
            directed
            (draftLocation (identifier <> "-directed"))
        ]
        (draftLocation (identifier <> "-directed-field"))
    , Draft.nameFieldMember
        [Draft.draftTextScalar label (draftLocation (identifier <> "-name"))]
        (draftLocation (identifier <> "-name-field"))
    , Draft.referenceMember
        (Draft.relationshipSourceReference
           (draftIdentity source)
           (draftLocation (identifier <> "-source")))
    , Draft.referenceMember
        (Draft.relationshipTargetReference
           (draftIdentity target)
           (draftLocation (identifier <> "-target")))
    , draftProperty (identifier <> "-commitment") "o2i.commitment" "asserted"
    ]

viewNode :: Text -> Draft.ViewNodeDraft
viewNode target =
  Draft.viewNodeDraft
    (draftIdentity (target <> "-node"))
    (draftLocation (target <> "-node"))
    [ Draft.referenceMember
        (Draft.viewNodeElementReference
           (draftIdentity target)
           (draftLocation (target <> "-node-target")))
    ]

viewConnection ::
     (Text, Text, Bool, Text, Text, Text) -> Draft.ViewConnectionDraft
viewConnection (identifier, _, _, _, source, target) =
  Draft.viewConnectionDraft
    (draftIdentity (identifier <> "-connection"))
    (draftLocation (identifier <> "-connection"))
    [ Draft.referenceMember
        (Draft.viewConnectionRelationshipReference
           (draftIdentity identifier)
           (draftLocation (identifier <> "-connection-relationship")))
    , Draft.referenceMember
        (Draft.viewConnectionSourceReference
           (draftIdentity (source <> "-node"))
           (draftLocation (identifier <> "-connection-source")))
    , Draft.referenceMember
        (Draft.viewConnectionTargetReference
           (draftIdentity (target <> "-node"))
           (draftLocation (identifier <> "-connection-target")))
    ]

draftProperty :: Text -> Text -> Text -> Draft.DraftMember scope
draftProperty identifier key value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey
          [Draft.draftTextScalar key (draftLocation (identifier <> "-key"))])
       [Draft.draftTextScalar value (draftLocation (identifier <> "-value"))]
       (draftLocation identifier)
       [])

draftIdentity :: Text -> Draft.DraftIdentity scope
draftIdentity value =
  Draft.draftIdentity
    [Draft.draftTextScalar value (draftLocation (value <> "-identity"))]

draftLocation :: Text -> Draft.DraftLocation
draftLocation value =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing value) 1)
       [])
    Nothing

first3 :: (first, second, third) -> first
first3 (value, _, _) = value

uncurry3 ::
     (first -> second -> third -> result) -> (first, second, third) -> result
uncurry3 function (first, second, third) = function first second third

uncurry6 ::
     (first -> second -> third -> fourth -> fifth -> sixth -> result)
  -> (first, second, third, fourth, fifth, sixth)
  -> result
uncurry6 function (first, second, third, fourth, fifth, sixth) =
  function first second third fourth fifth sixth

requireDocument :: ToolDescriptor -> TraceResult -> IO TraceResultDocument
requireDocument tool result =
  case traceResultDocument tool result of
    Left _ ->
      assertFailure "prepared Trace became a failure" >> fail "unreachable"
    Right document -> pure document

assertCoreProvenance :: Bool -> ByteString.ByteString -> Assertion
assertCoreProvenance expected encoded = do
  document <- decodeObject encoded
  provenance <- objectMember "provenance" document >>= requireObject
  contracts <- objectMember "contracts" provenance >>= requireArray
  kinds <-
    traverse
      (\value -> requireObject value >>= objectMember "kind" >>= requireText)
      contracts
  kinds @?= ["operation", "adapter", "profile"]
    <> if expected
         then ["core"]
         else []

assertRequestShape :: ByteString.ByteString -> Assertion
assertRequestShape encoded = do
  document <- decodeObject encoded
  sort (map AesonKey.toText (AesonKeyMap.keys document))
    @?= [ "context"
        , "diagnostics"
        , "execution"
        , "kind"
        , "operation"
        , "provenance"
        , "request"
        , "schema"
        , "tool"
        , "trace"
        ]
  request <- objectMember "request" document >>= requireObject
  sort (map AesonKey.toText (AesonKeyMap.keys request))
    @?= ["adapterId", "view"]
  objectMember "adapterId" request >>= (@?= Aeson.Null)
  view <- objectMember "view" request >>= requireObject
  objectMember "kind" view >>= requireText >>= (@?= "name")
  objectMember "value" view >>= requireText >>= (@?= "Binding")

decodeObject :: ByteString.ByteString -> IO Aeson.Object
decodeObject encoded =
  case Aeson.eitherDecodeStrict encoded of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> requireObject value

objectMember :: Text -> Aeson.Object -> IO Aeson.Value
objectMember name object =
  case AesonKeyMap.lookup (AesonKey.fromText name) object of
    Nothing ->
      assertFailure "Trace machine member is missing" >> fail "unreachable"
    Just value -> pure value

requireObject :: Aeson.Value -> IO Aeson.Object
requireObject value =
  case value of
    Aeson.Object object -> pure object
    _ ->
      assertFailure "Trace machine member is not an object"
        >> fail "unreachable"

requireArray :: Aeson.Value -> IO [Aeson.Value]
requireArray value =
  case value of
    Aeson.Array values -> pure (toList values)
    _ ->
      assertFailure "Trace machine member is not an array" >> fail "unreachable"

requireText :: Aeson.Value -> IO Text
requireText value =
  case value of
    Aeson.String text -> pure text
    _ -> assertFailure "Trace machine member is not text" >> fail "unreachable"

assertTraceSchema :: ByteString.ByteString -> Assertion
assertTraceSchema encoded = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.trace-v1.schema.json")
  schema <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  document <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  validateJSONSchema schema document
    @? "Trace machine document violates its generated Schema"

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
