{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Domain tests for proposed and accepted Need qualifications.
module O2I.Test.Qualification
  ( needQualificationTests
  ) where

import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import O2I
import O2I.Test.Support
import Test.Tasty
import Test.Tasty.HUnit

needQualificationTests :: TestTree
needQualificationTests =
  testGroup
    "need qualification"
    [ testCase "valid proposal yields a Need qualification candidate"
        $ withSemanticallyValid
            minimalQualificationGraph
            [sampleStrategyFormulation]
        $ \model ->
            case validateNeedQualificationProposal
                   model
                   sampleNeedQualificationProposal
                     { rawNeedQualificationRationale = "x"
                     , rawNeedQualificationSourceReference = "  strategy/kr-1  "
                     } of
              Failure errors ->
                assertFailure ("qualification errors: " ++ show errors)
              Success candidate -> do
                contextRefId (needQualificationCandidateStrategy candidate)
                  @?= strategyId
                contextRefId (needQualificationCandidateNeed candidate)
                  @?= needId
                unNodeId (needQualificationCandidateKeyResult candidate)
                  @?= strategyKeyResultId
                unNodeId (needQualificationCandidateObjective candidate)
                  @?= needObjectiveId
                needQualificationCandidateRationale candidate @?= "x"
                needQualificationSourceReferenceText
                  (needQualificationCandidateSourceReference candidate)
                  @?= "strategy/kr-1"
                withSemanticContextRef model SNeed needId $ \need ->
                  qualifyingStrategies model need @?= []
    , testCase "accepted candidate becomes a queryable qualification"
        $ withSemanticallyValid
            minimalQualificationGraph
            [sampleStrategyFormulation]
        $ \initialModel ->
            case validateNeedQualificationProposal
                   initialModel
                   sampleNeedQualificationProposal of
              Failure errors ->
                assertFailure ("qualification errors: " ++ show errors)
              Success candidate -> do
                qualifyingStrategies
                  initialModel
                  (needQualificationCandidateNeed candidate)
                  @?= []
                let acceptedGraph =
                      minimalQualificationGraph
                        { rawEdges =
                            edge
                              (unNodeId
                                 (needQualificationCandidateKeyResult candidate))
                              translatesStrategyKeyResultToNeedObjective
                              (unNodeId
                                 (needQualificationCandidateObjective candidate))
                              : edge
                                  (contextRefId
                                     (needQualificationCandidateStrategy
                                        candidate))
                                  qualifiesNeed
                                  (contextRefId
                                     (needQualificationCandidateNeed candidate))
                              : rawEdges minimalQualificationGraph
                        }
                case validateStructure acceptedGraph of
                  StructureModelRejected errors ->
                    assertFailure ("structural errors: " ++ show errors)
                  StructureAccepted graph ->
                    case validateModelSemantics
                           graph
                           [sampleStrategyFormulation] of
                      Failure errors ->
                        assertFailure ("semantic errors: " ++ show errors)
                      Success acceptedModel ->
                        qualifyingStrategies
                          acceptedModel
                          (needQualificationCandidateNeed candidate)
                          @?= [needQualificationCandidateStrategy candidate]
                  StructureInternalFailure internal ->
                    assertFailure
                      ("internal structural failure: " ++ show internal)
    , testCase "proposal source reference must not be blank"
        $ withSemanticallyValid
            minimalQualificationGraph
            [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [EmptyNeedQualificationSourceReference]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal
                   {rawNeedQualificationSourceReference = "  "})
    , testCase "proposal errors accumulate transparently"
        $ withSemanticallyValid unqualifiedNeedGraph [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ NeedQualificationStrategyKindMismatch
                  needId
                  (ContextNodeKind Need)
              , NeedQualificationNeedKindMismatch
                  strategyId
                  (ContextNodeKind Strategy)
              , NeedQualificationKeyResultMismatch
                  needObjectiveId
                  (PrimitiveNodeKind Need Objective)
                  (Just needId)
              , NeedQualificationObjectiveMismatch
                  strategyKeyResultId
                  (PrimitiveNodeKind Strategy KeyResult)
                  (Just strategyId)
              , EmptyNeedQualificationRationale
              , EmptyNeedQualificationSourceReference
              ]
              (validateNeedQualificationProposal
                 model
                 RawNeedQualificationProposal
                   { rawNeedQualificationCandidateStrategy = needId
                   , rawNeedQualificationNeed = strategyId
                   , rawNeedQualificationStrategyKeyResult = needObjectiveId
                   , rawNeedQualificationNeedObjective = strategyKeyResultId
                   , rawNeedQualificationRationale = "  "
                   , rawNeedQualificationSourceReference = "\t"
                   })
    , testCase "unknown proposal references are rejected"
        $ withSemanticallyValid unqualifiedNeedGraph [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ UnknownNeedQualificationStrategy missingId
              , UnknownNeedQualificationNeed missingId
              , UnknownNeedQualificationKeyResult missingId
              , UnknownNeedQualificationObjective missingId
              ]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal
                   { rawNeedQualificationCandidateStrategy = missingId
                   , rawNeedQualificationNeed = missingId
                   , rawNeedQualificationStrategyKeyResult = missingId
                   , rawNeedQualificationNeedObjective = missingId
                   })
    , testCase "Key Result must be listed in the Strategy formulation"
        $ withSemanticallyValid
            unlistedProposalGraph
            [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ UnlistedNeedQualificationKeyResult
                  strategyId
                  unlistedStrategyKeyResultId
              ]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal
                   { rawNeedQualificationStrategyKeyResult =
                       unlistedStrategyKeyResultId
                   })
    , testCase "Key Result must belong to the candidate Strategy"
        $ withSemanticallyValid
            unqualifiedTwoStrategyGraph
            [sampleStrategyFormulation, secondStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ NeedQualificationKeyResultMismatch
                  secondStrategyKeyResultId
                  (PrimitiveNodeKind Strategy KeyResult)
                  (Just secondStrategyId)
              ]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal
                   { rawNeedQualificationStrategyKeyResult =
                       secondStrategyKeyResultId
                   })
    , testCase "Need Objective must belong to the submitted Need"
        $ withSemanticallyValid
            twoNeedQualificationGraph
            [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ NeedQualificationObjectiveMismatch
                  additionalNeedObjectiveId
                  (PrimitiveNodeKind Need Objective)
                  (Just additionalNeedId)
              ]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal
                   { rawNeedQualificationNeedObjective =
                       additionalNeedObjectiveId
                   })
    , testCase "initial proposal rejects a modeled macrorelation"
        $ withSemanticallyValid
            needQualificationMacroOnlyGraph
            [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [NeedQualificationRelationAlreadyModeled strategyId needId]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal)
    , testCase "initial proposal rejects modeled Primitive evidence"
        $ withSemanticallyValid
            needQualificationEvidenceOnlyGraph
            [sampleStrategyFormulation]
        $ \model ->
            assertNeedQualificationErrors
              [ NeedQualificationTranslationAlreadyModeled
                  strategyKeyResultId
                  needObjectiveId
              ]
              (validateNeedQualificationProposal
                 model
                 sampleNeedQualificationProposal)
    , testCase "qualified Need returns its Strategy"
        $ withSemanticallyValid sampleGraph [sampleStrategyFormulation]
        $ \model ->
            withSemanticContextRef model SNeed needId $ \need ->
              map contextRefId (qualifyingStrategies model need)
                @?= [strategyId]
    , testCase "situated unqualified Need returns no Strategy"
        $ withSemanticallyValid unqualifiedNeedGraph [sampleStrategyFormulation]
        $ \model ->
            withSemanticContextRef model SNeed needId $ \need ->
              qualifyingStrategies model need @?= []
    , testCase "qualifies without translates evidence does not qualify"
        $ withSemanticallyValid
            qualifiesWithoutTranslationGraph
            [sampleStrategyFormulation]
        $ \model ->
            withSemanticContextRef model SNeed needId $ \need ->
              qualifyingStrategies model need @?= []
    , testCase "unlisted strategic Key Result does not qualify"
        $ withSemanticallyValid
            unlistedQualifiesGraph
            [sampleStrategyFormulation]
        $ \model ->
            withSemanticContextRef model SNeed needId $ \need ->
              qualifyingStrategies model need @?= []
    , testCase "multiple Strategies can qualify the same Need"
        $ withSemanticallyValid
            multiplyQualifyingGraph
            [sampleStrategyFormulation, secondStrategyFormulation]
        $ \model ->
            withSemanticContextRef model SNeed needId $ \need ->
              sort (map contextRefId (qualifyingStrategies model need))
                @?= sort [strategyId, secondStrategyId]
    ]

