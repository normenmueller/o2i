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
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import qualified O2I.Assessment as Assessment
import O2I.Core.Identity (occurrenceIdentity)
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
  , qualificationSubjectsOwnerBranchToken
  , qualificationSubjectsOwnerBranches
  , qualifyOwnerBranchToken
  , qualifyOwnerBranches
  , readinessOwnerBranchToken
  , readinessOwnerBranches
  , traceOwnerBranchToken
  , traceOwnerBranches
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
import qualified O2I.Operation.Qualification.Subjects.Result.Internal as SubjectsInternal
import qualified O2I.Operation.Qualify.Result.Internal as QualifyInternal
import qualified O2I.Operation.Readiness.Result.Internal as ReadinessInternal
import O2I.Operation.Schema
import qualified O2I.Operation.Trace.Result.Internal as TraceInternal
import qualified O2I.Operation.Validate.Result.Internal as ValidateInternal
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental
import qualified O2I.Structure as Structure
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
    , testCase
        "rejects cross-branch and empty owner evidence"
        rejectsInvalidOwnerEvidence
    , testCase
        "rejects impossible closed owner scalar values"
        rejectsImpossibleOwnerScalars
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
    (const 7)
    (const 8)
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
        , qualificationSubjectsCommandError
            (SubjectsInternal.QualificationSubjectsSupplementalInputFailure
               supplementalDefects)
        , traceCommandError
            (TraceInternal.TraceOwnerContractFailure
               (TraceInternal.TraceSemanticModelContractFailure []))
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
        , "qualification-subjects-failed"
        , "trace-failed"
        ]
  fmap commandErrorCode errors
    @?= [ "cli.argument.input"
        , "command.input-io"
        , "preparation.profile-marker"
        , "validate.supplemental-input"
        , "qualify.supplemental-input"
        , "readiness.evidence-input"
        , "assess.assessment-input"
        , "qualification-subjects.supplemental-input"
        , "trace.owner-contract"
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
        , "qualification-subjects-failed"
        , "trace-failed"
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
        , ( "qualificationSubjectsFailure"
          , 12
          , map
              qualificationSubjectsOwnerBranchToken
              (NonEmpty.toList qualificationSubjectsOwnerBranches))
        , ( "traceFailure"
          , 10
          , map traceOwnerBranchToken (NonEmpty.toList traceOwnerBranches))
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
      case AesonKeyMap.lookup "$defs" root of
        Just (Aeson.Object definitions) ->
          case AesonKeyMap.lookup (AesonKey.fromText definition) definitions of
            Just failure -> Right (ownerBranchTokens failure)
            Nothing ->
              Left ("missing Schema definition " <> Text.unpack definition)
        _ -> Left "command-error Schema has no definitions"
    _ -> Left "command-error Schema is not an object"
  where
    ownerBranchTokens value =
      case value of
        Aeson.Object object ->
          case ownerBranchToken object of
            Just token -> [token]
            Nothing -> concatMap ownerBranchTokens (AesonKeyMap.elems object)
        Aeson.Array values -> concatMap ownerBranchTokens (toList values)
        _ -> []
    ownerBranchToken object = do
      Aeson.Object properties <- AesonKeyMap.lookup "properties" object
      Aeson.Object category <- AesonKeyMap.lookup "category" properties
      Aeson.String "owner-contract" <- AesonKeyMap.lookup "const" category
      Aeson.Object branch <- AesonKeyMap.lookup "branch" properties
      Aeson.String token <- AesonKeyMap.lookup "const" branch
      pure token

ownerCategoryDocuments :: Assertion
ownerCategoryDocuments = do
  tool <- requireTool
  reference <- requireRight (mkSourceReference "owner-model")
  acquiredResult <-
    acquireWith
      (const (pure ByteString.empty))
      (pure ByteString.empty)
      AssessmentRole
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
        , qualificationSubjectsCommandError
            (SubjectsInternal.QualificationSubjectsOwnerContractFailure
               (SubjectsInternal.QualificationSubjectsAcquiredModelRoleFailure
                  identity))
        , traceCommandError
            (TraceInternal.TraceOwnerContractFailure
               (TraceInternal.TraceAcquiredModelRoleFailure identity))
        ]
      documents = map (commandErrorDocument tool) errors
      encoded = map encodeCommandErrorDocument documents
  fmap commandErrorCode errors
    @?= [ "validate.owner-contract"
        , "qualify.owner-contract"
        , "readiness.owner-contract"
        , "assess.owner-contract"
        , "qualification-subjects.owner-contract"
        , "trace.owner-contract"
        ]
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= [ "validate-failed"
        , "qualify-failed"
        , "readiness-failed"
        , "assess-failed"
        , "qualification-subjects-failed"
        , "trace-failed"
        ]
  encoded
    @?= [ ownerBytes "validate-failed" "validate.owner-contract"
        , ownerBytes "qualify-failed" "qualify.owner-contract"
        , ownerBytes "readiness-failed" "readiness.owner-contract"
        , ownerBytes "assess-failed" "assess.owner-contract"
        , ownerBytes
            "qualification-subjects-failed"
            "qualification-subjects.owner-contract"
        , ownerBytes "trace-failed" "trace.owner-contract"
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
        , qualificationSubjectsCommandError
            (SubjectsInternal.QualificationSubjectsCommonFailure common)
        , traceCommandError (TraceInternal.TraceCommonFailure common)
        ]
      documents = map (commandErrorDocument tool) errors
      encoded = map encodeCommandErrorDocument documents
  fmap commandErrorCode errors @?= replicate 6 "preparation.profile-marker"
  fmap (schemaVariantText . commandErrorDocumentVariant) documents
    @?= replicate 6 "preparation-failed"
  encoded
    @?= replicate
          6
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
        , qualificationSubjectsCommandError
            (SubjectsInternal.QualificationSubjectsCommonFailure process)
        , traceCommandError (TraceInternal.TraceCommonFailure process)
        ]
      processDocuments = map (commandErrorDocument tool) processErrors
      processEncoded = map encodeCommandErrorDocument processDocuments
  fmap commandErrorCode processErrors @?= replicate 6 "command.input-io"
  fmap (schemaVariantText . commandErrorDocumentVariant) processDocuments
    @?= replicate 6 "command-failed"
  processEncoded
    @?= replicate
          6
          "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"command-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"command.input-io\",\"failure\":{\"sourceKind\":\"stdin\",\"sourceReference\":\"common-stdin\",\"message\":\"user error (common unavailable)\"}}"
  traverse_ assertEmbeddedSchema processEncoded

