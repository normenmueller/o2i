{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Focused collective Strategy-realization validation tests.
module O2I.Test.Collective
  ( collectiveTests
  ) where

import Data.List (permutations)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Test.Support
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

collectiveTests :: TestTree
collectiveTests =
  testGroup
    "collective Strategy realization"
    [ testCase
        "valid Asserted collective claim constructs one opaque witness"
        validCollectiveTest
    , testCase
        "direct binary realizes remains outside the relation registry"
        directRealizesInadmissibleTest
    , testCase
        "valid Candidate is diagnosed separately and constructs no witness"
        validCandidateTest
    , testCase
        "Candidate collective resolves a Candidate contributor diagnostically"
        candidateCollectiveCandidateContributorTest
    , testCase
        "Candidate collective resolves a Candidate target diagnostically"
        candidateCollectiveCandidateTargetTest
    , testCase
        "Candidate participant diagnostics retain role and stable order"
        candidateCollectiveMultipleCandidateParticipantsTest
    , testCase
        "Asserted collective rejects a Candidate contributor precisely"
        assertedCollectiveCandidateContributorTest
    , testCase
        "Asserted collective rejects a Candidate target precisely"
        assertedCollectiveCandidateTargetTest
    , testCase
        "Candidate semantic deficiencies are retained without a witness"
        candidateIssueTest
    , testCase
        "Asserted contributor evidence deficiencies are errors"
        assertedContributionErrorTest
    , testCase
        "macro and collective semantic errors accumulate"
        macroAndCollectiveErrorAccumulationTest
    , testCase
        "collective coverage is separate from individual contribution"
        collectiveCoverageTest
    , testCase
        "collective Fit obligations accumulate independently"
        collectiveFitTest
    , tradeOffSetTests
    , testCase
        "target compatibility evidence is bound to every contributor"
        contributorCompatibilityTest
    , testCase
        "missing and ambiguous Fit references are distinct"
        collectiveFitReferenceTest
    , testCase
        "contributor lower bound and distinctness accumulate"
        contributorCardinalityTest
    , testCase
        "all Candidate structural defects are fatal"
        candidateStructuralFailureTest
    , testCase
        "target self-participation is rejected"
        contributorTargetSeparationTest
    , testCase
        "unknown and non-Strategy contributors are rejected"
        contributorTypingTest
    , testCase "unknown and non-Strategy targets are rejected" targetTypingTest
    , testCase "claim occurrence identities are unique" claimIdentityTest
    , testCase "blank claim and Fit identities are rejected" blankIdentityTest
    , testCase
        "independent structural and semantic errors accumulate"
        independentErrorAccumulationTest
    , testCase
        "fatal Asserted errors retain independent Candidate diagnostics"
        fatalErrorRetainsCandidateTest
    , testCase
        "Context errors retain blocked collective Candidate diagnostics"
        contextErrorRetainsBlockedCandidateTest
    , testCase
        "Context errors retain blocked contribution Candidate diagnostics"
        contextErrorRetainsBlockedContributionCandidateTest
    , testCase
        "Context errors retain contribution structural diagnostics"
        contextErrorRetainsContributionStructureTest
    , testCase
        "Context Candidates preserve available collective Candidate semantics"
        contextCandidatePreservesCollectiveSemanticsTest
    , collectiveContributionTests
    ]

collectiveContributionTests :: TestTree
collectiveContributionTests =
  testGroup
    "collective Strategy contribution"
    [ testCase
        "open Candidate requires rationale but no Primitive graph"
        openContributionCandidateTest
    , testCase
        "closed Candidate may omit its Primitive graph"
        closedContributionCandidateTest
    , testCase
        "closed Asserted contribution constructs one homogeneous witness"
        assertedContributionWitnessTest
    , testCase
        "Asserted contribution rejects Open participant completeness"
        assertedOpenContributionTest
    , testCase
        "supplied Candidate graph is fully diagnosed and never witnessed"
        candidateMixedContributionGraphTest
    , testCase
        "Candidate requires a non-empty provenance-bearing rationale"
        candidateContributionRationaleTest
    , testCase
        "Asserted contribution requires a Primitive graph"
        assertedContributionGraphRequiredTest
    , testCase
        "Candidate graph accumulates provenance and topology diagnostics"
        candidateContributionTopologyTest
    , testCase
        "Action contribution graph is an independent closed mode"
        assertedActionContributionWitnessTest
    , testCase
        "contribution evidence is exactly bound to its proposition"
        contributionBindingTest
    , testCase
        "missing and ambiguous contribution evidence references are distinct"
        contributionEvidenceReferenceTest
    , testCase
        "family claim identities are globally unique"
        collectiveFamilyIdentityTest
    , testCase
        "finding-free Candidate preserves independent Asserted aggregates"
        collectiveRegistryCandidatePreservesAssertedTest
    , testCase
        "fatal family error suppresses every aggregate projection"
        collectiveRegistryFatalErrorSuppressesAggregatesTest
    , testCase
        "registry preserves interleaved Candidate source order"
        collectiveRegistryCandidateOrderTest
    , testCase
        "registry Candidate routing is occurrence-exact"
        collectiveRegistryCandidateOccurrenceTest
    , testCase
        "registry work accounts for every routed source"
        collectiveRegistryRoutingWorkTest
    , testCase
        "registry identity work accounts for repeated claim probes"
        collectiveRegistryIdentityWorkTest
    , testCase
        "registry Candidate work counts nodes and edges truthfully"
        collectiveRegistryCandidateWorkTest
    , testCase
        "contribution provenance binding is exact and observable"
        contributionProvenanceBindingTest
    , testCase
        "contribution work is operation-bound and truthful"
        contributionWorkTest
    , testCase
        "unrelated formulation size affects only one-time preparation"
        contributionFormulationWorkTest
    , QC.testProperty
        "participant order does not change collective validity"
        contributionParticipantOrderProperty
    ]

tradeOffSetTests :: TestTree
tradeOffSetTests =
  testGroup
    "validated Trade-off set semantics"
    [ QC.testProperty
        "Fit-evidence permutations do not change Fit"
        fitPermutationInvariantProperty
    , QC.testProperty
        "formulation permutations do not change Fit"
        formulationPermutationInvariantProperty
    , QC.testProperty
        "repeated Fit occurrences do not change Fit"
        duplicateOccurrenceInvariantProperty
    , testCase
        "repeated formulation occurrences do not change Fit"
        duplicateFormulationOccurrenceTest
    , testCase "surrounding whitespace does not change Fit" whitespaceTest
    , testCase "missing Trade-offs do not match" missingTradeOffTest
    , testCase "additional Trade-offs do not match" additionalTradeOffTest
    , testCase "empty and blank Trade-offs do not match" emptyTradeOffTest
    , testCase
        "different Trade-off content does not match"
        differingTradeOffTest
    ]

openContributionCandidateTest :: Assertion
openContributionCandidateTest = do
  let assessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence {rawContributionPrimitiveGraph = Nothing}]
          [ candidateClaim
              contributionProposition {rawContributionCompleteness = Open}
          ]
  assessmentCollectiveContributionErrors assessment @?= []
  assessmentCandidatePropositions assessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyContributionFamily
            contributionClaimId
        ]
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] -> candidateCollectiveContributionIssues candidate @?= []
    candidates ->
      assertFailure
        ("expected one contribution Candidate, got " ++ show (length candidates))
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Nothing -> assertFailure "Candidate assessment lost its validated aggregate"
    Just validated ->
      assertBool
        "Candidate constructed semantic contribution witness"
        (null (collectiveStrategyContributions validated))

closedContributionCandidateTest :: Assertion
closedContributionCandidateTest = do
  let assessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence {rawContributionPrimitiveGraph = Nothing}]
          [candidateClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] -> candidateCollectiveContributionIssues candidate @?= []
    _ -> assertFailure "closed contribution Candidate was not retained"

assertedContributionWitnessTest :: Assertion
assertedContributionWitnessTest = do
  let assessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence]
          [assertedClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Nothing -> assertFailure "valid contribution did not validate"
    Just validated ->
      case collectiveStrategyContributions validated of
        [contribution] -> do
          collectiveContributionId contribution @?= contributionClaimId
          fmap contextRefId (collectiveContributionParticipants contribution)
            @?= contributorOneId
            NonEmpty.:| [contributorTwoId]
          contextRefId (collectiveContributionTarget contribution)
            @?= strategyId
          collectiveContributionEvidenceReference contribution
            @?= contributionEvidenceRef
          let graph = collectiveContributionPrimitiveGraph contribution
          contributionGraphMode graph @?= KeyResultContributionGraph
          contributionGraphNodes graph
            @?= contributorOneKeyResultId
            NonEmpty.:| [contributorTwoKeyResultId, strategyKeyResultId]
          fmap snd (contributionGraphOccurrences graph)
            @?= contributorOneTargetKeyResultEdge
            NonEmpty.:| [contributorTwoTargetKeyResultEdge]
          contributionGraphRationaleReference graph @?= contributionRationaleRef
          contributionGraphProvenance graph @?= "source://joint-mechanism"
        contributions ->
          assertFailure
            ("expected one contribution witness, got "
               ++ show (length contributions))

assertedOpenContributionTest :: Assertion
assertedOpenContributionTest = do
  let proposition = contributionProposition {rawContributionCompleteness = Open}
      assessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence]
          [assertedClaim proposition]
  assessmentCollectiveContributionErrors assessment
    @?= [ CollectiveContributionStructuralError
            (AssertedOpenCollectiveFanIn
               CollectiveStrategyContributionFamily
               contributionClaimId)
        ]

