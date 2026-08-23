module OwnerSourceOpaqueConstructors where

import O2I.Operation.Diagnostic.Owner.Source

forgedAuthority :: PreparedAuthority authority profile document
forgedAuthority = PreparedAuthority undefined undefined undefined

forgedScope :: PreparedScope authority profile document scope
forgedScope = PreparedScope undefined

forgedSupplementalBinding ::
     SupplementalOwnerBinding authority profile document scope inputs
forgedSupplementalBinding = SupplementalOwnerBinding undefined undefined

forgedSupplementalEvidence :: SupplementalOwnerBindingEvidence scope inputs
forgedSupplementalEvidence =
  SupplementalOwnerBindingEvidence undefined undefined

forgedBound ::
     BoundOwnerSupplementalInputs authority profile document scope inputs
forgedBound = BoundOwnerSupplementalInputs undefined
