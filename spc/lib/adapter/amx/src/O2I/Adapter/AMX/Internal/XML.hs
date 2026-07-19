{-# LANGUAGE OverloadedStrings #-}

-- | Safe native AMX XML decoding with stable source paths.
module O2I.Adapter.AMX.Internal.XML
  ( decodeAMX
  , archiNamespace
  , expectedRootQName
  ) where

import qualified Data.ByteString as ByteString
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Lazy as LazyText
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Adapter
import O2I.Inspection.Input
import O2I.Inspection.Provenance
import qualified Text.XML as XML
import qualified Text.XML.Stream.Parse as XMLParse

archiNamespace :: Text
archiNamespace = "http://www.archimatetool.com/archimate"

expectedRootQName :: ExpandedQName
expectedRootQName = expandedQName (Just archiNamespace) 'm' "odel"

nativeVersionAttribute :: ExpandedQName
nativeVersionAttribute = expandedQName Nothing 'v' "ersion"

xmlnsNamespace :: Text
xmlnsNamespace = "http://www.w3.org/2000/xmlns/"

-- | Decode exact source bytes without DTD, entity, resolver, or network use.
decodeAMX :: SourceDocument -> DecodeAttempt AMXDecodeDefect AMXDocument
decodeAMX source =
  case stripSupportedBom (sourceDocumentBytes source) of
    Left encoding -> unsupportedBom source encoding
    Right bytes ->
      case TextEncoding.decodeUtf8' bytes of
        Left _ -> unavailable source EncodingNotObserved InvalidUtf8
        Right decoded ->
          let observation = encodingObservation source decoded
           in case declaredEncoding observation of
                Just encoding
                  | not (isUtf8Name encoding) ->
                    unavailable
                      source
                      observation
                      (UnsupportedXmlEncoding encoding)
                _
                  | containsUnsafeXml decoded ->
                    unavailable source observation UnsafeXml
                  | otherwise -> parseNativeDocument source observation decoded

stripSupportedBom :: ByteString.ByteString -> Either Text ByteString.ByteString
stripSupportedBom bytes
  | ByteString.pack [0, 0, 254, 255] `ByteString.isPrefixOf` bytes =
    Left "UTF-32BE"
  | ByteString.pack [255, 254, 0, 0] `ByteString.isPrefixOf` bytes =
    Left "UTF-32LE"
  | ByteString.pack [254, 255] `ByteString.isPrefixOf` bytes = Left "UTF-16BE"
  | ByteString.pack [255, 254] `ByteString.isPrefixOf` bytes = Left "UTF-16LE"
  | ByteString.pack [239, 187, 191] `ByteString.isPrefixOf` bytes =
    Right (ByteString.drop 3 bytes)
  | otherwise = Right bytes

unsupportedBom ::
     SourceDocument -> Text -> DecodeAttempt AMXDecodeDefect document
unsupportedBom source encoding =
  unavailable source EncodingNotObserved (UnsupportedXmlEncoding encoding)

unavailable ::
     SourceDocument
  -> EncodingObservation
  -> AMXDecodeDefect
  -> DecodeAttempt AMXDecodeDefect document
unavailable source observation defect =
  DecodeUnavailable
    (DecodeUnavailableObservation observation)
    (Located (documentLocation source) defect :| [])

parseNativeDocument ::
     SourceDocument
  -> EncodingObservation
  -> Text
  -> DecodeAttempt AMXDecodeDefect AMXDocument
parseNativeDocument source observation decoded =
  case XML.parseText parserSettings (LazyText.fromStrict decoded) of
    Left _ -> unavailable source observation MalformedXml
    Right parsed ->
      case annotateDocument source parsed of
        Left defect -> unavailable source observation defect
        Right annotated -> bindNativeDocument annotated

parserSettings :: XML.ParseSettings
parserSettings =
  XML.def
    { XML.psRetainNamespaces = True
    , XMLParse.psIgnoreInternalEntityDeclarations = True
    }

bindNativeDocument :: AMXElement -> DecodeAttempt AMXDecodeDefect AMXDocument
bindNativeDocument root =
  case defects of
    [] ->
      DecodePassed
        ResolvedNativeBinding
          { nativeRootQName = amxElementQName root
          , nativeVersion = nativeVersionLiteral ('5' :| ".0.0")
          }
        AMXDocument
          { amxDocumentRoot = root
          , amxDocumentElements =
              filter
                ((== expandedQName Nothing 'e' "lement") . amxElementQName)
                (elementDescendants root)
          }
    first:rest ->
      DecodeRejected
        RejectedNativeBinding
          { rejectedEncoding = Utf8Binding
          , rejectedRootQName =
              Located (amxElementLocation root) (amxElementQName root)
          , rejectedNativeVersion =
              fmap
                (Located (elementAttributeLocation nativeVersionAttribute root))
                observedVersion
          }
        (first :| rest)
  where
    observedVersion = elementAttribute nativeVersionAttribute root
    rootDefects =
      [ Located
        (amxElementLocation root)
        (UnexpectedRootQName (amxElementQName root))
      | amxElementQName root /= expectedRootQName
      ]
    versionDefects =
      case observedVersion of
        Nothing -> [Located (amxElementLocation root) MissingNativeVersion]
        Just "5.0.0" -> []
        Just version ->
          [ Located
              (elementAttributeLocation nativeVersionAttribute root)
              (UnsupportedNativeVersion version)
          ]
    defects = rootDefects ++ versionDefects

annotateDocument ::
     SourceDocument -> XML.Document -> Either AMXDecodeDefect AMXElement
annotateDocument source document = do
  rootName <- expandedName (XML.elementName root)
  annotateElement source (firstPathStep rootName :| []) Map.empty root
  where
    root = XML.documentRoot document

annotateElement ::
     SourceDocument
  -> NonEmpty PathStep
  -> Map Text Text
  -> XML.Element
  -> Either AMXDecodeDefect AMXElement
annotateElement source path inherited element = do
  name <- expandedName (XML.elementName element)
  attributes <- fmap Map.fromList (traverse annotateAttribute visibleAttributes)
  annotatedChildren <- annotateChildren source path namespaces childElements
  pure
    AMXElement
      { amxElementQName = name
      , amxElementAttributes = attributes
      , amxElementChildren = annotatedChildren
      , amxElementLocation =
          SourceLocation
            { locationSource = sourceDocumentIdentity source
            , locationPath = path
            , locationTarget = ElementTarget
            , locationSpan = Nothing
            }
      , amxElementNamespaces = namespaces
      }
  where
    visibleAttributes =
      [ attribute
      | attribute@(name, _) <- Map.toList (XML.elementAttributes element)
      , not (isNamespaceDeclaration name)
      ]
    annotateAttribute (name, value) = do
      expanded <- expandedName name
      pure (expanded, value)
    namespaces =
      Map.union
        (Map.fromList
           (mapMaybe
              namespaceBinding
              (Map.toList (XML.elementAttributes element))))
        inherited
    childElements = [child | XML.NodeElement child <- XML.elementNodes element]

annotateChildren ::
     SourceDocument
  -> NonEmpty PathStep
  -> Map Text Text
  -> [XML.Element]
  -> Either AMXDecodeDefect [AMXElement]
annotateChildren source parentPath namespaces = go Map.empty
  where
    go _ [] = Right []
    go counts (child:rest) = do
      name <- expandedName (XML.elementName child)
      let preceding = Map.findWithDefault 0 name counts
          nextCounts = Map.insert name (preceding + 1) counts
      annotated <-
        annotateElement
          source
          (appendPath parentPath (pathStepAfter name preceding))
          namespaces
          child
      remaining <- go nextCounts rest
      pure (annotated : remaining)

appendPath :: NonEmpty value -> value -> NonEmpty value
appendPath (first :| rest) value = first :| (rest ++ [value])

expandedName :: XML.Name -> Either AMXDecodeDefect ExpandedQName
expandedName name =
  case mkExpandedQName (XML.nameNamespace name) (XML.nameLocalName name) of
    Left EmptyQNameLocalName -> Left MalformedXml
    Right expanded -> Right expanded

isNamespaceDeclaration :: XML.Name -> Bool
isNamespaceDeclaration name =
  XML.nameNamespace name == Just xmlnsNamespace
    || XML.namePrefix name == Just "xmlns"
    || (XML.namePrefix name == Nothing && XML.nameLocalName name == "xmlns")
    || "xmlns:" `Text.isPrefixOf` XML.nameLocalName name

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

encodingObservation :: SourceDocument -> Text -> EncodingObservation
encodingObservation source decoded =
  case xmlDeclarationEncoding decoded of
    Nothing -> EncodingDefaultedToUtf8
    Just encoding ->
      EncodingDeclared
        (Located
           ((documentLocation source)
              { locationTarget =
                  AttributeTarget (expandedQName Nothing 'e' "ncoding")
              })
           encoding)

declaredEncoding :: EncodingObservation -> Maybe Text
declaredEncoding observation =
  case observation of
    EncodingDeclared located -> Just (locatedValue located)
    EncodingNotObserved -> Nothing
    EncodingDefaultedToUtf8 -> Nothing

xmlDeclarationEncoding :: Text -> Maybe Text
xmlDeclarationEncoding text
  | "<?xml" `Text.isPrefixOf` text = do
    let declaration = Text.takeWhileEnd (/= '<') (Text.takeWhile (/= '>') text)
    attributeValue "encoding" declaration
  | otherwise = Nothing

attributeValue :: Text -> Text -> Maybe Text
attributeValue key input = search (Text.drop 5 input)
  where
    search remaining =
      case Text.breakOn key remaining of
        (_, suffix)
          | Text.null suffix -> Nothing
          | otherwise ->
            let afterKey = Text.drop (Text.length key) suffix
                afterSpace = Text.dropWhile isXmlSpace afterKey
             in case Text.uncons afterSpace of
                  Just ('=', afterEquals) ->
                    quoted (Text.dropWhile isXmlSpace afterEquals)
                  _ -> search (Text.drop 1 suffix)
    quoted value =
      case Text.uncons value of
        Just ('\'', rest) -> Just (Text.takeWhile (/= '\'') rest)
        Just ('"', rest) -> Just (Text.takeWhile (/= '"') rest)
        _ -> Nothing

isXmlSpace :: Char -> Bool
isXmlSpace character = character `elem` [' ', '\t', '\r', '\n']

isUtf8Name :: Text -> Bool
isUtf8Name = (== "utf-8") . Text.toCaseFold

containsUnsafeXml :: Text -> Bool
containsUnsafeXml = scan
  where
    scan remaining
      | Text.null remaining = False
      | "<!--" `Text.isPrefixOf` remaining =
        scanAfter "-->" (Text.drop 4 remaining)
      | "<![CDATA[" `Text.isPrefixOf` remaining =
        scanAfter "]]>" (Text.drop 9 remaining)
      | "<?" `Text.isPrefixOf` remaining =
        scanAfter "?>" (Text.drop 2 remaining)
      | "<!DOCTYPE" `Text.isPrefixOf` remaining = True
      | "<!ENTITY" `Text.isPrefixOf` remaining = True
      | "&" `Text.isPrefixOf` remaining =
        case Text.breakOn ";" (Text.drop 1 remaining) of
          (_, suffix)
            | Text.null suffix -> scan (Text.drop 1 remaining)
          (name, suffix) ->
            if safeEntity name
              then scan (Text.drop 1 suffix)
              else True
      | otherwise = scan (Text.drop 1 remaining)
    scanAfter marker remaining =
      case Text.breakOn marker remaining of
        (_, suffix)
          | Text.null suffix -> False
          | otherwise -> scan (Text.drop (Text.length marker) suffix)

safeEntity :: Text -> Bool
safeEntity name =
  name `elem` ["amp", "lt", "gt", "quot", "apos"] || "#" `Text.isPrefixOf` name

documentLocation :: SourceDocument -> SourceLocation
documentLocation source =
  SourceLocation
    { locationSource = sourceDocumentIdentity source
    , locationPath = firstPathStep (expandedQName Nothing 'd' "ocument") :| []
    , locationTarget = ElementTarget
    , locationSpan = Nothing
    }
