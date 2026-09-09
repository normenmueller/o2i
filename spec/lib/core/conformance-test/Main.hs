module Main
  ( main
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import O2I.Core.Conformance
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Rule.Catalog
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain
    (testGroup
       "Core public-source conformance"
       [ testCase
           "covers Structure 12/12 through real producers"
           structureCoverage
       , testCase "covers Binding 4/4 through real producers" bindingCoverage
       , testCase
           "covers Semantics 27/27 through real producers"
           semanticsCoverage
       ])

structureCoverage :: IO ()
structureCoverage =
  foldCoreConformanceResult
    (\failures ->
       assertBool
         ("conformance source failure count=" <> show (NonEmpty.length failures))
         False)
    verify
    structureCorpusRuleIds
  where
    verify ruleIds = do
      let observed = Set.fromList (map coreRuleIdText ruleIds)
          catalog =
            Set.fromList
              [ coreRuleIdText (coreRuleIdentity rule)
              | rule <-
                  NonEmpty.toList
                    (coreRulesForStage coreRuleCatalog structureRuleStage)
              ]
      Set.size catalog @?= 15
      assertBool
        ("observed="
           <> show (Set.toAscList observed)
           <> "; missing="
           <> show (Set.toAscList (catalog Set.\\ observed)))
        (Set.size observed == 12)
      assertBool
        "observed Structure producers must belong to owner catalog"
        (observed `Set.isSubsetOf` catalog)

bindingCoverage :: IO ()
bindingCoverage =
  foldCoreConformanceResult
    (\failures ->
       assertBool
         ("conformance source failure count=" <> show (NonEmpty.length failures))
         False)
    verify
    bindingCorpusRuleIds
  where
    verify ruleIds = do
      let observed = Set.fromList (map coreRuleIdText ruleIds)
          catalog =
            Set.fromList
              [ coreRuleIdText (coreRuleIdentity rule)
              | rule <-
                  NonEmpty.toList
                    (coreRulesForStage coreRuleCatalog capabilityInputRuleStage)
              ]
      Set.size observed @?= 4
      assertBool
        "observed Binding producers must belong to owner catalog"
        (observed `Set.isSubsetOf` catalog)

semanticsCoverage :: IO ()
semanticsCoverage =
  foldCoreConformanceResult
    (\failures ->
       assertBool
         ("conformance source failure count=" <> show (NonEmpty.length failures))
         False)
    verify
    semanticsCorpusRuleIds
  where
    verify ruleIds = do
      let observed = Set.fromList (map coreRuleIdText ruleIds)
          catalog =
            Set.fromList
              [ coreRuleIdText (coreRuleIdentity rule)
              | rule <-
                  NonEmpty.toList
                    (coreRulesForStage coreRuleCatalog semanticsRuleStage)
              ]
      Set.size catalog @?= 39
      assertBool
        ("observed="
           <> show (Set.toAscList observed)
           <> "; extra="
           <> show (Set.toAscList (observed Set.\\ catalog)))
        (Set.size observed == 27 && observed `Set.isSubsetOf` catalog)
