-- | Native collective-claim contract tests.
module O2I.Adapter.AMX.Test.Collective
  ( collectiveTests
  ) where

import O2I.Adapter.AMX.Test.Collective.Contract (collectiveContractTests)
import Test.Tasty (TestTree)

collectiveTests :: TestTree
collectiveTests = collectiveContractTests