candidateMixedContributionGraphTest :: Assertion
candidateMixedContributionGraphTest = do
  let mixed =
        contributionEvidence
          { rawContributionPrimitiveGraph =
              Just
                (RawKeyResultContributionGraph
                   contributionGraph
                     { rawContributionGraphNodes =
                         rawContributionGraphNodes contributionGraph
                           ++ [contributorTwoActionId]
                     , rawContributionGraphEdges =
                         rawContributionGraphEdges contributionGraph
                           ++ [contributorTwoTargetActionEdge]
                     })
          }
      assessment =
        assessContributionModel
          completeCollectiveGraph
          [mixed]
          [candidateClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] -> do
      let issues = candidateCollectiveContributionIssues candidate
      assertBool
        "mixed node kind was not diagnosed"
        (InvalidContributionGraphNodeKind
           KeyResultContributionGraph
           contributorTwoActionId
           `elem` issues)
      assertBool
        "mixed edge mode was not diagnosed"
        (ContributionGraphEdgeModeMismatch
           KeyResultContributionGraph
           contributorTwoTargetActionEdge
           `elem` issues)
    _ -> assertFailure "diagnostic Candidate was not retained"

candidateContributionRationaleTest :: Assertion
candidateContributionRationaleTest = do
  let evidence =
        contributionEvidence
          { rawJointContributionRationales = []
          , rawContributionPrimitiveGraph = Nothing
          }
      assessment =
        assessContributionModel
          coverageGapGraph
          [evidence]
          [candidateClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] ->
      candidateCollectiveContributionIssues candidate
        @?= [MissingJointContributionRationale]
    _ -> assertFailure "invalid rationale Candidate was not retained"

assertedContributionGraphRequiredTest :: Assertion
assertedContributionGraphRequiredTest = do
  let evidence = contributionEvidence {rawContributionPrimitiveGraph = Nothing}
      assessment =
        assessContributionModel
          coverageGapGraph
          [evidence]
          [assertedClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment
    @?= [ AssertedCollectiveContributionIssue
            contributionClaimId
            AssertedCollectiveContributionMissingPrimitiveGraph
        ]

candidateContributionTopologyTest :: Assertion
candidateContributionTopologyTest = do
  let graph =
        contributionGraph
          { rawContributionGraphProvenance = "source://other-rationale"
          , rawContributionGraphEdges = [contributorOneTargetKeyResultEdge]
          }
      evidence =
        contributionEvidence
          { rawContributionPrimitiveGraph =
              Just (RawKeyResultContributionGraph graph)
          }
      assessment =
        assessContributionModel
          coverageGapGraph
          [evidence]
          [candidateClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] -> do
      let issues = candidateCollectiveContributionIssues candidate
      assertBool
        "provenance mismatch was not diagnosed"
        (ContributionGraphProvenanceMismatch contributionRationaleRef
           `elem` issues)
      assertBool
        "disconnected graph was not diagnosed"
        (DisconnectedContributionPrimitiveGraph `elem` issues)
      assertBool
        "missing participant reachability was not diagnosed"
        (ContributionGraphParticipantCannotReachTarget contributorTwoId
           `elem` issues)
    _ -> assertFailure "invalid topology Candidate was not retained"

assertedActionContributionWitnessTest :: Assertion
assertedActionContributionWitnessTest = do
  let assessment =
        assessContributionModel
          actionContributionRawGraph
          [actionContributionEvidence]
          [assertedClaim contributionProposition]
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Just validated ->
      case collectiveStrategyContributions validated of
        [contribution] ->
          contributionGraphMode
            (collectiveContributionPrimitiveGraph contribution)
            @?= ActionContributionGraph
        _ -> assertFailure "expected one Action contribution"
    Nothing -> assertFailure "valid Action contribution did not validate"

contributionBindingTest :: Assertion
contributionBindingTest = do
  let misbound =
        contributionEvidence
          { rawContributionEvidenceParticipants = [contributorOneId]
          , rawContributionEvidenceTarget = contributorTwoId
          }
      assessment =
        assessContributionModel
          coverageGapGraph
          [misbound]
          [assertedClaim contributionProposition]
      issues = assessmentCollectiveContributionErrors assessment
  assertBool
    "participant binding mismatch was not fatal"
    (AssertedCollectiveContributionIssue
       contributionClaimId
       CollectiveContributionParticipantsMismatch
       `elem` issues)
  assertBool
    "target binding mismatch was not fatal"
    (AssertedCollectiveContributionIssue
       contributionClaimId
       (CollectiveContributionTargetMismatch strategyId contributorTwoId)
       `elem` issues)

contributionEvidenceReferenceTest :: Assertion
contributionEvidenceReferenceTest = do
  let claim = assertedClaim contributionProposition
      missingAssessment = assessContributionModel coverageGapGraph [] [claim]
      ambiguousAssessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence, contributionEvidence]
          [claim]
      expected issue =
        [AssertedCollectiveContributionIssue contributionClaimId issue]
  assessmentCollectiveContributionErrors missingAssessment
    @?= expected
          (CollectiveContributionEvidenceNotFound contributionEvidenceRef)
  assessmentCollectiveContributionErrors ambiguousAssessment
    @?= expected
          (CollectiveContributionEvidenceAmbiguous contributionEvidenceRef)
  case assessmentCollectiveContributionWork ambiguousAssessment of
    Nothing -> assertFailure "ambiguous contribution work was not retained"
    Just work -> do
      contributionEvidenceBucketProbes work @?= 1
      contributionEvidencePayloadReads work @?= 0

collectiveFamilyIdentityTest :: Assertion
collectiveFamilyIdentityTest = do
  let contribution =
        contributionProposition {rawContributionId = collectiveClaimId}
      assessment =
        assessMixedCollectiveModel
          coverageGapGraph
          [ CollectiveStrategyRealizationEvidence completeFit
          , CollectiveStrategyContributionEvidence contributionEvidence
          ]
          [ CollectiveStrategyRealizationClaim assertedCollective
          , CollectiveStrategyContributionClaim (candidateClaim contribution)
          ]
  case modelAssessmentStatus assessment of
    SemanticsRejected errors -> do
      let identityErrors =
            filter isCollectiveIdentityError (NonEmpty.toList errors)
      identityErrors
        @?= [ CollectiveSemanticError
                (DuplicateCollectiveFanInClaimId collectiveClaimId)
            ]
    _ -> assertFailure "cross-family duplicate identity was accepted"
  assessmentCandidatePropositions assessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyContributionFamily
            collectiveClaimId
        ]
  case assessmentValidatedCollectiveStrategyRealizations assessment of
    Nothing -> pure ()
    Just _ -> assertFailure "global rejection exposed realization witnesses"
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Nothing -> pure ()
    Just _ -> assertFailure "global rejection exposed contribution witnesses"

collectiveRegistryCandidatePreservesAssertedTest :: Assertion
collectiveRegistryCandidatePreservesAssertedTest = do
  let assessment =
        assessMixedCollectiveModel
          completeMixedCollectiveGraph
          [ CollectiveStrategyRealizationEvidence completeFit
          , CollectiveStrategyContributionEvidence contributionEvidence
          ]
          [ CollectiveStrategyRealizationClaim assertedCollective
          , CollectiveStrategyContributionClaim
              (candidateClaim contributionProposition)
          ]
  case modelAssessmentStatus assessment of
    SemanticsPending _ -> pure ()
    _ -> assertFailure "finding-free Candidate did not keep semantics pending"
  case assessmentValidatedCollectiveStrategyRealizations assessment of
    Nothing -> assertFailure "Candidate suppressed independent realization"
    Just validated ->
      fmap collectiveRealizationId (collectiveStrategyRealizations validated)
        @?= [collectiveClaimId]
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Nothing -> assertFailure "Candidate suppressed validated contribution set"
    Just validated ->
      assertBool
        "Candidate constructed a contribution witness"
        (null (collectiveStrategyContributions validated))

collectiveRegistryFatalErrorSuppressesAggregatesTest :: Assertion
collectiveRegistryFatalErrorSuppressesAggregatesTest = do
  let invalidRealization =
        assertedClaim (collectiveProposition {rawTarget = missingId})
      assessment =
        assessMixedCollectiveModel
          completeMixedCollectiveGraph
          [ CollectiveStrategyRealizationEvidence completeFit
          , CollectiveStrategyContributionEvidence contributionEvidence
          ]
          [ CollectiveStrategyRealizationClaim invalidRealization
          , CollectiveStrategyContributionClaim
              (assertedClaim contributionProposition)
          ]
  case modelAssessmentStatus assessment of
    SemanticsRejected _ -> pure ()
    _ -> assertFailure "fatal family error did not reject model semantics"
  assessmentCollectiveContributionErrors assessment @?= []
  case assessmentValidatedCollectiveStrategyRealizations assessment of
    Nothing -> pure ()
    Just _ -> assertFailure "fatal family error exposed realization witnesses"
  case assessmentValidatedCollectiveStrategyContributions assessment of
    Nothing -> pure ()
    Just _ -> assertFailure "fatal family error exposed contribution witnesses"

isCollectiveIdentityError :: ModelSemanticError -> Bool
isCollectiveIdentityError semanticError =
  case semanticError of
    CollectiveSemanticError (DuplicateCollectiveFanInClaimId _) -> True
    _ -> False

collectiveRegistryCandidateOrderTest :: Assertion
collectiveRegistryCandidateOrderTest = do
  let assessment =
        assessMixedCollectiveModel
          coverageGapGraph
          [ CollectiveStrategyContributionEvidence contributionEvidence
          , CollectiveStrategyRealizationEvidence completeFit
          ]
          [ CollectiveStrategyContributionClaim
              (candidateClaim contributionProposition)
          , CollectiveStrategyRealizationClaim candidateCollective
          ]
  assessmentCandidatePropositions assessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyContributionFamily
            contributionClaimId
        , CandidateCollectiveProposition
            CollectiveStrategyRealizationFamily
            collectiveClaimId
        ]

