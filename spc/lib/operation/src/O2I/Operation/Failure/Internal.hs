-- | Private representation of common Operation failure boundaries.
module O2I.Operation.Failure.Internal
  ( CommandFailure(..)
  , PreparationFailure(..)
  , CommonFailure(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.ArchiMate.Profile.Notation (MarkerCandidate)
import O2I.Operation.Acquisition (AcquisitionFailure)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterSelectionError
  )
import O2I.Operation.Profile (ProfileCompatibility, ProfileResolution)
import O2I.Operation.View (ViewSelectionFailure)

-- | Closed process-level command failure owned by Operation.
data CommandFailure =
  CommandInputAcquisitionFailure !AcquisitionFailure

-- | Closed failure of one authority-owned preparation stage.
data PreparationFailure
  = AdapterSelectionPreparationFailure !AdapterSelectionError
  | AdapterDecodePreparationFailure
      !AdapterDescriptor
      !(NonEmpty AdapterDiagnostic)
  | ProfileMarkerPreparationFailure ![MarkerCandidate]
  | ProfileResolutionPreparationFailure !ProfileResolution
  | ProfileCompatibilityPreparationFailure !ProfileCompatibility
  | ViewSelectionPreparationFailure !ViewSelectionFailure

-- | Common process boundary without conflating command and model rejection.
data CommonFailure
  = CommonCommandFailure !CommandFailure
  | CommonPreparationFailure !PreparationFailure
