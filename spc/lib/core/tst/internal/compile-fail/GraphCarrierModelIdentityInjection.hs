module GraphCarrierModelIdentityInjection where

import O2I.Core.Contract (CoreQualifiedEndpointId)
import O2I.Core.Graph.Commitment (Commitment(Candidate))
import O2I.Core.Graph.Observation.Index
  ( GraphObservationInput
  , GraphObservationInput(CarrierObservationInput)
  )
import O2I.Core.Identity (ModelOccurrence)

invalidCarrierInput ::
     ModelOccurrence -> CoreQualifiedEndpointId -> GraphObservationInput
invalidCarrierInput occurrence endpoint =
  CarrierObservationInput occurrence endpoint Candidate
