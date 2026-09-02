-- | Private representation of closed command-error values.
module O2I.Operation.Command.Error.Internal
  ( ArgumentFailureField(..)
  , ArgumentFailureDefect(..)
  , ArgumentFailure(..)
  , CommandDiagnosticValue(..)
  , CommandDiagnosticField(..)
  , CommandInputDiagnostic(..)
  , CommandOwnerEvidence(..)
  , CommandOwnerDiagnostic(..)
  , CommandError(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Assess.Result (AssessFailure)
import O2I.Operation.Command.Error.Branch.Generated (CommandOwnerBranch)
import O2I.Operation.Failure (CommandFailure, PreparationFailure)
import O2I.Operation.Qualify.Result (QualifyFailure)
import O2I.Operation.Readiness.Result (ReadinessFailure)
import O2I.Operation.Validate.Result (ValidateFailure)

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

-- | One purpose-built scalar or immutable identity retained by a command
-- diagnostic. Constructors stay private so only Operation can associate a
-- value kind with producer-owned evidence.
data CommandDiagnosticValue
  = CommandDiagnosticText !Text
  | CommandDiagnosticNatural !Natural
  | CommandDiagnosticModelIdentity !Text
  | CommandDiagnosticOccurrenceIdentity !Text
  | CommandDiagnosticQualifiedType !Text
  | CommandDiagnosticSourceKey !Text !Natural
  | CommandDiagnosticSourceIdentity !Text !Natural !Text !Text
  | CommandDiagnosticAdapterDescriptor !Text !Text !Text !Text
  | CommandDiagnosticCanonicalOccurrence !Text !Natural
  | CommandDiagnosticUnicodeScalar !Natural !Natural
  deriving (Eq, Ord, Show)

-- | One closed producer-selected detail name and its ordered exact values.
data CommandDiagnosticField =
  CommandDiagnosticField !Text ![CommandDiagnosticValue]
  deriving (Eq, Ord, Show)

-- | One complete capability-input diagnostic.
data CommandInputDiagnostic =
  CommandInputDiagnostic
    !Text
    !(NonEmpty Natural)
    !Text
    ![CommandDiagnosticField]
  deriving (Eq, Ord, Show)

-- | One retained occurrence of owner-contract evidence.
data CommandOwnerEvidence =
  CommandOwnerEvidence !Text ![CommandDiagnosticField]
  deriving (Eq, Ord, Show)

-- | One exact owner-contract branch and all retained evidence occurrences.
data CommandOwnerDiagnostic =
  CommandOwnerDiagnostic !CommandOwnerBranch !(NonEmpty CommandOwnerEvidence)
  deriving (Eq, Ord, Show)

-- | Closed pre-report command-error algebra.
data CommandError
  = ArgumentCommandError !ArgumentFailure
  | ProcessCommandError !CommandFailure
  | PreparationCommandError !PreparationFailure
  | ValidateCommandError !ValidateFailure
  | QualifyCommandError !QualifyFailure
  | ReadinessCommandError !ReadinessFailure
  | AssessCommandError !AssessFailure
