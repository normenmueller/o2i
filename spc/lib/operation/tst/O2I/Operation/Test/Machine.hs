{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Machine
  ( tests
  ) where

import qualified Data.ByteString.Char8 as ByteString
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Operation.Encoding.Internal
import O2I.Operation.Machine
import O2I.Operation.Machine.Internal
  ( assessOperationIdentity
  , operationIdentityInventory
  , operationIdentityValue
  , qualificationSubjectsOperationIdentity
  , qualifyOperationIdentity
  , readinessOperationIdentity
  , traceOperationIdentity
  , validateOperationIdentity
  , viewsOperationIdentity
  )
import O2I.Operation.Schema (machineSchemaVariants)
import O2I.Operation.Schema.Internal (defineMachineSchema)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertFailure, testCase)

tests :: TestTree
tests =
  testGroup
    "Operation machine envelope"
    [ testCase "validates exact composition metadata" validDescriptor
    , testCase "accumulates every unsafe descriptor field" invalidDescriptor
    , testCase "closes the exact operation identity inventory" exactIdentities
    , testCase "encodes the sole common envelope order" exactEnvelope
    ]

validDescriptor :: Assertion
validDescriptor = do
  descriptor <- requireDescriptor "o2i-tool" "0.3.0+build.7"
  toolDescriptorIdentity descriptor @?= "o2i-tool"
  toolDescriptorVersion descriptor @?= "0.3.0+build.7"
  foldToolDescriptor (,) descriptor @?= ("o2i-tool", "0.3.0+build.7")
  toolDescriptorFieldText toolIdentityField @?= "identity"
  toolDescriptorFieldText toolVersionField @?= "version"
  foldToolDescriptorField "identity" "version" toolIdentityField
    @?= ("identity" :: String)
  foldToolDescriptorField "identity" "version" toolVersionField
    @?= ("version" :: String)

invalidDescriptor :: Assertion
invalidDescriptor = do
  defectTags (mkToolDescriptor "" "") @?= ["empty:identity", "empty:version"]
  defectTags (mkToolDescriptor "bad\NULidentity" "bad\NULversion")
    @?= ["nul:identity", "nul:version"]

exactIdentities :: Assertion
exactIdentities = do
  operationIdentityInventory
    @?= [ viewsOperationIdentity
        , qualificationSubjectsOperationIdentity
        , validateOperationIdentity
        , traceOperationIdentity
        , qualifyOperationIdentity
        , readinessOperationIdentity
        , assessOperationIdentity
        ]
  fmap operationIdentityValue operationIdentityInventory
    @?= [ "views"
        , "qualification-subjects"
        , "validate"
        , "trace"
        , "qualify"
        , "readiness"
        , "assess"
        ]

exactEnvelope :: Assertion
exactEnvelope = do
  descriptor <- requireDescriptor "o2i" "9.8.7-rc.1"
  schema <-
    case defineMachineSchema "o2i.test.envelope" 1 ("completed" :| []) "{}" of
      Left defects ->
        assertFailure ("invalid test Schema: " <> show defects)
          >> fail "unreachable"
      Right value -> pure value
  let variant = NonEmpty.head (machineSchemaVariants schema)
      result =
        closedOperationMachineResult
          schema
          validateOperationIdentity
          descriptor
          variant
          [requiredMember "value" (textFragment "exact")]
  machineResultBytesValue result
    @?= ByteString.pack
          "{\"schema\":\"o2i.test.envelope/v1\",\"operation\":\"validate\",\"tool\":{\"identity\":\"o2i\",\"version\":\"9.8.7-rc.1\"},\"kind\":\"completed\",\"value\":\"exact\"}"

requireDescriptor :: Text.Text -> Text.Text -> IO ToolDescriptor
requireDescriptor identity version =
  case mkToolDescriptor identity version of
    Left defects ->
      assertFailure ("invalid test ToolDescriptor: " <> show defects)
        >> fail "unreachable"
    Right descriptor -> pure descriptor

defectTags :: Either (NonEmpty ToolDescriptorDefect) ToolDescriptor -> [String]
defectTags outcome =
  case outcome of
    Right _ -> ["accepted"]
    Left defects -> fmap defectTag (NonEmpty.toList defects)

defectTag :: ToolDescriptorDefect -> String
defectTag =
  foldToolDescriptorDefect
    (("empty:" <>) . Text.unpack . toolDescriptorFieldText)
    (("nul:" <>) . Text.unpack . toolDescriptorFieldText)
