{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Shared typed fixture vocabulary for private effect-trace search tests.
module O2I.Validation.Trace.Search.Test.Fixture where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation
import O2I.Validation.Trace.Search

macroSituationEdges :: RawNodeId -> [SomeEdge]
macroSituationEdges situation =
  [ typedEdge interventionId changesSituation situation
  , typedEdge situation surfacesNeed needId
  , typedEdge measureId measuresSituation situation
  ]

strategyRoles :: Map.Map RawNodeId TraceStrategyRoles
strategyRoles =
  Map.singleton
    strategyId
    TraceStrategyRoles
      { traceRoleDriver = strategyDriverId
      , traceRoleObjective = strategyObjectiveId
      , traceRoleKeyResults = [strategyKeyResultId]
      , traceRoleActions = [strategyActionId]
      }

strategyRolesWithFanOut :: Int -> Map.Map RawNodeId TraceStrategyRoles
strategyRolesWithFanOut count =
  Map.union
    strategyRoles
    (Map.fromList
       [ ( strategySituationId ordinal "strategy"
         , TraceStrategyRoles
             { traceRoleDriver = strategySituationId ordinal "strategy-driver"
             , traceRoleObjective =
                 strategySituationId ordinal "strategy-objective"
             , traceRoleKeyResults =
                 [strategySituationId ordinal "strategy-key-result"]
             , traceRoleActions =
                 [strategySituationId ordinal "strategy-action"]
             })
       | ordinal <- [1 .. count]
       ])

needMeasureRoles :: Int -> Map.Map RawNodeId TraceStrategyRoles
needMeasureRoles count =
  Map.fromList
    [ ( needMeasureId ordinal "strategy"
      , TraceStrategyRoles
          { traceRoleDriver = needMeasureId ordinal "strategy-driver"
          , traceRoleObjective = needMeasureId ordinal "strategy-objective"
          , traceRoleKeyResults = [needMeasureId ordinal "strategy-key-result"]
          , traceRoleActions = [needMeasureId ordinal "strategy-action"]
          })
    | ordinal <- [1 .. count]
    ]

strategyActionFanOutRoles :: Int -> Map.Map RawNodeId TraceStrategyRoles
strategyActionFanOutRoles count =
  Map.singleton
    strategyId
    TraceStrategyRoles
      { traceRoleDriver = strategyDriverId
      , traceRoleObjective = strategyObjectiveId
      , traceRoleKeyResults =
          strategyKeyResultId
            : [ strategyActionFanOutId ordinal "strategy-key-result"
              | ordinal <- [1 .. count]
              ]
      , traceRoleActions =
          strategyActionId
            : [ strategyActionFanOutId ordinal "strategy-action"
              | ordinal <- [1 .. count]
              ]
      }

needObjectiveFanOutRoles :: Int -> Map.Map RawNodeId TraceStrategyRoles
needObjectiveFanOutRoles count =
  Map.singleton
    strategyId
    TraceStrategyRoles
      { traceRoleDriver = strategyDriverId
      , traceRoleObjective = strategyObjectiveId
      , traceRoleKeyResults =
          strategyKeyResultId
            : [ needObjectiveFanOutId ordinal "strategy-key-result"
              | ordinal <- [1 .. count]
              ]
      , traceRoleActions = [strategyActionId]
      }

convergentKeyResultRoles :: Int -> Map.Map RawNodeId TraceStrategyRoles
convergentKeyResultRoles count =
  Map.singleton
    strategyId
    TraceStrategyRoles
      { traceRoleDriver = strategyDriverId
      , traceRoleObjective = strategyObjectiveId
      , traceRoleKeyResults =
          strategyKeyResultId
            : [convergentStrategyKeyResultId ordinal | ordinal <- [1 .. count]]
      , traceRoleActions = [strategyActionId]
      }

contextNode :: RawNodeId -> SContext context -> SomeNode
contextNode identifier context =
  SomeNode (ContextNode (mkNodeId identifier) context)

primitiveNode ::
     RawNodeId
  -> RawNodeId
  -> SContext context
  -> SPrimitive primitive
  -> Interpretation context primitive
  -> SomeNode
primitiveNode identifier owner context primitive interpretation =
  SomeNode
    (PrimitiveNode
       (mkNodeId identifier)
       (mkNodeId owner)
       context
       primitive
       interpretation)

performanceDimensionNode :: RawNodeId -> RawNodeId -> SomeNode
performanceDimensionNode identifier owner =
  SomeNode
    (PerformanceDimensionNode
       (mkNodeId identifier)
       (mkNodeId owner)
       MeasureMeasurementDimension)

anchorNode :: RawNodeId -> SomeNode
anchorNode identifier =
  SomeNode (AnchorNode (mkNodeId identifier) SBusinessCapability)

typedEdge :: RawNodeId -> Relation from to -> RawNodeId -> SomeEdge
typedEdge from relation to =
  SomeEdge (Edge (mkNodeId from) relation (mkNodeId to))

pathId :: Int -> Text.Text -> RawNodeId
pathId ordinal suffix =
  RawNodeId ("path-" <> Text.pack (show ordinal) <> "-" <> suffix)

unreachableId :: Int -> Text.Text -> RawNodeId
unreachableId ordinal suffix =
  RawNodeId ("unreachable-" <> Text.pack (show ordinal) <> "-" <> suffix)

mismatchedId :: Int -> Text.Text -> RawNodeId
mismatchedId ordinal suffix =
  RawNodeId ("mismatched-" <> Text.pack (show ordinal) <> "-" <> suffix)

unconstitutedId :: Int -> Text.Text -> RawNodeId
unconstitutedId ordinal suffix =
  RawNodeId ("unconstituted-" <> Text.pack (show ordinal) <> "-" <> suffix)

liveSituationId :: Int -> RawNodeId
liveSituationId ordinal =
  RawNodeId ("live-situation-" <> Text.pack (show ordinal))

strategySituationId :: Int -> Text.Text -> RawNodeId
strategySituationId ordinal suffix =
  RawNodeId ("strategy-situation-" <> Text.pack (show ordinal) <> "-" <> suffix)

targetMeasureSituationId :: Int -> Text.Text -> RawNodeId
targetMeasureSituationId ordinal suffix =
  RawNodeId
    ("target-measure-situation-" <> Text.pack (show ordinal) <> "-" <> suffix)

needMeasureId :: Int -> Text.Text -> RawNodeId
needMeasureId ordinal suffix =
  RawNodeId ("need-measure-" <> Text.pack (show ordinal) <> "-" <> suffix)

strategyActionFanOutId :: Int -> Text.Text -> RawNodeId
strategyActionFanOutId ordinal suffix =
  RawNodeId
    ("strategy-action-fan-out-" <> Text.pack (show ordinal) <> "-" <> suffix)

needObjectiveFanOutId :: Int -> Text.Text -> RawNodeId
needObjectiveFanOutId ordinal suffix =
  RawNodeId
    ("need-objective-fan-out-" <> Text.pack (show ordinal) <> "-" <> suffix)

anchorRelationFanOutId :: Int -> Text.Text -> RawNodeId
anchorRelationFanOutId ordinal suffix =
  RawNodeId
    ("anchor-relation-fan-out-" <> Text.pack (show ordinal) <> "-" <> suffix)

visionFanOutId :: Int -> Text.Text -> RawNodeId
visionFanOutId ordinal suffix =
  RawNodeId ("vision-fan-out-" <> Text.pack (show ordinal) <> "-" <> suffix)

convergentStrategyKeyResultId :: Int -> RawNodeId
convergentStrategyKeyResultId ordinal =
  RawNodeId ("convergent-strategy-key-result-" <> Text.pack (show ordinal))

convergentInterventionKeyResultId :: Int -> RawNodeId
convergentInterventionKeyResultId ordinal =
  RawNodeId ("convergent-intervention-key-result-" <> Text.pack (show ordinal))

threeWayRejectionId :: Text.Text -> RawNodeId
threeWayRejectionId suffix = RawNodeId ("three-way-rejection-" <> suffix)

needMeasureVisionId, needMeasureInterventionId :: RawNodeId
needMeasureVisionId = RawNodeId "need-measure-vision"

needMeasureInterventionId = RawNodeId "need-measure-intervention"

visionId, strategyId, needId, interventionId, measureId, situationId ::
     RawNodeId
visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

interventionId = RawNodeId "intervention"

measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

visionObjectiveId, strategyDriverId, strategyObjectiveId :: RawNodeId
visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyKeyResultId, strategyActionId :: RawNodeId
strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"
