-- | Output-intent scanner that is independent of successful parsing.
--
-- The scanner recognizes only admitted command paths, masks their exact
-- positional and value operands, and therefore never mistakes escaped data
-- for output intent. Unknown paths deliberately use the root scanner.
module O2I.Cli.Scanner
  ( scanOutputMode
  ) where

import Data.List (isPrefixOf)
import O2I.Cli.Options (OutputMode(..))

data ScanSpec = ScanSpec
  { scanPathLength :: Int
  , scanPositionalCount :: Int
  , scanValueOptions :: [String]
  }

-- | Select JSON exactly when an unmasked @--json@ or malformed
-- @--json=...@ token appears. Exact help and version invocations remain human.
scanOutputMode :: [String] -> OutputMode
scanOutputMode ["--help"] = HumanOutput
scanOutputMode ["--version"] = HumanOutput
scanOutputMode arguments =
  case commandSpec arguments of
    Nothing -> detectJson arguments
    Just spec ->
      scanKnown
        (scanPositionalCount spec)
        (scanValueOptions spec)
        (drop (scanPathLength spec) arguments)

scanKnown :: Int -> [String] -> [String] -> OutputMode
scanKnown positionalCount valueOptions = go positionalCount
  where
    go _ [] = HumanOutput
    go remaining ("--":tokens) = detectJson (drop remaining tokens)
    go remaining (token:tokens)
      | token `elem` valueOptions =
        case tokens of
          [] -> HumanOutput
          _:rest -> go remaining rest
      | token == "--json" = JsonOutput
      | token `elem` ["--verbose", "--debug", "--help"] = go remaining tokens
      | remaining > 0 = go (remaining - 1) tokens
      | jsonIntent token = JsonOutput
      | otherwise = go remaining tokens

detectJson :: [String] -> OutputMode
detectJson tokens =
  if any jsonIntent tokens
    then JsonOutput
    else HumanOutput

jsonIntent :: String -> Bool
jsonIntent token = token == "--json" || "--json=" `isPrefixOf` token

commandSpec :: [String] -> Maybe ScanSpec
commandSpec arguments =
  case arguments of
    "adapters":_ -> Just (simple 1 0 [])
    "profiles":_ -> Just (simple 1 0 [])
    "views":_ -> Just (simple 1 1 ["--adapter"])
    "qualification-subjects":_ -> Just (model 1 ["--supplement"])
    "validate":_ -> Just (model 1 ["--level", "--supplement"])
    "trace":_ -> Just (model 1 [])
    "qualify":_ -> Just (model 1 ["--strategy-id", "--need-id", "--supplement"])
    "readiness":_ -> Just (model 1 ["--input", "--supplement"])
    "assess":_ -> Just (model 1 ["--input", "--supplement"])
    "rules":"operation":_ -> Just (simple 2 0 [])
    "rules":"core":_ -> Just (simple 2 0 [])
    "rules":"adapter":_ -> Just (simple 2 1 [])
    "rules":"profile":_ -> Just (simple 2 1 [])
    "explain":"operation":_ -> Just (simple 2 1 [])
    "explain":"core":_ -> Just (simple 2 1 [])
    "explain":"adapter":_ -> Just (simple 2 2 [])
    "explain":"profile":_ -> Just (simple 2 2 [])
    _ -> Nothing

simple :: Int -> Int -> [String] -> ScanSpec
simple = ScanSpec

model :: Int -> [String] -> ScanSpec
model positional extras =
  ScanSpec 1 positional (["--view", "--view-id", "--adapter"] <> extras)
