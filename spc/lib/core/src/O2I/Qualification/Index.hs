{-# LANGUAGE RoleAnnotations #-}

-- | Private fixed index for Core Need qualification.
module O2I.Qualification.Index
  ( QualificationIndex
  , buildQualificationIndex
  , qualificationIndexGraphIdentity
  , qualificationIndexSubjects
  , IndexedQualificationCarrier
  , qualificationCarrierAt
  , qualificationCarrierAtAddress
  , qualificationCarrierAddressProbeWork
  , qualificationCarrierObservation
  , qualificationCarrierNeedRank
  , qualificationCarrierStrategyRank
  , qualificationOccurrencesForIdentity
  , qualificationOccurrencesForIdentityAtAddress
  , qualificationOwnerForMember
  , qualificationOwnerForMemberAtAddress
  , qualificationRelationsBetween
  , qualificationRelationsBetweenAtAddress
  , qualificationResolveIdentity
  , qualificationIndexWork
  , endpointContextNeed
  , endpointContextStrategy
  , endpointNeedObjective
  , endpointStrategyKeyResult
  , tokenQualifies
  , tokenTranslatesInto
  ) where

import Data.Char (ord)
import qualified Data.IntMap.Strict as IntMap
import Data.IntMap.Strict (IntMap)
import Data.List (sort, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (unpack)
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreRelationToken
  , coreRelationTokenText
  )
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal
  ( CoreQualifiedEndpointId(..)
  , CoreRelationToken(..)
  )
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , ContextualizationObservation
  , RelationObservation
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationMemberOccurrence
  , contextualizationOccurrenceIdentity
  , relationOccurrenceIdentity
  , relationSourceOccurrence
  , relationTargetOccurrence
  , relationToken
  )
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Core.Identity.Internal
  ( IdentityResolution
  , SelectedIdentityKind(..)
  , SelectedViewScope
  , resolveIdentity
  , scopedOccurrenceIdentity
  , selectedViewOccurrenceModelIdentity
  )
import O2I.Qualification.Internal
  ( QualificationSubject(..)
  , QualificationSubjectEligibility(..)
  , QualificationSubjects(..)
  , QualificationWork(..)
  , emptyQualificationWork
  )
import O2I.Structure
  ( structuredIncidenceOccurrence
  , structuredPropositionFamily
  , structuredPropositionIncidences
  , structuredPropositionOccurrence
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )
import O2I.Structure.Internal (WellFormedGraph(..), wellFormedGraphIdentity)

type role QualificationIndex nominal

-- | Only the addresses required by the closed qualification rule family.
data QualificationIndex scope = QualificationIndex
  { indexedQualificationGraphIdentity :: !ModelIdentity
  , indexedQualificationSelectedViewScope :: !(SelectedViewScope scope)
  , indexedQualificationIdentityKinds :: !(Map
                                             OccurrenceIdentity
                                             SelectedIdentityKind)
  , indexedQualificationCarriers :: !(Map
                                        OccurrenceIdentity
                                        (IndexedQualificationCarrier scope))
  , indexedQualificationCarrierAddresses :: !(CarrierAddressIndex
                                                (IndexedQualificationCarrier
                                                   scope))
  , indexedQualificationOccurrences :: !(Map ModelIdentity [OccurrenceIdentity])
  , indexedQualificationOccurrenceAddresses :: !(CarrierAddressIndex
                                                   [OccurrenceIdentity])
  , indexedQualificationOwners :: !(Map
                                      OccurrenceIdentity
                                      (ContextualizationObservation scope))
  , indexedQualificationOwnerAddresses :: !(CarrierAddressIndex
                                              (ContextualizationObservation
                                                 scope))
  , indexedQualificationRelations :: !(Map
                                         ( OccurrenceIdentity
                                         , CoreRelationToken
                                         , OccurrenceIdentity)
                                         [RelationObservation scope])
  , indexedQualificationRelationAddresses :: !(CarrierAddressIndex
                                                 [RelationObservation scope])
  , indexedQualificationSubjects :: !(QualificationSubjects scope)
  , indexedQualificationWork :: !QualificationWork
  }

-- | One carrier together with its compact fixed-subject addresses.
--
-- Need and Strategy ranks are prepared with the graph index so proposal
-- routing never searches the requested pair product.
data IndexedQualificationCarrier scope =
  IndexedQualificationCarrier
    !(CarrierObservation scope)
    !(Maybe Int)
    !(Maybe Int)

