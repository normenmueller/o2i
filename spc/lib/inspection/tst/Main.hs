{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I
import O2I.Inspection
import System.FilePath ((</>))
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit

data TestDecodeDefect =
  TestDecodeDefect
  deriving (Eq, Show)

data TestViewDefect =
  TestViewDefect
  deriving (Eq, Show)

data TestProfileFact =
  TestProfileFact
  deriving (Eq, Show)

data TestProfileDefect
  = TestRootProfileDefect
  | TestReachedProfileDefect
  deriving (Eq, Show)

data AlternateFact =
  AlternateFact
  deriving (Eq, Show)

data AlternateDefect =
  AlternateDefect
  deriving (Eq, Show)

data DecodeMode
  = DecodeSucceeds
  | DecodeUnavailableMode
  | DecodeRejectedMode

data ViewMode
  = ViewSucceeds
  | ViewFails

data RootMode
  = RootSucceeds
  | RootFails

data FactTemplate
  = OccurrenceTemplate OccurrenceId
  | NodeTemplate OccurrenceId RawNode
  | EdgeTemplate OccurrenceId RawEdge
  | SeedTemplate OccurrenceId OccurrenceId
  | DependencyTemplate OccurrenceId OccurrenceId PersistedDependencyReason
  | ReferenceTemplate OccurrenceId [OccurrenceId] PersistedDependencyReason

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "o2i-inspection"
    [ testCase "exact source identity uses SHA-256" sourceIdentityTest
    , testCase "source locations are one-based" sourceLocationInvariantTest
    , testCase "decode result is total" decodeAttemptTest
    , testCase "View resolution failure is total" viewAttemptTest
    , testCase "root profile failure stops before closure" rootProfileTest
    , testCase "reached profile defects fail Profile" reachedDefectTest
    , testCase "unreached profile defects are excluded" unreachedDefectTest
    , testCase "closure retains repeated presentations" repeatedPresentationTest
    , testCase
        "closure includes core-derived macro premise relations"
        macroPremiseClosureTest
    , testCase
        "unresolved reached references fail Profile"
        unresolvedReferenceTest
    , testCase
        "Structure accumulates imported model defects"
        structureFailureTest
    , testCase "missing Strategy input is partial" strategyUnavailableTest
    , testCase
        "supplied empty Strategy input is validated"
        emptyStrategyInputTest
    , testCase
        "different existential profile types remain isolated"
        existentialAdapterTest
    , testCase "report JSON is stable and parseable" reportJsonTest
    , testCase "command-error JSON is parseable" commandJsonTest
    , testCase "checked-in schemas are valid JSON" schemaJsonTest
    , testCase "package license equals canonical license" licenseTest
    ]

sourceIdentityTest :: Assertion
sourceIdentityTest = do
  let identity = sourceDocumentIdentity testSource
  sourceDisplayLabel identity @?= "model.archimate"
  sourceInputKind identity @?= FileSource
  sourceHashText (sourceSha256 identity)
    @?= "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

sourceLocationInvariantTest :: Assertion
sourceLocationInvariantTest = do
  mkPathStep testRootQName 0 @?= Nothing
  mkSourceSpan 1 2 1 1 @?= Nothing
  assertBool
    "one-based path step expected"
    (mkPathStep testRootQName 1 /= Nothing)
  assertBool "ordered source span expected" (mkSourceSpan 1 1 1 1 /= Nothing)

decodeAttemptTest :: Assertion
decodeAttemptTest = do
  unavailable <-
    completedReport
      (runAdapter
         (testAdapter DecodeUnavailableMode ViewSucceeds RootSucceeds [] []))
  reportResult unavailable @?= InspectionFailed
  reportExitCode unavailable @?= 1
  map reportedState (stageReportsList (reportStageReports unavailable))
    @?= StageFailed
    : replicate 7 (StageNotRun (BlockedByFailure DecodeStage))
  rejected <-
    completedReport
      (runAdapter
         (testAdapter DecodeRejectedMode ViewSucceeds RootSucceeds [] []))
  case reportNativeBinding rejected of
    NativeBindingFailed (NativeBindingRejected _ _) -> pure ()
    binding -> assertFailure ("unexpected native binding: " <> show binding)

viewAttemptTest :: Assertion
viewAttemptTest = do
  report <-
    completedReport
      (runAdapter (testAdapter DecodeSucceeds ViewFails RootSucceeds [] []))
  case reportViewResolution report of
    ViewRejected _ -> pure ()
    resolution ->
      assertFailure ("unexpected View resolution: " <> show resolution)
  take 3 (map reportedState (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure ViewScopeStage)
        ]

rootProfileTest :: Assertion
rootProfileTest = do
  report <-
    completedReport
      (runAdapter (testAdapter DecodeSucceeds ViewSucceeds RootFails [] []))
  case reportProfileResolution report of
    ProfileRejectedResolution _ -> pure ()
    resolution ->
      assertFailure ("unexpected profile resolution: " <> show resolution)
  reportScopeResolution report @?= ScopeUnavailable

reachedDefectTest :: Assertion
reachedDefectTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            missionFacts
            [reachedDefect missionOccurrence]))
  case reportScopeResolution report of
    ScopeRejectedResolution _ -> pure ()
    resolution -> assertFailure ("unexpected scope state: " <> show resolution)
  diagnosticCodes report @?= ["o2i.test.profile.reached"]

