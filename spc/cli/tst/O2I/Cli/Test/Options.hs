{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Options
  ( tests
  ) where

import O2I.Cli.Options
import Options.Applicative (ParserResult(..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "options"
    [ accepted
        "exact View name"
        ["inspect", "model.archimate", "--view", "O2I Reference"]
        (InspectCommand
           InspectOptions
             { inspectModelToken = "model.archimate"
             , inspectViewSelection = ViewName "O2I Reference"
             , inspectVerbosity = NormalVerbosity
             , inspectOutputMode = HumanOutput
             })
    , acceptedWith
        "stable View identifier"
        ["inspect", "model.archimate", "--view-id", "id-view"]
        ((== ViewIdentifier "id-view")
           . inspectViewSelection
           . inspectCommandOptions)
    , acceptedWith
        "stdin token"
        ["inspect", "-", "--view", "Scope"]
        ((== "-") . inspectModelToken . inspectCommandOptions)
    , acceptedWith
        "verbose"
        (baseArguments <> ["--verbose"])
        ((== VerboseVerbosity) . inspectVerbosity . inspectCommandOptions)
    , acceptedWith
        "debug"
        (baseArguments <> ["--debug"])
        ((== DebugVerbosity) . inspectVerbosity . inspectCommandOptions)
    , acceptedWith
        "JSON output"
        (baseArguments <> ["--json"])
        ((== JsonOutput) . inspectOutputMode . inspectCommandOptions)
    , accepted "build revision" ["--build-revision"] BuildRevisionCommand
    , rejected "missing command" []
    , rejected "missing selector" ["inspect", "model.archimate"]
    , rejected
        "both selectors"
        ["inspect", "model.archimate", "--view", "A", "--view-id", "id"]
    , rejected
        "both verbosity options"
        (baseArguments <> ["--verbose", "--debug"])
    , rejected "version subcommand" ["version"]
    , rejectedOption "format" "--format"
    , rejectedOption "through" "--through"
    , rejectedOption "no-color" "--no-color"
    ]

baseArguments :: [String]
baseArguments = ["inspect", "model.archimate", "--view", "A"]

accepted :: String -> [String] -> CliOptions -> TestTree
accepted label arguments expected =
  testCase
    label
    (case parseCliOptions arguments of
       Success actual -> actual @?= expected
       Failure _ -> assertFailure "expected parser success"
       CompletionInvoked _ -> assertFailure "expected parser success")

acceptedWith :: String -> [String] -> (CliOptions -> Bool) -> TestTree
acceptedWith label arguments predicate =
  testCase
    label
    (case parseCliOptions arguments of
       Success actual -> assertBool "unexpected parsed value" (predicate actual)
       Failure _ -> assertFailure "expected parser success"
       CompletionInvoked _ -> assertFailure "expected parser success")

rejected :: String -> [String] -> TestTree
rejected label arguments =
  testCase
    label
    (case parseCliOptions arguments of
       Failure _ -> pure ()
       Success _ -> assertFailure "unexpected parser success"
       CompletionInvoked _ -> assertFailure "unexpected completion")

rejectedOption :: String -> String -> TestTree
rejectedOption label option =
  rejected ("unsupported --" <> label) (baseArguments <> [option, "value"])
