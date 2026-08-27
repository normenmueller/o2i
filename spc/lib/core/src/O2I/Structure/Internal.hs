{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Internal representation of the Core Structure boundary.
module O2I.Structure.Internal
  ( CarrierProjection(..)
  , RelationProjection(..)
  , ContextualizationProjection(..)
  , StructuredPropositionProjection(..)
  , StructuredIncidenceProjection(..)
  , StructureProjection(..)
  , StructureProjectionKind(..)
  , ScopedStructureProjection(..)
  , StructureEndpointRole(..)
  , StructureInputDefect(..)
  , StructureRule(..)
  , structureRuleId
  , StructureZeroOrMultipleOccurrences(..)
  , QualifiedEndpointCatalogMembershipEvidence(..)
  , ContextualizationSourceCategoryEvidence(..)
  , ContextualizationTargetCategoryEvidence(..)
  , ContextualizationTargetOwnerCardinalityEvidence(..)
  , SemanticRelationCompatibilityEvidence(..)
  , StructuredPropositionIdentityEvidence(..)
  , CollectiveParticipantTypeEvidence(..)
  , CollectiveParticipantCardinalityEvidence(..)
  , CollectiveParticipantUniquenessEvidence(..)
  , CollectiveTargetTypeEvidence(..)
  , CollectiveTargetCardinalityEvidence(..)
  , CollectiveTargetDistinctnessEvidence(..)
  , StructureDefect(..)
  , structureDefectRule
  , StructureDefectEliminator(..)
  , foldStructureDefect
  , StructureAssessment(..)
  , StructuredIncidenceObservation(..)
  , StructuredPropositionObservation(..)
  , WellFormedGraph(..)
  , wellFormedGraphIdentity
  , sameWellFormedGraph
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreCarrierCategory
  , CoreO2IType
  , CoreParticipantCompleteness
  , CoreRelationToken
  , CoreRuleId
  , CoreStructuredPropositionFamilyId
  , CoreStructuredPropositionRoleId
  )
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment
  , ContextualizationObservation
  , RelationObservation
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Core.Identity.Internal
  ( ScopedOccurrence
  , SelectedViewScope
  , sameSelectedViewScope
  , selectedViewScopeGraphIdentity
  )

-- | One profile-projected O2I carrier before endpoint qualification.
data CarrierProjection =
  CarrierProjection
    !OccurrenceIdentity
    !CoreCarrierCategory
    !CoreO2IType
    !Commitment
  deriving (Eq, Ord, Show)

-- | One profile-projected binary semantic relation.
data RelationProjection =
  RelationProjection
    !OccurrenceIdentity
    !OccurrenceIdentity
    !CoreRelationToken
    !OccurrenceIdentity
    !Commitment
  deriving (Eq, Ord, Show)

-- | One profile-projected Context-to-member contextualization.
data ContextualizationProjection =
  ContextualizationProjection
    !OccurrenceIdentity
    !OccurrenceIdentity
    !OccurrenceIdentity
    !Commitment
  deriving (Eq, Ord, Show)

-- | One atomic structured proposition before family validation.
data StructuredPropositionProjection =
  StructuredPropositionProjection
    !OccurrenceIdentity
    !CoreStructuredPropositionFamilyId
    !CoreParticipantCompleteness
    !Commitment
  deriving (Eq, Ord, Show)

-- | One role-labelled endpoint occurrence of a structured proposition.
--
-- The first identity belongs to the notation segment that carries the
-- incidence. The second identifies the structured proposition.
data StructuredIncidenceProjection =
  StructuredIncidenceProjection
    !OccurrenceIdentity
    !OccurrenceIdentity
    !CoreStructuredPropositionRoleId
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Complete profile projection of one selected O2I View.
data StructureProjection =
  StructureProjection
    ![CarrierProjection]
    ![ContextualizationProjection]
    ![RelationProjection]
    ![StructuredPropositionProjection]
    ![StructuredIncidenceProjection]
  deriving (Eq, Show)

-- | Projection after selected-View membership has been established once.
--
-- Only carrier and proposition owners retain their scoped occurrence because
-- later stages need their exact model identity. All remaining references have
-- already passed the same input boundary.
data ScopedStructureProjection scope =
  ScopedStructureProjection
    ![(CarrierProjection, ScopedOccurrence scope)]
    ![ContextualizationProjection]
    ![RelationProjection]
    ![(StructuredPropositionProjection, ScopedOccurrence scope)]
    ![StructuredIncidenceProjection]
  deriving (Eq, Show)

-- | Closed projection kind used in duplicate-occurrence evidence.
data StructureProjectionKind
  = CarrierProjectionKind
  | ContextualizationProjectionKind
  | RelationProjectionKind
  | StructuredPropositionProjectionKind
  | StructuredIncidenceProjectionKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed endpoint role used in missing-projection evidence.
data StructureEndpointRole
  = RelationSourceRole
  | RelationTargetRole
  | ContextualizationOwnerRole
  | ContextualizationMemberRole
  | StructuredIncidenceEndpointRole
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Invalid use of the Structure construction boundary.
--
-- These defects describe an invalid projection, not a model-semantic rule
-- violation, and therefore carry no Core rule identity.
data StructureInputDefect
  = ProjectionOutsideSelectedView !OccurrenceIdentity
  | DuplicateStructureProjection
      !OccurrenceIdentity
      !(NonEmpty StructureProjectionKind)
  | MissingCarrierProjection
      !OccurrenceIdentity
      !StructureEndpointRole
      !OccurrenceIdentity
  | MissingStructuredPropositionProjection
      !OccurrenceIdentity
      !OccurrenceIdentity
  deriving (Eq, Show)

-- | Closed structural rules implemented by this stage.
--
-- The constructors select behavior. Their identifiers are provenance only and
-- are checked against the compiled Structure partition by focused tests.
data StructureRule
  = QualifiedEndpointCatalogMembershipRule
  | ContextualizationSourceCategoryRule
  | ContextualizationTargetCategoryRule
  | ContextualizationTargetOwnerCardinalityRule
  | SemanticRelationCompatibilityRule
  | StructuredPropositionIdentityRule
  | CollectiveParticipantTypeRule
  | CollectiveParticipantCardinalityRule
  | CollectiveParticipantUniquenessRule
  | CollectiveTargetTypeRule
  | CollectiveTargetCardinalityRule
  | CollectiveTargetDistinctnessRule
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Project the exact compiled-contract provenance of one structural rule.
structureRuleId :: StructureRule -> CoreRuleId
structureRuleId rule = CoreRuleId (structureRuleIdText rule)

structureRuleIdText :: StructureRule -> Text
structureRuleIdText rule =
  case rule of
    QualifiedEndpointCatalogMembershipRule ->
      "core.qualified-endpoint.catalog-membership"
    ContextualizationSourceCategoryRule ->
      "core.contextualization.source-category"
    ContextualizationTargetCategoryRule ->
      "core.contextualization.target-category"
    ContextualizationTargetOwnerCardinalityRule ->
      "core.contextualization.target-owner-cardinality"
    SemanticRelationCompatibilityRule -> "core.semantic-relation.compatibility"
    StructuredPropositionIdentityRule -> "core.structured-proposition.identity"
    CollectiveParticipantTypeRule ->
      "core.collective-strategy-realization.participant-type"
    CollectiveParticipantCardinalityRule ->
      "core.collective-strategy-realization.participant-cardinality"
    CollectiveParticipantUniquenessRule ->
      "core.collective-strategy-realization.participant-uniqueness"
    CollectiveTargetTypeRule ->
      "core.collective-strategy-realization.target-type"
    CollectiveTargetCardinalityRule ->
      "core.collective-strategy-realization.target-cardinality"
    CollectiveTargetDistinctnessRule ->
      "core.collective-strategy-realization.target-distinctness"

-- | Exact zero-or-at-least-two evidence for a violated cardinality.
--
-- The public module keeps constructors opaque and exposes a total fold.
data StructureZeroOrMultipleOccurrences
  = NoStructureOccurrence
  | MultipleStructureOccurrences
      !OccurrenceIdentity
      !OccurrenceIdentity
      ![OccurrenceIdentity]
  deriving (Eq, Ord, Show)

-- | Evidence that one carrier has no admitted qualified endpoint.
newtype QualifiedEndpointCatalogMembershipEvidence =
  QualifiedEndpointCatalogMembershipEvidence OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that a contextualization owner has the wrong category.
data ContextualizationSourceCategoryEvidence =
  ContextualizationSourceCategoryEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that a contextualization member has the wrong category.
data ContextualizationTargetCategoryEvidence =
  ContextualizationTargetCategoryEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that an owned carrier has zero or multiple owners.
data ContextualizationTargetOwnerCardinalityEvidence =
  ContextualizationTargetOwnerCardinalityEvidence
    !OccurrenceIdentity
    !StructureZeroOrMultipleOccurrences
  deriving (Eq, Ord, Show)

-- | Evidence that a semantic relation has incompatible endpoints.
data SemanticRelationCompatibilityEvidence =
  SemanticRelationCompatibilityEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that a proposition model identity is not unique.
data StructuredPropositionIdentityEvidence =
  StructuredPropositionIdentityEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
    !OccurrenceIdentity
    ![OccurrenceIdentity]
  deriving (Eq, Ord, Show)

-- | Evidence that one participant incidence targets the wrong carrier type.
data CollectiveParticipantTypeEvidence =
  CollectiveParticipantTypeEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that a collective proposition has fewer than two participants.
data CollectiveParticipantCardinalityEvidence =
  CollectiveParticipantCardinalityEvidence
    !OccurrenceIdentity
    !(Maybe OccurrenceIdentity)
  deriving (Eq, Ord, Show)

-- | Evidence that participant endpoint identities repeat.
data CollectiveParticipantUniquenessEvidence =
  CollectiveParticipantUniquenessEvidence
    !OccurrenceIdentity
    !(NonEmpty OccurrenceIdentity)
  deriving (Eq, Ord, Show)

-- | Evidence that one target incidence has the wrong carrier type.
data CollectiveTargetTypeEvidence =
  CollectiveTargetTypeEvidence
    !OccurrenceIdentity
    !OccurrenceIdentity
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that a collective proposition has zero or multiple targets.
data CollectiveTargetCardinalityEvidence =
  CollectiveTargetCardinalityEvidence
    !OccurrenceIdentity
    !StructureZeroOrMultipleOccurrences
  deriving (Eq, Ord, Show)

-- | Evidence that target and participant endpoint roles overlap.
data CollectiveTargetDistinctnessEvidence =
  CollectiveTargetDistinctnessEvidence
    !OccurrenceIdentity
    !(NonEmpty OccurrenceIdentity)
  deriving (Eq, Ord, Show)

-- | One structurally invalid O2I proposition or carrier.
--
-- Each constructor is owned by exactly one Structure rule and admits only its
-- exact evidence cardinality. Constructors stay private at the public API.
data StructureDefect
  = QualifiedEndpointCatalogMembershipDefect
      !QualifiedEndpointCatalogMembershipEvidence
  | ContextualizationSourceCategoryDefect
      !ContextualizationSourceCategoryEvidence
  | ContextualizationTargetCategoryDefect
      !ContextualizationTargetCategoryEvidence
  | ContextualizationTargetOwnerCardinalityDefect
      !ContextualizationTargetOwnerCardinalityEvidence
  | SemanticRelationCompatibilityDefect !SemanticRelationCompatibilityEvidence
  | StructuredPropositionIdentityDefect !StructuredPropositionIdentityEvidence
  | CollectiveParticipantTypeDefect !CollectiveParticipantTypeEvidence
  | CollectiveParticipantCardinalityDefect
      !CollectiveParticipantCardinalityEvidence
  | CollectiveParticipantUniquenessDefect
      !CollectiveParticipantUniquenessEvidence
  | CollectiveTargetTypeDefect !CollectiveTargetTypeEvidence
  | CollectiveTargetCardinalityDefect !CollectiveTargetCardinalityEvidence
  | CollectiveTargetDistinctnessDefect !CollectiveTargetDistinctnessEvidence
  deriving (Eq, Ord, Show)

-- | Project the exact Core-owned rule identity of one structural defect.
structureDefectRule :: StructureDefect -> CoreRuleId
structureDefectRule = structureRuleId . structureDefectRuleIdentity

structureDefectRuleIdentity :: StructureDefect -> StructureRule
structureDefectRuleIdentity defect =
  case defect of
    QualifiedEndpointCatalogMembershipDefect _ ->
      QualifiedEndpointCatalogMembershipRule
    ContextualizationSourceCategoryDefect _ ->
      ContextualizationSourceCategoryRule
    ContextualizationTargetCategoryDefect _ ->
      ContextualizationTargetCategoryRule
    ContextualizationTargetOwnerCardinalityDefect _ ->
      ContextualizationTargetOwnerCardinalityRule
    SemanticRelationCompatibilityDefect _ -> SemanticRelationCompatibilityRule
    StructuredPropositionIdentityDefect _ -> StructuredPropositionIdentityRule
    CollectiveParticipantTypeDefect _ -> CollectiveParticipantTypeRule
    CollectiveParticipantCardinalityDefect _ ->
      CollectiveParticipantCardinalityRule
    CollectiveParticipantUniquenessDefect _ ->
      CollectiveParticipantUniquenessRule
    CollectiveTargetTypeDefect _ -> CollectiveTargetTypeRule
    CollectiveTargetCardinalityDefect _ -> CollectiveTargetCardinalityRule
    CollectiveTargetDistinctnessDefect _ -> CollectiveTargetDistinctnessRule

-- | Named total consumer for all twelve Structure rules.
data StructureDefectEliminator result = StructureDefectEliminator
  { eliminateQualifiedEndpointCatalogMembership :: QualifiedEndpointCatalogMembershipEvidence -> result
  , eliminateContextualizationSourceCategory :: ContextualizationSourceCategoryEvidence -> result
  , eliminateContextualizationTargetCategory :: ContextualizationTargetCategoryEvidence -> result
  , eliminateContextualizationTargetOwnerCardinality :: ContextualizationTargetOwnerCardinalityEvidence -> result
  , eliminateSemanticRelationCompatibility :: SemanticRelationCompatibilityEvidence -> result
  , eliminateStructuredPropositionIdentity :: StructuredPropositionIdentityEvidence -> result
  , eliminateCollectiveParticipantType :: CollectiveParticipantTypeEvidence -> result
  , eliminateCollectiveParticipantCardinality :: CollectiveParticipantCardinalityEvidence -> result
  , eliminateCollectiveParticipantUniqueness :: CollectiveParticipantUniquenessEvidence -> result
  , eliminateCollectiveTargetType :: CollectiveTargetTypeEvidence -> result
  , eliminateCollectiveTargetCardinality :: CollectiveTargetCardinalityEvidence -> result
  , eliminateCollectiveTargetDistinctness :: CollectiveTargetDistinctnessEvidence -> result
  }

foldStructureDefect ::
     StructureDefectEliminator result -> StructureDefect -> result
foldStructureDefect eliminator defect =
  case defect of
    QualifiedEndpointCatalogMembershipDefect evidence ->
      eliminateQualifiedEndpointCatalogMembership eliminator evidence
    ContextualizationSourceCategoryDefect evidence ->
      eliminateContextualizationSourceCategory eliminator evidence
    ContextualizationTargetCategoryDefect evidence ->
      eliminateContextualizationTargetCategory eliminator evidence
    ContextualizationTargetOwnerCardinalityDefect evidence ->
      eliminateContextualizationTargetOwnerCardinality eliminator evidence
    SemanticRelationCompatibilityDefect evidence ->
      eliminateSemanticRelationCompatibility eliminator evidence
    StructuredPropositionIdentityDefect evidence ->
      eliminateStructuredPropositionIdentity eliminator evidence
    CollectiveParticipantTypeDefect evidence ->
      eliminateCollectiveParticipantType eliminator evidence
    CollectiveParticipantCardinalityDefect evidence ->
      eliminateCollectiveParticipantCardinality eliminator evidence
    CollectiveParticipantUniquenessDefect evidence ->
      eliminateCollectiveParticipantUniqueness eliminator evidence
    CollectiveTargetTypeDefect evidence ->
      eliminateCollectiveTargetType eliminator evidence
    CollectiveTargetCardinalityDefect evidence ->
      eliminateCollectiveTargetCardinality eliminator evidence
    CollectiveTargetDistinctnessDefect evidence ->
      eliminateCollectiveTargetDistinctness eliminator evidence

-- | Closed result of structural assessment.
data StructureAssessment scope
  = StructureRejected !(NonEmpty StructureDefect)
  | StructureAccepted !(WellFormedGraph scope)
  deriving (Eq, Show)

type role StructuredIncidenceObservation nominal

-- | One structurally valid role-labelled incidence.
data StructuredIncidenceObservation scope =
  StructuredIncidenceObservation
    !OccurrenceIdentity
    !CoreStructuredPropositionRoleId
    !OccurrenceIdentity
  deriving (Eq, Ord, Show)

type role StructuredPropositionObservation nominal

-- | One structurally valid atomic structured proposition.
data StructuredPropositionObservation scope =
  StructuredPropositionObservation
    !OccurrenceIdentity
    !ModelIdentity
    !CoreStructuredPropositionFamilyId
    !CoreParticipantCompleteness
    !Commitment
    ![StructuredIncidenceObservation scope]
  deriving (Eq, Ord, Show)

type role WellFormedGraph nominal

-- | Opaque structurally valid selected-View graph.
--
-- Collections are retained in canonical occurrence order. The type exposes
-- enumeration only, never lookup, traversal, or query operations.
data WellFormedGraph scope = WellFormedGraph
  { wellFormedSelectedViewScope :: !(SelectedViewScope scope)
  , storedWellFormedCarriers :: ![CarrierObservation scope]
  , storedWellFormedContextualizations :: ![ContextualizationObservation scope]
  , storedWellFormedRelations :: ![RelationObservation scope]
  , storedWellFormedStructuredPropositions :: ![StructuredPropositionObservation
                                                  scope]
  }

-- | Project the exact selected View identity for later Core stages.
wellFormedGraphIdentity :: WellFormedGraph scope -> ModelIdentity
wellFormedGraphIdentity =
  selectedViewScopeGraphIdentity . wellFormedSelectedViewScope

-- | Compare the complete producing graph, including its selected-View scope.
sameWellFormedGraph :: WellFormedGraph scope -> WellFormedGraph scope -> Bool
sameWellFormedGraph left right =
  sameSelectedViewScope
    (wellFormedSelectedViewScope left)
    (wellFormedSelectedViewScope right)
    && left == right

instance Eq (WellFormedGraph scope) where
  left == right =
    storedWellFormedCarriers left == storedWellFormedCarriers right
      && storedWellFormedContextualizations left
           == storedWellFormedContextualizations right
      && storedWellFormedRelations left == storedWellFormedRelations right
      && storedWellFormedStructuredPropositions left
           == storedWellFormedStructuredPropositions right

instance Show (WellFormedGraph scope) where
  showsPrec precedence graph =
    showParen (precedence > 10)
      $ showString "WellFormedGraph "
          . showsPrec 11 (storedWellFormedCarriers graph)
          . showChar ' '
          . showsPrec 11 (storedWellFormedContextualizations graph)
          . showChar ' '
          . showsPrec 11 (storedWellFormedRelations graph)
          . showChar ' '
          . showsPrec 11 (storedWellFormedStructuredPropositions graph)
