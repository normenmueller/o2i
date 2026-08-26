-- | Private 38-stage factorized-frontier evaluator for Core Trace.
module O2I.Trace.Eval
  ( assessTraceabilityInternal
  , bindTraceIdentityInternal
  , validateSuppliedTraceInternal
  , validateSuppliedTraceWithWorkInternal
  , promoteTraceInternal
  ) where

import Data.Bits (finiteBitSize)
import qualified Data.IntMap.Strict as IntMap
import Data.IntMap.Strict (IntMap)
import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Set as Set
import Data.Set (Set)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types (StrategyFormulationInput(..))
import O2I.Semantics.Internal
  ( QualificationEligibleStrategy(..)
  , SemanticallyValidModel(..)
  , StrategyFormulationAssessment(..)
  , semanticallyValidModelGraphIdentity
  )
import O2I.Trace.Grammar
import O2I.Trace.Index
import O2I.Trace.Internal

newtype Assignment =
  Assignment [Maybe DenseIdentity]
  deriving (Eq, Show)

-- | One compacted frontier binding and its least complete history summary.
-- Histories with the same live binding are never retained separately.
data FrontierEntry = FrontierEntry
  { frontierBinding :: !Assignment
  , frontierLeastHistory :: !Assignment
  } deriving (Eq, Show)

data AssignmentTrie value = AssignmentTrie
  { trieValue :: !(Maybe value)
  , trieChildren :: !(IntMap (AssignmentTrie value))
  }

data Frontier = Frontier
  { frontierSize :: !Int
  , frontierTrie :: !(AssignmentTrie FrontierEntry)
  }

data StageFold =
  StageFold !Frontier !Int !Int !Int !Int !Int

data FrontierResult = FrontierResult
  { frontierConsistent :: !Bool
  , frontierLeastWitness :: !(Maybe Assignment)
  , frontierFinalBindings :: ![Assignment]
  , frontierWork :: !TraceWork
  }

assessTraceabilityInternal ::
     SemanticallyValidModel scope -> (TraceAssessment scope, TraceWork)
assessTraceabilityInternal model =
  case traceIndexRoots index of
    [] -> (NoAssertedRoot (traceIndexGraphIdentity index), traceIndexWork index)
    firstRoot:remainingRoots ->
      let (firstTrace, firstWork) = assessRoot index firstRoot
          (remainingTraces, remainingWork) =
            foldl'
              (assessRemainingRoot index)
              ([], emptyTraceWork)
              remainingRoots
       in ( AssessedRootTraces
              (traceIndexGraphIdentity index)
              (firstTrace :| reverse remainingTraces)
          , addTraceWork
              (traceIndexWork index)
              (addTraceWork firstWork remainingWork))
  where
    index = buildTraceIndex (semanticModelGraph model)

assessRemainingRoot ::
     TraceIndex scope
  -> ([RootTrace scope], TraceWork)
  -> TraceRootBinding
  -> ([RootTrace scope], TraceWork)
assessRemainingRoot index (traces, work) root =
  let (trace, rootWork) = assessRoot index root
   in (trace : traces, addTraceWork work rootWork)

assessRoot ::
     TraceIndex scope -> TraceRootBinding -> (RootTrace scope, TraceWork)
assessRoot index root =
  ( RootTrace (traceIndexGraphIdentity index) root result
  , addTraceWork
      supportClassificationWork
      (addTraceWork (frontierWork primary) diagnosticWork))
  where
    supportClassificationWork =
      emptyTraceWork
        {traceAddressTrieSteps = length traceSlots * addressLookupStepBound}
    supported = filter (slotSupported index root) traceSlots
    missing = filter (`notElem` supported) traceSlots
    primary = runFrontier index root supported Nothing []
    (result, diagnosticWork)
      | frontierConsistent primary && null missing =
        ( CompleteTraceResult
            (completeWitness index (requiredLeastWitness primary))
        , denseEmissionWork (length traceVariables))
      | frontierConsistent primary =
        let (projections, projectionWork) =
              exactProjections index root supported
            (supports, supportWork) =
              admissiblePartialSupports index root supported
            (gaps, gapWork) =
              consistentGaps index root supported missing projections
         in ( PartialTraceResult
                PartialTrace
                  { storedPartialVariableProjections =
                      projectionsInOrder projections
                  , storedPartialRelationSupport =
                      filter (isRelationSlot . storedSupportSlot) supports
                  , storedPartialOwnershipSupport =
                      filter (not . isRelationSlot . storedSupportSlot) supports
                  , storedPartialGaps = gaps
                  }
            , addTraceWork projectionWork (addTraceWork supportWork gapWork))
      | otherwise =
        ( PartialTraceResult
            PartialTrace
              { storedPartialVariableProjections =
                  [ TraceVariableProjection variable []
                  | variable <- traceVariables
                  ]
              , storedPartialRelationSupport = emptyPartialSupports True
              , storedPartialOwnershipSupport = emptyPartialSupports False
              , storedPartialGaps =
                  GlobalConsistencyObstruction
                    (nonEmptyInvariant supported)
                    GloballyInconsistentSupport
                    :| []
              }
        , emptyTraceWork)

