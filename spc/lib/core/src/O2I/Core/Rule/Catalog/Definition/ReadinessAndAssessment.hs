{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for readiness and assessment rules.
module O2I.Core.Rule.Catalog.Definition.ReadinessAndAssessment
  ( readinessAndAssessmentDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(ReadinessAndAssessmentStage)
  , ruleDefinition
  )

-- | Complete readiness-and-assessment stage in explicit identity order.
readinessAndAssessmentDefinitions :: NonEmpty CoreRuleDefinition
readinessAndAssessmentDefinitions =
  define
    "core.assessment.actual-start.cardinality"
    "An assessment has exactly one actual start for the traced Intervention."
    "Assessment chronology begins from one unambiguous Intervention start."
    "Provide one actual start bound to the traced Intervention."
    :| [ define
           "core.assessment.actual-start.chronology"
           "Readiness precedes actual start, and actual start does not follow assessment."
           "The assessment timeline must begin after readiness and by assessment time."
           "Correct actualStartAt or assessedAt to satisfy the required chronology."
       , define
           "core.assessment.anchor.identity"
           "Every observation names the Situation Anchor bound by its TraceIdentity."
           "Observed evidence must concern the exact traced anchor."
           "Set the observation anchor to the trace's Situation Anchor."
       , define
           "core.assessment.chronology.observation"
           "Every observation occurs after actual start and no later than assessment."
           "Only post-start evidence available by assessment time is admissible."
           "Correct observedAt, actualStartAt, or assessedAt."
       , define
           "core.assessment.coverage.trace-observation"
           "The bound TraceIdentity has at least one submitted observation."
           "An evidence assessment requires observed evidence for its trace."
           "Provide at least one observation for the bound trace."
       , define
           "core.assessment.effect-criterion.apply"
           "Every valid observation is evaluated by the bound ex-ante effect criterion."
           "Effect attainment is determined only by the declared readiness criterion."
           "Correct the observation value or revise the plan before evidence collection."
       , define
           "core.assessment.identity.observation"
           "Every observation has one complete canonical observation identity."
           "TraceIdentity and observation time identify one evidence occurrence."
           "Provide the complete trace binding and canonical observedAt value."
       , define
           "core.assessment.identity.observation-uniqueness"
           "No two observations share the same TraceIdentity and observedAt identity."
           "Observation identity must be unique within the assessment bundle."
           "Remove the duplicate or assign the correct observation time."
       , define
           "core.assessment.kpi.identity"
           "Every observation names the Measure KPI bound by its TraceIdentity."
           "Observed values must measure the exact traced KPI."
           "Set the observation KPI to the trace's Measure KPI."
       , define
           "core.assessment.limitations.required"
           "Every assessed observation records all required assessment limitations."
           "The result must not imply causal proof or known first attainment time."
           "Include the required causality and first-attainment limitations."
       , define
           "core.assessment.readiness.reconstructed-proof"
           "Assessment reconstructs an EvidenceReady proof for the same current subject."
           "Persisted or stale readiness proof material is not an assessment prerequisite."
           "Correct the embedded readiness input against the current selected View."
       , define
           "core.assessment.source.nonempty"
           "Every observation has one nonempty canonical source."
           "Evidence must identify where the observed value came from."
           "Provide a canonical nonempty source description."
       , define
           "core.assessment.target-criterion.apply"
           "Every valid observation is evaluated by the bound ex-ante target criterion."
           "Target attainment and due disposition follow the declared readiness plan."
           "Correct the observation value or revise the plan before evidence collection."
       , define
           "core.assessment.trace.identity"
           "Every observation carries the exact bound TraceIdentity."
           "Assessment evidence cannot be transferred between effect traces."
           "Replace the observation trace with the assessment's bound trace."
       , define
           "core.assessment.value-domain.observation"
           "Every observation value belongs to the bound KPI value domain."
           "An out-of-domain value cannot be compared with the evidence criteria."
           "Provide a quantitative, ordinal, or categorical value in the KPI domain."
       , define
           "core.readiness.baseline.chronology"
           "The baseline is observed no earlier than plan establishment and no later than readiness."
           "The ex-ante baseline must exist by the readiness decision."
           "Correct planEstablishedAt, baseline observedAt, or readinessCheckedAt."
       , define
           "core.readiness.baseline.identity"
           "The baseline belongs to the exact KPI and trace in the evidence plan."
           "Readiness requires a baseline for the effect being traced and measured."
           "Bind the baseline to the plan's exact TraceIdentity and Measure KPI."
       , define
           "core.readiness.baseline.value-domain"
           "The baseline value belongs to the bound KPI value domain."
           "Effect change can be evaluated only from a domain-valid baseline."
           "Provide a baseline value in the KPI's declared domain."
       , define
           "core.readiness.effect-criterion.kind"
           "The effect criterion kind is compatible with the bound KPI domain."
           "Quantitative, ordinal, and categorical domains admit different criteria."
           "Choose an effect criterion admitted by the KPI domain kind."
       , define
           "core.readiness.effect-criterion.value-domain"
           "The effect criterion parameters belong to the bound KPI value domain."
           "Criterion units, scales, levels, and categories must match the KPI."
           "Align the effect criterion values with the KPI domain."
       , define
           "core.readiness.evidence-plan.cardinality"
           "Readiness has exactly one plan for the exact current complete TraceIdentity."
           "One unambiguous ex-ante plan governs evidence collection for the trace."
           "Provide one evidence plan bound to the current complete trace."
       , define
           "core.readiness.evidence-plan.chronology"
           "Plan, baseline, readiness, planned start, and target due times are ordered."
           "The evidence plan must be established before intervention and target due time."
           "Correct the plan timestamps to satisfy the required total chronology."
       , define
           "core.readiness.evidence-plan.source"
           "The evidence plan and its baseline have nonempty canonical sources."
           "Readiness requires traceable sources for planned and baseline evidence."
           "Provide canonical nonempty plan and baseline source descriptions."
       , define
           "core.readiness.kpi-definition.cardinality"
           "Readiness has exactly one KPI definition for the traced Measure KPI."
           "One domain definition governs evidence values for the trace."
           "Provide one KPI definition bound to the traced Measure KPI."
       , define
           "core.readiness.kpi-definition.interpretation"
           "The KPI definition has one nonempty canonical interpretation."
           "Consumers need an explicit meaning for the measured values."
           "Provide a canonical nonempty KPI interpretation."
       , define
           "core.readiness.kpi-definition.measurement-method"
           "The KPI definition has one nonempty canonical measurement method."
           "Evidence collection must state how KPI values are obtained."
           "Provide a canonical nonempty measurement method."
       , define
           "core.readiness.kpi-definition.unit"
           "A quantitative KPI definition has one exact canonical unit."
           "Quantitative values and criteria must share one measurement unit."
           "Provide the KPI unit and use it consistently in values and criteria."
       , define
           "core.readiness.kpi-definition.value-domain"
           "The KPI definition has one valid quantitative, ordinal, or categorical domain."
           "The closed value domain determines admissible evidence and criteria."
           "Correct the unit, scale, levels, categories, or effect direction."
       , define
           "core.readiness.planned-start.cardinality"
           "Readiness has exactly one planned start for the traced Intervention."
           "One planned start anchors the ex-ante evidence chronology."
           "Provide one planned start bound to the traced Intervention."
       , define
           "core.readiness.target-criterion.due"
           "The target due time follows the planned Intervention start."
           "Target attainment must have a future due boundary at readiness time."
           "Set targetDueAt after plannedStartAt."
       , define
           "core.readiness.target-criterion.kind"
           "The target criterion kind is compatible with the bound KPI domain."
           "Quantitative, ordinal, and categorical domains admit different targets."
           "Choose a target criterion admitted by the KPI domain kind."
       , define
           "core.readiness.target-criterion.value-domain"
           "The target criterion parameters belong to the bound KPI value domain."
           "Target units, scales, levels, and categories must match the KPI."
           "Align the target criterion values with the KPI domain."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier ReadinessAndAssessmentStage
