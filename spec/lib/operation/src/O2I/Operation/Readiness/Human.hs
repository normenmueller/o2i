{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Complete terminal-neutral human projection of Readiness results.
module O2I.Operation.Readiness.Human
  ( type HumanReadinessRequest
  , foldHumanReadinessRequest
  , type HumanReadinessContext
  , foldHumanReadinessContext
  , type HumanEvidenceInputSubject
  , foldHumanEvidenceInputSubject
  , type HumanEvidenceInputDiagnostic
  , foldHumanEvidenceInputDiagnostic
  , type HumanReadinessEvidenceKey
  , foldHumanReadinessEvidenceKey
  , type HumanReadinessDiagnostic
  , foldHumanReadinessDiagnostic
  , type HumanReadinessUnavailableReason
  , foldHumanReadinessUnavailableReason
  , type HumanReadinessUnavailable
  , foldHumanReadinessUnavailable
  , type HumanReadinessAssessment
  , foldHumanReadinessAssessment
  , type HumanReadinessFailure
  , foldHumanReadinessFailure
  , type HumanReadinessReport
  , readinessHumanReport
  , foldHumanReadinessReport
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (coreRuleIdText)
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanReadinessFailure
  , foldHumanReadinessFailure
  , projectReadinessFailure
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
  , projectAcquiredReadinessSource
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
import O2I.Operation.Readiness.Request (ReadinessRequest, foldReadinessRequest)
import O2I.Operation.Readiness.Result
  ( PreparedReadiness
  , ReadinessPrerequisite
  , ReadinessResult
  , ReadinessUnavailable
  , foldPreparedReadiness
  , foldReadinessUnavailable
  )
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldReadinessReport)
import O2I.Operation.View (selectedViewDescriptor)
import qualified O2I.Readiness as Readiness
import qualified O2I.Trace as Trace

-- | Exact retained Readiness request contract.
data HumanReadinessRequest =
  HumanReadinessRequest
    HumanInputSource
    HumanViewSelector
    HumanAdapterSelection
    HumanInputSource
    [HumanInputSource]

-- | Complete context shared by every prepared Readiness branch.
data HumanReadinessContext =
  HumanReadinessContext
    ReportEnvelope
    HumanReadinessRequest
    HumanSourceIdentity
    (Maybe HumanSourceIdentity)
    [HumanSourceIdentity]
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Closed typed subject carried by an evidence-input diagnostic.
data HumanEvidenceInputSubject
  = HumanEvidenceTextSubject Text Text
  | HumanEvidenceNaturalSubject Text Natural
  | HumanEvidenceModelSubject Text HumanModelIdentity
  | HumanEvidenceOccurrenceSubject Text HumanOccurrenceIdentity
  | HumanEvidenceQualifiedTypeSubject Text HumanQualifiedType

-- | Complete rule, reason, pointer, and subjects of an input defect.
data HumanEvidenceInputDiagnostic =
  HumanEvidenceInputDiagnostic
    Text
    Text
    Text
    (NonEmpty HumanEvidenceInputSubject)

-- | Closed readiness criterion key.
data HumanReadinessEvidenceKey
  = HumanReadinessSubjectKey HumanModelIdentity HumanTraceIdentity
  | HumanKpiDefinitionKey HumanModelIdentity
  | HumanPlannedStartKey HumanModelIdentity
  | HumanEvidencePlanKey HumanTraceIdentity

-- | Failed readiness rule and its exact evidence key.
data HumanReadinessDiagnostic =
  HumanReadinessDiagnostic Text HumanReadinessEvidenceKey

-- | Closed reason why trace reconstruction was unavailable.
data HumanReadinessUnavailableReason
  = HumanTraceGraphMismatch HumanModelIdentity HumanModelIdentity
  | HumanTraceSlotUnsupported
      Text
      Text
      Text
      HumanTraceBinding
      HumanTraceBinding
      Text
  | HumanTracePromotionUnavailable Text

-- | Binding or reconstruction unavailability for a readiness subject.
data HumanReadinessUnavailable
  = HumanReadinessBindingUnavailable
      HumanTraceIdentity
      (NonEmpty HumanEvidenceInputDiagnostic)
  | HumanReadinessReconstructionUnavailable
      HumanModelIdentity
      HumanTraceIdentity
      (NonEmpty HumanReadinessUnavailableReason)

-- | Ready or not-ready assessment with exact typed evidence.
data HumanReadinessAssessment
  = HumanNotReadyAssessment
      HumanModelIdentity
      HumanTraceIdentity
      (NonEmpty HumanReadinessDiagnostic)
  | HumanReadyAssessment HumanModelIdentity HumanTraceIdentity

-- | Complete terminal-neutral Readiness report.
data HumanReadinessReport
  = HumanReadinessFailed HumanReadinessFailure
  | HumanReadinessPrerequisiteRejected
      ReadinessPrerequisite
      HumanReadinessContext
  | HumanReadinessSubjectUnavailable
      HumanReadinessUnavailable
      HumanReadinessContext
  | HumanReadinessNotReady HumanReadinessAssessment HumanReadinessContext
  | HumanReadinessReady HumanReadinessAssessment HumanReadinessContext

-- | Consume every exact requested Readiness field.
foldHumanReadinessRequest ::
     (HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> HumanInputSource -> [HumanInputSource] -> result)
  -> HumanReadinessRequest
  -> result
foldHumanReadinessRequest consume (HumanReadinessRequest model view adapter evidence supplements) =
  consume model view adapter evidence supplements

-- | Consume every prepared Readiness context field.
foldHumanReadinessContext ::
     (ReportEnvelope -> HumanReadinessRequest -> HumanSourceIdentity -> Maybe
                                                                          HumanSourceIdentity -> [HumanSourceIdentity] -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanReadinessContext
  -> result
foldHumanReadinessContext consume (HumanReadinessContext envelope request model evidence supplements view diagnostics) =
  consume envelope request model evidence supplements view diagnostics

-- | Eliminate every closed evidence-input subject branch.
foldHumanEvidenceInputSubject ::
     (Text -> Text -> result)
  -> (Text -> Natural -> result)
  -> (Text -> HumanModelIdentity -> result)
  -> (Text -> HumanOccurrenceIdentity -> result)
  -> (Text -> HumanQualifiedType -> result)
  -> HumanEvidenceInputSubject
  -> result
foldHumanEvidenceInputSubject text natural model occurrence qualified subject =
  case subject of
    HumanEvidenceTextSubject label value -> text label value
    HumanEvidenceNaturalSubject label value -> natural label value
    HumanEvidenceModelSubject label value -> model label value
    HumanEvidenceOccurrenceSubject label value -> occurrence label value
    HumanEvidenceQualifiedTypeSubject label value -> qualified label value

-- | Consume every evidence-input diagnostic field.
foldHumanEvidenceInputDiagnostic ::
     (Text -> Text -> Text -> NonEmpty HumanEvidenceInputSubject -> result)
  -> HumanEvidenceInputDiagnostic
  -> result
foldHumanEvidenceInputDiagnostic consume (HumanEvidenceInputDiagnostic rule reason pointer subjects) =
  consume rule reason pointer subjects

-- | Eliminate every closed readiness evidence-key branch.
foldHumanReadinessEvidenceKey ::
     (HumanModelIdentity -> HumanTraceIdentity -> result)
  -> (HumanModelIdentity -> result)
  -> (HumanModelIdentity -> result)
  -> (HumanTraceIdentity -> result)
  -> HumanReadinessEvidenceKey
  -> result
foldHumanReadinessEvidenceKey subject kpi planned evidencePlan key =
  case key of
    HumanReadinessSubjectKey graph trace -> subject graph trace
    HumanKpiDefinitionKey identity -> kpi identity
    HumanPlannedStartKey identity -> planned identity
    HumanEvidencePlanKey trace -> evidencePlan trace

-- | Consume the failed rule and exact readiness evidence key.
foldHumanReadinessDiagnostic ::
     (Text -> HumanReadinessEvidenceKey -> result)
  -> HumanReadinessDiagnostic
  -> result
foldHumanReadinessDiagnostic consume (HumanReadinessDiagnostic rule key) =
  consume rule key

-- | Eliminate every closed readiness-unavailability reason.
foldHumanReadinessUnavailableReason ::
     (HumanModelIdentity -> HumanModelIdentity -> result)
  -> (Text -> Text -> Text -> HumanTraceBinding -> HumanTraceBinding -> Text -> result)
  -> (Text -> result)
  -> HumanReadinessUnavailableReason
  -> result
foldHumanReadinessUnavailableReason mismatch unsupported promotion reason =
  case reason of
    HumanTraceGraphMismatch expected supplied -> mismatch expected supplied
    HumanTraceSlotUnsupported kind identifier rule source target disposition ->
      unsupported kind identifier rule source target disposition
    HumanTracePromotionUnavailable retained -> promotion retained

-- | Eliminate binding or reconstruction unavailability.
foldHumanReadinessUnavailable ::
     (HumanTraceIdentity -> NonEmpty HumanEvidenceInputDiagnostic -> result)
  -> (HumanModelIdentity -> HumanTraceIdentity -> NonEmpty
                                                    HumanReadinessUnavailableReason -> result)
  -> HumanReadinessUnavailable
  -> result
foldHumanReadinessUnavailable binding reconstruction unavailable =
  case unavailable of
    HumanReadinessBindingUnavailable trace diagnostics ->
      binding trace diagnostics
    HumanReadinessReconstructionUnavailable graph trace reasons ->
      reconstruction graph trace reasons

-- | Eliminate not-ready or ready assessment results.
foldHumanReadinessAssessment ::
     (HumanModelIdentity -> HumanTraceIdentity -> NonEmpty
                                                    HumanReadinessDiagnostic -> result)
  -> (HumanModelIdentity -> HumanTraceIdentity -> result)
  -> HumanReadinessAssessment
  -> result
foldHumanReadinessAssessment notReady ready assessment =
  case assessment of
    HumanNotReadyAssessment graph trace diagnostics ->
      notReady graph trace diagnostics
    HumanReadyAssessment graph trace -> ready graph trace

-- | Project a Readiness result without rendering it.
readinessHumanReport ::
     ToolDescriptor -> ReadinessResult -> HumanReadinessReport
readinessHumanReport tool =
  foldReadinessReport
    tool
    (HumanReadinessFailed . projectReadinessFailure)
    (\envelope stage prepared ->
       preparedContext
         (HumanReadinessPrerequisiteRejected stage)
         envelope
         prepared)
    (\envelope unavailable prepared ->
       preparedContext
         (HumanReadinessSubjectUnavailable (projectUnavailable unavailable))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanReadinessNotReady (projectAssessment assessment))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanReadinessReady (projectAssessment assessment))
         envelope
         prepared)

