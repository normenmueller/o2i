module Main where

import qualified O2I.Cli.Test.Options as Options
import qualified O2I.Cli.Test.Output as Output
import qualified O2I.Cli.Test.Process as Process
import qualified O2I.Cli.Test.Scanner as Scanner
import qualified O2I.Cli.Test.Static as Static
import qualified O2I.Cli.Test.TerminalText as TerminalText
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "o2i-cli"
       [ Options.tests
       , Output.tests
       , Process.tests
       , Scanner.tests
       , Static.tests
       , TerminalText.tests
       ])
