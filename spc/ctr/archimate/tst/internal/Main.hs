module Main
  ( main
  ) where

import O2I.ArchiMate.Profile.Internal.ClosureWorkTest (closureWorkTests)
import O2I.ArchiMate.Profile.Internal.InventoryTest (inventoryTests)
import O2I.ArchiMate.Profile.Internal.NotationConformanceTest
  ( notationConformanceTests
  )
import O2I.ArchiMate.Profile.Internal.ProjectionIdentityTest
  ( projectionIdentityTests
  )
import O2I.ArchiMate.Profile.Rule.CatalogTest (catalogTests)
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "O2I ArchiMate Profile internals"
       [ closureWorkTests
       , inventoryTests
       , notationConformanceTests
       , projectionIdentityTests
       , catalogTests
       ])
