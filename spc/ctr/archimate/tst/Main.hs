module Main
  ( main
  ) where

import O2I.ArchiMate.Profile.Test.Contract (contractTests)
import Test.Tasty (defaultMain)

main :: IO ()
main = defaultMain contractTests
