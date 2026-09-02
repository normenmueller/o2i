-- | Private representation of closed command-error values.
module O2I.Operation.Command.Error.Internal
  ( ArgumentFailureField(..)
  , ArgumentFailureDefect(..)
  , ArgumentFailure(..)
  , CommandError(..)
  ) where

import Data.Text (Text)
import O2I.Operation.Failure (CommandFailure, PreparationFailure)

-- | Field rejected while authoring one argument failure.
data ArgumentFailureField
  = ArgumentFailureCodeField
  | ArgumentFailureMessageField
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why caller input cannot become an invariant-safe argument failure.
data ArgumentFailureDefect
  = InvalidArgumentFailureCode !Text
  | EmptyArgumentFailureField !ArgumentFailureField
  | ArgumentFailureFieldContainsNul !ArgumentFailureField
  | ArgumentFailureFieldContainsSurrogate !ArgumentFailureField
  deriving (Eq, Ord, Show)

-- | Exact validated CLI-owned argument code and message.
data ArgumentFailure =
  ArgumentFailure !Text !Text
  deriving (Eq, Ord, Show)

-- | Closed pre-report command-error algebra.
data CommandError
  = ArgumentCommandError !ArgumentFailure
  | ProcessCommandError !CommandFailure
  | PreparationCommandError !PreparationFailure
