{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Static
  ( tests
  ) where

import Data.Text (Text)
import O2I.Cli.Options (CliError(..))
import O2I.Cli.Static
import O2I.Operation.Discovery.Rule
  ( RuleDiscoveryCompilation
  , foldRuleAuthority
  , foldRuleDiscoveryCompilation
  , ruleDiscoveryAuthority
  )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "static composition"
    [ testCase
        "selects Profile rules through public Operation folds"
        profileRules
    , testCase "rejects an unknown Profile reference" unknownProfile
    ]

profileRules :: Assertion
profileRules = do
  composition <- requireRight staticComposition
  compilation <-
    requireRight (staticProfileRules "o2i.archimate-profile@0.3" composition)
  selectedProfileReference compilation @?= Just "o2i.archimate-profile@0.3"

unknownProfile :: Assertion
unknownProfile = do
  composition <- requireRight staticComposition
  case staticProfileRules "not-a-profile@0" composition of
    Left failure -> cliErrorCode failure @?= "cli.argument.profile-ref"
    Right _ -> assertFailure "unknown Profile reference was selected"

selectedProfileReference :: RuleDiscoveryCompilation -> Maybe Text
selectedProfileReference =
  foldRuleDiscoveryCompilation
    (const Nothing)
    (foldRuleAuthority
       (const Nothing)
       (const Nothing)
       (\reference _ -> Just reference)
       (\_ _ -> Nothing)
       . ruleDiscoveryAuthority)

requireRight :: Show failure => Either failure value -> IO value
requireRight outcome =
  case outcome of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
