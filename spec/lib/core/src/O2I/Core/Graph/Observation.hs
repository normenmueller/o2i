-- | Canonical, notation-independent observations of one selected O2I View.
--
-- These values record facts established by Structure. They do not implement
-- structural or semantic validation and expose no graph traversal surface.
module O2I.Core.Graph.Observation
  ( Commitment(..)
  , CarrierObservation
  , carrierOccurrenceIdentity
  , carrierModelIdentity
  , carrierQualifiedEndpoint
  , carrierCommitment
  , RelationObservation
  , relationOccurrenceIdentity
  , relationSourceOccurrence
  , relationToken
  , relationTargetOccurrence
  , relationCommitment
  , ContextualizationObservation
  , contextualizationOccurrenceIdentity
  , contextualizationOwnerOccurrence
  , contextualizationMemberOccurrence
  , contextualizationCommitment
  ) where

import O2I.Core.Graph.Commitment
import O2I.Core.Graph.Observation.Internal
