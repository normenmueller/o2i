{-# LANGUAGE OverloadedStrings #-}

-- | Private construction of the static Core rule catalog.
module O2I.Core.Rule.Catalog.Internal
  ( CoreRuleAuthority(..)
  , coreRuleAuthorityText
  , foldCoreRuleAuthority
  , CoreRuleStage(..)
  , capabilityInputRuleStage
  , qualificationRuleStage
  , readinessAndAssessmentRuleStage
  , semanticsRuleStage
  , structureRuleStage
  , traceRuleStage
  , coreRuleStageText
  , foldCoreRuleStage
  , CoreRule(..)
  , CoreRuleCatalog(..)
  , coreRuleCatalog
  , coreRuleCatalogContract
  , coreRuleCatalogEntries
  , coreRuleCatalogSize
  , coreRuleAction
  , coreRuleAuthority
  , coreRuleExpectation
  , coreRuleIdentity
  , coreRuleMeaning
  , coreRuleStage
  , coreRulesForStage
  , lookupCoreRule
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Ord (comparing)
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreContractWitness
  , CoreRuleId
  , coreContractWitness
  , coreRuleIdText
  )
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(..)
  , ruleDefinitionAction
  , ruleDefinitionExpectation
  , ruleDefinitionIdentity
  , ruleDefinitionMeaning
  , ruleDefinitionStage
  )
import O2I.Core.Rule.Catalog.Definition.CapabilityInput
  ( capabilityInputDefinitions
  )
import O2I.Core.Rule.Catalog.Definition.Qualification (qualificationDefinitions)
import O2I.Core.Rule.Catalog.Definition.ReadinessAndAssessment
  ( readinessAndAssessmentDefinitions
  )
import O2I.Core.Rule.Catalog.Definition.Semantics (semanticsDefinitions)
import O2I.Core.Rule.Catalog.Definition.Structure (structureDefinitions)
import O2I.Core.Rule.Catalog.Definition.Trace (traceDefinitions)

-- | Closed authority for every Core rule.
data CoreRuleAuthority =
  CoreAuthority
  deriving (Eq, Ord, Show)

-- | Render the sole Core authority for discovery output.
coreRuleAuthorityText :: CoreRuleAuthority -> Text
coreRuleAuthorityText CoreAuthority = "Core"

-- | Consume the sole closed Core-authority case.
foldCoreRuleAuthority :: result -> CoreRuleAuthority -> result
foldCoreRuleAuthority core CoreAuthority = core

-- | Stage containing rules for capability-owned supplemental inputs.
capabilityInputRuleStage :: CoreRuleStage
capabilityInputRuleStage = CapabilityInputStage

-- | Stage containing qualification rules.
qualificationRuleStage :: CoreRuleStage
qualificationRuleStage = QualificationStage

-- | Shared stage containing readiness and assessment rules.
readinessAndAssessmentRuleStage :: CoreRuleStage
readinessAndAssessmentRuleStage = ReadinessAndAssessmentStage

-- | Stage containing semantic-validation rules.
semanticsRuleStage :: CoreRuleStage
semanticsRuleStage = SemanticsStage

-- | Stage containing structural-validation rules.
structureRuleStage :: CoreRuleStage
structureRuleStage = StructureStage

-- | Stage containing effect-trace rules.
traceRuleStage :: CoreRuleStage
traceRuleStage = TraceStage

-- | Render one closed Core processing stage for discovery output.
coreRuleStageText :: CoreRuleStage -> Text
coreRuleStageText CapabilityInputStage = "capability-input"
coreRuleStageText QualificationStage = "qualification"
coreRuleStageText ReadinessAndAssessmentStage = "readiness-and-assessment"
coreRuleStageText SemanticsStage = "semantics"
coreRuleStageText StructureStage = "structure"
coreRuleStageText TraceStage = "trace"

-- | Consume every closed Core stage without exposing its constructors.
foldCoreRuleStage ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> CoreRuleStage
  -> result
foldCoreRuleStage capabilityInput qualification readinessAndAssessment semantics structure trace stage =
  case stage of
    CapabilityInputStage -> capabilityInput
    QualificationStage -> qualification
    ReadinessAndAssessmentStage -> readinessAndAssessment
    SemanticsStage -> semantics
    StructureStage -> structure
    TraceStage -> trace

-- | One rule identity from the exact compiled Core contract.
--
-- This wrapper carries discovery data only and cannot select evaluation
-- behavior.
data CoreRule =
  CoreRule !CoreRuleDefinition
  deriving (Eq, Ord, Show)

-- | Static complete Core rule catalog bound to one compiled contract witness.
data CoreRuleCatalog =
  CoreRuleCatalog
    !CoreContractWitness
    !(NonEmpty CoreRule)
    !(Map Text CoreRule)
    !(NonEmpty CoreRule)
    !(NonEmpty CoreRule)
    !(NonEmpty CoreRule)
    !(NonEmpty CoreRule)
    !(NonEmpty CoreRule)
    !(NonEmpty CoreRule)

