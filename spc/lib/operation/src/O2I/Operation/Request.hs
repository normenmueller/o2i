{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed capability requests without capability-payload interpretation.
--
-- Each constructor binds one capability to its own exact source references.
-- Operation retains their identity and order; Core remains the sole owner of
-- payload schemas, decoding, binding, and semantic evaluation.
module O2I.Operation.Request
  ( type CapabilityIdentity
  , validationCapability
  , traceCapability
  , qualificationCapability
  , readinessCapability
  , assessmentCapability
  , capabilityIdentityText
  , foldCapabilityIdentity
  , type CapabilityInputReferences
  , capabilityInputReferences
  , foldCapabilityInputReferences
  , type RequestedContract
  , validationRequest
  , traceRequest
  , qualificationRequest
  , readinessRequest
  , assessmentRequest
  , requestedCapability
  , requestedViewSelector
  , requestedInputs
  , foldRequestedContract
  ) where

import Data.Text (Text)
import O2I.Operation.Provenance (SourceReference)
import O2I.Operation.Request.Internal
import O2I.Operation.View (ViewSelector)

validationCapability :: CapabilityIdentity
validationCapability = ValidationCapability

traceCapability :: CapabilityIdentity
traceCapability = TraceCapability

qualificationCapability :: CapabilityIdentity
qualificationCapability = QualificationCapability

readinessCapability :: CapabilityIdentity
readinessCapability = ReadinessCapability

assessmentCapability :: CapabilityIdentity
assessmentCapability = AssessmentCapability

-- | Stable machine identity of one capability.
capabilityIdentityText :: CapabilityIdentity -> Text
capabilityIdentityText capability =
  case capability of
    ValidationCapability -> "validate"
    TraceCapability -> "trace"
    QualificationCapability -> "qualify"
    ReadinessCapability -> "readiness"
    AssessmentCapability -> "assess"

-- | Consume every closed capability identity.
foldCapabilityIdentity ::
     result
  -> result
  -> result
  -> result
  -> result
  -> CapabilityIdentity
  -> result
foldCapabilityIdentity validate trace qualify readiness assess capability =
  case capability of
    ValidationCapability -> validate
    TraceCapability -> trace
    QualificationCapability -> qualify
    ReadinessCapability -> readiness
    AssessmentCapability -> assess

-- | Project exact capability-owned references in caller order.
capabilityInputReferences :: CapabilityInputReferences -> [SourceReference]
capabilityInputReferences references =
  case references of
    ValidationInputReferences values -> values
    TraceInputReferences -> []
    QualificationInputReferences values -> values
    ReadinessInputReferences primary values -> primary : values
    AssessmentInputReferences primary values -> primary : values

-- | Consume every capability-specific input-reference case.
foldCapabilityInputReferences ::
     ([SourceReference] -> result)
  -> result
  -> ([SourceReference] -> result)
  -> (SourceReference -> [SourceReference] -> result)
  -> (SourceReference -> [SourceReference] -> result)
  -> CapabilityInputReferences
  -> result
foldCapabilityInputReferences validate trace qualify readiness assess references =
  case references of
    ValidationInputReferences values -> validate values
    TraceInputReferences -> trace
    QualificationInputReferences values -> qualify values
    ReadinessInputReferences primary values -> readiness primary values
    AssessmentInputReferences primary values -> assess primary values

validationRequest :: ViewSelector -> [SourceReference] -> RequestedContract
validationRequest = ValidationRequest

traceRequest :: ViewSelector -> RequestedContract
traceRequest = TraceRequest

qualificationRequest :: ViewSelector -> [SourceReference] -> RequestedContract
qualificationRequest = QualificationRequest

readinessRequest ::
     ViewSelector -> SourceReference -> [SourceReference] -> RequestedContract
readinessRequest = ReadinessRequest

assessmentRequest ::
     ViewSelector -> SourceReference -> [SourceReference] -> RequestedContract
assessmentRequest = AssessmentRequest

-- | Capability selected by the immutable request.
requestedCapability :: RequestedContract -> CapabilityIdentity
requestedCapability request =
  case request of
    ValidationRequest _ _ -> ValidationCapability
    TraceRequest _ -> TraceCapability
    QualificationRequest _ _ -> QualificationCapability
    ReadinessRequest _ _ _ -> ReadinessCapability
    AssessmentRequest _ _ _ -> AssessmentCapability

-- | Exact mandatory View selector retained without normalization.
requestedViewSelector :: RequestedContract -> ViewSelector
requestedViewSelector request =
  case request of
    ValidationRequest selector _ -> selector
    TraceRequest selector -> selector
    QualificationRequest selector _ -> selector
    ReadinessRequest selector _ _ -> selector
    AssessmentRequest selector _ _ -> selector

-- | Capability-owned source references retained without payload parsing.
requestedInputs :: RequestedContract -> CapabilityInputReferences
requestedInputs request =
  case request of
    ValidationRequest _ references -> ValidationInputReferences references
    TraceRequest _ -> TraceInputReferences
    QualificationRequest _ references -> QualificationInputReferences references
    ReadinessRequest _ primary references ->
      ReadinessInputReferences primary references
    AssessmentRequest _ primary references ->
      AssessmentInputReferences primary references

-- | Consume every capability-specific immutable request shape.
foldRequestedContract ::
     (ViewSelector -> [SourceReference] -> result)
  -> (ViewSelector -> result)
  -> (ViewSelector -> [SourceReference] -> result)
  -> (ViewSelector -> SourceReference -> [SourceReference] -> result)
  -> (ViewSelector -> SourceReference -> [SourceReference] -> result)
  -> RequestedContract
  -> result
foldRequestedContract validate trace qualify readiness assess request =
  case request of
    ValidationRequest selector references -> validate selector references
    TraceRequest selector -> trace selector
    QualificationRequest selector references -> qualify selector references
    ReadinessRequest selector primary references ->
      readiness selector primary references
    AssessmentRequest selector primary references ->
      assess selector primary references
