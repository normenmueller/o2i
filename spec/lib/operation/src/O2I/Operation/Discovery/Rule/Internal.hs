-- | Internal closed data for authority-local Rule discovery.
module O2I.Operation.Discovery.Rule.Internal
  ( RuleContractBinding(..)
  , RuleAuthority(..)
  , DiscoveredRule(..)
  , RuleDiscoveryDefect(..)
  , RuleDiscoveryCompilation(..)
  , RuleDiscovery(..)
  , RuleExplanationRequestDefect(..)
  , RuleExplanation(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Text (Text)
import O2I.Operation.Adapter (AdapterId)

-- | Digest and source references binding rules to one compiled contract.
data RuleContractBinding =
  RuleContractBinding !Text !Text !(Maybe Text)
  deriving (Eq, Ord, Show)

-- | Closed owner of one discoverable compiled rule catalog.
data RuleAuthority
  = OperationAuthority !RuleContractBinding
  | CoreAuthority !RuleContractBinding
  | ProfileAuthority !Text !RuleContractBinding
  | AdapterAuthority !AdapterId !RuleContractBinding
  deriving (Eq, Ord, Show)

-- | One authority-bound rule projected for discovery and explanation.
data DiscoveredRule =
  DiscoveredRule !RuleAuthority !Text !Text !Text !Text !Text
  deriving (Eq, Ord, Show)

-- | Contract mismatch or duplicate identity found during rule discovery.
data RuleDiscoveryDefect
  = ProfileRuleCatalogMismatch !Text !Text !Text !Text
  | DuplicateRuleIdentity !Text !Text
  deriving (Eq, Ord, Show)

-- | Failed validation or compiled rule-discovery inventory.
data RuleDiscoveryCompilation
  = RuleDiscoveryCompilationFailed !(NonEmpty RuleDiscoveryDefect)
  | RuleDiscoveryCompiled !RuleDiscovery

-- | Non-empty authority-local rule inventory with indexed lookup.
data RuleDiscovery =
  RuleDiscovery
    !RuleAuthority
    !(NonEmpty DiscoveredRule)
    !(Map Text DiscoveredRule)

-- | Invalid empty identity supplied to rule explanation.
data RuleExplanationRequestDefect =
  EmptyRuleExplanationRequest
  deriving (Eq, Ord, Show)

-- | Exact lookup result retaining the requested authority and identity.
data RuleExplanation
  = RuleExplanationFound !RuleAuthority !Text !DiscoveredRule
  | RuleExplanationNotFound !RuleAuthority !Text
