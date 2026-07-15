{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List (nub, sort)
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
    [ structureTests
    , performanceDimensionRoleTests
    , semanticTests
    , qualificationTests
    , traceTests
    , readinessTests
    , effectEvidenceTests
    , registryTests
    ]

performanceDimensionRoleTests :: TestTree
performanceDimensionRoleTests =
  testGroup
    "closed performance-dimension roles"
    [ testCase "StrategySuccessDimension admits Strategy Key Results"
        $ withWellFormed strategySuccessPerformanceDimensionGraph
        $ \graph ->
            withContextRef graph SStrategy strategyId $ \strategy ->
              map
                unNodeId
                (performanceDimensionNodesIn
                   graph
                   strategy
                   StrategySuccessDimension)
                @?= [strategyPerformanceDimensionId]
    , testCase "MeasureMeasurementDimension admits Measure KPIs"
        $ withWellFormed measureMeasurementPerformanceDimensionGraph
        $ \graph ->
            withContextRef graph SMeasure measureId $ \measure ->
              map
                unNodeId
                (performanceDimensionNodesIn
                   graph
                   measure
                   MeasureMeasurementDimension)
                @?= [measurePerformanceDimensionId]
    , testCase "the registry contains exactly both admissible roles"
        $ map performanceDimensionRoleIdentity allPerformanceDimensionRoles
            @?= [ ( StrategySuccessDimensionCode
                  , PerformanceDimensionRoleName "strategy-success-dimension"
                  , Strategy
                  , KeyResult)
                , ( MeasureMeasurementDimensionCode
                  , PerformanceDimensionRoleName "measure-measurement-dimension"
                  , Measure
                  , KPI)
                ]
    , testCase "performance-dimension relation names are stable" $ do
        let strategicName =
              relationNameFor
                (containsPerformanceDimension StrategySuccessDimension)
            measurementName =
              relationNameFor
                (containsPerformanceDimension MeasureMeasurementDimension)
        strategicName
          @?= RelationName
                "strategy-performance-dimension-contains-strategy-key-result"
        measurementName
          @?= RelationName "measure-performance-dimension-contains-measure-kpi"
        map relationCodeOf (lookupRelations strategicName)
          @?= [PerformanceDimensionMembership StrategySuccessDimensionCode]
        map relationCodeOf (lookupRelations measurementName)
          @?= [PerformanceDimensionMembership MeasureMeasurementDimensionCode]
        relationNameFor indicatesMeasurePerformanceDimension
          @?= RelationName
                "strategy-driver-indicates-measure-performance-dimension"
        relationNameFor determinesMeasurePerformanceDimension
          @?= RelationName
                "strategy-key-result-determines-measure-performance-dimension"
    , QC.testProperty
        "raw performance-dimension ownership derives from the role registry"
        $ QC.forAll (QC.elements [minBound .. maxBound])
        $ \context -> rawPerformanceDimensionOwnershipMatchesRegistry context
    , testCase "StrategySuccessDimension rejects non-KeyResult membership"
        $ let invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension StrategySuccessDimension))
                  strategyActionId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (StructuringNodeKind Strategy PerformanceDimension)
                    (PrimitiveNodeKind Strategy Action)
                ]
                (validateStructure strategySuccessDimensionWithActionGraph)
    , testCase "MeasureMeasurementDimension cannot type a Strategy dimension"
        $ let invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension MeasureMeasurementDimension))
                  strategyKeyResultId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (StructuringNodeKind Strategy PerformanceDimension)
                    (PrimitiveNodeKind Strategy KeyResult)
                ]
                (validateStructure
                   strategySuccessPerformanceDimensionGraph
                     {rawEdges = [invalidEdge]})
    ]

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
    , testCase "validated context lookup returns a typed reference"
        $ withWellFormed sampleGraph
        $ \graph ->
            withContextRef graph SNeed needId $ \need ->
              contextRefId need @?= needId
    , testCase "validated context lookup rejects a false type index"
        $ withWellFormed sampleGraph
        $ \graph -> lookupContextRef graph SStrategy needId @?= Nothing
    , testCase "validated context lookup rejects non-context nodes"
        $ withWellFormed sampleGraph
        $ \graph -> lookupContextRef graph SNeed needObjectiveId @?= Nothing
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
    , testCase "wrong relation endpoint kinds are rejected"
        $ let invalidEdge = edge needId qualifiesNeed strategyId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (ContextNodeKind Need)
                    (ContextNodeKind Strategy)
                ]
                (validateStructure invalidRelationEndpointsGraph)
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
            [ InvalidStructuringContext
                measurePerformanceDimensionId
                Need
                PerformanceDimension
            ]
            (validateStructure
               (RawGraph
                  [ RawContextNode needId Need
                  , RawStructuringNode
                      measurePerformanceDimensionId
                      needId
                      PerformanceDimension
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

qualificationTests :: TestTree
qualificationTests =
  testGroup
    "need qualification"
    [ testCase "qualified Need returns its Strategy"
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
     , testCase "effect traces expose every typed proof-path constituent"
         $ withTraceable sampleGraph
         $ \model ->
             let trace = NonEmpty.head (effectTraces model)
              in do
                   contextRefId (traceVision trace) @?= visionId
                   unNodeId (traceVisionObjective trace) @?= visionObjectiveId
                   contextRefId (traceStrategy trace) @?= strategyId
                   unNodeId (traceStrategyDriver trace) @?= strategyDriverId
                   unNodeId (traceStrategyObjective trace)
                     @?= strategyObjectiveId
                   unNodeId (traceStrategyKeyResult trace)
                     @?= strategyKeyResultId
                   unNodeId (traceStrategyAction trace) @?= strategyActionId
                   contextRefId (traceNeed trace) @?= needId
                   unNodeId (traceNeedDriver trace) @?= needDriverId
                   unNodeId (traceNeedObjective trace) @?= needObjectiveId
                   contextRefId (traceIntervention trace) @?= interventionId
                   unNodeId (traceInterventionAction trace)
                     @?= interventionActionId
                   unNodeId (traceInterventionKeyResult trace)
                     @?= interventionKeyResultId
                   contextRefId (traceMeasure trace) @?= measureId
                   unNodeId (traceMeasurePerformanceDimension trace)
                     @?= measurePerformanceDimensionId
                   unNodeId (traceKPI trace) @?= measureKpiId
                   contextRefId (traceSituation trace) @?= situationId
                   situationAnchorRefId (traceSituationAnchor trace)
                     @?= situationAnchorId
                   situationAnchorRefKind (traceSituationAnchor trace)
                     @?= BusinessCapability
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
               (unNodeId . traceInterventionKeyResult)
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
  [ edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      measurePerformanceDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpiId
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

readinessTests :: TestTree
readinessTests =
  testGroup
    "evidence readiness"
    [ testCase "complete ex-ante plans establish readiness"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready -> do
            NonEmpty.length (evidencePlans ready) @?= 1
            NonEmpty.length (readyEffectTraces ready) @?= 1
            readinessCheckedAt ready @?= readinessDate
            plannedInterventionStarts ready @?= [samplePlannedStart]
    , testCase "known Intervention has one evidence-ready trace"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              length (readyTracesForIntervention ready intervention) @?= 1
    , testCase "trace-free Intervention has no evidence-ready trace"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withWellFormed
              (RawGraph [RawContextNode missingId Intervention] [])
              (\graph ->
                 withContextRef graph SIntervention missingId $ \intervention ->
                   readyTracesForIntervention ready intervention @?= [])
    , testCase "Intervention may have multiple evidence-ready traces"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention -> do
              length (readyTracesForIntervention ready intervention) @?= 2
              plannedInterventionStarts ready @?= [samplePlannedStart]
    , testCase "contradictory starts for multi-trace Intervention are rejected"
        $ withTraceable twoPathGraph
        $ \model ->
            let contradictory =
                  samplePlannedStart {plannedStartAt = afterInterventionDate}
             in assertReadinessErrors
                  [DuplicatePlannedInterventionStart interventionId 2]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     [samplePlannedStart, contradictory]
                     (fmap planForTrace (effectTraces model)))
    , testCase "unknown planned Intervention timing is rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let unknown = PlannedInterventionStart missingId interventionDate
             in assertReadinessErrors
                  [UnknownPlannedInterventionStart missingId]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     [samplePlannedStart, unknown]
                     (fmap planForTrace (effectTraces model)))
    , testCase "every traced Intervention requires planned timing"
        $ withTraceable sampleGraph
        $ \model ->
            let intervention =
                  traceIntervention (NonEmpty.head (effectTraces model))
             in assertReadinessErrors
                  [MissingPlannedInterventionStart intervention]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     []
                     (fmap planForTrace (effectTraces model)))
    , testCase "plan and baseline may be fixed at the check time"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan =
                  (planForTrace trace)
                    { establishedAt = readinessDate
                    , baseline =
                        (baseline (planForTrace trace))
                          {observedAt = readinessDate}
                    }
             in assertSuccess
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (plannedStartsFor model)
                     (NonEmpty.singleton plan))
    , testCase "duplicate plans for one trace are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan = planForTrace trace
                identifier = traceIdentifier trace
             in assertReadinessErrors
                  [DuplicateEvidencePlan identifier 2]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (plannedStartsFor model)
                     (plan NonEmpty.:| [plan]))
    , testCase "unknown planned traces are rejected exactly"
        $ withTraceable twoPathGraph
        $ \twoPath ->
            case filter
                   ((/= interventionKeyResultId)
                      . unNodeId
                      . traceInterventionKeyResult)
                   (NonEmpty.toList (effectTraces twoPath)) of
              unknownTrace:_ ->
                withTraceable sampleGraph $ \singlePath ->
                  let knownTrace = NonEmpty.head (effectTraces singlePath)
                      knownPlan = planForTrace knownTrace
                      unknownPlan = planForTrace unknownTrace
                   in assertReadinessErrors
                        [ UnknownEvidencePlanTrace
                            (traceIdentifier unknownTrace)
                        ]
                        (validateEvidenceReadinessAt
                           readinessDate
                           singlePath
                           (plannedStartsFor singlePath)
                           (knownPlan NonEmpty.:| [unknownPlan]))
              [] -> assertFailure "two-path fixture lacks an unknown trace"
    , testCase "every trace requires one plan"
        $ withTraceable twoPathGraph
        $ \model ->
            case NonEmpty.toList (effectTraces model) of
              planned:omitted:_ ->
                assertReadinessErrors
                  [MissingEvidencePlan (traceIdentifier omitted)]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (plannedStartsFor model)
                     (NonEmpty.singleton (planForTrace planned)))
              traces ->
                assertFailure
                  ("expected two traces, got " ++ show (length traces))
    , readinessFailureTest
        "plan must be established by the check time"
        readinessDate
        (\plan -> plan {establishedAt = afterReadinessDate})
        (\identifier -> [PlanEstablishedAfterCheck identifier])
    , testCase "readiness must be checked before planned start"
        $ withTraceable sampleGraph
        $ \model ->
            let intervention =
                  traceIntervention (NonEmpty.head (effectTraces model))
             in assertReadinessErrors
                  [ReadinessCheckedAtOrAfterPlannedStart intervention]
                  (validateEvidenceReadinessAt
                     interventionDate
                     model
                     (plannedStartsFor model)
                     (fmap planForTrace (effectTraces model)))
    , readinessFailureTest
        "baseline must be observed by the check time"
        readinessDate
        (mapBaseline (\item -> item {observedAt = afterReadinessDate}))
        (\identifier -> [BaselineObservedAfterCheck identifier])
    , readinessFailureTest
        "baseline cannot be later than the readiness check"
        readinessDate
        (mapBaseline (\item -> item {observedAt = interventionDate}))
        (\identifier -> [BaselineObservedAfterCheck identifier])
    , readinessFailureTest
        "target due date must follow intervention"
        readinessDate
        (\plan -> plan {targetDueAt = interventionDate})
        (\identifier -> [InvalidTargetDueDate identifier])
    , readinessFailureTest
        "baseline KPI must match the trace"
        readinessDate
        (mapBaseline (\item -> item {observationKPI = missingId}))
        (\identifier -> [BaselineKPIMismatch identifier measureKpiId missingId])
    , readinessFailureTest
        "baseline anchor must match the trace"
        readinessDate
        (mapBaseline (\item -> item {observationAnchor = missingId}))
        (\identifier ->
           [BaselineAnchorMismatch identifier situationAnchorId missingId])
    , readinessFailureTest
        "criterion units must match the baseline unit"
        readinessDate
        (\plan ->
           plan
             {effectCriterion = AbsoluteIncreaseByAtLeast (Quantity 10 count)})
        (\identifier -> [CriterionUnitMismatch identifier percent count])
    , readinessFailureTest
        "effect criterion magnitude must be positive"
        readinessDate
        (\plan ->
           plan
             {effectCriterion = AbsoluteIncreaseByAtLeast (Quantity 0 percent)})
        (\identifier -> [InvalidEffectCriterion identifier])
    , readinessFailureTest
        "relative effect criterion ratio must be positive"
        readinessDate
        (\plan ->
           plan {effectCriterion = RelativeIncreaseByAtLeast (RelativeChange 0)})
        (\identifier -> [InvalidEffectCriterion identifier])
    , readinessFailureTest
        "relative effect criterion requires nonzero baseline"
        readinessDate
        (\plan ->
           plan
             { baseline = observation 0 baselineDate percent
             , effectCriterion =
                 RelativeIncreaseByAtLeast (RelativeChange (1 / 10))
             })
        (\identifier -> [RelativeEffectCriterionWithZeroBaseline identifier])
    , readinessFailureTest
        "target criterion bounds must be valid"
        readinessDate
        (\plan ->
           plan
             { targetCriterion =
                 Within (Quantity 80 percent) (Quantity 70 percent)
             })
        (\identifier -> [InvalidTargetCriterion identifier])
    , readinessFailureTest
        "target criterion bounds must share one unit"
        readinessDate
        (\plan ->
           plan
             { targetCriterion =
                 Within (Quantity 70 percent) (Quantity 80 count)
             })
        (\identifier ->
           [ CriterionUnitMismatch identifier percent count
           , InvalidTargetCriterion identifier
           ])
    , readinessFailureTest
        "all plan units must be named"
        readinessDate
        (replacePlanUnit (NamedUnit " "))
        (\identifier -> [EmptyUnit identifier])
    , readinessFailureTest
        "plan provenance must be nonblank"
        readinessDate
        (\plan -> plan {planSource = EvidenceSource " "})
        (\identifier -> [EmptyPlanSource identifier])
    , readinessFailureTest
        "baseline provenance must be nonblank"
        readinessDate
        (mapBaseline (\item -> item {observationSource = EvidenceSource " "}))
        (\identifier -> [EmptyBaselineSource identifier])
    ]

