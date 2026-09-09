module CoreRuleCatalogInternalModule where

import O2I.Core.Rule.Catalog.Internal

internalRule :: CoreRule -> CoreRule
internalRule = id
