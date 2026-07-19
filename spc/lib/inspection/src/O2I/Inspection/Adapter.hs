{-# LANGUAGE GADTs #-}

-- | First-class format-adapter boundary.
module O2I.Inspection.Adapter
  ( Adapter(..)
  , AdapterDescriptor
  , AdapterDescriptorError(..)
  , mkAdapterDescriptor
  , adapterDescriptor
  , adapterIdentifier
  , adapterName
  , adapterVersion
  , NativeVersion
  , NativeVersionError(..)
  , mkNativeVersion
  , nativeVersionLiteral
  , nativeVersionText
  , O2IProfileVersion
  , Utf8Binding(..)
  , ResolvedNativeBinding(..)
  , EncodingObservation(..)
  , DecodeUnavailableObservation(..)
  , RejectedNativeBinding(..)
  , DecodeAttempt(..)
  , ViewSelector(..)
  , ViewCandidate(..)
  , ResolvedView(..)
  , ObservedViewResolution(..)
  , ViewAttempt(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Inspection.Diagnostic
import O2I.Inspection.Input
import O2I.Inspection.Profile
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Validated adapter identity reported independently of implementation details.
data AdapterDescriptor = AdapterDescriptor
  { descriptorIdentifier :: Text
  , descriptorName :: Text
  , descriptorVersion :: Text
  } deriving (Eq, Ord, Show)

-- | Every empty field found while validating an adapter descriptor.
data AdapterDescriptorError
  = EmptyAdapterIdentifier
  | EmptyAdapterName
  | EmptyAdapterVersion
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Validate all report-visible descriptor fields, accumulating empty fields.
mkAdapterDescriptor ::
     Text
  -> Text
  -> Text
  -> Either (NonEmpty AdapterDescriptorError) AdapterDescriptor
mkAdapterDescriptor identifier name version =
  case NonEmpty.nonEmpty errors of
    Nothing ->
      Right
        AdapterDescriptor
          { descriptorIdentifier = identifier
          , descriptorName = name
          , descriptorVersion = version
          }
    Just failures -> Left failures
  where
    errors =
      [EmptyAdapterIdentifier | Text.null identifier]
        ++ [EmptyAdapterName | Text.null name]
        ++ [EmptyAdapterVersion | Text.null version]

-- | Construct a descriptor from statically non-empty character sequences.
adapterDescriptor ::
     NonEmpty Char -> NonEmpty Char -> NonEmpty Char -> AdapterDescriptor
adapterDescriptor identifier name version =
  AdapterDescriptor
    { descriptorIdentifier = nonEmptyText identifier
    , descriptorName = nonEmptyText name
    , descriptorVersion = nonEmptyText version
    }

-- | Read the non-empty stable adapter identifier.
adapterIdentifier :: AdapterDescriptor -> Text
adapterIdentifier (AdapterDescriptor identifier _ _) = identifier

-- | Read the non-empty human-readable adapter name.
adapterName :: AdapterDescriptor -> Text
adapterName (AdapterDescriptor _ name _) = name

-- | Read the non-empty adapter contract version.
adapterVersion :: AdapterDescriptor -> Text
adapterVersion (AdapterDescriptor _ _ version) = version

-- | Native concrete-format version.
newtype NativeVersion = NativeVersion
  { unNativeVersion :: Text
  } deriving (Eq, Ord, Show)

-- | Why native-version text cannot be represented in a report.
data NativeVersionError =
  EmptyNativeVersion
  deriving (Eq, Ord, Show)

-- | Validate report-visible native-version text.
mkNativeVersion :: Text -> Either NativeVersionError NativeVersion
mkNativeVersion value
  | Text.null value = Left EmptyNativeVersion
  | otherwise = Right (NativeVersion value)

-- | Construct a native version from a statically non-empty character sequence.
nativeVersionLiteral :: NonEmpty Char -> NativeVersion
nativeVersionLiteral = NativeVersion . nonEmptyText

-- | Read the validated native-format version.
nativeVersionText :: NativeVersion -> Text
nativeVersionText (NativeVersion version) = version

-- | Proof that the complete document was decoded as UTF-8.
data Utf8Binding =
  Utf8Binding
  deriving (Eq, Ord, Show)

-- | Successful native-format binding.
data ResolvedNativeBinding = ResolvedNativeBinding
  { nativeRootQName :: ExpandedQName
  , nativeVersion :: NativeVersion
  } deriving (Eq, Ord, Show)

-- | Encoding information that is safe to expose before native binding.
data EncodingObservation location
  = EncodingNotObserved
  | EncodingDefaultedToUtf8
  | EncodingDeclared (Located location Text)
  deriving (Eq, Ord, Show)

-- | Safe observations retained when native decoding is unavailable.
newtype DecodeUnavailableObservation location = DecodeUnavailableObservation
  { unavailableEncoding :: EncodingObservation location
  } deriving (Eq, Ord, Show)

-- | Complete safe XML observations that violate the native binding.
data RejectedNativeBinding location = RejectedNativeBinding
  { rejectedEncoding :: Utf8Binding
  , rejectedRootQName :: Located location ExpandedQName
  , rejectedNativeVersion :: Maybe (Located location Text)
  } deriving (Eq, Ord, Show)

-- | Total native decode result.
data DecodeAttempt location defect document
  = DecodeUnavailable
      (DecodeUnavailableObservation location)
      (NonEmpty (Located location defect))
  | DecodeRejected
      (RejectedNativeBinding location)
      (NonEmpty (Located location defect))
  | DecodePassed ResolvedNativeBinding document

-- | One adapter with existential document, View, fact, and defect types.
-- Every callback emits source-relative positions; only Inspection binds them
-- to the identity of the exact document under inspection.
data Adapter where
  Adapter
    :: AdapterDescriptor
    -> (SourceDocument -> DecodeAttempt SourcePosition decodeDefect document)
    -> (decodeDefect -> DiagnosticSpec)
    -> (document -> ViewSelector -> ViewAttempt
                                      SourcePosition
                                      viewDefect
                                      selectedView)
    -> (viewDefect -> DiagnosticSpec)
    -> O2IProfileContract SourcePosition profileFact profileDefect
    -> (document -> selectedView -> ProfileSnapshot SourcePosition profileFact)
    -> Adapter

nonEmptyText :: NonEmpty Char -> Text
nonEmptyText = Text.pack . NonEmpty.toList
