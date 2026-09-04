module HumanFailureOpaqueConstructorsC where

import O2I.Operation.Human.Failure

rule :: HumanFailureAdapterRule
rule = HumanFailureAdapterRule undefined undefined undefined undefined undefined

occurrence :: HumanFailureAdapterOccurrence
occurrence = HumanFailureAdapterOccurrence undefined

diagnostic :: HumanFailureAdapterDiagnostic
diagnostic = HumanFailureAdapterDiagnostic undefined undefined

target :: HumanFailureCanonicalTarget
target =
  HumanFailureCanonicalTarget undefined undefined undefined undefined undefined

reference :: HumanFailureCanonicalReference
reference =
  HumanFailureCanonicalReference
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

opaque :: HumanFailureOpaqueEvidence
opaque =
  HumanFailureOpaqueEvidence undefined undefined undefined undefined undefined

property :: HumanFailureCanonicalProperty
property =
  HumanFailureCanonicalProperty
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

marker :: HumanFailureMarkerCandidate
marker = HumanFailureMarkerCandidate undefined undefined undefined

viewCandidate :: HumanFailureViewSelectionCandidate
viewCandidate =
  HumanFailureViewSelectionCandidate undefined undefined undefined undefined

inputDefect :: HumanInputDefect
inputDefect = HumanInputDefect undefined undefined undefined undefined undefined

identityDefect :: HumanIdentityIndexDefect
identityDefect = HumanIdentityIndexDefect undefined undefined

scopeDefect :: HumanSelectedViewScopeDefect
scopeDefect = HumanSelectedViewScopeDefect undefined undefined undefined
