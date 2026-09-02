{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.CommandError
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.Foldable (traverse_)
import Data.JSON.JSONSchema (validateJSONSchema)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Operation.Acquisition.Internal
  ( AcquisitionFailure(..)
  , standardInput
  )
import O2I.Operation.Command.Error
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Failure (inputAcquisitionFailure, preparationFailure)
import O2I.Operation.Failure.Internal (PreparationFailure(..))
import O2I.Operation.Machine
import O2I.Operation.Provenance (mkSourceReference)
import O2I.Operation.Schema
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "command error boundary"
    [ testCase
        "validates exact argument scalars without normalization"
        argumentAuthoring
    , testCase
        "accumulates every argument authoring defect in field order"
        argumentDefects
    , testCase
        "closes the exact ADT, encoder, and Schema variant bijection"
        branchBijection
    , testCase "embeds the exact generated Schema bytes" embeddedSchema
    ]

argumentAuthoring :: Assertion
argumentAuthoring = do
  failure <- requireArgument "cli.argument.view-id" "  View Ω was not found  "
  argumentFailureCode failure @?= "cli.argument.view-id"
  argumentFailureMessage failure @?= "  View Ω was not found  "
  foldArgumentFailure (,) failure
    @?= ("cli.argument.view-id", "  View Ω was not found  ")
  commandErrorCode (argumentCommandError failure) @?= "cli.argument.view-id"
  foldCommandError
    (const (0 :: Int))
    (const 1)
    (const 2)
    (argumentCommandError failure)
    @?= 0

argumentDefects :: Assertion
argumentDefects = do
  defectTags (argumentFailure "" "") @?= ["empty:code", "empty:message"]
  defectTags (argumentFailure "CLI.argument.bad" "ok")
    @?= ["invalid:CLI.argument.bad"]
  defectTags (argumentFailure "cli.argument.bad--token" "bad\NULmessage")
    @?= ["invalid:cli.argument.bad--token", "nul:message"]

branchBijection :: Assertion
branchBijection = do
  tool <- requireTool
  argument <- requireArgument "cli.argument.input" "missing input"
  reference <- requireRight (mkSourceReference "stdin")
  let process =
        processCommandError
          (inputAcquisitionFailure
             (AcquisitionFailure
                (standardInput reference)
                (userError "unavailable")))
      preparation =
        commonCommandError
          (preparationFailure (ProfileMarkerPreparationFailure []))
      documents =
        [ commandErrorDocument tool (argumentCommandError argument)
        , commandErrorDocument tool process
        , commandErrorDocument tool preparation
        ]
      encoded = fmap encodeCommandErrorDocument documents
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= ["argument-invalid", "command-failed", "preparation-failed"]
  fmap
    schemaVariantText
    (NonEmpty.toList (machineSchemaVariants commandErrorSchema))
    @?= ["argument-invalid", "command-failed", "preparation-failed"]
  encoded
    @?= [ "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"argument-invalid\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"cli.argument.input\",\"message\":\"missing input\"}"
        , "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"command-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"command.input-io\",\"failure\":{\"sourceKind\":\"stdin\",\"sourceReference\":\"stdin\",\"message\":\"user error (unavailable)\"}}"
        , "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"preparation-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"preparation.profile-marker\",\"stage\":\"profile-marker\"}"
        ]
  traverse_ assertEmbeddedSchema encoded

embeddedSchema :: Assertion
embeddedSchema = do
  checkedIn <- ByteString.readFile schemaPath
  commandErrorSchemaBytes @?= checkedIn
  schemaAuthorityReference (machineSchemaAuthority commandErrorSchema)
    @?= "o2i.command-error/v1"

assertEmbeddedSchema :: ByteString -> Assertion
assertEmbeddedSchema encoded = do
  schemaValue <-
    case Aeson.eitherDecodeStrict commandErrorSchemaBytes of
      Left message -> assertFailure ("embedded Schema: " <> message)
      Right value -> pure value
  documentValue <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure ("command-error document: " <> message)
      Right value -> pure value
  validateJSONSchema schemaValue documentValue
    @? "encoded command error violates the embedded Schema"

schemaPath :: FilePath
schemaPath = "contract" </> "schema" </> "o2i.command-error-v1.schema.json"

requireArgument :: Text.Text -> Text.Text -> IO ArgumentFailure
requireArgument code message = requireRight (argumentFailure code message)

requireTool :: IO ToolDescriptor
requireTool = requireRight (mkToolDescriptor "o2i" "0.3.0")

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

defectTags ::
     Either (NonEmpty.NonEmpty ArgumentFailureDefect) ArgumentFailure
  -> [String]
defectTags result =
  case result of
    Right _ -> ["accepted"]
    Left defects -> fmap defectTag (NonEmpty.toList defects)

defectTag :: ArgumentFailureDefect -> String
defectTag =
  foldArgumentFailureDefect
    (("invalid:" <>) . Text.unpack)
    (("empty:" <>) . field)
    (("nul:" <>) . field)
    (("surrogate:" <>) . field)
  where
    field = Text.unpack . argumentFailureFieldText