slotSupported :: TraceIndex scope -> TraceRootBinding -> TraceSlot -> Bool
slotSupported index root slot =
  not (null (assertedBucket index (rootAssignment index root) slot))

rootAssignment :: TraceIndex scope -> TraceRootBinding -> Assignment
rootAssignment _ root =
  assignmentInsert
    NeedVariable
    need
    (assignmentInsert InterventionVariable intervention emptyAssignment)
  where
    intervention = denseIdentityFromRank (storedRootInterventionRank root)
    need = denseIdentityFromRank (storedRootNeedRank root)

runFrontier ::
     TraceIndex scope
  -> TraceRootBinding
  -> [TraceSlot]
  -> Maybe TraceSlot
  -> [TraceVariable]
  -> FrontierResult
runFrontier index root supported candidateOverride distinguished =
  FrontierResult
    { frontierConsistent = frontierSize finalFrontier /= 0
    , frontierLeastWitness = leastWitness
    , frontierFinalBindings =
        map frontierBinding (frontierEntries finalFrontier)
    , frontierWork =
        addTraceWork
          (emptyTraceWork {traceConsistencyRuns = 1})
          (addTraceWork work finalTraversalWork)
    }
  where
    initialBinding = rootAssignment index root
    initialEntry = FrontierEntry initialBinding initialBinding
    initialFrontier = singletonFrontier initialEntry
    (finalFrontier, work) =
      foldl'
        (advanceStage index supported candidateOverride distinguished)
        (initialFrontier, emptyTraceWork)
        (zip [0 ..] traceSlots)
    (leastWitness, finalComparisons) = leastHistoryCount finalFrontier
    finalTraversalWork =
      emptyTraceWork
        { traceFrontierKeyTrieSteps =
            2 * frontierTraversalStepBound finalFrontier
        , traceFrontierHistoryCellComparisons = finalComparisons
        }

advanceStage ::
     TraceIndex scope
  -> [TraceSlot]
  -> Maybe TraceSlot
  -> [TraceVariable]
  -> (Frontier, TraceWork)
  -> (Int, TraceSlot)
  -> (Frontier, TraceWork)
advanceStage index supported candidateOverride distinguished (previous, accumulatedWork) (stage, slot) =
  (next, addTraceWork accumulatedWork stageWork)
  where
    retained = slot `elem` supported || candidateOverride == Just slot
    liveAfter = Set.union (futureVariables stage) (Set.fromList distinguished)
    StageFold next bucketOccurrences emitted addressSteps keySteps comparisons =
      foldl'
        (advanceEntry index candidateOverride retained slot liveAfter)
        (StageFold emptyFrontier 0 0 0 0 0)
        (frontierEntries previous)
    stageWork =
      emptyTraceWork
        { traceFrontierStageVisits = 1
        , traceFrontierBindingsVisited = frontierSize previous
        , traceSupportBucketOccurrences = bucketOccurrences
        , traceFrontierBindingsEmitted = emitted
        , traceFrontierPeakPair = frontierSize previous + frontierSize next
        , traceAddressTrieSteps = addressSteps
        , traceFrontierKeyTrieSteps =
            keySteps + frontierTraversalStepBound previous
        , traceFrontierHistoryCellComparisons = comparisons
        }

advanceEntry ::
     TraceIndex scope
  -> Maybe TraceSlot
  -> Bool
  -> TraceSlot
  -> Set TraceVariable
  -> StageFold
  -> FrontierEntry
  -> StageFold
