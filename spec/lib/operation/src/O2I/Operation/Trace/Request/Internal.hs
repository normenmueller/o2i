-- | Private representation of Trace requests.
module O2I.Operation.Trace.Request.Internal
  ( TraceRequest(..)
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | One exact selected-View Trace request. Trace admits no supplemental input.
data TraceRequest =
  TraceRequest !InputSource !ViewSelector !(Maybe AdapterId)
  deriving (Show)
