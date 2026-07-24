{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeOperators #-}

-- | Structural validation from unchecked to typed O2I graphs.
--
-- Structural validation proves identifier, ownership, interpretation, and
-- relation-endpoint integrity without asserting semantic completeness.
module O2I.Validation.Structure
  ( StructuralError(..)
  , StructureInternalError(..)
  , StructuralAssessment
  , StructureResult(..)
  , validateStructure
  , validateClaimStructure
  , structuralGraph
  , structuralCandidatePropositions
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
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation

-- | Structural violations detected while validating a 'RawGraph'.
data StructuralError
  = DuplicateNodeId RawNodeId
    -- ^ More than one node declares the same identifier.
  | DuplicateEdge RawEdge
    -- ^ The exact same directed edge occurs more than once.
  | UnknownOwner RawNodeId RawNodeId
    -- ^ A child node identifies an owner that is not a declared context.
  | AssertedNodeDependsOnCandidate RawNodeId RawNodeId
    -- ^ An asserted owned node depends on a candidate Context declaration.
  | InvalidPrimitiveInterpretation RawNodeId Context Primitive
    -- ^ A Primitive is inadmissible in its owning Context.
  | InvalidStructuringContext RawNodeId Context Structuring
    -- ^ A structuring form is inadmissible in its owning Context.
  | UnknownEdgeEndpoint RawEdge RawNodeId
    -- ^ An edge endpoint does not identify a declared node.
  | AssertedEdgeDependsOnCandidate RawEdge RawNodeId
    -- ^ An asserted edge depends on a candidate endpoint declaration.
  | UnknownRelation RelationName
    -- ^ An edge names no registered O2I relation.
  | InvalidRelationEndpointKinds RawEdge NodeKindValue NodeKindValue
    -- ^ Endpoint kinds do not match the named relation specification.
  | PerformanceDimensionMembershipOwnerMismatch RawEdge RawNodeId RawNodeId
    -- ^ PerformanceDimension and member have different owning Context IDs.
  deriving (Eq, Show)

-- | Internal failures after a graph has passed every structural model check.
data StructureInternalError
  = ContextTypingInvariant RawNodeId
    -- ^ A checked Context declaration could not be typed.
  | ChildTypingInvariant RawNodeId
    -- ^ A checked Primitive, structuring element, or anchor could not be typed.
  | EdgeTypingInvariant RawEdge
    -- ^ A checked relation could not be typed.
  deriving (Eq, Show)

-- | Total outcome of structural model validation and typing.
data StructureResult
  = StructureModelRejected (NonEmpty.NonEmpty StructuralError)
    -- ^ The model violates one or more independently accumulated rules.
  | StructureAccepted StructuralAssessment
    -- ^ Every proposition is structurally valid and assertions are typed.
  | StructureInternalFailure StructureInternalError
    -- ^ An implementation invariant failed after successful model validation.

-- | Opaque structural result separating asserted semantics from candidates.
--
-- The graph contains only asserted propositions. Retained candidates have
-- passed the same applicable identity, ownership, interpretation, relation,
-- endpoint-kind, and membership-owner checks but remain outside that graph.
data StructuralAssessment =
  StructuralAssessment WellFormedGraph [CandidateGraphProposition]

newtype StructurallyAdmissibleRawGraph =
  StructurallyAdmissibleRawGraph RawClaimGraph

-- | Read the exact asserted graph established by structural validation.
structuralGraph :: StructuralAssessment -> WellFormedGraph
structuralGraph (StructuralAssessment graph _) = graph

-- | Read structurally admissible candidates excluded from the asserted graph.
structuralCandidatePropositions ::
     StructuralAssessment -> [CandidateGraphProposition]
structuralCandidatePropositions (StructuralAssessment _ candidates) = candidates

-- * Structural validation
-- | Validate unchecked input as an opaque structurally typed graph.
--
-- Independent errors accumulate. Success guarantees unique IDs and edges,
-- valid ownership and interpretations, known relations, typed endpoints, and
-- one shared owner Context instance for each PerformanceDimension membership.
validateStructure :: RawGraph -> StructureResult
validateStructure raw =
  validateClaimStructure
    RawClaimGraph
      { rawNodeClaims = map assertedClaim (rawNodes raw)
      , rawEdgeClaims = map assertedClaim (rawEdges raw)
      }

-- | Validate explicit node and relation claims as the asserted typed graph.
--
-- Every proposition is structurally inspected. Candidate propositions may
-- depend on asserted or candidate declarations. Asserted propositions may
-- depend only on asserted declarations; commitments are never promoted or
-- downgraded.
validateClaimStructure :: RawClaimGraph -> StructureResult
validateClaimStructure raw =
  case collectStructuralErrors raw of
    Failure failures -> StructureModelRejected failures
    Success admissible ->
      case typeStructure admissible of
        Left internal -> StructureInternalFailure internal
        Right assessment -> StructureAccepted assessment

collectStructuralErrors ::
     RawClaimGraph
  -> Validation
       (NonEmpty.NonEmpty StructuralError)
       StructurallyAdmissibleRawGraph
collectStructuralErrors raw =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing -> Success (StructurallyAdmissibleRawGraph raw)
  where
    errors = nodeErrors raw ++ edgeErrors raw

nodeErrors :: RawClaimGraph -> [StructuralError]
nodeErrors raw = duplicateIdErrors ++ concatMap validateClaim nodeClaims
  where
    nodeClaims = rawNodeClaims raw
    nodes = map claimedProposition nodeClaims
    assertedNodes = assertedValues nodeClaims
    candidateNodes = candidateValues nodeClaims
    assertedIdentifiers = map rawNodeId assertedNodes
    candidateOnlyIdentifiers =
      [ rawNodeId node
      | node <- candidateNodes
      , rawNodeId node `notElem` assertedIdentifiers
      ]
    identifiers = map rawNodeId nodes
    duplicateIdErrors = map DuplicateNodeId (duplicates identifiers)
    assertedOwners = contextKindsOf assertedNodes
    owners = contextKindsOf nodes
    validateClaim claim =
      validateNode (claimCommitment claim) (claimedProposition claim)
    validateNode _ (RawContextNode _ _) = []
    validateNode commitment (RawPrimitiveNode identifier owner primitive) =
      case Map.lookup owner owners of
        Nothing -> [UnknownOwner identifier owner]
        Just context ->
          dependencyErrors commitment identifier owner
            ++ [ InvalidPrimitiveInterpretation identifier context primitive
               | isNothing (lookupInterpretation context primitive)
               ]
    validateNode commitment (RawStructuringNode identifier owner structuring) =
      case Map.lookup owner owners of
        Nothing -> [UnknownOwner identifier owner]
        Just context ->
          dependencyErrors commitment identifier owner
            ++ [ InvalidStructuringContext identifier context structuring
               | isNothing (lookupPerformanceDimensionRole context)
               ]
    validateNode _ (RawAnchorNode _ _) = []
    dependencyErrors commitment identifier owner =
      [ AssertedNodeDependsOnCandidate identifier owner
      | commitment == Asserted
      , owner `elem` candidateOnlyIdentifiers
      , Map.notMember owner assertedOwners
      ]

edgeErrors :: RawClaimGraph -> [StructuralError]
edgeErrors raw = duplicateEdgeErrors ++ concatMap validateClaim edgeClaims
  where
    edgeClaims = rawEdgeClaims raw
    edges = map claimedProposition edgeClaims
    assertedIdentifiers = map rawNodeId (assertedValues (rawNodeClaims raw))
    candidateOnlyIdentifiers =
      [ rawNodeId node
      | node <- candidateValues (rawNodeClaims raw)
      , rawNodeId node `notElem` assertedIdentifiers
      ]
    duplicateEdgeErrors = map DuplicateEdge (duplicates edges)
    kinds = rawNodeKinds raw
    declarations =
      Map.fromListWith
        (++)
        [ (rawNodeId node, [node])
        | node <- map claimedProposition (rawNodeClaims raw)
        ]
    validateClaim claim =
      validateEdge (claimCommitment claim) (claimedProposition claim)
    validateEdge commitment edge =
      endpointErrors commitment candidateOnlyIdentifiers edge fromKind toKind
        ++ relationErrors edge fromKind toKind candidates
        ++ performanceDimensionMembershipOwnerErrors
             edge
             declarations
             fromKind
             toKind
             candidates
      where
        fromKind = Map.lookup (rawEdgeFrom edge) kinds
        toKind = Map.lookup (rawEdgeTo edge) kinds
        candidates = lookupRelations (rawEdgeRelation edge)

endpointErrors ::
     Commitment
  -> [RawNodeId]
  -> RawEdge
  -> Maybe NodeKindValue
  -> Maybe NodeKindValue
  -> [StructuralError]
endpointErrors commitment candidates edge fromKind toKind =
  endpointError (rawEdgeFrom edge) fromKind
    ++ endpointError (rawEdgeTo edge) toKind
  where
    endpointError identifier kind
      | commitment == Asserted
      , identifier `elem` candidates =
        [AssertedEdgeDependsOnCandidate edge identifier]
      | not (isNothing kind) = []
      | otherwise = [UnknownEdgeEndpoint edge identifier]

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

performanceDimensionMembershipOwnerErrors ::
     RawEdge
  -> Map RawNodeId [RawNode]
  -> Maybe NodeKindValue
  -> Maybe NodeKindValue
  -> [SomeRelation]
  -> [StructuralError]
performanceDimensionMembershipOwnerErrors edge declarations (Just fromKind) (Just toKind) candidates
  | any isMatchingMembership candidates =
    case ( uniqueDeclaration (rawEdgeFrom edge)
         , uniqueDeclaration (rawEdgeTo edge)) of
      (Just (RawStructuringNode _ dimensionOwner PerformanceDimension), Just (RawPrimitiveNode _ memberOwner _))
        | dimensionOwner /= memberOwner ->
          [ PerformanceDimensionMembershipOwnerMismatch
              edge
              dimensionOwner
              memberOwner
          ]
      _ -> []
  where
    isMatchingMembership relation@(SomeRelation witness) =
      matchesKinds fromKind toKind relation
        && case relationCode (relationSpec witness) of
             PerformanceDimensionMembership _ -> True
             _ -> False
    uniqueDeclaration identifier =
      case Map.lookup identifier declarations of
        Just [node] -> Just node
        _ -> Nothing
performanceDimensionMembershipOwnerErrors _ _ _ _ _ = []

typeStructure ::
     StructurallyAdmissibleRawGraph
  -> Either StructureInternalError StructuralAssessment
typeStructure (StructurallyAdmissibleRawGraph raw) = do
  contexts <- traverse buildContext contextNodes
  let contextMap = Map.fromList [(someNodeRawId node, node) | node <- contexts]
  children <- traverse (buildChild contextMap) childNodes
  let nodes =
        Map.fromList [(someNodeRawId node, node) | node <- contexts ++ children]
  edges <- traverse (buildEdge nodes) assertedEdges
  pure
    (StructuralAssessment (mkWellFormedGraph nodes edges) candidatePropositions)
  where
    assertedNodes = assertedValues (rawNodeClaims raw)
    assertedEdges = assertedValues (rawEdgeClaims raw)
    contextNodes = [node | node@(RawContextNode _ _) <- assertedNodes]
    childNodes = [node | node <- assertedNodes, not (isContextNode node)]
    candidatePropositions =
      map CandidateNodeProposition (candidateValues (rawNodeClaims raw))
        ++ map CandidateEdgeProposition (candidateValues (rawEdgeClaims raw))

buildContext :: RawNode -> Either StructureInternalError SomeNode
buildContext (RawContextNode identifier context) =
  case someSContext context of
    SomeSContext witness ->
      Right (SomeNode (ContextNode (mkNodeId identifier) witness))
buildContext node = Left (ContextTypingInvariant (rawNodeId node))

buildChild ::
     Map RawNodeId SomeNode -> RawNode -> Either StructureInternalError SomeNode
buildChild contexts node =
  case buildChildMaybe contexts node of
    Just child -> Right child
    Nothing -> Left (ChildTypingInvariant (rawNodeId node))

buildChildMaybe :: Map RawNodeId SomeNode -> RawNode -> Maybe SomeNode
buildChildMaybe contexts (RawPrimitiveNode identifier owner primitive) = do
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
buildChildMaybe contexts (RawStructuringNode identifier owner PerformanceDimension) = do
  SomeNode (ContextNode ownerId context) <- Map.lookup owner contexts
  SomePerformanceDimensionRole role <-
    lookupPerformanceDimensionRole (contextValue context)
  Refl <-
    eqSNodeKind
      (SContextKind context)
      (SContextKind (performanceDimensionRoleContext role))
  pure (SomeNode (PerformanceDimensionNode (mkNodeId identifier) ownerId role))
buildChildMaybe _ (RawAnchorNode identifier anchor) = do
  SomeSAnchor witness <- pure (someSAnchor anchor)
  pure (SomeNode (AnchorNode (mkNodeId identifier) witness))
buildChildMaybe _ (RawContextNode _ _) = Nothing

buildEdge ::
     Map RawNodeId SomeNode -> RawEdge -> Either StructureInternalError SomeEdge
buildEdge nodes raw =
  case buildEdgeMaybe nodes raw of
    Just result -> Right result
    Nothing -> Left (EdgeTypingInvariant raw)

buildEdgeMaybe :: Map RawNodeId SomeNode -> RawEdge -> Maybe SomeEdge
buildEdgeMaybe nodes raw = do
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
rawNodeId (RawAnchorNode identifier _) = identifier

someNodeRawId :: SomeNode -> RawNodeId
someNodeRawId (SomeNode node) = unNodeId (nodeId node)

isContextNode :: RawNode -> Bool
isContextNode (RawContextNode _ _) = True
isContextNode _ = False

contextKindsOf :: [RawNode] -> Map RawNodeId Context
contextKindsOf nodes =
  Map.fromList
    [(identifier, context) | RawContextNode identifier context <- nodes]

rawNodeKinds :: RawClaimGraph -> Map RawNodeId NodeKindValue
rawNodeKinds raw = Map.fromList (mapMaybeKind nodes)
  where
    nodes = map claimedProposition (rawNodeClaims raw)
    owners = contextKindsOf nodes
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
rawKind _ (RawAnchorNode _ anchor) = Just (AnchorNodeKind anchor)

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort

assertedValues :: [Claim value] -> [value]
assertedValues claims =
  [ claimedProposition proposition
  | proposition <- claims
  , claimCommitment proposition == Asserted
  ]

candidateValues :: [Claim value] -> [value]
candidateValues claims =
  [ claimedProposition proposition
  | proposition <- claims
  , claimCommitment proposition == Candidate
  ]
