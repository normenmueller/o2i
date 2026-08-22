{-# LANGUAGE RoleAnnotations #-}

-- | Representation-private source witnesses for owner diagnostics.
module O2I.Operation.Diagnostic.Owner.Source.Internal
  ( ModelOwnerSource(..)
  , ScopedModelOwnerSource(..)
  , SupplementalOwnerOccurrence(..)
  , SupplementalOwnerBinding(..)
  , SupplementalOwnerBindingEvidence(..)
  , BoundOwnerSupplementalInputs(..)
  ) where

import O2I.Operation.Acquisition (AcquiredSource)
import O2I.Operation.Provenance (SourceIdentity)
import O2I.Semantics.Input
  ( BoundSupplementalInputs
  , SupplementalBinding
  , SupplementalBindingEvidence
  )

-- | Exact acquired model identity retained at its canonical document.
newtype ModelOwnerSource document =
  ModelOwnerSource SourceIdentity

type role ModelOwnerSource nominal

-- | Exact model identity retained at the selected-View scope derived from it.
newtype ScopedModelOwnerSource scope =
  ScopedModelOwnerSource SourceIdentity

type role ScopedModelOwnerSource nominal

-- | Exact acquired artifact retained privately in one input generation.
newtype SupplementalOwnerOccurrence inputs =
  SupplementalOwnerOccurrence AcquiredSource

type role SupplementalOwnerOccurrence nominal

-- | Exact Core binding whose source occurrences never escape Operation.
newtype SupplementalOwnerBinding scope inputs =
  SupplementalOwnerBinding
    (SupplementalBinding scope (SupplementalOwnerOccurrence inputs))

type role SupplementalOwnerBinding nominal nominal

-- | Exact graph-dependent evidence retained with its private occurrence.
newtype SupplementalOwnerBindingEvidence scope inputs =
  SupplementalOwnerBindingEvidence
    (SupplementalBindingEvidence scope (SupplementalOwnerOccurrence inputs))

type role SupplementalOwnerBindingEvidence nominal nominal

-- | Accepted bound payloads after source-attributed Binding succeeds.
newtype BoundOwnerSupplementalInputs scope inputs =
  BoundOwnerSupplementalInputs (BoundSupplementalInputs scope)

type role BoundOwnerSupplementalInputs nominal nominal
