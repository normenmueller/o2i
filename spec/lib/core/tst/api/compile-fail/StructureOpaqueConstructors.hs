module StructureOpaqueConstructors where

import O2I.Structure

forgeGraph :: WellFormedGraph scope
forgeGraph = WellFormedGraph [] [] [] []

forgeEvidence :: StructureEvidence scope
forgeEvidence = StructureEvidence undefined

forgeAssessment :: StructureAssessment scope
forgeAssessment = StructureAssessment undefined

forgeCardinality :: StructureZeroOrMultipleOccurrences
forgeCardinality = NoStructureOccurrence
