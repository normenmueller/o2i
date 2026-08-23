module OwnerSupplementalSourceCrossGeneration where

import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner.Source

crossAuthority ::
     PreparedAuthority firstAuthority profile document
  -> PreparedDiagnostic secondAuthority profile document
  -> PreparedDiagnosticDocument
crossAuthority authority diagnostic =
  preparedDiagnosticDocument authority [diagnostic] []
