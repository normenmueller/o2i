{-# LANGUAGE DataKinds #-}

module MacroEvidenceProjectionMismatch where

import O2I.Language.Element
import O2I.Language.Macro

strategyKeyResult ::
     TypedMacroSelector 'Strategy 'Need ('PrimitiveKind 'Strategy 'KeyResult)
strategyKeyResult = SourceStrategyRoleSelector StrategyKeyResultRole

invalidProjection :: SNodeKind ('PrimitiveKind 'Need 'Objective)
invalidProjection = typedSelectorKind strategyKeyResult
