{-# LANGUAGE RoleAnnotations #-}

-- | Public Core evidence Assessment boundary.
--
-- Core reconstructs the embedded Readiness proof in the current selected View,
-- validates collection rules before evaluating any item, and then retains one
-- independent source-ordered invalid or assessed outcome per observation.
module O2I.Assessment
  ( AssessmentInputOrdinal
  , assessmentInputOrdinal
  , assessmentInputOrdinalValue
  , ObservationOrdinal
  , observationOrdinalValue
  , ActualInterventionStart
  , actualInterventionIdentity
  , actualInterventionStartAt
  , Observation
  , observationOrdinal
  , observationTraceIdentity
  , observationObservedAt
  , observationSource
  , observationValue
  , AssessmentBundleInput
  , decodeAssessmentBundleInput
  , assessmentBundleInputOrdinal
  , assessmentReadinessInput
  , assessmentBundleTraceIdentity
  , assessmentAssessedAt
  , assessmentActualStart
  , assessmentObservations
  , AssessmentInputDefect
  , assessmentInputDefectRule
  , assessmentInputDefectKind
  , assessmentInputDefectOrdinal
  , assessmentInputDefectPointer
  , assessmentInputDefectSubjects
  , BoundAssessmentBundleInput
  , AssessmentInputBinding
  , bindAssessmentBundleInput
  , foldAssessmentInputBinding
  , boundAssessmentBundleInput
  , boundAssessmentReadinessInput
  , AssessmentSubjectUnavailableReason
  , foldAssessmentSubjectUnavailableReason
  , AssessmentSubject
  , AssessmentSubjectAssessment
  , prepareAssessmentSubject
  , foldAssessmentSubjectAssessment
  , assessmentSubjectGraphIdentity
  , assessmentSubjectTraceIdentity
  , AssessmentEvidenceKey
  , AssessmentEvidenceKind(..)
  , foldAssessmentEvidenceKey
  , AssessmentDiagnosticEvidence
  , assessmentDiagnosticRule
  , assessmentDiagnosticKey
  , assessmentDiagnosticKind
  , EffectResult
  , EffectResultKind(..)
  , effectResultKind
  , foldEffectResult
  , TargetAttainment
  , TargetAttainmentKind(..)
  , targetAttainmentKind
  , foldTargetAttainment
  , AssessmentLimitationKind(..)
  , foldAssessmentLimitationKind
  , ObservationAssessment
  , foldObservationAssessment
  , EvidenceAssessedProof
  , evidenceAssessedGraphIdentity
  , evidenceAssessedTraceIdentity
  , evidenceAssessedObservationCount
  , AssessmentDisposition(..)
  , AssessmentResult
  , assessEvidence
  , assessmentDisposition
  , assessmentResultGraphIdentity
  , assessmentResultTraceIdentity
  , assessmentCollectionDiagnostics
  , assessmentObservationResults
  , evidenceAssessedProof
  , foldAssessmentResult
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Assessment.Binding (bindAssessmentBundleInputInternal)
import O2I.Assessment.Decode (decodeAssessmentBundleInputInternal)
import O2I.Assessment.Eval (assessEvidenceInternal)
import O2I.Assessment.Internal
  ( ActualInterventionStart
  , AssessmentBundleInput
  , AssessmentEvidenceKey
  , AssessmentInputBinding
  , AssessmentInputDefect
  , AssessmentInputOrdinal
  , AssessmentLimitation
  , AssessmentResult
  , AssessmentSubject
  , AssessmentSubjectAssessment
  , AssessmentSubjectUnavailableReason
  , BoundAssessmentBundleInput
  , EffectResult
  , EvidenceAssessedProof
  , Observation
  , ObservationAssessment
  , ObservationOrdinal
  , TargetAttainment
  )
import qualified O2I.Assessment.Internal as Internal
import O2I.Assessment.Subject (prepareAssessmentSubjectInternal)
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Identity (ModelIdentity)
import O2I.Readiness
  ( BoundReadinessInput
  , CanonicalText
  , DomainValue
  , EvidenceInputDefectKind
  , EvidenceInputDiagnosticSubject
  , ReadinessEvidenceKey
  , ReadinessInput
  , ReadinessSubjectUnavailableReason
  , UtcTimestamp
  , evidencePlanTraceIdentity
  , readinessEvidencePlan
  )
import O2I.Readiness.Internal (ReadinessDefect(..))
import qualified O2I.Readiness.Internal as ReadinessInternal
import O2I.Semantics (SemanticAssessment, SemanticallyValidModel)
import O2I.Structure (WellFormedGraph)
import O2I.Trace (TraceIdentity)

-- | Construct a stable producer-assigned bundle ordinal.
assessmentInputOrdinal :: Natural -> AssessmentInputOrdinal
assessmentInputOrdinal = Internal.AssessmentInputOrdinal

-- | Project the natural-number value of a bundle ordinal.
assessmentInputOrdinalValue :: AssessmentInputOrdinal -> Natural
assessmentInputOrdinalValue (Internal.AssessmentInputOrdinal value) = value

-- | Project the zero-based source position of an observation.
observationOrdinalValue :: ObservationOrdinal -> Natural
observationOrdinalValue (Internal.ObservationOrdinal value) = value

-- | Project the Intervention named by the one submitted actual start.
actualInterventionIdentity :: ActualInterventionStart -> ModelIdentity
actualInterventionIdentity = Internal.storedActualIntervention

-- | Project the exact UTC instant of the actual Intervention start.
actualInterventionStartAt :: ActualInterventionStart -> UtcTimestamp
actualInterventionStartAt = Internal.storedActualStartAt

-- | Project an observation's stable source position.
observationOrdinal :: Observation -> ObservationOrdinal
observationOrdinal = Internal.storedObservationOrdinal

-- | Project the complete Trace identity submitted by an observation.
observationTraceIdentity :: Observation -> TraceIdentity
observationTraceIdentity = Internal.storedObservationTrace

-- | Project the exact UTC instant of an observation.
observationObservedAt :: Observation -> UtcTimestamp
observationObservedAt = Internal.storedObservedAt

-- | Project the canonical evidence source of an observation.
observationSource :: Observation -> CanonicalText
observationSource = Internal.storedObservationSource

-- | Project the observed KPI value in its closed domain family.
observationValue :: Observation -> DomainValue
observationValue = Internal.storedObservationValue

-- | Decode exactly one Assessment bundle or all phase-local input defects.
decodeAssessmentBundleInput ::
     AssessmentInputOrdinal
  -> ByteString
  -> Either (NonEmpty AssessmentInputDefect) AssessmentBundleInput
decodeAssessmentBundleInput = decodeAssessmentBundleInputInternal

-- | Project the producer-assigned bundle occurrence ordinal.
assessmentBundleInputOrdinal :: AssessmentBundleInput -> AssessmentInputOrdinal
assessmentBundleInputOrdinal = Internal.storedAssessmentOrdinal

-- | Project the embedded Readiness input that Core must reconstruct.
assessmentReadinessInput :: AssessmentBundleInput -> ReadinessInput
assessmentReadinessInput = Internal.storedAssessmentReadiness

-- | Project the exact Trace identity carried by the embedded evidence plan.
assessmentBundleTraceIdentity :: AssessmentBundleInput -> TraceIdentity
assessmentBundleTraceIdentity =
  evidencePlanTraceIdentity . readinessEvidencePlan . assessmentReadinessInput

-- | Project the exact UTC instant at which the bundle is assessed.
assessmentAssessedAt :: AssessmentBundleInput -> UtcTimestamp
assessmentAssessedAt = Internal.storedAssessedAt

-- | Project the one submitted actual Intervention start.
assessmentActualStart :: AssessmentBundleInput -> ActualInterventionStart
assessmentActualStart = Internal.storedActualStart

-- | Project submitted observations in unchanged source order.
assessmentObservations :: AssessmentBundleInput -> [Observation]
assessmentObservations = Internal.storedObservations

-- | Project the authoritative evidence-input rule for a decoding defect.
assessmentInputDefectRule :: AssessmentInputDefect -> CoreRuleId
assessmentInputDefectRule = Internal.storedAssessmentInputDefectRule

-- | Classify an Assessment input defect in the shared closed defect family.
assessmentInputDefectKind :: AssessmentInputDefect -> EvidenceInputDefectKind
assessmentInputDefectKind = Internal.storedAssessmentInputDefectKind

-- | Project the bundle occurrence ordinal addressed by an input defect.
assessmentInputDefectOrdinal :: AssessmentInputDefect -> AssessmentInputOrdinal
assessmentInputDefectOrdinal = Internal.storedAssessmentInputDefectOrdinal

-- | Project the RFC 6901 pointer of the defective bundle site.
assessmentInputDefectPointer :: AssessmentInputDefect -> Text
assessmentInputDefectPointer = Internal.storedAssessmentInputDefectPointer

-- | Project the non-empty typed diagnostic subjects of an input defect.
assessmentInputDefectSubjects ::
     AssessmentInputDefect -> NonEmpty EvidenceInputDiagnosticSubject
assessmentInputDefectSubjects = Internal.storedAssessmentInputDefectSubjects

-- | Bind the embedded Readiness identities to one well-formed selected View.
bindAssessmentBundleInput ::
     WellFormedGraph scope
  -> AssessmentBundleInput
  -> AssessmentInputBinding scope
bindAssessmentBundleInput = bindAssessmentBundleInputInternal

-- | Eliminate unavailable and successfully bound bundle outcomes.
foldAssessmentInputBinding ::
     (AssessmentBundleInput -> NonEmpty AssessmentInputDefect -> result)
  -> (BoundAssessmentBundleInput scope -> result)
  -> AssessmentInputBinding scope
  -> result
foldAssessmentInputBinding unavailable bound binding =
  case binding of
    Internal.AssessmentInputSubjectUnavailable input defects ->
      unavailable input defects
    Internal.AssessmentInputBound value -> bound value

-- | Project the decoded bundle retained by a successful binding proof.
boundAssessmentBundleInput ::
     BoundAssessmentBundleInput scope -> AssessmentBundleInput
boundAssessmentBundleInput = Internal.storedBoundAssessmentBundle

-- | Project the embedded Readiness binding for Core reconstruction.
boundAssessmentReadinessInput ::
     BoundAssessmentBundleInput scope -> BoundReadinessInput scope
boundAssessmentReadinessInput = Internal.storedBoundAssessmentReadiness

-- | Eliminate Readiness prerequisite and criterion failure families.
foldAssessmentSubjectUnavailableReason ::
     (ReadinessSubjectUnavailableReason -> result)
  -> (CoreRuleId -> ReadinessEvidenceKey -> result)
  -> AssessmentSubjectUnavailableReason
  -> result
foldAssessmentSubjectUnavailableReason prerequisite criterion reason =
  case reason of
    Internal.AssessmentReadinessSubjectUnavailable unavailable ->
      prerequisite unavailable
    Internal.AssessmentReadinessCriterionNotSatisfied defect ->
      criterion
        (storedReadinessDefectRule defect)
        (storedReadinessDefectKey defect)

-- | Reconstruct the current supplied Trace and EvidenceReady proof in Core.
prepareAssessmentSubject ::
     SemanticallyValidModel scope
  -> SemanticAssessment scope
  -> BoundAssessmentBundleInput scope
  -> AssessmentSubjectAssessment scope
prepareAssessmentSubject = prepareAssessmentSubjectInternal

-- | Eliminate unavailable and available Assessment subject outcomes.
foldAssessmentSubjectAssessment ::
     (ModelIdentity -> TraceIdentity -> NonEmpty
                                          AssessmentSubjectUnavailableReason -> result)
  -> (AssessmentSubject scope -> result)
  -> AssessmentSubjectAssessment scope
  -> result
foldAssessmentSubjectAssessment unavailable available assessment =
  case assessment of
    Internal.AssessmentSubjectUnavailable graph trace reasons ->
      unavailable graph trace reasons
    Internal.AssessmentSubjectAvailable subject -> available subject

-- | Project the current selected-View graph identity of the subject.
assessmentSubjectGraphIdentity :: AssessmentSubject scope -> ModelIdentity
assessmentSubjectGraphIdentity =
  ReadinessInternal.storedReadyGraphIdentity
    . Internal.storedAssessmentReadyProof

-- | Project the exact reconstructed and evidence-ready Trace identity.
assessmentSubjectTraceIdentity :: AssessmentSubject scope -> TraceIdentity
assessmentSubjectTraceIdentity =
  ReadinessInternal.storedReadyTraceIdentity
    . Internal.storedAssessmentReadyProof

-- | Closed classification of an Assessment diagnostic address.
data AssessmentEvidenceKind
  = AssessmentSubjectEvidence
  | ActualStartEvidence
  | ObservationSetEvidence
  | ObservationEvidence
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Eliminate every Assessment evidence-key branch through total handlers.
foldAssessmentEvidenceKey ::
     (ModelIdentity -> TraceIdentity -> result)
  -> (ModelIdentity -> result)
  -> (ModelIdentity -> TraceIdentity -> result)
  -> (TraceIdentity -> UtcTimestamp -> result)
  -> AssessmentEvidenceKey
  -> result
foldAssessmentEvidenceKey subject actual observationSet observation key =
  case key of
    Internal.AssessmentSubjectKey graph trace -> subject graph trace
    Internal.ActualStartKey intervention -> actual intervention
    Internal.ObservationSetKey graph trace -> observationSet graph trace
    Internal.ObservationKey trace observedAt -> observation trace observedAt

-- | Opaque selected-View-scoped evidence for one failed Assessment rule.
newtype AssessmentDiagnosticEvidence scope =
  AssessmentDiagnosticEvidence Internal.AssessmentDefect

type role AssessmentDiagnosticEvidence nominal

-- | Project the authoritative Assessment rule of one diagnostic.
assessmentDiagnosticRule :: AssessmentDiagnosticEvidence scope -> CoreRuleId
assessmentDiagnosticRule (AssessmentDiagnosticEvidence defect) =
  Internal.storedAssessmentDefectRule defect

-- | Project the exact evidence address of one diagnostic.
assessmentDiagnosticKey ::
     AssessmentDiagnosticEvidence scope -> AssessmentEvidenceKey
assessmentDiagnosticKey (AssessmentDiagnosticEvidence defect) =
  Internal.storedAssessmentDefectKey defect

-- | Classify the address family of one Assessment diagnostic.
assessmentDiagnosticKind ::
     AssessmentDiagnosticEvidence scope -> AssessmentEvidenceKind
assessmentDiagnosticKind evidence =
  case assessmentDiagnosticKey evidence of
    Internal.AssessmentSubjectKey {} -> AssessmentSubjectEvidence
    Internal.ActualStartKey {} -> ActualStartEvidence
    Internal.ObservationSetKey {} -> ObservationSetEvidence
    Internal.ObservationKey {} -> ObservationEvidence

-- | Closed classification of an independently evaluated effect result.
data EffectResultKind
  = EffectSatisfiedKind
  | EffectNotSatisfiedKind
  | EffectNotAssessableZeroBaselineKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify an opaque effect result without exposing constructors.
effectResultKind :: EffectResult -> EffectResultKind
effectResultKind result =
  case result of
    Internal.EffectSatisfied -> EffectSatisfiedKind
    Internal.EffectNotSatisfied -> EffectNotSatisfiedKind
    Internal.EffectNotAssessableZeroBaseline ->
      EffectNotAssessableZeroBaselineKind

-- | Eliminate every effect-result branch through total handlers.
foldEffectResult :: result -> result -> result -> EffectResult -> result
foldEffectResult satisfied notSatisfied notAssessable result =
  case result of
    Internal.EffectSatisfied -> satisfied
    Internal.EffectNotSatisfied -> notSatisfied
    Internal.EffectNotAssessableZeroBaseline -> notAssessable

-- | Closed target status for one observation and its ex-ante due time.
data TargetAttainmentKind
  = TargetSatisfiedInObservationByDueKind
  | TargetSatisfiedInObservationAfterDueKind
  | TargetNotSatisfiedInObservationKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify an opaque target-attainment result.
targetAttainmentKind :: TargetAttainment -> TargetAttainmentKind
targetAttainmentKind result =
  case result of
    Internal.TargetSatisfiedInObservationByDue ->
      TargetSatisfiedInObservationByDueKind
    Internal.TargetSatisfiedInObservationAfterDue ->
      TargetSatisfiedInObservationAfterDueKind
    Internal.TargetNotSatisfiedInObservation ->
      TargetNotSatisfiedInObservationKind

-- | Eliminate every target-attainment branch through total handlers.
foldTargetAttainment :: result -> result -> result -> TargetAttainment -> result
foldTargetAttainment byDue afterDue notSatisfied result =
  case result of
    Internal.TargetSatisfiedInObservationByDue -> byDue
    Internal.TargetSatisfiedInObservationAfterDue -> afterDue
    Internal.TargetNotSatisfiedInObservation -> notSatisfied

-- | Closed limits retained for every empirically assessed observation.
data AssessmentLimitationKind
  = CausalityNotEstablishedLimitation
  | FirstTargetAttainmentTimeNotEstablishedLimitation
  deriving (Bounded, Enum, Eq, Ord, Show)

limitationKind :: AssessmentLimitation -> AssessmentLimitationKind
limitationKind limitation =
  case limitation of
    Internal.CausalityNotEstablished -> CausalityNotEstablishedLimitation
    Internal.FirstTargetAttainmentTimeNotEstablished ->
      FirstTargetAttainmentTimeNotEstablishedLimitation

-- | Eliminate every public Assessment limitation through total handlers.
foldAssessmentLimitationKind ::
     result -> result -> AssessmentLimitationKind -> result
foldAssessmentLimitationKind causality firstAttainment limitation =
  case limitation of
    CausalityNotEstablishedLimitation -> causality
    FirstTargetAttainmentTimeNotEstablishedLimitation -> firstAttainment

-- | Eliminate invalid and assessed observation outcomes through total handlers.
foldObservationAssessment ::
     (Observation -> NonEmpty (AssessmentDiagnosticEvidence scope) -> result)
  -> (Observation -> EffectResult -> TargetAttainment -> NonEmpty
                                                           AssessmentLimitationKind -> result)
  -> ObservationAssessment scope
  -> result
foldObservationAssessment invalid assessed result =
  case result of
    Internal.InvalidObservation observation defects ->
      invalid observation (fmap AssessmentDiagnosticEvidence defects)
    Internal.AssessedObservation observation effect target limitations ->
      assessed observation effect target (fmap limitationKind limitations)

-- | Project the selected-View graph certified by an assessed proof.
evidenceAssessedGraphIdentity :: EvidenceAssessedProof scope -> ModelIdentity
evidenceAssessedGraphIdentity = Internal.storedAssessedGraphIdentity

-- | Project the exact covered Trace identity certified by an assessed proof.
evidenceAssessedTraceIdentity :: EvidenceAssessedProof scope -> TraceIdentity
evidenceAssessedTraceIdentity = Internal.storedAssessedTraceIdentity

-- | Project the positive number of valid submitted observations.
evidenceAssessedObservationCount :: EvidenceAssessedProof scope -> Natural
evidenceAssessedObservationCount = Internal.storedAssessedObservationCount

-- | Closed top-level classification without any aggregate evidence score.
data AssessmentDisposition
  = AssessmentInputInvalidDisposition
  | AssessmentObservationsInvalidDisposition
  | AssessmentEvidenceAssessedDisposition
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Validate the collection and independently evaluate every valid item.
assessEvidence :: AssessmentSubject scope -> AssessmentResult scope
assessEvidence = assessEvidenceInternal

-- | Classify collection-invalid, mixed-invalid, and fully assessed results.
assessmentDisposition :: AssessmentResult scope -> AssessmentDisposition
assessmentDisposition result =
  case result of
    Internal.AssessmentInputInvalid {} -> AssessmentInputInvalidDisposition
    Internal.AssessmentObservationsCompleted _ _ _ Nothing ->
      AssessmentObservationsInvalidDisposition
    Internal.AssessmentObservationsCompleted _ _ _ (Just _) ->
      AssessmentEvidenceAssessedDisposition

-- | Project the current selected-View graph identity of a result.
assessmentResultGraphIdentity :: AssessmentResult scope -> ModelIdentity
assessmentResultGraphIdentity result =
  case result of
    Internal.AssessmentInputInvalid graph _ _ -> graph
    Internal.AssessmentObservationsCompleted graph _ _ _ -> graph

-- | Project the exact bound Trace identity of a result.
assessmentResultTraceIdentity :: AssessmentResult scope -> TraceIdentity
assessmentResultTraceIdentity result =
  case result of
    Internal.AssessmentInputInvalid _ trace _ -> trace
    Internal.AssessmentObservationsCompleted _ trace _ _ -> trace

-- | Project collection defects; completed collection validation yields none.
assessmentCollectionDiagnostics ::
     AssessmentResult scope -> [AssessmentDiagnosticEvidence scope]
assessmentCollectionDiagnostics result =
  case result of
    Internal.AssessmentInputInvalid _ _ defects ->
      map AssessmentDiagnosticEvidence (NonEmpty.toList defects)
    Internal.AssessmentObservationsCompleted {} -> []

-- | Project item outcomes in source order; collection failure yields none.
assessmentObservationResults ::
     AssessmentResult scope -> [ObservationAssessment scope]
assessmentObservationResults result =
  case result of
    Internal.AssessmentInputInvalid {} -> []
    Internal.AssessmentObservationsCompleted _ _ observations _ -> observations

-- | Project a proof only when coverage holds and every item is valid.
evidenceAssessedProof ::
     AssessmentResult scope -> Maybe (EvidenceAssessedProof scope)
evidenceAssessedProof result =
  case result of
    Internal.AssessmentInputInvalid {} -> Nothing
    Internal.AssessmentObservationsCompleted _ _ _ proof -> proof

-- | Eliminate collection failure and completed item-sequence results.
foldAssessmentResult ::
     (ModelIdentity -> TraceIdentity -> NonEmpty
                                          (AssessmentDiagnosticEvidence scope) -> result)
  -> ([ObservationAssessment scope] -> Maybe (EvidenceAssessedProof scope) -> result)
  -> AssessmentResult scope
  -> result
foldAssessmentResult invalid completed result =
  case result of
    Internal.AssessmentInputInvalid graph trace defects ->
      invalid graph trace (fmap AssessmentDiagnosticEvidence defects)
    Internal.AssessmentObservationsCompleted _ _ observations proof ->
      completed observations proof
