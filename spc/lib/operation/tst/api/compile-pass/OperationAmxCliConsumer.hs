{-# LANGUAGE OverloadedStrings #-}

-- | Package-external proof of the exact CLI composition dependency edge.
module OperationAmxCliConsumer where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX (amxAdapter)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Adapter.Authoring (compileAdapterCollection)
import O2I.Operation.Assess.Machine
import O2I.Operation.Assess.Result
import O2I.Operation.Command.Error
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Diagnostic
import O2I.Operation.Failure
import O2I.Operation.Identity
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile
import O2I.Operation.Qualify.Machine
import O2I.Operation.Qualify.Result
import O2I.Operation.Readiness.Machine
import O2I.Operation.Readiness.Result
import O2I.Operation.Schema (MachineSchema)
import O2I.Operation.Validate.Machine
import O2I.Operation.Validate.Result
import O2I.Operation.View (ViewSelector, viewByIdentity)

-- | Compile the exact statically linked AMX and Profile composition.
staticComposition :: Either () (AdapterCollection, ProfileInventory)
staticComposition =
  case amxAdapter of
    Left _ -> Left ()
    Right adapter ->
      case compileAdapterCollection (adapter :| []) of
        Left _ -> Left ()
        Right adapters ->
          foldProfileInventoryCompilation
            (const (Left ()))
            (\profiles -> Right (adapters, profiles))
            compiledProfileInventory

-- | Decode an exact lexical identity and retain the owned Core type opaquely.
identitySelector :: Text -> Either ModelIdentityDefect ViewSelector
identitySelector = fmap viewByIdentity . lexicalModelIdentity

-- | Author and encode a CLI-owned argument error without reconstructing JSON.
argumentErrorBytes ::
     ToolDescriptor
  -> Text
  -> Text
  -> Either (NonEmpty ArgumentFailureDefect) ByteString
argumentErrorBytes tool code message =
  fmap
    (encodeCommandErrorDocument
       . commandErrorDocument tool
       . argumentCommandError)
    (argumentFailure code message)

-- | Encode either existing common Operation failure through the same algebra.
commonErrorBytes :: ToolDescriptor -> CommonFailure -> ByteString
commonErrorBytes tool =
  encodeCommandErrorDocument . commandErrorDocument tool . commonCommandError

-- | Consume every command branch for human rendering without constructors.
consumeCommandError :: CommandError -> Text
consumeCommandError =
  foldCommandError
    argumentFailureMessage
    commandFailureCode
    preparationFailureCode
    consumeValidateFailure
    consumeQualifyFailure
    consumeReadinessFailure
    consumeAssessFailure

-- | Route a real Validate document failure through the closed error encoder.
validateResultOrErrorBytes :: ToolDescriptor -> ValidateResult -> ByteString
validateResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . validateCommandError)
    encodeValidateResultDocument
    (validateResultDocument tool result)

-- | Route a real Qualify document failure through the closed error encoder.
qualifyResultOrErrorBytes :: ToolDescriptor -> QualifyResult -> ByteString
qualifyResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . qualifyCommandError)
    encodeQualifyResultDocument
    (qualifyResultDocument tool result)

-- | Route a real Readiness document failure through the closed error encoder.
readinessResultOrErrorBytes :: ToolDescriptor -> ReadinessResult -> ByteString
readinessResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . readinessCommandError)
    encodeReadinessResultDocument
    (readinessResultDocument tool result)

-- | Route a real Assess document failure through the closed error encoder.
assessResultOrErrorBytes :: ToolDescriptor -> AssessResult -> ByteString
assessResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . assessCommandError)
    encodeAssessResultDocument
    (assessResultDocument tool result)

commandErrorBytes :: ToolDescriptor -> CommandError -> ByteString
commandErrorBytes tool = encodeCommandErrorDocument . commandErrorDocument tool

consumeValidateFailure :: ValidateFailure -> Text
consumeValidateFailure =
  foldValidateFailure
    consumeCommonFailure
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . validateCommandOwnerDiagnostic)

