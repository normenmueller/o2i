{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Preparation
  ( tests
  ) where

import O2I.Operation.Preparation
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup "preparation" [testCase "classifies every closed stage" stageCases]

stageCases :: Assertion
stageCases = do
  preparationStageText adapterSelectionStage @?= "adapter-selection"
  preparationStageText adapterDecodeStage @?= "adapter-decode"
  preparationStageText canonicalizationStage @?= "canonicalization"
  preparationStageText profileMarkerStage @?= "profile-marker"
  preparationStageText profileResolutionStage @?= "profile-resolution"
  preparationStageText profileCompatibilityStage @?= "profile-compatibility"
  preparationStageText viewSelectionStage @?= "view-selection"
  classify adapterSelectionStage @?= 0
  classify adapterDecodeStage @?= 1
  classify canonicalizationStage @?= 2
  classify profileMarkerStage @?= 3
  classify profileResolutionStage @?= 4
  classify profileCompatibilityStage @?= 5
  classify viewSelectionStage @?= 6
  where
    classify = foldPreparationStage 0 1 2 3 4 5 6 :: PreparationStage -> Int
