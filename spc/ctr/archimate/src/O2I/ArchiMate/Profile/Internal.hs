{-# LANGUAGE OverloadedStrings #-}

-- | Internal typed projection of the declarative ArchiMate profile contract.
--
-- The JSON contract is authoritative. This module is the closed executable
-- projection checked for complete equality with that contract.
module O2I.ArchiMate.Profile.Internal
  ( ArchiMateProfileContract
  , ApplicabilityProvenance
  , MatrixImplementation
  , SymbolInterpretation
  , ApplicabilityDecision
  , MetadataContract
  , MetadataKind(..)
  , CarrierType(..)
  , CarrierMapping
  , Requirement
  , Cardinality
  , ArchiMateRelationshipRepresentation
  , ArchiMateRelationMapping
  , ContextualizationContract
  , CollectiveContract
  , CollectiveCarrierContract
  , CollectiveSegmentContract
  , CollectiveContributorsContract
  , CollectiveTargetContract
  , profileContract
  , profileVersionText
  , contractSchema
  , contractProfileVersion
  , contractApplicabilityProvenance
  , applicabilityArchiMateStandardVersion
  , applicabilityMatrixImplementation
  , applicabilitySymbolInterpretations
  , applicabilityDecisions
  , matrixImplementationRepositoryUri
  , matrixImplementationRepositoryRelativePath
  , matrixImplementationRevision
  , symbolInterpretationSymbol
  , symbolInterpretationRelationship
  , applicabilityDecisionRelationMapping
  , applicabilityDecisionRelationMappingId
  , applicabilityDecisionSourceElement
  , applicabilityDecisionTargetElement
  , applicabilityDecisionMatrixSymbol
  , contractMetadata
  , contractCarrierMappings
  , contractRelationMappings
  , contractContextualization
  , contractCollectiveRealization
  , modelProfileKey
  , modelProfileCardinality
  , modelAdditionalO2IProperties
  , carrierKindKey
  , carrierTypeKey
  , carrierCommitmentKey
  , carrierCommitmentValues
  , carrierMetadataCardinality
  , carrierAdditionalO2IProperties
  , relationCommitmentKey
  , relationCommitmentValues
  , relationMetadataCardinality
  , relationAdditionalO2IProperties
  , metadataKindText
  , metadataKindFromText
  , carrierTypeText
  , carrierTypeFromText
  , carrierTypeForNodeKind
  , carrierMappingId
  , carrierMappingKind
  , carrierMappingTypes
  , carrierMappingElement
  , carrierMappingOwnership
  , carrierMappingFor
  , relationMappings
  , relationMappingId
  , relationMappingCode
  , relationMappingName
  , relationMappingLabel
  , relationMappingSource
  , relationMappingTarget
  , relationMappingRepresentation
  , nodeKindIdentifier
  , expectedRelationshipLabel
  , expectedRelationshipRepresentation
  , relationshipRepresentation
  , relationshipTypeName
  , relationshipDirected
  , relationshipRepresentationText
  , contextualizationId
  , contextualizationRepresentation
  , contextualizationLabel
  , contextualizationSourceKind
  , contextualizationTargetKinds
  , contextualizationIncomingCardinality
  , contextualizationMetadata
  , contextualizationProjection
  , collectiveId
  , collectiveCarrier
  , collectiveSegments
  , collectiveContributors
  , collectiveTarget
  , collectiveJunctionChains
  , collectiveProjection
  , collectiveCarrierKind
  , collectiveCarrierType
  , collectiveCarrierElement
  , collectiveJunctionType
  , collectiveCommitmentKey
  , collectiveCommitmentValues
  , collectiveFitEvidenceKey
  , collectiveFitEvidenceCardinality
  , collectiveAdditionalO2IProperties
  , collectiveSegmentRepresentation
  , collectiveSegmentLabel
  , collectiveSegmentMetadata
  , collectiveContributorEndpoint
  , collectiveContributorCardinality
  , collectiveContributorsDistinct
  , collectiveTargetEndpoint
  , collectiveTargetCardinality
  , collectiveTargetDistinctFromContributors
  , requirementText
  , requirementIsRequired
  , requirementIsForbidden
  , cardinalityText
  , cardinalityAccepts
  , commitmentText
  , commitmentFromText
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I
  ( AnchorRelationFamily(..)
  , Commitment(..)
  , Context(..)
  , FixedRelationCode(..)
  , NodeKindValue(..)
  , Primitive(..)
  , RelationCode(..)
  , RelationName(..)
  , SituationAnchor(..)
  , SomeRelation
  , Structuring(..)
  , allRelations
  , relationCodeOf
  , relationIdentity
  )
import O2I.Inspection.Profile
  ( O2IProfileVersion
  , o2iProfileVersionLiteral
  , profileVersionText
  )
import O2I.Language (reifyRelation)

-- | Complete compile-time projection of the ArchiMate profile contract.
data ArchiMateProfileContract = ArchiMateProfileContract
  { contractSchemaValue :: Text
    -- ^ Stable schema identifier of the declarative contract.
  , contractProfileVersionValue :: O2IProfileVersion
    -- ^ Exact O2I profile version implemented by this projection.
  , contractApplicabilityProvenanceValue :: ApplicabilityProvenance
    -- ^ Reproducible source evidence for ArchiMate applicability decisions.
  , contractMetadataValue :: MetadataContract
    -- ^ Persisted metadata placement and cardinality contract.
  , contractCarrierMappingsValue :: [CarrierMapping]
    -- ^ Carrier mappings in authoritative order.
  , contractRelationMappingsValue :: [ArchiMateRelationMapping]
    -- ^ Relation mappings in authoritative core-registry order.
  , contractContextualizationValue :: ContextualizationContract
    -- ^ Exact contextualization syntax.
  , contractCollectiveRealizationValue :: CollectiveContract
    -- ^ Exact collective Strategy-realization syntax.
  } deriving (Eq, Show)

-- | Closed provenance for the ArchiMate applicability evidence used here.
data ApplicabilityProvenance = ApplicabilityProvenance
  { applicabilityArchiMateStandardVersionValue :: Text
    -- ^ ArchiMate standard version interpreted by the profile.
  , applicabilityMatrixImplementationValue :: MatrixImplementation
    -- ^ Exact implementation source of the admitted relationship matrix.
  , applicabilitySymbolInterpretationsValue :: NonEmpty SymbolInterpretation
    -- ^ Closed interpretation of matrix symbols used by decisions.
  , applicabilityDecisionsValue :: NonEmpty ApplicabilityDecision
    -- ^ Profile mappings justified through exact matrix coordinates.
  } deriving (Eq, Show)

-- | Exact repository source of one admitted relationship-matrix implementation.
data MatrixImplementation = MatrixImplementation
  { matrixImplementationRepositoryUriValue :: Text
  , matrixImplementationRepositoryRelativePathValue :: Text
  , matrixImplementationRevisionValue :: Text
  } deriving (Eq, Show)

-- | One matrix symbol and its exact ArchiMate relationship interpretation.
data SymbolInterpretation = SymbolInterpretation
  { symbolInterpretationSymbolValue :: Text
  , symbolInterpretationRelationshipValue :: ArchiMateRelationshipRepresentation
  } deriving (Eq, Show)

-- | One applicability decision tied to typed profile mapping values.
data ApplicabilityDecision = ApplicabilityDecision
  { applicabilityDecisionRelationMappingValue :: ArchiMateRelationMapping
  , applicabilityDecisionSymbolInterpretationValue :: SymbolInterpretation
  } deriving (Eq, Show)

-- | Exact persisted metadata keys, cardinalities, and closed values.
data MetadataContract = MetadataContract
  { modelProfileKeyValue :: Text
    -- ^ Root property selecting the O2I profile.
  , modelProfileCardinalityValue :: Cardinality
    -- ^ Required root-property cardinality.
  , modelAdditionalO2IPropertiesValue :: Requirement
    -- ^ Policy for additional root-level O2I properties.
  , carrierKindKeyValue :: Text
    -- ^ Property identifying the O2I carrier kind.
  , carrierTypeKeyValue :: Text
    -- ^ Property identifying the O2I carrier type.
  , carrierCommitmentKeyValue :: Text
    -- ^ Property carrying proposition commitment on typed carriers.
  , carrierCommitmentValuesValue :: NonEmpty Commitment
    -- ^ Closed carrier commitment vocabulary.
  , carrierMetadataCardinalityValue :: Cardinality
    -- ^ Cardinality of required carrier metadata properties.
  , carrierAdditionalO2IPropertiesValue :: Requirement
    -- ^ Policy for additional carrier-level O2I properties.
  , relationCommitmentKeyValue :: Text
    -- ^ Property carrying proposition commitment on semantic relations.
  , relationCommitmentValuesValue :: NonEmpty Commitment
    -- ^ Closed semantic-relation commitment vocabulary.
  , relationMetadataCardinalityValue :: Cardinality
    -- ^ Required relation commitment cardinality.
  , relationAdditionalO2IPropertiesValue :: Requirement
    -- ^ Policy for additional relation-level O2I properties.
  } deriving (Eq, Show)

-- | Closed persisted @o2i.kind@ universe.
data MetadataKind
  = ContextMetadata
  | PrimitiveMetadata
  | StructuringMetadata
  | SituationAnchorMetadata
  | StructuredPropositionMetadata
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed persisted carrier type with its semantic runtime value.
data CarrierType
  = ContextCarrier Context
  | PrimitiveCarrier Primitive
  | StructuringCarrier Structuring
  | SituationAnchorCarrier SituationAnchor
  deriving (Eq, Ord, Show)

-- | One exact carrier mapping in canonical contract order.
data CarrierMapping = CarrierMapping
  { carrierMappingIdValue :: Text
  , carrierMappingTypesValue :: NonEmpty CarrierType
  , carrierMappingArchiElementValue :: Text
  , carrierMappingContextOwnershipValue :: Requirement
  } deriving (Eq, Show)

-- | Closed contract requirement vocabulary.
data Requirement
  = Required
  | Forbidden
  deriving (Eq, Ord, Show)

-- | Closed contract cardinality vocabulary.
data Cardinality
  = ExactlyOne
  | ExactlyOneEach
  | ExactlyOneNonEmpty
  | AtLeastTwo
  deriving (Eq, Ord, Show)

-- | Exact native relationship kind and Association direction flag.
data ArchiMateRelationshipRepresentation = ArchiMateRelationshipRepresentation
  { relationshipTypeNameValue :: Text
    -- ^ Exact ArchiMate relationship metaclass name.
  , relationshipDirectedValue :: Bool
    -- ^ Whether an Association is explicitly directed.
  } deriving (Eq, Ord, Show)

-- | One core relation enriched with its exact ArchiMate representation.
data ArchiMateRelationMapping = ArchiMateRelationMapping
  { relationMappingIdValue :: Text
    -- ^ Stable identifier of this concrete mapping.
  , relationMappingCodeValue :: RelationCode
    -- ^ Notation-independent relation code.
  , relationMappingNameValue :: RelationName
    -- ^ Persisted O2I relation name.
  , relationMappingLabelValue :: Text
    -- ^ Exact ArchiMate relationship label.
  , relationMappingSourceValue :: NodeKindValue
    -- ^ Required source endpoint kind.
  , relationMappingTargetValue :: NodeKindValue
    -- ^ Required target endpoint kind.
  , relationMappingRepresentationValue :: ArchiMateRelationshipRepresentation
    -- ^ Required ArchiMate relationship representation.
  } deriving (Eq, Show)

-- | Exact native contextualization pattern.
data ContextualizationContract = ContextualizationContract
  { contextualizationIdValue :: Text
    -- ^ Stable structured-pattern identifier.
  , contextualizationRepresentationValue :: ArchiMateRelationshipRepresentation
    -- ^ Required relationship representation.
  , contextualizationLabelValue :: Text
    -- ^ Exact contextualization label.
  , contextualizationSourceKindValue :: MetadataKind
    -- ^ Required source carrier kind.
  , contextualizationTargetKindsValue :: NonEmpty MetadataKind
    -- ^ Allowed target carrier kinds.
  , contextualizationIncomingCardinalityValue :: Cardinality
    -- ^ Required incoming contextualization cardinality.
  , contextualizationMetadataValue :: Requirement
    -- ^ Policy for metadata on the relationship carrier.
  , contextualizationProjectionValue :: Text
    -- ^ Stable projection role.
  } deriving (Eq, Show)

-- | Exact native collective Strategy-realization pattern.
data CollectiveContract = CollectiveContract
  { collectiveIdValue :: Text
    -- ^ Stable structured-pattern identifier.
  , collectiveCarrierValue :: CollectiveCarrierContract
    -- ^ Junction-carrier contract.
  , collectiveSegmentsValue :: CollectiveSegmentContract
    -- ^ Incoming and outgoing segment contract.
  , collectiveContributorsValue :: CollectiveContributorsContract
    -- ^ Contributor endpoint contract.
  , collectiveTargetValue :: CollectiveTargetContract
    -- ^ Target endpoint contract.
  , collectiveJunctionChainsValue :: Requirement
    -- ^ Policy for Junction-to-Junction chains.
  , collectiveProjectionValue :: Text
    -- ^ Stable projection role.
  } deriving (Eq, Show)

-- | Carrier portion of the collective realization contract.
data CollectiveCarrierContract = CollectiveCarrierContract
  { collectiveCarrierKindValue :: MetadataKind
    -- ^ Required O2I carrier kind.
  , collectiveCarrierTypeValue :: Text
    -- ^ Required O2I carrier type.
  , collectiveCarrierElementValue :: Text
    -- ^ Required ArchiMate element metaclass.
  , collectiveJunctionTypeValue :: Text
    -- ^ Required ArchiMate Junction type.
  , collectiveCommitmentKeyValue :: Text
    -- ^ Property carrying the collective proposition commitment.
  , collectiveCommitmentValuesValue :: NonEmpty Commitment
    -- ^ Closed collective commitment vocabulary.
  , collectiveFitEvidenceKeyValue :: Text
    -- ^ Property referencing collective Fit evidence.
  , collectiveFitEvidenceCardinalityValue :: Cardinality
    -- ^ Required collective Fit evidence cardinality.
  , collectiveAdditionalO2IPropertiesValue :: Requirement
    -- ^ Policy for additional carrier-level O2I properties.
  } deriving (Eq, Show)

-- | Segment portion of the collective realization contract.
data CollectiveSegmentContract = CollectiveSegmentContract
  { collectiveSegmentRepresentationValue :: ArchiMateRelationshipRepresentation
    -- ^ Required segment relationship representation.
  , collectiveSegmentLabelValue :: Text
    -- ^ Exact segment label.
  , collectiveSegmentMetadataValue :: Requirement
    -- ^ Policy for O2I metadata on segments.
  } deriving (Eq, Show)

-- | Contributor portion of the collective realization contract.
data CollectiveContributorsContract = CollectiveContributorsContract
  { collectiveContributorEndpointValue :: NodeKindValue
    -- ^ Required contributor endpoint kind.
  , collectiveContributorCardinalityValue :: Cardinality
    -- ^ Required number of contributors.
  , collectiveContributorsDistinctValue :: Requirement
    -- ^ Whether contributors must be distinct.
  } deriving (Eq, Show)

-- | Target portion of the collective realization contract.
data CollectiveTargetContract = CollectiveTargetContract
  { collectiveTargetEndpointValue :: NodeKindValue
    -- ^ Required target endpoint kind.
  , collectiveTargetCardinalityValue :: Cardinality
    -- ^ Required number of targets.
  , collectiveTargetDistinctFromContributorsValue :: Requirement
    -- ^ Whether the target must differ from every contributor.
  } deriving (Eq, Show)

contractSchema :: ArchiMateProfileContract -> Text
contractSchema = contractSchemaValue

-- | Exact O2I profile version implemented by this contract.
contractProfileVersion :: ArchiMateProfileContract -> O2IProfileVersion
contractProfileVersion = contractProfileVersionValue

-- | Reproducible evidence supporting ArchiMate applicability decisions.
contractApplicabilityProvenance ::
     ArchiMateProfileContract -> ApplicabilityProvenance
contractApplicabilityProvenance = contractApplicabilityProvenanceValue

-- | ArchiMate standard version interpreted by the profile.
applicabilityArchiMateStandardVersion :: ApplicabilityProvenance -> Text
applicabilityArchiMateStandardVersion =
  applicabilityArchiMateStandardVersionValue

-- | Exact relationship-matrix implementation used as applicability evidence.
applicabilityMatrixImplementation ::
     ApplicabilityProvenance -> MatrixImplementation
applicabilityMatrixImplementation = applicabilityMatrixImplementationValue

-- | Closed matrix-symbol interpretations used by applicability decisions.
applicabilitySymbolInterpretations ::
     ApplicabilityProvenance -> NonEmpty SymbolInterpretation
applicabilitySymbolInterpretations = applicabilitySymbolInterpretationsValue

-- | Profile mappings justified by exact relationship-matrix coordinates.
applicabilityDecisions ::
     ApplicabilityProvenance -> NonEmpty ApplicabilityDecision
applicabilityDecisions = applicabilityDecisionsValue

-- | Repository URI of the admitted matrix implementation.
matrixImplementationRepositoryUri :: MatrixImplementation -> Text
matrixImplementationRepositoryUri = matrixImplementationRepositoryUriValue

-- | Repository-relative path of the admitted matrix implementation.
matrixImplementationRepositoryRelativePath :: MatrixImplementation -> Text
matrixImplementationRepositoryRelativePath =
  matrixImplementationRepositoryRelativePathValue

-- | Exact 40-hex source revision of the admitted matrix implementation.
matrixImplementationRevision :: MatrixImplementation -> Text
matrixImplementationRevision = matrixImplementationRevisionValue

-- | Exact symbol used by an admitted relationship-matrix coordinate.
symbolInterpretationSymbol :: SymbolInterpretation -> Text
symbolInterpretationSymbol = symbolInterpretationSymbolValue

-- | ArchiMate relationship represented by one matrix symbol.
symbolInterpretationRelationship ::
     SymbolInterpretation -> ArchiMateRelationshipRepresentation
symbolInterpretationRelationship = symbolInterpretationRelationshipValue

applicabilityDecisionRelationMapping ::
     ApplicabilityDecision -> ArchiMateRelationMapping
applicabilityDecisionRelationMapping = applicabilityDecisionRelationMappingValue

-- | Stable profile-mapping identifier justified by this decision.
applicabilityDecisionRelationMappingId :: ApplicabilityDecision -> Text
applicabilityDecisionRelationMappingId =
  relationMappingId . applicabilityDecisionRelationMapping

-- | Source matrix coordinate derived from the mapping's typed source carrier.
applicabilityDecisionSourceElement :: ApplicabilityDecision -> Text
applicabilityDecisionSourceElement =
  carrierElementForNodeKind
    . relationMappingSource
    . applicabilityDecisionRelationMapping

-- | Target matrix coordinate derived from the mapping's typed target carrier.
applicabilityDecisionTargetElement :: ApplicabilityDecision -> Text
applicabilityDecisionTargetElement =
  carrierElementForNodeKind
    . relationMappingTarget
    . applicabilityDecisionRelationMapping

-- | Matrix symbol referenced by this decision.
applicabilityDecisionMatrixSymbol :: ApplicabilityDecision -> Text
applicabilityDecisionMatrixSymbol =
  symbolInterpretationSymbol . applicabilityDecisionSymbolInterpretationValue

carrierElementForNodeKind :: NodeKindValue -> Text
carrierElementForNodeKind =
  carrierMappingElement . carrierMappingFor . carrierTypeForNodeKind

-- | Persisted metadata contract.
contractMetadata :: ArchiMateProfileContract -> MetadataContract
contractMetadata = contractMetadataValue

contractCarrierMappings :: ArchiMateProfileContract -> [CarrierMapping]
contractCarrierMappings = contractCarrierMappingsValue

contractRelationMappings ::
     ArchiMateProfileContract -> [ArchiMateRelationMapping]
contractRelationMappings = contractRelationMappingsValue

-- | Concrete contextualization pattern.
contractContextualization ::
     ArchiMateProfileContract -> ContextualizationContract
contractContextualization = contractContextualizationValue

-- | Concrete collective Strategy-realization pattern.
contractCollectiveRealization :: ArchiMateProfileContract -> CollectiveContract
contractCollectiveRealization = contractCollectiveRealizationValue

-- | Root property selecting the O2I profile.
modelProfileKey :: MetadataContract -> Text
modelProfileKey = modelProfileKeyValue

-- | Required profile-property cardinality at model root.
modelProfileCardinality :: MetadataContract -> Cardinality
modelProfileCardinality = modelProfileCardinalityValue

-- | Policy for additional root-level O2I properties.
modelAdditionalO2IProperties :: MetadataContract -> Requirement
modelAdditionalO2IProperties = modelAdditionalO2IPropertiesValue

-- | Property identifying a carrier's O2I kind.
carrierKindKey :: MetadataContract -> Text
carrierKindKey = carrierKindKeyValue

-- | Property identifying a carrier's O2I type.
carrierTypeKey :: MetadataContract -> Text
carrierTypeKey = carrierTypeKeyValue

-- | Property carrying commitment on a typed carrier.
carrierCommitmentKey :: MetadataContract -> Text
carrierCommitmentKey = carrierCommitmentKeyValue

carrierCommitmentValues :: MetadataContract -> NonEmpty Commitment
carrierCommitmentValues = carrierCommitmentValuesValue

carrierMetadataCardinality :: MetadataContract -> Cardinality
carrierMetadataCardinality = carrierMetadataCardinalityValue

carrierAdditionalO2IProperties :: MetadataContract -> Requirement
carrierAdditionalO2IProperties = carrierAdditionalO2IPropertiesValue

-- | Property carrying commitment on a semantic relation.
relationCommitmentKey :: MetadataContract -> Text
relationCommitmentKey = relationCommitmentKeyValue

relationCommitmentValues :: MetadataContract -> NonEmpty Commitment
relationCommitmentValues = relationCommitmentValuesValue

relationMetadataCardinality :: MetadataContract -> Cardinality
relationMetadataCardinality = relationMetadataCardinalityValue

relationAdditionalO2IProperties :: MetadataContract -> Requirement
relationAdditionalO2IProperties = relationAdditionalO2IPropertiesValue

-- | Exact ArchiMate relationship metaclass name.
relationshipTypeName :: ArchiMateRelationshipRepresentation -> Text
relationshipTypeName = relationshipTypeNameValue

-- | Whether an ArchiMate Association is explicitly directed.
relationshipDirected :: ArchiMateRelationshipRepresentation -> Bool
relationshipDirected = relationshipDirectedValue

relationMappingId :: ArchiMateRelationMapping -> Text
relationMappingId = relationMappingIdValue

-- | Notation-independent relation code of a concrete mapping.
relationMappingCode :: ArchiMateRelationMapping -> RelationCode
relationMappingCode = relationMappingCodeValue

-- | Persisted O2I relation name of a concrete mapping.
relationMappingName :: ArchiMateRelationMapping -> RelationName
relationMappingName = relationMappingNameValue

-- | Exact ArchiMate label of a concrete relation mapping.
relationMappingLabel :: ArchiMateRelationMapping -> Text
relationMappingLabel = relationMappingLabelValue

-- | Required source endpoint kind of a concrete relation mapping.
relationMappingSource :: ArchiMateRelationMapping -> NodeKindValue
relationMappingSource = relationMappingSourceValue

-- | Required target endpoint kind of a concrete relation mapping.
relationMappingTarget :: ArchiMateRelationMapping -> NodeKindValue
relationMappingTarget = relationMappingTargetValue

-- | Required ArchiMate representation of a concrete relation mapping.
relationMappingRepresentation ::
     ArchiMateRelationMapping -> ArchiMateRelationshipRepresentation
relationMappingRepresentation = relationMappingRepresentationValue

contextualizationId :: ContextualizationContract -> Text
contextualizationId = contextualizationIdValue

-- | ArchiMate representation of contextualization.
contextualizationRepresentation ::
     ContextualizationContract -> ArchiMateRelationshipRepresentation
contextualizationRepresentation = contextualizationRepresentationValue

-- | Exact relationship label of contextualization.
contextualizationLabel :: ContextualizationContract -> Text
contextualizationLabel = contextualizationLabelValue

contextualizationSourceKind :: ContextualizationContract -> MetadataKind
contextualizationSourceKind = contextualizationSourceKindValue

contextualizationTargetKinds ::
     ContextualizationContract -> NonEmpty MetadataKind
contextualizationTargetKinds = contextualizationTargetKindsValue

contextualizationIncomingCardinality :: ContextualizationContract -> Cardinality
contextualizationIncomingCardinality = contextualizationIncomingCardinalityValue

contextualizationMetadata :: ContextualizationContract -> Requirement
contextualizationMetadata = contextualizationMetadataValue

contextualizationProjection :: ContextualizationContract -> Text
contextualizationProjection = contextualizationProjectionValue

collectiveId :: CollectiveContract -> Text
collectiveId = collectiveIdValue

-- | Junction-carrier portion of collective Strategy realization.
collectiveCarrier :: CollectiveContract -> CollectiveCarrierContract
collectiveCarrier = collectiveCarrierValue

-- | Segment portion of collective Strategy realization.
collectiveSegments :: CollectiveContract -> CollectiveSegmentContract
collectiveSegments = collectiveSegmentsValue

-- | Contributor portion of collective Strategy realization.
collectiveContributors :: CollectiveContract -> CollectiveContributorsContract
collectiveContributors = collectiveContributorsValue

-- | Target portion of collective Strategy realization.
collectiveTarget :: CollectiveContract -> CollectiveTargetContract
collectiveTarget = collectiveTargetValue

-- | Policy for Junction-to-Junction chains.
collectiveJunctionChains :: CollectiveContract -> Requirement
collectiveJunctionChains = collectiveJunctionChainsValue

collectiveProjection :: CollectiveContract -> Text
collectiveProjection = collectiveProjectionValue

-- | Required O2I kind of the collective Junction carrier.
collectiveCarrierKind :: CollectiveCarrierContract -> MetadataKind
collectiveCarrierKind = collectiveCarrierKindValue

-- | Required O2I type of the collective Junction carrier.
collectiveCarrierType :: CollectiveCarrierContract -> Text
collectiveCarrierType = collectiveCarrierTypeValue

-- | Required ArchiMate element type of the collective carrier.
collectiveCarrierElement :: CollectiveCarrierContract -> Text
collectiveCarrierElement = collectiveCarrierElementValue

-- | Required native ArchiMate Junction type.
collectiveJunctionType :: CollectiveCarrierContract -> Text
collectiveJunctionType = collectiveJunctionTypeValue

-- | Property carrying commitment on the collective proposition.
collectiveCommitmentKey :: CollectiveCarrierContract -> Text
collectiveCommitmentKey = collectiveCommitmentKeyValue

collectiveCommitmentValues :: CollectiveCarrierContract -> NonEmpty Commitment
collectiveCommitmentValues = collectiveCommitmentValuesValue

-- | Property referencing collective Fit evidence.
collectiveFitEvidenceKey :: CollectiveCarrierContract -> Text
collectiveFitEvidenceKey = collectiveFitEvidenceKeyValue

collectiveFitEvidenceCardinality :: CollectiveCarrierContract -> Cardinality
collectiveFitEvidenceCardinality = collectiveFitEvidenceCardinalityValue

collectiveAdditionalO2IProperties :: CollectiveCarrierContract -> Requirement
collectiveAdditionalO2IProperties = collectiveAdditionalO2IPropertiesValue

-- | ArchiMate representation required for collective segments.
collectiveSegmentRepresentation ::
     CollectiveSegmentContract -> ArchiMateRelationshipRepresentation
collectiveSegmentRepresentation = collectiveSegmentRepresentationValue

-- | Exact relationship label required for collective segments.
collectiveSegmentLabel :: CollectiveSegmentContract -> Text
collectiveSegmentLabel = collectiveSegmentLabelValue

-- | Policy for O2I metadata on collective segments.
collectiveSegmentMetadata :: CollectiveSegmentContract -> Requirement
collectiveSegmentMetadata = collectiveSegmentMetadataValue

collectiveContributorEndpoint :: CollectiveContributorsContract -> NodeKindValue
collectiveContributorEndpoint = collectiveContributorEndpointValue

-- | Required number of distinct contributor Strategies.
collectiveContributorCardinality ::
     CollectiveContributorsContract -> Cardinality
collectiveContributorCardinality = collectiveContributorCardinalityValue

-- | Whether contributor Strategies must be distinct.
collectiveContributorsDistinct :: CollectiveContributorsContract -> Requirement
collectiveContributorsDistinct = collectiveContributorsDistinctValue

collectiveTargetEndpoint :: CollectiveTargetContract -> NodeKindValue
collectiveTargetEndpoint = collectiveTargetEndpointValue

-- | Required number of target Strategies.
collectiveTargetCardinality :: CollectiveTargetContract -> Cardinality
collectiveTargetCardinality = collectiveTargetCardinalityValue

-- | Whether the target must differ from every contributor.
collectiveTargetDistinctFromContributors ::
     CollectiveTargetContract -> Requirement
collectiveTargetDistinctFromContributors =
  collectiveTargetDistinctFromContributorsValue

-- | Complete typed profile projection in contract order.
profileContract :: ArchiMateProfileContract
profileContract =
  ArchiMateProfileContract
    { contractSchemaValue = "o2i.archimate-profile/v2"
    , contractProfileVersionValue = o2iProfileVersionLiteral ('0' :| ".3")
    , contractApplicabilityProvenanceValue = applicabilityProvenance
    , contractMetadataValue = metadataContract
    , contractCarrierMappingsValue = carrierMappings
    , contractRelationMappingsValue = relationMappings
    , contractContextualizationValue = contextualizationContract
    , contractCollectiveRealizationValue = collectiveContract
    }

applicabilityProvenance :: ApplicabilityProvenance
applicabilityProvenance =
  ApplicabilityProvenance
    { applicabilityArchiMateStandardVersionValue = "3.2"
    , applicabilityMatrixImplementationValue = matrixImplementation
    , applicabilitySymbolInterpretationsValue = influenceSymbol :| []
    , applicabilityDecisionsValue = directsStrategyDecision :| []
    }

matrixImplementation :: MatrixImplementation
matrixImplementation =
  MatrixImplementation
    { matrixImplementationRepositoryUriValue =
        "https://github.com/archimatetool/archi"
    , matrixImplementationRepositoryRelativePathValue =
        "com.archimatetool.model/model/relationships.xml"
    , matrixImplementationRevisionValue =
        "b5bd0038922ab68b26eb78c97ff7efc2ff0bba82"
    }

influenceSymbol :: SymbolInterpretation
influenceSymbol = SymbolInterpretation "n" influence

directsStrategyDecision :: ApplicabilityDecision
directsStrategyDecision =
  ApplicabilityDecision
    { applicabilityDecisionRelationMappingValue =
        relationMapping (reifyRelation (FixedRelation DirectsStrategyCode))
    , applicabilityDecisionSymbolInterpretationValue = influenceSymbol
    }

metadataContract :: MetadataContract
metadataContract =
  MetadataContract
    { modelProfileKeyValue = "o2i.profile"
    , modelProfileCardinalityValue = ExactlyOne
    , modelAdditionalO2IPropertiesValue = Forbidden
    , carrierKindKeyValue = "o2i.kind"
    , carrierTypeKeyValue = "o2i.type"
    , carrierCommitmentKeyValue = "o2i.commitment"
    , carrierCommitmentValuesValue = Candidate :| [Asserted]
    , carrierMetadataCardinalityValue = ExactlyOneEach
    , carrierAdditionalO2IPropertiesValue = Forbidden
    , relationCommitmentKeyValue = "o2i.commitment"
    , relationCommitmentValuesValue = Candidate :| [Asserted]
    , relationMetadataCardinalityValue = ExactlyOne
    , relationAdditionalO2IPropertiesValue = Forbidden
    }

carrierMappings :: [CarrierMapping]
carrierMappings =
  contextMapping
    : map (carrierMappingFor . PrimitiveCarrier) [minBound .. maxBound]
    ++ map (carrierMappingFor . StructuringCarrier) [minBound .. maxBound]
    ++ map (carrierMappingFor . SituationAnchorCarrier) [minBound .. maxBound]

contextMapping :: CarrierMapping
contextMapping =
  CarrierMapping
    { carrierMappingIdValue = "context"
    , carrierMappingTypesValue =
        fmap ContextCarrier (Ethos :| [Mission .. maxBound])
    , carrierMappingArchiElementValue = "Grouping"
    , carrierMappingContextOwnershipValue = Forbidden
    }

-- | Return the exact mapping for one semantic carrier type.
carrierMappingFor :: CarrierType -> CarrierMapping
carrierMappingFor carrier =
  case carrier of
    ContextCarrier _ -> contextMapping
    PrimitiveCarrier primitive ->
      CarrierMapping
        { carrierMappingIdValue = "primitive." <> primitiveToken primitive
        , carrierMappingTypesValue = PrimitiveCarrier primitive :| []
        , carrierMappingArchiElementValue = primitiveRepresentation primitive
        , carrierMappingContextOwnershipValue = Required
        }
    StructuringCarrier structuring ->
      CarrierMapping
        { carrierMappingIdValue = "structuring." <> structuringToken structuring
        , carrierMappingTypesValue = StructuringCarrier structuring :| []
        , carrierMappingArchiElementValue = "Grouping"
        , carrierMappingContextOwnershipValue = Required
        }
    SituationAnchorCarrier anchor ->
      CarrierMapping
        { carrierMappingIdValue = "situation-anchor." <> anchorToken anchor
        , carrierMappingTypesValue = SituationAnchorCarrier anchor :| []
        , carrierMappingArchiElementValue = anchorRepresentation anchor
        , carrierMappingContextOwnershipValue = Forbidden
        }

carrierMappingId :: CarrierMapping -> Text
carrierMappingId = carrierMappingIdValue

carrierMappingKind :: CarrierMapping -> MetadataKind
carrierMappingKind = carrierTypeKind . NonEmpty.head . carrierMappingTypesValue

carrierMappingTypes :: CarrierMapping -> NonEmpty CarrierType
carrierMappingTypes = carrierMappingTypesValue

-- | Required ArchiMate element metaclass for one carrier mapping.
carrierMappingElement :: CarrierMapping -> Text
carrierMappingElement = carrierMappingArchiElementValue

-- | Contextualization requirement of one carrier mapping.
carrierMappingOwnership :: CarrierMapping -> Requirement
carrierMappingOwnership = carrierMappingContextOwnershipValue

-- | Render one persisted @o2i.kind@ value.
metadataKindText :: MetadataKind -> Text
metadataKindText kind =
  case kind of
    ContextMetadata -> "Context"
    PrimitiveMetadata -> "Primitive"
    StructuringMetadata -> "Structuring"
    SituationAnchorMetadata -> "SituationAnchor"
    StructuredPropositionMetadata -> "StructuredProposition"

-- | Decode one value from the closed @o2i.kind@ vocabulary.
metadataKindFromText :: Text -> Maybe MetadataKind
metadataKindFromText value =
  lookup value [(metadataKindText kind, kind) | kind <- [minBound .. maxBound]]

carrierTypeText :: CarrierType -> Text
carrierTypeText carrier =
  case carrier of
    ContextCarrier context -> contextTypeText context
    PrimitiveCarrier primitive -> primitiveTypeText primitive
    StructuringCarrier structuring -> structuringTypeText structuring
    SituationAnchorCarrier anchor -> anchorTypeText anchor

-- | Decode one carrier type admitted for the supplied metadata kind.
carrierTypeFromText :: MetadataKind -> Text -> Maybe CarrierType
carrierTypeFromText kind value =
  lookup
    value
    [ (carrierTypeText carrier, carrier)
    | mapping <- carrierMappings
    , carrier <- NonEmpty.toList (carrierMappingTypes mapping)
    , carrierTypeKind carrier == kind
    ]

-- | Lift one notation-independent node kind into its carrier type.
carrierTypeForNodeKind :: NodeKindValue -> CarrierType
carrierTypeForNodeKind kind =
  case kind of
    ContextNodeKind context -> ContextCarrier context
    PrimitiveNodeKind _ primitive -> PrimitiveCarrier primitive
    StructuringNodeKind _ structuring -> StructuringCarrier structuring
    AnchorNodeKind anchor -> SituationAnchorCarrier anchor

carrierTypeKind :: CarrierType -> MetadataKind
carrierTypeKind carrier =
  case carrier of
    ContextCarrier _ -> ContextMetadata
    PrimitiveCarrier _ -> PrimitiveMetadata
    StructuringCarrier _ -> StructuringMetadata
    SituationAnchorCarrier _ -> SituationAnchorMetadata

contextTypeText :: Context -> Text
contextTypeText context =
  case context of
    Ethos -> "Ethos"
    Mission -> "Mission"
    Vision -> "Vision"
    Strategy -> "Strategy"
    Situation -> "Situation"
    Need -> "Need"
    Intervention -> "Intervention"
    Measure -> "Measure"

primitiveTypeText :: Primitive -> Text
primitiveTypeText primitive =
  case primitive of
    Principle -> "Principle"
    Driver -> "Driver"
    Objective -> "Objective"
    KeyResult -> "KeyResult"
    KPI -> "KPI"
    Action -> "Action"

structuringTypeText :: Structuring -> Text
structuringTypeText structuring =
  case structuring of
    PerformanceDimension -> "PerformanceDimension"

anchorTypeText :: SituationAnchor -> Text
anchorTypeText anchor =
  case anchor of
    BusinessCapability -> "BusinessCapability"
    BusinessProcess -> "BusinessProcess"
    BusinessObject -> "BusinessObject"
    ValueStream -> "ValueStream"

primitiveRepresentation :: Primitive -> Text
primitiveRepresentation primitive =
  case primitive of
    Principle -> "Principle"
    Driver -> "Driver"
    Objective -> "Goal"
    KeyResult -> "Outcome"
    KPI -> "Assessment"
    Action -> "CourseOfAction"

anchorRepresentation :: SituationAnchor -> Text
anchorRepresentation anchor =
  case anchor of
    BusinessCapability -> "Capability"
    BusinessProcess -> "BusinessProcess"
    BusinessObject -> "BusinessObject"
    ValueStream -> "ValueStream"

-- | All concrete relation mappings in core-registry order.
relationMappings :: [ArchiMateRelationMapping]
relationMappings = map relationMapping allRelations

relationMapping :: SomeRelation -> ArchiMateRelationMapping
relationMapping relation =
  ArchiMateRelationMapping
    { relationMappingIdValue = mappingIdentifier code name
    , relationMappingCodeValue = code
    , relationMappingNameValue = name
    , relationMappingLabelValue = label
    , relationMappingSourceValue = from
    , relationMappingTargetValue = to
    , relationMappingRepresentationValue = representation
    }
  where
    code = relationCodeOf relation
    (name, from, to) = relationIdentity relation
    (label, representation) = relationContract code

relationContract :: RelationCode -> (Text, ArchiMateRelationshipRepresentation)
relationContract code =
  case code of
    FixedRelation fixed -> fixedRelationContract fixed
    PerformanceDimensionMembership _ -> ("contains", aggregation)
    AnchorRelation family _ ->
      case family of
        ConstitutedByAnchorFamily -> ("is-constituted-by", aggregation)
        AnchorsNeedDriverFamily -> ("anchors", association)
        ChangesAnchorFamily -> ("changes", association)
        MeasuresAnchorFamily -> ("measures", association)

fixedRelationContract ::
     FixedRelationCode -> (Text, ArchiMateRelationshipRepresentation)
fixedRelationContract code =
  case code of
    GuidesMissionCode -> ("guides", association)
    GroundsVisionCode -> ("grounds", association)
    GuidesVisionCode -> ("guides", association)
    OrientsStrategyCode -> ("orients", association)
    DirectsStrategyCode -> ("directs", influence)
    ContributesToStrategyCode -> ("contributes-to", association)
    QualifiesNeedCode -> ("qualifies", association)
    SurfacesNeedCode -> ("surfaces", association)
    AddressesNeedCode -> ("addresses", association)
    DirectsInterventionCode -> ("directs", association)
    ChangesSituationCode -> ("changes", association)
    SetsTargetForMeasureCode -> ("sets-target-for", association)
    MeasuresSituationCode -> ("measures", association)
    FramesMeasureCode -> ("frames", association)
    GuidesEthosPrincipleToMissionDriverCode -> ("guides", influence)
    GuidesEthosPrincipleToVisionObjectiveCode -> ("guides", influence)
    GroundsMissionDriverToVisionObjectiveCode -> ("grounds", influence)
    OrientsVisionObjectiveToStrategyObjectiveCode -> ("orients", influence)
    GroundsStrategyDriverToObjectiveCode -> ("grounds", influence)
    SubstantiatesStrategyKeyResultObjectiveCode ->
      ("substantiates", realization)
    GuidesStrategyPrincipleToActionCode -> ("guides", association)
    ContributesStrategyActionToKeyResultCode -> ("contributes-to", realization)
    GuidesStrategyPrincipleToPrincipleCode -> ("guides", influence)
    ContributesStrategyKeyResultToKeyResultCode -> ("contributes-to", influence)
    ContributesStrategyActionToActionCode -> ("contributes-to", association)
    TranslatesStrategyKeyResultToNeedObjectiveCode ->
      ("translates-into", influence)
    GroundsNeedDriverToObjectiveCode -> ("grounds", influence)
    IndicatesMeasurePerformanceDimensionCode -> ("indicates", influence)
    DeterminesMeasurePerformanceDimensionCode -> ("determines", influence)
    GuidesStrategyActionToInterventionActionCode -> ("guides", association)
    ContributesInterventionActionToKeyResultCode ->
      ("contributes-to", realization)
    SubstantiatesInterventionKeyResultNeedObjectiveCode ->
      ("substantiates", realization)
    ContributesInterventionKeyResultToStrategyKeyResultCode ->
      ("contributes-to", influence)
    SetsTargetForMeasureKPICode -> ("sets-target-for", association)

-- | Required ArchiMate representation for one semantic relation code.
expectedRelationshipRepresentation ::
     RelationCode -> ArchiMateRelationshipRepresentation
expectedRelationshipRepresentation = snd . relationContract

-- | Exact persisted ArchiMate label for one semantic relation code.
expectedRelationshipLabel :: RelationCode -> Text
expectedRelationshipLabel = fst . relationContract

mappingIdentifier :: RelationCode -> RelationName -> Text
mappingIdentifier code name =
  relationNameText name
    <> case code of
         AnchorRelation _ anchor -> "." <> anchorToken anchor
         _ -> ""

nodeKindIdentifier :: NodeKindValue -> Text
nodeKindIdentifier kind =
  case kind of
    ContextNodeKind context -> "context." <> contextToken context
    PrimitiveNodeKind context primitive ->
      "primitive." <> contextToken context <> "." <> primitiveToken primitive
    StructuringNodeKind context structuring ->
      "structuring."
        <> contextToken context
        <> "."
        <> structuringToken structuring
    AnchorNodeKind anchor -> "situation-anchor." <> anchorToken anchor

contextToken :: Context -> Text
contextToken context =
  case context of
    Ethos -> "ethos"
    Mission -> "mission"
    Vision -> "vision"
    Strategy -> "strategy"
    Situation -> "situation"
    Need -> "need"
    Intervention -> "intervention"
    Measure -> "measure"

primitiveToken :: Primitive -> Text
primitiveToken primitive =
  case primitive of
    Principle -> "principle"
    Driver -> "driver"
    Objective -> "objective"
    KeyResult -> "key-result"
    KPI -> "kpi"
    Action -> "action"

structuringToken :: Structuring -> Text
structuringToken structuring =
  case structuring of
    PerformanceDimension -> "performance-dimension"

anchorToken :: SituationAnchor -> Text
anchorToken anchor =
  case anchor of
    BusinessCapability -> "business-capability"
    BusinessProcess -> "business-process"
    BusinessObject -> "business-object"
    ValueStream -> "value-stream"

influence :: ArchiMateRelationshipRepresentation
influence = ArchiMateRelationshipRepresentation "InfluenceRelationship" False

realization :: ArchiMateRelationshipRepresentation
realization =
  ArchiMateRelationshipRepresentation "RealizationRelationship" False

aggregation :: ArchiMateRelationshipRepresentation
aggregation =
  ArchiMateRelationshipRepresentation "AggregationRelationship" False

association :: ArchiMateRelationshipRepresentation
association = ArchiMateRelationshipRepresentation "AssociationRelationship" True

composition :: ArchiMateRelationshipRepresentation
composition =
  ArchiMateRelationshipRepresentation "CompositionRelationship" False

-- | Observe one concrete relationship representation.
relationshipRepresentation ::
     Text -> Bool -> ArchiMateRelationshipRepresentation
relationshipRepresentation = ArchiMateRelationshipRepresentation

contextualizationContract :: ContextualizationContract
contextualizationContract =
  ContextualizationContract
    { contextualizationIdValue = "contextualization"
    , contextualizationRepresentationValue = composition
    , contextualizationLabelValue = "contextualizes"
    , contextualizationSourceKindValue = ContextMetadata
    , contextualizationTargetKindsValue =
        PrimitiveMetadata :| [StructuringMetadata]
    , contextualizationIncomingCardinalityValue = ExactlyOne
    , contextualizationMetadataValue = Forbidden
    , contextualizationProjectionValue = "context-ownership"
    }

collectiveContract :: CollectiveContract
collectiveContract =
  CollectiveContract
    { collectiveIdValue = "collective-strategy-realization"
    , collectiveCarrierValue =
        CollectiveCarrierContract
          { collectiveCarrierKindValue = StructuredPropositionMetadata
          , collectiveCarrierTypeValue = "CollectiveStrategyRealization"
          , collectiveCarrierElementValue = "Junction"
          , collectiveJunctionTypeValue = "and"
          , collectiveCommitmentKeyValue = "o2i.commitment"
          , collectiveCommitmentValuesValue = Candidate :| [Asserted]
          , collectiveFitEvidenceKeyValue = "o2i.collective-fit-evidence"
          , collectiveFitEvidenceCardinalityValue = ExactlyOneNonEmpty
          , collectiveAdditionalO2IPropertiesValue = Forbidden
          }
    , collectiveSegmentsValue =
        CollectiveSegmentContract
          { collectiveSegmentRepresentationValue = realization
          , collectiveSegmentLabelValue = "realizes"
          , collectiveSegmentMetadataValue = Forbidden
          }
    , collectiveContributorsValue =
        CollectiveContributorsContract
          { collectiveContributorEndpointValue = ContextNodeKind Strategy
          , collectiveContributorCardinalityValue = AtLeastTwo
          , collectiveContributorsDistinctValue = Required
          }
    , collectiveTargetValue =
        CollectiveTargetContract
          { collectiveTargetEndpointValue = ContextNodeKind Strategy
          , collectiveTargetCardinalityValue = ExactlyOne
          , collectiveTargetDistinctFromContributorsValue = Required
          }
    , collectiveJunctionChainsValue = Forbidden
    , collectiveProjectionValue = "structured-proposition"
    }

-- | Render one relationship representation for deterministic diagnostics.
relationshipRepresentationText :: ArchiMateRelationshipRepresentation -> Text
relationshipRepresentationText representation =
  relationshipTypeName representation
    <> if relationshipDirected representation
         then ":directed"
         else ""

-- | Render one closed requirement value.
requirementText :: Requirement -> Text
requirementText requirement =
  case requirement of
    Required -> "required"
    Forbidden -> "forbidden"

-- | Whether the contract requires the governed fact.
requirementIsRequired :: Requirement -> Bool
requirementIsRequired requirement = requirement == Required

-- | Whether the contract forbids the governed fact.
requirementIsForbidden :: Requirement -> Bool
requirementIsForbidden requirement = requirement == Forbidden

-- | Render one closed cardinality value.
cardinalityText :: Cardinality -> Text
cardinalityText cardinality =
  case cardinality of
    ExactlyOne -> "exactly-one"
    ExactlyOneEach -> "exactly-one-each"
    ExactlyOneNonEmpty -> "exactly-one-non-empty"
    AtLeastTwo -> "at-least-two"

-- | Test an observed count against one contract cardinality.
cardinalityAccepts :: Cardinality -> Int -> Bool
cardinalityAccepts cardinality count =
  case cardinality of
    ExactlyOne -> count == 1
    ExactlyOneEach -> count == 1
    ExactlyOneNonEmpty -> count == 1
    AtLeastTwo -> count >= 2

-- | Render one persisted commitment value.
commitmentText :: Commitment -> Text
commitmentText commitment =
  case commitment of
    Candidate -> "candidate"
    Asserted -> "asserted"

-- | Decode one value from the closed commitment vocabulary.
commitmentFromText :: Text -> Maybe Commitment
commitmentFromText value =
  lookup
    value
    [ (commitmentText commitment, commitment)
    | commitment <- NonEmpty.toList (carrierCommitmentValues metadataContract)
    ]
