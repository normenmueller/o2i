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
import Data.List (nub, sort)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import qualified Data.Vector as Vector
import Numeric.Natural (Natural)
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
  | TestInformationalProfileFinding
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

data DiagnosticContractPoint
  = ContractDecode
  | ContractView
  | ContractProfile
  | ContractScope
  deriving (Eq, Show)

data ContractDefect = ContractDefect
  { contractDefectCode :: Text
  , contractDefectMessage :: Text
  } deriving (Eq, Show)

data FactTemplate
  = OccurrenceTemplate OccurrenceId
  | NodeTemplate OccurrenceId RawNode
  | NodeClaimTemplate OccurrenceId (Claim RawNode)
  | EdgeTemplate OccurrenceId RawEdge
  | EdgeClaimTemplate OccurrenceId (Claim RawEdge)
  | CollectiveTemplate
      OccurrenceId
      (Claim RawCollectiveStrategyRealization)
      [OccurrenceId]
      OccurrenceId
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
    , testCase
        "adapter positions bind only to the inspected source"
        adapterPositionSourceBindingTest
    , testCase
        "OccurrenceId length framing rejects namespace and path collisions"
        occurrenceIdentityCollisionTest
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
        "diagnostic sets are canonical across Decode, View, Profile, and Scope"
        diagnosticSetCanonicalizationTest
    , testCase
        "effect-trace identity rejects constituent collisions"
        traceIdentityCollisionTest
    , testCase "decode result is total" decodeAttemptTest
    , testCase "View resolution failure is total" viewAttemptTest
    , testCase "root profile failure stops before closure" rootProfileTest
    , testCase "reached profile defects fail Profile" reachedDefectTest
    , testCase "unreached profile defects are excluded" unreachedDefectTest
    , testCase
        "reached informational Profile findings survive successful closure"
        informationalProfileFindingTest
    , testCase "closure retains repeated presentations" repeatedPresentationTest
    , testCase
        "closure includes core-derived macro premise relations"
        macroPremiseClosureTest
    , testCase
        "closed-scope provenance is complete and canonical"
        closedScopeProvenanceTest
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
        "candidate Strategy content is warned and excluded"
        candidateStrategyInputTest
    , testCase
        "explicit graph Candidates survive import and remain excluded"
        candidateGraphClaimsInspectionTest
    , testCase
        "missing asserted macro evidence fails Semantics with provenance"
        missingMacroEvidenceInspectionTest
    , testCase
        "macro-evidence diagnostics are invariant under imported order"
        macroEvidenceDiagnosticOrderTest
    , testCase
        "valid asserted collective claim is retained by Semantics"
        validCollectiveInspectionTest
    , testCase
        "collective Claim closure includes persisted contribution evidence"
        collectiveContributionClosureTest
    , testCase
        "missing persisted collective contribution evidence fails Semantics"
        missingCollectiveContributionTest
    , testCase
        "unrelated evidence and unselected collective Claims remain isolated"
        collectiveContributionIsolationTest
    , testCase
        "collective contribution closure has linear occurrence cardinality"
        collectiveContributionScaleContractTest
    , testCase
        "collective Candidate is warned, excluded, and keeps Draft maturity"
        candidateCollectiveInspectionTest
    , testCase
        "collective Candidate semantic issues remain warnings"
        candidateCollectiveIssueInspectionTest
    , testCase
        "Candidate participant issue identifies claim, role, and participant"
        candidateParticipantIssueSpecTest
    , testCase
        "malformed collective Candidate fails Semantics"
        malformedCandidateCollectiveInspectionTest
    , testCase
        "duplicate collective Candidate identities fail Semantics"
        duplicateCandidateCollectiveInspectionTest
    , testCase
        "asserted collective semantic defects fail Semantics"
        assertedCollectiveFailureInspectionTest
    , testCase
        "fatal collective errors retain independent Candidate warnings"
        fatalCollectiveRetainsCandidateInspectionTest
    , testCase
        "Context errors retain blocked collective Candidate warnings"
        contextErrorRetainsBlockedCollectiveCandidateInspectionTest
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

adapterPositionSourceBindingTest :: Assertion
adapterPositionSourceBindingTest = do
  let firstSource = sourceDocument "first.archimate" "first"
      secondSource = sourceDocument "second.archimate" "second"
      adapters =
        [ testAdapter DecodeRejectedMode ViewSucceeds RootSucceeds [] []
        , testAdapter DecodeSucceeds ViewFails RootSucceeds [] []
        , testAdapter DecodeSucceeds ViewSucceeds RootFails [] []
        , completeModelAdapter
        ]
  mapM_ (assertAdapterSourceBinding firstSource) adapters
  mapM_ (assertAdapterSourceBinding secondSource) adapters

assertAdapterSourceBinding :: SourceDocument -> Adapter -> Assertion
assertAdapterSourceBinding document adapter = do
  report <-
    completedReport
      (inspectSourceDocument adapter (ViewById "view-1") noInputs document)
  let identity = sourceDocumentIdentity document
      locations = reportSourceLocations report
  assertBool
    "source-binding fixture produced no locations"
    (not (null locations))
  assertBool
    "adapter position escaped the inspected source identity"
    (all ((== identity) . locationSource) locations)

reportSourceLocations :: InspectionReport -> [SourceLocation]
reportSourceLocations report =
  nativeLocations (reportNativeBinding report)
    ++ viewLocations (reportViewResolution report)
    ++ concatMap
         diagnosticLocations
         (diagnosticsList (reportDiagnostics report))
    ++ maybe
         []
         (map provenanceLocation
            . NonEmpty.toList
            . closedScopeProvenanceOccurrences)
         (reportClosedScopeProvenance report)

nativeLocations :: NativeAdapterBinding -> [SourceLocation]
nativeLocations binding =
  case binding of
    NativeBindingResolved _ -> []
    NativeBindingFailed failure ->
      case failure of
        NativeBindingUnavailable observation _ ->
          encodingLocations (unavailableEncoding observation)
        NativeBindingRejected rejected _ ->
          locatedAt (rejectedRootQName rejected)
            : maybe [] (pure . locatedAt) (rejectedNativeVersion rejected)

encodingLocations :: EncodingObservation SourceLocation -> [SourceLocation]
encodingLocations observation =
  case observation of
    EncodingNotObserved -> []
    EncodingDefaultedToUtf8 -> []
    EncodingDeclared declaration -> [locatedAt declaration]

viewLocations :: ViewResolution -> [SourceLocation]
viewLocations resolution =
  case resolution of
    ViewUnavailable -> []
    ViewResolved resolved -> [resolvedViewLocation (resolvedView resolved)]
    ViewRejected failure ->
      case failedViewObservation failure of
        NoViewMatch -> []
        OneViewMatch candidate -> [viewCandidateLocation candidate]
        MultipleViewMatches candidates ->
          map viewCandidateLocation (atLeastTwoToList candidates)