unreachedDefectTest :: Assertion
unreachedDefectTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            missionFacts
            [reachedDefect (OccurrenceId "outside")]))
  assertBool
    "unreached adapter defect must not be reported"
    ("o2i.test.profile.reached" `notElem` diagnosticCodes report)
  reportScopeResolution report
    @?= ScopeResolved
          ClosedScopeSummary
            {directOccurrenceCount = 1, closedOccurrenceCount = 3}

repeatedPresentationTest :: Assertion
repeatedPresentationTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            repeatedMissionFacts
            []))
  reportScopeResolution report
    @?= ScopeResolved
          ClosedScopeSummary
            {directOccurrenceCount = 2, closedOccurrenceCount = 4}

macroPremiseClosureTest :: Assertion
macroPremiseClosureTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            macroPremiseFacts
            []))
  reportScopeResolution report
    @?= ScopeResolved
          ClosedScopeSummary
            {directOccurrenceCount = 1, closedOccurrenceCount = 7}

unresolvedReferenceTest :: Assertion
unresolvedReferenceTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            (missionFacts
               ++ [ ReferenceTemplate
                      missionOccurrence
                      []
                      PersistedContextOwnership
                  ])
            []))
  diagnosticCodes report @?= ["o2i.inspection.scope.reference-unresolved"]
  map reportedState (take 4 (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure ProfileStage)
        ]

structureFailureTest :: Assertion
structureFailureTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            duplicateNodeFacts
            []))
  diagnosticCodes report @?= ["o2i.structure.node-id-duplicate"]
  map reportedState (take 5 (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure StructureStage)
        ]