collectiveRegistryCandidateOccurrenceTest :: Assertion
collectiveRegistryCandidateOccurrenceTest = do
  let duplicateCommitmentAssessment =
        assessCollectiveModel
          completeCollectiveGraph
          [completeFit]
          [assertedCollective, candidateCollective]
      malformed =
        candidateClaim
          (collectiveProposition {rawContributors = [contributorOneId]})
      interleavedAssessment =
        assessMixedCollectiveModel
          coverageGapGraph
          [ CollectiveStrategyRealizationEvidence completeFit
          , CollectiveStrategyContributionEvidence contributionEvidence
          ]
          [ CollectiveStrategyRealizationClaim malformed
          , CollectiveStrategyContributionClaim
              (candidateClaim contributionProposition)
          , CollectiveStrategyRealizationClaim candidateCollective
          ]
  assessmentCandidatePropositions duplicateCommitmentAssessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyRealizationFamily
            collectiveClaimId
        ]
  assessmentCandidatePropositions interleavedAssessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyContributionFamily
            contributionClaimId
        , CandidateCollectiveProposition
            CollectiveStrategyRealizationFamily
            collectiveClaimId
        ]

collectiveRegistryRoutingWorkTest :: Assertion
collectiveRegistryRoutingWorkTest = do
  let unrelatedContributions = map unrelatedContributionEvidence [1 .. 500]
      unrelatedFits = map unrelatedFitEvidence [1 .. 500]
      assessment =
        assessMixedCollectiveModel
          coverageGapGraph
          (CollectiveStrategyContributionEvidence contributionEvidence
             : map CollectiveStrategyContributionEvidence unrelatedContributions
             ++ map CollectiveStrategyRealizationEvidence unrelatedFits)
          [ CollectiveStrategyContributionClaim
              (assertedClaim contributionProposition)
          ]
      work = assessmentCollectiveRegistryPreparationWork assessment
  registryClaimSourceReads work @?= 1
  registryClaimIdentityProbes work @?= 1
  registryEvidenceSourceReads work @?= 1001
  registryFitEvidenceInsertions work @?= 500
  registryContributionEvidenceInsertions work @?= 501
  registryStructuralCandidateSourceReads work @?= 0
  registryCandidateEdgeInsertions work @?= 0

collectiveRegistryIdentityWorkTest :: Assertion
collectiveRegistryIdentityWorkTest = do
  let size = 500
      assessment =
        assessCollectiveModel
          completeCollectiveGraph
          [completeFit]
          (replicate size candidateCollective)
      work = assessmentCollectiveRegistryPreparationWork assessment
  registryClaimSourceReads work @?= size
  registryClaimIdentityProbes work @?= 2 * size - 1

collectiveRegistryCandidateWorkTest :: Assertion
collectiveRegistryCandidateWorkTest = do
  let size = 500
      nodeAssessment = assessContributionClaimModel size False
      edgeAssessment = assessContributionClaimModel size True
      nodeWork = assessmentCollectiveRegistryPreparationWork nodeAssessment
      edgeWork = assessmentCollectiveRegistryPreparationWork edgeAssessment
      baseAssessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence]
          [assertedClaim contributionProposition]
  registryStructuralCandidateSourceReads nodeWork @?= size
  registryCandidateEdgeInsertions nodeWork @?= 0
  registryStructuralCandidateSourceReads edgeWork @?= 2 * size
  registryCandidateEdgeInsertions edgeWork @?= size
  assessmentCollectiveContributionWork nodeAssessment
    @?= assessmentCollectiveContributionWork baseAssessment
  assessmentCollectiveContributionWork edgeAssessment
    @?= assessmentCollectiveContributionWork baseAssessment

contributionProvenanceBindingTest :: Assertion
contributionProvenanceBindingTest = do
  let exactProvenance = "  source://joint-mechanism  "
      rationale =
        contributionRationale {rawJointRationaleProvenance = exactProvenance}
      exactGraph =
        contributionGraph {rawContributionGraphProvenance = exactProvenance}
      exactEvidence =
        contributionEvidence
          { rawJointContributionRationales = [rationale]
          , rawContributionPrimitiveGraph =
              Just (RawKeyResultContributionGraph exactGraph)
          }
      mismatchEvidence =
        exactEvidence
          { rawContributionPrimitiveGraph =
              Just
                (RawKeyResultContributionGraph
                   exactGraph
                     { rawContributionGraphProvenance =
                         Text.strip exactProvenance
                     })
          }
      exactAssessment =
        assessContributionModel
          coverageGapGraph
          [exactEvidence]
          [assertedClaim contributionProposition]
      mismatchAssessment =
        assessContributionModel
          coverageGapGraph
          [mismatchEvidence]
          [assertedClaim contributionProposition]
  case assessmentValidatedCollectiveStrategyContributions exactAssessment of
    Just validated ->
      case collectiveStrategyContributions validated of
        [contribution] ->
          contributionGraphProvenance
            (collectiveContributionPrimitiveGraph contribution)
            @?= exactProvenance
        _ -> assertFailure "exact provenance did not produce one contribution"
    Nothing -> assertFailure "exact provenance did not validate"
  assessmentCollectiveContributionErrors mismatchAssessment
    @?= [ AssertedCollectiveContributionIssue
            contributionClaimId
            (ContributionGraphProvenanceMismatch contributionRationaleRef)
        ]

contributionWorkTest :: Assertion
contributionWorkTest = do
  let baseAssessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence]
          [assertedClaim contributionProposition]
      unrelated = map unrelatedContributionEvidence [1 .. 500]
      adversarialAssessment =
        assessContributionModel
          coverageGapGraph
          (contributionEvidence : unrelated)
          [assertedClaim contributionProposition]
  case assessmentCollectiveContributionPreparationWork adversarialAssessment of
    Nothing -> assertFailure "contribution preparation work was not retained"
    Just preparation -> do
      contributionEvidenceBundlesRead preparation @?= 501
      contributionEvidenceIndexInsertions preparation @?= 501
      contributionStrategyFormulationsRead preparation @?= 3
      contributionFormulationMemberInsertions preparation @?= 6
  case ( assessmentCollectiveContributionWork baseAssessment
       , assessmentCollectiveContributionWork adversarialAssessment) of
    (Just baseWork, Just adversarialWork) -> do
      adversarialWork @?= baseWork
      assertContributionWork baseWork
    _ -> assertFailure "contribution work was not retained"

contributionFormulationWorkTest :: Assertion
contributionFormulationWorkTest = do
  let size = 200
      baseAssessment =
        assessContributionModel
          coverageGapGraph
          [contributionEvidence]
          [assertedClaim contributionProposition]
      adversarialAssessment =
        assessContributionModelWith
          (collectiveFormulations ++ [unrelatedContributionFormulation size])
          (unrelatedContributionFormulationGraph size)
          [contributionEvidence]
          [assertedClaim contributionProposition]
  case modelAssessmentStatus adversarialAssessment of
    SemanticsRejected errors ->
      assertFailure ("adversarial formulation errors: " ++ show errors)
    _ -> pure ()
  case assessmentCollectiveContributionPreparationWork adversarialAssessment of
    Nothing -> assertFailure "contribution preparation work was not retained"
    Just preparation -> do
      contributionStrategyFormulationsRead preparation @?= 4
      contributionFormulationMemberInsertions preparation @?= 408
  assessmentCollectiveContributionWork adversarialAssessment
    @?= assessmentCollectiveContributionWork baseAssessment

assertContributionWork :: CollectiveContributionValidationWork -> Assertion
assertContributionWork work = do
  fanInClaimsRead (contributionStructuralWork work) @?= 1
  fanInParticipantDeclarationLookups (contributionStructuralWork work) @?= 2
  contributionEvidenceBucketProbes work @?= 1
  contributionEvidencePayloadReads work @?= 1
  contributionRationalesRead work @?= 1
  contributionNodeLookups work @?= 3
  contributionFormulationLookups work @?= 3
  contributionEdgeOccurrenceLookups work @?= 2
  assertBool
    "linear traversals visited an impossible number of nodes"
    (contributionTraversalNodeVisits work <= 6)

contributionParticipantOrderProperty :: QC.Property
contributionParticipantOrderProperty =
  QC.forAll (QC.elements (permutations [contributorOneId, contributorTwoId])) $ \participants ->
    let proposition =
          contributionProposition {rawContributionParticipants = participants}
        assessment =
          assessContributionModel
            coverageGapGraph
            [contributionEvidence]
            [assertedClaim proposition]
     in case assessmentValidatedCollectiveStrategyContributions assessment of
          Just validated ->
            case collectiveStrategyContributions validated of
              [contribution] ->
                fmap
                  contextRefId
                  (collectiveContributionParticipants contribution)
                  QC.=== NonEmpty.fromList participants
              _ -> QC.counterexample "expected one contribution" False
          Nothing ->
            QC.counterexample
              (show (assessmentCollectiveContributionErrors assessment))
              False

unrelatedContributionEvidence :: Int -> RawCollectiveContributionEvidence
unrelatedContributionEvidence ordinal =
  contributionEvidence
    { rawContributionEvidenceRef =
        CollectiveContributionEvidenceRef
          ("unrelated-evidence-" <> Text.pack (show ordinal))
    }

unrelatedFitEvidence :: Int -> RawCollectiveFitEvidence
unrelatedFitEvidence ordinal =
  completeFit
    { rawFitEvidenceRef =
        CollectiveFitEvidenceRef ("unrelated-fit-" <> Text.pack (show ordinal))
    }

fitPermutationInvariantProperty :: QC.Property
fitPermutationInvariantProperty =
  QC.forAll (QC.elements (permutations tradeOffValues)) $ \values ->
    tradeOffIssues targetTradeOffs values QC.=== []

formulationPermutationInvariantProperty :: QC.Property
formulationPermutationInvariantProperty =
  QC.forAll (QC.elements targetTradeOffPermutations) $ \values ->
    tradeOffIssues values tradeOffValues QC.=== []