advanceEntry index candidateOverride retained slot liveAfter state entry
  | not retained = insertTransition state (compactEntry liveAfter entry) 0 0
  | otherwise = foldl' extend (chargeAddressLookup state) bucket
  where
    extend accumulated (endpoints, occurrences) =
      insertTransition
        accumulated
        (compactEntry liveAfter (extendEntry slot endpoints entry))
        (length occurrences)
        0
    bucket
      | candidateOverride == Just slot =
        candidateBucket index (frontierBinding entry) slot
      | otherwise = assertedBucket index (frontierBinding entry) slot

chargeAddressLookup :: StageFold -> StageFold
chargeAddressLookup (StageFold entries occurrences emitted addressSteps keySteps comparisons) =
  StageFold
    entries
    occurrences
    emitted
    (addressSteps + addressLookupStepBound)
    keySteps
    comparisons

insertTransition :: StageFold -> FrontierEntry -> Int -> Int -> StageFold
insertTransition (StageFold entries occurrences emitted addressSteps keySteps comparisons) entry supportSize lookupSteps =
  StageFold
    next
    (occurrences + supportSize)
    (emitted + 1)
    (addressSteps + lookupSteps)
    (keySteps + assignmentTransitionStepBound + insertionSteps)
    (comparisons + historyComparisons)
  where
    (next, insertionSteps, historyComparisons) = frontierInsert entry entries

extendEntry ::
     TraceSlot
  -> (DenseIdentity, DenseIdentity)
  -> FrontierEntry
  -> FrontierEntry
extendEntry slot (source, target) entry =
  FrontierEntry
    { frontierBinding = extended (frontierBinding entry)
    , frontierLeastHistory = extended (frontierLeastHistory entry)
    }
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot
    extended =
      assignmentInsert targetVariable target
        . assignmentInsert sourceVariable source

compactEntry :: Set TraceVariable -> FrontierEntry -> FrontierEntry
compactEntry retained entry =
  entry {frontierBinding = assignmentRestrict retained (frontierBinding entry)}

leastHistoryCount :: Frontier -> (Maybe Assignment, Int)
leastHistoryCount frontier =
  case map frontierLeastHistory (frontierEntries frontier) of
    [] -> (Nothing, 0)
    first:remaining ->
      let (least, comparisons) = foldl' choose (first, 0) remaining
       in (Just least, comparisons)
  where
    choose (least, comparisons) candidate =
      let (ordering, cells) = compareAssignmentCount candidate least
       in ( if ordering == LT
              then candidate
              else least
          , comparisons + cells)

emptyAssignment :: Assignment
emptyAssignment = Assignment (replicate (length traceVariables) Nothing)

assignmentLookup :: TraceVariable -> Assignment -> Maybe DenseIdentity
assignmentLookup variable (Assignment values) = values !! fromEnum variable

assignmentInsert :: TraceVariable -> DenseIdentity -> Assignment -> Assignment
assignmentInsert variable value (Assignment values) =
  Assignment (replaceAt (fromEnum variable) (Just value) values)

replaceAt :: Int -> value -> [value] -> [value]
replaceAt 0 replacement (_:values) = replacement : values
replaceAt position replacement (value:values) =
  value : replaceAt (position - 1) replacement values
replaceAt _ _ [] = error "Trace assignment variable rank out of bounds"

assignmentRestrict :: Set TraceVariable -> Assignment -> Assignment
assignmentRestrict retained (Assignment values) =
  Assignment
    [ if variable `Set.member` retained
      then value
      else Nothing
    | (variable, value) <- zip traceVariables values
    ]

assignmentKey :: Assignment -> [Int]
assignmentKey (Assignment values) =
  [maybe 0 ((+ 1) . denseIdentityRank) value | value <- values]

compareAssignmentCount :: Assignment -> Assignment -> (Ordering, Int)
compareAssignmentCount (Assignment left) (Assignment right) =
  compareCells left right 0
  where
    compareCells [] [] count = (EQ, count)
    compareCells (leftValue:leftValues) (rightValue:rightValues) count =
      case compare leftValue rightValue of
        EQ -> compareCells leftValues rightValues (count + 1)
        ordering -> (ordering, count + 1)
    compareCells _ _ _ = error "Trace assignment shape mismatch"

emptyTrie :: AssignmentTrie value
emptyTrie = AssignmentTrie Nothing IntMap.empty

