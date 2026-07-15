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
  , lookupSemanticContextRef
  , qualifyingStrategies
  , EffectTrace
  , EffectTraceId
  , SomeSituationAnchorRef
  , TraceableEffectModel
  , TraceabilityError(..)
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
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
  , Unit(..)
  , Level(..)
  , Delta(..)
  , ValueDomain(..)
  , RelativeChange(..)
  , RawKPIDefinition(..)
  , KPIDefinition
  , kpiDefinitionKPI
  , kpiDefinitionUnit
  , kpiDefinitionDomain
  , kpiDefinitionMeasurementMethod
  , kpiDefinitionInterpretation
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , PlannedInterventionStart(..)
  , EvidencePlan(..)
  , EvidenceReadyModel
  , kpiDefinitions
  , lookupKPIDefinition
  , evidencePlans
  , readinessCheckedAt
  , plannedInterventionStarts
  , readyEffectTraces
  , readyInterventions
  , readyTracesForIntervention
  , ActualInterventionStart(..)
  , FollowUpObservation(..)
  , CriterionResult(..)
  , TargetResult(..)
  , EffectAssessment(..)
  , EvidenceAssessedModel
  , EvidenceReadinessError(..)
  , EvidenceError(..)
  , evidenceAssessedAt
  , actualInterventionStarts
  , effectAssessments
  , isEffectiveNeed
  , validateStructure
  , validateModelSemantics
  , validateTraceability
  , validateEvidenceReadinessAt
  , assessEffectEvidenceAt
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