occurrenceIdentityCollisionTest :: Assertion
occurrenceIdentityCollisionTest = do
  let namespaceLeft =
        occurrenceForPath
          (firstPathStep (expandedQName (Just "urn}reserved") 'n' "ame") :| [])
      namespaceRight =
        occurrenceForPath
          (firstPathStep (expandedQName (Just "urn") 'r' "eserved}name") :| [])
      pathLeft =
        occurrenceForPath
          (firstPathStep (expandedQName Nothing 'a' "[1]/{urn:path}b") :| [])
      pathRight =
        occurrenceForPath
          (firstPathStep (expandedQName Nothing 'a' "")
             :| [firstPathStep (expandedQName (Just "urn:path") 'b' "")])
  namespaceLeft /= namespaceRight @? "namespace delimiters must not collide"
  pathLeft /= pathRight @? "path delimiters must not collide"

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
    , AssertedNodeDependsOnCandidate node other
    , InvalidPrimitiveInterpretation node Mission Objective
    , InvalidStructuringContext node Mission PerformanceDimension
    , UnknownEdgeEndpoint edge other
    , AssertedEdgeDependsOnCandidate edge other
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
    , "o2i.structure.asserted-node-depends-on-candidate"
    , "o2i.structure.interpretation-invalid"
    , "o2i.structure.structuring-context-invalid"
    , "o2i.structure.endpoint-unknown"
    , "o2i.structure.asserted-edge-depends-on-candidate"
    , "o2i.structure.relation-unknown"
    , "o2i.structure.relation-endpoint-kinds-invalid"
    , "o2i.structure.membership-owner-mismatch"
    ]
  assertClosedMapping
    SemanticsStage
    candidatePropositionSpec
    [ CandidateModelNode (RawContextNode node Strategy)
    , CandidateModelEdge edge
    , CandidateStrategyFormulation node
    ]
    [ "o2i.claim.candidate-excluded"
    , "o2i.claim.candidate-excluded"
    , "o2i.claim.candidate-excluded"
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
    SemanticsStage
    modelSemanticErrorSpec
    [ ContextSemanticError (EthosWithoutPrinciple node)
    , MacroEvidenceSemanticError
        (MissingMacroEvidence (RawEdge node relation other))
    , CollectiveSemanticError
        (CollectiveStructuralError EmptyCollectiveRealizationClaimId)
    ]
    [ "o2i.semantics.ethos-principle-missing"
    , "o2i.semantics.macro-evidence-missing"
    , "o2i.semantics.collective.claim-id-empty"
    ]
  assertClosedMapping
    TraceabilityStage
    traceabilityDefectSpec
    [ NoIntervention
    , InterventionWithoutNeed node
    , MissingEffectTrace node other
    ]
    [ "o2i.traceability.intervention-missing"
    , "o2i.traceability.intervention-need-missing"
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
  firstMessage <-
    diagnosticForSpec testLocation (identitySpecWithMessage "first message")
  secondMessage <-
    diagnosticForSpec testLocation (identitySpecWithMessage "second message")
  assertDistinctDiagnosticIds firstMessage secondMessage
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

diagnosticSetCanonicalizationTest :: Assertion
diagnosticSetCanonicalizationTest =
  mapM_
    assertCanonicalAt
    [ContractDecode, ContractView, ContractProfile, ContractScope]
  where
    first = ContractDefect "same" "z-last diagnostic"
    second = ContractDefect "same" "a-first diagnostic"
    assertCanonicalAt point = do
      firstReport <-
        completedReport
          (runAdapter
             (diagnosticContractAdapter point (first :| [second, first])))
      secondReport <-
        completedReport
          (runAdapter
             (diagnosticContractAdapter point (second :| [first, second])))
      renderInspectionReportJSON firstReport
        @?= renderInspectionReportJSON secondReport
      let diagnostics = diagnosticsList (reportDiagnostics firstReport)
          identifiers = map diagnosticId diagnostics
          expectedStage = contractInspectionStage point
      map (diagnosticCodeText . diagnosticCode) diagnostics
        @?= replicate 2 "o2i.test.contract.same"
      map diagnosticMessage diagnostics
        @?= ["a-first diagnostic", "z-last diagnostic"]
      length identifiers @?= 2
      length (nub identifiers) @?= length identifiers
      stageDiagnosticIds expectedStage firstReport @?= identifiers
      nestedDiagnosticIds point firstReport @?= identifiers

contractInspectionStage :: DiagnosticContractPoint -> InspectionStage
contractInspectionStage point =
  case point of
    ContractDecode -> DecodeStage
    ContractView -> ViewScopeStage
    ContractProfile -> ProfileStage
    ContractScope -> ProfileStage

stageDiagnosticIds :: InspectionStage -> InspectionReport -> [DiagnosticId]
stageDiagnosticIds stage report =
  concat
    [ reportedDiagnosticIds stageReport
    | stageReport <- stageReportsList (reportStageReports report)
    , reportedStage stageReport == stage
    ]

nestedDiagnosticIds ::
     DiagnosticContractPoint -> InspectionReport -> [DiagnosticId]
nestedDiagnosticIds point report =
  case point of
    ContractDecode ->
      case reportNativeBinding report of
        NativeBindingFailed (NativeBindingUnavailable _ identifiers) ->
          NonEmpty.toList identifiers
        _ -> []
    ContractView ->
      case reportViewResolution report of
        ViewRejected failure ->
          NonEmpty.toList (failedViewDiagnosticIds failure)
        _ -> []
    ContractProfile ->
      case reportProfileResolution report of
        ProfileRejectedResolution failure ->
          NonEmpty.toList (rejectedProfileDiagnosticIds failure)
        _ -> []
    ContractScope ->
      case reportScopeResolution report of
        ScopeRejectedResolution failure ->
          NonEmpty.toList (rejectedScopeDiagnosticIds failure)
        _ -> []

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
  identitySpecFor "Identity test defect." subjects dataFields

identitySpecWithMessage :: Text -> DiagnosticSpec
identitySpecWithMessage message = identitySpecFor message [] Map.empty

identitySpecFor ::
     Text
  -> [DiagnosticSubject]
  -> Map.Map Text DiagnosticAtom
  -> DiagnosticSpec
identitySpecFor message subjects dataFields =
  diagnosticSpec
    (o2iDiagnosticCode "identity")
    ErrorSeverity
    ModelFinding
    message
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
  locationForPath
    (firstPathStep (expandedQName (Just "urn}reserved") 'n' "ame") :| [])

reservedQNameLocationRight =
  locationForPath
    (firstPathStep (expandedQName (Just "urn") 'r' "eserved}name") :| [])

singlePathCollisionLocation, multiPathCollisionLocation :: SourceLocation
singlePathCollisionLocation =
  locationForPath
    (firstPathStep (expandedQName Nothing 'a' "[1]/{urn:path}b") :| [])

multiPathCollisionLocation =
  locationForPath
    (firstPathStep (expandedQName Nothing 'a' "")
       :| [firstPathStep (expandedQName (Just "urn:path") 'b' "")])

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
            [missionOccurrence]))
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
            [testOccurrence "outside"]))
  assertBool
    "unreached adapter defect must not be reported"
    ("o2i.test.profile.reached" `notElem` diagnosticCodes report)
  assertResolvedScopeSummary 1 3 report

informationalProfileFindingTest :: Assertion
informationalProfileFindingTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapterWithDefects
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            missionFacts
            [(missionOccurrence, TestInformationalProfileFinding)]))
  assertResolvedScopeSummary 1 3 report
  assertBool
    "reached informational finding must be retained"
    ("o2i.test.profile.information" `elem` diagnosticCodes report)
  case [ diagnostic
       | diagnostic <- diagnosticsList (reportDiagnostics report)
       , diagnosticCodeText (diagnosticCode diagnostic)
           == "o2i.test.profile.information"
       ] of
    [diagnostic] -> diagnosticSeverity diagnostic @?= InfoSeverity
    diagnostics ->
      assertFailure
        ("expected one informational Profile finding: " <> show diagnostics)
  map reportedState (take 4 (stageReportsList (reportStageReports report)))
    @?= [StagePassed, StagePassed, StagePassed, StagePassed]

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
  assertResolvedScopeSummary 2 4 report

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
  assertResolvedScopeSummary 1 7 report

closedScopeProvenanceTest :: Assertion
closedScopeProvenanceTest = do
  report <-
    completedReport
      (runAdapter
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            (macroPremiseFacts
               ++ [ DependencyTemplate
                      macroEdgeOccurrence
                      ethosOccurrence
                      PersistedContextOwnership
                  , DependencyTemplate
                      macroEdgeOccurrence
                      ethosOccurrence
                      PersistedRelationshipEndpoint
                  ])
            []))
  provenance <-
    case reportClosedScopeProvenance report of
      Nothing -> assertFailure "resolved scope omitted mandatory provenance"
      Just artifact -> pure artifact
  let occurrences =
        NonEmpty.toList (closedScopeProvenanceOccurrences provenance)
      actualIds = map provenanceOccurrenceId occurrences
      expectedReasons =
        [ (macroPresentation, [DirectPresentation])
        , (macroEdgeOccurrence, [DirectPresentation])
        , (ethosOccurrence, [RelationshipEndpoint, ContextOwnership])
        , (missionOccurrence, [RelationshipEndpoint])
        , (premiseEdgeOccurrence, [MacroPremise])
        , (principleOccurrence, [RelationshipEndpoint])
        , (driverOccurrence, [RelationshipEndpoint])
        ]
  actualIds @?= sort (map fst expectedReasons)
  map
    (\occurrence ->
       ( provenanceOccurrenceId occurrence
       , NonEmpty.toList (provenanceReasons occurrence)))
    occurrences
    @?= sort expectedReasons
  map provenanceLocation occurrences @?= replicate 7 testLocation

assertResolvedScopeSummary ::
     Natural -> Natural -> InspectionReport -> Assertion
assertResolvedScopeSummary direct closed report =
  case reportScopeResolution report of
    ScopeResolved scope ->
      resolvedScopeSummary scope
        @?= ClosedScopeSummary
              {directOccurrenceCount = direct, closedOccurrenceCount = closed}
    resolution -> assertFailure ("unexpected scope state: " <> show resolution)

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
                 (sourcedFromDocument testSource (StrategyFormulationBundle []))
           })
  reportScopeResolution supplied @?= reportScopeResolution unavailable
  reportResult supplied @?= InspectionFailed
  diagnosticCodes supplied @?= ["o2i.semantics.formulation-missing"]

candidateStrategyInputTest :: Assertion
candidateStrategyInputTest = do
  report <-
    completedReport
      (runAdapterWithInputs
         completeModelAdapter
         noInputs
           { strategyInput =
               Supplied
                 (sourcedFromDocument
                    strategySourceDocument
                    (StrategyFormulationBundle
                       [candidateClaim completeStrategyFormulation]))
           })
  reportResult report @?= InspectionFailed
  let diagnostics = diagnosticsList (reportDiagnostics report)
  map (diagnosticCodeText . diagnosticCode) diagnostics
    @?= ["o2i.claim.candidate-excluded", "o2i.semantics.formulation-missing"]
  map diagnosticSeverity diagnostics @?= [WarningSeverity, ErrorSeverity]
  map reportedState (take 6 (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StagePassed
        , StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure SemanticsStage)
        ]

