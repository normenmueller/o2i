{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

-- | Structurally typed O2I graph and total graph queries.
--
-- Graph modules instantiate the O2I language. They establish local graph
-- well-formedness; global semantic completeness belongs to Validation.
module O2I.Graph.Typed
  ( Node(..)
  , SomeNode(..)
  , Edge(..)
  , SomeEdge(..)
  , WellFormedGraph
  , mkWellFormedGraph
  , graphNodes
  , graphEdges
  , nodeId
  , nodeKind
  , nodeOwner
  , someNodeId
  , someNodeKind
  , someNodeOwner
  , someEdgeFrom
  , someEdgeRelation
  , someEdgeTo
  , lookupNode
  , lookupContextRef
  , contextNodesOf
  , primitiveNodesIn
  , performanceDimensionNodesIn
  , constitutingAnchorNodes
  , hasEdge
  , outgoingContextTargets
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Type.Equality ((:~:)(Refl))
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation

-- * Typed graph
-- | Structurally validated node indexed by its complete semantic kind.
data Node (kind :: NodeKind) where
  ContextNode
    :: NodeId ('ContextKind context)
    -> SContext context
    -> Node ('ContextKind context)
    -- ^ Validated context node.
  PrimitiveNode
    :: NodeId ('PrimitiveKind context primitive)
    -> NodeId ('ContextKind context)
    -> SContext context
    -> SPrimitive primitive
    -> Interpretation context primitive
    -> Node ('PrimitiveKind context primitive)
    -- ^ Validated contextualized Primitive with interpretation proof.
  PerformanceDimensionNode
    :: NodeId ('StructuringKind context 'PerformanceDimension)
    -> NodeId ('ContextKind context)
    -> PerformanceDimensionRole context member
    -> Node ('StructuringKind context 'PerformanceDimension)
    -- ^ Validated performance dimension whose role fixes its member kind.
  AnchorNode
    :: NodeId ('AnchorKind anchor)
    -> SSituationAnchor anchor
    -> Node ('AnchorKind anchor)
    -- ^ Validated Situation anchor.

deriving instance Show (Node kind)

-- | Existential validated node for heterogeneous graph storage.
data SomeNode where
  SomeNode :: Node kind -> SomeNode
    -- ^ Hide the node-kind index while retaining its typed node.

instance Show SomeNode where
  show (SomeNode node) = show node

-- | Structurally validated edge whose endpoint kinds match its relation.
data Edge (from :: NodeKind) (to :: NodeKind) = Edge
  { edgeFrom :: NodeId from -- ^ Typed source node identifier.
  , edgeRelation :: Relation from to -- ^ Typed admissibility witness.
  , edgeTo :: NodeId to -- ^ Typed target node identifier.
  }

-- | Existential validated edge for heterogeneous graph storage.
data SomeEdge where
  SomeEdge :: Edge from to -> SomeEdge
    -- ^ Hide endpoint indices while retaining a typed edge.

instance Show SomeEdge where
  show (SomeEdge edge) =
    show
      ( unNodeId (edgeFrom edge)
      , relationName (relationSpec (edgeRelation edge))
      , unNodeId (edgeTo edge))

instance Eq SomeEdge where
  SomeEdge left == SomeEdge right =
    unNodeId (edgeFrom left) == unNodeId (edgeFrom right)
      && relationName (relationSpec (edgeRelation left))
           == relationName (relationSpec (edgeRelation right))
      && unNodeId (edgeTo left) == unNodeId (edgeTo right)

-- | Read the source identifier of a validated edge.
someEdgeFrom :: SomeEdge -> RawNodeId
someEdgeFrom (SomeEdge edge) = unNodeId (edgeFrom edge)

-- | Read the serialized relation name of a validated edge.
someEdgeRelation :: SomeEdge -> RelationName
someEdgeRelation (SomeEdge edge) = relationNameFor (edgeRelation edge)

-- | Read the target identifier of a validated edge.
someEdgeTo :: SomeEdge -> RawNodeId
someEdgeTo (SomeEdge edge) = unNodeId (edgeTo edge)

-- * Well-formed graph stage
-- | Opaque graph with valid IDs, ownership, interpretations, and edges.
--
-- PerformanceDimension memberships share one owner Context instance.
-- Construction is restricted to structural validation.
data WellFormedGraph = WellFormedGraph
  { typedNodes :: Map RawNodeId SomeNode
  , typedEdges :: [SomeEdge]
  }

-- | Internal constructor used after all structural checks have succeeded.
mkWellFormedGraph :: Map RawNodeId SomeNode -> [SomeEdge] -> WellFormedGraph
mkWellFormedGraph = WellFormedGraph

-- | Enumerate validated nodes without exposing graph constructors.
graphNodes :: WellFormedGraph -> [SomeNode]
graphNodes = Map.elems . typedNodes

-- | Enumerate validated edges without exposing graph constructors.
graphEdges :: WellFormedGraph -> [SomeEdge]
graphEdges = typedEdges

-- | Read the kind-indexed identifier of a validated node.
nodeId :: Node kind -> NodeId kind
nodeId (ContextNode identifier _) = identifier
nodeId (PrimitiveNode identifier _ _ _ _) = identifier
nodeId (PerformanceDimensionNode identifier _ _) = identifier
nodeId (AnchorNode identifier _) = identifier

-- | Recover the singleton kind witness carried by a validated node.
nodeKind :: Node kind -> SNodeKind kind
nodeKind (ContextNode _ context) = SContextKind context
nodeKind (PrimitiveNode _ _ context primitive _) =
  SPrimitiveKind context primitive
nodeKind (PerformanceDimensionNode _ _ role) = SPerformanceDimensionKind role
nodeKind (AnchorNode _ anchor) = SAnchorKind anchor

-- | Return the owning Context ID of a Primitive or structuring element.
nodeOwner :: Node kind -> Maybe RawNodeId
nodeOwner (ContextNode _ _) = Nothing
nodeOwner (PrimitiveNode _ owner _ _ _) = Just (unNodeId owner)
nodeOwner (PerformanceDimensionNode _ owner _) = Just (unNodeId owner)
nodeOwner (AnchorNode _ _) = Nothing

-- | Read an existential validated node identifier.
someNodeId :: SomeNode -> RawNodeId
someNodeId (SomeNode node) = unNodeId (nodeId node)

-- | Read the complete runtime kind of an existential validated node.
someNodeKind :: SomeNode -> NodeKindValue
someNodeKind (SomeNode node) = nodeKindValue (nodeKind node)

-- | Read the optional owner of an existential validated node.
someNodeOwner :: SomeNode -> Maybe RawNodeId
someNodeOwner (SomeNode node) = nodeOwner node

-- | Look up a validated node by its unique raw identifier.
lookupNode :: WellFormedGraph -> RawNodeId -> Maybe SomeNode
lookupNode graph identifier = Map.lookup identifier (typedNodes graph)

-- | Resolve a raw identifier as a context reference of the requested type.
--
-- Resolution succeeds only for a validated context node of exactly that type.
lookupContextRef ::
     WellFormedGraph
  -> SContext context
  -> RawNodeId
  -> Maybe (ContextRef context)
lookupContextRef graph expected identifier = do
  SomeNode (ContextNode stored actual) <- lookupNode graph identifier
  Refl <- eqSNodeKind (SContextKind actual) (SContextKind expected)
  pure (mkContextRef (unNodeId stored))

-- | Enumerate context-node identifiers of the requested context type.
contextNodesOf :: WellFormedGraph -> Context -> [RawNodeId]
contextNodesOf graph expected =
  [ unNodeId identifier
  | SomeNode (ContextNode identifier context) <- graphNodes graph
  , contextValue context == expected
  ]

-- | Enumerate primitive nodes of a kind owned by one context node.
primitiveNodesIn :: WellFormedGraph -> RawNodeId -> Primitive -> [RawNodeId]
primitiveNodesIn graph owner expected =
  [ unNodeId identifier
  | SomeNode (PrimitiveNode identifier context _ primitive _) <-
      graphNodes graph
  , unNodeId context == owner
  , primitiveValue primitive == expected
  ]

-- | Enumerate typed performance dimensions of one role and owning Context.
performanceDimensionNodesIn ::
     WellFormedGraph
  -> ContextRef context
  -> PerformanceDimensionRole context member
  -> [NodeId ('StructuringKind context 'PerformanceDimension)]
performanceDimensionNodesIn graph owner role =
  [ nodeId node
  | SomeNode node@(PerformanceDimensionNode _ context storedRole) <-
      graphNodes graph
  , unNodeId context == contextRefId owner
  , performanceDimensionRoleCode storedRole == performanceDimensionRoleCode role
  , Just Refl <- [eqSNodeKind (nodeKind node) (SPerformanceDimensionKind role)]
  ]

-- | Enumerate anchors related as constituents of one Situation.
constitutingAnchorNodes :: WellFormedGraph -> RawNodeId -> [RawNodeId]
constitutingAnchorNodes graph situation =
  [ unNodeId (edgeTo edge)
  | SomeEdge edge <- graphEdges graph
  , unNodeId (edgeFrom edge) == situation
  , AnchorRelation ConstitutedByAnchorFamily _ <-
      [relationCode (relationSpec (edgeRelation edge))]
  ]

-- | Test whether an exact validated edge exists.
hasEdge :: WellFormedGraph -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasEdge graph from relation to = any matches (graphEdges graph)
  where
    matches (SomeEdge edge) =
      unNodeId (edgeFrom edge) == from
        && relationName (relationSpec (edgeRelation edge)) == relation
        && unNodeId (edgeTo edge) == to

-- * Graph queries
-- | Find context targets reached from a source by a named context relation.
outgoingContextTargets ::
     WellFormedGraph -> RawNodeId -> RelationName -> [RawNodeId]
outgoingContextTargets graph from relation =
  [ unNodeId (edgeTo edge)
  | SomeEdge edge <- graphEdges graph
  , unNodeId (edgeFrom edge) == from
  , relationName (relationSpec (edgeRelation edge)) == relation
  ]
