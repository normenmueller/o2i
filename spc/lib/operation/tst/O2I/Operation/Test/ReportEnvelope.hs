{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.ReportEnvelope
  ( hostileTool
  , contractsWithoutCore
  , contractsWithCore
  , assertPreparedEnvelope
  , assertViewEnvelope
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import O2I.Core.Contract
  ( coreContractIdentity
  , coreContractIdentityText
  , coreContractSha256
  , coreContractSha256Text
  , coreContractVersion
  , coreContractVersionText
  )
import O2I.Operation.Machine
  ( ToolDescriptor
  , ToolDescriptorDefect
  , mkToolDescriptor
  )
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Rule.Catalog
  ( operationRuleCatalog
  , operationRuleCatalogContractDigest
  , operationRuleCatalogContractIdentity
  , operationRuleCatalogContractVersion
  )
import O2I.Operation.Schema
  ( MachineSchema
  , SchemaAuthority
  , SchemaVariant
  , foldSchemaAuthority
  , machineSchemaAuthority
  , schemaDigestText
  , schemaIdentityText
  , schemaVariantText
  , schemaVersionValue
  )
import OperationReportPublicObserver
import Test.Tasty.HUnit (Assertion, (@?=), assertFailure)

hostileToolIdentity :: Text
hostileToolIdentity = "o2i\n\"tool\"\\raw"

hostileToolVersion :: Text
hostileToolVersion = "0.3.0\tβ"

hostileTool :: IO ToolDescriptor
hostileTool =
  case mkToolDescriptor hostileToolIdentity hostileToolVersion of
    Left defects -> invalidTool defects
    Right tool -> pure tool

contractsWithoutCore :: NonEmpty ObservedReportContract
contractsWithoutCore =
  operationContract
    :| [ObservedAdapterReportContract, ObservedProfileReportContract]

contractsWithCore :: NonEmpty ObservedReportContract
contractsWithCore = contractsWithoutCore <> (coreContract :| [])

assertPreparedEnvelope ::
     MachineSchema
  -> SchemaVariant
  -> ObservedReportOperation
  -> NonEmpty ObservedReportContract
  -> ReportEnvelope
  -> Assertion
assertPreparedEnvelope schema variant operation contracts envelope =
  observeReportEnvelope envelope
    @?= ObservedReportEnvelope
          (observeSchemaAuthority (machineSchemaAuthority schema))
          (schemaVariantText variant)
          operation
          (ObservedToolDescriptor hostileToolIdentity hostileToolVersion)
          (ObservedPreparedReportAuthority contracts)

assertViewEnvelope ::
     MachineSchema -> SchemaVariant -> Text -> ReportEnvelope -> Assertion
assertViewEnvelope schema variant adapter envelope =
  observeReportEnvelope envelope
    @?= ObservedReportEnvelope
          (observeSchemaAuthority (machineSchemaAuthority schema))
          (schemaVariantText variant)
          ObservedViewsReportOperation
          (ObservedToolDescriptor hostileToolIdentity hostileToolVersion)
          (ObservedViewReportAuthority adapter)

observeSchemaAuthority :: SchemaAuthority -> ObservedSchemaAuthority
observeSchemaAuthority =
  foldSchemaAuthority $ \identity version digest ->
    ObservedSchemaAuthority
      (schemaIdentityText identity)
      (schemaVersionValue version)
      (schemaDigestText digest)

operationContract :: ObservedReportContract
operationContract =
  ObservedOperationReportContract
    (operationRuleCatalogContractIdentity operationRuleCatalog)
    (operationRuleCatalogContractVersion operationRuleCatalog)
    (operationRuleCatalogContractDigest operationRuleCatalog)

coreContract :: ObservedReportContract
coreContract =
  ObservedCoreReportContract
    (coreContractIdentityText coreContractIdentity)
    (coreContractVersionText coreContractVersion)
    (coreContractSha256Text coreContractSha256)

invalidTool :: NonEmpty ToolDescriptorDefect -> IO value
invalidTool defects =
  assertFailure ("invalid hostile ToolDescriptor: " <> show defects)
    >> fail "unreachable"
