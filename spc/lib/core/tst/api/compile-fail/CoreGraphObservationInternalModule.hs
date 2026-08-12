module CoreGraphObservationInternalModule where

import O2I.Core.Graph.Observation.Internal

internalConstructor ::
     ScopedGraphOccurrence scope -> ScopedGraphOccurrence scope
internalConstructor = id