strategyUnavailableTest :: Assertion
strategyUnavailableTest = do
  report <-
    completedReport
      (runAdapterWithInputs
         (testAdapter DecodeSucceeds ViewSucceeds RootSucceeds strategyFacts [])
         noInputs)
  reportResult report @?= InspectionPartial
  reportExitCode report @?= 3
  map reportedState (take 6 (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StagePassed
        , StagePassed
        , StageUnavailable
        , StageNotRun (BlockedByUnavailable SemanticsStage)
        ]

emptyStrategyInputTest :: Assertion
emptyStrategyInputTest = do
  unavailable <-
    completedReport
      (runAdapterWithInputs
         (testAdapter DecodeSucceeds ViewSucceeds RootSucceeds strategyFacts [])
         noInputs)
  supplied <-
    completedReport
      (runAdapterWithInputs
         (testAdapter DecodeSucceeds ViewSucceeds RootSucceeds strategyFacts [])
         noInputs
           { strategyInput =
               Supplied
                 (Sourced
                    (sourceDocumentIdentity testSource)
                    (StrategyFormulationBundle []))
           })
  reportScopeResolution supplied @?= reportScopeResolution unavailable
  reportResult supplied @?= InspectionFailed
  diagnosticCodes supplied @?= ["o2i.semantics.formulation-missing"]

existentialAdapterTest :: Assertion
existentialAdapterTest = do
  first <- completedReport (runAdapter goodMissionAdapter)
  second <- completedReport (runAdapter alternateAdapter)
  reportScopeResolution first @?= reportScopeResolution second
  reportResult first @?= reportResult second

reportJsonTest :: Assertion
reportJsonTest = do
  report <- completedReport (runAdapter goodMissionAdapter)
  let first = renderInspectionReportJSON report
      second = renderInspectionReportJSON report
  first @?= second
  case Aeson.eitherDecode first :: Either String Aeson.Value of
    Left message -> assertFailure message
    Right _ -> pure ()

commandJsonTest :: Assertion
commandJsonTest = do
  let commandError = InputCommandError "missing.archimate" "not found"
  commandErrorExitCode commandError @?= 2
  case Aeson.eitherDecode (renderCommandErrorJSON commandError) :: Either
         String
         Aeson.Value of
    Left message -> assertFailure message
    Right _ -> pure ()

schemaJsonTest :: Assertion
schemaJsonTest =
  mapM_
    assertJsonFile
    ["o2i.inspection.report-v1.schema.json", "o2i.command-error-v1.schema.json"]
  where
    assertJsonFile name = do
      bytes <- LazyByteString.readFile ("schema" </> name)
      case Aeson.eitherDecode bytes :: Either String Aeson.Value of
        Left message -> assertFailure (name <> ": " <> message)
        Right _ -> pure ()

licenseTest :: Assertion
licenseTest = do
  canonical <- ByteString.readFile (".." </> ".." </> "LICENSE")
  local <- ByteString.readFile "LICENSE"
  local @?= canonical

testSource :: SourceDocument
testSource = sourceDocumentFromBytes "model.archimate" FileSource "abc"

goodMissionAdapter :: Adapter
goodMissionAdapter =
  testAdapter DecodeSucceeds ViewSucceeds RootSucceeds missionFacts []

alternateAdapter :: Adapter
alternateAdapter =
  Adapter
    testDescriptor
    (\_ -> DecodePassed testNativeBinding ())
    (\AlternateDefect -> testSpec DecodeStage "o2i.test.alt.decode")
    (\_ _ -> ViewPassed testResolvedView ())
    (\AlternateDefect -> testSpec ViewScopeStage "o2i.test.alt.view")
    O2IProfileContract
      { projectProfileFacts =
          \(ObservedProfileFacts facts) ->
            ProfileProjection
              { projectedRoot =
                  RootProjectable
                    (OneO2IProfile "0.2")
                    (resolveProfileVersion (O2IProfileVersion "0.2"))
              , projectedFacts =
                  concatMap
                    (const (instantiateFacts missionFacts))
                    (take 1 facts)
              , projectedDefects = []
              }
      , profileDefectSpec =
          \AlternateDefect -> testSpec ProfileStage "o2i.test.alt.profile"
      }
    (\_ _ -> ObservedProfileFacts [Located testLocation AlternateFact])

testAdapter ::
     DecodeMode
  -> ViewMode
  -> RootMode
  -> [FactTemplate]
  -> [DeferredProfileDefect TestProfileDefect]
  -> Adapter
testAdapter decodeMode viewMode rootMode templates deferred =
  Adapter
    testDescriptor
    decode
    testDecodeSpec
    resolveView
    testViewSpec
    contract
    observe
  where
    decode _ =
      case decodeMode of
        DecodeSucceeds -> DecodePassed testNativeBinding ()
        DecodeUnavailableMode ->
          DecodeUnavailable
            (DecodeUnavailableObservation EncodingNotObserved)
            (Located testLocation TestDecodeDefect :| [])
        DecodeRejectedMode ->
          DecodeRejected
            RejectedNativeBinding
              { rejectedEncoding = Utf8Binding
              , rejectedRootQName = Located testLocation testRootQName
              , rejectedNativeVersion = Just (Located testLocation "4.0.0")
              }
            (Located testLocation TestDecodeDefect :| [])
    resolveView _ _ =
      case viewMode of
        ViewSucceeds -> ViewPassed testResolvedView ()
        ViewFails ->
          ViewFailed NoViewMatch (Located testLocation TestViewDefect :| [])
    contract =
      O2IProfileContract
        {projectProfileFacts = project, profileDefectSpec = testProfileSpec}
    project _ =
      ProfileProjection
        { projectedRoot =
            case rootMode of
              RootSucceeds ->
                RootProjectable
                  (OneO2IProfile "0.2")
                  (resolveProfileVersion (O2IProfileVersion "0.2"))
              RootFails ->
                RootUnprojectable
                  NoO2IProfile
                  (Located testLocation TestRootProfileDefect :| [])
        , projectedFacts = instantiateFacts templates
        , projectedDefects = deferred
        }
    observe _ _ = ObservedProfileFacts [Located testLocation TestProfileFact]

instantiateFacts :: [FactTemplate] -> [IndexedProfileFact]
instantiateFacts = map instantiate
  where
    instantiate template =
      case template of
        OccurrenceTemplate occurrence -> indexOccurrence occurrence testLocation
        NodeTemplate occurrence node -> indexNode occurrence node testLocation
        EdgeTemplate occurrence edge -> indexEdge occurrence edge testLocation
        SeedTemplate presentation target ->
          indexPresentation presentation target
        DependencyTemplate source target reason ->
          indexDependency source target reason
        ReferenceTemplate source matches reason ->
          indexReference
            source
            ReferenceOccurrence
              { referenceOccurrenceId = OccurrenceId "reference"
              , referenceFromOccurrence = source
              , referenceRole = OwnershipTargetReference
              , referenceToken = Just "missing"
              , referenceLocation = testLocation
              }
            matches
            reason

reachedDefect :: OccurrenceId -> DeferredProfileDefect TestProfileDefect
reachedDefect occurrence =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = Located testLocation TestReachedProfileDefect
    }

