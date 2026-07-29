{-# LANGUAGE OverloadedStrings #-}

-- | Semantically admitted graph families for effect-trace evaluation.
module O2I.Validation.Trace.Eval.Test.Scenarios
  ( allAnchorKindsScenario
  , anchorFanOutScenario
  , addressedNeedMeasureScenario
  , convergentKeyResultScenario
  , mismatchedSpinesScenario
  , needObjectiveFanOutScenario
  , permuteScenario
  , shortCircuitEarlyScenario
  , shortCircuitLateScenario
  , strategyActionFanOutScenario
  , strategySituationFanOutScenario
  , targetMeasureSituationScenario
  , unconstitutedAnchorFanOutScenario
  , unconstitutedAnchorIds
  , unreachableContextsScenario
  , visionFanOutScenario
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Test.Fixture
  ( registryFormulations
  , registryGraph
  )
import O2I.Validation.Semantics.Context (RawStrategyFormulation(..))
import O2I.Validation.Trace.Eval.Test.Fixture
  ( TraceScenario(..)
  , baselineScenario
  )

allAnchorKindsScenario :: TraceScenario
allAnchorKindsScenario =
  addScenario
    (concatMap
       anchorNodes
       [(BusinessProcess, 1), (BusinessObject, 1), (ValueStream, 1)])
    (concatMap
       anchorEdges
       [(BusinessProcess, 1), (BusinessObject, 1), (ValueStream, 1)])
    []
    baselineScenario

anchorFanOutScenario :: Int -> TraceScenario
anchorFanOutScenario count =
  addScenario
    (concatMap anchorNodes anchors)
    (concatMap anchorEdges anchors)
    []
    baselineScenario
  where
    anchors = [(BusinessProcess, ordinal) | ordinal <- [1 .. count]]

permuteScenario :: TraceScenario -> TraceScenario
permuteScenario scenario =
  scenario
    { traceScenarioGraph =
        (traceScenarioGraph scenario)
          { rawNodes = reverse (rawNodes (traceScenarioGraph scenario))
          , rawEdges = reverse (rawEdges (traceScenarioGraph scenario))
          }
    , traceScenarioFormulations = reverse (traceScenarioFormulations scenario)
    }

unreachableContextsScenario :: Int -> TraceScenario
unreachableContextsScenario count =
  addScenario
    (concatMap unreachableNodes ordinals)
    (concatMap unreachableSemanticEdges ordinals)
    (concatMap unreachableFormulations ordinals)
    baselineScenario
  where
    ordinals = [1 .. count]

mismatchedSpinesScenario :: Int -> TraceScenario
mismatchedSpinesScenario count =
  addScenario
    []
    (concatMap mismatchedContextEdges ordinals)
    []
    (unreachableContextsScenario count)
  where
    ordinals = [1 .. count]

strategySituationFanOutScenario :: Int -> TraceScenario
strategySituationFanOutScenario count =
  addScenario
    (concatMap situationNodes ordinals)
    (concatMap partialSituationEdges ordinals)
    []
    baselineScenario
  where
    ordinals = [1 .. count]

targetMeasureSituationScenario :: Int -> TraceScenario
targetMeasureSituationScenario count =
  addScenario
    (concatMap measureSituationNodes ordinals)
    (concatMap measureSituationEdges ordinals)
    []
    baselineScenario
  where
    ordinals = [1 .. count]

addressedNeedMeasureScenario :: Int -> TraceScenario
addressedNeedMeasureScenario count =
  addScenario
    (concatMap completePathNodes ordinals)
    (concatMap completePathEdges ordinals)
    (concatMap completePathFormulations ordinals)
    baselineScenario
  where
    ordinals = [1 .. count]

strategyActionFanOutScenario :: Int -> TraceScenario
strategyActionFanOutScenario count =
  extendPrimaryRoles
    strategyActions
    strategyKeyResults
    (addScenario
       (concatMap strategyActionNodes ordinals)
       (concatMap strategyActionEdges ordinals)
       []
       baselineScenario)
  where
    ordinals = [1 .. count]
    strategyActions = map (`axisId` "strategy-action") ordinals
    strategyKeyResults = map (`axisId` "strategy-key-result") ordinals

needObjectiveFanOutScenario :: Int -> TraceScenario
needObjectiveFanOutScenario count =
  addScenario
    [ RawPrimitiveNode (axisId ordinal "need-objective") needId Objective
    | ordinal <- [1 .. count]
    ]
    (concatMap needObjectiveEdges [1 .. count])
    []
    baselineScenario

visionFanOutScenario :: Int -> TraceScenario
visionFanOutScenario count =
  addScenario
    (concatMap visionNodes [1 .. count])
    (concatMap visionEdges [1 .. count])
    []
    baselineScenario

convergentKeyResultScenario :: Int -> TraceScenario
convergentKeyResultScenario count =
  extendPrimaryRoles
    strategyActions
    strategyKeyResults
    (addScenario
       (concatMap convergentNodes ordinals)
       (concatMap convergentEdges ordinals)
       []
       baselineScenario)
  where
    ordinals = [1 .. count]
    strategyActions = map (`axisId` "convergent-strategy-action") ordinals
    strategyKeyResults =
      map (`axisId` "convergent-strategy-key-result") ordinals

shortCircuitEarlyScenario :: TraceScenario
shortCircuitEarlyScenario =
  baselineScenario
    { traceScenarioGraph =
        registryGraph
          { rawEdges =
              removeEdge
                interventionKeyResultId
                (relationNameFor
                   contributesInterventionKeyResultToStrategyKeyResult)
                strategyKeyResultId
                (rawEdges registryGraph)
          }
    }

shortCircuitLateScenario :: TraceScenario
shortCircuitLateScenario =
  baselineScenario
    { traceScenarioGraph =
        registryGraph
          { rawEdges =
              removeEdge
                measureKPIId
                (anchorRelationFamilyName MeasuresAnchorFamily)
                situationAnchorId
                (rawEdges registryGraph)
          }
    }

unconstitutedAnchorFanOutScenario :: Int -> TraceScenario
unconstitutedAnchorFanOutScenario count =
  addScenario
    [RawAnchorNode identifier BusinessProcess | identifier <- identifiers]
    (concatMap unconstitutedAnchorEdges identifiers)
    []
    baselineScenario
  where
    identifiers = unconstitutedAnchorIds count

unconstitutedAnchorIds :: Int -> [RawNodeId]
unconstitutedAnchorIds count =
  [axisId ordinal "unconstituted-anchor" | ordinal <- [1 .. count]]

addScenario ::
     [RawNode]
  -> [RawEdge]
  -> [RawStrategyFormulation]
  -> TraceScenario
  -> TraceScenario
addScenario nodes edges formulations scenario =
  scenario
    { traceScenarioGraph =
        (traceScenarioGraph scenario)
          { rawNodes = rawNodes (traceScenarioGraph scenario) ++ nodes
          , rawEdges = rawEdges (traceScenarioGraph scenario) ++ edges
          }
    , traceScenarioFormulations =
        traceScenarioFormulations scenario ++ formulations
    }

extendPrimaryRoles ::
     [RawNodeId] -> [RawNodeId] -> TraceScenario -> TraceScenario
extendPrimaryRoles actions keyResults scenario =
  case traceScenarioFormulations scenario of
    formulation:_ ->
      scenario
        { traceScenarioFormulations =
            formulation
              { rawFormulationActions =
                  appendNonEmpty (rawFormulationActions formulation) actions
              , rawFormulationKeyResults =
                  appendNonEmpty
                    (rawFormulationKeyResults formulation)
                    keyResults
              }
              : drop 1 (traceScenarioFormulations scenario)
        }
    [] -> scenario

appendNonEmpty :: NonEmpty value -> [value] -> NonEmpty value
appendNonEmpty existing additions =
  case additions of
    [] -> existing
    first:rest -> existing <> (first :| rest)

unreachableNodes :: Int -> [RawNode]
unreachableNodes ordinal =
  [ RawContextNode (unreachableId ordinal "vision") Vision
  , RawPrimitiveNode
      (unreachableId ordinal "vision-objective")
      (unreachableId ordinal "vision")
      Objective
  , RawContextNode (unreachableId ordinal "strategy") Strategy
  , RawPrimitiveNode
      (unreachableId ordinal "strategy-driver")
      (unreachableId ordinal "strategy")
      Driver
  , RawPrimitiveNode
      (unreachableId ordinal "strategy-objective")
      (unreachableId ordinal "strategy")
      Objective
  , RawPrimitiveNode
      (unreachableId ordinal "strategy-principle")
      (unreachableId ordinal "strategy")
      Principle
  , RawPrimitiveNode
      (unreachableId ordinal "strategy-action")
      (unreachableId ordinal "strategy")
      Action
  , RawPrimitiveNode
      (unreachableId ordinal "strategy-key-result")
      (unreachableId ordinal "strategy")
      KeyResult
  , RawContextNode (unreachableId ordinal "need") Need
  , RawPrimitiveNode
      (unreachableId ordinal "need-driver")
      (unreachableId ordinal "need")
      Driver
  , RawPrimitiveNode
      (unreachableId ordinal "need-objective")
      (unreachableId ordinal "need")
      Objective
  , RawContextNode (unreachableId ordinal "intervention") Intervention
  , RawPrimitiveNode
      (unreachableId ordinal "intervention-action")
      (unreachableId ordinal "intervention")
      Action
  , RawPrimitiveNode
      (unreachableId ordinal "intervention-key-result")
      (unreachableId ordinal "intervention")
      KeyResult
  , RawContextNode (unreachableId ordinal "measure") Measure
  , RawStructuringNode
      (unreachableId ordinal "measure-dimension")
      (unreachableId ordinal "measure")
      PerformanceDimension
  , RawPrimitiveNode
      (unreachableId ordinal "measure-kpi")
      (unreachableId ordinal "measure")
      KPI
  , RawContextNode (unreachableId ordinal "situation") Situation
  , RawAnchorNode (unreachableId ordinal "situation-anchor") BusinessCapability
  ]

unreachableSemanticEdges :: Int -> [RawEdge]
unreachableSemanticEdges ordinal =
  [ edge
      missionDriverId
      groundsMissionDriverToVisionObjective
      (unreachableId ordinal "vision-objective")
  , edge
      ethosPrincipleId
      guidesEthosPrincipleToVisionObjective
      (unreachableId ordinal "vision-objective")
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      (unreachableId ordinal "strategy-objective")
  , edge
      (unreachableId ordinal "strategy-driver")
      groundsStrategyDriverToObjective
      (unreachableId ordinal "strategy-objective")
  , edge
      (unreachableId ordinal "strategy-principle")
      guidesStrategyPrincipleToAction
      (unreachableId ordinal "strategy-action")
  , edge
      (unreachableId ordinal "strategy-action")
      contributesStrategyActionToKeyResult
      (unreachableId ordinal "strategy-key-result")
  , edge
      (unreachableId ordinal "strategy-key-result")
      substantiatesStrategyKeyResultObjective
      (unreachableId ordinal "strategy-objective")
  , edge
      (unreachableId ordinal "need-driver")
      groundsNeedDriverToObjective
      (unreachableId ordinal "need-objective")
  , edge situationId surfacesNeed (unreachableId ordinal "need")
  , anchorEdge
      situationAnchorId
      AnchorsNeedDriverFamily
      (unreachableId ordinal "need-driver")
  , edge
      (unreachableId ordinal "intervention-action")
      contributesInterventionActionToKeyResult
      (unreachableId ordinal "intervention-key-result")
  , edge
      (unreachableId ordinal "measure-dimension")
      (containsPerformanceDimension MeasureMeasurementDimension)
      (unreachableId ordinal "measure-kpi")
  , anchorEdge
      (unreachableId ordinal "situation")
      ConstitutedByAnchorFamily
      (unreachableId ordinal "situation-anchor")
  ]

unreachableFormulations :: Int -> [RawStrategyFormulation]
unreachableFormulations ordinal =
  case registryFormulations of
    formulation:_ ->
      [ formulation
          { rawFormulationStrategy = unreachableId ordinal "strategy"
          , rawFormulationDiagnosis = unreachableId ordinal "strategy-driver"
          , rawFormulationIntent = unreachableId ordinal "strategy-objective"
          , rawFormulationGuidingPolicy =
              unreachableId ordinal "strategy-principle"
          , rawFormulationActions =
              unreachableId ordinal "strategy-action" :| []
          , rawFormulationKeyResults =
              unreachableId ordinal "strategy-key-result" :| []
          }
      ]
    [] -> []

mismatchedContextEdges :: Int -> [RawEdge]
mismatchedContextEdges ordinal =
  [ edge
      (unreachableId ordinal "vision")
      orientsStrategy
      (unreachableId ordinal "strategy")
  , edge
      (unreachableId ordinal "strategy")
      qualifiesNeed
      (unreachableId ordinal "need")
  , edge
      (unreachableId ordinal "strategy")
      directsIntervention
      (unreachableId ordinal "intervention")
  , edge
      (unreachableId ordinal "strategy")
      framesMeasure
      (unreachableId ordinal "measure")
  , edge
      (unreachableId ordinal "intervention")
      addressesNeed
      (unreachableId ordinal "need")
  , edge
      (unreachableId ordinal "intervention")
      setsTargetForMeasure
      (unreachableId ordinal "measure")
  , edge
      (unreachableId ordinal "measure")
      measuresSituation
      (unreachableId ordinal "situation")
  , edge (unreachableId ordinal "intervention") changesSituation situationId
  , edge
      (unreachableId ordinal "situation")
      surfacesNeed
      (unreachableId ordinal "need")
  ]

situationNodes :: Int -> [RawNode]
situationNodes ordinal =
  [ RawContextNode (axisId ordinal "situation") Situation
  , RawAnchorNode (axisId ordinal "situation-anchor") BusinessCapability
  ]

partialSituationEdges :: Int -> [RawEdge]
partialSituationEdges ordinal =
  [ anchorEdge
      (axisId ordinal "situation")
      ConstitutedByAnchorFamily
      (axisId ordinal "situation-anchor")
  , edge measureId measuresSituation (axisId ordinal "situation")
  , edge interventionId changesSituation (axisId ordinal "situation")
  ]

measureSituationNodes :: Int -> [RawNode]
measureSituationNodes ordinal =
  [ RawContextNode (axisId ordinal "measure") Measure
  , RawStructuringNode
      (axisId ordinal "measure-dimension")
      (axisId ordinal "measure")
      PerformanceDimension
  , RawPrimitiveNode
      (axisId ordinal "measure-kpi")
      (axisId ordinal "measure")
      KPI
  ]
    ++ situationNodes ordinal

measureSituationEdges :: Int -> [RawEdge]
measureSituationEdges ordinal =
  [ edge strategyId framesMeasure measure
  , edge interventionId setsTargetForMeasure measure
  , edge measure measuresSituation situation
  , edge interventionId changesSituation situation
  , edge situation surfacesNeed needId
  , edge strategyDriverId indicatesMeasurePerformanceDimension dimension
  , edge strategyKeyResultId determinesMeasurePerformanceDimension dimension
  , edge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      kpi
  , edge interventionKeyResultId setsTargetForMeasureKPI kpi
  , anchorEdge kpi MeasuresAnchorFamily anchor
  , anchorEdge interventionActionId ChangesAnchorFamily anchor
  , anchorEdge anchor AnchorsNeedDriverFamily needDriverId
  , anchorEdge situation ConstitutedByAnchorFamily anchor
  ]
  where
    measure = axisId ordinal "measure"
    dimension = axisId ordinal "measure-dimension"
    kpi = axisId ordinal "measure-kpi"
    situation = axisId ordinal "situation"
    anchor = axisId ordinal "situation-anchor"

strategyActionNodes :: Int -> [RawNode]
strategyActionNodes ordinal =
  [ RawPrimitiveNode (axisId ordinal "strategy-action") strategyId Action
  , RawPrimitiveNode (axisId ordinal "strategy-key-result") strategyId KeyResult
  ]

strategyActionEdges :: Int -> [RawEdge]
strategyActionEdges ordinal =
  [ edge strategyPrincipleId guidesStrategyPrincipleToAction action
  , edge action contributesStrategyActionToKeyResult keyResult
  , edge keyResult substantiatesStrategyKeyResultObjective strategyObjectiveId
  , edge action guidesStrategyActionToInterventionAction interventionActionId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      keyResult
  , edge keyResult translatesStrategyKeyResultToNeedObjective needObjectiveId
  , edge keyResult determinesMeasurePerformanceDimension measureDimensionId
  ]
  where
    action = axisId ordinal "strategy-action"
    keyResult = axisId ordinal "strategy-key-result"

needObjectiveEdges :: Int -> [RawEdge]
needObjectiveEdges ordinal =
  [ edge needDriverId groundsNeedDriverToObjective objective
  , edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      objective
  , edge
      interventionKeyResultId
      substantiatesInterventionKeyResultNeedObjective
      objective
  ]
  where
    objective = axisId ordinal "need-objective"

visionNodes :: Int -> [RawNode]
visionNodes ordinal =
  [RawContextNode vision Vision, RawPrimitiveNode objective vision Objective]
  where
    vision = axisId ordinal "vision"
    objective = axisId ordinal "vision-objective"

visionEdges :: Int -> [RawEdge]
visionEdges ordinal =
  [ edge missionDriverId groundsMissionDriverToVisionObjective objective
  , edge ethosPrincipleId guidesEthosPrincipleToVisionObjective objective
  , edge vision orientsStrategy strategyId
  , edge objective orientsVisionObjectiveToStrategyObjective strategyObjectiveId
  ]
  where
    vision = axisId ordinal "vision"
    objective = axisId ordinal "vision-objective"

convergentNodes :: Int -> [RawNode]
convergentNodes ordinal =
  [ RawPrimitiveNode strategyAction strategyId Action
  , RawPrimitiveNode strategyKeyResult strategyId KeyResult
  , RawPrimitiveNode interventionAction interventionId Action
  , RawPrimitiveNode interventionKeyResult interventionId KeyResult
  , RawPrimitiveNode needObjective needId Objective
  ]
  where
    strategyAction = axisId ordinal "convergent-strategy-action"
    strategyKeyResult = axisId ordinal "convergent-strategy-key-result"
    interventionAction = axisId ordinal "convergent-intervention-action"
    interventionKeyResult = axisId ordinal "convergent-intervention-key-result"
    needObjective = axisId ordinal "convergent-need-objective"

convergentEdges :: Int -> [RawEdge]
convergentEdges ordinal =
  [ edge strategyPrincipleId guidesStrategyPrincipleToAction strategyAction
  , edge strategyAction contributesStrategyActionToKeyResult strategyKeyResult
  , edge
      strategyKeyResult
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , edge
      strategyAction
      guidesStrategyActionToInterventionAction
      interventionAction
  , edge
      interventionAction
      contributesInterventionActionToKeyResult
      interventionKeyResult
  , edge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , edge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , edge needDriverId groundsNeedDriverToObjective needObjective
  , edge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , edge
      strategyKeyResult
      determinesMeasurePerformanceDimension
      measureDimensionId
  , edge interventionKeyResult setsTargetForMeasureKPI measureKPIId
  , anchorEdge interventionAction ChangesAnchorFamily situationAnchorId
  ]
  where
    strategyAction = axisId ordinal "convergent-strategy-action"
    strategyKeyResult = axisId ordinal "convergent-strategy-key-result"
    interventionAction = axisId ordinal "convergent-intervention-action"
    interventionKeyResult = axisId ordinal "convergent-intervention-key-result"
    needObjective = axisId ordinal "convergent-need-objective"

completePathNodes :: Int -> [RawNode]
completePathNodes = unreachableNodes

completePathEdges :: Int -> [RawEdge]
completePathEdges ordinal =
  [ edge vision orientsStrategy strategy
  , edge strategy qualifiesNeed need
  , edge strategy directsIntervention intervention
  , edge strategy framesMeasure measure
  , edge intervention addressesNeed need
  , edge intervention setsTargetForMeasure measure
  , edge intervention changesSituation situation
  , edge measure measuresSituation situation
  , edge situation surfacesNeed need
  , edge
      visionObjective
      orientsVisionObjectiveToStrategyObjective
      strategyObjective
  , edge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , edge
      strategyAction
      guidesStrategyActionToInterventionAction
      interventionAction
  , edge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , edge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , edge strategyDriver indicatesMeasurePerformanceDimension measureDimension
  , edge
      strategyKeyResult
      determinesMeasurePerformanceDimension
      measureDimension
  , edge interventionKeyResult setsTargetForMeasureKPI measureKPI
  , anchorEdge measureKPI MeasuresAnchorFamily anchor
  , anchorEdge interventionAction ChangesAnchorFamily anchor
  , anchorEdge anchor AnchorsNeedDriverFamily needDriver
  ]
    ++ unreachableSemanticEdges ordinal
  where
    vision = unreachableId ordinal "vision"
    visionObjective = unreachableId ordinal "vision-objective"
    strategy = unreachableId ordinal "strategy"
    strategyDriver = unreachableId ordinal "strategy-driver"
    strategyObjective = unreachableId ordinal "strategy-objective"
    strategyAction = unreachableId ordinal "strategy-action"
    strategyKeyResult = unreachableId ordinal "strategy-key-result"
    need = unreachableId ordinal "need"
    needDriver = unreachableId ordinal "need-driver"
    needObjective = unreachableId ordinal "need-objective"
    intervention = unreachableId ordinal "intervention"
    interventionAction = unreachableId ordinal "intervention-action"
    interventionKeyResult = unreachableId ordinal "intervention-key-result"
    measure = unreachableId ordinal "measure"
    measureDimension = unreachableId ordinal "measure-dimension"
    measureKPI = unreachableId ordinal "measure-kpi"
    situation = unreachableId ordinal "situation"
    anchor = unreachableId ordinal "situation-anchor"

completePathFormulations :: Int -> [RawStrategyFormulation]
completePathFormulations = unreachableFormulations

anchorNodes :: (SituationAnchor, Int) -> [RawNode]
anchorNodes (kind, ordinal) = [RawAnchorNode (anchorId kind ordinal) kind]

anchorEdges :: (SituationAnchor, Int) -> [RawEdge]
anchorEdges (kind, ordinal) =
  [ anchorEdge situationId ConstitutedByAnchorFamily anchor
  , anchorEdge anchor AnchorsNeedDriverFamily needDriverId
  , anchorEdge interventionActionId ChangesAnchorFamily anchor
  , anchorEdge measureKPIId MeasuresAnchorFamily anchor
  ]
  where
    anchor = anchorId kind ordinal

unconstitutedAnchorEdges :: RawNodeId -> [RawEdge]
unconstitutedAnchorEdges anchor =
  [ anchorEdge anchor AnchorsNeedDriverFamily needDriverId
  , anchorEdge interventionActionId ChangesAnchorFamily anchor
  , anchorEdge measureKPIId MeasuresAnchorFamily anchor
  ]

removeEdge :: RawNodeId -> RelationName -> RawNodeId -> [RawEdge] -> [RawEdge]
removeEdge from relation to =
  filter
    (\candidate ->
       rawEdgeFrom candidate /= from
         || rawEdgeRelation candidate /= relation
         || rawEdgeTo candidate /= to)

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge :: RawNodeId -> AnchorRelationFamily -> RawNodeId -> RawEdge
anchorEdge from family to = RawEdge from (anchorRelationFamilyName family) to

axisId :: Int -> Text -> RawNodeId
axisId ordinal suffix =
  RawNodeId ("eval-" <> Text.pack (show ordinal) <> "-" <> suffix)

unreachableId :: Int -> Text -> RawNodeId
unreachableId ordinal suffix =
  RawNodeId ("eval-unreachable-" <> Text.pack (show ordinal) <> "-" <> suffix)

anchorId :: SituationAnchor -> Int -> RawNodeId
anchorId kind ordinal =
  axisId
    ordinal
    (case kind of
       BusinessCapability -> "business-capability"
       BusinessProcess -> "business-process"
       BusinessObject -> "business-object"
       ValueStream -> "value-stream")

ethosPrincipleId, missionDriverId, visionObjectiveId :: RawNodeId
ethosPrincipleId = RawNodeId "ethos-principle"

missionDriverId = RawNodeId "mission-driver"

visionObjectiveId = RawNodeId "vision-objective"

strategyId, strategyDriverId, strategyObjectiveId, strategyPrincipleId ::
     RawNodeId
strategyId = RawNodeId "strategy"

strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyPrincipleId = RawNodeId "strategy-principle"

strategyKeyResultId :: RawNodeId
strategyKeyResultId = RawNodeId "strategy-key-result-0"

needId, needDriverId, needObjectiveId :: RawNodeId
needId = RawNodeId "need"

needDriverId = RawNodeId "need-driver"

needObjectiveId = RawNodeId "need-objective"

interventionId, interventionActionId, interventionKeyResultId :: RawNodeId
interventionId = RawNodeId "intervention"

interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId = RawNodeId "intervention-key-result"

measureId, measureDimensionId, measureKPIId :: RawNodeId
measureId = RawNodeId "measure"

measureDimensionId = RawNodeId "measure-dimension-0"

measureKPIId = RawNodeId "measure-kpi-0"

situationId, situationAnchorId :: RawNodeId
situationId = RawNodeId "situation"

situationAnchorId = RawNodeId "situation-anchor"
