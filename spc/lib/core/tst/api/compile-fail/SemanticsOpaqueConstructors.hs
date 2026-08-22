module SemanticsOpaqueConstructors where

import O2I.Semantics

forgeSemanticModel :: SemanticallyValidModel scope
forgeSemanticModel = SemanticallyValidModel undefined [] [] []

forgeEvidence :: SemanticDiagnosticEvidence scope
forgeEvidence = SemanticDiagnosticEvidence undefined

forgeAssessment :: SemanticAssessment scope
forgeAssessment = SemanticAssessment undefined

forgeCollective :: CollectiveStrategyRealizationAssessment scope
forgeCollective = CollectiveStrategyRealizationCandidate undefined undefined
