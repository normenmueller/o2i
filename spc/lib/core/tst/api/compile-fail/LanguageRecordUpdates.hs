{-# LANGUAGE DataKinds #-}

module LanguageRecordUpdates where

import qualified O2I.Language as Language

rewriteClaim :: Language.Claim value -> Language.Claim value
rewriteClaim modelClaim =
  modelClaim {Language.claimCommitment = Language.claimCommitment modelClaim}

rewriteContextRef :: Language.ContextRef context -> Language.ContextRef context
rewriteContextRef reference =
  reference {Language.contextRefId = Language.contextRefId reference}

type EthosPrincipleSpec
  = Language.InterpretationSpec 'Language.Ethos 'Language.Principle

rewriteInterpretationCode :: EthosPrincipleSpec -> EthosPrincipleSpec
rewriteInterpretationCode spec =
  spec {Language.interpretationCode = Language.interpretationCode spec}

rewriteInterpretationContext :: EthosPrincipleSpec -> EthosPrincipleSpec
rewriteInterpretationContext spec =
  spec {Language.interpretationContext = Language.interpretationContext spec}

rewriteInterpretationPrimitive :: EthosPrincipleSpec -> EthosPrincipleSpec
rewriteInterpretationPrimitive spec =
  spec
    {Language.interpretationPrimitive = Language.interpretationPrimitive spec}

rewriteInterpretationWitness :: EthosPrincipleSpec -> EthosPrincipleSpec
rewriteInterpretationWitness spec =
  spec {Language.interpretationWitness = Language.interpretationWitness spec}

type MacroSpec
  = Language.RelationSpec
      ('Language.ContextKind 'Language.Ethos)
      ('Language.ContextKind 'Language.Mission)

rewriteRelationCode :: MacroSpec -> MacroSpec
rewriteRelationCode spec =
  spec {Language.relationCode = Language.relationCode spec}

rewriteRelationSemantics :: MacroSpec -> MacroSpec
rewriteRelationSemantics spec =
  spec {Language.relationSemantics = Language.relationSemantics spec}

rewriteRelationName :: MacroSpec -> MacroSpec
rewriteRelationName spec =
  spec {Language.relationName = Language.relationName spec}

rewriteRelationLabel :: MacroSpec -> MacroSpec
rewriteRelationLabel spec =
  spec {Language.relationLabel = Language.relationLabel spec}

rewriteRelationFrom :: MacroSpec -> MacroSpec
rewriteRelationFrom spec =
  spec {Language.relationFrom = Language.relationFrom spec}

rewriteRelationTo :: MacroSpec -> MacroSpec
rewriteRelationTo spec = spec {Language.relationTo = Language.relationTo spec}
