{-# LANGUAGE DataKinds #-}

module LanguageOpaqueConstructors where

import qualified O2I.Language as Language

forgedNodeId :: Language.NodeId ('Language.ContextKind 'Language.Need)
forgedNodeId = Language.NodeId undefined

forgedContextRef :: Language.ContextRef 'Language.Need
forgedContextRef = Language.ContextRef undefined

forgedInterpretationSpec ::
     Language.InterpretationSpec 'Language.Ethos 'Language.Principle
forgedInterpretationSpec =
  Language.InterpretationSpec undefined undefined undefined undefined

forgedSomeInterpretation :: Language.SomeInterpretation
forgedSomeInterpretation = Language.SomeInterpretation undefined

forgedRelation ::
     Language.Relation
       ('Language.ContextKind 'Language.Ethos)
       ('Language.ContextKind 'Language.Mission)
forgedRelation = Language.Relation undefined

forgedSomeRelation :: Language.SomeRelation
forgedSomeRelation = Language.SomeRelation undefined

forgedMacroClaim :: Language.MacroClaim ()
forgedMacroClaim = Language.MacroClaim undefined

forgedMacroEvidenceRule :: Language.MacroEvidenceRule
forgedMacroEvidenceRule = Language.MacroEvidenceRule undefined undefined

forgedRelationSpec ::
     Language.RelationSpec
       ('Language.ContextKind 'Language.Ethos)
       ('Language.ContextKind 'Language.Mission)
forgedRelationSpec =
  Language.RelationSpec
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
