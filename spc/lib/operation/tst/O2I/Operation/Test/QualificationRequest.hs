{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.QualificationRequest
  ( tests
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Identity (ModelIdentity, modelIdentity, modelIdentityText)
import O2I.Operation.Acquisition (InputSource, fileInput)
import O2I.Operation.Provenance (mkSourceReference)
import O2I.Operation.Qualify.Request
import O2I.Operation.View (viewByName)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "Qualify request"
    [ testCase "rejects duplicate Strategy selectors" duplicateStrategy
    , testCase "rejects duplicate Need selectors" duplicateNeed
    , testCase
        "admits the same exact identity across categories"
        crossCategoryIdentity
    , testCase "performs no identity normalization" exactEquality
    , testCase
        "orders every duplicate defect by category and exact identity"
        canonicalDefectOrder
    , testCase "folds every valid request field exactly" exactRequest
    ]

duplicateStrategy :: Assertion
duplicateStrategy = do
  model <- modelSource
  let repeated = identity "strategy"
  defects <-
    requireLeft
      (qualifyRequest
         model
         (viewByName "Target")
         Nothing
         (repeated :| [repeated])
         []
         [])
  defectTags defects @?= [("strategy", "strategy")]

duplicateNeed :: Assertion
duplicateNeed = do
  model <- modelSource
  let repeated = identity "need"
  defects <-
    requireLeft
      (qualifyRequest
         model
         (viewByName "Target")
         Nothing
         (identity "strategy" :| [])
         [repeated, repeated]
         [])
  defectTags defects @?= [("need", "need")]

crossCategoryIdentity :: Assertion
crossCategoryIdentity = do
  model <- modelSource
  let shared = identity "shared"
  _ <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Target")
         Nothing
         (shared :| [])
         [shared]
         [])
  pure ()

exactEquality :: Assertion
exactEquality = do
  model <- modelSource
  let selectors =
        identity "A"
          :| [ identity "a"
             , identity "spaced"
             , identity "spaced "
             , identity "\233"
             , identity "e\769"
             ]
  request <-
    requireRight
      (qualifyRequest model (viewByName "Target") Nothing selectors [] [])
  fmap modelIdentityText (NonEmpty.toList (qualifyStrategySelectors request))
    @?= ["A", "a", "spaced", "spaced ", "\233", "e\769"]

canonicalDefectOrder :: Assertion
canonicalDefectOrder = do
  model <- modelSource
  let first =
        qualifyRequest
          model
          (viewByName "Target")
          Nothing
          (identity "strategy-z"
             :| [ identity "strategy-a"
                , identity "strategy-z"
                , identity "strategy-a"
                ])
          [ identity "need-z"
          , identity "need-a"
          , identity "need-z"
          , identity "need-a"
          ]
          []
      second =
        qualifyRequest
          model
          (viewByName "Target")
          Nothing
          (identity "strategy-a"
             :| [ identity "strategy-z"
                , identity "strategy-a"
                , identity "strategy-z"
                ])
          [ identity "need-a"
          , identity "need-z"
          , identity "need-a"
          , identity "need-z"
          ]
          []
      expected =
        [ ("need", "need-a")
        , ("need", "need-z")
        , ("strategy", "strategy-a")
        , ("strategy", "strategy-z")
        ]
  defectTags <$> requireLeft first >>= (@?= expected)
  defectTags <$> requireLeft second >>= (@?= expected)

exactRequest :: Assertion
exactRequest = do
  model <- modelSource
  request <-
    requireRight
      (qualifyRequest
         model
         (viewByName "Target")
         Nothing
         (identity "strategy" :| [])
         [identity "need"]
         [model])
  foldQualifyRequest
    (\_ _ adapter strategies needs supplements -> do
       adapter @?= Nothing
       fmap modelIdentityText (NonEmpty.toList strategies) @?= ["strategy"]
       fmap modelIdentityText needs @?= ["need"]
       length supplements @?= 1)
    request

defectTags :: NonEmpty QualifyRequestDefect -> [(Text, Text)]
defectTags =
  fmap
    (foldQualifyRequestDefect $ \category repeated ->
       (qualifySelectorCategoryText category, modelIdentityText repeated))
    . NonEmpty.toList

modelSource :: IO InputSource
modelSource = do
  reference <- requireRight (mkSourceReference "model")
  requireRight (fileInput reference "model.amx")

identity :: Text -> ModelIdentity
identity value =
  case modelIdentity value of
    Left defect -> error ("invalid test identity: " <> show defect)
    Right result -> result

requireLeft :: Show value => Either failure value -> IO failure
requireLeft result =
  case result of
    Left failure -> pure failure
    Right value ->
      assertFailure ("expected request rejection, got " <> show value)
        >> fail "unreachable"

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure ->
      assertFailure ("expected request acceptance, got " <> show failure)
        >> fail "unreachable"
    Right value -> pure value
