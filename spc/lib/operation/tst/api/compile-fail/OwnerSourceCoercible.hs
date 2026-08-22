module OwnerSourceCoercible where

import Data.Coerce (coerce)
import O2I.Operation.Diagnostic.Owner.Source

coerceModelSource ::
     ModelOwnerSource firstDocument -> ModelOwnerSource secondDocument
coerceModelSource = coerce

coerceScopedModelSource ::
     ScopedModelOwnerSource firstScope -> ScopedModelOwnerSource secondScope
coerceScopedModelSource = coerce

coerceSupplementalBindingScope ::
     SupplementalOwnerBinding firstScope inputs
  -> SupplementalOwnerBinding secondScope inputs
coerceSupplementalBindingScope = coerce

coerceSupplementalBindingInputs ::
     SupplementalOwnerBinding scope firstInputs
  -> SupplementalOwnerBinding scope secondInputs
coerceSupplementalBindingInputs = coerce

coerceSupplementalEvidenceScope ::
     SupplementalOwnerBindingEvidence firstScope inputs
  -> SupplementalOwnerBindingEvidence secondScope inputs
coerceSupplementalEvidenceScope = coerce

coerceSupplementalEvidenceInputs ::
     SupplementalOwnerBindingEvidence scope firstInputs
  -> SupplementalOwnerBindingEvidence scope secondInputs
coerceSupplementalEvidenceInputs = coerce

coerceBoundScope ::
     BoundOwnerSupplementalInputs firstScope inputs
  -> BoundOwnerSupplementalInputs secondScope inputs
coerceBoundScope = coerce

coerceBoundInputs ::
     BoundOwnerSupplementalInputs scope firstInputs
  -> BoundOwnerSupplementalInputs scope secondInputs
coerceBoundInputs = coerce
