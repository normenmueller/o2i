{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import qualified Data.Aeson as Aeson
import Data.Aeson.Key (Key)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import qualified Data.Vector as Vector
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
    , testCase "AtLeastTwo validates its lower bound" atLeastTwoTest
    , testCase "profile snapshots contain exactly one fact" profileSnapshotTest
    , testCase
        "Core defect mappings enumerate every closed constructor"
        closedCoreDefectMappingTest
    , testCase
        "diagnostic identity representation is stable"
        diagnosticIdentityRepresentationTest
    , testCase
        "diagnostic identity rejects delimiter collisions"
        diagnosticIdentityCollisionTest
    , testCase
        "effect-trace identity rejects constituent collisions"
        traceIdentityCollisionTest
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
    , testCase
        "adversarial adapter remains schema-valid by construction"
        adversarialAdapterTest
    , testCase
        "Draft 2020-12 accepts every rendered report state"
        reportSchemaPositiveTest
    , testCase
        "Draft 2020-12 rejects impossible stage automata"
        reportSchemaNegativeTest
    , testCase
        "supplemental source identities survive every consumed stage"
        supplementalSourceRetentionTest
    , testCase "command-error JSON is parseable" commandJsonTest
    , testCase "checked-in schemas are valid JSON" schemaJsonTest
    , testCase "package license equals canonical license" licenseTest
    ]

sourceIdentityTest :: Assertion
sourceIdentityTest = do
  let identity = sourceDocumentIdentity testSource
      validHash = sourceHashText (sourceSha256 identity)
  sourceDisplayLabel identity @?= "model.archimate"
  sourceInputKind identity @?= FileSource
  validHash
    @?= "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  mkSourceHash validHash @?= Just (sourceSha256 identity)
  mkSourceHash ("A" <> Text.drop 1 validHash) @?= Nothing
  mkSourceHash (Text.drop 1 validHash) @?= Nothing

sourceLocationInvariantTest :: Assertion
sourceLocationInvariantTest = do
  mkExpandedQName Nothing "" @?= Left EmptyQNameLocalName
  fmap qNameLocalName (mkExpandedQName (Just "urn:test") "model")
    @?= Right "model"
  mkPathStep testRootQName 0 @?= Nothing
  let step = firstPathStep testRootQName
  pathStepName step @?= testRootQName
  pathStepOrdinal step @?= 1
  mkSourceSpan 1 2 1 1 @?= Nothing
  mkSourceSpan 0 1 1 1 @?= Nothing
  assertBool
    "one-based path step expected"
    (mkPathStep testRootQName 1 /= Nothing)
  case mkSourceSpan 1 2 3 4 of
    Nothing -> assertFailure "ordered source span expected"
    Just sourceSpan -> do
      spanStartLine sourceSpan @?= 1
      spanStartColumn sourceSpan @?= 2
      spanEndLine sourceSpan @?= 3
      spanEndColumn sourceSpan @?= 4

atLeastTwoTest :: Assertion
atLeastTwoTest = do
  atLeastTwoFromList ([] :: [Text]) @?= Nothing
  atLeastTwoFromList (["one"] :: [Text]) @?= Nothing
  fmap atLeastTwoToList (atLeastTwoFromList (["one", "two", "three"] :: [Text]))
    @?= Just ["one", "two", "three"]
  atLeastTwoToList (atLeastTwo "one" "two" ["three"] :: AtLeastTwo Text)
    @?= ["one", "two", "three"]

profileSnapshotTest :: Assertion
profileSnapshotTest =
  snapshotFact (profileSnapshot (Located testLocation TestProfileFact))
    @?= Located testLocation TestProfileFact

