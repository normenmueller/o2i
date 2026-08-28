{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private representation of the Core-owned Readiness contract.
module O2I.Readiness.Internal
  ( ReadinessInputOrdinal(..)
  , CanonicalText(..)
  , Unit(..)
  , CanonicalDecimal(..)
  , PositiveDecimal(..)
  , UtcTimestamp(..)
  , compareUtcTimestamp
  , EffectDirection(..)
  , QuantitativeComparison(..)
  , OrdinalComparison(..)
  , ValueDomain(..)
  , DomainValue(..)
  , KPIDefinition(..)
  , PlannedInterventionStart(..)
  , BaselineObservation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , EvidencePlan(..)
  , ReadinessInput(..)
  , EvidenceInputDefectKind(..)
  , EvidenceInputDiagnosticSubject(..)
  , EvidenceInputDefect(..)
  , sortEvidenceInputDefects
  , BoundReadinessInput(..)
  , ReadinessInputBinding(..)
  , ReadinessSubjectUnavailableReason(..)
  , ReadinessSubject(..)
  , ReadinessSubjectAssessment(..)
  , ReadinessRule(..)
  , readinessRuleId
  , ReadinessEvidenceKey(..)
  , ReadinessDefect(..)
  , sortReadinessDefects
  , EvidenceReadyProof(..)
  , ReadinessAssessment(..)
  , ReadinessWork(..)
  , emptyReadinessWork
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreQualifiedEndpointId)
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Trace
  ( BoundTraceIdentity
  , PromotedTraceableEffectModel
  , SuppliedTraceUnavailableReason
  , TraceIdentity
  , TracePromotionUnavailableReason
  )

-- | Stable zero-based ordinal assigned by Operation to the evidence input.
newtype ReadinessInputOrdinal =
  ReadinessInputOrdinal Natural
  deriving (Eq, Ord, Show)

-- | NFC canonical nonempty text with no admitted edge whitespace.
newtype CanonicalText =
  CanonicalText Text
  deriving (Eq, Ord, Show)

-- | Case-sensitive NFC canonical measurement unit.
newtype Unit =
  Unit Text
  deriving (Eq, Ord, Show)

-- | Exact canonical base-10 value and its preserved canonical lexeme.
data CanonicalDecimal = CanonicalDecimal
  { storedDecimalCoefficient :: !Integer
  , storedDecimalScale :: !Natural
  , storedDecimalText :: !Text
  } deriving (Eq, Show)

instance Ord CanonicalDecimal where
  compare left right =
    compare
      (scaled (commonScale left right) left)
      (scaled (commonScale left right) right)
    where
      commonScale x y = max (storedDecimalScale x) (storedDecimalScale y)
      scaled scale value =
        storedDecimalCoefficient value * 10 ^ (scale - storedDecimalScale value)

-- | Exact positive canonical decimal.
newtype PositiveDecimal =
  PositiveDecimal CanonicalDecimal
  deriving (Eq, Ord, Show)

-- | Exact canonical UTC instant. The calendar tuple is validated at decode.
data UtcTimestamp = UtcTimestamp
  { storedTimestampText :: !Text
  , storedTimestampYear :: !Int
  , storedTimestampMonth :: !Int
  , storedTimestampDay :: !Int
  , storedTimestampHour :: !Int
  , storedTimestampMinute :: !Int
  , storedTimestampSecond :: !Int
  , storedTimestampFraction :: !CanonicalDecimal
  } deriving (Eq, Show)

instance Ord UtcTimestamp where
  compare = compareUtcTimestamp

compareUtcTimestamp :: UtcTimestamp -> UtcTimestamp -> Ordering
compareUtcTimestamp left right =
  compare (fixed left) (fixed right)
    <> compare (storedTimestampFraction left) (storedTimestampFraction right)
  where
    fixed value =
      ( storedTimestampYear value
      , storedTimestampMonth value
      , storedTimestampDay value
      , storedTimestampHour value
      , storedTimestampMinute value
      , storedTimestampSecond value)

-- | Closed direction of improvement for quantitative or ordinal values.
data EffectDirection
  = EffectIncrease
  | EffectDecrease
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed comparison operator for a quantitative target threshold.
data QuantitativeComparison
  = QuantitativeAtLeast
  | QuantitativeAtMost
  | QuantitativeEqual
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed comparison operator for a rank in an ordinal scale.
data OrdinalComparison
  = OrdinalAtLeastRank
  | OrdinalAtMostRank
  | OrdinalEqualRank
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Quantitative, ordinal, or categorical KPI value domain.
data ValueDomain
  = QuantitativeDomain !Unit !EffectDirection
  | OrdinalDomain !CanonicalText !(NonEmpty CanonicalText) !EffectDirection
  | CategoricalDomain !(NonEmpty CanonicalText)
  deriving (Eq, Ord, Show)

-- | Observed value in one of the three closed domain families.
data DomainValue
  = QuantitativeValue !CanonicalDecimal !Unit
  | OrdinalValue !CanonicalText !CanonicalText
  | CategoricalValue !CanonicalText
  deriving (Eq, Ord, Show)

-- | Complete KPI definition supplied for readiness evaluation.
data KPIDefinition = KPIDefinition
  { storedKpiIdentity :: !ModelIdentity
  , storedKpiDomain :: !ValueDomain
  , storedMeasurementMethod :: !CanonicalText
  , storedInterpretation :: !CanonicalText
  } deriving (Eq, Ord, Show)

-- | Planned start timestamp for the traced intervention.
data PlannedInterventionStart = PlannedInterventionStart
  { storedPlannedIntervention :: !ModelIdentity
  , storedPlannedStartAt :: !UtcTimestamp
  } deriving (Eq, Ord, Show)

-- | Baseline value together with its observation time and source.
data BaselineObservation = BaselineObservation
  { storedBaselineObservedAt :: !UtcTimestamp
  , storedBaselineSource :: !CanonicalText
  , storedBaselineValue :: !DomainValue
  } deriving (Eq, Ord, Show)

-- | Minimum-effect criterion in one closed domain family.
data EffectCriterion
  = QuantitativeAbsoluteEffect !PositiveDecimal
  | QuantitativeRelativeEffect !PositiveDecimal
  | OrdinalStepsEffect !Natural
  | CategoricalTransitionEffect !(NonEmpty CanonicalText)
  deriving (Eq, Ord, Show)

-- | Target criterion in one closed domain family.
data TargetCriterion
  = QuantitativeThreshold !QuantitativeComparison !CanonicalDecimal !Unit
  | OrdinalThreshold !OrdinalComparison !CanonicalText !CanonicalText
  | CategoricalMembership !(NonEmpty CanonicalText)
  deriving (Eq, Ord, Show)

-- | Supplied Trace, baseline, criteria, due date, source, and establishment time.
data EvidencePlan = EvidencePlan
  { storedEvidenceTrace :: !TraceIdentity
  , storedBaseline :: !BaselineObservation
  , storedEffectCriterion :: !EffectCriterion
  , storedTargetCriterion :: !TargetCriterion
  , storedTargetDueAt :: !UtcTimestamp
  , storedEvidencePlanSource :: !CanonicalText
  , storedPlanEstablishedAt :: !UtcTimestamp
  } deriving (Eq, Show)

-- | Fully decoded and canonicalized explicit Readiness input.
data ReadinessInput = ReadinessInput
  { storedReadinessOrdinal :: !ReadinessInputOrdinal
  , storedReadinessCheckedAt :: !UtcTimestamp
  , storedKpiDefinition :: !KPIDefinition
  , storedPlannedStart :: !PlannedInterventionStart
  , storedEvidencePlan :: !EvidencePlan
  } deriving (Eq, Show)

-- | Closed classification of input decoding and selected-View binding defects.
data EvidenceInputDefectKind
  = EvidenceInputInvalidUtf8
  | EvidenceInputInvalidJsonSyntax
  | EvidenceInputDuplicateObjectMember
  | EvidenceInputTopLevelObjectRequired
  | EvidenceInputDiscriminatorInvalid
  | EvidenceInputRequiredMemberMissing
  | EvidenceInputUnknownMember
  | EvidenceInputValueKindInvalid
  | EvidenceInputScalarGrammarInvalid
  | EvidenceInputArrayCardinalityInvalid
  | EvidenceInputArrayDistinctnessInvalid
  | EvidenceInputNormalizationCollision
  | EvidenceInputModelIdentityUnicodeScalarInvalid
  | EvidenceInputModelIdentityContainsNul
  | EvidenceInputIdentityUnknown
  | EvidenceInputIdentityAmbiguous
  | EvidenceInputIdentityOutOfSelectedView
  | EvidenceInputIdentityWrongType
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Typed value attached to an input diagnostic.
data EvidenceInputDiagnosticSubject
  = EvidenceInputTextSubject !Text !Text
  | EvidenceInputNaturalSubject !Text !Natural
  | EvidenceInputModelSubject !Text !ModelIdentity
  | EvidenceInputOccurrenceSubject !Text !OccurrenceIdentity
  | EvidenceInputQualifiedTypeSubject !Text !CoreQualifiedEndpointId
  deriving (Eq, Ord, Show)

-- | Canonically addressed defect in one explicit input occurrence.
data EvidenceInputDefect = EvidenceInputDefect
  { storedEvidenceInputDefectRule :: !CoreRuleId
  , storedEvidenceInputDefectKind :: !EvidenceInputDefectKind
  , storedEvidenceInputDefectOrdinal :: !ReadinessInputOrdinal
  , storedEvidenceInputDefectPointer :: !Text
  , storedEvidenceInputDefectSubjects :: !(NonEmpty
                                             EvidenceInputDiagnosticSubject)
  } deriving (Eq, Show)

sortEvidenceInputDefects :: [EvidenceInputDefect] -> [EvidenceInputDefect]
sortEvidenceInputDefects = sortOn evidenceInputDefectOrder

evidenceInputDefectOrder ::
     EvidenceInputDefect
  -> ( ReadinessInputOrdinal
     , Int
     , Text
     , CoreRuleId
     , NonEmpty EvidenceInputDiagnosticSubject)
evidenceInputDefectOrder defect =
  ( storedEvidenceInputDefectOrdinal defect
  , evidenceInputPhaseRank (storedEvidenceInputDefectKind defect)
  , storedEvidenceInputDefectPointer defect
  , storedEvidenceInputDefectRule defect
  , storedEvidenceInputDefectSubjects defect)

evidenceInputPhaseRank :: EvidenceInputDefectKind -> Int
evidenceInputPhaseRank kind =
  case kind of
    EvidenceInputInvalidUtf8 -> 0
    EvidenceInputInvalidJsonSyntax -> 1
    EvidenceInputDuplicateObjectMember -> 2
    EvidenceInputTopLevelObjectRequired -> 3
    EvidenceInputDiscriminatorInvalid -> 3
    EvidenceInputRequiredMemberMissing -> 4
    EvidenceInputUnknownMember -> 4
    EvidenceInputValueKindInvalid -> 4
    EvidenceInputScalarGrammarInvalid -> 4
    EvidenceInputArrayCardinalityInvalid -> 4
    EvidenceInputArrayDistinctnessInvalid -> 4
    EvidenceInputNormalizationCollision -> 4
    EvidenceInputModelIdentityUnicodeScalarInvalid -> 4
    EvidenceInputModelIdentityContainsNul -> 4
    EvidenceInputIdentityUnknown -> 5
    EvidenceInputIdentityAmbiguous -> 5
    EvidenceInputIdentityOutOfSelectedView -> 5
    EvidenceInputIdentityWrongType -> 5

type role BoundReadinessInput nominal

-- | Proof that every readiness identity site binds in one selected View.
data BoundReadinessInput scope = BoundReadinessInput
  { storedBoundReadinessInput :: !ReadinessInput
  , storedBoundReadinessTrace :: !(BoundTraceIdentity scope)
  }

type role ReadinessInputBinding nominal

-- | Binding outcome for all independent input identity sites.
data ReadinessInputBinding scope
  = ReadinessInputSubjectUnavailable
      !ReadinessInput
      !(NonEmpty EvidenceInputDefect)
  | ReadinessInputBound !(BoundReadinessInput scope)

-- | Prerequisite reason from supplied-Trace validation or promotion.
data ReadinessSubjectUnavailableReason
  = ReadinessSuppliedTraceUnavailable !SuppliedTraceUnavailableReason
  | ReadinessPromotionUnavailable !TracePromotionUnavailableReason
  deriving (Eq, Show)

type role ReadinessSubject nominal

-- | Readiness subject with validated Trace and reconstructed promotion proof.
data ReadinessSubject scope = ReadinessSubject
  { storedReadinessPromotedTrace :: !(PromotedTraceableEffectModel scope)
  , storedReadinessBoundInput :: !(BoundReadinessInput scope)
  , storedReadinessSuppliedSupportCount :: !Int
  }

type role ReadinessSubjectAssessment nominal

-- | Outcome of reconstructing the readiness subject prerequisites.
data ReadinessSubjectAssessment scope
  = ReadinessSubjectUnavailable
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty ReadinessSubjectUnavailableReason)
  | ReadinessSubjectAvailable !(ReadinessSubject scope)

