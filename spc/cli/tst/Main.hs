module Main where

import qualified O2I.Cli.Test.Input as Input
import qualified O2I.Cli.Test.Options as Options
import qualified O2I.Cli.Test.Output as Output
import qualified O2I.Cli.Test.Process as Process
import qualified O2I.Cli.Test.Schema as Schema
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "o2i-cli"
       [Options.tests, Input.tests, Output.tests, Schema.tests, Process.tests])