emptyFrontier :: Frontier
emptyFrontier = Frontier 0 emptyTrie

singletonFrontier :: FrontierEntry -> Frontier
singletonFrontier entry = fst3 (frontierInsert entry emptyFrontier)

frontierInsert :: FrontierEntry -> Frontier -> (Frontier, Int, Int)
frontierInsert entry frontier =
  ( Frontier
      (frontierSize frontier
         + if inserted
             then 1
             else 0)
      nextTrie
  , 2 * length traceVariables * intMapWordDepth
  , historyComparisons)
  where
    (nextTrie, inserted, historyComparisons) =
      trieInsert
        (assignmentKey (frontierBinding entry))
        entry
        (frontierTrie frontier)

trieInsert ::
     [Int]
  -> FrontierEntry
  -> AssignmentTrie FrontierEntry
  -> (AssignmentTrie FrontierEntry, Bool, Int)
trieInsert [] entry trie =
  case trieValue trie of
    Nothing -> (trie {trieValue = Just entry}, True, 0)
    Just old ->
      let (ordering, comparisons) =
            compareAssignmentCount
              (frontierLeastHistory entry)
              (frontierLeastHistory old)
          selected =
            if ordering == LT
              then entry
              else old
       in (trie {trieValue = Just selected}, False, comparisons)
trieInsert (key:keys) entry trie =
  ( trie {trieChildren = IntMap.insert key nextChild (trieChildren trie)}
  , inserted
  , comparisons)
  where
    child = IntMap.findWithDefault emptyTrie key (trieChildren trie)
    (nextChild, inserted, comparisons) = trieInsert keys entry child

frontierEntries :: Frontier -> [FrontierEntry]
frontierEntries = trieEntries . frontierTrie

trieEntries :: AssignmentTrie value -> [value]
trieEntries trie =
  maybe [] (: []) (trieValue trie)
    ++ concatMap trieEntries (IntMap.elems (trieChildren trie))

intMapWordDepth :: Int
intMapWordDepth = finiteBitSize (0 :: Int)

frontierTraversalStepBound :: Frontier -> Int
frontierTraversalStepBound frontier =
  frontierSize frontier * length traceVariables * intMapWordDepth

addressLookupStepBound :: Int
addressLookupStepBound = 3 * intMapWordDepth + 2 * length traceVariables

assignmentTransitionStepBound :: Int
assignmentTransitionStepBound = 3 * length traceVariables

fst3 :: (first, second, third) -> first
fst3 (value, _, _) = value

futureVariables :: Int -> Set TraceVariable
futureVariables stage =
  Set.fromList
    [ variable
    | slot <- drop (stage + 1) traceSlots
    , variable <- pairValues (traceSlotVariables slot)
    ]

pairValues :: (value, value) -> [value]
pairValues (left, right) = [left, right]

assertedBucket ::
     TraceIndex scope
  -> Assignment
  -> TraceSlot
  -> [((DenseIdentity, DenseIdentity), [OccurrenceIdentity])]
assertedBucket index binding slot =
  traceIndexAssertedBucket
    index
    slot
    (assignmentLookup sourceVariable binding)
    (assignmentLookup targetVariable binding)
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot

candidateBucket ::
     TraceIndex scope
  -> Assignment
  -> TraceSlot
  -> [((DenseIdentity, DenseIdentity), [OccurrenceIdentity])]
candidateBucket index binding slot =
  traceIndexCandidateBucket
    index
    slot
    (assignmentLookup sourceVariable binding)
    (assignmentLookup targetVariable binding)
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot

exactProjections ::
     TraceIndex scope
  -> TraceRootBinding
  -> [TraceSlot]
  -> ([(TraceVariable, [ModelIdentity])], TraceWork)
exactProjections index root supported =
  foldl' project ([], emptyTraceWork) traceVariables
  where
    mentioned =
      Set.fromList
        [ variable
        | slot <- supported
        , variable <- pairValues (traceSlotVariables slot)
        ]
    project (projections, work) variable
      | variable `Set.notMember` mentioned =
        let domain = traceIndexDomain index variable
         in ( projections
                ++ [(variable, map (traceIndexResolveIdentity index) domain)]
            , addTraceWork work (denseEmissionWork (length domain)))
      | otherwise =
        let result = runFrontier index root supported Nothing [variable]
            values =
              [ traceIndexResolveIdentity index dense
              | binding <- frontierFinalBindings result
              , Just dense <- [assignmentLookup variable binding]
              ]
         in ( projections ++ [(variable, values)]
            , addTraceWork
                work
                (addTraceWork
                   (frontierWork result)
                   (denseEmissionWork (length values))))

