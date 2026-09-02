module O2I.Cli.Test.Scanner
  ( tests
  ) where

import O2I.Cli.Options (OutputMode(..))
import O2I.Cli.Scanner (scanOutputMode)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), testCase)

tests :: TestTree
tests =
  testGroup
    "output-intent scanner"
    [ human "exact help is human" ["--help"]
    , human "exact version is human" ["--version"]
    , json "report flag" ["adapters", "--json"]
    , json "malformed report flag" ["adapters", "--json=true"]
    , human "fixed operand is masked" ["views", "--", "--json"]
    , human
        "unescaped option-looking fixed operand is masked"
        ["views", "--json=true"]
    , json
        "exact report flag remains unmasked before a fixed operand"
        ["views", "--json"]
    , human
        "value-option operand is masked"
        ["trace", "model", "--view", "--json"]
    , json
        "unmasked token after value operand selects JSON"
        ["trace", "model", "--view", "Scope", "--json=true"]
    , human
        "all escaped fixed operands are masked"
        ["explain", "adapter", "--", "--json", "--json=true"]
    , json "extra escaped token is unmasked" ["views", "--", "model", "--json"]
    , json "unknown path uses root scanner" ["unknown", "--view", "--json"]
    ]

human :: String -> [String] -> TestTree
human label arguments =
  testCase label (scanOutputMode arguments @?= HumanOutput)

json :: String -> [String] -> TestTree
json label arguments = testCase label (scanOutputMode arguments @?= JsonOutput)
