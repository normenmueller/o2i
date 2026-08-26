{-# LANGUAGE RoleAnnotations #-}

-- | Private addressed index for the fixed effect-trace grammar.
module O2I.Trace.Index
  ( TraceIndex
  , DenseIdentity
  , denseIdentityRank
  , denseIdentityFromRank
  , buildTraceIndex
  , traceIndexGraphIdentity
  , traceIndexInternIdentity
  , traceIndexInternIdentityWithSteps
  , traceIndexResolveIdentity
  , traceIndexDomain
  , traceIndexRoots
  , traceIndexAssertedSupport
  , traceIndexCandidateSupport
  , traceIndexAssertedBucket
  , traceIndexCandidateBucket
  , traceIndexWork
  ) where

import Data.Bits (finiteBitSize)
import qualified Data.IntMap.Strict as IntMap
import Data.IntMap.Strict (IntMap)
import qualified Data.IntSet as IntSet
import Data.IntSet (IntSet)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Text as Text
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment(..)
  , ContextualizationObservation
  , RelationObservation
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationCommitment
  , contextualizationMemberOccurrence
  , contextualizationOccurrenceIdentity
  , contextualizationOwnerOccurrence
  , relationCommitment
  , relationOccurrenceIdentity
  , relationSourceOccurrence
  , relationTargetOccurrence
  , relationToken
  )
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Structure
  ( WellFormedGraph
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  )
import O2I.Structure.Internal (wellFormedGraphIdentity)
import O2I.Trace.Grammar
import O2I.Trace.Internal (TraceRootBinding(..), TraceWork(..), emptyTraceWork)

newtype DenseIdentity =
  DenseIdentity Int
  deriving (Eq, Ord, Show)

type DenseEndpoints = (DenseIdentity, DenseIdentity)

type SupportIndex = IntMap (IntMap [OccurrenceIdentity])

data SupportBuckets = SupportBuckets
  { bucketExact :: !SupportIndex
  , bucketBySource :: !(IntMap [(DenseEndpoints, [OccurrenceIdentity])])
  , bucketByTarget :: !(IntMap [(DenseEndpoints, [OccurrenceIdentity])])
  , bucketAll :: ![(DenseEndpoints, [OccurrenceIdentity])]
  }

data SearchTree key value
  = EmptySearchTree
  | SearchTreeNode !key !value !(SearchTree key value) !(SearchTree key value)

type role TraceIndex nominal

data TraceIndex scope = TraceIndex
  { indexedGraphIdentity :: !ModelIdentity
  , indexedIdentityKeys :: !(SearchTree ModelIdentity DenseIdentity)
  , indexedIdentityValues :: !(IntMap ModelIdentity)
  , indexedDomains :: ![IntSet]
  , indexedAssertedSupport :: !(IntMap SupportBuckets)
  , indexedCandidateSupport :: !(IntMap SupportBuckets)
  , indexedRoots :: ![TraceRootBinding]
  , indexedWork :: !TraceWork
  }

