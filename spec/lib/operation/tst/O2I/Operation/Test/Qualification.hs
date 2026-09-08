{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Operation.Test.Qualification
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.IORef
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Resolution (compiledProfileDescriptor)
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentity
  , modelIdentityText
  )
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquisitionFailure
  , InputSource
  , fileInput
  )
import O2I.Operation.Acquisition.Internal (acquireWith)
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Command.Error (commandErrorCode, qualifyCommandError)
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Diagnostic
  ( foldPreparedDiagnosticDocument
  , preparedDiagnosticStage
  )
import qualified O2I.Operation.Human.Diagnostic as HumanDiagnostic
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import O2I.Operation.Profile
import O2I.Operation.Provenance (SourceOrdinal, SourceRole, mkSourceReference)
import qualified O2I.Operation.Qualification.Subjects.Human as SubjectsHuman
import O2I.Operation.Qualification.Subjects.Machine
import O2I.Operation.Qualification.Subjects.Request
import O2I.Operation.Qualification.Subjects.Result
import O2I.Operation.Qualification.Subjects.Runtime.Internal
  ( runQualificationSubjectsWith
  )
import qualified O2I.Operation.Qualify.Human as QualifyHuman
import O2I.Operation.Qualify.Machine
import O2I.Operation.Qualify.Request
import O2I.Operation.Qualify.Result
import O2I.Operation.Qualify.Runtime.Internal (runQualifyWith)
import O2I.Operation.Schema (schemaVariantText)
import O2I.Operation.Test.AdapterSupport (compileCompleteAdapter)
import qualified O2I.Operation.Test.HumanFailureCorrespondence as FailureCorrespondence
import qualified O2I.Operation.Test.ReportEnvelope as ReportEnvelope
import O2I.Operation.View (viewByName)
import qualified O2I.Qualification as Qualification
import OperationReportPublicObserver (ObservedReportOperation(..))
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "Qualification operations"
    [ testCase
        "discovers exact names and Core eligibility without name selectors"
        discoveryProjection
    , testCase
        "keeps display names outside exact selector resolution"
        displayNameIsNotSelector
    , testCase
        "expands absent Need selectors before Core assessment"
        absentNeedExpansion
    , testCase
        "acquires every supplemental source exactly once"
        supplementalAcquisitionWork
    , testCase
        "acquires Qualify inputs exactly once and fails fast"
        qualifyAcquisition
    , testCase
        "lifts malformed supplemental input through the real Left branch"
        malformedQualifySupplemental
    , testCase
        "rejects every Qualify prerequisite at its exact stage"
        qualifyPrerequisites
    , testCase
        "continues Semantics rejection and unavailability into Core"
        semanticsContinuation
    , testCase
        "accumulates selector failures canonically"
        selectorFailureAccumulation
    , testCase
        "emits every requested pair and no unrequested pair"
        requestedPairs
    , testCase
        "encodes actual Qualify variants and exact provenance"
        qualifyMachineContracts
    , testCase
        "projects both reports through every real terminal branch"
        humanReports
    ]

discoveryProjection :: Assertion
discoveryProjection = do
  result <- runSubjects []
  inventory <- discoveredInventory result
  let needs = qualificationInventoryNeedSubjects inventory
      strategies = qualificationInventoryStrategySubjects inventory
      names =
        Map.fromList
          [ ( modelIdentityText (discoveredQualificationSubjectIdentity subject)
            , discoveredQualificationSubjectDisplayName subject)
          | subject <- needs <> strategies
          ]
  names
    @?= Map.fromList
          [ ("need-absent", Nothing)
          , ("need-multiple", Nothing)
          , ("need-non-text", Nothing)
          , ("need-present", Just "Need display")
          , ("strategy", Just "Strategy display")
          ]
  map
    (qualificationSubjectCategoryText . discoveredQualificationSubjectCategory)
    needs
    @?= replicate 4 "need"
  map
    (qualificationSubjectCategoryText . discoveredQualificationSubjectCategory)
    strategies
    @?= ["strategy"]
  map
    (qualificationSubjectEligibilityText
       . discoveredQualificationSubjectEligibility)
    (needs <> strategies)
    @?= replicate 4 "ineligible"
    <> ["eligibility-unavailable"]
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireSubjectsDocument tool result
  assertSchema
    ("contract"
       </> "schema"
       </> "o2i.discovery.qualification-subjects-v1.schema.json")
    (encodeQualificationSubjectsDocument document)

