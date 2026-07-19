{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Input
  ( tests
  ) where

import O2I.Cli.Input
import O2I.Cli.Options
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "input"
    [ testCase
        "dash selects standard input"
        (inputSourceFor "-" @?= StandardInput)
    , testCase
        "ordinary path remains a path"
        (inputSourceFor "model.archimate" @?= InputPath "model.archimate")
    , testCase "name selector is preserved" nameSelector
    , testCase "identifier selector is preserved" identifierSelector
    , testCase "supplemental inputs remain absent" absentInputs
    ]

nameSelector :: Assertion
nameSelector =
  viewSelector (inspectionRequestFor (options (ViewName "Exact")))
    @?= ViewByName "Exact"

identifierSelector :: Assertion
identifierSelector =
  viewSelector (inspectionRequestFor (options (ViewIdentifier "id-view")))
    @?= ViewById "id-view"

absentInputs :: Assertion
absentInputs =
  inspectionInputs (inspectionRequestFor (options (ViewName "Exact")))
    @?= InspectionInputs
          { strategyInput = Absent
          , readinessInput = Absent
          , evidenceInput = Absent
          }

options :: ViewSelection -> InspectOptions
options selection =
  InspectOptions
    { inspectModelToken = "model.archimate"
    , inspectViewSelection = selection
    , inspectVerbosity = NormalVerbosity
    , inspectOutputMode = HumanOutput
    }
