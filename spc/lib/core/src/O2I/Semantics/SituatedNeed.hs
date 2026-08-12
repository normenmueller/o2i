{-# LANGUAGE DataKinds #-}

-- | Family-specific assessment of globally situated Needs.
module O2I.Semantics.SituatedNeed
  ( assessSituatedNeeds
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import O2I.Core.Contract (CoreQualifiedEndpointId)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment(..)
  , RelationObservation
  , carrierCommitment
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationOccurrenceIdentity
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Semantics.Index
import O2I.Semantics.Internal
import O2I.Semantics.Vocabulary

-- | Assess every Need in canonical occurrence order.
assessSituatedNeeds :: SemanticIndex scope -> [SituatedNeedAssessment scope]
assessSituatedNeeds semanticIndex =
  map
    (assessSituatedNeed semanticIndex)
    (carriersAtEndpoint semanticIndex endpointContextNeed)

assessSituatedNeed ::
     SemanticIndex scope
  -> CarrierObservation scope
  -> SituatedNeedAssessment scope
assessSituatedNeed semanticIndex need =
  case carrierCommitment need of
    Candidate -> SituatedNeedCandidate needIdentity needOccurrence
    Asserted ->
      case NonEmpty.nonEmpty (sortSemanticDefects defects) of
        Just failures -> SituatedNeedInvalid needIdentity failures
        Nothing ->
          SituatedNeedValid
            GloballySituatedNeed
              { situatedNeedIdentity = needIdentity
              , situatedNeedOccurrence = needOccurrence
              , situatedNeedWitnesses = Set.toAscList (Set.fromList witnesses)
              }
  where
    needOccurrence = carrierOccurrenceIdentity need
    needIdentity = carrierModelIdentity need
    drivers =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        needOccurrence
        endpointNeedDriver
    objectives =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        needOccurrence
        endpointNeedObjective
    situations =
      filter
        (isAssertedEndpoint semanticIndex endpointContextSituation)
        (assertedIncomingSources semanticIndex needOccurrence tokenSurfaces)
    anchorsBySituation =
      [ ( situation
        , filter
            (isAssertedSituationAnchor semanticIndex)
            (assertedOutgoingTargets
               semanticIndex
               situation
               tokenIsConstitutedBy))
      | situation <- situations
      ]
    anchors = Set.toAscList . Set.fromList $ concatMap snd anchorsBySituation
    anchorSet = Set.fromList anchors
    driverSet = Set.fromList drivers
    objectiveSet = Set.fromList objectives
    unanchoredDrivers = filter (null . anchoredBySituation) drivers
    anchoredBySituation driver =
      filter
        (`Set.member` anchorSet)
        (assertedIncomingSources semanticIndex driver tokenAnchors)
    ungroundedObjectives = filter (null . groundedByOwnedDriver) objectives
    groundedByOwnedDriver objective =
      filter
        (`Set.member` driverSet)
        (assertedIncomingSources semanticIndex objective tokenGrounds)
    defects =
      cardinalityDefect
        Generated.SituatedNeedDriverCardinalityRule
        drivers
        (SemanticNeedEvidenceKey needIdentity)
        ++ cardinalityDefect
             Generated.SituatedNeedObjectiveCardinalityRule
             objectives
             (SemanticNeedEvidenceKey needIdentity)
        ++ cardinalityDefect
             Generated.SituatedNeedSurfacingSituationCardinalityRule
             situations
             (SemanticNeedEvidenceKey needIdentity)
        ++ [ mkSemanticDefect
             Generated.SituatedNeedSurfacingSituationAnchoringRule
             (SemanticNeedMemberEvidenceKey needIdentity situationIdentity)
             [situation]
           | (situation, []) <- anchorsBySituation
           , Just situationIdentity <- [modelIdentityAt semanticIndex situation]
           ]
        ++ [ mkSemanticDefect
             Generated.SituatedNeedDriverAnchoringRule
             (SemanticNeedMemberEvidenceKey needIdentity driverIdentity)
             [driver]
           | driver <- unanchoredDrivers
           , Just driverIdentity <- [modelIdentityAt semanticIndex driver]
           ]
        ++ [ mkSemanticDefect
             Generated.SituatedNeedObjectiveGroundingRule
             (SemanticNeedMemberEvidenceKey needIdentity objectiveIdentity)
             [objective]
           | objective <- ungroundedObjectives
           , Just objectiveIdentity <- [modelIdentityAt semanticIndex objective]
           ]
    witnesses =
      needOccurrence
        : drivers
        ++ objectives
        ++ situations
        ++ anchors
        ++ contextualizationWitnesses semanticIndex (drivers ++ objectives)
        ++ relationWitnesses
    relationWitnesses =
      concat
        [ relationOccurrences
          (assertedMatchingRelations
             semanticIndex
             situation
             tokenSurfaces
             needOccurrence)
        | situation <- situations
        ]
        ++ concat
             [ relationOccurrences
               (assertedMatchingRelations
                  semanticIndex
                  situation
                  tokenIsConstitutedBy
                  anchor)
             | (situation, situationAnchors) <- anchorsBySituation
             , anchor <- situationAnchors
             ]
        ++ concat
             [ relationOccurrences
               (assertedMatchingRelations
                  semanticIndex
                  anchor
                  tokenAnchors
                  driver)
             | anchor <- anchors
             , driver <-
                 filter
                   (`Set.member` driverSet)
                   (assertedOutgoingTargets semanticIndex anchor tokenAnchors)
             ]
        ++ concat
             [ relationOccurrences
               (assertedMatchingRelations
                  semanticIndex
                  driver
                  tokenGrounds
                  objective)
             | driver <- drivers
             , objective <-
                 filter
                   (`Set.member` objectiveSet)
                   (assertedOutgoingTargets semanticIndex driver tokenGrounds)
             ]

cardinalityDefect ::
     Generated.GeneratedSemanticRule 'Generated.GeneratedNeedKeySchema
  -> [OccurrenceIdentity]
  -> SemanticEvidenceKey 'Generated.GeneratedNeedKeySchema
  -> [SemanticDefect]
cardinalityDefect rule occurrences evidence =
  case occurrences of
    [] -> [mkSemanticDefect rule evidence []]
    _ -> []

modelIdentityAt ::
     SemanticIndex scope -> OccurrenceIdentity -> Maybe ModelIdentity
modelIdentityAt semanticIndex occurrence =
  carrierModelIdentity <$> carrierAt semanticIndex occurrence

isAssertedEndpoint ::
     SemanticIndex scope
  -> CoreQualifiedEndpointId
  -> OccurrenceIdentity
  -> Bool
isAssertedEndpoint semanticIndex endpoint occurrence =
  maybe
    False
    (\carrier ->
       carrierCommitment carrier == Asserted
         && carrierQualifiedEndpoint carrier == endpoint)
    (carrierAt semanticIndex occurrence)

isAssertedSituationAnchor :: SemanticIndex scope -> OccurrenceIdentity -> Bool
isAssertedSituationAnchor semanticIndex occurrence =
  any
    (\endpoint -> isAssertedEndpoint semanticIndex endpoint occurrence)
    situationAnchorEndpoints

contextualizationWitnesses ::
     SemanticIndex scope -> [OccurrenceIdentity] -> [OccurrenceIdentity]
contextualizationWitnesses semanticIndex members =
  [ contextualizationOccurrenceIdentity contextualization
  | member <- members
  , Just contextualization <- [contextualizationForMember semanticIndex member]
  ]

relationOccurrences :: [RelationObservation scope] -> [OccurrenceIdentity]
relationOccurrences = map relationOccurrenceIdentity