closedCoreDefectMappingTest :: Assertion
closedCoreDefectMappingTest = do
  traceable <- completeTraceableModel
  let trace = NonEmpty.head (effectTraces traceable)
      traceId = traceIdentifier trace
      intervention = traceIntervention trace
      kpi = traceKPI trace
      node = RawNodeId "node"
      other = RawNodeId "other"
      relation = RelationName "relation"
      edge = RawEdge node relation other
      domain = BoundedDomain (Level 0) (Level 1)
  assertClosedMapping
    StructureStage
    structuralDefectSpec
    [ DuplicateNodeId node
    , DuplicateEdge edge
    , UnknownOwner node other
    , InvalidPrimitiveInterpretation node Mission Objective
    , InvalidStructuringContext node Mission PerformanceDimension
    , UnknownEdgeEndpoint edge other
    , UnknownRelation relation
    , InvalidRelationEndpointKinds
        edge
        (ContextNodeKind Mission)
        (ContextNodeKind Vision)
    , PerformanceDimensionMembershipOwnerMismatch edge node other
    ]
    [ "o2i.structure.node-id-duplicate"
    , "o2i.structure.edge-duplicate"
    , "o2i.structure.owner-unknown"
    , "o2i.structure.interpretation-invalid"
    , "o2i.structure.structuring-context-invalid"
    , "o2i.structure.endpoint-unknown"
    , "o2i.structure.relation-unknown"
    , "o2i.structure.relation-endpoint-kinds-invalid"
    , "o2i.structure.membership-owner-mismatch"
    ]
  assertClosedMapping
    SemanticsStage
    semanticDefectSpec
    [ EthosWithoutPrinciple node
    , MissionWithoutDriver node
    , MissionWithoutEthosGuidance node
    , VisionWithoutObjective node
    , VisionWithoutMissionGrounding node
    , VisionWithoutEthosGuidance node
    , StrategyIntentWithoutVisionOrientation node other
    , SituationWithoutConstitutingAnchor node
    , NeedWithoutDriver node
    , NeedWithoutObjective node
    , NeedWithoutSurfacingSituation node
    , UnanchoredNeedDriver node other
    , UngroundedNeedObjective node other
    , InterventionWithoutAction node
    , InterventionWithoutKeyResult node
    , InterventionWithoutActionContribution node
    , MeasureWithoutPerformanceDimension node
    , MeasureWithoutKPI node
    , MeasureWithoutKPIDimensionMembership node
    , StrategyWithoutFormulation node
    , DuplicateStrategyFormulation node
    , UnknownFormulationStrategy node
    , FormulationForNonStrategy node (ContextNodeKind Mission)
    , EmptyStrategyText node ScopeField
    , DuplicateStrategyPrimitiveReference node DiagnosisRole other
    , InvalidStrategyPrimitiveReference node IntentRole other Objective
    , StrategyActionWithoutKeyResult node other
    , MissingStrategyCoherence node node relation other
    ]
    [ "o2i.semantics.ethos-principle-missing"
    , "o2i.semantics.mission-driver-missing"
    , "o2i.semantics.mission-ethos-guidance-missing"
    , "o2i.semantics.vision-objective-missing"
    , "o2i.semantics.vision-mission-grounding-missing"
    , "o2i.semantics.vision-ethos-guidance-missing"
    , "o2i.semantics.strategy-vision-orientation-missing"
    , "o2i.semantics.situation-unconstituted"
    , "o2i.semantics.need-driver-missing"
    , "o2i.semantics.need-objective-missing"
    , "o2i.semantics.need-unsituated"
    , "o2i.semantics.need-driver-unanchored"
    , "o2i.semantics.need-objective-ungrounded"
    , "o2i.semantics.intervention-action-missing"
    , "o2i.semantics.intervention-key-result-missing"
    , "o2i.semantics.intervention-action-contribution-missing"
    , "o2i.semantics.measure-performance-dimension-missing"
    , "o2i.semantics.measure-kpi-missing"
    , "o2i.semantics.measure-kpi-membership-missing"
    , "o2i.semantics.formulation-missing"
    , "o2i.semantics.formulation-duplicate"
    , "o2i.semantics.formulation-strategy-unknown"
    , "o2i.semantics.formulation-target-invalid"
    , "o2i.semantics.formulation-text-empty"
    , "o2i.semantics.formulation-reference-duplicate"
    , "o2i.semantics.formulation-reference-invalid"
    , "o2i.semantics.strategy-action-unsubstantiated"
    , "o2i.semantics.strategy-coherence-missing"
    ]
  assertClosedMapping
    TraceabilityStage
    traceabilityDefectSpec
    [ NoIntervention
    , InterventionWithoutNeed node
    , MissingMacroEvidence node relation other
    , MissingEffectTrace node other
    ]
    [ "o2i.traceability.intervention-missing"
    , "o2i.traceability.intervention-need-missing"
    , "o2i.traceability.macro-evidence-missing"
    , "o2i.traceability.effect-trace-missing"
    ]
  assertClosedMapping
    ReadinessStage
    readinessDefectSpec
    [ UnknownKPIDefinition node
    , DuplicateKPIDefinition node 2
    , ConflictingKPIDefinition node 2
    , MissingKPIDefinition kpi
    , InvalidKPIValueDomain node domain
    , EmptyKPIUnit node
    , EmptyKPIMeasurementMethod node
    , EmptyKPIInterpretation node
    , UnknownPlannedInterventionStart node
    , DuplicatePlannedInterventionStart node 2
    , MissingPlannedInterventionStart intervention
    , ReadinessCheckedAtOrAfterPlannedStart intervention
    , UnknownEvidencePlanTrace traceId
    , DuplicateEvidencePlan traceId 2
    , MissingEvidencePlan traceId
    , PlanEstablishedAfterCheck traceId
    , BaselineObservedAfterCheck traceId
    , InvalidTargetDueDate traceId
    , BaselineKPIMismatch traceId node other
    , BaselineAnchorMismatch traceId node other
    , InvalidEffectCriterion traceId
    , RelativeEffectCriterionWithZeroBaseline traceId
    , InvalidTargetCriterion traceId
    , BaselineLevelOutsideDomain traceId (Level 2) domain
    , EffectCriterionOutsideDomain traceId (Level 2) domain
    , TargetCriterionOutsideDomain traceId (Level 2) domain
    , EmptyPlanSource traceId
    , EmptyBaselineSource traceId
    ]
    [ "o2i.readiness.kpi-definition-unknown"
    , "o2i.readiness.kpi-definition-duplicate"
    , "o2i.readiness.kpi-definition-conflicting"
    , "o2i.readiness.kpi-definition-missing"
    , "o2i.readiness.kpi-domain-invalid"
    , "o2i.readiness.kpi-unit-empty"
    , "o2i.readiness.kpi-method-empty"
    , "o2i.readiness.kpi-interpretation-empty"
    , "o2i.readiness.planned-start-unknown"
    , "o2i.readiness.planned-start-duplicate"
    , "o2i.readiness.planned-start-missing"
    , "o2i.readiness.check-not-before-start"
    , "o2i.readiness.plan-trace-unknown"
    , "o2i.readiness.plan-duplicate"
    , "o2i.readiness.plan-missing"
    , "o2i.readiness.plan-established-after-check"
    , "o2i.readiness.baseline-after-check"
    , "o2i.readiness.target-date-invalid"
    , "o2i.readiness.baseline-kpi-mismatch"
    , "o2i.readiness.baseline-anchor-mismatch"
    , "o2i.readiness.effect-criterion-invalid"
    , "o2i.readiness.relative-baseline-zero"
    , "o2i.readiness.target-criterion-invalid"
    , "o2i.readiness.baseline-domain-invalid"
    , "o2i.readiness.effect-domain-invalid"
    , "o2i.readiness.target-domain-invalid"
    , "o2i.readiness.plan-source-empty"
    , "o2i.readiness.baseline-source-empty"
    ]
  assertClosedMapping
    EvidenceStage
    evidenceDefectSpec
    [ UnknownActualInterventionStart node
    , DuplicateActualInterventionStart node 2
    , MissingActualInterventionStart intervention
    , ActualInterventionStartAtOrBeforeReadiness intervention
    , ActualInterventionStartAtOrAfterAssessment intervention
    , UnknownFollowUpTrace traceId
    , DuplicateFollowUpObservation traceId followUpDate 2
    , MissingFollowUpObservation traceId
    , FollowUpKPIMismatch traceId node other
    , FollowUpAnchorMismatch traceId node other
    , FollowUpLevelOutsideDomain traceId (Level 2) domain
    , FollowUpObservedAtOrBeforeActualStart traceId
    , FollowUpObservedAfterAssessment traceId
    , EmptyFollowUpSource traceId
    ]
    [ "o2i.evidence.actual-start-unknown"
    , "o2i.evidence.actual-start-duplicate"
    , "o2i.evidence.actual-start-missing"
    , "o2i.evidence.actual-start-before-readiness"
    , "o2i.evidence.actual-start-after-assessment"
    , "o2i.evidence.follow-up-trace-unknown"
    , "o2i.evidence.follow-up-duplicate"
    , "o2i.evidence.follow-up-missing"
    , "o2i.evidence.follow-up-kpi-mismatch"
    , "o2i.evidence.follow-up-anchor-mismatch"
    , "o2i.evidence.follow-up-domain-invalid"
    , "o2i.evidence.follow-up-before-start"
    , "o2i.evidence.follow-up-after-assessment"
    , "o2i.evidence.follow-up-source-empty"
    ]