denseEmissionWork :: Int -> TraceWork
denseEmissionWork count =
  emptyTraceWork {traceAddressTrieSteps = count * intMapWordDepth}

completeWitness :: TraceIndex scope -> Assignment -> CompleteWitness scope
completeWitness index assignment =
  CompleteWitness
    { storedCompleteTraceIdentity = identity
    , storedCompleteRelationSupport = exactSupports index assignment True
    , storedCompleteOwnershipSupport = exactSupports index assignment False
    }
  where
    identity =
      traceIdentityValue
        (traceIndexGraphIdentity index)
        [ ( variable
          , traceIndexResolveIdentity
              index
              (requiredAssignment variable assignment))
        | variable <- traceVariables
        ]

requiredLeastWitness :: FrontierResult -> Assignment
requiredLeastWitness result =
  case frontierLeastWitness result of
    Just witness -> witness
    Nothing -> error "consistent Trace frontier without a history summary"

exactSupports :: TraceIndex scope -> Assignment -> Bool -> [TraceSlotSupport]
exactSupports index assignment relations =
  [ TraceSlotSupport
    slot
    (traceIndexAssertedSupport index slot (assignmentEndpoints assignment slot))
  | slot <- traceSlots
  , isRelationSlot slot == relations
  ]

admissiblePartialSupports ::
     TraceIndex scope
  -> TraceRootBinding
  -> [TraceSlot]
  -> ([TraceSlotSupport], TraceWork)
admissiblePartialSupports index root supported =
  foldl' supportForSlot ([], emptyTraceWork) traceSlots
  where
    supportForSlot (supports, work) slot
      | slot `notElem` supported =
        (supports ++ [TraceSlotSupport slot []], work)
      | otherwise =
        let (sourceVariable, targetVariable) = traceSlotVariables slot
            result =
              runFrontier
                index
                root
                supported
                Nothing
                [sourceVariable, targetVariable]
            endpointPairs =
              [ ( requiredAssignment sourceVariable binding
                , requiredAssignment targetVariable binding)
              | binding <- frontierFinalBindings result
              ]
            occurrences =
              sort
                (concatMap (traceIndexAssertedSupport index slot) endpointPairs)
            lookupWork =
              emptyTraceWork
                { traceAddressTrieSteps =
                    length endpointPairs * addressLookupStepBound
                }
         in ( supports ++ [TraceSlotSupport slot occurrences]
            , addTraceWork work (addTraceWork (frontierWork result) lookupWork))

emptyPartialSupports :: Bool -> [TraceSlotSupport]
emptyPartialSupports relations =
  [ TraceSlotSupport slot []
  | slot <- traceSlots
  , isRelationSlot slot == relations
  ]

isRelationSlot :: TraceSlot -> Bool
isRelationSlot slot =
  case slot of
    RelationTraceSlot _ -> True
    OwnershipTraceSlot _ -> False

projectionsInOrder ::
     [(TraceVariable, [ModelIdentity])] -> [TraceVariableProjection]
projectionsInOrder projections =
  [ TraceVariableProjection variable (projectionValues projections variable)
  | variable <- traceVariables
  ]

consistentGaps ::
     TraceIndex scope
  -> TraceRootBinding
  -> [TraceSlot]
  -> [TraceSlot]
  -> [(TraceVariable, [ModelIdentity])]
  -> (NonEmpty TraceGap, TraceWork)
consistentGaps index root supported missing projections =
  case reverse gaps of
    first:remaining -> (first :| remaining, work)
    [] -> error "partial Trace without a gap"
  where
    (gaps, work) = foldl' classify ([], emptyTraceWork) missing
    classify (accumulated, accumulatedWork) slot =
      let rootCandidateBucket =
            candidateBucket index (rootAssignment index root) slot
          candidateResult
            | null rootCandidateBucket = Nothing
            | otherwise = Just (runFrontier index root supported (Just slot) [])
          disposition =
            case candidateResult of
              Just result
                | frontierConsistent result -> CandidateOnlySupport
              _ -> MissingSupport
          nextWork =
            maybe
              accumulatedWork
              (addTraceWork accumulatedWork . frontierWork)
              candidateResult
       in (mkGap projections slot disposition : accumulated, nextWork)

