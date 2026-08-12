-- | Immutable identities and deterministic provenance for Operation inputs.
module O2I.Operation.Provenance
  ( SourceRole(..)
  , SourceOrdinal
  , sourceOrdinal
  , sourceOrdinalValue
  , SourceReference
  , SourceReferenceError(..)
  , mkSourceReference
  , sourceReferenceText
  , SourceSha256
  , sourceSha256Text
  , SourceIdentity
  , sourceIdentityRole
  , sourceIdentityOrdinal
  , sourceIdentityReference
  , sourceIdentitySha256
  , foldSourceIdentity
  , SupplementalProvenance
  , mkSupplementalProvenance
  , supplementalProvenanceSources
  , foldSupplementalProvenance
  , SupplementalProvenanceDefect
  , foldSupplementalProvenanceDefect
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Provenance.Internal

-- | Assign a stable zero-based ordinal.
sourceOrdinal :: Natural -> SourceOrdinal
sourceOrdinal = SourceOrdinal

-- | Project the zero-based ordinal.
sourceOrdinalValue :: SourceOrdinal -> Natural
sourceOrdinalValue (SourceOrdinal value) = value

-- | Project the stable source reference.
sourceReferenceText :: SourceReference -> Text
sourceReferenceText (SourceReference value) = value

-- | Project the lowercase hexadecimal SHA-256 digest.
sourceSha256Text :: SourceSha256 -> Text
sourceSha256Text (SourceSha256 value) = value

-- | Project the source role.
sourceIdentityRole :: SourceIdentity -> SourceRole
sourceIdentityRole (SourceIdentity role _ _ _) = role

-- | Project the Operation-assigned ordinal.
sourceIdentityOrdinal :: SourceIdentity -> SourceOrdinal
sourceIdentityOrdinal (SourceIdentity _ ordinal _ _) = ordinal

-- | Project the caller-owned source reference.
sourceIdentityReference :: SourceIdentity -> SourceReference
sourceIdentityReference (SourceIdentity _ _ reference _) = reference

-- | Project the digest of the exact acquired bytes.
sourceIdentitySha256 :: SourceIdentity -> SourceSha256
sourceIdentitySha256 (SourceIdentity _ _ _ digest) = digest

-- | Eliminate an opaque source identity without exposing its constructor.
foldSourceIdentity ::
     (SourceRole -> SourceOrdinal -> SourceReference -> SourceSha256 -> value)
  -> SourceIdentity
  -> value
foldSourceIdentity project (SourceIdentity role ordinal reference digest) =
  project role ordinal reference digest

-- | Project canonically ordered consumed supplemental sources.
supplementalProvenanceSources :: SupplementalProvenance -> [SourceIdentity]
supplementalProvenanceSources (SupplementalProvenance identities) = identities

-- | Eliminate opaque supplemental provenance.
foldSupplementalProvenance ::
     ([SourceIdentity] -> value) -> SupplementalProvenance -> value
foldSupplementalProvenance project (SupplementalProvenance identities) =
  project identities

-- | Eliminate every closed supplemental-provenance defect.
foldSupplementalProvenanceDefect ::
     (SourceIdentity -> value)
  -> (SourceOrdinal -> NonEmpty SourceIdentity -> value)
  -> SupplementalProvenanceDefect
  -> value
foldSupplementalProvenanceDefect onModel onDuplicate defect =
  case defect of
    ModelIdentityIsNotSupplemental identity -> onModel identity
    DuplicateSupplementalOrdinal ordinal identities ->
      onDuplicate ordinal identities
