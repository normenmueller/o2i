-- | Three-stage O2I validation orchestration and accumulated errors.
module O2I.Validation
  ( Check
  , StructuralError(..)
  , TraceabilityError(..)
  , EvidenceError(..)
  , validateStructure
  , validateTraceability
  , assessEffectEvidence
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Validation (Validation)
import O2I.Evidence
import O2I.Internal.Elaboration
import O2I.Trace

type Check error result = Validation (NonEmpty error) result