mkGap ::
     [(TraceVariable, [ModelIdentity])]
  -> TraceSlot
  -> TraceGapDisposition
  -> TraceGap
mkGap projections slot disposition =
  case (sourceValues, targetValues) of
    ([source], [target]) ->
      BoundSlotGap
        slot
        (TraceBoundEndpoints sourceVariable source targetVariable target)
        disposition
    _ ->
      UnboundSlotGap slot established (nonEmptyInvariant unresolved) disposition
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot
    sourceValues = projectionValues projections sourceVariable
    targetValues = projectionValues projections targetVariable
    established =
      [(sourceVariable, value) | [value] <- [sourceValues]]
        ++ [(targetVariable, value) | [value] <- [targetValues]]
    unresolved =
      [ variable
      | (variable, values) <-
          [(sourceVariable, sourceValues), (targetVariable, targetValues)]
      , length values /= 1
      ]

nonEmptyInvariant :: [value] -> NonEmpty value
nonEmptyInvariant values =
  case NonEmpty.nonEmpty values of
    Just result -> result
    Nothing -> error "Trace evaluator invariant requires a non-empty value"

bindTraceIdentityInternal ::
     SemanticallyValidModel scope
  -> TraceIdentity
  -> Either (NonEmpty TraceIdentityBindingDefect) (BoundTraceIdentity scope)
bindTraceIdentityInternal model identity =
  case NonEmpty.nonEmpty defects of
    Nothing -> Right (BoundTraceIdentity identity)
    Just failures -> Left failures
  where
    index = buildTraceIndex (semanticModelGraph model)
    defects =
      [ TraceIdentityVariableUnresolved variable boundIdentity
      | variable <- traceVariables
      , let boundIdentity = traceIdentityBinding identity variable
      , maybe
          True
          (`notElem` traceIndexDomain index variable)
          (traceIndexInternIdentity index boundIdentity)
      ]

validateSuppliedTraceInternal ::
     SemanticallyValidModel scope
  -> BoundTraceIdentity scope
  -> SuppliedTraceAssessment scope
validateSuppliedTraceInternal model =
  fst . validateSuppliedTraceWithWorkInternal model

validateSuppliedTraceWithWorkInternal ::
     SemanticallyValidModel scope
  -> BoundTraceIdentity scope
  -> (SuppliedTraceAssessment scope, TraceWork)
validateSuppliedTraceWithWorkInternal model boundIdentity
  | storedTraceGraphIdentity identity /= traceIndexGraphIdentity index =
    ( SuppliedTraceUnavailable
        identity
        (TraceGraphIdentityMismatch
           (traceIndexGraphIdentity index)
           (storedTraceGraphIdentity identity)
           :| [])
    , traceIndexWork index)
  | otherwise =
    ( case NonEmpty.nonEmpty failures of
        Just reasons -> SuppliedTraceUnavailable identity reasons
        Nothing ->
          SuppliedTraceComplete
            SuppliedCompleteTrace
              { storedSuppliedTraceIdentity = identity
              , storedSuppliedRelationSupport =
                  exactSupports index denseIdentity True
              , storedSuppliedOwnershipSupport =
                  exactSupports index denseIdentity False
              }
    , addTraceWork
        (traceIndexWork index)
        (emptyTraceWork
           { traceDirectSupportLookups = lookupCount
           , tracePreparationIdentityScalarSteps = bindingScalarSteps
           , traceAddressTrieSteps = lookupCount * addressLookupStepBound
           }))
  where
    identity = storedBoundTraceIdentity boundIdentity
    index = buildTraceIndex (semanticModelGraph model)
    (denseIdentity, bindingScalarSteps) =
      identityAssignmentWithSteps index identity
    checkedSlots =
      [ (slot, endpoints, asserted, candidate)
      | slot <- traceSlots
      , let endpoints = identityEndpoints identity slot
            asserted =
              traceIndexAssertedSupport
                index
                slot
                (assignmentEndpoints denseIdentity slot)
            candidate
              | null asserted =
                traceIndexCandidateSupport
                  index
                  slot
                  (assignmentEndpoints denseIdentity slot)
              | otherwise = []
      ]
    failures =
      [ ExactSlotUnsupported
        slot
        endpoints
        (if null candidate
           then MissingSupport
           else CandidateOnlySupport)
      | (slot, endpoints, asserted, candidate) <- checkedSlots
      , null asserted
      ]
    lookupCount =
      sum
        [ 1
          + if null asserted
              then 1
              else 0
        | (_, _, asserted, _) <- checkedSlots
        ]

