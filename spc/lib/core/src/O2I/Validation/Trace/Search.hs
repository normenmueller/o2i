{-# LANGUAGE BangPatterns #-}

-- | Cabal-private, output-sensitive effect-trace search.
--
-- One immutable index is built for one validation call and discarded with the
-- search result. Traversal starts from persisted Intervention-to-Need facts and
-- addresses only relation and ownership buckets reachable from those facts.
module O2I.Validation.Trace.Search
  ( TraceStrategyRoles(..)
  , TracePath(..)
  , TraceIndexBuildWork(..)
  , TraceTraversalWork(..)
  , TraceSearchWork(..)
  , TraceSearchResult
  , searchInterventions
  , searchAddressedNeeds
  , searchPaths
  , searchCovers
  , searchWork
  , deriveTracePaths
  ) where

import Data.List (foldl')
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation

-- | Validated Strategy roles required by effect-trace derivation.
data TraceStrategyRoles = TraceStrategyRoles
  { traceRoleDriver :: RawNodeId
  , traceRoleObjective :: RawNodeId
  , traceRoleKeyResults :: [RawNodeId]
  , traceRoleActions :: [RawNodeId]
  } deriving (Eq, Show)

data TraceStrategyRoleIndex = TraceStrategyRoleIndex
  { indexedRoleDriver :: RawNodeId
  , indexedRoleObjective :: RawNodeId
  , indexedRoleKeyResults :: Set RawNodeId
  , indexedRoleActions :: Set RawNodeId
  }

-- | One complete notation-independent relational effect path.
data TracePath = TracePath
  { pathVision :: RawNodeId
  , pathVisionObjective :: RawNodeId
  , pathStrategy :: RawNodeId
  , pathStrategyDriver :: RawNodeId
  , pathStrategyObjective :: RawNodeId
  , pathStrategyKeyResult :: RawNodeId
  , pathStrategyAction :: RawNodeId
  , pathNeed :: RawNodeId
  , pathNeedDriver :: RawNodeId
  , pathNeedObjective :: RawNodeId
  , pathIntervention :: RawNodeId
  , pathInterventionAction :: RawNodeId
  , pathInterventionKeyResult :: RawNodeId
  , pathMeasure :: RawNodeId
  , pathMeasurePerformanceDimension :: RawNodeId
  , pathMeasureKPI :: RawNodeId
  , pathSituation :: RawNodeId
  , pathSituationAnchor :: RawNodeId
  , pathSituationAnchorKind :: SituationAnchor
  } deriving (Eq, Ord, Show)

-- | Exact one-pass cost of constructing a per-validation search index.
data TraceIndexBuildWork = TraceIndexBuildWork
  { traceIndexedNodeOccurrences :: !Int
  , traceIndexedEdgeOccurrences :: !Int
  } deriving (Eq, Show)

-- | Deterministic work performed after the immutable index has been built.
--
-- The metric intentionally excludes index construction. Unrelated graph facts
-- therefore affect build work but cannot affect addressed traversal work.
data TraceTraversalWork = TraceTraversalWork
  { traceNodeBucketProbes :: !Int
  , traceNodeOccurrences :: !Int
  , traceNodeMembershipProbes :: !Int
  , traceEdgeBucketProbes :: !Int
  , traceEdgeOccurrences :: !Int
  , traceEdgeMembershipProbes :: !Int
  , traceStrategyRoleProbes :: !Int
  , tracePathExtensions :: !Int
  , tracePathsEmitted :: !Int
  } deriving (Eq, Show)

instance Semigroup TraceTraversalWork where
  left <> right =
    TraceTraversalWork
      { traceNodeBucketProbes =
          traceNodeBucketProbes left + traceNodeBucketProbes right
      , traceNodeOccurrences =
          traceNodeOccurrences left + traceNodeOccurrences right
      , traceNodeMembershipProbes =
          traceNodeMembershipProbes left + traceNodeMembershipProbes right
      , traceEdgeBucketProbes =
          traceEdgeBucketProbes left + traceEdgeBucketProbes right
      , traceEdgeOccurrences =
          traceEdgeOccurrences left + traceEdgeOccurrences right
      , traceEdgeMembershipProbes =
          traceEdgeMembershipProbes left + traceEdgeMembershipProbes right
      , traceStrategyRoleProbes =
          traceStrategyRoleProbes left + traceStrategyRoleProbes right
      , tracePathExtensions =
          tracePathExtensions left + tracePathExtensions right
      , tracePathsEmitted = tracePathsEmitted left + tracePathsEmitted right
      }

instance Monoid TraceTraversalWork where
  mempty = TraceTraversalWork 0 0 0 0 0 0 0 0 0

-- | Separate build and addressed traversal accounting for one search.
data TraceSearchWork = TraceSearchWork
  { traceIndexBuildWork :: TraceIndexBuildWork
  , traceTraversalWork :: TraceTraversalWork
  } deriving (Eq, Show)

-- | Complete private result consumed by traceability validation.
data TraceSearchResult = TraceSearchResult
  { resultInterventions :: [RawNodeId]
  , resultAddressedNeeds :: Map RawNodeId [RawNodeId]
  , resultPaths :: [TracePath]
  , resultCoveredPairs :: Set (RawNodeId, RawNodeId)
  , resultWork :: TraceSearchWork
  }

-- | Read every Intervention in deterministic identifier order.
searchInterventions :: TraceSearchResult -> [RawNodeId]
searchInterventions = resultInterventions

-- | Read addressed Needs for one Intervention in deterministic order.
searchAddressedNeeds :: TraceSearchResult -> RawNodeId -> [RawNodeId]
searchAddressedNeeds result intervention =
  Map.findWithDefault [] intervention (resultAddressedNeeds result)

-- | Read complete paths in deterministic constituent order.
searchPaths :: TraceSearchResult -> [TracePath]
searchPaths = resultPaths

-- | Test whether one addressed pair produced at least one complete path.
searchCovers :: TraceSearchResult -> RawNodeId -> RawNodeId -> Bool
searchCovers result intervention need =
  Set.member (intervention, need) (resultCoveredPairs result)

-- | Read separate index-build and addressed-traversal work.
searchWork :: TraceSearchResult -> TraceSearchWork
searchWork = resultWork

-- | Build one immutable index and derive only reachable effect traces.
deriveTracePaths ::
     WellFormedGraph -> Map RawNodeId TraceStrategyRoles -> TraceSearchResult
deriveTracePaths graph strategies =
  TraceSearchResult
    { resultInterventions = interventions
    , resultAddressedNeeds = addressedNeeds
    , resultPaths = paths
    , resultCoveredPairs =
        Set.fromList [(pathIntervention path, pathNeed path) | path <- paths]
    , resultWork =
        TraceSearchWork
          { traceIndexBuildWork = indexedWork index
          , traceTraversalWork =
              searchWorkOf pathSearch
                <> mempty {tracePathsEmitted = length paths}
          }
    }
  where
    index = buildTraceSearchIndex graph
    strategyRoleIndex = Map.map indexStrategyRoles strategies
    interventions =
      Set.toAscList
        (Map.findWithDefault Set.empty Intervention (indexedContexts index))
    addressedSearch = relationSearch index addressesNeedName
    addressedPairs = searchValues addressedSearch
    addressedNeeds =
      Map.map
        reverse
        (foldl'
           insertAddressedPair
           (Map.fromList [(intervention, []) | intervention <- interventions])
           addressedPairs)
    pathSearch =
      bindSearch addressedSearch (pathsForAddressedPair index strategyRoleIndex)
    paths = searchValues pathSearch

indexStrategyRoles :: TraceStrategyRoles -> TraceStrategyRoleIndex
indexStrategyRoles roles =
  TraceStrategyRoleIndex
    { indexedRoleDriver = traceRoleDriver roles
    , indexedRoleObjective = traceRoleObjective roles
    , indexedRoleKeyResults = Set.fromList (traceRoleKeyResults roles)
    , indexedRoleActions = Set.fromList (traceRoleActions roles)
    }

insertAddressedPair ::
     Map RawNodeId [RawNodeId]
  -> (RawNodeId, RawNodeId)
  -> Map RawNodeId [RawNodeId]
insertAddressedPair addressed (intervention, need) =
  Map.adjust (need :) intervention addressed

data TraceSearchIndex = TraceSearchIndex
  { indexedContexts :: Map Context (Set RawNodeId)
  , indexedPrimitives :: Map (RawNodeId, Primitive) (Set RawNodeId)
  , indexedPrimitiveOwnership :: Map RawNodeId (RawNodeId, Primitive)
  , indexedStructuringOwnership :: Map RawNodeId (RawNodeId, Structuring)
  , indexedAnchors :: Map RawNodeId SituationAnchor
  , indexedOutgoing :: Map (RelationName, RawNodeId) (Set RawNodeId)
  , indexedIncoming :: Map (RelationName, RawNodeId) (Set RawNodeId)
  , indexedRelations :: Map RelationName (Set (RawNodeId, RawNodeId))
  , indexedMeasureTargetKeyResults :: Map (RawNodeId, RawNodeId) (Set RawNodeId)
  , indexedMeasureTargetKPIs :: Map (RawNodeId, RawNodeId) (Set RawNodeId)
  , indexedWork :: TraceIndexBuildWork
  }

buildTraceSearchIndex :: WellFormedGraph -> TraceSearchIndex
buildTraceSearchIndex graph =
  (foldl' indexEdge nodesIndexed edges)
    { indexedWork =
        TraceIndexBuildWork
          { traceIndexedNodeOccurrences = length nodes
          , traceIndexedEdgeOccurrences = length edges
          }
    }
  where
    nodes = graphNodes graph
    edges = graphEdges graph
    nodesIndexed = foldl' indexNode emptyTraceSearchIndex nodes

emptyTraceSearchIndex :: TraceSearchIndex
emptyTraceSearchIndex =
  TraceSearchIndex
    { indexedContexts = Map.empty
    , indexedPrimitives = Map.empty
    , indexedPrimitiveOwnership = Map.empty
    , indexedStructuringOwnership = Map.empty
    , indexedAnchors = Map.empty
    , indexedOutgoing = Map.empty
    , indexedIncoming = Map.empty
    , indexedRelations = Map.empty
    , indexedMeasureTargetKeyResults = Map.empty
    , indexedMeasureTargetKPIs = Map.empty
    , indexedWork = TraceIndexBuildWork 0 0
    }

indexNode :: TraceSearchIndex -> SomeNode -> TraceSearchIndex
indexNode index node =
  case (someNodeKind node, someNodeOwner node) of
    (ContextNodeKind context, Nothing) ->
      index
        {indexedContexts = insertSet context identifier (indexedContexts index)}
    (PrimitiveNodeKind _ primitive, Just owner) ->
      index
        { indexedPrimitives =
            insertSet (owner, primitive) identifier (indexedPrimitives index)
        , indexedPrimitiveOwnership =
            Map.insert
              identifier
              (owner, primitive)
              (indexedPrimitiveOwnership index)
        }
    (StructuringNodeKind _ structuring, Just owner) ->
      index
        { indexedStructuringOwnership =
            Map.insert
              identifier
              (owner, structuring)
              (indexedStructuringOwnership index)
        }
    (AnchorNodeKind anchor, Nothing) ->
      index
        {indexedAnchors = Map.insert identifier anchor (indexedAnchors index)}
    _ -> index
  where
    identifier = someNodeId node

indexEdge :: TraceSearchIndex -> SomeEdge -> TraceSearchIndex
indexEdge index edge =
  indexMeasureTarget
    index
      { indexedOutgoing =
          insertSet (relation, source) target (indexedOutgoing index)
      , indexedIncoming =
          insertSet (relation, target) source (indexedIncoming index)
      , indexedRelations =
          Map.insertWith
            Set.union
            relation
            (Set.singleton (source, target))
            (indexedRelations index)
      }
  where
    indexMeasureTarget indexed
      | relation /= setsTargetForKPIName = indexed
      | otherwise =
        case ( Map.lookup source (indexedPrimitiveOwnership index)
             , Map.lookup target (indexedPrimitiveOwnership index)) of
          (Just (intervention, KeyResult), Just (measure, KPI)) ->
            indexed
              { indexedMeasureTargetKeyResults =
                  insertSet
                    (measure, intervention)
                    source
                    (indexedMeasureTargetKeyResults indexed)
              , indexedMeasureTargetKPIs =
                  insertSet
                    (measure, source)
                    target
                    (indexedMeasureTargetKPIs indexed)
              }
          _ -> indexed
    source = someEdgeFrom edge
    relation = someEdgeRelation edge
    target = someEdgeTo edge

insertSet ::
     Ord key
  => key
  -> RawNodeId
  -> Map key (Set RawNodeId)
  -> Map key (Set RawNodeId)
insertSet key value = Map.insertWith Set.union key (Set.singleton value)

data Search value = Search
  { searchValues :: [value]
  , searchWorkOf :: TraceTraversalWork
  }

mapSearch :: (left -> right) -> Search left -> Search right
mapSearch transform searched =
  Search
    { searchValues = map transform (searchValues searched)
    , searchWorkOf = searchWorkOf searched
    }

bindSearch :: Search left -> (left -> Search right) -> Search right
bindSearch searched next =
  Search
    { searchValues = outputs
    , searchWorkOf =
        searchWorkOf searched
          <> foldMap searchWorkOf branches
          <> mempty {tracePathExtensions = length outputs}
    }
  where
    branches = map next (searchValues searched)
    outputs = concatMap searchValues branches

selectiveEdgeIntersectionSearch ::
     Ord value => Set value -> Set value -> Search value
selectiveEdgeIntersectionSearch left right =
  Search
    { searchValues =
        filter (`Set.member` guardValues) (Set.toAscList candidates)
    , searchWorkOf =
        mempty
          { traceEdgeBucketProbes = 2
          , traceEdgeOccurrences = Set.size candidates
          , traceEdgeMembershipProbes = Set.size candidates
          }
    }
  where
    (candidates, guardValues)
      | Set.size left <= Set.size right = (left, right)
      | otherwise = (right, left)

selectiveThreeWayEdgeIntersectionSearch ::
     Ord value => Set value -> Set value -> Set value -> Search value
selectiveThreeWayEdgeIntersectionSearch first second third =
  Search
    { searchValues = reverse acceptedDescending
    , searchWorkOf =
        mempty
          { traceEdgeBucketProbes = 3
          , traceEdgeOccurrences = Set.size candidates
          , traceEdgeMembershipProbes = membershipProbes
          }
    }
  where
    (acceptedDescending, membershipProbes) =
      foldl' evaluateCandidate ([], 0) (Set.toAscList candidates)
    evaluateCandidate (accepted, probes) candidate
      | not (Set.member candidate firstGuard) =
        let !nextProbes = probes + 1
         in (accepted, nextProbes)
      | Set.member candidate secondGuard =
        let !nextProbes = probes + 2
         in (candidate : accepted, nextProbes)
      | otherwise =
        let !nextProbes = probes + 2
         in (accepted, nextProbes)
    (candidates, firstGuard, secondGuard)
      | Set.size first <= Set.size second && Set.size first <= Set.size third =
        (first, second, third)
      | Set.size second <= Set.size third = (second, first, third)
      | otherwise = (third, first, second)

primitiveGuard ::
     TraceSearchIndex -> RawNodeId -> Primitive -> RawNodeId -> Search ()
primitiveGuard index owner primitive identifier =
  nodeMembershipSearch
    (Map.lookup identifier (indexedPrimitiveOwnership index)
       == Just (owner, primitive))

structuringGuard ::
     TraceSearchIndex -> RawNodeId -> Structuring -> RawNodeId -> Search ()
structuringGuard index owner structuring identifier =
  nodeMembershipSearch
    (Map.lookup identifier (indexedStructuringOwnership index)
       == Just (owner, structuring))

anchorKindSearch :: TraceSearchIndex -> RawNodeId -> Search SituationAnchor
anchorKindSearch index anchor =
  case Map.lookup anchor (indexedAnchors index) of
    Nothing ->
      Search
        {searchValues = [], searchWorkOf = mempty {traceNodeBucketProbes = 1}}
    Just anchorKind ->
      Search
        { searchValues = [anchorKind]
        , searchWorkOf =
            mempty {traceNodeBucketProbes = 1, traceNodeOccurrences = 1}
        }

nodeMembershipSearch :: Bool -> Search ()
nodeMembershipSearch member =
  Search
    { searchValues = [() | member]
    , searchWorkOf = mempty {traceNodeMembershipProbes = 1}
    }

nodeBucketSearch :: Set value -> Search value
nodeBucketSearch values =
  Search
    { searchValues = Set.toAscList values
    , searchWorkOf =
        mempty
          {traceNodeBucketProbes = 1, traceNodeOccurrences = Set.size values}
    }

outgoingSearch ::
     TraceSearchIndex -> RelationName -> RawNodeId -> Search RawNodeId
outgoingSearch index relation source =
  edgeBucketSearch
    (Map.findWithDefault Set.empty (relation, source) (indexedOutgoing index))

incomingSearch ::
     TraceSearchIndex -> RelationName -> RawNodeId -> Search RawNodeId
incomingSearch index relation target =
  edgeBucketSearch
    (Map.findWithDefault Set.empty (relation, target) (indexedIncoming index))

edgeBucketSearch :: Set value -> Search value
edgeBucketSearch values =
  Search
    { searchValues = Set.toAscList values
    , searchWorkOf =
        mempty
          {traceEdgeBucketProbes = 1, traceEdgeOccurrences = Set.size values}
    }

edgeMembershipSearch :: Ord value => Set value -> value -> Search ()
edgeMembershipSearch values value =
  Search
    { searchValues = [() | Set.member value values]
    , searchWorkOf = mempty {traceEdgeMembershipProbes = 1}
    }

relationSearch ::
     TraceSearchIndex -> RelationName -> Search (RawNodeId, RawNodeId)
relationSearch index relation =
  edgeBucketSearch
    (Map.findWithDefault Set.empty relation (indexedRelations index))

edgeGuard ::
     TraceSearchIndex -> RelationName -> RawNodeId -> RawNodeId -> Search ()
edgeGuard index relation source target =
  Search
    { searchValues = [() | Set.member target targets]
    , searchWorkOf =
        mempty {traceEdgeBucketProbes = 1, traceEdgeMembershipProbes = 1}
    }
  where
    targets =
      Map.findWithDefault Set.empty (relation, source) (indexedOutgoing index)

strategyRolesSearch ::
     Map RawNodeId TraceStrategyRoleIndex
  -> RawNodeId
  -> Search TraceStrategyRoleIndex
strategyRolesSearch strategies strategy =
  Search
    { searchValues = maybe [] pure (Map.lookup strategy strategies)
    , searchWorkOf = mempty {traceStrategyRoleProbes = 1}
    }

pathsForAddressedPair ::
     TraceSearchIndex
  -> Map RawNodeId TraceStrategyRoleIndex
  -> (RawNodeId, RawNodeId)
  -> Search TracePath
pathsForAddressedPair index strategies (intervention, need) =
  bindSearch (measureStrategiesForAddressedPair index intervention need) $ \measureStrategies ->
    bindSearch
      (situationsByAnchorSearch index (traceMeasureContexts measureStrategies)) $ \situationsByAnchor ->
      bindSearch (measureKeyResultPairsSearch index measureStrategies) $ \pairsByStrategy ->
        bindSearch (nodeBucketSearch (traceMeasureStrategies measureStrategies)) $ \strategy ->
          bindSearch (strategyRolesSearch strategies strategy) $ \roles ->
            expandVisionLinks
              (traceCoresForStrategyMeasure
                 index
                 situationsByAnchor
                 (contextsForStrategyMeasure measureStrategies strategy)
                 roles
                 (Map.findWithDefault Set.empty strategy pairsByStrategy))
              (visionLinksForStrategy index strategy roles)

-- | Group target Measures by Strategies that qualify one addressed Need.
measureStrategiesForAddressedPair ::
     TraceSearchIndex -> RawNodeId -> RawNodeId -> Search TraceMeasureStrategies
measureStrategiesForAddressedPair index intervention need =
  Search
    { searchValues =
        [ TraceMeasureStrategies intervention need measure groupedStrategies
        | (measure, groupedStrategies) <- Map.toAscList strategiesByMeasure
        ]
    , searchWorkOf = searchWorkOf strategyMeasures
    }
  where
    strategyMeasures =
      bindSearch qualifyingStrategies $ \strategy ->
        bindSearch (outgoingSearch index framesMeasureName strategy) $ \measure ->
          mapSearch
            (const (measure, strategy))
            (edgeGuard index setsTargetForMeasureName intervention measure)
    strategiesByMeasure =
      foldl'
        (\grouped (measure, strategy) -> insertSet measure strategy grouped)
        Map.empty
        (searchValues strategyMeasures)
    qualifyingStrategies =
      bindSearch (incomingSearch index qualifiesNeedName need) $ \strategy ->
        mapSearch
          (const strategy)
          (edgeGuard index directsInterventionName strategy intervention)

-- | Join Measure-bound Intervention KRs to their owning Strategy once.
measureKeyResultPairsSearch ::
     TraceSearchIndex
  -> TraceMeasureStrategies
  -> Search (Map RawNodeId (Set (RawNodeId, RawNodeId)))
measureKeyResultPairsSearch index measureStrategies =
  Search
    { searchValues = [pairsByStrategy]
    , searchWorkOf = searchWorkOf strategyPairs
    }
  where
    strategyPairs =
      bindSearch measureTargetKeyResults $ \interventionKeyResult ->
        bindSearch
          (outgoingSearch
             index
             contributesInterventionKeyResultName
             interventionKeyResult) $ \strategyKeyResult ->
          mapSearch
            (\strategy -> (strategy, (interventionKeyResult, strategyKeyResult)))
            (strategyOwnerSearch strategyKeyResult)
    measureTargetKeyResults =
      edgeBucketSearch
        (Map.findWithDefault
           Set.empty
           ( traceMeasureStrategiesMeasure measureStrategies
           , traceMeasureStrategiesIntervention measureStrategies)
           (indexedMeasureTargetKeyResults index))
    strategyOwnerSearch strategyKeyResult =
      Search
        { searchValues =
            [ strategy
            | Just (strategy, KeyResult) <-
                [Map.lookup strategyKeyResult (indexedPrimitiveOwnership index)]
            , Set.member strategy (traceMeasureStrategies measureStrategies)
            ]
        , searchWorkOf = mempty {traceNodeMembershipProbes = 2}
        }
    pairsByStrategy =
      foldl'
        (\grouped (strategy, pair) ->
           Map.insertWith Set.union strategy (Set.singleton pair) grouped)
        Map.empty
        (searchValues strategyPairs)

contextsForStrategyMeasure ::
     TraceMeasureStrategies -> RawNodeId -> TraceContexts
contextsForStrategyMeasure measureStrategies strategy =
  TraceContexts
    { traceContextStrategy = strategy
    , traceContextNeed = traceMeasureStrategiesNeed measureStrategies
    , traceContextIntervention =
        traceMeasureStrategiesIntervention measureStrategies
    , traceContextMeasure = traceMeasureStrategiesMeasure measureStrategies
    }

data TraceMeasureStrategies = TraceMeasureStrategies
  { traceMeasureStrategiesIntervention :: RawNodeId
  , traceMeasureStrategiesNeed :: RawNodeId
  , traceMeasureStrategiesMeasure :: RawNodeId
  , traceMeasureStrategies :: Set RawNodeId
  }

traceMeasureContexts :: TraceMeasureStrategies -> TraceMeasureContexts
traceMeasureContexts measureStrategies =
  TraceMeasureContexts
    { traceMeasureIntervention =
        traceMeasureStrategiesIntervention measureStrategies
    , traceMeasureNeed = traceMeasureStrategiesNeed measureStrategies
    , traceMeasureMeasure = traceMeasureStrategiesMeasure measureStrategies
    }

data TraceMeasureContexts = TraceMeasureContexts
  { traceMeasureIntervention :: RawNodeId
  , traceMeasureNeed :: RawNodeId
  , traceMeasureMeasure :: RawNodeId
  }

data TraceContexts = TraceContexts
  { traceContextStrategy :: RawNodeId
  , traceContextNeed :: RawNodeId
  , traceContextIntervention :: RawNodeId
  , traceContextMeasure :: RawNodeId
  }

data TraceSpine = TraceSpine
  { traceSpineContexts :: TraceContexts
  , traceSpineRoles :: TraceStrategyRoleIndex
  , traceSpineStrategyKeyResult :: RawNodeId
  , traceSpineStrategyAction :: RawNodeId
  , traceSpineNeedDriver :: RawNodeId
  , traceSpineNeedObjective :: RawNodeId
  , traceSpineInterventionAction :: RawNodeId
  , traceSpineInterventionKeyResult :: RawNodeId
  , traceSpineMeasureDimension :: RawNodeId
  , traceSpineMeasureKPI :: RawNodeId
  }

data TraceCore = TraceCore
  { traceCoreSpine :: TraceSpine
  , traceCoreAnchor :: RawNodeId
  , traceCoreAnchorKind :: SituationAnchor
  , traceCoreSituation :: RawNodeId
  }

data VisionLink = VisionLink
  { visionLinkVision :: RawNodeId
  , visionLinkObjective :: RawNodeId
  }

data AnchoredTraceSpine = AnchoredTraceSpine
  { anchoredTraceSpine :: TraceSpine
  , anchoredTraceAnchor :: RawNodeId
  , anchoredTraceAnchorKind :: SituationAnchor
  }

-- | Derive one Measure-bound spine from its Intervention Key Result.
anchoredPrimitiveSpines ::
     TraceSearchIndex
  -> TraceContexts
  -> TraceStrategyRoleIndex
  -> Set (RawNodeId, RawNodeId)
  -> Search AnchoredTraceSpine
anchoredPrimitiveSpines index contexts roles keyResultPairs =
  bindSearch strategyFoundation $ \() ->
    bindSearch (edgeBucketSearch keyResultPairs) $ \(interventionKeyResult, strategyKeyResult) ->
      bindSearch
        (nodeMembershipSearch
           (Set.member strategyKeyResult (indexedRoleKeyResults roles))) $ \() ->
        bindSearch
          (edgeGuard
             index
             substantiatesStrategyObjectiveName
             strategyKeyResult
             (indexedRoleObjective roles)) $ \() ->
          bindSearch
            (interventionActionsForKeyResult
               index
               contexts
               interventionKeyResult) $ \interventionAction ->
            bindSearch
              (strategyActionsForSpine
                 index
                 roles
                 strategyKeyResult
                 interventionAction) $ \strategyAction ->
              bindSearch
                (anchoredMeasureNeedPaths
                   index
                   contexts
                   roles
                   strategyKeyResult
                   interventionKeyResult
                   interventionAction) $ \(dimension, kpi, needDriver, needObjective, anchor, anchorKind) ->
                Search
                  { searchValues =
                      [ makeAnchoredSpine
                          strategyKeyResult
                          strategyAction
                          needDriver
                          needObjective
                          interventionAction
                          interventionKeyResult
                          dimension
                          kpi
                          anchor
                          anchorKind
                      ]
                  , searchWorkOf = mempty
                  }
  where
    strategyFoundation =
      edgeGuard
        index
        groundsStrategyObjectiveName
        (indexedRoleDriver roles)
        (indexedRoleObjective roles)
    makeAnchoredSpine strategyKeyResult strategyAction needDriver needObjective interventionAction interventionKeyResult dimension kpi anchor anchorKind =
      AnchoredTraceSpine
        { anchoredTraceSpine =
            TraceSpine
              { traceSpineContexts = contexts
              , traceSpineRoles = roles
              , traceSpineStrategyKeyResult = strategyKeyResult
              , traceSpineStrategyAction = strategyAction
              , traceSpineNeedDriver = needDriver
              , traceSpineNeedObjective = needObjective
              , traceSpineInterventionAction = interventionAction
              , traceSpineInterventionKeyResult = interventionKeyResult
              , traceSpineMeasureDimension = dimension
              , traceSpineMeasureKPI = kpi
              }
        , anchoredTraceAnchor = anchor
        , anchoredTraceAnchorKind = anchorKind
        }

interventionActionsForKeyResult ::
     TraceSearchIndex -> TraceContexts -> RawNodeId -> Search RawNodeId
interventionActionsForKeyResult index contexts interventionKeyResult =
  bindSearch
    (incomingSearch
       index
       contributesInterventionActionName
       interventionKeyResult) $ \interventionAction ->
    mapSearch
      (const interventionAction)
      (primitiveGuard
         index
         (traceContextIntervention contexts)
         Action
         interventionAction)

strategyActionsForSpine ::
     TraceSearchIndex
  -> TraceStrategyRoleIndex
  -> RawNodeId
  -> RawNodeId
  -> Search RawNodeId
strategyActionsForSpine index roles strategyKeyResult interventionAction =
  bindSearch
    (selectiveEdgeIntersectionSearch
       (Map.findWithDefault
          Set.empty
          (contributesStrategyActionName, strategyKeyResult)
          (indexedIncoming index))
       (Map.findWithDefault
          Set.empty
          (guidesInterventionActionName, interventionAction)
          (indexedIncoming index))) $ \strategyAction ->
    mapSearch
      (const strategyAction)
      (nodeMembershipSearch
         (Set.member strategyAction (indexedRoleActions roles)))

-- | Join Measure, anchored Need, and Objective facts without cross products.
anchoredMeasureNeedPaths ::
     TraceSearchIndex
  -> TraceContexts
  -> TraceStrategyRoleIndex
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> Search
       (RawNodeId, RawNodeId, RawNodeId, RawNodeId, RawNodeId, SituationAnchor)
anchoredMeasureNeedPaths index contexts roles strategyKeyResult interventionKeyResult interventionAction =
  bindSearch changedAnchorsSearch $ \changedAnchorSet ->
    bindSearch (edgeBucketSearch targetedKPIs) $ \kpi ->
      bindSearch (outgoingSearch index measuresAnchorName kpi) $ \anchor ->
        bindSearch (edgeMembershipSearch changedAnchorSet anchor) $ \() ->
          bindSearch (anchorKindSearch index anchor) $ \anchorKind ->
            bindSearch (incomingSearch index containsMeasureKPIName kpi) $ \dimension ->
              bindSearch
                (structuringGuard
                   index
                   (traceContextMeasure contexts)
                   PerformanceDimension
                   dimension) $ \() ->
                bindSearch
                  (edgeGuard
                     index
                     indicatesMeasureDimensionName
                     (indexedRoleDriver roles)
                     dimension) $ \() ->
                  bindSearch
                    (edgeGuard
                       index
                       determinesMeasureDimensionName
                       strategyKeyResult
                       dimension) $ \() ->
                    bindSearch
                      (outgoingSearch index anchorsNeedDriverName anchor) $ \needDriver ->
                      bindSearch
                        (primitiveGuard
                           index
                           (traceContextNeed contexts)
                           Driver
                           needDriver) $ \() ->
                        mapSearch
                          (\needObjective ->
                             ( dimension
                             , kpi
                             , needDriver
                             , needObjective
                             , anchor
                             , anchorKind))
                          (needObjectivesForSpine
                             index
                             contexts
                             needDriver
                             strategyKeyResult
                             interventionKeyResult)
  where
    changedAnchorsSearch =
      Search
        { searchValues = [indexedChangedAnchors]
        , searchWorkOf = mempty {traceEdgeBucketProbes = 1}
        }
    indexedChangedAnchors =
      Map.findWithDefault
        Set.empty
        (changesAnchorName, interventionAction)
        (indexedOutgoing index)
    targetedKPIs =
      Map.findWithDefault
        Set.empty
        (traceContextMeasure contexts, interventionKeyResult)
        (indexedMeasureTargetKPIs index)

needObjectivesForSpine ::
     TraceSearchIndex
  -> TraceContexts
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> Search RawNodeId
needObjectivesForSpine index contexts needDriver strategyKeyResult interventionKeyResult =
  bindSearch
    (selectiveThreeWayEdgeIntersectionSearch
       (Map.findWithDefault
          Set.empty
          (groundsNeedObjectiveName, needDriver)
          (indexedOutgoing index))
       (Map.findWithDefault
          Set.empty
          (translatesNeedObjectiveName, strategyKeyResult)
          (indexedOutgoing index))
       (Map.findWithDefault
          Set.empty
          (substantiatesNeedObjectiveName, interventionKeyResult)
          (indexedOutgoing index))) $ \needObjective ->
    mapSearch
      (const needObjective)
      (primitiveGuard index (traceContextNeed contexts) Objective needObjective)

-- | Index macrocompatible Situations once by their persisted anchor.
situationsByAnchorSearch ::
     TraceSearchIndex
  -> TraceMeasureContexts
  -> Search (Map RawNodeId (Set RawNodeId))
situationsByAnchorSearch index measureContexts =
  Search
    { searchValues = [situationsByAnchor | not (Map.null situationsByAnchor)]
    , searchWorkOf =
        searchWorkOf compatibleSituations
          <> foldMap (searchWorkOf . snd) anchoredSituations
          <> mempty {tracePathExtensions = length associations}
    }
  where
    compatibleSituations =
      bindSearch (outgoingSearch index measuresSituationName measure) $ \situation ->
        bindSearch (edgeGuard index changesSituationName intervention situation) $ \() ->
          mapSearch
            (const situation)
            (edgeGuard index surfacesNeedName situation need)
    anchoredSituations =
      [ (situation, outgoingSearch index constitutedByAnchorName situation)
      | situation <- searchValues compatibleSituations
      ]
    associations =
      [ (anchor, situation)
      | (situation, anchors) <- anchoredSituations
      , anchor <- searchValues anchors
      ]
    situationsByAnchor =
      foldl'
        (\grouped (anchor, situation) -> insertSet anchor situation grouped)
        Map.empty
        associations
    intervention = traceMeasureIntervention measureContexts
    need = traceMeasureNeed measureContexts
    measure = traceMeasureMeasure measureContexts

-- | Read only macrocompatible Situations persisted for one completed anchor.
situationsForAnchor ::
     Map RawNodeId (Set RawNodeId) -> RawNodeId -> Search RawNodeId
situationsForAnchor situationsByAnchor anchor =
  edgeBucketSearch (Map.findWithDefault Set.empty anchor situationsByAnchor)

-- | Complete Situation-attached paths before expanding oriented Visions.
traceCoresForStrategyMeasure ::
     TraceSearchIndex
  -> Map RawNodeId (Set RawNodeId)
  -> TraceContexts
  -> TraceStrategyRoleIndex
  -> Set (RawNodeId, RawNodeId)
  -> Search TraceCore
traceCoresForStrategyMeasure index situationsByAnchor contexts roles keyResultPairs =
  bindSearch (anchoredPrimitiveSpines index contexts roles keyResultPairs) $ \anchoredSpine ->
    mapSearch
      (TraceCore
         (anchoredTraceSpine anchoredSpine)
         (anchoredTraceAnchor anchoredSpine)
         (anchoredTraceAnchorKind anchoredSpine))
      (situationsForAnchor
         situationsByAnchor
         (anchoredTraceAnchor anchoredSpine))

-- | Read compatible Vision links in Vision-then-Objective identifier order.
visionLinksForStrategy ::
     TraceSearchIndex
  -> RawNodeId
  -> TraceStrategyRoleIndex
  -> Search VisionLink
visionLinksForStrategy index strategy roles =
  Search
    { searchValues =
        [ VisionLink vision objective
        | (vision, visionObjectives) <- Map.toAscList objectivesByVision
        , objective <- Set.toAscList visionObjectives
        ]
    , searchWorkOf =
        searchWorkOf objectiveSearch
          <> mempty
               { traceEdgeBucketProbes = 1
               , traceNodeMembershipProbes = length objectives
               , traceEdgeMembershipProbes = length objectives
               }
    }
  where
    orientedVisions =
      Map.findWithDefault
        Set.empty
        (orientsStrategyName, strategy)
        (indexedIncoming index)
    objectiveSearch =
      incomingSearch
        index
        orientsVisionObjectiveName
        (indexedRoleObjective roles)
    objectives = searchValues objectiveSearch
    objectivesByVision = foldl' addObjective Map.empty objectives
    addObjective grouped objective =
      case Map.lookup objective (indexedPrimitiveOwnership index) of
        Just (vision, Objective)
          | Set.member vision orientedVisions ->
            insertSet vision objective grouped
        _ -> grouped

-- | Expand completed cores only after their Strategy has compatible Visions.
expandVisionLinks :: Search TraceCore -> Search VisionLink -> Search TracePath
expandVisionLinks coreSearch visionSearch
  | null cores =
    Search {searchValues = [], searchWorkOf = searchWorkOf coreSearch}
  | otherwise =
    Search
      { searchValues =
          [makeTracePath core vision | vision <- visions, core <- cores]
      , searchWorkOf =
          searchWorkOf coreSearch
            <> searchWorkOf visionSearch
            <> mempty {tracePathExtensions = length cores * length visions}
      }
  where
    cores = searchValues coreSearch
    visions = searchValues visionSearch

makeTracePath :: TraceCore -> VisionLink -> TracePath
makeTracePath core vision =
  TracePath
    { pathVision = visionLinkVision vision
    , pathVisionObjective = visionLinkObjective vision
    , pathStrategy = traceContextStrategy contexts
    , pathStrategyDriver = indexedRoleDriver roles
    , pathStrategyObjective = indexedRoleObjective roles
    , pathStrategyKeyResult = traceSpineStrategyKeyResult spine
    , pathStrategyAction = traceSpineStrategyAction spine
    , pathNeed = traceContextNeed contexts
    , pathNeedDriver = traceSpineNeedDriver spine
    , pathNeedObjective = traceSpineNeedObjective spine
    , pathIntervention = traceContextIntervention contexts
    , pathInterventionAction = traceSpineInterventionAction spine
    , pathInterventionKeyResult = traceSpineInterventionKeyResult spine
    , pathMeasure = traceContextMeasure contexts
    , pathMeasurePerformanceDimension = traceSpineMeasureDimension spine
    , pathMeasureKPI = traceSpineMeasureKPI spine
    , pathSituation = traceCoreSituation core
    , pathSituationAnchor = traceCoreAnchor core
    , pathSituationAnchorKind = traceCoreAnchorKind core
    }
  where
    spine = traceCoreSpine core
    contexts = traceSpineContexts spine
    roles = traceSpineRoles spine

addressesNeedName, changesSituationName, surfacesNeedName :: RelationName
addressesNeedName = relationNameFor addressesNeed

changesSituationName = relationNameFor changesSituation

surfacesNeedName = relationNameFor surfacesNeed

qualifiesNeedName, directsInterventionName :: RelationName
qualifiesNeedName = relationNameFor qualifiesNeed

directsInterventionName = relationNameFor directsIntervention

setsTargetForMeasureName, framesMeasureName :: RelationName
setsTargetForMeasureName = relationNameFor setsTargetForMeasure

framesMeasureName = relationNameFor framesMeasure

measuresSituationName, orientsStrategyName :: RelationName
measuresSituationName = relationNameFor measuresSituation

orientsStrategyName = relationNameFor orientsStrategy

orientsVisionObjectiveName, groundsStrategyObjectiveName :: RelationName
orientsVisionObjectiveName =
  relationNameFor orientsVisionObjectiveToStrategyObjective

groundsStrategyObjectiveName = relationNameFor groundsStrategyDriverToObjective

substantiatesStrategyObjectiveName, contributesStrategyActionName ::
     RelationName
substantiatesStrategyObjectiveName =
  relationNameFor substantiatesStrategyKeyResultObjective

contributesStrategyActionName =
  relationNameFor contributesStrategyActionToKeyResult

translatesNeedObjectiveName, groundsNeedObjectiveName :: RelationName
translatesNeedObjectiveName =
  relationNameFor translatesStrategyKeyResultToNeedObjective

groundsNeedObjectiveName = relationNameFor groundsNeedDriverToObjective

substantiatesNeedObjectiveName, contributesInterventionKeyResultName ::
     RelationName
substantiatesNeedObjectiveName =
  relationNameFor substantiatesInterventionKeyResultNeedObjective

contributesInterventionKeyResultName =
  relationNameFor contributesInterventionKeyResultToStrategyKeyResult

contributesInterventionActionName, guidesInterventionActionName :: RelationName
contributesInterventionActionName =
  relationNameFor contributesInterventionActionToKeyResult

guidesInterventionActionName =
  relationNameFor guidesStrategyActionToInterventionAction

containsMeasureKPIName, indicatesMeasureDimensionName :: RelationName
containsMeasureKPIName =
  relationNameFor (containsPerformanceDimension MeasureMeasurementDimension)

indicatesMeasureDimensionName =
  relationNameFor indicatesMeasurePerformanceDimension

determinesMeasureDimensionName, setsTargetForKPIName :: RelationName
determinesMeasureDimensionName =
  relationNameFor determinesMeasurePerformanceDimension

setsTargetForKPIName = relationNameFor setsTargetForMeasureKPI

constitutedByAnchorName, anchorsNeedDriverName :: RelationName
constitutedByAnchorName = anchorRelationFamilyName ConstitutedByAnchorFamily

anchorsNeedDriverName = anchorRelationFamilyName AnchorsNeedDriverFamily

changesAnchorName, measuresAnchorName :: RelationName
changesAnchorName = anchorRelationFamilyName ChangesAnchorFamily

measuresAnchorName = anchorRelationFamilyName MeasuresAnchorFamily
