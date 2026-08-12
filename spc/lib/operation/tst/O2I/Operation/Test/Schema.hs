{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Schema
  ( main
  , tests
  ) where

import qualified Data.ByteString.Char8 as ByteString
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Operation.Schema
import O2I.Operation.Schema.Internal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "machine Schema metadata"
    [ testCase
        "binds identity, version, variants, and exact bytes"
        validAuthority
    , testCase "accumulates every independent metadata defect" invalidAuthority
    , testCase "preserves authoritative variant declaration order" variantOrder
    , testCase "changes the digest when exact Schema bytes change" digestBinding
    ]

validAuthority :: IO ()
validAuthority = do
  schema <-
    requireSchema
      "o2i.test.result"
      1
      ("completed" :| ["unavailable"])
      schemaBytes
  let authority = machineSchemaAuthority schema
  schemaIdentityText (schemaAuthorityIdentity authority) @?= "o2i.test.result"
  schemaVersionValue (schemaAuthorityVersion authority) @?= 1
  schemaAuthorityReference authority @?= "o2i.test.result/v1"
  schemaDigestText (schemaAuthorityDigest authority)
    @?= "a2c799262a3ce3c19ef5cdd983bf3d12b43ab3c426227091b909dcb7054738c0"
  fmap schemaVariantText (NonEmpty.toList (machineSchemaVariants schema))
    @?= ["completed", "unavailable"]

invalidAuthority :: IO ()
invalidAuthority =
  case defineMachineSchema
         "O2I..result"
         0
         ("bad_value" :| ["duplicate", "duplicate"])
         ByteString.empty of
    Right _ -> assertFailure "invalid generated metadata was accepted"
    Left defects ->
      fmap defectTag (NonEmpty.toList defects)
        @?= [ "identity:O2I..result"
            , "version:0"
            , "document:empty"
            , "variant:bad_value"
            , "variant-duplicate:duplicate"
            ]

variantOrder :: IO ()
variantOrder = do
  schema <-
    requireSchema
      "o2i.test.order"
      2
      ("z-last" :| ["a-first", "middle"])
      schemaBytes
  fmap schemaVariantText (NonEmpty.toList (machineSchemaVariants schema))
    @?= ["z-last", "a-first", "middle"]

digestBinding :: IO ()
digestBinding = do
  first <- requireSchema "o2i.test.digest" 1 ("one" :| []) schemaBytes
  second <-
    requireSchema
      "o2i.test.digest"
      1
      ("one" :| [])
      (schemaBytes <> ByteString.pack "\n")
  schemaAuthorityDigest (machineSchemaAuthority first)
    /= schemaAuthorityDigest (machineSchemaAuthority second) @?= True

schemaBytes :: ByteString.ByteString
schemaBytes = ByteString.pack "{\"type\":\"object\"}"

requireSchema ::
     Text
  -> Natural
  -> NonEmpty Text
  -> ByteString.ByteString
  -> IO MachineSchema
requireSchema identity version variants bytes =
  case defineMachineSchema identity version variants bytes of
    Left defects ->
      assertFailure ("expected valid generated metadata, got " <> show defects)
        >> requireSchema identity version variants bytes
    Right schema -> pure schema

defectTag :: SchemaDefinitionDefect -> String
defectTag defect =
  case defect of
    InvalidSchemaIdentity value -> "identity:" <> showText value
    InvalidSchemaVersion value -> "version:" <> show value
    EmptySchemaDocument -> "document:empty"
    InvalidSchemaVariant value -> "variant:" <> showText value
    DuplicateSchemaVariant value -> "variant-duplicate:" <> showText value

showText :: Text -> String
showText = Text.unpack