duplicateOccurrenceInvariantProperty :: QC.Positive Int -> QC.Property
duplicateOccurrenceInvariantProperty (QC.Positive rawMultiplicity) =
  let multiplicity = 1 + rawMultiplicity `mod` 20
      values = concatMap (replicate multiplicity) tradeOffValues
   in tradeOffIssues targetTradeOffs values QC.=== []

duplicateFormulationOccurrenceTest :: Assertion
duplicateFormulationOccurrenceTest =
  tradeOffIssues
    ("avoid opaque decisions"
       NonEmpty.:| [ "avoid opaque decisions"
                   , "preserve human accountability"
                   , "reject unsupported channels"
                   ])
    tradeOffValues
    @?= []

whitespaceTest :: Assertion
whitespaceTest =
  tradeOffIssues
    ("  avoid opaque decisions "
       NonEmpty.:| [ "preserve human accountability\n"
                   , "\treject unsupported channels"
                   ])
    [ "  avoid opaque decisions "
    , "\tpreserve human accountability\n"
    , "reject unsupported channels  "
    ]
    @?= []

missingTradeOffTest :: Assertion
missingTradeOffTest =
  tradeOffIssues
    targetTradeOffs
    ["avoid opaque decisions", "preserve human accountability"]
    @?= [tradeOffMismatch]

additionalTradeOffTest :: Assertion
additionalTradeOffTest =
  tradeOffIssues
    targetTradeOffs
    (tradeOffValues ++ ["avoid unreviewed automation"])
    @?= [tradeOffMismatch]

emptyTradeOffTest :: Assertion
emptyTradeOffTest = do
  tradeOffIssues targetTradeOffs [] @?= [tradeOffMismatch]
  tradeOffIssues targetTradeOffs [" "] @?= [tradeOffMismatch]

differingTradeOffTest :: Assertion
differingTradeOffTest =
  tradeOffIssues
    targetTradeOffs
    [ "avoid opaque decisions"
    , "preserve human accountability"
    , "accept unsupported channels"
    ]
    @?= [tradeOffMismatch]

tradeOffIssues ::
     NonEmpty.NonEmpty Text -> [Text] -> [CollectiveStrategyRealizationError]
tradeOffIssues formulationTradeOffs fitTradeOffs =
  assessmentCollectiveErrors
    (assessCollectiveModelWith
       (collectiveFormulationsWithTradeOffs formulationTradeOffs)
       completeCollectiveGraph
       [completeFit {rawFitTargetTradeOffs = fitTradeOffs}]
       [assertedCollective])

tradeOffMismatch :: CollectiveStrategyRealizationError
tradeOffMismatch =
  AssertedCollectiveIssue collectiveClaimId CollectiveFitTradeOffsMismatch

targetTradeOffs :: NonEmpty.NonEmpty Text
targetTradeOffs =
  "avoid opaque decisions"
    NonEmpty.:| ["preserve human accountability", "reject unsupported channels"]

tradeOffValues :: [Text]
tradeOffValues = NonEmpty.toList targetTradeOffs

targetTradeOffPermutations :: [NonEmpty.NonEmpty Text]
targetTradeOffPermutations =
  [value NonEmpty.:| values | value:values <- permutations tradeOffValues]

validCollectiveTest :: Assertion
validCollectiveTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    case validateCollectiveStrategyRealizations
           semantic
           [completeFit]
           [assertedCollective] of
      Failure errors ->
        assertFailure ("unexpected collective errors: " ++ show errors)
      Success assessment -> do
        case collectiveStrategyRealizations assessment of
          [realization] -> do
            collectiveRealizationId realization @?= collectiveClaimId
            fmap contextRefId (collectiveContributors realization)
              @?= contributorOneId
              NonEmpty.:| [contributorTwoId]
            contextRefId (collectiveTarget realization) @?= strategyId
            collectiveFitEvidenceReference realization @?= fitEvidenceRef
            fmap
              (contextRefId . fst)
              (collectiveContributionEvidence realization)
              @?= [contributorOneId, contributorTwoId]
            contributionPremiseRelations realization
              @?= [ relationNameFor contributesStrategyKeyResultToKeyResult
                  , relationNameFor contributesStrategyActionToAction
                  ]
            assertBool
              "validated realization was not found by identity"
              (case lookupCollectiveStrategyRealization
                      assessment
                      collectiveClaimId of
                 Just _ -> True
                 Nothing -> False)
            fmap
              collectiveRealizationId
              (collectiveRealizationsForTarget
                 assessment
                 (collectiveTarget realization))
              @?= [collectiveClaimId]
          realizations ->
            assertFailure
              ("expected one collective realization, got "
                 ++ show (length realizations))

directRealizesInadmissibleTest :: Assertion
directRealizesInadmissibleTest = do
  lookupRelations (RelationName "strategy-realizes-strategy") @?= []
  lookupRelations (RelationName "realizes") @?= []
  relationNameFor contributesToStrategy
    @?= RelationName "strategy-contributes-to-strategy"

validCandidateTest :: Assertion
validCandidateTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \raw -> do
    let assessment =
          assessCollectiveModel raw [completeFit] [candidateCollective]
    assessmentCollectiveErrors assessment @?= []
    case assessmentValidatedCollectiveStrategyRealizations assessment of
      Nothing ->
        assertFailure "Candidate assessment lost validated Asserted set"
      Just validated ->
        assertBool
          "Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations validated))
    case assessmentCandidateCollectiveStrategyRealizations assessment of
      [candidate] -> do
        candidateCollectiveClaim candidate @?= candidateCollective
        candidateCollectiveIssues candidate @?= []
      candidates ->
        assertFailure
          ("expected one Candidate assessment, got " ++ show (length candidates))

candidateCollectiveCandidateContributorTest :: Assertion
candidateCollectiveCandidateContributorTest =
  assertCandidateParticipant
    [ CandidateParticipantSemanticsUnavailable
        CollectiveContributor
        candidateStrategyId
    ]
    collectiveProposition
      {rawContributors = [candidateStrategyId, contributorTwoId]}

candidateCollectiveCandidateTargetTest :: Assertion
candidateCollectiveCandidateTargetTest =
  assertCandidateParticipant
    [ CandidateParticipantSemanticsUnavailable
        CollectiveTarget
        candidateStrategyId
    ]
    collectiveProposition {rawTarget = candidateStrategyId}

candidateCollectiveMultipleCandidateParticipantsTest :: Assertion
candidateCollectiveMultipleCandidateParticipantsTest =
  assertCandidateParticipant
    [ CandidateParticipantSemanticsUnavailable
        CollectiveContributor
        candidateStrategyId
    , CandidateParticipantSemanticsUnavailable
        CollectiveContributor
        secondCandidateStrategyId
    , CandidateParticipantSemanticsUnavailable
        CollectiveTarget
        candidateTargetStrategyId
    ]
    collectiveProposition
      { rawContributors = [candidateStrategyId, secondCandidateStrategyId]
      , rawTarget = candidateTargetStrategyId
      }

assertedCollectiveCandidateContributorTest :: Assertion
assertedCollectiveCandidateContributorTest =
  assertAssertedParticipantDependency
    CollectiveContributor
    collectiveProposition
      {rawContributors = [candidateStrategyId, contributorTwoId]}

assertedCollectiveCandidateTargetTest :: Assertion
assertedCollectiveCandidateTargetTest =
  assertAssertedParticipantDependency
    CollectiveTarget
    collectiveProposition {rawTarget = candidateStrategyId}

assertCandidateParticipant ::
     [CollectiveStrategyRealizationIssue]
  -> RawCollectiveStrategyRealization
  -> Assertion
assertCandidateParticipant expectedIssues proposition = do
  let claim = candidateClaim proposition
      assessment = assessCollectiveClaimModel [claim]
  assessmentCollectiveErrors assessment @?= []
  case modelAssessmentStatus assessment of
    SemanticsPending _ -> pure ()
    _ -> assertFailure "Candidate participant did not keep semantics pending"
  case assessmentValidatedCollectiveStrategyRealizations assessment of
    Nothing -> pure ()
    Just validated ->
      assertBool
        "Candidate participant constructed a collective witness"
        (null (collectiveStrategyRealizations validated))
  case assessmentCandidateCollectiveStrategyRealizations assessment of
    [candidate] -> do
      candidateCollectiveClaim candidate @?= claim
      candidateCollectiveIssues candidate @?= expectedIssues
    candidates ->
      assertFailure
        ("expected one Candidate assessment, got " ++ show (length candidates))

assertAssertedParticipantDependency ::
     CollectiveParticipantRole -> RawCollectiveStrategyRealization -> Assertion
assertAssertedParticipantDependency role proposition = do
  let assessment = assessCollectiveClaimModel [assertedClaim proposition]
      expected =
        CollectiveStructuralError
          (AssertedCollectiveDependsOnCandidate
             collectiveClaimId
             role
             candidateStrategyId)
  assessmentCollectiveErrors assessment @?= [expected]
  case modelAssessmentStatus assessment of
    SemanticsRejected errors ->
      assertBool
        "precise Candidate dependency was absent from semantic rejection"
        (CollectiveSemanticError (CollectiveRegistryRealizationError expected)
           `elem` NonEmpty.toList errors)
    _ -> assertFailure "Asserted Candidate dependency did not reject semantics"
  case assessmentValidatedCollectiveStrategyRealizations assessment of
    Nothing -> pure ()
    Just _ ->
      assertFailure "Asserted Candidate dependency exposed collective witnesses"

candidateIssueTest :: Assertion
candidateIssueTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \raw -> do
    let assessment =
          assessCollectiveModel raw [completeFit] [candidateCollective]
    assessmentCollectiveErrors assessment @?= []
    case assessmentValidatedCollectiveStrategyRealizations assessment of
      Nothing ->
        assertFailure "Candidate assessment lost validated Asserted set"
      Just validated ->
        assertBool
          "invalid Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations validated))
    case assessmentCandidateCollectiveStrategyRealizations assessment of
      [candidate] ->
        candidateCollectiveIssues candidate
          @?= [ MissingContributorContribution contributorTwoId strategyId
              , UncoveredTargetAction strategyActionId
              ]
      candidates ->
        assertFailure
          ("expected one Candidate assessment, got " ++ show (length candidates))

