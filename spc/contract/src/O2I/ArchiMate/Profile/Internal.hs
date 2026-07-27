{-# LANGUAGE OverloadedStrings #-}

-- | Internal typed projection of the declarative ArchiMate profile contract.
--
-- The JSON contract is authoritative. This module is the closed executable
-- projection checked for complete equality with that contract.
module O2I.ArchiMate.Profile.Internal
  ( ArchiMateProfileContract(..)
  , MetadataContract(..)
  , MetadataKind(..)
  , CarrierType(..)
  , CarrierMapping(..)
  , Requirement(..)
  , Cardinality(..)
  , ArchiMateRelationshipRepresentation(..)
  , ArchiMateRelationMapping(..)
  , ContextualizationContract(..)
  , CollectiveContract(..)
  , CollectiveCarrierContract(..)
  , CollectiveSegmentContract(..)
  , CollectiveContributorsContract(..)
  , CollectiveTargetContract(..)
  , profileContract
  , profileVersionText
  , metadataKindText
  , metadataKindFromText
  , carrierTypeText
  , carrierTypeFromText
  , carrierTypeForNodeKind
  , carrierMappingKind
  , carrierMappingTypes
  , carrierMappingElement
  , carrierMappingOwnership
  , carrierMappingFor
  , relationMappings
  , nodeKindIdentifier
  , expectedRelationshipLabel
  , expectedRelationshipRepresentation
  , relationshipRepresentation
  , relationshipRepresentationText
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

-- | Complete compile-time AMX implementation of the profile contract.
data ArchiMateProfileContract = ArchiMateProfileContract
  { contractSchema :: Text
    -- ^ Stable schema identifier of the declarative contract.
  , contractProfileVersion :: O2IProfileVersion
    -- ^ Exact O2I profile version implemented by this projection.
  , contractMetadata :: MetadataContract
    -- ^ Persisted metadata placement and cardinality contract.
  , contractCarrierMappings :: [CarrierMapping]
    -- ^ Carrier mappings in authoritative order.
  , contractRelationMappings :: [ArchiMateRelationMapping]
    -- ^ Relation mappings in authoritative core-registry order.
  , contractContextualization :: ContextualizationContract
    -- ^ Exact contextualization syntax.
  , contractCollectiveRealization :: CollectiveContract
    -- ^ Exact collective Strategy-realization syntax.
  } deriving (Eq, Show)

-- | Exact persisted metadata keys, cardinalities, and closed values.
data MetadataContract = MetadataContract
  { modelProfileKey :: Text
    -- ^ Root property selecting the O2I profile.
  , modelProfileCardinality :: Cardinality
    -- ^ Required root-property cardinality.
  , modelAdditionalO2IProperties :: Requirement
    -- ^ Policy for additional root-level O2I properties.
  , carrierKindKey :: Text
    -- ^ Property identifying the O2I carrier kind.
  , carrierTypeKey :: Text
    -- ^ Property identifying the O2I carrier type.
  , carrierCommitmentKey :: Text
    -- ^ Property carrying proposition commitment on typed carriers.
  , carrierCommitmentValues :: NonEmpty Commitment
    -- ^ Closed carrier commitment vocabulary.
  , carrierMetadataCardinality :: Cardinality
    -- ^ Cardinality of required carrier metadata properties.
  , carrierAdditionalO2IProperties :: Requirement
    -- ^ Policy for additional carrier-level O2I properties.
  , relationCommitmentKey :: Text
    -- ^ Property carrying proposition commitment on semantic relations.
  , relationCommitmentValues :: NonEmpty Commitment
    -- ^ Closed semantic-relation commitment vocabulary.
  , relationMetadataCardinality :: Cardinality
    -- ^ Required relation commitment cardinality.
  , relationAdditionalO2IProperties :: Requirement
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
  { carrierMappingId :: Text
  , carrierMappingTypesValue :: NonEmpty CarrierType
  , carrierMappingArchiElement :: Text
  , carrierMappingContextOwnership :: Requirement
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
  { relationshipTypeName :: Text
    -- ^ Exact ArchiMate relationship metaclass name.
  , relationshipDirected :: Bool
    -- ^ Whether an Association is explicitly directed.
  } deriving (Eq, Ord, Show)

-- | One core relation enriched with its exact AMX representation.
data ArchiMateRelationMapping = ArchiMateRelationMapping
  { relationMappingId :: Text
    -- ^ Stable identifier of this concrete mapping.
  , relationMappingCode :: RelationCode
    -- ^ Notation-independent relation code.
  , relationMappingName :: RelationName
    -- ^ Persisted O2I relation name.
  , relationMappingLabel :: Text
    -- ^ Exact ArchiMate relationship label.
  , relationMappingSource :: NodeKindValue
    -- ^ Required source endpoint kind.
  , relationMappingTarget :: NodeKindValue
    -- ^ Required target endpoint kind.
  , relationMappingRepresentation :: ArchiMateRelationshipRepresentation
    -- ^ Required ArchiMate relationship representation.
  } deriving (Eq, Show)

-- | Exact native contextualization pattern.
data ContextualizationContract = ContextualizationContract
  { contextualizationId :: Text
    -- ^ Stable structured-pattern identifier.
  , contextualizationRepresentation :: ArchiMateRelationshipRepresentation
    -- ^ Required relationship representation.
  , contextualizationLabel :: Text
    -- ^ Exact contextualization label.
  , contextualizationSourceKind :: MetadataKind
    -- ^ Required source carrier kind.
  , contextualizationTargetKinds :: NonEmpty MetadataKind
    -- ^ Allowed target carrier kinds.
  , contextualizationIncomingCardinality :: Cardinality
    -- ^ Required incoming contextualization cardinality.
  , contextualizationMetadata :: Requirement
    -- ^ Policy for metadata on the relationship carrier.
  , contextualizationProjection :: Text
    -- ^ Stable projection role.
  } deriving (Eq, Show)

-- | Exact native collective Strategy-realization pattern.
data CollectiveContract = CollectiveContract
  { collectiveId :: Text
    -- ^ Stable structured-pattern identifier.
  , collectiveCarrier :: CollectiveCarrierContract
    -- ^ Junction-carrier contract.
  , collectiveSegments :: CollectiveSegmentContract
    -- ^ Incoming and outgoing segment contract.
  , collectiveContributors :: CollectiveContributorsContract
    -- ^ Contributor endpoint contract.
  , collectiveTarget :: CollectiveTargetContract
    -- ^ Target endpoint contract.
  , collectiveJunctionChains :: Requirement
    -- ^ Policy for Junction-to-Junction chains.
  , collectiveProjection :: Text
    -- ^ Stable projection role.
  } deriving (Eq, Show)

-- | Carrier portion of the collective realization contract.
data CollectiveCarrierContract = CollectiveCarrierContract
  { collectiveCarrierKind :: MetadataKind
    -- ^ Required O2I carrier kind.
  , collectiveCarrierType :: Text
    -- ^ Required O2I carrier type.
  , collectiveCarrierElement :: Text
    -- ^ Required ArchiMate element metaclass.
  , collectiveJunctionType :: Text
    -- ^ Required ArchiMate Junction type.
  , collectiveCommitmentKey :: Text
    -- ^ Property carrying the collective proposition commitment.
  , collectiveCommitmentValues :: NonEmpty Commitment
    -- ^ Closed collective commitment vocabulary.
  , collectiveFitEvidenceKey :: Text
    -- ^ Property referencing collective Fit evidence.
  , collectiveFitEvidenceCardinality :: Cardinality
    -- ^ Required collective Fit evidence cardinality.
  , collectiveAdditionalO2IProperties :: Requirement
    -- ^ Policy for additional carrier-level O2I properties.
  } deriving (Eq, Show)

-- | Segment portion of the collective realization contract.
data CollectiveSegmentContract = CollectiveSegmentContract
  { collectiveSegmentRepresentation :: ArchiMateRelationshipRepresentation
    -- ^ Required segment relationship representation.
  , collectiveSegmentLabel :: Text
    -- ^ Exact segment label.
  , collectiveSegmentMetadata :: Requirement
    -- ^ Policy for O2I metadata on segments.
  } deriving (Eq, Show)

-- | Contributor portion of the collective realization contract.
data CollectiveContributorsContract = CollectiveContributorsContract
  { collectiveContributorEndpoint :: NodeKindValue
    -- ^ Required contributor endpoint kind.
  , collectiveContributorCardinality :: Cardinality
    -- ^ Required number of contributors.
  , collectiveContributorsDistinct :: Requirement
    -- ^ Whether contributors must be distinct.
  } deriving (Eq, Show)

-- | Target portion of the collective realization contract.
data CollectiveTargetContract = CollectiveTargetContract
  { collectiveTargetEndpoint :: NodeKindValue
    -- ^ Required target endpoint kind.
  , collectiveTargetCardinality :: Cardinality
    -- ^ Required number of targets.
  , collectiveTargetDistinctFromContributors :: Requirement
    -- ^ Whether the target must differ from every contributor.
  } deriving (Eq, Show)

-- | Complete AMX profile implementation in contract order.
profileContract :: ArchiMateProfileContract
profileContract =
  ArchiMateProfileContract
    { contractSchema = "o2i.archimate-profile/v1"
    , contractProfileVersion = o2iProfileVersionLiteral ('0' :| ".2")
    , contractMetadata = metadataContract
    , contractCarrierMappings = carrierMappings
    , contractRelationMappings = relationMappings
    , contractContextualization = contextualizationContract
    , contractCollectiveRealization = collectiveContract
    }

metadataContract :: MetadataContract
metadataContract =
  MetadataContract
    { modelProfileKey = "o2i.profile"
    , modelProfileCardinality = ExactlyOne
    , modelAdditionalO2IProperties = Forbidden
    , carrierKindKey = "o2i.kind"
    , carrierTypeKey = "o2i.type"
    , carrierCommitmentKey = "o2i.commitment"
    , carrierCommitmentValues = Candidate :| [Asserted]
    , carrierMetadataCardinality = ExactlyOneEach
    , carrierAdditionalO2IProperties = Forbidden
    , relationCommitmentKey = "o2i.commitment"
    , relationCommitmentValues = Candidate :| [Asserted]
    , relationMetadataCardinality = ExactlyOne
    , relationAdditionalO2IProperties = Forbidden
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
    { carrierMappingId = "context"
    , carrierMappingTypesValue =
        fmap ContextCarrier (Ethos :| [Mission .. maxBound])
    , carrierMappingArchiElement = "Grouping"
    , carrierMappingContextOwnership = Forbidden
    }

-- | Return the exact mapping for one semantic carrier type.
carrierMappingFor :: CarrierType -> CarrierMapping
carrierMappingFor carrier =
  case carrier of
    ContextCarrier _ -> contextMapping
    PrimitiveCarrier primitive ->
      CarrierMapping
        { carrierMappingId = "primitive." <> primitiveToken primitive
        , carrierMappingTypesValue = PrimitiveCarrier primitive :| []
        , carrierMappingArchiElement = primitiveRepresentation primitive
        , carrierMappingContextOwnership = Required
        }
    StructuringCarrier structuring ->
      CarrierMapping
        { carrierMappingId = "structuring." <> structuringToken structuring
        , carrierMappingTypesValue = StructuringCarrier structuring :| []
        , carrierMappingArchiElement = "Grouping"
        , carrierMappingContextOwnership = Required
        }
    SituationAnchorCarrier anchor ->
      CarrierMapping
        { carrierMappingId = "situation-anchor." <> anchorToken anchor
        , carrierMappingTypesValue = SituationAnchorCarrier anchor :| []
        , carrierMappingArchiElement = anchorRepresentation anchor
        , carrierMappingContextOwnership = Forbidden
        }

carrierMappingKind :: CarrierMapping -> MetadataKind
carrierMappingKind = carrierTypeKind . NonEmpty.head . carrierMappingTypesValue

carrierMappingTypes :: CarrierMapping -> NonEmpty CarrierType
carrierMappingTypes = carrierMappingTypesValue

-- | Required ArchiMate element metaclass for one carrier mapping.
carrierMappingElement :: CarrierMapping -> Text
carrierMappingElement = carrierMappingArchiElement

-- | Contextualization requirement of one carrier mapping.
carrierMappingOwnership :: CarrierMapping -> Requirement
carrierMappingOwnership = carrierMappingContextOwnership

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
    BusinessRole -> "BusinessRole"
    ValueStream -> "ValueStream"
    RegulatoryConstraint -> "RegulatoryConstraint"

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
    BusinessRole -> "BusinessRole"
    ValueStream -> "ValueStream"
    RegulatoryConstraint -> "Requirement"

-- | All concrete relation mappings in core-registry order.
relationMappings :: [ArchiMateRelationMapping]
relationMappings = map relationMapping allRelations

relationMapping :: SomeRelation -> ArchiMateRelationMapping
relationMapping relation =
  ArchiMateRelationMapping
    { relationMappingId = mappingIdentifier code name
    , relationMappingCode = code
    , relationMappingName = name
    , relationMappingLabel = label
    , relationMappingSource = from
    , relationMappingTarget = to
    , relationMappingRepresentation = representation
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
    DirectsStrategyCode -> ("directs", association)
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

-- | Exact persisted AMX label for one semantic relation code.
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
    BusinessRole -> "business-role"
    ValueStream -> "value-stream"
    RegulatoryConstraint -> "regulatory-constraint"

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
    { contextualizationId = "contextualization"
    , contextualizationRepresentation = composition
    , contextualizationLabel = "contextualizes"
    , contextualizationSourceKind = ContextMetadata
    , contextualizationTargetKinds = PrimitiveMetadata :| [StructuringMetadata]
    , contextualizationIncomingCardinality = ExactlyOne
    , contextualizationMetadata = Forbidden
    , contextualizationProjection = "context-ownership"
    }

collectiveContract :: CollectiveContract
collectiveContract =
  CollectiveContract
    { collectiveId = "collective-strategy-realization"
    , collectiveCarrier =
        CollectiveCarrierContract
          { collectiveCarrierKind = StructuredPropositionMetadata
          , collectiveCarrierType = "CollectiveStrategyRealization"
          , collectiveCarrierElement = "Junction"
          , collectiveJunctionType = "and"
          , collectiveCommitmentKey = "o2i.commitment"
          , collectiveCommitmentValues = Candidate :| [Asserted]
          , collectiveFitEvidenceKey = "o2i.collective-fit-evidence"
          , collectiveFitEvidenceCardinality = ExactlyOneNonEmpty
          , collectiveAdditionalO2IProperties = Forbidden
          }
    , collectiveSegments =
        CollectiveSegmentContract
          { collectiveSegmentRepresentation = realization
          , collectiveSegmentLabel = "realizes"
          , collectiveSegmentMetadata = Forbidden
          }
    , collectiveContributors =
        CollectiveContributorsContract
          { collectiveContributorEndpoint = ContextNodeKind Strategy
          , collectiveContributorCardinality = AtLeastTwo
          , collectiveContributorsDistinct = Required
          }
    , collectiveTarget =
        CollectiveTargetContract
          { collectiveTargetEndpoint = ContextNodeKind Strategy
          , collectiveTargetCardinality = ExactlyOne
          , collectiveTargetDistinctFromContributors = Required
          }
    , collectiveJunctionChains = Forbidden
    , collectiveProjection = "structured-proposition"
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