effectEvidenceTests :: TestTree
effectEvidenceTests =
  testGroup
    "effect evidence"
    [ testCase "complete evidence is assessed"
        $ withAssessed id 75 followUpDate
        $ \assessed assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
            evidenceAssessedAt assessed @?= assessmentDate
            actualInterventionStarts assessed @?= [sampleActualStart]
    , testCase "effect can be supported before target achievement"
        $ withAssessed id 60 followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetNotSatisfiedInObservation
    , testCase "target achievement does not imply positive effect"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 72 baselineDate percent
                 , effectCriterion =
                     AbsoluteIncreaseByAtLeast (Quantity 10 percent)
                 })
            75
            followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= NotSatisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "satisfied observation after due is distinguished"
        $ withAssessed
            (\plan -> plan {targetDueAt = earlyTargetDate})
            75
            followUpDate
        $ \_ assessment ->
            targetResult assessment @?= TargetSatisfiedInObservationAfterDue
    , testCase "late actual start does not move the absolute target due time"
        $ withReadyPlan id
        $ \ready trace ->
            let lateStart = sampleActualStart {actualStartAt = assessmentDate}
                followUp = followUpForTrace trace 75 lateObservationDate percent
             in case assessEffectEvidenceAt
                       lateAssessmentDate
                       ready
                       [lateStart]
                       (NonEmpty.singleton followUp) of
                  Failure errors ->
                    assertFailure ("evidence errors: " ++ show errors)
                  Success assessed ->
                    targetResult (NonEmpty.head (effectAssessments assessed))
                      @?= TargetSatisfiedInObservationAfterDue
    , testCase "AtMost targets are assessed"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 60 baselineDate percent
                 , effectCriterion =
                     AbsoluteDecreaseByAtLeast (Quantity 10 percent)
                 , targetCriterion = AtMost (Quantity 50 percent)
                 })
            45
            followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "Within targets are assessed"
        $ withAssessed
            (\plan ->
               plan
                 { targetCriterion =
                     Within (Quantity 70 percent) (Quantity 80 percent)
                 })
            75
            followUpDate
        $ \_ assessment ->
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "absolute percentage delta is measured in percentage points"
        $ withAssessed id 50 followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "nine percentage points do not satisfy a ten-point delta"
        $ withAssessed id 49 followUpDate
        $ \_ assessment -> effectResult assessment @?= NotSatisfied
    , testCase "relative increase is distinct from absolute delta"
        $ withAssessed
            (\plan ->
               plan
                 { effectCriterion =
                     RelativeIncreaseByAtLeast (RelativeChange (1 / 10))
                 })
            44
            followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "relative decrease is assessed against baseline magnitude"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 100 baselineDate percent
                 , effectCriterion =
                     RelativeDecreaseByAtLeast (RelativeChange (1 / 10))
                 , targetCriterion = AtMost (Quantity 100 percent)
                 })
            90
            followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "one actual start governs all traces of an Intervention"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            assertSuccess
              (assessEffectEvidenceAt
                 assessmentDate
                 ready
                 [sampleActualStart]
                 (followUpsForReady ready 75 followUpDate percent))
    , testCase "actual start must be after the readiness check"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              let startAtReadiness =
                    sampleActualStart {actualStartAt = readinessDate}
               in assertEvidenceErrors
                    [ActualInterventionStartAtOrBeforeReadiness intervention]
                    (assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [startAtReadiness]
                       (followUpsForReady ready 75 followUpDate percent))
    , testCase "actual start before readiness is rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              let earlyStart =
                    sampleActualStart {actualStartAt = beforeReadinessDate}
               in assertEvidenceErrors
                    [ActualInterventionStartAtOrBeforeReadiness intervention]
                    (assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [earlyStart]
                       (followUpsForReady ready 75 followUpDate percent))
    , testCase "contradictory actual starts are rejected canonically"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            let contradictory =
                  sampleActualStart {actualStartAt = afterInterventionDate}
             in assertEvidenceErrors
                  [DuplicateActualInterventionStart interventionId 2]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart, contradictory]
                     (followUpsForReady ready 75 followUpDate percent))
    , testCase "unknown actual Intervention timing is rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let unknown = ActualInterventionStart missingId interventionDate
             in assertEvidenceErrors
                  [UnknownActualInterventionStart missingId]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart, unknown]
                     (followUpsForReady ready 75 followUpDate percent))
    , testCase "every ready Intervention requires actual timing"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              assertEvidenceErrors
                [MissingActualInterventionStart intervention]
                (assessEffectEvidenceAt
                   assessmentDate
                   ready
                   []
                   (followUpsForReady ready 75 followUpDate percent))
    , testCase "multiple follow-ups per trace are assessed independently"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let trace = NonEmpty.head (readyEffectTraces ready)
                first = followUpForTrace trace 60 followUpDate percent
                second = followUpForTrace trace 75 laterFollowUpDate percent
             in case assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [sampleActualStart]
                       (first NonEmpty.:| [second]) of
                  Failure errors ->
                    assertFailure ("evidence errors: " ++ show errors)
                  Success assessed ->
                    NonEmpty.length (effectAssessments assessed) @?= 2
    , testCase "duplicate trace and timestamp pairs are rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let trace = NonEmpty.head (readyEffectTraces ready)
                followUp = followUpForTrace trace 75 followUpDate percent
                identifier = traceIdentifier trace
             in assertEvidenceErrors
                  [DuplicateFollowUpObservation identifier followUpDate 2]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart]
                     (followUp NonEmpty.:| [followUp]))
    , testCase "every ready trace requires a follow-up"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            case NonEmpty.toList (readyEffectTraces ready) of
              observed:omitted:_ ->
                assertEvidenceErrors
                  [MissingFollowUpObservation (traceIdentifier omitted)]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart]
                     (NonEmpty.singleton
                        (followUpForTrace observed 75 followUpDate percent)))
              traces ->
                assertFailure
                  ("expected two traces, got " ++ show (length traces))
    , testCase "unknown follow-up traces are rejected exactly"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \twoPath ->
            case filter
                   ((/= interventionKeyResultId)
                      . unNodeId
                      . traceInterventionKeyResult)
                   (NonEmpty.toList (readyEffectTraces twoPath)) of
              unknownTrace:_ ->
                withReady sampleGraph [sampleStrategyFormulation] $ \single ->
                  let knownTrace = NonEmpty.head (readyEffectTraces single)
                      known =
                        followUpForTrace knownTrace 75 followUpDate percent
                      unknown =
                        followUpForTrace unknownTrace 75 followUpDate percent
                   in assertEvidenceErrors
                        [UnknownFollowUpTrace (traceIdentifier unknownTrace)]
                        (assessEffectEvidenceAt
                           assessmentDate
                           single
                           [sampleActualStart]
                           (known NonEmpty.:| [unknown]))
              [] -> assertFailure "two-path fixture lacks an unknown trace"
    , evidenceFailureTest
        "follow-up KPI must match the trace"
        (\item -> item {observationKPI = missingId})
        (\identifier _ ->
           [FollowUpKPIMismatch identifier measureKpiId missingId])
    , evidenceFailureTest
        "follow-up anchor must match the trace"
        (\item -> item {observationAnchor = missingId})
        (\identifier _ ->
           [FollowUpAnchorMismatch identifier situationAnchorId missingId])
    , evidenceFailureTest
        "follow-up unit must match the baseline"
        (\item -> item {observedValue = Quantity 75 count})
        (\identifier _ -> [FollowUpUnitMismatch identifier percent count])
    , evidenceFailureTest
        "follow-up must be observed after actual start"
        (\item -> item {observedAt = interventionDate})
        (\identifier _ -> [FollowUpObservedAtOrBeforeActualStart identifier])
    , evidenceFailureAtTest
        "future-dated follow-up is rejected"
        followUpDate
        (\item -> item {observedAt = laterFollowUpDate})
        (\identifier _ -> [FollowUpObservedAfterAssessment identifier])
    , evidenceFailureAtTest
        "actual start must precede assessment"
        interventionDate
        (\item -> item {observedAt = interventionDate})
        (\identifier intervention ->
           [ ActualInterventionStartAtOrAfterAssessment intervention
           , FollowUpObservedAtOrBeforeActualStart identifier
           ])
    , testCase "follow-up may be observed exactly at assessedAt"
        $ withReadyPlan id
        $ \ready trace ->
            assertSuccess
              (assessEffectEvidenceAt
                 followUpDate
                 ready
                 [sampleActualStart]
                 (NonEmpty.singleton
                    (followUpForTrace trace 75 followUpDate percent)))
    , evidenceFailureTest
        "follow-up unit must be named"
        (\item -> item {observedValue = Quantity 75 (NamedUnit " ")})
        (\identifier _ ->
           [ FollowUpUnitMismatch identifier percent (NamedUnit " ")
           , EmptyFollowUpUnit identifier
           ])
    , evidenceFailureTest
        "follow-up provenance must be nonblank"
        (\item -> item {observationSource = EvidenceSource " "})
        (\identifier _ -> [EmptyFollowUpSource identifier])
    , testCase "positive effect makes the traced Need effective"
        $ assertEffectiveNeed id 75 True
    , testCase "missing positive effect leaves the traced Need ineffective"
        $ assertEffectiveNeed
            (\plan -> plan {baseline = observation 72 baselineDate percent})
            75
            False
    , QC.testProperty "positive effect thresholds are accepted"
        $ QC.forAll (QC.chooseInteger (1, 100))
        $ \threshold ->
            evidenceSucceeds
              (\plan ->
                 plan
                   { effectCriterion =
                       AbsoluteIncreaseByAtLeast
                         (Quantity (fromInteger threshold) percent)
                   })
              (fromInteger threshold + 40)
    , QC.testProperty "both effect directions are assessed"
        $ QC.forAll ((,) <$> QC.arbitrary <*> QC.chooseInteger (1, 100))
        $ \(increases, threshold) ->
            directionalEvidenceSucceeds increases threshold
    ]

