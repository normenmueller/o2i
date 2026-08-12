{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Duplicate-safe JSON decoding for Core-owned supplemental inputs.
--
-- This module deliberately separates UTF-8, JSON syntax, and duplicate-member
-- phases. Typed schema decoding may consume only t'DuplicateFreeJson'.
module O2I.Input.Internal.Json
  ( Utf8Failure(..)
  , Utf8Json
  , decodeUtf8Json
  , JsonSyntaxFailure(..)
  , ParsedJson
  , parseJsonSyntax
  , JsonPointer
  , jsonPointerText
  , DuplicateFreeJson
  , rejectDuplicateMembers
  , duplicateFreeValue
  ) where

import Data.Aeson (Value)
import Data.Aeson.Decoding (toEitherValue)
import Data.Aeson.Decoding.Text (textToTokens)
import Data.Aeson.Decoding.Tokens (TkArray(..), TkRecord(..), Tokens(..))
import qualified Data.Aeson.Key as Key
import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding

-- | The exact source bytes are not valid UTF-8.
data Utf8Failure =
  InvalidUtf8
  deriving (Eq, Ord, Show)

-- | UTF-8 text admitted to the JSON-syntax phase.
newtype Utf8Json =
  Utf8Json Text
  deriving (Eq, Show)

-- | Decode exact UTF-8 without replacement or BOM handling.
decodeUtf8Json :: ByteString -> Either Utf8Failure Utf8Json
decodeUtf8Json bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left InvalidUtf8
    Right value -> Right (Utf8Json value)

-- | The admitted UTF-8 text is not exactly one complete JSON value.
data JsonSyntaxFailure =
  InvalidJsonSyntax
  deriving (Eq, Ord, Show)

-- | One syntactically valid JSON value with every duplicate-member site.
data ParsedJson =
  ParsedJson !Value !(Set JsonPointer)
  deriving (Eq, Show)

-- | Parse exactly one JSON value and retain duplicate-member evidence.
--
-- Aeson's token stream preserves decoded object keys, including keys whose
-- source escape spellings differ. Conversion establishes complete JSON
-- syntax; the second traversal records duplicate members before any typed
-- decoder can observe Aeson's duplicate-collapsing object representation.
parseJsonSyntax :: Utf8Json -> Either JsonSyntaxFailure ParsedJson
parseJsonSyntax (Utf8Json source) = do
  let tokens = textToTokens source
  (value, remainder) <- mapSyntaxFailure (toEitherValue tokens)
  requireJsonWhitespace remainder
  (scannedRemainder, duplicates) <- scanValue rootPointer tokens
  requireJsonWhitespace scannedRemainder
  pure (ParsedJson value duplicates)

-- | RFC 6901 pointer of one duplicate object-member site.
newtype JsonPointer =
  JsonPointer Text
  deriving (Eq, Ord, Show)

-- | Project the canonical RFC 6901 representation.
jsonPointerText :: JsonPointer -> Text
jsonPointerText (JsonPointer value) = value

rootPointer :: JsonPointer
rootPointer = JsonPointer Text.empty

appendMember :: JsonPointer -> Text -> JsonPointer
appendMember (JsonPointer parent) member =
  JsonPointer (parent <> "/" <> escapePointerToken member)

appendIndex :: JsonPointer -> Int -> JsonPointer
appendIndex pointer = appendMember pointer . Text.pack . show

escapePointerToken :: Text -> Text
escapePointerToken = Text.replace "/" "~1" . Text.replace "~" "~0"

-- | JSON value proven to contain no duplicate object member.
newtype DuplicateFreeJson =
  DuplicateFreeJson Value
  deriving (Eq, Show)

-- | Admit only duplicate-free JSON and return every duplicate site together.
rejectDuplicateMembers ::
     ParsedJson -> Either (NonEmpty JsonPointer) DuplicateFreeJson
rejectDuplicateMembers (ParsedJson value duplicates) =
  case NonEmpty.nonEmpty (Set.toAscList duplicates) of
    Just sites -> Left sites
    Nothing -> Right (DuplicateFreeJson value)

-- | Project the value only after duplicate-member assessment has passed.
duplicateFreeValue :: DuplicateFreeJson -> Value
duplicateFreeValue (DuplicateFreeJson value) = value

scanValue ::
     JsonPointer
  -> Tokens continuation String
  -> Either JsonSyntaxFailure (continuation, Set JsonPointer)
scanValue pointer tokens =
  case tokens of
    TkLit _ remainder -> Right (remainder, Set.empty)
    TkText _ remainder -> Right (remainder, Set.empty)
    TkNumber _ remainder -> Right (remainder, Set.empty)
    TkArrayOpen array -> scanArray pointer 0 array
    TkRecordOpen record -> scanRecord pointer Set.empty record
    TkErr _ -> Left InvalidJsonSyntax

scanArray ::
     JsonPointer
  -> Int
  -> TkArray continuation String
  -> Either JsonSyntaxFailure (continuation, Set JsonPointer)
scanArray pointer !index array =
  case array of
    TkItem tokens -> do
      (continuation, nested) <- scanValue (appendIndex pointer index) tokens
      (remainder, following) <- scanArray pointer (index + 1) continuation
      pure (remainder, Set.union nested following)
    TkArrayEnd remainder -> Right (remainder, Set.empty)
    TkArrayErr _ -> Left InvalidJsonSyntax

scanRecord ::
     JsonPointer
  -> Set Text
  -> TkRecord continuation String
  -> Either JsonSyntaxFailure (continuation, Set JsonPointer)
scanRecord pointer !seen record =
  case record of
    TkPair key tokens -> do
      let member = Key.toText key
          memberPointer = appendMember pointer member
          duplicate =
            if Set.member member seen
              then Set.singleton memberPointer
              else Set.empty
      (continuation, nested) <- scanValue memberPointer tokens
      (remainder, following) <-
        scanRecord pointer (Set.insert member seen) continuation
      pure (remainder, Set.unions [duplicate, nested, following])
    TkRecordEnd remainder -> Right (remainder, Set.empty)
    TkRecordErr _ -> Left InvalidJsonSyntax

requireJsonWhitespace :: Text -> Either JsonSyntaxFailure ()
requireJsonWhitespace remainder
  | Text.all isJsonWhitespace remainder = Right ()
  | otherwise = Left InvalidJsonSyntax

isJsonWhitespace :: Char -> Bool
isJsonWhitespace value =
  value == ' ' || value == '\t' || value == '\n' || value == '\r'

mapSyntaxFailure :: Either String value -> Either JsonSyntaxFailure value
mapSyntaxFailure = either (const (Left InvalidJsonSyntax)) Right
