module StructurePublicApi where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment)
import O2I.Core.Identity (OccurrenceIdentity, SelectedViewScope)
import O2I.Structure

projectCarrier ::
     OccurrenceIdentity
  -> CoreCarrierCategory
  -> CoreO2IType
  -> Commitment
  -> CarrierProjection
projectCarrier = carrierProjection

projectRelation ::
     OccurrenceIdentity
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> Commitment
  -> RelationProjection
projectRelation = relationProjection

projectCollective ::
     OccurrenceIdentity
  -> CoreStructuredPropositionFamilyId
  -> CoreParticipantCompleteness
  -> Commitment
  -> StructuredPropositionProjection
projectCollective = structuredPropositionProjection

assess ::
     SelectedViewScope scope
  -> StructureProjection
  -> Either (NonEmpty StructureInputDefect) (StructureAssessment scope)
assess = assessStructure

consumeAssessment ::
     StructureAssessment scope
  -> Either (NonEmpty StructureDefect) (WellFormedGraph scope)
consumeAssessment assessment =
  case assessment of
    StructureRejected defects -> Left defects
    StructureAccepted graph -> Right graph

data StructureEvidenceView
  = QualifiedEndpointView OccurrenceIdentity
  | ContextSourceView OccurrenceIdentity OccurrenceIdentity
  | ContextTargetView OccurrenceIdentity OccurrenceIdentity
  | OwnerCardinalityView OccurrenceIdentity Int
  | RelationCompatibilityView
      OccurrenceIdentity
      OccurrenceIdentity
      OccurrenceIdentity
  | PropositionIdentityView
      OccurrenceIdentity
      OccurrenceIdentity
      OccurrenceIdentity
      [OccurrenceIdentity]
  | ParticipantTypeView OccurrenceIdentity OccurrenceIdentity OccurrenceIdentity
  | ParticipantCardinalityView OccurrenceIdentity (Maybe OccurrenceIdentity)
  | ParticipantUniquenessView OccurrenceIdentity (NonEmpty OccurrenceIdentity)
  | TargetTypeView OccurrenceIdentity OccurrenceIdentity OccurrenceIdentity
  | TargetCardinalityView OccurrenceIdentity Int
  | TargetDistinctnessView OccurrenceIdentity (NonEmpty OccurrenceIdentity)

projectDefect :: StructureDefect -> StructureEvidenceView
projectDefect = foldStructureDefect eliminator
  where
    eliminator =
      StructureDefectEliminator
        { eliminateQualifiedEndpointCatalogMembership =
            QualifiedEndpointView . qualifiedEndpointCatalogMembershipSubject
        , eliminateContextualizationSourceCategory =
            \evidence ->
              ContextSourceView
                (contextualizationSourceCategorySegment evidence)
                (contextualizationSourceCategoryOwner evidence)
        , eliminateContextualizationTargetCategory =
            \evidence ->
              ContextTargetView
                (contextualizationTargetCategorySegment evidence)
                (contextualizationTargetCategoryMember evidence)
        , eliminateContextualizationTargetOwnerCardinality =
            \evidence ->
              OwnerCardinalityView
                (contextualizationTargetOwnerCardinalityMember evidence)
                (cardinalitySize
                   (contextualizationTargetOwnerCardinalityOwners evidence))
        , eliminateSemanticRelationCompatibility =
            \evidence ->
              RelationCompatibilityView
                (semanticRelationCompatibilityRelation evidence)
                (semanticRelationCompatibilitySource evidence)
                (semanticRelationCompatibilityTarget evidence)
        , eliminateStructuredPropositionIdentity =
            \evidence ->
              PropositionIdentityView
                (structuredPropositionIdentitySubject evidence)
                (structuredPropositionIdentityFirstOccurrence evidence)
                (structuredPropositionIdentitySecondOccurrence evidence)
                (structuredPropositionIdentityRemainingOccurrences evidence)
        , eliminateCollectiveParticipantType =
            \evidence ->
              ParticipantTypeView
                (collectiveParticipantTypeClaim evidence)
                (collectiveParticipantTypeSegment evidence)
                (collectiveParticipantTypeEndpoint evidence)
        , eliminateCollectiveParticipantCardinality =
            \evidence ->
              ParticipantCardinalityView
                (collectiveParticipantCardinalityClaim evidence)
                (collectiveParticipantCardinalitySoleEndpoint evidence)
        , eliminateCollectiveParticipantUniqueness =
            \evidence ->
              ParticipantUniquenessView
                (collectiveParticipantUniquenessClaim evidence)
                (collectiveParticipantUniquenessDuplicateEndpoints evidence)
        , eliminateCollectiveTargetType =
            \evidence ->
              TargetTypeView
                (collectiveTargetTypeClaim evidence)
                (collectiveTargetTypeSegment evidence)
                (collectiveTargetTypeEndpoint evidence)
        , eliminateCollectiveTargetCardinality =
            \evidence ->
              TargetCardinalityView
                (collectiveTargetCardinalityClaim evidence)
                (cardinalitySize (collectiveTargetCardinalityEndpoints evidence))
        , eliminateCollectiveTargetDistinctness =
            \evidence ->
              TargetDistinctnessView
                (collectiveTargetDistinctnessClaim evidence)
                (collectiveTargetDistinctnessOverlappingEndpoints evidence)
        }

cardinalitySize :: StructureZeroOrMultipleOccurrences -> Int
cardinalitySize =
  foldStructureZeroOrMultipleOccurrences
    0
    (\_ _ remaining -> 2 + length remaining)

enumerateGraph :: WellFormedGraph scope -> (Int, Int, Int, Int)
enumerateGraph graph =
  ( length (wellFormedCarriers graph)
  , length (wellFormedContextualizations graph)
  , length (wellFormedRelations graph)
  , length (wellFormedStructuredPropositions graph))
