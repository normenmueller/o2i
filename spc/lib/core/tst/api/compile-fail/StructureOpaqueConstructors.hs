module StructureOpaqueConstructors where

import O2I.Structure

forgeGraph :: WellFormedGraph scope
forgeGraph = WellFormedGraph [] [] [] []

forgeDefect :: StructureDefect
forgeDefect = QualifiedEndpointCatalogMembershipDefect undefined

forgeCardinality :: StructureZeroOrMultipleOccurrences
forgeCardinality = NoStructureOccurrence
