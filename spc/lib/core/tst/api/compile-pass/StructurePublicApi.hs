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

enumerateGraph :: WellFormedGraph scope -> (Int, Int, Int, Int)
enumerateGraph graph =
  ( length (wellFormedCarriers graph)
  , length (wellFormedContextualizations graph)
  , length (wellFormedRelations graph)
  , length (wellFormedStructuredPropositions graph))
