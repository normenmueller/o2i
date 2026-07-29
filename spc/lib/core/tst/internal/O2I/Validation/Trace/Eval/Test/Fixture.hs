{-# LANGUAGE OverloadedStrings #-}

-- | Semantically valid fixtures for private effect-trace evaluation.
module O2I.Validation.Trace.Eval.Test.Fixture
  ( emptyEvaluation
  , baselineEvaluation
  , extraInterventionEvaluation
  , additionalProcessAnchorEvaluation
  , allAnchorKindsEvaluation
  , processAnchorFanOutEvaluation
  , permutedBaselineEvaluation
  , interventionId
  , needId
  , extraInterventionId
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.MacroEvidence.Test.Fixture
  ( ScenarioShape(Sparse)
  , registryGraph
  , scenarioSemantic
  , validateRegistryGraph
  , validateRegistryScenario
  )
import O2I.Validation.Semantics.Context (ContextSemantics)
import O2I.Validation.Trace.Eval

emptyEvaluation :: Either String TraceEvaluationResult
emptyEvaluation = evaluateSemantic (scenarioSemantic Sparse 0)

baselineEvaluation :: Either String TraceEvaluationResult
baselineEvaluation = evaluateSemantic validateRegistryScenario

extraInterventionEvaluation :: Either String TraceEvaluationResult
extraInterventionEvaluation =
  evaluateGraph
    registryGraph
      { rawNodes =
          rawNodes registryGraph
            ++ [ RawContextNode extraInterventionId Intervention
               , RawPrimitiveNode
                   extraInterventionActionId
                   extraInterventionId
                   Action
               , RawPrimitiveNode
                   extraInterventionKeyResultId
                   extraInterventionId
                   KeyResult
               ]
      , rawEdges =
          rawEdges registryGraph
            ++ [ edge
                   extraInterventionActionId
                   contributesInterventionActionToKeyResult
                   extraInterventionKeyResultId
               ]
      }

additionalProcessAnchorEvaluation :: Either String TraceEvaluationResult
additionalProcessAnchorEvaluation = processAnchorFanOutEvaluation 1

allAnchorKindsEvaluation :: Either String TraceEvaluationResult
allAnchorKindsEvaluation =
  evaluateGraph
    (addAnchors
       [(BusinessProcess, 1), (BusinessObject, 1), (ValueStream, 1)]
       registryGraph)

processAnchorFanOutEvaluation :: Int -> Either String TraceEvaluationResult
processAnchorFanOutEvaluation count =
  evaluateGraph
    (addAnchors
       [(BusinessProcess, ordinal) | ordinal <- [1 .. count]]
       registryGraph)

permutedBaselineEvaluation :: Either String TraceEvaluationResult
permutedBaselineEvaluation =
  evaluateGraph
    registryGraph
      { rawNodes = reverse (rawNodes registryGraph)
      , rawEdges = reverse (rawEdges registryGraph)
      }

evaluateGraph :: RawGraph -> Either String TraceEvaluationResult
evaluateGraph = evaluateSemantic . validateRegistryGraph

evaluateSemantic ::
     Either String ContextSemantics -> Either String TraceEvaluationResult
evaluateSemantic = fmap (evaluateEffectTraces . prepareMacroEvidence)

addAnchors :: [(SituationAnchor, Int)] -> RawGraph -> RawGraph
addAnchors anchors graph =
  graph
    { rawNodes =
        rawNodes graph
          ++ [ RawAnchorNode (anchorId kind ordinal) kind
             | (kind, ordinal) <- anchors
             ]
    , rawEdges = rawEdges graph ++ concatMap anchorEdges anchors
    }

anchorEdges :: (SituationAnchor, Int) -> [RawEdge]
anchorEdges (kind, ordinal) =
  [ anchorEdge situationId ConstitutedByAnchorFamily anchor
  , anchorEdge anchor AnchorsNeedDriverFamily needDriverId
  , anchorEdge interventionActionId ChangesAnchorFamily anchor
  , anchorEdge measureKPIId MeasuresAnchorFamily anchor
  ]
  where
    anchor = anchorId kind ordinal

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge :: RawNodeId -> AnchorRelationFamily -> RawNodeId -> RawEdge
anchorEdge from family to = RawEdge from (anchorRelationFamilyName family) to

anchorId :: SituationAnchor -> Int -> RawNodeId
anchorId kind ordinal =
  RawNodeId ("trace-" <> anchorPrefix kind <> "-" <> Text.pack (show ordinal))

anchorPrefix :: SituationAnchor -> Text
anchorPrefix kind =
  case kind of
    BusinessCapability -> "business-capability"
    BusinessProcess -> "business-process"
    BusinessObject -> "business-object"
    ValueStream -> "value-stream"

interventionId, needId, situationId :: RawNodeId
interventionId = RawNodeId "intervention"

needId = RawNodeId "need"

situationId = RawNodeId "situation"

needDriverId, interventionActionId, measureKPIId :: RawNodeId
needDriverId = RawNodeId "need-driver"

interventionActionId = RawNodeId "intervention-action"

measureKPIId = RawNodeId "measure-kpi-0"

extraInterventionId, extraInterventionActionId, extraInterventionKeyResultId ::
     RawNodeId
extraInterventionId = RawNodeId "trace-extra-intervention"

extraInterventionActionId = RawNodeId "trace-extra-intervention-action"

extraInterventionKeyResultId = RawNodeId "trace-extra-intervention-key-result"
