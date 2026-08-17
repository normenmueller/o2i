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
  , StructureZeroOrMultipleOccurrences
  , foldStructureZeroOrMultipleOccurrences
  , QualifiedEndpointCatalogMembershipEvidence
  , qualifiedEndpointCatalogMembershipSubject
  , ContextualizationSourceCategoryEvidence
  , contextualizationSourceCategorySegment
  , contextualizationSourceCategoryOwner
  , ContextualizationTargetCategoryEvidence
  , contextualizationTargetCategorySegment
  , contextualizationTargetCategoryMember
  , ContextualizationTargetOwnerCardinalityEvidence
  , contextualizationTargetOwnerCardinalityMember
  , contextualizationTargetOwnerCardinalityOwners
  , SemanticRelationCompatibilityEvidence
  , semanticRelationCompatibilityRelation
  , semanticRelationCompatibilitySource
  , semanticRelationCompatibilityTarget
  , StructuredPropositionIdentityEvidence
  , structuredPropositionIdentitySubject
  , structuredPropositionIdentityFirstOccurrence
  , structuredPropositionIdentitySecondOccurrence
  , structuredPropositionIdentityRemainingOccurrences
  , CollectiveParticipantTypeEvidence
  , collectiveParticipantTypeClaim
  , collectiveParticipantTypeSegment
  , collectiveParticipantTypeEndpoint
  , CollectiveParticipantCardinalityEvidence
  , collectiveParticipantCardinalityClaim
  , collectiveParticipantCardinalitySoleEndpoint
  , CollectiveParticipantUniquenessEvidence
  , collectiveParticipantUniquenessClaim
  , collectiveParticipantUniquenessDuplicateEndpoints
  , CollectiveTargetTypeEvidence
  , collectiveTargetTypeClaim
  , collectiveTargetTypeSegment
  , collectiveTargetTypeEndpoint
  , CollectiveTargetCardinalityEvidence
  , collectiveTargetCardinalityClaim
  , collectiveTargetCardinalityEndpoints
  , CollectiveTargetDistinctnessEvidence
  , collectiveTargetDistinctnessClaim
  , collectiveTargetDistinctnessOverlappingEndpoints
  , StructureDefectEliminator(..)
  , foldStructureDefect
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

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Contract
  ( CoreCarrierCategory
  , CoreO2IType
  , CoreParticipantCompleteness
  , CoreRelationToken
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
import O2I.Structure.Internal hiding (foldStructureDefect)
import qualified O2I.Structure.Internal as StructureInternal

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

-- | Eliminate exact zero-or-at-least-two occurrence evidence.
foldStructureZeroOrMultipleOccurrences ::
     result
  -> (OccurrenceIdentity -> OccurrenceIdentity -> [OccurrenceIdentity] -> result)
  -> StructureZeroOrMultipleOccurrences
  -> result
foldStructureZeroOrMultipleOccurrences onZero onMultiple occurrences =
  case occurrences of
    NoStructureOccurrence -> onZero
    MultipleStructureOccurrences first second remaining ->
      onMultiple first second remaining

-- | Eliminate one closed structural defect through its exact named handler.
foldStructureDefect ::
     StructureDefectEliminator result -> StructureDefect -> result
foldStructureDefect = StructureInternal.foldStructureDefect

-- | Project the carrier occurrence that could not be qualified.
qualifiedEndpointCatalogMembershipSubject ::
     QualifiedEndpointCatalogMembershipEvidence -> OccurrenceIdentity
qualifiedEndpointCatalogMembershipSubject (QualifiedEndpointCatalogMembershipEvidence subject) =
  subject

-- | Project the contextualization segment whose owner is invalid.
contextualizationSourceCategorySegment ::
     ContextualizationSourceCategoryEvidence -> OccurrenceIdentity
contextualizationSourceCategorySegment (ContextualizationSourceCategoryEvidence segment _) =
  segment

-- | Project the carrier occurrence used in the owner role.
contextualizationSourceCategoryOwner ::
     ContextualizationSourceCategoryEvidence -> OccurrenceIdentity
contextualizationSourceCategoryOwner (ContextualizationSourceCategoryEvidence _ owner) =
  owner

-- | Project the contextualization segment whose member is invalid.
contextualizationTargetCategorySegment ::
     ContextualizationTargetCategoryEvidence -> OccurrenceIdentity
contextualizationTargetCategorySegment (ContextualizationTargetCategoryEvidence segment _) =
  segment

-- | Project the carrier occurrence used in the member role.
contextualizationTargetCategoryMember ::
     ContextualizationTargetCategoryEvidence -> OccurrenceIdentity
contextualizationTargetCategoryMember (ContextualizationTargetCategoryEvidence _ member) =
  member

-- | Project the Primitive or Structuring carrier requiring one owner.
contextualizationTargetOwnerCardinalityMember ::
     ContextualizationTargetOwnerCardinalityEvidence -> OccurrenceIdentity
contextualizationTargetOwnerCardinalityMember (ContextualizationTargetOwnerCardinalityEvidence member _) =
  member

-- | Project constructive zero-or-at-least-two owner occurrences.
contextualizationTargetOwnerCardinalityOwners ::
     ContextualizationTargetOwnerCardinalityEvidence
  -> StructureZeroOrMultipleOccurrences
contextualizationTargetOwnerCardinalityOwners (ContextualizationTargetOwnerCardinalityEvidence _ owners) =
  owners

-- | Project the semantic relation occurrence being assessed.
semanticRelationCompatibilityRelation ::
     SemanticRelationCompatibilityEvidence -> OccurrenceIdentity
semanticRelationCompatibilityRelation (SemanticRelationCompatibilityEvidence relation _ _) =
  relation

-- | Project the carrier occurrence in the source role.
semanticRelationCompatibilitySource ::
     SemanticRelationCompatibilityEvidence -> OccurrenceIdentity
semanticRelationCompatibilitySource (SemanticRelationCompatibilityEvidence _ source _) =
  source

-- | Project the carrier occurrence in the target role.
semanticRelationCompatibilityTarget ::
     SemanticRelationCompatibilityEvidence -> OccurrenceIdentity
semanticRelationCompatibilityTarget (SemanticRelationCompatibilityEvidence _ _ target) =
  target

-- | Project the proposition occurrence chosen as deterministic subject.
structuredPropositionIdentitySubject ::
     StructuredPropositionIdentityEvidence -> OccurrenceIdentity
structuredPropositionIdentitySubject (StructuredPropositionIdentityEvidence subject _ _ _) =
  subject

-- | Project the first occurrence sharing the model identity.
structuredPropositionIdentityFirstOccurrence ::
     StructuredPropositionIdentityEvidence -> OccurrenceIdentity
structuredPropositionIdentityFirstOccurrence (StructuredPropositionIdentityEvidence _ first _ _) =
  first

-- | Project the second occurrence proving multiplicity.
structuredPropositionIdentitySecondOccurrence ::
     StructuredPropositionIdentityEvidence -> OccurrenceIdentity
structuredPropositionIdentitySecondOccurrence (StructuredPropositionIdentityEvidence _ _ second _) =
  second

-- | Project further occurrences sharing the model identity.
structuredPropositionIdentityRemainingOccurrences ::
     StructuredPropositionIdentityEvidence -> [OccurrenceIdentity]
structuredPropositionIdentityRemainingOccurrences (StructuredPropositionIdentityEvidence _ _ _ remaining) =
  remaining

-- | Project the collective proposition occurrence.
collectiveParticipantTypeClaim ::
     CollectiveParticipantTypeEvidence -> OccurrenceIdentity
collectiveParticipantTypeClaim (CollectiveParticipantTypeEvidence claim _ _) =
  claim

-- | Project the participant incidence segment.
collectiveParticipantTypeSegment ::
     CollectiveParticipantTypeEvidence -> OccurrenceIdentity
collectiveParticipantTypeSegment (CollectiveParticipantTypeEvidence _ segment _) =
  segment

-- | Project the carrier occurrence in the participant endpoint role.
collectiveParticipantTypeEndpoint ::
     CollectiveParticipantTypeEvidence -> OccurrenceIdentity
collectiveParticipantTypeEndpoint (CollectiveParticipantTypeEvidence _ _ endpoint) =
  endpoint

-- | Project the collective proposition occurrence.
collectiveParticipantCardinalityClaim ::
     CollectiveParticipantCardinalityEvidence -> OccurrenceIdentity
collectiveParticipantCardinalityClaim (CollectiveParticipantCardinalityEvidence claim _) =
  claim

-- | Project the sole participant endpoint, if one exists.
collectiveParticipantCardinalitySoleEndpoint ::
     CollectiveParticipantCardinalityEvidence -> Maybe OccurrenceIdentity
collectiveParticipantCardinalitySoleEndpoint (CollectiveParticipantCardinalityEvidence _ endpoint) =
  endpoint

-- | Project the collective proposition occurrence.
collectiveParticipantUniquenessClaim ::
     CollectiveParticipantUniquenessEvidence -> OccurrenceIdentity
collectiveParticipantUniquenessClaim (CollectiveParticipantUniquenessEvidence claim _) =
  claim

-- | Project distinct participant endpoints occurring more than once.
collectiveParticipantUniquenessDuplicateEndpoints ::
     CollectiveParticipantUniquenessEvidence -> NonEmpty OccurrenceIdentity
collectiveParticipantUniquenessDuplicateEndpoints (CollectiveParticipantUniquenessEvidence _ endpoints) =
  endpoints

-- | Project the collective proposition occurrence.
collectiveTargetTypeClaim :: CollectiveTargetTypeEvidence -> OccurrenceIdentity
collectiveTargetTypeClaim (CollectiveTargetTypeEvidence claim _ _) = claim

-- | Project the target incidence segment.
collectiveTargetTypeSegment ::
     CollectiveTargetTypeEvidence -> OccurrenceIdentity
collectiveTargetTypeSegment (CollectiveTargetTypeEvidence _ segment _) = segment

-- | Project the carrier occurrence in the target endpoint role.
collectiveTargetTypeEndpoint ::
     CollectiveTargetTypeEvidence -> OccurrenceIdentity
collectiveTargetTypeEndpoint (CollectiveTargetTypeEvidence _ _ endpoint) =
  endpoint

-- | Project the collective proposition occurrence.
collectiveTargetCardinalityClaim ::
     CollectiveTargetCardinalityEvidence -> OccurrenceIdentity
collectiveTargetCardinalityClaim (CollectiveTargetCardinalityEvidence claim _) =
  claim

-- | Project constructive zero-or-at-least-two target endpoints.
collectiveTargetCardinalityEndpoints ::
     CollectiveTargetCardinalityEvidence -> StructureZeroOrMultipleOccurrences
collectiveTargetCardinalityEndpoints (CollectiveTargetCardinalityEvidence _ endpoints) =
  endpoints

-- | Project the collective proposition occurrence.
collectiveTargetDistinctnessClaim ::
     CollectiveTargetDistinctnessEvidence -> OccurrenceIdentity
collectiveTargetDistinctnessClaim (CollectiveTargetDistinctnessEvidence claim _) =
  claim

-- | Project endpoints occupying participant and target roles.
collectiveTargetDistinctnessOverlappingEndpoints ::
     CollectiveTargetDistinctnessEvidence -> NonEmpty OccurrenceIdentity
collectiveTargetDistinctnessOverlappingEndpoints (CollectiveTargetDistinctnessEvidence _ endpoints) =
  endpoints

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
