{-# LANGUAGE DataKinds #-}

-- | Relational effect-trace derivation and validation.
--
-- Trace validation derives complete paths only from semantically valid O2I
-- graphs; it does not assess empirical observations.
module O2I.Validation.Trace
  ( EffectTrace
  , EffectTraceId
  , SomeSituationAnchorRef
  , TraceableEffectModel
  , TraceabilityError(..)
  , MacroEvidenceWitness
  , macroEvidenceWitnesses
  , macroEvidenceWitnessesFor
  , witnessPremises
  , validateTraceability
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , effectTraceIdText
  , traceVision
  , traceVisionObjective
  , traceStrategy
  , traceStrategyDriver
  , traceStrategyObjective
  , traceStrategyKeyResult
  , traceStrategyAction
  , traceNeed
  , traceNeedDriver
  , traceNeedObjective
  , traceIntervention
  , traceInterventionAction
  , traceInterventionKeyResult
  , traceMeasure
  , traceMeasurePerformanceDimension
  , traceKPI
  , traceSituation
  , traceSituationAnchor
  , situationAnchorRefId
  , situationAnchorRefKind
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro (MacroClaim)
import O2I.Language.Relation
import O2I.Validation.MacroEvidence
import qualified O2I.Validation.MacroEvidence as Evidence
import O2I.Validation.Semantics
import O2I.Validation.Trace.Eval
import O2I.Validation.Trace.Types

-- | Interpret the canonical macro rule against one completely validated
-- semantic model.
macroEvidenceWitnesses ::
     SemanticallyValidModel -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  Evidence.macroEvidenceWitnessesIn (modelPreparedMacroEvidence semantic)

-- | Select exact witnesses for one registered Context macrorelation claim.
macroEvidenceWitnessesFor ::
     SemanticallyValidModel
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesFor semantic =
  Evidence.macroEvidenceWitnessesForIn (modelPreparedMacroEvidence semantic)

-- | Opaque semantic model with at least one complete effect trace and full
-- trace coverage for every Need addressed by every Intervention.
data TraceableEffectModel = TraceableEffectModel
  { traceableSemanticallyValidModel :: SemanticallyValidModel
  , validatedTraces :: NonEmpty.NonEmpty EffectTrace
  , traceIndex :: Map EffectTraceId EffectTrace
  }

-- | Violations of relational effect traceability.
data TraceabilityError
  = NoIntervention
    -- ^ The model contains no Intervention from which a trace can be derived.
  | InterventionWithoutNeed RawNodeId
    -- ^ An Intervention addresses no Need.
  | MissingMacroEvidence RawNodeId RelationName RawNodeId
    -- ^ A context macrorelation lacks its required primitive evidence.
  | MissingEffectTrace RawNodeId RawNodeId
    -- ^ An Intervention/Need pair has no complete relational effect path.
  deriving (Eq, Show)

-- * Traceability validation interface
-- | Derive complete relational effect traces.
--
-- Complete paths cover every addressed Need, and primitive evidence supports
-- every macrorelation; observations and causal attribution remain outside.
validateTraceability ::
     SemanticallyValidModel
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
-- * Traceability validation implementation
validateTraceability semantic =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty traces of
        Just nonEmptyTraces ->
          Success
            TraceableEffectModel
              { traceableSemanticallyValidModel = semantic
              , validatedTraces = nonEmptyTraces
              , traceIndex = indexedTraces
              }
        Nothing -> Failure (NonEmpty.singleton NoIntervention)
  where
    evidence = modelPreparedMacroEvidence semantic
    evaluated = evaluateEffectTraces evidence
    interventions = traceEvaluationInterventions evaluated
    indexedTraces = traceEvaluationTraceMap evaluated
    traces = traceEvaluationTraces evaluated
    interventionErrors
      | null interventions = [NoIntervention]
      | otherwise = concatMap errorsForIntervention interventions
    errorsForIntervention intervention =
      case traceEvaluationAddressedNeedsFor evaluated intervention of
        [] -> [InterventionWithoutNeed (unNodeId intervention)]
        needs ->
          [ MissingEffectTrace (unNodeId intervention) (unNodeId need)
          | need <- needs
          , not
              (traceEvaluationCovers
                 evaluated
                 AddressedNeed
                   { addressedNeedIntervention = intervention
                   , addressedNeedNeed = need
                   })
          ]
    errors = macroEvidenceErrors evidence ++ interventionErrors

-- | Enumerate all distinct validated effect traces.
effectTraces :: TraceableEffectModel -> NonEmpty.NonEmpty EffectTrace
effectTraces = validatedTraces

-- | Resolve a trace identifier within its validated traceable model.
lookupEffectTrace :: TraceableEffectModel -> EffectTraceId -> Maybe EffectTrace
lookupEffectTrace model identifier = Map.lookup identifier (traceIndex model)

macroEvidenceErrors :: PreparedMacroEvidence -> [TraceabilityError]
macroEvidenceErrors evidence =
  [ MissingMacroEvidence
    (rawEdgeFrom conclusion)
    (rawEdgeRelation conclusion)
    (rawEdgeTo conclusion)
  | (conclusion, claim) <- macroEvidenceClaims evidence
  , not (macroEvidenceExistsIn evidence claim)
  ]
