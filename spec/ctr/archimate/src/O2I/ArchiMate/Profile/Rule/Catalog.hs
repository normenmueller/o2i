-- | Complete discovery catalog for exact selected-Profile rule explanations.
--
-- The ArchiMate Profile package is the sole owner of this inventory. The
-- catalog is static, performs no I/O, and provides no evaluator or semantic
-- dispatch mechanism.
module O2I.ArchiMate.Profile.Rule.Catalog
  ( ProfileRuleCatalog
  , selectedProfileRuleCatalog
  , selectedProfileRuleCatalogProfileReference
  , selectedProfileRuleCatalogContractDigest
  , selectedProfileRuleCatalogEntries
  , selectedProfileRuleCatalogSize
  , selectedProfileRulesForStage
  , lookupSelectedProfileRule
  , foldSelectedProfileRuleCatalog
  ) where

import O2I.ArchiMate.Profile.Rule.Internal.Catalog