assertNeedQualificationErrors ::
     [NeedQualificationError]
  -> Validation
       (NonEmpty.NonEmpty NeedQualificationError)
       NeedQualificationCandidate
  -> Assertion
assertNeedQualificationErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ ->
      assertFailure "invalid Need qualification proposal was accepted"

minimalQualificationGraph :: RawGraph
minimalQualificationGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawContextNode needId Need
    , RawContextNode situationId Situation
    , RawPrimitiveNode strategyDriverId strategyId Driver
    , RawPrimitiveNode strategyObjectiveId strategyId Objective
    , RawPrimitiveNode strategyPrincipleId strategyId Principle
    , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
    , RawPrimitiveNode strategyActionId strategyId Action
    , RawPrimitiveNode needDriverId needId Driver
    , RawPrimitiveNode needObjectiveId needId Objective
    , RawAnchorNode situationAnchorId BusinessCapability
    ]
    [ edge strategyDriverId groundsStrategyDriverToObjective strategyObjectiveId
    , edge strategyPrincipleId guidesStrategyPrincipleToAction strategyActionId
    , edge
        strategyActionId
        contributesStrategyActionToKeyResult
        strategyKeyResultId
    , edge
        strategyKeyResultId
        substantiatesStrategyKeyResultObjective
        strategyObjectiveId
    , edge situationId surfacesNeed needId
    , anchorEdge situationId constitutedByAnchor situationAnchorId
    , anchorEdge situationAnchorId anchorsNeedDriver needDriverId
    , edge needDriverId groundsNeedDriverToObjective needObjectiveId
    ]

