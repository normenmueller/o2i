module SemanticOccurrenceOpaqueConstructors where

import O2I.Semantics

forgeRole :: SemanticOccurrenceRole
forgeRole = SemanticOccurrenceRole undefined

forgeGroup :: SemanticOccurrenceGroup
forgeGroup = SemanticOccurrenceGroup forgeRole []