assertClosedMapping ::
     InspectionStage
  -> (defect -> DiagnosticSpec)
  -> [defect]
  -> [Text]
  -> Assertion
assertClosedMapping _stage specification defects expectedCodes =
  map (diagnosticCodeText . specCode . specification) defects @?= expectedCodes

diagnosticIdentityRepresentationTest :: Assertion
diagnosticIdentityRepresentationTest = do
  first <- diagnosticForSpec testLocation (testSpec "x")
  second <- diagnosticForSpec testLocation (testSpec "x")
  diagnosticIdText (diagnosticId first)
    @?= diagnosticIdText (diagnosticId second)
  diagnosticStage first @?= DecodeStage
  diagnosticCodeText (diagnosticCode first) @?= "o2i.x"

diagnosticIdentityCollisionTest :: Assertion
diagnosticIdentityCollisionTest = do
  subjectsLeft <- diagnosticForSubjects [DiagnosticSubject "a" "b,c:d"]
  subjectsRight <-
    diagnosticForSubjects [DiagnosticSubject "a" "b", DiagnosticSubject "c" "d"]
  assertDistinctDiagnosticIds subjectsLeft subjectsRight
  textData <- diagnosticForData (DiagnosticText "1:true")
  integerData <- diagnosticForData (DiagnosticInteger 1)
  booleanData <- diagnosticForData (DiagnosticBoolean True)
  assertDistinctDiagnosticIds textData integerData
  assertDistinctDiagnosticIds integerData booleanData
  let firstEdge = RawEdge (RawNodeId "a:b") (RelationName "c") (RawNodeId "d")
      secondEdge = RawEdge (RawNodeId "a") (RelationName "b") (RawNodeId "c:d")
  firstEdgeDiagnostic <-
    diagnosticForSpec
      testLocation
      (structuralDefectSpec (DuplicateEdge firstEdge))
  secondEdgeDiagnostic <-
    diagnosticForSpec
      testLocation
      (structuralDefectSpec (DuplicateEdge secondEdge))
  assertDistinctDiagnosticIds firstEdgeDiagnostic secondEdgeDiagnostic
  reservedLeft <- diagnosticForLocations reservedQNameLocationLeft
  reservedRight <- diagnosticForLocations reservedQNameLocationRight
  assertDistinctDiagnosticIds reservedLeft reservedRight
  singlePath <- diagnosticForLocations singlePathCollisionLocation
  multiplePath <- diagnosticForLocations multiPathCollisionLocation
  assertDistinctDiagnosticIds singlePath multiplePath

traceIdentityCollisionTest :: Assertion
traceIdentityCollisionTest = do
  first <-
    renamedCompleteTraceId
      [ (completeVisionId, RawNodeId "left:right")
      , (completeVisionObjectiveId, RawNodeId "tail")
      ]
  second <-
    renamedCompleteTraceId
      [ (completeVisionId, RawNodeId "left")
      , (completeVisionObjectiveId, RawNodeId "right:tail")
      ]
  effectTraceIdText first
    /= effectTraceIdText second
         @? "length framing must distinguish shifted trace delimiters"
  firstDiagnostic <-
    diagnosticForSpec
      testLocation
      (readinessDefectSpec (MissingEvidencePlan first))
  secondDiagnostic <-
    diagnosticForSpec
      testLocation
      (readinessDefectSpec (MissingEvidencePlan second))
  assertDistinctDiagnosticIds firstDiagnostic secondDiagnostic

diagnosticForSubjects :: [DiagnosticSubject] -> IO Diagnostic
diagnosticForSubjects subjects =
  diagnosticForSpec testLocation (identitySpec subjects Map.empty)

diagnosticForLocations :: SourceLocation -> IO Diagnostic
diagnosticForLocations location =
  diagnosticForSpec location (identitySpec [] Map.empty)

diagnosticForData :: DiagnosticAtom -> IO Diagnostic
diagnosticForData atom =
  diagnosticForSpec
    testLocation
    (identitySpec [] (Map.singleton "reserved,:|=" atom))

identitySpec ::
     [DiagnosticSubject] -> Map.Map Text DiagnosticAtom -> DiagnosticSpec
identitySpec subjects dataFields =
  diagnosticSpec
    (o2iDiagnosticCode "identity")
    ErrorSeverity
    ModelFinding
    "Identity test defect."
    subjects
    dataFields

diagnosticForSpec :: SourceLocation -> DiagnosticSpec -> IO Diagnostic
diagnosticForSpec location specification = do
  report <-
    completedReport (runAdapter (diagnosticAdapter location specification))
  case diagnosticsList (reportDiagnostics report) of
    [diagnostic] -> pure diagnostic
    diagnostics ->
      assertFailure
        ("expected one diagnostic, found " <> show (length diagnostics))

assertDistinctDiagnosticIds :: Diagnostic -> Diagnostic -> Assertion
assertDistinctDiagnosticIds first second =
  diagnosticId first /= diagnosticId second @? "diagnostic IDs collided"

reservedQNameLocationLeft, reservedQNameLocationRight :: SourceLocation
reservedQNameLocationLeft =
  testLocation
    { locationPath =
        firstPathStep (expandedQName (Just "urn}reserved") 'n' "ame") :| []
    }

reservedQNameLocationRight =
  testLocation
    { locationPath =
        firstPathStep (expandedQName (Just "urn") 'r' "eserved}name") :| []
    }

singlePathCollisionLocation, multiPathCollisionLocation :: SourceLocation
singlePathCollisionLocation =
  testLocation
    { locationPath =
        firstPathStep (expandedQName Nothing 'a' "[1]/{urn:path}b") :| []
    }

multiPathCollisionLocation =
  testLocation
    { locationPath =
        firstPathStep (expandedQName Nothing 'a' "")
          :| [firstPathStep (expandedQName (Just "urn:path") 'b' "")]
    }

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
  first <- completedReport (runAdapter goodEthosAdapter)
  second <- completedReport (runAdapter alternateAdapter)
  reportScopeResolution first @?= reportScopeResolution second
  reportResult first @?= reportResult second