distinctPrimaryOwnerRoles :: Assertion
distinctPrimaryOwnerRoles = do
  tool <- requireTool
  assessment <- requireSourceIdentity AssessmentRole "assessment-source"
  readiness <- requireSourceIdentity ReadinessRole "readiness-source"
  encodeCommandErrorDocument
    (commandErrorDocument
       tool
       (readinessCommandError
          (ReadinessInternal.ReadinessOwnerContractFailure
             (ReadinessInternal.ReadinessAcquiredEvidenceRoleFailure assessment))))
    @?= ownerSourceBytes
          "readiness-failed"
          "readiness.owner-contract"
          "acquired-readiness-role"
          "assessment"
          "assessment-source"
  encodeCommandErrorDocument
    (commandErrorDocument
       tool
       (assessCommandError
          (AssessInternal.AssessOwnerContractFailure
             (AssessInternal.AssessAcquiredBundleRoleFailure readiness))))
    @?= ownerSourceBytes
          "assess-failed"
          "assess.owner-contract"
          "acquired-assessment-role"
          "readiness"
          "readiness-source"

rejectsInvalidOwnerEvidence :: Assertion
rejectsInvalidOwnerEvidence = do
  tool <- requireTool
  mismatched <-
    requireSourceIdentity AssessmentRole "hostile-\"assessment\"\nsource"
  let sourceBytes =
        encodeCommandErrorDocument
          (commandErrorDocument
             tool
             (traceCommandError
                (TraceInternal.TraceOwnerContractFailure
                   (TraceInternal.TraceAcquiredModelRoleFailure mismatched))))
      semanticBytes =
        encodeCommandErrorDocument
          (commandErrorDocument
             tool
             (traceCommandError
                (TraceInternal.TraceOwnerContractFailure
                   (TraceInternal.TraceSemanticModelContractFailure []))))
  sourceValue <- requireJSON sourceBytes
  semanticValue <- requireJSON semanticBytes
  assertEmbeddedSchema sourceBytes
  assertEmbeddedSchema semanticBytes
  assertRejectedByEmbeddedSchema
    (replaceOwnerBranch "acquired-model-role" semanticValue)
  assertRejectedByEmbeddedSchema (replaceOwnerFields [] sourceValue)
  assertRejectedByEmbeddedSchema
    (replaceOwnerFieldMember "source" "role" (Aeson.String "model") sourceValue)
  assertRejectedByEmbeddedSchema
    (replaceOwnerFieldMember
       "source"
       "role"
       (Aeson.String "unknown-role")
       sourceValue)
  traverse_
    (\reference ->
       assertRejectedByEmbeddedSchema
         (replaceOwnerFieldMember
            "source"
            "reference"
            (Aeson.String reference)
            sourceValue))
    ["", "contains\NULnul"]