buildTraceIndex :: WellFormedGraph scope -> TraceIndex scope
buildTraceIndex graph =
  TraceIndex
    { indexedGraphIdentity = wellFormedGraphIdentity graph
    , indexedIdentityKeys = identityKeys
    , indexedIdentityValues = identityValues
    , indexedDomains = domains
    , indexedAssertedSupport = assertedBuckets
    , indexedCandidateSupport = candidateBuckets
    , indexedRoots = roots
    , indexedWork =
        emptyTraceWork
          { traceCarrierVisits = length carriers
          , traceRelationVisits = length relations
          , traceOwnershipVisits = length contextualizations
          , traceRootCount = length roots
          , tracePreparationIdentityScalarSteps = identityOrderingScalarSteps
          , tracePreparationFixedWordSteps =
              preparationFixedWordSteps
                carriers
                relations
                contextualizations
                (length roots)
          }
    }
  where
    carriers = wellFormedCarriers graph
    relations = wellFormedRelations graph
    contextualizations = wellFormedContextualizations graph
    (orderedIdentities, identitySortSteps) =
      sortUniqueMeasured
        compareModelIdentity
        (map carrierModelIdentity carriers)
    identityPairs =
      [ (identity, DenseIdentity rank)
      | (rank, identity) <- zip [0 ..] orderedIdentities
      ]
    identityKeys = buildSearchTree identityPairs
    identityValues =
      IntMap.fromDistinctAscList
        [(rank, identity) | (rank, identity) <- zip [0 ..] orderedIdentities]
    resolveCarrier carrier =
      case lookupSearchTree
             compareModelIdentity
             (carrierModelIdentity carrier)
             identityKeys of
        (Just dense, steps) -> ((carrier, dense), steps)
        (Nothing, _) ->
          error "Trace carrier identity missing from dense interning"
    resolvedCarriersWithWork = map resolveCarrier carriers
    resolvedCarriers = map fst resolvedCarriersWithWork
    identityLookupSteps = sum (map snd resolvedCarriersWithWork)
    carrierEntries =
      [ (carrierOccurrenceIdentity carrier, (carrier, dense))
      | (carrier, dense) <- resolvedCarriers
      ]
    (orderedCarrierEntries, carrierSortSteps) =
      sortMeasuredBy (compareOccurrenceIdentity `onFirst`) carrierEntries
    carrierByOccurrence = buildSearchTree orderedCarrierEntries
    domains =
      [ IntSet.fromList
        [ denseIdentityRank dense
        | (carrier, dense) <- resolvedCarriers
        , carrierQualifiedEndpoint carrier `elem` traceVariableEndpoint variable
        ]
      | variable <- traceVariables
      ]
    (assertedRelations, candidateRelations, relationLookupSteps) =
      indexedRelations
    indexedRelations =
      foldl'
        (indexRelation carrierByOccurrence)
        (IntMap.empty, IntMap.empty, 0)
        relations
    (assertedSupport, candidateSupport, ownershipLookupSteps) =
      foldl'
        (indexOwnership carrierByOccurrence)
        (assertedRelations, candidateRelations, 0)
        contextualizations
    identityOrderingScalarSteps =
      identitySortSteps
        + identityLookupSteps
        + carrierSortSteps
        + relationLookupSteps
        + ownershipLookupSteps
    assertedBuckets = buildSupportBuckets assertedSupport
    candidateBuckets = buildSupportBuckets candidateSupport
    rootIndex =
      maybe
        []
        (supportTuples . bucketExact)
        (IntMap.lookup
           (traceSlotRank (RelationTraceSlot rootSlot))
           assertedBuckets)
    roots =
      [ TraceRootBinding
        (resolveDense identityValues intervention)
        (resolveDense identityValues need)
        (first :| remaining)
        (denseIdentityRank intervention)
        (denseIdentityRank need)
      | ((intervention, need), support) <- rootIndex
      , first:remaining <- [support]
      ]

traceIndexGraphIdentity :: TraceIndex scope -> ModelIdentity
traceIndexGraphIdentity = indexedGraphIdentity

traceIndexInternIdentity ::
     TraceIndex scope -> ModelIdentity -> Maybe DenseIdentity
traceIndexInternIdentity index identity =
  fst (traceIndexInternIdentityWithSteps index identity)

traceIndexInternIdentityWithSteps ::
     TraceIndex scope -> ModelIdentity -> (Maybe DenseIdentity, Int)
traceIndexInternIdentityWithSteps index identity =
  lookupSearchTree compareModelIdentity identity (indexedIdentityKeys index)

traceIndexResolveIdentity :: TraceIndex scope -> DenseIdentity -> ModelIdentity
traceIndexResolveIdentity index = resolveDense (indexedIdentityValues index)

denseIdentityRank :: DenseIdentity -> Int
denseIdentityRank (DenseIdentity rank) = rank

