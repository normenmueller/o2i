-- | Immutable identities and deterministic provenance for Operation inputs.
module O2I.Operation.Provenance
  ( SourceRole(..)
  , SourceOrdinal
  , sourceOrdinal
  , sourceOrdinalValue
  , SourceKey
  , sourceKey
  , sourceKeyRole
  , sourceKeyOrdinal
  , foldSourceKey
  , SourceReference
  , SourceReferenceError(..)
  , mkSourceReference
  , sourceReferenceText
  , SourceSha256
  , sourceSha256Text
  , SourceIdentity
  , sourceIdentityKey
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

-- | Bind one role to one role-local ordinal.
sourceKey :: SourceRole -> SourceOrdinal -> SourceKey
sourceKey = SourceKey

-- | Project the role of an exact source key.
sourceKeyRole :: SourceKey -> SourceRole
sourceKeyRole (SourceKey role _) = role

-- | Project the role-local ordinal of an exact source key.
sourceKeyOrdinal :: SourceKey -> SourceOrdinal
sourceKeyOrdinal (SourceKey _ ordinal) = ordinal

-- | Consume both fields of one exact source key.
foldSourceKey :: (SourceRole -> SourceOrdinal -> value) -> SourceKey -> value
foldSourceKey consume (SourceKey role ordinal) = consume role ordinal

-- | Project the stable source reference.
sourceReferenceText :: SourceReference -> Text
sourceReferenceText (SourceReference value) = value

-- | Project the lowercase hexadecimal SHA-256 digest.
sourceSha256Text :: SourceSha256 -> Text
sourceSha256Text (SourceSha256 value) = value

-- | Project the exact role-local source key.
sourceIdentityKey :: SourceIdentity -> SourceKey
sourceIdentityKey (SourceIdentity key _ _) = key

-- | Project the source role.
sourceIdentityRole :: SourceIdentity -> SourceRole
sourceIdentityRole (SourceIdentity (SourceKey role _) _ _) = role

-- | Project the Operation-assigned ordinal.
sourceIdentityOrdinal :: SourceIdentity -> SourceOrdinal
sourceIdentityOrdinal (SourceIdentity (SourceKey _ ordinal) _ _) = ordinal

-- | Project the caller-owned source reference.
sourceIdentityReference :: SourceIdentity -> SourceReference
sourceIdentityReference (SourceIdentity _ reference _) = reference

-- | Project the digest of the exact acquired bytes.
sourceIdentitySha256 :: SourceIdentity -> SourceSha256
sourceIdentitySha256 (SourceIdentity _ _ digest) = digest

-- | Eliminate an opaque source identity without exposing its constructor.
foldSourceIdentity ::
     (SourceRole -> SourceOrdinal -> SourceReference -> SourceSha256 -> value)
  -> SourceIdentity
  -> value
foldSourceIdentity project (SourceIdentity (SourceKey role ordinal) reference digest) =
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
  -> (SourceKey -> NonEmpty SourceIdentity -> value)
  -> SupplementalProvenanceDefect
  -> value
foldSupplementalProvenanceDefect onModel onDuplicate defect =
  case defect of
    ModelIdentityIsNotSupplemental identity -> onModel identity
    DuplicateSupplementalSource key identities -> onDuplicate key identities