data CarrierAddressIndex value =
  CarrierAddressIndex !(Maybe value) !(IntMap (CarrierAddressIndex value))

emptyCarrierAddressIndex :: CarrierAddressIndex value
emptyCarrierAddressIndex = CarrierAddressIndex Nothing IntMap.empty

insertCarrierAddress ::
     [Int] -> value -> CarrierAddressIndex value -> CarrierAddressIndex value
insertCarrierAddress key value (CarrierAddressIndex stored children) =
  case key of
    [] -> CarrierAddressIndex (Just value) children
    scalar:remaining ->
      CarrierAddressIndex
        stored
        (IntMap.alter
           (Just
              . insertCarrierAddress remaining value
              . maybe emptyCarrierAddressIndex id)
           scalar
           children)

lookupCarrierAddress :: [Int] -> CarrierAddressIndex value -> (Maybe value, Int)
lookupCarrierAddress key (CarrierAddressIndex stored children) =
  case key of
    [] -> (stored, 0)
    scalar:remaining ->
      case IntMap.lookup scalar children of
        Nothing -> (Nothing, 1)
        Just child ->
          let (value, visits) = lookupCarrierAddress remaining child
           in (value, visits + 1)

occurrenceAddressKey :: OccurrenceIdentity -> [Int]
occurrenceAddressKey = map ord . unpack . occurrenceIdentityText

modelAddressKey :: ModelIdentity -> [Int]
modelAddressKey = map ord . unpack . modelIdentityText

relationAddressKey ::
     OccurrenceIdentity -> CoreRelationToken -> OccurrenceIdentity -> [Int]
relationAddressKey source token target =
  occurrenceAddressKey source
    ++ [-1]
    ++ map ord (unpack (coreRelationTokenText token))
    ++ [-1]
    ++ occurrenceAddressKey target

carrierAddressIndexFromList :: [([Int], value)] -> CarrierAddressIndex value
carrierAddressIndexFromList =
  foldl
    (\index (key, value) -> insertCarrierAddress key value index)
    emptyCarrierAddressIndex