identityEndpoints :: TraceIdentity -> TraceSlot -> TraceBoundEndpoints
identityEndpoints identity slot =
  TraceBoundEndpoints
    sourceVariable
    (traceIdentityBinding identity sourceVariable)
    targetVariable
    (traceIdentityBinding identity targetVariable)
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot

identityAssignmentWithSteps ::
     TraceIndex scope -> TraceIdentity -> (Assignment, Int)
identityAssignmentWithSteps index identity =
  foldl' insertBinding (emptyAssignment, 0) traceVariables
  where
    insertBinding (assignment, accumulatedSteps) variable =
      case traceIndexInternIdentityWithSteps
             index
             (traceIdentityBinding identity variable) of
        (Just dense, steps) ->
          (assignmentInsert variable dense assignment, accumulatedSteps + steps)
        (Nothing, _) ->
          error "bound Trace identity missing from dense interning"

assignmentEndpoints :: Assignment -> TraceSlot -> (DenseIdentity, DenseIdentity)
assignmentEndpoints assignment slot =
  ( requiredAssignment sourceVariable assignment
  , requiredAssignment targetVariable assignment)
  where
    (sourceVariable, targetVariable) = traceSlotVariables slot

requiredAssignment :: TraceVariable -> Assignment -> DenseIdentity
requiredAssignment variable assignment =
  case assignmentLookup variable assignment of
    Just value -> value
    Nothing -> error "Trace assignment missing required fixed variable"

projectionValues ::
     [(TraceVariable, [ModelIdentity])] -> TraceVariable -> [ModelIdentity]
projectionValues projections variable =
  case lookup variable projections of
    Just values -> values
    Nothing -> []

promoteTraceInternal ::
     SemanticallyValidModel scope
  -> StrategyFormulationAssessment scope
  -> SuppliedCompleteTrace scope
  -> TracePromotionAssessment scope
promoteTraceInternal model strategyAssessment supplied =
  case promotionReasons of
    [] ->
      TracePromotionSucceeded
        PromotedTraceableEffectModel
          { storedPromotedGraphIdentity = modelIdentity
          , storedPromotedTraceIdentity = identity
          , storedPromotedStrategyProofIdentity =
              traceIdentityBinding identity StrategyVariable
          }
    first:remaining ->
      TracePromotionUnavailable modelIdentity identity (first :| remaining)
  where
    modelIdentity = semanticallyValidModelGraphIdentity model
    identity = storedSuppliedTraceIdentity supplied
    promotionReasons =
      case strategyAssessment of
        StrategyFormulationUnavailable _ _ -> [StrategyAssessmentUnavailable]
        StrategyFormulationCandidate _ _ -> [StrategyAssessmentUnavailable]
        StrategyFormulationInvalid _ _ -> [StrategyAssessmentInvalid]
        StrategyFormulationValid proof
          | eligibleStrategyGraphIdentity proof /= modelIdentity ->
            [StrategyProofModelMismatch]
          | eligibleStrategyIdentity proof
              /= traceIdentityBinding identity StrategyVariable ->
            [StrategyIdentityMismatch]
          | otherwise -> formulationMismatches identity proof

formulationMismatches ::
     TraceIdentity
  -> QualificationEligibleStrategy scope
  -> [TracePromotionUnavailableReason]
formulationMismatches identity proof =
  [ StrategyDiagnosisMismatch
  | formulationDiagnosis formulation /= binding StrategyDriverVariable
  ]
    ++ [ StrategyIntentMismatch
       | formulationIntent formulation /= binding StrategyObjectiveVariable
       ]
    ++ [ StrategyActionNotInFormulation
       | binding StrategyActionVariable
           `notElem` NonEmpty.toList (formulationActions formulation)
       ]
    ++ [ StrategyKeyResultNotInFormulation
       | binding StrategyKeyResultVariable
           `notElem` NonEmpty.toList (formulationKeyResults formulation)
       ]
  where
    formulation = eligibleStrategyInput proof
    binding = traceIdentityBinding identity
