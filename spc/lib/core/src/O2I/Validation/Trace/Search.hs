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
      bindSearch addressedSearch (pathsForAddressedPair index strategies)
    paths = searchValues pathSearch

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

crossSearch :: Search left -> Search right -> Search (left, right)
crossSearch left right =
  Search
    { searchValues = pairs
    , searchWorkOf =
        searchWorkOf left
          <> searchWorkOf right
          <> mempty {tracePathExtensions = length pairs}
    }
  where
    pairs =
      [ (leftValue, rightValue)
      | leftValue <- searchValues left
      , rightValue <- searchValues right
      ]

valuesSearch :: Ord value => [value] -> Search value
valuesSearch values = Search (Set.toAscList (Set.fromList values)) mempty

intersectionSearch :: Ord value => [Search value] -> Search value
intersectionSearch [] = Search [] mempty
intersectionSearch searches@(first:rest) =
  Search
    { searchValues =
        Set.toAscList
          (foldl'
             Set.intersection
             (Set.fromList (searchValues first))
             (map (Set.fromList . searchValues) rest))
    , searchWorkOf = foldMap searchWorkOf searches
    }

primitiveSearch ::
     TraceSearchIndex -> RawNodeId -> Primitive -> Search RawNodeId
primitiveSearch index owner primitive =
  nodeBucketSearch
    (Map.findWithDefault Set.empty (owner, primitive) (indexedPrimitives index))

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
     Map RawNodeId TraceStrategyRoles -> RawNodeId -> Search TraceStrategyRoles
strategyRolesSearch strategies strategy =
  Search
    { searchValues = maybe [] pure (Map.lookup strategy strategies)
    , searchWorkOf = mempty {traceStrategyRoleProbes = 1}
    }

pathsForAddressedPair ::
     TraceSearchIndex
  -> Map RawNodeId TraceStrategyRoles
  -> (RawNodeId, RawNodeId)
  -> Search TracePath
pathsForAddressedPair index strategies (intervention, need) =
  bindSearch macroContexts $ \contexts ->
    bindSearch
      (strategyRolesSearch strategies (macroStrategy contexts))
      (primitivePaths index contexts)
  where
    situations =
      intersectionSearch
        [ outgoingSearch index changesSituationName intervention
        , incomingSearch index surfacesNeedName need
        ]
    qualifyingStrategies =
      intersectionSearch
        [ incomingSearch index qualifiesNeedName need
        , incomingSearch index directsInterventionName intervention
        ]
    situationStrategies = crossSearch situations qualifyingStrategies
    macroContexts =
      bindSearch situationStrategies $ \(situation, strategy) ->
        mapSearch
          (\(measure, vision) ->
             MacroContexts
               { macroVision = vision
               , macroStrategy = strategy
               , macroNeed = need
               , macroIntervention = intervention
               , macroMeasure = measure
               , macroSituation = situation
               })
          (crossSearch
             (intersectionSearch
                [ outgoingSearch index setsTargetForMeasureName intervention
                , outgoingSearch index framesMeasureName strategy
                , incomingSearch index measuresSituationName situation
                ])
             (incomingSearch index orientsStrategyName strategy))

data MacroContexts = MacroContexts
  { macroVision :: RawNodeId
  , macroStrategy :: RawNodeId
  , macroNeed :: RawNodeId
  , macroIntervention :: RawNodeId
  , macroMeasure :: RawNodeId
  , macroSituation :: RawNodeId
  }

primitivePaths ::
     TraceSearchIndex -> MacroContexts -> TraceStrategyRoles -> Search TracePath
primitivePaths index contexts roles =
  bindSearch visionObjectives $ \visionObjective ->
    bindSearch strategyBase $ \(strategyKeyResult, strategyAction) ->
      bindSearch (needPaths index contexts strategyKeyResult) $ \(needDriver, needObjective) ->
        bindSearch
          (interventionPaths
             index
             contexts
             strategyKeyResult
             strategyAction
             needObjective) $ \(interventionAction, interventionKeyResult) ->
          bindSearch
            (measurePaths
               index
               contexts
               roles
               strategyKeyResult
               interventionKeyResult) $ \(dimension, kpi) ->
            mapSearch
              (makeTracePath
                 contexts
                 roles
                 visionObjective
                 strategyKeyResult
                 strategyAction
                 needDriver
                 needObjective
                 interventionAction
                 interventionKeyResult
                 dimension
                 kpi)
              (anchorPaths index contexts needDriver interventionAction kpi)
  where
    visionObjectives =
      intersectionSearch
        [ primitiveSearch index (macroVision contexts) Objective
        , incomingSearch
            index
            orientsVisionObjectiveName
            (traceRoleObjective roles)
        ]
    strategyBase =
      bindSearch
        (edgeGuard
           index
           groundsStrategyObjectiveName
           (traceRoleDriver roles)
           (traceRoleObjective roles)) $ \() ->
        bindSearch (valuesSearch (traceRoleKeyResults roles)) $ \keyResult ->
          bindSearch
            (edgeGuard
               index
               substantiatesStrategyObjectiveName
               keyResult
               (traceRoleObjective roles)) $ \() ->
            mapSearch
              ((,) keyResult)
              (intersectionSearch
                 [ valuesSearch (traceRoleActions roles)
                 , incomingSearch index contributesStrategyActionName keyResult
                 ])