assertedContributionErrorTest :: Assertion
assertedContributionErrorTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic ->
    assertCollectiveErrors
      [ AssertedCollectiveIssue
          collectiveClaimId
          (MissingContributorContribution contributorTwoId strategyId)
      , AssertedCollectiveIssue
          collectiveClaimId
          (UncoveredTargetAction strategyActionId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective])

macroAndCollectiveErrorAccumulationTest :: Assertion
macroAndCollectiveErrorAccumulationTest =
  case modelAssessmentStatus assessment of
    SemanticsRejected errors ->
      NonEmpty.toList errors
        @?= [ MacroEvidenceSemanticError
                (MissingMacroEvidence
                   (edge contributorTwoId contributesToStrategy strategyId))
            , CollectiveSemanticError
                (CollectiveRegistryRealizationError
                   (AssertedCollectiveIssue
                      collectiveClaimId
                      (MissingContributorContribution
                         contributorTwoId
                         strategyId)))
            , CollectiveSemanticError
                (CollectiveRegistryRealizationError
                   (AssertedCollectiveIssue
                      collectiveClaimId
                      (UncoveredTargetAction strategyActionId)))
            ]
    SemanticsPending _ ->
      assertFailure "invalid asserted evidence remained pending"
    SemanticsAccepted _ ->
      assertFailure "independent semantic defects were accepted"
  where
    assessment =
      assessCollectiveModel
        missingSecondContributionGraph
        [completeFit]
        [assertedCollective]

collectiveCoverageTest :: Assertion
collectiveCoverageTest =
  withCollectiveSemanticModel coverageGapGraph $ \semantic ->
    assertCollectiveErrors
      [ AssertedCollectiveIssue
          collectiveClaimId
          (UncoveredTargetAction strategyActionId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective])

collectiveFitTest :: Assertion
collectiveFitTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      (map
         (AssertedCollectiveIssue collectiveClaimId)
         [ CollectiveFitContributorsMismatch
         , CollectiveFitTargetMismatch strategyId contributorOneId
         , MissingMutualCoherencePair contributorOneId contributorTwoId
         , CollectiveFitGuidingPolicyMismatch
             strategyPrincipleId
             contributorOnePrincipleId
         , CollectiveFitTradeOffsMismatch
         , EmptyCollectiveFitEvidence ViableInteractionFit
         ])
      (validateCollectiveStrategyRealizations
         semantic
         [ invalidFit
             { rawFitContributors = [contributorOneId]
             , rawFitTarget = contributorOneId
             , rawMutualCoherenceEvidence = []
             , rawFitTargetGuidingPolicy = contributorOnePrincipleId
             , rawFitTargetTradeOffs = ["incompatible trade-off"]
             , rawViableInteractionEvidence = []
             }
         ]
         [assertedCollective])

contributorCompatibilityTest :: Assertion
contributorCompatibilityTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      (map
         (AssertedCollectiveIssue collectiveClaimId)
         [ InvalidContributorCompatibilityContributor ethosId
         , DuplicateContributorCompatibilityContributor contributorOneId
         , MissingContributorCompatibilityEvidence
             contributorTwoId
             GuidingPolicyCompatibilityFit
         , MissingContributorCompatibilityEvidence
             contributorTwoId
             TradeOffCompatibilityFit
         , EmptyContributorCompatibilityEvidence
             contributorOneId
             GuidingPolicyCompatibilityFit
         ])
      (validateCollectiveStrategyRealizations
         semantic
         [ completeFit
             { rawContributorCompatibilityEvidence =
                 [ RawContributorCompatibilityEvidence
                     contributorOneId
                     " "
                     "The contributor respects the target Trade-offs."
                 , RawContributorCompatibilityEvidence
                     contributorOneId
                     "The duplicate is otherwise complete."
                     "The duplicate is otherwise complete."
                 , RawContributorCompatibilityEvidence
                     ethosId
                     "The foreign participant cannot establish coverage."
                     "The foreign participant cannot establish coverage."
                 ]
             }
         ]
         [assertedCollective])

collectiveFitReferenceTest :: Assertion
collectiveFitReferenceTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic -> do
    assertCollectiveErrors
      [ AssertedCollectiveIssue
          collectiveClaimId
          (CollectiveFitEvidenceNotFound fitEvidenceRef)
      ]
      (validateCollectiveStrategyRealizations semantic [] [assertedCollective])
    assertCollectiveErrors
      [ AssertedCollectiveIssue
          collectiveClaimId
          (CollectiveFitEvidenceAmbiguous fitEvidenceRef)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit, completeFit]
         [assertedCollective])

contributorCardinalityTest :: Assertion
contributorCardinalityTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      (map
         CollectiveStructuralError
         [ TooFewCollectiveContributors collectiveClaimId
         , DuplicateCollectiveContributor collectiveClaimId contributorOneId
         ])
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedClaim
             (collectiveProposition
                {rawContributors = [contributorOneId, contributorOneId]})
         ])

candidateStructuralFailureTest :: Assertion
candidateStructuralFailureTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    mapM_ (assertCandidateFailure semantic) candidateStructuralCases
  where
    assertCandidateFailure semantic (proposition, expected) =
      assertCollectiveErrors
        (map CollectiveStructuralError expected)
        (validateCollectiveStrategyRealizations
           semantic
           [completeFit]
           [candidateClaim proposition])
    candidateStructuralCases =
      [ ( collectiveProposition {rawRealizationId = ClaimId " "}
        , [EmptyCollectiveRealizationClaimId])
      , ( collectiveProposition
            {rawCollectiveFitEvidence = CollectiveFitEvidenceRef " "}
        , [EmptyCollectiveFitEvidenceReference collectiveClaimId])
      , ( collectiveProposition {rawContributors = [contributorOneId]}
        , [TooFewCollectiveContributors collectiveClaimId])
      , ( collectiveProposition
            { rawContributors =
                [contributorOneId, contributorTwoId, contributorOneId]
            }
        , [DuplicateCollectiveContributor collectiveClaimId contributorOneId])
      , ( collectiveProposition
            {rawContributors = [contributorOneId, strategyId]}
        , [CollectiveContributorIsTarget collectiveClaimId strategyId])
      , ( collectiveProposition
            {rawContributors = [missingId, contributorTwoId]}
        , [ UnknownCollectiveParticipant
              collectiveClaimId
              CollectiveContributor
              missingId
          ])
      , ( collectiveProposition {rawContributors = [ethosId, contributorTwoId]}
        , [ NonStrategyCollectiveParticipant
              collectiveClaimId
              CollectiveContributor
              ethosId
              (ContextNodeKind Ethos)
          ])
      , ( collectiveProposition {rawTarget = missingId}
        , [ UnknownCollectiveParticipant
              collectiveClaimId
              CollectiveTarget
              missingId
          ])
      , ( collectiveProposition {rawTarget = ethosId}
        , [ NonStrategyCollectiveParticipant
              collectiveClaimId
              CollectiveTarget
              ethosId
              (ContextNodeKind Ethos)
          ])
      ]

contributorTargetSeparationTest :: Assertion
contributorTargetSeparationTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      [ CollectiveStructuralError
          (CollectiveContributorIsTarget collectiveClaimId strategyId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedClaim
             (collectiveProposition
                {rawContributors = [contributorOneId, strategyId]})
         ])

contributorTypingTest :: Assertion
contributorTypingTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      (map
         CollectiveStructuralError
         [ UnknownCollectiveParticipant
             collectiveClaimId
             CollectiveContributor
             missingId
         , NonStrategyCollectiveParticipant
             collectiveClaimId
             CollectiveContributor
             ethosId
             (ContextNodeKind Ethos)
         ])
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedClaim
             (collectiveProposition {rawContributors = [missingId, ethosId]})
         ])

targetTypingTest :: Assertion
targetTypingTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic -> do
    assertCollectiveErrors
      [ CollectiveStructuralError
          (UnknownCollectiveParticipant
             collectiveClaimId
             CollectiveTarget
             missingId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedClaim (collectiveProposition {rawTarget = missingId})])
    assertCollectiveErrors
      [ CollectiveStructuralError
          (NonStrategyCollectiveParticipant
             collectiveClaimId
             CollectiveTarget
             ethosId
             (ContextNodeKind Ethos))
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedClaim (collectiveProposition {rawTarget = ethosId})])

claimIdentityTest :: Assertion
claimIdentityTest =
  mapM_
    assertDuplicateIdentity
    [ [candidateCollective, candidateCollective]
    , [candidateCollective, candidateCollective, candidateCollective]
    , [candidateCollective, assertedCollective]
    , [assertedCollective, assertedCollective]
    ]
  where
    assertDuplicateIdentity claims =
      case modelAssessmentStatus
             (assessCollectiveModel completeCollectiveGraph [completeFit] claims) of
        SemanticsRejected errors ->
          NonEmpty.toList errors
            @?= [ CollectiveSemanticError
                    (DuplicateCollectiveFanInClaimId collectiveClaimId)
                ]
        _ -> assertFailure "duplicate collective identity was accepted"

blankIdentityTest :: Assertion
blankIdentityTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      (map
         CollectiveStructuralError
         [ EmptyCollectiveRealizationClaimId
         , EmptyCollectiveFitEvidenceReference (ClaimId " ")
         ])
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedClaim
             (collectiveProposition
                { rawRealizationId = ClaimId " "
                , rawCollectiveFitEvidence = CollectiveFitEvidenceRef ""
                })
         ])

