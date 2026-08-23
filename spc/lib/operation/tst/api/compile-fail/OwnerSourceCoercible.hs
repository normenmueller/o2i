module OwnerSourceCoercible where

import Data.Coerce (coerce)
import O2I.Operation.Diagnostic.Owner.Source

coerceAuthority ::
     PreparedAuthority firstAuthority profile document
  -> PreparedAuthority secondAuthority profile document
coerceAuthority = coerce

coerceScope ::
     PreparedScope authority profile document firstScope
  -> PreparedScope authority profile document secondScope
coerceScope = coerce

coerceSupplementalBindingInputs ::
     SupplementalOwnerBinding authority profile document scope firstInputs
  -> SupplementalOwnerBinding authority profile document scope secondInputs
coerceSupplementalBindingInputs = coerce

coerceSupplementalEvidenceScope ::
     SupplementalOwnerBindingEvidence firstScope inputs
  -> SupplementalOwnerBindingEvidence secondScope inputs
coerceSupplementalEvidenceScope = coerce

coerceBoundScope ::
     BoundOwnerSupplementalInputs authority profile document firstScope inputs
  -> BoundOwnerSupplementalInputs authority profile document secondScope inputs
coerceBoundScope = coerce