reportJsonTest :: Assertion
reportJsonTest = do
  report <- completedReport (runAdapter goodEthosAdapter)
  let first = renderInspectionReportJSON report
      second = renderInspectionReportJSON report
  first @?= second
  case Aeson.eitherDecode first :: Either String Aeson.Value of
    Left message -> assertFailure message
    Right _ -> pure ()

adversarialAdapterTest :: Assertion
adversarialAdapterTest = do
  mkAdapterDescriptor "" "" ""
    @?= Left (EmptyAdapterIdentifier :| [EmptyAdapterName, EmptyAdapterVersion])
  mkDiagnosticCode "not-o2i" @?= Left DiagnosticCodeMissingO2IPrefix
  fmap diagnosticCodeText (mkDiagnosticCode "o2i.external.valid")
    @?= Right "o2i.external.valid"
  schema <- inspectionSchema
  reports <-
    traverse
      (completedReport . runAdapter . adversarialAdapter)
      [AdversarialDecode, AdversarialView, AdversarialProfile]
  let diagnostics = map (diagnosticsList . reportDiagnostics) reports
  map (map diagnosticStage) diagnostics
    @?= [[DecodeStage], [ViewScopeStage], [ProfileStage]]
  assertBool
    "all adversarial codes must remain in the O2I namespace"
    (all (all ((== "o2i.") . diagnosticCodeText . diagnosticCode)) diagnostics)
  assertBool
    "all adversarial defects must retain source provenance"
    (all (all ((== [testLocation]) . diagnosticLocations)) diagnostics)
  assertBool
    "every adversarial report must satisfy Draft 2020-12"
    (all (validateJSONSchema schema . renderedReportValue) reports)

reportSchemaPositiveTest :: Assertion
reportSchemaPositiveTest = do
  schema <- inspectionSchema
  reports <- allReportVariants
  mapM_
    (\(name, report) ->
       assertBool
         (name <> " renderer output failed Draft 2020-12 validation")
         (validateJSONSchema schema (renderedReportValue report)))
    reports

reportSchemaNegativeTest :: Assertion
reportSchemaNegativeTest = do
  schema <- inspectionSchema
  reports <- allReportVariants
  partial <- namedReport "semantics-unavailable" reports
  semanticFailure <- namedReport "semantics-failed" reports
  let partialValue = renderedReportValue partial
      semanticFailureValue = renderedReportValue semanticFailure
      impossible =
        [ ("result contradicts stages", setField "result" "passed" partialValue)
        , ( "blocked stage is not the earliest unavailable stage"
          , modifyStage 5 (setBlockedByStage "profile") partialValue)
        , ( "not-run successor claims to have passed"
          , modifyStage 5 markStagePassed partialValue)
        , ( "unused Strategy source appears in unavailable Semantics"
          , copyField "supplementalSources" semanticFailureValue partialValue)
        ]
  mapM_
    (\(name, value) ->
       assertBool
         (name <> " unexpectedly satisfies the report schema")
         (not (validateJSONSchema schema value)))
    impossible

supplementalSourceRetentionTest :: Assertion
supplementalSourceRetentionTest = do
  inputs <- validInspectionInputs
  complete <- completedReport (runAdapterWithInputs completeModelAdapter inputs)
  map supplementalInputKind (reportSupplementalSources complete)
    @?= [StrategySupplement, ReadinessSupplement, EvidenceSupplement]
  reportResult complete @?= InspectionPassed
  let firstIdentity = sourceIdentity "strategy-a.json" "same formulation"
      secondIdentity = sourceIdentity "strategy-b.json" "same formulation"
      supplied identity =
        noInputs
          { strategyInput =
              Supplied (Sourced identity (StrategyFormulationBundle []))
          }
  first <-
    completedReport
      (runAdapterWithInputs strategyModelAdapter (supplied firstIdentity))
  second <-
    completedReport
      (runAdapterWithInputs strategyModelAdapter (supplied secondIdentity))
  sourceSha256 firstIdentity @?= sourceSha256 secondIdentity
  reportSupplementalSources first
    @?= [SupplementalSource StrategySupplement firstIdentity]
  reportSupplementalSources second
    @?= [SupplementalSource StrategySupplement secondIdentity]
  renderInspectionReportJSON first
    /= renderInspectionReportJSON second
         @? "reports must distinguish equal data supplied by different sources"
  map diagnosticSupplementalSources (diagnosticsList (reportDiagnostics first))
    @?= [[SupplementalSource StrategySupplement firstIdentity]]
  map diagnosticSupplementalSources (diagnosticsList (reportDiagnostics second))
    @?= [[SupplementalSource StrategySupplement secondIdentity]]

