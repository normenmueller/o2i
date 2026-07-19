{-# LANGUAGE OverloadedStrings #-}

-- | Native ArchiMate realization of the core-owned O2I registries.
module O2I.Adapter.AMX.Internal.Registry
  ( AMXRelationSignature(..)
  , ArchiRelationshipRepresentation(..)
  , relationSignatures
  , expectedElementRepresentation
  , expectedRelationshipRepresentation
  , actualRelationshipRepresentation
  , representationText
  , relationDependencyReason
  , isHiddenDependencyRelation
  ) where

import Data.Text (Text)
import O2I
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.Inspection.Profile
import O2I.Inspection.Provenance (ExpandedQName(..))

-- | One core relation enriched only with its concrete AMX realization.
data AMXRelationSignature = AMXRelationSignature
  { signatureCode :: RelationCode
  , signatureName :: RelationName
  , signatureAMXLabel :: Text
  , signatureFrom :: NodeKindValue
  , signatureTo :: NodeKindValue
  , signatureRepresentation :: ArchiRelationshipRepresentation
  } deriving (Eq, Show)

-- | Exact native relationship kind and Association direction flag.
data ArchiRelationshipRepresentation = ArchiRelationshipRepresentation
  { relationshipTypeName :: Text
  , relationshipDirected :: Bool
  } deriving (Eq, Ord, Show)

-- | Complete relation registry derived from the semantic Core registry.
relationSignatures :: [AMXRelationSignature]
relationSignatures = map enrich allRelations
  where
    enrich relation =
      let (name, from, to) = relationIdentity relation
          code = relationCodeOf relation
       in AMXRelationSignature
            { signatureCode = code
            , signatureName = name
            , signatureAMXLabel = amxRelationLabel code
            , signatureFrom = from
            , signatureTo = to
            , signatureRepresentation = expectedRelationshipRepresentation code
            }

-- | Required ArchiMate element local name for one O2I node kind.
expectedElementRepresentation :: NodeKindValue -> Text
expectedElementRepresentation kind =
  case kind of
    ContextNodeKind _ -> "Grouping"
    PrimitiveNodeKind _ primitive -> primitiveRepresentation primitive
    StructuringNodeKind _ PerformanceDimension -> "Grouping"
    AnchorNodeKind anchor -> anchorRepresentation anchor

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

-- | Concrete ArchiMate relation mapping for every core relation code.
expectedRelationshipRepresentation ::
     RelationCode -> ArchiRelationshipRepresentation
expectedRelationshipRepresentation code =
  case code of
    FixedRelation fixed -> fixedRepresentation fixed
    PerformanceDimensionMembership _ -> aggregation
    AnchorRelation family _ ->
      case family of
        ConstitutedByAnchorFamily -> aggregation
        AnchorsNeedDriverFamily -> association
        ChangesAnchorFamily -> association
        MeasuresAnchorFamily -> association

fixedRepresentation :: FixedRelationCode -> ArchiRelationshipRepresentation
fixedRepresentation code =
  case code of
    GuidesMissionCode -> influence
    GroundsVisionCode -> influence
    GuidesVisionCode -> influence
    OrientsStrategyCode -> influence
    DirectsStrategyCode -> influence
    ContributesToStrategyCode -> influence
    QualifiesNeedCode -> influence
    SurfacesNeedCode -> influence
    AddressesNeedCode -> influence
    DirectsInterventionCode -> influence
    ChangesSituationCode -> influence
    SetsTargetForMeasureCode -> influence
    MeasuresSituationCode -> influence
    FramesMeasureCode -> influence
    GuidesEthosPrincipleToMissionDriverCode -> influence
    GuidesEthosPrincipleToVisionObjectiveCode -> influence
    GroundsMissionDriverToVisionObjectiveCode -> influence
    OrientsVisionObjectiveToStrategyObjectiveCode -> influence
    GroundsStrategyDriverToObjectiveCode -> influence
    SubstantiatesStrategyKeyResultObjectiveCode -> realization
    GuidesStrategyPrincipleToActionCode -> association
    ContributesStrategyActionToKeyResultCode -> realization
    GuidesStrategyPrincipleToPrincipleCode -> influence
    ContributesStrategyKeyResultToKeyResultCode -> influence
    ContributesStrategyActionToActionCode -> association
    TranslatesStrategyKeyResultToNeedObjectiveCode -> influence
    GroundsNeedDriverToObjectiveCode -> influence
    IndicatesMeasurePerformanceDimensionCode -> influence
    DeterminesMeasurePerformanceDimensionCode -> influence
    GuidesStrategyActionToInterventionActionCode -> association
    ContributesInterventionActionToKeyResultCode -> realization
    SubstantiatesInterventionKeyResultNeedObjectiveCode -> realization
    ContributesInterventionKeyResultToStrategyKeyResultCode -> influence
    SetsTargetForMeasureKPICode -> association

amxRelationLabel :: RelationCode -> Text
amxRelationLabel code =
  case code of
    FixedRelation fixed -> fixedRelationLabel fixed
    PerformanceDimensionMembership _ -> "contains"
    AnchorRelation family _ ->
      case family of
        ConstitutedByAnchorFamily -> "is-constituted-by"
        AnchorsNeedDriverFamily -> "anchors"
        ChangesAnchorFamily -> "changes"
        MeasuresAnchorFamily -> "measures"

fixedRelationLabel :: FixedRelationCode -> Text
fixedRelationLabel code =
  case code of
    GuidesMissionCode -> "guides"
    GroundsVisionCode -> "grounds"
    GuidesVisionCode -> "guides"
    OrientsStrategyCode -> "orients"
    DirectsStrategyCode -> "directs"
    ContributesToStrategyCode -> "contributes-to"
    QualifiesNeedCode -> "qualifies"
    SurfacesNeedCode -> "surfaces"
    AddressesNeedCode -> "addresses"
    DirectsInterventionCode -> "directs"
    ChangesSituationCode -> "changes"
    SetsTargetForMeasureCode -> "sets-target-for"
    MeasuresSituationCode -> "measures"
    FramesMeasureCode -> "frames"
    GuidesEthosPrincipleToMissionDriverCode -> "guides"
    GuidesEthosPrincipleToVisionObjectiveCode -> "guides"
    GroundsMissionDriverToVisionObjectiveCode -> "grounds"
    OrientsVisionObjectiveToStrategyObjectiveCode -> "orients"
    GroundsStrategyDriverToObjectiveCode -> "grounds"
    SubstantiatesStrategyKeyResultObjectiveCode -> "substantiates"
    GuidesStrategyPrincipleToActionCode -> "guides"
    ContributesStrategyActionToKeyResultCode -> "contributes-to"
    GuidesStrategyPrincipleToPrincipleCode -> "guides"
    ContributesStrategyKeyResultToKeyResultCode -> "contributes-to"
    ContributesStrategyActionToActionCode -> "contributes-to"
    TranslatesStrategyKeyResultToNeedObjectiveCode -> "translates-into"
    GroundsNeedDriverToObjectiveCode -> "grounds"
    IndicatesMeasurePerformanceDimensionCode -> "indicates"
    DeterminesMeasurePerformanceDimensionCode -> "determines"
    GuidesStrategyActionToInterventionActionCode -> "guides"
    ContributesInterventionActionToKeyResultCode -> "contributes-to"
    SubstantiatesInterventionKeyResultNeedObjectiveCode -> "substantiates"
    ContributesInterventionKeyResultToStrategyKeyResultCode -> "contributes-to"
    SetsTargetForMeasureKPICode -> "sets-target-for"

influence :: ArchiRelationshipRepresentation
influence = ArchiRelationshipRepresentation "InfluenceRelationship" False

realization :: ArchiRelationshipRepresentation
realization = ArchiRelationshipRepresentation "RealizationRelationship" False

aggregation :: ArchiRelationshipRepresentation
aggregation = ArchiRelationshipRepresentation "AggregationRelationship" False

association :: ArchiRelationshipRepresentation
association = ArchiRelationshipRepresentation "AssociationRelationship" True

-- | Observe one persisted AMX relationship representation.
actualRelationshipRepresentation ::
     AMXElement -> Maybe ArchiRelationshipRepresentation
actualRelationshipRepresentation relationship = do
  relationshipType <- elementType relationship
  if qNameNamespace relationshipType /= Just archiNamespace
    then Nothing
    else Just
           ArchiRelationshipRepresentation
             { relationshipTypeName = qNameLocalName relationshipType
             , relationshipDirected =
                 elementAttribute
                   (ExpandedQName Nothing "directed")
                   relationship
                   == Just "true"
             }

representationText :: ArchiRelationshipRepresentation -> Text
representationText representation =
  relationshipTypeName representation
    <> if relationshipDirected representation
         then ":directed"
         else ""

-- | Provenance reason for relation endpoints reached by scope closure.
relationDependencyReason :: RelationCode -> PersistedDependencyReason
relationDependencyReason code =
  case code of
    PerformanceDimensionMembership _ -> PersistedPerformanceDimensionMembership
    AnchorRelation family _ ->
      case family of
        ConstitutedByAnchorFamily -> PersistedSituationDependency
        AnchorsNeedDriverFamily -> PersistedNeedDependency
        ChangesAnchorFamily -> PersistedSituationDependency
        MeasuresAnchorFamily -> PersistedSituationDependency
    FixedRelation fixed -> fixedDependencyReason fixed

fixedDependencyReason :: FixedRelationCode -> PersistedDependencyReason
fixedDependencyReason code =
  case code of
    GuidesMissionCode -> PersistedRelationshipEndpoint
    GroundsVisionCode -> PersistedRelationshipEndpoint
    GuidesVisionCode -> PersistedRelationshipEndpoint
    OrientsStrategyCode -> PersistedRelationshipEndpoint
    DirectsStrategyCode -> PersistedRelationshipEndpoint
    ContributesToStrategyCode -> PersistedRelationshipEndpoint
    QualifiesNeedCode -> PersistedNeedDependency
    SurfacesNeedCode -> PersistedNeedDependency
    AddressesNeedCode -> PersistedNeedDependency
    DirectsInterventionCode -> PersistedRelationshipEndpoint
    ChangesSituationCode -> PersistedSituationDependency
    SetsTargetForMeasureCode -> PersistedRelationshipEndpoint
    MeasuresSituationCode -> PersistedSituationDependency
    FramesMeasureCode -> PersistedRelationshipEndpoint
    GuidesEthosPrincipleToMissionDriverCode -> PersistedRelationshipEndpoint
    GuidesEthosPrincipleToVisionObjectiveCode -> PersistedRelationshipEndpoint
    GroundsMissionDriverToVisionObjectiveCode -> PersistedRelationshipEndpoint
    OrientsVisionObjectiveToStrategyObjectiveCode ->
      PersistedRelationshipEndpoint
    GroundsStrategyDriverToObjectiveCode -> PersistedRelationshipEndpoint
    SubstantiatesStrategyKeyResultObjectiveCode -> PersistedRelationshipEndpoint
    GuidesStrategyPrincipleToActionCode -> PersistedRelationshipEndpoint
    ContributesStrategyActionToKeyResultCode -> PersistedRelationshipEndpoint
    GuidesStrategyPrincipleToPrincipleCode -> PersistedRelationshipEndpoint
    ContributesStrategyKeyResultToKeyResultCode -> PersistedRelationshipEndpoint
    ContributesStrategyActionToActionCode -> PersistedRelationshipEndpoint
    TranslatesStrategyKeyResultToNeedObjectiveCode -> PersistedNeedDependency
    GroundsNeedDriverToObjectiveCode -> PersistedNeedDependency
    IndicatesMeasurePerformanceDimensionCode -> PersistedRelationshipEndpoint
    DeterminesMeasurePerformanceDimensionCode -> PersistedRelationshipEndpoint
    GuidesStrategyActionToInterventionActionCode ->
      PersistedRelationshipEndpoint
    ContributesInterventionActionToKeyResultCode ->
      PersistedRelationshipEndpoint
    SubstantiatesInterventionKeyResultNeedObjectiveCode ->
      PersistedNeedDependency
    ContributesInterventionKeyResultToStrategyKeyResultCode ->
      PersistedRelationshipEndpoint
    SetsTargetForMeasureKPICode -> PersistedRelationshipEndpoint

-- | Relations added when reached even if they are not directly presented.
isHiddenDependencyRelation :: RelationCode -> Bool
isHiddenDependencyRelation code =
  relationDependencyReason code /= PersistedRelationshipEndpoint
