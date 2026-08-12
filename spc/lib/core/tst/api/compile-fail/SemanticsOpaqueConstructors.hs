module SemanticsOpaqueConstructors where

import O2I.Semantics

forgeSemanticModel :: SemanticallyValidModel scope
forgeSemanticModel = SemanticallyValidModel undefined [] [] []

forgeDefect :: SemanticDefect
forgeDefect = SemanticDefect undefined undefined []

forgeCollective :: CollectiveStrategyRealizationAssessment scope
forgeCollective = CollectiveStrategyRealizationCandidate undefined undefined
