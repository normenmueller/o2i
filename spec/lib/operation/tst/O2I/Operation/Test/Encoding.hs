{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Encoding
  ( main
  , tests
  ) where

import qualified Data.ByteString.Char8 as ByteString
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Operation.Encoding.Internal
import O2I.Operation.Schema
import O2I.Operation.Schema.Internal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "canonical machine-result encoding"
    [ testCase "emits exact ordered escaped UTF-8 bytes" canonicalBytes
    , testCase "returns identical bytes for identical values" deterministicBytes
    , testCase "omits only absent optional members" omissionPolicy
    , testCase "rejects undeclared result variants" undeclaredVariant
    , testCase "rejects reserved and duplicate top-level members" invalidMembers
    , testCase "rejects duplicate nested object members" nestedDuplicates
    ]

canonicalBytes :: IO ()
canonicalBytes = do
  result <- completeResult
  machineResultBytesValue result @?= expectedDocument
  schemaVariantText (machineResultVariantValue result) @?= "completed"
  schemaAuthorityReference
    (machineSchemaAuthority (machineResultSchemaValue result))
    @?= "o2i.test.result/v1"

deterministicBytes :: IO ()
deterministicBytes = do
  first <- completeResult
  second <- completeResult
  machineResultBytesValue first @?= machineResultBytesValue second

omissionPolicy :: IO ()
omissionPolicy = do
  schema <- testSchema
  variant <- firstVariant schema
  absent <- requireResult schema variant (optionalMember "label" Nothing)
  present <-
    requireResult
      schema
      variant
      (optionalMember "label" (Just (textFragment "")))
  machineResultBytesValue absent
    @?= ByteString.pack
          "{\"schema\":\"o2i.test.result/v1\",\"kind\":\"completed\"}"
  machineResultBytesValue present
    @?= ByteString.pack
          "{\"schema\":\"o2i.test.result/v1\",\"kind\":\"completed\",\"label\":\"\"}"

undeclaredVariant :: IO ()
undeclaredVariant = do
  schema <- testSchema
  case machineResult schema (SchemaVariant "not-declared") [] of
    Right _ -> assertFailure "an undeclared result variant was accepted"
    Left defects ->
      fmap defectTag (NonEmpty.toList defects) @?= ["variant:not-declared"]

invalidMembers :: IO ()
invalidMembers = do
  schema <- testSchema
  variant <- firstVariant schema
  case machineResult
         schema
         variant
         [ requiredMember "schema" (textFragment "caller-owned")
         , requiredMember "operation" (textFragment "caller-owned")
         , requiredMember "tool" (textFragment "caller-owned")
         , requiredMember "kind" (textFragment "completed")
         , requiredMember "label" (textFragment "first")
         , requiredMember "label" (textFragment "second")
         ] of
    Right _ -> assertFailure "reserved or duplicate members were accepted"
    Left defects ->
      fmap defectTag (NonEmpty.toList defects)
        @?= [ "reserved:schema"
            , "reserved:operation"
            , "reserved:tool"
            , "reserved:kind"
            , "duplicate:label"
            ]

nestedDuplicates :: IO ()
nestedDuplicates =
  case objectFragment
         [ requiredMember "value" (naturalFragment 1)
         , requiredMember "value" (naturalFragment 2)
         ] of
    Right _ -> assertFailure "duplicate nested members were accepted"
    Left defects ->
      fmap defectTag (NonEmpty.toList defects) @?= ["duplicate:value"]

completeResult :: IO MachineResult
completeResult = do
  schema <- testSchema
  variant <- firstVariant schema
  requireResult
    schema
    variant
    [ requiredMember "label" (textFragment "\"slash\\\b\t\n\f\r\SOHä")
    , requiredMember "count" (naturalFragment 2)
    , requiredMember "enabled" (booleanFragment True)
    , requiredMember "items" (arrayFragment [textFragment "ä", nullFragment])
    ]

expectedDocument :: ByteString.ByteString
expectedDocument =
  TextEncoding.encodeUtf8
    "{\"schema\":\"o2i.test.result/v1\",\"kind\":\"completed\",\"label\":\"\\\"slash\\\\\\b\\t\\n\\f\\r\\u0001ä\",\"count\":2,\"enabled\":true,\"items\":[\"ä\",null]}"

testSchema :: IO MachineSchema
testSchema =
  case defineMachineSchema
         "o2i.test.result"
         1
         ("completed" :| ["unavailable"])
         (ByteString.pack "{\"type\":\"object\"}") of
    Left defects ->
      assertFailure ("invalid test Schema: " <> show defects) >> testSchema
    Right schema -> pure schema

firstVariant :: MachineSchema -> IO SchemaVariant
firstVariant schema = pure (NonEmpty.head (machineSchemaVariants schema))

requireResult ::
     MachineSchema -> SchemaVariant -> [CanonicalMember] -> IO MachineResult
requireResult schema variant members =
  case machineResult schema variant members of
    Left defects ->
      assertFailure ("expected an encodable result, got " <> show defects)
        >> requireResult schema variant members
    Right result -> pure result

defectTag :: MachineEncodingDefect -> String
defectTag defect =
  case defect of
    UndeclaredSchemaVariant variant ->
      "variant:" <> Text.unpack (schemaVariantText variant)
    ReservedMachineMember name -> "reserved:" <> Text.unpack name
    DuplicateMachineMember name -> "duplicate:" <> Text.unpack name
