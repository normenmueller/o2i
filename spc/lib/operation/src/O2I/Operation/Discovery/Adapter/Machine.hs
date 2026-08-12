{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine document for the complete compiled Adapter inventory.
module O2I.Operation.Discovery.Adapter.Machine
  ( type AdapterInventoryDocument
  , adapterInventoryDocument
  , adapterInventorySchema
  , adapterInventoryDocumentVariant
  , encodeAdapterInventoryDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Operation.Discovery.Adapter (AdapterDiscovery, foldAdapterDiscovery)
import O2I.Operation.Discovery.Machine.Internal (adapterDescriptorFragment)
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , requiredMember
  , textFragment
  )
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable Adapter-inventory document.
newtype AdapterInventoryDocument =
  AdapterInventoryDocument MachineResult

-- | Project one complete static Adapter discovery into its machine contract.
adapterInventoryDocument :: AdapterDiscovery -> AdapterInventoryDocument
adapterInventoryDocument discovery =
  foldAdapterDiscovery
    (\descriptors ->
       AdapterInventoryDocument
         (closedMachineResult
            Generated.adapterInventoryMachineSchema
            Generated.adapterInventoryVariant
            [ requiredMember "authority" (textFragment "Operation")
            , requiredMember
                "adapters"
                (arrayFragment
                   (fmap adapterDescriptorFragment (NonEmpty.toList descriptors)))
            ]))
    discovery

-- | Exact generated Schema authority for Adapter inventory documents.
adapterInventorySchema :: MachineSchema
adapterInventorySchema = Generated.adapterInventoryMachineSchema

-- | Exact constructor discriminator of this document.
adapterInventoryDocumentVariant :: AdapterInventoryDocument -> SchemaVariant
adapterInventoryDocumentVariant (AdapterInventoryDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeAdapterInventoryDocument :: AdapterInventoryDocument -> ByteString
encodeAdapterInventoryDocument (AdapterInventoryDocument result) =
  machineResultBytesValue result
