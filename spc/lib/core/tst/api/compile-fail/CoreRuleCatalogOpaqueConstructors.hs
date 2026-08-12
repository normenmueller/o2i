module CoreRuleCatalogOpaqueConstructors where

import O2I.Core.Rule.Catalog

rebuildRule :: CoreRule -> CoreRule
rebuildRule rule = CoreRule (coreRuleIdentity rule)
