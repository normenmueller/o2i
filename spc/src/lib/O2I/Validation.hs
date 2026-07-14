-- | Curated facade for the staged O2I validation pipeline.
--
-- Validation progresses from structural elaboration through semantic
-- completeness, effect traceability, ex-ante readiness, and ex-post evidence
-- assessment.
module O2I.Validation
  ( Validation(..)
  , Check
  , StructuralError(..)
  , StrategyAnchoring(..)
  , RawStrategyFormulation(..)
  , StrategyFormulation
  , StrategyTextField(..)
  , StrategyPrimitiveRole(..)
  , ModelInvariantError(..)
  , SemanticallyValidModel
  , strategyFormulations
  , strategyFormulationData
  , qualifyingStrategies
  , EffectTrace
  , EffectTraceId
  , TraceableEffectModel
  , TraceabilityError(..)
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , traceStrategy
  , traceStrategyKeyResult
  , traceNeed
  , traceIntervention
  , traceInterventionKeyResult
  , traceKPI
  , traceAnchor
  , Unit(..)
  , Quantity(..)
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , EvidencePlan(..)
  , EvidenceReadyModel
  , evidencePlans
  , readyEffectTraces
  , readyTracesForIntervention
  , FollowUpObservation(..)
  , CriterionResult(..)
  , TargetResult(..)
  , EffectAssessment(..)
  , EvidenceAssessedModel
  , EvidenceReadinessError(..)
  , EvidenceError(..)
  , effectAssessments
  , isEffectiveNeed
  , validateStructure
  , validateModelSemantics
  , validateTraceability
  , validateEvidenceReadinessAt
  , assessEffectEvidence
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Validation (Validation(..))
import O2I.Validation.Evidence
import O2I.Validation.Readiness
import O2I.Validation.Semantics
import O2I.Validation.Structure
import O2I.Validation.Trace

-- | Validation result that accumulates one or more independent errors.
type Check error result = Validation (NonEmpty error) result
