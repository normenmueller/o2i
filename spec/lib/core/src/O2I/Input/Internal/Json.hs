{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | One lossless, duplicate-aware JSON boundary for Core-owned input.
--
-- Paths are persistent reverse token chains. Descending into one member or
-- array item is therefore constant work and shares the complete parent path.
-- RFC 6901 text is materialized only for actual evidence.
module O2I.Input.Internal.Json
  ( Utf8Failure(..)
  , Utf8Json
  , decodeUtf8Json
  , JsonSyntaxFailure(..)
  , JsonPath
  , rootJsonPath
  , appendJsonMember
  , appendJsonIndex
  , jsonPathText
  , JsonValue(..)
  , JsonString
  , jsonStringText
  , JsonMalformedScalar(..)
  , jsonStringMalformedScalars
  , JsonNode
  , jsonNodePath
  , jsonNodeValue
  , JsonObject
  , ParsedJson
  , parseJsonSyntax
  , JsonPointer
  , jsonPointerText
  , DuplicateFreeJson
  , rejectDuplicateMembers
  , duplicateFreeNode
  , JsonWork(..)
  , parseJsonSyntaxWithWork
  ) where

import Data.ByteString (ByteString)
import Data.Char (chr, digitToInt, isDigit, ord)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric.Natural (Natural)

-- | The exact source bytes are not valid UTF-8.
data Utf8Failure =
  InvalidUtf8
  deriving (Eq, Ord, Show)

-- | UTF-8 text admitted to the JSON-syntax phase.
newtype Utf8Json =
  Utf8Json Text
  deriving (Eq, Show)

-- | Decode exact UTF-8 without replacement.
decodeUtf8Json :: ByteString -> Either Utf8Failure Utf8Json
decodeUtf8Json bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left InvalidUtf8
    Right value -> Right (Utf8Json value)

-- | The admitted UTF-8 text is not exactly one complete JSON value.
data JsonSyntaxFailure =
  InvalidJsonSyntax
  deriving (Eq, Ord, Show)

-- | Persistent reverse sequence of raw RFC 6901 reference tokens.
--
-- The newest token is stored at the root of the value. Construction never
-- copies or renders an ancestor path. Object-member and array-index syntax
-- share this one identity: member @"0"@ and index @0@ therefore denote the
-- same pointer token before rendering and global deduplication.
data JsonPath
  = JsonRoot
  | JsonToken !Text !JsonPath
  deriving (Eq, Show)

-- Ordering follows the root-to-leaf raw token sequence even though storage is
-- reversed. No token is escaped or pointer text materialized for comparison.
instance Ord JsonPath where
  compare left right =
    case (left, right) of
      (JsonRoot, JsonRoot) -> EQ
      (JsonRoot, JsonToken _ _) -> LT
      (JsonToken _ _, JsonRoot) -> GT
      (JsonToken leftToken leftParent, JsonToken rightToken rightParent) ->
        case compare leftParent rightParent of
          EQ -> compare leftToken rightToken
          parentOrdering -> parentOrdering

rootJsonPath :: JsonPath
rootJsonPath = JsonRoot

appendJsonMember :: JsonPath -> Text -> JsonPath
appendJsonMember parent member = JsonToken member parent

appendJsonIndex :: JsonPath -> Int -> JsonPath
appendJsonIndex parent index = JsonToken (Text.pack (show index)) parent

-- | Render one path exactly as RFC 6901.
jsonPathText :: JsonPath -> Text
jsonPathText = fst . renderJsonPath

-- The difference list preserves root-to-leaf output order while visiting the
-- reverse structural path and every member token once.
renderJsonPath :: JsonPath -> (Text, Int)
renderJsonPath path =
  let (chunks, tokenVisits) = collect path
   in (Text.concat (chunks []), tokenVisits)
  where
    collect current =
      case current of
        JsonRoot -> (id, 0)
        JsonToken token parent ->
          let (parentChunks, parentVisits) = collect parent
              (escaped, tokenVisits) = escapePointerToken token
           in (parentChunks . (("/" <> escaped) :), parentVisits + tokenVisits)

escapePointerToken :: Text -> (Text, Int)
escapePointerToken member =
  let (chunks, visits) = collect member [] 0
   in (Text.concat (reverse chunks), visits)
  where
    collect remaining chunks visits =
      case Text.uncons remaining of
        Nothing -> (chunks, visits)
        Just (value, rest) ->
          let escaped =
                case value of
                  '~' -> "~0"
                  '/' -> "~1"
                  _ -> Text.singleton value
           in collect rest (escaped : chunks) (visits + 1)

-- | Lossless JSON value needed by the closed typed decoder.
--
-- Numeric lexemes are retained exactly after JSON-grammar validation. Closed
-- payload decoders decide whether one admitted site requires an integer or
-- another numeric schema without reparsing the source document.
data JsonValue
  = JsonObjectValue !JsonObject
  | JsonArrayValue ![JsonNode]
  | JsonStringValue !JsonString
  | JsonNumberValue !Text
  | JsonBooleanValue !Bool
  | JsonNullValue
  deriving (Eq, Show)

-- | Decoded JSON string plus malformed UTF-16 escape evidence which cannot be
-- represented losslessly by strict 'Text'.
data JsonString =
  JsonString !Text ![JsonMalformedScalar]
  deriving (Eq, Show)

jsonStringText :: JsonString -> Text
jsonStringText (JsonString value _) = value

-- | Exact zero-based decoded-scalar position and surrogate code point.
data JsonMalformedScalar =
  JsonMalformedScalar !Natural !Natural
  deriving (Eq, Ord, Show)

jsonStringMalformedScalars :: JsonString -> [JsonMalformedScalar]
jsonStringMalformedScalars (JsonString _ malformed) = malformed

-- | Object members after syntax parsing. Duplicate members remain separately
-- evidenced and must be rejected before this last-value map is consumed.
type JsonObject = Map Text JsonNode

-- | One parsed value with its shared structural path.
data JsonNode =
  JsonNode !JsonPath !JsonValue
  deriving (Eq, Show)

jsonNodePath :: JsonNode -> JsonPath
jsonNodePath (JsonNode path _) = path

jsonNodeValue :: JsonNode -> JsonValue
jsonNodeValue (JsonNode _ value) = value

-- | Exact private work evidence for the single parser traversal.
--
-- Source scalar visits equal the consumed UTF-8 text length for every
-- successful parse. Path extensions count constant-work persistent nodes.
-- Distinct duplicate retentions count globally distinct structural evidence
-- paths. Duplicate pointer renderings count those paths after deduplication,
-- and pointer token scalar visits make their unavoidable output cost explicit.
data JsonWork = JsonWork
  { jsonSourceScalarVisits :: !Int
  , jsonDecodedScalarRetentions :: !Int
  , jsonValueVisits :: !Int
  , jsonPathExtensions :: !Int
  , jsonDistinctDuplicateRetentions :: !Int
  , jsonDuplicatePointerRenderings :: !Int
  , jsonDuplicatePointerTokenScalarVisits :: !Int
  } deriving (Eq, Show)

emptyWork :: JsonWork
emptyWork = JsonWork 0 0 0 0 0 0 0

-- Difference-list accumulation makes every local duplicate candidate and
-- every subtree combination constant work. After the single parse traversal,
-- one structural set removes equal paths before any RFC 6901 text is rendered.
newtype DuplicatePaths =
  DuplicatePaths ([JsonPath] -> [JsonPath])

noDuplicatePaths :: DuplicatePaths
noDuplicatePaths = DuplicatePaths id

oneDuplicatePath :: JsonPath -> DuplicatePaths
oneDuplicatePath path = DuplicatePaths (path :)

appendDuplicatePaths :: DuplicatePaths -> DuplicatePaths -> DuplicatePaths
appendDuplicatePaths (DuplicatePaths left) (DuplicatePaths right) =
  DuplicatePaths (left . right)

duplicatePathList :: DuplicatePaths -> [JsonPath]
duplicatePathList (DuplicatePaths difference) = difference []

data Cursor = Cursor
  { cursorInput :: !Text
  , cursorWork :: !JsonWork
  }

data ParsedJson =
  ParsedJson !JsonNode ![JsonPointer]
  deriving (Eq, Show)

-- | Parse exactly one JSON value with one lossless traversal.
parseJsonSyntax :: Utf8Json -> Either JsonSyntaxFailure ParsedJson
parseJsonSyntax source = fst <$> parseJsonSyntaxWithWork source

-- | Parse while returning private exact work evidence for focused tests.
parseJsonSyntaxWithWork ::
     Utf8Json -> Either JsonSyntaxFailure (ParsedJson, JsonWork)
parseJsonSyntaxWithWork (Utf8Json source) = do
  start <- skipWhitespace (Cursor source emptyWork)
  (node, duplicatePaths, afterValue) <- parseValue rootJsonPath start
  end <- skipWhitespace afterValue
  if Text.null (cursorInput end)
    then let distinctPaths =
               Set.toList (Set.fromList (duplicatePathList duplicatePaths))
             rendered = map renderDuplicate distinctPaths
             pointers = sort (map fst rendered)
             renderings = length rendered
             tokenVisits = sum (map snd rendered)
             work =
               (cursorWork end)
                 { jsonDistinctDuplicateRetentions = renderings
                 , jsonDuplicatePointerRenderings = renderings
                 , jsonDuplicatePointerTokenScalarVisits = tokenVisits
                 }
          in Right (ParsedJson node pointers, work)
    else Left InvalidJsonSyntax

-- | RFC 6901 pointer of one duplicate object-member site.
newtype JsonPointer =
  JsonPointer Text
  deriving (Eq, Ord, Show)

jsonPointerText :: JsonPointer -> Text
jsonPointerText (JsonPointer value) = value

renderDuplicate :: JsonPath -> (JsonPointer, Int)
renderDuplicate path =
  let (pointer, tokenVisits) = renderJsonPath path
   in (JsonPointer pointer, tokenVisits)

newtype DuplicateFreeJson =
  DuplicateFreeJson JsonNode
  deriving (Eq, Show)

rejectDuplicateMembers ::
     ParsedJson -> Either (NonEmpty JsonPointer) DuplicateFreeJson
rejectDuplicateMembers (ParsedJson node pointers) =
  case pointers of
    first:rest -> Left (first :| rest)
    [] -> Right (DuplicateFreeJson node)

duplicateFreeNode :: DuplicateFreeJson -> JsonNode
duplicateFreeNode (DuplicateFreeJson node) = node

parseValue ::
     JsonPath
  -> Cursor
  -> Either JsonSyntaxFailure (JsonNode, DuplicatePaths, Cursor)
parseValue path cursor = do
  (first, afterPeek) <- peekChar cursor
  let visited = incrementValueVisit afterPeek
  case first of
    '"' -> do
      (value, after) <- parseString visited
      Right (JsonNode path (JsonStringValue value), noDuplicatePaths, after)
    '{' -> parseObject path visited
    '[' -> parseArray path visited
    't' -> literal path "true" (JsonBooleanValue True) visited
    'f' -> literal path "false" (JsonBooleanValue False) visited
    'n' -> literal path "null" JsonNullValue visited
    '-' -> parseNumber path visited
    value
      | isDigit value -> parseNumber path visited
      | otherwise -> Left InvalidJsonSyntax

incrementValueVisit :: Cursor -> Cursor
incrementValueVisit cursor =
  cursor
    { cursorWork =
        (cursorWork cursor)
          {jsonValueVisits = jsonValueVisits (cursorWork cursor) + 1}
    }

parseObject ::
     JsonPath
  -> Cursor
  -> Either JsonSyntaxFailure (JsonNode, DuplicatePaths, Cursor)
parseObject path cursor = do
  afterOpen <- expectChar '{' cursor
  start <- skipWhitespace afterOpen
  case peekMaybe start of
    Just '}' -> do
      end <- expectChar '}' start
      Right (JsonNode path (JsonObjectValue Map.empty), noDuplicatePaths, end)
    _ -> members Set.empty Set.empty Map.empty noDuplicatePaths start
  where
    members !seen !duplicated !object !duplicates current = do
      (member, afterMember) <- parseKey current
      afterKey <- skipWhitespace afterMember
      afterColon <- expectChar ':' afterKey
      beforeValue <- skipWhitespace afterColon
      let memberPath = appendJsonMember path member
          withPath = incrementPathExtension beforeValue
      (value, nested, afterValue) <- parseValue memberPath withPath
      let alreadySeen = Set.member member seen
          firstDuplicate = alreadySeen && Set.notMember member duplicated
          duplicates' =
            if firstDuplicate
              then duplicates
                     `appendDuplicatePaths` nested
                     `appendDuplicatePaths` oneDuplicatePath memberPath
              else duplicates `appendDuplicatePaths` nested
          duplicated' =
            if firstDuplicate
              then Set.insert member duplicated
              else duplicated
          object' = Map.insert member value object
          seen' = Set.insert member seen
      afterSpace <- skipWhitespace afterValue
      case peekMaybe afterSpace of
        Just ',' -> do
          afterComma <- expectChar ',' afterSpace >>= skipWhitespace
          members seen' duplicated' object' duplicates' afterComma
        Just '}' -> do
          end <- expectChar '}' afterSpace
          Right (JsonNode path (JsonObjectValue object'), duplicates', end)
        _ -> Left InvalidJsonSyntax

parseArray ::
     JsonPath
  -> Cursor
  -> Either JsonSyntaxFailure (JsonNode, DuplicatePaths, Cursor)
parseArray path cursor = do
  afterOpen <- expectChar '[' cursor
  start <- skipWhitespace afterOpen
  case peekMaybe start of
    Just ']' -> do
      end <- expectChar ']' start
      Right (JsonNode path (JsonArrayValue []), noDuplicatePaths, end)
    _ -> items 0 [] noDuplicatePaths start
  where
    items !index values duplicates current = do
      let itemPath = appendJsonIndex path index
          withPath = incrementPathExtension current
      (value, nested, afterValue) <- parseValue itemPath withPath
      afterSpace <- skipWhitespace afterValue
      case peekMaybe afterSpace of
        Just ',' -> do
          afterComma <- expectChar ',' afterSpace >>= skipWhitespace
          items
            (index + 1)
            (value : values)
            (duplicates `appendDuplicatePaths` nested)
            afterComma
        Just ']' -> do
          end <- expectChar ']' afterSpace
          Right
            ( JsonNode path (JsonArrayValue (reverse (value : values)))
            , duplicates `appendDuplicatePaths` nested
            , end)
        _ -> Left InvalidJsonSyntax

incrementPathExtension :: Cursor -> Cursor
incrementPathExtension cursor =
  cursor
    { cursorWork =
        (cursorWork cursor)
          {jsonPathExtensions = jsonPathExtensions (cursorWork cursor) + 1}
    }

parseKey :: Cursor -> Either JsonSyntaxFailure (Text, Cursor)
parseKey cursor = do
  (value, after) <- parseString cursor
  case jsonStringMalformedScalars value of
    [] -> Right (jsonStringText value, after)
    _ -> Left InvalidJsonSyntax

data DecodedScalar
  = UnicodeScalar !Char
  | MalformedSurrogate !Int

parseString :: Cursor -> Either JsonSyntaxFailure (JsonString, Cursor)
parseString cursor = do
  afterOpen <- expectChar '"' cursor
  collect [] afterOpen
  where
    collect values current = do
      (value, afterValue) <- takeChar current
      case value of
        '"' ->
          let decoded = reverse values
           in Right
                ( decodedJsonString decoded
                , retainDecoded (length decoded) afterValue)
        '\\' -> do
          (escaped, afterEscape) <- parseEscape afterValue
          collect (escaped ++ values) afterEscape
        _
          | ord value < 0x20 -> Left InvalidJsonSyntax
          | otherwise -> collect (UnicodeScalar value : values) afterValue

decodedJsonString :: [DecodedScalar] -> JsonString
decodedJsonString values =
  JsonString
    (Text.pack (map retainedChar values))
    [ JsonMalformedScalar index (fromIntegral codePoint)
    | (index, MalformedSurrogate codePoint) <- zip [0 ..] values
    ]
  where
    retainedChar value =
      case value of
        UnicodeScalar scalar -> scalar
        MalformedSurrogate _ -> '\xfffd'

parseEscape :: Cursor -> Either JsonSyntaxFailure ([DecodedScalar], Cursor)
parseEscape cursor = do
  (value, after) <- takeChar cursor
  case value of
    '"' -> Right ([UnicodeScalar '"'], after)
    '\\' -> Right ([UnicodeScalar '\\'], after)
    '/' -> Right ([UnicodeScalar '/'], after)
    'b' -> Right ([UnicodeScalar '\b'], after)
    'f' -> Right ([UnicodeScalar '\f'], after)
    'n' -> Right ([UnicodeScalar '\n'], after)
    'r' -> Right ([UnicodeScalar '\r'], after)
    't' -> Right ([UnicodeScalar '\t'], after)
    'u' -> parseUnicodeEscape after
    _ -> Left InvalidJsonSyntax

parseUnicodeEscape ::
     Cursor -> Either JsonSyntaxFailure ([DecodedScalar], Cursor)
parseUnicodeEscape cursor = do
  (firstUnit, afterFirst) <- parseHexUnit cursor
  collectUnits [firstUnit] afterFirst
  where
    collectUnits reversedUnits current
      | "\\u" `Text.isPrefixOf` cursorInput current = do
        afterSlash <- expectChar '\\' current
        afterU <- expectChar 'u' afterSlash
        (unit, afterUnit) <- parseHexUnit afterU
        collectUnits (unit : reversedUnits) afterUnit
      | otherwise =
        Right (reverse (decodeUnits (reverse reversedUnits)), current)
    decodeUnits units =
      case units of
        high:low:remaining
          | isHighSurrogate high && isLowSurrogate low ->
            UnicodeScalar (combineSurrogates high low) : decodeUnits remaining
        unit:remaining
          | isHighSurrogate unit || isLowSurrogate unit ->
            MalformedSurrogate unit : decodeUnits remaining
          | otherwise -> UnicodeScalar (chr unit) : decodeUnits remaining
        [] -> []

parseHexUnit :: Cursor -> Either JsonSyntaxFailure (Int, Cursor)
parseHexUnit cursor = do
  (a, afterA) <- takeHex cursor
  (b, afterB) <- takeHex afterA
  (c, afterC) <- takeHex afterB
  (d, afterD) <- takeHex afterC
  Right (a * 4096 + b * 256 + c * 16 + d, afterD)

takeHex :: Cursor -> Either JsonSyntaxFailure (Int, Cursor)
takeHex cursor = do
  (value, after) <- takeChar cursor
  if isHex value
    then Right (digitToInt value, after)
    else Left InvalidJsonSyntax
  where
    isHex value =
      (value >= '0' && value <= '9')
        || (value >= 'a' && value <= 'f')
        || (value >= 'A' && value <= 'F')

isHighSurrogate :: Int -> Bool
isHighSurrogate value = value >= 0xd800 && value <= 0xdbff

isLowSurrogate :: Int -> Bool
isLowSurrogate value = value >= 0xdc00 && value <= 0xdfff

combineSurrogates :: Int -> Int -> Char
combineSurrogates high low =
  chr (0x10000 + (high - 0xd800) * 0x400 + low - 0xdc00)

retainDecoded :: Int -> Cursor -> Cursor
retainDecoded count cursor =
  cursor
    { cursorWork =
        (cursorWork cursor)
          { jsonDecodedScalarRetentions =
              jsonDecodedScalarRetentions (cursorWork cursor) + count
          }
    }

literal ::
     JsonPath
  -> Text
  -> JsonValue
  -> Cursor
  -> Either JsonSyntaxFailure (JsonNode, DuplicatePaths, Cursor)
literal path expected value cursor = do
  after <- consumeExact expected cursor
  Right (JsonNode path value, noDuplicatePaths, after)

parseNumber ::
     JsonPath
  -> Cursor
  -> Either JsonSyntaxFailure (JsonNode, DuplicatePaths, Cursor)
parseNumber path cursor = do
  afterSign <- consumeOptional '-' cursor
  afterInteger <- parseInteger afterSign
  afterFraction <- parseFraction afterInteger
  afterExponent <- parseExponent afterFraction
  Right
    ( JsonNode path (JsonNumberValue (consumedLexeme cursor afterExponent))
    , noDuplicatePaths
    , afterExponent)

consumedLexeme :: Cursor -> Cursor -> Text
consumedLexeme before after =
  Text.take
    (jsonSourceScalarVisits (cursorWork after)
       - jsonSourceScalarVisits (cursorWork before))
    (cursorInput before)

parseInteger :: Cursor -> Either JsonSyntaxFailure Cursor
parseInteger cursor =
  case peekMaybe cursor of
    Just '0' -> expectChar '0' cursor
    Just value
      | value >= '1' && value <= '9' -> do
        afterFirst <- snd <$> takeChar cursor
        consumeWhile isDigit afterFirst
    _ -> Left InvalidJsonSyntax

parseFraction :: Cursor -> Either JsonSyntaxFailure Cursor
parseFraction cursor =
  case peekMaybe cursor of
    Just '.' -> do
      afterDot <- expectChar '.' cursor
      requireDigits afterDot
    _ -> Right cursor

parseExponent :: Cursor -> Either JsonSyntaxFailure Cursor
parseExponent cursor =
  case peekMaybe cursor of
    Just 'e' -> exponentAfterMarker cursor
    Just 'E' -> exponentAfterMarker cursor
    _ -> Right cursor
  where
    exponentAfterMarker current = do
      afterMarker <- snd <$> takeChar current
      afterSign <-
        case peekMaybe afterMarker of
          Just '+' -> expectChar '+' afterMarker
          Just '-' -> expectChar '-' afterMarker
          _ -> Right afterMarker
      requireDigits afterSign

requireDigits :: Cursor -> Either JsonSyntaxFailure Cursor
requireDigits cursor =
  case peekMaybe cursor of
    Just value
      | isDigit value -> consumeWhile isDigit cursor
    _ -> Left InvalidJsonSyntax

consumeWhile :: (Char -> Bool) -> Cursor -> Either JsonSyntaxFailure Cursor
consumeWhile predicate cursor =
  case peekMaybe cursor of
    Just value
      | predicate value -> snd <$> takeChar cursor >>= consumeWhile predicate
    _ -> Right cursor

consumeOptional :: Char -> Cursor -> Either JsonSyntaxFailure Cursor
consumeOptional expected cursor =
  case peekMaybe cursor of
    Just value
      | value == expected -> expectChar expected cursor
    _ -> Right cursor

consumeExact :: Text -> Cursor -> Either JsonSyntaxFailure Cursor
consumeExact expected cursor =
  Text.foldl'
    (\result value -> result >>= expectChar value)
    (Right cursor)
    expected

skipWhitespace :: Cursor -> Either JsonSyntaxFailure Cursor
skipWhitespace = consumeWhile isJsonWhitespace

isJsonWhitespace :: Char -> Bool
isJsonWhitespace value =
  value == ' ' || value == '\t' || value == '\n' || value == '\r'

peekMaybe :: Cursor -> Maybe Char
peekMaybe = fmap fst . Text.uncons . cursorInput

peekChar :: Cursor -> Either JsonSyntaxFailure (Char, Cursor)
peekChar cursor =
  case peekMaybe cursor of
    Nothing -> Left InvalidJsonSyntax
    Just value -> Right (value, cursor)

expectChar :: Char -> Cursor -> Either JsonSyntaxFailure Cursor
expectChar expected cursor = do
  (actual, after) <- takeChar cursor
  if actual == expected
    then Right after
    else Left InvalidJsonSyntax

takeChar :: Cursor -> Either JsonSyntaxFailure (Char, Cursor)
takeChar cursor =
  case Text.uncons (cursorInput cursor) of
    Nothing -> Left InvalidJsonSyntax
    Just (value, remaining) ->
      Right
        ( value
        , cursor
            { cursorInput = remaining
            , cursorWork =
                (cursorWork cursor)
                  { jsonSourceScalarVisits =
                      jsonSourceScalarVisits (cursorWork cursor) + 1
                  }
            })
