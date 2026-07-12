{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

-- | Typed concrete O2I model graph and safe graph queries.
module O2I.Model
  ( Node(..)
  , SomeNode(..)
  , Edge(..)
  , SomeEdge(..)
  , WellFormedModel
  , mkWellFormedModel
  , modelNodes
  , modelEdges
  , nodeId
  , nodeKind
  , nodeOwner
  , lookupNode
  , contextNodesOf
  , primitiveNodesIn
  , structuringNodesIn
  , anchorNodesIn
  , hasEdge
  , outgoingContextTargets
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Relation
import O2I.Types

-- * Typed model graph
data Node (kind :: NodeKind) where
  ContextNode
    :: NodeId ('ContextKind context)
    -> SContext context
    -> Node ('ContextKind context)
  PrimitiveNode
    :: NodeId ('PrimitiveKind context primitive)
    -> NodeId ('ContextKind context)
    -> SContext context
    -> SPrimitive primitive
    -> Interpretation context primitive
    -> Node ('PrimitiveKind context primitive)
  StructuringNode
    :: NodeId ('StructuringKind context structuring)
    -> NodeId ('ContextKind context)
    -> SContext context
    -> SStructuring structuring
    -> Node ('StructuringKind context structuring)
  AnchorNode
    :: NodeId ('AnchorKind anchor)
    -> NodeId ('ContextKind 'Situation)
    -> SSituationAnchor anchor
    -> Node ('AnchorKind anchor)

deriving instance Show (Node kind)

data SomeNode where
  SomeNode :: Node kind -> SomeNode

instance Show SomeNode where
  show (SomeNode node) = show node

data Edge (from :: NodeKind) (to :: NodeKind) = Edge
  { edgeFrom :: NodeId from
  , edgeRelation :: Relation from to
  , edgeTo :: NodeId to
  }

data SomeEdge where
  SomeEdge :: Edge from to -> SomeEdge

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

-- * Validated model stage
data WellFormedModel = WellFormedModel
  { typedNodes :: Map RawNodeId SomeNode
  , typedEdges :: [SomeEdge]
  }

mkWellFormedModel :: Map RawNodeId SomeNode -> [SomeEdge] -> WellFormedModel
mkWellFormedModel = WellFormedModel

modelNodes :: WellFormedModel -> [SomeNode]
modelNodes = Map.elems . typedNodes

modelEdges :: WellFormedModel -> [SomeEdge]
modelEdges = typedEdges

nodeId :: Node kind -> NodeId kind
nodeId (ContextNode identifier _) = identifier
nodeId (PrimitiveNode identifier _ _ _ _) = identifier
nodeId (StructuringNode identifier _ _ _) = identifier
nodeId (AnchorNode identifier _ _) = identifier

nodeKind :: Node kind -> SNodeKind kind
nodeKind (ContextNode _ context) = SContextKind context
nodeKind (PrimitiveNode _ _ context primitive _) =
  SPrimitiveKind context primitive
nodeKind (StructuringNode _ _ context structuring) =
  SStructuringKind context structuring
nodeKind (AnchorNode _ _ anchor) = SAnchorKind anchor

nodeOwner :: Node kind -> Maybe RawNodeId
nodeOwner (ContextNode _ _) = Nothing
nodeOwner (PrimitiveNode _ owner _ _ _) = Just (unNodeId owner)
nodeOwner (StructuringNode _ owner _ _) = Just (unNodeId owner)
nodeOwner (AnchorNode _ owner _) = Just (unNodeId owner)

lookupNode :: WellFormedModel -> RawNodeId -> Maybe SomeNode
lookupNode model identifier = Map.lookup identifier (typedNodes model)

contextNodesOf :: WellFormedModel -> Context -> [RawNodeId]
contextNodesOf model expected =
  [ unNodeId identifier
  | SomeNode (ContextNode identifier context) <- modelNodes model
  , contextValue context == expected
  ]

primitiveNodesIn :: WellFormedModel -> RawNodeId -> Primitive -> [RawNodeId]
primitiveNodesIn model owner expected =
  [ unNodeId identifier
  | SomeNode (PrimitiveNode identifier context _ primitive _) <-
      modelNodes model
  , unNodeId context == owner
  , primitiveValue primitive == expected
  ]

structuringNodesIn :: WellFormedModel -> RawNodeId -> Structuring -> [RawNodeId]
structuringNodesIn model owner expected =
  [ unNodeId identifier
  | SomeNode (StructuringNode identifier context _ structuring) <-
      modelNodes model
  , unNodeId context == owner
  , structuringValue structuring == expected
  ]

anchorNodesIn :: WellFormedModel -> RawNodeId -> [RawNodeId]
anchorNodesIn model owner =
  [ unNodeId identifier
  | SomeNode (AnchorNode identifier context _) <- modelNodes model
  , unNodeId context == owner
  ]

hasEdge :: WellFormedModel -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasEdge model from relation to = any matches (modelEdges model)
  where
    matches (SomeEdge edge) =
      unNodeId (edgeFrom edge) == from
        && relationName (relationSpec (edgeRelation edge)) == relation
        && unNodeId (edgeTo edge) == to

-- * Graph queries
outgoingContextTargets ::
     WellFormedModel -> RawNodeId -> RelationName -> [RawNodeId]
outgoingContextTargets model from relation =
  [ unNodeId (edgeTo edge)
  | SomeEdge edge <- modelEdges model
  , unNodeId (edgeFrom edge) == from
  , relationName (relationSpec (edgeRelation edge)) == relation
  ]