needPaths ::
     TraceSearchIndex
  -> MacroContexts
  -> RawNodeId
  -> Search (RawNodeId, RawNodeId)
needPaths index contexts strategyKeyResult =
  bindSearch needObjectives $ \needObjective ->
    bindSearch (incomingSearch index groundsNeedObjectiveName needObjective) $ \needDriver ->
      mapSearch
        (const (needDriver, needObjective))
        (primitiveGuard index (macroNeed contexts) Driver needDriver)
  where
    needObjectives =
      intersectionSearch
        [ primitiveSearch index (macroNeed contexts) Objective
        , outgoingSearch index translatesNeedObjectiveName strategyKeyResult
        ]

interventionPaths ::
     TraceSearchIndex
  -> MacroContexts
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> Search (RawNodeId, RawNodeId)
interventionPaths index contexts strategyKeyResult strategyAction needObjective =
  bindSearch interventionKeyResults $ \keyResult ->
    bindSearch
      (primitiveGuard index (macroIntervention contexts) KeyResult keyResult) $ \() ->
      bindSearch
        (edgeGuard
           index
           contributesInterventionKeyResultName
           keyResult
           strategyKeyResult) $ \() ->
        bindSearch
          (incomingSearch index contributesInterventionActionName keyResult) $ \action ->
          bindSearch
            (primitiveGuard index (macroIntervention contexts) Action action) $ \() ->
            mapSearch
              (const (action, keyResult))
              (edgeGuard
                 index
                 guidesInterventionActionName
                 strategyAction
                 action)
  where
    interventionKeyResults =
      incomingSearch index substantiatesNeedObjectiveName needObjective

measurePaths ::
     TraceSearchIndex
  -> MacroContexts
  -> TraceStrategyRoles
  -> RawNodeId
  -> RawNodeId
  -> Search (RawNodeId, RawNodeId)
measurePaths index contexts roles strategyKeyResult interventionKeyResult =
  bindSearch measureKPIs $ \kpi ->
    bindSearch (primitiveGuard index (macroMeasure contexts) KPI kpi) $ \() ->
      bindSearch (incomingSearch index containsMeasureKPIName kpi) $ \dimension ->
        bindSearch
          (structuringGuard
             index
             (macroMeasure contexts)
             PerformanceDimension
             dimension) $ \() ->
          bindSearch
            (edgeGuard
               index
               indicatesMeasureDimensionName
               (traceRoleDriver roles)
               dimension) $ \() ->
            mapSearch
              (const (dimension, kpi))
              (edgeGuard
                 index
                 determinesMeasureDimensionName
                 strategyKeyResult
                 dimension)
  where
    measureKPIs =
      outgoingSearch index setsTargetForKPIName interventionKeyResult

anchorPaths ::
     TraceSearchIndex
  -> MacroContexts
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> Search (RawNodeId, SituationAnchor)
anchorPaths index contexts needDriver interventionAction kpi =
  bindSearch (outgoingSearch index changesAnchorName interventionAction) $ \anchor ->
    bindSearch
      (edgeGuard index constitutedByAnchorName (macroSituation contexts) anchor) $ \() ->
      bindSearch (edgeGuard index anchorsNeedDriverName anchor needDriver) $ \() ->
        bindSearch (edgeGuard index measuresAnchorName kpi anchor) $ \() ->
          mapSearch ((,) anchor) (anchorKindSearch index anchor)

makeTracePath ::
     MacroContexts
  -> TraceStrategyRoles
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> (RawNodeId, SituationAnchor)
  -> TracePath
makeTracePath contexts roles visionObjective strategyKeyResult strategyAction needDriver needObjective interventionAction interventionKeyResult dimension kpi (anchor, anchorKind) =
  TracePath
    { pathVision = macroVision contexts
    , pathVisionObjective = visionObjective
    , pathStrategy = macroStrategy contexts
    , pathStrategyDriver = traceRoleDriver roles
    , pathStrategyObjective = traceRoleObjective roles
    , pathStrategyKeyResult = strategyKeyResult
    , pathStrategyAction = strategyAction
    , pathNeed = macroNeed contexts
    , pathNeedDriver = needDriver
    , pathNeedObjective = needObjective
    , pathIntervention = macroIntervention contexts
    , pathInterventionAction = interventionAction
    , pathInterventionKeyResult = interventionKeyResult
    , pathMeasure = macroMeasure contexts
    , pathMeasurePerformanceDimension = dimension
    , pathMeasureKPI = kpi
    , pathSituation = macroSituation contexts
    , pathSituationAnchor = anchor
    , pathSituationAnchorKind = anchorKind
    }

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