denseIdentityFromRank :: Int -> DenseIdentity
denseIdentityFromRank = DenseIdentity

traceIndexDomain :: TraceIndex scope -> TraceVariable -> [DenseIdentity]
traceIndexDomain index variable =
  map
    DenseIdentity
    (IntSet.toAscList (indexedDomains index !! fromEnum variable))

traceIndexRoots :: TraceIndex scope -> [TraceRootBinding]
traceIndexRoots = indexedRoots

traceIndexAssertedSupport ::
     TraceIndex scope -> TraceSlot -> DenseEndpoints -> [OccurrenceIdentity]
traceIndexAssertedSupport index slot endpoints =
  lookupSupport (indexedAssertedSupport index) slot endpoints

traceIndexCandidateSupport ::
     TraceIndex scope -> TraceSlot -> DenseEndpoints -> [OccurrenceIdentity]
traceIndexCandidateSupport index slot endpoints =
  lookupSupport (indexedCandidateSupport index) slot endpoints

traceIndexAssertedBucket ::
     TraceIndex scope
  -> TraceSlot
  -> Maybe DenseIdentity
  -> Maybe DenseIdentity
  -> [(DenseEndpoints, [OccurrenceIdentity])]
traceIndexAssertedBucket index = lookupBucket (indexedAssertedSupport index)

traceIndexCandidateBucket ::
     TraceIndex scope
  -> TraceSlot
  -> Maybe DenseIdentity
  -> Maybe DenseIdentity
  -> [(DenseEndpoints, [OccurrenceIdentity])]
traceIndexCandidateBucket index = lookupBucket (indexedCandidateSupport index)

traceIndexWork :: TraceIndex scope -> TraceWork
traceIndexWork = indexedWork

lookupSupport ::
     IntMap SupportBuckets
  -> TraceSlot
  -> DenseEndpoints
  -> [OccurrenceIdentity]
lookupSupport indexes slot (source, target) =
  maybe
    []
    (lookupExact source target . bucketExact)
    (IntMap.lookup (traceSlotRank slot) indexes)

lookupBucket ::
     IntMap SupportBuckets
  -> TraceSlot
  -> Maybe DenseIdentity
  -> Maybe DenseIdentity
  -> [(DenseEndpoints, [OccurrenceIdentity])]
lookupBucket indexes slot source target =
  case IntMap.lookup (traceSlotRank slot) indexes of
    Nothing -> []
    Just buckets ->
      case (source, target) of
        (Just sourceIdentity, Just targetIdentity) ->
          let endpoints = (sourceIdentity, targetIdentity)
              support =
                lookupExact sourceIdentity targetIdentity (bucketExact buckets)
           in [(endpoints, support) | not (null support)]
        (Just sourceIdentity, Nothing) ->
          IntMap.findWithDefault
            []
            (denseIdentityRank sourceIdentity)
            (bucketBySource buckets)
        (Nothing, Just targetIdentity) ->
          IntMap.findWithDefault
            []
            (denseIdentityRank targetIdentity)
            (bucketByTarget buckets)
        (Nothing, Nothing) -> bucketAll buckets

lookupExact ::
     DenseIdentity -> DenseIdentity -> SupportIndex -> [OccurrenceIdentity]
lookupExact source target support =
  maybe
    []
    (IntMap.findWithDefault [] (denseIdentityRank target))
    (IntMap.lookup (denseIdentityRank source) support)

indexRelation ::
     SearchTree OccurrenceIdentity (CarrierObservation scope, DenseIdentity)
  -> (IntMap SupportIndex, IntMap SupportIndex, Int)
  -> RelationObservation scope
  -> (IntMap SupportIndex, IntMap SupportIndex, Int)
