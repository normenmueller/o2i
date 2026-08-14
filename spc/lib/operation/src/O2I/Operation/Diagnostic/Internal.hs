-- | Private representation of common typed Operation diagnostics.
module O2I.Operation.Diagnostic.Internal
  ( DiagnosticCode(..)
  , DiagnosticSeverity(..)
  , DiagnosticDisposition(..)
  , DiagnosticProvenance(..)
  , DiagnosticOccurrence(..)
  , Diagnostic(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftLocation)
import O2I.ArchiMate.Profile.Notation (CanonicalOccurrence)
import O2I.ArchiMate.Profile.Rule.Explanation (ProfileRuleExplanation)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Core.Rule.Catalog (CoreRule)
import O2I.Operation.Adapter (AdapterOccurrence)
import O2I.Operation.Diagnostic.AdapterOwner.Internal (AdapterRuleWitness)
import O2I.Operation.Provenance (SourceIdentity)
import O2I.Operation.Rule.Catalog (OperationRule)

-- | Stable code derived exclusively from the owning compiled rule identity.
newtype DiagnosticCode =
  DiagnosticCode Text
  deriving (Eq, Ord, Show)

-- | Closed impact level of one emitted diagnostic.
data DiagnosticSeverity
  = DebugSeverity
  | InfoSeverity
  | WarningSeverity
  | ErrorSeverity
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed interpretation of one diagnostic at the command boundary.
data DiagnosticDisposition
  = ModelFinding
  | ProcessFailure
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed typed provenance of one diagnostic rule.
data DiagnosticProvenance
  = OperationDiagnosticProvenance !OperationRule
  | AdapterDiagnosticProvenance !AdapterRuleWitness
  | ProfileDiagnosticProvenance !ProfileRuleExplanation
  | CoreDiagnosticProvenance !CoreRule
  deriving (Eq, Ord, Show)

-- | Closed typed location or subject occurrence retained by Operation.
data DiagnosticOccurrence
  = SourceDiagnosticOccurrence !SourceIdentity
  | AdapterDiagnosticOccurrence !SourceIdentity !AdapterOccurrence
  | DraftDiagnosticOccurrence !SourceIdentity !DraftLocation
  | CanonicalDiagnosticOccurrence !SourceIdentity !CanonicalOccurrence
  | SubjectDiagnosticOccurrence !SourceIdentity !ModelIdentity
  | CoreDiagnosticOccurrence !SourceIdentity !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | One rule-owned diagnostic with a non-empty exact occurrence set.
data Diagnostic =
  Diagnostic
    !DiagnosticSeverity
    !DiagnosticDisposition
    !DiagnosticProvenance
    !(NonEmpty DiagnosticOccurrence)
  deriving (Eq, Ord, Show)
