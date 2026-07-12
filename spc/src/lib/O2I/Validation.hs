-- | Curated facade for the staged O2I validation pipeline.
--
-- Validation progresses from structural elaboration through semantic
-- completeness and effect traceability to empirical evidence assessment.
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
  , EffectTrace
  , EffectTraceId
  , TraceableEffectModel
  , TraceabilityError(..)
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , traceNeed
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
  , EvidenceClaim(..)
  , CriterionResult(..)
  , TargetResult(..)
  , EffectAssessment(..)
  , EvidenceAssessedModel
  , EvidenceError(..)
  , effectAssessments
  , isEffectiveNeed
  , validateStructure
  , validateModelSemantics
  , validateTraceability
  , assessEffectEvidence
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Validation (Validation(..))
import O2I.Validation.Evidence
import O2I.Validation.Semantics
import O2I.Validation.Structure
import O2I.Validation.Trace

-- | Validation result that accumulates one or more independent errors.
type Check error result = Validation (NonEmpty error) result
