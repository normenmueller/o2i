{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private addressed index for Core semantic assessment.
--
-- The index is built once per selected View. It supports only the fixed
-- semantic rules owned by Core and deliberately exposes no public graph-query
-- surface.
module O2I.Semantics.Index
  ( SemanticIndex
  , buildSemanticIndex
  , semanticIndexGraphIdentity
  , indexedCarriers
  , carrierAt
  , occurrencesForModelIdentity
  , carriersAtEndpoint
  , contextualizationForMember
  , ownedMembersAtEndpoint
  , assertedOwnedMembersAtEndpoint
  , matchingRelations
  , assertedMatchingRelations
  , outgoingTargets
  , assertedOutgoingTargets
  , incomingSources
  , assertedIncomingSources
  , indexedStructuredPropositions
  , strategyFormulationInputFor
  , strategyIdentitySiteResolved
  , collectiveFitInputFor
  , collectiveIdentitySiteResolved
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRelationToken)
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment(..)
  , ContextualizationObservation
  , RelationObservation
  , carrierCommitment
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationCommitment
  , contextualizationMemberOccurrence
  , contextualizationOwnerOccurrence
  , relationCommitment
  , relationSourceOccurrence
  , relationTargetOccurrence
  , relationToken
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types
  ( BoundSupplementalInputs(..)
  , CollectiveFitInput
  , StrategyFormulationInput
  , SupplementalInput(..)
  , SupplementalInputOrdinal
  , SupplementalInputSet(..)
  , collectiveClaim
  , formulationStrategy
  , supplementalIdentitySiteResolved
  )
import O2I.Structure
  ( StructuredPropositionObservation
  , WellFormedGraph
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )
import O2I.Structure.Internal (wellFormedGraphIdentity)

type role SemanticIndex nominal

-- | Fixed indexes required by Core-owned semantic rules.
data SemanticIndex scope = SemanticIndex
  { indexGraphIdentity :: !ModelIdentity
  , indexCarriers :: ![CarrierObservation scope]
  , indexCarrierByOccurrence :: !(Map
                                    OccurrenceIdentity
                                    (CarrierObservation scope))
  , indexOccurrencesByModelIdentity :: !(Map ModelIdentity [OccurrenceIdentity])
  , indexCarriersByEndpoint :: !(Map
                                   CoreQualifiedEndpointId
                                   [CarrierObservation scope])
  , indexContextualizationByMember :: !(Map
                                          OccurrenceIdentity
                                          (ContextualizationObservation scope))
  , indexOwnedMembers :: !(Map
                             (OccurrenceIdentity, CoreQualifiedEndpointId)
                             [OccurrenceIdentity])
  , indexAssertedOwnedMembers :: !(Map
                                     ( OccurrenceIdentity
                                     , CoreQualifiedEndpointId)
                                     [OccurrenceIdentity])
  , indexForwardRelations :: !(RelationOrientation scope)
  , indexReverseRelations :: !(RelationOrientation scope)
  , indexPropositions :: ![StructuredPropositionObservation scope]
  , indexStrategyInputs :: !(Map
                               ModelIdentity
                               ( SupplementalInputOrdinal
                               , StrategyFormulationInput))
  , indexCollectiveInputs :: !(Map
                                 ModelIdentity
                                 (SupplementalInputOrdinal, CollectiveFitInput))
  , indexBoundInputs :: !(BoundSupplementalInputs scope)
  }

-- | Build every fixed semantic index in one pass over each input collection.
buildSemanticIndex ::
     WellFormedGraph scope
  -> BoundSupplementalInputs scope
  -> SemanticIndex scope
buildSemanticIndex graph boundInputs@(BoundSupplementalInputs inputSet _) =
  SemanticIndex
    { indexGraphIdentity = wellFormedGraphIdentity graph
    , indexCarriers = carriers
    , indexCarrierByOccurrence =
        Map.fromList
          [(carrierOccurrenceIdentity carrier, carrier) | carrier <- carriers]
    , indexOccurrencesByModelIdentity =
        canonicalBuckets
          [ (carrierModelIdentity carrier, carrierOccurrenceIdentity carrier)
          | carrier <- carriers
          ]
    , indexCarriersByEndpoint =
        canonicalBuckets
          [(carrierQualifiedEndpoint carrier, carrier) | carrier <- carriers]
    , indexContextualizationByMember =
        Map.fromList
          [ ( contextualizationMemberOccurrence contextualization
            , contextualization)
          | contextualization <- contextualizations
          ]
    , indexOwnedMembers = ownedMembers contextualizations carriers
    , indexAssertedOwnedMembers =
        ownedMembers
          (filter
             ((== Asserted) . contextualizationCommitment)
             contextualizations)
          (filter ((== Asserted) . carrierCommitment) carriers)
    , indexForwardRelations =
        relationOrientation
          relationSourceOccurrence
          relationTargetOccurrence
          relations
    , indexReverseRelations =
        relationOrientation
          relationTargetOccurrence
          relationSourceOccurrence
          relations
    , indexPropositions = wellFormedStructuredPropositions graph
    , indexStrategyInputs =
        Map.fromList
          [ (formulationStrategy formulation, (ordinal, formulation))
          | StrategyFormulationSupplement _ ordinal formulation <- inputs
          , supplementalIdentitySiteResolved
              boundInputs
              ordinal
              "/strategy"
              (formulationStrategy formulation)
          ]
    , indexCollectiveInputs =
        Map.fromList
          [ (collectiveClaim collective, (ordinal, collective))
          | CollectiveFitSupplement _ ordinal collective <- inputs
          , supplementalIdentitySiteResolved
              boundInputs
              ordinal
              "/claim"
              (collectiveClaim collective)
          ]
    , indexBoundInputs = boundInputs
    }
  where
    SupplementalInputSet inputs = inputSet
    carriers = wellFormedCarriers graph
    contextualizations = wellFormedContextualizations graph
    relations = wellFormedRelations graph

-- | Project the selected View identity retained by this stage index.
semanticIndexGraphIdentity :: SemanticIndex scope -> ModelIdentity
semanticIndexGraphIdentity = indexGraphIdentity

indexedCarriers :: SemanticIndex scope -> [CarrierObservation scope]
indexedCarriers = indexCarriers

carrierAt ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> Maybe (CarrierObservation scope)
carrierAt semanticIndex occurrence =
  Map.lookup occurrence (indexCarrierByOccurrence semanticIndex)

occurrencesForModelIdentity ::
     SemanticIndex scope -> ModelIdentity -> [OccurrenceIdentity]
occurrencesForModelIdentity semanticIndex identifier =
  Map.findWithDefault
    []
    identifier
    (indexOccurrencesByModelIdentity semanticIndex)

carriersAtEndpoint ::
     SemanticIndex scope
  -> CoreQualifiedEndpointId
  -> [CarrierObservation scope]
carriersAtEndpoint semanticIndex endpoint =
  Map.findWithDefault [] endpoint (indexCarriersByEndpoint semanticIndex)

contextualizationForMember ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> Maybe (ContextualizationObservation scope)
contextualizationForMember semanticIndex member =
  Map.lookup member (indexContextualizationByMember semanticIndex)

ownedMembersAtEndpoint ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreQualifiedEndpointId
  -> [OccurrenceIdentity]
ownedMembersAtEndpoint semanticIndex owner endpoint =
  Map.findWithDefault [] (owner, endpoint) (indexOwnedMembers semanticIndex)

assertedOwnedMembersAtEndpoint ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreQualifiedEndpointId
  -> [OccurrenceIdentity]
assertedOwnedMembersAtEndpoint semanticIndex owner endpoint =
  Map.findWithDefault
    []
    (owner, endpoint)
    (indexAssertedOwnedMembers semanticIndex)

matchingRelations ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> [RelationObservation scope]
matchingRelations semanticIndex source token target =
  maybe
    []
    bucketRelations
    (relationBucket (indexForwardRelations semanticIndex) source token target)

assertedMatchingRelations ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> [RelationObservation scope]
assertedMatchingRelations semanticIndex source token target =
  maybe
    []
    bucketAssertedRelations
    (relationBucket (indexForwardRelations semanticIndex) source token target)

outgoingTargets ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
outgoingTargets semanticIndex source token =
  orientedEndpoints (indexForwardRelations semanticIndex) source token

assertedOutgoingTargets ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
assertedOutgoingTargets semanticIndex source token =
  assertedOrientedEndpoints (indexForwardRelations semanticIndex) source token

incomingSources ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
incomingSources semanticIndex target token =
  orientedEndpoints (indexReverseRelations semanticIndex) target token

assertedIncomingSources ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
assertedIncomingSources semanticIndex target token =
  assertedOrientedEndpoints (indexReverseRelations semanticIndex) target token

indexedStructuredPropositions ::
     SemanticIndex scope -> [StructuredPropositionObservation scope]
indexedStructuredPropositions = indexPropositions

strategyFormulationInputFor ::
     SemanticIndex scope -> ModelIdentity -> Maybe StrategyFormulationInput
strategyFormulationInputFor semanticIndex strategy =
  snd <$> Map.lookup strategy (indexStrategyInputs semanticIndex)

strategyIdentitySiteResolved ::
     SemanticIndex scope -> ModelIdentity -> Text -> ModelIdentity -> Bool
strategyIdentitySiteResolved semanticIndex strategy pointer identifier =
  case Map.lookup strategy (indexStrategyInputs semanticIndex) of
    Nothing -> False
    Just (ordinal, _) ->
      supplementalIdentitySiteResolved
        (indexBoundInputs semanticIndex)
        ordinal
        pointer
        identifier

collectiveFitInputFor ::
     SemanticIndex scope -> ModelIdentity -> Maybe CollectiveFitInput
collectiveFitInputFor semanticIndex claim =
  snd <$> Map.lookup claim (indexCollectiveInputs semanticIndex)

collectiveIdentitySiteResolved ::
     SemanticIndex scope -> ModelIdentity -> Text -> ModelIdentity -> Bool
collectiveIdentitySiteResolved semanticIndex claim pointer identifier =
  case Map.lookup claim (indexCollectiveInputs semanticIndex) of
    Nothing -> False
    Just (ordinal, _) ->
      supplementalIdentitySiteResolved
        (indexBoundInputs semanticIndex)
        ordinal
        pointer
        identifier

canonicalBuckets :: Ord key => [(key, value)] -> Map key [value]
canonicalBuckets = Map.map reverse . Map.fromListWith (++) . map singletonValue
  where
    singletonValue (key, value) = (key, [value])

ownedMembers ::
     [ContextualizationObservation scope]
  -> [CarrierObservation scope]
  -> Map (OccurrenceIdentity, CoreQualifiedEndpointId) [OccurrenceIdentity]
ownedMembers contextualizations carriers =
  canonicalBuckets
    [ ( ( contextualizationOwnerOccurrence contextualization
        , carrierQualifiedEndpoint carrier)
      , member)
    | contextualization <- contextualizations
    , let member = contextualizationMemberOccurrence contextualization
    , Just carrier <- [Map.lookup member carrierByOccurrence]
    ]
  where
    carrierByOccurrence =
      Map.fromList
        [(carrierOccurrenceIdentity carrier, carrier) | carrier <- carriers]

data RelationBucket scope = RelationBucket
  { bucketRelations :: ![RelationObservation scope]
  , bucketAssertedRelations :: ![RelationObservation scope]
  }

type RelationOrientation scope
  = Map
      (OccurrenceIdentity, CoreRelationToken)
      (Map OccurrenceIdentity (RelationBucket scope))

relationOrientation ::
     (RelationObservation scope -> OccurrenceIdentity)
  -> (RelationObservation scope -> OccurrenceIdentity)
  -> [RelationObservation scope]
  -> RelationOrientation scope
relationOrientation primary secondary = foldr insertRelation Map.empty
  where
    insertRelation relation =
      Map.insertWith
        (Map.unionWith appendBucket)
        (primary relation, relationToken relation)
        (Map.singleton (secondary relation) (singletonBucket relation))

singletonBucket :: RelationObservation scope -> RelationBucket scope
singletonBucket relation =
  RelationBucket [relation] [relation | relationCommitment relation == Asserted]

appendBucket ::
     RelationBucket scope -> RelationBucket scope -> RelationBucket scope
appendBucket left right =
  RelationBucket
    (bucketRelations left ++ bucketRelations right)
    (bucketAssertedRelations left ++ bucketAssertedRelations right)

relationBucket ::
     RelationOrientation scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> Maybe (RelationBucket scope)
relationBucket orientation primary token secondary =
  Map.lookup (primary, token) orientation >>= Map.lookup secondary

orientedEndpoints ::
     RelationOrientation scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
orientedEndpoints orientation primary token =
  maybe [] Map.keys (Map.lookup (primary, token) orientation)

assertedOrientedEndpoints ::
     RelationOrientation scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> [OccurrenceIdentity]
assertedOrientedEndpoints orientation primary token =
  maybe
    []
    (Map.keys . Map.filter (not . null . bucketAssertedRelations))
    (Map.lookup (primary, token) orientation)