indexRelation carriers (asserted, candidate, accumulatedSteps) relation =
  case (sourceResult, targetResult) of
    (Just source, Just target) ->
      let (nextAsserted, nextCandidate) =
            foldl'
              (insertMatchingRelation relation source target)
              (asserted, candidate)
              traceRelationSlots
       in ( nextAsserted
          , nextCandidate
          , accumulatedSteps + sourceSteps + targetSteps)
    _ -> (asserted, candidate, accumulatedSteps + sourceSteps + targetSteps)
  where
    (sourceResult, sourceSteps) =
      lookupSearchTree
        compareOccurrenceIdentity
        (relationSourceOccurrence relation)
        carriers
    (targetResult, targetSteps) =
      lookupSearchTree
        compareOccurrenceIdentity
        (relationTargetOccurrence relation)
        carriers

insertMatchingRelation ::
     RelationObservation scope
  -> (CarrierObservation scope, DenseIdentity)
  -> (CarrierObservation scope, DenseIdentity)
  -> (IntMap SupportIndex, IntMap SupportIndex)
  -> TraceRelationSlot
  -> (IntMap SupportIndex, IntMap SupportIndex)
insertMatchingRelation relation (source, sourceDense) (target, targetDense) indexes slot
  | relationToken relation /= traceRelationSlotToken slot = indexes
  | carrierQualifiedEndpoint source
      `notElem` traceVariableEndpoint sourceVariable = indexes
  | carrierQualifiedEndpoint target
      `notElem` traceVariableEndpoint targetVariable = indexes
  | otherwise =
    insertSupport
      (relationCommitment relation)
      (RelationTraceSlot slot)
      (sourceDense, targetDense)
      (relationOccurrenceIdentity relation)
      indexes
  where
    (sourceVariable, targetVariable) = traceRelationSlotVariables slot

indexOwnership ::
     SearchTree OccurrenceIdentity (CarrierObservation scope, DenseIdentity)
  -> (IntMap SupportIndex, IntMap SupportIndex, Int)
  -> ContextualizationObservation scope
  -> (IntMap SupportIndex, IntMap SupportIndex, Int)
indexOwnership carriers (asserted, candidate, accumulatedSteps) contextualization =
  case (ownerResult, memberResult) of
    (Just owner, Just member) ->
      let (nextAsserted, nextCandidate) =
            foldl'
              (insertMatchingOwnership contextualization owner member)
              (asserted, candidate)
              traceOwnershipSlots
       in ( nextAsserted
          , nextCandidate
          , accumulatedSteps + ownerSteps + memberSteps)
    _ -> (asserted, candidate, accumulatedSteps + ownerSteps + memberSteps)
  where
    (ownerResult, ownerSteps) =
      lookupSearchTree
        compareOccurrenceIdentity
        (contextualizationOwnerOccurrence contextualization)
        carriers
    (memberResult, memberSteps) =
      lookupSearchTree
        compareOccurrenceIdentity
        (contextualizationMemberOccurrence contextualization)
        carriers

insertMatchingOwnership ::
     ContextualizationObservation scope
  -> (CarrierObservation scope, DenseIdentity)
  -> (CarrierObservation scope, DenseIdentity)
  -> (IntMap SupportIndex, IntMap SupportIndex)
  -> TraceOwnershipSlot
  -> (IntMap SupportIndex, IntMap SupportIndex)
insertMatchingOwnership contextualization (owner, ownerDense) (member, memberDense) indexes slot
  | carrierQualifiedEndpoint owner `notElem` traceVariableEndpoint ownerVariable =
    indexes
  | carrierQualifiedEndpoint member
      `notElem` traceVariableEndpoint memberVariable = indexes
  | otherwise =
    insertSupport
      (contextualizationCommitment contextualization)
      (OwnershipTraceSlot slot)
      (ownerDense, memberDense)
      (contextualizationOccurrenceIdentity contextualization)
      indexes
  where
    (ownerVariable, memberVariable) = traceOwnershipSlotVariables slot

