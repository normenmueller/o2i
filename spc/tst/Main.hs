{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List (nub)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import O2I
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "O2I"
    [structureTests, semanticTests, traceTests, evidenceTests, registryTests]

structureTests :: TestTree
structureTests =
  testGroup
    "structural elaboration"
    [ testCase "empty graph is structurally well-formed"
        $ assertSuccess (validateStructure emptyGraph)
    , testCase "complete reference graph is structurally well-formed"
        $ assertSuccess (validateStructure sampleGraph)
    , testCase "typed edges expose safe total observations"
        $ withWellFormed sampleGraph
        $ \graph ->
            case graphEdges graph of
              candidate:_ -> do
                someEdgeFrom candidate @?= visionId
                someEdgeRelation candidate @?= relationNameFor orientsStrategy
                someEdgeTo candidate @?= strategyId
              [] -> assertFailure "reference graph has no edges"
    , testCase "structural errors accumulate"
        $ let invalidEdge =
                RawEdge missingId (RelationName "unknown") strategyId
           in assertStructuralErrors
                [ DuplicateNodeId strategyId
                , UnknownOwner needObjectiveId missingId
                , UnknownEdgeEndpoint invalidEdge missingId
                , UnknownRelation (RelationName "unknown")
                ]
                (validateStructure multiplyInvalidGraph)
    , testCase "duplicate edges are rejected"
        $ let duplicate = edge visionId orientsStrategy strategyId
           in assertStructuralErrors
                [DuplicateEdge duplicate]
                (validateStructure
                   sampleGraph {rawEdges = duplicate : rawEdges sampleGraph})
    , testCase "wrong relation domains are rejected"
        $ let invalidEdge = edge needId qualifiesNeed strategyId
           in assertStructuralErrors
                [ InvalidRelationDomain
                    invalidEdge
                    (ContextNodeKind Need)
                    (ContextNodeKind Strategy)
                ]
                (validateStructure invalidRelationDomainGraph)
    , testCase "unknown primitive owners are rejected exactly"
        $ assertStructuralErrors
            [UnknownOwner needObjectiveId missingId]
            (validateStructure
               (RawGraph
                  [RawPrimitiveNode needObjectiveId missingId Objective]
                  []))
    , testCase "invalid primitive interpretations are rejected exactly"
        $ assertStructuralErrors
            [InvalidPrimitiveInterpretation measureKpiId Strategy KPI]
            (validateStructure
               (RawGraph
                  [ RawContextNode strategyId Strategy
                  , RawPrimitiveNode measureKpiId strategyId KPI
                  ]
                  []))
    , testCase "invalid structuring contexts are rejected exactly"
        $ assertStructuralErrors
            [InvalidStructuringContext measureDomainId Need Domain]
            (validateStructure
               (RawGraph
                  [ RawContextNode needId Need
                  , RawStructuringNode measureDomainId needId Domain
                  ]
                  []))
    , testCase "invalid Situation anchor contexts are rejected exactly"
        $ assertStructuralErrors
            [InvalidAnchorContext situationAnchorId Need BusinessCapability]
            (validateStructure
               (RawGraph
                  [ RawContextNode needId Need
                  , RawAnchorNode situationAnchorId needId BusinessCapability
                  ]
                  []))
    , testCase "edge errors accumulate independently"
        $ let from = RawNodeId "unknown-from"
              to = RawNodeId "unknown-to"
              relation = RelationName "unknown"
              invalidEdge = RawEdge from relation to
           in assertStructuralErrors
                [ UnknownEdgeEndpoint invalidEdge from
                , UnknownEdgeEndpoint invalidEdge to
                , UnknownRelation relation
                ]
                (validateStructure independentlyInvalidEdgeGraph)
    , QC.testProperty "unknown endpoints accumulate"
        $ QC.forAll unknownEndpointGraph
        $ \raw ->
            case validateStructure raw of
              Failure errors ->
                case rawEdges raw of
                  [candidate] ->
                    NonEmpty.toList errors
                      == [ UnknownEdgeEndpoint candidate (rawEdgeFrom candidate)
                         , UnknownEdgeEndpoint candidate (rawEdgeTo candidate)
                         , UnknownRelation (rawEdgeRelation candidate)
                         ]
                  _ -> False
              Success _ -> False
    ]

semanticTests :: TestTree
semanticTests =
  testGroup
    "model semantics"
    [ testCase "complete reference model is semantically valid"
        $ withWellFormed sampleGraph
        $ \graph ->
            assertSuccess
              (validateModelSemantics graph [sampleStrategyFormulation])
    , testCase "model without Strategy requires no formulation"
        $ withWellFormed emptyGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "every Strategy requires exactly one formulation"
        $ assertSemanticErrorsWith
            sampleGraph
            []
            [StrategyWithoutFormulation strategyId]
    , testCase "duplicate Strategy formulations are rejected exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [sampleStrategyFormulation, sampleStrategyFormulation]
            [DuplicateStrategyFormulation strategyId]
    , testCase "unknown formulation Strategy is rejected exactly"
        $ assertSemanticErrorsWith
            emptyGraph
            [sampleStrategyFormulation {rawFormulationStrategy = missingId}]
            [UnknownFormulationStrategy missingId]
    , testCase "non-Strategy formulation owner is rejected exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [ sampleStrategyFormulation
            , sampleStrategyFormulation {rawFormulationStrategy = needId}
            ]
            [FormulationForNonStrategy needId (ContextNodeKind Need)]
    , testCase "all Strategy text fields require nonblank content"
        $ assertSemanticErrorsWith
            sampleGraph
            [blankStrategyFormulation]
            [ EmptyStrategyText strategyId ScopeField
            , EmptyStrategyText strategyId PeriodField
            , EmptyStrategyText strategyId ResponsibilityScopeField
            , EmptyStrategyText strategyId DecisionLevelField
            , EmptyStrategyText strategyId ResponsibilitiesField
            , EmptyStrategyText strategyId DecisionPathsField
            , EmptyStrategyText strategyId ImplementationLogicField
            , EmptyStrategyText strategyId GuardrailsField
            , EmptyStrategyText strategyId PositioningField
            , EmptyStrategyText strategyId TradeOffsField
            , EmptyStrategyText strategyId FitRationaleField
            ]
    , testCase "independent role errors accumulate without coherence cascades"
        $ assertSemanticErrorsWith
            sampleGraph
            [invalidRoleStrategyFormulation]
            [ InvalidStrategyPrimitiveReference
                strategyId
                DiagnosisRole
                needDriverId
                Driver
            , InvalidStrategyPrimitiveReference
                strategyId
                IntentRole
                strategyDriverId
                Objective
            , InvalidStrategyPrimitiveReference
                strategyId
                GuidingPolicyRole
                strategyObjectiveId
                Principle
            , InvalidStrategyPrimitiveReference
                strategyId
                CoherentActionRole
                interventionActionId
                Action
            , InvalidStrategyPrimitiveReference
                strategyId
                StrategicKeyResultRole
                interventionKeyResultId
                KeyResult
            ]
    , testCase "duplicate Action and Key Result references accumulate exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [duplicateReferenceStrategyFormulation]
            [ DuplicateStrategyPrimitiveReference
                strategyId
                CoherentActionRole
                strategyActionId
            , DuplicateStrategyPrimitiveReference
                strategyId
                StrategicKeyResultRole
                strategyKeyResultId
            ]
    , testCase "diagnosis must ground strategic intention"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyDriverId
                  groundsStrategyDriverToObjective
                  strategyObjectiveId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyDriverId
                (relationNameFor groundsStrategyDriverToObjective)
                strategyObjectiveId
            ]
    , testCase "guiding policy must guide every coherent Action"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyPrincipleId
                  guidesStrategyPrincipleToAction
                  strategyActionId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyPrincipleId
                (relationNameFor guidesStrategyPrincipleToAction)
                strategyActionId
            ]
    , testCase "every coherent Action must contribute to a Key Result"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyActionId
                  contributesStrategyActionToKeyResult
                  strategyKeyResultId)
               sampleGraph)
            [StrategyActionWithoutKeyResult strategyId strategyActionId]
    , testCase "every strategic Key Result must substantiate intention"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyKeyResultId
                  substantiatesStrategyKeyResultObjective
                  strategyObjectiveId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyKeyResultId
                (relationNameFor substantiatesStrategyKeyResultObjective)
                strategyObjectiveId
            ]
    , testCase "need requires a driver"
        $ assertSemanticErrors
            (removeNode needDriverId sampleGraph)
            [ NeedWithoutDriver needId
            , UngroundedNeedObjective needId needObjectiveId
            ]
    , testCase "need requires an objective"
        $ assertSemanticErrors
            (removeNode needObjectiveId sampleGraph)
            [NeedWithoutObjective needId]
    , testCase "need requires a surfacing situation"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= edge situationId surfacesNeed needId)
                    (rawEdges sampleGraph)
              }
            [ NeedWithoutSurfacingSituation needId
            , UnanchoredNeedDriver needId needDriverId
            ]
    , testCase "need driver requires a situation anchor"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= anchorEdge
                          situationAnchorId
                          anchorsNeedDriver
                          needDriverId)
                    (rawEdges sampleGraph)
              }
            [UnanchoredNeedDriver needId needDriverId]
    , testCase "need objective requires grounding"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= edge
                          needDriverId
                          groundsNeedDriverToObjective
                          needObjectiveId)
                    (rawEdges sampleGraph)
              }
            [UngroundedNeedObjective needId needObjectiveId]
    , testCase "situated unqualified need is semantically valid"
        $ withWellFormed unqualifiedNeedGraph
        $ \graph ->
            assertSuccess
              (validateModelSemantics graph [sampleStrategyFormulation])
    ]

