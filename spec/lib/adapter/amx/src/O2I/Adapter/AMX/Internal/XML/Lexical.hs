{-# LANGUAGE OverloadedStrings #-}

-- | Shared XML 1.0 lexical rules for recognition and safe decoding.
module O2I.Adapter.AMX.Internal.XML.Lexical
  ( XmlDeclaration
  , declarationEncoding
  , isXmlSpace
  , isXmlNameCharacter
  , validXmlName
  , parseQName
  , validQName
  , xmlCharacterReference
  , validXmlScalar
  , quotedXmlValue
  , normalizeXmlAttributeValue
  , normalizeXmlAttributeWhitespace
  , skipXmlComment
  , skipXmlProcessingInstruction
  , parseXmlDeclaration
  ) where

import Data.Char (chr, ord)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as Builder

data XmlDeclaration = XmlDeclaration
  { declarationEncoding :: !(Maybe Text)
  }

isXmlSpace :: Char -> Bool
isXmlSpace character = Text.any (== character) " \t\r\n"

isXmlNameCharacter :: Char -> Bool
isXmlNameCharacter character =
  character == ':' || isXmlNCNameCharacter character

validXmlName :: Text -> Bool
validXmlName value =
  case Text.uncons value of
    Just (first, rest) ->
      (first == ':' || isXmlNameStartCharacter first)
        && Text.all isXmlNameCharacter rest
    Nothing -> False

validQName :: Text -> Bool
validQName = maybe False (const True) . parseQName

parseQName :: Text -> Maybe (Maybe Text, Text)
parseQName lexical =
  case Text.splitOn ":" lexical of
    [local]
      | validNCName local -> Just (Nothing, local)
    [prefix, local]
      | validNCName prefix && validNCName local -> Just (Just prefix, local)
    _ -> Nothing

xmlCharacterReference :: Text -> Maybe (Int, Text)
xmlCharacterReference input
  | Just rest <- Text.stripPrefix "amp;" input = Just (ord '&', rest)
  | Just rest <- Text.stripPrefix "lt;" input = Just (ord '<', rest)
  | Just rest <- Text.stripPrefix "gt;" input = Just (ord '>', rest)
  | Just rest <- Text.stripPrefix "quot;" input = Just (ord '"', rest)
  | Just rest <- Text.stripPrefix "apos;" input = Just (ord '\'', rest)
  | Just numeric <- Text.stripPrefix "#" input = numericReference numeric
  | otherwise = Nothing

validXmlScalar :: Int -> Bool
validXmlScalar value =
  value == 0x9
    || value == 0xA
    || value == 0xD
    || (value >= 0x20 && value <= 0xD7FF)
    || (value >= 0xE000 && value <= 0xFFFD)
    || (value >= 0x10000 && value <= 0x10FFFF)

quotedXmlValue :: Text -> Maybe (Text, Text)
quotedXmlValue input = do
  (quote, value) <- Text.uncons input
  if quote == '\'' || quote == '"'
    then go quote value value
    else Nothing
  where
    go quote original remaining =
      case Text.uncons remaining of
        Just (character, rest)
          | character == quote ->
            Just
              ( Text.take
                  (Text.length original - Text.length remaining)
                  original
              , rest)
          | character == '<' -> Nothing
          | character == '&' -> do
            (value, afterReference) <- xmlCharacterReference rest
            if validXmlScalar value
              then pure ()
              else Nothing
            go quote original afterReference
          | validXmlScalar (ord character) -> go quote original rest
          | otherwise -> Nothing
        Nothing -> Nothing

normalizeXmlAttributeValue :: Text -> Maybe Text
normalizeXmlAttributeValue =
  fmap (LazyText.toStrict . Builder.toLazyText) . go mempty
  where
    go output remaining =
      case Text.uncons remaining of
        Nothing -> Just output
        Just ('&', afterAmpersand) -> do
          (value, rest) <- xmlCharacterReference afterAmpersand
          if validXmlScalar value
            then go (output <> Builder.singleton (chr value)) rest
            else Nothing
        Just ('\r', afterCarriageReturn)
          | Just rest <- Text.stripPrefix "\n" afterCarriageReturn ->
            go (output <> Builder.singleton ' ') rest
          | otherwise ->
            go (output <> Builder.singleton ' ') afterCarriageReturn
        Just (character, rest) ->
          if validXmlScalar (ord character)
            then go
                   (output
                      <> Builder.singleton
                           (if character == '\t' || character == '\n'
                              then ' '
                              else character))
                   rest
            else Nothing

-- | Normalize raw XML 1.0 attribute whitespace before DOM construction.
-- Character references remain lexical so that referenced whitespace stays
-- distinct from raw tab and end-of-line characters.
normalizeXmlAttributeWhitespace :: Text -> Text
normalizeXmlAttributeWhitespace =
  LazyText.toStrict . Builder.toLazyText . go XmlContent mempty
  where
    go region output remaining =
      case region of
        XmlContent
          | Just rest <- Text.stripPrefix "<!--" remaining ->
            go XmlComment (output <> Builder.fromText "<!--") rest
          | Just rest <- Text.stripPrefix "<![CDATA[" remaining ->
            go XmlCData (output <> Builder.fromText "<![CDATA[") rest
          | Just rest <- Text.stripPrefix "<?" remaining ->
            go XmlProcessingInstruction (output <> Builder.fromText "<?") rest
          | Just rest <- Text.stripPrefix "<" remaining ->
            go XmlTag (output <> Builder.singleton '<') rest
          | otherwise -> copyOne region output remaining
        XmlTag ->
          case Text.uncons remaining of
            Just ('\'', rest) ->
              go XmlSingleQuoted (output <> Builder.singleton '\'') rest
            Just ('"', rest) ->
              go XmlDoubleQuoted (output <> Builder.singleton '"') rest
            Just ('>', rest) ->
              go XmlContent (output <> Builder.singleton '>') rest
            _ -> copyOne region output remaining
        XmlSingleQuoted -> quoted '\'' region output remaining
        XmlDoubleQuoted -> quoted '"' region output remaining
        XmlComment -> opaque "-->" XmlContent region output remaining
        XmlCData -> opaque "]]>" XmlContent region output remaining
        XmlProcessingInstruction ->
          opaque "?>" XmlContent region output remaining
    quoted delimiter region output remaining =
      case Text.uncons remaining of
        Nothing -> output
        Just (character, rest)
          | character == delimiter ->
            go XmlTag (output <> Builder.singleton character) rest
          | character == '\r'
          , Just afterLineFeed <- Text.stripPrefix "\n" rest ->
            go region (output <> Builder.singleton ' ') afterLineFeed
          | character == '\r' || character == '\n' || character == '\t' ->
            go region (output <> Builder.singleton ' ') rest
          | otherwise -> go region (output <> Builder.singleton character) rest
    opaque marker next region output remaining
      | Just rest <- Text.stripPrefix marker remaining =
        go next (output <> Builder.fromText marker) rest
      | otherwise = copyOne region output remaining
    copyOne region output remaining =
      case Text.uncons remaining of
        Nothing -> output
        Just (character, rest) ->
          go region (output <> Builder.singleton character) rest

data XmlRegion
  = XmlContent
  | XmlTag
  | XmlSingleQuoted
  | XmlDoubleQuoted
  | XmlComment
  | XmlCData
  | XmlProcessingInstruction

-- | Consume comment content after @<!--@ and return text after @-->@.
skipXmlComment :: Text -> Maybe Text
skipXmlComment = go
  where
    go input
      | Just rest <- Text.stripPrefix "-->" input = Just rest
      | Just _ <- Text.stripPrefix "--" input = Nothing
      | Just (character, rest) <- Text.uncons input
      , validXmlScalar (ord character) = go rest
      | otherwise = Nothing

-- | Consume a processing instruction after @<?@. XML's reserved target is
-- rejected here; an optional XML declaration is handled separately.
skipXmlProcessingInstruction :: Text -> Maybe Text
skipXmlProcessingInstruction input = do
  let (target, afterTarget) = Text.span isXmlNameCharacter input
  if validXmlName target && Text.toCaseFold target /= "xml"
    then pure ()
    else Nothing
  case Text.uncons afterTarget of
    Just ('?', rest) -> Text.stripPrefix ">" rest
    Just (separator, dataInput)
      | isXmlSpace separator -> skipUntil "?>" dataInput
    _ -> Nothing

-- | Parse one exact XML 1.0 declaration from the document start.
parseXmlDeclaration :: Text -> Maybe (XmlDeclaration, Text)
parseXmlDeclaration input = do
  afterPrefix <- Text.stripPrefix "<?xml" input
  afterVersion <- declarationAttribute "version" ["1.0"] afterPrefix
  (encoding, afterEncoding) <- optionalEncoding afterVersion
  afterStandalone <- optionalStandalone afterEncoding
  remaining <- Text.stripPrefix "?>" (Text.dropWhile isXmlSpace afterStandalone)
  pure (XmlDeclaration encoding, remaining)

numericReference :: Text -> Maybe (Int, Text)
numericReference input = do
  let (base, validDigit, digitsInput) =
        case Text.uncons input of
          Just ('x', rest) -> (16, isHexDigit, rest)
          _ -> (10, isDecimalDigit, input)
      (digits, ending) = Text.break (== ';') digitsInput
  if not (Text.null digits) && Text.all validDigit digits
    then pure ()
    else Nothing
  (';', rest) <- Text.uncons ending
  value <- parseNumber base digits
  Just (value, rest)

parseNumber :: Int -> Text -> Maybe Int
parseNumber base = Text.foldl' step (Just 0)
  where
    step Nothing _ = Nothing
    step (Just total) character = do
      digit <- digitValue character
      let next = total * base + digit
      if next <= 0x10FFFF
        then Just next
        else Nothing

digitValue :: Char -> Maybe Int
digitValue character
  | isDecimalDigit character = Just (fromEnum character - fromEnum '0')
  | character >= 'a' && character <= 'f' =
    Just (10 + fromEnum character - fromEnum 'a')
  | character >= 'A' && character <= 'F' =
    Just (10 + fromEnum character - fromEnum 'A')
  | otherwise = Nothing

isDecimalDigit :: Char -> Bool
isDecimalDigit character = character >= '0' && character <= '9'

isHexDigit :: Char -> Bool
isHexDigit character =
  isDecimalDigit character
    || (character >= 'a' && character <= 'f')
    || (character >= 'A' && character <= 'F')

validNCName :: Text -> Bool
validNCName value =
  case Text.uncons value of
    Just (first, rest) ->
      isXmlNameStartCharacter first && Text.all isXmlNCNameCharacter rest
    Nothing -> False

isXmlNCNameCharacter :: Char -> Bool
isXmlNCNameCharacter character =
  isXmlNameStartCharacter character
    || isDecimalDigit character
    || character == '-'
    || character == '.'
    || character == '\xB7'
    || (character >= '\x0300' && character <= '\x036F')
    || (character >= '\x203F' && character <= '\x2040')

isXmlNameStartCharacter :: Char -> Bool
isXmlNameStartCharacter character =
  character == '_'
    || (character >= 'A' && character <= 'Z')
    || (character >= 'a' && character <= 'z')
    || (character >= '\xC0' && character <= '\xD6')
    || (character >= '\xD8' && character <= '\xF6')
    || (character >= '\xF8' && character <= '\x2FF')
    || (character >= '\x370' && character <= '\x37D')
    || (character >= '\x37F' && character <= '\x1FFF')
    || (character >= '\x200C' && character <= '\x200D')
    || (character >= '\x2070' && character <= '\x218F')
    || (character >= '\x2C00' && character <= '\x2FEF')
    || (character >= '\x3001' && character <= '\xD7FF')
    || (character >= '\xF900' && character <= '\xFDCF')
    || (character >= '\xFDF0' && character <= '\xFFFD')
    || (character >= '\x10000' && character <= '\xEFFFF')

skipUntil :: Text -> Text -> Maybe Text
skipUntil marker input = do
  let (content, ending) = Text.breakOn marker input
  if Text.all (validXmlScalar . ord) content
    then pure ()
    else Nothing
  if Text.null ending
    then Nothing
    else Text.stripPrefix marker ending

declarationAttribute :: Text -> [Text] -> Text -> Maybe Text
declarationAttribute name accepted input = do
  (separator, afterSeparator) <- Text.uncons input
  if isXmlSpace separator
    then pure ()
    else Nothing
  afterName <- Text.stripPrefix name (Text.dropWhile isXmlSpace afterSeparator)
  afterEquals <- Text.stripPrefix "=" (Text.dropWhile isXmlSpace afterName)
  (value, rest) <- quotedValue (Text.dropWhile isXmlSpace afterEquals)
  if value `elem` accepted
    then Just rest
    else Nothing

optionalEncoding :: Text -> Maybe (Maybe Text, Text)
optionalEncoding input =
  case optionalAttribute "encoding" input of
    Nothing -> Just (Nothing, input)
    Just (value, rest)
      | validEncodingName value -> Just (Just value, rest)
      | otherwise -> Nothing

optionalStandalone :: Text -> Maybe Text
optionalStandalone input =
  case optionalAttribute "standalone" input of
    Nothing -> Just input
    Just (value, rest)
      | value == "yes" || value == "no" -> Just rest
      | otherwise -> Nothing

optionalAttribute :: Text -> Text -> Maybe (Text, Text)
optionalAttribute name input = do
  (separator, afterSeparator) <- Text.uncons input
  if isXmlSpace separator
    then pure ()
    else Nothing
  let afterSpace = Text.dropWhile isXmlSpace afterSeparator
  afterName <- Text.stripPrefix name afterSpace
  afterEquals <- Text.stripPrefix "=" (Text.dropWhile isXmlSpace afterName)
  quotedValue (Text.dropWhile isXmlSpace afterEquals)

quotedValue :: Text -> Maybe (Text, Text)
quotedValue input = do
  (quote, value) <- Text.uncons input
  if quote == '\'' || quote == '"'
    then do
      let (literal, closing) = Text.break (== quote) value
      if Text.all (validXmlScalar . ord) literal
        then pure ()
        else Nothing
      (_, remaining) <- Text.uncons closing
      pure (literal, remaining)
    else Nothing

validEncodingName :: Text -> Bool
validEncodingName value =
  case Text.uncons value of
    Just (first, rest) ->
      isAsciiLetter first
        && Text.all
             (\character ->
                isAsciiLetter character
                  || isDecimalDigit character
                  || Text.any (== character) "._-")
             rest
    Nothing -> False

isAsciiLetter :: Char -> Bool
isAsciiLetter character =
  (character >= 'A' && character <= 'Z')
    || (character >= 'a' && character <= 'z')
