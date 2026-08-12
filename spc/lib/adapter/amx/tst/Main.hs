module Main
  ( main
  ) where

import O2I.Adapter.AMX.Test.Contract
import O2I.Adapter.AMX.Test.Draft
import O2I.Adapter.AMX.Test.Fixture
import O2I.Adapter.AMX.Test.XML
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup "o2i-amx" [contractTests, draftTests, fixtureTests, xmlTests])
