{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Complete terminal-neutral human projection of Validate results.
module O2I.Operation.Validate.Human
  ( type HumanValidateRequest
  , foldHumanValidateRequest
  , type HumanValidateContext
  , foldHumanValidateContext
  , type HumanValidateUnavailability
  , foldHumanValidateUnavailability
  , type HumanValidateFailure
  , foldHumanValidateFailure
  , type HumanValidateReport
  , validateHumanReport
  , foldHumanValidateReport
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanValidateFailure
  , foldHumanValidateFailure
  , projectValidateFailure
  )
import O2I.Operation.Human.Value
  ( HumanAdapterSelection
  , HumanInputSource
  , HumanModelIdentity
  , HumanSourceIdentity
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( projectAcquiredSupplementalSource
  , projectAdapterSelection
  , projectInputSource
  , projectModelIdentity
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Provenance (sourceOrdinalValue)
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldValidateReport)
import O2I.Operation.Validate.Request
  ( ValidateRequest
  , ValidationLevel
  , foldValidateRequest
  , notationValidationLevel
  , profileValidationLevel
  , semanticsValidationLevel
  , structureValidationLevel
  )
import O2I.Operation.Validate.Result
  ( PreparedValidation
  , ValidateResult
  , ValidateUnavailabilityWitness
  , foldPreparedValidation
  , foldValidateUnavailabilityWitness
  )
import O2I.Operation.View (selectedViewDescriptor)
import O2I.Semantics
  ( CollectiveFitUnavailableReason(..)
  , StrategyFormulationUnavailableReason(..)
  )

-- | Exact retained Validate request contract.
data HumanValidateRequest =
  HumanValidateRequest
    ValidationLevel
    HumanInputSource
    HumanViewSelector
    HumanAdapterSelection
    [HumanInputSource]

-- | Complete context shared by every prepared Validate branch.
data HumanValidateContext =
  HumanValidateContext
    ReportEnvelope
    HumanValidateRequest
    ValidationLevel
    HumanSourceIdentity
    [HumanSourceIdentity]
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Closed typed witness for a completed unavailable validation.
data HumanValidateUnavailability
  = HumanValidateBindingUnavailable Natural
  | HumanValidateStrategyUnavailable HumanModelIdentity Text
  | HumanValidateCollectiveFitUnavailable
      HumanModelIdentity
      (NonEmpty Text)
      [HumanModelIdentity]
  | HumanValidateCollectiveCoverageUnavailable
      HumanModelIdentity
      [HumanModelIdentity]
  | HumanValidatePrimitiveSupportUnavailable
      HumanModelIdentity
      HumanModelIdentity
      (NonEmpty Text)
      [HumanModelIdentity]

-- | Complete terminal-neutral validation report.
data HumanValidateReport
  = HumanValidateFailed HumanValidateFailure
  | HumanValidateAccepted HumanValidateContext
  | HumanValidateRejected HumanValidateContext
  | HumanValidateUnavailable
      (NonEmpty HumanValidateUnavailability)
      HumanValidateContext

-- | Consume every exact requested Validate field.
foldHumanValidateRequest ::
     (ValidationLevel -> HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> [HumanInputSource] -> result)
  -> HumanValidateRequest
  -> result
foldHumanValidateRequest consume (HumanValidateRequest level model view adapter supplements) =
  consume level model view adapter supplements

-- | Consume every prepared Validate context field.
foldHumanValidateContext ::
     (ReportEnvelope -> HumanValidateRequest -> ValidationLevel -> HumanSourceIdentity -> [HumanSourceIdentity] -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanValidateContext
  -> result
foldHumanValidateContext consume (HumanValidateContext envelope request completed model supplements view diagnostics) =
  consume envelope request completed model supplements view diagnostics

-- | Eliminate every closed validation-unavailability branch.
foldHumanValidateUnavailability ::
     (Natural -> result)
  -> (HumanModelIdentity -> Text -> result)
  -> (HumanModelIdentity -> NonEmpty Text -> [HumanModelIdentity] -> result)
  -> (HumanModelIdentity -> [HumanModelIdentity] -> result)
  -> (HumanModelIdentity -> HumanModelIdentity -> NonEmpty Text -> [HumanModelIdentity] -> result)
  -> HumanValidateUnavailability
  -> result
foldHumanValidateUnavailability binding strategy fit coverage primitive unavailable =
  case unavailable of
    HumanValidateBindingUnavailable ordinal -> binding ordinal
    HumanValidateStrategyUnavailable subject reason -> strategy subject reason
    HumanValidateCollectiveFitUnavailable subject reasons blockers ->
      fit subject reasons blockers
    HumanValidateCollectiveCoverageUnavailable subject blockers ->
      coverage subject blockers
    HumanValidatePrimitiveSupportUnavailable subject participant reasons blockers ->
      primitive subject participant reasons blockers

-- | Project a validation result without rendering it.
validateHumanReport :: ToolDescriptor -> ValidateResult -> HumanValidateReport
validateHumanReport tool =
  foldValidateReport
    tool
    (HumanValidateFailed . projectValidateFailure)
    (prepared HumanValidateAccepted)
    (prepared HumanValidateRejected)
    (\envelope witnesses subject ->
       prepared
         (HumanValidateUnavailable (fmap projectUnavailable witnesses))
         envelope
         subject)

-- | Eliminate every closed validation-report branch.
foldHumanValidateReport ::
     (HumanValidateFailure -> result)
  -> (HumanValidateContext -> result)
  -> (HumanValidateContext -> result)
  -> (NonEmpty HumanValidateUnavailability -> HumanValidateContext -> result)
  -> HumanValidateReport
  -> result
foldHumanValidateReport failed accepted rejected unavailable report =
  case report of
    HumanValidateFailed failure -> failed failure
    HumanValidateAccepted context -> accepted context
    HumanValidateRejected context -> rejected context
    HumanValidateUnavailable witnesses context -> unavailable witnesses context

prepared ::
     (HumanValidateContext -> HumanValidateReport)
  -> ReportEnvelope
  -> PreparedValidation
  -> HumanValidateReport
prepared constructor envelope subject =
  foldPreparedValidation
    (\request level view supplements diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanValidateContext
                envelope
                (projectValidateRequest request)
                level
                (humanDiagnosticDocumentModelSource document)
                (map projectAcquiredSupplementalSource supplements)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    subject

projectValidateRequest :: ValidateRequest -> HumanValidateRequest
projectValidateRequest =
  foldValidateRequest
    (project notationValidationLevel [])
    (project profileValidationLevel [])
    (project structureValidationLevel [])
    (\model view adapter supplements ->
       project semanticsValidationLevel supplements model view adapter)
  where
    project level supplements model view adapter =
      HumanValidateRequest
        level
        (projectInputSource model)
        (projectViewSelector view)
        (projectAdapterSelection adapter)
        (map projectInputSource supplements)

projectUnavailable ::
     ValidateUnavailabilityWitness -> HumanValidateUnavailability
projectUnavailable =
  foldValidateUnavailabilityWitness
    (HumanValidateBindingUnavailable . sourceOrdinalValue)
    (\subject reason ->
       HumanValidateStrategyUnavailable
         (projectModelIdentity subject)
         (strategyReasonText reason))
    (\subject reasons blockers ->
       HumanValidateCollectiveFitUnavailable
         (projectModelIdentity subject)
         (fmap collectiveReasonText reasons)
         (map projectModelIdentity blockers))
    (\subject blockers ->
       HumanValidateCollectiveCoverageUnavailable
         (projectModelIdentity subject)
         (map projectModelIdentity blockers))
    (\subject participant reasons blockers ->
       HumanValidatePrimitiveSupportUnavailable
         (projectModelIdentity subject)
         (projectModelIdentity participant)
         (fmap collectiveReasonText reasons)
         (map projectModelIdentity blockers))

strategyReasonText :: StrategyFormulationUnavailableReason -> Text
strategyReasonText reason =
  case reason of
    StrategyFormulationInputMissing -> "input-missing"
    StrategyFormulationIdentityUnresolved -> "identity-unresolved"

collectiveReasonText :: CollectiveFitUnavailableReason -> Text
collectiveReasonText reason =
  case reason of
    CollectiveFitInputMissing -> "collective-fit-input-missing"
    CollectiveFitIdentityUnresolved -> "collective-fit-identity-unresolved"
    ParticipantStrategyFormulationUnavailable ->
      "participant-strategy-formulation-unavailable"
    ParticipantStrategyFormulationInvalid ->
      "participant-strategy-formulation-invalid"
    TargetStrategyFormulationUnavailable ->
      "target-strategy-formulation-unavailable"
    TargetStrategyFormulationInvalid -> "target-strategy-formulation-invalid"
