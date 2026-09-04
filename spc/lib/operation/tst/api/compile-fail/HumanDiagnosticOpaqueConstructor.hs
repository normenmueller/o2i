module HumanDiagnosticOpaqueConstructor where

import O2I.Operation.Human.Diagnostic
  ( HumanDiagnostic
  , HumanSemanticDiagnosticEvidence
  )

forgedSemantic :: HumanSemanticDiagnosticEvidence
forgedSemantic = HumanSemanticDiagnosticEvidence undefined

forged :: HumanDiagnostic
forged =
  HumanDiagnostic
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
