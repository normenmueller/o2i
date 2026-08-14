{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine document for profile-neutral View discovery.
module O2I.Operation.Discovery.View.Machine
  ( type ViewDiscoveryDocument
  , viewDiscoveryDocument
  , viewDiscoverySchema
  , viewDiscoveryDocumentVariant
  , encodeViewDiscoveryDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Operation.Discovery.Machine.Internal (viewDiscoveryAuthorityFragment)
import O2I.Operation.Discovery.View
  ( ViewDiscovery
  , foldViewDiscovery
  , foldViewDiscoveryFailure
  , foldViewDiscoveryResult
  , viewDiscoveryAuthorities
  )
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , closedOperationMachineResult
  , requiredMember
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( acquisitionFailureFragment
  , adapterDescriptorFragment
  , adapterDiagnosticFragment
  , adapterSelectionErrorFragment
  , sourceIdentityFragment
  , viewDescriptorFragment
  )
import O2I.Operation.Machine.Internal (viewsOperationIdentity)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable success or closed View-discovery failure document.
newtype ViewDiscoveryDocument =
  ViewDiscoveryDocument MachineResult

-- | Project every profile-neutral discovery branch without retaining the
-- complete canonical notation document. Composition metadata is explicit even
-- when a pre-completion command failure does not emit an Operation envelope.
viewDiscoveryDocument ::
     ToolDescriptor -> ViewDiscovery -> ViewDiscoveryDocument
viewDiscoveryDocument tool = foldViewDiscovery failed succeeded
  where
    failed =
      foldViewDiscoveryFailure
        (\failure ->
           ViewDiscoveryDocument
             (closedMachineResult
                Generated.viewDiscoveryMachineSchema
                Generated.viewAcquisitionFailedVariant
                [requiredMember "failure" (acquisitionFailureFragment failure)]))
        (\source failure ->
           ViewDiscoveryDocument
             (closedMachineResult
                Generated.viewDiscoveryMachineSchema
                Generated.viewAdapterSelectionFailedVariant
                [ requiredMember "source" (sourceIdentityFragment source)
                , requiredMember
                    "failure"
                    (adapterSelectionErrorFragment failure)
                ]))
        (\source adapter diagnostics ->
           ViewDiscoveryDocument
             (closedMachineResult
                Generated.viewDiscoveryMachineSchema
                Generated.viewAdapterDecodeFailedVariant
                [ requiredMember "source" (sourceIdentityFragment source)
                , requiredMember "adapter" (adapterDescriptorFragment adapter)
                , requiredMember
                    "diagnostics"
                    (arrayFragment
                       (fmap
                          adapterDiagnosticFragment
                          (NonEmpty.toList diagnostics)))
                ]))
    succeeded result =
      foldViewDiscoveryResult
        (\source adapter _ views ->
           ViewDiscoveryDocument
             (closedOperationMachineResult
                Generated.viewDiscoveryMachineSchema
                viewsOperationIdentity
                tool
                Generated.viewsDiscoveredVariant
                [ requiredMember "source" (sourceIdentityFragment source)
                , requiredMember "adapter" (adapterDescriptorFragment adapter)
                , requiredMember
                    "authorities"
                    (arrayFragment
                       (fmap
                          viewDiscoveryAuthorityFragment
                          (NonEmpty.toList (viewDiscoveryAuthorities result))))
                , requiredMember
                    "views"
                    (arrayFragment (fmap viewDescriptorFragment views))
                ]))
        result

-- | Exact generated Schema authority for View discovery documents.
viewDiscoverySchema :: MachineSchema
viewDiscoverySchema = Generated.viewDiscoveryMachineSchema

-- | Exact constructor discriminator selected by discovery.
viewDiscoveryDocumentVariant :: ViewDiscoveryDocument -> SchemaVariant
viewDiscoveryDocumentVariant (ViewDiscoveryDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeViewDiscoveryDocument :: ViewDiscoveryDocument -> ByteString
encodeViewDiscoveryDocument (ViewDiscoveryDocument result) =
  machineResultBytesValue result
