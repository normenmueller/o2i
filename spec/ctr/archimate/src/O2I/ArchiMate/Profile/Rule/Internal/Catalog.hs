-- | Private assembly of the static selected-Profile rule catalog.
module O2I.ArchiMate.Profile.Rule.Internal.Catalog
  ( ProfileRuleCatalog(..)
  , selectedProfileRuleCatalog
  , selectedProfileRuleCatalogProfileReference
  , selectedProfileRuleCatalogContractDigest
  , selectedProfileRuleCatalogEntries
  , selectedProfileRuleCatalogSize
  , selectedProfileRulesForStage
  , lookupSelectedProfileRule
  , foldSelectedProfileRuleCatalog
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Ord (comparing)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Resolution
  ( compiledDescriptor
  , descriptorReference
  , profileDescriptorContractDigestValue
  )
import O2I.ArchiMate.Profile.Rule.Internal.Definition
  ( RuleDefinition(..)
  , compiledProfileRuleDefinitions
  )
import O2I.ArchiMate.Profile.Rule.Internal.Explanation

-- | Static complete selected-Profile rule catalog and its exact lookup index.
data ProfileRuleCatalog =
  ProfileRuleCatalog
    !Text
    !Text
    !(NonEmpty ProfileRuleExplanation)
    !(Map Text ProfileRuleExplanation)

-- | Complete catalog bound to the one selected compiled Profile descriptor.
--
-- Construction is constant for one package build. Canonical enumeration is
-- @O(R)@ and exact lookup is @O(log R)@ for @R@ selected-Profile rules.
selectedProfileRuleCatalog :: ProfileRuleCatalog
selectedProfileRuleCatalog =
  ProfileRuleCatalog reference digest entries byIdentity
  where
    reference = descriptorReference compiledDescriptor
    digest = profileDescriptorContractDigestValue compiledDescriptor
    entries =
      NonEmpty.sortBy
        (comparing (profileRuleIdText . profileRuleId))
        (fmap (materialize reference digest) compiledProfileRuleDefinitions)
    byIdentity =
      Map.fromList
        [ (profileRuleIdText (profileRuleId explanation), explanation)
        | explanation <- NonEmpty.toList entries
        ]

materialize :: Text -> Text -> RuleDefinition -> ProfileRuleExplanation
materialize reference digest (RuleDefinition identifier expectation meaning action) =
  ProfileRuleExplanation
    (ProfileRuleId identifier)
    selectedProfileRuleAuthority
    reference
    digest
    selectedProfileRuleStage
    expectation
    meaning
    action

-- | Exact compiled Profile reference shared by every catalog entry.
selectedProfileRuleCatalogProfileReference :: ProfileRuleCatalog -> Text
selectedProfileRuleCatalogProfileReference (ProfileRuleCatalog reference _ _ _) =
  reference

-- | Exact compiled Profile contract digest shared by every catalog entry.
selectedProfileRuleCatalogContractDigest :: ProfileRuleCatalog -> Text
selectedProfileRuleCatalogContractDigest (ProfileRuleCatalog _ digest _ _) =
  digest

-- | Enumerate every selected-Profile rule in canonical rule-identity order.
selectedProfileRuleCatalogEntries ::
     ProfileRuleCatalog -> NonEmpty ProfileRuleExplanation
selectedProfileRuleCatalogEntries (ProfileRuleCatalog _ _ entries _) = entries

-- | Return the exact number of selected-Profile rules in @O(1)@ time.
selectedProfileRuleCatalogSize :: ProfileRuleCatalog -> Int
selectedProfileRuleCatalogSize (ProfileRuleCatalog _ _ _ byIdentity) =
  Map.size byIdentity

-- | Enumerate the complete canonical partition for the closed Profile stage.
selectedProfileRulesForStage ::
     ProfileRuleCatalog -> ProfileRuleStage -> NonEmpty ProfileRuleExplanation
selectedProfileRulesForStage (ProfileRuleCatalog _ _ entries _) ProfileStage =
  entries

-- | Look up one exact selected-Profile rule identity without normalization.
--
-- Lookup is discovery only and performs no Profile semantic dispatch.
lookupSelectedProfileRule ::
     ProfileRuleCatalog -> Text -> Maybe ProfileRuleExplanation
lookupSelectedProfileRule (ProfileRuleCatalog _ _ _ byIdentity) identifier =
  Map.lookup identifier byIdentity

-- | Consume the complete immutable catalog without exposing its constructor.
foldSelectedProfileRuleCatalog ::
     (Text -> Text -> NonEmpty ProfileRuleExplanation -> result)
  -> ProfileRuleCatalog
  -> result
foldSelectedProfileRuleCatalog consume catalog =
  consume
    (selectedProfileRuleCatalogProfileReference catalog)
    (selectedProfileRuleCatalogContractDigest catalog)
    (selectedProfileRuleCatalogEntries catalog)
