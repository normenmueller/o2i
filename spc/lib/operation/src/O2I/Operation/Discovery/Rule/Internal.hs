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

data RuleContractBinding =
  RuleContractBinding !Text !Text !(Maybe Text)
  deriving (Eq, Ord, Show)

data RuleAuthority
  = OperationAuthority !RuleContractBinding
  | CoreAuthority !RuleContractBinding
  | ProfileAuthority !Text !RuleContractBinding
  | AdapterAuthority !AdapterId !RuleContractBinding
  deriving (Eq, Ord, Show)

data DiscoveredRule =
  DiscoveredRule !RuleAuthority !Text !Text !Text !Text !Text
  deriving (Eq, Ord, Show)

data RuleDiscoveryDefect
  = ProfileRuleCatalogMismatch !Text !Text !Text !Text
  | DuplicateRuleIdentity !Text !Text
  deriving (Eq, Ord, Show)

data RuleDiscoveryCompilation
  = RuleDiscoveryCompilationFailed !(NonEmpty RuleDiscoveryDefect)
  | RuleDiscoveryCompiled !RuleDiscovery

data RuleDiscovery =
  RuleDiscovery
    !RuleAuthority
    !(NonEmpty DiscoveredRule)
    !(Map Text DiscoveredRule)

data RuleExplanationRequestDefect =
  EmptyRuleExplanationRequest
  deriving (Eq, Ord, Show)

data RuleExplanation
  = RuleExplanationFound !RuleAuthority !Text !DiscoveredRule
  | RuleExplanationNotFound !RuleAuthority !Text