traceTests :: TestTree
traceTests =
  testGroup
    "relational effect trace"
    ([ testCase "empty model is not traceable"
         $ withSemanticallyValid emptyGraph []
         $ \model ->
             assertTraceabilityErrors
               [NoIntervention]
               (validateTraceability model)
     , testCase "complete reference model is traceable"
         $ withTraceable sampleGraph (const (pure ()))
     , testCase "every Intervention must address a Need"
         $ withSemanticallyValid
             (withoutEdge (edge interventionId addressesNeed needId) sampleGraph)
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [InterventionWithoutNeed interventionId]
               (validateTraceability model)
     , testCase "every addressed need requires a complete trace"
         $ withSemanticallyValid
             additionalUntracedNeedGraph
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [MissingEffectTrace interventionId additionalNeedId]
               (validateTraceability model)
     , testCase "every macrorelation requires primitive evidence"
         $ withSemanticallyValid
             macroWithoutEvidenceGraph
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [ MissingMacroEvidence
                   ethosId
                   (relationNameFor guidesMission)
                   missionId
               ]
               (validateTraceability model)
     , testCase "parallel primitive paths produce distinct traces"
         $ withTraceable twoPathGraph
         $ \model -> do
             let identifiers =
                   map traceIdentifier (NonEmpty.toList (effectTraces model))
             length identifiers @?= 2
             length (nub identifiers) @?= 2
     , testCase "unlisted Strategy primitives cannot substantiate a trace"
         $ withTraceable unlistedStrategyPathGraph
         $ \model ->
             map
               traceInterventionKeyResult
               (NonEmpty.toList (effectTraces model))
               @?= [interventionKeyResultId]
     , unlistedStrategyMacroTest
         "unlisted intent cannot substantiate orients"
         unlistedOrientsGraph
         (edge visionId orientsStrategy strategyId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted Key Result cannot substantiate qualifies"
         unlistedQualifiesGraph
         (edge strategyId qualifiesNeed needId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted Action cannot substantiate directs Intervention"
         unlistedDirectsInterventionGraph
         (edge strategyId directsIntervention interventionId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted diagnosis and Key Result cannot substantiate frames"
         unlistedFramesGraph
         (edge strategyId framesMeasure measureId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted policies cannot substantiate directs Strategy"
         unlistedDirectsStrategyGraph
         (edge strategyId directsStrategy secondStrategyId)
         [sampleStrategyFormulation, secondStrategyFormulation]
         []
     , unlistedStrategyMacroTest
         "unlisted Actions and Key Results cannot substantiate contributes"
         unlistedContributesStrategyGraph
         (edge strategyId contributesToStrategy secondStrategyId)
         [sampleStrategyFormulation, secondStrategyFormulation]
         []
     ]
       ++ map missingEdgeTest (rawEdges sampleGraph)
       ++ [ QC.testProperty "removing any effect-path edge is rejected"
              $ QC.forAll (QC.elements (rawEdges sampleGraph))
              $ \missingEdge ->
                  traceabilityFails
                    sampleGraph
                      { rawEdges =
                          filter (/= missingEdge) (rawEdges sampleGraph)
                      }
          , QC.testProperty "all situation anchor types are traceable"
              $ QC.forAll (QC.elements [minBound .. maxBound])
              $ \anchor -> traceabilitySucceeds (graphWithAnchor anchor)
          ])

data MissingEdgeExpectation
  = SemanticExpectation [ModelInvariantError]
  | TraceExpectation [TraceabilityError]

missingEdgeTest :: RawEdge -> TestTree
missingEdgeTest missingEdge =
  testCase ("trace rejects missing edge " ++ show missingEdge) $ do
    let raw = withoutEdge missingEdge sampleGraph
    case missingEdgeExpectation missingEdge of
      Just (SemanticExpectation expected) -> assertSemanticErrors raw expected
      Just (TraceExpectation expected) ->
        withSemanticallyValid raw [sampleStrategyFormulation] $ \model ->
          assertTraceabilityErrors expected (validateTraceability model)
      Nothing -> assertFailure "missing exact edge-error expectation"

unlistedStrategyMacroTest ::
     TestName
  -> RawGraph
  -> RawEdge
  -> [RawStrategyFormulation]
  -> [TraceabilityError]
  -> TestTree
unlistedStrategyMacroTest name raw macro formulations additionalErrors =
  testCase name
    $ withSemanticallyValid raw formulations
    $ \model ->
        assertTraceabilityErrors
          (MissingMacroEvidence
             (rawEdgeFrom macro)
             (rawEdgeRelation macro)
             (rawEdgeTo macro)
             : additionalErrors)
          (validateTraceability model)

missingEdgeExpectation :: RawEdge -> Maybe MissingEdgeExpectation
missingEdgeExpectation candidate
  | candidate == edge situationId surfacesNeed needId =
    Just
      (SemanticExpectation
         [ NeedWithoutSurfacingSituation needId
         , UnanchoredNeedDriver needId needDriverId
         ])
  | candidate
      == edge
           strategyDriverId
           groundsStrategyDriverToObjective
           strategyObjectiveId =
    semanticCoherence
      strategyDriverId
      groundsStrategyDriverToObjective
      strategyObjectiveId
  | candidate
      == edge
           strategyPrincipleId
           guidesStrategyPrincipleToAction
           strategyActionId =
    semanticCoherence
      strategyPrincipleId
      guidesStrategyPrincipleToAction
      strategyActionId
  | candidate
      == edge
           strategyKeyResultId
           substantiatesStrategyKeyResultObjective
           strategyObjectiveId =
    semanticCoherence
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  | candidate
      == edge
           strategyActionId
           contributesStrategyActionToKeyResult
           strategyKeyResultId =
    Just
      (SemanticExpectation
         [StrategyActionWithoutKeyResult strategyId strategyActionId])
  | candidate == edge needDriverId groundsNeedDriverToObjective needObjectiveId =
    Just (SemanticExpectation [UngroundedNeedObjective needId needObjectiveId])
  | candidate == anchorEdge situationId constitutedByAnchor situationAnchorId =
    unanchoredNeedDriver
  | candidate == anchorEdge situationAnchorId anchorsNeedDriver needDriverId =
    unanchoredNeedDriver
  | candidate == edge interventionId addressesNeed needId =
    Just (TraceExpectation [InterventionWithoutNeed interventionId])
  | Just (from, relation, to) <- missingMacroEvidence candidate =
    Just
      (TraceExpectation
         [ MissingMacroEvidence from relation to
         , MissingEffectTrace interventionId needId
         ])
  | candidate `elem` traceOnlyEdges =
    Just (TraceExpectation [MissingEffectTrace interventionId needId])
  | otherwise = Nothing
  where
    semanticCoherence ::
         RawNodeId
      -> Relation from to
      -> RawNodeId
      -> Maybe MissingEdgeExpectation
    semanticCoherence from relation to =
      Just
        (SemanticExpectation
           [ MissingStrategyCoherence
               strategyId
               from
               (relationNameFor relation)
               to
           ])
    unanchoredNeedDriver =
      Just (SemanticExpectation [UnanchoredNeedDriver needId needDriverId])

missingMacroEvidence :: RawEdge -> Maybe (RawNodeId, RelationName, RawNodeId)
missingMacroEvidence candidate
  | candidate
      == edge
           visionObjectiveId
           orientsVisionObjectiveToStrategyObjective
           strategyObjectiveId = macro visionId orientsStrategy strategyId
  | candidate
      == edge
           strategyKeyResultId
           translatesStrategyKeyResultToNeedObjective
           needObjectiveId = macro strategyId qualifiesNeed needId
  | candidate
      == edge
           strategyActionId
           guidesStrategyActionToInterventionAction
           interventionActionId =
    macro strategyId directsIntervention interventionId
  | candidate
      == edge
           interventionKeyResultId
           substantiatesInterventionKeyResultNeedObjective
           needObjectiveId = macro interventionId addressesNeed needId
  | candidate `elem` measureFramingEdges =
    macro strategyId framesMeasure measureId
  | candidate
      == edge interventionKeyResultId setsTargetForMeasureKPI measureKpiId =
    macro interventionId setsTargetForMeasure measureId
  | candidate == anchorEdge interventionActionId changesAnchor situationAnchorId =
    macro interventionId changesSituation situationId
  | candidate == anchorEdge measureKpiId measuresAnchor situationAnchorId =
    macro measureId measuresSituation situationId
  | otherwise = Nothing
  where
    macro ::
         RawNodeId
      -> Relation from to
      -> RawNodeId
      -> Maybe (RawNodeId, RelationName, RawNodeId)
    macro from relation to = Just (from, relationNameFor relation, to)

measureFramingEdges :: [RawEdge]
measureFramingEdges =
  [ edge strategyDriverId indicatesMeasureDomain measureDomainId
  , edge strategyKeyResultId determinesMeasureDomain measureDomainId
  , edge measureDomainId containsMeasureKPI measureKpiId
  ]

traceOnlyEdges :: [RawEdge]
traceOnlyEdges =
  [ edge visionId orientsStrategy strategyId
  , edge strategyId qualifiesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId changesSituation situationId
  , edge strategyId framesMeasure measureId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      interventionActionId
      contributesInterventionActionToKeyResult
      interventionKeyResultId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  ]

evidenceTests :: TestTree
evidenceTests =
  testGroup
    "effect evidence"
    [ testCase "complete evidence is assessed"
        $ withAssessed successfulClaim
        $ \assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= ObservedSatisfiedOnTime
    , testCase "effect can be supported before target achievement"
        $ withAssessed belowTargetClaim
        $ \assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= NotSatisfiedAtFollowUp
    , testCase "target achievement does not imply positive effect"
        $ withAssessed targetWithoutEffectClaim
        $ \assessment -> do
            effectResult assessment @?= NotSatisfied
            targetResult assessment @?= ObservedSatisfiedOnTime
    , testCase "late target achievement is distinguished"
        $ withAssessed lateTargetClaim
        $ \assessment -> targetResult assessment @?= ObservedSatisfiedAfterDue
    , testCase "zero effect criteria are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier =
                  traceIdentifier (NonEmpty.head (effectTraces model))
             in assertEvidenceErrors
                  [InvalidEffectCriterion identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (zeroEffectClaim identifier)))
    , testCase "duplicate claims for one trace are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier =
                  traceIdentifier (NonEmpty.head (effectTraces model))
                evidenceClaim = successfulClaim identifier
             in assertEvidenceErrors
                  [DuplicateEvidenceClaim identifier 2]
                  (assessEffectEvidence
                     model
                     (evidenceClaim NonEmpty.:| [evidenceClaim]))
    , testCase "unknown effect traces are rejected exactly"
        $ withTraceable twoPathGraph
        $ \twoPath ->
            case filter
                   ((/= interventionKeyResultId) . traceInterventionKeyResult)
                   (NonEmpty.toList (effectTraces twoPath)) of
              unknownTrace:_ ->
                withTraceable sampleGraph $ \singlePath ->
                  let knownTrace = NonEmpty.head (effectTraces singlePath)
                      knownClaim = claimForTrace knownTrace
                      unknownClaim = claimForTrace unknownTrace
                   in assertEvidenceErrors
                        [UnknownEffectTrace (traceIdentifier unknownTrace)]
                        (assessEffectEvidence
                           singlePath
                           (knownClaim NonEmpty.:| [unknownClaim]))
              [] -> assertFailure "two-path fixture lacks an unknown trace"
    , testCase "intervention Key Result must match the trace"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [ InterventionKeyResultMismatch
                      identifier
                      interventionKeyResultId
                      missingId
                  ]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (mismatchedKeyResultClaim identifier)))
    , testCase "observed KPI must match the trace"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [ObservationKPIMismatch identifier measureKpiId missingId]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (mismatchedKpiClaim identifier)))
    , testCase "observed Situation anchor must match the trace"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [ ObservationAnchorMismatch
                      identifier
                      situationAnchorId
                      missingId
                  ]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (mismatchedAnchorClaim identifier)))
    , testCase "evidence criteria must precede intervention"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [InvalidEvidencePlanOrder identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (latePlanClaim identifier)))
    , testCase "target due date must follow intervention"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [InvalidTargetDueDate identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (invalidDueClaim identifier)))
    , testCase "invalid Within bounds are rejected exactly"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [InvalidTargetCriterion identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (invalidWithinClaim identifier)))
    , testCase "observation units must match"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [ObservationUnitMismatch identifier percent count]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (mismatchedUnitClaim identifier)))
    , testCase "criterion units must match observation units"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [CriterionUnitMismatch identifier percent count]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton
                        (mismatchedCriterionUnitClaim identifier)))
    , testCase "observation time order is validated"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [InvalidObservationOrder identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (invalidTimeClaim identifier)))
    , testCase "units must be named"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [EmptyUnit identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (emptyUnitClaim identifier)))
    , testCase "evidence sources must be named"
        $ withTraceable sampleGraph
        $ \model ->
            let identifier = traceId model
             in assertEvidenceErrors
                  [EmptyEvidenceSource identifier]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (emptySourceClaim identifier)))
    , testCase "every trace requires exactly one evidence claim"
        $ withTraceable twoPathGraph
        $ \model ->
            case NonEmpty.toList (effectTraces model) of
              [claimedTrace, omittedTrace] ->
                assertEvidenceErrors
                  [MissingEvidenceClaim (traceIdentifier omittedTrace)]
                  (assessEffectEvidence
                     model
                     (NonEmpty.singleton (claimForTrace claimedTrace)))
              traces ->
                assertFailure
                  ("expected exactly two traces, got " ++ show (length traces))
    , testCase "positive effect makes the traced Need effective"
        $ assertEffectiveNeed successfulClaim True
    , testCase "missing positive effect leaves the traced Need ineffective"
        $ assertEffectiveNeed targetWithoutEffectClaim False
    , QC.testProperty "positive effect thresholds are accepted"
        $ QC.forAll (QC.chooseInteger (1, 100))
        $ \threshold ->
            evidenceSucceeds
              (\identifier ->
                 setEffectCriterion
                   (IncreaseByAtLeast (Quantity (fromInteger threshold) percent))
                   (claim identifier (fromInteger threshold + 40) targetDate))
    , QC.testProperty "both effect directions are assessed"
        $ QC.forAll ((,) <$> QC.arbitrary <*> QC.chooseInteger (1, 100))
        $ \(increases, threshold) ->
            evidenceSucceeds (directionalClaim increases threshold)
    ]

