{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private representation of the Core-owned evidence Assessment contract.
module O2I.Assessment.Internal
  ( AssessmentInputOrdinal(..)
  , ObservationOrdinal(..)
  , ActualInterventionStart(..)
  , Observation(..)
  , AssessmentBundleInput(..)
  , AssessmentInputDefect(..)
  , sortAssessmentInputDefects
  , BoundAssessmentBundleInput(..)
  , AssessmentInputBinding(..)
  , AssessmentSubjectUnavailableReason(..)
  , AssessmentSubject(..)
  , AssessmentSubjectAssessment(..)
  , AssessmentRule(..)
  , assessmentRuleId
  , AssessmentEvidenceKey(..)
  , AssessmentDefect(..)
  , sortAssessmentDefects
  , EffectResult(..)
  , TargetAttainment(..)
  , AssessmentLimitation(..)
  , ObservationAssessment(..)
  , EvidenceAssessedProof(..)
  , AssessmentResult(..)
  , AssessmentWork(..)
  , emptyAssessmentWork
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity (ModelIdentity)
import O2I.Readiness.Internal
  ( BoundReadinessInput
  , CanonicalText
  , DomainValue
  , EvidenceInputDefectKind
  , EvidenceInputDiagnosticSubject
  , EvidenceReadyProof
  , ReadinessDefect
  , ReadinessInput
  , ReadinessSubjectUnavailableReason
  , UtcTimestamp
  )
import O2I.Trace (TraceIdentity)

-- | Stable zero-based ordinal assigned to one assessment bundle source.
newtype AssessmentInputOrdinal =
  AssessmentInputOrdinal Natural
  deriving (Eq, Ord, Show)

-- | Stable zero-based source position of one submitted observation.
newtype ObservationOrdinal =
  ObservationOrdinal Natural
  deriving (Eq, Ord, Show)

-- | The one actual start submitted for the traced Intervention.
data ActualInterventionStart = ActualInterventionStart
  { storedActualIntervention :: !ModelIdentity
  , storedActualStartAt :: !UtcTimestamp
  } deriving (Eq, Show)

-- | One source-ordered follow-up observation.
data Observation = Observation
  { storedObservationOrdinal :: !ObservationOrdinal
  , storedObservationTrace :: !TraceIdentity
  , storedObservedAt :: !UtcTimestamp
  , storedObservationSource :: !CanonicalText
  , storedObservationValue :: !DomainValue
  } deriving (Eq, Show)

-- | Fully decoded explicit Assessment bundle.
data AssessmentBundleInput = AssessmentBundleInput
  { storedAssessmentOrdinal :: !AssessmentInputOrdinal
  , storedAssessmentReadiness :: !ReadinessInput
  , storedAssessedAt :: !UtcTimestamp
  , storedActualStart :: !ActualInterventionStart
  , storedObservations :: ![Observation]
  } deriving (Eq, Show)

-- | One Assessment-owned decoding defect with generic evidence-input detail.
data AssessmentInputDefect = AssessmentInputDefect
  { storedAssessmentInputDefectRule :: !CoreRuleId
  , storedAssessmentInputDefectKind :: !EvidenceInputDefectKind
  , storedAssessmentInputDefectOrdinal :: !AssessmentInputOrdinal
  , storedAssessmentInputDefectPointer :: !Text
  , storedAssessmentInputDefectSubjects :: !(NonEmpty
                                               EvidenceInputDiagnosticSubject)
  } deriving (Eq, Show)

sortAssessmentInputDefects :: [AssessmentInputDefect] -> [AssessmentInputDefect]
sortAssessmentInputDefects =
  sortOn
    (\defect ->
       ( storedAssessmentInputDefectOrdinal defect
       , storedAssessmentInputDefectPointer defect
       , storedAssessmentInputDefectRule defect
       , storedAssessmentInputDefectSubjects defect))

type role BoundAssessmentBundleInput nominal

-- | Bundle whose embedded Readiness subject is bound to one selected View.
data BoundAssessmentBundleInput scope = BoundAssessmentBundleInput
  { storedBoundAssessmentBundle :: !AssessmentBundleInput
  , storedBoundAssessmentReadiness :: !(BoundReadinessInput scope)
  }

type role AssessmentInputBinding nominal

-- | Selected-View binding outcome for the embedded Readiness subject.
data AssessmentInputBinding scope
  = AssessmentInputSubjectUnavailable
      !AssessmentBundleInput
      !(NonEmpty AssessmentInputDefect)
  | AssessmentInputBound !(BoundAssessmentBundleInput scope)

-- | Why Core could not reconstruct a current EvidenceReady proof.
data AssessmentSubjectUnavailableReason
  = AssessmentReadinessSubjectUnavailable !ReadinessSubjectUnavailableReason
  | AssessmentReadinessCriterionNotSatisfied !ReadinessDefect

type role AssessmentSubject nominal

-- | Current reconstructed Ready proof paired with its exact submitted bundle.
data AssessmentSubject scope = AssessmentSubject
  { storedAssessmentReadyProof :: !(EvidenceReadyProof scope)
  , storedAssessmentSubjectBundle :: !(BoundAssessmentBundleInput scope)
  , storedAssessmentTraceSupport :: !Int
  , storedAssessmentReadinessCriteria :: !Int
  }

type role AssessmentSubjectAssessment nominal

-- | Outcome of reconstructing every Assessment prerequisite in Core.
data AssessmentSubjectAssessment scope
  = AssessmentSubjectUnavailable
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty AssessmentSubjectUnavailableReason)
  | AssessmentSubjectAvailable !(AssessmentSubject scope)

-- | Closed Assessment rule inventory.
data AssessmentRule
  = AssessmentActualStartCardinality
  | AssessmentActualStartChronology
  | AssessmentAnchorIdentity
  | AssessmentObservationChronology
  | AssessmentTraceObservationCoverage
  | AssessmentEffectCriterionApply
  | AssessmentObservationIdentity
  | AssessmentObservationUniqueness
  | AssessmentKpiIdentity
  | AssessmentLimitationsRequired
  | AssessmentReadinessReconstructedProof
  | AssessmentSourceNonempty
  | AssessmentTargetCriterionApply
  | AssessmentTraceIdentity
  | AssessmentObservationValueDomain
  deriving (Bounded, Enum, Eq, Ord, Show)

assessmentRuleId :: AssessmentRule -> CoreRuleId
assessmentRuleId ruleValue =
  CoreRuleId
    $ case ruleValue of
        AssessmentActualStartCardinality ->
          "core.assessment.actual-start.cardinality"
        AssessmentActualStartChronology ->
          "core.assessment.actual-start.chronology"
        AssessmentAnchorIdentity -> "core.assessment.anchor.identity"
        AssessmentObservationChronology ->
          "core.assessment.chronology.observation"
        AssessmentTraceObservationCoverage ->
          "core.assessment.coverage.trace-observation"
        AssessmentEffectCriterionApply ->
          "core.assessment.effect-criterion.apply"
        AssessmentObservationIdentity -> "core.assessment.identity.observation"
        AssessmentObservationUniqueness ->
          "core.assessment.identity.observation-uniqueness"
        AssessmentKpiIdentity -> "core.assessment.kpi.identity"
        AssessmentLimitationsRequired -> "core.assessment.limitations.required"
        AssessmentReadinessReconstructedProof ->
          "core.assessment.readiness.reconstructed-proof"
        AssessmentSourceNonempty -> "core.assessment.source.nonempty"
        AssessmentTargetCriterionApply ->
          "core.assessment.target-criterion.apply"
        AssessmentTraceIdentity -> "core.assessment.trace.identity"
        AssessmentObservationValueDomain ->
          "core.assessment.value-domain.observation"

-- | Canonical subject, collection, slot, or observation diagnostic address.
data AssessmentEvidenceKey
  = AssessmentSubjectKey !ModelIdentity !TraceIdentity
  | ActualStartKey !ModelIdentity
  | ObservationSetKey !ModelIdentity !TraceIdentity
  | ObservationKey !TraceIdentity !UtcTimestamp
  deriving (Eq, Ord, Show)

-- | One failed Assessment validity rule at its exact evidence address.
data AssessmentDefect = AssessmentDefect
  { storedAssessmentDefectRule :: !CoreRuleId
  , storedAssessmentDefectKey :: !AssessmentEvidenceKey
  } deriving (Eq, Show)

sortAssessmentDefects :: [AssessmentDefect] -> [AssessmentDefect]
sortAssessmentDefects =
  sortOn
    (\defect ->
       (storedAssessmentDefectRule defect, storedAssessmentDefectKey defect))

-- | Effect evaluation, deliberately independent of target attainment.
data EffectResult
  = EffectSatisfied
  | EffectNotSatisfied
  | EffectNotAssessableZeroBaseline
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Target status in this observation and relative to its ex-ante due time.
data TargetAttainment
  = TargetSatisfiedInObservationByDue
  | TargetSatisfiedInObservationAfterDue
  | TargetNotSatisfiedInObservation
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Required limits of every assessed observation.
data AssessmentLimitation
  = CausalityNotEstablished
  | FirstTargetAttainmentTimeNotEstablished
  deriving (Bounded, Enum, Eq, Ord, Show)

type role ObservationAssessment nominal

-- | One independent observation result retained in source order.
data ObservationAssessment scope
  = InvalidObservation !Observation !(NonEmpty AssessmentDefect)
  | AssessedObservation
      !Observation
      !EffectResult
      !TargetAttainment
      !(NonEmpty AssessmentLimitation)

type role EvidenceAssessedProof nominal

-- | Proof that the bound trace is covered and every submitted item is valid.
data EvidenceAssessedProof scope = EvidenceAssessedProof
  { storedAssessedGraphIdentity :: !ModelIdentity
  , storedAssessedTraceIdentity :: !TraceIdentity
  , storedAssessedObservationCount :: !Natural
  }

type role AssessmentResult nominal

-- | Collection-invalid or completed non-aggregating observation sequence.
data AssessmentResult scope
  = AssessmentInputInvalid
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty AssessmentDefect)
  | AssessmentObservationsCompleted
      !ModelIdentity
      !TraceIdentity
      ![ObservationAssessment scope]
      !(Maybe (EvidenceAssessedProof scope))

-- | Private counters for adversarial Assessment work and retention probes.
data AssessmentWork = AssessmentWork
  { assessmentInputOccurrences :: !Int
  , assessmentTraceSupportOccurrences :: !Int
  , assessmentReadinessCriteriaEvaluated :: !Int
  , assessmentSubmittedObservations :: !Int
  , assessmentAddressedObservationSupport :: !Int
  , assessmentIndexEntries :: !Int
  , assessmentOrderingEntries :: !Int
  , assessmentOrderingKeyScalars :: !Int
  , assessmentTransitions :: !Int
  , assessmentRetainedEntries :: !Int
  } deriving (Eq, Show)

emptyAssessmentWork :: AssessmentWork
emptyAssessmentWork = AssessmentWork 0 0 0 0 0 0 0 0 0 0
