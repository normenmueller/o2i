{-# LANGUAGE ExplicitNamespaces #-}

-- | Package-internal proof boundary for Adapter-owned diagnostics.
module O2I.Operation.Diagnostic.AdapterOwner.Internal
  ( type AdapterRuleWitness
  , foldAdapterRuleWitness
  , type AdapterRuleResolutionFailure
  , foldAdapterRuleResolutionFailure
  , resolveAdapterContractRule
  ) where

import Data.List (find)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterRule
  , AdapterRuleId
  , CompiledAdapterContract
  , adapterContractDescriptor
  , adapterContractRules
  , adapterRuleId
  )

-- | Proof that one exact rule was resolved from one compiled Adapter contract.
-- The representation constructor is lexical to this owner module.
data AdapterRuleWitness =
  AdapterRuleWitness !AdapterDescriptor !AdapterRule
  deriving (Eq, Ord, Show)

-- | Closed failure to resolve a rule within one compiled Adapter contract.
data AdapterRuleResolutionFailure =
  AdapterRuleNotInContract !AdapterDescriptor !AdapterRuleId
  deriving (Eq, Ord, Show)

-- | Consume the descriptor and rule intrinsically paired by one compiled
-- contract lookup.
foldAdapterRuleWitness ::
     (AdapterDescriptor -> AdapterRule -> result)
  -> AdapterRuleWitness
  -> result
foldAdapterRuleWitness consume (AdapterRuleWitness descriptor rule) =
  consume descriptor rule

-- | Consume an unsuccessful exact rule lookup with its owning descriptor and
-- requested identity.
foldAdapterRuleResolutionFailure ::
     (AdapterDescriptor -> AdapterRuleId -> result)
  -> AdapterRuleResolutionFailure
  -> result
foldAdapterRuleResolutionFailure consume failure =
  case failure of
    AdapterRuleNotInContract descriptor identifier ->
      consume descriptor identifier

-- | Resolve one exact rule from the immutable inventory of a compiled Adapter
-- contract. No caller can construct the successful witness directly.
resolveAdapterContractRule ::
     AdapterRuleId
  -> CompiledAdapterContract
  -> Either AdapterRuleResolutionFailure AdapterRuleWitness
resolveAdapterContractRule identifier contract =
  case find ((== identifier) . adapterRuleId) (adapterContractRules contract) of
    Nothing ->
      Left
        (AdapterRuleNotInContract
           (adapterContractDescriptor contract)
           identifier)
    Just rule ->
      Right (AdapterRuleWitness (adapterContractDescriptor contract) rule)