registryTests :: TestTree
registryTests =
  testGroup
    "typed registries"
    [ QC.testProperty "relation lookup round-trips"
        $ QC.forAll (QC.elements allRelations) relationRoundTrips
    , testCase "relation registry identities are unique"
        $ assertBool "duplicate relation identity" relationRegistryIsUnique
    , testCase "every relation code is represented"
        $ relationCodes @?= allRelationCodes
    , QC.testProperty "interpretation lookup round-trips"
        $ QC.forAll (QC.elements allInterpretations) interpretationRoundTrips
    , testCase "every interpretation code is represented"
        $ interpretationCodes @?= [minBound .. maxBound]
    ]

relationRoundTrips :: SomeRelation -> Bool
relationRoundTrips relation =
  relation `elem` lookupRelations (relationNameOf relation)

relationRegistryIsUnique :: Bool
relationRegistryIsUnique = identities == nub identities
  where
    identities = map relationIdentity allRelations

relationCodes :: [RelationCode]
relationCodes = nub (map relationCodeOf allRelations)

interpretationRoundTrips :: SomeInterpretation -> Bool
interpretationRoundTrips interpretation =
  case lookupInterpretation context primitive of
    Just _ -> True
    Nothing -> False
  where
    (context, primitive) = interpretationIdentity interpretation