needQualificationMacroOnlyGraph :: RawGraph
needQualificationMacroOnlyGraph =
  minimalQualificationGraph
    { rawEdges =
        edge strategyId qualifiesNeed needId
          : rawEdges minimalQualificationGraph
    }

needQualificationEvidenceOnlyGraph :: RawGraph
needQualificationEvidenceOnlyGraph =
  minimalQualificationGraph
    { rawEdges =
        edge
          strategyKeyResultId
          translatesStrategyKeyResultToNeedObjective
          needObjectiveId
          : rawEdges minimalQualificationGraph
    }

twoNeedQualificationGraph :: RawGraph
twoNeedQualificationGraph =
  minimalQualificationGraph
    { rawNodes =
        RawContextNode additionalNeedId Need
          : RawPrimitiveNode additionalNeedDriverId additionalNeedId Driver
          : RawPrimitiveNode
              additionalNeedObjectiveId
              additionalNeedId
              Objective
          : rawNodes minimalQualificationGraph
    , rawEdges =
        edge situationId surfacesNeed additionalNeedId
          : anchorEdge
              situationAnchorId
              anchorsNeedDriver
              additionalNeedDriverId
          : edge
              additionalNeedDriverId
              groundsNeedDriverToObjective
              additionalNeedObjectiveId
          : rawEdges minimalQualificationGraph
    }

unlistedProposalGraph :: RawGraph
unlistedProposalGraph =
  unqualifiedNeedGraph
    { rawNodes =
        RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult
          : rawNodes unqualifiedNeedGraph
    }

unqualifiedTwoStrategyGraph :: RawGraph
unqualifiedTwoStrategyGraph =
  unqualifiedNeedGraph
    { rawNodes =
        RawContextNode secondStrategyId Strategy
          : secondStrategyNodes
          ++ rawNodes unqualifiedNeedGraph
    , rawEdges = secondStrategyCoherenceEdges ++ rawEdges unqualifiedNeedGraph
    }

sampleNeedQualificationProposal :: RawNeedQualificationProposal
sampleNeedQualificationProposal =
  RawNeedQualificationProposal
    { rawNeedQualificationCandidateStrategy = strategyId
    , rawNeedQualificationNeed = needId
    , rawNeedQualificationStrategyKeyResult = strategyKeyResultId
    , rawNeedQualificationNeedObjective = needObjectiveId
    , rawNeedQualificationRationale =
        "The strategic result requires the submitted change."
    , rawNeedQualificationSourceReference = "strategy/kr-1"
    }

qualifiesWithoutTranslationGraph :: RawGraph
qualifiesWithoutTranslationGraph =
  withoutEdge
    (edge
       strategyKeyResultId
       translatesStrategyKeyResultToNeedObjective
       needObjectiveId)
    sampleGraph

multiplyQualifyingGraph :: RawGraph
multiplyQualifyingGraph =
  sampleGraph
    { rawNodes =
        RawContextNode secondStrategyId Strategy
          : secondStrategyNodes
          ++ rawNodes sampleGraph
    , rawEdges =
        edge secondStrategyId qualifiesNeed needId
          : edge
              secondStrategyKeyResultId
              translatesStrategyKeyResultToNeedObjective
              needObjectiveId
          : secondStrategyCoherenceEdges
          ++ rawEdges sampleGraph
    }
