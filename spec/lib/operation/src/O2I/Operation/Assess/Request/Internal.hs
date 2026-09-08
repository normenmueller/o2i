-- | Private representation of selected-View assessment requests.
module O2I.Operation.Assess.Request.Internal
  ( AssessRequest(..)
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | One exact selected-View assessment request.
data AssessRequest =
  AssessRequest
    !InputSource
    !ViewSelector
    !(Maybe AdapterId)
    !InputSource
    ![InputSource]
  deriving (Show)
