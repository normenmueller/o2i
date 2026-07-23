module Main
  ( main
  ) where

import O2I.Adapter.AMX.Test.Collective
import O2I.Adapter.AMX.Test.Decode
import O2I.Adapter.AMX.Test.Fixture
import O2I.Adapter.AMX.Test.Profile
import O2I.Adapter.AMX.Test.Projection
import O2I.Adapter.AMX.Test.View
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "o2i-amx"
       [ decodeTests
       , viewTests
       , profileTests
       , collectiveTests
       , projectionTests
       , fixtureTests
       ])
