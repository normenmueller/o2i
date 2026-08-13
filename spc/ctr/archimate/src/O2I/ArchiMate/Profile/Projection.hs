{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}

-- | Opaque Profile assessment and notation-independent Core projection.
module O2I.ArchiMate.Profile.Projection
  ( ProfileEvidenceKind
  , foldProfileEvidenceKind
  , ProfileEvidence
  , profileEvidenceKind
  , foldProfileEvidence
  , -- | Opaque generated Profile-rule defect with exact typed evidence.
    ProfileDefect
  , profileDefectRuleId
  , foldProfileDefect
  , -- | Closed internal contract failure, distinct from model rejection.
    ProfileContractFailure
  , foldProfileContractFailure
  , -- | Opaque total outcome of applying Profile projection.
    ProfileProjectionAssessment
  , assessSelectedView
  , foldProfileProjectionAssessment
  , -- | Opaque successful notation-independent projection into Core material.
    ProfileProjection
  , profileStructureProjection
  , profileMappingProvenance
  , profileQualificationProposals
  , -- | Opaque provenance for one concrete Profile mapping.
    ProfileMappingProvenance
  , foldProfileMappingProvenance
  , -- | Opaque projected qualification proposal and its source evidence.
    QualificationProposal
  , qualificationProposalOccurrence
  , qualificationProposalIdentity
  , qualificationProposalRationale
  , qualificationProposalSources
  , qualificationProposalReferences
  , -- | Opaque normalized rationale and its exact native source location.
    QualificationRationale
  , qualificationRationaleLocation
  , qualificationRationaleValue
  , -- | Opaque source occurrence retained by a qualification proposal.
    QualificationSource
  , qualificationSourceOccurrence
  , qualificationSourceValue
  , -- | Opaque typed reference retained by a qualification proposal.
    QualificationReference
  , qualificationReferenceOccurrence
  , qualificationReferenceRole
  , qualificationReferenceTarget
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftLocation, DraftScalar)
import O2I.ArchiMate.Profile.Internal.Generated
  ( GeneratedProfileEvidenceKind(..)
  , generatedProfileDefectRuleId
  )
import O2I.ArchiMate.Profile.Internal.Projection
  ( ProfileContractFailure
  , ProfileDefect
  , ProfileMappingProvenance
  , ProfileProjection
  , ProfileProjectionAssessment
  , QualificationProposal
  , QualificationRationale
  , QualificationReference
  , QualificationSource
  )
import qualified O2I.ArchiMate.Profile.Internal.Projection as Internal
import O2I.ArchiMate.Profile.Notation
  ( CanonicalOccurrence
  , NotationConformantUniverse
  )
import O2I.Core.Contract (CoreQualificationProposalRoleId)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Structure (StructureProjection)

-- | Closed public vocabulary for generated Profile evidence shapes.
data ProfileEvidenceKind
  = CarrierOccurrenceEvidenceKind
  | ClassificationOccurrenceEvidenceKind
  | MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind
  | PropertyOccurrenceEvidenceKind
  | PropertySlotEvidenceKind
  | PropertyValueEvidenceKind
  | ProposalCarrierOccurrenceEvidenceKind
  | ProposalReferenceIncidenceEvidenceKind
  | RelationshipOccurrenceEvidenceKind
  | ReservedPropertyOccurrenceEvidenceKind
  | StructuredCarrierOccurrenceEvidenceKind
  | StructuredIncidenceEvidenceKind
  deriving (Eq, Ord, Show)

-- | Consume every closed Profile evidence kind.
foldProfileEvidenceKind ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> ProfileEvidenceKind
  -> result
foldProfileEvidenceKind carrier classification metadata property slot value proposal reference relationship reserved structured incidence kind =
  case kind of
    CarrierOccurrenceEvidenceKind -> carrier
    ClassificationOccurrenceEvidenceKind -> classification
    MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind -> metadata
    PropertyOccurrenceEvidenceKind -> property
    PropertySlotEvidenceKind -> slot
    PropertyValueEvidenceKind -> value
    ProposalCarrierOccurrenceEvidenceKind -> proposal
    ProposalReferenceIncidenceEvidenceKind -> reference
    RelationshipOccurrenceEvidenceKind -> relationship
    ReservedPropertyOccurrenceEvidenceKind -> reserved
    StructuredCarrierOccurrenceEvidenceKind -> structured
    StructuredIncidenceEvidenceKind -> incidence