interpretationCodes :: [InterpretationCode]
interpretationCodes = map interpretationCodeOf allInterpretations

withWellFormed :: RawGraph -> (WellFormedGraph -> Assertion) -> Assertion
withWellFormed raw action =
  case validateStructure raw of
    Failure errors -> assertFailure ("structural errors: " ++ show errors)
    Success graph -> action graph

withTraceable :: RawGraph -> (TraceableEffectModel -> Assertion) -> Assertion
withTraceable raw action =
  withSemanticallyValid raw [sampleStrategyFormulation] $ \model ->
    case validateTraceability model of
      Failure errors -> assertFailure ("traceability errors: " ++ show errors)
      Success traceable -> action traceable

withSemanticallyValid ::
     RawGraph
  -> [RawStrategyFormulation]
  -> (SemanticallyValidModel -> Assertion)
  -> Assertion
withSemanticallyValid raw formulations action =
  case validateSemanticRaw raw formulations of
    Failure errors -> assertFailure ("semantic errors: " ++ show errors)
    Success model -> action model

validateSemanticRaw ::
     RawGraph
  -> [RawStrategyFormulation]
  -> Validation (NonEmpty.NonEmpty ModelInvariantError) SemanticallyValidModel
validateSemanticRaw raw formulations =
  case validateStructure raw of
    Failure errors ->
      error ("test fixture has structural errors: " ++ show errors)
    Success graph -> validateModelSemantics graph formulations

assertSemanticErrors :: RawGraph -> [ModelInvariantError] -> Assertion
assertSemanticErrors raw expected =
  assertSemanticErrorsWith raw [sampleStrategyFormulation] expected

assertSemanticErrorsWith ::
     RawGraph -> [RawStrategyFormulation] -> [ModelInvariantError] -> Assertion
assertSemanticErrorsWith raw formulations expected =
  case validateSemanticRaw raw formulations of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "semantically invalid model was accepted"

assertStructuralErrors ::
     [StructuralError]
  -> Validation (NonEmpty.NonEmpty StructuralError) WellFormedGraph
  -> Assertion
assertStructuralErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "structurally invalid graph was accepted"

assertTraceabilityErrors ::
     [TraceabilityError]
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
  -> Assertion
assertTraceabilityErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "untraceable effect model was accepted"

assertEvidenceErrors ::
     [EvidenceError]
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
  -> Assertion
assertEvidenceErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid evidence was accepted"

assertEffectiveNeed :: (EffectTraceId -> EvidenceClaim) -> Bool -> Assertion
assertEffectiveNeed makeClaim expected =
  withTraceable sampleGraph $ \model ->
    let trace = NonEmpty.head (effectTraces model)
        evidenceClaim = makeClaim (traceIdentifier trace)
     in case assessEffectEvidence model (NonEmpty.singleton evidenceClaim) of
          Failure errors -> assertFailure ("evidence errors: " ++ show errors)
          Success assessed ->
            isEffectiveNeed assessed (traceNeed trace) @?= expected

withAssessed ::
     (EffectTraceId -> EvidenceClaim)
  -> (EffectAssessment -> Assertion)
  -> Assertion
withAssessed makeClaim action =
  withTraceable sampleGraph $ \model ->
    case assessEffectEvidence
           model
           (NonEmpty.singleton (makeClaim (traceId model))) of
      Failure errors -> assertFailure ("evidence errors: " ++ show errors)
      Success assessed -> action (NonEmpty.head (effectAssessments assessed))

traceId :: TraceableEffectModel -> EffectTraceId
traceId = traceIdentifier . NonEmpty.head . effectTraces

traceabilityFails :: RawGraph -> Bool
traceabilityFails raw =
  case validateSemanticRaw raw [sampleStrategyFormulation] of
    Failure _ -> True
    Success model ->
      case validateTraceability model of
        Failure _ -> True
        Success _ -> False

