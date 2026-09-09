{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Complete terminal-neutral human projection of Assess results.
module O2I.Operation.Assess.Human
  ( type HumanAssessRequest
  , foldHumanAssessRequest
  , type HumanAssessContext
  , foldHumanAssessContext
  , type HumanAssessmentSubjectValue
  , foldHumanAssessmentSubjectValue
  , type HumanAssessmentInputDiagnostic
  , foldHumanAssessmentInputDiagnostic
  , type HumanAssessmentEvidenceKey
  , foldHumanAssessmentEvidenceKey
  , type HumanAssessmentDiagnostic
  , foldHumanAssessmentDiagnostic
  , type HumanAssessmentReadinessKey
  , foldHumanAssessmentReadinessKey
  , type HumanAssessmentUnavailableReason
  , foldHumanAssessmentUnavailableReason
  , type HumanAssessUnavailable
  , foldHumanAssessUnavailable
  , type HumanDomainValue
  , foldHumanDomainValue
  , type HumanObservation
  , foldHumanObservation
  , type HumanObservationAssessment
  , foldHumanObservationAssessment
  , type HumanEvidenceAssessedProof
  , foldHumanEvidenceAssessedProof
  , type HumanAssessmentResult
  , foldHumanAssessmentResult
  , type HumanAssessFailure
  , foldHumanAssessFailure
  , type HumanAssessReport
  , assessHumanReport
  , foldHumanAssessReport
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Assessment (AssessmentLimitationKind(..))
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract (coreRuleIdText)
import O2I.Operation.Assess.Request (AssessRequest, foldAssessRequest)
import O2I.Operation.Assess.Result
  ( AssessPrerequisite
  , AssessResult
  , AssessUnavailable
  , PreparedAssess
  , foldAssessUnavailable
  , foldPreparedAssess
  )
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanAssessFailure
  , foldHumanAssessFailure
  , projectAssessFailure
  )
import O2I.Operation.Human.Value
  ( HumanAdapterSelection
  , HumanInputSource
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanQualifiedType
  , HumanSourceIdentity
  , HumanTraceBinding
  , HumanTraceIdentity
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( HumanTraceBinding(..)
  , projectAcquiredAssessmentSource
  , projectAcquiredSupplementalSource
  , projectAdapterSelection
  , projectInputSource
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectQualifiedType
  , projectTraceIdentity
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldAssessReport)
import O2I.Operation.View (selectedViewDescriptor)
import qualified O2I.Readiness as Readiness
import qualified O2I.Trace as Trace

-- | Exact retained Assess request contract.
data HumanAssessRequest =
  HumanAssessRequest
    HumanInputSource
    HumanViewSelector
    HumanAdapterSelection
    HumanInputSource
    [HumanInputSource]

-- | Complete context shared by every prepared Assess branch.
data HumanAssessContext =
  HumanAssessContext
    ReportEnvelope
    HumanAssessRequest
    HumanSourceIdentity
    (Maybe HumanSourceIdentity)
    [HumanSourceIdentity]
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Closed typed subject carried by an assessment-input diagnostic.
data HumanAssessmentSubjectValue
  = HumanAssessmentTextSubject Text Text
  | HumanAssessmentNaturalSubject Text Natural
  | HumanAssessmentModelSubject Text HumanModelIdentity
  | HumanAssessmentOccurrenceSubject Text HumanOccurrenceIdentity
  | HumanAssessmentQualifiedTypeSubject Text HumanQualifiedType

-- | Complete rule, reason, pointer, and subjects of an input defect.
data HumanAssessmentInputDiagnostic =
  HumanAssessmentInputDiagnostic
    Text
    Text
    Text
    (NonEmpty HumanAssessmentSubjectValue)

-- | Closed assessment-input evidence key.
data HumanAssessmentEvidenceKey
  = HumanAssessmentSubjectKey HumanModelIdentity HumanTraceIdentity
  | HumanAssessmentActualStartKey HumanModelIdentity
  | HumanAssessmentObservationSetKey HumanModelIdentity HumanTraceIdentity
  | HumanAssessmentObservationKey HumanTraceIdentity Text

-- | Failed assessment-input rule and its exact evidence key.
data HumanAssessmentDiagnostic =
  HumanAssessmentDiagnostic Text HumanAssessmentEvidenceKey

-- | Closed readiness evidence key retained during assessment.
data HumanAssessmentReadinessKey
  = HumanAssessmentReadinessSubjectKey HumanModelIdentity HumanTraceIdentity
  | HumanAssessmentKpiDefinitionKey HumanModelIdentity
  | HumanAssessmentPlannedStartKey HumanModelIdentity
  | HumanAssessmentEvidencePlanKey HumanTraceIdentity

-- | Closed reason why assessment reconstruction was unavailable.
data HumanAssessmentUnavailableReason
  = HumanAssessmentTraceGraphMismatch HumanModelIdentity HumanModelIdentity
  | HumanAssessmentTraceSlotUnsupported
      Text
      Text
      Text
      HumanTraceBinding
      HumanTraceBinding
      Text
  | HumanAssessmentTracePromotionUnavailable Text
  | HumanAssessmentReadinessCriterionUnavailable
      Text
      HumanAssessmentReadinessKey

-- | Binding or reconstruction unavailability for an assessment subject.
data HumanAssessUnavailable
  = HumanAssessBindingUnavailable
      HumanTraceIdentity
      (NonEmpty HumanAssessmentInputDiagnostic)
  | HumanAssessReconstructionUnavailable
      HumanModelIdentity
      HumanTraceIdentity
      (NonEmpty HumanAssessmentUnavailableReason)

-- | Closed quantitative, ordinal, or categorical observation value.
data HumanDomainValue
  = HumanQuantitativeValue Text Text
  | HumanOrdinalValue Text Text
  | HumanCategoricalValue Text

-- | One ordered observation with trace, time, source, and value.
data HumanObservation =
  HumanObservation Natural HumanTraceIdentity Text Text HumanDomainValue

-- | Invalid or assessed outcome for one observation.
data HumanObservationAssessment
  = HumanInvalidObservation
      HumanObservation
      (NonEmpty HumanAssessmentDiagnostic)
  | HumanAssessedObservation HumanObservation Text Text (NonEmpty Text)

-- | Proof that the retained observation set was fully assessed.
data HumanEvidenceAssessedProof =
  HumanEvidenceAssessedProof HumanModelIdentity HumanTraceIdentity Natural

-- | Invalid collection or assessed observations for one subject.
data HumanAssessmentResult
  = HumanAssessmentCollectionInvalid
      HumanModelIdentity
      HumanTraceIdentity
      (NonEmpty HumanAssessmentDiagnostic)
  | HumanAssessmentObservations
      HumanModelIdentity
      HumanTraceIdentity
      [HumanObservationAssessment]
      (Maybe HumanEvidenceAssessedProof)

-- | Complete terminal-neutral Assess report.
data HumanAssessReport
  = HumanAssessFailed HumanAssessFailure
  | HumanAssessPrerequisiteRejected AssessPrerequisite HumanAssessContext
  | HumanAssessSubjectUnavailable HumanAssessUnavailable HumanAssessContext
  | HumanAssessCollectionInvalid HumanAssessmentResult HumanAssessContext
  | HumanAssessObservationsInvalid HumanAssessmentResult HumanAssessContext
  | HumanAssessCompleted HumanAssessmentResult HumanAssessContext

-- | Consume every exact requested Assess field.
foldHumanAssessRequest ::
     (HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> HumanInputSource -> [HumanInputSource] -> result)
  -> HumanAssessRequest
  -> result
foldHumanAssessRequest consume (HumanAssessRequest model view adapter bundle supplements) =
  consume model view adapter bundle supplements

-- | Consume every prepared Assess context field.
foldHumanAssessContext ::
     (ReportEnvelope -> HumanAssessRequest -> HumanSourceIdentity -> Maybe
                                                                       HumanSourceIdentity -> [HumanSourceIdentity] -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanAssessContext
  -> result
foldHumanAssessContext consume (HumanAssessContext envelope request model bundle supplements view diagnostics) =
  consume envelope request model bundle supplements view diagnostics

-- | Eliminate every closed assessment subject-value branch.
foldHumanAssessmentSubjectValue ::
     (Text -> Text -> result)
  -> (Text -> Natural -> result)
  -> (Text -> HumanModelIdentity -> result)
  -> (Text -> HumanOccurrenceIdentity -> result)
  -> (Text -> HumanQualifiedType -> result)
  -> HumanAssessmentSubjectValue
  -> result
foldHumanAssessmentSubjectValue text natural model occurrence qualified subject =
  case subject of
    HumanAssessmentTextSubject label value -> text label value
    HumanAssessmentNaturalSubject label value -> natural label value
    HumanAssessmentModelSubject label value -> model label value
    HumanAssessmentOccurrenceSubject label value -> occurrence label value
    HumanAssessmentQualifiedTypeSubject label value -> qualified label value

-- | Consume every assessment-input diagnostic field.
foldHumanAssessmentInputDiagnostic ::
     (Text -> Text -> Text -> NonEmpty HumanAssessmentSubjectValue -> result)
  -> HumanAssessmentInputDiagnostic
  -> result
foldHumanAssessmentInputDiagnostic consume (HumanAssessmentInputDiagnostic rule reason pointer subjects) =
  consume rule reason pointer subjects

-- | Eliminate every closed assessment evidence-key branch.
foldHumanAssessmentEvidenceKey ::
     (HumanModelIdentity -> HumanTraceIdentity -> result)
  -> (HumanModelIdentity -> result)
  -> (HumanModelIdentity -> HumanTraceIdentity -> result)
  -> (HumanTraceIdentity -> Text -> result)
  -> HumanAssessmentEvidenceKey
  -> result
foldHumanAssessmentEvidenceKey subject actualStart observations observation key =
  case key of
    HumanAssessmentSubjectKey graph trace -> subject graph trace
    HumanAssessmentActualStartKey intervention -> actualStart intervention
    HumanAssessmentObservationSetKey graph trace -> observations graph trace
    HumanAssessmentObservationKey trace observedAt ->
      observation trace observedAt

-- | Consume the failed rule and exact assessment evidence key.
foldHumanAssessmentDiagnostic ::
     (Text -> HumanAssessmentEvidenceKey -> result)
  -> HumanAssessmentDiagnostic
  -> result
foldHumanAssessmentDiagnostic consume (HumanAssessmentDiagnostic rule key) =
  consume rule key

-- | Eliminate every closed retained readiness-key branch.
foldHumanAssessmentReadinessKey ::
     (HumanModelIdentity -> HumanTraceIdentity -> result)
  -> (HumanModelIdentity -> result)
  -> (HumanModelIdentity -> result)
  -> (HumanTraceIdentity -> result)
  -> HumanAssessmentReadinessKey
  -> result
foldHumanAssessmentReadinessKey subject kpi planned evidencePlan key =
  case key of
    HumanAssessmentReadinessSubjectKey graph trace -> subject graph trace
    HumanAssessmentKpiDefinitionKey identity -> kpi identity
    HumanAssessmentPlannedStartKey identity -> planned identity
    HumanAssessmentEvidencePlanKey trace -> evidencePlan trace

-- | Eliminate every closed assessment-unavailability reason.
foldHumanAssessmentUnavailableReason ::
     (HumanModelIdentity -> HumanModelIdentity -> result)
  -> (Text -> Text -> Text -> HumanTraceBinding -> HumanTraceBinding -> Text -> result)
  -> (Text -> result)
  -> (Text -> HumanAssessmentReadinessKey -> result)
  -> HumanAssessmentUnavailableReason
  -> result
foldHumanAssessmentUnavailableReason mismatch unsupported promotion readiness reason =
  case reason of
    HumanAssessmentTraceGraphMismatch expected supplied ->
      mismatch expected supplied
    HumanAssessmentTraceSlotUnsupported kind identifier rule source target disposition ->
      unsupported kind identifier rule source target disposition
    HumanAssessmentTracePromotionUnavailable value -> promotion value
    HumanAssessmentReadinessCriterionUnavailable rule key -> readiness rule key

-- | Eliminate binding or reconstruction unavailability.
foldHumanAssessUnavailable ::
     (HumanTraceIdentity -> NonEmpty HumanAssessmentInputDiagnostic -> result)
  -> (HumanModelIdentity -> HumanTraceIdentity -> NonEmpty
                                                    HumanAssessmentUnavailableReason -> result)
  -> HumanAssessUnavailable
  -> result
foldHumanAssessUnavailable binding reconstruction unavailable =
  case unavailable of
    HumanAssessBindingUnavailable trace diagnostics -> binding trace diagnostics
    HumanAssessReconstructionUnavailable graph trace reasons ->
      reconstruction graph trace reasons

-- | Eliminate every closed observation-value branch.
foldHumanDomainValue ::
     (Text -> Text -> result)
  -> (Text -> Text -> result)
  -> (Text -> result)
  -> HumanDomainValue
  -> result
foldHumanDomainValue quantitative ordinal categorical value =
  case value of
    HumanQuantitativeValue retained unit -> quantitative retained unit
    HumanOrdinalValue scale level -> ordinal scale level
    HumanCategoricalValue retained -> categorical retained

-- | Consume every retained observation field.
foldHumanObservation ::
     (Natural -> HumanTraceIdentity -> Text -> Text -> HumanDomainValue -> result)
  -> HumanObservation
  -> result
foldHumanObservation consume (HumanObservation ordinal trace observedAt source value) =
  consume ordinal trace observedAt source value

-- | Eliminate invalid or assessed observation outcomes.
foldHumanObservationAssessment ::
     (HumanObservation -> NonEmpty HumanAssessmentDiagnostic -> result)
  -> (HumanObservation -> Text -> Text -> NonEmpty Text -> result)
  -> HumanObservationAssessment
  -> result
foldHumanObservationAssessment invalid assessed assessment =
  case assessment of
    HumanInvalidObservation observation diagnostics ->
      invalid observation diagnostics
    HumanAssessedObservation observation effect target limitations ->
      assessed observation effect target limitations

-- | Consume every retained evidence-assessed proof field.
foldHumanEvidenceAssessedProof ::
     (HumanModelIdentity -> HumanTraceIdentity -> Natural -> result)
  -> HumanEvidenceAssessedProof
  -> result
foldHumanEvidenceAssessedProof consume (HumanEvidenceAssessedProof graph trace count) =
  consume graph trace count

-- | Eliminate invalid collection or assessed-observation results.
foldHumanAssessmentResult ::
     (HumanModelIdentity -> HumanTraceIdentity -> NonEmpty
                                                    HumanAssessmentDiagnostic -> result)
  -> (HumanModelIdentity -> HumanTraceIdentity -> [HumanObservationAssessment] -> Maybe
                                                                                    HumanEvidenceAssessedProof -> result)
  -> HumanAssessmentResult
  -> result
foldHumanAssessmentResult invalid observations result =
  case result of
    HumanAssessmentCollectionInvalid graph trace diagnostics ->
      invalid graph trace diagnostics
    HumanAssessmentObservations graph trace values proof ->
      observations graph trace values proof

-- | Project an Assess result without rendering it.
assessHumanReport :: ToolDescriptor -> AssessResult -> HumanAssessReport
assessHumanReport tool =
  foldAssessReport
    tool
    (HumanAssessFailed . projectAssessFailure)
    (\envelope stage prepared ->
       preparedContext (HumanAssessPrerequisiteRejected stage) envelope prepared)
    (\envelope unavailable prepared ->
       preparedContext
         (HumanAssessSubjectUnavailable (projectUnavailable unavailable))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanAssessCollectionInvalid (projectAssessment assessment))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanAssessObservationsInvalid (projectAssessment assessment))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanAssessCompleted (projectAssessment assessment))
         envelope
         prepared)

