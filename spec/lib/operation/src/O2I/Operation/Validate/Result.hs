{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal Validate results.
--
-- Rejection is a completed assessment. Unavailability is reserved for a
-- prepared subject whose supplemental Binding or semantic prerequisites are
-- incomplete. Expected pre-preparation failures and internal owner-contract
-- failures remain disjoint.
module O2I.Operation.Validate.Result
  ( type ValidationDisposition
  , validationAccepted
  , validationRejected
  , validationUnavailable
  , validationDispositionText
  , foldValidationDisposition
  , type ValidateInternalFailure
  , foldValidateInternalFailure
  , type ValidateFailure
  , foldValidateFailure
  , type ValidateUnavailabilityWitness
  , foldValidateUnavailabilityWitness
  , type PreparedValidation
  , preparedValidationLevel
  , preparedValidationDiagnostics
  , foldPreparedValidation
  , type ValidateResult
  , validateResultDisposition
  , foldValidateResult
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Projection (ProfileContractEvidence)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Diagnostic.Owner (AdapterNotationResolutionFailure)
import O2I.Operation.Failure (CommonFailure)
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceOrdinal
  , SupplementalProvenanceDefect
  )
import O2I.Operation.Validate.Request (ValidateRequest, ValidationLevel)
import O2I.Operation.Validate.Result.Internal
import O2I.Operation.View (SelectedView)
import O2I.Semantics
  ( CollectiveFitUnavailableReason
  , StrategyFormulationUnavailableReason
  )
import O2I.Semantics.Input (SupplementalInputDefect)
import O2I.Structure (StructureInputDefect)

-- | The requested level completed positively.
validationAccepted :: ValidationDisposition
validationAccepted = ValidationAccepted

-- | The first failing assessment stage rejected the prepared model.
validationRejected :: ValidationDisposition
validationRejected = ValidationRejected

-- | The prepared subject remained unavailable.
validationUnavailable :: ValidationDisposition
validationUnavailable = ValidationUnavailable

-- | Stable machine token for one terminal disposition.
validationDispositionText :: ValidationDisposition -> Text
validationDispositionText disposition =
  case disposition of
    ValidationAccepted -> "accepted"
    ValidationRejected -> "rejected"
    ValidationUnavailable -> "unavailable"

-- | Consume every closed terminal disposition.
foldValidationDisposition ::
     result -> result -> result -> ValidationDisposition -> result
foldValidationDisposition accepted rejected unavailable disposition =
  case disposition of
    ValidationAccepted -> accepted
    ValidationRejected -> rejected
    ValidationUnavailable -> unavailable

-- | Consume every internal owner-contract failure without erasing evidence.
foldValidateInternalFailure ::
     (SourceIdentity -> result)
  -> (SourceIdentity -> result)
  -> (AdapterDescriptor -> result)
  -> (AdapterNotationResolutionFailure -> result)
  -> (forall profile document. NonEmpty
                                 (ProfileContractEvidence profile document) -> result)
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> ([OccurrenceIdentity] -> result)
  -> ValidateInternalFailure
  -> result
foldValidateInternalFailure modelRole supplementalRole adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    ValidateAcquiredModelRoleFailure value -> modelRole value
    ValidateAcquiredSupplementalRoleFailure value -> supplementalRole value
    ValidateSelectedAdapterContractFailure value -> adapter value
    ValidateNotationContractFailure value -> notation value
    ValidateProfileContractFailure values -> profile values
    ValidateIdentityIndexFailure values -> identity values
    ValidateSelectedViewScopeFailure values -> scope values
    ValidateStructureInputFailure values -> structure values
    ValidateSupplementalProvenanceFailure values -> provenance values
    ValidateSemanticUnavailableContractFailure values -> semantic values

-- | Consume expected common/input failure or internal contract failure.
foldValidateFailure ::
     (CommonFailure -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (ValidateInternalFailure -> result)
  -> ValidateFailure
  -> result
foldValidateFailure common supplemental internal failure =
  case failure of
    ValidateCommonFailure value -> common value
    ValidateSupplementalInputFailure values -> supplemental values
    ValidateOwnerContractFailure value -> internal value

-- | Consume every retained Binding/Core unavailability witness.
foldValidateUnavailabilityWitness ::
     (SourceOrdinal -> result)
  -> (ModelIdentity -> StrategyFormulationUnavailableReason -> result)
  -> (ModelIdentity -> NonEmpty CollectiveFitUnavailableReason -> [ModelIdentity] -> result)
  -> (ModelIdentity -> [ModelIdentity] -> result)
  -> (ModelIdentity -> ModelIdentity -> NonEmpty CollectiveFitUnavailableReason -> [ModelIdentity] -> result)
  -> ValidateUnavailabilityWitness
  -> result
foldValidateUnavailabilityWitness binding strategy fit coverage primitive witness =
  case witness of
    ValidateBindingUnavailable ordinal -> binding ordinal
    ValidateStrategyFormulationUnavailable subject reason ->
      strategy subject reason
    ValidateCollectiveFitUnavailable subject reasons blockers ->
      fit subject reasons blockers
    ValidateCollectiveCoverageUnavailable subject blockers ->
      coverage subject blockers
    ValidatePrimitiveSupportUnavailable claim participant reasons blockers ->
      primitive claim participant reasons blockers

-- | Last cumulative level of one prepared result.
preparedValidationLevel :: PreparedValidation -> ValidationLevel
preparedValidationLevel prepared =
  foldPreparedValidation (\_ completed _ _ _ -> completed) prepared

-- | Authority-once shared diagnostic document.
preparedValidationDiagnostics ::
     PreparedValidation -> PreparedDiagnosticDocument
preparedValidationDiagnostics prepared =
  foldPreparedValidation (\_ _ _ _ diagnostics -> diagnostics) prepared

-- | Eliminate one prepared subject while preserving its selected-View witness.
foldPreparedValidation ::
     (forall document. ValidateRequest -> ValidationLevel -> SelectedView
                                                               document -> [AcquiredSupplementalSource] -> PreparedDiagnosticDocument -> result)
  -> PreparedValidation
  -> result
foldPreparedValidation consume prepared =
  case prepared of
    PreparedValidation request completed view supplements diagnostics ->
      consume request completed view supplements diagnostics

-- | Return the completed terminal classification; failures have none.
validateResultDisposition :: ValidateResult -> Maybe ValidationDisposition
validateResultDisposition =
  foldValidateResult
    (const Nothing)
    (const (Just ValidationAccepted))
    (const (Just ValidationRejected))
    (\_ _ -> Just ValidationUnavailable)

-- | Consume terminal failure or one prepared primary report.
foldValidateResult ::
     (ValidateFailure -> result)
  -> (PreparedValidation -> result)
  -> (PreparedValidation -> result)
  -> (NonEmpty ValidateUnavailabilityWitness -> PreparedValidation -> result)
  -> ValidateResult
  -> result
foldValidateResult failed accepted rejected unavailable result =
  case result of
    ValidateFailed failure -> failed failure
    ValidateAccepted subject -> accepted subject
    ValidateRejected subject -> rejected subject
    ValidateUnavailable witnesses subject -> unavailable witnesses subject
