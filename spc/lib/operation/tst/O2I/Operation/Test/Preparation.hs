{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Preparation
  ( tests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Operation.Preparation
import O2I.Operation.Provenance
import O2I.Operation.Request
import O2I.Operation.View
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "preparation"
    [ testCase "enumerates every closed stage" stageCases
    , testCase "distinguishes required and omitted stages" requirementCases
    , testCase "omits absent request-owned inputs" omittedPlan
    , testCase "requires present request-owned inputs" requiredPlan
    , testCase "folds plan and step projections" projectionCases
    ]

stageCases :: Assertion
stageCases = do
  fmap preparationStageText stages
    @?= [ "model-acquisition"
        , "capability-input-acquisition"
        , "adapter-selection"
        , "adapter-decode"
        , "canonicalization"
        , "profile-marker"
        , "profile-resolution"
        , "profile-compatibility"
        , "view-selection"
        ]
  fmap stageTag stages @?= [0 .. 8]
  where
    stages =
      [ modelAcquisitionStage
      , capabilityInputAcquisitionStage
      , adapterSelectionStage
      , adapterDecodeStage
      , canonicalizationStage
      , profileMarkerStage
      , profileResolutionStage
      , profileCompatibilityStage
      , viewSelectionStage
      ]
    stageTag :: PreparationStage -> Int
    stageTag = foldPreparationStage 0 1 2 3 4 5 6 7 8

requirementCases :: Assertion
requirementCases = do
  foldPreparationRequirement "required" "omitted" requiredPreparation
    @?= ("required" :: Text)
  foldPreparationRequirement "required" "omitted" omittedPreparation
    @?= ("omitted" :: Text)

omittedPlan :: Assertion
omittedPlan =
  stepTags (preparationPlan (validationRequest (viewByName "Target") []))
    @?= expectedTags False

requiredPlan :: Assertion
requiredPlan = do
  input <- reference "qualification"
  stepTags
    (preparationPlan (qualificationRequest (viewByName "Target") [input]))
    @?= expectedTags True

projectionCases :: Assertion
projectionCases = do
  input <- reference "readiness"
  let request = readinessRequest (viewByName "Target") input []
      plan = preparationPlan request
  capabilityIdentityText (requestedCapability (preparationPlanRequest plan))
    @?= "readiness"
  foldPreparationPlan
    (\stored steps ->
       ( capabilityIdentityText (requestedCapability stored)
       , NonEmpty.length steps))
    plan
    @?= ("readiness", 9)
  fmap
    (foldPreparationStep
       (\stage requirement ->
          ( preparationStageText stage
          , foldPreparationRequirement True False requirement)))
    (NonEmpty.toList (preparationPlanSteps plan))
    @?= stepTags plan

stepTags :: PreparationPlan -> [(Text, Bool)]
stepTags =
  fmap
    (\step ->
       ( preparationStageText (preparationStepStage step)
       , foldPreparationRequirement True False (preparationStepRequirement step)))
    . NonEmpty.toList
    . preparationPlanSteps

expectedTags :: Bool -> [(Text, Bool)]
expectedTags inputs =
  [ ("model-acquisition", True)
  , ("capability-input-acquisition", inputs)
  , ("adapter-selection", True)
  , ("adapter-decode", True)
  , ("canonicalization", True)
  , ("profile-marker", True)
  , ("profile-resolution", True)
  , ("profile-compatibility", True)
  , ("view-selection", True)
  ]

reference :: Text -> IO SourceReference
reference value =
  case mkSourceReference value of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right result -> pure result
