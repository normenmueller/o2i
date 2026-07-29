{-# LANGUAGE OverloadedStrings #-}

-- | Deliberately naive semantic oracle for complete effect traces.
--
-- This module interprets only validated raw facts and Strategy formulations.
-- It does not import evaluator rules, plans, indexes, or execution modules.
module O2I.Validation.Trace.Eval.Test.Oracle
  ( OracleTrace(..)
  , oracleAddressedNeeds
  , oracleCoveredPairs
  , oracleInterventions
  , oracleTraces
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Semantics.Context (RawStrategyFormulation(..))

-- | Complete constituent identity in the stable public trace field order.
data OracleTrace = OracleTrace
  { oracleTraceVision :: RawNodeId
  , oracleTraceVisionObjective :: RawNodeId
  , oracleTraceStrategy :: RawNodeId
  , oracleTraceStrategyDriver :: RawNodeId
  , oracleTraceStrategyObjective :: RawNodeId
  , oracleTraceStrategyKeyResult :: RawNodeId
  , oracleTraceStrategyAction :: RawNodeId
  , oracleTraceNeed :: RawNodeId
  , oracleTraceNeedDriver :: RawNodeId
  , oracleTraceNeedObjective :: RawNodeId
  , oracleTraceIntervention :: RawNodeId
  , oracleTraceInterventionAction :: RawNodeId
  , oracleTraceInterventionKeyResult :: RawNodeId
  , oracleTraceMeasure :: RawNodeId
  , oracleTraceMeasureDimension :: RawNodeId
  , oracleTraceMeasureKPI :: RawNodeId
  , oracleTraceSituation :: RawNodeId
  , oracleTraceAnchor :: RawNodeId
  , oracleTraceAnchorKind :: SituationAnchor
  } deriving (Eq, Ord, Show)

oracleInterventions :: RawGraph -> [RawNodeId]
oracleInterventions graph =
  Set.toAscList
    (Set.fromList
       [identifier | RawContextNode identifier Intervention <- rawNodes graph])

oracleAddressedNeeds :: RawGraph -> [(RawNodeId, RawNodeId)]
oracleAddressedNeeds graph =
  Set.toAscList
    (Set.fromList
       [ (rawEdgeFrom candidate, rawEdgeTo candidate)
       | candidate <- rawEdges graph
       , rawEdgeRelation candidate == relationNameFor addressesNeed
       ])

-- | Project the exact canonical Intervention-to-Need coverage of traces.
oracleCoveredPairs :: [OracleTrace] -> [(RawNodeId, RawNodeId)]
oracleCoveredPairs traces =
  Set.toAscList
    (Set.fromList
       [ (oracleTraceIntervention trace, oracleTraceNeed trace)
       | trace <- traces
       ])

oracleTraces :: RawGraph -> [RawStrategyFormulation] -> [OracleTrace]
oracleTraces graph formulations =
  Set.toAscList
    (Set.fromList
       [ OracleTrace
         { oracleTraceVision = vision
         , oracleTraceVisionObjective = visionObjective
         , oracleTraceStrategy = strategy
         , oracleTraceStrategyDriver = strategyDriver
         , oracleTraceStrategyObjective = strategyObjective
         , oracleTraceStrategyKeyResult = strategyKeyResult
         , oracleTraceStrategyAction = strategyAction
         , oracleTraceNeed = need
         , oracleTraceNeedDriver = needDriver
         , oracleTraceNeedObjective = needObjective
         , oracleTraceIntervention = intervention
         , oracleTraceInterventionAction = interventionAction
         , oracleTraceInterventionKeyResult = interventionKeyResult
         , oracleTraceMeasure = measure
         , oracleTraceMeasureDimension = measureDimension
         , oracleTraceMeasureKPI = measureKPI
         , oracleTraceSituation = situation
         , oracleTraceAnchor = anchor
         , oracleTraceAnchorKind = anchorKind
         }
       | intervention <- contexts Intervention
       , need <- contexts Need
       , hasRelation intervention addressesNeed need
       , strategy <- contexts Strategy
       , hasRelation strategy qualifiesNeed need
       , hasRelation strategy directsIntervention intervention
       , measure <- contexts Measure
       , hasRelation strategy framesMeasure measure
       , hasRelation intervention setsTargetForMeasure measure
       , situation <- contexts Situation
       , hasRelation measure measuresSituation situation
       , hasRelation intervention changesSituation situation
       , hasRelation situation surfacesNeed need
       , vision <- contexts Vision
       , hasRelation vision orientsStrategy strategy
       , formulation <- formulations
       , rawFormulationStrategy formulation == strategy
       , strategyKeyResult <-
           NonEmpty.toList (rawFormulationKeyResults formulation)
       , strategyAction <- NonEmpty.toList (rawFormulationActions formulation)
       , strategyDriver <- [rawFormulationDiagnosis formulation]
       , strategyObjective <- [rawFormulationIntent formulation]
       , interventionKeyResult <- ownedPrimitives intervention KeyResult
       , hasRelation
           interventionKeyResult
           contributesInterventionKeyResultToStrategyKeyResult
           strategyKeyResult
       , interventionAction <- ownedPrimitives intervention Action
       , hasRelation
           interventionAction
           contributesInterventionActionToKeyResult
           interventionKeyResult
       , hasRelation
           strategyAction
           guidesStrategyActionToInterventionAction
           interventionAction
       , hasRelation
           strategyAction
           contributesStrategyActionToKeyResult
           strategyKeyResult
       , hasRelation
           strategyKeyResult
           substantiatesStrategyKeyResultObjective
           strategyObjective
       , hasRelation
           strategyDriver
           groundsStrategyDriverToObjective
           strategyObjective
       , visionObjective <- ownedPrimitives vision Objective
       , hasRelation
           visionObjective
           orientsVisionObjectiveToStrategyObjective
           strategyObjective
       , needObjective <- ownedPrimitives need Objective
       , hasRelation
           strategyKeyResult
           translatesStrategyKeyResultToNeedObjective
           needObjective
       , needDriver <- ownedPrimitives need Driver
       , hasRelation needDriver groundsNeedDriverToObjective needObjective
       , hasRelation
           interventionKeyResult
           substantiatesInterventionKeyResultNeedObjective
           needObjective
       , measureDimension <- ownedStructuring measure PerformanceDimension
       , hasRelation
           strategyDriver
           indicatesMeasurePerformanceDimension
           measureDimension
       , hasRelation
           strategyKeyResult
           determinesMeasurePerformanceDimension
           measureDimension
       , measureKPI <- ownedPrimitives measure KPI
       , hasRelation
           measureDimension
           (containsPerformanceDimension MeasureMeasurementDimension)
           measureKPI
       , hasRelation interventionKeyResult setsTargetForMeasureKPI measureKPI
       , (anchor, anchorKind) <- anchors
       , hasAnchorRelation measureKPI MeasuresAnchorFamily anchor
       , hasAnchorRelation interventionAction ChangesAnchorFamily anchor
       , hasAnchorRelation anchor AnchorsNeedDriverFamily needDriver
       , hasAnchorRelation situation ConstitutedByAnchorFamily anchor
       ])
  where
    contexts context =
      [ identifier
      | RawContextNode identifier candidate <- rawNodes graph
      , candidate == context
      ]
    ownedPrimitives owner primitive =
      [ identifier
      | RawPrimitiveNode identifier candidateOwner candidate <- rawNodes graph
      , candidateOwner == owner
      , candidate == primitive
      ]
    ownedStructuring owner structuring =
      [ identifier
      | RawStructuringNode identifier candidateOwner candidate <- rawNodes graph
      , candidateOwner == owner
      , candidate == structuring
      ]
    anchors =
      [(identifier, kind) | RawAnchorNode identifier kind <- rawNodes graph]
    hasRelation from relation to =
      RawEdge from (relationNameFor relation) to `elem` rawEdges graph
    hasAnchorRelation from family to =
      RawEdge from (anchorRelationFamilyName family) to `elem` rawEdges graph
