module CoreRuleCatalogPublicApi where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract (CoreContractWitness, CoreRuleId)
import O2I.Core.Rule.Catalog

catalogContract :: CoreContractWitness
catalogContract = coreRuleCatalogContract coreRuleCatalog

catalogEntries :: NonEmpty CoreRule
catalogEntries = coreRuleCatalogEntries coreRuleCatalog

catalogSize :: Int
catalogSize = coreRuleCatalogSize coreRuleCatalog

ruleAuthority :: CoreRule -> CoreRuleAuthority
ruleAuthority = coreRuleAuthority

ruleAuthorityText :: CoreRule -> Text
ruleAuthorityText = coreRuleAuthorityText . coreRuleAuthority

ruleIdentity :: CoreRule -> CoreRuleId
ruleIdentity = coreRuleIdentity

ruleStage :: CoreRule -> CoreRuleStage
ruleStage = coreRuleStage

ruleExpectation :: CoreRule -> Text
ruleExpectation = coreRuleExpectation

ruleMeaning :: CoreRule -> Text
ruleMeaning = coreRuleMeaning

ruleAction :: CoreRule -> Text
ruleAction = coreRuleAction

stageRules :: CoreRuleStage -> NonEmpty CoreRule
stageRules = coreRulesForStage coreRuleCatalog

exactLookup :: Text -> Maybe CoreRule
exactLookup = lookupCoreRule coreRuleCatalog
