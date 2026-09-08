{-# LANGUAGE DeriveGeneric #-}

-- | Source-preserving native AMX observations before Draft projection.
module O2I.Adapter.AMX.Internal.Types where

import Data.Map.Strict (Map)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Expanded XML name. Prefix spelling is deliberately absent.
data NativeName = NativeName
  { nativeNameNamespace :: !(Maybe Text)
  , nativeNameLocal :: !Text
  } deriving (Eq, Generic, Ord, Show)

-- | One path step and its one-based equal-name sibling ordinal.
data NativePathStep = NativePathStep
  { nativePathStepName :: !NativeName
  , nativePathStepOrdinal :: !Int
  } deriving (Eq, Generic, Ord, Show)

type NativePath = [NativePathStep]

-- | One decoded native attribute.
data NativeAttribute = NativeAttribute
  { nativeAttributeName :: !NativeName
  , nativeAttributeValue :: !Text
  , nativeAttributePath :: !NativePath
  } deriving (Eq, Generic, Ord, Show)

-- | Native child content after XML decoding.
data NativeContent
  = NativeText !Text
  | NativeElementContent !NativeElement
  deriving (Eq, Generic, Show)

-- | One native element with expanded names, namespace context, and path.
data NativeElement = NativeElement
  { nativeElementName :: !NativeName
  , nativeElementAttributes :: ![NativeAttribute]
  , nativeElementContent :: ![NativeContent]
  , nativeElementNamespaces :: !(Map Text Text)
  , nativeElementPath :: !NativePath
  } deriving (Eq, Generic, Show)

newtype NativeDocument = NativeDocument
  { nativeDocumentRoot :: NativeElement
  } deriving (Eq, Generic, Show)

-- | Closed native decoding failure vocabulary.
data NativeFailure
  = InputLimitExceeded !Int !Int
  | XmlDepthLimitExceeded !Int !Int
  | XmlElementLimitExceeded !Int !Int
  | XmlAttributeLimitExceeded !Int !Int
  | XmlTextLimitExceeded !Int !Int
  | InvalidUtf8
  | UnsupportedEncoding !Text
  | UnsupportedXmlFacility
  | ForbiddenXmlScalar !Int
  | MalformedXml
  deriving (Eq, Generic, Ord, Show)

data NativeClassification
  = NativeFormatMatch !NativeDocument
  | NativeFormatMismatch !NativeMismatch !NativeDocument
  deriving (Eq, Generic, Show)

-- | Exact reason why decoded XML does not satisfy the native AMX contract.
data NativeMismatch
  = NativeRootMismatch !NativeName
  | NativeVersionMissing
  | NativeVersionUnsupported !Text
  deriving (Eq, Generic, Ord, Show)

lookupAttribute :: NativeName -> NativeElement -> [NativeAttribute]
lookupAttribute name =
  filter ((== name) . nativeAttributeName) . nativeElementAttributes

childElements :: NativeElement -> [NativeElement]
childElements element =
  [child | NativeElementContent child <- nativeElementContent element]
