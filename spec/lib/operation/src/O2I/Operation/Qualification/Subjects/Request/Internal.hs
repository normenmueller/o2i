-- | Private representation of qualification-subject discovery requests.
module O2I.Operation.Qualification.Subjects.Request.Internal
  ( QualificationSubjectsRequest(..)
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | One exact selected-View qualification-subject discovery request.
data QualificationSubjectsRequest =
  QualificationSubjectsRequest
    !InputSource
    !ViewSelector
    !(Maybe AdapterId)
    ![InputSource]
  deriving (Show)
