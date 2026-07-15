{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

-- | Structural elaboration from unchecked to typed O2I graphs.
--
-- Structural validation proves identifier, ownership, interpretation, and
-- relation-endpoint integrity without asserting semantic completeness.
module O2I.Validation.Structure
  ( StructuralError(..)
  , validateStructure
  ) where

import Data.List (group, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (isNothing)
import Data.Type.Equality ((:~:)(Refl))
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation

-- | Structural violations detected while elaborating a 'RawGraph'.
data StructuralError
  = DuplicateNodeId RawNodeId
    -- ^ More than one node declares the same identifier.
  | DuplicateEdge RawEdge
    -- ^ The exact same directed edge occurs more than once.
  | UnknownOwner RawNodeId RawNodeId
    -- ^ A child node identifies an owner that is not a declared context.
  | InvalidPrimitiveInterpretation RawNodeId Context Primitive
    -- ^ A Primitive is inadmissible in its owning Context.
  | InvalidStructuringContext RawNodeId Context Structuring
    -- ^ A structuring form is inadmissible in its owning Context.
  | InvalidAnchorContext RawNodeId Context SituationAnchor
    -- ^ A Situation anchor is not owned by a Situation context.
  | UnknownEdgeEndpoint RawEdge RawNodeId
    -- ^ An edge endpoint does not identify a declared node.
  | UnknownRelation RelationName
    -- ^ An edge names no registered O2I relation.
  | InvalidRelationEndpointKinds RawEdge NodeKindValue NodeKindValue
    -- ^ Endpoint kinds do not match the named relation specification.
  | ElaborationInvariantViolation
    -- ^ Internal elaboration failed after all public checks succeeded.
  deriving (Eq, Show)

-- * Structural validation
-- | Elaborate unchecked input into an opaque structurally typed graph.
--
-- Independent errors accumulate. Success guarantees unique IDs and edges,
-- valid ownership and interpretations, known relations, and typed endpoints.
validateStructure ::
     RawGraph -> Validation (NonEmpty.NonEmpty StructuralError) WellFormedGraph
validateStructure raw =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case buildGraph raw of
        Just graph -> Success graph
        Nothing -> Failure (NonEmpty.singleton ElaborationInvariantViolation)
  where
    errors = nodeErrors raw ++ edgeErrors raw

nodeErrors :: RawGraph -> [StructuralError]
nodeErrors raw = duplicateIdErrors ++ concatMap validateNode (rawNodes raw)
  where
    identifiers = map rawNodeId (rawNodes raw)
    duplicateIdErrors = map DuplicateNodeId (duplicates identifiers)
    owners = contextKinds raw
    validateNode (RawContextNode _ _) = []
    validateNode (RawPrimitiveNode identifier owner primitive) =
      case Map.lookup owner owners of
        Nothing -> [UnknownOwner identifier owner]
        Just context ->
          [ InvalidPrimitiveInterpretation identifier context primitive
          | isNothing (lookupInterpretation context primitive)
          ]
    validateNode (RawStructuringNode identifier owner structuring) =
      case Map.lookup owner owners of
        Nothing -> [UnknownOwner identifier owner]
        Just context ->
          [ InvalidStructuringContext identifier context structuring
          | isNothing (lookupPerformanceDimensionRole context)
          ]
    validateNode (RawAnchorNode identifier owner anchor) =
      case Map.lookup owner owners of
        Nothing -> [UnknownOwner identifier owner]
        Just context ->
          [ InvalidAnchorContext identifier context anchor
          | context /= Situation
          ]

edgeErrors :: RawGraph -> [StructuralError]
edgeErrors raw = duplicateEdgeErrors ++ concatMap validateEdge (rawEdges raw)
  where
    duplicateEdgeErrors = map DuplicateEdge (duplicates (rawEdges raw))
    kinds = rawNodeKinds raw
    validateEdge edge =
      endpointErrors edge fromKind toKind
        ++ relationErrors edge fromKind toKind candidates
      where
        fromKind = Map.lookup (rawEdgeFrom edge) kinds
        toKind = Map.lookup (rawEdgeTo edge) kinds
        candidates = lookupRelations (rawEdgeRelation edge)

endpointErrors ::
     RawEdge -> Maybe NodeKindValue -> Maybe NodeKindValue -> [StructuralError]
endpointErrors edge fromKind toKind =
  [UnknownEdgeEndpoint edge (rawEdgeFrom edge) | isNothing fromKind]
    ++ [UnknownEdgeEndpoint edge (rawEdgeTo edge) | isNothing toKind]

relationErrors ::
     RawEdge
  -> Maybe NodeKindValue
  -> Maybe NodeKindValue
  -> [SomeRelation]
  -> [StructuralError]
relationErrors edge fromKind toKind candidates =
  unknownErrors ++ endpointKindErrors
  where
    unknownErrors = [UnknownRelation (rawEdgeRelation edge) | null candidates]
    endpointKindErrors =
      case (fromKind, toKind, candidates) of
        (Just from, Just to, _:_)
          | not (any (matchesKinds from to) candidates) ->
            [InvalidRelationEndpointKinds edge from to]
        _ -> []

matchesKinds :: NodeKindValue -> NodeKindValue -> SomeRelation -> Bool
matchesKinds fromKind toKind (SomeRelation relation) =
  let spec = relationSpec relation
   in nodeKindValue (relationFrom spec) == fromKind
        && nodeKindValue (relationTo spec) == toKind

buildGraph :: RawGraph -> Maybe WellFormedGraph
buildGraph raw = do
  contexts <- traverse buildContext contextNodes
  let contextMap = Map.fromList [(someNodeRawId node, node) | node <- contexts]
  children <- traverse (buildChild contextMap) childNodes
  let nodes =
        Map.fromList [(someNodeRawId node, node) | node <- contexts ++ children]
  edges <- traverse (buildEdge nodes) (rawEdges raw)
  pure (mkWellFormedGraph nodes edges)
  where
    contextNodes = [node | node@(RawContextNode _ _) <- rawNodes raw]
    childNodes = [node | node <- rawNodes raw, not (isContextNode node)]

buildContext :: RawNode -> Maybe SomeNode
buildContext (RawContextNode identifier context) =
  case someSContext context of
    SomeSContext witness ->
      Just (SomeNode (ContextNode (mkNodeId identifier) witness))
buildContext _ = Nothing

buildChild :: Map RawNodeId SomeNode -> RawNode -> Maybe SomeNode
buildChild contexts (RawPrimitiveNode identifier owner primitive) = do
  SomeNode (ContextNode ownerId context) <- Map.lookup owner contexts
  SomeSPrimitive primitiveWitness <- pure (someSPrimitive primitive)
  SomeInterpretation spec <-
    lookupInterpretation (contextValue context) primitive
  Refl <-
    eqSNodeKind
      (SPrimitiveKind context primitiveWitness)
      (SPrimitiveKind
         (interpretationContext spec)
         (interpretationPrimitive spec))
  pure
    (SomeNode
       (PrimitiveNode
          (mkNodeId identifier)
          ownerId
          context
          primitiveWitness
          (interpretationWitness spec)))
buildChild contexts (RawStructuringNode identifier owner PerformanceDimension) = do
  SomeNode (ContextNode ownerId context) <- Map.lookup owner contexts
  SomePerformanceDimensionRole role <-
    lookupPerformanceDimensionRole (contextValue context)
  Refl <-
    eqSNodeKind
      (SContextKind context)
      (SContextKind (performanceDimensionRoleContext role))
  pure (SomeNode (PerformanceDimensionNode (mkNodeId identifier) ownerId role))
buildChild contexts (RawAnchorNode identifier owner anchor) = do
  SomeNode (ContextNode ownerId context) <- Map.lookup owner contexts
  SomeSAnchor witness <- pure (someSAnchor anchor)
  Refl <- eqSNodeKind (SContextKind context) (SContextKind SSituation)
  pure (SomeNode (AnchorNode (mkNodeId identifier) ownerId witness))
buildChild _ (RawContextNode _ _) = Nothing

buildEdge :: Map RawNodeId SomeNode -> RawEdge -> Maybe SomeEdge
buildEdge nodes raw = do
  SomeNode fromNode <- Map.lookup (rawEdgeFrom raw) nodes
  SomeNode toNode <- Map.lookup (rawEdgeTo raw) nodes
  relation <-
    firstMatching fromNode toNode (lookupRelations (rawEdgeRelation raw))
  pure relation
  where
    firstMatching :: Node left -> Node right -> [SomeRelation] -> Maybe SomeEdge
    firstMatching _ _ [] = Nothing
    firstMatching fromNode toNode (SomeRelation relation:rest) =
      let spec = relationSpec relation
       in case ( eqSNodeKind (nodeKind fromNode) (relationFrom spec)
               , eqSNodeKind (nodeKind toNode) (relationTo spec)) of
            (Just Refl, Just Refl) ->
              Just (SomeEdge (Edge (nodeId fromNode) relation (nodeId toNode)))
            _ -> firstMatching fromNode toNode rest

rawNodeId :: RawNode -> RawNodeId
rawNodeId (RawContextNode identifier _) = identifier
rawNodeId (RawPrimitiveNode identifier _ _) = identifier
rawNodeId (RawStructuringNode identifier _ _) = identifier
rawNodeId (RawAnchorNode identifier _ _) = identifier

someNodeRawId :: SomeNode -> RawNodeId
someNodeRawId (SomeNode node) = unNodeId (nodeId node)

isContextNode :: RawNode -> Bool
isContextNode (RawContextNode _ _) = True
isContextNode _ = False

contextKinds :: RawGraph -> Map RawNodeId Context
contextKinds raw =
  Map.fromList
    [(identifier, context) | RawContextNode identifier context <- rawNodes raw]

rawNodeKinds :: RawGraph -> Map RawNodeId NodeKindValue
rawNodeKinds raw = Map.fromList (mapMaybeKind (rawNodes raw))
  where
    owners = contextKinds raw
    mapMaybeKind [] = []
    mapMaybeKind (node:rest) =
      case rawKind owners node of
        Just kind -> (rawNodeId node, kind) : mapMaybeKind rest
        Nothing -> mapMaybeKind rest

rawKind :: Map RawNodeId Context -> RawNode -> Maybe NodeKindValue
rawKind _ (RawContextNode _ context) = Just (ContextNodeKind context)
rawKind owners (RawPrimitiveNode _ owner primitive) =
  PrimitiveNodeKind <$> Map.lookup owner owners <*> pure primitive
rawKind owners (RawStructuringNode _ owner structuring) =
  StructuringNodeKind <$> Map.lookup owner owners <*> pure structuring
rawKind _ (RawAnchorNode _ _ anchor) = Just (AnchorNodeKind anchor)

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort
