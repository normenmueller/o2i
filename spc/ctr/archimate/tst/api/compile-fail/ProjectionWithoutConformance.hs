module ProjectionWithoutConformance where

import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Projection as Projection

projectRaw ::
     Closure.ProfileAssessmentUniverse profile document
  -> Projection.ProfileProjectionAssessment
projectRaw = Projection.assessSelectedView
