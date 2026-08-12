{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Profile-neutral View discovery through one selected notation adapter.
--
-- The operation acquires exact bytes, selects and runs one adapter, builds one
-- canonical notation document, and enumerates native Views. It deliberately
-- performs no Profile resolution, compatibility check, or Profile assessment.
module O2I.Operation.Discovery.View
  ( type ViewDiscoveryAuthority
  , foldViewDiscoveryAuthority
  , viewDiscoveryAuthorityText
  , type ViewDiscoveryFailure
  , foldViewDiscoveryFailure
  , type ViewDiscoveryResult
  , viewDiscoverySource
  , viewDiscoveryAdapter
  , viewDiscoveryDocument
  , viewDiscoveryViews
  , viewDiscoveryAuthorities
  , foldViewDiscoveryResult
  , type ViewDiscovery
  , foldViewDiscovery
  , discoverViews
  , discoverAcquiredViews
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , ViewDescriptor
  , buildCanonicalDocument
  , viewInventory
  )
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , AdapterDescriptor
  , AdapterDiagnostic
  , AdapterId
  , AdapterSelectionError
  , SelectedAdapter
  , adapterDescriptorId
  , adapterIdText
  , foldAdapterExecution
  , foldAdapterSelection
  , foldDecodeOutcome
  , runSelectedAdapter
  , selectAdapter
  )
import O2I.Operation.Discovery.View.Internal
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(ModelRole)
  , sourceOrdinal
  )

-- | Consume the Operation or exact selected-adapter authority.
foldViewDiscoveryAuthority ::
     result -> (AdapterId -> result) -> ViewDiscoveryAuthority -> result
foldViewDiscoveryAuthority operation adapter authority =
  case authority of
    OperationViewAuthority -> operation
    AdapterViewAuthority identifier -> adapter identifier

-- | Stable authority label for discovery provenance.
viewDiscoveryAuthorityText :: ViewDiscoveryAuthority -> Text
viewDiscoveryAuthorityText =
  foldViewDiscoveryAuthority
    "Operation"
    (\identifier -> "Adapter:" <> adapterIdText identifier)

-- | Consume every acquisition, selection, or selected-decode failure.
foldViewDiscoveryFailure ::
     (AcquisitionFailure -> result)
  -> (SourceIdentity -> AdapterSelectionError -> result)
  -> (SourceIdentity -> AdapterDescriptor -> NonEmpty AdapterDiagnostic -> result)
  -> ViewDiscoveryFailure
  -> result
foldViewDiscoveryFailure acquisition selection decode failure =
  case failure of
    ViewAcquisitionFailed value -> acquisition value
    ViewAdapterSelectionFailed source value -> selection source value
    ViewAdapterDecodeFailed source descriptor diagnostics ->
      decode source descriptor diagnostics

-- | Identity of the one exactly acquired model source.
viewDiscoverySource :: ViewDiscoveryResult -> SourceIdentity
viewDiscoverySource (ViewDiscoveryResult source _ _ _) = source

-- | Descriptor of the one selected adapter.
viewDiscoveryAdapter :: ViewDiscoveryResult -> AdapterDescriptor
viewDiscoveryAdapter (ViewDiscoveryResult _ descriptor _ _) = descriptor

-- | Profile-neutral canonical notation document.
viewDiscoveryDocument :: ViewDiscoveryResult -> CanonicalDocument
viewDiscoveryDocument (ViewDiscoveryResult _ _ document _) = document

-- | Native Views in deterministic canonical document order.
viewDiscoveryViews :: ViewDiscoveryResult -> [ViewDescriptor]
viewDiscoveryViews (ViewDiscoveryResult _ _ _ views) = views

-- | Exact authority boundary: Operation plus the selected adapter only.
viewDiscoveryAuthorities ::
     ViewDiscoveryResult -> NonEmpty ViewDiscoveryAuthority
viewDiscoveryAuthorities result =
  OperationViewAuthority
    :| [ AdapterViewAuthority
           (adapterDescriptorId (viewDiscoveryAdapter result))
       ]

-- | Consume every successful profile-neutral discovery field.
foldViewDiscoveryResult ::
     (SourceIdentity -> AdapterDescriptor -> CanonicalDocument -> [ViewDescriptor] -> result)
  -> ViewDiscoveryResult
  -> result
foldViewDiscoveryResult consume (ViewDiscoveryResult source adapter document views) =
  consume source adapter document views

-- | Consume failure or the complete canonical View inventory.
foldViewDiscovery ::
     (ViewDiscoveryFailure -> result)
  -> (ViewDiscoveryResult -> result)
  -> ViewDiscovery
  -> result
foldViewDiscovery failed succeeded outcome =
  case outcome of
    ViewDiscoveryFailed failure -> failed failure
    ViewsDiscovered result -> succeeded result

-- | Acquire one model source exactly once and discover its native Views.
discoverViews ::
     AdapterCollection -> Maybe AdapterId -> InputSource -> IO ViewDiscovery
discoverViews adapters requested source = do
  acquired <- acquireSource ModelRole (sourceOrdinal 0) source
  pure
    (case acquired of
       Left failure -> ViewDiscoveryFailed (ViewAcquisitionFailed failure)
       Right model -> discoverAcquiredViews adapters requested model)

-- | Discover native Views from an already acquired immutable model source.
--
-- Selection invokes the existing static adapter collection. The selected
-- adapter decodes once; canonical construction and View enumeration are linear
-- in retained Draft evidence. No Profile API is imported or invoked.
discoverAcquiredViews ::
     AdapterCollection -> Maybe AdapterId -> AcquiredSource -> ViewDiscovery
discoverAcquiredViews adapters requested acquired =
  foldAdapterSelection
    (ViewDiscoveryFailed
       . ViewAdapterSelectionFailed (acquiredSourceIdentity acquired))
    decodeSelected
    (selectAdapter adapters requested (acquiredSourceBytes acquired))
  where
    decodeSelected :: SelectedAdapter -> ViewDiscovery
    decodeSelected selected =
      foldAdapterExecution
        (\descriptor _ outcome ->
           foldDecodeOutcome
             (ViewDiscoveryFailed
                . ViewAdapterDecodeFailed
                    (acquiredSourceIdentity acquired)
                    descriptor)
             (\draft ->
                let document = buildCanonicalDocument draft
                 in ViewsDiscovered
                      (ViewDiscoveryResult
                         (acquiredSourceIdentity acquired)
                         descriptor
                         document
                         (viewInventory document)))
             outcome)
        (runSelectedAdapter selected (acquiredSourceBytes acquired))
