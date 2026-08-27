module Main
  ( main
  ) where

import qualified O2I.Operation.Test.Acquisition as Acquisition
import qualified O2I.Operation.Test.Adapter as Adapter
import qualified O2I.Operation.Test.Diagnostic as Diagnostic
import qualified O2I.Operation.Test.Discovery as Discovery
import qualified O2I.Operation.Test.DiscoveryMachine as DiscoveryMachine
import qualified O2I.Operation.Test.Encoding as Encoding
import qualified O2I.Operation.Test.Failure as Failure
import qualified O2I.Operation.Test.Machine as Machine
import qualified O2I.Operation.Test.OwnerEvidence as OwnerEvidence
import qualified O2I.Operation.Test.Preparation as Preparation
import qualified O2I.Operation.Test.PreparationRuntime as PreparationRuntime
import qualified O2I.Operation.Test.Profile as Profile
import qualified O2I.Operation.Test.Provenance as Provenance
import qualified O2I.Operation.Test.Qualification as Qualification
import qualified O2I.Operation.Test.QualificationRequest as QualificationRequest
import qualified O2I.Operation.Test.Request as Request
import qualified O2I.Operation.Test.Result as Result
import qualified O2I.Operation.Test.RuleCatalog as RuleCatalog
import qualified O2I.Operation.Test.Schema as Schema
import qualified O2I.Operation.Test.Trace as Trace
import qualified O2I.Operation.Test.Validate as Validate
import qualified O2I.Operation.Test.View as View
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain
    (testGroup
       "operation"
       [ Acquisition.tests
       , Adapter.tests
       , Discovery.tests
       , DiscoveryMachine.tests
       , Diagnostic.tests
       , Encoding.tests
       , Failure.tests
       , Machine.tests
       , OwnerEvidence.tests
       , Preparation.tests
       , PreparationRuntime.tests
       , Profile.tests
       , Provenance.tests
       , Qualification.tests
       , QualificationRequest.tests
       , Request.tests
       , Result.tests
       , RuleCatalog.tests
       , Schema.tests
       , Trace.tests
       , Validate.tests
       , View.tests
       ])