-- | Build every qualification-specific address in one graph pass.
buildQualificationIndex :: WellFormedGraph scope -> QualificationIndex scope
buildQualificationIndex graph =
  QualificationIndex
    { indexedQualificationGraphIdentity = wellFormedGraphIdentity graph
    , indexedQualificationSelectedViewScope = wellFormedSelectedViewScope graph
    , indexedQualificationIdentityKinds = identityKinds
    , indexedQualificationCarriers = Map.fromList indexedCarriers
    , indexedQualificationCarrierAddresses =
        foldl
          (\addresses (occurrence, carrier) ->
             insertCarrierAddress
               (occurrenceAddressKey occurrence)
               carrier
               addresses)
          emptyCarrierAddressIndex
          indexedCarriers
    , indexedQualificationOccurrences = occurrenceBuckets
    , indexedQualificationOccurrenceAddresses =
        carrierAddressIndexFromList
          [ (modelAddressKey identifier, occurrences)
          | (identifier, occurrences) <- Map.toAscList occurrenceBuckets
          ]
    , indexedQualificationOwners = ownerAddresses
    , indexedQualificationOwnerAddresses =
        carrierAddressIndexFromList
          [ (occurrenceAddressKey occurrence, owner)
          | (occurrence, owner) <- Map.toAscList ownerAddresses
          ]
    , indexedQualificationRelations = relationBuckets
    , indexedQualificationRelationAddresses =
        carrierAddressIndexFromList
          [ (relationAddressKey source token target, observations)
          | ((source, token, target), observations) <-
              Map.toAscList relationBuckets
          ]
    , indexedQualificationSubjects =
        QualificationSubjects needSubjects strategySubjects
    , indexedQualificationWork =
        emptyQualificationWork
          { qualificationCarrierVisits = length carriers
          , qualificationRelationVisits = length relations
          , qualificationContextualizationVisits = length contextualizations
          }
    }
  where
    carriers = wellFormedCarriers graph
    contextualizations = wellFormedContextualizations graph
    relations = wellFormedRelations graph
    subjectsAt endpoint =
      sortOn
        (\subject ->
           ( storedQualificationSubjectIdentity subject
           , storedQualificationSubjectOccurrence subject))
        [ QualificationSubject
          (carrierModelIdentity carrier)
          (carrierOccurrenceIdentity carrier)
          endpoint
          QualificationSubjectEligibilityUnavailable
        | carrier <- carriers
        , carrierQualifiedEndpoint carrier == endpoint
        ]
    needSubjects = subjectsAt endpointContextNeed
    strategySubjects = subjectsAt endpointContextStrategy
    needRanks =
      Map.fromList
        [ (storedQualificationSubjectOccurrence subject, rank)
        | (rank, subject) <- zip [0 ..] needSubjects
        ]
    strategyRanks =
      Map.fromList
        [ (storedQualificationSubjectOccurrence subject, rank)
        | (rank, subject) <- zip [0 ..] strategySubjects
        ]
    indexedCarriers =
      [ ( carrierOccurrenceIdentity carrier
        , IndexedQualificationCarrier
            carrier
            (Map.lookup (carrierOccurrenceIdentity carrier) needRanks)
            (Map.lookup (carrierOccurrenceIdentity carrier) strategyRanks))
      | carrier <- carriers
      ]
    occurrenceBuckets =
      canonicalBuckets
        [ (effectGraphIdentity occurrence, occurrence)
        | occurrence <- effectGraphOccurrences
        ]
    ownerAddresses =
      Map.fromList
        [ (contextualizationMemberOccurrence value, value)
        | value <- contextualizations
        ]
    relationBuckets =
      canonicalBuckets
        [ ( ( relationSourceOccurrence relation
            , relationToken relation
            , relationTargetOccurrence relation)
          , relation)
        | relation <- relations
        ]
    propositions = wellFormedStructuredPropositions graph
    effectGraphOccurrences =
      map carrierOccurrenceIdentity carriers
        ++ map contextualizationOccurrenceIdentity contextualizations
        ++ map relationOccurrenceIdentity relations
        ++ concat
             [ structuredPropositionOccurrence proposition
               : map
                   structuredIncidenceOccurrence
                   (structuredPropositionIncidences proposition)
             | proposition <- propositions
             ]
    effectGraphIdentity occurrence =
      case selectedViewOccurrenceModelIdentity
             (wellFormedSelectedViewScope graph)
             occurrence of
        Just identifier -> identifier
        Nothing ->
          error
            "Structure invariant violated: effect-graph occurrence is outside the selected View"
    identityKinds =
      Map.fromList
        ([ ( carrierOccurrenceIdentity carrier
           , SelectedCarrier (carrierQualifiedEndpoint carrier))
         | carrier <- carriers
         ]
           ++ [ (relationOccurrenceIdentity relation, SelectedRelation)
              | relation <- relations
              ]
           ++ [ ( contextualizationOccurrenceIdentity contextualization
                , SelectedContextualization)
              | contextualization <- contextualizations
              ]
           ++ [ ( structuredPropositionOccurrence proposition
                , SelectedStructuredProposition
                    (structuredPropositionFamily proposition))
              | proposition <- propositions
              ]
           ++ [ ( structuredIncidenceOccurrence incidence
                , SelectedStructuredIncidence)
              | proposition <- propositions
              , incidence <- structuredPropositionIncidences proposition
              ])

qualificationIndexGraphIdentity :: QualificationIndex scope -> ModelIdentity
qualificationIndexGraphIdentity = indexedQualificationGraphIdentity

qualificationIndexSubjects ::
     QualificationIndex scope -> QualificationSubjects scope
qualificationIndexSubjects = indexedQualificationSubjects

qualificationCarrierAt ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> Maybe (IndexedQualificationCarrier scope)
qualificationCarrierAt index occurrence =
  Map.lookup occurrence (indexedQualificationCarriers index)

qualificationCarrierAtAddress ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> (Maybe (IndexedQualificationCarrier scope), Int)
qualificationCarrierAtAddress index occurrence =
  lookupCarrierAddress
    (occurrenceAddressKey occurrence)
    (indexedQualificationCarrierAddresses index)

qualificationCarrierAddressProbeWork ::
     [OccurrenceIdentity] -> [OccurrenceIdentity] -> (Int, Int)
