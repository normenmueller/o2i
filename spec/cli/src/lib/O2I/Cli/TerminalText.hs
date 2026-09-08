{-# LANGUAGE OverloadedStrings #-}

-- | Total encoding of untrusted text for terminal-facing output.
module O2I.Cli.TerminalText
  ( terminalSafeText
  , terminalLiteral
  ) where

import Data.Char (ord, toUpper)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)

-- | Preserve readable text while making every terminal-sensitive scalar
-- visible. Reverse solidus and quotation mark use their lossless short form;
-- controls, line separators, and the closed Unicode 16.0 @Cf@ table use one
-- canonical upper-case scalar escape.
terminalSafeText :: Text -> Text
terminalSafeText = Text.concatMap encodeCharacter

-- | Place one untrusted scalar inside the human contract's quoted grammar.
terminalLiteral :: Text -> Text
terminalLiteral value = "\"" <> terminalSafeText value <> "\""

encodeCharacter :: Char -> Text
encodeCharacter character
  | character == '\\' = "\\\\"
  | character == '"' = "\\\""
  | escapedScalar character = "\\u{" <> scalarCode character <> "}"
  | otherwise = Text.singleton character

escapedScalar :: Char -> Bool
escapedScalar character =
  let code = ord character
   in code <= 0x1f
        || code == 0x7f
        || between 0x80 0x9f code
        || code == 0x2028
        || code == 0x2029
        || formatScalar code

formatScalar :: Int -> Bool
formatScalar code =
  code == 0x00ad
    || between 0x0600 0x0605 code
    || code == 0x061c
    || code == 0x06dd
    || code == 0x070f
    || between 0x0890 0x0891 code
    || code == 0x08e2
    || code == 0x180e
    || between 0x200b 0x200f code
    || between 0x202a 0x202e code
    || between 0x2060 0x2064 code
    || between 0x2066 0x206f code
    || code == 0xfeff
    || between 0xfff9 0xfffb code
    || code == 0x110bd
    || code == 0x110cd
    || between 0x13430 0x1343f code
    || between 0x1bca0 0x1bca3 code
    || between 0x1d173 0x1d17a code
    || code == 0xe0001
    || between 0xe0020 0xe007f code

between :: Int -> Int -> Int -> Bool
between lower upper value = value >= lower && value <= upper

scalarCode :: Char -> Text
scalarCode character =
  Text.justifyRight 4 '0' (Text.pack (map toUpper (showHex (ord character) "")))
