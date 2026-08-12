-- | Private representation of closed Operation requests.
module O2I.Operation.Request.Internal
  ( CapabilityIdentity(..)
  , CapabilityInputReferences(..)
  , RequestedContract(..)
  ) where

import O2I.Operation.Provenance (SourceReference)
import O2I.Operation.View (ViewSelector)

-- | Closed identity of one executable O2I capability.
data CapabilityIdentity
  = ValidationCapability
  | TraceCapability
  | QualificationCapability
  | ReadinessCapability
  | AssessmentCapability
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact source references owned by one capability request.
--
-- Payload bytes remain opaque here. Their schemas and decoders belong to the
-- corresponding Core capability.
data CapabilityInputReferences
  = ValidationInputReferences ![SourceReference]
  | TraceInputReferences
  | QualificationInputReferences ![SourceReference]
  | ReadinessInputReferences !SourceReference ![SourceReference]
  | AssessmentInputReferences !SourceReference ![SourceReference]
  deriving (Eq, Show)

-- | Closed immutable contract prepared before capability execution.
data RequestedContract
  = ValidationRequest !ViewSelector ![SourceReference]
  | TraceRequest !ViewSelector
  | QualificationRequest !ViewSelector ![SourceReference]
  | ReadinessRequest !ViewSelector !SourceReference ![SourceReference]
  | AssessmentRequest !ViewSelector !SourceReference ![SourceReference]
  deriving (Show)
