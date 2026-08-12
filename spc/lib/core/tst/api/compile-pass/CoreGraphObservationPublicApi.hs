module CoreGraphObservationPublicApi where

import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRelationToken)
import O2I.Core.Graph.Observation
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)

carrierView ::
     CarrierObservation scope
  -> (OccurrenceIdentity, ModelIdentity, CoreQualifiedEndpointId, Commitment)
carrierView carrier =
  ( carrierOccurrenceIdentity carrier
  , carrierModelIdentity carrier
  , carrierQualifiedEndpoint carrier
  , carrierCommitment carrier)

relationView ::
     RelationObservation scope
  -> ( OccurrenceIdentity
     , OccurrenceIdentity
     , CoreRelationToken
     , OccurrenceIdentity
     , Commitment)
relationView relation =
  ( relationOccurrenceIdentity relation
  , relationSourceOccurrence relation
  , relationToken relation
  , relationTargetOccurrence relation
  , relationCommitment relation)

contextualizationView ::
     ContextualizationObservation scope
  -> (OccurrenceIdentity, OccurrenceIdentity, OccurrenceIdentity, Commitment)
contextualizationView contextualization =
  ( contextualizationOccurrenceIdentity contextualization
  , contextualizationOwnerOccurrence contextualization
  , contextualizationMemberOccurrence contextualization
  , contextualizationCommitment contextualization)

commitmentView :: Commitment -> Bool
commitmentView Candidate = False
commitmentView Asserted = True
