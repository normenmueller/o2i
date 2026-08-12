-- | Static discovery catalog for Operation-owned bootstrap rules.
--
-- The catalog exposes provenance and explanation data only. Rule identifiers
-- and text never select evaluator behavior.
module O2I.Operation.Rule.Catalog
  ( OperationRuleId
  , operationRuleIdText
  , OperationRuleAuthority
  , operationRuleAuthorityText
  , foldOperationRuleAuthority
  , OperationRuleStage
  , operationRuleStageText
  , foldOperationRuleStage
  , OperationRule
  , operationRuleIdentity
  , operationRuleAuthority
  , operationRuleStage
  , operationRuleExpectation
  , operationRuleMeaning
  , operationRuleAction
  , OperationRuleCatalog
  , operationRuleCatalog
  , operationRuleCatalogContractIdentity
  , operationRuleCatalogContractVersion
  , operationRuleCatalogContractDigest
  , operationRuleCatalogEntries
  , operationRuleCatalogSize
  , operationRulesForStage
  , lookupOperationRule
  ) where

import O2I.Operation.Rule.Internal.Catalog
