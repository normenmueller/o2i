{-# LANGUAGE GADTs #-}

-- | Cabal-private occurrence index for macro-relation interpretation.
--
-- This module contains storage and lookup mechanics only. It knows neither
-- typed macro claims nor evidence sufficiency. Its deterministic work measure
-- is an internal performance contract used by the private index test suite;
-- it is not part of the public O2I graph API.
module O2I.Graph.Macro.Index
  ( FactIndex
  , OccurrenceFact
  , factOrdinal
  , factOccurrence
  , factValue
  , MacroLookupWork
  , macroLookupNodeOccurrences
  , macroLookupEdgeBucketProbes
  , macroLookupEdgeOccurrences
  , macroLookupClaimOccurrences
  , IndexedLookup(..)
  , buildFactIndex
  , orderedEdgeFacts
  , contextFactsFor
  , claimBucketLookup
  , premiseEdgeFactsBetween
  , ownedPrimitiveIdentifiers
  , ownedStructuringIdentifiers
  , constituentAnchorIdentifiers
  ) where

import Data.List (foldl', sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation

-- | One persisted fact paired with source order and occurrence identity.
data OccurrenceFact occurrence value = OccurrenceFact
  { factOrdinal :: Int
  , factOccurrence :: occurrence
  , factValue :: value
  }

-- | One stable adjacency bucket with an eagerly cached occurrence count.
data OccurrenceBucket occurrence value = OccurrenceBucket
  { occurrenceBucketCardinality :: !Int
  , occurrenceBucketFacts :: [OccurrenceFact occurrence value]
  }

-- | Occurrence-preserving indexes over persisted graph facts.
--
-- Primitive owner/type buckets also determine canonical Interpretation,
-- because O2I admits exactly one Interpretation per Context/Primitive pair.
data FactIndex node edge = FactIndex
  { indexedContextsByIdentity :: Map
      (RawNodeId, Context)
      [OccurrenceFact node RawNode]
  , indexedPrimitivesByOwnerType :: Map
      (RawNodeId, Primitive)
      [OccurrenceFact node RawNode]
  , indexedStructuringByOwnerType :: Map
      (RawNodeId, Structuring)
      [OccurrenceFact node RawNode]
  , indexedEdgesByCodeSource :: Map
      (RelationCode, RawNodeId)
      (OccurrenceBucket edge RawEdge)
  , indexedEdgesByCodeTarget :: Map
      (RelationCode, RawNodeId)
      (OccurrenceBucket edge RawEdge)
  , indexedConstituentAnchors :: Map RawNodeId [RawNodeId]
  , indexedEdgesInOrder :: [OccurrenceFact edge RawEdge]
  }

-- | Deterministic occurrence work performed by addressed bucket lookups.
data MacroLookupWork = MacroLookupWork
  { macroLookupNodeOccurrences :: Int
    -- ^ Node occurrences read from addressed selector buckets.
  , macroLookupEdgeBucketProbes :: Int
    -- ^ Relation/endpoint adjacency buckets addressed by premise lookup.
  , macroLookupEdgeOccurrences :: Int
    -- ^ Edge occurrences visited in addressed adjacency buckets.
  , macroLookupClaimOccurrences :: Int
    -- ^ Claim occurrences read from one exact conclusion bucket.
  } deriving (Eq, Show)

instance Semigroup MacroLookupWork where
  MacroLookupWork leftNodes leftProbes leftEdges leftClaims <> MacroLookupWork rightNodes rightProbes rightEdges rightClaims =
    MacroLookupWork
      (leftNodes + rightNodes)
      (leftProbes + rightProbes)
      (leftEdges + rightEdges)
      (leftClaims + rightClaims)

instance Monoid MacroLookupWork where
  mempty = MacroLookupWork 0 0 0 0

-- | Stable indexed values and the occurrence work required to address them.
data IndexedLookup value = IndexedLookup
  { lookupValues :: [value]
  , lookupWork :: MacroLookupWork
  }

-- | Build every format-neutral fact index exactly once.
buildFactIndex :: [(node, RawNode)] -> [(edge, RawEdge)] -> FactIndex node edge
buildFactIndex nodes edges =
  FactIndex
    { indexedContextsByIdentity = contextsByIdentity
    , indexedPrimitivesByOwnerType = primitivesByOwnerType
    , indexedStructuringByOwnerType = structuringByOwnerType
    , indexedEdgesByCodeSource = edgesByCodeSource
    , indexedEdgesByCodeTarget = edgesByCodeTarget
    , indexedConstituentAnchors = constituentAnchors
    , indexedEdgesInOrder = edgeFacts
    }
  where
    nodeFacts =
      zipWith
        (\ordinal (occurrence, node) -> OccurrenceFact ordinal occurrence node)
        [0 ..]
        nodes
    edgeFacts =
      zipWith
        (\ordinal (occurrence, edge) -> OccurrenceFact ordinal occurrence edge)
        [0 ..]
        edges
    nodesById = stableBuckets rawNodeIdentifierOf nodeFacts
    contextsByIdentity =
      stableBucketsMaybe
        (\fact ->
           case factValue fact of
             RawContextNode identifier context -> Just (identifier, context)
             _ -> Nothing)
        nodeFacts
    primitivesByOwnerType =
      stableBucketsMaybe
        (\fact ->
           case factValue fact of
             RawPrimitiveNode _ owner primitive -> Just (owner, primitive)
             _ -> Nothing)
        nodeFacts
    structuringByOwnerType =
      stableBucketsMaybe
        (\fact ->
           case factValue fact of
             RawStructuringNode _ owner structuring -> Just (owner, structuring)
             _ -> Nothing)
        nodeFacts
    codedEdges =
      [ (code, fact)
      | fact <- edgeFacts
      , code <- relationCodesFor nodesById (factValue fact)
      ]
    edgesByCodeSource =
      Map.map
        (occurrenceBucket . map snd)
        (stableBuckets
           (\(code, fact) -> (code, rawEdgeFrom (factValue fact)))
           codedEdges)
    edgesByCodeTarget =
      Map.map
        (occurrenceBucket . map snd)
        (stableBuckets
           (\(code, fact) -> (code, rawEdgeTo (factValue fact)))
           codedEdges)
    constituentAnchors = buildConstituentAnchors nodeFacts edgesByCodeTarget

-- | Enumerate persisted edge occurrences in source order.
orderedEdgeFacts :: FactIndex node edge -> [OccurrenceFact edge RawEdge]
orderedEdgeFacts = indexedEdgesInOrder

-- | Resolve Context occurrences with one exact ID and Context type.
contextFactsFor ::
     FactIndex node edge
  -> RawNodeId
  -> Context
  -> [OccurrenceFact node RawNode]
contextFactsFor index identifier context =
  Map.findWithDefault [] (identifier, context) (indexedContextsByIdentity index)

-- | Observe one exact claim bucket and its deterministic addressed work.
claimBucketLookup :: [value] -> IndexedLookup value
claimBucketLookup values =
  IndexedLookup values mempty {macroLookupClaimOccurrences = length values}

-- | Resolve persisted premise edges through relation-code/endpoint buckets.
--
-- For each finite relation code, both addressed endpoint sides are probed once
-- to compare cached occurrence cardinalities. Only the lower-cardinality side
-- is traversed. Abstracting from ordered-map and set factors, lookup work is
-- @O(C * (S + T) + V_selected)@.
premiseEdgeFactsBetween ::
     FactIndex node edge
  -> MacroRelationPattern
  -> [RawNodeId]
  -> [RawNodeId]
  -> IndexedLookup (OccurrenceFact edge RawEdge)
premiseEdgeFactsBetween index pattern' sources targets =
  IndexedLookup
    (orderedOccurrenceFacts (concatMap fst searches))
    (foldMap snd searches)
  where
    sourceIdentifiers = stableDistinct sources
    targetIdentifiers = stableDistinct targets
    sourceSet = Set.fromList sourceIdentifiers
    targetSet = Set.fromList targetIdentifiers
    searches =
      [ premiseFactsForCode
        index
        code
        sourceIdentifiers
        sourceSet
        targetIdentifiers
        targetSet
      | code <- relationPatternCodes pattern'
      ]

premiseFactsForCode ::
     FactIndex node edge
  -> RelationCode
  -> [RawNodeId]
  -> Set.Set RawNodeId
  -> [RawNodeId]
  -> Set.Set RawNodeId
  -> ([OccurrenceFact edge RawEdge], MacroLookupWork)
premiseFactsForCode index code sources sourceSet targets targetSet
  | null sources || null targets = ([], mempty)
  | sourceCardinality <= targetCardinality =
    selectedFacts
      sourceBuckets
      sourceCardinality
      (\edge -> Set.member (rawEdgeTo edge) targetSet)
  | otherwise =
    selectedFacts
      targetBuckets
      targetCardinality
      (\edge -> Set.member (rawEdgeFrom edge) sourceSet)
  where
    sourceBuckets =
      addressedBuckets (indexedEdgesByCodeSource index) code sources
    targetBuckets =
      addressedBuckets (indexedEdgesByCodeTarget index) code targets
    sourceCardinality = sum (map occurrenceBucketCardinality sourceBuckets)
    targetCardinality = sum (map occurrenceBucketCardinality targetBuckets)
    bucketProbes = length sourceBuckets + length targetBuckets
    selectedFacts buckets cardinality matches =
      ( filter (matches . factValue) visited
      , mempty
          { macroLookupEdgeBucketProbes = bucketProbes
          , macroLookupEdgeOccurrences = cardinality
          })
      where
        visited = concatMap occurrenceBucketFacts buckets

addressedBuckets ::
     Map (RelationCode, RawNodeId) (OccurrenceBucket occurrence value)
  -> RelationCode
  -> [RawNodeId]
  -> [OccurrenceBucket occurrence value]
addressedBuckets adjacency code =
  map
    (\identifier ->
       Map.findWithDefault emptyOccurrenceBucket (code, identifier) adjacency)

occurrenceBucket ::
     [OccurrenceFact occurrence value] -> OccurrenceBucket occurrence value
occurrenceBucket facts = OccurrenceBucket (length facts) facts

emptyOccurrenceBucket :: OccurrenceBucket occurrence value
emptyOccurrenceBucket = OccurrenceBucket 0 []

orderedOccurrenceFacts ::
     [OccurrenceFact occurrence value] -> [OccurrenceFact occurrence value]
orderedOccurrenceFacts =
  Map.elems . Map.fromList . map (\fact -> (factOrdinal fact, fact))

-- | Resolve Primitive occurrences by exact owner and Primitive type.
ownedPrimitiveIdentifiers ::
     FactIndex node edge -> RawNodeId -> Primitive -> IndexedLookup RawNodeId
ownedPrimitiveIdentifiers index owner primitive =
  nodeBucketIdentifiers
    (Map.findWithDefault
       []
       (owner, primitive)
       (indexedPrimitivesByOwnerType index))

-- | Resolve structuring occurrences by exact owner and structuring type.
ownedStructuringIdentifiers ::
     FactIndex node edge -> RawNodeId -> Structuring -> IndexedLookup RawNodeId
ownedStructuringIdentifiers index owner structuring =
  nodeBucketIdentifiers
    (Map.findWithDefault
       []
       (owner, structuring)
       (indexedStructuringByOwnerType index))

-- | Resolve constituent Situation anchors for one Context occurrence.
constituentAnchorIdentifiers ::
     FactIndex node edge -> RawNodeId -> IndexedLookup RawNodeId
constituentAnchorIdentifiers index context =
  IndexedLookup
    identifiers
    mempty {macroLookupNodeOccurrences = length identifiers}
  where
    identifiers =
      Map.findWithDefault [] context (indexedConstituentAnchors index)

nodeBucketIdentifiers ::
     [OccurrenceFact node RawNode] -> IndexedLookup RawNodeId
nodeBucketIdentifiers facts =
  IndexedLookup
    (map (rawNodeIdentifier . factValue) facts)
    mempty {macroLookupNodeOccurrences = length facts}

stableBuckets :: Ord key => (value -> key) -> [value] -> Map key [value]
stableBuckets keyOf =
  Map.map reverse
    . foldl'
        (\buckets value -> Map.insertWith (++) (keyOf value) [value] buckets)
        Map.empty

stableBucketsMaybe ::
     Ord key => (value -> Maybe key) -> [value] -> Map key [value]
stableBucketsMaybe keyOf =
  Map.map reverse
    . foldl'
        (\buckets value ->
           case keyOf value of
             Nothing -> buckets
             Just key -> Map.insertWith (++) key [value] buckets)
        Map.empty

rawNodeIdentifierOf :: OccurrenceFact node RawNode -> RawNodeId
rawNodeIdentifierOf = rawNodeIdentifier . factValue

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier node =
  case node of
    RawContextNode identifier _ -> identifier
    RawPrimitiveNode identifier _ _ -> identifier
    RawStructuringNode identifier _ _ -> identifier
    RawAnchorNode identifier _ -> identifier

rawNodeKinds ::
     Map RawNodeId [OccurrenceFact node RawNode] -> RawNode -> [NodeKindValue]
rawNodeKinds nodesById node =
  case node of
    RawContextNode _ context -> [ContextNodeKind context]
    RawPrimitiveNode _ owner primitive ->
      [ PrimitiveNodeKind context primitive
      | ownerFact <- Map.findWithDefault [] owner nodesById
      , RawContextNode _ context <- [factValue ownerFact]
      ]
    RawStructuringNode _ owner structuring ->
      [ StructuringNodeKind context structuring
      | ownerFact <- Map.findWithDefault [] owner nodesById
      , RawContextNode _ context <- [factValue ownerFact]
      ]
    RawAnchorNode _ anchor -> [AnchorNodeKind anchor]

relationCodesFor ::
     Map RawNodeId [OccurrenceFact node RawNode] -> RawEdge -> [RelationCode]
relationCodesFor nodesById edge =
  stableDistinct
    [ relationCode spec
    | SomeRelation relation <- lookupRelations (rawEdgeRelation edge)
    , let spec = relationSpec relation
    , endpointKindOccurs nodesById (relationFrom spec) (rawEdgeFrom edge)
    , endpointKindOccurs nodesById (relationTo spec) (rawEdgeTo edge)
    ]

endpointKindOccurs ::
     Map RawNodeId [OccurrenceFact node RawNode]
  -> SNodeKind kind
  -> RawNodeId
  -> Bool
endpointKindOccurs nodesById expected identifier =
  any
    (elem (nodeKindValue expected) . rawNodeKinds nodesById . factValue)
    (Map.findWithDefault [] identifier nodesById)

buildConstituentAnchors ::
     [OccurrenceFact node RawNode]
  -> Map (RelationCode, RawNodeId) (OccurrenceBucket edge RawEdge)
  -> Map RawNodeId [RawNodeId]
buildConstituentAnchors nodeFacts edgesByCodeTarget =
  Map.map (map third . sortOn firstTwo) (stableBuckets fstValue occurrences)
  where
    anchorFacts =
      [ (factOrdinal fact, identifier, anchor)
      | fact <- nodeFacts
      , RawAnchorNode identifier anchor <- [factValue fact]
      ]
    occurrences =
      [ ( rawEdgeFrom edge
        , (anchorOrdinal, factOrdinal edgeFact, anchorIdentifier))
      | (anchorOrdinal, anchorIdentifier, anchor) <- anchorFacts
      , edgeFact <-
          occurrenceBucketFacts
            (Map.findWithDefault
               emptyOccurrenceBucket
               ( AnchorRelation ConstitutedByAnchorFamily anchor
               , anchorIdentifier)
               edgesByCodeTarget)
      , let edge = factValue edgeFact
      ]
    fstValue (key, _) = key
    firstTwo (_, (anchorOrdinal, edgeOrdinal, _)) = (anchorOrdinal, edgeOrdinal)
    third (_, (_, _, identifier)) = identifier

relationPatternCodes :: MacroRelationPattern -> [RelationCode]
relationPatternCodes pattern' =
  case pattern' of
    ExactRelation code -> [code]
    AnchorRelationFamilyPattern family ->
      [AnchorRelation family anchor | anchor <- [minBound .. maxBound]]

stableDistinct :: Ord value => [value] -> [value]
stableDistinct = go Set.empty
  where
    go _ [] = []
    go seen (value:values)
      | Set.member value seen = go seen values
      | otherwise = value : go (Set.insert value seen) values
