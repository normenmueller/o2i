{-# LANGUAGE DataKinds #-}

module MacroEvidenceEndpointMismatch where

import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation

invalidAlternative :: AlternativeShape 'Strategy 'Need
invalidAlternative =
  Single
    (SourceStrategyRoleSelector StrategyKeyResultRole)
    translatesStrategyKeyResultToNeedObjective
    (TargetPrimitiveSelector SNeed SDriver)
