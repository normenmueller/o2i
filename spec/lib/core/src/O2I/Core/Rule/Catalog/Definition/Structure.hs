{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for structural rules.
module O2I.Core.Rule.Catalog.Definition.Structure
  ( structureDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(StructureStage)
  , ruleDefinition
  )

-- | Complete structure stage in explicit rule identity order.
structureDefinitions :: NonEmpty CoreRuleDefinition
structureDefinitions =
  define
    "core.collective-strategy-realization.participant-cardinality"
    "A collective Strategy realization has at least two participant Strategies."
    "Collective realization requires more than one contributing Strategy."
    "Add participant incidences until at least two Strategies participate."
    :| [ define
           "core.collective-strategy-realization.participant-type"
           "Every participant incidence targets a Strategy Context."
           "Only Strategies can participate in collective Strategy realization."
           "Replace the endpoint with a context.strategy occurrence."
       , define
           "core.collective-strategy-realization.participant-uniqueness"
           "Collective realization participant Strategies are distinct."
           "One Strategy cannot fill multiple participant positions in the same claim."
           "Remove duplicate participant incidences."
       , define
           "core.collective-strategy-realization.target-cardinality"
           "A collective Strategy realization has exactly one target Strategy."
           "The collective contribution must converge on one unambiguous target."
           "Provide exactly one target incidence."
       , define
           "core.collective-strategy-realization.target-distinctness"
           "The target Strategy is distinct from every participant Strategy."
           "A Strategy cannot contribute collectively to itself in the same claim."
           "Choose a target outside the participant set."
       , define
           "core.collective-strategy-realization.target-type"
           "The target incidence targets a Strategy Context."
           "Collective Strategy realization can target only a Strategy."
           "Replace the endpoint with a context.strategy occurrence."
       , define
           "core.contextualization.source-category"
           "Every contextualization source is a Context."
           "Only Contexts own contextualized O2I elements."
           "Use a Context as the source of the contextualization."
       , define
           "core.contextualization.target-category"
           "Every contextualization target is a Primitive or Structuring element."
           "Only contextualized element categories can receive Context ownership."
           "Use a Primitive or Structuring endpoint as the target."
       , define
           "core.contextualization.target-owner-cardinality"
           "Every contextualized element has exactly one Context owner."
           "Qualified endpoint meaning requires one unambiguous owning Context."
           "Add the missing owner or remove competing contextualizations."
       , define
           "core.qualified-endpoint.catalog-membership"
           "Every carrier resolves to exactly one admitted qualified Core endpoint."
           "Carrier category, O2I type, and ownership must identify one Core endpoint."
           "Correct the carrier type, category, or contextualization."
       , define
           "core.semantic-relation.compatibility"
           "Every relation token and qualified endpoint pair matches one Core relation."
           "Only relations admitted for the exact source and target types are valid."
           "Correct the relation token or one of its qualified endpoints."
       , define
           "core.structured-proposition.commitment"
           "Every structured proposition has exactly one Candidate or Asserted commitment."
           "The complete proposition carries one explicit commitment state."
           "Provide exactly one admitted commitment."
       , define
           "core.structured-proposition.family"
           "Every structured proposition names exactly one admitted family."
           "The family selects the proposition's closed structural contract."
           "Provide one exact admitted structured-proposition family identity."
       , define
           "core.structured-proposition.identity"
           "Every structured proposition has one nonempty model-wide unique identity."
           "The indivisible proposition must be addressable without ambiguity."
           "Provide a nonempty identity that is unique in the model."
       , define
           "core.structured-proposition.incidence"
           "Every structured incidence has one admitted role and resolvable endpoint."
           "Role-labelled occurrences form the complete proposition boundary."
           "Correct the incidence role or endpoint reference."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier StructureStage
