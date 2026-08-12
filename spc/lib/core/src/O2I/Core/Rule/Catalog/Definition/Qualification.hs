{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for qualification rules.
module O2I.Core.Rule.Catalog.Definition.Qualification
  ( qualificationDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(QualificationStage)
  , ruleDefinition
  )

-- | Complete qualification stage in explicit rule identity order.
qualificationDefinitions :: NonEmpty CoreRuleDefinition
qualificationDefinitions =
  define
    "core.qualification.pair.proposal-presence"
    "Every eligible selected Need and Strategy pair has a qualification proposal."
    "A requested eligible pair must be represented by a formal proposal."
    "Add a proposal routed to the reported Need and Strategy pair."
    :| [ define
           "core.qualification.proposal.effect-graph-membership"
           "A qualification proposal is not already part of the effect graph."
           "Proposals remain outside the model until authorized acceptance."
           "Remove the proposal from the effect graph before qualification."
       , define
           "core.qualification.proposal.existing-macro-qualification"
           "No Candidate or Asserted Strategy-qualifies-Need relation already exists for the proposal."
           "A proposal must not duplicate an existing macro qualification."
           "Remove the duplicate proposal or resolve the existing qualification."
       , define
           "core.qualification.proposal.existing-primitive-support"
           "No Candidate or Asserted proposed primitive support relation already exists."
           "A proposal must not duplicate existing Key Result to Need Objective support."
           "Remove the duplicate proposal or resolve the existing primitive support."
       , define
           "core.qualification.proposal.key-result-context"
           "The proposed Key Result is contextualized by the selected Strategy."
           "Primitive support must originate in the Strategy being qualified."
           "Select a Key Result owned by the proposal's Strategy."
       , define
           "core.qualification.proposal.listed-key-result"
           "The proposed Key Result occurs in the selected Strategy formulation."
           "Qualification may use only a Key Result admitted by the Strategy proof."
           "List the Key Result in the Strategy formulation or select a listed one."
       , define
           "core.qualification.proposal.need-eligibility"
           "The selected Need has a GloballySituatedNeed proof from this model."
           "Only a semantically eligible Need can enter qualification."
           "Correct the Need semantics before qualifying it."
       , define
           "core.qualification.proposal.objective-context"
           "The proposed Objective is contextualized by the selected Need."
           "Primitive support must terminate in the Need being qualified."
           "Select an Objective owned by the proposal's Need."
       , define
           "core.qualification.proposal.rationale"
           "A qualification proposal has exactly one nonempty normalized rationale."
           "The proposed qualification must carry explicit documentation."
           "Provide one canonical nonempty rationale."
       , define
           "core.qualification.proposal.role.key-result.cardinality"
           "A qualification proposal has exactly one Key Result role endpoint."
           "One Key Result is required to route the primitive support proposal."
           "Provide exactly one Key Result role endpoint."
       , define
           "core.qualification.proposal.role.key-result.target"
           "The Key Result role targets a Strategy Key Result."
           "The role endpoint must have the qualified type required by the proposal."
           "Reference a primitive.strategy.key-result endpoint."
       , define
           "core.qualification.proposal.role.need.cardinality"
           "A qualification proposal has exactly one Need role endpoint."
           "One Need is required to derive the proposal route."
           "Provide exactly one Need role endpoint."
       , define
           "core.qualification.proposal.role.need.target"
           "The Need role targets a Need Context."
           "The route role must resolve to the qualified Need type."
           "Reference a context.need endpoint."
       , define
           "core.qualification.proposal.role.objective.cardinality"
           "A qualification proposal has exactly one Objective role endpoint."
           "One Need Objective is required for the proposed primitive support."
           "Provide exactly one Objective role endpoint."
       , define
           "core.qualification.proposal.role.objective.target"
           "The Objective role targets a Need Objective."
           "The role endpoint must have the qualified type required by the proposal."
           "Reference a primitive.need.objective endpoint."
       , define
           "core.qualification.proposal.role.strategy.cardinality"
           "A qualification proposal has exactly one Strategy role endpoint."
           "One Strategy is required to derive the proposal route."
           "Provide exactly one Strategy role endpoint."
       , define
           "core.qualification.proposal.role.strategy.target"
           "The Strategy role targets a Strategy Context."
           "The route role must resolve to the qualified Strategy type."
           "Reference a context.strategy endpoint."
       , define
           "core.qualification.proposal.selected-need"
           "The proposal Need belongs to the explicit selected Need set."
           "Only requested Need and Strategy routes are assessed."
           "Select the Need for this request or route the proposal to a selected Need."
       , define
           "core.qualification.proposal.selected-strategy"
           "The proposal Strategy belongs to the explicit selected Strategy set."
           "Only requested Need and Strategy routes are assessed."
           "Select the Strategy or route the proposal to a selected Strategy."
       , define
           "core.qualification.proposal.sources"
           "A qualification proposal has one or more normalized source identities."
           "The rationale requires explicit traceable source references."
           "Provide at least one canonical source identity."
       , define
           "core.qualification.proposal.strategy-eligibility"
           "The selected Strategy has a QualificationEligibleStrategy proof from this model."
           "Only a complete valid Strategy formulation can enter qualification."
           "Correct the Strategy formulation before qualifying it."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier QualificationStage
