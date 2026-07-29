-- | Runner for the private typed relational evaluator contracts.
module Main where

import qualified O2I.Validation.Relational.Test.Contracts as Contracts
import qualified O2I.Validation.Relational.Test.Generated as Generated
import qualified O2I.Validation.Relational.Test.Matrix as Matrix
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "private typed relational evaluator"
       [Contracts.tests, Matrix.tests, Generated.tests])
