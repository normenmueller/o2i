-- | Independent list-based semantic oracle for the complete macro registry.
module O2I.Validation.MacroEvidence.Test.Oracle
  ( naiveFrameWitnesses
  , naiveMacroWitnesses
  ) where

import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Graph.Macro
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.Semantics.Context

-- | Enumerate exact Frames-Measure evidence without the production evaluator.
naiveFrameWitnesses :: RawGraph -> RawStrategyFormulation -> [[RawEdge]]
naiveFrameWitnesses graph formulation =
  sort
    [ [indication, determination, membership]
    | indication <- matching indicatesMeasurePerformanceDimension
    , rawEdgeFrom indication == rawFormulationDiagnosis formulation
    , determination <- matching determinesMeasurePerformanceDimension
    , rawEdgeFrom determination
        `elem` NonEmpty.toList (rawFormulationKeyResults formulation)
    , rawEdgeTo indication == rawEdgeTo determination
    , membership <-
        matching (containsPerformanceDimension MeasureMeasurementDimension)
    , rawEdgeFrom membership == rawEdgeTo indication
    ]
  where
    matching relation =
      [ candidate
      | candidate <- rawEdges graph
      , rawEdgeRelation candidate == relationNameFor relation
      ]

-- | Enumerate one claim from erased registry premises without the production
-- relational evaluator.
naiveMacroWitnesses ::
     MacroFactIndex RawNodeId RawEdge
  -> [RawStrategyFormulation]
  -> MacroClaim RawNodeId
  -> [[RawEdge]]
naiveMacroWitnesses index formulations claim =
  case lookupMacroEvidenceRule (macroClaimConclusion claim) of
    Nothing -> []
    Just rule' ->
      concatMap
        (sort . enumerateAlternative Map.empty [])
        (NonEmpty.toList (ruleAlternatives rule'))
  where
    enumerateAlternative bindings witnesses alternative =
      enumeratePremises
        bindings
        witnesses
        (NonEmpty.toList (alternativePremises alternative))
    enumeratePremises _ witnesses [] = [reverse witnesses]
    enumeratePremises bindings witnesses (premise:rest) =
      [ result
      | (_, candidate) <-
          macroPremiseEdgesBetween
            index
            (premiseRelation premise)
            (selectorValues bindings (premiseSource premise))
            (selectorValues bindings (premiseTarget premise))
      , Just withSource <-
          [ bindSelector
              (premiseSource premise)
              (rawEdgeFrom candidate)
              bindings
          ]
      , Just withTarget <-
          [ bindSelector
              (premiseTarget premise)
              (rawEdgeTo candidate)
              withSource
          ]
      , result <- enumeratePremises withTarget (candidate : witnesses) rest
      ]
    selectorValues bindings selector =
      case Map.lookup selector bindings of
        Just identifier -> [identifier]
        Nothing -> selectorCandidates selector
    selectorCandidates selector =
      sort
        (nub
           (case selector of
              StrategyRolePrimitive side role -> strategyRoleValues side role
              _ -> macroSelectorCandidates index claim selector))
    strategyRoleValues side role =
      [ roleValue role formulation
      | strategy <- macroSelectorCandidates index claim (ClaimContext side)
      , formulation <- formulations
      , rawFormulationStrategy formulation == strategy
      ]

bindSelector ::
     MacroNodeSelector
  -> RawNodeId
  -> Map MacroNodeSelector RawNodeId
  -> Maybe (Map MacroNodeSelector RawNodeId)
bindSelector selector identifier bindings =
  case Map.lookup selector bindings of
    Nothing -> Just (Map.insert selector identifier bindings)
    Just existing
      | existing == identifier -> Just bindings
      | otherwise -> Nothing

roleValue :: StrategyPrimitiveRole -> RawStrategyFormulation -> RawNodeId
roleValue role formulation =
  case role of
    DiagnosisRole -> rawFormulationDiagnosis formulation
    IntentRole -> rawFormulationIntent formulation
    GuidingPolicyRole -> rawFormulationGuidingPolicy formulation
    CoherentActionRole -> NonEmpty.head (rawFormulationActions formulation)
    StrategicKeyResultRole ->
      NonEmpty.head (rawFormulationKeyResults formulation)