traceabilitySucceeds :: RawGraph -> Bool
traceabilitySucceeds raw =
  case validateSemanticRaw raw [sampleStrategyFormulation] of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success _ -> True

evidenceSucceeds :: (EffectTraceId -> EvidenceClaim) -> Bool
evidenceSucceeds makeClaim =
  case validateSemanticRaw sampleGraph [sampleStrategyFormulation] of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success traceable ->
          case assessEffectEvidence
                 traceable
                 (NonEmpty.singleton (makeClaim (traceId traceable))) of
            Failure _ -> False
            Success _ -> True

assertSuccess :: Validation errors result -> Assertion
assertSuccess (Success _) = pure ()
assertSuccess (Failure _) = assertFailure "expected validation success"

emptyGraph :: RawGraph
emptyGraph = RawGraph [] []

sampleGraph :: RawGraph
sampleGraph = RawGraph sampleNodes sampleEdges

unqualifiedNeedGraph :: RawGraph
unqualifiedNeedGraph =
  sampleGraph
    { rawEdges =
        filter
          (`notElem` [ edge strategyId qualifiesNeed needId
                     , edge
                         strategyKeyResultId
                         translatesStrategyKeyResultToNeedObjective
                         needObjectiveId
                     ])
          (rawEdges sampleGraph)
    }

sampleStrategyFormulation :: RawStrategyFormulation
sampleStrategyFormulation =
  RawStrategyFormulation
    { rawFormulationStrategy = strategyId
    , rawFormulationScope = "enterprise" NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "enterprise"
          , anchoringDecisionLevel = "executive"
          , anchoringResponsibilities = "strategy owner" NonEmpty.:| []
          , anchoringDecisionPaths = "portfolio governance" NonEmpty.:| []
          , anchoringImplementationLogic = "coherent action commitments"
          }
    , rawFormulationGuardrails = "evidence before assumption" NonEmpty.:| []
    , rawFormulationDiagnosis = strategyDriverId
    , rawFormulationIntent = strategyObjectiveId
    , rawFormulationGuidingPolicy = strategyPrincipleId
    , rawFormulationPositioning = "shared understanding" NonEmpty.:| []
    , rawFormulationTradeOffs = "traceability over speed" NonEmpty.:| []
    , rawFormulationActions = strategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = strategyKeyResultId NonEmpty.:| []
    , rawFormulationFitRationale = "actions substantiate intent" NonEmpty.:| []
    }

blankStrategyFormulation :: RawStrategyFormulation
blankStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationScope = " " NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = " "
          , anchoringResponsibilityScope = " "
          , anchoringDecisionLevel = " "
          , anchoringResponsibilities = " " NonEmpty.:| []
          , anchoringDecisionPaths = " " NonEmpty.:| []
          , anchoringImplementationLogic = " "
          }
    , rawFormulationGuardrails = " " NonEmpty.:| []
    , rawFormulationPositioning = " " NonEmpty.:| []
    , rawFormulationTradeOffs = " " NonEmpty.:| []
    , rawFormulationFitRationale = " " NonEmpty.:| []
    }

invalidRoleStrategyFormulation :: RawStrategyFormulation
invalidRoleStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationDiagnosis = needDriverId
    , rawFormulationIntent = strategyDriverId
    , rawFormulationGuidingPolicy = strategyObjectiveId
    , rawFormulationActions = interventionActionId NonEmpty.:| []
    , rawFormulationKeyResults = interventionKeyResultId NonEmpty.:| []
    }

duplicateReferenceStrategyFormulation :: RawStrategyFormulation
duplicateReferenceStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationActions = strategyActionId NonEmpty.:| [strategyActionId]
    , rawFormulationKeyResults =
        strategyKeyResultId NonEmpty.:| [strategyKeyResultId]
    }

withoutEdge :: RawEdge -> RawGraph -> RawGraph
withoutEdge removed raw = raw {rawEdges = filter (/= removed) (rawEdges raw)}

removeNode :: RawNodeId -> RawGraph -> RawGraph
removeNode identifier raw =
  raw
    { rawNodes = filter ((/= identifier) . rawNodeIdentifier) (rawNodes raw)
    , rawEdges =
        filter
          (\candidate ->
             rawEdgeFrom candidate /= identifier
               && rawEdgeTo candidate /= identifier)
          (rawEdges raw)
    }

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier (RawContextNode identifier _) = identifier
rawNodeIdentifier (RawPrimitiveNode identifier _ _) = identifier
rawNodeIdentifier (RawStructuringNode identifier _ _) = identifier
rawNodeIdentifier (RawAnchorNode identifier _ _) = identifier

twoPathGraph :: RawGraph
twoPathGraph =
  RawGraph (sampleNodes ++ secondPathNodes) (sampleEdges ++ secondPathEdges)

secondPathNodes :: [RawNode]
secondPathNodes =
  [ RawPrimitiveNode (duplicateId needDriverId) needId Driver
  , RawPrimitiveNode (duplicateId needObjectiveId) needId Objective
  , RawPrimitiveNode (duplicateId interventionActionId) interventionId Action
  , RawPrimitiveNode
      (duplicateId interventionKeyResultId)
      interventionId
      KeyResult
  , RawPrimitiveNode (duplicateId measureKpiId) measureId KPI
  , RawStructuringNode (duplicateId measureDomainId) measureId Domain
  , RawAnchorNode (duplicateId situationAnchorId) situationId BusinessCapability
  ]

secondPathEdges :: [RawEdge]
secondPathEdges =
  [ edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId needDriverId)
      groundsNeedDriverToObjective
      (duplicateId needObjectiveId)
  , anchorEdge situationId constitutedByAnchor (duplicateId situationAnchorId)
  , anchorEdge
      (duplicateId situationAnchorId)
      anchorsNeedDriver
      (duplicateId needDriverId)
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      (duplicateId interventionActionId)
  , edge
      (duplicateId interventionActionId)
      contributesInterventionActionToKeyResult
      (duplicateId interventionKeyResultId)
  , edge
      (duplicateId interventionKeyResultId)
      substantiatesInterventionKeyResultNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId interventionKeyResultId)
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge strategyDriverId indicatesMeasureDomain (duplicateId measureDomainId)
  , edge
      strategyKeyResultId
      determinesMeasureDomain
      (duplicateId measureDomainId)
  , edge
      (duplicateId measureDomainId)
      containsMeasureKPI
      (duplicateId measureKpiId)
  , edge
      (duplicateId interventionKeyResultId)
      setsTargetForMeasureKPI
      (duplicateId measureKpiId)
  , anchorEdge
      (duplicateId interventionActionId)
      changesAnchor
      (duplicateId situationAnchorId)
  , anchorEdge
      (duplicateId measureKpiId)
      measuresAnchor
      (duplicateId situationAnchorId)
  ]

unlistedStrategyPathGraph :: RawGraph
unlistedStrategyPathGraph =
  RawGraph
    (sampleNodes ++ map duplicateChild childNodes)
    (sampleEdges ++ map duplicateEdge evidenceEdges)
  where
    childNodes = filter (not . isContextNode) sampleNodes
    evidenceEdges =
      filter
        (\candidate ->
           not
             (isContextId (rawEdgeFrom candidate)
                && isContextId (rawEdgeTo candidate)))
        sampleEdges