displayNameIsNotSelector :: Assertion
displayNameIsNotSelector = do
  model <- modelSource
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         (identity "Strategy display" :| [])
         []
         [])
  result <-
    withEnvironment $ \adapters profiles ->
      runQualifyWith memoryAcquire adapters profiles request
  (disposition, unavailable) <-
    completedValue
      (\assessment ->
         ( Qualification.qualificationAssessmentDisposition assessment
         , map
             unavailableProjection
             (Qualification.qualificationSubjectUnavailable assessment)))
      result
  disposition @?= Qualification.QualificationSubjectsUnavailable
  case unavailable of
    [(category, reason, occurrences)] -> do
      category @?= Qualification.QualificationStrategyCategory
      reason @?= Qualification.QualificationSelectorUnknown
      occurrences @?= []
    _ -> assertFailure "expected one unknown Strategy selector"
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireQualifyDocument tool result
  assertSchema
    ("contract" </> "schema" </> "o2i.operation.qualify-v1.schema.json")
    (encodeQualifyResultDocument document)

absentNeedExpansion :: Assertion
absentNeedExpansion = do
  model <- modelSource
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         (identity "strategy" :| [])
         []
         [])
  result <-
    withEnvironment $ \adapters profiles ->
      runQualifyWith memoryAcquire adapters profiles request
  (selectedNeeds, unavailable) <-
    completedValue
      (\assessment ->
         ( map
             modelIdentityText
             (Qualification.qualificationSelectedNeeds assessment)
         , map
             (\subject ->
                ( Qualification.qualificationUnavailableCategory subject
                , modelIdentityText
                    (Qualification.qualificationUnavailableIdentity subject)))
             (Qualification.qualificationSubjectUnavailable assessment)))
      result
  selectedNeeds
    @?= ["need-absent", "need-multiple", "need-non-text", "need-present"]
  unavailable @?= [(Qualification.QualificationStrategyCategory, "strategy")]

supplementalAcquisitionWork :: Assertion
supplementalAcquisitionWork = do
  model <- modelSource
  supplements <- traverse supplementalSource [0 .. 255 :: Int]
  observed <- newIORef []
  let acquire =
        acquireWith
          (\path -> modifyIORef' observed (<> [path]) >> pure ByteString.empty)
          (ioError (userError "unexpected stdin read"))
      request =
        qualificationSubjectsRequest
          model
          (viewByName "Binding")
          Nothing
          supplements
  _ <-
    withEnvironment $ \adapters profiles ->
      runQualificationSubjectsWith acquire adapters profiles request
  paths <- readIORef observed
  length paths @?= 257
  paths @?= "model.amx"
    : ["supplement-" <> show value | value <- [0 .. 255 :: Int]]

qualifyAcquisition :: Assertion
qualifyAcquisition = do
  model <- modelSource
  supplements <- traverse supplementalSource [0 .. 2 :: Int]
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         (identity "strategy" :| [])
         []
         supplements)
  supplementalBytes <-
    ByteString.readFile
      ("tst" </> "fixtures" </> "owner-source-strategy-valid.json")
  mapM_
    (\(failedPath, expectedPaths) -> do
       observed <- newIORef []
       let acquire =
             acquireWith
               (\path -> do
                  modifyIORef' observed (<> [path])
                  if Just path == failedPath
                    then ioError (userError "intended acquisition failure")
                    else pure
                           (if path == "model.amx"
                              then ByteString.empty
                              else supplementalBytes))
               (ioError (userError "unexpected stdin read"))
       result <-
         withEnvironment $ \adapters profiles ->
           runQualifyWith acquire adapters profiles request
       readIORef observed >>= (@?= expectedPaths)
       case failedPath of
         Nothing -> pure ()
         Just _ ->
           foldQualifyResult
             (const (pure ()))
             (\_ _ -> assertFailure "failed acquisition reached prerequisite")
             (\_ _ -> assertFailure "failed acquisition reached assessment")
             result)
    [ (Nothing, ["model.amx", "supplement-0", "supplement-1", "supplement-2"])
    , (Just "supplement-1", ["model.amx", "supplement-0", "supplement-1"])
    ]

malformedQualifySupplemental :: Assertion
malformedQualifySupplemental = do
  model <- modelSource
  supplement <- supplementalSource 0
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         (identity "strategy" :| [])
         []
         [supplement])
  result <-
    withEnvironment $ \adapters profiles ->
      runQualifyWith memoryAcquire adapters profiles request
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  case qualifyResultDocument tool result of
    Left failure -> do
      foldQualifyFailure
        (const (assertFailure "malformed supplement became common failure"))
        (const (pure ()))
        (const (assertFailure "malformed supplement became owner failure"))
        failure
      let commandError = qualifyCommandError failure
          document = commandErrorDocument tool commandError
          encoded = encodeCommandErrorDocument document
      commandErrorCode commandError @?= "qualify.supplemental-input"
      schemaVariantText (commandErrorDocumentVariant document)
        @?= "qualify-failed"
      encoded
        @?= "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"qualify-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"qualify.supplemental-input\",\"failure\":{\"category\":\"supplemental-input\",\"diagnostics\":[{\"ruleId\":\"core.supplemental.decode.json-syntax\",\"inputOrdinals\":[0],\"reason\":\"invalid-json-syntax\",\"fields\":[]}]}}"
      schema <- requireJson (LazyByteString.fromStrict commandErrorSchemaBytes)
      value <-
        case Aeson.eitherDecodeStrict encoded of
          Left message -> assertFailure message >> fail "unreachable"
          Right decoded -> pure decoded
      validateJSONSchema schema value
        @? "Qualify command error violates its generated Schema"
    Right _ -> assertFailure "malformed supplement acquired a result document"