-- | Exact evidence for one generated Profile defect rule.
data ProfileEvidence (kind :: ProfileEvidenceKind) where
  CarrierOccurrenceEvidence
    :: !CanonicalOccurrence -> ProfileEvidence 'CarrierOccurrenceEvidenceKind
  ClassificationOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'ClassificationOccurrenceEvidenceKind
  MetadataOwnerAndO2iPropertyOccurrencesEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind
  PropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ProfileEvidence 'PropertyOccurrenceEvidenceKind
  PropertySlotEvidence
    :: !CanonicalOccurrence
    -> !Text
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'PropertySlotEvidenceKind
  PropertyValueEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![DraftScalar]
    -> ProfileEvidence 'PropertyValueEvidenceKind
  ProposalCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'ProposalCarrierOccurrenceEvidenceKind
  ProposalReferenceIncidenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'ProposalReferenceIncidenceEvidenceKind
  RelationshipOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'RelationshipOccurrenceEvidenceKind
  ReservedPropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> !Text
    -> ProfileEvidence 'ReservedPropertyOccurrenceEvidenceKind
  StructuredCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'StructuredCarrierOccurrenceEvidenceKind
  StructuredIncidenceEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'StructuredIncidenceEvidenceKind

-- | Runtime witness for the statically indexed evidence shape.
profileEvidenceKind :: ProfileEvidence kind -> ProfileEvidenceKind
profileEvidenceKind evidence =
  case evidence of
    CarrierOccurrenceEvidence _ -> CarrierOccurrenceEvidenceKind
    ClassificationOccurrenceEvidence _ -> ClassificationOccurrenceEvidenceKind
    MetadataOwnerAndO2iPropertyOccurrencesEvidence _ _ ->
      MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind
    PropertyOccurrenceEvidence _ _ -> PropertyOccurrenceEvidenceKind
    PropertySlotEvidence _ _ _ -> PropertySlotEvidenceKind
    PropertyValueEvidence _ _ _ -> PropertyValueEvidenceKind
    ProposalCarrierOccurrenceEvidence _ -> ProposalCarrierOccurrenceEvidenceKind
    ProposalReferenceIncidenceEvidence _ _ _ ->
      ProposalReferenceIncidenceEvidenceKind
    RelationshipOccurrenceEvidence _ -> RelationshipOccurrenceEvidenceKind
    ReservedPropertyOccurrenceEvidence _ _ _ ->
      ReservedPropertyOccurrenceEvidenceKind
    StructuredCarrierOccurrenceEvidence _ ->
      StructuredCarrierOccurrenceEvidenceKind
    StructuredIncidenceEvidence _ _ -> StructuredIncidenceEvidenceKind

-- | Consume every exact, typed Profile defect evidence shape.
foldProfileEvidence ::
     (CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> [CanonicalOccurrence] -> result)
  -> (CanonicalOccurrence -> CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> Text -> [CanonicalOccurrence] -> result)
  -> (CanonicalOccurrence -> CanonicalOccurrence -> [DraftScalar] -> result)
  -> (CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> CanonicalOccurrence -> [CanonicalOccurrence] -> result)
  -> (CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> CanonicalOccurrence -> Text -> result)
  -> (CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> [CanonicalOccurrence] -> result)
  -> ProfileEvidence kind
  -> result
foldProfileEvidence carrier classification metadata property slot value proposal reference relationship reserved structured incidence evidence =
  case evidence of
    CarrierOccurrenceEvidence occurrence -> carrier occurrence
    ClassificationOccurrenceEvidence occurrence -> classification occurrence
    MetadataOwnerAndO2iPropertyOccurrencesEvidence owner properties ->
      metadata owner properties
    PropertyOccurrenceEvidence propertyOccurrence owner ->
      property propertyOccurrence owner
    PropertySlotEvidence owner key properties -> slot owner key properties
    PropertyValueEvidence propertyOccurrence owner scalars ->
      value propertyOccurrence owner scalars
    ProposalCarrierOccurrenceEvidence occurrence -> proposal occurrence
    ProposalReferenceIncidenceEvidence occurrence proposalOccurrence related ->
      reference occurrence proposalOccurrence related
    RelationshipOccurrenceEvidence occurrence -> relationship occurrence
    ReservedPropertyOccurrenceEvidence propertyOccurrence owner key ->
      reserved propertyOccurrence owner key
    StructuredCarrierOccurrenceEvidence occurrence -> structured occurrence
    StructuredIncidenceEvidence occurrence related ->
      incidence occurrence related

-- | Generated rule identifier that owns the exact defect evidence.
profileDefectRuleId :: ProfileDefect -> Text
profileDefectRuleId = Internal.profileDefectRuleIdValue

