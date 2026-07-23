{-# LANGUAGE OverloadedStrings #-}

-- | Immutable native indexes for collective Strategy realization.
module O2I.Adapter.AMX.Internal.Profile.Collective.Index
  ( CollectiveIndex
  , buildCollectiveIndex
  , collectiveObservations
  , collectiveObservationByOccurrence
  , collectiveObservationsById
  , relationshipsAtEndpoint
  , collectiveSegmentOccurrences
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Profile.Collective.Syntax
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Provenance

-- | One projection-local index retaining persisted declaration order.
data CollectiveIndex = CollectiveIndex
  { indexedObservations :: [CollectiveObservation]
  , indexedObservationsByOccurrence :: Map OccurrenceId CollectiveObservation
  , indexedObservationsById :: Map Text [CollectiveObservation]
  , indexedRelationshipAdjacency :: Map Text [AMXElement]
  , indexedSegmentOccurrences :: Set OccurrenceId
  }

-- | Build every collective lookup once for one decoded document projection.
buildCollectiveIndex :: Environment -> CollectiveIndex
buildCollectiveIndex environment =
  CollectiveIndex
    { indexedObservations = observations
    , indexedObservationsByOccurrence =
        Map.fromList
          [ (nodeOccurrence (observedJunction observation), observation)
          | observation <- observations
          ]
    , indexedObservationsById =
        Map.fromListWith
          (flip (++))
          [ (identifier, [observation])
          | observation <- observations
          , identifier <- maybeToList (elementId (observedJunction observation))
          ]
    , indexedRelationshipAdjacency = adjacency
    , indexedSegmentOccurrences =
        Set.fromList
          [ relationshipOccurrence segment
          | observation <- observations
          , segment <- observedSegments observation
          ]
    }
  where
    adjacency = relationshipAdjacency (environmentRelationships environment)
    observations =
      map
        (observeCollective environment adjacency)
        (filter isCollectiveClaimCandidate (environmentNodes environment))

-- | Collective observations in persisted Junction declaration order.
collectiveObservations :: CollectiveIndex -> [CollectiveObservation]
collectiveObservations = indexedObservations

-- | Resolve one collective observation by exact Junction occurrence.
collectiveObservationByOccurrence ::
     CollectiveIndex -> OccurrenceId -> Maybe CollectiveObservation
collectiveObservationByOccurrence index occurrence =
  Map.lookup occurrence (indexedObservationsByOccurrence index)

-- | Resolve every same-ID observation in persisted declaration order.
collectiveObservationsById :: CollectiveIndex -> Text -> [CollectiveObservation]
collectiveObservationsById index identifier =
  Map.findWithDefault [] identifier (indexedObservationsById index)

-- | Resolve persisted relationships incident to one endpoint identifier.
relationshipsAtEndpoint :: CollectiveIndex -> Maybe Text -> [AMXElement]
relationshipsAtEndpoint _ Nothing = []
relationshipsAtEndpoint index (Just identifier) =
  Map.findWithDefault [] identifier (indexedRelationshipAdjacency index)

-- | Exact occurrence set of every relationship used as a collective segment.
collectiveSegmentOccurrences :: CollectiveIndex -> Set OccurrenceId
collectiveSegmentOccurrences = indexedSegmentOccurrences

relationshipAdjacency :: [AMXElement] -> Map Text [AMXElement]
relationshipAdjacency relationships =
  Map.fromListWith
    (flip (++))
    [ (identifier, [relationship])
    | relationship <- relationships
    , identifier <- endpointIds relationship
    ]

endpointIds :: AMXElement -> [Text]
endpointIds relationship =
  stableUnique
    (mapMaybe
       (\role -> elementAttribute (endpointQName role) relationship)
       [SourceEndpoint, TargetEndpoint])

stableUnique :: Ord value => [value] -> [value]
stableUnique = go Set.empty
  where
    go _ [] = []
    go seen (value:values)
      | Set.member value seen = go seen values
      | otherwise = value : go (Set.insert value seen) values

maybeToList :: Maybe value -> [value]
maybeToList Nothing = []
maybeToList (Just value) = [value]
