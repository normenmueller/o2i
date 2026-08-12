-- | Internal constructors for immutable Operation source provenance.
module O2I.Operation.Provenance.Internal
  ( SourceRole(..)
  , SourceOrdinal(..)
  , SourceReference(..)
  , SourceReferenceError(..)
  , mkSourceReference
  , SourceSha256(..)
  , sourceSha256FromBytes
  , SourceIdentity(..)
  , sourceIdentityFromBytes
  , SupplementalProvenance(..)
  , SupplementalProvenanceDefect(..)
  , mkSupplementalProvenance
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.List (sort, sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric (showHex)
import Numeric.Natural (Natural)

-- | Closed role of one Operation input source.
data SourceRole
  = ModelRole
  | SupplementalRole
  | ReadinessRole
  | AssessmentRole
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Stable zero-based ordinal assigned at the Operation boundary.
newtype SourceOrdinal = SourceOrdinal
  { sourceOrdinalNatural :: Natural
  } deriving (Eq, Ord, Show)

-- | Stable caller-owned reference to one input source.
newtype SourceReference = SourceReference
  { sourceReferenceValue :: Text
  } deriving (Eq, Ord, Show)

-- | Why a source reference cannot identify an input.
data SourceReferenceError
  = EmptySourceReference
  | SourceReferenceContainsNul
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Validate a non-empty, NUL-free source reference.
mkSourceReference :: Text -> Either SourceReferenceError SourceReference
mkSourceReference value
  | Text.null value = Left EmptySourceReference
  | Text.any (== '\NUL') value = Left SourceReferenceContainsNul
  | otherwise = Right (SourceReference value)

-- | Lowercase hexadecimal SHA-256 of exact acquired bytes.
newtype SourceSha256 = SourceSha256
  { sourceSha256Value :: Text
  } deriving (Eq, Ord, Show)

-- | Hash exact source bytes into their immutable digest.
sourceSha256FromBytes :: ByteString -> SourceSha256
sourceSha256FromBytes = SourceSha256 . sha256Hex

-- | Immutable identity of one complete acquired source.
data SourceIdentity = SourceIdentity
  { identityRole :: !SourceRole
  , identityOrdinal :: !SourceOrdinal
  , identityReference :: !SourceReference
  , identitySha256 :: !SourceSha256
  } deriving (Eq, Ord, Show)

-- | Bind exact bytes to their Operation-assigned identity.
sourceIdentityFromBytes ::
     SourceRole
  -> SourceOrdinal
  -> SourceReference
  -> ByteString
  -> SourceIdentity
sourceIdentityFromBytes role ordinal reference bytes =
  SourceIdentity
    { identityRole = role
    , identityOrdinal = ordinal
    , identityReference = reference
    , identitySha256 = sourceSha256FromBytes bytes
    }

-- | Canonically ordered identities of consumed non-model sources.
newtype SupplementalProvenance = SupplementalProvenance
  { supplementalProvenanceIdentities :: [SourceIdentity]
  } deriving (Eq, Show)

-- | Why supplemental provenance cannot be constructed.
data SupplementalProvenanceDefect
  = ModelIdentityIsNotSupplemental !SourceIdentity
  | DuplicateSupplementalOrdinal !SourceOrdinal !(NonEmpty SourceIdentity)
  deriving (Eq, Show)

-- | Validate and canonicalize consumed supplemental source identities.
--
-- Ordinals are unique across one Operation request and therefore define the
-- canonical order independently of caller collection order.
mkSupplementalProvenance ::
     [SourceIdentity]
  -> Either (NonEmpty SupplementalProvenanceDefect) SupplementalProvenance
mkSupplementalProvenance identities =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right (SupplementalProvenance (sortOn identityOrdinal identities))
  where
    defects = modelDefects ++ ordinalDefects
    modelDefects =
      map
        ModelIdentityIsNotSupplemental
        (filter ((== ModelRole) . identityRole) (sort identities))
    ordinalDefects =
      [ DuplicateSupplementalOrdinal ordinal (first :| second : rest)
      | (ordinal, grouped) <- Map.toAscList identitiesByOrdinal
      , first:second:rest <- [sort grouped]
      ]
    identitiesByOrdinal =
      Map.fromListWith
        (++)
        [(identityOrdinal identity, [identity]) | identity <- identities]

sha256Hex :: ByteString -> Text
sha256Hex =
  TextEncoding.decodeUtf8
    . ByteString.pack
    . concatMap hexByte
    . ByteString.unpack
    . SHA256.hash
  where
    hexByte byte =
      case showHex byte "" of
        [digit] -> map (fromIntegral . fromEnum) ['0', digit]
        digits -> map (fromIntegral . fromEnum) digits