independentErrorAccumulationTest :: Assertion
independentErrorAccumulationTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic ->
    assertCollectiveErrors
      [ CollectiveStructuralError
          (UnknownCollectiveParticipant
             (ClaimId "malformed-candidate")
             CollectiveContributor
             missingId)
      , CollectiveStructuralError
          (NonStrategyCollectiveParticipant
             (ClaimId "malformed-candidate")
             CollectiveContributor
             ethosId
             (ContextNodeKind Ethos))
      , AssertedCollectiveIssue
          collectiveClaimId
          (MissingContributorContribution contributorTwoId strategyId)
      , AssertedCollectiveIssue
          collectiveClaimId
          (UncoveredTargetAction strategyActionId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ candidateClaim
             (collectiveProposition
                { rawRealizationId = ClaimId "malformed-candidate"
                , rawContributors = [missingId, ethosId]
                })
         , assertedCollective
         ])

fatalErrorRetainsCandidateTest :: Assertion
fatalErrorRetainsCandidateTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \raw -> do
    let assertedReference = CollectiveFitEvidenceRef "missing-asserted-fit"
        candidateReference = CollectiveFitEvidenceRef "missing-candidate-fit"
        invalidAsserted =
          assertedClaim
            collectiveProposition
              { rawRealizationId = ClaimId "invalid-asserted"
              , rawCollectiveFitEvidence = assertedReference
              }
        diagnosticCandidate =
          candidateClaim
            collectiveProposition
              { rawRealizationId = ClaimId "diagnostic-candidate"
              , rawCollectiveFitEvidence = candidateReference
              }
        assessment =
          assessCollectiveModel raw [] [invalidAsserted, diagnosticCandidate]
        expectedErrors =
          [ AssertedCollectiveIssue
              (ClaimId "invalid-asserted")
              (CollectiveFitEvidenceNotFound assertedReference)
          ]
    assessmentCollectiveErrors assessment @?= expectedErrors
    case assessmentCandidateCollectiveStrategyRealizations assessment of
      [candidate] -> do
        candidateCollectiveClaim candidate @?= diagnosticCandidate
        candidateCollectiveIssues candidate
          @?= [CollectiveFitEvidenceNotFound candidateReference]
      candidates ->
        assertFailure
          ("expected one retained Candidate assessment, got "
             ++ show (length candidates))
    case assessmentValidatedCollectiveStrategyRealizations assessment of
      Nothing -> pure ()
      Just _ ->
        assertFailure "fatal collective assessment exposed aggregate witnesses"

contextErrorRetainsBlockedCandidateTest :: Assertion
contextErrorRetainsBlockedCandidateTest = do
  let assessment =
        assessCollectiveModelWith
          []
          completeCollectiveGraph
          [completeFit]
          [candidateCollective]
  assertBool
    "expected fatal Context errors"
    (not (null (assessmentInvariantErrors assessment)))
  case modelAssessmentStatus assessment of
    SemanticsRejected _ -> pure ()
    _ -> assertFailure "Context errors did not reject model semantics"
  assessmentCollectiveErrors assessment @?= []
  assessmentCandidatePropositions assessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyRealizationFamily
            collectiveClaimId
        ]
  assertBlockedCollectiveCandidate assessment

contextErrorRetainsBlockedContributionCandidateTest :: Assertion
contextErrorRetainsBlockedContributionCandidateTest = do
  let assessment =
        assessContextRejectedContribution
          (candidateClaim contributionProposition)
  assertBool
    "expected fatal Context errors"
    (not (null (assessmentInvariantErrors assessment)))
  assessmentCollectiveContributionErrors assessment @?= []
  assessmentCandidatePropositions assessment
    @?= [ CandidateCollectiveProposition
            CollectiveStrategyContributionFamily
            contributionClaimId
        ]
  case assessmentCandidateCollectiveStrategyContributions assessment of
    [candidate] ->
      candidateCollectiveContributionIssues candidate
        @?= [CollectiveContributionSemanticEvaluationBlocked]
    candidates ->
      assertFailure
        ("expected one blocked contribution Candidate, got "
           ++ show (length candidates))
  assessmentCollectiveContributionPreparationWork assessment @?= Nothing
  assessmentCollectiveContributionWork assessment @?= Nothing

contextErrorRetainsContributionStructureTest :: Assertion
contextErrorRetainsContributionStructureTest = do
  let proposition =
        contributionProposition
          {rawContributionParticipants = [contributorOneId]}
      assessment =
        assessContextRejectedContribution (candidateClaim proposition)
  assessmentCollectiveContributionErrors assessment
    @?= [ CollectiveContributionStructuralError
            (TooFewCollectiveFanInParticipants
               CollectiveStrategyContributionFamily
               contributionClaimId)
        ]

assessContextRejectedContribution ::
     Claim RawCollectiveStrategyContribution -> ModelAssessment
assessContextRejectedContribution claim =
  case validateStructure completeCollectiveGraph of
    StructureAccepted structure ->
      assessModelSemantics
        structure
        ModelSemanticsInput
          { modelStrategyClaims = []
          , modelCollectiveClaims = [CollectiveStrategyContributionClaim claim]
          , modelCollectiveEvidence =
              [CollectiveStrategyContributionEvidence contributionEvidence]
          }
    StructureModelRejected errors ->
      error ("blocked contribution fixture failed: " ++ show errors)
    StructureInternalFailure internal ->
      error
        ("blocked contribution fixture failed internally: " ++ show internal)

contextCandidatePreservesCollectiveSemanticsTest :: Assertion
contextCandidatePreservesCollectiveSemanticsTest =
  case validateClaimStructure claimGraph of
    StructureAccepted structure -> do
      let assessment =
            assessModelSemantics
              structure
              ModelSemanticsInput
                { modelStrategyClaims = map assertedClaim collectiveFormulations
                , modelCollectiveClaims =
                    [CollectiveStrategyRealizationClaim candidateCollective]
                , modelCollectiveEvidence =
                    [CollectiveStrategyRealizationEvidence completeFit]
                }
      assessmentInvariantErrors assessment @?= []
      assessmentCollectiveErrors assessment @?= []
      assessmentCandidatePropositions assessment
        @?= [ CandidateModelNode candidateContext
            , CandidateCollectiveProposition
                CollectiveStrategyRealizationFamily
                collectiveClaimId
            ]
      case modelAssessmentStatus assessment of
        SemanticsPending pending ->
          NonEmpty.toList pending
            @?= [ CandidateModelNode candidateContext
                , CandidateCollectiveProposition
                    CollectiveStrategyRealizationFamily
                    collectiveClaimId
                ]
        _ -> assertFailure "Context Candidates did not keep semantics pending"
      case assessmentCandidateCollectiveStrategyRealizations assessment of
        [candidate] -> do
          candidateCollectiveClaim candidate @?= candidateCollective
          candidateCollectiveIssues candidate @?= []
        candidates ->
          assertFailure
            ("expected one evaluated collective Candidate, got "
               ++ show (length candidates))
    StructureModelRejected errors ->
      assertFailure ("collective Candidate fixture failed: " ++ show errors)
    StructureInternalFailure internal ->
      assertFailure
        ("collective Candidate fixture failed internally: " ++ show internal)
  where
    candidateContext =
      RawContextNode (RawNodeId "candidate-unrelated-strategy") Strategy
    claimGraph =
      RawClaimGraph
        (map assertedClaim (rawNodes completeCollectiveGraph)
           ++ [candidateClaim candidateContext])
        (map assertedClaim (rawEdges completeCollectiveGraph))

assertBlockedCollectiveCandidate :: ModelAssessment -> Assertion
assertBlockedCollectiveCandidate assessment =
  case assessmentCandidateCollectiveStrategyRealizations assessment of
    [candidate] -> do
      candidateCollectiveClaim candidate @?= candidateCollective
      candidateCollectiveIssues candidate
        @?= [CollectiveSemanticEvaluationBlocked]
    candidates ->
      assertFailure
        ("expected one blocked collective Candidate, got "
           ++ show (length candidates))

validateCollectiveStrategyRealizations ::
     RawGraph
  -> [RawCollectiveFitEvidence]
  -> [Claim RawCollectiveStrategyRealization]
  -> Validation
       (NonEmpty.NonEmpty CollectiveStrategyRealizationError)
       ValidatedCollectiveStrategyRealizations
validateCollectiveStrategyRealizations raw fitEvidence claims =
  let assessment = assessCollectiveModel raw fitEvidence claims
   in case NonEmpty.nonEmpty (assessmentCollectiveErrors assessment) of
        Just errors -> Failure errors
        Nothing ->
          case assessmentValidatedCollectiveStrategyRealizations assessment of
            Just validated -> Success validated
            Nothing ->
              error
                "collective test fixture did not reach collective assessment"

assertCollectiveErrors ::
     [CollectiveStrategyRealizationError]
  -> Validation
       (NonEmpty.NonEmpty CollectiveStrategyRealizationError)
       ValidatedCollectiveStrategyRealizations
  -> Assertion
assertCollectiveErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid collective claim was accepted"

withCollectiveSemanticModel :: RawGraph -> (RawGraph -> Assertion) -> Assertion
withCollectiveSemanticModel raw action = action raw

assessCollectiveModel ::
     RawGraph
  -> [RawCollectiveFitEvidence]
  -> [Claim RawCollectiveStrategyRealization]
  -> ModelAssessment
assessCollectiveModel = assessCollectiveModelWith collectiveFormulations

assessCollectiveModelWith ::
     [RawStrategyFormulation]
  -> RawGraph
  -> [RawCollectiveFitEvidence]
  -> [Claim RawCollectiveStrategyRealization]
  -> ModelAssessment
