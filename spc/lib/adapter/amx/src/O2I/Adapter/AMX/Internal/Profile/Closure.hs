{-# LANGUAGE OverloadedStrings #-}

-- | Monotone O2I candidacy and registered relationship resolution.
module O2I.Adapter.AMX.Internal.Profile.Closure
  ( CandidateClosure(..)
  , candidateClosure
  , semanticRelationshipElements
  , projectedRawEdge
  , exactSignatures
  , resolvedSignatures
  ) where

import Control.Monad (guard)
import Data.List (foldl')
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Sequence
import Data.Sequence (Seq((:<|)), (|>))
import qualified Data.Set as Set
import Data.Set (Set)
import O2I
import O2I.Adapter.AMX.Internal.Profile.Collective
import O2I.Adapter.AMX.Internal.Profile.Metadata
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Provenance

-- | Finite least fixed point of persisted candidate and relationship facts.
data CandidateClosure = CandidateClosure
  { closureCandidates :: Set OccurrenceId
  , closureRelationships :: Set OccurrenceId
  } deriving (Eq, Show)

-- | Compute candidacy using indexed relationship adjacency and a work queue.
candidateClosure :: Environment -> CandidateClosure
candidateClosure environment =
  processCandidates
    initialCandidates
    (Sequence.fromList intrinsicOccurrences)
    Set.empty
  where
    intrinsicOccurrences =
      [ nodeOccurrence node
      | node <- environmentNodes environment
      , hasDirectO2IMetadata node
      ]
    initialCandidates = Set.fromList intrinsicOccurrences
    adjacency = relationshipAdjacency environment
    processCandidates candidates Sequence.Empty relationships =
      CandidateClosure
        {closureCandidates = candidates, closureRelationships = relationships}
    processCandidates candidates (current :<| queue) relationships =
      let adjacent = Map.findWithDefault [] current adjacency
          (nextCandidates, nextQueue, nextRelationships) =
            foldl' reachRelationship (candidates, queue, relationships) adjacent
       in processCandidates nextCandidates nextQueue nextRelationships
    reachRelationship state@(candidates, queue, relationships) relationship
      | Set.member occurrence relationships = state
      | not (relationshipEligible environment closure relationship) = state
      | otherwise =
        foldl'
          addEndpoint
          (candidates, queue, Set.insert occurrence relationships)
          (uniqueEndpointOccurrences environment relationship)
      where
        occurrence = relationshipOccurrence relationship
        closure =
          CandidateClosure
            { closureCandidates = candidates
            , closureRelationships = relationships
            }
    addEndpoint state@(candidates, queue, relationships) endpoint
      | Set.member endpoint candidates = state
      | otherwise =
        (Set.insert endpoint candidates, queue |> endpoint, relationships)

relationshipAdjacency :: Environment -> Map.Map OccurrenceId [AMXElement]
relationshipAdjacency environment =
  Map.fromListWith
    (flip (++))
    [ (nodeOccurrence endpoint, [relationship])
    | relationship <- environmentRelationships environment
    , endpoint <- endpointElementsForAdjacency environment relationship
    ]

endpointElementsForAdjacency :: Environment -> AMXElement -> [AMXElement]
endpointElementsForAdjacency environment relationship =
  stableUniqueElements
    (endpointElements environment SourceEndpoint relationship
       ++ endpointElements environment TargetEndpoint relationship)

relationshipEligible :: Environment -> CandidateClosure -> AMXElement -> Bool
relationshipEligible environment closure relationship
  | Set.member occurrence (closureRelationships closure) = True
  | isOwnershipRelationship relationship =
    ownershipEligible environment closure relationship
  | otherwise =
    let signatures = possibleSignatures environment closure relationship
        endpointsAreCandidates =
          all
            (`Set.member` closureCandidates closure)
            (uniqueEndpointOccurrences environment relationship)
        isPresented =
          Set.member occurrence (environmentPresentedRelations environment)
     in (isPresented && (not (null signatures) || endpointsAreCandidates))
          || any (isHiddenDependencyRelation . signatureCode) signatures
  where
    occurrence = relationshipOccurrence relationship

ownershipEligible :: Environment -> CandidateClosure -> AMXElement -> Bool
ownershipEligible environment closure relationship =
  any eligible (uniqueEndpointElements environment relationship)
  where
    eligible element =
      Set.member (nodeOccurrence element) (closureCandidates closure)
        && case metadataKind element of
             Just ContextMetadata -> endpointIs SourceEndpoint element
             Just PrimitiveMetadata -> endpointIs TargetEndpoint element
             Just StructuringMetadata -> endpointIs TargetEndpoint element
             Just SituationAnchorMetadata -> endpointIs TargetEndpoint element
             Nothing -> True
    endpointIs role element =
      elementAttribute (endpointQName role) relationship == elementId element

possibleSignatures ::
     Environment -> CandidateClosure -> AMXElement -> [AMXRelationSignature]
possibleSignatures environment closure relationship =
  [ signature
  | signature <- relationSignatures
  , signatureAMXLabel signature == elementName relationship
  , endpointCompatible sourceKinds (signatureFrom signature)
  , endpointCompatible targetKinds (signatureTo signature)
  , not (null sourceKinds && null targetKinds)
  ]
  where
    sourceKinds = reachedEndpointKinds SourceEndpoint
    targetKinds = reachedEndpointKinds TargetEndpoint
    reachedEndpointKinds role =
      [ kind
      | endpoint <- endpointElements environment role relationship
      , Set.member (nodeOccurrence endpoint) (closureCandidates closure)
      , Just kind <- [nodeKind environment endpoint]
      ]

endpointCompatible :: [NodeKindValue] -> NodeKindValue -> Bool
endpointCompatible observed expected = null observed || expected `elem` observed

-- | Retain registered semantic relationships for deferred Inspection closure.
semanticRelationshipElements :: Environment -> CandidateClosure -> [AMXElement]
semanticRelationshipElements environment closure =
  [ relationship
  | relationship <- environmentRelationships environment
  , not (isOwnershipRelationship relationship)
  , relationship `notElem` collectiveSegmentElements environment
  , let occurrence = relationshipOccurrence relationship
  , Set.member occurrence (closureRelationships closure)
      || not (null (exactSignatures environment relationship))
  ]

-- | Project one persisted relationship when endpoints and notation permit it.
projectedRawEdge ::
     Environment -> CandidateClosure -> AMXElement -> Maybe RawEdge
projectedRawEdge environment closure relationship = do
  source <- uniqueEndpointElement environment SourceEndpoint relationship
  target <- uniqueEndpointElement environment TargetEndpoint relationship
  sourceId <- elementId source
  targetId <- elementId target
  let resolved = resolvedSignatures environment relationship
      endpointsAreCandidates =
        all
          (`Set.member` closureCandidates closure)
          [nodeOccurrence source, nodeOccurrence target]
      semanticName =
        case resolved of
          signature:_ -> Just (signatureName signature)
          []
            | endpointsAreCandidates ->
              Just (RelationName (elementName relationship))
            | otherwise -> Nothing
      representationIsValid =
        case resolved of
          [] -> True
          signatures ->
            maybe
              False
              (\actual -> any ((== actual) . signatureRepresentation) signatures)
              (actualRelationshipRepresentation relationship)
  name <- semanticName
  if representationIsValid
    then Just (RawEdge (RawNodeId sourceId) name (RawNodeId targetId))
    else Nothing

-- | Resolve all exact core signatures for one persisted relationship.
exactSignatures :: Environment -> AMXElement -> [AMXRelationSignature]
exactSignatures environment relationship = do
  source <-
    maybeToList (uniqueEndpointElement environment SourceEndpoint relationship)
  target <-
    maybeToList (uniqueEndpointElement environment TargetEndpoint relationship)
  sourceKind <- maybeToList (nodeKind environment source)
  targetKind <- maybeToList (nodeKind environment target)
  signature <- relationSignatures
  guard (signatureAMXLabel signature == elementName relationship)
  guard (signatureFrom signature == sourceKind)
  guard (signatureTo signature == targetKind)
  pure signature

-- | Resolve exact or uniquely implied endpoint-invalid signatures.
resolvedSignatures :: Environment -> AMXElement -> [AMXRelationSignature]
resolvedSignatures environment relationship =
  case exactSignatures environment relationship of
    [] -> uniquelyResolvedPartial
    exact -> exact
  where
    sourceKind =
      uniqueEndpointElement environment SourceEndpoint relationship
        >>= nodeKind environment
    targetKind =
      uniqueEndpointElement environment TargetEndpoint relationship
        >>= nodeKind environment
    partial =
      [ signature
      | signature <- relationSignatures
      , signatureAMXLabel signature == elementName relationship
      , endpointMatches sourceKind (signatureFrom signature)
          || endpointMatches targetKind (signatureTo signature)
      ]
    uniquelyResolvedPartial =
      case partial of
        [signature] -> [signature]
        _ -> []

endpointMatches :: Maybe NodeKindValue -> NodeKindValue -> Bool
endpointMatches observed expected = observed == Just expected

maybeToList :: Maybe value -> [value]
maybeToList value =
  case value of
    Nothing -> []
    Just present -> [present]
