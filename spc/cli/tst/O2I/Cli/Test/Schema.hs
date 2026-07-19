{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Schema
  ( tests
  ) where

import Data.Aeson (Value(..), decodeStrict')
import Data.Aeson.Key (Key)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as ByteString
import O2I.Cli.Test.Support
import System.Exit (ExitCode(..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "JSON schema"
    [ testCase "inspection document discriminator" inspectionDiscriminator
    , testCase "inspection has exactly eight stages" eightStages
    , testCase
        "resolved scope carries mandatory closed provenance"
        resolvedScopeProvenance
    , testCase "command-error document discriminator" commandDiscriminator
    , testCase "JSON is one prefix-free document" prefixFreeDocument
    ]

inspectionDiscriminator :: Assertion
inspectionDiscriminator = do
  bytes <- fixtureBytes "partial-strategy.archimate"
  result <- runO2I ["inspect", "-", "--view", "CLI Scope", "--json"] bytes
  processExitCode result @?= ExitFailure 3
  field "schema" (decoded (processStdout result))
    @?= Just (String "o2i.inspection.report/v1")

eightStages :: Assertion
eightStages = do
  bytes <- fixtureBytes "partial-strategy.archimate"
  result <- runO2I ["inspect", "-", "--view-id", "view", "--json"] bytes
  case field "stages" (decoded (processStdout result)) of
    Just (Array stages) -> length stages @?= 8
    _ -> assertFailure "missing stages array"

resolvedScopeProvenance :: Assertion
resolvedScopeProvenance = do
  bytes <- fixtureBytes "partial-strategy.archimate"
  result <- runO2I ["inspect", "-", "--view-id", "view", "--json"] bytes
  let decodedReport = decoded (processStdout result)
  case nestedField ["scope", "provenance", "occurrences"] decodedReport of
    Just (Array occurrences) -> length occurrences @?= 2
    _ -> assertFailure "resolved scope omitted closed provenance"

commandDiscriminator :: Assertion
commandDiscriminator = do
  result <-
    runO2I
      ["inspect", "missing-cli-model.archimate", "--view", "Scope", "--json"]
      ByteString.empty
  processExitCode result @?= ExitFailure 2
  field "schema" (decoded (processStdout result))
    @?= Just (String "o2i.command-error/v1")
  field "inspectionState" (decoded (processStdout result)) @?= Nothing

prefixFreeDocument :: Assertion
prefixFreeDocument = do
  result <-
    runO2I
      ["inspect", "missing-cli-model.archimate", "--view", "Scope", "--json"]
      ByteString.empty
  case decodeStrict' (processStdout result) :: Maybe Value of
    Nothing -> assertFailure "stdout is not one JSON document"
    Just _ -> do
      assertBool
        "stdout contains process prefix"
        (not (ByteString.isInfixOf "[o2i|" (processStdout result)))
      processStderr result @?= ByteString.empty

decoded :: ByteString.ByteString -> Value
decoded bytes =
  case decodeStrict' bytes of
    Just value -> value
    Nothing -> Null

field :: Key -> Value -> Maybe Value
field key value =
  case value of
    Object object -> KeyMap.lookup key object
    _ -> Nothing

nestedField :: [Key] -> Value -> Maybe Value
nestedField keys value =
  case keys of
    [] -> Just value
    key:rest -> field key value >>= nestedField rest