allReportVariants :: IO [(String, InspectionReport)]
allReportVariants = do
  inputs <- validInspectionInputs
  let strategyOnly = noInputs {strategyInput = strategyInput inputs}
      readinessEmpty =
        strategyOnly
          { readinessInput =
              Supplied
                (Sourced
                   readinessSourceIdentity
                   (ReadinessBundle readinessDate [] [] []))
          }
      evidenceUnavailable = inputs {evidenceInput = Absent}
      evidenceEmpty =
        inputs
          { evidenceInput =
              Supplied
                (Sourced
                   evidenceSourceIdentity
                   (EvidenceBundle assessmentDate [] []))
          }
      cases =
        [ ( "decode-failed"
          , runAdapter
              (testAdapter
                 DecodeRejectedMode
                 ViewSucceeds
                 RootSucceeds
                 completeEthosFacts
                 []))
        , ( "view-failed"
          , runAdapter
              (testAdapter
                 DecodeSucceeds
                 ViewFails
                 RootSucceeds
                 completeEthosFacts
                 []))
        , ( "profile-failed"
          , runAdapter
              (testAdapter
                 DecodeSucceeds
                 ViewSucceeds
                 RootFails
                 completeEthosFacts
                 []))
        , ( "adversarial-decode-failed"
          , runAdapter (adversarialAdapter AdversarialDecode))
        , ( "adversarial-view-failed"
          , runAdapter (adversarialAdapter AdversarialView))
        , ( "adversarial-profile-failed"
          , runAdapter (adversarialAdapter AdversarialProfile))
        , ( "scope-failed"
          , runAdapter
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
        , ( "structure-failed"
          , runAdapter
              (testAdapter
                 DecodeSucceeds
                 ViewSucceeds
                 RootSucceeds
                 duplicateNodeFacts
                 []))
        , ( "semantics-unavailable"
          , runAdapterWithInputs strategyModelAdapter noInputs)
        , ( "semantics-failed"
          , runAdapterWithInputs
              strategyModelAdapter
              noInputs
                { strategyInput =
                    Supplied
                      (Sourced
                         strategySourceIdentity
                         (StrategyFormulationBundle []))
                })
        , ("traceability-failed", runAdapter goodEthosAdapter)
        , ( "readiness-unavailable"
          , runAdapterWithInputs completeModelAdapter strategyOnly)
        , ( "readiness-failed"
          , runAdapterWithInputs completeModelAdapter readinessEmpty)
        , ( "evidence-unavailable"
          , runAdapterWithInputs completeModelAdapter evidenceUnavailable)
        , ( "evidence-failed"
          , runAdapterWithInputs completeModelAdapter evidenceEmpty)
        , ("passed", runAdapterWithInputs completeModelAdapter inputs)
        ]
  traverse complete cases
  where
    complete (name, outcome) = do
      report <- completedReport outcome
      pure (name, report)

namedReport :: String -> [(String, InspectionReport)] -> IO InspectionReport
namedReport requested reports =
  case lookup requested reports of
    Nothing -> assertFailure ("missing report variant: " <> requested)
    Just report -> pure report

inspectionSchema :: IO Aeson.Value
inspectionSchema = do
  bytes <-
    LazyByteString.readFile
      ("schema" </> "o2i.inspection.report-v1.schema.json")
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message
    Right schema -> pure schema

renderedReportValue :: InspectionReport -> Aeson.Value
renderedReportValue report =
  maybe Aeson.Null id (Aeson.decode (renderInspectionReportJSON report))

setField :: Key -> Aeson.Value -> Aeson.Value -> Aeson.Value
setField key value document =
  case document of
    Aeson.Object object -> Aeson.Object (KeyMap.insert key value object)
    _ -> document

copyField :: Key -> Aeson.Value -> Aeson.Value -> Aeson.Value
copyField key source target =
  case source of
    Aeson.Object object ->
      maybe
        target
        (\value -> setField key value target)
        (KeyMap.lookup key object)
    _ -> target

modifyStage :: Int -> (Aeson.Value -> Aeson.Value) -> Aeson.Value -> Aeson.Value
modifyStage index transform document =
  case document of
    Aeson.Object object ->
      case KeyMap.lookup "stages" object of
        Just (Aeson.Array stages)
          | index < Vector.length stages ->
            Aeson.Object
              (KeyMap.insert
                 "stages"
                 (Aeson.Array
                    (stages
                       Vector.// [(index, transform (stages Vector.! index))]))
                 object)
        _ -> document
    _ -> document

setBlockedByStage :: Aeson.Value -> Aeson.Value -> Aeson.Value
setBlockedByStage stageValue stage =
  case stage of
    Aeson.Object object ->
      case KeyMap.lookup "blockedBy" object of
        Just blocked ->
          Aeson.Object
            (KeyMap.insert
               "blockedBy"
               (setField "stage" stageValue blocked)
               object)
        Nothing -> stage
    _ -> stage

markStagePassed :: Aeson.Value -> Aeson.Value
markStagePassed stage =
  case stage of
    Aeson.Object object ->
      Aeson.Object
        (KeyMap.delete "blockedBy" (KeyMap.insert "state" "passed" object))
    _ -> stage

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

goodEthosAdapter :: Adapter
goodEthosAdapter =
  testAdapter DecodeSucceeds ViewSucceeds RootSucceeds completeEthosFacts []

strategyModelAdapter :: Adapter
strategyModelAdapter =
  testAdapter DecodeSucceeds ViewSucceeds RootSucceeds strategyFacts []

completeModelAdapter :: Adapter
completeModelAdapter =
  testAdapter DecodeSucceeds ViewSucceeds RootSucceeds completeModelFacts []

validInspectionInputs :: IO InspectionInputs
validInspectionInputs = do
  traceable <- completeTraceableModel
  let trace = NonEmpty.head (effectTraces traceable)
      definition =
        RawKPIDefinition
          { rawDefinitionKPI = completeMeasureKpiId
          , rawDefinitionUnit = PercentagePoints
          , rawDefinitionDomain = BoundedDomain (Level 0) (Level 100)
          , rawDefinitionMeasurementMethod = "controlled monthly measurement"
          , rawDefinitionInterpretation = "higher levels indicate improvement"
          }
      plannedStart =
        PlannedInterventionStart
          { plannedIntervention = completeInterventionId
          , plannedStartAt = interventionDate
          }
      baselineObservation =
        Observation
          { observationKPI = completeMeasureKpiId
          , observationAnchor = completeSituationAnchorId
          , observedAt = baselineDate
          , observedLevel = Level 40
          , observationSource = EvidenceSource "controlled baseline"
          }
      evidencePlan =
        EvidencePlan
          { plannedTrace = traceIdentifier trace
          , establishedAt = criteriaDate
          , targetDueAt = targetDate
          , planSource = EvidenceSource "approved evidence plan"
          , baseline = baselineObservation
          , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 10)
          , targetCriterion = AtLeast (Level 70)
          }
      actualStart =
        ActualInterventionStart
          { actualIntervention = completeInterventionId
          , actualStartAt = interventionDate
          }
      followUp =
        FollowUpObservation
          { followUpTrace = traceIdentifier trace
          , followUpObservation =
              baselineObservation
                { observedAt = followUpDate
                , observedLevel = Level 75
                , observationSource = EvidenceSource "controlled follow-up"
                }
          }
  pure
    InspectionInputs
      { strategyInput =
          Supplied
            (Sourced
               strategySourceIdentity
               (StrategyFormulationBundle [completeStrategyFormulation]))
      , readinessInput =
          Supplied
            (Sourced
               readinessSourceIdentity
               ReadinessBundle
                 { readinessCheckedAtInput = readinessDate
                 , kpiDefinitionsInput = [definition]
                 , plannedStartsInput = [plannedStart]
                 , evidencePlansInput = [evidencePlan]
                 })
      , evidenceInput =
          Supplied
            (Sourced
               evidenceSourceIdentity
               EvidenceBundle
                 { evidenceAssessedAtInput = assessmentDate
                 , actualStartsInput = [actualStart]
                 , followUpsInput = [followUp]
                 })
      }

completeTraceableModel :: IO TraceableEffectModel
completeTraceableModel = completeTraceableModelFor completeRawGraph

completeTraceableModelFor :: RawGraph -> IO TraceableEffectModel
completeTraceableModelFor graphInput =
  case validateStructure graphInput of
    StructureAccepted graph ->
      case validateModelSemantics graph [completeStrategyFormulation] of
        Failure defects ->
          assertFailure ("complete Semantics fixture failed: " <> show defects)
        Success semantic ->
          case validateTraceability semantic of
            Failure defects ->
              assertFailure
                ("complete Traceability fixture failed: " <> show defects)
            Success traceable -> pure traceable
    StructureModelRejected defects ->
      assertFailure ("complete Structure fixture failed: " <> show defects)
    StructureInternalFailure failure ->
      assertFailure ("complete Structure fixture failed: " <> show failure)

renamedCompleteTraceId :: [(RawNodeId, RawNodeId)] -> IO EffectTraceId
renamedCompleteTraceId renames = do
  traceable <- completeTraceableModelFor (renameGraph renames completeRawGraph)
  pure (traceIdentifier (NonEmpty.head (effectTraces traceable)))

renameGraph :: [(RawNodeId, RawNodeId)] -> RawGraph -> RawGraph
renameGraph renames graph =
  RawGraph
    { rawNodes = map renameNode (rawNodes graph)
    , rawEdges = map renameEdge (rawEdges graph)
    }
  where
    rename identifier = maybe identifier id (lookup identifier renames)
    renameNode node =
      case node of
        RawContextNode identifier context ->
          RawContextNode (rename identifier) context
        RawPrimitiveNode identifier owner primitive ->
          RawPrimitiveNode (rename identifier) (rename owner) primitive
        RawStructuringNode identifier owner structuring ->
          RawStructuringNode (rename identifier) (rename owner) structuring
        RawAnchorNode identifier anchor ->
          RawAnchorNode (rename identifier) anchor
    renameEdge edge =
      edge
        { rawEdgeFrom = rename (rawEdgeFrom edge)
        , rawEdgeTo = rename (rawEdgeTo edge)
        }

sourceIdentity :: Text -> ByteString.ByteString -> SourceIdentity
sourceIdentity label bytes =
  sourceDocumentIdentity (sourceDocumentFromBytes label FileSource bytes)

strategySourceIdentity, readinessSourceIdentity, evidenceSourceIdentity ::
     SourceIdentity
strategySourceIdentity = sourceIdentity "strategy.json" "strategy-input"

readinessSourceIdentity = sourceIdentity "readiness.json" "readiness-input"

evidenceSourceIdentity = sourceIdentity "evidence.json" "evidence-input"

completeModelFacts :: [FactTemplate]
completeModelFacts = graphFacts completeRawGraph

graphFacts :: RawGraph -> [FactTemplate]
graphFacts graph =
  OccurrenceTemplate completePresentation
    : concat
        [ [ NodeTemplate occurrence node
          , SeedTemplate completePresentation occurrence
          ]
        | (index, node) <- zip [(1 :: Int) ..] (rawNodes graph)
        , let occurrence = indexedOccurrence "node" index
        ]
    ++ concat
         [ [ EdgeTemplate occurrence edgeValue
           , SeedTemplate completePresentation occurrence
           ]
         | (index, edgeValue) <- zip [(1 :: Int) ..] (rawEdges graph)
         , let occurrence = indexedOccurrence "edge" index
         ]

indexedOccurrence :: Text -> Int -> OccurrenceId
indexedOccurrence prefix index =
  OccurrenceId (prefix <> "-" <> Text.pack (show index))

completePresentation :: OccurrenceId
completePresentation = OccurrenceId "presentation-complete"

completeRawGraph :: RawGraph
completeRawGraph = RawGraph completeNodes completeEdges

completeNodes :: [RawNode]
completeNodes =
  [ RawContextNode completeEthosId Ethos
  , RawContextNode completeMissionId Mission
  , RawContextNode completeVisionId Vision
  , RawContextNode completeStrategyId Strategy
  , RawContextNode completeNeedId Need
  , RawContextNode completeInterventionId Intervention
  , RawContextNode completeMeasureId Measure
  , RawContextNode completeSituationId Situation
  , RawPrimitiveNode completeEthosPrincipleId completeEthosId Principle
  , RawPrimitiveNode completeMissionDriverId completeMissionId Driver
  , RawPrimitiveNode completeVisionObjectiveId completeVisionId Objective
  , RawPrimitiveNode completeStrategyDriverId completeStrategyId Driver
  , RawPrimitiveNode completeStrategyObjectiveId completeStrategyId Objective
  , RawPrimitiveNode completeStrategyPrincipleId completeStrategyId Principle
  , RawPrimitiveNode completeStrategyKeyResultId completeStrategyId KeyResult
  , RawPrimitiveNode completeStrategyActionId completeStrategyId Action
  , RawPrimitiveNode completeNeedDriverId completeNeedId Driver
  , RawPrimitiveNode completeNeedObjectiveId completeNeedId Objective
  , RawPrimitiveNode completeInterventionActionId completeInterventionId Action
  , RawPrimitiveNode
      completeInterventionKeyResultId
      completeInterventionId
      KeyResult
  , RawPrimitiveNode completeMeasureKpiId completeMeasureId KPI
  , RawStructuringNode
      completeMeasureDimensionId
      completeMeasureId
      PerformanceDimension
  , RawAnchorNode completeSituationAnchorId BusinessCapability
  ]

completeEdges :: [RawEdge]
completeEdges =
  [ completeEdge
      completeEthosPrincipleId
      guidesEthosPrincipleToMissionDriver
      completeMissionDriverId
  , completeEdge
      completeMissionDriverId
      groundsMissionDriverToVisionObjective
      completeVisionObjectiveId
  , completeEdge
      completeEthosPrincipleId
      guidesEthosPrincipleToVisionObjective
      completeVisionObjectiveId
  , completeEdge completeVisionId orientsStrategy completeStrategyId
  , completeEdge completeStrategyId qualifiesNeed completeNeedId
  , completeEdge completeSituationId surfacesNeed completeNeedId
  , completeEdge completeStrategyId directsIntervention completeInterventionId
  , completeEdge completeInterventionId addressesNeed completeNeedId
  , completeEdge completeInterventionId changesSituation completeSituationId
  , completeEdge completeStrategyId framesMeasure completeMeasureId
  , completeEdge completeInterventionId setsTargetForMeasure completeMeasureId
  , completeEdge completeMeasureId measuresSituation completeSituationId
  , completeEdge
      completeVisionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      completeStrategyObjectiveId
  , completeEdge
      completeStrategyDriverId
      groundsStrategyDriverToObjective
      completeStrategyObjectiveId
  , completeEdge
      completeStrategyPrincipleId
      guidesStrategyPrincipleToAction
      completeStrategyActionId
  , completeEdge
      completeStrategyKeyResultId
      substantiatesStrategyKeyResultObjective
      completeStrategyObjectiveId
  , completeEdge
      completeStrategyActionId
      contributesStrategyActionToKeyResult
      completeStrategyKeyResultId
  , completeEdge
      completeStrategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      completeNeedObjectiveId
  , completeEdge
      completeNeedDriverId
      groundsNeedDriverToObjective
      completeNeedObjectiveId
  , completeEdge
      completeSituationId
      (constitutedByAnchor SBusinessCapability)
      completeSituationAnchorId
  , completeEdge
      completeSituationAnchorId
      (anchorsNeedDriver SBusinessCapability)
      completeNeedDriverId
  , completeEdge
      completeStrategyActionId
      guidesStrategyActionToInterventionAction
      completeInterventionActionId
  , completeEdge
      completeInterventionActionId
      contributesInterventionActionToKeyResult
      completeInterventionKeyResultId
  , completeEdge
      completeInterventionKeyResultId
      substantiatesInterventionKeyResultNeedObjective
      completeNeedObjectiveId
  , completeEdge
      completeInterventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      completeStrategyKeyResultId
  , completeEdge
      completeStrategyDriverId
      indicatesMeasurePerformanceDimension
      completeMeasureDimensionId
  , completeEdge
      completeStrategyKeyResultId
      determinesMeasurePerformanceDimension
      completeMeasureDimensionId
  , completeEdge
      completeMeasureDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      completeMeasureKpiId
  , completeEdge
      completeInterventionKeyResultId
      setsTargetForMeasureKPI
      completeMeasureKpiId
  , completeEdge
      completeInterventionActionId
      (changesAnchor SBusinessCapability)
      completeSituationAnchorId
  , completeEdge
      completeMeasureKpiId
      (measuresAnchor SBusinessCapability)
      completeSituationAnchorId
  ]

completeEdge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
completeEdge from relation to = RawEdge from (relationNameFor relation) to

completeStrategyFormulation :: RawStrategyFormulation
completeStrategyFormulation =
  RawStrategyFormulation
    { rawFormulationStrategy = completeStrategyId
    , rawFormulationScope = "enterprise" :| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "enterprise"
          , anchoringDecisionLevel = "executive"
          , anchoringResponsibilities = "strategy owner" :| []
          , anchoringDecisionPaths = "governance" :| []
          , anchoringImplementationLogic = "coherent commitments"
          }
    , rawFormulationGuardrails = "evidence before assumption" :| []
    , rawFormulationDiagnosis = completeStrategyDriverId
    , rawFormulationIntent = completeStrategyObjectiveId
    , rawFormulationGuidingPolicy = completeStrategyPrincipleId
    , rawFormulationPositioning = "shared understanding" :| []
    , rawFormulationTradeOffs = "traceability over speed" :| []
    , rawFormulationActions = completeStrategyActionId :| []
    , rawFormulationKeyResults = completeStrategyKeyResultId :| []
    , rawFormulationFitRationale = "actions substantiate intent" :| []
    }

completeEthosId, completeMissionId, completeVisionId, completeStrategyId ::
     RawNodeId
completeEthosId = RawNodeId "complete-ethos"

completeMissionId = RawNodeId "complete-mission"

completeVisionId = RawNodeId "complete-vision"

completeStrategyId = RawNodeId "complete-strategy"

completeNeedId, completeInterventionId, completeMeasureId, completeSituationId ::
     RawNodeId
completeNeedId = RawNodeId "complete-need"

completeInterventionId = RawNodeId "complete-intervention"

completeMeasureId = RawNodeId "complete-measure"

completeSituationId = RawNodeId "complete-situation"

completeEthosPrincipleId, completeMissionDriverId, completeVisionObjectiveId ::
     RawNodeId
completeEthosPrincipleId = RawNodeId "complete-ethos-principle"

completeMissionDriverId = RawNodeId "complete-mission-driver"

completeVisionObjectiveId = RawNodeId "complete-vision-objective"

completeStrategyDriverId, completeStrategyObjectiveId :: RawNodeId
completeStrategyDriverId = RawNodeId "complete-strategy-driver"

completeStrategyObjectiveId = RawNodeId "complete-strategy-objective"

completeStrategyPrincipleId, completeStrategyKeyResultId, completeStrategyActionId ::
     RawNodeId
completeStrategyPrincipleId = RawNodeId "complete-strategy-principle"

completeStrategyKeyResultId = RawNodeId "complete-strategy-key-result"

completeStrategyActionId = RawNodeId "complete-strategy-action"

completeNeedDriverId, completeNeedObjectiveId, completeInterventionActionId ::
     RawNodeId
completeNeedDriverId = RawNodeId "complete-need-driver"

completeNeedObjectiveId = RawNodeId "complete-need-objective"

completeInterventionActionId = RawNodeId "complete-intervention-action"

completeInterventionKeyResultId, completeMeasureKpiId, completeMeasureDimensionId ::
     RawNodeId
completeInterventionKeyResultId = RawNodeId "complete-intervention-key-result"

completeMeasureKpiId = RawNodeId "complete-measure-kpi"

completeMeasureDimensionId = RawNodeId "complete-measure-dimension"

completeSituationAnchorId :: RawNodeId
completeSituationAnchorId = RawNodeId "complete-situation-anchor"

criteriaDate, baselineDate, readinessDate, interventionDate :: UTCTime
criteriaDate = timestamp 2025 12 1

baselineDate = timestamp 2026 1 1

readinessDate = timestamp 2026 1 15

interventionDate = timestamp 2026 2 1

targetDate, followUpDate, assessmentDate :: UTCTime
targetDate = timestamp 2026 6 30

followUpDate = timestamp 2026 6 1

assessmentDate = timestamp 2026 7 1

timestamp :: Integer -> Int -> Int -> UTCTime
timestamp year month day =
  UTCTime (fromGregorian year month day) (secondsToDiffTime 0)

alternateAdapter :: Adapter
alternateAdapter =
  Adapter
    testDescriptor
    (\_ -> DecodePassed testNativeBinding ())
    (\AlternateDefect -> testSpec "o2i.test.alt.decode")
    (\_ _ -> ViewPassed testResolvedView ())
    (\AlternateDefect -> testSpec "o2i.test.alt.view")
    O2IProfileContract
      { projectProfileSnapshot =
          \snapshot ->
            ProfileProjection
              { projectedRoot =
                  RootProjectable
                    (OneO2IProfile "0.2")
                    (resolveProfileVersion
                       (o2iProfileVersionLiteral ('0' :| ".2")))
              , projectedFacts =
                  case locatedValue (snapshotFact snapshot) of
                    AlternateFact -> instantiateFacts completeEthosFacts
              , projectedDefects = []
              }
      , profileDefectSpec = \AlternateDefect -> testSpec "o2i.test.alt.profile"
      }
    (\_ _ -> profileSnapshot (Located testLocation AlternateFact))

data AdversarialMode
  = AdversarialDecode
  | AdversarialView
  | AdversarialProfile

data AdversarialDefect =
  AdversarialDefect

adversarialAdapter :: AdversarialMode -> Adapter
adversarialAdapter mode =
  Adapter
    (adapterDescriptor ('x' :| "") ('x' :| "") ('x' :| ""))
    decode
    adversarialSpec
    resolveView
    adversarialSpec
    contract
    (\_ _ -> profileSnapshot (Located testLocation TestProfileFact))
  where
    decode _ =
      case mode of
        AdversarialDecode ->
          DecodeUnavailable
            (DecodeUnavailableObservation EncodingNotObserved)
            (Located testLocation AdversarialDefect :| [])
        AdversarialView -> DecodePassed testNativeBinding ()
        AdversarialProfile -> DecodePassed testNativeBinding ()
    resolveView _ _ =
      case mode of
        AdversarialDecode ->
          ViewFailed NoViewMatch (Located testLocation AdversarialDefect :| [])
        AdversarialView ->
          ViewFailed NoViewMatch (Located testLocation AdversarialDefect :| [])
        AdversarialProfile -> ViewPassed testResolvedView ()
    contract =
      O2IProfileContract
        { projectProfileSnapshot =
            \_ ->
              ProfileProjection
                { projectedRoot =
                    RootUnprojectable
                      NoO2IProfile
                      (Located testLocation AdversarialDefect :| [])
                , projectedFacts = []
                , projectedDefects = []
                }
        , profileDefectSpec = adversarialSpec
        }

adversarialSpec :: AdversarialDefect -> DiagnosticSpec
adversarialSpec AdversarialDefect =
  diagnosticSpec
    (o2iDiagnosticCode "")
    WarningSeverity
    ProcessFailure
    ""
    [DiagnosticSubject "" ""]
    (Map.singleton "attemptedCode" (DiagnosticText "not-o2i"))

diagnosticAdapter :: SourceLocation -> DiagnosticSpec -> Adapter
diagnosticAdapter location specification =
  Adapter
    testDescriptor
    (\_ ->
       DecodeUnavailable
         (DecodeUnavailableObservation EncodingNotObserved)
         (Located location specification :| []))
    id
    (\_ _ -> ViewFailed NoViewMatch (Located location TestViewDefect :| []))
    testViewSpec
    O2IProfileContract
      { projectProfileSnapshot =
          \_ ->
            ProfileProjection
              { projectedRoot =
                  RootUnprojectable
                    NoO2IProfile
                    (Located location TestRootProfileDefect :| [])
              , projectedFacts = []
              , projectedDefects = []
              }
      , profileDefectSpec = testProfileSpec
      }
    (\_ _ -> profileSnapshot (Located location TestProfileFact))

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
        {projectProfileSnapshot = project, profileDefectSpec = testProfileSpec}
    project _ =
      ProfileProjection
        { projectedRoot =
            case rootMode of
              RootSucceeds ->
                RootProjectable
                  (OneO2IProfile "0.2")
                  (resolveProfileVersion
                     (o2iProfileVersionLiteral ('0' :| ".2")))
              RootFails ->
                RootUnprojectable
                  NoO2IProfile
                  (Located testLocation TestRootProfileDefect :| [])
        , projectedFacts = instantiateFacts templates
        , projectedDefects = deferred
        }
    observe _ _ = profileSnapshot (Located testLocation TestProfileFact)

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

completeEthosFacts :: [FactTemplate]
completeEthosFacts =
  [ OccurrenceTemplate ethosPresentation
  , NodeTemplate ethosOccurrence (RawContextNode (RawNodeId "ethos") Ethos)
  , SeedTemplate ethosPresentation ethosOccurrence
  , NodeTemplate
      principleOccurrence
      (RawPrimitiveNode (RawNodeId "principle") (RawNodeId "ethos") Principle)
  , DependencyTemplate
      ethosOccurrence
      principleOccurrence
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

ethosPresentation :: OccurrenceId
ethosPresentation = OccurrenceId "presentation-ethos"

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
  adapterDescriptor ('t' :| "est") ('T' :| "est adapter") ('1' :| "")

testNativeBinding :: ResolvedNativeBinding
testNativeBinding =
  ResolvedNativeBinding
    { nativeRootQName = testRootQName
    , nativeVersion = nativeVersionLiteral ('5' :| ".0.0")
    }

testRootQName :: ExpandedQName
testRootQName = expandedQName (Just "urn:test") 'm' "odel"

testLocation :: SourceLocation
testLocation =
  SourceLocation
    { locationSource = sourceDocumentIdentity testSource
    , locationPath = firstPathStep testRootQName :| []
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
testDecodeSpec TestDecodeDefect = testSpec "o2i.test.decode"

testViewSpec :: TestViewDefect -> DiagnosticSpec
testViewSpec TestViewDefect = testSpec "o2i.test.view"

testProfileSpec :: TestProfileDefect -> DiagnosticSpec
testProfileSpec defect =
  case defect of
    TestRootProfileDefect -> testSpec "o2i.test.profile.root"
    TestReachedProfileDefect -> testSpec "o2i.test.profile.reached"

testSpec :: Text -> DiagnosticSpec
testSpec code =
  diagnosticSpec
    (o2iDiagnosticCode (maybe code id (Text.stripPrefix "o2i." code)))
    ErrorSeverity
    ModelFinding
    "Test defect."
    []
    Map.empty

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