-- | Closed inventory of the exact seventeen Readiness criteria.
data ReadinessRule
  = ReadinessKpiDefinitionCardinality
  | ReadinessKpiDefinitionUnit
  | ReadinessKpiDefinitionValueDomain
  | ReadinessKpiDefinitionMeasurementMethod
  | ReadinessKpiDefinitionInterpretation
  | ReadinessPlannedStartCardinality
  | ReadinessEvidencePlanCardinality
  | ReadinessEvidencePlanSource
  | ReadinessEvidencePlanChronology
  | ReadinessBaselineIdentity
  | ReadinessBaselineValueDomain
  | ReadinessBaselineChronology
  | ReadinessEffectCriterionKind
  | ReadinessEffectCriterionValueDomain
  | ReadinessTargetCriterionKind
  | ReadinessTargetCriterionValueDomain
  | ReadinessTargetCriterionDue
  deriving (Bounded, Enum, Eq, Ord, Show)

readinessRuleId :: ReadinessRule -> CoreRuleId
readinessRuleId readinessRule =
  CoreRuleId
    $ case readinessRule of
        ReadinessKpiDefinitionCardinality ->
          "core.readiness.kpi-definition.cardinality"
        ReadinessKpiDefinitionUnit -> "core.readiness.kpi-definition.unit"
        ReadinessKpiDefinitionValueDomain ->
          "core.readiness.kpi-definition.value-domain"
        ReadinessKpiDefinitionMeasurementMethod ->
          "core.readiness.kpi-definition.measurement-method"
        ReadinessKpiDefinitionInterpretation ->
          "core.readiness.kpi-definition.interpretation"
        ReadinessPlannedStartCardinality ->
          "core.readiness.planned-start.cardinality"
        ReadinessEvidencePlanCardinality ->
          "core.readiness.evidence-plan.cardinality"
        ReadinessEvidencePlanSource -> "core.readiness.evidence-plan.source"
        ReadinessEvidencePlanChronology ->
          "core.readiness.evidence-plan.chronology"
        ReadinessBaselineIdentity -> "core.readiness.baseline.identity"
        ReadinessBaselineValueDomain -> "core.readiness.baseline.value-domain"
        ReadinessBaselineChronology -> "core.readiness.baseline.chronology"
        ReadinessEffectCriterionKind -> "core.readiness.effect-criterion.kind"
        ReadinessEffectCriterionValueDomain ->
          "core.readiness.effect-criterion.value-domain"
        ReadinessTargetCriterionKind -> "core.readiness.target-criterion.kind"
        ReadinessTargetCriterionValueDomain ->
          "core.readiness.target-criterion.value-domain"
        ReadinessTargetCriterionDue -> "core.readiness.target-criterion.due"