assessCollectiveModelWith formulations raw fitEvidence claims =
  case validateStructure raw of
    StructureAccepted structure ->
      assessModelSemantics
        structure
        ModelSemanticsInput
          { modelStrategyClaims = map assertedClaim formulations
          , modelCollectiveClaims =
              map CollectiveStrategyRealizationClaim claims
          , modelCollectiveEvidence =
              map CollectiveStrategyRealizationEvidence fitEvidence
          }
    StructureModelRejected errors ->
      error ("collective fixture structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      error ("collective fixture internal failure: " ++ show internal)

assessCollectiveClaimModel ::
     [Claim RawCollectiveStrategyRealization] -> ModelAssessment
assessCollectiveClaimModel claims =
  case validateClaimStructure candidateParticipantClaimGraph of
    StructureAccepted structure ->
      assessModelSemantics
        structure
        ModelSemanticsInput
          { modelStrategyClaims = map assertedClaim collectiveFormulations
          , modelCollectiveClaims =
              map CollectiveStrategyRealizationClaim claims
          , modelCollectiveEvidence =
              [CollectiveStrategyRealizationEvidence completeFit]
          }
    StructureModelRejected errors ->
      error ("Candidate participant fixture failed: " ++ show errors)
    StructureInternalFailure internal ->
      error
        ("Candidate participant fixture failed internally: " ++ show internal)

contributionPremiseRelations :: CollectiveStrategyRealization -> [RelationName]
contributionPremiseRelations realization =
  [ rawEdgeRelation premise
  | (_, witnesses) <- collectiveContributionEvidence realization
  , witness <- NonEmpty.toList witnesses
  , premise <- NonEmpty.toList (witnessPremises witness)
  ]

collectiveClaimId :: ClaimId
collectiveClaimId = ClaimId "collective-realization"

fitEvidenceRef :: CollectiveFitEvidenceRef
fitEvidenceRef = CollectiveFitEvidenceRef "collective-fit"

collectiveProposition :: RawCollectiveStrategyRealization
collectiveProposition =
  RawCollectiveStrategyRealization
    { rawRealizationId = collectiveClaimId
    , rawContributors = [contributorOneId, contributorTwoId]
    , rawTarget = strategyId
    , rawRealizationCompleteness = Closed
    , rawCollectiveFitEvidence = fitEvidenceRef
    }

assertedCollective :: Claim RawCollectiveStrategyRealization
assertedCollective = assertedClaim collectiveProposition

candidateCollective :: Claim RawCollectiveStrategyRealization
candidateCollective = candidateClaim collectiveProposition

candidateStrategyId :: RawNodeId
candidateStrategyId = RawNodeId "candidate-collective-participant"

secondCandidateStrategyId :: RawNodeId
secondCandidateStrategyId = RawNodeId "second-candidate-collective-participant"

candidateTargetStrategyId :: RawNodeId
candidateTargetStrategyId = RawNodeId "candidate-collective-target"

candidateParticipantClaimGraph :: RawClaimGraph
candidateParticipantClaimGraph =
  RawClaimGraph
    { rawNodeClaims =
        map assertedClaim (rawNodes completeCollectiveGraph)
          ++ map
               (candidateClaim . (`RawContextNode` Strategy))
               [ candidateStrategyId
               , secondCandidateStrategyId
               , candidateTargetStrategyId
               ]
    , rawEdgeClaims = map assertedClaim (rawEdges completeCollectiveGraph)
    }

completeFit :: RawCollectiveFitEvidence
completeFit =
  RawCollectiveFitEvidence
    { rawFitEvidenceRef = fitEvidenceRef
    , rawFitContributors = [contributorOneId, contributorTwoId]
    , rawFitTarget = strategyId
    , rawMutualCoherenceEvidence =
        [ RawMutualCoherenceEvidence
            contributorOneId
            contributorTwoId
            "The contributor commitments are mutually coherent."
        ]
    , rawFitTargetGuidingPolicy = strategyPrincipleId
    , rawFitTargetTradeOffs =
        NonEmpty.toList (rawFormulationTradeOffs sampleStrategyFormulation)
    , rawContributorCompatibilityEvidence =
        [ RawContributorCompatibilityEvidence
            contributorOneId
            "The contributor complies with the target Guiding Policy."
            "The contributor respects the target Trade-offs."
        , RawContributorCompatibilityEvidence
            contributorTwoId
            "The contributor complies with the target Guiding Policy."
            "The contributor respects the target Trade-offs."
        ]
    , rawViableInteractionEvidence =
        ["The contributor actions have a viable interaction model."]
    }

invalidFit :: RawCollectiveFitEvidence
invalidFit = completeFit

completeCollectiveGraph :: RawGraph
completeCollectiveGraph =
  RawGraph
    (rawNodes sampleGraph ++ contributorNodes)
    (rawEdges sampleGraph
       ++ contributorInternalEdges
       ++ contributorContextEdges
       ++ [contributorOneTargetKeyResultEdge, contributorTwoTargetActionEdge])

missingSecondContributionGraph :: RawGraph
missingSecondContributionGraph =
  completeCollectiveGraph
    { rawEdges =
        filter
          (/= contributorTwoTargetActionEdge)
          (rawEdges completeCollectiveGraph)
    }

coverageGapGraph :: RawGraph
coverageGapGraph =
  missingSecondContributionGraph
    { rawEdges =
        contributorTwoTargetKeyResultEdge
          : rawEdges missingSecondContributionGraph
    }

completeMixedCollectiveGraph :: RawGraph
completeMixedCollectiveGraph =
  coverageGapGraph
    {rawEdges = contributorTwoTargetActionEdge : rawEdges coverageGapGraph}

contributorNodes :: [RawNode]
contributorNodes = contributorOneNodes ++ contributorTwoNodes

contributorOneNodes, contributorTwoNodes :: [RawNode]
contributorOneNodes = contributorStrategyNodes contributorOneIds

contributorTwoNodes = contributorStrategyNodes contributorTwoIds

contributorStrategyNodes :: ContributorIds -> [RawNode]
contributorStrategyNodes ids =
  [ RawContextNode (contributorStrategy ids) Strategy
  , RawPrimitiveNode (contributorDriver ids) (contributorStrategy ids) Driver
  , RawPrimitiveNode
      (contributorObjective ids)
      (contributorStrategy ids)
      Objective
  , RawPrimitiveNode
      (contributorPrinciple ids)
      (contributorStrategy ids)
      Principle
  , RawPrimitiveNode (contributorAction ids) (contributorStrategy ids) Action
  , RawPrimitiveNode
      (contributorKeyResult ids)
      (contributorStrategy ids)
      KeyResult
  ]

contributorInternalEdges :: [RawEdge]
contributorInternalEdges =
  concatMap contributorStrategyEdges [contributorOneIds, contributorTwoIds]

contributorStrategyEdges :: ContributorIds -> [RawEdge]
contributorStrategyEdges ids =
  [ edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      (contributorObjective ids)
  , edge
      (contributorDriver ids)
      groundsStrategyDriverToObjective
      (contributorObjective ids)
  , edge
      (contributorKeyResult ids)
      substantiatesStrategyKeyResultObjective
      (contributorObjective ids)
  , edge
      (contributorPrinciple ids)
      guidesStrategyPrincipleToAction
      (contributorAction ids)
  , edge
      (contributorAction ids)
      contributesStrategyActionToKeyResult
      (contributorKeyResult ids)
  ]

contributorContextEdges :: [RawEdge]
contributorContextEdges =
  [ edge contributorOneId contributesToStrategy strategyId
  , edge contributorTwoId contributesToStrategy strategyId
  ]

contributorOneTargetKeyResultEdge :: RawEdge
contributorOneTargetKeyResultEdge =
  edge
    contributorOneKeyResultId
    contributesStrategyKeyResultToKeyResult
    strategyKeyResultId

contributorTwoTargetActionEdge :: RawEdge
contributorTwoTargetActionEdge =
  edge contributorTwoActionId contributesStrategyActionToAction strategyActionId

contributorOneTargetActionEdge :: RawEdge
contributorOneTargetActionEdge =
  edge contributorOneActionId contributesStrategyActionToAction strategyActionId

contributorTwoTargetKeyResultEdge :: RawEdge
contributorTwoTargetKeyResultEdge =
  edge
    contributorTwoKeyResultId
    contributesStrategyKeyResultToKeyResult
    strategyKeyResultId

collectiveFormulations :: [RawStrategyFormulation]
collectiveFormulations =
  [ sampleStrategyFormulation
  , contributorFormulation contributorOneIds
  , contributorFormulation contributorTwoIds
  ]

collectiveFormulationsWithTradeOffs ::
     NonEmpty.NonEmpty Text -> [RawStrategyFormulation]
collectiveFormulationsWithTradeOffs tradeOffs =
  [ sampleStrategyFormulation {rawFormulationTradeOffs = tradeOffs}
  , contributorFormulation contributorOneIds
  , contributorFormulation contributorTwoIds
  ]

contributorFormulation :: ContributorIds -> RawStrategyFormulation
contributorFormulation ids =
  sampleStrategyFormulation
    { rawFormulationStrategy = contributorStrategy ids
    , rawFormulationDiagnosis = contributorDriver ids
    , rawFormulationIntent = contributorObjective ids
    , rawFormulationGuidingPolicy = contributorPrinciple ids
    , rawFormulationActions = contributorAction ids NonEmpty.:| []
    , rawFormulationKeyResults = contributorKeyResult ids NonEmpty.:| []
    }

data ContributorIds = ContributorIds
  { contributorStrategy :: RawNodeId
  , contributorDriver :: RawNodeId
  , contributorObjective :: RawNodeId
  , contributorPrinciple :: RawNodeId
  , contributorAction :: RawNodeId
  , contributorKeyResult :: RawNodeId
  }

contributorOneIds, contributorTwoIds :: ContributorIds
contributorOneIds =
  ContributorIds
    (RawNodeId "collective-contributor-one")
    (RawNodeId "collective-contributor-one-driver")
    (RawNodeId "collective-contributor-one-objective")
    (RawNodeId "collective-contributor-one-principle")
    (RawNodeId "collective-contributor-one-action")
    (RawNodeId "collective-contributor-one-key-result")

contributorTwoIds =
  ContributorIds
    (RawNodeId "collective-contributor-two")
    (RawNodeId "collective-contributor-two-driver")
    (RawNodeId "collective-contributor-two-objective")
    (RawNodeId "collective-contributor-two-principle")
    (RawNodeId "collective-contributor-two-action")
    (RawNodeId "collective-contributor-two-key-result")

contributorOneId, contributorTwoId :: RawNodeId
contributorOneId = contributorStrategy contributorOneIds

contributorTwoId = contributorStrategy contributorTwoIds

contributorOnePrincipleId :: RawNodeId
contributorOnePrincipleId = contributorPrinciple contributorOneIds

contributorOneKeyResultId, contributorTwoKeyResultId :: RawNodeId
contributorOneKeyResultId = contributorKeyResult contributorOneIds

contributorTwoKeyResultId = contributorKeyResult contributorTwoIds

contributorOneActionId, contributorTwoActionId :: RawNodeId
contributorOneActionId = contributorAction contributorOneIds

contributorTwoActionId = contributorAction contributorTwoIds

contributionClaimId :: ClaimId
contributionClaimId = ClaimId "collective-contribution"

contributionEvidenceRef :: CollectiveContributionEvidenceRef
contributionEvidenceRef =
  CollectiveContributionEvidenceRef "collective-contribution-evidence"

contributionRationaleRef :: JointContributionRationaleRef
contributionRationaleRef = JointContributionRationaleRef "joint-mechanism"

contributionProposition :: RawCollectiveStrategyContribution
contributionProposition =
  RawCollectiveStrategyContribution
    { rawContributionId = contributionClaimId
    , rawContributionParticipants = [contributorOneId, contributorTwoId]
    , rawContributionTarget = strategyId
    , rawContributionCompleteness = Closed
    , rawContributionEvidence = contributionEvidenceRef
    }

contributionRationale :: RawJointContributionRationale
contributionRationale =
  RawJointContributionRationale
    { rawJointRationaleRef = contributionRationaleRef
    , rawJointRationaleText =
        "The participants create one contribution through coordinated interaction."
    , rawJointRationaleProvenance = "source://joint-mechanism"
    }

contributionGraph :: RawBoundContributionGraph
contributionGraph =
  RawBoundContributionGraph
    { rawContributionGraphClaim = contributionClaimId
    , rawContributionGraphRationale = contributionRationaleRef
    , rawContributionGraphProvenance = "source://joint-mechanism"
    , rawContributionGraphNodes =
        [ contributorOneKeyResultId
        , contributorTwoKeyResultId
        , strategyKeyResultId
        ]
    , rawContributionGraphEdges =
        [contributorOneTargetKeyResultEdge, contributorTwoTargetKeyResultEdge]
    }

contributionEvidence :: RawCollectiveContributionEvidence
contributionEvidence =
  RawCollectiveContributionEvidence
    { rawContributionEvidenceRef = contributionEvidenceRef
    , rawContributionEvidenceClaim = contributionClaimId
    , rawContributionEvidenceParticipants = [contributorOneId, contributorTwoId]
    , rawContributionEvidenceTarget = strategyId
    , rawJointContributionRationales = [contributionRationale]
    , rawContributionPrimitiveGraph =
        Just (RawKeyResultContributionGraph contributionGraph)
    }

actionContributionGraph :: RawBoundContributionGraph
actionContributionGraph =
  contributionGraph
    { rawContributionGraphNodes =
        [contributorOneActionId, contributorTwoActionId, strategyActionId]
    , rawContributionGraphEdges =
        [contributorOneTargetActionEdge, contributorTwoTargetActionEdge]
    }

actionContributionEvidence :: RawCollectiveContributionEvidence
actionContributionEvidence =
  contributionEvidence
    { rawContributionPrimitiveGraph =
        Just (RawActionContributionGraph actionContributionGraph)
    }

actionContributionRawGraph :: RawGraph
actionContributionRawGraph =
  completeCollectiveGraph
    { rawEdges =
        contributorOneTargetActionEdge : rawEdges completeCollectiveGraph
    }

assessContributionModel ::
     RawGraph
  -> [RawCollectiveContributionEvidence]
  -> [Claim RawCollectiveStrategyContribution]
  -> ModelAssessment
assessContributionModel raw evidence claims =
  assessContributionModelWith collectiveFormulations raw evidence claims

assessContributionModelWith ::
     [RawStrategyFormulation]
  -> RawGraph
  -> [RawCollectiveContributionEvidence]
  -> [Claim RawCollectiveStrategyContribution]
  -> ModelAssessment
assessContributionModelWith formulations raw evidence claims =
  assessMixedCollectiveModelWith
    formulations
    raw
    (map CollectiveStrategyContributionEvidence evidence)
    (map CollectiveStrategyContributionClaim claims)

assessContributionClaimModel :: Int -> Bool -> ModelAssessment
assessContributionClaimModel size includeEdges =
  assessContributionClaimModelWithCandidates candidateNodes candidateEdges
  where
    candidateNodes = map candidateNoiseNode [1 .. size]
    candidateEdges
      | includeEdges = map candidateNoiseEdge [1 .. size]
      | otherwise = []

assessContributionClaimModelWithCandidates ::
     [RawNode] -> [RawEdge] -> ModelAssessment
assessContributionClaimModelWithCandidates candidateNodes candidateEdges =
  case validateClaimStructure raw of
    StructureAccepted structure ->
      assessModelSemantics
        structure
        ModelSemanticsInput
          { modelStrategyClaims = map assertedClaim collectiveFormulations
          , modelCollectiveClaims =
              [ CollectiveStrategyContributionClaim
                  (assertedClaim contributionProposition)
              ]
          , modelCollectiveEvidence =
              [CollectiveStrategyContributionEvidence contributionEvidence]
          }
    StructureModelRejected errors ->
      error ("registry Candidate fixture failed: " ++ show errors)
    StructureInternalFailure internal ->
      error ("registry Candidate fixture failed internally: " ++ show internal)
  where
    raw =
      RawClaimGraph
        { rawNodeClaims =
            map assertedClaim (rawNodes coverageGapGraph)
              ++ map candidateClaim candidateNodes
        , rawEdgeClaims =
            map assertedClaim (rawEdges coverageGapGraph)
              ++ map candidateClaim candidateEdges
        }

candidateNoiseNode :: Int -> RawNode
candidateNoiseNode ordinal = RawContextNode (candidateNoiseId ordinal) Strategy

candidateNoiseEdge :: Int -> RawEdge
candidateNoiseEdge ordinal =
  edge (candidateNoiseId ordinal) contributesToStrategy strategyId

candidateNoiseId :: Int -> RawNodeId
candidateNoiseId ordinal =
  RawNodeId ("registry-candidate-" <> Text.pack (show ordinal))

assessMixedCollectiveModel ::
     RawGraph
  -> [RawCollectiveFanInEvidence]
  -> [RawCollectiveFanInClaim]
  -> ModelAssessment
assessMixedCollectiveModel raw evidence claims =
  assessMixedCollectiveModelWith collectiveFormulations raw evidence claims

assessMixedCollectiveModelWith ::
     [RawStrategyFormulation]
  -> RawGraph
  -> [RawCollectiveFanInEvidence]
  -> [RawCollectiveFanInClaim]
  -> ModelAssessment
assessMixedCollectiveModelWith formulations raw evidence claims =
  case validateStructure raw of
    StructureAccepted structure ->
      assessModelSemantics
        structure
        ModelSemanticsInput
          { modelStrategyClaims = map assertedClaim formulations
          , modelCollectiveClaims = claims
          , modelCollectiveEvidence = evidence
          }
    StructureModelRejected errors ->
      error ("collective fixture structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      error ("collective fixture internal failure: " ++ show internal)

unrelatedContributionFormulationGraph :: Int -> RawGraph
unrelatedContributionFormulationGraph size =
  coverageGapGraph
    { rawNodes =
        RawContextNode secondStrategyId Strategy
          : secondStrategyNodes
          ++ concatMap unrelatedFormulationNodes [1 .. size]
          ++ rawNodes coverageGapGraph
    , rawEdges =
        secondStrategyMinimumEdges
          ++ concatMap unrelatedFormulationEdges [1 .. size]
          ++ rawEdges coverageGapGraph
    }

unrelatedContributionFormulation :: Int -> RawStrategyFormulation
unrelatedContributionFormulation size =
  secondStrategyFormulation
    { rawFormulationActions =
        secondStrategyActionId NonEmpty.:| map unrelatedActionId [1 .. size]
    , rawFormulationKeyResults =
        secondStrategyKeyResultId
          NonEmpty.:| map unrelatedKeyResultId [1 .. size]
    }

unrelatedFormulationNodes :: Int -> [RawNode]
unrelatedFormulationNodes ordinal =
  [ RawPrimitiveNode (unrelatedActionId ordinal) secondStrategyId Action
  , RawPrimitiveNode (unrelatedKeyResultId ordinal) secondStrategyId KeyResult
  ]

unrelatedFormulationEdges :: Int -> [RawEdge]
unrelatedFormulationEdges ordinal =
  [ edge
      secondStrategyPrincipleId
      guidesStrategyPrincipleToAction
      (unrelatedActionId ordinal)
  , edge
      (unrelatedActionId ordinal)
      contributesStrategyActionToKeyResult
      (unrelatedKeyResultId ordinal)
  , edge
      (unrelatedKeyResultId ordinal)
      substantiatesStrategyKeyResultObjective
      secondStrategyObjectiveId
  ]

unrelatedActionId, unrelatedKeyResultId :: Int -> RawNodeId
unrelatedActionId ordinal =
  RawNodeId ("unrelated-action-" <> Text.pack (show ordinal))

unrelatedKeyResultId ordinal =
  RawNodeId ("unrelated-key-result-" <> Text.pack (show ordinal))
