-- | Stable source identities and occurrence-level provenance.
module O2I.Inspection.Provenance
  ( SourceInputKind(..)
  , SourceHash(..)
  , SourceIdentity(..)
  , ExpandedQName(..)
  , PathStep(..)
  , mkPathStep
  , LocationTarget(..)
  , SourceSpan(..)
  , mkSourceSpan
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
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)

-- | How the inspected bytes entered the application.
data SourceInputKind
  = FileSource
  | StandardInputSource
  deriving (Eq, Ord, Show)

-- | Lowercase hexadecimal SHA-256 of the exact acquired bytes.
newtype SourceHash = SourceHash
  { sourceHashText :: Text
  } deriving (Eq, Ord, Show)

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
  { pathStepName :: ExpandedQName
  , pathStepOrdinal :: Natural
  } deriving (Eq, Ord, Show)

-- | Construct a path segment only with a one-based sibling ordinal.
mkPathStep :: ExpandedQName -> Natural -> Maybe PathStep
mkPathStep name ordinal
  | ordinal == 0 = Nothing
  | otherwise = Just PathStep {pathStepName = name, pathStepOrdinal = ordinal}

-- | Exact field represented by a source location.
data LocationTarget
  = ElementTarget
  | AttributeTarget ExpandedQName
  | PropertyTarget Text
  | TextFieldTarget ExpandedQName
  deriving (Eq, Ord, Show)

-- | Optional one-based source span.
data SourceSpan = SourceSpan
  { spanStartLine :: Natural
  , spanStartColumn :: Natural
  , spanEndLine :: Natural
  , spanEndColumn :: Natural
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
