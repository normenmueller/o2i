{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Deterministic resource envelope and linear lexical XML scan.
module O2I.Adapter.AMX.Internal.XML.Scan
  ( DecodeLimits(..)
  , defaultDecodeLimits
  , enforceInputByteLimit
  , scanXmlText
  ) where

import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.Defect

-- | Closed resource contract enforced before the native XML parser runs.
--
-- Text counts Unicode scalar values in XML character data and CDATA sections.
-- Element counts cover element nodes; attribute counts include namespace
-- declarations. The input-byte limit includes an optional byte-order mark.
data DecodeLimits = DecodeLimits
  { maximumInputBytes :: Int
  , maximumXmlDepth :: Int
  , maximumXmlElements :: Int
  , maximumXmlAttributes :: Int
  , maximumXmlTextCharacters :: Int
  } deriving (Eq, Show)

-- | Conservative production limits for one inspected native AMX document.
defaultDecodeLimits :: DecodeLimits
defaultDecodeLimits =
  DecodeLimits
    { maximumInputBytes = 64 * 1024 * 1024
    , maximumXmlDepth = 128
    , maximumXmlElements = 500000
    , maximumXmlAttributes = 2000000
    , maximumXmlTextCharacters = 32 * 1024 * 1024
    }

-- | Enforce the exact source-byte budget before decoding or BOM removal.
enforceInputByteLimit ::
     DecodeLimits -> ByteString.ByteString -> Either AMXDecodeDefect ()
enforceInputByteLimit limits bytes =
  checkLimit
    InputBytesLimitExceeded
    (maximumInputBytes limits)
    (ByteString.length bytes)

-- | Reject unsafe XML constructs and enforce parser-facing limits in one pass.
--
-- The scanner advances monotonically through the decoded text. It permits only
-- predefined and numeric entity references, skips comments and processing
-- instructions, and counts CDATA as character data.
scanXmlText :: DecodeLimits -> Text -> Either AMXDecodeDefect ()
scanXmlText limits = scanDocument limits initialScanState

data ScanState = ScanState
  { scanDepth :: !Int
  , scanElements :: !Int
  , scanAttributes :: !Int
  , scanTextCharacters :: !Int
  }

initialScanState :: ScanState
initialScanState = ScanState 0 0 0 0

scanDocument :: DecodeLimits -> ScanState -> Text -> Either AMXDecodeDefect ()
scanDocument limits !state input =
  case Text.uncons input of
    Nothing -> Right ()
    Just ('<', rest)
      | Just after <- Text.stripPrefix "!--" rest ->
        scanDelimited "-->" limits state after
      | Just after <- Text.stripPrefix "![CDATA[" rest ->
        scanCData limits state after
      | Just after <- Text.stripPrefix "?" rest ->
        scanDelimited "?>" limits state after
      | Just after <- Text.stripPrefix "/" rest ->
        scanClosingTag limits state after
      | Just _ <- Text.stripPrefix "!" rest -> Left UnsafeXml
      | otherwise -> scanOpeningTag limits state rest
    Just ('&', rest) -> do
      remaining <- scanEntity rest
      state' <- addTextCharacters limits 1 state
      scanDocument limits state' remaining
    Just (_, rest) -> do
      state' <- addTextCharacters limits 1 state
      scanDocument limits state' rest

scanDelimited ::
     Text -> DecodeLimits -> ScanState -> Text -> Either AMXDecodeDefect ()
scanDelimited marker limits state = go
  where
    go remaining
      | Just after <- Text.stripPrefix marker remaining =
        scanDocument limits state after
      | otherwise =
        case Text.uncons remaining of
          Nothing -> Right ()
          Just (_, after) -> go after

scanCData :: DecodeLimits -> ScanState -> Text -> Either AMXDecodeDefect ()
scanCData limits = go
  where
    go !state remaining
      | Just after <- Text.stripPrefix "]]>" remaining =
        scanDocument limits state after
      | otherwise =
        case Text.uncons remaining of
          Nothing -> Right ()
          Just (_, after) -> do
            state' <- addTextCharacters limits 1 state
            go state' after

scanClosingTag :: DecodeLimits -> ScanState -> Text -> Either AMXDecodeDefect ()
scanClosingTag limits state = go
  where
    go remaining =
      case Text.uncons remaining of
        Nothing -> Right ()
        Just ('>', after) ->
          scanDocument
            limits
            state {scanDepth = max 0 (scanDepth state - 1)}
            after
        Just (_, after) -> go after

scanOpeningTag :: DecodeLimits -> ScanState -> Text -> Either AMXDecodeDefect ()
scanOpeningTag limits state input = do
  let elementCount = scanElements state + 1
      depth = scanDepth state + 1
  checkLimit XmlElementsLimitExceeded (maximumXmlElements limits) elementCount
  checkLimit XmlDepthLimitExceeded (maximumXmlDepth limits) depth
  scanTag
    limits
    state {scanDepth = depth, scanElements = elementCount}
    Nothing
    input

scanTag ::
     DecodeLimits
  -> ScanState
  -> Maybe Char
  -> Text
  -> Either AMXDecodeDefect ()
scanTag limits !state !lastSignificant input =
  case Text.uncons input of
    Nothing -> Right ()
    Just ('>', rest) ->
      let nextState =
            case lastSignificant of
              Just '/' -> state {scanDepth = max 0 (scanDepth state - 1)}
              _ -> state
       in scanDocument limits nextState rest
    Just (quote, rest)
      | quote == '\'' || quote == '"' -> do
        remaining <- scanQuotedAttribute quote rest
        scanTag limits state (Just quote) remaining
    Just ('=', rest) -> do
      state' <- addAttribute limits state
      scanTag limits state' (Just '=') rest
    Just ('&', rest) -> do
      remaining <- scanEntity rest
      scanTag limits state (Just '&') remaining
    Just (character, rest) ->
      scanTag
        limits
        state
        (if isXmlSpace character
           then lastSignificant
           else Just character)
        rest

scanQuotedAttribute :: Char -> Text -> Either AMXDecodeDefect Text
scanQuotedAttribute quote = go
  where
    go remaining =
      case Text.uncons remaining of
        Nothing -> Right Text.empty
        Just (character, after)
          | character == quote -> Right after
          | character == '&' -> scanEntity after >>= go
          | otherwise -> go after

scanEntity :: Text -> Either AMXDecodeDefect Text
scanEntity input
  | Just rest <- Text.stripPrefix "amp;" input = Right rest
  | Just rest <- Text.stripPrefix "lt;" input = Right rest
  | Just rest <- Text.stripPrefix "gt;" input = Right rest
  | Just rest <- Text.stripPrefix "quot;" input = Right rest
  | Just rest <- Text.stripPrefix "apos;" input = Right rest
  | Just numeric <- Text.stripPrefix "#" input = scanNumericEntity numeric
  | otherwise = Left UnsafeXml

scanNumericEntity :: Text -> Either AMXDecodeDefect Text
scanNumericEntity input
  | Just hexadecimal <- Text.stripPrefix "x" input =
    scanEntityDigits isHexDigit False hexadecimal
  | Just hexadecimal <- Text.stripPrefix "X" input =
    scanEntityDigits isHexDigit False hexadecimal
  | otherwise = scanEntityDigits isDecimalDigit False input

scanEntityDigits ::
     (Char -> Bool) -> Bool -> Text -> Either AMXDecodeDefect Text
scanEntityDigits validDigit !observedDigit input =
  case Text.uncons input of
    Just (';', rest)
      | observedDigit -> Right rest
    Just (character, rest)
      | validDigit character -> scanEntityDigits validDigit True rest
    _ -> Left UnsafeXml

isDecimalDigit :: Char -> Bool
isDecimalDigit character = character `elem` ['0' .. '9']

isHexDigit :: Char -> Bool
isHexDigit character =
  isDecimalDigit character
    || character `elem` ['a' .. 'f']
    || character `elem` ['A' .. 'F']

addAttribute :: DecodeLimits -> ScanState -> Either AMXDecodeDefect ScanState
addAttribute limits state = do
  let observed = scanAttributes state + 1
  checkLimit XmlAttributesLimitExceeded (maximumXmlAttributes limits) observed
  pure state {scanAttributes = observed}

addTextCharacters ::
     DecodeLimits -> Int -> ScanState -> Either AMXDecodeDefect ScanState
addTextCharacters limits added state = do
  let observed = scanTextCharacters state + added
  checkLimit XmlTextLimitExceeded (maximumXmlTextCharacters limits) observed
  pure state {scanTextCharacters = observed}

checkLimit ::
     (Int -> Int -> AMXDecodeDefect) -> Int -> Int -> Either AMXDecodeDefect ()
checkLimit defect limit observed
  | observed <= limit = Right ()
  | otherwise = Left (defect limit observed)

isXmlSpace :: Char -> Bool
isXmlSpace character = character `elem` [' ', '\t', '\r', '\n']
