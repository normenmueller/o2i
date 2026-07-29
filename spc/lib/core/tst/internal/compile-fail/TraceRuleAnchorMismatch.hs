{-# LANGUAGE DataKinds #-}

module TraceRuleAnchorMismatch where

import O2I.Language.Element
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Rule
import O2I.Validation.Trace.Types

invalidAnchorRule ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> CompiledPlan (EffectTraceConstituents 'BusinessProcess)
invalidAnchorRule prepared context =
  effectTraceConstituentRule prepared context BusinessCapabilityConstituentRule
