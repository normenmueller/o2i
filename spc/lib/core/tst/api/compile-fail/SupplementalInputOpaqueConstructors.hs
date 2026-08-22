module SupplementalInputOpaqueConstructors where

import O2I.Semantics.Input

forgeDefect :: SupplementalInputDefect
forgeDefect = SupplementalInvalidUtf8Defect (supplementalInputOrdinal 0)

forgeBinding :: SupplementalBinding scope provenance
forgeBinding = SupplementalBinding undefined

forgeBindingEvidence :: SupplementalBindingEvidence scope provenance
forgeBindingEvidence = SupplementalBindingEvidence undefined undefined