qualifyPrerequisites :: Assertion
qualifyPrerequisites =
  mapM_
    (\(expected, draft) -> do
       result <- runQualifyDraft draft (identity "strategy" :| []) [] []
       foldQualifyResult
         (const (assertFailure "prerequisite fixture failed"))
         (\stage _ -> stage @?= expected)
         (\_ _ -> assertFailure "prerequisite fixture reached Core")
         result
       assertQualifyDocument "qualify-prerequisite-rejected" result)
    [ (notationQualifyPrerequisite, notationRejectedDraft)
    , (profileQualifyPrerequisite, profileRejectedDraft)
    , (structureQualifyPrerequisite, structureRejectedDraft)
    ]

semanticsContinuation :: Assertion
semanticsContinuation =
  mapM_
    (\(draft, selector, expectedSemanticsDiagnostic) -> do
       result <- runQualifyDraft draft (identity selector :| []) [] []
       stages <-
         foldQualifyResult
           (const (assertFailure "Semantics fixture failed" >> pure []))
           (\_ _ ->
              assertFailure "Semantics became a public prerequisite" >> pure [])
           (\_ prepared -> pure (preparedDiagnosticStages prepared))
           result
       ("semantics" `elem` stages) @?= expectedSemanticsDiagnostic
       assertQualifyDocument "qualify-completed" result)
    [ (semanticsRejectedDraft, "missing-strategy", True)
    , (semanticsUnavailableDraft, "strategy", False)
    ]

selectorFailureAccumulation :: Assertion
selectorFailureAccumulation = do
  result <-
    runQualifyDraft
      qualificationDraft
      (identity "missing-z" :| [identity "missing-a"])
      [identity "missing-z", identity "missing-a"]
      []
  unavailable <-
    completedValue
      (map selectorFailure . Qualification.qualificationSubjectUnavailable)
      result
  unavailable
    @?= [ ("need", "missing-a", Qualification.QualificationSelectorUnknown)
        , ("need", "missing-z", Qualification.QualificationSelectorUnknown)
        , ("strategy", "missing-a", Qualification.QualificationSelectorUnknown)
        , ("strategy", "missing-z", Qualification.QualificationSelectorUnknown)
        ]

requestedPairs :: Assertion
requestedPairs = do
  result <-
    runQualifyDraft
      requestedPairDraft
      (identity "strategy-b" :| [identity "strategy-a"])
      [identity "need-b", identity "need-a"]
      []
  (disposition, selectedStrategies, selectedNeeds, pairs, unrouted) <-
    completedValue
      (\assessment ->
         ( Qualification.qualificationAssessmentDisposition assessment
         , map
             modelIdentityText
             (Qualification.qualificationSelectedStrategies assessment)
         , map
             modelIdentityText
             (Qualification.qualificationSelectedNeeds assessment)
         , map
             pairProjection
             (Qualification.qualificationPairAssessments assessment)
         , length (Qualification.qualificationUnroutedProposals assessment)))
      result
  disposition @?= Qualification.QualificationPairOutcomesAvailable
  selectedStrategies @?= ["strategy-a", "strategy-b"]
  selectedNeeds @?= ["need-a", "need-b"]
  pairs
    @?= [ ( "need-a"
          , "strategy-a"
          , Qualification.QualificationPairInvalidSelectedSubjects)
        , ( "need-a"
          , "strategy-b"
          , Qualification.QualificationPairInvalidSelectedSubjects)
        , ( "need-b"
          , "strategy-a"
          , Qualification.QualificationPairInvalidSelectedSubjects)
        , ( "need-b"
          , "strategy-b"
          , Qualification.QualificationPairInvalidSelectedSubjects)
        ]
  unrouted @?= 0

qualifyMachineContracts :: Assertion
qualifyMachineContracts = do
  results <-
    sequence
      [ runQualifyDraft notationRejectedDraft (identity "strategy" :| []) [] []
      , runQualifyDraft profileRejectedDraft (identity "strategy" :| []) [] []
      , runQualifyDraft structureRejectedDraft (identity "strategy" :| []) [] []
      , runQualifyDraft
          semanticsUnavailableDraft
          (identity "strategy" :| [])
          []
          []
      ]
  mapM_
    (uncurry assertQualifyDocument)
    (zip
       [ "qualify-prerequisite-rejected"
       , "qualify-prerequisite-rejected"
       , "qualify-prerequisite-rejected"
       , "qualify-completed"
       ]
       results)
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  case results of
    firstResult:_ -> do
      prerequisite <- requireQualifyDocument tool firstResult
      assertImpossibleSemanticsPrerequisite
        (encodeQualifyResultDocument prerequisite)
    [] -> assertFailure "machine fixture table is empty"

