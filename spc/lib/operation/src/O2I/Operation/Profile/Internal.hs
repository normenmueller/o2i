{-# LANGUAGE OverloadedStrings #-}

-- | Private representation of Profile bootstrap and compatibility outcomes.
module O2I.Operation.Profile.Internal where

import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftScalar, DraftValueKind)
import O2I.ArchiMate.Profile.Notation (CanonicalProperty, MarkerCandidate)
import O2I.ArchiMate.Profile.Resolution (ProfileDescriptor)
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Rule.Catalog (OperationRule)

-- | Descriptor-derived key of one immutable compiled Profile.
data ProfileInventoryKey =
  ProfileInventoryKey !Text !Text
  deriving (Eq, Ord, Show)

-- | Closed internal-contract failure for one static Profile inventory.
data ProfileInventoryDefect
  = EmptyProfileInventory
  | DuplicateProfileInventoryKey !OperationRule !ProfileInventoryKey
  deriving (Eq, Show)

-- | Closed result of validating one static Profile collection.
data ProfileInventoryCompilation
  = ProfileInventoryCompilationFailed !(NonEmpty ProfileInventoryDefect)
  | ProfileInventoryCompiled !ProfileInventory

-- | Canonically ordered static Profile inventory and exact reference index.
data ProfileInventory = ProfileInventory
  { profileInventoryEntriesValue :: !(NonEmpty ProfileDescriptor)
  , profileInventoryByReferenceValue :: !(Map Text ProfileDescriptor)
  }

-- | Marker evidence whose notation-level assessment was accepted once.
newtype ProfileMarkerEvidence =
  ProfileMarkerEvidence [CanonicalProperty]

-- | Total boundary between notation assessment and Profile resolution.
data ProfileMarkerEvidenceOutcome
  = ProfileMarkerEvidenceRejected ![MarkerCandidate]
  | ProfileMarkerEvidenceAccepted !ProfileMarkerEvidence

-- | Exact resolved Profile descriptor.
newtype ResolvedProfile =
  ResolvedProfile ProfileDescriptor

-- | Seven-way Profile resolution with exact Operation rule evidence.
data ProfileResolution
  = ProfileReferenceMissing !OperationRule !Text
  | ProfileReferencePropertyMultiplicity
      !OperationRule
      !Text
      ![CanonicalProperty]
  | ProfileReferenceValueMultiplicity
      !OperationRule
      !Text
      !CanonicalProperty
      ![DraftScalar]
  | ProfileReferenceValueKindInvalid
      !OperationRule
      !Text
      !DraftScalar
      !DraftValueKind
  | ProfileReferenceGrammarInvalid !OperationRule !Text !DraftScalar
  | ProfileReferenceUnknown !OperationRule !Text !Text
  | ProfileResolved !ResolvedProfile

-- | Total adapter compatibility outcome after exact Profile resolution.
data ProfileCompatibility
  = ProfileAdapterIdNotAdmitted
      !OperationRule
      !ResolvedProfile
      !AdapterDescriptor
      ![Text]
  | ProfileAdapterNotationMismatch
      !OperationRule
      !ResolvedProfile
      !AdapterDescriptor
      !Text
      !Text
  | ProfileAdapterCompatible !ResolvedProfile !AdapterDescriptor !Text