insertSupport ::
     Commitment
  -> TraceSlot
  -> DenseEndpoints
  -> OccurrenceIdentity
  -> (IntMap SupportIndex, IntMap SupportIndex)
  -> (IntMap SupportIndex, IntMap SupportIndex)
insertSupport commitment slot (source, target) occurrence (asserted, candidate) =
  case commitment of
    Asserted -> (insert asserted, candidate)
    Candidate -> (asserted, insert candidate)
  where
    insert =
      IntMap.insertWith
        (IntMap.unionWith (IntMap.unionWith (++)))
        (traceSlotRank slot)
        (IntMap.singleton
           (denseIdentityRank source)
           (IntMap.singleton (denseIdentityRank target) [occurrence]))

buildSupportBuckets :: IntMap SupportIndex -> IntMap SupportBuckets
buildSupportBuckets = IntMap.map build
  where
    build support =
      SupportBuckets
        { bucketExact = canonical
        , bucketBySource =
            IntMap.fromListWith
              (flip (++))
              [ (denseIdentityRank source, [(endpoints, occurrences)])
              | (endpoints@(source, _), occurrences) <- tuples
              ]
        , bucketByTarget =
            IntMap.fromListWith
              (flip (++))
              [ (denseIdentityRank target, [(endpoints, occurrences)])
              | (endpoints@(_, target), occurrences) <- tuples
              ]
        , bucketAll = tuples
        }
      where
        canonical = IntMap.map (IntMap.map sort) support
        tuples = supportTuples canonical

supportTuples :: SupportIndex -> [(DenseEndpoints, [OccurrenceIdentity])]
supportTuples support =
  [ ((DenseIdentity source, DenseIdentity target), occurrences)
  | (source, targets) <- IntMap.toAscList support
  , (target, occurrences) <- IntMap.toAscList targets
  ]

traceSlotRank :: TraceSlot -> Int
traceSlotRank slot =
  case slot of
    RelationTraceSlot relationSlot -> fromEnum relationSlot
    OwnershipTraceSlot ownershipSlot ->
      length traceRelationSlots + fromEnum ownershipSlot

resolveDense :: IntMap ModelIdentity -> DenseIdentity -> ModelIdentity
resolveDense identities (DenseIdentity rank) =
  case IntMap.lookup rank identities of
    Just identity -> identity
    Nothing -> error "Trace dense identity rank missing from reverse index"

compareModelIdentity :: ModelIdentity -> ModelIdentity -> (Ordering, Int)
compareModelIdentity left right =
  compareText (modelIdentityText left) (modelIdentityText right)

compareOccurrenceIdentity ::
     OccurrenceIdentity -> OccurrenceIdentity -> (Ordering, Int)
compareOccurrenceIdentity left right =
  compareText (occurrenceIdentityText left) (occurrenceIdentityText right)

compareText :: Text.Text -> Text.Text -> (Ordering, Int)
compareText left right = compareScalars (Text.unpack left) (Text.unpack right) 0
  where
    compareScalars [] [] steps = (EQ, steps)
    compareScalars [] (_:_) steps = (LT, steps)
    compareScalars (_:_) [] steps = (GT, steps)
    compareScalars (leftScalar:leftScalars) (rightScalar:rightScalars) steps =
      case compare leftScalar rightScalar of
        EQ -> compareScalars leftScalars rightScalars (steps + 2)
        ordering -> (ordering, steps + 2)

onFirst ::
     (key -> key -> (Ordering, Int))
  -> (key, value)
  -> (key, value)
  -> (Ordering, Int)
onFirst compareKey (left, _) (right, _) = compareKey left right

sortMeasuredBy ::
     (value -> value -> (Ordering, Int)) -> [value] -> ([value], Int)
