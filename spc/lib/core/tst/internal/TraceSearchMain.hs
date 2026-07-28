-- | Runner for the private effect-trace search contracts.
module Main where

import O2I.Validation.Trace.Search.Test.Contracts (tests)
import Test.Tasty (defaultMain)

main :: IO ()
main = defaultMain tests
