-- | Native collective-claim contract tests.
module O2I.Adapter.AMX.Test.Collective
  ( collectiveTests
  ) where

import O2I.Adapter.AMX.Test.Collective.Contract (collectiveContractTests)
import O2I.Adapter.AMX.Test.Collective.Evidence (collectiveEvidenceTests)
import Test.Tasty (TestTree, testGroup)

collectiveTests :: TestTree
collectiveTests =
  testGroup
    "collective realization"
    [collectiveContractTests, collectiveEvidenceTests]
