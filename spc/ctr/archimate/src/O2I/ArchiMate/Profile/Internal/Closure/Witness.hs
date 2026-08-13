{-# LANGUAGE RoleAnnotations #-}

-- | Selected-Profile and source-bound wrapper around accepted closure data.
module O2I.ArchiMate.Profile.Internal.Closure.Witness where

import qualified O2I.ArchiMate.Profile.Internal.Closure as Raw
import O2I.ArchiMate.Profile.Internal.Notation.Witness
import O2I.ArchiMate.Profile.Internal.Resolution

-- | Exact positive selected-View universe before Notation assessment.
newtype ProfileAssessmentUniverse profile document =
  ProfileAssessmentUniverse Raw.ClosedView

type role ProfileAssessmentUniverse nominal nominal

deriveProfileAssessmentUniverseValue ::
     SelectedArchiMateProfile profile
  -> CanonicalDocument document
  -> CanonicalView document
  -> ProfileAssessmentUniverse profile document
deriveProfileAssessmentUniverseValue _ _ view =
  ProfileAssessmentUniverse (Raw.closeView (canonicalViewValue view))

profileAssessmentUniverseValue ::
     ProfileAssessmentUniverse profile document -> Raw.ClosedView
profileAssessmentUniverseValue (ProfileAssessmentUniverse universe) = universe