qualificationCarrierAddressProbeWork members probes =
  ( length probes
  , sum [visits | probe <- probes, let (_, visits) = probeLookup probe])
  where
    addresses =
      foldl
        (\index occurrence ->
           insertCarrierAddress (occurrenceAddressKey occurrence) () index)
        emptyCarrierAddressIndex
        members
    probeLookup occurrence =
      lookupCarrierAddress (occurrenceAddressKey occurrence) addresses

qualificationCarrierObservation ::
     IndexedQualificationCarrier scope -> CarrierObservation scope
qualificationCarrierObservation (IndexedQualificationCarrier carrier _ _) =
  carrier

qualificationCarrierNeedRank :: IndexedQualificationCarrier scope -> Maybe Int
qualificationCarrierNeedRank (IndexedQualificationCarrier _ rank _) = rank

qualificationCarrierStrategyRank ::
     IndexedQualificationCarrier scope -> Maybe Int
qualificationCarrierStrategyRank (IndexedQualificationCarrier _ _ rank) = rank

qualificationOccurrencesForIdentity ::
     QualificationIndex scope -> ModelIdentity -> [OccurrenceIdentity]
qualificationOccurrencesForIdentity index identifier =
  Map.findWithDefault [] identifier (indexedQualificationOccurrences index)

qualificationOccurrencesForIdentityAtAddress ::
     QualificationIndex scope -> ModelIdentity -> ([OccurrenceIdentity], Int)
qualificationOccurrencesForIdentityAtAddress index identifier =
  case lookupCarrierAddress
         (modelAddressKey identifier)
         (indexedQualificationOccurrenceAddresses index) of
    (Nothing, visits) -> ([], visits)
    (Just occurrences, visits) -> (occurrences, visits)

qualificationOwnerForMember ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> Maybe (ContextualizationObservation scope)
qualificationOwnerForMember index occurrence =
  Map.lookup occurrence (indexedQualificationOwners index)

qualificationOwnerForMemberAtAddress ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> (Maybe (ContextualizationObservation scope), Int)
qualificationOwnerForMemberAtAddress index occurrence =
  lookupCarrierAddress
    (occurrenceAddressKey occurrence)
    (indexedQualificationOwnerAddresses index)

qualificationRelationsBetween ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> [RelationObservation scope]
qualificationRelationsBetween index source token target =
  Map.findWithDefault
    []
    (source, token, target)
    (indexedQualificationRelations index)

qualificationRelationsBetweenAtAddress ::
     QualificationIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> ([RelationObservation scope], Int)
qualificationRelationsBetweenAtAddress index source token target =
  case lookupCarrierAddress
         (relationAddressKey source token target)
         (indexedQualificationRelationAddresses index) of
    (Nothing, visits) -> ([], visits)
    (Just relations, visits) -> (relations, visits)

qualificationResolveIdentity ::
     QualificationIndex scope
  -> SelectedIdentityKind
  -> ModelIdentity
  -> IdentityResolution scope
qualificationResolveIdentity index expected =
  resolveIdentity
    (indexedQualificationSelectedViewScope index)
    classify
    expected
  where
    classify occurrence =
      Map.findWithDefault
        SelectedUnclassifiedOccurrence
        (scopedOccurrenceIdentity occurrence)
        (indexedQualificationIdentityKinds index)

qualificationIndexWork :: QualificationIndex scope -> QualificationWork
qualificationIndexWork = indexedQualificationWork

canonicalBuckets :: (Ord key, Ord value) => [(key, value)] -> Map key [value]
canonicalBuckets = Map.map sort . Map.fromListWith (++) . map singletonValue
  where
    singletonValue (key, value) = (key, [value])

endpointContextNeed :: CoreQualifiedEndpointId
endpointContextNeed =
  CoreQualifiedEndpointId Generated.GeneratedEndpointContextNeed

endpointContextStrategy :: CoreQualifiedEndpointId
endpointContextStrategy =
  CoreQualifiedEndpointId Generated.GeneratedEndpointContextStrategy

endpointNeedObjective :: CoreQualifiedEndpointId
endpointNeedObjective =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveNeedObjective

endpointStrategyKeyResult :: CoreQualifiedEndpointId
endpointStrategyKeyResult =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyKeyResult

tokenQualifies :: CoreRelationToken
tokenQualifies = CoreRelationToken Generated.GeneratedTokenQualifies

tokenTranslatesInto :: CoreRelationToken
tokenTranslatesInto = CoreRelationToken Generated.GeneratedTokenTranslatesInto
