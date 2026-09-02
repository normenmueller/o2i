{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.CommandError
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.Foldable (toList, traverse_)
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (nub)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import qualified O2I.Assessment as Assessment
import O2I.Operation.Acquisition (acquiredSourceIdentity)
import O2I.Operation.Acquisition.Internal
  ( AcquisitionFailure(..)
  , acquireWith
  , standardInput
  )
import qualified O2I.Operation.Assess.Result.Internal as AssessInternal
import O2I.Operation.Command.Error
import O2I.Operation.Command.Error.Branch.Generated
  ( assessOwnerBranchToken
  , assessOwnerBranches
  , qualifyOwnerBranchToken
  , qualifyOwnerBranches
  , readinessOwnerBranchToken
  , readinessOwnerBranches
  , validateOwnerBranchToken
  , validateOwnerBranches
  )
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Failure
  ( commandFailure
  , inputAcquisitionFailure
  , preparationFailure
  )
import O2I.Operation.Failure.Internal (PreparationFailure(..))
import O2I.Operation.Machine
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(..)
  , mkSourceReference
  , sourceOrdinal
  )
import qualified O2I.Operation.Qualify.Result.Internal as QualifyInternal
import qualified O2I.Operation.Readiness.Result.Internal as ReadinessInternal
import O2I.Operation.Schema
import qualified O2I.Operation.Validate.Result.Internal as ValidateInternal
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental
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
    , testCase
        "closes every generated owner inventory against the embedded Schema"
        ownerBranchInventoryBijection
    , testCase
        "retains and encodes every capability owner category"
        ownerCategoryDocuments
    , testCase
        "retains and encodes common failures through every capability lift"
        commonCapabilityDocuments
    , testCase
        "separates Readiness and Assessment source roles with full evidence"
        distinctPrimaryOwnerRoles
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
    (const 3)
    (const 4)
    (const 5)
    (const 6)
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
  supplementalDefects <-
    requireLeft
      (Supplemental.decodeSupplementalInput
         ()
         (Supplemental.supplementalInputOrdinal 0)
         "{")
  evidenceDefects <-
    requireLeft
      (Readiness.decodeReadinessInput (Readiness.readinessInputOrdinal 0) "{}")
  assessmentDefects <-
    requireLeft
      (Assessment.decodeAssessmentBundleInput
         (Assessment.assessmentInputOrdinal 0)
         "{}")
  let process =
        processCommandError
          (inputAcquisitionFailure
             (AcquisitionFailure
                (standardInput reference)
                (userError "unavailable")))
      preparation =
        commonCommandError
          (preparationFailure (ProfileMarkerPreparationFailure []))
      errors =
        [ argumentCommandError argument
        , process
        , preparation
        , validateCommandError
            (ValidateInternal.ValidateSupplementalInputFailure
               supplementalDefects)
        , qualifyCommandError
            (QualifyInternal.QualifySupplementalInputFailure supplementalDefects)
        , readinessCommandError
            (ReadinessInternal.ReadinessEvidenceInputFailure evidenceDefects)
        , assessCommandError
            (AssessInternal.AssessBundleInputFailure assessmentDefects)
        ]
      documents = map (commandErrorDocument tool) errors
      encoded = fmap encodeCommandErrorDocument documents
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= [ "argument-invalid"
        , "command-failed"
        , "preparation-failed"
        , "validate-failed"
        , "qualify-failed"
        , "readiness-failed"
        , "assess-failed"
        ]
  fmap commandErrorCode errors
    @?= [ "cli.argument.input"
        , "command.input-io"
        , "preparation.profile-marker"
        , "validate.supplemental-input"
        , "qualify.supplemental-input"
        , "readiness.evidence-input"
        , "assess.assessment-input"
        ]
  fmap
    schemaVariantText
    (NonEmpty.toList (machineSchemaVariants commandErrorSchema))
    @?= [ "argument-invalid"
        , "command-failed"
        , "preparation-failed"
        , "validate-failed"
        , "qualify-failed"
        , "readiness-failed"
        , "assess-failed"
        ]
  take 3 encoded
    @?= [ "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"argument-invalid\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"cli.argument.input\",\"message\":\"missing input\"}"
        , "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"command-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"command.input-io\",\"failure\":{\"sourceKind\":\"stdin\",\"sourceReference\":\"stdin\",\"message\":\"user error (unavailable)\"}}"
        , "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"preparation-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"preparation.profile-marker\",\"stage\":\"profile-marker\"}"
        ]
  traverse_ assertEmbeddedSchema encoded

