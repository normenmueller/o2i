module OwnerFreeSourceIdentity where

import O2I.ArchiMate.Profile.Closure
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Provenance

freeProfileSource ::
     SourceIdentity
  -> ProfileAssessmentUniverse profile document
  -> [PreparedDiagnostic authority profile document]
freeProfileSource = profileActivationDiagnostics
