{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Output
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import O2I.Cli.Options (CliError(..))
import O2I.Cli.Output
import O2I.Operation.Command.Error.Machine (commandErrorSchemaBytes)
import O2I.Operation.Machine (mkToolDescriptor)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "command-error output"
    [ testCase "uses the canonical Operation document" canonicalDocument
    , testCase "rejects a non-argument CLI code before output" invalidCode
    ]

canonicalDocument :: Assertion
canonicalDocument = do
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  encoded <-
    requireRight
      (prepareArgumentCommandError
         tool
         (CliError "cli.argument.command" "Unknown command: frobnicate"))
  encoded
    @?= ByteString.concat
          [ "{\"schema\":\"o2i.command-error/v1\","
          , "\"kind\":\"argument-invalid\","
          , "\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},"
          , "\"code\":\"cli.argument.command\","
          , "\"message\":\"Unknown command: frobnicate\"}"
          ]
  schema <- decode "embedded command-error Schema" commandErrorSchemaBytes
  document <- decode "prepared command-error document" encoded
  validateJSONSchema schema document
    @? "prepared command-error document violates the exact embedded Schema"

invalidCode :: Assertion
invalidCode = do
  tool <- requireRight (mkToolDescriptor "o2i" "0.3.0")
  prepareArgumentCommandError
    tool
    (CliError "cli.internal.failure" "Internal failure")
    @?= Left InvalidArgumentCommandError

decode :: String -> ByteString.ByteString -> IO Aeson.Value
decode label bytes =
  case Aeson.eitherDecodeStrict bytes of
    Left message ->
      assertFailure (label <> ": " <> message) >> fail "unreachable"
    Right value -> pure value

requireRight :: Show failure => Either failure value -> IO value
requireRight outcome =
  case outcome of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
