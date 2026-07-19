{-# LANGUAGE OverloadedStrings #-}

-- | Total encoding of untrusted text for terminal-facing output.
module O2I.Cli.TerminalText
  ( terminalSafeText
  ) where

import Data.Char (ord, toUpper)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)

-- | Preserve readable text while making every terminal control visible.
-- Backslashes are doubled so control escapes cannot be confused with input.
terminalSafeText :: Text -> Text
terminalSafeText = Text.concatMap encodeCharacter

encodeCharacter :: Char -> Text
encodeCharacter character
  | character == '\\' = "\\\\"
  | terminalControl character = "\\u{" <> controlCode character <> "}"
  | otherwise = Text.singleton character

terminalControl :: Char -> Bool
terminalControl character =
  let code = ord character
   in code <= 0x1f || code == 0x7f || (code >= 0x80 && code <= 0x9f)

controlCode :: Char -> Text
controlCode character =
  Text.justifyRight 4 '0' (Text.pack (map toUpper (showHex (ord character) "")))
