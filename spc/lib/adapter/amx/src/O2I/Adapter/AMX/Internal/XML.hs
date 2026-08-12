{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Safe recognition and source-path-preserving AMX XML decoding.
module O2I.Adapter.AMX.Internal.XML
  ( decodeNative
  , decodeNativeWithLimits
  , hasNativeAMXSignal
  , archiNamespace
  , xsiNamespace
  , expectedRootName
  ) where

import qualified Data.ByteString as ByteString
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Encoding.Error as TextEncodingError
import qualified Data.Text.Lazy as LazyText
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML.Lexical (normalizeXmlAttributeWhitespace)
import O2I.Adapter.AMX.Internal.XML.Scan
import qualified Text.XML as XML
import qualified Text.XML.Stream.Parse as XMLParse

archiNamespace, xsiNamespace :: Text
archiNamespace = "http://www.archimatetool.com/archimate"

xsiNamespace = "http://www.w3.org/2001/XMLSchema-instance"

xmlnsNamespace :: Text
xmlnsNamespace = "http://www.w3.org/2000/xmlns/"

expectedRootName, versionName :: NativeName
expectedRootName = NativeName (Just archiNamespace) "model"

versionName = NativeName Nothing "version"

decodeNative ::
     ByteString.ByteString -> Either NativeFailure NativeClassification
decodeNative = decodeNativeWithLimits defaultDecodeLimits

decodeNativeWithLimits ::
     DecodeLimits
  -> ByteString.ByteString
  -> Either NativeFailure NativeClassification
decodeNativeWithLimits limits source = do
  enforceInputByteLimit limits source
  bytes <- stripUtf8Bom source
  decoded <-
    either (const (Left InvalidUtf8)) Right (TextEncoding.decodeUtf8' bytes)
  declaredEncoding <- scanXmlText limits decoded
  case declaredEncoding of
    Just encodingName
      | Text.toCaseFold encodingName /= "utf-8" ->
        Left (UnsupportedEncoding encodingName)
    _ -> pure ()
  document <-
    either
      (const (Left MalformedXml))
      Right
      (XML.parseText
         parserSettings
         (LazyText.fromStrict (normalizeXmlAttributeWhitespace decoded)))
  root <- annotateRoot (XML.documentRoot document)
  let native = NativeDocument root
      versions = map nativeAttributeValue (lookupAttribute versionName root)
  pure
    (if nativeElementName root /= expectedRootName
       then NativeFormatMismatch
              (NativeRootMismatch (nativeElementName root))
              native
       else case versions of
              ["5.0.0"] -> NativeFormatMatch native
              [] -> NativeFormatMismatch NativeVersionMissing native
              version:_ ->
                NativeFormatMismatch (NativeVersionUnsupported version) native)

-- | Detect a bounded native AMX root signal without claiming arbitrary
-- malformed or non-XML input for this adapter.
hasNativeAMXSignal :: ByteString.ByteString -> Bool
hasNativeAMXSignal source = rootClaimsExpectedName prefix
  where
    signalLimit = maximumInputBytes defaultDecodeLimits
    prefix = decodeSignalPrefix (ByteString.take signalLimit source)

decodeSignalPrefix :: ByteString.ByteString -> Text
decodeSignalPrefix bytes
  | ByteString.isPrefixOf (ByteString.pack [0, 0, 254, 255]) bytes =
    TextEncoding.decodeUtf32BEWith signalDecodeError (ByteString.drop 4 bytes)
  | ByteString.isPrefixOf (ByteString.pack [255, 254, 0, 0]) bytes =
    TextEncoding.decodeUtf32LEWith signalDecodeError (ByteString.drop 4 bytes)
  | ByteString.isPrefixOf (ByteString.pack [254, 255]) bytes =
    TextEncoding.decodeUtf16BEWith signalDecodeError (ByteString.drop 2 bytes)
  | ByteString.isPrefixOf (ByteString.pack [255, 254]) bytes =
    TextEncoding.decodeUtf16LEWith signalDecodeError (ByteString.drop 2 bytes)
  | ByteString.isPrefixOf (ByteString.pack [0, 0, 0, 60]) bytes =
    TextEncoding.decodeUtf32BEWith signalDecodeError bytes
  | ByteString.isPrefixOf (ByteString.pack [60, 0, 0, 0]) bytes =
    TextEncoding.decodeUtf32LEWith signalDecodeError bytes
  | ByteString.isPrefixOf (ByteString.pack [0, 60]) bytes =
    TextEncoding.decodeUtf16BEWith signalDecodeError bytes
  | ByteString.isPrefixOf (ByteString.pack [60, 0]) bytes =
    TextEncoding.decodeUtf16LEWith signalDecodeError bytes
  | ByteString.isPrefixOf (ByteString.pack [239, 187, 191]) bytes =
    decodeUtf8Prefix (ByteString.drop 3 bytes)
  | otherwise = decodeUtf8Prefix bytes

decodeUtf8Prefix :: ByteString.ByteString -> Text
decodeUtf8Prefix = TextEncoding.decodeUtf8With signalDecodeError

signalDecodeError :: TextEncodingError.OnDecodeError
signalDecodeError _ _ = Just '\0'

rootClaimsExpectedName :: Text -> Bool
rootClaimsExpectedName = hasExpandedRootSignal (Just archiNamespace) "model"

stripUtf8Bom ::
     ByteString.ByteString -> Either NativeFailure ByteString.ByteString
stripUtf8Bom bytes
  | ByteString.isPrefixOf (ByteString.pack [0, 0, 254, 255]) bytes =
    Left (UnsupportedEncoding "UTF-32BE")
  | ByteString.isPrefixOf (ByteString.pack [255, 254, 0, 0]) bytes =
    Left (UnsupportedEncoding "UTF-32LE")
  | ByteString.isPrefixOf (ByteString.pack [254, 255]) bytes =
    Left (UnsupportedEncoding "UTF-16BE")
  | ByteString.isPrefixOf (ByteString.pack [255, 254]) bytes =
    Left (UnsupportedEncoding "UTF-16LE")
  | ByteString.isPrefixOf (ByteString.pack [0, 0, 0, 60]) bytes =
    Left (UnsupportedEncoding "UTF-32BE")
  | ByteString.isPrefixOf (ByteString.pack [60, 0, 0, 0]) bytes =
    Left (UnsupportedEncoding "UTF-32LE")
  | ByteString.isPrefixOf (ByteString.pack [0, 60]) bytes =
    Left (UnsupportedEncoding "UTF-16BE")
  | ByteString.isPrefixOf (ByteString.pack [60, 0]) bytes =
    Left (UnsupportedEncoding "UTF-16LE")
  | ByteString.isPrefixOf (ByteString.pack [239, 187, 191]) bytes =
    Right (ByteString.drop 3 bytes)
  | otherwise = Right bytes

parserSettings :: XML.ParseSettings
parserSettings =
  XML.def
    { XML.psRetainNamespaces = True
    , XMLParse.psIgnoreInternalEntityDeclarations = True
    }

annotateRoot :: XML.Element -> Either NativeFailure NativeElement
annotateRoot root = do
  name <- expandedName (XML.elementName root)
  annotateElement [NativePathStep name 1] Map.empty root

annotateElement ::
     NativePath
  -> Map Text Text
  -> XML.Element
  -> Either NativeFailure NativeElement
annotateElement path inherited element = do
  name <- expandedName (XML.elementName element)
  let namespaceMap =
        Map.union
          (Map.fromList
             (mapMaybe
                namespaceBinding
                (Map.toList (XML.elementAttributes element))))
          inherited
      visible =
        [ (attributeName, value)
        | (attributeName, value) <- Map.toList (XML.elementAttributes element)
        , not (isNamespaceDeclaration attributeName)
        ]
  attributes <-
    fmap
      (sortOn nativeAttributeName)
      (traverse (annotateAttribute path) visible)
  content <- annotateContent path namespaceMap (XML.elementNodes element)
  pure
    NativeElement
      { nativeElementName = name
      , nativeElementAttributes = attributes
      , nativeElementContent = content
      , nativeElementNamespaces = namespaceMap
      , nativeElementPath = path
      }

annotateAttribute ::
     NativePath -> (XML.Name, Text) -> Either NativeFailure NativeAttribute
annotateAttribute parent (name, value) = do
  expanded <- expandedName name
  pure
    NativeAttribute
      { nativeAttributeName = expanded
      , nativeAttributeValue = value
      , nativeAttributePath = parent <> [NativePathStep expanded 1]
      }

annotateContent ::
     NativePath
  -> Map Text Text
  -> [XML.Node]
  -> Either NativeFailure [NativeContent]
annotateContent parent namespaces nodes =
  fmap snd (mapAccumLM annotate Map.empty nodes)
  where
    annotate counts node =
      case node of
        XML.NodeElement child -> do
          name <- expandedName (XML.elementName child)
          let ordinal = Map.findWithDefault 0 name counts + 1
              next = Map.insert name ordinal counts
          observed <-
            annotateElement
              (parent <> [NativePathStep name ordinal])
              namespaces
              child
          pure (next, Just (NativeElementContent observed))
        XML.NodeContent text -> pure (counts, Just (NativeText text))
        XML.NodeComment _ -> pure (counts, Nothing)
        XML.NodeInstruction _ -> pure (counts, Nothing)

mapAccumLM ::
     (state -> input -> Either failure (state, Maybe output))
  -> state
  -> [input]
  -> Either failure (state, [output])
mapAccumLM step initial = go initial []
  where
    go !state outputs [] = Right (state, reverse outputs)
    go !state outputs (value:rest) = do
      (next, output) <- step state value
      let collected = maybe outputs (: outputs) output
      collected `seq` go next collected rest

expandedName :: XML.Name -> Either NativeFailure NativeName
expandedName name
  | Text.null (XML.nameLocalName name) = Left MalformedXml
  | otherwise =
    Right (NativeName (XML.nameNamespace name) (XML.nameLocalName name))

isNamespaceDeclaration :: XML.Name -> Bool
isNamespaceDeclaration name =
  XML.nameNamespace name == Just xmlnsNamespace
    || XML.namePrefix name == Just "xmlns"
    || (XML.namePrefix name == Nothing && XML.nameLocalName name == "xmlns")
    || Text.isPrefixOf "xmlns:" (XML.nameLocalName name)

namespaceBinding :: (XML.Name, Text) -> Maybe (Text, Text)
namespaceBinding (name, value)
  | XML.nameNamespace name == Just xmlnsNamespace =
    Just
      ( if XML.nameLocalName name == "xmlns"
          then ""
          else XML.nameLocalName name
      , value)
  | XML.namePrefix name == Just "xmlns" = Just (XML.nameLocalName name, value)
  | XML.namePrefix name == Nothing && XML.nameLocalName name == "xmlns" =
    Just ("", value)
  | Just prefix <- Text.stripPrefix "xmlns:" (XML.nameLocalName name) =
    Just (prefix, value)
  | otherwise = Nothing
