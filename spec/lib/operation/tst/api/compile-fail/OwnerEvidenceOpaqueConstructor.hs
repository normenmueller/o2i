module OwnerEvidenceOpaqueConstructor where

import O2I.Operation.Diagnostic

forgedDiagnostic :: PreparedDiagnostic authority profile document
forgedDiagnostic = ProfileActivationDiagnostic undefined

forgedDocument :: PreparedDiagnosticDocument
forgedDocument = PreparedDiagnosticDocument undefined undefined undefined