candidateGraphClaimsInspectionTest :: Assertion
candidateGraphClaimsInspectionTest = do
  let candidateNodeId = RawNodeId "candidate-strategy"
      candidateNodeOccurrence = testOccurrence "candidate-node"
      candidateEdgeOccurrence = testOccurrence "candidate-edge"
      facts =
        completeModelFacts
          ++ [ NodeClaimTemplate
                 candidateNodeOccurrence
                 (candidateClaim (RawContextNode candidateNodeId Strategy))
             , SeedTemplate completePresentation candidateNodeOccurrence
             , EdgeClaimTemplate
                 candidateEdgeOccurrence
                 (candidateClaim
                    (completeEdge
                       completeStrategyId
                       directsStrategy
                       completeStrategyId))
             , SeedTemplate completePresentation candidateEdgeOccurrence
             ]
      inputs =
        noInputs
          { strategyInput =
              Supplied
                (sourcedFromDocument
                   strategySourceDocument
                   (StrategyFormulationBundle
                      [assertedClaim completeStrategyFormulation]))
          }
  report <-
    completedReport
      (runAdapterWithInputs
         (testAdapter DecodeSucceeds ViewSucceeds RootSucceeds facts [])
         inputs)
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageUnavailable
  diagnosticCodes report
    @?= ["o2i.claim.candidate-excluded", "o2i.claim.candidate-excluded"]

missingMacroEvidenceInspectionTest :: Assertion
missingMacroEvidenceInspectionTest = do
  report <-
    completedReport
      (runAdapterWithInputs
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            (graphFacts graphWithoutFrameEvidence)
            [])
         inputs)
  reportResult report @?= InspectionFailed
  map reportedState (take 6 (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StagePassed
        , StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure SemanticsStage)
        ]
  case diagnosticsList (reportDiagnostics report) of
    [diagnostic] -> do
      diagnosticCodeText (diagnosticCode diagnostic)
        @?= "o2i.semantics.macro-evidence-missing"
      diagnosticStage diagnostic @?= SemanticsStage
      diagnosticSubjects diagnostic
        @?= [ DiagnosticSubject
                "edge"
                (rawEdgeSubjectIdentifier singleFrameEdge)
            ]
      diagnosticLocations diagnostic @?= [testLocation]
      map supplementalTuple (diagnosticSupplementalSources diagnostic)
        @?= [ ( StrategySupplement
              , sourceDocumentIdentity strategySourceDocument)
            ]
    diagnostics ->
      assertFailure
        ("expected one macro-evidence diagnostic, got "
           <> show (length diagnostics))
  where
    singleFrameEdge =
      completeEdge completeStrategyId framesMeasure completeMeasureId
    singleFramePremises =
      [ completeEdge
          completeStrategyDriverId
          indicatesMeasurePerformanceDimension
          completeMeasureDimensionId
      , completeEdge
          completeStrategyKeyResultId
          determinesMeasurePerformanceDimension
          completeMeasureDimensionId
      ]
    graphWithoutFrameEvidence =
      completeRawGraph
        { rawEdges =
            filter (`notElem` singleFramePremises) (rawEdges completeRawGraph)
        }
    inputs =
      noInputs
        { strategyInput =
            Supplied
              (sourcedFromDocument
                 strategySourceDocument
                 (StrategyFormulationBundle
                    [assertedClaim completeStrategyFormulation]))
        }

macroEvidenceDiagnosticOrderTest :: Assertion
macroEvidenceDiagnosticOrderTest = do
  baselineReport <-
    macroEvidenceReport
      graphWithoutMacroEvidence
      [assertedClaim completeStrategyFormulation]
  reordered <-
    macroEvidenceReport
      RawGraph
        { rawNodes = reverse (rawNodes graphWithoutMacroEvidence)
        , rawEdges = reverse (rawEdges graphWithoutMacroEvidence)
        }
      (reverse [assertedClaim completeStrategyFormulation])
  map diagnosticObservation (diagnosticsList (reportDiagnostics baselineReport))
    @?= expected
  map diagnosticObservation (diagnosticsList (reportDiagnostics reordered))
    @?= expected
  where
    expected =
      [ ( "o2i.semantics.macro-evidence-missing"
        , SemanticsStage
        , [DiagnosticSubject "edge" (rawEdgeSubjectIdentifier conclusion)]
        , [testLocation]
        , [(StrategySupplement, sourceDocumentIdentity strategySourceDocument)])
      | conclusion <- sort [canonicalFrameEdge, qualificationEdge]
      ]
    diagnosticObservation diagnostic =
      ( diagnosticCodeText (diagnosticCode diagnostic)
      , diagnosticStage diagnostic
      , diagnosticSubjects diagnostic
      , diagnosticLocations diagnostic
      , map supplementalTuple (diagnosticSupplementalSources diagnostic))

macroEvidenceReport ::
     RawGraph -> [Claim RawStrategyFormulation] -> IO InspectionReport
macroEvidenceReport graph formulations =
  completedReport
    (runAdapterWithInputs
       (testAdapter
          DecodeSucceeds
          ViewSucceeds
          RootSucceeds
          (graphFacts graph)
          [])
       noInputs
         { strategyInput =
             Supplied
               (sourcedFromDocument
                  strategySourceDocument
                  (StrategyFormulationBundle formulations))
         })

graphWithoutMacroEvidence :: RawGraph
graphWithoutMacroEvidence =
  completeRawGraph
    { rawEdges =
        filter
          (`notElem` (framePremises ++ [qualificationPremise]))
          (rawEdges completeRawGraph)
    }

canonicalFrameEdge, qualificationEdge :: RawEdge
canonicalFrameEdge =
  completeEdge completeStrategyId framesMeasure completeMeasureId

qualificationEdge = completeEdge completeStrategyId qualifiesNeed completeNeedId

framePremises :: [RawEdge]
framePremises =
  [ completeEdge
      completeStrategyDriverId
      indicatesMeasurePerformanceDimension
      completeMeasureDimensionId
  , completeEdge
      completeStrategyKeyResultId
      determinesMeasurePerformanceDimension
      completeMeasureDimensionId
  ]

qualificationPremise :: RawEdge
qualificationPremise =
  completeEdge
    completeStrategyKeyResultId
    translatesStrategyKeyResultToNeedObjective
    completeNeedObjectiveId

validCollectiveInspectionTest :: Assertion
validCollectiveInspectionTest = do
  report <- completedReport (runCollectiveInspection assertedCollectiveClaim)
  schema <- inspectionSchema
  assertBool
    "collective report failed Draft 2020-12 validation"
    (validateJSONSchema schema (renderedReportValue report))
  reportMaturity report @?= Just SemanticallyValid
  reportMaturityText report @?= Just "semantically-valid"
  case Aeson.decode (renderInspectionReportJSON report) of
    Just (Aeson.Object objectValue) ->
      KeyMap.lookup "maturity" objectValue
        @?= Just (Aeson.String "semantically-valid")
    _ -> assertFailure "collective report did not encode one JSON object"
  semanticsState report @?= StagePassed
  case reportSemanticAssessment report of
    Nothing -> assertFailure "missing complete semantic assessment"
    Just assessment ->
      map
        collectiveRealizationId
        (semanticCollectiveStrategyRealizations assessment)
        @?= [collectiveInspectionClaimId]
  assertBool
    "collective participant closure reason was not retained"
    (CollectiveRealizationParticipant `elem` collectiveReasons report)
  assertBool
    "collective segment closure reason was not retained"
    (CollectiveRealizationSegment `elem` collectiveReasons report)

collectiveContributionClosureTest :: Assertion
collectiveContributionClosureTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveScopeFacts collectiveInspectionGraph assertedCollectiveClaim)
         suppliedCollectiveFit)
  semanticsState report @?= StagePassed
  reasonsForOccurrence
    report
    (collectiveEdgeOccurrence
       collectiveInspectionGraph
       (completeEdge
          collectiveContributorOneId
          contributesToStrategy
          completeStrategyId))
    @?= [CollectiveRealizationContribution]
  reasonsForOccurrence
    report
    (collectiveEdgeOccurrence
       collectiveInspectionGraph
       (completeEdge
          (contributorId "one" "key-result")
          contributesStrategyKeyResultToKeyResult
          completeStrategyKeyResultId))
    @?= [MacroPremise]
  reasonsForOccurrence
    report
    (collectiveEdgeOccurrence
       collectiveInspectionGraph
       (completeEdge
          collectiveContributorTwoId
          contributesToStrategy
          completeStrategyId))
    @?= [CollectiveRealizationContribution]
  reasonsForOccurrence
    report
    (collectiveEdgeOccurrence
       collectiveInspectionGraph
       (completeEdge
          (contributorId "two" "action")
          contributesStrategyActionToAction
          completeStrategyActionId))
    @?= [MacroPremise]

