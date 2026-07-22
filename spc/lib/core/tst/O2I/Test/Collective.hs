{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Focused collective Strategy-realization validation tests.
module O2I.Test.Collective
  ( collectiveTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I
import O2I.Test.Support
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

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
        "Candidate semantic deficiencies are retained without a witness"
        candidateIssueTest
    , testCase
        "Asserted contributor evidence deficiencies are errors"
        assertedContributionErrorTest
    , testCase
        "collective coverage is separate from individual contribution"
        collectiveCoverageTest
    , testCase
        "collective Fit obligations accumulate independently"
        collectiveFitTest
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
    ]

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
        assertBool
          "asserted validation retained a Candidate assessment"
          (null (candidateCollectiveStrategyRealizations assessment))
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
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    case validateCollectiveStrategyRealizations
           semantic
           [completeFit]
           [candidateCollective] of
      Failure errors ->
        assertFailure ("unexpected Candidate errors: " ++ show errors)
      Success assessment -> do
        assertBool
          "Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations assessment))
        case candidateCollectiveStrategyRealizations assessment of
          [candidate] -> do
            candidateCollectiveClaim candidate @?= candidateCollective
            candidateCollectiveIssues candidate @?= []
          candidates ->
            assertFailure
              ("expected one Candidate assessment, got "
                 ++ show (length candidates))

candidateIssueTest :: Assertion
candidateIssueTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic ->
    case validateCollectiveStrategyRealizations
           semantic
           [completeFit]
           [candidateCollective] of
      Failure errors ->
        assertFailure ("unexpected Candidate errors: " ++ show errors)
      Success assessment -> do
        assertBool
          "invalid Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations assessment))
        case candidateCollectiveStrategyRealizations assessment of
          [candidate] ->
            candidateCollectiveIssues candidate
              @?= [ MissingContributorContribution contributorTwoId strategyId
                  , UncoveredTargetAction strategyActionId
                  ]
          candidates ->
            assertFailure
              ("expected one Candidate assessment, got "
                 ++ show (length candidates))

assertedContributionErrorTest :: Assertion
assertedContributionErrorTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic ->
    assertCollectiveErrors
      [ AssertedCollectiveRealizationIssue
          collectiveClaimId
          (MissingContributorContribution contributorTwoId strategyId)
      , AssertedCollectiveRealizationIssue
          collectiveClaimId
          (UncoveredTargetAction strategyActionId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective])

collectiveCoverageTest :: Assertion
collectiveCoverageTest =
  withCollectiveSemanticModel coverageGapGraph $ \semantic ->
    assertCollectiveErrors
      [ AssertedCollectiveRealizationIssue
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
         (AssertedCollectiveRealizationIssue collectiveClaimId)
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
         (AssertedCollectiveRealizationIssue collectiveClaimId)
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
      [ AssertedCollectiveRealizationIssue
          collectiveClaimId
          (CollectiveFitEvidenceNotFound fitEvidenceRef)
      ]
      (validateCollectiveStrategyRealizations semantic [] [assertedCollective])
    assertCollectiveErrors
      [ AssertedCollectiveRealizationIssue
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
      [ TooFewCollectiveContributors collectiveClaimId
      , DuplicateCollectiveContributor collectiveClaimId contributorOneId
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedCollective
             {rawContributors = [contributorOneId, contributorOneId]}
         ])

contributorTargetSeparationTest :: Assertion
contributorTargetSeparationTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      [CollectiveContributorIsTarget collectiveClaimId strategyId]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective {rawContributors = [contributorOneId, strategyId]}])

contributorTypingTest :: Assertion
contributorTypingTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      [ UnknownCollectiveParticipant
          collectiveClaimId
          CollectiveContributor
          missingId
      , NonStrategyCollectiveParticipant
          collectiveClaimId
          CollectiveContributor
          ethosId
          (ContextNodeKind Ethos)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective {rawContributors = [missingId, ethosId]}])

targetTypingTest :: Assertion
targetTypingTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic -> do
    assertCollectiveErrors
      [ UnknownCollectiveParticipant
          collectiveClaimId
          CollectiveTarget
          missingId
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective {rawTarget = missingId}])
    assertCollectiveErrors
      [ NonStrategyCollectiveParticipant
          collectiveClaimId
          CollectiveTarget
          ethosId
          (ContextNodeKind Ethos)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective {rawTarget = ethosId}])

claimIdentityTest :: Assertion
claimIdentityTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      [DuplicateCollectiveRealizationClaimId collectiveClaimId]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [assertedCollective, candidateCollective])

blankIdentityTest :: Assertion
blankIdentityTest =
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    assertCollectiveErrors
      [ EmptyCollectiveRealizationClaimId
      , EmptyCollectiveFitEvidenceReference (ClaimId " ")
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ assertedCollective
             { rawRealizationId = ClaimId " "
             , rawCollectiveFitEvidence = CollectiveFitEvidenceRef ""
             }
         ])

independentErrorAccumulationTest :: Assertion
independentErrorAccumulationTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic ->
    assertCollectiveErrors
      [ UnknownCollectiveParticipant
          (ClaimId "malformed-candidate")
          CollectiveContributor
          missingId
      , NonStrategyCollectiveParticipant
          (ClaimId "malformed-candidate")
          CollectiveContributor
          ethosId
          (ContextNodeKind Ethos)
      , AssertedCollectiveRealizationIssue
          collectiveClaimId
          (MissingContributorContribution contributorTwoId strategyId)
      , AssertedCollectiveRealizationIssue
          collectiveClaimId
          (UncoveredTargetAction strategyActionId)
      ]
      (validateCollectiveStrategyRealizations
         semantic
         [completeFit]
         [ candidateCollective
             { rawRealizationId = ClaimId "malformed-candidate"
             , rawContributors = [missingId, ethosId]
             }
         , assertedCollective
         ])

assertCollectiveErrors ::
     [CollectiveStrategyRealizationError]
  -> Validation
       (NonEmpty.NonEmpty CollectiveStrategyRealizationError)
       CollectiveStrategyRealizationAssessment
  -> Assertion
assertCollectiveErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid collective claim was accepted"

withCollectiveSemanticModel ::
     RawGraph -> (SemanticallyValidModel -> Assertion) -> Assertion
withCollectiveSemanticModel raw action =
  case validateStructure raw of
    StructureModelRejected errors ->
      assertFailure ("collective fixture structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      assertFailure ("collective fixture internal failure: " ++ show internal)
    StructureAccepted structure ->
      case validateModelSemantics
             (structuralGraph structure)
             collectiveFormulations of
        Failure errors ->
          assertFailure ("collective fixture semantic errors: " ++ show errors)
        Success semantic -> action semantic

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

assertedCollective :: RawCollectiveStrategyRealization
assertedCollective =
  RawCollectiveStrategyRealization
    { rawRealizationId = collectiveClaimId
    , rawContributors = [contributorOneId, contributorTwoId]
    , rawTarget = strategyId
    , rawCollectiveFitEvidence = fitEvidenceRef
    , rawCommitment = Asserted
    }

candidateCollective :: RawCollectiveStrategyRealization
candidateCollective = assertedCollective {rawCommitment = Candidate}

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

contributorTwoActionId :: RawNodeId
contributorTwoActionId = contributorAction contributorTwoIds
