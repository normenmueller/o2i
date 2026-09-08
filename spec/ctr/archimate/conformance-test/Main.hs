{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import O2I.ArchiMate.Profile.Conformance
import qualified O2I.ArchiMate.Profile.Rule.Catalog as Catalog
import qualified O2I.ArchiMate.Profile.Rule.Explanation as Explanation
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain
    (testGroup
       "Profile public-source conformance"
       [ testCase
           "covers every self and unordered cross-family pair"
           pairCoverage
       , testCase
           "aligns every scenario with the public production family fold"
           familyAlignment
       , testCase
           "covers both selected and non-selected placement"
           placementCoverage
       , testCase
           "retains all affected occurrences and multiplicity"
           occurrenceCoverage
       , testCase
           "mutation oracle rejects every omitted matrix edge"
           mutationOracle
       , testCase
           "reports source-produced Profile catalog coverage"
           profileCoverage
       ])

pairCoverage :: IO ()
pairCoverage = do
  Set.size observedPairs @?= 28
  Set.size observedSelfPairs @?= 7
  Set.size observedCrossPairs @?= 21
  where
    observedPairs =
      Set.fromList (map duplicateCaseFamilies duplicateIdentityCases)
    observedSelfPairs = Set.filter (uncurry (==)) observedPairs
    observedCrossPairs = Set.filter (uncurry (/=)) observedPairs

familyAlignment :: IO ()
familyAlignment = do
  mapM_
    (\duplicateCase ->
       sortFamilies (duplicateCaseObservedFamilies duplicateCase)
         @?= sortFamilies (sourceFamilies duplicateCase))
    duplicateIdentityCases
  Set.fromList (concatMap duplicateCaseObservedFamilies duplicateIdentityCases)
    @?= Set.fromList [minBound .. maxBound]
  mapM_
    (\duplicateCase ->
       assertBool
         "removing one observed production-domain member must break alignment"
         (case duplicateCaseObservedFamilies duplicateCase of
            [] -> False
            _:remaining ->
              sortFamilies remaining
                /= sortFamilies (sourceFamilies duplicateCase)))
    duplicateIdentityCases
  where
    sourceFamilies duplicateCase =
      let (left, right) = duplicateCaseFamilies duplicateCase
       in if left == right
            then replicate (duplicateCaseMultiplicity duplicateCase) left
            else left
                   : right
                   : replicate
                       (duplicateCaseMultiplicity duplicateCase - 2)
                       right
    sortFamilies = sort

placementCoverage :: IO ()
placementCoverage =
  mapM_
    (\placements ->
       Set.fromList placements
         @?= Set.fromList [SelectedPlacement, NonSelectedPlacement])
    (Map.elems placementsByPair)
  where
    placementsByPair =
      Map.fromListWith
        (<>)
        [ ( duplicateCaseFamilies duplicateCase
          , [duplicateCasePlacement duplicateCase])
        | duplicateCase <- duplicateIdentityCases
        ]

occurrenceCoverage :: IO ()
occurrenceCoverage = do
  mapM_
    (\duplicateCase -> do
       duplicateCaseAffectedOccurrences duplicateCase
         @?= duplicateCaseMultiplicity duplicateCase
       duplicateCaseTargetCardinalities duplicateCase
         @?= replicate
               (duplicateCaseMultiplicity duplicateCase)
               (duplicateCaseMultiplicity duplicateCase))
    duplicateIdentityCases
  assertBool
    "one real public source must retain a duplicate group larger than two"
    (any ((> 2) . duplicateCaseMultiplicity) duplicateIdentityCases)

mutationOracle :: IO ()
mutationOracle = do
  let complete = Set.fromList (map caseKey duplicateIdentityCases)
  Set.size complete @?= 56
  mapM_
    (\omitted ->
       assertBool
         ("omission survived: " <> show omitted)
         (Set.fromList
            [ caseKey duplicateCase
            | duplicateCase <- duplicateIdentityCases
            , caseKey duplicateCase /= omitted
            ]
            /= complete))
    (Set.toList complete)
  where
    caseKey duplicateCase =
      ( duplicateCaseFamilies duplicateCase
      , duplicateCasePlacement duplicateCase)

profileCoverage :: IO ()
profileCoverage = do
  let closureRules = Set.fromList profileCorpusClosureRuleIds
      observedRules = Set.fromList profileCorpusRuleIds Set.\\ closureRules
      classificationRules = Set.fromList profileCorpusClassificationRuleIds
      invariantRules = Set.fromList profileCorpusInvariantRuleIds
      classificationCases =
        Set.fromList
          [ (graph, qualification)
          | (graph, qualification, _) <- profileCorpusClassifications
          ]
      fullCatalog =
        Set.fromList
          (map
             (Explanation.profileRuleIdText . Explanation.profileRuleId)
             (NonEmpty.toList
                (Catalog.selectedProfileRuleCatalogEntries
                   Catalog.selectedProfileRuleCatalog)))
      catalogRules = fullCatalog Set.\\ closureRules
      observedKinds = Set.fromList profileCorpusEvidenceKinds
  Set.size fullCatalog @?= 151
  Set.size closureRules @?= 25
  Set.size catalogRules @?= 126
  classificationCases
    @?= Set.fromList
          [ (graph, qualification)
          | graph <- [False, True]
          , qualification <- [False, True]
          ]
  Set.size classificationRules @?= 4
  invariantRules
    @?= Set.fromList
          [ "qualification.proposal.carrier.category"
          , "qualification.proposal.carrier.stable-identity-scope"
          ]
  assertBool
    "classification rules must belong to the evidence-capable set"
    (classificationRules `Set.isSubsetOf` observedRules)
  assertBool
    ("Profile rule coverage: "
       <> show (Set.size observedRules)
       <> "/"
       <> show (Set.size catalogRules)
       <> "; missing="
       <> show (Set.toAscList (catalogRules Set.\\ observedRules))
       <> "; extra="
       <> show (Set.toAscList (observedRules Set.\\ catalogRules)))
    (observedRules == catalogRules)
  assertBool
    ("Profile evidence-form coverage: "
       <> show (Set.size observedKinds)
       <> "/12; observed="
       <> show (Set.toAscList observedKinds))
    (Set.size observedKinds == 12)
  mapM_
    (\omitted ->
       assertBool
         ("Profile rule deletion survived: " <> show omitted)
         (Set.delete omitted observedRules /= catalogRules))
    (Set.toList catalogRules)
  let catalogOnlySubstitute = Set.findMin (catalogRules Set.\\ invariantRules)
  mapM_
    (\replaced ->
       assertBool
         ("invariant catalog substitution survived: " <> show replaced)
         (Set.insert catalogOnlySubstitute (Set.delete replaced observedRules)
            /= catalogRules))
    (Set.toList invariantRules)
