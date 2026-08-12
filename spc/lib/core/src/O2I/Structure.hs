-- | Structural validation of one selected O2I View.
--
-- Structure qualifies profile-projected carriers, validates their exact
-- relation and contextualization shape, and checks every admitted structured
-- proposition family. It exposes no graph query surface.
module O2I.Structure
  ( CarrierProjection
  , carrierProjection
  , RelationProjection
  , relationProjection
  , ContextualizationProjection
  , contextualizationProjection
  , StructuredPropositionProjection
  , structuredPropositionProjection
  , StructuredIncidenceProjection
  , structuredIncidenceProjection
  , StructureProjection
  , structureProjection
  , StructureProjectionKind(..)
  , StructureEndpointRole(..)
  , StructureInputDefect(..)
  , StructureDefect
  , structureDefectRule
  , structureDefectSubject
  , structureDefectRelatedOccurrences
  , StructureAssessment(..)
  , StructuredIncidenceObservation
  , structuredIncidenceOccurrence
  , structuredIncidenceRole
  , structuredIncidenceEndpoint
  , StructuredPropositionObservation
  , structuredPropositionOccurrence
  , structuredPropositionModelIdentity
  , structuredPropositionFamily
  , structuredPropositionCompleteness
  , structuredPropositionCommitment
  , structuredPropositionIncidences
  , WellFormedGraph
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  , wellFormedStructuredPropositions
  , assessStructure
  ) where

import O2I.Core.Contract
  ( CoreCarrierCategory
  , CoreO2IType
  , CoreParticipantCompleteness
  , CoreRelationToken
  , CoreRuleId
  , CoreStructuredPropositionFamilyId
  , CoreStructuredPropositionRoleId
  )
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment
  , ContextualizationObservation
  , RelationObservation
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Structure.Index (assessStructure)
import O2I.Structure.Internal

-- | Project one carrier into the notation-independent Structure boundary.
carrierProjection ::
     OccurrenceIdentity
  -> CoreCarrierCategory
  -> CoreO2IType
  -> Commitment
  -> CarrierProjection
carrierProjection = CarrierProjection

-- | Project one binary semantic relation.
relationProjection ::
     OccurrenceIdentity
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> Commitment
  -> RelationProjection
relationProjection = RelationProjection

-- | Project one Context-to-member contextualization.
contextualizationProjection ::
     OccurrenceIdentity
  -> OccurrenceIdentity
  -> OccurrenceIdentity
  -> Commitment
  -> ContextualizationProjection
contextualizationProjection = ContextualizationProjection

-- | Project one structured proposition.
structuredPropositionProjection ::
     OccurrenceIdentity
  -> CoreStructuredPropositionFamilyId
  -> CoreParticipantCompleteness
  -> Commitment
  -> StructuredPropositionProjection
structuredPropositionProjection = StructuredPropositionProjection

-- | Project one role-labelled structured-proposition incidence.
structuredIncidenceProjection ::
     OccurrenceIdentity
  -> OccurrenceIdentity
  -> CoreStructuredPropositionRoleId
  -> OccurrenceIdentity
  -> StructuredIncidenceProjection
structuredIncidenceProjection = StructuredIncidenceProjection

-- | Collect the complete selected-View projection.
structureProjection ::
     [CarrierProjection]
  -> [ContextualizationProjection]
  -> [RelationProjection]
  -> [StructuredPropositionProjection]
  -> [StructuredIncidenceProjection]
  -> StructureProjection
structureProjection = StructureProjection

-- | Project the exact Core rule violated by a structural defect.
structureDefectRule :: StructureDefect -> CoreRuleId
structureDefectRule (StructureDefect rule _ _) = structureRuleId rule

-- | Project the primary occurrence addressed by a structural defect.
structureDefectSubject :: StructureDefect -> OccurrenceIdentity
structureDefectSubject (StructureDefect _ subject _) = subject

-- | Project canonically ordered related occurrences.
structureDefectRelatedOccurrences :: StructureDefect -> [OccurrenceIdentity]
structureDefectRelatedOccurrences (StructureDefect _ _ related) = related

-- | Project the notation segment carrying an incidence.
structuredIncidenceOccurrence ::
     StructuredIncidenceObservation scope -> OccurrenceIdentity
structuredIncidenceOccurrence (StructuredIncidenceObservation occurrence _ _) =
  occurrence

-- | Project the closed family role of an incidence.
structuredIncidenceRole ::
     StructuredIncidenceObservation scope -> CoreStructuredPropositionRoleId
structuredIncidenceRole (StructuredIncidenceObservation _ role _) = role

-- | Project the endpoint occurrence of an incidence.
structuredIncidenceEndpoint ::
     StructuredIncidenceObservation scope -> OccurrenceIdentity
structuredIncidenceEndpoint (StructuredIncidenceObservation _ _ endpoint) =
  endpoint

-- | Project the canonical identity of a structured proposition.
structuredPropositionOccurrence ::
     StructuredPropositionObservation scope -> OccurrenceIdentity
structuredPropositionOccurrence (StructuredPropositionObservation occurrence _ _ _ _ _) =
  occurrence

-- | Project its exact model identity.
structuredPropositionModelIdentity ::
     StructuredPropositionObservation scope -> ModelIdentity
structuredPropositionModelIdentity (StructuredPropositionObservation _ identifier _ _ _ _) =
  identifier

-- | Project its closed family.
structuredPropositionFamily ::
     StructuredPropositionObservation scope -> CoreStructuredPropositionFamilyId
structuredPropositionFamily (StructuredPropositionObservation _ _ family _ _ _) =
  family

-- | Project its explicit participant completeness.
structuredPropositionCompleteness ::
     StructuredPropositionObservation scope -> CoreParticipantCompleteness
structuredPropositionCompleteness (StructuredPropositionObservation _ _ _ completeness _ _) =
  completeness

-- | Project its explicit commitment.
structuredPropositionCommitment ::
     StructuredPropositionObservation scope -> Commitment
structuredPropositionCommitment (StructuredPropositionObservation _ _ _ _ commitment _) =
  commitment

-- | Enumerate its incidences in canonical segment order.
structuredPropositionIncidences ::
     StructuredPropositionObservation scope
  -> [StructuredIncidenceObservation scope]
structuredPropositionIncidences (StructuredPropositionObservation _ _ _ _ _ incidences) =
  incidences

-- | Enumerate qualified carriers in canonical occurrence order.
wellFormedCarriers :: WellFormedGraph scope -> [CarrierObservation scope]
wellFormedCarriers = storedWellFormedCarriers

-- | Enumerate contextualizations in canonical occurrence order.
wellFormedContextualizations ::
     WellFormedGraph scope -> [ContextualizationObservation scope]
wellFormedContextualizations = storedWellFormedContextualizations

-- | Enumerate binary semantic relations in canonical occurrence order.
wellFormedRelations :: WellFormedGraph scope -> [RelationObservation scope]
wellFormedRelations = storedWellFormedRelations

-- | Enumerate structured propositions in canonical occurrence order.
wellFormedStructuredPropositions ::
     WellFormedGraph scope -> [StructuredPropositionObservation scope]
wellFormedStructuredPropositions = storedWellFormedStructuredPropositions
