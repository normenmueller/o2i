-- | Private representation of cumulative Validate requests.
module O2I.Operation.Validate.Request.Internal
  ( ValidationLevel(..)
  , ValidateRequest(..)
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | Closed last stage requested by one Validate invocation.
data ValidationLevel
  = NotationValidationLevel
  | ProfileValidationLevel
  | StructureValidationLevel
  | SemanticsValidationLevel
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One exact model request whose shape statically limits supplements to
-- Semantics.
data ValidateRequest
  = NotationValidateRequest !InputSource !ViewSelector !(Maybe AdapterId)
  | ProfileValidateRequest !InputSource !ViewSelector !(Maybe AdapterId)
  | StructureValidateRequest !InputSource !ViewSelector !(Maybe AdapterId)
  | SemanticsValidateRequest
      !InputSource
      !ViewSelector
      !(Maybe AdapterId)
      ![InputSource]
  deriving (Show)
