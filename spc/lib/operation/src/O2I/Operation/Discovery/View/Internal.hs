-- | Internal closed data for profile-neutral View discovery.
module O2I.Operation.Discovery.View.Internal
  ( ViewDiscoveryAuthority(..)
  , ViewDiscoveryFailure(..)
  , ViewDiscoveryResult(..)
  , ViewDiscovery(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.ArchiMate.Profile.Notation (CanonicalDocument, ViewDescriptor)
import O2I.Operation.Acquisition (AcquisitionFailure)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterId
  , AdapterSelectionError
  )
import O2I.Operation.Provenance (SourceIdentity)

-- | Closed authority that supplied a discovered View result.
data ViewDiscoveryAuthority
  = OperationViewAuthority
  | AdapterViewAuthority !AdapterId
  deriving (Eq, Ord, Show)

-- | Acquisition, adapter-selection, or adapter-decode discovery failure.
data ViewDiscoveryFailure
  = ViewAcquisitionFailed !AcquisitionFailure
  | ViewAdapterSelectionFailed !SourceIdentity !AdapterSelectionError
  | ViewAdapterDecodeFailed
      !SourceIdentity
      !AdapterDescriptor
      !(NonEmpty AdapterDiagnostic)

-- | Complete source, adapter, canonical document, and View inventory.
data ViewDiscoveryResult =
  ViewDiscoveryResult
    !SourceIdentity
    !AdapterDescriptor
    !CanonicalDocument
    ![ViewDescriptor]

-- | Failure or complete successful profile-neutral View discovery.
data ViewDiscovery
  = ViewDiscoveryFailed !ViewDiscoveryFailure
  | ViewsDiscovered !ViewDiscoveryResult