-- | Eliminate every closed Assess-report branch.
foldHumanAssessReport ::
     (HumanAssessFailure -> result)
  -> (AssessPrerequisite -> HumanAssessContext -> result)
  -> (HumanAssessUnavailable -> HumanAssessContext -> result)
  -> (HumanAssessmentResult -> HumanAssessContext -> result)
  -> (HumanAssessmentResult -> HumanAssessContext -> result)
  -> (HumanAssessmentResult -> HumanAssessContext -> result)
  -> HumanAssessReport
  -> result
foldHumanAssessReport failed prerequisite unavailable collection invalid completed report =
  case report of
    HumanAssessFailed failure -> failed failure
    HumanAssessPrerequisiteRejected stage context -> prerequisite stage context
    HumanAssessSubjectUnavailable reason context -> unavailable reason context
    HumanAssessCollectionInvalid result context -> collection result context
    HumanAssessObservationsInvalid result context -> invalid result context
    HumanAssessCompleted result context -> completed result context

preparedContext ::
     (HumanAssessContext -> HumanAssessReport)
  -> ReportEnvelope
  -> PreparedAssess
  -> HumanAssessReport
preparedContext constructor envelope prepared =
  foldPreparedAssess
    (\request view bundle supplements diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanAssessContext
                envelope
                (projectAssessRequest request)
                (humanDiagnosticDocumentModelSource document)
                (projectAcquiredAssessmentSource <$> bundle)
                (map projectAcquiredSupplementalSource supplements)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    prepared

projectAssessRequest :: AssessRequest -> HumanAssessRequest
projectAssessRequest =
  foldAssessRequest $ \model view adapter bundle supplements ->
    HumanAssessRequest
      (projectInputSource model)
      (projectViewSelector view)
      (projectAdapterSelection adapter)
      (projectInputSource bundle)
      (map projectInputSource supplements)

projectUnavailable :: AssessUnavailable -> HumanAssessUnavailable
projectUnavailable =
  foldAssessUnavailable
    (\trace defects ->
       HumanAssessBindingUnavailable
         (projectTraceIdentity trace)
         (fmap projectInputDiagnostic defects))
    (\graph trace reasons ->
       HumanAssessReconstructionUnavailable
         (projectModelIdentity graph)
         (projectTraceIdentity trace)
         (fmap projectUnavailableReason reasons))

projectAssessment :: Assessment.AssessmentResult scope -> HumanAssessmentResult
projectAssessment result =
  Assessment.foldAssessmentResult
    (\graph trace diagnostics ->
       HumanAssessmentCollectionInvalid
         (projectModelIdentity graph)
         (projectTraceIdentity trace)
         (fmap projectDiagnostic diagnostics))
    (\observations proof ->
       HumanAssessmentObservations
         (projectModelIdentity (Assessment.assessmentResultGraphIdentity result))
         (projectTraceIdentity (Assessment.assessmentResultTraceIdentity result))
         (map projectObservationAssessment observations)
         (projectProof <$> proof))
    result

projectObservationAssessment ::
     Assessment.ObservationAssessment scope -> HumanObservationAssessment
projectObservationAssessment =
  Assessment.foldObservationAssessment
    (\observation diagnostics ->
       HumanInvalidObservation
         (projectObservation observation)
         (fmap projectDiagnostic diagnostics))
    (\observation effect target limitations ->
       HumanAssessedObservation
         (projectObservation observation)
         (effectText effect)
         (targetText target)
         (fmap limitationText limitations))

projectObservation :: Assessment.Observation -> HumanObservation
projectObservation observation =
  HumanObservation
    (Assessment.observationOrdinalValue
       (Assessment.observationOrdinal observation))
    (projectTraceIdentity (Assessment.observationTraceIdentity observation))
    (Readiness.utcTimestampText (Assessment.observationObservedAt observation))
    (Readiness.canonicalTextValue (Assessment.observationSource observation))
    (projectDomainValue (Assessment.observationValue observation))

projectDomainValue :: Readiness.DomainValue -> HumanDomainValue
projectDomainValue =
  Readiness.foldDomainValue
    (\value unit ->
       HumanQuantitativeValue
         (Readiness.canonicalDecimalText value)
         (Readiness.unitText unit))
    (\scale level ->
       HumanOrdinalValue
         (Readiness.canonicalTextValue scale)
         (Readiness.canonicalTextValue level))
    (HumanCategoricalValue . Readiness.canonicalTextValue)

projectProof ::
     Assessment.EvidenceAssessedProof scope -> HumanEvidenceAssessedProof
projectProof proof =
  HumanEvidenceAssessedProof
    (projectModelIdentity (Assessment.evidenceAssessedGraphIdentity proof))
    (projectTraceIdentity (Assessment.evidenceAssessedTraceIdentity proof))
    (Assessment.evidenceAssessedObservationCount proof)

projectDiagnostic ::
     Assessment.AssessmentDiagnosticEvidence scope -> HumanAssessmentDiagnostic
projectDiagnostic diagnostic =
  HumanAssessmentDiagnostic
    (coreRuleIdText (Assessment.assessmentDiagnosticRule diagnostic))
    (projectEvidenceKey (Assessment.assessmentDiagnosticKey diagnostic))

projectEvidenceKey ::
     Assessment.AssessmentEvidenceKey -> HumanAssessmentEvidenceKey
projectEvidenceKey =
  Assessment.foldAssessmentEvidenceKey
    (\graph trace ->
       HumanAssessmentSubjectKey
         (projectModelIdentity graph)
         (projectTraceIdentity trace))
    (HumanAssessmentActualStartKey . projectModelIdentity)
    (\graph trace ->
       HumanAssessmentObservationSetKey
         (projectModelIdentity graph)
         (projectTraceIdentity trace))
    (\trace observedAt ->
       HumanAssessmentObservationKey
         (projectTraceIdentity trace)
         (Readiness.utcTimestampText observedAt))

projectInputDiagnostic ::
     Assessment.AssessmentInputDefect -> HumanAssessmentInputDiagnostic
projectInputDiagnostic defect =
  HumanAssessmentInputDiagnostic
    (coreRuleIdText (Assessment.assessmentInputDefectRule defect))
    (inputDefectKindText (Assessment.assessmentInputDefectKind defect))
    (Assessment.assessmentInputDefectPointer defect)
    (fmap projectInputSubject (Assessment.assessmentInputDefectSubjects defect))

projectInputSubject ::
     Readiness.EvidenceInputDiagnosticSubject -> HumanAssessmentSubjectValue
projectInputSubject =
  Readiness.foldEvidenceInputDiagnosticSubject
    HumanAssessmentTextSubject
    HumanAssessmentNaturalSubject
    (\label value ->
       HumanAssessmentModelSubject label (projectModelIdentity value))
    (\label value ->
       HumanAssessmentOccurrenceSubject label (projectOccurrenceIdentity value))
    (\label value ->
       HumanAssessmentQualifiedTypeSubject label (projectQualifiedType value))

projectUnavailableReason ::
     Assessment.AssessmentSubjectUnavailableReason
  -> HumanAssessmentUnavailableReason
projectUnavailableReason =
  Assessment.foldAssessmentSubjectUnavailableReason
    (Readiness.foldReadinessSubjectUnavailableReason
       projectSuppliedTraceReason
       (HumanAssessmentTracePromotionUnavailable . promotionReasonText))
    (\rule key ->
       HumanAssessmentReadinessCriterionUnavailable
         (coreRuleIdText rule)
         (projectReadinessKey key))

projectSuppliedTraceReason ::
     Trace.SuppliedTraceUnavailableReason -> HumanAssessmentUnavailableReason
projectSuppliedTraceReason reason =
  case reason of
    Trace.TraceGraphIdentityMismatch expected supplied ->
      HumanAssessmentTraceGraphMismatch
        (projectModelIdentity expected)
        (projectModelIdentity supplied)
    Trace.ExactSlotUnsupported slot endpoints disposition ->
      HumanAssessmentTraceSlotUnsupported
        (slotKindText slot)
        (Trace.traceSlotId slot)
        (coreRuleIdText (Trace.traceSlotRuleId slot))
        (HumanTraceBinding
           (Trace.traceVariableId (Trace.traceBoundSourceVariable endpoints))
           (projectModelIdentity (Trace.traceBoundSourceIdentity endpoints)))
        (HumanTraceBinding
           (Trace.traceVariableId (Trace.traceBoundTargetVariable endpoints))
           (projectModelIdentity (Trace.traceBoundTargetIdentity endpoints)))
        (gapDispositionText disposition)

projectReadinessKey ::
     Readiness.ReadinessEvidenceKey -> HumanAssessmentReadinessKey
projectReadinessKey =
  Readiness.foldReadinessEvidenceKey
    (\graph trace ->
       HumanAssessmentReadinessSubjectKey
         (projectModelIdentity graph)
         (projectTraceIdentity trace))
    (HumanAssessmentKpiDefinitionKey . projectModelIdentity)
    (HumanAssessmentPlannedStartKey . projectModelIdentity)
    (HumanAssessmentEvidencePlanKey . projectTraceIdentity)

effectText :: Assessment.EffectResult -> Text
effectText =
  Assessment.foldEffectResult
    "satisfied"
    "not-satisfied"
    "not-assessable-zero-baseline"

targetText :: Assessment.TargetAttainment -> Text
targetText =
  Assessment.foldTargetAttainment
    "satisfied-in-observation-by-due"
    "satisfied-in-observation-after-due"
    "not-satisfied-in-observation"

limitationText :: AssessmentLimitationKind -> Text
limitationText limitation =
  case limitation of
    CausalityNotEstablishedLimitation -> "causality-not-established"
    FirstTargetAttainmentTimeNotEstablishedLimitation ->
      "first-target-attainment-time-not-established"

slotKindText :: Trace.TraceSlot -> Text
slotKindText slot =
  case slot of
    Trace.RelationTraceSlot _ -> "relation"
    Trace.OwnershipTraceSlot _ -> "ownership"

gapDispositionText :: Trace.TraceGapDisposition -> Text
gapDispositionText disposition =
  case disposition of
    Trace.MissingSupport -> "missing-support"
    Trace.CandidateOnlySupport -> "candidate-only"
    Trace.GloballyInconsistentSupport -> "globally-inconsistent"

promotionReasonText :: Trace.TracePromotionUnavailableReason -> Text
promotionReasonText reason =
  case reason of
    Trace.StrategyAssessmentUnavailable -> "strategy-assessment-unavailable"
    Trace.StrategyAssessmentInvalid -> "strategy-assessment-invalid"
    Trace.StrategyProofModelMismatch -> "strategy-proof-model-mismatch"
    Trace.StrategyIdentityMismatch -> "strategy-identity-mismatch"
    Trace.StrategyDiagnosisMismatch -> "strategy-diagnosis-mismatch"
    Trace.StrategyIntentMismatch -> "strategy-intent-mismatch"
    Trace.StrategyActionNotInFormulation -> "strategy-action-not-in-formulation"
    Trace.StrategyKeyResultNotInFormulation ->
      "strategy-key-result-not-in-formulation"

inputDefectKindText :: Readiness.EvidenceInputDefectKind -> Text
inputDefectKindText kind =
  case kind of
    Readiness.EvidenceInputInvalidUtf8 -> "invalid-utf8"
    Readiness.EvidenceInputInvalidJsonSyntax -> "invalid-json-syntax"
    Readiness.EvidenceInputDuplicateObjectMember -> "duplicate-object-member"
    Readiness.EvidenceInputTopLevelObjectRequired -> "top-level-object-required"
    Readiness.EvidenceInputDiscriminatorInvalid -> "discriminator-invalid"
    Readiness.EvidenceInputRequiredMemberMissing -> "required-member-missing"
    Readiness.EvidenceInputUnknownMember -> "unknown-member"
    Readiness.EvidenceInputValueKindInvalid -> "value-kind-invalid"
    Readiness.EvidenceInputScalarGrammarInvalid -> "scalar-grammar-invalid"
    Readiness.EvidenceInputArrayCardinalityInvalid ->
      "array-cardinality-invalid"
    Readiness.EvidenceInputArrayDistinctnessInvalid ->
      "array-distinctness-invalid"
    Readiness.EvidenceInputNormalizationCollision -> "normalization-collision"
    Readiness.EvidenceInputModelIdentityUnicodeScalarInvalid ->
      "model-identity-unicode-scalar-invalid"
    Readiness.EvidenceInputModelIdentityContainsNul ->
      "model-identity-contains-nul"
    Readiness.EvidenceInputIdentityUnknown -> "unknown"
    Readiness.EvidenceInputIdentityAmbiguous -> "ambiguous"
    Readiness.EvidenceInputIdentityOutOfSelectedView -> "out-of-selected-view"
    Readiness.EvidenceInputIdentityWrongType -> "wrong-type"
