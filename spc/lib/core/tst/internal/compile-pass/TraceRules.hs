{-# LANGUAGE DataKinds #-}

module TraceRules where

import O2I.Language.Element
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Rule
import O2I.Validation.Trace.Types

addressedNeeds :: PreparedMacroEvidence -> CompiledPlan AddressedNeed
addressedNeeds = addressedNeedRule

contextSkeletons :: PreparedMacroEvidence -> CompiledPlan EffectTraceContext
contextSkeletons = effectTraceContextRule

capabilityConstituents ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> CompiledPlan (EffectTraceConstituents 'BusinessCapability)
capabilityConstituents prepared context =
  effectTraceConstituentRule prepared context BusinessCapabilityConstituentRule

processConstituents ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> CompiledPlan (EffectTraceConstituents 'BusinessProcess)
processConstituents prepared context =
  effectTraceConstituentRule prepared context BusinessProcessConstituentRule

objectConstituents ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> CompiledPlan (EffectTraceConstituents 'BusinessObject)
objectConstituents prepared context =
  effectTraceConstituentRule prepared context BusinessObjectConstituentRule

valueStreamConstituents ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> CompiledPlan (EffectTraceConstituents 'ValueStream)
valueStreamConstituents prepared context =
  effectTraceConstituentRule prepared context ValueStreamConstituentRule