missionFacts :: [FactTemplate]
missionFacts =
  [ OccurrenceTemplate missionPresentation
  , NodeTemplate
      missionOccurrence
      (RawContextNode (RawNodeId "mission") Mission)
  , SeedTemplate missionPresentation missionOccurrence
  , NodeTemplate
      driverOccurrence
      (RawPrimitiveNode (RawNodeId "driver") (RawNodeId "mission") Driver)
  , DependencyTemplate
      missionOccurrence
      driverOccurrence
      PersistedContextOwnership
  ]

repeatedMissionFacts :: [FactTemplate]
repeatedMissionFacts =
  missionFacts
    ++ [ OccurrenceTemplate secondPresentation
       , SeedTemplate secondPresentation missionOccurrence
       ]

strategyFacts :: [FactTemplate]
strategyFacts =
  [ OccurrenceTemplate strategyPresentation
  , NodeTemplate
      strategyOccurrence
      (RawContextNode (RawNodeId "strategy") Strategy)
  , SeedTemplate strategyPresentation strategyOccurrence
  ]

duplicateNodeFacts :: [FactTemplate]
duplicateNodeFacts =
  [ OccurrenceTemplate missionPresentation
  , OccurrenceTemplate secondPresentation
  , NodeTemplate
      missionOccurrence
      (RawContextNode (RawNodeId "duplicate") Mission)
  , NodeTemplate
      driverOccurrence
      (RawContextNode (RawNodeId "duplicate") Vision)
  , SeedTemplate missionPresentation missionOccurrence
  , SeedTemplate secondPresentation driverOccurrence
  ]

macroPremiseFacts :: [FactTemplate]
macroPremiseFacts =
  [ OccurrenceTemplate macroPresentation
  , NodeTemplate ethosOccurrence (RawContextNode (RawNodeId "ethos") Ethos)
  , NodeTemplate
      missionOccurrence
      (RawContextNode (RawNodeId "mission") Mission)
  , NodeTemplate
      principleOccurrence
      (RawPrimitiveNode (RawNodeId "principle") (RawNodeId "ethos") Principle)
  , NodeTemplate
      driverOccurrence
      (RawPrimitiveNode (RawNodeId "driver") (RawNodeId "mission") Driver)
  , EdgeTemplate
      macroEdgeOccurrence
      (RawEdge
         (RawNodeId "ethos")
         (relationNameFor guidesMission)
         (RawNodeId "mission"))
  , EdgeTemplate
      premiseEdgeOccurrence
      (RawEdge
         (RawNodeId "principle")
         (relationNameFor guidesEthosPrincipleToMissionDriver)
         (RawNodeId "driver"))
  , SeedTemplate macroPresentation macroEdgeOccurrence
  , DependencyTemplate
      macroEdgeOccurrence
      ethosOccurrence
      PersistedRelationshipEndpoint
  , DependencyTemplate
      macroEdgeOccurrence
      missionOccurrence
      PersistedRelationshipEndpoint
  , DependencyTemplate
      premiseEdgeOccurrence
      principleOccurrence
      PersistedRelationshipEndpoint
  , DependencyTemplate
      premiseEdgeOccurrence
      driverOccurrence
      PersistedRelationshipEndpoint
  ]