missingCollectiveContributionTest :: Assertion
missingCollectiveContributionTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveScopeFacts graph assertedCollectiveClaim)
         suppliedCollectiveFit)
  semanticsState report @?= StageFailed
  assertBool
    "missing persisted macro evidence must remain a semantic failure"
    ("o2i.semantics.collective.contribution-missing"
       `elem` diagnosticCodes report)
  where
    graph =
      collectiveInspectionGraph
        { rawEdges =
            filter
              (/= completeEdge
                    collectiveContributorTwoId
                    contributesToStrategy
                    completeStrategyId)
              (rawEdges collectiveInspectionGraph)
        }

collectiveContributionIsolationTest :: Assertion
collectiveContributionIsolationTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveScopeFacts graph assertedCollectiveClaim
            ++ [ CollectiveTemplate
                   unselectedCollectiveClaimOccurrence
                   unselectedCollectiveClaim
                   [ collectiveNodeOccurrence collectiveContributorOneId
                   , collectiveNodeOccurrence collectiveContributorTwoId
                   ]
                   (collectiveNodeOccurrence completeStrategyId)
               ])
         suppliedCollectiveFit)
  semanticsState report @?= StagePassed
  assertBool
    "an unselected collective Claim entered the closed scope"
    (null (reasonsForOccurrence report unselectedCollectiveClaimOccurrence))
  assertBool
    "an unrelated contribution edge entered the closed scope"
    (null
       (reasonsForOccurrence
          report
          (collectiveEdgeOccurrence graph unrelatedContribution)))
  assertBool
    "unrelated Primitive evidence entered the closed scope"
    (null
       (reasonsForOccurrence
          report
          (collectiveEdgeOccurrence graph unrelatedPremise)))
  where
    graph =
      RawGraph
        (rawNodes collectiveInspectionGraph ++ unrelatedNodes)
        (rawEdges collectiveInspectionGraph
           ++ [unrelatedContribution, unrelatedPremise])
    unrelatedNodes =
      [ RawContextNode unrelatedStrategyId Strategy
      , RawPrimitiveNode unrelatedKeyResultId unrelatedStrategyId KeyResult
      ]
    unrelatedContribution =
      completeEdge unrelatedStrategyId contributesToStrategy completeStrategyId
    unrelatedPremise =
      completeEdge
        unrelatedKeyResultId
        contributesStrategyKeyResultToKeyResult
        completeStrategyKeyResultId

collectiveContributionScaleContractTest :: Assertion
collectiveContributionScaleContractTest = do
  baselineReport <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveScopeFacts collectiveInspectionGraph assertedCollectiveClaim)
         suppliedCollectiveFit)
  scaled <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveScopeFacts collectiveInspectionGraph assertedCollectiveClaim
            ++ concatMap additionalClaim [2 .. claimCount])
         suppliedCollectiveFit)
  semanticsState scaled @?= StagePassed
  case reportSemanticAssessment scaled of
    Nothing -> assertFailure "missing scaled semantic assessment"
    Just assessment ->
      length (semanticCollectiveStrategyRealizations assessment) @?= claimCount
  case (reportScopeResolution baselineReport, reportScopeResolution scaled) of
    (ScopeResolved baselineScope, ScopeResolved scaledScope) -> do
      let baselineSummary = resolvedScopeSummary baselineScope
          scaledSummary = resolvedScopeSummary scaledScope
          additions = fromIntegral (claimCount - 1)
      directOccurrenceCount scaledSummary
        @?= directOccurrenceCount baselineSummary
        + additions
      closedOccurrenceCount scaledSummary
        @?= closedOccurrenceCount baselineSummary
        + 2 * additions
    _ -> assertFailure "expected baseline and scaled closed scopes"
  reasonsForOccurrence
    scaled
    (collectiveEdgeOccurrence
       collectiveInspectionGraph
       (completeEdge
          collectiveContributorOneId
          contributesToStrategy
          completeStrategyId))
    @?= [CollectiveRealizationContribution]
  where
    claimCount = 64
    additionalClaim number =
      [ CollectiveTemplate
          claimOccurrence
          (assertedClaim
             collectiveInspectionProposition
               { rawRealizationId =
                   ClaimId ("inspection-collective-" <> Text.pack (show number))
               })
          [ collectiveNodeOccurrence collectiveContributorOneId
          , collectiveNodeOccurrence collectiveContributorTwoId
          ]
          (collectiveNodeOccurrence completeStrategyId)
      , OccurrenceTemplate presentationOccurrence
      , SeedTemplate presentationOccurrence claimOccurrence
      ]
      where
        claimOccurrence =
          testOccurrence ("collective-claim-" <> Text.pack (show number))
        presentationOccurrence =
          testOccurrence ("collective-presentation-" <> Text.pack (show number))

collectiveReasons :: InspectionReport -> [InclusionReason]
collectiveReasons =
  concatMap (NonEmpty.toList . provenanceReasons)
    . maybe [] (NonEmpty.toList . closedScopeProvenanceOccurrences)
    . reportClosedScopeProvenance

reasonsForOccurrence :: InspectionReport -> OccurrenceId -> [InclusionReason]
reasonsForOccurrence report occurrence =
  [ reason
  | provenance <-
      maybe
        []
        (NonEmpty.toList . closedScopeProvenanceOccurrences)
        (reportClosedScopeProvenance report)
  , provenanceOccurrenceId provenance == occurrence
  , reason <- NonEmpty.toList (provenanceReasons provenance)
  ]

candidateCollectiveInspectionTest :: Assertion
candidateCollectiveInspectionTest = do
  report <-
    completedReport (runCollectiveInspection candidateCollectiveInspectionClaim)
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageUnavailable
  diagnosticCodes report @?= ["o2i.claim.collective-candidate-excluded"]
  case reportSemanticAssessment report of
    Nothing -> assertFailure "missing Candidate semantic assessment"
    Just assessment ->
      length (semanticCollectiveStrategyRealizations assessment) @?= 0

candidateCollectiveIssueInspectionTest :: Assertion
candidateCollectiveIssueInspectionTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFit candidateCollectiveInspectionClaim Absent)
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageUnavailable
  diagnosticCodes report
    @?= [ "o2i.claim.collective-candidate-excluded"
        , "o2i.semantics.collective.fit-evidence-not-found"
        ]
  map diagnosticSeverity (diagnosticsList (reportDiagnostics report))
    @?= [WarningSeverity, WarningSeverity]

candidateParticipantIssueSpecTest :: Assertion
candidateParticipantIssueSpecTest = do
  let specification =
        candidateCollectiveRealizationIssueSpec
          collectiveInspectionClaimId
          (CandidateParticipantSemanticsUnavailable
             CollectiveContributor
             collectiveContributorOneId)
  diagnosticCodeText (specCode specification)
    @?= "o2i.semantics.collective.candidate-participant-semantics-unavailable"
  specSeverity specification @?= WarningSeverity
  specMessage specification
    @?= "A Candidate Strategy participant is unavailable to validated collective semantics."
  specSubjects specification
    @?= [ DiagnosticSubject
            "collective-claim"
            (claimIdText collectiveInspectionClaimId)
        , DiagnosticSubject "participant-role" "contributor"
        , DiagnosticSubject "node" (rawNodeIdText collectiveContributorOneId)
        ]

malformedCandidateCollectiveInspectionTest :: Assertion
malformedCandidateCollectiveInspectionTest = do
  report <-
    completedReport
      (runCollectiveInspection
         (candidateClaim
            (collectiveInspectionProposition
               {rawContributors = [collectiveContributorOneId]})))
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageFailed
  diagnosticCodes report @?= ["o2i.semantics.collective.contributors-too-few"]
  map diagnosticSeverity (diagnosticsList (reportDiagnostics report))
    @?= [ErrorSeverity]

duplicateCandidateCollectiveInspectionTest :: Assertion
duplicateCandidateCollectiveInspectionTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFacts
         (collectiveInspectionFacts candidateCollectiveInspectionClaim
            ++ [ CollectiveTemplate
                   duplicateCollectiveClaimOccurrence
                   candidateCollectiveInspectionClaim
                   [ collectiveNodeOccurrence collectiveContributorOneId
                   , collectiveNodeOccurrence collectiveContributorTwoId
                   ]
                   (collectiveNodeOccurrence completeStrategyId)
               , SeedTemplate
                   completePresentation
                   duplicateCollectiveClaimOccurrence
               ])
         (Supplied
            (sourcedFromDocument
               collectiveFitSourceDocument
               (CollectiveFitEvidenceBundle [collectiveInspectionFit]))))
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageFailed
  diagnosticCodes report
    @?= [ "o2i.claim.collective-candidate-excluded"
        , "o2i.semantics.collective.claim-id-duplicate"
        ]
  map diagnosticSeverity (diagnosticsList (reportDiagnostics report))
    @?= [WarningSeverity, ErrorSeverity]

