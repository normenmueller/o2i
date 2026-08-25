{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Opaque Profile assessment and notation-independent Core projection.
module O2I.ArchiMate.Profile.Projection
  ( ProfileEvidenceKind
  , foldProfileEvidenceKind
  , ProfileEvidence
  , profileEvidenceKind
  , foldProfileEvidence
  , -- | Opaque generated Profile-rule evidence with exact owner indices.
    ProfileDiagnosticEvidence
  , profileDiagnosticRuleId
  , foldProfileDiagnosticEvidence
  , -- | Closed internal contract failure, distinct from model rejection.
    ProfileContractEvidence
  , foldProfileContractEvidence
  , -- | Opaque total outcome of applying Profile projection.
    ProfileProjectionAssessment
  , canonicalOccurrenceIdentity
  , assessSelectedView
  , foldProfileProjectionAssessment
  , -- | Opaque successful notation-independent projection into Core material.
    ProfileProjection
  , withProfileStructureAssessment
  , ProfileClassificationEvidence
  , profileClassificationEvidence
  , foldProfileClassificationEvidence
  , -- | Opaque provenance for one concrete Profile mapping.
    ProfileMappingProvenance
  , profileMappingProvenance
  , profileMappingEvidenceKind
  , foldProfileMappingProvenance
  , -- | Opaque positive proposal invariant with exact owner indices.
    ProfileInvariantEvidence
  , profileQualificationInvariantEvidence
  , foldProfileInvariantEvidence
  , profileQualificationProposals
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
import qualified O2I.ArchiMate.Profile.Internal.Closure as InternalClosure
import O2I.ArchiMate.Profile.Internal.Generated
  ( GeneratedProfileDefectRule
  , GeneratedProfileEvidenceKind(..)
  , generatedProfileDefectRuleId
  , generatedQualificationInvariantRuleId
  )
import O2I.ArchiMate.Profile.Internal.Projection
  ( QualificationProposal
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
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , OccurrenceIdentityDefect
  , SelectedViewScopeDefect
  , buildModelIdentityIndex
  , withSelectedViewScope
  )
import O2I.Structure
  ( StructureAssessment
  , StructureInputDefect
  , assessStructure
  )

-- | Opaque diagnostic evidence nominal in its producing Profile document.
newtype ProfileDiagnosticEvidence profile document =
  ProfileDiagnosticEvidence Internal.ProfileDefect

type role ProfileDiagnosticEvidence nominal nominal

-- | Opaque contract evidence nominal in its producing Profile document.
newtype ProfileContractEvidence profile document =
  ProfileContractEvidence Internal.ProfileContractFailure

type role ProfileContractEvidence nominal nominal

-- | Opaque total result nominal in its producing Profile document.
newtype ProfileProjectionAssessment profile document =
  ProfileProjectionAssessment Internal.ProfileProjectionAssessment

type role ProfileProjectionAssessment nominal nominal

-- | Opaque successful projection nominal in its producing Profile document.
newtype ProfileProjection profile document =
  ProfileProjection Internal.ProfileProjection

type role ProfileProjection nominal nominal

-- | Positive truth-table provenance nominal in its producing Profile document.
newtype ProfileClassificationEvidence profile document =
  ProfileClassificationEvidence InternalClosure.ClassificationProvenance

type role ProfileClassificationEvidence nominal nominal

-- | Concrete mapping provenance nominal in its producing Profile document.
newtype ProfileMappingProvenance profile document =
  ProfileMappingProvenance Internal.ProfileMappingProvenance

type role ProfileMappingProvenance nominal nominal

-- | Positive qualification invariant nominal in its producing Profile document.
newtype ProfileInvariantEvidence profile document =
  ProfileInvariantEvidence Internal.ProfileInvariantEvidence

type role ProfileInvariantEvidence nominal nominal

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
data ProfileEvidence profile document (kind :: ProfileEvidenceKind) where
  CarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence profile document 'CarrierOccurrenceEvidenceKind
  ClassificationOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence profile document 'ClassificationOccurrenceEvidenceKind
  MetadataOwnerAndO2iPropertyOccurrencesEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence
         profile
         document
         'MetadataOwnerAndO2iPropertyOccurrencesEvidenceKind
  PropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ProfileEvidence profile document 'PropertyOccurrenceEvidenceKind
  PropertySlotEvidence
    :: !CanonicalOccurrence
    -> !Text
    -> ![CanonicalOccurrence]
    -> ProfileEvidence profile document 'PropertySlotEvidenceKind
  PropertyValueEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![DraftScalar]
    -> ProfileEvidence profile document 'PropertyValueEvidenceKind
  ProposalCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence profile document 'ProposalCarrierOccurrenceEvidenceKind
  ProposalReferenceIncidenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence profile document 'ProposalReferenceIncidenceEvidenceKind
  RelationshipOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence profile document 'RelationshipOccurrenceEvidenceKind
  ReservedPropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> !Text
    -> ProfileEvidence profile document 'ReservedPropertyOccurrenceEvidenceKind
  StructuredCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence profile document 'StructuredCarrierOccurrenceEvidenceKind
  StructuredIncidenceEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence profile document 'StructuredIncidenceEvidenceKind

type role ProfileEvidence nominal nominal nominal

-- | Runtime witness for the statically indexed evidence shape.
profileEvidenceKind ::
     ProfileEvidence profile document kind -> ProfileEvidenceKind
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
  -> ProfileEvidence profile document kind
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

-- | Generated rule identifier carried by exact scoped Profile evidence.
profileDiagnosticRuleId :: ProfileDiagnosticEvidence profile document -> Text
profileDiagnosticRuleId (ProfileDiagnosticEvidence defect) =
  Internal.profileDefectRuleIdValue defect

-- | Consume a rule identifier paired with evidence of exactly its rule kind.
foldProfileDiagnosticEvidence ::
     forall profile document result.
     (forall kind. Text -> ProfileEvidence profile document kind -> result)
  -> ProfileDiagnosticEvidence profile document
  -> result
foldProfileDiagnosticEvidence consume (ProfileDiagnosticEvidence defect) =
  case defect of
    Internal.ProfileDefect rule evidence -> consumeEvidence rule evidence
  where
    consumeEvidence ::
         forall kind.
         GeneratedProfileDefectRule kind
      -> Internal.ProfileEvidence kind
      -> result
    consumeEvidence rule evidence =
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
foldProfileContractEvidence ::
     (Text -> ProfileEvidenceKind -> result)
  -> (Text -> ProfileEvidenceKind -> result)
  -> (Text -> CanonicalOccurrence -> result)
  -> (CanonicalOccurrence -> Text -> result)
  -> ProfileContractEvidence profile document
  -> result
foldProfileContractEvidence unknown mismatch missing impossible (ProfileContractEvidence failure) =
  case failure of
    Internal.UnknownGeneratedProfileRule rule kind ->
      unknown rule (publicEvidenceKind kind)
    Internal.GeneratedProfileEvidenceMismatch rule kind ->
      mismatch rule (publicEvidenceKind kind)
    Internal.MissingCoreContractBinding binding occurrence ->
      missing binding occurrence
    Internal.ImpossibleOccurrenceIdentity occurrence details ->
      impossible occurrence details

-- | Project one canonical Profile occurrence into its normalized Core identity.
--
-- The result preserves the Core identity boundary as a total outcome. Profile
-- owns the exact ArchiMate occurrence grammar; callers cannot configure or
-- reproduce that grammar independently.
canonicalOccurrenceIdentity ::
     CanonicalOccurrence -> Either OccurrenceIdentityDefect OccurrenceIdentity
canonicalOccurrenceIdentity = Internal.canonicalOccurrenceIdentityValue

-- | Apply the compiled Profile contract after exact Notation conformance.
--
-- The total result separates internal contract failure from model rejection
-- and successful projection. Profile maps notation into Core material; it does
-- not define additional fachliche semantics.
assessSelectedView ::
     NotationConformantUniverse profile document
  -> ProfileProjectionAssessment profile document
assessSelectedView =
  ProfileProjectionAssessment . Internal.assessSelectedViewValue

-- | Distinguish contract failure, model rejection, and exact projection.
foldProfileProjectionAssessment ::
     (NonEmpty (ProfileContractEvidence profile document) -> result)
  -> (NonEmpty (ProfileDiagnosticEvidence profile document) -> result)
  -> (ProfileProjection profile document -> result)
  -> ProfileProjectionAssessment profile document
  -> result
foldProfileProjectionAssessment contractFailure rejected accepted (ProfileProjectionAssessment assessment) =
  case assessment of
    Internal.ProfileContractFailed failures ->
      contractFailure (ProfileContractEvidence <$> failures)
    Internal.ProfileRejected defects ->
      rejected (ProfileDiagnosticEvidence <$> defects)
    Internal.ProfileAccepted projection ->
      accepted (ProfileProjection projection)

-- | Assess the inseparable Profile-owned Core input under one fresh scope.
--
-- The selected View subject, Structure projection, complete model identity
-- domain, and graph membership never leave this elimination independently. A
-- caller therefore cannot combine any of them from different Profile
-- documents.
withProfileStructureAssessment ::
     ProfileProjection profile document
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (forall scope. StructureAssessment scope -> result)
  -> result
withProfileStructureAssessment (ProfileProjection projection) identityFailure scopeFailure structureFailure consume =
  case buildModelIdentityIndex
         (Internal.profileModelIdentityOccurrencesValue projection) of
    Left defects -> identityFailure defects
    Right index ->
      case withSelectedViewScope
             index
             (Internal.profileSelectedViewValue projection)
             (Internal.profileSelectedOccurrencesValue projection)
             (\scope ->
                case assessStructure
                       scope
                       (Internal.profileStructureProjectionValue projection) of
                  Left defects -> structureFailure defects
                  Right assessment -> consume assessment) of
        Left defects -> scopeFailure defects
        Right result -> result

-- | Classified root and displayed occurrences retained by this exact result.
profileClassificationEvidence ::
     ProfileProjection profile document
  -> [ProfileClassificationEvidence profile document]
profileClassificationEvidence (ProfileProjection projection) =
  map
    ProfileClassificationEvidence
    (Internal.profileClassificationProvenanceValue projection)

-- | Consume positive classification provenance without exposing its owner.
foldProfileClassificationEvidence ::
     (Bool -> Bool -> Text -> CanonicalOccurrence -> result)
  -> ProfileClassificationEvidence profile document
  -> result
foldProfileClassificationEvidence consume (ProfileClassificationEvidence evidence) =
  consume
    (InternalClosure.classificationProvenanceGraphMembershipValue evidence)
    (InternalClosure.classificationProvenanceQualificationMembershipValue
       evidence)
    (InternalClosure.classificationProvenanceRuleIdValue evidence)
    (InternalClosure.classificationProvenanceOccurrenceValue evidence)

-- | Canonically ordered concrete mapping provenance retained by the Profile.
profileMappingProvenance ::
     ProfileProjection profile document
  -> [ProfileMappingProvenance profile document]
profileMappingProvenance (ProfileProjection projection) =
  map
    ProfileMappingProvenance
    (Internal.profileMappingProvenanceValue projection)

-- | Generated evidence form carried by one real concrete mapping.
profileMappingEvidenceKind ::
     ProfileMappingProvenance profile document -> ProfileEvidenceKind
profileMappingEvidenceKind (ProfileMappingProvenance provenance) =
  case provenance of
    Internal.CarrierMappingProvenance _ _ _ -> CarrierOccurrenceEvidenceKind
    Internal.RelationMappingProvenance _ _ _ _ _ ->
      RelationshipOccurrenceEvidenceKind
    Internal.ConstructionMappingProvenance _ _ _ evidenceKind ->
      publicEvidenceKind evidenceKind

-- | Consume carrier, relationship, or construction mapping provenance without
-- exposing its representation.
foldProfileMappingProvenance ::
     (Text -> OccurrenceIdentity -> Text -> result)
  -> (Text -> OccurrenceIdentity -> Text -> OccurrenceIdentity -> OccurrenceIdentity -> result)
  -> (Text -> OccurrenceIdentity -> Text -> result)
  -> ProfileMappingProvenance profile document
  -> result
foldProfileMappingProvenance carrier relation construction (ProfileMappingProvenance provenance) =
  case provenance of
    Internal.CarrierMappingProvenance occurrence ruleId mappingId ->
      carrier ruleId occurrence mappingId
    Internal.RelationMappingProvenance occurrence ruleId mappingId source target ->
      relation ruleId occurrence mappingId source target
    Internal.ConstructionMappingProvenance occurrence ruleId mappingId _ ->
      construction ruleId occurrence mappingId

-- | Two constant positive facts for each actually projected proposal.
profileQualificationInvariantEvidence ::
     ProfileProjection profile document
  -> [ProfileInvariantEvidence profile document]
profileQualificationInvariantEvidence (ProfileProjection projection) =
  map
    ProfileInvariantEvidence
    (Internal.profileInvariantEvidenceValue projection)

-- | Consume one generated qualification-invariant rule paired with the
-- existing proposal-carrier occurrence evidence form.
foldProfileInvariantEvidence ::
     (Text -> ProfileEvidence
                profile
                document
                'ProposalCarrierOccurrenceEvidenceKind -> result)
  -> ProfileInvariantEvidence profile document
  -> result
foldProfileInvariantEvidence consume (ProfileInvariantEvidence invariantEvidence) =
  case invariantEvidence of
    Internal.ProfileInvariantEvidence rule evidence ->
      case evidence of
        Internal.ProposalCarrierOccurrenceEvidence occurrence ->
          consume
            (generatedQualificationInvariantRuleId rule)
            (ProposalCarrierOccurrenceEvidence occurrence)

-- | Qualification proposals retained separately from the structure graph.
profileQualificationProposals ::
     ProfileProjection profile document -> [QualificationProposal]
profileQualificationProposals (ProfileProjection projection) =
  Internal.profileQualificationProposalsValue projection

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