consumeQualifyFailure :: QualifyFailure -> Text
consumeQualifyFailure =
  foldQualifyFailure
    consumeCommonFailure
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . qualifyCommandOwnerDiagnostic)

consumeReadinessFailure :: ReadinessFailure -> Text
consumeReadinessFailure =
  foldReadinessFailure
    consumeCommonFailure
    (consumeInputDiagnostics readinessCommandInputDiagnostic)
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . readinessCommandOwnerDiagnostic)

consumeAssessFailure :: AssessFailure -> Text
consumeAssessFailure =
  foldAssessFailure
    consumeCommonFailure
    (consumeInputDiagnostics assessmentCommandInputDiagnostic)
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . assessCommandOwnerDiagnostic)

consumeCommonFailure :: CommonFailure -> Text
consumeCommonFailure =
  foldCommonFailure commandFailureCode preparationFailureCode

consumeInputDiagnostics ::
     (defect -> CommandInputDiagnostic) -> NonEmpty defect -> Text
consumeInputDiagnostics project =
  Text.intercalate "|"
    . map (consumeInputDiagnostic . project)
    . NonEmpty.toList

consumeInputDiagnostic :: CommandInputDiagnostic -> Text
consumeInputDiagnostic =
  foldCommandInputDiagnostic $ \rule ordinals reason fields ->
    Text.intercalate
      ":"
      [ rule
      , Text.intercalate "," (map (Text.pack . show) (NonEmpty.toList ordinals))
      , reason
      , Text.intercalate "," (map consumeDiagnosticField fields)
      ]

consumeOwnerDiagnostic :: CommandOwnerDiagnostic -> Text
consumeOwnerDiagnostic =
  foldCommandOwnerDiagnostic $ \branch evidence ->
    branch
      <> ":"
      <> Text.intercalate
           ","
           (map consumeOwnerEvidence (NonEmpty.toList evidence))

consumeOwnerEvidence :: CommandOwnerEvidence -> Text
consumeOwnerEvidence =
  foldCommandOwnerEvidence $ \kind fields ->
    kind <> ":" <> Text.intercalate "," (map consumeDiagnosticField fields)

consumeDiagnosticField :: CommandDiagnosticField -> Text
consumeDiagnosticField =
  foldCommandDiagnosticField $ \name values ->
    name <> "=" <> Text.intercalate "+" (map consumeDiagnosticValue values)

consumeDiagnosticValue :: CommandDiagnosticValue -> Text
consumeDiagnosticValue =
  foldCommandDiagnosticValue
    ("text:" <>)
    (("natural:" <>) . Text.pack . show)
    ("model:" <>)
    ("occurrence:" <>)
    ("qualified:" <>)
    (\role ordinal -> role <> ":" <> Text.pack (show ordinal))
    (\role ordinal reference digest ->
       Text.intercalate ":" [role, Text.pack (show ordinal), reference, digest])
    (\identifier name version notation ->
       Text.intercalate ":" [identifier, name, version, notation])
    (\kind ordinal -> kind <> ":" <> Text.pack (show ordinal))
    (\index codePoint ->
       Text.pack (show index) <> ":" <> Text.pack (show codePoint))

-- | Exact immutable Schema input available before the first output byte.
commandErrorPreflight :: (MachineSchema, ByteString)
commandErrorPreflight = (commandErrorSchema, commandErrorSchemaBytes)

-- | Consume all supplemental groups and all closed finding branches.
consumeSupplementalGroups ::
     SupplementalDiagnosticGroups authority profile document -> [Text]
consumeSupplementalGroups =
  foldSupplementalDiagnosticGroups
    (\source diagnostics -> fmap (consumeSupplemental source) diagnostics)
    concat

consumeSupplemental ::
     AcquiredSupplementalSource -> SupplementalDiagnostic -> Text
consumeSupplemental groupSource diagnostic =
  supplementalDiagnosticRuleIdentity diagnostic
    <> ":"
    <> foldSupplementalDiagnostic tagged tagged tagged tagged diagnostic
  where
    tagged retainedSource pointer identity
      | retainedSource == groupSource = pointer <> ":" <> identity
      | otherwise = "source-mismatch"