unlistedOrientsGraph :: RawGraph
unlistedOrientsGraph =
  replaceStrategyEvidence
    [RawPrimitiveNode unlistedStrategyObjectiveId strategyId Objective]
    [ edge
        visionObjectiveId
        orientsVisionObjectiveToStrategyObjective
        strategyObjectiveId
    ]
    [ edge
        visionObjectiveId
        orientsVisionObjectiveToStrategyObjective
        unlistedStrategyObjectiveId
    ]

unlistedQualifiesGraph :: RawGraph
unlistedQualifiesGraph =
  replaceStrategyEvidence
    [RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult]
    [ edge
        strategyKeyResultId
        translatesStrategyKeyResultToNeedObjective
        needObjectiveId
    ]
    [ edge
        unlistedStrategyKeyResultId
        translatesStrategyKeyResultToNeedObjective
        needObjectiveId
    ]

unlistedDirectsInterventionGraph :: RawGraph
unlistedDirectsInterventionGraph =
  replaceStrategyEvidence
    [RawPrimitiveNode unlistedStrategyActionId strategyId Action]
    [ edge
        strategyActionId
        guidesStrategyActionToInterventionAction
        interventionActionId
    ]
    [ edge
        unlistedStrategyActionId
        guidesStrategyActionToInterventionAction
        interventionActionId
    ]

unlistedFramesGraph :: RawGraph
unlistedFramesGraph =
  replaceStrategyEvidence
    [ RawPrimitiveNode unlistedStrategyDriverId strategyId Driver
    , RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult
    ]
    [ edge strategyDriverId indicatesMeasureDomain measureDomainId
    , edge strategyKeyResultId determinesMeasureDomain measureDomainId
    ]
    [ edge unlistedStrategyDriverId indicatesMeasureDomain measureDomainId
    , edge unlistedStrategyKeyResultId determinesMeasureDomain measureDomainId
    ]

replaceStrategyEvidence :: [RawNode] -> [RawEdge] -> [RawEdge] -> RawGraph
replaceStrategyEvidence addedNodes removedEdges addedEdges =
  sampleGraph
    { rawNodes = addedNodes ++ rawNodes sampleGraph
    , rawEdges =
        addedEdges ++ filter (`notElem` removedEdges) (rawEdges sampleGraph)
    }

unlistedDirectsStrategyGraph :: RawGraph
unlistedDirectsStrategyGraph =
  twoStrategyGraph
    (edge strategyId directsStrategy secondStrategyId)
    [ RawPrimitiveNode unlistedStrategyPrincipleId strategyId Principle
    , RawPrimitiveNode
        secondUnlistedStrategyPrincipleId
        secondStrategyId
        Principle
    ]
    [ edge
        unlistedStrategyPrincipleId
        guidesStrategyPrincipleToPrinciple
        secondUnlistedStrategyPrincipleId
    ]

unlistedContributesStrategyGraph :: RawGraph
unlistedContributesStrategyGraph =
  twoStrategyGraph
    (edge strategyId contributesToStrategy secondStrategyId)
    [ RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult
    , RawPrimitiveNode
        secondUnlistedStrategyKeyResultId
        secondStrategyId
        KeyResult
    , RawPrimitiveNode unlistedStrategyActionId strategyId Action
    , RawPrimitiveNode secondUnlistedStrategyActionId secondStrategyId Action
    ]
    [ edge
        unlistedStrategyKeyResultId
        contributesStrategyKeyResultToKeyResult
        secondUnlistedStrategyKeyResultId
    , edge
        unlistedStrategyActionId
        contributesStrategyActionToAction
        secondUnlistedStrategyActionId
    ]

twoStrategyGraph :: RawEdge -> [RawNode] -> [RawEdge] -> RawGraph
twoStrategyGraph macro addedNodes addedEdges =
  sampleGraph
    { rawNodes =
        RawContextNode secondStrategyId Strategy
          : secondStrategyNodes
          ++ addedNodes
          ++ rawNodes sampleGraph
    , rawEdges =
        macro
          : secondStrategyCoherenceEdges
          ++ addedEdges
          ++ rawEdges sampleGraph
    }

secondStrategyNodes :: [RawNode]
secondStrategyNodes =
  [ RawPrimitiveNode secondStrategyDriverId secondStrategyId Driver
  , RawPrimitiveNode secondStrategyObjectiveId secondStrategyId Objective
  , RawPrimitiveNode secondStrategyPrincipleId secondStrategyId Principle
  , RawPrimitiveNode secondStrategyKeyResultId secondStrategyId KeyResult
  , RawPrimitiveNode secondStrategyActionId secondStrategyId Action
  ]

secondStrategyCoherenceEdges :: [RawEdge]
secondStrategyCoherenceEdges =
  [ edge
      secondStrategyDriverId
      groundsStrategyDriverToObjective
      secondStrategyObjectiveId
  , edge
      secondStrategyPrincipleId
      guidesStrategyPrincipleToAction
      secondStrategyActionId
  , edge
      secondStrategyActionId
      contributesStrategyActionToKeyResult
      secondStrategyKeyResultId
  , edge
      secondStrategyKeyResultId
      substantiatesStrategyKeyResultObjective
      secondStrategyObjectiveId
  ]

secondStrategyFormulation :: RawStrategyFormulation
secondStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationStrategy = secondStrategyId
    , rawFormulationDiagnosis = secondStrategyDriverId
    , rawFormulationIntent = secondStrategyObjectiveId
    , rawFormulationGuidingPolicy = secondStrategyPrincipleId
    , rawFormulationActions = secondStrategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = secondStrategyKeyResultId NonEmpty.:| []
    }

duplicateChild :: RawNode -> RawNode
duplicateChild (RawPrimitiveNode identifier owner primitive) =
  RawPrimitiveNode (duplicateId identifier) owner primitive
duplicateChild (RawStructuringNode identifier owner structuring) =
  RawStructuringNode (duplicateId identifier) owner structuring
duplicateChild (RawAnchorNode identifier owner anchor) =
  RawAnchorNode (duplicateId identifier) owner anchor
duplicateChild node@(RawContextNode _ _) = node

duplicateEdge :: RawEdge -> RawEdge
duplicateEdge candidate =
  candidate
    { rawEdgeFrom = duplicateIfChild (rawEdgeFrom candidate)
    , rawEdgeTo = duplicateIfChild (rawEdgeTo candidate)
    }

duplicateIfChild :: RawNodeId -> RawNodeId
duplicateIfChild identifier
  | isContextId identifier = identifier
  | otherwise = duplicateId identifier

duplicateId :: RawNodeId -> RawNodeId
duplicateId (RawNodeId identifier) = RawNodeId ("second-" <> identifier)

isContextNode :: RawNode -> Bool
isContextNode (RawContextNode _ _) = True
isContextNode _ = False

isContextId :: RawNodeId -> Bool
isContextId identifier =
  identifier
    `elem` [ visionId
           , strategyId
           , needId
           , interventionId
           , measureId
           , situationId
           ]

graphWithAnchor :: SituationAnchor -> RawGraph
graphWithAnchor anchor =
  sampleGraph {rawNodes = map replaceAnchor (rawNodes sampleGraph)}
  where
    replaceAnchor (RawAnchorNode identifier owner _) =
      RawAnchorNode identifier owner anchor
    replaceAnchor node = node

