{-# LANGUAGE GADTs #-}

-- | First-class format-adapter boundary.
module O2I.Inspection.Adapter
  ( Adapter(..)
  , AdapterDescriptor(..)
  , NativeVersion(..)
  , O2IProfileVersion(..)
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
import Data.Text (Text)
import O2I.Inspection.Diagnostic
import O2I.Inspection.Input
import O2I.Inspection.Profile
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Stable adapter identity reported independently of implementation details.
data AdapterDescriptor = AdapterDescriptor
  { adapterIdentifier :: Text
  , adapterName :: Text
  , adapterVersion :: Text
  } deriving (Eq, Ord, Show)

-- | Native concrete-format version.
newtype NativeVersion = NativeVersion
  { nativeVersionText :: Text
  } deriving (Eq, Ord, Show)

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
data EncodingObservation
  = EncodingNotObserved
  | EncodingDefaultedToUtf8
  | EncodingDeclared (Located Text)
  deriving (Eq, Ord, Show)

-- | Safe observations retained when native decoding is unavailable.
newtype DecodeUnavailableObservation = DecodeUnavailableObservation
  { unavailableEncoding :: EncodingObservation
  } deriving (Eq, Ord, Show)

-- | Complete safe XML observations that violate the native binding.
data RejectedNativeBinding = RejectedNativeBinding
  { rejectedEncoding :: Utf8Binding
  , rejectedRootQName :: Located ExpandedQName
  , rejectedNativeVersion :: Maybe (Located Text)
  } deriving (Eq, Ord, Show)

-- | Total native decode result.
data DecodeAttempt defect document
  = DecodeUnavailable DecodeUnavailableObservation (NonEmpty (Located defect))
  | DecodeRejected RejectedNativeBinding (NonEmpty (Located defect))
  | DecodePassed ResolvedNativeBinding document

-- | One adapter with existential document, View, fact, and defect types.
data Adapter where
  Adapter
    :: AdapterDescriptor
    -> (SourceDocument -> DecodeAttempt decodeDefect document)
    -> (decodeDefect -> DiagnosticSpec)
    -> (document -> ViewSelector -> ViewAttempt viewDefect selectedView)
    -> (viewDefect -> DiagnosticSpec)
    -> O2IProfileContract profileFact profileDefect
    -> (document -> selectedView -> ObservedProfileFacts profileFact)
    -> Adapter