-- | The complete compiled Core rule catalog.
--
-- Construction is constant for one package build. Canonical enumeration is
-- @O(R)@ and exact lookup is @O(log R)@ for @R@ compiled rule identities.
coreRuleCatalog :: CoreRuleCatalog
coreRuleCatalog =
  CoreRuleCatalog
    coreContractWitness
    entries
    byIdentity
    capabilityInputRules
    qualificationRules
    readinessAndAssessmentRules
    semanticsRules
    structureRules
    traceRules
  where
    capabilityInputRules = CoreRule <$> capabilityInputDefinitions
    qualificationRules = CoreRule <$> qualificationDefinitions
    readinessAndAssessmentRules = CoreRule <$> readinessAndAssessmentDefinitions
    semanticsRules = CoreRule <$> semanticsDefinitions
    structureRules = CoreRule <$> structureDefinitions
    traceRules = CoreRule <$> traceDefinitions
    entries =
      NonEmpty.sortBy
        (comparing (coreRuleIdText . coreRuleIdentity))
        (capabilityInputRules
           <> qualificationRules
           <> readinessAndAssessmentRules
           <> semanticsRules
           <> structureRules
           <> traceRules)
    byIdentity =
      Map.fromList
        [ (coreRuleIdText (coreRuleIdentity rule), rule)
        | rule <- NonEmpty.toList entries
        ]

-- | Project the compiled Core contract witness bound to this catalog.
coreRuleCatalogContract :: CoreRuleCatalog -> CoreContractWitness
coreRuleCatalogContract (CoreRuleCatalog witness _ _ _ _ _ _ _ _) = witness

-- | Enumerate every rule in exact compiled-contract order.
coreRuleCatalogEntries :: CoreRuleCatalog -> NonEmpty CoreRule
coreRuleCatalogEntries (CoreRuleCatalog _ entries _ _ _ _ _ _ _) = entries

-- | Return the exact number of compiled Core rules in @O(1)@ time.
coreRuleCatalogSize :: CoreRuleCatalog -> Int
coreRuleCatalogSize (CoreRuleCatalog _ _ byIdentity _ _ _ _ _ _) =
  Map.size byIdentity

-- | Project the sole normative authority for this rule.
coreRuleAuthority :: CoreRule -> CoreRuleAuthority
coreRuleAuthority _ = CoreAuthority

-- | Project the exact Core contract rule identity used as provenance.
coreRuleIdentity :: CoreRule -> CoreRuleId
coreRuleIdentity (CoreRule definition) = ruleDefinitionIdentity definition

-- | Project the exact processing stage that owns this rule.
coreRuleStage :: CoreRule -> CoreRuleStage
coreRuleStage (CoreRule definition) = ruleDefinitionStage definition

-- | Project the normative expectation owned with the compiled rule.
coreRuleExpectation :: CoreRule -> Text
coreRuleExpectation (CoreRule definition) = ruleDefinitionExpectation definition

-- | Project the human-facing meaning without selecting evaluator behavior.
coreRuleMeaning :: CoreRule -> Text
coreRuleMeaning (CoreRule definition) = ruleDefinitionMeaning definition

-- | Project the human-facing corrective action.
coreRuleAction :: CoreRule -> Text
coreRuleAction (CoreRule definition) = ruleDefinitionAction definition

-- | Enumerate the complete canonical partition for one processing stage.
coreRulesForStage :: CoreRuleCatalog -> CoreRuleStage -> NonEmpty CoreRule
coreRulesForStage (CoreRuleCatalog _ _ _ rules _ _ _ _ _) CapabilityInputStage =
  rules
coreRulesForStage (CoreRuleCatalog _ _ _ _ rules _ _ _ _) QualificationStage =
  rules
coreRulesForStage (CoreRuleCatalog _ _ _ _ _ rules _ _ _) ReadinessAndAssessmentStage =
  rules
coreRulesForStage (CoreRuleCatalog _ _ _ _ _ _ rules _ _) SemanticsStage = rules
coreRulesForStage (CoreRuleCatalog _ _ _ _ _ _ _ rules _) StructureStage = rules
coreRulesForStage (CoreRuleCatalog _ _ _ _ _ _ _ _ rules) TraceStage = rules

-- | Look up one exact rule identity without normalization or fallback.
--
-- Lookup is discovery only and performs no semantic dispatch.
lookupCoreRule :: CoreRuleCatalog -> Text -> Maybe CoreRule
lookupCoreRule (CoreRuleCatalog _ _ byIdentity _ _ _ _ _ _) identifier =
  Map.lookup identifier byIdentity