-- | Consume a rule identifier paired with evidence of exactly its rule kind.
foldProfileDefect ::
     (forall kind. Text -> ProfileEvidence kind -> result)
  -> ProfileDefect
  -> result
foldProfileDefect consume (Internal.ProfileDefect rule evidence) =
  case evidence of
    Internal.CarrierOccurrenceEvidence occurrence ->
      consume ruleId (CarrierOccurrenceEvidence occurrence)
    Internal.ClassificationOccurrenceEvidence occurrence ->
      consume ruleId (ClassificationOccurrenceEvidence occurrence)
    Internal.MetadataOwnerAndO2iPropertyOccurrencesEvidence owner properties ->
      consume
        ruleId
        (MetadataOwnerAndO2iPropertyOccurrencesEvidence owner properties)
    Internal.PropertyOccurrenceEvidence property owner ->
      consume ruleId (PropertyOccurrenceEvidence property owner)
    Internal.PropertySlotEvidence owner key properties ->
      consume ruleId (PropertySlotEvidence owner key properties)
    Internal.PropertyValueEvidence property owner scalars ->
      consume ruleId (PropertyValueEvidence property owner scalars)
    Internal.ProposalCarrierOccurrenceEvidence occurrence ->
      consume ruleId (ProposalCarrierOccurrenceEvidence occurrence)
    Internal.ProposalReferenceIncidenceEvidence occurrence proposal related ->
      consume
        ruleId
        (ProposalReferenceIncidenceEvidence occurrence proposal related)
    Internal.RelationshipOccurrenceEvidence occurrence ->
      consume ruleId (RelationshipOccurrenceEvidence occurrence)
    Internal.ReservedPropertyOccurrenceEvidence property owner key ->
      consume ruleId (ReservedPropertyOccurrenceEvidence property owner key)
    Internal.StructuredCarrierOccurrenceEvidence occurrence ->
      consume ruleId (StructuredCarrierOccurrenceEvidence occurrence)
    Internal.StructuredIncidenceEvidence occurrence related ->
      consume ruleId (StructuredIncidenceEvidence occurrence related)
  where
    ruleId = generatedProfileDefectRuleId rule

-- | Consume every closed compiled Profile/Core contract failure.
foldProfileContractFailure ::
     (Text -> ProfileEvidenceKind -> result)
  -> (Text -> ProfileEvidenceKind -> result)
  -> (Text -> CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> Text -> result)
  -> ProfileContractFailure
  -> result
foldProfileContractFailure unknown mismatch missing impossible failure =
  case failure of
    Internal.UnknownGeneratedProfileRule rule kind ->
      unknown rule (publicEvidenceKind kind)
    Internal.GeneratedProfileEvidenceMismatch rule kind ->
      mismatch rule (publicEvidenceKind kind)
    Internal.MissingCoreContractBinding binding occurrence ->
      missing binding occurrence
    Internal.ImpossibleOccurrenceIdentity occurrence details ->
      impossible occurrence details

-- | Apply the compiled Profile contract after exact Notation conformance.
--
-- The total result separates internal contract failure from model rejection
-- and successful projection. Profile maps notation into Core material; it does
-- not define additional fachliche semantics.
assessSelectedView ::
     NotationConformantUniverse profile document -> ProfileProjectionAssessment
assessSelectedView = Internal.assessSelectedViewValue

-- | Distinguish contract failure, model rejection, and exact projection.
foldProfileProjectionAssessment ::
     (NonEmpty ProfileContractFailure -> result)
  -> (NonEmpty ProfileDefect -> result)
  -> (ProfileProjection -> result)
  -> ProfileProjectionAssessment
  -> result
foldProfileProjectionAssessment contractFailure rejected accepted assessment =
  case assessment of
    Internal.ProfileContractFailed failures -> contractFailure failures
    Internal.ProfileRejected defects -> rejected defects
    Internal.ProfileAccepted projection -> accepted projection

-- | Notation-independent Core structure emitted by a successful projection.
profileStructureProjection :: ProfileProjection -> StructureProjection
profileStructureProjection = Internal.profileStructureProjectionValue

-- | Canonically ordered concrete mapping provenance retained by the Profile.
profileMappingProvenance :: ProfileProjection -> [ProfileMappingProvenance]
profileMappingProvenance = Internal.profileMappingProvenanceValue

-- | Consume carrier or relationship mapping provenance without exposing its
-- representation.
foldProfileMappingProvenance ::
     (OccurrenceIdentity -> Text -> result)
  -> (OccurrenceIdentity -> Text -> OccurrenceIdentity -> OccurrenceIdentity -> result)
  -> ProfileMappingProvenance
  -> result
