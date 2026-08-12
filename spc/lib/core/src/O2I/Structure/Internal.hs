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
  , StructureDefect(..)
  , StructureAssessment(..)
  , StructuredIncidenceObservation(..)
  , StructuredPropositionObservation(..)
  , WellFormedGraph(..)
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
import O2I.Core.Identity.Internal (ScopedOccurrence, SelectedViewScope)

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

-- | One structurally invalid O2I proposition or carrier.
data StructureDefect =
  StructureDefect !StructureRule !OccurrenceIdentity ![OccurrenceIdentity]
  deriving (Eq, Ord, Show)

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