ownerBranchInventoryBijection :: Assertion
ownerBranchInventoryBijection = do
  schema <-
    case Aeson.eitherDecodeStrict commandErrorSchemaBytes of
      Left message ->
        assertFailure ("embedded Schema: " <> message) >> fail "unreachable"
      Right value -> pure value
  let inventories =
        [ ( "validateFailure"
          , 10
          , map validateOwnerBranchToken (NonEmpty.toList validateOwnerBranches))
        , ( "qualifyFailure"
          , 10
          , map qualifyOwnerBranchToken (NonEmpty.toList qualifyOwnerBranches))
        , ( "readinessFailure"
          , 11
          , map
              readinessOwnerBranchToken
              (NonEmpty.toList readinessOwnerBranches))
        , ( "assessFailure"
          , 11
          , map assessOwnerBranchToken (NonEmpty.toList assessOwnerBranches))
        ]
  traverse_
    (\(definition, cardinality, tokens) -> do
       length tokens @?= cardinality
       length (nub tokens) @?= cardinality
       schemaOwnerBranchTokens definition schema @?= Right tokens)
    inventories

schemaOwnerBranchTokens :: Text.Text -> Aeson.Value -> Either String [Text.Text]
schemaOwnerBranchTokens definition schema =
  case schema of
    Aeson.Object root ->
      case [ mapMaybeText (toList values)
           | Just (Aeson.Object definitions) <-
               [AesonKeyMap.lookup "$defs" root]
           , Just (Aeson.Object failure) <-
               [AesonKeyMap.lookup (AesonKey.fromText definition) definitions]
           , Just (Aeson.Array alternatives) <-
               [AesonKeyMap.lookup "oneOf" failure]
           , Aeson.Object alternative <- toList alternatives
           , Just (Aeson.Object properties) <-
               [AesonKeyMap.lookup "properties" alternative]
           , Just (Aeson.Object category) <-
               [AesonKeyMap.lookup "category" properties]
           , AesonKeyMap.lookup "const" category
               == Just (Aeson.String "owner-contract")
           , Just (Aeson.Object branch) <-
               [AesonKeyMap.lookup "branch" properties]
           , Just (Aeson.Array values) <- [AesonKeyMap.lookup "enum" branch]
           ] of
        [Just tokens] -> Right tokens
        _ ->
          Left
            ("missing exact owner branch enum for " <> Text.unpack definition)
    _ -> Left "command-error Schema is not an object"
  where
    mapMaybeText values =
      if length texts == length values
        then Just texts
        else Nothing
      where
        texts = [value | Aeson.String value <- values]

ownerCategoryDocuments :: Assertion
ownerCategoryDocuments = do
  tool <- requireTool
  reference <- requireRight (mkSourceReference "owner-model")
  acquiredResult <-
    acquireWith
      (const (pure ByteString.empty))
      (pure ByteString.empty)
      ModelRole
      (sourceOrdinal 0)
      (standardInput reference)
  acquired <-
    case acquiredResult of
      Left _ ->
        assertFailure "in-memory acquisition failed" >> fail "unreachable"
      Right value -> pure value
  let identity = acquiredSourceIdentity acquired
      errors =
        [ validateCommandError
            (ValidateInternal.ValidateOwnerContractFailure
               (ValidateInternal.ValidateAcquiredModelRoleFailure identity))
        , qualifyCommandError
            (QualifyInternal.QualifyOwnerContractFailure
               (QualifyInternal.QualifyAcquiredModelRoleFailure identity))
        , readinessCommandError
            (ReadinessInternal.ReadinessOwnerContractFailure
               (ReadinessInternal.ReadinessAcquiredModelRoleFailure identity))
        , assessCommandError
            (AssessInternal.AssessOwnerContractFailure
               (AssessInternal.AssessAcquiredModelRoleFailure identity))
        ]
      documents = map (commandErrorDocument tool) errors
      encoded = map encodeCommandErrorDocument documents
  fmap commandErrorCode errors
    @?= [ "validate.owner-contract"
        , "qualify.owner-contract"
        , "readiness.owner-contract"
        , "assess.owner-contract"
        ]
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= [ "validate-failed"
        , "qualify-failed"
        , "readiness-failed"
        , "assess-failed"
        ]
  encoded
    @?= [ ownerBytes "validate-failed" "validate.owner-contract"
        , ownerBytes "qualify-failed" "qualify.owner-contract"
        , ownerBytes "readiness-failed" "readiness.owner-contract"
        , ownerBytes "assess-failed" "assess.owner-contract"
        ]
  traverse_ assertEmbeddedSchema encoded

