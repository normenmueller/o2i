{-# LANGUAGE OverloadedStrings #-}

-- | Internal constructors for source-bound provenance artifacts.
module O2I.Inspection.Provenance.Internal
  ( SourceInputKind(..)
  , SourceHash(..)
  , mkSourceHash
  , sourceHashFromBytes
  , SourceIdentity(..)
  , ExpandedQName(..)
  , ExpandedQNameError(..)
  , mkExpandedQName
  , expandedQName
  , PathStep(..)
  , mkPathStep
  , firstPathStep
  , pathStepAfter
  , LocationTarget(..)
  , SourceSpan(..)
  , mkSourceSpan
  , SourcePosition(..)
  , sourcePosition
  , SourceLocation(..)
  , bindSourcePosition
  , Located(..)
  , OccurrenceKind(..)
  , OccurrenceKindError(..)
  , mkOccurrenceKind
  , occurrenceKindLiteral
  , OccurrenceId(..)
  , occurrenceId
  , ReferenceRole(..)
  , ReferenceOccurrence(..)
  , InclusionReason(..)
  , OccurrenceProvenance(..)
  , ClosedScopeProvenance(..)
  , mkClosedScopeProvenance
  , SupplementalInputKind(..)
  , SupplementalSource(..)
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
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
  { sourceHashValue :: Text
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

-- | Immutable identity of one complete acquired input.
data SourceIdentity = SourceIdentity
  { identityDisplayLabel :: Text -- ^ Human-readable acquisition label.
  , identityInputKind :: SourceInputKind -- ^ How exact bytes were acquired.
  , identitySha256 :: SourceHash -- ^ Digest of the complete acquired bytes.
  } deriving (Eq, Ord, Show)

-- | Namespace-independent XML name.
data ExpandedQName = ExpandedQName
  { expandedQNameNamespaceValue :: Maybe Text
  , expandedQNameLocalNameValue :: Text
  } deriving (Eq, Ord, Show)

-- | Why an expanded QName cannot be represented in a report.
data ExpandedQNameError =
  EmptyQNameLocalName
  deriving (Eq, Ord, Show)

-- | Validate the non-empty local name required by report locations.
mkExpandedQName :: Maybe Text -> Text -> Either ExpandedQNameError ExpandedQName
mkExpandedQName namespace localName
  | Text.null localName = Left EmptyQNameLocalName
  | otherwise = Right (ExpandedQName namespace localName)

-- | Construct an expanded QName from a statically non-empty local name.
expandedQName :: Maybe Text -> Char -> Text -> ExpandedQName
expandedQName namespace first rest =
  ExpandedQName namespace (Text.cons first rest)

-- | One expanded-QName path segment and its one-based sibling ordinal.
data PathStep = PathStep
  { stepName :: ExpandedQName
  , stepOrdinal :: Natural
  } deriving (Eq, Ord, Show)

-- | Construct a path segment only with a one-based sibling ordinal.
mkPathStep :: ExpandedQName -> Natural -> Maybe PathStep
mkPathStep name ordinal
  | ordinal == 0 = Nothing
  | otherwise = Just PathStep {stepName = name, stepOrdinal = ordinal}

-- | Construct the first sibling occurrence of an expanded QName.
firstPathStep :: ExpandedQName -> PathStep
firstPathStep name = PathStep {stepName = name, stepOrdinal = 1}

-- | Construct the occurrence after a known count of preceding siblings.
pathStepAfter :: ExpandedQName -> Natural -> PathStep
pathStepAfter name preceding =
  PathStep {stepName = name, stepOrdinal = preceding + 1}

-- | Exact field represented by a source location.
data LocationTarget
  = ElementTarget
  | AttributeTarget ExpandedQName
  | PropertyTarget Text
  | TextFieldTarget ExpandedQName
  deriving (Eq, Ord, Show)

-- | Optional one-based source span.
data SourceSpan = SourceSpan
  { spanStartLineValue :: Natural
  , spanStartColumnValue :: Natural
  , spanEndLineValue :: Natural
  , spanEndColumnValue :: Natural
  } deriving (Eq, Ord, Show)

-- | Construct a one-based, non-inverted source span.
mkSourceSpan :: Natural -> Natural -> Natural -> Natural -> Maybe SourceSpan
mkSourceSpan startLine startColumn endLine endColumn
  | any (== 0) [startLine, startColumn, endLine, endColumn] = Nothing
  | (endLine, endColumn) < (startLine, startColumn) = Nothing
  | otherwise =
    Just
      SourceSpan
        { spanStartLineValue = startLine
        , spanStartColumnValue = startColumn
        , spanEndLineValue = endLine
        , spanEndColumnValue = endColumn
        }

-- | Source-relative position produced by a concrete-format adapter.
data SourcePosition = SourcePosition
  { positionStructuralPath :: NonEmpty PathStep
  , positionFieldTarget :: LocationTarget
  , positionSourceSpan :: Maybe SourceSpan
  } deriving (Eq, Ord, Show)

-- | Stable occurrence location independent of namespace prefixes.
data SourceLocation = SourceLocation
  { locationSourceIdentity :: SourceIdentity -- ^ Exact acquired source.
  , locationStructuralPath :: NonEmpty PathStep -- ^ Non-empty source path.
  , locationFieldTarget :: LocationTarget -- ^ Exact field represented.
  , locationSourceSpan :: Maybe SourceSpan -- ^ Optional concrete text span.
  } deriving (Eq, Ord, Show)

-- | Bind a source-relative position to the current Inspection request.
bindSourcePosition :: SourceIdentity -> SourcePosition -> SourceLocation
bindSourcePosition source (SourcePosition path target sourceSpan) =
  SourceLocation
    { locationSourceIdentity = source
    , locationStructuralPath = path
    , locationFieldTarget = target
    , locationSourceSpan = sourceSpan
    }

-- | Construct one source-relative position without binding a source identity.
sourcePosition ::
     NonEmpty PathStep -> LocationTarget -> Maybe SourceSpan -> SourcePosition
sourcePosition path target sourceSpan =
  SourcePosition
    { positionStructuralPath = path
    , positionFieldTarget = target
    , positionSourceSpan = sourceSpan
    }

-- | A value tied to one exact source occurrence.
data Located location a = Located
  { locatedAt :: location
  , locatedValue :: a
  } deriving (Eq, Ord, Show)

-- | Adapter-defined class of persisted or presented source occurrence.
newtype OccurrenceKind = OccurrenceKind
  { occurrenceKindValue :: Text
  } deriving (Eq, Ord, Show)

-- | Why an occurrence kind cannot identify an occurrence.
data OccurrenceKindError =
  EmptyOccurrenceKind
  deriving (Eq, Ord, Show)

-- | Validate the non-empty occurrence kind owned by an adapter.
mkOccurrenceKind :: Text -> Either OccurrenceKindError OccurrenceKind
mkOccurrenceKind value
  | Text.null value = Left EmptyOccurrenceKind
  | otherwise = Right (OccurrenceKind value)

-- | Construct an occurrence kind from a statically non-empty value.
occurrenceKindLiteral :: NonEmpty Char -> OccurrenceKind
occurrenceKindLiteral = OccurrenceKind . Text.pack . NonEmpty.toList

-- | Opaque canonical identity of one persisted or presented occurrence.
newtype OccurrenceId = OccurrenceId
  { occurrenceIdValue :: Text
  } deriving (Eq, Ord, Show)

-- | Derive an occurrence identity only from its kind and structured source
-- path. Every variable component is UTF-8 hexadecimal and byte-length framed.
occurrenceId :: OccurrenceKind -> NonEmpty PathStep -> OccurrenceId
occurrenceId (OccurrenceKind kind) path =
  OccurrenceId
    ("o2i-occurrence/v1:"
       <> frame kind
       <> frame (decimalText (NonEmpty.length path))
       <> foldMap encodeStep path)
  where
    encodeStep step =
      encodeNamespace (expandedQNameNamespaceValue name)
        <> frame (expandedQNameLocalNameValue name)
        <> frame (decimalText (stepOrdinal step))
      where
        name = stepName step
    encodeNamespace namespace =
      case namespace of
        Nothing -> frame "0"
        Just value -> frame "1" <> frame value

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
data ReferenceOccurrence location = ReferenceOccurrence
  { referenceOccurrenceId :: OccurrenceId
  , referenceFromOccurrence :: OccurrenceId
  , referenceRole :: ReferenceRole
  , referenceToken :: Maybe Text
  , referenceLocation :: location
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
  | CollectiveRealizationParticipant
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Audit record for one occurrence in a closed semantic scope.
data OccurrenceProvenance = OccurrenceProvenance
  { occurrenceProvenanceId :: OccurrenceId -- ^ Included occurrence.
  , occurrenceProvenanceLocation :: SourceLocation -- ^ Unique location.
  , occurrenceProvenanceReasons :: NonEmpty InclusionReason
    -- ^ Canonical non-empty reasons for inclusion.
  } deriving (Eq, Show)

-- | Complete canonical provenance artifact of one closed semantic scope.
newtype ClosedScopeProvenance = ClosedScopeProvenance
  { closedScopeOccurrences :: NonEmpty OccurrenceProvenance
    -- ^ Canonically ordered complete occurrence audit trail.
  } deriving (Eq, Show)

-- | Construct canonical closed-scope provenance after closure has established
-- one location and at least one reason for every reached occurrence.
mkClosedScopeProvenance ::
     NonEmpty (OccurrenceId, SourceLocation, NonEmpty InclusionReason)
  -> ClosedScopeProvenance
mkClosedScopeProvenance entries =
  ClosedScopeProvenance
    (fmap toProvenance (NonEmpty.sortWith occurrenceKey entries))
  where
    occurrenceKey (identifier, _, _) = identifier
    toProvenance (identifier, location, reasons) =
      OccurrenceProvenance
        { occurrenceProvenanceId = identifier
        , occurrenceProvenanceLocation = location
        , occurrenceProvenanceReasons = canonicalReasons reasons
        }
    canonicalReasons =
      NonEmpty.fromList . Set.toAscList . Set.fromList . NonEmpty.toList

-- | Supplemental input whose source participated in a validation stage.
data SupplementalInputKind
  = StrategySupplement
  | CollectiveFitSupplement
  | ReadinessSupplement
  | EvidenceSupplement
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Identity and role of one supplemental source actually consumed.
data SupplementalSource = SupplementalSource
  { supplementalKind :: SupplementalInputKind
  , supplementalIdentity :: SourceIdentity
  } deriving (Eq, Ord, Show)

frame :: Text -> Text
frame value = decimalText (ByteString.length bytes) <> ":" <> hexBytes bytes
  where
    bytes = TextEncoding.encodeUtf8 value

hexBytes :: ByteString -> Text
hexBytes = Text.pack . concatMap hexByte . ByteString.unpack
  where
    hexByte byte =
      case showHex byte "" of
        [digit] -> ['0', digit]
        digits -> digits

decimalText :: Show value => value -> Text
decimalText = Text.pack . show

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