registryTests :: TestTree
registryTests =
  testGroup
    "typed registries"
    [ QC.testProperty
        "performance-dimension role lookup and reification round-trip"
        $ QC.forAll
            (QC.elements allPerformanceDimensionRoles)
            performanceDimensionRoleRoundTrips
    , testCase "every performance-dimension role code is represented"
        $ performanceDimensionRoleCodes @?= [minBound .. maxBound]
    , QC.testProperty "relation lookup round-trips"
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

performanceDimensionRoleRoundTrips :: SomePerformanceDimensionRole -> Bool
performanceDimensionRoleRoundTrips role =
  reifyPerformanceDimensionRole (performanceDimensionRoleCodeOf role) == role
    && lookupPerformanceDimensionRole context == Just role
  where
    (_, _, context, _) = performanceDimensionRoleIdentity role

performanceDimensionRoleCodes :: [PerformanceDimensionRoleCode]
performanceDimensionRoleCodes =
  map performanceDimensionRoleCodeOf allPerformanceDimensionRoles

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

withContextRef ::
     WellFormedGraph
  -> SContext context
  -> RawNodeId
  -> (ContextRef context -> Assertion)
  -> Assertion
withContextRef graph context identifier action =
  case lookupContextRef graph context identifier of
    Nothing -> assertFailure "validated Context reference was not found"
    Just reference -> action reference

withSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> (ContextRef context -> Assertion)
  -> Assertion
withSemanticContextRef model context identifier action =
  case lookupSemanticContextRef model context identifier of
    Nothing -> assertFailure "semantic Context reference was not found"
    Just reference -> action reference

withOnlyReadyIntervention ::
     EvidenceReadyModel -> (ContextRef 'Intervention -> Assertion) -> Assertion
withOnlyReadyIntervention ready action =
  case readyInterventions ready of
    [intervention] -> action intervention
    interventions ->
      assertFailure
        ("expected one ready Intervention, got " ++ show (length interventions))

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

assertReadinessErrors ::
     [EvidenceReadinessError]
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
  -> Assertion
assertReadinessErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid evidence readiness was accepted"

assertEvidenceErrors ::
     [EvidenceError]
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
  -> Assertion
assertEvidenceErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid evidence was accepted"

withReady ::
     RawGraph
  -> [RawStrategyFormulation]
  -> (EvidenceReadyModel -> Assertion)
  -> Assertion
withReady raw formulations action =
  withSemanticallyValid raw formulations $ \semantic ->
    case validateTraceability semantic of
      Failure errors -> assertFailure ("traceability errors: " ++ show errors)
      Success traceable ->
        case validateEvidenceReadinessAt
               readinessDate
               traceable
               (plannedStartsFor traceable)
               (fmap planForTrace (effectTraces traceable)) of
          Failure errors -> assertFailure ("readiness errors: " ++ show errors)
          Success ready -> action ready

withReadyPlan ::
     (EvidencePlan -> EvidencePlan)
  -> (EvidenceReadyModel -> EffectTrace -> Assertion)
  -> Assertion
withReadyPlan transform action =
  withTraceable sampleGraph $ \traceable ->
    let trace = NonEmpty.head (effectTraces traceable)
        plan = transform (planForTrace trace)
     in case validateEvidenceReadinessAt
               readinessDate
               traceable
               (plannedStartsFor traceable)
               (NonEmpty.singleton plan) of
          Failure errors -> assertFailure ("readiness errors: " ++ show errors)
          Success ready -> action ready trace

readinessFailureTest ::
     TestName
  -> UTCTime
  -> (EvidencePlan -> EvidencePlan)
  -> (EffectTraceId -> [EvidenceReadinessError])
  -> TestTree
readinessFailureTest name checkedAt transform expected =
  testCase name
    $ withTraceable sampleGraph
    $ \traceable ->
        let trace = NonEmpty.head (effectTraces traceable)
            plan = transform (planForTrace trace)
         in assertReadinessErrors
              (expected (traceIdentifier trace))
              (validateEvidenceReadinessAt
                 checkedAt
                 traceable
                 (plannedStartsFor traceable)
                 (NonEmpty.singleton plan))

evidenceFailureTest ::
     TestName
  -> (Observation -> Observation)
  -> (EffectTraceId -> ContextRef 'Intervention -> [EvidenceError])
  -> TestTree
evidenceFailureTest name transform expected =
  evidenceFailureAtTest name assessmentDate transform expected

evidenceFailureAtTest ::
     TestName
  -> UTCTime
  -> (Observation -> Observation)
  -> (EffectTraceId -> ContextRef 'Intervention -> [EvidenceError])
  -> TestTree
evidenceFailureAtTest name assessedAt transform expected =
  testCase name
    $ withReadyPlan id
    $ \ready trace ->
        let observation' = transform (observation 75 followUpDate percent)
            followUp = FollowUpObservation (traceIdentifier trace) observation'
         in assertEvidenceErrors
              (expected (traceIdentifier trace) (traceIntervention trace))
              (assessEffectEvidenceAt
                 assessedAt
                 ready
                 [sampleActualStart]
                 (NonEmpty.singleton followUp))

assertEffectiveNeed ::
     (EvidencePlan -> EvidencePlan) -> Rational -> Bool -> Assertion
assertEffectiveNeed transform followValue expected =
  withReadyPlan transform $ \ready trace ->
    let followUp = followUpForTrace trace followValue followUpDate percent
     in case assessEffectEvidenceAt
               assessmentDate
               ready
               [sampleActualStart]
               (NonEmpty.singleton followUp) of
          Failure errors -> assertFailure ("evidence errors: " ++ show errors)
          Success assessed ->
            isEffectiveNeed assessed (traceNeed trace) @?= expected

withAssessed ::
     (EvidencePlan -> EvidencePlan)
  -> Rational
  -> UTCTime
  -> (EvidenceAssessedModel -> EffectAssessment -> Assertion)
  -> Assertion
withAssessed transform followValue followTimestamp action =
  withReadyPlan transform $ \ready trace ->
    case assessEffectEvidenceAt
           assessmentDate
           ready
           [sampleActualStart]
           (NonEmpty.singleton
              (followUpForTrace trace followValue followTimestamp percent)) of
      Failure errors -> assertFailure ("evidence errors: " ++ show errors)
      Success assessed ->
        action assessed (NonEmpty.head (effectAssessments assessed))

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

evidenceSucceeds :: (EvidencePlan -> EvidencePlan) -> Rational -> Bool
evidenceSucceeds transform followValue =
  case validateSemanticRaw sampleGraph [sampleStrategyFormulation] of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success traceable ->
          let trace = NonEmpty.head (effectTraces traceable)
              plan = transform (planForTrace trace)
           in case validateEvidenceReadinessAt
                     readinessDate
                     traceable
                     (plannedStartsFor traceable)
                     (NonEmpty.singleton plan) of
                Failure _ -> False
                Success ready ->
                  case assessEffectEvidenceAt
                         assessmentDate
                         ready
                         [sampleActualStart]
                         (NonEmpty.singleton
                            (followUpForTrace
                               trace
                               followValue
                               followUpDate
                               percent)) of
                    Failure _ -> False
                    Success assessed ->
                      effectResult (NonEmpty.head (effectAssessments assessed))
                        == Satisfied

directionalEvidenceSucceeds :: Bool -> Integer -> Bool
directionalEvidenceSucceeds increases threshold =
  if increases
    then evidenceSucceeds
           (\plan -> plan {effectCriterion = AbsoluteIncreaseByAtLeast quantity})
           (40 + amount)
    else evidenceSucceeds
           (\plan ->
              plan
                { baseline = observation 100 baselineDate percent
                , effectCriterion = AbsoluteDecreaseByAtLeast quantity
                , targetCriterion = AtMost (Quantity 100 percent)
                })
           (100 - amount)
  where
    amount = fromInteger threshold
    quantity = Quantity amount percent

assertSuccess :: Validation errors result -> Assertion
assertSuccess (Success _) = pure ()
assertSuccess (Failure _) = assertFailure "expected validation success"

emptyGraph :: RawGraph
emptyGraph = RawGraph [] []

strategySuccessPerformanceDimensionGraph :: RawGraph
strategySuccessPerformanceDimensionGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
    , RawStructuringNode
        strategyPerformanceDimensionId
        strategyId
        PerformanceDimension
    ]
    [ edge
        strategyPerformanceDimensionId
        (containsPerformanceDimension StrategySuccessDimension)
        strategyKeyResultId
    ]

measureMeasurementPerformanceDimensionGraph :: RawGraph
measureMeasurementPerformanceDimensionGraph =
  RawGraph
    [ RawContextNode measureId Measure
    , RawPrimitiveNode measureKpiId measureId KPI
    , RawStructuringNode
        measurePerformanceDimensionId
        measureId
        PerformanceDimension
    ]
    [ edge
        measurePerformanceDimensionId
        (containsPerformanceDimension MeasureMeasurementDimension)
        measureKpiId
    ]

strategySuccessDimensionWithActionGraph :: RawGraph
strategySuccessDimensionWithActionGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawPrimitiveNode strategyActionId strategyId Action
    , RawStructuringNode
        strategyPerformanceDimensionId
        strategyId
        PerformanceDimension
    ]
    [ RawEdge
        strategyPerformanceDimensionId
        (relationNameFor (containsPerformanceDimension StrategySuccessDimension))
        strategyActionId
    ]

rawPerformanceDimensionOwnershipMatchesRegistry :: Context -> Bool
rawPerformanceDimensionOwnershipMatchesRegistry context =
  case (lookupPerformanceDimensionRole context, validateStructure raw) of
    (Just _, Success _) -> True
    (Nothing, Failure errors) ->
      NonEmpty.toList errors
        == [ InvalidStructuringContext
               genericPerformanceDimensionId
               context
               PerformanceDimension
           ]
    _ -> False
  where
    raw =
      RawGraph
        [ RawContextNode performanceDimensionOwnerId context
        , RawStructuringNode
            genericPerformanceDimensionId
            performanceDimensionOwnerId
            PerformanceDimension
        ]
        []

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
  , RawStructuringNode
      (duplicateId measurePerformanceDimensionId)
      measureId
      PerformanceDimension
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
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      (duplicateId measurePerformanceDimensionId)
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      (duplicateId measurePerformanceDimensionId)
  , edge
      (duplicateId measurePerformanceDimensionId)
      (containsPerformanceDimension MeasureMeasurementDimension)
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
    [ edge
        strategyDriverId
        indicatesMeasurePerformanceDimension
        measurePerformanceDimensionId
    , edge
        strategyKeyResultId
        determinesMeasurePerformanceDimension
        measurePerformanceDimensionId
    ]
    [ edge
        unlistedStrategyDriverId
        indicatesMeasurePerformanceDimension
        measurePerformanceDimensionId
    , edge
        unlistedStrategyKeyResultId
        determinesMeasurePerformanceDimension
        measurePerformanceDimensionId
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
  , RawStructuringNode
      measurePerformanceDimensionId
      measureId
      PerformanceDimension
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
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      measurePerformanceDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpiId
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

invalidRelationEndpointsGraph :: RawGraph
invalidRelationEndpointsGraph =
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

planForTrace :: EffectTrace -> EvidencePlan
planForTrace trace =
  EvidencePlan
    { plannedTrace = traceIdentifier trace
    , establishedAt = criteriaDate
    , targetDueAt = targetDate
    , planSource = EvidenceSource "approved measurement plan"
    , baseline = alignObservation trace (observation 40 baselineDate percent)
    , effectCriterion = AbsoluteIncreaseByAtLeast (Quantity 10 percent)
    , targetCriterion = AtLeast (Quantity 70 percent)
    }

plannedStartsFor :: TraceableEffectModel -> [PlannedInterventionStart]
plannedStartsFor model =
  [ samplePlannedStart {plannedIntervention = contextRefId intervention}
  | intervention <-
      nub (map traceIntervention (NonEmpty.toList (effectTraces model)))
  ]

samplePlannedStart :: PlannedInterventionStart
samplePlannedStart =
  PlannedInterventionStart
    {plannedIntervention = interventionId, plannedStartAt = interventionDate}

sampleActualStart :: ActualInterventionStart
sampleActualStart =
  ActualInterventionStart
    {actualIntervention = interventionId, actualStartAt = interventionDate}

followUpForTrace ::
     EffectTrace -> Rational -> UTCTime -> Unit -> FollowUpObservation
followUpForTrace trace value observationTime observationUnit =
  FollowUpObservation
    { followUpTrace = traceIdentifier trace
    , followUpObservation =
        alignObservation
          trace
          (observation value observationTime observationUnit)
    }

alignObservation :: EffectTrace -> Observation -> Observation
alignObservation trace item =
  item
    { observationKPI = unNodeId (traceKPI trace)
    , observationAnchor = situationAnchorRefId (traceSituationAnchor trace)
    }

followUpsForReady ::
     EvidenceReadyModel
  -> Rational
  -> UTCTime
  -> Unit
  -> NonEmpty.NonEmpty FollowUpObservation
followUpsForReady ready value observationTime observationUnit =
  fmap
    (\trace -> followUpForTrace trace value observationTime observationUnit)
    (readyEffectTraces ready)

mapBaseline :: (Observation -> Observation) -> EvidencePlan -> EvidencePlan
mapBaseline transform plan = plan {baseline = transform (baseline plan)}

replacePlanUnit :: Unit -> EvidencePlan -> EvidencePlan
replacePlanUnit replacement plan =
  plan
    { baseline =
        (baseline plan)
          {observedValue = (observedValue (baseline plan)) {unit = replacement}}
    , effectCriterion = replaceEffectUnit (effectCriterion plan)
    , targetCriterion = replaceTargetUnit (targetCriterion plan)
    }
  where
    replaceQuantityUnit quantity = quantity {unit = replacement}
    replaceEffectUnit (AbsoluteIncreaseByAtLeast quantity) =
      AbsoluteIncreaseByAtLeast (replaceQuantityUnit quantity)
    replaceEffectUnit (AbsoluteDecreaseByAtLeast quantity) =
      AbsoluteDecreaseByAtLeast (replaceQuantityUnit quantity)
    replaceEffectUnit criterion@(RelativeIncreaseByAtLeast _) = criterion
    replaceEffectUnit criterion@(RelativeDecreaseByAtLeast _) = criterion
    replaceTargetUnit (AtLeast quantity) =
      AtLeast (replaceQuantityUnit quantity)
    replaceTargetUnit (AtMost quantity) = AtMost (replaceQuantityUnit quantity)
    replaceTargetUnit (Within lower upper) =
      Within (replaceQuantityUnit lower) (replaceQuantityUnit upper)

observation :: Rational -> UTCTime -> Unit -> Observation
observation value observedTimestamp valueUnit =
  Observation
    { observationKPI = measureKpiId
    , observationAnchor = situationAnchorId
    , observedAt = observedTimestamp
    , observedValue = Quantity value valueUnit
    , observationSource = EvidenceSource "decision registry"
    }

criteriaDate, baselineDate, beforeReadinessDate, readinessDate :: UTCTime
criteriaDate = timestamp 2025 12 1

baselineDate = timestamp 2026 1 1

beforeReadinessDate = timestamp 2026 1 10

readinessDate = timestamp 2026 1 15

afterReadinessDate :: UTCTime
afterReadinessDate = timestamp 2026 1 20

interventionDate, afterInterventionDate, earlyTargetDate :: UTCTime
interventionDate = timestamp 2026 2 1

afterInterventionDate = timestamp 2026 3 1

earlyTargetDate = timestamp 2026 2 15

targetDate, followUpDate, laterFollowUpDate, assessmentDate :: UTCTime
targetDate = timestamp 2026 6 30

followUpDate = timestamp 2026 6 1

laterFollowUpDate = timestamp 2026 6 15

assessmentDate = timestamp 2026 7 1

lateObservationDate, lateAssessmentDate :: UTCTime
lateObservationDate = timestamp 2026 7 15

lateAssessmentDate = timestamp 2026 8 1

timestamp :: Integer -> Int -> Int -> UTCTime
timestamp year month day =
  UTCTime (fromGregorian year month day) (secondsToDiffTime 0)

percent, count :: Unit
percent = PercentagePoints

count = NamedUnit "count"

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

interventionKeyResultId, measureKpiId, measurePerformanceDimensionId ::
     RawNodeId
interventionKeyResultId = RawNodeId "intervention-key-result"

measureKpiId = RawNodeId "measure-kpi"

measurePerformanceDimensionId = RawNodeId "measure-performance-dimension"

strategyPerformanceDimensionId, performanceDimensionOwnerId, genericPerformanceDimensionId ::
     RawNodeId
strategyPerformanceDimensionId = RawNodeId "strategy-performance-dimension"

performanceDimensionOwnerId = RawNodeId "performance-dimension-owner"

genericPerformanceDimensionId = RawNodeId "performance-dimension"

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