assertedCollectiveFailureInspectionTest :: Assertion
assertedCollectiveFailureInspectionTest = do
  report <-
    completedReport
      (runCollectiveInspectionWithFit assertedCollectiveClaim Absent)
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageFailed
  diagnosticCodes report @?= ["o2i.semantics.collective.fit-evidence-not-found"]

fatalCollectiveRetainsCandidateInspectionTest :: Assertion
fatalCollectiveRetainsCandidateInspectionTest = do
  let assertedReference = CollectiveFitEvidenceRef "missing-asserted-fit"
      candidateReference = CollectiveFitEvidenceRef "missing-candidate-fit"
      invalidAsserted =
        assertedClaim
          collectiveInspectionProposition
            { rawRealizationId = ClaimId "invalid-asserted"
            , rawCollectiveFitEvidence = assertedReference
            }
      diagnosticCandidate =
        candidateClaim
          collectiveInspectionProposition
            { rawRealizationId = ClaimId "diagnostic-candidate"
            , rawCollectiveFitEvidence = candidateReference
            }
      candidateOccurrence = testOccurrence "independent-candidate"
      facts =
        collectiveInspectionFacts invalidAsserted
          ++ [ CollectiveTemplate
                 candidateOccurrence
                 diagnosticCandidate
                 [ collectiveNodeOccurrence collectiveContributorOneId
                 , collectiveNodeOccurrence collectiveContributorTwoId
                 ]
                 (collectiveNodeOccurrence completeStrategyId)
             , SeedTemplate completePresentation candidateOccurrence
             ]
  report <- completedReport (runCollectiveInspectionWithFacts facts Absent)
  reportMaturity report @?= Just Draft
  semanticsState report @?= StageFailed
  diagnosticCodes report
    @?= [ "o2i.claim.collective-candidate-excluded"
        , "o2i.semantics.collective.fit-evidence-not-found"
        , "o2i.semantics.collective.fit-evidence-not-found"
        ]
  map diagnosticSeverity (diagnosticsList (reportDiagnostics report))
    @?= [WarningSeverity, WarningSeverity, ErrorSeverity]
  case reportSemanticAssessment report of
    Nothing -> assertFailure "missing semantic assessment"
    Just assessment ->
      assertBool
        "fatal collective assessment exposed aggregate witnesses"
        (null (semanticCollectiveStrategyRealizations assessment))

contextErrorRetainsBlockedCollectiveCandidateInspectionTest :: Assertion
contextErrorRetainsBlockedCollectiveCandidateInspectionTest = do
  report <-
    completedReport
      (runAdapterWithInputs
         (testAdapter
            DecodeSucceeds
            ViewSucceeds
            RootSucceeds
            (collectiveInspectionFacts candidateCollectiveInspectionClaim)
            [])
         noInputs
           { strategyInput =
               Supplied
                 (sourcedFromDocument
                    strategySourceDocument
                    (StrategyFormulationBundle []))
           , collectiveFitInput =
               Supplied
                 (sourcedFromDocument
                    collectiveFitSourceDocument
                    (CollectiveFitEvidenceBundle [collectiveInspectionFit]))
           })
  reportResult report @?= InspectionFailed
  semanticsState report @?= StageFailed
  let codes = diagnosticCodes report
  assertBool
    "collective Candidate exclusion warning is absent"
    ("o2i.claim.collective-candidate-excluded" `elem` codes)
  assertBool
    "blocked collective Candidate diagnostic is absent"
    ("o2i.semantics.collective.evaluation-blocked" `elem` codes)
  assertBool
    "fatal Context diagnostic is absent"
    ("o2i.semantics.formulation-missing" `elem` codes)
  case reportSemanticAssessment report of
    Nothing -> assertFailure "missing blocked Candidate semantic assessment"
    Just assessment ->
      length (semanticCollectiveStrategyRealizations assessment) @?= 0

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
        , ( "resolved scope omits mandatory provenance"
          , removeScopeProvenance partialValue)
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
  let firstDocument = sourceDocument "strategy-a.json" "same formulation"
      secondDocument = sourceDocument "strategy-b.json" "same formulation"
      firstIdentity = sourceDocumentIdentity firstDocument
      secondIdentity = sourceDocumentIdentity secondDocument
      supplied document =
        noInputs
          { strategyInput =
              Supplied
                (sourcedFromDocument document (StrategyFormulationBundle []))
          }
  first <-
    completedReport
      (runAdapterWithInputs strategyModelAdapter (supplied firstDocument))
  second <-
    completedReport
      (runAdapterWithInputs strategyModelAdapter (supplied secondDocument))
  sourceSha256 firstIdentity @?= sourceSha256 secondIdentity
  map supplementalTuple (reportSupplementalSources first)
    @?= [(StrategySupplement, firstIdentity)]
  map supplementalTuple (reportSupplementalSources second)
    @?= [(StrategySupplement, secondIdentity)]
  renderInspectionReportJSON first
    /= renderInspectionReportJSON second
         @? "reports must distinguish equal data supplied by different sources"
  map
    (map supplementalTuple . diagnosticSupplementalSources)
    (diagnosticsList (reportDiagnostics first))
    @?= [[(StrategySupplement, firstIdentity)]]
  map
    (map supplementalTuple . diagnosticSupplementalSources)
    (diagnosticsList (reportDiagnostics second))
    @?= [[(StrategySupplement, secondIdentity)]]

supplementalTuple ::
     SupplementalSource -> (SupplementalInputKind, SourceIdentity)
supplementalTuple supplemental =
  (supplementalInputKind supplemental, supplementalSourceIdentity supplemental)