commonCapabilityDocuments :: Assertion
commonCapabilityDocuments = do
  tool <- requireTool
  reference <- requireRight (mkSourceReference "common-stdin")
  let common = preparationFailure (ProfileMarkerPreparationFailure [])
      errors =
        [ validateCommandError (ValidateInternal.ValidateCommonFailure common)
        , qualifyCommandError (QualifyInternal.QualifyCommonFailure common)
        , readinessCommandError
            (ReadinessInternal.ReadinessCommonFailure common)
        , assessCommandError (AssessInternal.AssessCommonFailure common)
        ]
      documents = map (commandErrorDocument tool) errors
      encoded = map encodeCommandErrorDocument documents
  fmap commandErrorCode errors @?= replicate 4 "preparation.profile-marker"
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= replicate 4 "preparation-failed"
  encoded
    @?= replicate
          4
          "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"preparation-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"preparation.profile-marker\",\"stage\":\"profile-marker\"}"
  traverse_ assertEmbeddedSchema encoded
  let process =
        commandFailure
          (inputAcquisitionFailure
             (AcquisitionFailure
                (standardInput reference)
                (userError "common unavailable")))
      processErrors =
        [ validateCommandError (ValidateInternal.ValidateCommonFailure process)
        , qualifyCommandError (QualifyInternal.QualifyCommonFailure process)
        , readinessCommandError
            (ReadinessInternal.ReadinessCommonFailure process)
        , assessCommandError (AssessInternal.AssessCommonFailure process)
        ]
      processDocuments = map (commandErrorDocument tool) processErrors
      processEncoded = map encodeCommandErrorDocument processDocuments
  fmap commandErrorCode processErrors @?= replicate 4 "command.input-io"
  fmap (schemaVariantText . commandErrorDocumentVariant) processDocuments
    @?= replicate 4 "command-failed"
  processEncoded
    @?= replicate
          4
          "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"command-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"command.input-io\",\"failure\":{\"sourceKind\":\"stdin\",\"sourceReference\":\"common-stdin\",\"message\":\"user error (common unavailable)\"}}"
  traverse_ assertEmbeddedSchema processEncoded

distinctPrimaryOwnerRoles :: Assertion
distinctPrimaryOwnerRoles = do
  readiness <- requireSourceIdentity ReadinessRole "readiness-source"
  assessment <- requireSourceIdentity AssessmentRole "assessment-source"
  let readinessDiagnostic =
        readinessCommandOwnerDiagnostic
          (ReadinessInternal.ReadinessAcquiredEvidenceRoleFailure readiness)
      assessmentDiagnostic =
        assessCommandOwnerDiagnostic
          (AssessInternal.AssessAcquiredBundleRoleFailure assessment)
  ownerDiagnosticSummary readinessDiagnostic
    @?= ( "acquired-readiness-role"
        , [ ( "source-identity"
            , [ ( "source"
                , [ "source-identity:readiness:0:readiness-source:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                  ])
              ])
          ])
  ownerDiagnosticSummary assessmentDiagnostic
    @?= ( "acquired-assessment-role"
        , [ ( "source-identity"
            , [ ( "source"
                , [ "source-identity:assessment:0:assessment-source:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                  ])
              ])
          ])

ownerDiagnosticSummary ::
     CommandOwnerDiagnostic
  -> (Text.Text, [(Text.Text, [(Text.Text, [Text.Text])])])
ownerDiagnosticSummary =
  foldCommandOwnerDiagnostic $ \branch evidence ->
    (branch, map evidenceSummary (NonEmpty.toList evidence))
  where
    evidenceSummary =
      foldCommandOwnerEvidence $ \kind fields -> (kind, map fieldSummary fields)
    fieldSummary =
      foldCommandDiagnosticField $ \name values ->
        (name, map valueSummary values)
    valueSummary =
      foldCommandDiagnosticValue
        ("text:" <>)
        (("natural:" <>) . Text.pack . show)
        ("model-identity:" <>)
        ("occurrence-identity:" <>)
        ("qualified-type:" <>)
        (\role ordinal ->
           Text.intercalate ":" ["source-key", role, Text.pack (show ordinal)])
        (\role ordinal reference digest ->
           Text.intercalate
             ":"
             [ "source-identity"
             , role
             , Text.pack (show ordinal)
             , reference
             , digest
             ])
        (\identifier name version notation ->
           Text.intercalate
             ":"
             ["adapter-descriptor", identifier, name, version, notation])
        (\kind ordinal ->
           Text.intercalate
             ":"
             ["canonical-occurrence", kind, Text.pack (show ordinal)])
        (\index codePoint ->
           Text.intercalate
             ":"
             [ "unicode-scalar"
             , Text.pack (show index)
             , Text.pack (show codePoint)
             ])

requireSourceIdentity :: SourceRole -> Text.Text -> IO SourceIdentity
requireSourceIdentity role source = do
  reference <- requireRight (mkSourceReference source)
  result <-
    acquireWith
      (const (pure ByteString.empty))
      (pure ByteString.empty)
      role
      (sourceOrdinal 0)
      (standardInput reference)
  acquired <- requireRight result
  pure (acquiredSourceIdentity acquired)

ownerBytes :: Text.Text -> Text.Text -> ByteString
ownerBytes variant code =
  Text.encodeUtf8
    ("{\"schema\":\"o2i.command-error/v1\",\"kind\":\""
       <> variant
       <> "\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\""
       <> code
       <> "\",\"failure\":{\"category\":\"owner-contract\",\"branch\":\"acquired-model-role\",\"evidence\":[{\"kind\":\"source-identity\",\"fields\":[{\"name\":\"source\",\"values\":[{\"kind\":\"source-identity\",\"role\":\"model\",\"ordinal\":0,\"reference\":\"owner-model\",\"sha256\":\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"}]}]}]}}")

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

requireLeft :: Either failure value -> IO failure
requireLeft result =
  case result of
    Left failure -> pure failure
    Right _ -> assertFailure "expected a decoding failure" >> fail "unreachable"

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