sampleNodes :: [RawNode]
sampleNodes =
  [ RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode needId Need
  , RawContextNode interventionId Intervention
  , RawContextNode measureId Measure
  , RawContextNode situationId Situation
  , RawPrimitiveNode visionObjectiveId visionId Objective
  , RawPrimitiveNode strategyDriverId strategyId Driver
  , RawPrimitiveNode strategyObjectiveId strategyId Objective
  , RawPrimitiveNode strategyPrincipleId strategyId Principle
  , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
  , RawPrimitiveNode strategyActionId strategyId Action
  , RawPrimitiveNode needDriverId needId Driver
  , RawPrimitiveNode needObjectiveId needId Objective
  , RawPrimitiveNode interventionActionId interventionId Action
  , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
  , RawPrimitiveNode measureKpiId measureId KPI
  , RawStructuringNode measureDomainId measureId Domain
  , RawAnchorNode situationAnchorId situationId BusinessCapability
  ]

sampleEdges :: [RawEdge]
sampleEdges =
  [ edge visionId orientsStrategy strategyId
  , edge strategyId qualifiesNeed needId
  , edge situationId surfacesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId addressesNeed needId
  , edge interventionId changesSituation situationId
  , edge strategyId framesMeasure measureId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , edge strategyDriverId groundsStrategyDriverToObjective strategyObjectiveId
  , edge strategyPrincipleId guidesStrategyPrincipleToAction strategyActionId
  , edge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , edge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  , edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      needObjectiveId
  , edge needDriverId groundsNeedDriverToObjective needObjectiveId
  , anchorEdge situationId constitutedByAnchor situationAnchorId
  , anchorEdge situationAnchorId anchorsNeedDriver needDriverId
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      interventionActionId
  , edge
      interventionActionId
      contributesInterventionActionToKeyResult
      interventionKeyResultId
  , edge
      interventionKeyResultId
      substantiatesInterventionKeyResultNeedObjective
      needObjectiveId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge strategyDriverId indicatesMeasureDomain measureDomainId
  , edge strategyKeyResultId determinesMeasureDomain measureDomainId
  , edge measureDomainId containsMeasureKPI measureKpiId
  , edge interventionKeyResultId setsTargetForMeasureKPI measureKpiId
  , anchorEdge interventionActionId changesAnchor situationAnchorId
  , anchorEdge measureKpiId measuresAnchor situationAnchorId
  ]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge ::
     RawNodeId
  -> (SSituationAnchor 'BusinessCapability -> Relation from to)
  -> RawNodeId
  -> RawEdge
anchorEdge from relation to = edge from (relation SBusinessCapability) to

multiplyInvalidGraph :: RawGraph
multiplyInvalidGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawContextNode strategyId Need
    , RawPrimitiveNode needObjectiveId missingId KPI
    ]
    [RawEdge missingId (RelationName "unknown") strategyId]

invalidRelationDomainGraph :: RawGraph
invalidRelationDomainGraph =
  RawGraph
    [RawContextNode strategyId Strategy, RawContextNode needId Need]
    [edge needId qualifiesNeed strategyId]

independentlyInvalidEdgeGraph :: RawGraph
independentlyInvalidEdgeGraph =
  RawGraph
    []
    [ RawEdge
        (RawNodeId "unknown-from")
        (RelationName "unknown")
        (RawNodeId "unknown-to")
    ]

unknownEndpointGraph :: QC.Gen RawGraph
unknownEndpointGraph = do
  suffix <- QC.listOf1 (QC.elements ['a' .. 'z'])
  let from = RawNodeId ("unknown-from-" <> Text.pack suffix)
      to = RawNodeId ("unknown-to-" <> Text.pack suffix)
  pure (RawGraph [] [RawEdge from (RelationName "unknown") to])

additionalUntracedNeedGraph :: RawGraph
additionalUntracedNeedGraph =
  sampleGraph
    { rawNodes =
        RawContextNode additionalNeedId Need
          : RawPrimitiveNode additionalNeedDriverId additionalNeedId Driver
          : RawPrimitiveNode
              additionalNeedObjectiveId
              additionalNeedId
              Objective
          : rawNodes sampleGraph
    , rawEdges =
        edge interventionId addressesNeed additionalNeedId
          : edge situationId surfacesNeed additionalNeedId
          : anchorEdge
              situationAnchorId
              anchorsNeedDriver
              additionalNeedDriverId
          : edge
              additionalNeedDriverId
              groundsNeedDriverToObjective
              additionalNeedObjectiveId
          : edge
              interventionKeyResultId
              substantiatesInterventionKeyResultNeedObjective
              additionalNeedObjectiveId
          : rawEdges sampleGraph
    }

macroWithoutEvidenceGraph :: RawGraph
macroWithoutEvidenceGraph =
  sampleGraph
    { rawNodes =
        RawContextNode ethosId Ethos
          : RawContextNode missionId Mission
          : rawNodes sampleGraph
    , rawEdges = edge ethosId guidesMission missionId : rawEdges sampleGraph
    }

successfulClaim :: EffectTraceId -> EvidenceClaim
successfulClaim identifier = claim identifier 75 targetDate

belowTargetClaim :: EffectTraceId -> EvidenceClaim
belowTargetClaim identifier = claim identifier 60 targetDate

targetWithoutEffectClaim :: EffectTraceId -> EvidenceClaim
targetWithoutEffectClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 10 percent))
    ((claim identifier 75 targetDate)
       {baseline = observation 72 baselineDate percent})

lateTargetClaim :: EffectTraceId -> EvidenceClaim
lateTargetClaim identifier = claim identifier 75 earlyTargetDate

mismatchedUnitClaim :: EffectTraceId -> EvidenceClaim
mismatchedUnitClaim identifier =
  (successfulClaim identifier) {followUp = observation 75 followUpDate count}

mismatchedCriterionUnitClaim :: EffectTraceId -> EvidenceClaim
mismatchedCriterionUnitClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 10 count))
    (successfulClaim identifier)

invalidTimeClaim :: EffectTraceId -> EvidenceClaim
invalidTimeClaim identifier =
  (successfulClaim identifier) {baseline = observation 40 followUpDate percent}

mismatchedKeyResultClaim :: EffectTraceId -> EvidenceClaim
mismatchedKeyResultClaim identifier =
  (successfulClaim identifier) {evidenceInterventionKeyResult = missingId}

mismatchedKpiClaim :: EffectTraceId -> EvidenceClaim
mismatchedKpiClaim identifier =
  (successfulClaim identifier)
    { followUp =
        (followUp (successfulClaim identifier)) {observationKPI = missingId}
    }

mismatchedAnchorClaim :: EffectTraceId -> EvidenceClaim
mismatchedAnchorClaim identifier =
  (successfulClaim identifier)
    { followUp =
        (followUp (successfulClaim identifier)) {observationAnchor = missingId}
    }

zeroEffectClaim :: EffectTraceId -> EvidenceClaim
zeroEffectClaim identifier =
  setEffectCriterion
    (IncreaseByAtLeast (Quantity 0 percent))
    (successfulClaim identifier)

emptyUnitClaim :: EffectTraceId -> EvidenceClaim
emptyUnitClaim identifier =
  setTargetCriterion
    (AtLeast (Quantity 70 unnamed))
    (setEffectCriterion
       (IncreaseByAtLeast (Quantity 10 unnamed))
       ((successfulClaim identifier)
          { baseline = observation 40 baselineDate unnamed
          , followUp = observation 75 followUpDate unnamed
          }))
  where
    unnamed = Unit " "