humanReports :: Assertion
humanReports = do
  supplement <- supplementalSource 0
  subjectsFailed <- runSubjects [supplement]
  model <- modelSource
  subjectsPrerequisite <-
    withDraftEnvironment notationRejectedDraft $ \adapters profiles ->
      runQualificationSubjectsWith
        memoryAcquire
        adapters
        profiles
        (qualificationSubjectsRequest model (viewByName "Binding") Nothing [])
  subjectsDiscovered <- runSubjects []
  tool <- ReportEnvelope.hostileTool
  assertSubjects tool "failed" subjectsFailed
  assertSubjects tool "prerequisite" subjectsPrerequisite
  assertSubjects tool "discovered" subjectsDiscovered
  qualifyRequestValue <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         (identity "strategy" :| [])
         []
         [supplement])
  qualifyFailed <-
    withEnvironment $ \adapters profiles ->
      runQualifyWith memoryAcquire adapters profiles qualifyRequestValue
  qualifyPrerequisite <-
    runQualifyDraft notationRejectedDraft (identity "strategy" :| []) [] []
  qualifyCompleted <-
    runQualifyDraft semanticsUnavailableDraft (identity "strategy" :| []) [] []
  assertQualify tool "failed" qualifyFailed
  assertQualify tool "prerequisite" qualifyPrerequisite
  assertQualify tool "completed" qualifyCompleted
  where
    assertSubjects ::
         ToolDescriptor -> Text -> QualificationSubjectsResult -> Assertion
    assertSubjects tool expected result =
      SubjectsHuman.foldHumanQualificationSubjectsReport
        (\failureValue -> do
           expected @?= "failed"
           raw <- observeRawSubjectsFailure result
           human <- observeHumanSubjectsFailure failureValue
           human @?= raw)
        (\_ context -> do
           expected @?= "prerequisite"
           assertSubjectsContext tool result context)
        (\needs strategies context -> do
           expected @?= "discovered"
           length needs @?= 4
           length strategies @?= 1
           assertSubjectsContext tool result context)
        (SubjectsHuman.qualificationSubjectsHumanReport tool result)
    observeRawSubjectsFailure result =
      foldQualificationSubjectsResult
        (foldQualificationSubjectsFailure
           (pure . (: []) . FailureCorrespondence.observeRawCommonFailure)
           (pure
              . map FailureCorrespondence.observeRawSupplementalInputDefect
              . NonEmpty.toList)
           (\_ -> unexpected "Subjects owner failure in real input fixture"))
        (\_ _ -> unexpected "Subjects prerequisite in failed fixture")
        (\_ _ -> unexpected "Subjects discovery in failed fixture")
        result
    observeHumanSubjectsFailure failureValue =
      SubjectsHuman.foldHumanQualificationSubjectsFailure
        (pure . (: []) . FailureCorrespondence.observeHumanCommonFailure)
        (pure
           . map FailureCorrespondence.observeHumanSupplementalInputDefect
           . NonEmpty.toList)
        (\_ -> unexpected "Subjects model-role failure in real input fixture")
        (\_ ->
           unexpected "Subjects supplemental-role failure in real input fixture")
        (\_ -> unexpected "Subjects adapter failure in real input fixture")
        (\_ -> unexpected "Subjects notation failure in real input fixture")
        (\_ -> unexpected "Subjects Profile failure in real input fixture")
        (\_ -> unexpected "Subjects identity failure in real input fixture")
        (\_ -> unexpected "Subjects scope failure in real input fixture")
        (\_ -> unexpected "Subjects Structure failure in real input fixture")
        (\_ -> unexpected "Subjects provenance failure in real input fixture")
        (unexpected "Subjects context failure in real input fixture")
        (\_ _ -> unexpected "Subjects projection failure in real input fixture")
        (\_ _ -> unexpected "Subjects join failure in real input fixture")
        failureValue
    assertSubjectsContext ::
         ToolDescriptor
      -> QualificationSubjectsResult
      -> SubjectsHuman.HumanQualificationSubjectsContext
      -> Assertion
    assertSubjectsContext tool result context = do
      document <- requireSubjectsDocument tool result
      SubjectsHuman.foldHumanQualificationSubjectsContext
        (\envelope request model supplements _ diagnostics -> do
           ReportEnvelope.assertPreparedEnvelope
             qualificationSubjectsSchema
             (qualificationSubjectsDocumentVariant document)
             ObservedQualificationSubjectsReportOperation
             ReportEnvelope.contractsWithCore
             envelope
           SubjectsHuman.foldHumanQualificationSubjectsRequest
             (\modelInput selector adapter requestedSupplements -> do
                assertModelInput modelInput
                assertSelector selector
                assertAutomatic adapter
                assertBool
                  "supplement-free Subjects request gained inputs"
                  (null requestedSupplements))
             request
           assertBool
             "supplement-free Subjects context gained inputs"
             (null supplements)
           assertContextModel model diagnostics)
        context
    assertQualify :: ToolDescriptor -> Text -> QualifyResult -> Assertion
    assertQualify tool expected result =
      QualifyHuman.foldHumanQualifyReport
        (\failureValue -> do
           expected @?= "failed"
           raw <- observeRawQualifyFailure result
           human <- observeHumanQualifyFailure failureValue
           human @?= raw)
        (\_ context -> do
           expected @?= "prerequisite"
           assertQualifyContext tool result context)
        (\assessment context -> do
           expected @?= "completed"
           QualifyHuman.foldHumanQualificationAssessment
             (\_ _ _ _ _ _ _ -> pure ())
             assessment
           assertQualifyContext tool result context)
        (QualifyHuman.qualifyHumanReport tool result)
    observeRawQualifyFailure result =
      foldQualifyResult
        (foldQualifyFailure
           (pure . (: []) . FailureCorrespondence.observeRawCommonFailure)
           (pure
              . map FailureCorrespondence.observeRawSupplementalInputDefect
              . NonEmpty.toList)
           (\_ -> unexpected "Qualify owner failure in real input fixture"))
        (\_ _ -> unexpected "Qualify prerequisite in failed fixture")
        (\_ _ -> unexpected "Qualify completion in failed fixture")
        result
    observeHumanQualifyFailure failureValue =
      QualifyHuman.foldHumanQualifyFailure
        (pure . (: []) . FailureCorrespondence.observeHumanCommonFailure)
        (pure
           . map FailureCorrespondence.observeHumanSupplementalInputDefect
           . NonEmpty.toList)
        (\_ -> unexpected "Qualify model-role failure in real input fixture")
        (\_ ->
           unexpected "Qualify supplemental-role failure in real input fixture")
        (\_ -> unexpected "Qualify adapter failure in real input fixture")
        (\_ -> unexpected "Qualify notation failure in real input fixture")
        (\_ -> unexpected "Qualify Profile failure in real input fixture")
        (\_ -> unexpected "Qualify identity failure in real input fixture")
        (\_ -> unexpected "Qualify scope failure in real input fixture")
        (\_ -> unexpected "Qualify Structure failure in real input fixture")
        (\_ -> unexpected "Qualify provenance failure in real input fixture")
        (unexpected "Qualify context failure in real input fixture")
        failureValue
    unexpected message = assertFailure message >> fail "unreachable"
    assertQualifyContext ::
         ToolDescriptor
      -> QualifyResult
      -> QualifyHuman.HumanQualifyContext
      -> Assertion
    assertQualifyContext tool result context = do
      document <- requireQualifyDocument tool result
      QualifyHuman.foldHumanQualifyContext
        (\envelope request model supplements _ diagnostics -> do
           ReportEnvelope.assertPreparedEnvelope
             qualifyResultSchema
             (qualifyResultDocumentVariant document)
             ObservedQualifyReportOperation
             ReportEnvelope.contractsWithCore
             envelope
           QualifyHuman.foldHumanQualifyRequest
             (\modelInput selector adapter strategies needs requestedSupplements -> do
                assertModelInput modelInput
                assertSelector selector
                assertAutomatic adapter
                length strategies @?= 1
                assertBool "Qualify request gained Needs" (null needs)
                assertBool
                  "supplement-free Qualify request gained inputs"
                  (null requestedSupplements))
             request
           assertBool
             "supplement-free Qualify context gained inputs"
             (null supplements)
           assertContextModel model diagnostics)
        context
    assertModelInput :: HumanValue.HumanInputSource -> Assertion
    assertModelInput =
      HumanValue.foldHumanInputSource
        (\reference path -> do
           reference @?= "model"
           path @?= "model.amx")
        (const (assertFailure "Qualification model became standard input"))
    assertSelector :: HumanValue.HumanViewSelector -> Assertion
    assertSelector =
      HumanValue.foldHumanViewSelector
        (@?= "Binding")
        (const (assertFailure "Qualification selector changed kind"))
    assertAutomatic :: HumanValue.HumanAdapterSelection -> Assertion
    assertAutomatic =
      HumanValue.foldHumanAdapterSelection
        (pure ())
        (const (assertFailure "Qualification adapter became explicit"))
    assertContextModel ::
         HumanValue.HumanSourceIdentity
      -> HumanDiagnostic.HumanDiagnosticDocument
      -> Assertion
    assertContextModel model diagnostics = do
      let sourceTuple =
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
          retained = sourceTuple model
      retained
        @?= sourceTuple
              (HumanDiagnostic.humanDiagnosticDocumentModelSource diagnostics)
      case retained of
        (role, ordinal, reference, digest) -> do
          role @?= ("model" :: Text)
          ordinal @?= (0 :: Natural)
          reference @?= "model"
          assertBool "Qualification source digest is empty" (digest /= "")

