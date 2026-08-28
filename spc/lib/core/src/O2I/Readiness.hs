{-# LANGUAGE RoleAnnotations #-}

-- | Public Core Readiness boundary.
--
-- Exact bytes are decoded and bound before subject reconstruction. Only a
-- directly validated supplied Trace with a Core-reconstructed Strategy proof
-- can reach the 17 closed Readiness criteria. Results and proofs are opaque
-- and nominal in their selected-View scope.
module O2I.Readiness
  ( ReadinessInputOrdinal
  , readinessInputOrdinal
  , readinessInputOrdinalValue
  , CanonicalText
  , canonicalTextValue
  , Unit
  , unitText
  , CanonicalDecimal
  , canonicalDecimalText
  , PositiveDecimal
  , positiveDecimalText
  , UtcTimestamp
  , utcTimestampText
  , EffectDirection(..)
  , QuantitativeComparison(..)
  , OrdinalComparison(..)
  , ValueDomain
  , ValueDomainKind(..)
  , valueDomainKind
  , foldValueDomain
  , DomainValue
  , DomainValueKind(..)
  , domainValueKind
  , foldDomainValue
  , KPIDefinition
  , kpiDefinitionIdentity
  , kpiDefinitionDomain
  , kpiDefinitionMeasurementMethod
  , kpiDefinitionInterpretation
  , PlannedInterventionStart
  , plannedInterventionIdentity
  , plannedInterventionStartAt
  , BaselineObservation
  , baselineObservedAt
  , baselineSource
  , baselineValue
  , EffectCriterion
  , EffectCriterionKind(..)
  , effectCriterionKind
  , foldEffectCriterion
  , TargetCriterion
  , TargetCriterionKind(..)
  , targetCriterionKind
  , foldTargetCriterion
  , EvidencePlan
  , evidencePlanTraceIdentity
  , evidencePlanBaseline
  , evidencePlanEffectCriterion
  , evidencePlanTargetCriterion
  , evidencePlanTargetDueAt
  , evidencePlanSource
  , evidencePlanEstablishedAt
  , ReadinessInput
  , decodeReadinessInput
  , readinessInputOrdinalOf
  , readinessCheckedAt
  , readinessKpiDefinition
  , readinessPlannedStart
  , readinessEvidencePlan
  , EvidenceInputDefectKind(..)
  , EvidenceInputDefect
  , evidenceInputDefectRule
  , evidenceInputDefectKind
  , evidenceInputDefectOrdinal
  , evidenceInputDefectPointer
  , EvidenceInputDiagnosticSubject
  , evidenceInputDefectSubjects
  , foldEvidenceInputDiagnosticSubject
  , ReadinessInputBinding
  , BoundReadinessInput
  , bindReadinessInput
  , foldReadinessInputBinding
  , boundReadinessInput
  , boundReadinessTraceIdentity
  , ReadinessSubjectUnavailableReason
  , foldReadinessSubjectUnavailableReason
  , ReadinessSubject
  , ReadinessSubjectAssessment
  , prepareReadinessSubject
  , foldReadinessSubjectAssessment
  , readinessSubjectGraphIdentity
  , readinessSubjectTraceIdentity
  , ReadinessDisposition(..)
  , ReadinessAssessment
  , assessReadiness
  , readinessDisposition
  , readinessAssessmentGraphIdentity
  , readinessAssessmentTraceIdentity
  , ReadinessDiagnosticEvidence
  , readinessDiagnostics
  , readinessDiagnosticRule
  , ReadinessEvidenceKind(..)
  , readinessDiagnosticKind
  , ReadinessEvidenceKey
  , readinessDiagnosticKey
  , foldReadinessEvidenceKey
  , EvidenceReadyProof
  , evidenceReadyProof
  , evidenceReadyGraphIdentity
  , evidenceReadyTraceIdentity
  , evidenceReadyInput
  , foldReadinessAssessment
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRuleId)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Readiness.Binding (bindReadinessInputInternal)
import O2I.Readiness.Decode (decodeReadinessInputInternal)
import O2I.Readiness.Eval
  ( assessReadinessInternal
  , prepareReadinessSubjectInternal
  )
import O2I.Readiness.Internal
  ( BaselineObservation
  , BoundReadinessInput
  , CanonicalDecimal
  , CanonicalText
  , DomainValue
  , EffectCriterion
  , EffectDirection(..)
  , EvidenceInputDefect
  , EvidenceInputDefectKind(..)
  , EvidenceInputDiagnosticSubject
  , EvidencePlan
  , EvidenceReadyProof
  , KPIDefinition
  , OrdinalComparison(..)
  , PlannedInterventionStart
  , PositiveDecimal
  , QuantitativeComparison(..)
  , ReadinessAssessment
  , ReadinessEvidenceKey
  , ReadinessInput
  , ReadinessInputBinding
  , ReadinessInputOrdinal
  , ReadinessSubject
  , ReadinessSubjectAssessment
  , ReadinessSubjectUnavailableReason
  , TargetCriterion
  , Unit
  , UtcTimestamp
  , ValueDomain
  )
import qualified O2I.Readiness.Internal as Internal
import O2I.Semantics (SemanticAssessment, SemanticallyValidModel)
import O2I.Structure (WellFormedGraph)
import O2I.Trace
  ( BoundTraceIdentity
  , SuppliedTraceUnavailableReason
  , TraceIdentity
  , TracePromotionUnavailableReason
  , promotedTraceGraphIdentity
  , promotedTraceIdentity
  )

-- | Construct an input occurrence ordinal from its natural-number value.
readinessInputOrdinal :: Natural -> ReadinessInputOrdinal
readinessInputOrdinal = Internal.ReadinessInputOrdinal

-- | Project the natural-number value of an input occurrence ordinal.
readinessInputOrdinalValue :: ReadinessInputOrdinal -> Natural
readinessInputOrdinalValue (Internal.ReadinessInputOrdinal value) = value

-- | Project the normalized text carried by canonical fachliche text.
canonicalTextValue :: CanonicalText -> Text
canonicalTextValue (Internal.CanonicalText value) = value

-- | Project the canonical text of a measurement unit.
unitText :: Unit -> Text
unitText (Internal.Unit value) = value

-- | Project a canonical decimal without changing its exact lexeme.
canonicalDecimalText :: CanonicalDecimal -> Text
canonicalDecimalText = Internal.storedDecimalText

-- | Project the exact canonical lexeme of a positive decimal.
positiveDecimalText :: PositiveDecimal -> Text
positiveDecimalText (Internal.PositiveDecimal value) =
  canonicalDecimalText value

-- | Project the exact canonical UTC timestamp text.
utcTimestampText :: UtcTimestamp -> Text
utcTimestampText = Internal.storedTimestampText

-- | Observable branch of an opaque KPI value domain.
data ValueDomainKind
  = QuantitativeDomainKind
  | OrdinalDomainKind
  | CategoricalDomainKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify a value domain without exposing its constructor.
valueDomainKind :: ValueDomain -> ValueDomainKind
valueDomainKind domain =
  case domain of
    Internal.QuantitativeDomain {} -> QuantitativeDomainKind
    Internal.OrdinalDomain {} -> OrdinalDomainKind
    Internal.CategoricalDomain {} -> CategoricalDomainKind

-- | Eliminate every value-domain branch through total handlers.
foldValueDomain ::
     (Unit -> EffectDirection -> result)
  -> (CanonicalText -> NonEmpty CanonicalText -> EffectDirection -> result)
  -> (NonEmpty CanonicalText -> result)
  -> ValueDomain
  -> result
foldValueDomain quantitative ordinal categorical domain =
  case domain of
    Internal.QuantitativeDomain unit direction -> quantitative unit direction
    Internal.OrdinalDomain scale levels direction ->
      ordinal scale levels direction
    Internal.CategoricalDomain values -> categorical values

-- | Observable branch of an opaque observed domain value.
data DomainValueKind
  = QuantitativeValueKind
  | OrdinalValueKind
  | CategoricalValueKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify an observed value without exposing its constructor.
domainValueKind :: DomainValue -> DomainValueKind
domainValueKind value =
  case value of
    Internal.QuantitativeValue {} -> QuantitativeValueKind
    Internal.OrdinalValue {} -> OrdinalValueKind
    Internal.CategoricalValue {} -> CategoricalValueKind

-- | Eliminate every observed-value branch through total handlers.
foldDomainValue ::
     (CanonicalDecimal -> Unit -> result)
  -> (CanonicalText -> CanonicalText -> result)
  -> (CanonicalText -> result)
  -> DomainValue
  -> result
foldDomainValue quantitative ordinal categorical value =
  case value of
    Internal.QuantitativeValue decimal unit -> quantitative decimal unit
    Internal.OrdinalValue scale level -> ordinal scale level
    Internal.CategoricalValue category -> categorical category

-- | Project the selected-View identity of the defined KPI.
kpiDefinitionIdentity :: KPIDefinition -> ModelIdentity
kpiDefinitionIdentity = Internal.storedKpiIdentity

-- | Project the KPI value domain.
kpiDefinitionDomain :: KPIDefinition -> ValueDomain
kpiDefinitionDomain = Internal.storedKpiDomain

-- | Project the canonical measurement method.
kpiDefinitionMeasurementMethod :: KPIDefinition -> CanonicalText
kpiDefinitionMeasurementMethod = Internal.storedMeasurementMethod

-- | Project the canonical interpretation guidance.
kpiDefinitionInterpretation :: KPIDefinition -> CanonicalText
kpiDefinitionInterpretation = Internal.storedInterpretation

-- | Project the selected-View identity of the planned intervention.
plannedInterventionIdentity :: PlannedInterventionStart -> ModelIdentity
plannedInterventionIdentity = Internal.storedPlannedIntervention

-- | Project the intervention's planned UTC start.
plannedInterventionStartAt :: PlannedInterventionStart -> UtcTimestamp
plannedInterventionStartAt = Internal.storedPlannedStartAt

-- | Project the UTC timestamp of the baseline observation.
baselineObservedAt :: BaselineObservation -> UtcTimestamp
baselineObservedAt = Internal.storedBaselineObservedAt

-- | Project the canonical source of the baseline observation.
baselineSource :: BaselineObservation -> CanonicalText
baselineSource = Internal.storedBaselineSource

-- | Project the baseline value in its declared domain family.
baselineValue :: BaselineObservation -> DomainValue
baselineValue = Internal.storedBaselineValue

-- | Observable branch of an opaque minimum-effect criterion.
data EffectCriterionKind
  = QuantitativeAbsoluteEffectKind
  | QuantitativeRelativeEffectKind
  | OrdinalStepsEffectKind
  | CategoricalTransitionEffectKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify an effect criterion without exposing its constructor.
effectCriterionKind :: EffectCriterion -> EffectCriterionKind
effectCriterionKind criterion =
  case criterion of
    Internal.QuantitativeAbsoluteEffect {} -> QuantitativeAbsoluteEffectKind
    Internal.QuantitativeRelativeEffect {} -> QuantitativeRelativeEffectKind
    Internal.OrdinalStepsEffect {} -> OrdinalStepsEffectKind
    Internal.CategoricalTransitionEffect {} -> CategoricalTransitionEffectKind

-- | Eliminate every effect-criterion branch through total handlers.
foldEffectCriterion ::
     (PositiveDecimal -> result)
  -> (PositiveDecimal -> result)
  -> (Natural -> result)
  -> (NonEmpty CanonicalText -> result)
  -> EffectCriterion
  -> result
foldEffectCriterion absolute relative ordinal categorical criterion =
  case criterion of
    Internal.QuantitativeAbsoluteEffect value -> absolute value
    Internal.QuantitativeRelativeEffect value -> relative value
    Internal.OrdinalStepsEffect value -> ordinal value
    Internal.CategoricalTransitionEffect values -> categorical values

-- | Observable branch of an opaque target criterion.
data TargetCriterionKind
  = QuantitativeThresholdKind
  | OrdinalThresholdKind
  | CategoricalMembershipKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify a target criterion without exposing its constructor.
targetCriterionKind :: TargetCriterion -> TargetCriterionKind
targetCriterionKind criterion =
  case criterion of
    Internal.QuantitativeThreshold {} -> QuantitativeThresholdKind
    Internal.OrdinalThreshold {} -> OrdinalThresholdKind
    Internal.CategoricalMembership {} -> CategoricalMembershipKind

-- | Eliminate every target-criterion branch through total handlers.
foldTargetCriterion ::
     (QuantitativeComparison -> CanonicalDecimal -> Unit -> result)
  -> (OrdinalComparison -> CanonicalText -> CanonicalText -> result)
  -> (NonEmpty CanonicalText -> result)
  -> TargetCriterion
  -> result
foldTargetCriterion quantitative ordinal categorical criterion =
  case criterion of
    Internal.QuantitativeThreshold comparison target unit ->
      quantitative comparison target unit
    Internal.OrdinalThreshold comparison scale level ->
      ordinal comparison scale level
    Internal.CategoricalMembership values -> categorical values

-- | Project the exact supplied Trace identity.
evidencePlanTraceIdentity :: EvidencePlan -> TraceIdentity
evidencePlanTraceIdentity = Internal.storedEvidenceTrace

-- | Project the baseline observation.
evidencePlanBaseline :: EvidencePlan -> BaselineObservation
evidencePlanBaseline = Internal.storedBaseline

-- | Project the minimum-effect criterion.
evidencePlanEffectCriterion :: EvidencePlan -> EffectCriterion
evidencePlanEffectCriterion = Internal.storedEffectCriterion

-- | Project the target criterion.
evidencePlanTargetCriterion :: EvidencePlan -> TargetCriterion
evidencePlanTargetCriterion = Internal.storedTargetCriterion

-- | Project the UTC due date for evaluating the target.
evidencePlanTargetDueAt :: EvidencePlan -> UtcTimestamp
evidencePlanTargetDueAt = Internal.storedTargetDueAt

-- | Project the canonical evidence-plan source.
evidencePlanSource :: EvidencePlan -> CanonicalText
evidencePlanSource = Internal.storedEvidencePlanSource

-- | Project the UTC timestamp at which the evidence plan was established.
evidencePlanEstablishedAt :: EvidencePlan -> UtcTimestamp
evidencePlanEstablishedAt = Internal.storedPlanEstablishedAt

-- | Decode exactly one ReadinessInput document or return all phase-local defects.
decodeReadinessInput ::
     ReadinessInputOrdinal
  -> ByteString
  -> Either (NonEmpty EvidenceInputDefect) ReadinessInput
decodeReadinessInput = decodeReadinessInputInternal

-- | Project the producer-assigned occurrence ordinal.
readinessInputOrdinalOf :: ReadinessInput -> ReadinessInputOrdinal
readinessInputOrdinalOf = Internal.storedReadinessOrdinal

-- | Project the UTC instant at which readiness was checked.
readinessCheckedAt :: ReadinessInput -> UtcTimestamp
readinessCheckedAt = Internal.storedReadinessCheckedAt

-- | Project the supplied KPI definition.
readinessKpiDefinition :: ReadinessInput -> KPIDefinition
readinessKpiDefinition = Internal.storedKpiDefinition

-- | Project the supplied planned intervention start.
readinessPlannedStart :: ReadinessInput -> PlannedInterventionStart
readinessPlannedStart = Internal.storedPlannedStart

-- | Project the supplied evidence plan.
readinessEvidencePlan :: ReadinessInput -> EvidencePlan
readinessEvidencePlan = Internal.storedEvidencePlan

-- | Project the authoritative Core rule that identified an input defect.
evidenceInputDefectRule :: EvidenceInputDefect -> CoreRuleId
evidenceInputDefectRule = Internal.storedEvidenceInputDefectRule

-- | Project the closed defect classification.
evidenceInputDefectKind :: EvidenceInputDefect -> EvidenceInputDefectKind
evidenceInputDefectKind = Internal.storedEvidenceInputDefectKind

-- | Project the ordinal of the defective input occurrence.
evidenceInputDefectOrdinal :: EvidenceInputDefect -> ReadinessInputOrdinal
evidenceInputDefectOrdinal = Internal.storedEvidenceInputDefectOrdinal

-- | Project the RFC 6901 pointer of the defective input site.
evidenceInputDefectPointer :: EvidenceInputDefect -> Text
evidenceInputDefectPointer = Internal.storedEvidenceInputDefectPointer

-- | Project the non-empty ordered diagnostic subjects of an input defect.
evidenceInputDefectSubjects ::
     EvidenceInputDefect -> NonEmpty EvidenceInputDiagnosticSubject
evidenceInputDefectSubjects = Internal.storedEvidenceInputDefectSubjects

-- | Eliminate every typed input-diagnostic subject through total handlers.
foldEvidenceInputDiagnosticSubject ::
     (Text -> Text -> result)
  -> (Text -> Natural -> result)
  -> (Text -> ModelIdentity -> result)
  -> (Text -> OccurrenceIdentity -> result)
  -> (Text -> CoreQualifiedEndpointId -> result)
  -> EvidenceInputDiagnosticSubject
  -> result
foldEvidenceInputDiagnosticSubject text natural model occurrence endpoint subject =
  case subject of
    Internal.EvidenceInputTextSubject label value -> text label value
    Internal.EvidenceInputNaturalSubject label value -> natural label value
    Internal.EvidenceInputModelSubject label value -> model label value
    Internal.EvidenceInputOccurrenceSubject label value ->
      occurrence label value
    Internal.EvidenceInputQualifiedTypeSubject label value ->
      endpoint label value

-- | Bind every decoded identity site against one well-formed selected View.
bindReadinessInput ::
     WellFormedGraph scope -> ReadinessInput -> ReadinessInputBinding scope
bindReadinessInput = bindReadinessInputInternal

-- | Eliminate unavailable and successfully bound input outcomes.
foldReadinessInputBinding ::
     (ReadinessInput -> NonEmpty EvidenceInputDefect -> result)
  -> (BoundReadinessInput scope -> result)
  -> ReadinessInputBinding scope
  -> result
foldReadinessInputBinding unavailable bound binding =
  case binding of
    Internal.ReadinessInputSubjectUnavailable input defects ->
      unavailable input defects
    Internal.ReadinessInputBound value -> bound value

-- | Project the decoded input carried by a successful binding proof.
boundReadinessInput :: BoundReadinessInput scope -> ReadinessInput
boundReadinessInput = Internal.storedBoundReadinessInput

-- | Project the selected-View-bound supplied Trace identity.
boundReadinessTraceIdentity ::
     BoundReadinessInput scope -> BoundTraceIdentity scope
boundReadinessTraceIdentity = Internal.storedBoundReadinessTrace

-- | Eliminate both prerequisite-unavailability families through total handlers.
foldReadinessSubjectUnavailableReason ::
     (SuppliedTraceUnavailableReason -> result)
  -> (TracePromotionUnavailableReason -> result)
  -> ReadinessSubjectUnavailableReason
  -> result
foldReadinessSubjectUnavailableReason supplied promotion reason =
  case reason of
    Internal.ReadinessSuppliedTraceUnavailable value -> supplied value
    Internal.ReadinessPromotionUnavailable value -> promotion value

-- | Validate the supplied Trace and reconstruct its proof from the producing semantics.
prepareReadinessSubject ::
     SemanticallyValidModel scope
  -> SemanticAssessment scope
  -> BoundReadinessInput scope
  -> ReadinessSubjectAssessment scope
prepareReadinessSubject = prepareReadinessSubjectInternal

-- | Eliminate unavailable and available subject-reconstruction outcomes.
foldReadinessSubjectAssessment ::
     (ModelIdentity -> TraceIdentity -> NonEmpty
                                          ReadinessSubjectUnavailableReason -> result)
  -> (ReadinessSubject scope -> result)
  -> ReadinessSubjectAssessment scope
  -> result
foldReadinessSubjectAssessment unavailable available assessment =
  case assessment of
    Internal.ReadinessSubjectUnavailable graph trace reasons ->
      unavailable graph trace reasons
    Internal.ReadinessSubjectAvailable subject -> available subject

-- | Project the actual graph identity of an available readiness subject.
readinessSubjectGraphIdentity :: ReadinessSubject scope -> ModelIdentity
readinessSubjectGraphIdentity =
  promotedTraceGraphIdentity . Internal.storedReadinessPromotedTrace

-- | Project the exact validated and promoted Trace identity.
readinessSubjectTraceIdentity :: ReadinessSubject scope -> TraceIdentity
readinessSubjectTraceIdentity =
  promotedTraceIdentity . Internal.storedReadinessPromotedTrace

-- | Closed top-level readiness result classification.
data ReadinessDisposition
  = ReadinessNotReadyDisposition
  | ReadinessReadyDisposition
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Evaluate the closed seventeen-rule readiness inventory.
assessReadiness :: ReadinessSubject scope -> ReadinessAssessment scope
assessReadiness = assessReadinessInternal

-- | Classify an assessment without exposing its result constructor.
readinessDisposition :: ReadinessAssessment scope -> ReadinessDisposition
readinessDisposition assessment =
  case assessment of
    Internal.ReadinessNotReady {} -> ReadinessNotReadyDisposition
    Internal.ReadinessReady {} -> ReadinessReadyDisposition

-- | Project the actual selected-View graph identity of an assessment.
readinessAssessmentGraphIdentity :: ReadinessAssessment scope -> ModelIdentity
readinessAssessmentGraphIdentity assessment =
  case assessment of
    Internal.ReadinessNotReady graph _ _ -> graph
    Internal.ReadinessReady proof -> Internal.storedReadyGraphIdentity proof

-- | Project the exact Trace identity of an assessment.
readinessAssessmentTraceIdentity :: ReadinessAssessment scope -> TraceIdentity
readinessAssessmentTraceIdentity assessment =
  case assessment of
    Internal.ReadinessNotReady _ trace _ -> trace
    Internal.ReadinessReady proof -> Internal.storedReadyTraceIdentity proof

-- | Opaque ordered evidence for one failed readiness criterion.
newtype ReadinessDiagnosticEvidence scope =
  ReadinessDiagnosticEvidence Internal.ReadinessDefect

type role ReadinessDiagnosticEvidence nominal

-- | Project ordered NotReady diagnostics; Ready yields the empty list.
readinessDiagnostics ::
     ReadinessAssessment scope -> [ReadinessDiagnosticEvidence scope]
readinessDiagnostics assessment =
  case assessment of
    Internal.ReadinessNotReady _ _ defects ->
      map ReadinessDiagnosticEvidence (NonEmpty.toList defects)
    Internal.ReadinessReady {} -> []

-- | Project the authoritative readiness rule of one diagnostic.
readinessDiagnosticRule :: ReadinessDiagnosticEvidence scope -> CoreRuleId
readinessDiagnosticRule (ReadinessDiagnosticEvidence defect) =
  Internal.storedReadinessDefectRule defect

-- | Closed classification of the subject or slot addressed by a diagnostic.
data ReadinessEvidenceKind
  = ReadinessSubjectEvidence
  | KPIDefinitionSlotEvidence
  | PlannedStartSlotEvidence
  | EvidencePlanSlotEvidence
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify the evidence key addressed by one diagnostic.
readinessDiagnosticKind ::
     ReadinessDiagnosticEvidence scope -> ReadinessEvidenceKind
readinessDiagnosticKind = readinessEvidenceKind . readinessDiagnosticKey

readinessEvidenceKind :: ReadinessEvidenceKey -> ReadinessEvidenceKind
readinessEvidenceKind key =
  case key of
    Internal.ReadinessSubjectKey {} -> ReadinessSubjectEvidence
    Internal.KPIDefinitionSlotKey {} -> KPIDefinitionSlotEvidence
    Internal.PlannedStartSlotKey {} -> PlannedStartSlotEvidence
    Internal.EvidencePlanSlotKey {} -> EvidencePlanSlotEvidence

-- | Project the canonical evidence key of one diagnostic.
readinessDiagnosticKey ::
     ReadinessDiagnosticEvidence scope -> ReadinessEvidenceKey
readinessDiagnosticKey (ReadinessDiagnosticEvidence defect) =
  Internal.storedReadinessDefectKey defect

-- | Eliminate every readiness evidence-key branch through total handlers.
foldReadinessEvidenceKey ::
     (ModelIdentity -> TraceIdentity -> result)
  -> (ModelIdentity -> result)
  -> (ModelIdentity -> result)
  -> (TraceIdentity -> result)
  -> ReadinessEvidenceKey
  -> result
foldReadinessEvidenceKey subject kpi planned plan key =
  case key of
    Internal.ReadinessSubjectKey graph trace -> subject graph trace
    Internal.KPIDefinitionSlotKey identity -> kpi identity
    Internal.PlannedStartSlotKey identity -> planned identity
    Internal.EvidencePlanSlotKey trace -> plan trace

-- | Project a Ready proof when and only when the assessment is Ready.
evidenceReadyProof ::
     ReadinessAssessment scope -> Maybe (EvidenceReadyProof scope)
evidenceReadyProof assessment =
  case assessment of
    Internal.ReadinessNotReady {} -> Nothing
    Internal.ReadinessReady proof -> Just proof

-- | Project the actual graph identity certified by a Ready proof.
evidenceReadyGraphIdentity :: EvidenceReadyProof scope -> ModelIdentity
evidenceReadyGraphIdentity = Internal.storedReadyGraphIdentity

-- | Project the exact Trace identity certified by a Ready proof.
evidenceReadyTraceIdentity :: EvidenceReadyProof scope -> TraceIdentity
evidenceReadyTraceIdentity = Internal.storedReadyTraceIdentity

-- | Project the explicit canonical input certified by a Ready proof.
evidenceReadyInput :: EvidenceReadyProof scope -> ReadinessInput
evidenceReadyInput = Internal.storedReadyInput

-- | Eliminate NotReady diagnostics or the Ready proof through total handlers.
foldReadinessAssessment ::
     (ModelIdentity -> TraceIdentity -> NonEmpty
                                          (ReadinessDiagnosticEvidence scope) -> result)
  -> (EvidenceReadyProof scope -> result)
  -> ReadinessAssessment scope
  -> result
foldReadinessAssessment notReady ready assessment =
  case assessment of
    Internal.ReadinessNotReady graph trace defects ->
      notReady graph trace (fmap ReadinessDiagnosticEvidence defects)
    Internal.ReadinessReady proof -> ready proof
