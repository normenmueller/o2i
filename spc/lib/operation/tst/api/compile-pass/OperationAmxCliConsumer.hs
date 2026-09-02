{-# LANGUAGE OverloadedStrings #-}

-- | Package-external proof of the exact CLI composition dependency edge.
module OperationAmxCliConsumer where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import O2I.Adapter.AMX (amxAdapter)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Adapter.Authoring (compileAdapterCollection)
import O2I.Operation.Command.Error
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Diagnostic
import O2I.Operation.Failure
import O2I.Operation.Identity
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile
import O2I.Operation.Schema (MachineSchema)
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
