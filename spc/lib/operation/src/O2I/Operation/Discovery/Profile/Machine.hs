{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine document for compiled Profile discovery.
module O2I.Operation.Discovery.Profile.Machine
  ( type ProfileInventoryDocument
  , profileInventoryDocument
  , profileInventorySchema
  , profileInventoryDocumentVariant
  , encodeProfileInventoryDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Operation.Discovery.Machine.Internal
  ( profileDiscoveryDefectFragment
  , profileDiscoveryRowFragment
  )
import O2I.Operation.Discovery.Profile
  ( ProfileDiscoveryCompilation
  , foldProfileDiscovery
  , foldProfileDiscoveryCompilation
  )
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , requiredMember
  , textFragment
  )
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable success or static-definition-failure Profile document.
newtype ProfileInventoryDocument =
  ProfileInventoryDocument MachineResult

-- | Project every Profile compilation branch into its exact machine variant.
profileInventoryDocument ::
     ProfileDiscoveryCompilation -> ProfileInventoryDocument
profileInventoryDocument = foldProfileDiscoveryCompilation invalid compiled
  where
    invalid defects =
      ProfileInventoryDocument
        (closedMachineResult
           Generated.profileInventoryMachineSchema
           Generated.profileDefinitionInvalidVariant
           [ requiredMember "authority" (textFragment "Operation")
           , requiredMember
               "diagnostics"
               (arrayFragment
                  (fmap profileDiscoveryDefectFragment (NonEmpty.toList defects)))
           ])
    compiled discovery =
      foldProfileDiscovery
        (\rows ->
           ProfileInventoryDocument
             (closedMachineResult
                Generated.profileInventoryMachineSchema
                Generated.profileInventoryVariant
                [ requiredMember "authority" (textFragment "Operation")
                , requiredMember
                    "profiles"
                    (arrayFragment
                       (fmap profileDiscoveryRowFragment (NonEmpty.toList rows)))
                ]))
        discovery

-- | Exact generated Schema authority for Profile inventory documents.
profileInventorySchema :: MachineSchema
profileInventorySchema = Generated.profileInventoryMachineSchema

-- | Exact constructor discriminator selected by Profile compilation.
profileInventoryDocumentVariant :: ProfileInventoryDocument -> SchemaVariant
profileInventoryDocumentVariant (ProfileInventoryDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeProfileInventoryDocument :: ProfileInventoryDocument -> ByteString
encodeProfileInventoryDocument (ProfileInventoryDocument result) =
  machineResultBytesValue result
