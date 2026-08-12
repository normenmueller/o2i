{-# LANGUAGE OverloadedStrings #-}

-- | Private assembly of the static Operation bootstrap-rule catalog.
module O2I.Operation.Rule.Internal.Catalog
  ( OperationRuleId(..)
  , operationRuleIdText
  , OperationRuleAuthority(..)
  , operationRuleAuthorityText
  , foldOperationRuleAuthority
  , OperationRuleStage(..)
  , operationRuleStageText
  , foldOperationRuleStage
  , OperationRule(..)
  , operationRuleIdentity
  , operationRuleAuthority
  , operationRuleStage
  , operationRuleExpectation
  , operationRuleMeaning
  , operationRuleAction
  , OperationRuleCatalog(..)
  , operationRuleCatalog
  , operationRuleCatalogContractIdentity
  , operationRuleCatalogContractVersion
  , operationRuleCatalogContractDigest
  , operationRuleCatalogEntries
  , operationRuleCatalogSize
  , operationRulesForStage
  , lookupOperationRule
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import O2I.Operation.Rule.Generated

-- | Exact Operation bootstrap-rule identity.
newtype OperationRuleId =
  OperationRuleId Text
  deriving (Eq, Ord, Show)

-- | Sole normative authority for Operation bootstrap rules.
data OperationRuleAuthority =
  OperationAuthority
  deriving (Eq, Ord, Show)

-- | Closed processing stage for Operation bootstrap rules.
data OperationRuleStage =
  PreparationStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One rule from the exact compiled Operation contract.
--
-- This value carries discovery data only and cannot select execution behavior.
newtype OperationRule =
  OperationRule GeneratedOperationRule
  deriving (Eq, Ord, Show)

-- | Complete static Operation rule catalog and exact lookup index.
data OperationRuleCatalog =
  OperationRuleCatalog !(NonEmpty OperationRule) !(Map Text OperationRule)

-- | The complete compiled Operation bootstrap-rule catalog.
--
-- Construction is constant for one package build. Canonical enumeration is
-- @O(R)@ and exact lookup is @O(log R)@ for @R@ compiled rule identities.
operationRuleCatalog :: OperationRuleCatalog
operationRuleCatalog = OperationRuleCatalog entries byIdentity
  where
    entries = OperationRule <$> generatedOperationRules
    byIdentity =
      Map.fromList
        [ (operationRuleIdText (operationRuleIdentity rule), rule)
        | rule <- NonEmpty.toList entries
        ]

-- | Project the exact Operation contract identity.
operationRuleCatalogContractIdentity :: OperationRuleCatalog -> Text
operationRuleCatalogContractIdentity _ = operationContractIdentity

-- | Project the exact Operation contract version.
operationRuleCatalogContractVersion :: OperationRuleCatalog -> Text
operationRuleCatalogContractVersion _ = operationContractVersion

-- | Project the SHA-256 digest of the compiled Operation companion.
operationRuleCatalogContractDigest :: OperationRuleCatalog -> Text
operationRuleCatalogContractDigest _ = operationContractSha256

-- | Enumerate every Operation rule in canonical identity order.
operationRuleCatalogEntries :: OperationRuleCatalog -> NonEmpty OperationRule
operationRuleCatalogEntries (OperationRuleCatalog entries _) = entries

-- | Return the exact number of Operation rules in @O(1)@ time.
operationRuleCatalogSize :: OperationRuleCatalog -> Int
operationRuleCatalogSize (OperationRuleCatalog _ byIdentity) =
  Map.size byIdentity

-- | Project one exact Operation rule identity.
operationRuleIdentity :: OperationRule -> OperationRuleId
operationRuleIdentity (OperationRule rule) =
  OperationRuleId (generatedOperationRuleId rule)

-- | Project the sole normative authority for this rule.
operationRuleAuthority :: OperationRule -> OperationRuleAuthority
operationRuleAuthority _ = OperationAuthority

-- | Project the closed processing stage for this rule.
operationRuleStage :: OperationRule -> OperationRuleStage
operationRuleStage (OperationRule rule) =
  case generatedOperationRuleStage rule of
    GeneratedPreparationStage -> PreparationStage

-- | Project the normative expectation owned with the compiled rule.
operationRuleExpectation :: OperationRule -> Text
operationRuleExpectation (OperationRule rule) =
  generatedOperationRuleExpectation rule

-- | Project the human-facing meaning without selecting evaluator behavior.
operationRuleMeaning :: OperationRule -> Text
operationRuleMeaning (OperationRule rule) = generatedOperationRuleMeaning rule

-- | Project the human-facing corrective action.
operationRuleAction :: OperationRule -> Text
operationRuleAction (OperationRule rule) = generatedOperationRuleAction rule

-- | Project the exact identity text.
operationRuleIdText :: OperationRuleId -> Text
operationRuleIdText (OperationRuleId identifier) = identifier

-- | Render the closed Operation authority.
operationRuleAuthorityText :: OperationRuleAuthority -> Text
operationRuleAuthorityText OperationAuthority = "Operation"

-- | Eliminate the closed Operation authority without exposing its constructor.
foldOperationRuleAuthority :: result -> OperationRuleAuthority -> result
foldOperationRuleAuthority operation OperationAuthority = operation

-- | Render the closed Operation processing stage.
operationRuleStageText :: OperationRuleStage -> Text
operationRuleStageText PreparationStage = "preparation"

-- | Eliminate the closed Operation stage without exposing its constructor.
foldOperationRuleStage :: result -> OperationRuleStage -> result
foldOperationRuleStage preparation PreparationStage = preparation

-- | Enumerate the complete partition for the closed preparation stage.
operationRulesForStage ::
     OperationRuleCatalog -> OperationRuleStage -> NonEmpty OperationRule
operationRulesForStage (OperationRuleCatalog entries _) PreparationStage =
  entries

-- | Look up one exact rule identity without normalization or fallback.
--
-- Lookup is discovery only and performs no execution dispatch.
lookupOperationRule :: OperationRuleCatalog -> Text -> Maybe OperationRule
lookupOperationRule (OperationRuleCatalog _ byIdentity) identifier =
  Map.lookup identifier byIdentity