runSubjects :: [InputSource] -> IO QualificationSubjectsResult
runSubjects supplements = do
  model <- modelSource
  withEnvironment $ \adapters profiles ->
    runQualificationSubjectsWith
      memoryAcquire
      adapters
      profiles
      (qualificationSubjectsRequest
         model
         (viewByName "Binding")
         Nothing
         supplements)

runQualifyDraft ::
     Draft.ProfileDraft
  -> NonEmpty ModelIdentity
  -> [ModelIdentity]
  -> [InputSource]
  -> IO QualifyResult
runQualifyDraft draft strategies needs supplements = do
  model <- modelSource
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Binding")
         Nothing
         strategies
         needs
         supplements)
  withDraftEnvironment draft $ \adapters profiles ->
    runQualifyWith memoryAcquire adapters profiles request

discoveredInventory ::
     QualificationSubjectsResult -> IO QualificationSubjectsInventory
discoveredInventory =
  foldQualificationSubjectsResult
    (const (assertFailure "discovery failed" >> fail "unreachable"))
    (\stage _ ->
       assertFailure
         ("discovery stopped at "
            <> show (qualificationSubjectsPrerequisiteText stage))
         >> fail "unreachable")
    (\inventory _ -> pure inventory)

completedValue ::
     (forall scope. Qualification.QualificationAssessment scope -> value)
  -> QualifyResult
  -> IO value
