{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for trace rules.
module O2I.Core.Rule.Catalog.Definition.Trace
  ( traceDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(TraceStage)
  , ruleDefinition
  )

-- | Complete trace stage in explicit rule identity order.
traceDefinitions :: NonEmpty CoreRuleDefinition
traceDefinitions =
  ownership
    "core.trace.ownership.intervention-action-at-intervention"
    "Intervention Action"
    "Intervention"
    :| [ ownership
           "core.trace.ownership.intervention-key-result-at-intervention"
           "Intervention Key Result"
           "Intervention"
       , ownership
           "core.trace.ownership.measure-kpi-at-measure"
           "Measure KPI"
           "Measure"
       , ownership
           "core.trace.ownership.measure-performance-dimension-at-measure"
           "Measure Performance Dimension"
           "Measure"
       , ownership
           "core.trace.ownership.need-driver-at-need"
           "Need Driver"
           "Need"
       , ownership
           "core.trace.ownership.need-objective-at-need"
           "Need Objective"
           "Need"
       , ownership
           "core.trace.ownership.strategy-action-at-strategy"
           "Strategy Action"
           "Strategy"
       , ownership
           "core.trace.ownership.strategy-driver-at-strategy"
           "Strategy Driver"
           "Strategy"
       , ownership
           "core.trace.ownership.strategy-key-result-at-strategy"
           "Strategy Key Result"
           "Strategy"
       , ownership
           "core.trace.ownership.strategy-objective-at-strategy"
           "Strategy Objective"
           "Strategy"
       , ownership
           "core.trace.ownership.vision-objective-at-vision"
           "Vision Objective"
           "Vision"
       , define
           "core.trace.promotion.strategy-action-membership"
           "The traced Strategy Action belongs to the eligible Strategy formulation."
           "Trace promotion may use only an Action proven by the Strategy assessment."
           "Select an Action listed in the eligible Strategy formulation."
       , define
           "core.trace.promotion.strategy-diagnosis"
           "The traced Strategy Driver equals the eligible formulation diagnosis."
           "Trace promotion preserves the Strategy proof's exact diagnosis."
           "Set strategyDriver to the formulation diagnosis."
       , define
           "core.trace.promotion.strategy-identity"
           "The traced Strategy equals the Strategy represented by the eligibility proof."
           "A Strategy proof can promote only a trace for that same Strategy."
           "Use the eligibility proof for the traced Strategy."
       , define
           "core.trace.promotion.strategy-intent"
           "The traced Strategy Objective equals the eligible formulation intent."
           "Trace promotion preserves the Strategy proof's exact intent."
           "Set strategyObjective to the formulation intent."
       , define
           "core.trace.promotion.strategy-key-result-membership"
           "The traced Strategy Key Result belongs to the eligible Strategy formulation."
           "Trace promotion may use only a Key Result proven by the Strategy assessment."
           "Select a Key Result listed in the eligible Strategy formulation."
       , define
           "core.trace.promotion.strategy-model-identity"
           "The Strategy eligibility proof belongs to the same semantic model as the trace."
           "Proofs cannot be transferred between selected-View graph identities."
           "Reconstruct the Strategy proof from the trace's current semantic model."
       , define
           "core.trace.promotion.strategy-proof"
           "Trace promotion has one available valid QualificationEligibleStrategy proof."
           "A complete supplied trace alone does not establish Strategy formulation validity."
           "Provide and validate the traced Strategy's formulation input."
       , define
           "core.trace.root.asserted-presence"
           "The graph has at least one Asserted Intervention-addresses-Need root."
           "Each effect trace begins from an explicit asserted Intervention and Need pair."
           "Add an Asserted Intervention-addresses-Need relation."
       , relation
           "core.trace.slot.intervention-action-changes-same-situation-anchor"
           "Intervention Action"
           "changes"
           "the same Situation Anchor"
       , relation
           "core.trace.slot.intervention-action-contributes-to-intervention-key-result"
           "Intervention Action"
           "contributes to"
           "Intervention Key Result"
       , relation
           "core.trace.slot.intervention-addresses-need"
           "Intervention"
           "addresses"
           "Need"
       , relation
           "core.trace.slot.intervention-changes-situation"
           "Intervention"
           "changes"
           "Situation"
       , relation
           "core.trace.slot.intervention-key-result-contributes-to-strategy-key-result"
           "Intervention Key Result"
           "contributes to"
           "Strategy Key Result"
       , relation
           "core.trace.slot.intervention-key-result-sets-target-for-measure-kpi"
           "Intervention Key Result"
           "sets a target for"
           "Measure KPI"
       , relation
           "core.trace.slot.intervention-key-result-substantiates-need-objective"
           "Intervention Key Result"
           "substantiates"
           "Need Objective"
       , relation
           "core.trace.slot.intervention-sets-target-for-measure"
           "Intervention"
           "sets a target for"
           "Measure"
       , relation
           "core.trace.slot.measure-kpi-measures-situation-anchor"
           "Measure KPI"
           "measures"
           "the same Situation Anchor"
       , relation
           "core.trace.slot.measure-measures-situation"
           "Measure"
           "measures"
           "Situation"
       , relation
           "core.trace.slot.measure-performance-dimension-contains-measure-kpi"
           "Measure Performance Dimension"
           "contains"
           "Measure KPI"
       , relation
           "core.trace.slot.need-driver-grounds-need-objective"
           "Need Driver"
           "grounds"
           "Need Objective"
       , relation
           "core.trace.slot.situation-anchor-anchors-need-driver"
           "Situation Anchor"
           "anchors"
           "Need Driver"
       , relation
           "core.trace.slot.situation-is-constituted-by-same-situation-anchor"
           "Situation"
           "is constituted by"
           "the same Situation Anchor"
       , relation
           "core.trace.slot.situation-surfaces-need"
           "Situation"
           "surfaces"
           "Need"
       , relation
           "core.trace.slot.strategy-action-contributes-to-strategy-key-result"
           "Strategy Action"
           "contributes to"
           "Strategy Key Result"
       , relation
           "core.trace.slot.strategy-action-guides-intervention-action"
           "Strategy Action"
           "guides"
           "Intervention Action"
       , relation
           "core.trace.slot.strategy-directs-intervention"
           "Strategy"
           "directs"
           "Intervention"
       , relation
           "core.trace.slot.strategy-driver-grounds-strategy-objective"
           "Strategy Driver"
           "grounds"
           "Strategy Objective"
       , relation
           "core.trace.slot.strategy-driver-indicates-measure-performance-dimension"
           "Strategy Driver"
           "indicates"
           "Measure Performance Dimension"
       , relation
           "core.trace.slot.strategy-frames-measure"
           "Strategy"
           "frames"
           "Measure"
       , relation
           "core.trace.slot.strategy-key-result-determines-measure-performance-dimension"
           "Strategy Key Result"
           "determines"
           "Measure Performance Dimension"
       , relation
           "core.trace.slot.strategy-key-result-substantiates-strategy-objective"
           "Strategy Key Result"
           "substantiates"
           "Strategy Objective"
       , relation
           "core.trace.slot.strategy-key-result-translates-into-need-objective"
           "Strategy Key Result"
           "translates into"
           "Need Objective"
       , relation
           "core.trace.slot.strategy-qualifies-need"
           "Strategy"
           "qualifies"
           "Need"
       , relation
           "core.trace.slot.vision-objective-orients-strategy-objective"
           "Vision Objective"
           "orients"
           "Strategy Objective"
       , relation
           "core.trace.slot.vision-orients-strategy"
           "Vision"
           "orients"
           "Strategy"
       , define
           "core.trace.supplied.graph-identity"
           "A supplied TraceIdentity names the current selected-View graph identity."
           "Direct trace validation cannot use a trace from another graph subject."
           "Supply a TraceIdentity reconstructed for the current selected View."
       , define
           "core.trace.supplied.ownership-slot"
           "Every supplied trace ownership slot has Asserted exact-endpoint support."
           "A supplied trace must prove each fixed contextualization directly."
           "Add Asserted support for the reported ownership slot and endpoints."
       , define
           "core.trace.supplied.relation-slot"
           "Every supplied trace relation slot has Asserted exact-endpoint support."
           "A supplied trace must prove each fixed semantic relation directly."
           "Add Asserted support for the reported relation slot and endpoints."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier TraceStage

ownership :: Text -> Text -> Text -> CoreRuleDefinition
ownership identifier member context =
  define
    identifier
    ("The trace's "
       <> member
       <> " is Asserted-contextualized by its exact "
       <> context
       <> ".")
    ("The witness must preserve exact " <> member <> " ownership.")
    ("Add the required Asserted " <> context <> " contextualization.")

relation :: Text -> Text -> Text -> Text -> CoreRuleDefinition
relation identifier source relationName target =
  define
    identifier
    ("The trace has Asserted support where "
       <> source
       <> " "
       <> relationName
       <> " "
       <> target
       <> ".")
    "The complete witness requires this exact endpoint-bound relation slot."
    ("Add the required Asserted "
       <> source
       <> " "
       <> relationName
       <> " "
       <> target
       <> " relation.")
