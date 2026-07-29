-- | Runner for the private typed effect-trace evaluator contracts.
module Main where

import O2I.Validation.Trace.Eval.Test.Contracts (tests)
import Test.Tasty (defaultMain)

main :: IO ()
main = defaultMain tests