-- | Eliminate every closed Readiness-report branch.
foldHumanReadinessReport ::
     (HumanReadinessFailure -> result)
  -> (ReadinessPrerequisite -> HumanReadinessContext -> result)
  -> (HumanReadinessUnavailable -> HumanReadinessContext -> result)
  -> (HumanReadinessAssessment -> HumanReadinessContext -> result)
  -> (HumanReadinessAssessment -> HumanReadinessContext -> result)
  -> HumanReadinessReport
  -> result
foldHumanReadinessReport failed prerequisite unavailable notReady ready report =
  case report of
    HumanReadinessFailed failure -> failed failure
    HumanReadinessPrerequisiteRejected stage context ->
      prerequisite stage context
    HumanReadinessSubjectUnavailable reason context ->
      unavailable reason context
    HumanReadinessNotReady assessment context -> notReady assessment context
    HumanReadinessReady assessment context -> ready assessment context

preparedContext ::
     (HumanReadinessContext -> HumanReadinessReport)
  -> ReportEnvelope
  -> PreparedReadiness
  -> HumanReadinessReport
preparedContext constructor envelope prepared =
  foldPreparedReadiness
    (\request view evidence supplements diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanReadinessContext
                envelope
                (projectReadinessRequest request)
                (humanDiagnosticDocumentModelSource document)
                (projectAcquiredReadinessSource <$> evidence)
                (map projectAcquiredSupplementalSource supplements)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    prepared

projectReadinessRequest :: ReadinessRequest -> HumanReadinessRequest
projectReadinessRequest =
  foldReadinessRequest $ \model view adapter evidence supplements ->
    HumanReadinessRequest
      (projectInputSource model)
      (projectViewSelector view)
      (projectAdapterSelection adapter)
      (projectInputSource evidence)
      (map projectInputSource supplements)

projectUnavailable :: ReadinessUnavailable -> HumanReadinessUnavailable
projectUnavailable =
  foldReadinessUnavailable
    (\trace defects ->
       HumanReadinessBindingUnavailable
         (projectTraceIdentity trace)
         (fmap projectInputDiagnostic defects))
    (\graph trace reasons ->
       HumanReadinessReconstructionUnavailable
         (projectModelIdentity graph)
         (projectTraceIdentity trace)
         (fmap projectUnavailableReason reasons))

projectAssessment ::
     Readiness.ReadinessAssessment scope -> HumanReadinessAssessment
projectAssessment =
  Readiness.foldReadinessAssessment
    (\graph trace diagnostics ->
       HumanNotReadyAssessment
         (projectModelIdentity graph)
         (projectTraceIdentity trace)
         (fmap projectReadinessDiagnostic diagnostics))
    (\proof ->
       HumanReadyAssessment
         (projectModelIdentity (Readiness.evidenceReadyGraphIdentity proof))
         (projectTraceIdentity (Readiness.evidenceReadyTraceIdentity proof)))

projectInputDiagnostic ::
     Readiness.EvidenceInputDefect -> HumanEvidenceInputDiagnostic
projectInputDiagnostic defect =
  HumanEvidenceInputDiagnostic
    (coreRuleIdText (Readiness.evidenceInputDefectRule defect))
    (inputDefectKindText (Readiness.evidenceInputDefectKind defect))
    (Readiness.evidenceInputDefectPointer defect)
    (fmap projectInputSubject (Readiness.evidenceInputDefectSubjects defect))

projectInputSubject ::
     Readiness.EvidenceInputDiagnosticSubject -> HumanEvidenceInputSubject
projectInputSubject =
  Readiness.foldEvidenceInputDiagnosticSubject
    HumanEvidenceTextSubject
    HumanEvidenceNaturalSubject
    (\label value ->
       HumanEvidenceModelSubject label (projectModelIdentity value))
    (\label value ->
       HumanEvidenceOccurrenceSubject label (projectOccurrenceIdentity value))
    (\label value ->
       HumanEvidenceQualifiedTypeSubject label (projectQualifiedType value))

projectUnavailableReason ::
     Readiness.ReadinessSubjectUnavailableReason
  -> HumanReadinessUnavailableReason
projectUnavailableReason =
  Readiness.foldReadinessSubjectUnavailableReason
    projectSuppliedTraceReason
    (HumanTracePromotionUnavailable . promotionReasonText)

projectSuppliedTraceReason ::
     Trace.SuppliedTraceUnavailableReason -> HumanReadinessUnavailableReason
projectSuppliedTraceReason reason =
  case reason of
    Trace.TraceGraphIdentityMismatch expected supplied ->
      HumanTraceGraphMismatch
        (projectModelIdentity expected)
        (projectModelIdentity supplied)
    Trace.ExactSlotUnsupported slot endpoints disposition ->
      HumanTraceSlotUnsupported
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

projectReadinessDiagnostic ::
     Readiness.ReadinessDiagnosticEvidence scope -> HumanReadinessDiagnostic
projectReadinessDiagnostic diagnostic =
  HumanReadinessDiagnostic
    (coreRuleIdText (Readiness.readinessDiagnosticRule diagnostic))
    (projectReadinessKey (Readiness.readinessDiagnosticKey diagnostic))

projectReadinessKey ::
     Readiness.ReadinessEvidenceKey -> HumanReadinessEvidenceKey
projectReadinessKey =
  Readiness.foldReadinessEvidenceKey
    (\graph trace ->
       HumanReadinessSubjectKey
         (projectModelIdentity graph)
         (projectTraceIdentity trace))
    (HumanKpiDefinitionKey . projectModelIdentity)
    (HumanPlannedStartKey . projectModelIdentity)
    (HumanEvidencePlanKey . projectTraceIdentity)

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
