{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

-- | Private deterministic typed domains and exact occurrence projections.
module O2I.Validation.Relational.Index
  ( RelationalIndex
  , IndexBuildWork(..)
  , buildRelationalIndex
  , indexBuildWork
  , nodeDomainFor
  , premiseSourceDomain
  , premiseTargetDomain
  , premiseSuccessors
  , premisePredecessors
  , premiseLoopDomain
  , exactPremiseOccurrences
  ) where

import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Type.Equality ((:~:)(Refl))
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Internal

-- | Exact build operations retained with the completed index.
data IndexBuildWork = IndexBuildWork
  { buildNodesRead :: !Int
  , buildNodeDomainInsertions :: !Int
  , buildEdgesRead :: !Int
  , buildCanonicalOccurrencesAssigned :: !Int
  , buildProjectionInsertions :: !Int
  , buildExactOccurrenceInsertions :: !Int
  , buildRelationProjectionsCreated :: !Int
  } deriving (Eq, Show)

data SomeNodeDomain where
  SomeNodeDomain :: SNodeKind kind -> Domain kind -> SomeNodeDomain

data LoopDomain from to where
  DifferentKindLoopDomain :: LoopDomain from to
  SameKindLoopDomain :: Domain kind -> LoopDomain kind kind

data RelationProjection from to = RelationProjection
  { projectionRelation :: Relation from to
  , projectionSources :: Domain from
  , projectionTargets :: Domain to
  , projectionOutgoing :: Map (NodeId from) (Domain to)
  , projectionIncoming :: Map (NodeId to) (Domain from)
  , projectionLoops :: LoopDomain from to
  , projectionOccurrences :: Map
      (NodeId from, NodeId to)
      [EdgeOccurrence from to]
  }

data SomeRelationProjection where
  SomeRelationProjection :: RelationProjection from to -> SomeRelationProjection

type ProjectionKey = (RelationCode, NodeKindValue, NodeKindValue)

-- | Closed typed index over one structurally validated graph.
data RelationalIndex = RelationalIndex
  { indexedNodeDomains :: Map NodeKindValue SomeNodeDomain
  , indexedRelationProjections :: Map ProjectionKey [SomeRelationProjection]
  , indexBuildWork :: IndexBuildWork
  }

-- | Build typed projections independently of input node and edge order.
--
-- Occurrences are ordered by relation code, source, then target. Exact
-- duplicates can only arise in direct index-unit fixtures because structural
-- validation rejects them before a production 'WellFormedGraph' is built.
buildRelationalIndex :: WellFormedGraph -> RelationalIndex
buildRelationalIndex graph =
  let nodes = graphNodes graph
      edges = sortOn edgeOrderKey (graphEdges graph)
      occurrences = zipWith canonicalOccurrence [0 ..] edges
      nodeIndex = foldr insertNodeDomain Map.empty nodes
      projectionIndex = foldr insertCanonicalOccurrence Map.empty occurrences
      projectionCount = sum (map length (Map.elems projectionIndex))
      edgeCount = length occurrences
   in RelationalIndex
        { indexedNodeDomains = nodeIndex
        , indexedRelationProjections = projectionIndex
        , indexBuildWork =
            IndexBuildWork
              { buildNodesRead = length nodes
              , buildNodeDomainInsertions = length nodes
              , buildEdgesRead = edgeCount
              , buildCanonicalOccurrencesAssigned = edgeCount
              , buildProjectionInsertions = edgeCount
              , buildExactOccurrenceInsertions = edgeCount
              , buildRelationProjectionsCreated = projectionCount
              }
        }

data CanonicalOccurrence where
  CanonicalOccurrence :: Int -> Edge from to -> CanonicalOccurrence

canonicalOccurrence :: Int -> SomeEdge -> CanonicalOccurrence
canonicalOccurrence ordinal (SomeEdge edge) = CanonicalOccurrence ordinal edge

edgeOrderKey :: SomeEdge -> (ProjectionKey, RawNodeId, RawNodeId)
edgeOrderKey (SomeEdge edge) =
  ( projectionKey (edgeRelation edge)
  , unNodeId (edgeFrom edge)
  , unNodeId (edgeTo edge))

projectionKey :: Relation from to -> ProjectionKey
projectionKey relation =
  let spec = relationSpec relation
   in ( relationCode spec
      , nodeKindValue (relationFrom spec)
      , nodeKindValue (relationTo spec))

insertNodeDomain ::
     SomeNode
  -> Map NodeKindValue SomeNodeDomain
  -> Map NodeKindValue SomeNodeDomain
insertNodeDomain (SomeNode node) domains =
  Map.alter (Just . extend) (nodeKindValue (nodeKind node)) domains
  where
    extend Nothing =
      SomeNodeDomain (nodeKind node) (singletonDomain (nodeId node))
    extend (Just (SomeNodeDomain existingKind existingDomain)) =
      case eqSNodeKind (nodeKind node) existingKind of
        Just Refl ->
          SomeNodeDomain
            existingKind
            (domainInsert (nodeId node) existingDomain)
        Nothing -> SomeNodeDomain existingKind existingDomain

insertCanonicalOccurrence ::
     CanonicalOccurrence
  -> Map ProjectionKey [SomeRelationProjection]
  -> Map ProjectionKey [SomeRelationProjection]
insertCanonicalOccurrence occurrence@(CanonicalOccurrence _ edge) =
  Map.alter
    (Just . insertProjection occurrence . maybe [] id)
    (projectionKey (edgeRelation edge))

insertProjection ::
     CanonicalOccurrence -> [SomeRelationProjection] -> [SomeRelationProjection]
insertProjection occurrence [] = [newProjection occurrence]
insertProjection occurrence (candidate:rest) =
  case occurrence of
    CanonicalOccurrence ordinal edge ->
      case candidate of
        SomeRelationProjection projection ->
          case matchProjection (edgeRelation edge) projection of
            Just Refl ->
              SomeRelationProjection (extendProjection ordinal edge projection)
                : rest
            Nothing -> candidate : insertProjection occurrence rest

matchProjection ::
     Relation from to
  -> RelationProjection candidateFrom candidateTo
  -> Maybe ('( from, to) :~: '( candidateFrom, candidateTo))
matchProjection expected projection
  | relationCode (relationSpec expected) /= relationCode (relationSpec actual) =
    Nothing
  | otherwise = do
    Refl <-
      eqSNodeKind
        (relationFrom (relationSpec expected))
        (relationFrom (relationSpec actual))
    Refl <-
      eqSNodeKind
        (relationTo (relationSpec expected))
        (relationTo (relationSpec actual))
    pure Refl
  where
    actual = projectionRelation projection

newProjection :: CanonicalOccurrence -> SomeRelationProjection
newProjection (CanonicalOccurrence ordinal edge) =
  let from = edgeFrom edge
      to = edgeTo edge
      occurrence = mkEdgeOccurrence ordinal edge
   in SomeRelationProjection
        RelationProjection
          { projectionRelation = edgeRelation edge
          , projectionSources = singletonDomain from
          , projectionTargets = singletonDomain to
          , projectionOutgoing = Map.singleton from (singletonDomain to)
          , projectionIncoming = Map.singleton to (singletonDomain from)
          , projectionLoops = initialLoopDomain edge
          , projectionOccurrences = Map.singleton (from, to) [occurrence]
          }

initialLoopDomain :: Edge from to -> LoopDomain from to
initialLoopDomain edge =
  case eqSNodeKind
         (relationFrom (relationSpec (edgeRelation edge)))
         (relationTo (relationSpec (edgeRelation edge))) of
    Nothing -> DifferentKindLoopDomain
    Just Refl
      | edgeFrom edge == edgeTo edge ->
        SameKindLoopDomain (singletonDomain (edgeFrom edge))
      | otherwise -> SameKindLoopDomain emptyDomain

extendProjection ::
     Int
  -> Edge from to
  -> RelationProjection from to
  -> RelationProjection from to
extendProjection ordinal edge projection =
  let from = edgeFrom edge
      to = edgeTo edge
      occurrence = mkEdgeOccurrence ordinal edge
   in projection
        { projectionSources = domainInsert from (projectionSources projection)
        , projectionTargets = domainInsert to (projectionTargets projection)
        , projectionOutgoing =
            Map.alter
              (Just . maybe (singletonDomain to) (domainInsert to))
              from
              (projectionOutgoing projection)
        , projectionIncoming =
            Map.alter
              (Just . maybe (singletonDomain from) (domainInsert from))
              to
              (projectionIncoming projection)
        , projectionLoops = extendLoopDomain edge (projectionLoops projection)
        , projectionOccurrences =
            Map.insertWith
              (++)
              (from, to)
              [occurrence]
              (projectionOccurrences projection)
        }

extendLoopDomain :: Edge from to -> LoopDomain from to -> LoopDomain from to
extendLoopDomain _ DifferentKindLoopDomain = DifferentKindLoopDomain
extendLoopDomain edge loops@(SameKindLoopDomain domain)
  | edgeFrom edge == edgeTo edge =
    SameKindLoopDomain (domainInsert (edgeFrom edge) domain)
  | otherwise = loops

-- | Return every node of one kind in canonical identifier order.
nodeDomainFor :: SNodeKind kind -> RelationalIndex -> Domain kind
nodeDomainFor expected index =
  case expected of
    SContextKind context ->
      lookupNodeDomain expected (ContextNodeKind (contextValue context)) index
    SPrimitiveKind context primitive ->
      lookupNodeDomain
        expected
        (PrimitiveNodeKind (contextValue context) (primitiveValue primitive))
        index
    SPerformanceDimensionKind role ->
      lookupNodeDomain
        expected
        (StructuringNodeKind
           (contextValue (performanceDimensionRoleContext role))
           PerformanceDimension)
        index
    SAnchorKind anchor ->
      lookupNodeDomain expected (AnchorNodeKind (anchorValue anchor)) index

lookupNodeDomain ::
     SNodeKind kind -> NodeKindValue -> RelationalIndex -> Domain kind
lookupNodeDomain expected key index =
  case Map.lookup key (indexedNodeDomains index) of
    Nothing -> emptyDomain
    Just (SomeNodeDomain actual domain) ->
      case eqSNodeKind expected actual of
        Just Refl -> domain
        Nothing -> emptyDomain

-- | Return distinct source nodes participating in one premise relation.
premiseSourceDomain :: Premise scope from to -> RelationalIndex -> Domain from
premiseSourceDomain premise index =
  maybe emptyDomain projectionSources (projectionFor premise index)

-- | Return distinct target nodes participating in one premise relation.
premiseTargetDomain :: Premise scope from to -> RelationalIndex -> Domain to
premiseTargetDomain premise index =
  maybe emptyDomain projectionTargets (projectionFor premise index)

-- | Return distinct targets connected to one bound premise source.
premiseSuccessors ::
     Premise scope from to -> NodeId from -> RelationalIndex -> Domain to
premiseSuccessors premise source index =
  case projectionFor premise index of
    Nothing -> emptyDomain
    Just projection ->
      Map.findWithDefault emptyDomain source (projectionOutgoing projection)

-- | Return distinct sources connected to one bound premise target.
premisePredecessors ::
     Premise scope from to -> NodeId to -> RelationalIndex -> Domain from
premisePredecessors premise target index =
  case projectionFor premise index of
    Nothing -> emptyDomain
    Just projection ->
      Map.findWithDefault emptyDomain target (projectionIncoming projection)

-- | Return nodes having an exact self occurrence of one premise relation.
premiseLoopDomain :: Premise scope kind kind -> RelationalIndex -> Domain kind
premiseLoopDomain premise index =
  case projectionFor premise index of
    Nothing -> emptyDomain
    Just projection ->
      case projectionLoops projection of
        SameKindLoopDomain domain -> domain
        DifferentKindLoopDomain -> emptyDomain

-- | Return exact persisted occurrences associated with one typed premise.
exactPremiseOccurrences ::
     Premise scope from to
  -> NodeId from
  -> NodeId to
  -> RelationalIndex
  -> [EdgeOccurrence from to]
exactPremiseOccurrences premise from to index =
  case projectionFor premise index of
    Nothing -> []
    Just projection ->
      Map.findWithDefault [] (from, to) (projectionOccurrences projection)

projectionFor ::
     Premise scope from to
  -> RelationalIndex
  -> Maybe (RelationProjection from to)
projectionFor premise index =
  search
    (Map.findWithDefault
       []
       (projectionKey (premiseRelation premise))
       (indexedRelationProjections index))
  where
    search [] = Nothing
    search (SomeRelationProjection projection:rest) =
      case matchProjection (premiseRelation premise) projection of
        Just Refl -> Just projection
        Nothing -> search rest
