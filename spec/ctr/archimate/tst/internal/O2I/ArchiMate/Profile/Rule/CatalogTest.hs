{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Rule.CatalogTest
  ( catalogTests
  ) where

import Data.Char (isSpace)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Internal.Generated
  ( generatedBootstrapRuleIds
  , generatedSelectedProfileRuleIds
  )
import O2I.ArchiMate.Profile.Internal.Resolution
  ( compiledDescriptor
  , descriptorReference
  , profileDescriptorContractDigestValue
  )
import O2I.ArchiMate.Profile.Rule.Catalog
import O2I.ArchiMate.Profile.Rule.Explanation
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertBool, testCase)

catalogTests :: TestTree
catalogTests =
  testGroup
    "selected Profile rule catalog"
    [ testCase "is complete and canonically ordered" completeInventory
    , testCase
        "is exactly partitioned by the closed Profile stage"
        stagePartition
    , testCase "excludes Operation bootstrap rules" bootstrapPartition
    , testCase
        "binds the exact selected Profile reference and digest"
        digestBinding
    , testCase "provides exact lookup without normalization" exactLookup
    , testCase "materializes every nonempty field" nonemptyFields
    , testCase "exposes every field through total folds" totalFolds
    ]

completeInventory :: Assertion
completeInventory = do
  catalogIds @?= generatedSelectedProfileRuleIds
  selectedProfileRuleCatalogSize selectedProfileRuleCatalog
    @?= length generatedSelectedProfileRuleIds
  Set.size (Set.fromList catalogIds) @?= length catalogIds

stagePartition :: Assertion
stagePartition = do
  explanationIds
    (selectedProfileRulesForStage
       selectedProfileRuleCatalog
       selectedProfileRuleStage)
    @?= catalogIds
  map profileRuleStage entries
    @?= replicate (length entries) selectedProfileRuleStage

bootstrapPartition :: Assertion
bootstrapPartition =
  assertBool
    "selected Profile and Operation bootstrap rule identities overlap"
    (Set.null
       (Set.intersection
          (Set.fromList catalogIds)
          (Set.fromList generatedBootstrapRuleIds)))

digestBinding :: Assertion
digestBinding = do
  selectedProfileRuleCatalogProfileReference selectedProfileRuleCatalog
    @?= descriptorReference compiledDescriptor
  selectedProfileRuleCatalogContractDigest selectedProfileRuleCatalog
    @?= profileDescriptorContractDigestValue compiledDescriptor
  map profileRuleProfileReference entries
    @?= replicate (length entries) (descriptorReference compiledDescriptor)
  map profileRuleProfileContractDigest entries
    @?= replicate
          (length entries)
          (profileDescriptorContractDigestValue compiledDescriptor)

exactLookup :: Assertion
exactLookup = do
  map
    (lookupSelectedProfileRule selectedProfileRuleCatalog . profileRuleIdText)
    (map profileRuleId entries)
    @?= map Just entries
  lookupSelectedProfileRule selectedProfileRuleCatalog "unknown" @?= Nothing
  lookupSelectedProfileRule selectedProfileRuleCatalog " carrier:context"
    @?= Nothing
  lookupSelectedProfileRule selectedProfileRuleCatalog "carrier:Context"
    @?= Nothing

nonemptyFields :: Assertion
nonemptyFields = mapM_ assertComplete entries
  where
    assertComplete explanation = do
      assertNonempty "rule ID" (profileRuleIdText (profileRuleId explanation))
      assertNonempty
        "authority"
        (profileRuleAuthorityText (profileRuleAuthority explanation))
      assertNonempty
        "profile reference"
        (profileRuleProfileReference explanation)
      assertNonempty
        "profile contract digest"
        (profileRuleProfileContractDigest explanation)
      assertNonempty
        "stage"
        (profileRuleStageText (profileRuleStage explanation))
      assertNonempty "expectation" (profileRuleExpectation explanation)
      assertNonempty "meaning" (profileRuleMeaning explanation)
      assertNonempty "action" (profileRuleAction explanation)

totalFolds :: Assertion
totalFolds = do
  map foldedExplanation entries @?= map accessorExplanation entries
  foldProfileRuleAuthority ("Profile" :: Text) selectedProfileRuleAuthority
    @?= "Profile"
  foldProfileRuleStage ("profile" :: Text) selectedProfileRuleStage
    @?= "profile"
  foldSelectedProfileRuleCatalog (,,) selectedProfileRuleCatalog
    @?= ( descriptorReference compiledDescriptor
        , profileDescriptorContractDigestValue compiledDescriptor
        , selectedProfileRuleCatalogEntries selectedProfileRuleCatalog)

foldedExplanation ::
     ProfileRuleExplanation
  -> ( ProfileRuleId
     , ProfileRuleAuthority
     , Text
     , Text
     , ProfileRuleStage
     , Text
     , Text
     , Text)
foldedExplanation = foldProfileRuleExplanation (,,,,,,,)

accessorExplanation ::
     ProfileRuleExplanation
  -> ( ProfileRuleId
     , ProfileRuleAuthority
     , Text
     , Text
     , ProfileRuleStage
     , Text
     , Text
     , Text)
accessorExplanation explanation =
  ( profileRuleId explanation
  , profileRuleAuthority explanation
  , profileRuleProfileReference explanation
  , profileRuleProfileContractDigest explanation
  , profileRuleStage explanation
  , profileRuleExpectation explanation
  , profileRuleMeaning explanation
  , profileRuleAction explanation)

assertNonempty :: String -> Text -> Assertion
assertNonempty label value =
  assertBool (label <> " is empty or blank") (Text.any (not . isSpace) value)

entries :: [ProfileRuleExplanation]
entries =
  NonEmpty.toList (selectedProfileRuleCatalogEntries selectedProfileRuleCatalog)

catalogIds :: [Text]
catalogIds = map (profileRuleIdText . profileRuleId) entries

explanationIds :: NonEmpty.NonEmpty ProfileRuleExplanation -> [Text]
explanationIds = map (profileRuleIdText . profileRuleId) . NonEmpty.toList
