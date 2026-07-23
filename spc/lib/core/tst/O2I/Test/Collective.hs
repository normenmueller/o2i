{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Focused collective Strategy-realization validation tests.
module O2I.Test.Collective
  ( collectiveTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I hiding (validateCollectiveStrategyRealizations)
import qualified O2I as O2I
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
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic -> do
    let assessment =
          assessCollectiveStrategyRealizations
            semantic
            [completeFit]
            [candidateCollective]
    collectiveStrategyRealizationErrors assessment @?= []
    case O2I.validateCollectiveStrategyRealizations assessment of
      Failure errors ->
        assertFailure ("unexpected Candidate errors: " ++ show errors)
      Success validated ->
        assertBool
          "Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations validated))
    case candidateCollectiveStrategyRealizations assessment of
      [candidate] -> do
        candidateCollectiveClaim candidate @?= candidateCollective
        candidateCollectiveIssues candidate @?= []
      candidates ->
        assertFailure
          ("expected one Candidate assessment, got " ++ show (length candidates))

candidateIssueTest :: Assertion
candidateIssueTest =
  withCollectiveSemanticModel missingSecondContributionGraph $ \semantic -> do
    let assessment =
          assessCollectiveStrategyRealizations
            semantic
            [completeFit]
            [candidateCollective]
    collectiveStrategyRealizationErrors assessment @?= []
    case O2I.validateCollectiveStrategyRealizations assessment of
      Failure errors ->
        assertFailure ("unexpected Candidate errors: " ++ show errors)
      Success validated ->
        assertBool
          "invalid Candidate validation constructed a collective witness"
          (null (collectiveStrategyRealizations validated))
    case candidateCollectiveStrategyRealizations assessment of
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
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic ->
    mapM_
      (assertDuplicateIdentity semantic)
      [ [candidateCollective, candidateCollective]
      , [candidateCollective, assertedCollective]
      , [assertedCollective, assertedCollective]
      ]
  where
    assertDuplicateIdentity semantic claims =
      assertCollectiveErrors
        [ CollectiveStructuralError
            (DuplicateCollectiveRealizationClaimId collectiveClaimId)
        ]
        (validateCollectiveStrategyRealizations semantic [completeFit] claims)

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
  withCollectiveSemanticModel completeCollectiveGraph $ \semantic -> do
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
          assessCollectiveStrategyRealizations
            semantic
            []
            [invalidAsserted, diagnosticCandidate]
        expectedErrors =
          [ AssertedCollectiveIssue
              (ClaimId "invalid-asserted")
              (CollectiveFitEvidenceNotFound assertedReference)
          ]
    collectiveStrategyRealizationErrors assessment @?= expectedErrors
    case candidateCollectiveStrategyRealizations assessment of
      [candidate] -> do
        candidateCollectiveClaim candidate @?= diagnosticCandidate
        candidateCollectiveIssues candidate
          @?= [CollectiveFitEvidenceNotFound candidateReference]
      candidates ->
        assertFailure
          ("expected one retained Candidate assessment, got "
             ++ show (length candidates))
    case O2I.validateCollectiveStrategyRealizations assessment of
      Failure errors -> NonEmpty.toList errors @?= expectedErrors
      Success _ ->
        assertFailure "fatal collective assessment exposed aggregate witnesses"

validateCollectiveStrategyRealizations ::
     SemanticallyValidModel
  -> [RawCollectiveFitEvidence]
  -> [Claim RawCollectiveStrategyRealization]
  -> Validation
       (NonEmpty.NonEmpty CollectiveStrategyRealizationError)
       ValidatedCollectiveStrategyRealizations
validateCollectiveStrategyRealizations semantic fitEvidence claims =
  O2I.validateCollectiveStrategyRealizations
    (assessCollectiveStrategyRealizations semantic fitEvidence claims)

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

collectiveProposition :: RawCollectiveStrategyRealization
collectiveProposition =
  RawCollectiveStrategyRealization
    { rawRealizationId = collectiveClaimId
    , rawContributors = [contributorOneId, contributorTwoId]
    , rawTarget = strategyId
    , rawCollectiveFitEvidence = fitEvidenceRef
    }

assertedCollective :: Claim RawCollectiveStrategyRealization
assertedCollective = assertedClaim collectiveProposition

candidateCollective :: Claim RawCollectiveStrategyRealization
candidateCollective = candidateClaim collectiveProposition

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