emptySourceClaim :: EffectTraceId -> EvidenceClaim
emptySourceClaim identifier =
  (successfulClaim identifier)
    { followUp =
        (followUp (successfulClaim identifier))
          {observationSource = EvidenceSource " "}
    }

latePlanClaim :: EffectTraceId -> EvidenceClaim
latePlanClaim identifier =
  let evidenceClaim = successfulClaim identifier
   in evidenceClaim
        { evidencePlan =
            (evidencePlan evidenceClaim) {establishedAt = interventionDate}
        }

invalidDueClaim :: EffectTraceId -> EvidenceClaim
invalidDueClaim identifier =
  let evidenceClaim = successfulClaim identifier
   in evidenceClaim
        { evidencePlan =
            (evidencePlan evidenceClaim) {targetDueAt = interventionDate}
        }

invalidWithinClaim :: EffectTraceId -> EvidenceClaim
invalidWithinClaim identifier =
  setTargetCriterion
    (Within (Quantity 80 percent) (Quantity 70 percent))
    (successfulClaim identifier)

claimForTrace :: EffectTrace -> EvidenceClaim
claimForTrace trace =
  evidenceClaim
    { evidenceInterventionKeyResult = traceInterventionKeyResult trace
    , baseline = alignObservation (baseline evidenceClaim)
    , followUp = alignObservation (followUp evidenceClaim)
    }
  where
    evidenceClaim = successfulClaim (traceIdentifier trace)
    alignObservation observation' =
      observation'
        {observationKPI = traceKPI trace, observationAnchor = traceAnchor trace}

directionalClaim :: Bool -> Integer -> EffectTraceId -> EvidenceClaim
directionalClaim increases threshold identifier =
  if increases
    then setEffectCriterion
           (IncreaseByAtLeast quantity)
           (claim identifier (40 + amount) targetDate)
    else setTargetCriterion
           (AtMost (Quantity 40 percent))
           (setEffectCriterion
              (DecreaseByAtLeast quantity)
              (claim identifier (40 - amount) targetDate))
  where
    amount = fromInteger threshold
    quantity = Quantity amount percent

claim :: EffectTraceId -> Rational -> UTCTime -> EvidenceClaim
claim identifier followValue due =
  EvidenceClaim
    { evidenceTrace = identifier
    , evidenceInterventionKeyResult = interventionKeyResultId
    , evidencePlan =
        EvidencePlan
          { establishedAt = criteriaDate
          , interventionStartedAt = interventionDate
          , targetDueAt = due
          , effectCriterion = IncreaseByAtLeast (Quantity 10 percent)
          , targetCriterion = AtLeast (Quantity 70 percent)
          }
    , baseline = observation 40 baselineDate percent
    , followUp = observation followValue followUpDate percent
    }

setEffectCriterion :: EffectCriterion -> EvidenceClaim -> EvidenceClaim
setEffectCriterion criterion evidenceClaim =
  evidenceClaim
    {evidencePlan = (evidencePlan evidenceClaim) {effectCriterion = criterion}}

setTargetCriterion :: TargetCriterion -> EvidenceClaim -> EvidenceClaim
setTargetCriterion criterion evidenceClaim =
  evidenceClaim
    {evidencePlan = (evidencePlan evidenceClaim) {targetCriterion = criterion}}

observation :: Rational -> UTCTime -> Unit -> Observation
observation value observedTimestamp valueUnit =
  Observation
    { observationKPI = measureKpiId
    , observationAnchor = situationAnchorId
    , observedAt = observedTimestamp
    , observedValue = Quantity value valueUnit
    , observationSource = EvidenceSource "decision registry"
    }

criteriaDate, baselineDate, interventionDate, earlyTargetDate, targetDate, followUpDate ::
     UTCTime
criteriaDate = timestamp 2025 12 1

baselineDate = timestamp 2026 1 1

interventionDate = timestamp 2026 2 1

earlyTargetDate = timestamp 2026 2 15

targetDate = timestamp 2026 6 30

followUpDate = timestamp 2026 6 1

timestamp :: Integer -> Int -> Int -> UTCTime
timestamp year month day =
  UTCTime (fromGregorian year month day) (secondsToDiffTime 0)

percent, count :: Unit
percent = Unit "percent"

count = Unit "count"

ethosId, missionId, visionId, strategyId, needId :: RawNodeId
ethosId = RawNodeId "ethos"

missionId = RawNodeId "mission"

visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

additionalNeedId, interventionId :: RawNodeId
additionalNeedId = RawNodeId "additional-need"

interventionId = RawNodeId "intervention"

measureId, situationId, missingId :: RawNodeId
measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

missingId = RawNodeId "missing"

visionObjectiveId, strategyDriverId, strategyObjectiveId :: RawNodeId
visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyPrincipleId, strategyKeyResultId, strategyActionId :: RawNodeId
strategyPrincipleId = RawNodeId "strategy-principle"

strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"

needDriverId, additionalNeedDriverId :: RawNodeId
needDriverId = RawNodeId "need-driver"

additionalNeedDriverId = RawNodeId "additional-need-driver"

needObjectiveId, additionalNeedObjectiveId, interventionActionId :: RawNodeId
needObjectiveId = RawNodeId "need-objective"

additionalNeedObjectiveId = RawNodeId "additional-need-objective"

interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId, measureKpiId, measureDomainId :: RawNodeId
interventionKeyResultId = RawNodeId "intervention-key-result"

measureKpiId = RawNodeId "measure-kpi"

measureDomainId = RawNodeId "measure-domain"

situationAnchorId :: RawNodeId
situationAnchorId = RawNodeId "situation-anchor"

secondStrategyId, secondStrategyDriverId, secondStrategyObjectiveId :: RawNodeId
secondStrategyId = RawNodeId "second-strategy"

secondStrategyDriverId = RawNodeId "second-strategy-driver"

secondStrategyObjectiveId = RawNodeId "second-strategy-objective"

secondStrategyPrincipleId, secondStrategyKeyResultId, secondStrategyActionId ::
     RawNodeId
secondStrategyPrincipleId = RawNodeId "second-strategy-principle"

secondStrategyKeyResultId = RawNodeId "second-strategy-key-result"

secondStrategyActionId = RawNodeId "second-strategy-action"

unlistedStrategyDriverId, unlistedStrategyObjectiveId :: RawNodeId
unlistedStrategyDriverId = RawNodeId "unlisted-strategy-driver"

unlistedStrategyObjectiveId = RawNodeId "unlisted-strategy-objective"

unlistedStrategyPrincipleId, unlistedStrategyKeyResultId :: RawNodeId
unlistedStrategyPrincipleId = RawNodeId "unlisted-strategy-principle"

unlistedStrategyKeyResultId = RawNodeId "unlisted-strategy-key-result"

unlistedStrategyActionId, secondUnlistedStrategyPrincipleId :: RawNodeId
unlistedStrategyActionId = RawNodeId "unlisted-strategy-action"

secondUnlistedStrategyPrincipleId =
  RawNodeId "second-unlisted-strategy-principle"

secondUnlistedStrategyKeyResultId, secondUnlistedStrategyActionId :: RawNodeId
secondUnlistedStrategyKeyResultId =
  RawNodeId "second-unlisted-strategy-key-result"

secondUnlistedStrategyActionId = RawNodeId "second-unlisted-strategy-action"
