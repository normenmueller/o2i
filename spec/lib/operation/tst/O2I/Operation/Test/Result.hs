module O2I.Operation.Test.Result
  ( tests
  ) where

import O2I.Operation.Result.Internal
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), testCase)

tests :: TestTree
tests =
  testGroup
    "internal result"
    [ testCase "folds the local closed cause and completion" foldCases
    , testCase "maps only the completion alternative" mapCases
    , testCase "sequences completion and terminates failure" andThenCases
    ]

data TestCause
  = DecodeRejected
  | BindingRejected
  deriving (Eq, Show)

data Observation
  = FailedWith !TestCause
  | CompletedWith !Int
  deriving (Eq, Show)

observe :: InternalResult TestCause Int -> Observation
observe = foldInternalResult FailedWith CompletedWith

foldCases :: Assertion
foldCases = do
  observe (internalFailureResult DecodeRejected) @?= FailedWith DecodeRejected
  observe (completedInternalResult 7) @?= CompletedWith 7

mapCases :: Assertion
mapCases = do
  observe (mapInternalResult (+ 1) (internalFailureResult DecodeRejected))
    @?= FailedWith DecodeRejected
  observe (mapInternalResult (+ 1) (completedInternalResult 7))
    @?= CompletedWith 8

andThenCases :: Assertion
andThenCases = do
  observe
    (andThenInternalResult
       (internalFailureResult DecodeRejected)
       (const (internalFailureResult BindingRejected)))
    @?= FailedWith DecodeRejected
  observe
    (andThenInternalResult
       (completedInternalResult 7)
       (completedInternalResult . (+ 1)))
    @?= CompletedWith 8
  observe
    (andThenInternalResult
       (completedInternalResult (7 :: Int))
       (const (internalFailureResult BindingRejected)))
    @?= FailedWith BindingRejected
