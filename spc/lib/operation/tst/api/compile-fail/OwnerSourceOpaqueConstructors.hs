module OwnerSourceOpaqueConstructors where

import O2I.Operation.Diagnostic.Owner.Source

forgedModelSource :: ModelOwnerSource document
forgedModelSource = ModelOwnerSource undefined

forgedScopedModelSource :: ScopedModelOwnerSource scope
forgedScopedModelSource = ScopedModelOwnerSource undefined

forgedSupplementalBinding :: SupplementalOwnerBinding scope inputs
forgedSupplementalBinding = SupplementalOwnerBinding undefined

forgedSupplementalEvidence :: SupplementalOwnerBindingEvidence scope inputs
forgedSupplementalEvidence = SupplementalOwnerBindingEvidence undefined

forgedBound :: BoundOwnerSupplementalInputs scope inputs
forgedBound = BoundOwnerSupplementalInputs undefined
