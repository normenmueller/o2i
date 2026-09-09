{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for semantic rules.
module O2I.Core.Rule.Catalog.Definition.Semantics
  ( semanticsDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(SemanticsStage)
  , ruleDefinition
  )

-- | Complete semantics stage in explicit rule identity order.
semanticsDefinitions :: NonEmpty CoreRuleDefinition
semanticsDefinitions =
  define
    "core.collective-strategy-realization.asserted-collective-coverage"
    "An Asserted collective realization covers every target Strategy Action and Key Result."
    "Valid asserted primitive witnesses must cover the complete target formulation."
    "Add asserted participant support for each uncovered target formulation member."
    :| [ define
           "core.collective-strategy-realization.asserted-completeness"
           "An Asserted collective realization declares closed participant completeness."
           "An asserted participant set must claim that its contributor inventory is complete."
           "Set participant completeness to closed or keep the proposition Candidate."
       , define
           "core.collective-strategy-realization.asserted-macro-support"
           "Every participant Strategy has Asserted contributes-to support to the target Strategy."
           "Each participant needs an explicit macro contribution to the collective target."
           "Add an Asserted Strategy-contributes-to-Strategy relation for the participant."
       , define
           "core.collective-strategy-realization.asserted-participant-primitive-support"
           "Every participant has Asserted Action or Key Result support into the target formulation."
           "Each participant's contribution must be evidenced below the macro relation."
           "Add an Asserted admitted primitive support relation into the target Strategy."
       , define
           "core.collective-strategy-realization.fit-pairwise-coherence"
           "Collective Fit records every distinct participant pair exactly once."
           "The Fit assessment must cover the complete unordered participant-pair set."
           "Add missing pairs and remove duplicate or extraneous pair records."
       , define
           "core.collective-strategy-realization.fit-participant-binding"
           "Collective Fit participants equal the proposition participant set."
           "Fit evidence must assess exactly the Strategies in the collective claim."
           "Align the Fit participant set with the proposition participants."
       , define
           "core.collective-strategy-realization.fit-participant-compatibility"
           "Collective Fit has exactly one compatibility record for every participant."
           "Each contributing Strategy must receive one explicit compatibility assessment."
           "Add missing records and remove duplicate or extraneous participant records."
       , define
           "core.collective-strategy-realization.fit-target-binding"
           "The Collective Fit target equals the proposition target Strategy."
           "Fit evidence must concern the exact target of the collective claim."
           "Bind Collective Fit to the proposition's target Strategy."
       , define
           "core.collective-strategy-realization.fit-target-guiding-policy"
           "Collective Fit names the valid target Strategy guiding policy."
           "Fit evidence must use the guiding policy from the target formulation proof."
           "Set targetGuidingPolicy to the target formulation's guiding policy."
       , define
           "core.collective-strategy-realization.fit-target-trade-offs"
           "Collective Fit trade-offs equal the valid target Strategy trade-off set."
           "Fit evidence must address every and only declared target trade-off."
           "Align targetTradeOffs with the target formulation trade-offs."
       , define
           "core.contextualization.asserted-dependency"
           "Every Asserted proposition uses only Asserted endpoint contextualizations."
           "Asserted semantic claims cannot depend on Candidate ownership."
           "Assert the required contextualization or keep the dependent proposition Candidate."
       , define
           "core.situated-need.driver-anchoring"
           "Every Need Driver is anchored by an anchor constituting a surfacing Situation."
           "Need drivers must connect to the same situated reality that surfaces the Need."
           "Anchor each Driver through an anchor of a surfacing Situation."
       , define
           "core.situated-need.driver-cardinality"
           "Every Need owns at least one Need Driver."
           "A globally situated Need states at least one observed driver."
           "Add and contextualize at least one Driver under the Need."
       , define
           "core.situated-need.objective-cardinality"
           "Every Need owns at least one Need Objective."
           "A globally situated Need states the outcome that should change."
           "Add and contextualize at least one Objective under the Need."
       , define
           "core.situated-need.objective-grounding"
           "Every Need Objective is grounded by a Driver owned by the same Need."
           "The desired Need outcome must be justified by its observed drivers."
           "Add a grounding relation from a same-Need Driver to each Objective."
       , define
           "core.situated-need.surfacing-situation-anchoring"
           "Every Situation surfacing a Need has at least one constituting anchor."
           "A surfacing Situation must be tied to an explicit observed anchor."
           "Relate each surfacing Situation to a constituting Situation Anchor."
       , define
           "core.situated-need.surfacing-situation-cardinality"
           "Every Need is surfaced by at least one Situation."
           "A globally situated Need must arise from an explicit Situation."
           "Add a Situation-surfaces-Need relation."
       , define
           "core.strategy-formulation.action-contributions"
           "Every listed Strategy Action contributes to at least one listed Key Result."
           "Each Action must explain which measurable Strategy result it advances."
           "Relate every listed Action to one or more listed Key Results."
       , define
           "core.strategy-formulation.actions"
           "Every Strategy owns one or more distinct listed Actions."
           "A complete Strategy formulation includes concrete coherent action choices."
           "List and contextualize at least one distinct Action under the Strategy."
       , define
           "core.strategy-formulation.anchoring.decision-level"
           "The Strategy formulation supplies one nonempty anchoring decision level."
           "A complete formulation locates the Strategy at an explicit decision level."
           "Supply the Strategy's anchoring decision level."
       , define
           "core.strategy-formulation.anchoring.decision-paths"
           "The Strategy formulation supplies one or more distinct anchoring decision paths."
           "A complete formulation states how decisions about the Strategy are made."
           "Supply at least one distinct anchoring decision path."
       , define
           "core.strategy-formulation.anchoring.implementation-logic"
           "The Strategy formulation supplies one nonempty anchoring implementation logic."
           "A complete formulation states how strategic decisions reach implementation."
           "Supply the Strategy's anchoring implementation logic."
       , define
           "core.strategy-formulation.anchoring.period"
           "The Strategy formulation supplies one nonempty anchoring period."
           "A complete formulation states the period in which the Strategy applies."
           "Supply the Strategy's anchoring period."
       , define
           "core.strategy-formulation.anchoring.responsibilities"
           "The Strategy formulation supplies one or more distinct anchoring responsibilities."
           "A complete formulation makes its material responsibilities explicit."
           "Supply at least one distinct anchoring responsibility."
       , define
           "core.strategy-formulation.anchoring.responsibility-scope"
           "The Strategy formulation supplies one nonempty anchoring responsibility scope."
           "A complete formulation states the organizational scope of responsibility."
           "Supply the Strategy's anchoring responsibility scope."
       , define
           "core.strategy-formulation.derived-guardrails"
           "The Strategy formulation supplies one or more distinct derived guardrails."
           "A complete formulation makes the boundaries derived from its choices explicit."
           "Supply at least one distinct derived guardrail."
       , define
           "core.strategy-formulation.diagnosis"
           "Every Strategy owns exactly one diagnosis Driver."
           "A complete Strategy formulation has one unambiguous diagnosis."
           "Keep exactly one Strategy Driver as the formulation diagnosis."
       , define
           "core.strategy-formulation.diagnosis-grounding"
           "The Strategy diagnosis grounds the Strategy intent."
           "The chosen objective must follow from the diagnosed challenge."
           "Add the exact diagnosis-grounds-intent relation."
       , define
           "core.strategy-formulation.fit-rationale"
           "The Strategy formulation supplies one or more distinct Fit rationales."
           "A complete formulation explains why its choices fit the stated challenge."
           "Supply at least one distinct Fit rationale."
       , define
           "core.strategy-formulation.guiding-policy"
           "Every Strategy owns exactly one guiding-policy Principle."
           "A complete Strategy formulation has one coherent guiding policy."
           "Keep exactly one Strategy Principle as the guiding policy."
       , define
           "core.strategy-formulation.guiding-policy-actions"
           "The Strategy guiding policy guides every listed Action."
           "Each action choice must implement the same coherent guiding policy."
           "Relate the guiding policy to every listed Strategy Action."
       , define
           "core.strategy-formulation.intent"
           "Every Strategy owns exactly one intent Objective."
           "A complete Strategy formulation has one unambiguous strategic intent."
           "Keep exactly one Strategy Objective as the formulation intent."
       , define
           "core.strategy-formulation.key-result-substantiation"
           "Every listed Strategy Key Result substantiates the Strategy intent."
           "Each Key Result must evidence progress toward the chosen objective."
           "Relate every listed Key Result to the Strategy intent."
       , define
           "core.strategy-formulation.key-results"
           "Every Strategy owns one or more distinct listed Key Results."
           "A complete Strategy formulation makes intended results observable."
           "List and contextualize at least one distinct Key Result under the Strategy."
       , define
           "core.strategy-formulation.positioning"
           "The Strategy formulation supplies one or more distinct positioning choices."
           "A complete formulation states the position established by its coherent choices."
           "Supply at least one distinct positioning choice."
       , define
           "core.strategy-formulation.scope"
           "The Strategy formulation supplies one or more distinct scope statements."
           "A complete formulation states the domain to which its choices apply."
           "Supply at least one distinct scope statement."
       , define
           "core.strategy-formulation.strategy-binding"
           "The supplemental Strategy identity equals the assessed model Strategy identity."
           "A formulation can qualify only the exact Strategy to which it is bound."
           "Bind the supplemental formulation to the assessed Strategy identity."
       , define
           "core.strategy-formulation.trade-offs"
           "The Strategy formulation supplies one or more distinct trade-offs."
           "A complete formulation makes the exclusions implied by its choices explicit."
           "Supply at least one distinct trade-off."
       , define
           "core.strategy-formulation.vision-orientation"
           "At least one Vision Objective orients the Strategy intent."
           "The strategic objective must connect to an explicit desired future state."
           "Add a Vision-Objective-orients-Strategy-Objective relation to the intent."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier SemanticsStage