allReportVariants :: IO [(String, InspectionReport)]
allReportVariants = do
  inputs <- validInspectionInputs
  let strategyOnly = noInputs {strategyInput = strategyInput inputs}
      readinessEmpty =
        strategyOnly
          { readinessInput =
              Supplied
                (sourcedFromDocument
                   readinessSourceDocument
                   (ReadinessBundle readinessDate [] [] []))
          }
      evidenceUnavailable = inputs {evidenceInput = Absent}
      evidenceEmpty =
        inputs
          { evidenceInput =
              Supplied
                (sourcedFromDocument
                   evidenceSourceDocument
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
                      (sourcedFromDocument
                         strategySourceDocument
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

removeScopeProvenance :: Aeson.Value -> Aeson.Value
removeScopeProvenance document =
  case document of
    Aeson.Object object ->
      case KeyMap.lookup "scope" object of
        Just (Aeson.Object scope) ->
          Aeson.Object
            (KeyMap.insert
               "scope"
               (Aeson.Object (KeyMap.delete "provenance" scope))
               object)
        _ -> document
    _ -> document

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
            (sourcedFromDocument
               strategySourceDocument
               (StrategyFormulationBundle
                  [assertedClaim completeStrategyFormulation]))
      , collectiveFitInput = Absent
      , readinessInput =
          Supplied
            (sourcedFromDocument
               readinessSourceDocument
               ReadinessBundle
                 { readinessCheckedAtInput = readinessDate
                 , kpiDefinitionsInput = [definition]
                 , plannedStartsInput = [plannedStart]
                 , evidencePlansInput = [evidencePlan]
                 })
      , evidenceInput =
          Supplied
            (sourcedFromDocument
               evidenceSourceDocument
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
    StructureAccepted assessment ->
      case modelAssessmentStatus
             (assessModelSemantics
                assessment
                ModelSemanticsInput
                  { modelStrategyClaims =
                      [assertedClaim completeStrategyFormulation]
                  , modelCollectiveClaims = []
                  , modelCollectiveFitEvidence = []
                  }) of
        SemanticsRejected defects ->
          assertFailure ("complete Semantics fixture failed: " <> show defects)
        SemanticsPending candidates ->
          assertFailure
            ("complete Semantics fixture remained pending: " <> show candidates)
        SemanticsAccepted semantic ->
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

sourceDocument :: Text -> ByteString.ByteString -> SourceDocument
sourceDocument label = sourceDocumentFromBytes label FileSource

strategySourceDocument, collectiveFitSourceDocument, readinessSourceDocument, evidenceSourceDocument ::
     SourceDocument
strategySourceDocument = sourceDocument "strategy.json" "strategy-input"

collectiveFitSourceDocument = sourceDocument "collective-fit.json" "fit-input"

readinessSourceDocument = sourceDocument "readiness.json" "readiness-input"

evidenceSourceDocument = sourceDocument "evidence.json" "evidence-input"

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

persistedGraphFacts :: RawGraph -> [FactTemplate]
persistedGraphFacts graph =
  nodeFacts ++ edgeFacts ++ endpointDependencies ++ ownershipDependencies
  where
    indexedNodes = zip [(1 :: Int) ..] (rawNodes graph)
    indexedEdges = zip [(1 :: Int) ..] (rawEdges graph)
    nodeFacts =
      [ NodeTemplate (indexedOccurrence "node" index) node
      | (index, node) <- indexedNodes
      ]
    edgeFacts =
      [ EdgeTemplate (indexedOccurrence "edge" index) edge
      | (index, edge) <- indexedEdges
      ]
    endpointDependencies =
      concat
        [ [ DependencyTemplate
              occurrence
              (nodeOccurrenceFor graph (rawEdgeFrom edge))
              PersistedRelationshipEndpoint
          , DependencyTemplate
              occurrence
              (nodeOccurrenceFor graph (rawEdgeTo edge))
              PersistedRelationshipEndpoint
          ]
        | (index, edge) <- indexedEdges
        , let occurrence = indexedOccurrence "edge" index
        ]
    ownershipDependencies =
      [ DependencyTemplate
        (nodeOccurrenceFor graph owner)
        (indexedOccurrence "node" index)
        PersistedContextOwnership
      | (index, node) <- indexedNodes
      , owner <- rawNodeOwner node
      ]

rawNodeOwner :: RawNode -> [RawNodeId]
rawNodeOwner node =
  case node of
    RawPrimitiveNode _ owner _ -> [owner]
    RawStructuringNode _ owner _ -> [owner]
    RawContextNode _ _ -> []
    RawAnchorNode _ _ -> []

nodeOccurrenceFor :: RawGraph -> RawNodeId -> OccurrenceId
nodeOccurrenceFor graph identifier =
  case [ indexedOccurrence "node" index
       | (index, node) <- zip [(1 :: Int) ..] (rawNodes graph)
       , testRawNodeIdentifier node == identifier
       ] of
    occurrence:_ -> occurrence
    [] -> error "graph fixture endpoint is absent"

indexedOccurrence :: Text -> Int -> OccurrenceId
indexedOccurrence prefix index =
  testOccurrence (prefix <> "-" <> Text.pack (show index))

completePresentation :: OccurrenceId
completePresentation = testOccurrence "presentation-complete"

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

runCollectiveInspection ::
     Claim RawCollectiveStrategyRealization -> InspectionOutcome
runCollectiveInspection claim =
  runCollectiveInspectionWithFit
    claim
    (Supplied
       (sourcedFromDocument
          collectiveFitSourceDocument
          (CollectiveFitEvidenceBundle [collectiveInspectionFit])))

runCollectiveInspectionWithFit ::
     Claim RawCollectiveStrategyRealization
  -> Availability CollectiveFitEvidenceBundle
  -> InspectionOutcome
runCollectiveInspectionWithFit claim fitAvailability =
  runCollectiveInspectionWithFacts
    (collectiveInspectionFacts claim)
    fitAvailability

runCollectiveInspectionWithFacts ::
     [FactTemplate]
  -> Availability CollectiveFitEvidenceBundle
  -> InspectionOutcome
runCollectiveInspectionWithFacts facts fitAvailability =
  runAdapterWithInputs
    (testAdapter DecodeSucceeds ViewSucceeds RootSucceeds facts [])
    noInputs
      { strategyInput =
          Supplied
            (sourcedFromDocument
               strategySourceDocument
               (StrategyFormulationBundle collectiveInspectionFormulations))
      , collectiveFitInput = fitAvailability
      }

collectiveInspectionFacts ::
     Claim RawCollectiveStrategyRealization -> [FactTemplate]
collectiveInspectionFacts claim =
  graphFacts collectiveInspectionGraph
    ++ [ CollectiveTemplate
           collectiveClaimOccurrence
           claim
           [ collectiveNodeOccurrence collectiveContributorOneId
           , collectiveNodeOccurrence collectiveContributorTwoId
           ]
           (collectiveNodeOccurrence completeStrategyId)
       , SeedTemplate completePresentation collectiveClaimOccurrence
       , OccurrenceTemplate collectiveSegmentOccurrence
       , DependencyTemplate
           collectiveClaimOccurrence
           collectiveSegmentOccurrence
           PersistedCollectiveRealizationSegment
       , DependencyTemplate
           collectiveSegmentOccurrence
           collectiveClaimOccurrence
           PersistedCollectiveRealizationSegment
       ]

collectiveScopeFacts ::
     RawGraph -> Claim RawCollectiveStrategyRealization -> [FactTemplate]
collectiveScopeFacts graph claim =
  OccurrenceTemplate completePresentation
    : persistedGraphFacts graph
    ++ directlyPresentedCollectiveBaseline graph
    ++ [ CollectiveTemplate
           collectiveClaimOccurrence
           claim
           [ nodeOccurrenceFor graph collectiveContributorOneId
           , nodeOccurrenceFor graph collectiveContributorTwoId
           ]
           (nodeOccurrenceFor graph completeStrategyId)
       , SeedTemplate completePresentation collectiveClaimOccurrence
       , OccurrenceTemplate collectiveSegmentOccurrence
       , DependencyTemplate
           collectiveClaimOccurrence
           collectiveSegmentOccurrence
           PersistedCollectiveRealizationSegment
       , DependencyTemplate
           collectiveSegmentOccurrence
           collectiveClaimOccurrence
           PersistedCollectiveRealizationSegment
       ]

directlyPresentedCollectiveBaseline :: RawGraph -> [FactTemplate]
directlyPresentedCollectiveBaseline graph =
  [ SeedTemplate completePresentation (nodeOccurrenceFor graph identifier)
  | node <- rawNodes collectiveInspectionGraph
  , let identifier = testRawNodeIdentifier node
  , any ((== identifier) . testRawNodeIdentifier) (rawNodes graph)
  ]
    ++ [ SeedTemplate completePresentation (collectiveEdgeOccurrence graph edge)
       | edge <- rawEdges collectiveInspectionGraph
       , edge `elem` rawEdges graph
       , rawEdgeRelation edge `notElem` collectiveContributionRelationNames
       ]

collectiveContributionRelationNames :: [RelationName]
collectiveContributionRelationNames =
  [ relationNameFor contributesToStrategy
  , relationNameFor contributesStrategyKeyResultToKeyResult
  , relationNameFor contributesStrategyActionToAction
  ]

collectiveNodeOccurrence :: RawNodeId -> OccurrenceId
collectiveNodeOccurrence identifier =
  case [ occurrence
       | (index, node) <- zip [(1 :: Int) ..] collectiveInspectionNodes
       , testRawNodeIdentifier node == identifier
       , let occurrence = indexedOccurrence "node" index
       ] of
    occurrence:_ -> occurrence
    [] -> error "collective fixture participant is absent"

collectiveEdgeOccurrence :: RawGraph -> RawEdge -> OccurrenceId
collectiveEdgeOccurrence graph expected =
  case [ indexedOccurrence "edge" index
       | (index, edge) <- zip [(1 :: Int) ..] (rawEdges graph)
       , edge == expected
       ] of
    occurrence:_ -> occurrence
    [] -> error "collective fixture edge is absent"

collectiveInspectionGraph :: RawGraph
collectiveInspectionGraph =
  RawGraph collectiveInspectionNodes collectiveInspectionEdges

collectiveInspectionNodes :: [RawNode]
collectiveInspectionNodes =
  completeNodes
    ++ contributorNodes "one" collectiveContributorOneId
    ++ contributorNodes "two" collectiveContributorTwoId
  where
    contributorNodes prefix strategy =
      [ RawContextNode strategy Strategy
      , RawPrimitiveNode (contributorId prefix "driver") strategy Driver
      , RawPrimitiveNode (contributorId prefix "objective") strategy Objective
      , RawPrimitiveNode (contributorId prefix "principle") strategy Principle
      , RawPrimitiveNode (contributorId prefix "action") strategy Action
      , RawPrimitiveNode (contributorId prefix "key-result") strategy KeyResult
      ]

collectiveInspectionEdges :: [RawEdge]
collectiveInspectionEdges =
  completeEdges
    ++ contributorEdges "one" collectiveContributorOneId
    ++ contributorEdges "two" collectiveContributorTwoId
    ++ [ completeEdge
           collectiveContributorOneId
           contributesToStrategy
           completeStrategyId
       , completeEdge
           collectiveContributorTwoId
           contributesToStrategy
           completeStrategyId
       , completeEdge
           (contributorId "one" "key-result")
           contributesStrategyKeyResultToKeyResult
           completeStrategyKeyResultId
       , completeEdge
           (contributorId "two" "action")
           contributesStrategyActionToAction
           completeStrategyActionId
       ]
  where
    contributorEdges prefix strategy =
      [ completeEdge
          completeVisionObjectiveId
          orientsVisionObjectiveToStrategyObjective
          (contributorId prefix "objective")
      , completeEdge
          (contributorId prefix "driver")
          groundsStrategyDriverToObjective
          (contributorId prefix "objective")
      , completeEdge
          (contributorId prefix "principle")
          guidesStrategyPrincipleToAction
          (contributorId prefix "action")
      , completeEdge
          (contributorId prefix "key-result")
          substantiatesStrategyKeyResultObjective
          (contributorId prefix "objective")
      , completeEdge
          (contributorId prefix "action")
          contributesStrategyActionToKeyResult
          (contributorId prefix "key-result")
      , completeEdge completeVisionId orientsStrategy strategy
      ]

collectiveInspectionFormulations :: [Claim RawStrategyFormulation]
collectiveInspectionFormulations =
  map
    assertedClaim
    [ completeStrategyFormulation
    , contributorFormulation "one" collectiveContributorOneId
    , contributorFormulation "two" collectiveContributorTwoId
    ]
  where
    contributorFormulation prefix strategy =
      completeStrategyFormulation
        { rawFormulationStrategy = strategy
        , rawFormulationDiagnosis = contributorId prefix "driver"
        , rawFormulationIntent = contributorId prefix "objective"
        , rawFormulationGuidingPolicy = contributorId prefix "principle"
        , rawFormulationActions = contributorId prefix "action" :| []
        , rawFormulationKeyResults = contributorId prefix "key-result" :| []
        }

collectiveInspectionClaimId :: ClaimId
collectiveInspectionClaimId = ClaimId "inspection-collective"

collectiveInspectionProposition :: RawCollectiveStrategyRealization
collectiveInspectionProposition =
  RawCollectiveStrategyRealization
    { rawRealizationId = collectiveInspectionClaimId
    , rawContributors = [collectiveContributorOneId, collectiveContributorTwoId]
    , rawTarget = completeStrategyId
    , rawCollectiveFitEvidence = collectiveInspectionFitRef
    }

assertedCollectiveClaim :: Claim RawCollectiveStrategyRealization
assertedCollectiveClaim = assertedClaim collectiveInspectionProposition

candidateCollectiveInspectionClaim :: Claim RawCollectiveStrategyRealization
candidateCollectiveInspectionClaim =
  candidateClaim collectiveInspectionProposition

unselectedCollectiveClaim :: Claim RawCollectiveStrategyRealization
unselectedCollectiveClaim =
  assertedClaim
    collectiveInspectionProposition
      {rawRealizationId = ClaimId "inspection-collective-unselected"}

collectiveInspectionFit :: RawCollectiveFitEvidence
collectiveInspectionFit =
  RawCollectiveFitEvidence
    { rawFitEvidenceRef = collectiveInspectionFitRef
    , rawFitContributors =
        [collectiveContributorOneId, collectiveContributorTwoId]
    , rawFitTarget = completeStrategyId
    , rawMutualCoherenceEvidence =
        [ RawMutualCoherenceEvidence
            collectiveContributorOneId
            collectiveContributorTwoId
            "The contributor commitments are mutually coherent."
        ]
    , rawFitTargetGuidingPolicy = completeStrategyPrincipleId
    , rawFitTargetTradeOffs =
        NonEmpty.toList (rawFormulationTradeOffs completeStrategyFormulation)
    , rawContributorCompatibilityEvidence =
        [ compatibility collectiveContributorOneId
        , compatibility collectiveContributorTwoId
        ]
    , rawViableInteractionEvidence = ["The actions interact viably."]
    }
  where
    compatibility contributor =
      RawContributorCompatibilityEvidence
        contributor
        "Compatible with the target Guiding Policy."
        "Compatible with the target Trade-offs."

collectiveInspectionFitRef :: CollectiveFitEvidenceRef
collectiveInspectionFitRef = CollectiveFitEvidenceRef "inspection-fit"

suppliedCollectiveFit :: Availability CollectiveFitEvidenceBundle
suppliedCollectiveFit =
  Supplied
    (sourcedFromDocument
       collectiveFitSourceDocument
       (CollectiveFitEvidenceBundle [collectiveInspectionFit]))

collectiveContributorOneId, collectiveContributorTwoId :: RawNodeId
collectiveContributorOneId = RawNodeId "collective-contributor-one"

collectiveContributorTwoId = RawNodeId "collective-contributor-two"

contributorId :: Text -> Text -> RawNodeId
contributorId prefix suffix =
  RawNodeId ("collective-contributor-" <> prefix <> "-" <> suffix)

collectiveClaimOccurrence :: OccurrenceId
collectiveClaimOccurrence = testOccurrence "collective-claim"

duplicateCollectiveClaimOccurrence :: OccurrenceId
duplicateCollectiveClaimOccurrence = testOccurrence "collective-claim-duplicate"

collectiveSegmentOccurrence :: OccurrenceId
collectiveSegmentOccurrence = testOccurrence "collective-segment"

unselectedCollectiveClaimOccurrence :: OccurrenceId
unselectedCollectiveClaimOccurrence =
  testOccurrence "collective-claim-unselected"

unrelatedStrategyId, unrelatedKeyResultId :: RawNodeId
unrelatedStrategyId = RawNodeId "collective-unrelated-strategy"

unrelatedKeyResultId = RawNodeId "collective-unrelated-key-result"

testRawNodeIdentifier :: RawNode -> RawNodeId
testRawNodeIdentifier node =
  case node of
    RawContextNode identifier _ -> identifier
    RawPrimitiveNode identifier _ _ -> identifier
    RawStructuringNode identifier _ _ -> identifier
    RawAnchorNode identifier _ -> identifier

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
    (\_ -> DecodePassed testNativeBinding testPosition)
    (\AlternateDefect -> testSpec "o2i.test.alt.decode")
    (\position _ -> ViewPassed (testResolvedViewAt position) position)
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
                    AlternateFact ->
                      instantiateFacts
                        (locatedAt (snapshotFact snapshot))
                        completeEthosFacts
              , projectedDefects = []
              }
      , profileDefectSpec = \AlternateDefect -> testSpec "o2i.test.alt.profile"
      }
    (\position _ -> profileSnapshot (Located position AlternateFact))

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
    (\position _ -> profileSnapshot (Located position TestProfileFact))
  where
    decode _ =
      case mode of
        AdversarialDecode ->
          DecodeUnavailable
            (DecodeUnavailableObservation EncodingNotObserved)
            (Located testPosition AdversarialDefect :| [])
        AdversarialView -> DecodePassed testNativeBinding testPosition
        AdversarialProfile -> DecodePassed testNativeBinding testPosition
    resolveView position _ =
      case mode of
        AdversarialDecode ->
          ViewFailed NoViewMatch (Located position AdversarialDefect :| [])
        AdversarialView ->
          ViewFailed NoViewMatch (Located position AdversarialDefect :| [])
        AdversarialProfile -> ViewPassed (testResolvedViewAt position) position
    contract =
      O2IProfileContract
        { projectProfileSnapshot =
            \snapshot ->
              let location = locatedAt (snapshotFact snapshot)
               in ProfileProjection
                    { projectedRoot =
                        RootUnprojectable
                          NoO2IProfile
                          (Located location AdversarialDefect :| [])
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

diagnosticContractAdapter ::
     DiagnosticContractPoint -> NonEmpty ContractDefect -> Adapter
diagnosticContractAdapter point defects =
  Adapter
    testDescriptor
    decode
    contractDefectSpec
    resolveView
    contractDefectSpec
    contract
    observe
  where
    decode _
      | point == ContractDecode =
        DecodeUnavailable
          (DecodeUnavailableObservation EncodingNotObserved)
          (locatedDefects testPosition)
      | otherwise = DecodePassed testNativeBinding testPosition
    resolveView position _
      | point == ContractView = ViewFailed NoViewMatch (locatedDefects position)
      | otherwise = ViewPassed (testResolvedViewAt position) position
    contract =
      O2IProfileContract
        { projectProfileSnapshot = project
        , profileDefectSpec = contractDefectSpec
        }
    project snapshot =
      ProfileProjection
        { projectedRoot =
            if point == ContractProfile
              then RootUnprojectable NoO2IProfile (locatedDefectsAt location)
              else RootProjectable
                     (OneO2IProfile "0.2")
                     (resolveProfileVersion
                        (o2iProfileVersionLiteral ('0' :| ".2")))
        , projectedFacts = instantiateFacts location missionFacts
        , projectedDefects =
            if point == ContractScope
              then map scopeDefect (NonEmpty.toList (locatedDefectsAt location))
              else []
        }
      where
        location = locatedAt (snapshotFact snapshot)
    observe position _ = profileSnapshot (Located position TestProfileFact)
    locatedDefects = locatedDefectsAt
    locatedDefectsAt location = fmap (Located location) defects
    scopeDefect located =
      DeferredProfileDefect
        { defectApplicability = ReachedProfileDefect (missionOccurrence :| [])
        , deferredDefect = located
        }

contractDefectSpec :: ContractDefect -> DiagnosticSpec
contractDefectSpec defect =
  diagnosticSpec
    (o2iDiagnosticCode ("test.contract." <> contractDefectCode defect))
    ErrorSeverity
    ModelFinding
    (contractDefectMessage defect)
    []
    Map.empty

diagnosticAdapter :: SourceLocation -> DiagnosticSpec -> Adapter
diagnosticAdapter location specification =
  Adapter
    testDescriptor
    (\_ ->
       DecodeUnavailable
         (DecodeUnavailableObservation EncodingNotObserved)
         (Located boundPosition specification :| []))
    id
    (\position _ ->
       ViewFailed NoViewMatch (Located position TestViewDefect :| []))
    testViewSpec
    O2IProfileContract
      { projectProfileSnapshot =
          \snapshot ->
            let position = locatedAt (snapshotFact snapshot)
             in ProfileProjection
                  { projectedRoot =
                      RootUnprojectable
                        NoO2IProfile
                        (Located position TestRootProfileDefect :| [])
                  , projectedFacts = []
                  , projectedDefects = []
                  }
      , profileDefectSpec = testProfileSpec
      }
    (\position _ -> profileSnapshot (Located position TestProfileFact))
  where
    boundPosition =
      sourcePosition
        (locationPath location)
        (locationTarget location)
        (locationSpan location)

testAdapter ::
     DecodeMode
  -> ViewMode
  -> RootMode
  -> [FactTemplate]
  -> [OccurrenceId]
  -> Adapter
testAdapter decodeMode viewMode rootMode templates deferred =
  testAdapterWithDefects
    decodeMode
    viewMode
    rootMode
    templates
    [(occurrence, TestReachedProfileDefect) | occurrence <- deferred]

testAdapterWithDefects ::
     DecodeMode
  -> ViewMode
  -> RootMode
  -> [FactTemplate]
  -> [(OccurrenceId, TestProfileDefect)]
  -> Adapter
testAdapterWithDefects decodeMode viewMode rootMode templates deferred =
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
        DecodeSucceeds -> DecodePassed testNativeBinding testPosition
        DecodeUnavailableMode ->
          DecodeUnavailable
            (DecodeUnavailableObservation EncodingNotObserved)
            (Located testPosition TestDecodeDefect :| [])
        DecodeRejectedMode ->
          DecodeRejected
            RejectedNativeBinding
              { rejectedEncoding = Utf8Binding
              , rejectedRootQName = Located testPosition testRootQName
              , rejectedNativeVersion = Just (Located testPosition "4.0.0")
              }
            (Located testPosition TestDecodeDefect :| [])
    resolveView position _ =
      case viewMode of
        ViewSucceeds -> ViewPassed (testResolvedViewAt position) position
        ViewFails ->
          ViewFailed NoViewMatch (Located position TestViewDefect :| [])
    contract =
      O2IProfileContract
        {projectProfileSnapshot = project, profileDefectSpec = testProfileSpec}
    project snapshot =
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
                  (Located
                     (locatedAt (snapshotFact snapshot))
                     TestRootProfileDefect
                     :| [])
        , projectedFacts =
            instantiateFacts (locatedAt (snapshotFact snapshot)) templates
        , projectedDefects =
            map (reachedFinding (locatedAt (snapshotFact snapshot))) deferred
        }
    observe position _ = profileSnapshot (Located position TestProfileFact)

instantiateFacts :: location -> [FactTemplate] -> [IndexedProfileFact location]
instantiateFacts location = map instantiate
  where
    instantiate template =
      case template of
        OccurrenceTemplate occurrence -> indexOccurrence occurrence location
        NodeTemplate occurrence node ->
          indexNode occurrence (assertedClaim node) location
        NodeClaimTemplate occurrence claim ->
          indexNode occurrence claim location
        EdgeTemplate occurrence edge ->
          indexEdge occurrence (assertedClaim edge) location
        EdgeClaimTemplate occurrence claim ->
          indexEdge occurrence claim location
        CollectiveTemplate occurrence claim contributors target ->
          indexCollectiveStrategyRealization
            occurrence
            claim
            contributors
            target
            location
        SeedTemplate presentation target ->
          indexPresentation presentation target
        DependencyTemplate source target reason ->
          indexDependency source target reason
        ReferenceTemplate source matches reason ->
          indexReference
            source
            ReferenceOccurrence
              { referenceOccurrenceId = testOccurrence "reference"
              , referenceFromOccurrence = source
              , referenceRole = OwnershipTargetReference
              , referenceToken = Just "missing"
              , referenceLocation = location
              }
            matches
            reason

reachedFinding ::
     SourcePosition
  -> (OccurrenceId, TestProfileDefect)
  -> DeferredProfileDefect SourcePosition TestProfileDefect
reachedFinding location (occurrence, finding) =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = Located location finding
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
missionPresentation = testOccurrence "presentation-mission"

ethosPresentation :: OccurrenceId
ethosPresentation = testOccurrence "presentation-ethos"

secondPresentation :: OccurrenceId
secondPresentation = testOccurrence "presentation-second"

strategyPresentation :: OccurrenceId
strategyPresentation = testOccurrence "presentation-strategy"

macroPresentation :: OccurrenceId
macroPresentation = testOccurrence "presentation-macro"

missionOccurrence :: OccurrenceId
missionOccurrence = testOccurrence "node-mission"

driverOccurrence :: OccurrenceId
driverOccurrence = testOccurrence "node-driver"

strategyOccurrence :: OccurrenceId
strategyOccurrence = testOccurrence "node-strategy"

ethosOccurrence, principleOccurrence, macroEdgeOccurrence, premiseEdgeOccurrence ::
     OccurrenceId
ethosOccurrence = testOccurrence "node-ethos"

principleOccurrence = testOccurrence "node-principle"

macroEdgeOccurrence = testOccurrence "edge-macro"

premiseEdgeOccurrence = testOccurrence "edge-premise"

testOccurrence :: Text -> OccurrenceId
testOccurrence token =
  occurrenceId
    (occurrenceKindLiteral ('t' :| "est"))
    (firstPathStep (expandedQName Nothing 'o' ("ccurrence-" <> token)) :| [])

occurrenceForPath :: NonEmpty PathStep -> OccurrenceId
occurrenceForPath = occurrenceId (occurrenceKindLiteral ('t' :| "est"))

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
testLocation = locationForPath (firstPathStep testRootQName :| [])

testPosition :: SourcePosition
testPosition =
  sourcePosition (firstPathStep testRootQName :| []) ElementTarget Nothing

locationForPath :: NonEmpty PathStep -> SourceLocation
locationForPath path =
  firstDiagnosticLocation (runAdapter (locationAdapter path))

testResolvedViewAt :: SourcePosition -> ResolvedView SourcePosition
testResolvedViewAt position =
  ResolvedView
    { resolvedViewId = "view-1"
    , resolvedViewName = "O2I"
    , resolvedViewLocation = position
    }

locationAdapter :: NonEmpty PathStep -> Adapter
locationAdapter path =
  Adapter
    testDescriptor
    (\_ -> DecodePassed testNativeBinding testPosition)
    testDecodeSpec
    (\_ _ ->
       ViewFailed
         NoViewMatch
         (Located (sourcePosition path ElementTarget Nothing) TestViewDefect
            :| []))
    testViewSpec
    O2IProfileContract
      { projectProfileSnapshot =
          \snapshot ->
            let position = locatedAt (snapshotFact snapshot)
             in ProfileProjection
                  { projectedRoot =
                      RootUnprojectable
                        NoO2IProfile
                        (Located position TestRootProfileDefect :| [])
                  , projectedFacts = []
                  , projectedDefects = []
                  }
      , profileDefectSpec = testProfileSpec
      }
    (\position _ -> profileSnapshot (Located position TestProfileFact))

firstDiagnosticLocation :: InspectionOutcome -> SourceLocation
firstDiagnosticLocation outcome =
  case outcome of
    InspectionCompleted report ->
      case diagnosticsList (reportDiagnostics report) of
        [diagnostic] ->
          case diagnosticLocations diagnostic of
            [location] -> location
            _ -> error "expected exactly one diagnostic location"
        _ -> error "expected exactly one diagnostic"
    InspectionCommandFailed _ -> error "expected completed inspection"

testDecodeSpec :: TestDecodeDefect -> DiagnosticSpec
testDecodeSpec TestDecodeDefect = testSpec "o2i.test.decode"

testViewSpec :: TestViewDefect -> DiagnosticSpec
testViewSpec TestViewDefect = testSpec "o2i.test.view"

testProfileSpec :: TestProfileDefect -> DiagnosticSpec
testProfileSpec defect =
  case defect of
    TestRootProfileDefect -> testSpec "o2i.test.profile.root"
    TestReachedProfileDefect -> testSpec "o2i.test.profile.reached"
    TestInformationalProfileFinding ->
      diagnosticSpec
        (o2iDiagnosticCode "test.profile.information")
        InfoSeverity
        ModelFinding
        "Test information."
        []
        Map.empty

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
    { strategyInput = Absent
    , collectiveFitInput = Absent
    , readinessInput = Absent
    , evidenceInput = Absent
    }

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

semanticsState :: InspectionReport -> StageState
semanticsState report =
  case filter
         ((== SemanticsStage) . reportedStage)
         (stageReportsList (reportStageReports report)) of
    stage:_ -> reportedState stage
    [] -> error "the eight-stage report omitted Semantics"
