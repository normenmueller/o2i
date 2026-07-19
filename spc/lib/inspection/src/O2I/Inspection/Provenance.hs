-- | Opaque source identities, source-bound locations, and closed-scope
-- provenance.
module O2I.Inspection.Provenance
  ( SourceInputKind(..)
  , SourceHash
  , mkSourceHash
  , sourceHashFromBytes
  , sourceHashText
  , SourceIdentity
  , sourceDisplayLabel
  , sourceInputKind
  , sourceSha256
  , ExpandedQName
  , ExpandedQNameError(..)
  , mkExpandedQName
  , expandedQName
  , qNameNamespace
  , qNameLocalName
  , PathStep
  , mkPathStep
  , firstPathStep
  , pathStepAfter
  , pathStepName
  , pathStepOrdinal
  , LocationTarget(..)
  , SourceSpan
  , mkSourceSpan
  , spanStartLine
  , spanStartColumn
  , spanEndLine
  , spanEndColumn
  , SourceLocator
  , locateSource
  , SourceLocation
  , locationSource
  , locationPath
  , locationTarget
  , locationSpan
  , Located(..)
  , OccurrenceKind
  , OccurrenceKindError(..)
  , mkOccurrenceKind
  , occurrenceKindLiteral
  , occurrenceKindText
  , OccurrenceId
  , occurrenceId
  , occurrenceIdText
  , ReferenceRole(..)
  , ReferenceOccurrence(..)
  , InclusionReason(..)
  , OccurrenceProvenance
  , provenanceOccurrenceId
  , provenanceLocation
  , provenanceReasons
  , ClosedScopeProvenance
  , closedScopeProvenanceOccurrences
  , SupplementalInputKind(..)
  , SupplementalSource
  , supplementalInputKind
  , supplementalSourceIdentity
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Inspection.Provenance.Internal

-- | Read the normalized lowercase hexadecimal digest.
sourceHashText :: SourceHash -> Text
sourceHashText (SourceHash value) = value

-- | Read the human-readable acquisition label.
sourceDisplayLabel :: SourceIdentity -> Text
sourceDisplayLabel (SourceIdentity label _ _) = label

-- | Read how the exact source bytes were acquired.
sourceInputKind :: SourceIdentity -> SourceInputKind
sourceInputKind (SourceIdentity _ kind _) = kind

-- | Read the digest of the complete acquired bytes.
sourceSha256 :: SourceIdentity -> SourceHash
sourceSha256 (SourceIdentity _ _ sourceHash) = sourceHash

-- | Read the optional namespace URI.
qNameNamespace :: ExpandedQName -> Maybe Text
qNameNamespace (ExpandedQName namespace _) = namespace

-- | Read the non-empty local name.
qNameLocalName :: ExpandedQName -> Text
qNameLocalName (ExpandedQName _ localName) = localName

-- | Read the expanded element name.
pathStepName :: PathStep -> ExpandedQName
pathStepName (PathStep name _) = name

-- | Read the one-based sibling ordinal.
pathStepOrdinal :: PathStep -> Natural
pathStepOrdinal (PathStep _ ordinal) = ordinal

-- | Read the one-based start line.
spanStartLine :: SourceSpan -> Natural
spanStartLine (SourceSpan startLine _ _ _) = startLine

-- | Read the one-based start column.
spanStartColumn :: SourceSpan -> Natural
spanStartColumn (SourceSpan _ startColumn _ _) = startColumn

-- | Read the one-based end line.
spanEndLine :: SourceSpan -> Natural
spanEndLine (SourceSpan _ _ endLine _) = endLine

-- | Read the one-based end column.
spanEndColumn :: SourceSpan -> Natural
spanEndColumn (SourceSpan _ _ _ endColumn) = endColumn

-- | Read the exact acquired source.
locationSource :: SourceLocation -> SourceIdentity
locationSource (SourceLocation source _ _ _) = source

-- | Read the non-empty structural source path.
locationPath :: SourceLocation -> NonEmpty PathStep
locationPath (SourceLocation _ path _ _) = path

-- | Read the exact field represented by the location.
locationTarget :: SourceLocation -> LocationTarget
locationTarget (SourceLocation _ _ target _) = target

-- | Read the optional concrete text span.
locationSpan :: SourceLocation -> Maybe SourceSpan
locationSpan (SourceLocation _ _ _ sourceSpan) = sourceSpan

-- | Read the adapter-owned non-empty occurrence kind.
occurrenceKindText :: OccurrenceKind -> Text
occurrenceKindText (OccurrenceKind kind) = kind

-- | Read the canonical length-framed occurrence identity.
occurrenceIdText :: OccurrenceId -> Text
occurrenceIdText (OccurrenceId identifier) = identifier

-- | Read the included occurrence identity.
provenanceOccurrenceId :: OccurrenceProvenance -> OccurrenceId
provenanceOccurrenceId (OccurrenceProvenance identifier _ _) = identifier

-- | Read the occurrence's unique source location.
provenanceLocation :: OccurrenceProvenance -> SourceLocation
provenanceLocation (OccurrenceProvenance _ location _) = location

-- | Read the canonical non-empty reasons for inclusion.
provenanceReasons :: OccurrenceProvenance -> NonEmpty InclusionReason
provenanceReasons (OccurrenceProvenance _ _ reasons) = reasons

-- | Read the canonically ordered complete occurrence audit trail.
closedScopeProvenanceOccurrences ::
     ClosedScopeProvenance -> NonEmpty OccurrenceProvenance
closedScopeProvenanceOccurrences (ClosedScopeProvenance occurrences) =
  occurrences

-- | Read the role of the consumed supplemental source.
supplementalInputKind :: SupplementalSource -> SupplementalInputKind
supplementalInputKind (SupplementalSource kind _) = kind

-- | Read the immutable identity of the consumed supplemental source.
supplementalSourceIdentity :: SupplementalSource -> SourceIdentity
supplementalSourceIdentity (SupplementalSource _ identity) = identity
