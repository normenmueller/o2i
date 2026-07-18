{-# LANGUAGE DataKinds #-}

module AggregateOpaqueConstructors where

import qualified O2I

forgedNodeId :: O2I.NodeId ('O2I.ContextKind 'O2I.Need)
forgedNodeId = O2I.NodeId undefined

forgedContextRef :: O2I.ContextRef 'O2I.Need
forgedContextRef = O2I.ContextRef undefined

forgedSomeInterpretation :: O2I.SomeInterpretation
forgedSomeInterpretation = O2I.SomeInterpretation undefined

forgedRelation ::
     O2I.Relation ('O2I.ContextKind 'O2I.Ethos) ('O2I.ContextKind 'O2I.Mission)
forgedRelation = O2I.Relation undefined

forgedSomeRelation :: O2I.SomeRelation
forgedSomeRelation = O2I.SomeRelation undefined

forgedMacroClaim :: O2I.MacroClaim ()
forgedMacroClaim = O2I.MacroClaim undefined

forgedMacroEvidenceRule :: O2I.MacroEvidenceRule
forgedMacroEvidenceRule = O2I.MacroEvidenceRule undefined undefined

forgedMacroFactIndex :: O2I.MacroFactIndex () ()
forgedMacroFactIndex = O2I.MacroFactIndex undefined undefined

forgedMacroDependency :: O2I.MacroDependency ()
forgedMacroDependency = O2I.MacroDependency undefined

forgedSomeNode :: O2I.SomeNode
forgedSomeNode = O2I.SomeNode undefined

forgedSomeEdge :: O2I.SomeEdge
forgedSomeEdge = O2I.SomeEdge undefined

forgedWellFormedGraph :: O2I.WellFormedGraph
forgedWellFormedGraph = O2I.WellFormedGraph undefined undefined

forgedStrategyFormulation :: O2I.StrategyFormulation
forgedStrategyFormulation = O2I.StrategyFormulation undefined

forgedNeedQualificationSourceReference :: O2I.NeedQualificationSourceReference
forgedNeedQualificationSourceReference =
  O2I.NeedQualificationSourceReference undefined

forgedNeedQualificationCandidate :: O2I.NeedQualificationCandidate
forgedNeedQualificationCandidate =
  O2I.NeedQualificationCandidate
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedSemanticallyValidModel :: O2I.SemanticallyValidModel
forgedSemanticallyValidModel = O2I.SemanticallyValidModel undefined undefined

forgedEffectTrace :: O2I.EffectTrace
forgedEffectTrace =
  O2I.EffectTrace
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedEffectTraceId :: O2I.EffectTraceId
forgedEffectTraceId = O2I.EffectTraceId undefined

forgedSituationAnchorRef :: O2I.SomeSituationAnchorRef
forgedSituationAnchorRef = O2I.SomeSituationAnchorRef undefined undefined

forgedTraceableEffectModel :: O2I.TraceableEffectModel
forgedTraceableEffectModel =
  O2I.TraceableEffectModel undefined undefined undefined

forgedMacroEvidenceWitness :: O2I.MacroEvidenceWitness
forgedMacroEvidenceWitness = O2I.MacroEvidenceWitness undefined

forgedKPIDefinition :: O2I.KPIDefinition
forgedKPIDefinition =
  O2I.KPIDefinition undefined undefined undefined undefined undefined

forgedEvidenceReadyModel :: O2I.EvidenceReadyModel
forgedEvidenceReadyModel =
  O2I.EvidenceReadyModel
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedEffectAssessment :: O2I.EffectAssessment
forgedEffectAssessment = O2I.EffectAssessment undefined undefined undefined

forgedEvidenceAssessedModel :: O2I.EvidenceAssessedModel
forgedEvidenceAssessedModel =
  O2I.EvidenceAssessedModel undefined undefined undefined undefined
