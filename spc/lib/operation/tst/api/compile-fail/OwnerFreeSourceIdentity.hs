module OwnerFreeSourceIdentity where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Resolution
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Provenance

freeProfileSource ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> [Diagnostic]
freeProfileSource = profileActivationDiagnostics
