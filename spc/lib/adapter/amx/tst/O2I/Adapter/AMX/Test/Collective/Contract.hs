{-# LANGUAGE OverloadedStrings #-}

-- | Behavioral contract for native collective Strategy realization.
module O2I.Adapter.AMX.Test.Collective.Contract
  ( collectiveContractTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX
import O2I.Adapter.AMX.Internal.Profile.Collective
import O2I.Adapter.AMX.Internal.Profile.Collective.Index
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.View
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Test.Collective.Scenario
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

collectiveContractTests :: TestTree
collectiveContractTests =
  testGroup
    "collective Strategy realization"
    [ testCase
        "projects one valid asserted Junction claim without a binary edge"
        assertedProjectionTest
    , testCase
        "projects a valid Candidate with its explicit commitment"
        candidateProjectionTest
    , testCase
        "Candidate participant diagnostics retain roles and stable source order"
        (candidateParticipantTest
           [ ("contributor", "contributor-a")
           , ("contributor", "contributor-b")
           , ("target", "target")
           ]
           candidateCollectiveMultipleCandidateParticipantsModel)
    , testCase
        "Asserted collective rejects a Candidate contributor with provenance"
        (assertedParticipantTest assertedCollectiveCandidateContributorModel)
    , testCase
        "Asserted collective rejects a Candidate target with provenance"
        (assertedParticipantTest assertedCollectiveCandidateTargetModel)
    , testCase
        "structured proposition kind metadata is mandatory"
        (rejects missingClaimKindModel ["o2i.amx.profile.kind-missing"])
    , testCase
        "missing structured proposition type remains generic"
        (genericTypeFallbackTest
           missingClaimTypeModel
           ["o2i.amx.profile.type-missing"])
    , testCase
        "structured proposition kind metadata is exact"
        (rejects invalidClaimKindModel ["o2i.amx.profile.kind-unknown"])
    , testCase
        "future structured proposition type remains generic"
        (genericTypeFallbackTest
           invalidClaimTypeModel
           ["o2i.amx.profile.type-invalid"])
    , testCase
        "structured proposition kind metadata is single-valued"
        (rejects duplicateClaimKindModel ["o2i.amx.profile.kind-duplicate"])
    , testCase
        "duplicate structured proposition type remains generic"
        (genericTypeFallbackTest
           duplicateClaimTypeModel
           ["o2i.amx.profile.type-duplicate"])
    , testCase
        "structured propositions reject unsupported O2I metadata"
        (rejects unsupportedClaimMetadataModel ["o2i.amx.profile.metadata-key"])
    , testCase
        "collective commitment is mandatory"
        (rejects missingCommitmentModel ["o2i.amx.profile.commitment-missing"])
    , testCase
        "collective commitment values are closed"
        (rejects invalidCommitmentModel ["o2i.amx.profile.commitment-invalid"])
    , testCase
        "collective commitment is single-valued"
        (rejects
           duplicateCommitmentModel
           ["o2i.amx.profile.commitment-duplicate"])
    , testCase
        "collective Fit evidence reference is mandatory"
        (rejects
           missingFitReferenceModel
           ["o2i.amx.profile.collective.fit-reference-missing"])
    , testCase
        "collective Fit evidence reference must be nonempty"
        (rejects
           emptyFitReferenceModel
           ["o2i.amx.profile.collective.fit-reference-empty"])
    , testCase
        "collective Fit evidence reference is single-valued"
        (rejects
           duplicateFitReferenceModel
           ["o2i.amx.profile.collective.fit-reference-duplicate"])
    , testCase
        "collective Claim identifiers must be nonempty"
        (rejects blankClaimIdModel ["o2i.amx.profile.collective.id-missing"])
    , testCase
        "duplicate collective Junction identifiers fail View resolution"
        duplicateClaimIdTest
    , testCase
        "partial View closure includes the complete persisted claim"
        partialViewClosureTest
    , testCase
        "direct Claim selection closes all segments and participants"
        claimOccurrenceClosureTest
    , testCase
        "partial View information reports exact shown and total counts"
        partialViewDiagnosticTest
    , testCase "full View emits no partial-claim diagnostic" fullViewTest
    , testCase
        "repeated presentations count one shown contributor once"
        repeatedPresentationCountTest
    , testCase
        "annotations never contribute to collective cardinality"
        annotationNonSemanticsTest
    , testCase
        "OR Junctions are rejected at Profile"
        (rejects orJunctionModel ["o2i.amx.profile.collective.junction-invalid"])
    , testCase
        "mixed segment types are rejected at Profile"
        (rejects
           mixedSegmentModel
           ["o2i.amx.profile.collective.segment-representation"])
    , testCase
        "segment names must be exactly realizes"
        (rejects
           wrongSegmentNameModel
           ["o2i.amx.profile.collective.segment-name"])
    , testCase
        "segment roles derive only from topology"
        (rejects
           segmentMetadataModel
           ["o2i.amx.profile.collective.segment-metadata"])
    , testCase "Junction chains are rejected" junctionChainTest
    , testCase "duplicate contributors are rejected" duplicateContributorTest
    , testCase "self-participation is rejected" selfParticipationTest
    , testCase
        "zero targets are rejected"
        (rejects zeroTargetModel ["o2i.amx.profile.collective.target"])
    , testCase
        "multiple targets are rejected"
        (rejects multipleTargetModel ["o2i.amx.profile.collective.target"])
    , testCase
        "singleton contributor claims are rejected"
        (rejects
           singletonContributorModel
           ["o2i.amx.profile.collective.contributors"])
    , testCase
        "unknown participants are diagnosed at their segment"
        unknownParticipantTest
    , testCase
        "ambiguous participants are diagnosed at their segment"
        ambiguousParticipantTest
    , testCase
        "non-Strategy participants remain for format-neutral validation"
        nonStrategyParticipantTest
    , testCase
        "globally incomplete Candidates fail despite a complete-looking View"
        incompleteCandidateTest
    , testCase
        "direct binary Strategy realizes remains inadmissible"
        directBinaryRealizesTest
    , testCase
        "collective defects outside the selected scope do not leak"
        outsideScopeTest
    , testCase
        "a selected participant alone does not select its collective claim"
        participantOnlyScopeTest
    , testCase
        "partial-View JSON and source diagnostics are deterministic"
        reportDeterminismTest
    ]

assertedProjectionTest :: Assertion
assertedProjectionTest = do
  environment <- environmentFor "Partial" assertedModel
  collectiveRawClaims (buildCollectiveIndex environment)
    @?= [expectedClaim Asserted]
  report <- inspectText (ViewByName "Partial") assertedModel
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed
  assertBool
    "collective realizes segments must not become binary graph edges"
    ("o2i.structure.relation-unknown" `notElem` diagnosticCodes report)

candidateProjectionTest :: Assertion
candidateProjectionTest = do
  environment <- environmentFor "Partial" candidateModel
  collectiveRawClaims (buildCollectiveIndex environment)
    @?= [expectedClaim Candidate]

candidateParticipantTest :: [(Text, Text)] -> Text -> Assertion
candidateParticipantTest expected input = do
  report <- inspectCommitmentModel input
  let codes = diagnosticCodes report
  assertBool
    "Candidate participant was misclassified as unknown"
    ("o2i.semantics.collective.participant-unknown" `notElem` codes)
  assertBool
    "Candidate collective exclusion was not diagnosed"
    ("o2i.claim.collective-candidate-excluded" `elem` codes)
  assertBool
    "Candidate participant exclusion was not diagnosed"
    ("o2i.claim.candidate-excluded" `elem` codes)
  case filter
         isCandidateParticipantIssue
         (diagnosticsList (reportDiagnostics report)) of
    diagnostics -> do
      map diagnosticSubjects diagnostics @?= map expectedSubjects expected
      map diagnosticSeverity diagnostics
        @?= replicate (length expected) WarningSeverity
      map diagnosticStage diagnostics
        @?= replicate (length expected) SemanticsStage
      assertBool
        "Candidate participant diagnostics lost claim and participant provenance"
        (all ((>= 2) . length . diagnosticLocations) diagnostics)
  where
    isCandidateParticipantIssue diagnostic =
      diagnosticCodeText (diagnosticCode diagnostic)
        == "o2i.semantics.collective.candidate-participant-semantics-unavailable"
    expectedSubjects (role, participant) =
      [ DiagnosticSubject "collective-claim" "claim"
      , DiagnosticSubject "participant-role" role
      , DiagnosticSubject "node" participant
      ]

assertedParticipantTest :: Text -> Assertion
assertedParticipantTest input = do
  report <- inspectCommitmentModel input
  case filter isCandidateDependency (diagnosticsList (reportDiagnostics report)) of
    [diagnostic] -> do
      diagnosticSeverity diagnostic @?= ErrorSeverity
      diagnosticStage diagnostic @?= SemanticsStage
      assertBool
        "Candidate dependency lost claim and participant provenance"
        (length (diagnosticLocations diagnostic) >= 2)
    diagnostics ->
      assertFailure
        ("expected one asserted Candidate dependency diagnostic: "
           <> show diagnostics)
  where
    isCandidateDependency diagnostic =
      diagnosticCodeText (diagnosticCode diagnostic)
        == "o2i.semantics.collective.asserted-depends-on-candidate"

inspectCommitmentModel :: Text -> IO InspectionReport
inspectCommitmentModel input =
  case inspectSourceDocument
         amxAdapter
         (ViewByName "Scope")
         commitmentInputs
         (source input) of
    InspectionCompleted report -> pure report
    InspectionCommandFailed commandError ->
      assertFailure ("unexpected command error: " <> show commandError)

commitmentInputs :: InspectionInputs
commitmentInputs =
  noInputs
    { strategyInput =
        Supplied
          (sourcedFromDocument
             (source "empty Strategy formulation input")
             (StrategyFormulationBundle []))
    }

duplicateClaimIdTest :: Assertion
duplicateClaimIdTest = do
  report <- inspectText (ViewByName "Scope") duplicateClaimIdModel
  diagnosticCodes report @?= ["o2i.amx.view.object-ambiguous"]
  stageState ViewScopeStage report @?= StageFailed
  assertBool
    "ambiguous Junction reference must retain source provenance"
    (all
       (not . null . diagnosticLocations)
       (diagnosticsList (reportDiagnostics report)))

partialViewClosureTest :: Assertion
partialViewClosureTest = do
  environment <- environmentFor "Partial" assertedModel
  report <- inspectText (ViewByName "Partial") assertedModel
  provenance <-
    maybe
      (assertFailure "expected closed-scope provenance")
      pure
      (reportClosedScopeProvenance report)
  let entries = NonEmpty.toList (closedScopeProvenanceOccurrences provenance)
      omittedContributor =
        nodeOccurrence
          (elementById "contributor-b" (environmentNodes environment))
      omittedSegment =
        relationshipOccurrence
          (elementById "incoming-b" (environmentRelationships environment))
  reasonsFor omittedContributor entries @?= [CollectiveRealizationParticipant]
  reasonsFor omittedSegment entries @?= [CollectiveRealizationSegment]
  map (sourceDisplayLabel . locationSource . provenanceLocation) entries
    @?= replicate (length entries) "test.archimate"

claimOccurrenceClosureTest :: Assertion
claimOccurrenceClosureTest = do
  environment <- environmentFor "Claim only" assertedModel
  report <- inspectText (ViewByName "Claim only") assertedModel
  provenance <-
    maybe
      (assertFailure "expected closed-scope provenance")
      pure
      (reportClosedScopeProvenance report)
  let entries = NonEmpty.toList (closedScopeProvenanceOccurrences provenance)
      claimOccurrence =
        nodeOccurrence (elementById "claim" (environmentNodes environment))
      participantOccurrences =
        map
          (\identifier ->
             nodeOccurrence
               (elementById identifier (environmentNodes environment)))
          ["contributor-a", "contributor-b", "target"]
      segmentOccurrences =
        map
          (\identifier ->
             relationshipOccurrence
               (elementById identifier (environmentRelationships environment)))
          ["incoming-a", "incoming-b", "outgoing"]
  assertBool
    "the claim Junction must be the directly selected occurrence"
    (DirectPresentation `elem` reasonsFor claimOccurrence entries)
  mapM_
    (\occurrence ->
       reasonsFor occurrence entries @?= [CollectiveRealizationParticipant])
    participantOccurrences
  mapM_
    (\occurrence ->
       reasonsFor occurrence entries @?= [CollectiveRealizationSegment])
    segmentOccurrences
  map (sourceDisplayLabel . locationSource . provenanceLocation) entries
    @?= replicate (length entries) "test.archimate"

partialViewDiagnosticTest :: Assertion
partialViewDiagnosticTest = do
  report <- inspectText (ViewByName "Partial") assertedModel
  case diagnosticsList (reportDiagnostics report) of
    [diagnostic] -> do
      diagnosticCodeText (diagnosticCode diagnostic)
        @?= "o2i.amx.profile.collective.view-partial"
      diagnosticSeverity diagnostic @?= InfoSeverity
      diagnosticStage diagnostic @?= ProfileStage
      diagnosticSubjects diagnostic
        @?= [ DiagnosticSubject "collective-claim" "claim"
            , DiagnosticSubject "shown-contributors" "1"
            , DiagnosticSubject "total-contributors" "2"
            ]
      length (diagnosticLocations diagnostic) @?= 1
    diagnostics ->
      assertFailure
        ("expected one partial-View diagnostic: " <> show diagnostics)

fullViewTest :: Assertion
fullViewTest = do
  report <- inspectText (ViewByName "Full") assertedModel
  assertBool
    "a complete View must not emit partial-claim information"
    ("o2i.amx.profile.collective.view-partial" `notElem` diagnosticCodes report)

repeatedPresentationCountTest :: Assertion
repeatedPresentationCountTest = do
  report <- inspectText (ViewByName "Repeated") assertedModel
  case diagnosticsList (reportDiagnostics report) of
    [diagnostic] ->
      diagnosticSubjects diagnostic
        @?= [ DiagnosticSubject "collective-claim" "claim"
            , DiagnosticSubject "shown-contributors" "1"
            , DiagnosticSubject "total-contributors" "2"
            ]
    diagnostics ->
      assertFailure
        ("expected one deduplicated partial-View diagnostic: "
           <> show diagnostics)

annotationNonSemanticsTest :: Assertion
annotationNonSemanticsTest = do
  report <- inspectText (ViewByName "Partial") assertedModel
  diagnosticCodes report @?= ["o2i.amx.profile.collective.view-partial"]
  case diagnosticsList (reportDiagnostics report) of
    [diagnostic] ->
      diagnosticSubjects diagnostic
        @?= [ DiagnosticSubject "collective-claim" "claim"
            , DiagnosticSubject "shown-contributors" "1"
            , DiagnosticSubject "total-contributors" "2"
            ]
    _ -> assertFailure "expected one partial-View diagnostic"

junctionChainTest :: Assertion
junctionChainTest = do
  report <- inspectText (ViewByName "Scope") junctionChainModel
  assertBool
    "Junction chain defect must be present"
    ("o2i.amx.profile.collective.junction-chain" `elem` diagnosticCodes report)

duplicateContributorTest :: Assertion
duplicateContributorTest = do
  report <- inspectText (ViewByName "Scope") duplicateContributorModel
  assertBool
    "duplicate contributor defect must be present"
    ("o2i.amx.profile.collective.contributor-duplicate"
       `elem` diagnosticCodes report)

selfParticipationTest :: Assertion
selfParticipationTest = do
  report <- inspectText (ViewByName "Scope") selfParticipationModel
  assertBool
    "self-participation defect must be present"
    ("o2i.amx.profile.collective.self-participation"
       `elem` diagnosticCodes report)

unknownParticipantTest :: Assertion
unknownParticipantTest = do
  report <- inspectText (ViewByName "Scope") unknownParticipantModel
  assertBool
    "unresolved endpoint defect must be present"
    ("o2i.amx.profile.collective.endpoint-unresolved"
       `elem` diagnosticCodes report)
  assertBool
    "unresolved endpoint defect must retain source provenance"
    (all
       (not . null . diagnosticLocations)
       (diagnosticsList (reportDiagnostics report)))
  case filter
         ((== "o2i.amx.profile.collective.endpoint-unresolved")
            . diagnosticCodeText
            . diagnosticCode)
         (diagnosticsList (reportDiagnostics report)) of
    [diagnostic] ->
      assertBool
        "unresolved endpoint must point to the persisted source reference"
        (any isSourceAttribute (diagnosticLocations diagnostic))
    diagnostics ->
      assertFailure ("expected one unresolved endpoint: " <> show diagnostics)
  where
    isSourceAttribute location =
      case locationTarget location of
        AttributeTarget name -> qNameLocalName name == "source"
        _ -> False

ambiguousParticipantTest :: Assertion
ambiguousParticipantTest = do
  report <- inspectText (ViewByName "Scope") ambiguousParticipantModel
  assertBool
    "ambiguous endpoint defect must be present"
    ("o2i.amx.profile.collective.endpoint-ambiguous"
       `elem` diagnosticCodes report)
  case filter
         ((== "o2i.amx.profile.collective.endpoint-ambiguous")
            . diagnosticCodeText
            . diagnosticCode)
         (diagnosticsList (reportDiagnostics report)) of
    [diagnostic] ->
      assertBool
        "ambiguous endpoint must point to the persisted source reference"
        (any isSourceAttribute (diagnosticLocations diagnostic))
    diagnostics ->
      assertFailure ("expected one ambiguous endpoint: " <> show diagnostics)
  where
    isSourceAttribute location =
      case locationTarget location of
        AttributeTarget name -> qNameLocalName name == "source"
        _ -> False

nonStrategyParticipantTest :: Assertion
nonStrategyParticipantTest = do
  environment <- environmentFor "Scope" nonStrategyParticipantModel
  case collectiveRawClaims (buildCollectiveIndex environment) of
    [claim] ->
      rawContributors (claimedProposition claim)
        @?= [RawNodeId "mission", RawNodeId "contributor-b"]
    claims ->
      assertFailure ("expected one projected collective claim: " <> show claims)
  report <- inspectText (ViewByName "Scope") nonStrategyParticipantModel
  assertBool
    "AMX must not steal format-neutral participant typing"
    (all
       (/= "o2i.amx.profile.collective.participant-type")
       (diagnosticCodes report))
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed

incompleteCandidateTest :: Assertion
incompleteCandidateTest = do
  environment <- environmentFor "Scope" incompleteCandidateModel
  collectiveRawClaims (buildCollectiveIndex environment) @?= []
  report <- inspectText (ViewByName "Scope") incompleteCandidateModel
  diagnosticCodes report @?= ["o2i.amx.profile.collective.target"]
  stageState ProfileStage report @?= StageFailed

directBinaryRealizesTest :: Assertion
directBinaryRealizesTest = do
  report <- inspectText (ViewByName "Scope") directBinaryRealizesModel
  diagnosticCodes report @?= ["o2i.structure.relation-unknown"]
  stageState StructureStage report @?= StageFailed

outsideScopeTest :: Assertion
outsideScopeTest = do
  report <- inspectText (ViewByName "Scope") outsideScopeModel
  assertBool
    "unreached collective defects must not leak"
    (all
       (not . Text.isPrefixOf "o2i.amx.profile.collective.")
       (diagnosticCodes report))
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed

participantOnlyScopeTest :: Assertion
participantOnlyScopeTest = do
  report <-
    inspectText (ViewByName "Participant only") participantOnlyScopeModel
  assertBool
    "an independently shown Strategy must not pull an unshown claim into scope"
    (all
       (not . Text.isPrefixOf "o2i.amx.profile.collective.")
       (diagnosticCodes report))
  stageState ProfileStage report @?= StagePassed

reportDeterminismTest :: Assertion
reportDeterminismTest = do
  first <- inspectText (ViewByName "Partial") assertedModel
  second <- inspectText (ViewByName "Partial") assertedModel
  renderInspectionReportJSON first @?= renderInspectionReportJSON second

genericTypeFallbackTest :: Text -> [Text] -> Assertion
genericTypeFallbackTest input expectedCodes = do
  environment <- environmentFor "Scope" input
  assertBool
    "generic structured proposition entered collective dispatch"
    (null (collectiveObservations (buildCollectiveIndex environment)))
  report <- inspectText (ViewByName "Scope") input
  diagnosticCodes report @?= expectedCodes
  assertBool
    "generic type metadata was misclassified as a collective defect"
    (all
       (not . Text.isPrefixOf "o2i.amx.profile.collective.")
       (diagnosticCodes report))
  assertBool
    "every generic Profile defect must retain source provenance"
    (all
       (not . null . diagnosticLocations)
       (diagnosticsList (reportDiagnostics report)))
  stageState ProfileStage report @?= StageFailed

rejects :: Text -> [Text] -> Assertion
rejects input expectedCodes = do
  report <- inspectText (ViewByName "Scope") input
  diagnosticCodes report @?= expectedCodes
  assertBool
    "every reached Profile defect must retain source provenance"
    (all
       (not . null . diagnosticLocations)
       (diagnosticsList (reportDiagnostics report)))
  stageState ProfileStage report @?= StageFailed

stageState :: InspectionStage -> InspectionReport -> StageState
stageState stage report =
  case filter
         ((== stage) . reportedStage)
         (stageReportsList (reportStageReports report)) of
    [stageReport] -> reportedState stageReport
    _ -> error "expected one report for each Inspection stage"

reasonsFor :: OccurrenceId -> [OccurrenceProvenance] -> [InclusionReason]
reasonsFor occurrence entries =
  case [ NonEmpty.toList (provenanceReasons entry)
       | entry <- entries
       , provenanceOccurrenceId entry == occurrence
       ] of
    [reasons] -> reasons
    _ -> []

environmentFor :: Text -> Text -> IO Environment
environmentFor viewName input =
  case decodeAMX (source input) of
    DecodePassed _ document ->
      case resolveAMXView document (ViewByName viewName) of
        ViewPassed _ selected -> pure (buildEnvironment document selected)
        ViewFailed _ defects ->
          assertFailure ("unexpected View defects: " <> show defects)
    DecodeUnavailable _ defects ->
      assertFailure ("unexpected Decode defects: " <> show defects)
    DecodeRejected _ defects ->
      assertFailure ("unexpected Decode rejection: " <> show defects)

elementById :: Text -> [AMXElement] -> AMXElement
elementById identifier elements =
  case filter ((== Just identifier) . elementId) elements of
    [found] -> found
    matches ->
      error
        ("expected one element "
           <> Text.unpack identifier
           <> ", found "
           <> show (length matches))
