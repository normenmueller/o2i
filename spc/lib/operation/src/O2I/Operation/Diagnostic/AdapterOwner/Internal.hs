{-# LANGUAGE ExplicitNamespaces #-}

-- | Package-internal proof boundary for Adapter-owned diagnostics.
module O2I.Operation.Diagnostic.AdapterOwner.Internal
  ( type AdapterRuleWitness
  , foldAdapterRuleWitness
  , type AdapterRuleResolutionFailure
  , foldAdapterRuleResolutionFailure
  , resolveAdapterContractRule
  , type AdapterNotationDiagnostic
  , foldAdapterNotationDiagnostic
  , type AdapterNotationResolutionFailure
  , foldAdapterNotationResolutionFailure
  , verifyAdapterNotationAuthority
  , resolveAdapterNotationDiagnostic
  ) where

import Data.List (find)
import qualified Data.List.NonEmpty as NonEmpty
import O2I.ArchiMate.Profile.Notation
  ( ArchiMateNotationIssue
  , ArchiMateNotationIssueKind
  , allArchiMateNotationIssueKinds
  , archiMateNotationIssueKind
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterRule
  , AdapterRuleId
  , CompiledAdapterContract
  , adapterContractDescriptor
  , adapterContractRules
  , adapterRuleId
  , lookupArchiMateNotationRule
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

-- | One exact Notation issue intrinsically paired with the Adapter rule
-- resolved for its closed Profile-owned kind.
data AdapterNotationDiagnostic =
  AdapterNotationDiagnostic
    !AdapterDescriptor
    !AdapterRule
    !ArchiMateNotationIssue
  deriving (Eq, Ord, Show)

-- | Closed internal failure of the compiled Adapter completeness invariant.
data AdapterNotationResolutionFailure
  = AdapterNotationAuthorityMismatch !AdapterDescriptor !AdapterDescriptor
  | AdapterNotationRuleMissing !AdapterDescriptor !ArchiMateNotationIssueKind
  deriving (Eq, Ord, Show)

-- | Consume the Adapter descriptor, exact resolved rule, and lossless
-- Profile-owned Notation issue without permitting their reassociation.
foldAdapterNotationDiagnostic ::
     (AdapterDescriptor -> AdapterRule -> ArchiMateNotationIssue -> result)
  -> AdapterNotationDiagnostic
  -> result
foldAdapterNotationDiagnostic consume diagnostic =
  case diagnostic of
    AdapterNotationDiagnostic descriptor rule issue ->
      consume descriptor rule issue

-- | Consume the exact Adapter contract and missing closed Notation kind.
foldAdapterNotationResolutionFailure ::
     (AdapterDescriptor -> AdapterDescriptor -> result)
  -> (AdapterDescriptor -> ArchiMateNotationIssueKind -> result)
  -> AdapterNotationResolutionFailure
  -> result
foldAdapterNotationResolutionFailure mismatch missing failure =
  case failure of
    AdapterNotationAuthorityMismatch authorityDescriptor contractDescriptor ->
      mismatch authorityDescriptor contractDescriptor
    AdapterNotationRuleMissing descriptor kind -> missing descriptor kind

-- | Verify the exact descriptor and closed kind-to-rule association minted
-- into the prepared authority before any issue is retained.
verifyAdapterNotationAuthority ::
     CompiledAdapterContract
  -> CompiledAdapterContract
  -> Either AdapterNotationResolutionFailure ()
verifyAdapterNotationAuthority authorityContract contract =
  if authorityDescriptor == contractDescriptor
       && authorityBindings == contractBindings
    then Right ()
    else Left
           (AdapterNotationAuthorityMismatch
              authorityDescriptor
              contractDescriptor)
  where
    authorityDescriptor = adapterContractDescriptor authorityContract
    contractDescriptor = adapterContractDescriptor contract
    authorityBindings = notationBindings authorityContract
    contractBindings = notationBindings contract
    notationBindings candidate =
      [ (kind, lookupArchiMateNotationRule kind candidate)
      | kind <- NonEmpty.toList allArchiMateNotationIssueKinds
      ]

-- | Bind one real Profile-owned issue only to the statically compiled Adapter
-- rule selected by its closed kind.
resolveAdapterNotationDiagnostic ::
     CompiledAdapterContract
  -> ArchiMateNotationIssue
  -> Either AdapterNotationResolutionFailure AdapterNotationDiagnostic
resolveAdapterNotationDiagnostic contract issue =
  case lookupArchiMateNotationRule kind contract of
    Nothing ->
      Left
        (AdapterNotationRuleMissing (adapterContractDescriptor contract) kind)
    Just rule ->
      Right
        (AdapterNotationDiagnostic
           (adapterContractDescriptor contract)
           rule
           issue)
  where
    kind = archiMateNotationIssueKind issue
