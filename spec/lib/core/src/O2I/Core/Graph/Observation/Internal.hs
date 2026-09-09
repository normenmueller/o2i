{-# LANGUAGE RoleAnnotations #-}

-- | Private construction of scope-bound canonical graph observations.
module O2I.Core.Graph.Observation.Internal
  ( ScopedGraphOccurrence(..)
  , scopedGraphOccurrenceIdentity
  , CarrierObservation(..)
  , carrierOccurrenceIdentity
  , carrierModelIdentity
  , carrierQualifiedEndpoint
  , carrierCommitment
  , RelationObservation(..)
  , relationOccurrenceIdentity
  , relationSourceOccurrence
  , relationToken
  , relationTargetOccurrence
  , relationCommitment
  , ContextualizationObservation(..)
  , contextualizationOccurrenceIdentity
  , contextualizationOwnerOccurrence
  , contextualizationMemberOccurrence
  , contextualizationCommitment
  ) where

import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRelationToken)
import O2I.Core.Graph.Commitment (Commitment)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)

type role ScopedGraphOccurrence nominal

-- | One occurrence proven to belong to exactly one selected-View scope.
newtype ScopedGraphOccurrence scope =
  ScopedGraphOccurrence OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Project the canonical occurrence identity without weakening its scope.
scopedGraphOccurrenceIdentity ::
     ScopedGraphOccurrence scope -> OccurrenceIdentity
scopedGraphOccurrenceIdentity (ScopedGraphOccurrence identifier) = identifier

type role CarrierObservation nominal

-- | One qualified carrier observation established by Structure.
data CarrierObservation scope =
  CarrierObservation
    !(ScopedGraphOccurrence scope)
    !ModelIdentity
    !CoreQualifiedEndpointId
    !Commitment
  deriving (Eq, Ord, Show)

-- | Project the carrier's canonical occurrence identity.
carrierOccurrenceIdentity :: CarrierObservation scope -> OccurrenceIdentity
carrierOccurrenceIdentity (CarrierObservation occurrence _ _ _) =
  scopedGraphOccurrenceIdentity occurrence

-- | Project the carrier's exact, unnormalized model identity.
carrierModelIdentity :: CarrierObservation scope -> ModelIdentity
carrierModelIdentity (CarrierObservation _ identifier _ _) = identifier

-- | Project the qualified endpoint established for the carrier.
carrierQualifiedEndpoint :: CarrierObservation scope -> CoreQualifiedEndpointId
carrierQualifiedEndpoint (CarrierObservation _ _ endpoint _) = endpoint

-- | Project the carrier proposition's explicit commitment.
carrierCommitment :: CarrierObservation scope -> Commitment
carrierCommitment (CarrierObservation _ _ _ commitment) = commitment

type role RelationObservation nominal

-- | One structurally valid binary semantic-relation observation.
data RelationObservation scope =
  RelationObservation
    !(ScopedGraphOccurrence scope)
    !(ScopedGraphOccurrence scope)
    !CoreRelationToken
    !(ScopedGraphOccurrence scope)
    !Commitment
  deriving (Eq, Ord, Show)

-- | Project the relation proposition's canonical occurrence identity.
relationOccurrenceIdentity :: RelationObservation scope -> OccurrenceIdentity
relationOccurrenceIdentity (RelationObservation occurrence _ _ _ _) =
  scopedGraphOccurrenceIdentity occurrence

-- | Project the canonical source-carrier occurrence identity.
relationSourceOccurrence :: RelationObservation scope -> OccurrenceIdentity
relationSourceOccurrence (RelationObservation _ source _ _ _) =
  scopedGraphOccurrenceIdentity source

-- | Project the closed semantic relation token.
relationToken :: RelationObservation scope -> CoreRelationToken
relationToken (RelationObservation _ _ token _ _) = token

-- | Project the canonical target-carrier occurrence identity.
relationTargetOccurrence :: RelationObservation scope -> OccurrenceIdentity
relationTargetOccurrence (RelationObservation _ _ _ target _) =
  scopedGraphOccurrenceIdentity target

-- | Project the relation proposition's explicit commitment.
relationCommitment :: RelationObservation scope -> Commitment
relationCommitment (RelationObservation _ _ _ _ commitment) = commitment

type role ContextualizationObservation nominal

-- | One structurally valid Context-to-member contextualization observation.
data ContextualizationObservation scope =
  ContextualizationObservation
    !(ScopedGraphOccurrence scope)
    !(ScopedGraphOccurrence scope)
    !(ScopedGraphOccurrence scope)
    !Commitment
  deriving (Eq, Ord, Show)

-- | Project the contextualization proposition's occurrence identity.
contextualizationOccurrenceIdentity ::
     ContextualizationObservation scope -> OccurrenceIdentity
contextualizationOccurrenceIdentity (ContextualizationObservation occurrence _ _ _) =
  scopedGraphOccurrenceIdentity occurrence

-- | Project the canonical owning-Context occurrence identity.
contextualizationOwnerOccurrence ::
     ContextualizationObservation scope -> OccurrenceIdentity
contextualizationOwnerOccurrence (ContextualizationObservation _ owner _ _) =
  scopedGraphOccurrenceIdentity owner

-- | Project the canonical contextualized-member occurrence identity.
contextualizationMemberOccurrence ::
     ContextualizationObservation scope -> OccurrenceIdentity
contextualizationMemberOccurrence (ContextualizationObservation _ _ member _) =
  scopedGraphOccurrenceIdentity member

-- | Project the contextualization proposition's explicit commitment.
contextualizationCommitment :: ContextualizationObservation scope -> Commitment
contextualizationCommitment (ContextualizationObservation _ _ _ commitment) =
  commitment
