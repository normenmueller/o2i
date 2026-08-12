module CoreGraphObservationOpaqueConstructors where

import O2I.Core.Graph.Observation

rebuildCarrier :: CarrierObservation scope -> CarrierObservation scope
rebuildCarrier carrier =
  CarrierObservation
    (carrierOccurrenceIdentity carrier)
    (carrierModelIdentity carrier)
    (carrierQualifiedEndpoint carrier)
    (carrierCommitment carrier)