sortMeasuredBy _ [] = ([], 0)
sortMeasuredBy _ [value] = ([value], 0)
sortMeasuredBy compareValue values =
  (merged, leftSteps + rightSteps + mergeSteps)
  where
    (leftValues, rightValues) = splitAt (length values `div` 2) values
    (sortedLeft, leftSteps) = sortMeasuredBy compareValue leftValues
    (sortedRight, rightSteps) = sortMeasuredBy compareValue rightValues
    (merged, mergeSteps) = mergeMeasured compareValue sortedLeft sortedRight

mergeMeasured ::
     (value -> value -> (Ordering, Int)) -> [value] -> [value] -> ([value], Int)
mergeMeasured _ [] right = (right, 0)
mergeMeasured _ left [] = (left, 0)
mergeMeasured compareValue left@(leftValue:leftValues) right@(rightValue:rightValues) =
  case compareValue leftValue rightValue of
    (GT, steps) ->
      let (remaining, remainingSteps) =
            mergeMeasured compareValue left rightValues
       in (rightValue : remaining, steps + remainingSteps)
    (_, steps) ->
      let (remaining, remainingSteps) =
            mergeMeasured compareValue leftValues right
       in (leftValue : remaining, steps + remainingSteps)

sortUniqueMeasured ::
     (value -> value -> (Ordering, Int)) -> [value] -> ([value], Int)
sortUniqueMeasured compareValue values = (unique, sortSteps + uniqueSteps)
  where
    (ordered, sortSteps) = sortMeasuredBy compareValue values
    (unique, uniqueSteps) = uniqueMeasured compareValue ordered

uniqueMeasured ::
     (value -> value -> (Ordering, Int)) -> [value] -> ([value], Int)
uniqueMeasured _ [] = ([], 0)
uniqueMeasured compareValue (first:remaining) =
  let (reversed, steps) = foldl' keep ([first], 0) remaining
   in (reverse reversed, steps)
  where
    keep (latest:accepted, accumulatedSteps) candidate =
      case compareValue latest candidate of
        (EQ, steps) -> (latest : accepted, accumulatedSteps + steps)
        (_, steps) -> (candidate : latest : accepted, accumulatedSteps + steps)
    keep ([], _) _ = error "Trace unique ordering lost its first identity"

buildSearchTree :: [(key, value)] -> SearchTree key value
buildSearchTree entries = fst (build (length entries) entries)
  where
    build 0 remaining = (EmptySearchTree, remaining)
    build count remaining =
      case afterLeft of
        [] -> error "Trace balanced search tree exhausted its input"
        (key, value):afterNode ->
          (SearchTreeNode key value left right, afterRight)
          where (right, afterRight) = build (count - leftCount - 1) afterNode
      where
        leftCount = count `div` 2
        (left, afterLeft) = build leftCount remaining

lookupSearchTree ::
     (key -> key -> (Ordering, Int))
  -> key
  -> SearchTree key value
  -> (Maybe value, Int)
lookupSearchTree _ _ EmptySearchTree = (Nothing, 0)
lookupSearchTree compareKey sought (SearchTreeNode key value left right) =
  case compareKey sought key of
    (LT, steps) -> addSteps steps (lookupSearchTree compareKey sought left)
    (GT, steps) -> addSteps steps (lookupSearchTree compareKey sought right)
    (EQ, steps) -> (Just value, steps)
  where
    addSteps steps (result, remainingSteps) = (result, steps + remainingSteps)

-- Every dense index is an 'IntMap'/'IntSet' Patricia trie. Its path length is
-- bounded by the fixed machine-word width. The counter records the exact
-- closed-schedule visits, each charged at that constant maximum trie depth.
preparationFixedWordSteps ::
     [CarrierObservation scope]
  -> [RelationObservation scope]
  -> [ContextualizationObservation scope]
  -> Int
  -> Int
preparationFixedWordSteps carriers relations contextualizations roots =
  finiteBitSize (0 :: Int) * operations
  where
    operations =
      1
        + length traceVariables * length carriers
        + length traceRelationSlots * length relations
        + length traceOwnershipSlots * length contextualizations
        + 2 * roots