rejectsImpossibleOwnerScalars :: Assertion
rejectsImpossibleOwnerScalars = do
  tool <- requireTool
  occurrence <- requireRight (occurrenceIdentity "closed-domain-occurrence")
  let projectionBytes =
        encodeCommandErrorDocument
          (commandErrorDocument
             tool
             (traceCommandError
                (TraceInternal.TraceOwnerContractFailure
                   (TraceInternal.TraceStructureInputFailure
                      (Structure.DuplicateStructureProjection
                         occurrence
                         (Structure.CarrierProjectionKind :| [])
                         :| [])))))
      endpointBytes =
        encodeCommandErrorDocument
          (commandErrorDocument
             tool
             (traceCommandError
                (TraceInternal.TraceOwnerContractFailure
                   (TraceInternal.TraceStructureInputFailure
                      (Structure.MissingCarrierProjection
                         occurrence
                         Structure.RelationSourceRole
                         occurrence
                         :| [])))))
  traverse_ assertEmbeddedSchema [projectionBytes, endpointBytes]
  projectionValue <- requireJSON projectionBytes
  endpointValue <- requireJSON endpointBytes
  assertRejectedByEmbeddedSchema
    (replaceOwnerFieldMember
       "projectionKinds"
       "value"
       (Aeson.String "unknown-projection-kind")
       projectionValue)
  assertRejectedByEmbeddedSchema
    (replaceOwnerFieldMember
       "endpointRole"
       "value"
       (Aeson.String "unknown-endpoint-role")
       endpointValue)

replaceOwnerBranch :: Text.Text -> Aeson.Value -> Aeson.Value
replaceOwnerBranch branch =
  mapFailureObject (AesonKeyMap.insert "branch" (Aeson.String branch))

replaceOwnerFields :: [Aeson.Value] -> Aeson.Value -> Aeson.Value
replaceOwnerFields fields =
  mapFailureObject $ \failure ->
    case AesonKeyMap.lookup "evidence" failure of
      Just (Aeson.Array evidence) ->
        AesonKeyMap.insert
          "evidence"
          (Aeson.toJSON (map clearFields (toList evidence)))
          failure
      _ -> failure
  where
    clearFields (Aeson.Object evidence) =
      Aeson.Object (AesonKeyMap.insert "fields" (Aeson.toJSON fields) evidence)
    clearFields value = value

replaceOwnerFieldMember ::
     Text.Text -> Text.Text -> Aeson.Value -> Aeson.Value -> Aeson.Value
replaceOwnerFieldMember fieldName memberName replacement =
  mapFailureObject $ \failure ->
    case AesonKeyMap.lookup "evidence" failure of
      Just (Aeson.Array evidence) ->
        AesonKeyMap.insert
          "evidence"
          (Aeson.Array (fmap replaceEvidence evidence))
          failure
      _ -> failure
  where
    replaceEvidence (Aeson.Object evidence) =
      case AesonKeyMap.lookup "fields" evidence of
        Just (Aeson.Array fields) ->
          Aeson.Object
            (AesonKeyMap.insert
               "fields"
               (Aeson.Array (fmap replaceField fields))
               evidence)
        _ -> Aeson.Object evidence
    replaceEvidence value = value
    replaceField (Aeson.Object field)
      | AesonKeyMap.lookup "name" field == Just (Aeson.String fieldName) =
        case AesonKeyMap.lookup "values" field of
          Just (Aeson.Array values) ->
            Aeson.Object
              (AesonKeyMap.insert
                 "values"
                 (Aeson.Array (fmap replaceValue values))
                 field)
          _ -> Aeson.Object field
    replaceField value = value
    replaceValue (Aeson.Object value) =
      Aeson.Object
        (AesonKeyMap.insert (AesonKey.fromText memberName) replacement value)
    replaceValue value = value

mapFailureObject ::
     (AesonKeyMap.KeyMap Aeson.Value -> AesonKeyMap.KeyMap Aeson.Value)
  -> Aeson.Value
  -> Aeson.Value
mapFailureObject alter value =
  case value of
    Aeson.Object root ->
      case AesonKeyMap.lookup "failure" root of
        Just (Aeson.Object failure) ->
          Aeson.Object
            (AesonKeyMap.insert "failure" (Aeson.Object (alter failure)) root)
        _ -> value
    _ -> value

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
  ownerSourceBytes variant code "acquired-model-role" "assessment" "owner-model"

ownerSourceBytes ::
     Text.Text -> Text.Text -> Text.Text -> Text.Text -> Text.Text -> ByteString
ownerSourceBytes variant code branch role reference =
  Text.encodeUtf8
    ("{\"schema\":\"o2i.command-error/v1\",\"kind\":\""
       <> variant
       <> "\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\""
       <> code
       <> "\",\"failure\":{\"category\":\"owner-contract\",\"branch\":\""
       <> branch
       <> "\",\"evidence\":[{\"kind\":\"source-identity\",\"fields\":[{\"name\":\"source\",\"values\":[{\"kind\":\"source-identity\",\"role\":\""
       <> role
       <> "\",\"ordinal\":0,\"reference\":\""
       <> reference
       <> "\",\"sha256\":\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"}]}]}]}}")

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

assertRejectedByEmbeddedSchema :: Aeson.Value -> Assertion
assertRejectedByEmbeddedSchema documentValue = do
  schemaValue <- requireJSON commandErrorSchemaBytes
  not (validateJSONSchema schemaValue documentValue)
    @? "invalid cross-branch command error satisfies the embedded Schema"

requireJSON :: ByteString -> IO Aeson.Value
requireJSON encoded =
  case Aeson.eitherDecodeStrict encoded of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

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
