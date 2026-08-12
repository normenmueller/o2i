{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Control.Monad (forM_)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Core.Contract
  ( CoreRuleId
  , coreContractWitness
  , coreRuleIdText
  , coreRuleIds
  )
import O2I.Core.Contract.Internal
  ( capabilityInputRuleIds
  , qualificationRuleIds
  , readinessAndAssessmentRuleIds
  , semanticsRuleIds
  , structureRuleIds
  , traceRuleIds
  )
import O2I.Core.Rule.Catalog
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain
    (testGroup
       "Core rule catalog"
       [ testCase "is bound to the compiled Core contract" $ do
           coreRuleCatalogContract coreRuleCatalog @?= coreContractWitness
       , testCase "is an exact ordered bijection with compiled rule IDs" $ do
           let entries =
                 NonEmpty.toList (coreRuleCatalogEntries coreRuleCatalog)
           map coreRuleIdentity entries @?= NonEmpty.toList coreRuleIds
           coreRuleCatalogSize coreRuleCatalog @?= NonEmpty.length coreRuleIds
       , testCase "resolves every exact identity without semantic dispatch" $ do
           let entries =
                 NonEmpty.toList (coreRuleCatalogEntries coreRuleCatalog)
           map
             (lookupCoreRule coreRuleCatalog . coreRuleIdText . coreRuleIdentity)
             entries
             @?= map Just entries
       , testCase "materializes every normative and presentation field" $ do
           let entries =
                 NonEmpty.toList (coreRuleCatalogEntries coreRuleCatalog)
           map (coreRuleAuthorityText . coreRuleAuthority) entries
             @?= replicate (length entries) "Core"
           forM_ entries $ \rule -> do
             let identifier =
                   Text.unpack (coreRuleIdText (coreRuleIdentity rule))
             assertNonempty identifier "expectation" (coreRuleExpectation rule)
             assertNonempty identifier "meaning" (coreRuleMeaning rule)
             assertNonempty identifier "action" (coreRuleAction rule)
       , testCase "partitions every rule into exactly one closed stage" $ do
           let entries =
                 NonEmpty.toList (coreRuleCatalogEntries coreRuleCatalog)
               stages =
                 [ capabilityInputRuleStage
                 , qualificationRuleStage
                 , readinessAndAssessmentRuleStage
                 , semanticsRuleStage
                 , structureRuleStage
                 , traceRuleStage
                 ]
               partitionFor stage =
                 NonEmpty.toList (coreRulesForStage coreRuleCatalog stage)
               partition = concatMap partitionFor stages
           forM_ stages $ \stage ->
             map coreRuleIdentity (partitionFor stage)
               @?= NonEmpty.toList (expectedRulesForStage stage)
           sort (map coreRuleIdentity partition)
             @?= map coreRuleIdentity entries
           map coreRuleStage partition
             @?= concatMap
                   (\stage ->
                      replicate
                        (NonEmpty.length
                           (coreRulesForStage coreRuleCatalog stage))
                        stage)
                   stages
       , testCase "does not normalize lookup input" $ do
           lookupCoreRule
             coreRuleCatalog
             " core.contextualization.source-category"
             @?= Nothing
           lookupCoreRule
             coreRuleCatalog
             "CORE.CONTEXTUALIZATION.SOURCE-CATEGORY"
             @?= Nothing
           lookupCoreRule coreRuleCatalog "unknown" @?= Nothing
       ])

assertNonempty :: String -> String -> Text.Text -> IO ()
assertNonempty identifier field value =
  assertBool (identifier ++ " has an empty " ++ field) (not (Text.null value))

expectedRulesForStage :: CoreRuleStage -> NonEmpty CoreRuleId
expectedRulesForStage =
  foldCoreRuleStage
    capabilityInputRuleIds
    qualificationRuleIds
    readinessAndAssessmentRuleIds
    semanticsRuleIds
    structureRuleIds
    traceRuleIds
