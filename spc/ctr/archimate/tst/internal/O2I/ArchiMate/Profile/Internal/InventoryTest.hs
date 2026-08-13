{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.InventoryTest
  ( inventoryTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Closure
  ( activationRuleRank
  , closureRuleRank
  )
import O2I.ArchiMate.Profile.Internal.Generated
import O2I.ArchiMate.Profile.Internal.Notation
import O2I.ArchiMate.Profile.Internal.Notation.Conformance
import O2I.ArchiMate.Profile.Internal.Projection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

inventoryTests :: TestTree
inventoryTests =
  testGroup
    "Generated runtime inventory"
    [ testCase "uses unique selected activation and closure rule identities" $ do
        assertUnique "activation rule IDs" activationRuleIds
        assertUnique "closure rule IDs" closureRuleIds
        assertSubset "activation rule IDs" activationRuleIds selectedRuleIds
        assertSubset "closure rule IDs" closureRuleIds selectedRuleIds
    , testCase "resolves every static activation source rule"
        $ assertSubset
            "activation source rule IDs"
            (concatMap
               generatedActivationStaticSourceRuleIds
               generatedActivationRules)
            selectedRuleIds
    , testCase "covers every property mapping with one matching runtime plan" $ do
        assertUnique "property mapping IDs" propertyMappingIds
        assertUnique "property runtime-plan IDs" propertyPlanIds
        propertyPlanInventory @?= propertyMappingInventory
    , testCase "consumes every unique pattern rule through its typed lookup" $ do
        assertUnique "pattern subjects" patternSubjects
        assertUnique "pattern rule IDs" patternRuleIds
        assertSubset "pattern rule IDs" patternRuleIds selectedRuleIds
        mapM_ consumePatternRule generatedPatternRuntimeRules
    , testCase "derives provenance ranks from generated rule order" $ do
        map activationRuleRank generatedActivationRules
          @?= [0 .. length generatedActivationRules - 1]
        map
          (closureRuleRank . generatedClosureProvenanceRuleId)
          generatedClosureRules
          @?= [0 .. length generatedClosureRules - 1]
    , testCase "closes and partitions all 38 Notation issue kinds" $ do
        NonEmpty.length allViewInventoryIssueKindsValue @?= 13
        NonEmpty.length allProfileMarkerIssueKindsValue @?= 13
        NonEmpty.length allSelectedUniverseIssueKindsValue @?= 12
        NonEmpty.length allArchiMateNotationIssueKindsValue @?= 38
        assertUnique
          "Notation issue tokens"
          (map
             archiMateNotationIssueKindTokenValue
             (NonEmpty.toList allArchiMateNotationIssueKindsValue))
        fmap ViewInventoryNotationKind allViewInventoryIssueKindsValue
          <> fmap ProfileMarkerNotationKind allProfileMarkerIssueKindsValue
          <> fmap
               SelectedUniverseNotationKind
               allSelectedUniverseIssueKindsValue
               @?= allArchiMateNotationIssueKindsValue
    ]
  where
    selectedRuleIds = Set.fromList generatedSelectedProfileRuleIds
    activationRuleIds =
      map generatedActivationProvenanceRuleId generatedActivationRules
    closureRuleIds = map generatedClosureProvenanceRuleId generatedClosureRules
    propertyMappingIds =
      map generatedPropertyMappingId generatedPropertyMappings
    propertyPlanIds =
      map generatedPropertyRuntimeMappingId generatedPropertyRuntimePlans
    patternSubjects =
      map generatedPatternRuntimeSubject generatedPatternRuntimeRules
    patternRuleIds =
      map generatedPatternRuntimeRuleId generatedPatternRuntimeRules

propertyMappingInventory :: Map.Map Text (Text, Text)
propertyMappingInventory =
  Map.fromList
    [ (mappingId, (key, owner))
    | GeneratedPropertyMapping mappingId _ key owner <-
        generatedPropertyMappings
    ]

propertyPlanInventory :: Map.Map Text (Text, Text)
propertyPlanInventory =
  Map.fromList
    [ (mappingId, (key, owner))
    | GeneratedPropertyRuntimePlan mappingId _ key owner _ _ _ _ _ _ <-
        generatedPropertyRuntimePlans
    ]

consumePatternRule :: GeneratedPatternRuntimeRule -> IO ()
consumePatternRule rule =
  case generatedPatternRuntimeExpected rule of
    GeneratedExpectedText expected ->
      patternTextExpectation subject occurrence @?= Right (ruleId, expected)
    GeneratedExpectedTexts expected ->
      patternTextsExpectation subject occurrence @?= Right (ruleId, expected)
    GeneratedExpectedBoolean expected ->
      patternBooleanExpectation subject occurrence @?= Right (ruleId, expected)
  where
    subject = generatedPatternRuntimeSubject rule
    ruleId = generatedPatternRuntimeRuleId rule
    occurrence = CanonicalOccurrence CanonicalRecordOccurrence 0

assertUnique :: Ord value => String -> [value] -> IO ()
assertUnique subject values =
  assertBool subject (length values == Set.size (Set.fromList values))

assertSubset :: String -> [Text] -> Set.Set Text -> IO ()
assertSubset subject values expected =
  assertBool subject (Set.fromList values `Set.isSubsetOf` expected)
