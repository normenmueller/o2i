{-# LANGUAGE ExistentialQuantification #-}

-- | Private representation of common Operation failure boundaries.
module O2I.Operation.Failure.Internal
  ( CommandFailure(..)
  , ProfileResolutionFailure(..)
  , ProfileCompatibilityFailure(..)
  , PreparationFailure(..)
  , CommonFailure(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftScalar, DraftValueKind)
import O2I.ArchiMate.Profile.Notation (CanonicalProperty, MarkerCandidate)
import O2I.Operation.Acquisition (AcquisitionFailure)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterSelectionError
  )
import O2I.Operation.Profile (ResolvedProfile)
import O2I.Operation.Rule.Catalog (OperationRule)
import O2I.Operation.View (ViewSelectionFailure)

-- | Closed process-level command failure owned by Operation.
data CommandFailure =
  CommandInputAcquisitionFailure !AcquisitionFailure

-- | Rejected branch of exact Profile resolution.
data ProfileResolutionFailure
  = ProfileReferenceMissingFailure !OperationRule !Text
  | ProfileReferencePropertyMultiplicityFailure
      !OperationRule
      !Text
      ![CanonicalProperty]
  | ProfileReferenceValueMultiplicityFailure
      !OperationRule
      !Text
      !CanonicalProperty
      ![DraftScalar]
  | ProfileReferenceValueKindInvalidFailure
      !OperationRule
      !Text
      !DraftScalar
      !DraftValueKind
  | ProfileReferenceGrammarInvalidFailure !OperationRule !Text !DraftScalar
  | ProfileReferenceUnknownFailure !OperationRule !Text !Text

-- | Rejected branch of exact Profile/Adapter compatibility.
data ProfileCompatibilityFailure
  = ProfileAdapterIdNotAdmittedFailure
      !OperationRule
      !ResolvedProfile
      !AdapterDescriptor
      ![Text]
  | ProfileAdapterNotationMismatchFailure
      !OperationRule
      !ResolvedProfile
      !AdapterDescriptor
      !Text
      !Text

-- | Closed failure of one authority-owned preparation stage.
data PreparationFailure
  = AdapterSelectionPreparationFailure !AdapterSelectionError
  | AdapterDecodePreparationFailure
      !AdapterDescriptor
      !(NonEmpty AdapterDiagnostic)
  | ProfileMarkerPreparationFailure ![MarkerCandidate]
  | ProfileResolutionPreparationFailure !ProfileResolutionFailure
  | ProfileCompatibilityPreparationFailure !ProfileCompatibilityFailure
  | forall document. ViewSelectionPreparationFailure
                       !(ViewSelectionFailure document)

-- | Common process boundary without conflating command and model rejection.
data CommonFailure
  = CommonCommandFailure !CommandFailure
  | CommonPreparationFailure !PreparationFailure
