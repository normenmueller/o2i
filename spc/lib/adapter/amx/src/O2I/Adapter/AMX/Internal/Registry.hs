{-# LANGUAGE OverloadedStrings #-}

-- | AMX representation observations and profile dependency classification.
module O2I.Adapter.AMX.Internal.Registry
  ( expectedElementRepresentation
  , actualRelationshipRepresentation
  , representationText
  , relationDependencyReason
  , isHiddenDependencyRelation
  ) where

import Data.Text (Text)
import O2I
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.ArchiMate.Profile
  ( ArchiMateRelationshipRepresentation
  , carrierMappingElement
  , carrierMappingFor
  , carrierTypeForNodeKind
  , relationshipRepresentation
  , relationshipRepresentationText
  )
import O2I.Inspection.Profile
import O2I.Inspection.Provenance (expandedQName, qNameLocalName, qNameNamespace)

-- | Required ArchiMate element local name for one O2I node kind.
expectedElementRepresentation :: NodeKindValue -> Text
expectedElementRepresentation kind =
  carrierMappingElement (carrierMappingFor (carrierTypeForNodeKind kind))

-- | Observe one persisted AMX relationship representation.
actualRelationshipRepresentation ::
     AMXElement -> Maybe ArchiMateRelationshipRepresentation
actualRelationshipRepresentation relationship = do
  relationshipType <- elementType relationship
  if qNameNamespace relationshipType /= Just archiNamespace
    then Nothing
    else Just
           (relationshipRepresentation
              (qNameLocalName relationshipType)
              (elementAttribute
                 (expandedQName Nothing 'd' "irected")
                 relationship
                 == Just "true"))

representationText :: ArchiMateRelationshipRepresentation -> Text
representationText = relationshipRepresentationText

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