completedValue project result =
  foldQualifyResult
    (const (assertFailure "qualification failed" >> fail "unreachable"))
    (\stage _ ->
       assertFailure ("qualification stopped at " <> show stage)
         >> fail "unreachable")
    (\assessment _ -> pure (project assessment))
    result

preparedDiagnosticStages :: PreparedQualify -> [Text]
preparedDiagnosticStages prepared =
  foldPreparedQualify
    (\_ _ _ diagnostics ->
       foldPreparedDiagnosticDocument
         (\_ modelDiagnostics _ -> map preparedDiagnosticStage modelDiagnostics)
         diagnostics)
    prepared

selectorFailure ::
     Qualification.QualificationSubjectUnavailable scope
  -> (Text, Text, Qualification.QualificationSubjectUnavailableReason)
selectorFailure unavailable =
  ( case Qualification.qualificationUnavailableCategory unavailable of
      Qualification.QualificationNeedCategory -> "need"
      Qualification.QualificationStrategyCategory -> "strategy"
  , modelIdentityText
      (Qualification.qualificationUnavailableIdentity unavailable)
  , Qualification.qualificationUnavailableReason unavailable)

pairProjection ::
     Qualification.QualificationPairAssessment scope
  -> (Text, Text, Qualification.QualificationPairDisposition)
pairProjection pair =
  ( modelIdentityText (Qualification.qualificationPairNeed pair)
  , modelIdentityText (Qualification.qualificationPairStrategy pair)
  , Qualification.qualificationPairDisposition pair)

unavailableProjection ::
     Qualification.QualificationSubjectUnavailable scope
  -> ( Qualification.QualificationSubjectCategory
     , Qualification.QualificationSubjectUnavailableReason
     , [OccurrenceIdentity])
unavailableProjection unavailable =
  ( Qualification.qualificationUnavailableCategory unavailable
  , Qualification.qualificationUnavailableReason unavailable
  , Qualification.qualificationUnavailableOccurrences unavailable)

memoryAcquire ::
     SourceRole
  -> SourceOrdinal
  -> InputSource
  -> IO (Either AcquisitionFailure AcquiredSource)
memoryAcquire role ordinal input =
  acquireWith
    (const (pure ByteString.empty))
    (pure ByteString.empty)
    role
    ordinal
    input

modelSource :: IO InputSource
modelSource = do
  reference <- requireRight (mkSourceReference "model")
  requireRight (fileInput reference "model.amx")

supplementalSource :: Int -> IO InputSource
supplementalSource value = do
  let name = "supplement-" <> show value
  reference <- requireRight (mkSourceReference (fromString name))
  requireRight (fileInput reference name)

withEnvironment ::
     (AdapterCollection -> ProfileInventory -> IO result) -> IO result
withEnvironment = withDraftEnvironment qualificationDraft

withDraftEnvironment ::
     Draft.ProfileDraft
  -> (AdapterCollection -> ProfileInventory -> IO result)
  -> IO result
withDraftEnvironment draft consume = do
  adapter <- qualificationAdapter draft
  adapters <- requireRight (compileAdapterCollection (adapter :| []))
  profiles <-
    foldProfileInventoryCompilation
      (const (assertFailure "Profile inventory rejected" >> fail "unreachable"))
      pure
      (compileProfileInventory [compiledProfileDescriptor])
  consume adapters profiles

