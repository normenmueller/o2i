-- | Private representation of evidence-readiness requests.
module O2I.Operation.Readiness.Request.Internal
  ( ReadinessRequest(..)
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | One exact selected-View readiness request.
data ReadinessRequest =
  ReadinessRequest
    !InputSource
    !ViewSelector
    !(Maybe AdapterId)
    !InputSource
    ![InputSource]
  deriving (Show)
