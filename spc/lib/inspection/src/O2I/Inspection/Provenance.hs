-- | Stable source identities and occurrence-level provenance.
module O2I.Inspection.Provenance
  ( SourceInputKind(..)
  , SourceHash
  , mkSourceHash
  , sourceHashFromBytes
  , sourceHashText
  , SourceIdentity(..)
  , ExpandedQName(..)
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
  , SourceLocation(..)
  , Located(..)
  , OccurrenceId(..)
  , ReferenceRole(..)
  , ReferenceOccurrence(..)
  , InclusionReason(..)
  , OccurrenceProvenance(..)
  , Provenance
  , mkProvenance
  , provenanceOccurrences
  , SupplementalInputKind(..)
  , SupplementalSource(..)
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric (showHex)
import Numeric.Natural (Natural)

-- | How the inspected bytes entered the application.
data SourceInputKind
  = FileSource
  | StandardInputSource
  deriving (Eq, Ord, Show)

-- | Lowercase hexadecimal SHA-256 of the exact acquired bytes.
newtype SourceHash = SourceHash
  { sourceHashText :: Text -- ^ Read the normalized digest.
  } deriving (Eq, Ord, Show)

-- | Validate a lowercase hexadecimal SHA-256 digest.
mkSourceHash :: Text -> Maybe SourceHash
mkSourceHash value
  | Text.length value == 64 && Text.all isLowerHexDigit value =
    Just (SourceHash value)
  | otherwise = Nothing

-- | Hash exact source bytes into a valid source identity component.
sourceHashFromBytes :: ByteString -> SourceHash
sourceHashFromBytes = SourceHash . sha256Hex

-- | Immutable identity of one complete model input.
data SourceIdentity = SourceIdentity
  { sourceDisplayLabel :: Text
  , sourceInputKind :: SourceInputKind
  , sourceSha256 :: SourceHash
  } deriving (Eq, Ord, Show)

-- | Namespace-independent XML name.
data ExpandedQName = ExpandedQName
  { qNameNamespace :: Maybe Text
  , qNameLocalName :: Text
  } deriving (Eq, Ord, Show)

-- | One expanded-QName path segment and its one-based sibling ordinal.
data PathStep = PathStep
  { pathStepName :: ExpandedQName -- ^ Read the expanded element name.
  , pathStepOrdinal :: Natural -- ^ Read the one-based sibling ordinal.
  } deriving (Eq, Ord, Show)

-- | Construct a path segment only with a one-based sibling ordinal.
mkPathStep :: ExpandedQName -> Natural -> Maybe PathStep
mkPathStep name ordinal
  | ordinal == 0 = Nothing
  | otherwise = Just PathStep {pathStepName = name, pathStepOrdinal = ordinal}

-- | Construct the first sibling occurrence of an expanded QName.
firstPathStep :: ExpandedQName -> PathStep
firstPathStep name = PathStep {pathStepName = name, pathStepOrdinal = 1}

-- | Construct the occurrence after a known count of preceding siblings.
pathStepAfter :: ExpandedQName -> Natural -> PathStep
pathStepAfter name preceding =
  PathStep {pathStepName = name, pathStepOrdinal = preceding + 1}

-- | Exact field represented by a source location.
data LocationTarget
  = ElementTarget
  | AttributeTarget ExpandedQName
  | PropertyTarget Text
  | TextFieldTarget ExpandedQName
  deriving (Eq, Ord, Show)

-- | Optional one-based source span.
data SourceSpan = SourceSpan
  { spanStartLine :: Natural -- ^ Read the one-based start line.
  , spanStartColumn :: Natural -- ^ Read the one-based start column.
  , spanEndLine :: Natural -- ^ Read the one-based end line.
  , spanEndColumn :: Natural -- ^ Read the one-based end column.
  } deriving (Eq, Ord, Show)

-- | Construct a one-based, non-inverted source span.
mkSourceSpan :: Natural -> Natural -> Natural -> Natural -> Maybe SourceSpan
mkSourceSpan startLine startColumn endLine endColumn
  | any (== 0) [startLine, startColumn, endLine, endColumn] = Nothing
  | (endLine, endColumn) < (startLine, startColumn) = Nothing
  | otherwise =
    Just
      SourceSpan
        { spanStartLine = startLine
        , spanStartColumn = startColumn
        , spanEndLine = endLine
        , spanEndColumn = endColumn
        }

-- | Stable occurrence location independent of namespace prefixes.
data SourceLocation = SourceLocation
  { locationSource :: SourceIdentity
  , locationPath :: NonEmpty PathStep
  , locationTarget :: LocationTarget
  , locationSpan :: Maybe SourceSpan
  } deriving (Eq, Ord, Show)

-- | A value tied to one exact source occurrence.
data Located a = Located
  { locatedAt :: SourceLocation
  , locatedValue :: a
  } deriving (Eq, Ord, Show)

-- | Adapter-stable identity of one persisted or presented occurrence.
newtype OccurrenceId = OccurrenceId
  { occurrenceIdText :: Text
  } deriving (Eq, Ord, Show)

-- | Semantic use of a persisted reference during closure.
data ReferenceRole
  = RelationSourceReference
  | RelationTargetReference
  | OwnershipSourceReference
  | OwnershipTargetReference
  | PresentationTargetReference
  | ConnectionRelationshipReference
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One reached reference whose cardinality Inspection must decide.
data ReferenceOccurrence = ReferenceOccurrence
  { referenceOccurrenceId :: OccurrenceId
  , referenceFromOccurrence :: OccurrenceId
  , referenceRole :: ReferenceRole
  , referenceToken :: Maybe Text
  , referenceLocation :: SourceLocation
  } deriving (Eq, Ord, Show)

-- | Why closure includes an occurrence.
data InclusionReason
  = DirectPresentation
  | RelationshipEndpoint
  | ContextOwnership
  | PerformanceDimensionMembership
  | SituationDependency
  | NeedDependency
  | MacroPremise
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Provenance retained for one included source occurrence.
data OccurrenceProvenance = OccurrenceProvenance
  { provenanceOccurrenceId :: OccurrenceId
  , provenanceLocation :: SourceLocation
  , provenanceReasons :: [InclusionReason]
  } deriving (Eq, Show)

-- | Complete ordered provenance of an imported graph.
newtype Provenance =
  Provenance [OccurrenceProvenance]
  deriving (Eq, Show)

-- | Construct ordered provenance for an opaque imported graph.
mkProvenance :: [OccurrenceProvenance] -> Provenance
mkProvenance = Provenance

-- | Read all retained occurrences in deterministic source order.
provenanceOccurrences :: Provenance -> [OccurrenceProvenance]
provenanceOccurrences (Provenance occurrences) = occurrences

-- | Supplemental input whose source participated in a validation stage.
data SupplementalInputKind
  = StrategySupplement
  | ReadinessSupplement
  | EvidenceSupplement
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Identity and role of one supplemental source actually consumed.
data SupplementalSource = SupplementalSource
  { supplementalInputKind :: SupplementalInputKind
  , supplementalSourceIdentity :: SourceIdentity
  } deriving (Eq, Ord, Show)

isLowerHexDigit :: Char -> Bool
isLowerHexDigit character =
  character >= '0' && character <= '9' || character >= 'a' && character <= 'f'

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