missionPresentation :: OccurrenceId
missionPresentation = OccurrenceId "presentation-mission"

secondPresentation :: OccurrenceId
secondPresentation = OccurrenceId "presentation-second"

strategyPresentation :: OccurrenceId
strategyPresentation = OccurrenceId "presentation-strategy"

macroPresentation :: OccurrenceId
macroPresentation = OccurrenceId "presentation-macro"

missionOccurrence :: OccurrenceId
missionOccurrence = OccurrenceId "node-mission"

driverOccurrence :: OccurrenceId
driverOccurrence = OccurrenceId "node-driver"

strategyOccurrence :: OccurrenceId
strategyOccurrence = OccurrenceId "node-strategy"

ethosOccurrence, principleOccurrence, macroEdgeOccurrence, premiseEdgeOccurrence ::
     OccurrenceId
ethosOccurrence = OccurrenceId "node-ethos"

principleOccurrence = OccurrenceId "node-principle"

macroEdgeOccurrence = OccurrenceId "edge-macro"

premiseEdgeOccurrence = OccurrenceId "edge-premise"

testDescriptor :: AdapterDescriptor
testDescriptor =
  AdapterDescriptor
    { adapterIdentifier = "test"
    , adapterName = "Test adapter"
    , adapterVersion = "1"
    }

testNativeBinding :: ResolvedNativeBinding
testNativeBinding =
  ResolvedNativeBinding
    {nativeRootQName = testRootQName, nativeVersion = NativeVersion "5.0.0"}

testRootQName :: ExpandedQName
testRootQName = ExpandedQName (Just "urn:test") "model"

testLocation :: SourceLocation
testLocation =
  SourceLocation
    { locationSource = sourceDocumentIdentity testSource
    , locationPath = PathStep testRootQName 1 :| []
    , locationTarget = ElementTarget
    , locationSpan = Nothing
    }

testResolvedView :: ResolvedView
testResolvedView =
  ResolvedView
    { resolvedViewId = "view-1"
    , resolvedViewName = "O2I"
    , resolvedViewLocation = testLocation
    }

testDecodeSpec :: TestDecodeDefect -> DiagnosticSpec
testDecodeSpec TestDecodeDefect = testSpec DecodeStage "o2i.test.decode"

testViewSpec :: TestViewDefect -> DiagnosticSpec
testViewSpec TestViewDefect = testSpec ViewScopeStage "o2i.test.view"

testProfileSpec :: TestProfileDefect -> DiagnosticSpec
testProfileSpec defect =
  case defect of
    TestRootProfileDefect -> testSpec ProfileStage "o2i.test.profile.root"
    TestReachedProfileDefect -> testSpec ProfileStage "o2i.test.profile.reached"

testSpec :: InspectionStage -> Text -> DiagnosticSpec
testSpec stage code =
  DiagnosticSpec
    { specCode = DiagnosticCode code
    , specStage = stage
    , specSeverity = ErrorSeverity
    , specDisposition = ModelFinding
    , specMessage = "Test defect."
    , specSubjects = []
    , specData = Map.empty
    }

noInputs :: InspectionInputs
noInputs =
  InspectionInputs
    {strategyInput = Absent, readinessInput = Absent, evidenceInput = Absent}

runAdapter :: Adapter -> InspectionOutcome
runAdapter adapter = runAdapterWithInputs adapter noInputs

runAdapterWithInputs :: Adapter -> InspectionInputs -> InspectionOutcome
runAdapterWithInputs adapter inputs =
  inspectSourceDocument adapter (ViewByName "O2I") inputs testSource

completedReport :: InspectionOutcome -> IO InspectionReport
completedReport outcome =
  case outcome of
    InspectionCompleted report -> pure report
    InspectionCommandFailed commandError ->
      assertFailure ("unexpected command error: " <> show commandError)

diagnosticCodes :: InspectionReport -> [Text]
diagnosticCodes =
  map (diagnosticCodeText . diagnosticCode)
    . diagnosticsList
    . reportDiagnostics
