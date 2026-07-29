module Main where

import O2I.Validation.MacroEvidence.Test.Contracts
import Test.Tasty

main :: IO ()
main = defaultMain macroEvidenceTests