qualificationAdapter :: Draft.ProfileDraft -> IO Adapter
qualificationAdapter draft = do
  identifier <- requireRight (mkAdapterId "amx")
  descriptor <-
    requireRight
      (mkAdapterDescriptor
         identifier
         "Qualification test adapter"
         "1.0.0"
         "archimate-3.2")
  compileCompleteAdapter descriptor [] $ \_ ->
    Right
      (adapterBehavior (const recognitionMatch) (const (decodedDraft draft)))

qualificationDraft :: Draft.ProfileDraft
qualificationDraft = qualificationDraftFrom subjectDefinitions

qualificationDraftFrom :: [SubjectDefinition] -> Draft.ProfileDraft
qualificationDraftFrom definitions = qualificationDraftWithExtras definitions []

qualificationDraftWithExtras ::
     [SubjectDefinition]
  -> [Draft.DraftMember Draft.ModelRootRole]
  -> Draft.ProfileDraft
qualificationDraftWithExtras definitions extras =
  Draft.profileDraft
    (Draft.modelRootDraft
       (draftIdentity "model")
       (draftLocation "model")
       (draftProperty "model-profile" "o2i.profile" "o2i.archimate-profile@0.3"
          : map (Draft.childRecordMember . element) definitions
              <> extras
              <> [Draft.childRecordMember (bindingView definitions)]))

type SubjectDefinition
  = (Text, Text, Text, Text, [Draft.DraftMember Draft.ElementRole])

subjectDefinitions :: [SubjectDefinition]
subjectDefinitions =
  [ ( "strategy"
    , "Grouping"
    , "Strategy"
    , "asserted"
    , oneName "strategy" "Strategy display")
  , ("need-absent", "Grouping", "Need", "asserted", [])
  , ( "need-present"
    , "Grouping"
    , "Need"
    , "asserted"
    , oneName "need-present" "Need display")
  , ( "need-multiple"
    , "Grouping"
    , "Need"
    , "asserted"
    , oneName "need-multiple-a" "First" <> oneName "need-multiple-b" "Second")
  , ( "need-non-text"
    , "Grouping"
    , "Need"
    , "asserted"
    , [ Draft.nameFieldMember
          [Draft.draftBooleanScalar True (draftLocation "need-non-text-name")]
          (draftLocation "need-non-text-name-field")
      ])
  ]

notationRejectedDraft :: Draft.ProfileDraft
notationRejectedDraft =
  qualificationDraftWithExtras
    [ ("strategy", "Driver", "Strategy", "asserted", [])
    , ("need", "Grouping", "Need", "asserted", [])
    ]
    [ Draft.childRecordMember
        (element ("model", "Grouping", "Strategy", "asserted", []))
    ]

profileRejectedDraft :: Draft.ProfileDraft
profileRejectedDraft =
  qualificationDraftFrom
    [ ("strategy", "Driver", "Strategy", "asserted", [])
    , ("need", "Grouping", "Need", "asserted", [])
    ]

structureRejectedDraft :: Draft.ProfileDraft
structureRejectedDraft =
  qualificationDraftFrom
    [ ("strategy", "Grouping", "Strategy", "asserted", [])
    , ("driver", "Driver", "Driver", "asserted", [])
    , ("need", "Grouping", "Need", "asserted", [])
    ]

semanticsUnavailableDraft :: Draft.ProfileDraft
semanticsUnavailableDraft =
  qualificationDraftFrom [("strategy", "Grouping", "Strategy", "asserted", [])]

semanticsRejectedDraft :: Draft.ProfileDraft
semanticsRejectedDraft =
  qualificationDraftFrom [("need", "Grouping", "Need", "asserted", [])]

requestedPairDraft :: Draft.ProfileDraft
requestedPairDraft =
  qualificationDraftFrom
    [ ("strategy-a", "Grouping", "Strategy", "candidate", [])
    , ("strategy-b", "Grouping", "Strategy", "candidate", [])
    , ("strategy-c", "Grouping", "Strategy", "candidate", [])
    , ("need-a", "Grouping", "Need", "asserted", [])
    , ("need-b", "Grouping", "Need", "asserted", [])
    ]

element :: SubjectDefinition -> Draft.ElementDraft
element (identifier, nativeType, o2iType, commitment, names) =
  Draft.elementDraft
    (draftIdentity identifier)
    (draftLocation identifier)
    (Draft.typeFieldMember
       [ Draft.draftTextScalar
           nativeType
           (draftLocation (identifier <> "-type"))
       ]
       (draftLocation (identifier <> "-type-field"))
       : names
           <> [ draftProperty (identifier <> "-o2i-type") "o2i.type" o2iType
              , draftProperty
                  (identifier <> "-commitment")
                  "o2i.commitment"
                  commitment
              ])

