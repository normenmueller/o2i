-- | Generic concrete O2I model graph.
module O2I.Graph
  ( ContextNode(..)
  , PrimitiveNode(..)
  , StructuringNode(..)
  , AnchorNode(..)
  , NodeRef(..)
  , Edge(..)
  , Model(..)
  , nodeKindValue
  , contextKind
  , primitiveContextAndKind
  , structuringContextAndKind
  , anchorKind
  , contextIds
  , primitiveIds
  , structuringIds
  , anchorIds
  , strategyIds
  , needIds
  , situationIds
  , interventionIds
  , measureIds
  , hasEdge
  , hasIncomingContextEdge
  , primitiveRefsInContext
  , structuringRefsInContext
  , anchorRefsInContext
  , addressedNeeds
  ) where

import O2I.Elements
import O2I.Relation

-- * Model graph
data ContextNode =
  ContextNode ContextId Context
  deriving (Eq, Show)

data PrimitiveNode =
  PrimitiveNode PrimitiveId ContextId Primitive
  deriving (Eq, Show)

data StructuringNode =
  StructuringNode StructuringId ContextId Structuring
  deriving (Eq, Show)

data AnchorNode =
  AnchorNode AnchorId ContextId SituationAnchor
  deriving (Eq, Show)

data NodeRef
  = CtxRef ContextId
  | PrimRef PrimitiveId
  | StructRef StructuringId
  | AnchorRef AnchorId
  deriving (Eq, Show)

data Edge =
  Edge NodeRef SomeRelation NodeRef
  deriving (Eq, Show)

data Model = Model
  { contextNodes :: [ContextNode]
  , primitiveNodes :: [PrimitiveNode]
  , structuringNodes :: [StructuringNode]
  , anchorNodes :: [AnchorNode]
  , edges :: [Edge]
  } deriving (Eq, Show)

-- * Graph queries
nodeKindValue :: Model -> NodeRef -> Maybe NodeKindValue
nodeKindValue m (CtxRef c) = ContextNodeKind <$> contextKind m c
nodeKindValue m (PrimRef p) =
  (\(c, k) -> PrimitiveNodeKind c k) <$> primitiveContextAndKind m p
nodeKindValue m (StructRef s) =
  (\(c, k) -> StructuringNodeKind c k) <$> structuringContextAndKind m s
nodeKindValue m (AnchorRef a) = AnchorNodeKind <$> anchorKind m a

contextKind :: Model -> ContextId -> Maybe Context
contextKind m c = lookup c [(i, k) | ContextNode i k <- contextNodes m]

primitiveContextAndKind :: Model -> PrimitiveId -> Maybe (Context, Primitive)
primitiveContextAndKind m p =
  case [(c, k) | PrimitiveNode i c k <- primitiveNodes m, i == p] of
    (c, k):_ -> (\context -> (context, k)) <$> contextKind m c
    [] -> Nothing

structuringContextAndKind ::
     Model -> StructuringId -> Maybe (Context, Structuring)
structuringContextAndKind m s =
  case [(c, k) | StructuringNode i c k <- structuringNodes m, i == s] of
    (c, k):_ -> (\context -> (context, k)) <$> contextKind m c
    [] -> Nothing

anchorKind :: Model -> AnchorId -> Maybe SituationAnchor
anchorKind m a = lookup a [(i, k) | AnchorNode i _ k <- anchorNodes m]

contextIds :: Model -> [ContextId]
contextIds m = [i | ContextNode i _ <- contextNodes m]

primitiveIds :: Model -> [PrimitiveId]
primitiveIds m = [i | PrimitiveNode i _ _ <- primitiveNodes m]

structuringIds :: Model -> [StructuringId]
structuringIds m = [i | StructuringNode i _ _ <- structuringNodes m]

anchorIds :: Model -> [AnchorId]
anchorIds m = [i | AnchorNode i _ _ <- anchorNodes m]

strategyIds :: Model -> [ContextId]
strategyIds m = [i | ContextNode i Strategy <- contextNodes m]

needIds :: Model -> [ContextId]
needIds m = [i | ContextNode i Need <- contextNodes m]

situationIds :: Model -> [ContextId]
situationIds m = [i | ContextNode i Situation <- contextNodes m]

interventionIds :: Model -> [ContextId]
interventionIds m = [i | ContextNode i Intervention <- contextNodes m]

measureIds :: Model -> [ContextId]
measureIds m = [i | ContextNode i Measure <- contextNodes m]

hasEdge :: Model -> NodeRef -> SomeRelation -> NodeRef -> Bool
hasEdge m from rel to = Edge from rel to `elem` edges m

hasIncomingContextEdge :: Model -> SomeRelation -> Context -> ContextId -> Bool
hasIncomingContextEdge m rel fromKind to = any matches (edges m)
  where
    matches (Edge (CtxRef from) rel' (CtxRef to')) =
      rel == rel' && to == to' && contextKind m from == Just fromKind
    matches _ = False

primitiveRefsInContext :: Model -> ContextId -> Primitive -> [NodeRef]
primitiveRefsInContext m context primitive =
  [ PrimRef i
  | PrimitiveNode i c p <- primitiveNodes m
  , c == context
  , p == primitive
  ]

structuringRefsInContext :: Model -> ContextId -> Structuring -> [NodeRef]
structuringRefsInContext m context structuring =
  [ StructRef i
  | StructuringNode i c s <- structuringNodes m
  , c == context
  , s == structuring
  ]

anchorRefsInContext :: Model -> ContextId -> [NodeRef]
anchorRefsInContext m context =
  [AnchorRef i | AnchorNode i c _ <- anchorNodes m, c == context]

addressedNeeds :: Model -> ContextId -> [ContextId]
addressedNeeds m intervention =
  [ to
  | Edge (CtxRef from) rel (CtxRef to) <- edges m
  , from == intervention
  , rel == SomeRelation AddressesNeed
  ]
