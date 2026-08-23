{-# LANGUAGE RoleAnnotations #-}

-- | Representation-private source witnesses for owner diagnostics.
module O2I.Operation.Diagnostic.Owner.Source.Internal
  ( PreparedAuthority(..)
  , PreparedScope(..)
  , SupplementalOwnerOccurrence(..)
  , SupplementalOwnerBinding(..)
  , SupplementalOwnerBindingEvidence(..)
  , BoundOwnerSupplementalInputs(..)
  ) where

import O2I.ArchiMate.Profile.Resolution (ProfileDescriptor)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Provenance (SourceIdentity)
import O2I.Semantics.Input
  ( BoundSupplementalInputs
  , SupplementalBinding
  , SupplementalBindingDiagnosticEvidence
  )

-- | One exact selected Adapter/Profile/model authority minted by preparation.
data PreparedAuthority authority profile document =
  PreparedAuthority !AdapterDescriptor !ProfileDescriptor !SourceIdentity

type role PreparedAuthority nominal nominal nominal

-- | The model authority retained at one fresh accepted Structure scope.
newtype PreparedScope authority profile document scope =
  PreparedScope SourceIdentity

type role PreparedScope nominal nominal nominal nominal

-- | Exact acquired artifact retained privately in one input generation.
newtype SupplementalOwnerOccurrence inputs =
  SupplementalOwnerOccurrence AcquiredSupplementalSource

type role SupplementalOwnerOccurrence nominal

-- | Exact Core binding whose source occurrences never escape Operation.
data SupplementalOwnerBinding authority profile document scope inputs =
  SupplementalOwnerBinding
    ![AcquiredSupplementalSource]
    !(SupplementalBinding scope (SupplementalOwnerOccurrence inputs))

type role SupplementalOwnerBinding nominal nominal nominal nominal nominal

-- | Exact graph-dependent evidence retained with its private occurrence.
data SupplementalOwnerBindingEvidence scope inputs =
  SupplementalOwnerBindingEvidence
    !AcquiredSupplementalSource
    !(SupplementalBindingDiagnosticEvidence
        scope
        (SupplementalOwnerOccurrence inputs))

type role SupplementalOwnerBindingEvidence nominal nominal

-- | Accepted bound payloads after source-attributed Binding succeeds.
newtype BoundOwnerSupplementalInputs authority profile document scope inputs =
  BoundOwnerSupplementalInputs (BoundSupplementalInputs scope)

type role BoundOwnerSupplementalInputs nominal nominal nominal nominal nominal