oneName :: Text -> Text -> [Draft.DraftMember scope]
oneName identifier value =
  [ Draft.nameFieldMember
      [Draft.draftTextScalar value (draftLocation (identifier <> "-name"))]
      (draftLocation (identifier <> "-name-field"))
  ]

bindingView :: [SubjectDefinition] -> Draft.ViewDraft
bindingView definitions =
  Draft.viewDraft
    (draftIdentity "binding-view")
    (draftLocation "binding-view")
    (Draft.nameFieldMember
       [Draft.draftTextScalar "Binding" (draftLocation "view-name")]
       (draftLocation "view-name-field")
       : map (Draft.childRecordMember . viewNode . first5) definitions)

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

first5 :: (first, second, third, fourth, fifth) -> first
first5 (value, _, _, _, _) = value

identity :: Text -> ModelIdentity
identity value =
  case modelIdentity value of
    Left defect -> error ("invalid test identity: " <> show defect)
    Right result -> result

requireSubjectsDocument ::
     ToolDescriptor
  -> QualificationSubjectsResult
  -> IO QualificationSubjectsDocument
requireSubjectsDocument tool result =
  case qualificationSubjectsDocument tool result of
    Left _ ->
      assertFailure "prepared discovery became a failure" >> fail "unreachable"
    Right document -> pure document

requireQualifyDocument ::
     ToolDescriptor -> QualifyResult -> IO QualifyResultDocument
requireQualifyDocument tool result =
  case qualifyResultDocument tool result of
    Left _ ->
      assertFailure "prepared qualification became a failure"
        >> fail "unreachable"
    Right document -> pure document

assertQualifyDocument :: Text -> QualifyResult -> Assertion
assertQualifyDocument expected result = do
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  document <- requireQualifyDocument tool result
  schemaVariantText (qualifyResultDocumentVariant document) @?= expected
  let encoded = encodeQualifyResultDocument document
  assertSchema qualifySchemaPath encoded
  root <- decodeObject encoded
  provenance <- objectMember "provenance" root >>= requireObject
  contracts <- objectMember "contracts" provenance >>= requireArray
  kinds <-
    traverse
      (\contract ->
         requireObject contract >>= objectMember "kind" >>= requireText)
      contracts
  kinds @?= ["operation", "adapter", "profile", "core"]

assertImpossibleSemanticsPrerequisite :: ByteString.ByteString -> Assertion
assertImpossibleSemanticsPrerequisite encoded = do
  schemaBytes <- LazyByteString.readFile qualifySchemaPath
  schema <- requireJson schemaBytes
  root <- decodeObject encoded
  execution <- objectMember "execution" root >>= requireObject
  let invalidExecution =
        Aeson.Object
          (AesonKeyMap.insert
             (AesonKey.fromText "prerequisite")
             (Aeson.String "semantics")
             execution)
      invalidDocument =
        Aeson.Object
          (AesonKeyMap.insert
             (AesonKey.fromText "execution")
             invalidExecution
             root)
  not (validateJSONSchema schema invalidDocument)
    @? "Qualify Schema admitted impossible Semantics prerequisite"

qualifySchemaPath :: FilePath
qualifySchemaPath =
  "contract" </> "schema" </> "o2i.operation.qualify-v1.schema.json"

decodeObject :: ByteString.ByteString -> IO Aeson.Object
decodeObject encoded =
  case Aeson.eitherDecodeStrict encoded of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> requireObject value

objectMember :: Text -> Aeson.Object -> IO Aeson.Value
objectMember name object =
  case AesonKeyMap.lookup (AesonKey.fromText name) object of
    Nothing -> assertFailure "machine member is missing" >> fail "unreachable"
    Just value -> pure value

requireObject :: Aeson.Value -> IO Aeson.Object
requireObject value =
  case value of
    Aeson.Object object -> pure object
    _ -> assertFailure "machine member is not an object" >> fail "unreachable"

requireArray :: Aeson.Value -> IO [Aeson.Value]
requireArray value =
  case value of
    Aeson.Array values -> pure (foldr (:) [] values)
    _ -> assertFailure "machine member is not an array" >> fail "unreachable"

requireText :: Aeson.Value -> IO Text
requireText value =
  case value of
    Aeson.String result -> pure result
    _ -> assertFailure "machine member is not text" >> fail "unreachable"

assertSchema :: FilePath -> ByteString.ByteString -> Assertion
assertSchema path encoded = do
  schemaBytes <- LazyByteString.readFile path
  schema <- requireJson schemaBytes
  document <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  validateJSONSchema schema document @? "machine document violates Schema"

requireJson :: LazyByteString.ByteString -> IO Aeson.Value
requireJson bytes =
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure ->
      assertFailure ("unexpected Left: " <> show failure) >> fail "unreachable"
    Right value -> pure value

fromString :: String -> Text
fromString = Text.pack
