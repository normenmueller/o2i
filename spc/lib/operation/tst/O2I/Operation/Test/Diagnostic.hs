{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module O2I.Operation.Test.Diagnostic
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString.Lazy as LazyByteString
import Language.Haskell.TH (lookupTypeName, lookupValueName)
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Machine (diagnosticSchemaAuthority)
import O2I.Operation.Schema
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

$(do
    diagnosticType <- lookupTypeName "PreparedDiagnostic"
    diagnosticConstructor <- lookupValueName "ProfileActivationDiagnostic"
    documentType <- lookupTypeName "PreparedDiagnosticDocument"
    documentConstructor <- lookupValueName "PreparedDiagnosticDocument"
    case ( diagnosticType
         , diagnosticConstructor
         , documentType
         , documentConstructor) of
      (Just _, Nothing, Just _, Nothing) -> pure []
      _ -> fail "prepared diagnostics and documents must be constructor-opaque")

tests :: TestTree
tests =
  testGroup
    "diagnostic"
    [ testCase "exposes only producer-derived classifications" classifications
    , testCase "publishes only the authority-once v2 schema" schemaRoot
    , testCase "binds the generated v2 schema authority" schemaAuthority
    ]

classifications :: Assertion
classifications = do
  diagnosticSeverityText infoSeverity @?= "info"
  diagnosticSeverityText errorSeverity @?= "error"
  diagnosticDispositionText modelFinding @?= "model-finding"

schemaRoot :: Assertion
schemaRoot = do
  payload <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v2.schema.json")
  schema <-
    case Aeson.eitherDecode payload of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  case schema of
    Aeson.Object object -> do
      AesonKeyMap.lookup "$id" object @?= Just "o2i.operation.diagnostic/v2"
      AesonKeyMap.lookup "$ref" object
        @?= Just "#/$defs/preparedDiagnosticDocument"
    _ -> assertFailure "diagnostic schema is not an object"

schemaAuthority :: Assertion
schemaAuthority = do
  schemaAuthorityReference diagnosticSchemaAuthority
    @?= "o2i.operation.diagnostic/v2"
  schemaDigestText (schemaAuthorityDigest diagnosticSchemaAuthority)
    @?= "becc0cc4dc574200325c702a872ed53d748d9f9a47fafda075d1b2832cc01183"
