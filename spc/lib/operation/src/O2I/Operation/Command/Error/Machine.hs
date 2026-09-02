{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Canonical machine document for closed command errors.
module O2I.Operation.Command.Error.Machine
  ( type CommandErrorDocument
  , commandErrorDocument
  , commandErrorSchema
  , commandErrorSchemaBytes
  , commandErrorDocumentVariant
  , encodeCommandErrorDocument
  ) where

import Data.ByteString (ByteString)
import O2I.Operation.Command.Error
  ( ArgumentFailure
  , CommandError
  , foldArgumentFailure
  , foldCommandError
  )
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , closedMachineResult
  , requiredMember
  , textFragment
  , toolDescriptorFragment
  )
import O2I.Operation.Failure
  ( CommandFailure
  , PreparationFailure
  , commandFailureCode
  , foldCommandFailure
  , preparationFailureCode
  , preparationFailureStage
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal (acquisitionFailureFragment)
import O2I.Operation.Preparation (preparationStageText)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable command error sealed by Operation's generated contract.
newtype CommandErrorDocument =
  CommandErrorDocument MachineResult

-- | Seal one closed command error with exact executable metadata.
commandErrorDocument :: ToolDescriptor -> CommandError -> CommandErrorDocument
commandErrorDocument tool =
  foldCommandError argumentDocument processDocument preparationDocument
  where
    argumentDocument :: ArgumentFailure -> CommandErrorDocument
    argumentDocument failure =
      foldArgumentFailure
        (\code message ->
           CommandErrorDocument
             (closedMachineResult
                Generated.commandErrorMachineSchema
                Generated.argumentInvalidVariant
                [ requiredMember "tool" (toolDescriptorFragment tool)
                , requiredMember "code" (textFragment code)
                , requiredMember "message" (textFragment message)
                ]))
        failure
    processDocument :: CommandFailure -> CommandErrorDocument
    processDocument failure =
      foldCommandFailure
        (\acquisition ->
           CommandErrorDocument
             (closedMachineResult
                Generated.commandErrorMachineSchema
                Generated.commandFailedVariant
                [ requiredMember "tool" (toolDescriptorFragment tool)
                , requiredMember
                    "code"
                    (textFragment (commandFailureCode failure))
                , requiredMember
                    "failure"
                    (acquisitionFailureFragment acquisition)
                ]))
        failure
    preparationDocument :: PreparationFailure -> CommandErrorDocument
    preparationDocument failure =
      CommandErrorDocument
        (closedMachineResult
           Generated.commandErrorMachineSchema
           Generated.preparationFailedVariant
           [ requiredMember "tool" (toolDescriptorFragment tool)
           , requiredMember
               "code"
               (textFragment (preparationFailureCode failure))
           , requiredMember
               "stage"
               (textFragment
                  (preparationStageText (preparationFailureStage failure)))
           ])

-- | Exact generated Schema metadata and immutable bytes.
commandErrorSchema :: MachineSchema
commandErrorSchema = Generated.commandErrorMachineSchema

-- | Exact immutable generated JSON Schema bytes for pre-output validation.
commandErrorSchemaBytes :: ByteString
commandErrorSchemaBytes = Generated.commandErrorSchemaBytes

-- | Exact constructor discriminator selected by the retained error branch.
commandErrorDocumentVariant :: CommandErrorDocument -> SchemaVariant
commandErrorDocumentVariant (CommandErrorDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes for one complete error document.
encodeCommandErrorDocument :: CommandErrorDocument -> ByteString
encodeCommandErrorDocument (CommandErrorDocument result) =
  machineResultBytesValue result
