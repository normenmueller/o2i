module OwnerSupplementalSourceCrossGeneration where

import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source

consume ::
     SupplementalOwnerBinding scope inputs
  -> SupplementalOwnerBindingEvidence scope inputs
  -> Diagnostic
consume = bindingEvidenceDiagnostic

crossGeneration ::
     SupplementalOwnerBinding scope firstInputs
  -> SupplementalOwnerBindingEvidence scope secondInputs
  -> Diagnostic
crossGeneration = consume
