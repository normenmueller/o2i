-- | Closed supplemental-input boundary for semantic capabilities.
--
-- Operation supplies exact bytes and a stable ordinal. Core alone decodes,
-- canonicalizes, validates set uniqueness, and binds every model identity to
-- one opaque structurally valid selected-View graph.
module O2I.Semantics.Input
  ( SupplementalInputOrdinal
  , supplementalInputOrdinal
  , supplementalInputOrdinalValue
  , SupplementalPayloadType(..)
  , SupplementalInput
  , decodeSupplementalInput
  , SupplementalInputSet
  , assessSupplementalInputSet
  , SupplementalBinding
  , BoundSupplementalInputs
  , bindSupplementalInputs
  , supplementalBindingInputs
  , supplementalBindingDefects
  , SupplementalInputDefectKind(..)
  , SupplementalInputEvidence(..)
  , SupplementalInputDefect
  , supplementalInputDefectKind
  , supplementalInputDefectEvidence
  , supplementalInputDefectRule
  ) where

import Numeric.Natural (Natural)
import O2I.Input.Internal.Binding (bindSupplementalInputs)
import O2I.Input.Internal.Decode (decodeSupplementalInput)
import O2I.Input.Internal.Set (assessSupplementalInputSet)
import O2I.Input.Internal.Types

-- | Construct one stable zero-based ordinal assigned by Operation.
supplementalInputOrdinal :: Natural -> SupplementalInputOrdinal
supplementalInputOrdinal = SupplementalInputOrdinal
