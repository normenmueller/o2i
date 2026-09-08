{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed discovery boundary for the compiled O2I Core rule inventory.
--
-- A t'CoreRule' carries discovery and explanation data only. Capability
-- evaluators use their own closed typed rule constructors; neither rule text
-- nor catalog lookup selects semantic behavior.
module O2I.Core.Rule.Catalog
  ( CoreRuleAuthority
  , coreRuleAuthorityText
  , foldCoreRuleAuthority
  , CoreRuleStage
  , capabilityInputRuleStage
  , qualificationRuleStage
  , readinessAndAssessmentRuleStage
  , semanticsRuleStage
  , structureRuleStage
  , traceRuleStage
  , coreRuleStageText
  , foldCoreRuleStage
  , type CoreRule
  , CoreRuleCatalog
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

import O2I.Core.Rule.Catalog.Internal