-- | Canonical key identifying readiness subject or input slot evidence.
data ReadinessEvidenceKey
  = ReadinessSubjectKey !ModelIdentity !TraceIdentity
  | KPIDefinitionSlotKey !ModelIdentity
  | PlannedStartSlotKey !ModelIdentity
  | EvidencePlanSlotKey !TraceIdentity
  deriving (Eq, Ord, Show)

data ReadinessDefect = ReadinessDefect
  { storedReadinessDefectRule :: !CoreRuleId
  , storedReadinessDefectKey :: !ReadinessEvidenceKey
  } deriving (Eq, Show)

sortReadinessDefects :: [ReadinessDefect] -> [ReadinessDefect]
sortReadinessDefects = sortOn readinessDefectOrder

readinessDefectOrder :: ReadinessDefect -> (CoreRuleId, ReadinessEvidenceKey)
readinessDefectOrder defect =
  (storedReadinessDefectRule defect, storedReadinessDefectKey defect)

type role EvidenceReadyProof nominal

-- | Nominal proof that all seventeen readiness criteria hold.
data EvidenceReadyProof scope = EvidenceReadyProof
  { storedReadyGraphIdentity :: !ModelIdentity
  , storedReadyTraceIdentity :: !TraceIdentity
  , storedReadyPromotedTrace :: !(PromotedTraceableEffectModel scope)
  , storedReadyInput :: !ReadinessInput
  }

type role ReadinessAssessment nominal

-- | NotReady or Ready evaluation result for one selected View.
data ReadinessAssessment scope
  = ReadinessNotReady !ModelIdentity !TraceIdentity !(NonEmpty ReadinessDefect)
  | ReadinessReady !(EvidenceReadyProof scope)

-- | Exact private counters for adversarial work and retention probes.
data ReadinessWork = ReadinessWork
  { readinessInputOccurrences :: !Int
  , readinessSuppliedSupportOccurrences :: !Int
  , readinessCriteriaEvaluated :: !Int
  , readinessOrderingEntries :: !Int
  , readinessOrderingKeyScalars :: !Int
  , readinessRetainedEntries :: !Int
  } deriving (Eq, Show)

emptyReadinessWork :: ReadinessWork
emptyReadinessWork = ReadinessWork 0 0 0 0 0 0
