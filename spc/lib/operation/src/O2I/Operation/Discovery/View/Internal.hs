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

data ViewDiscoveryAuthority
  = OperationViewAuthority
  | AdapterViewAuthority !AdapterId
  deriving (Eq, Ord, Show)

data ViewDiscoveryFailure
  = ViewAcquisitionFailed !AcquisitionFailure
  | ViewAdapterSelectionFailed !SourceIdentity !AdapterSelectionError
  | ViewAdapterDecodeFailed
      !SourceIdentity
      !AdapterDescriptor
      !(NonEmpty AdapterDiagnostic)

data ViewDiscoveryResult =
  ViewDiscoveryResult
    !SourceIdentity
    !AdapterDescriptor
    !CanonicalDocument
    ![ViewDescriptor]

data ViewDiscovery
  = ViewDiscoveryFailed !ViewDiscoveryFailure
  | ViewsDiscovered !ViewDiscoveryResult
