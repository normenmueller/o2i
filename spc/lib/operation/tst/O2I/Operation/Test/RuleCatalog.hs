{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.RuleCatalog
  ( tests
  ) where

import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Operation.Rule.Catalog
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

tests :: TestTree
tests =
  testGroup
    "Operation rule catalog"
    [ testCase "is complete and canonical" completeAndCanonical
    , testCase "supports exact lookup only" exactLookup
    , testCase "binds every rule to Operation preparation" closedOwnership
    , testCase "exposes complete explanations" completeExplanations
    , testCase "carries exact contract provenance" contractProvenance
    ]

completeAndCanonical :: IO ()
completeAndCanonical = do
  operationRuleCatalogSize operationRuleCatalog @?= 9
  identifiers @?= expectedIdentifiers
  identifiers @?= sort expectedIdentifiers
  where
    identifiers =
      fmap
        (operationRuleIdText . operationRuleIdentity)
        (NonEmpty.toList (operationRuleCatalogEntries operationRuleCatalog))
    expectedIdentifiers =
      [ "bootstrap.profile-adapter.adapter-id"
      , "bootstrap.profile-adapter.notation"
      , "bootstrap.profile-inventory.identity-token-uniqueness"
      , "bootstrap.profile-reference.grammar"
      , "bootstrap.profile-reference.missing"
      , "bootstrap.profile-reference.property-multiplicity"
      , "bootstrap.profile-reference.unknown"
      , "bootstrap.profile-reference.value-kind"
      , "bootstrap.profile-reference.value-multiplicity"
      ]

exactLookup :: IO ()
exactLookup = do
  fmap
    (operationRuleIdText . operationRuleIdentity)
    (lookupOperationRule
       operationRuleCatalog
       "bootstrap.profile-reference.missing")
    @?= Just "bootstrap.profile-reference.missing"
  lookupOperationRule operationRuleCatalog "BOOTSTRAP.PROFILE-REFERENCE.MISSING"
    @?= Nothing

closedOwnership :: IO ()
closedOwnership = do
  fmap operationRuleIdentity stageEntries @?= fmap operationRuleIdentity entries
  mapM_ assertOwnership (NonEmpty.toList entries)
  where
    entries = operationRuleCatalogEntries operationRuleCatalog
    firstStage = operationRuleStage (NonEmpty.head entries)
    stageEntries = operationRulesForStage operationRuleCatalog firstStage
    assertOwnership rule = do
      operationRuleAuthorityText (operationRuleAuthority rule) @?= "Operation"
      operationRuleStageText (operationRuleStage rule) @?= "preparation"
      foldOperationRuleAuthority True (operationRuleAuthority rule) @?= True
      foldOperationRuleStage True (operationRuleStage rule) @?= True

completeExplanations :: IO ()
completeExplanations = mapM_ assertComplete (NonEmpty.toList entries)
  where
    entries = operationRuleCatalogEntries operationRuleCatalog
    assertComplete rule =
      mapM_
        (assertBool "expected non-empty explanation" . not . Text.null)
        [ operationRuleExpectation rule
        , operationRuleMeaning rule
        , operationRuleAction rule
        ]

contractProvenance :: IO ()
contractProvenance = do
  operationRuleCatalogContractIdentity operationRuleCatalog @?= "o2i.operation"
  operationRuleCatalogContractVersion operationRuleCatalog @?= "0.3.0"
  operationRuleCatalogContractDigest operationRuleCatalog
    @?= "306e81674303a20a189ac779b0bc67775d3bb34906ca0166e668b6826bedc68f"
