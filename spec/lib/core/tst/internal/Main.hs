module Main
  ( main
  ) where

import qualified O2I.Core.Test.Assessment as Assessment
import qualified O2I.Core.Test.Contract as Contract
import qualified O2I.Core.Test.GraphObservation as GraphObservation
import qualified O2I.Core.Test.Identity as Identity
import qualified O2I.Core.Test.Input as Input
import qualified O2I.Core.Test.InputBinding as InputBinding
import qualified O2I.Core.Test.Qualification as Qualification
import qualified O2I.Core.Test.Readiness as Readiness
import qualified O2I.Core.Test.RuleCatalog as RuleCatalog
import qualified O2I.Core.Test.Semantics as Semantics
import qualified O2I.Core.Test.Structure as Structure
import qualified O2I.Core.Test.Trace as Trace
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "Core internal"
       [ Identity.tests
       , Contract.tests
       , GraphObservation.tests
       , RuleCatalog.tests
       , Structure.tests
       , Input.tests
       , InputBinding.tests
       , Semantics.tests
       , Qualification.tests
       , Trace.tests
       , Readiness.tests
       , Assessment.tests
       ])