foldProfileMappingProvenance carrier relation provenance =
  case provenance of
    Internal.CarrierMappingProvenance occurrence mappingId ->
      carrier occurrence mappingId
    Internal.RelationMappingProvenance occurrence mappingId source target ->
      relation occurrence mappingId source target

-- | Qualification proposals retained separately from the structure graph.
profileQualificationProposals :: ProfileProjection -> [QualificationProposal]
profileQualificationProposals = Internal.profileQualificationProposalsValue

-- | Stable occurrence identity of the proposal carrier.
qualificationProposalOccurrence :: QualificationProposal -> OccurrenceIdentity
qualificationProposalOccurrence = Internal.qualificationProposalOccurrenceValue

-- | Model identity observed for the proposal carrier.
qualificationProposalIdentity :: QualificationProposal -> ModelIdentity
qualificationProposalIdentity = Internal.qualificationProposalIdentityValue

-- | Optional fachliche rationale retaining its exact native occurrence.
qualificationProposalRationale ::
     QualificationProposal -> Maybe QualificationRationale
qualificationProposalRationale = Internal.qualificationProposalRationaleValue

-- | Exact native source location of the documentation occurrence.
qualificationRationaleLocation :: QualificationRationale -> DraftLocation
qualificationRationaleLocation = Internal.qualificationRationaleOccurrenceValue

-- | Fachliche rationale after canonical documentation normalization.
qualificationRationaleValue :: QualificationRationale -> Text
qualificationRationaleValue = Internal.qualificationRationaleValueValue

-- | Canonically ordered source occurrences without deduplication.
qualificationProposalSources :: QualificationProposal -> [QualificationSource]
qualificationProposalSources = Internal.qualificationProposalSourcesValue

-- | Stable occurrence identity of one source property occurrence.
qualificationSourceOccurrence :: QualificationSource -> OccurrenceIdentity
qualificationSourceOccurrence = Internal.qualificationSourceOccurrenceValue

-- | Canonically normalized source identity retained by that occurrence.
qualificationSourceValue :: QualificationSource -> Text
qualificationSourceValue = Internal.qualificationSourceValueValue

-- | Typed proposal references in deterministic source order.
qualificationProposalReferences ::
     QualificationProposal -> [QualificationReference]
qualificationProposalReferences = Internal.qualificationProposalReferencesValue

-- | Stable occurrence identity of the reference evidence.
qualificationReferenceOccurrence :: QualificationReference -> OccurrenceIdentity
qualificationReferenceOccurrence =
  Internal.qualificationReferenceOccurrenceValue

-- | Closed Core role assigned to the proposal reference.
qualificationReferenceRole ::
     QualificationReference -> CoreQualificationProposalRoleId
qualificationReferenceRole = Internal.qualificationReferenceRoleValue

-- | Stable occurrence identity targeted by the proposal reference.
qualificationReferenceTarget :: QualificationReference -> OccurrenceIdentity
qualificationReferenceTarget = Internal.qualificationReferenceTargetValue

publicEvidenceKind :: GeneratedProfileEvidenceKind -> ProfileEvidenceKind
publicEvidenceKind kind =
  case kind of
    GeneratedProfileEvidenceCarrierOccurrence -> CarrierOccurrenceEvidenceKind
    GeneratedProfileEvidenceClassificationOccurrence ->
      ClassificationOccurrenceEvidenceKind
    GeneratedProfileEvidenceMetadataOwnerAndO2iPropertyOccurrences ->
      MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind
    GeneratedProfileEvidencePropertyOccurrenceEvidence ->
      PropertyOccurrenceEvidenceKind
    GeneratedProfileEvidencePropertySlotEvidence -> PropertySlotEvidenceKind
    GeneratedProfileEvidencePropertyValueEvidence -> PropertyValueEvidenceKind
    GeneratedProfileEvidenceProposalCarrierOccurrence ->
      ProposalCarrierOccurrenceEvidenceKind
    GeneratedProfileEvidenceProposalReferenceIncidence ->
      ProposalReferenceIncidenceEvidenceKind
    GeneratedProfileEvidenceRelationshipOccurrence ->
      RelationshipOccurrenceEvidenceKind
    GeneratedProfileEvidenceReservedPropertyOccurrence ->
      ReservedPropertyOccurrenceEvidenceKind
    GeneratedProfileEvidenceStructuredCarrierOccurrence ->
      StructuredCarrierOccurrenceEvidenceKind
    GeneratedProfileEvidenceStructuredIncidence ->
      StructuredIncidenceEvidenceKind
