{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Options
  ( tests
  ) where

import O2I.Cli.Options
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "options"
    [ accepted "root help" ["--help"] (HelpCommand Nothing)
    , accepted "root version" ["--version"] VersionCommand
    , acceptedWith "adapter discovery" ["adapters", "--json"] isAdapters
    , acceptedWith
        "operation rules"
        ["rules", "operation"]
        (== RulesCommand OperationRules normalReport)
    , acceptedWith
        "adapter explanation operands"
        ["explain", "adapter", "amx", "native.root"]
        (== ExplainCommand (AdapterRules "amx") "native.root" normalReport)
    , acceptedWith
        "semantic validation supplements"
        [ "validate"
        , "model.archimate"
        , "--view-id"
        , "view-1"
        , "--level"
        , "semantics"
        , "--supplement"
        , "facts.json"
        ]
        isSemanticValidate
    , acceptedWith
        "qualification repeated selector categories"
        [ "qualify"
        , "model.archimate"
        , "--view"
        , "Scope"
        , "--strategy-id"
        , "s1"
        , "--strategy-id"
        , "s2"
        , "--need-id"
        , "n1"
        ]
        isQualify
    , acceptedWith
        "escaped option-like model operand"
        ["views", "--", "--json"]
        isEscapedView
    , acceptedWith
        "unescaped malformed-option-like model operand"
        ["views", "--json=true"]
        isOptionLookingView
    , rejected
        "both View selectors"
        ["trace", "m", "--view", "A", "--view-id", "v"]
    , rejected "missing View selector" ["trace", "m"]
    , rejected
        "supplement before semantics"
        [ "validate"
        , "m"
        , "--view"
        , "A"
        , "--level"
        , "profile"
        , "--supplement"
        , "s"
        ]
    , rejected
        "duplicate Strategy selector"
        [ "qualify"
        , "m"
        , "--view"
        , "A"
        , "--strategy-id"
        , "s"
        , "--strategy-id"
        , "s"
        ]
    , rejected
        "multiple stdin sources"
        ["readiness", "-", "--view", "A", "--input", "-"]
    , rejected "name=value option" ["adapters", "--json=true"]
    , rejected "short option" ["adapters", "-j"]
    , rejected
        "repeated scalar"
        ["views", "m", "--adapter", "a", "--adapter", "a"]
    , rejected "options after marker" ["views", "--", "m", "--json"]
    ]

normalReport :: ReportOptions
normalReport = ReportOptions HumanOutput NormalVerbosity

isAdapters :: CliOptions -> Bool
isAdapters (AdaptersCommand (ReportOptions JsonOutput NormalVerbosity)) = True
isAdapters _ = False

isSemanticValidate :: CliOptions -> Bool
isSemanticValidate (ValidateCommand (ModelOptions "model.archimate" (ViewIdentifier "view-1") Nothing) SemanticsLevel ["facts.json"] _) =
  True
isSemanticValidate _ = False

isQualify :: CliOptions -> Bool
isQualify (QualifyCommand _ ["s1", "s2"] ["n1"] [] _) = True
isQualify _ = False

isEscapedView :: CliOptions -> Bool
isEscapedView (ViewsCommand "--json" Nothing _) = True
isEscapedView _ = False

isOptionLookingView :: CliOptions -> Bool
isOptionLookingView (ViewsCommand "--json=true" Nothing _) = True
isOptionLookingView _ = False

accepted :: String -> [String] -> CliOptions -> TestTree
accepted label arguments expected =
  testCase label (parseCliOptions arguments @?= Right expected)

acceptedWith :: String -> [String] -> (CliOptions -> Bool) -> TestTree
acceptedWith label arguments predicate =
  testCase label $ do
    parsed <- either (assertFailure . show) pure (parseCliOptions arguments)
    assertBool "unexpected parsed value" (predicate parsed)

rejected :: String -> [String] -> TestTree
rejected label arguments =
  testCase label
    $ case parseCliOptions arguments of
        Left _ -> pure ()
        Right parsed ->
          assertFailure ("unexpected parser success: " <> show parsed)
