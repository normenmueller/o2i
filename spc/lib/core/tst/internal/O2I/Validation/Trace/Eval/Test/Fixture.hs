{-# LANGUAGE OverloadedStrings #-}

-- | Semantically valid fixtures for private effect-trace evaluation.
module O2I.Validation.Trace.Eval.Test.Fixture
  ( TraceScenario(..)
  , validateTraceScenario
  , evaluateTraceScenario
  , baselineScenario
  , emptyEvaluation
  , baselineEvaluation
  , extraInterventionEvaluation
  , additionalProcessAnchorEvaluation
  , allAnchorKindsEvaluation
  , processAnchorFanOutEvaluation
  , interventionId
  , needId
  , extraInterventionId
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.MacroEvidence.Test.Fixture
  ( ScenarioShape(Sparse)
  , registryFormulations
  , registryGraph
  , scenarioSemantic
  )
import O2I.Validation.Semantics.Context
  ( ContextSemantics
  , RawStrategyFormulation
  , validateContextSemantics
  )
import O2I.Validation.Structure
  ( StructureResult(..)
  , structuralGraph
  , validateStructure
  )
import O2I.Validation.Trace.Eval

-- | Raw graph and formulations admitted together at the semantic boundary.
data TraceScenario = TraceScenario
  { traceScenarioGraph :: RawGraph
  , traceScenarioFormulations :: [RawStrategyFormulation]
  }

-- | Validate one test scenario through the production semantic boundary.
validateTraceScenario :: TraceScenario -> Either String ContextSemantics
validateTraceScenario scenario =
  case validateStructure (traceScenarioGraph scenario) of
    StructureModelRejected errors -> Left ("structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      Left ("internal structural failure: " ++ show internal)
    StructureAccepted assessment ->
      case validateContextSemantics
             (structuralGraph assessment)
             (traceScenarioFormulations scenario) of
        Failure errors -> Left ("semantic errors: " ++ show errors)
        Success semantics -> Right semantics

-- | Prepare shared evidence once and evaluate one validated scenario.
evaluateTraceScenario :: TraceScenario -> Either String TraceEvaluationResult
evaluateTraceScenario =
  fmap (evaluateEffectTraces . prepareMacroEvidence) . validateTraceScenario

baselineScenario :: TraceScenario
baselineScenario = TraceScenario registryGraph registryFormulations

emptyEvaluation :: Either String TraceEvaluationResult
emptyEvaluation = evaluateSemantic (scenarioSemantic Sparse 0)

baselineEvaluation :: Either String TraceEvaluationResult
baselineEvaluation = evaluateTraceScenario baselineScenario

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

evaluateGraph :: RawGraph -> Either String TraceEvaluationResult
evaluateGraph graph =
  evaluateTraceScenario (TraceScenario graph registryFormulations)

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
