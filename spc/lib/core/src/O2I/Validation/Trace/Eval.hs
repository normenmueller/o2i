{-# LANGUAGE DataKinds #-}

-- | Private execution of endpoint-typed effect-trace rules.
module O2I.Validation.Trace.Eval
  ( CanonicalizationWork(..)
  , TraceEvaluationWork(..)
  , TraceEvaluationResult
  , evaluateEffectTraces
  , traceEvaluationInterventions
  , traceEvaluationAddressedNeedsFor
  , traceEvaluationTraceMap
  , traceEvaluationTraces
  , traceEvaluationCovers
  , traceEvaluationWork
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import O2I.Language.Element
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Rule
import O2I.Validation.Trace.Types

-- | Actual row classifications performed by one canonicalization boundary.
data CanonicalizationWork = CanonicalizationWork
  { canonicalizationRowsRead :: !Int
  , canonicalizationUniqueRows :: !Int
  , canonicalizationDuplicateRows :: !Int
  } deriving (Eq, Show)

instance Semigroup CanonicalizationWork where
  left <> right =
    CanonicalizationWork
      { canonicalizationRowsRead =
          canonicalizationRowsRead left + canonicalizationRowsRead right
      , canonicalizationUniqueRows =
          canonicalizationUniqueRows left + canonicalizationUniqueRows right
      , canonicalizationDuplicateRows =
          canonicalizationDuplicateRows left
            + canonicalizationDuplicateRows right
      }

instance Monoid CanonicalizationWork where
  mempty = CanonicalizationWork 0 0 0

-- | Exact operations performed after shared macro-evidence preparation.
data TraceEvaluationWork = TraceEvaluationWork
  { traceInterventionDomainValuesRead :: !Int
  , traceAddressedEvaluationWork :: !EvaluationWork
  , traceAddressedCanonicalizationWork :: !CanonicalizationWork
  , traceContextEvaluationWork :: !EvaluationWork
  , traceContextCanonicalizationWork :: !CanonicalizationWork
  , traceAnchorDomainsInspected :: !Int
  , traceEmptyAnchorDomainsSkipped :: !Int
  , traceConstituentPlansExecuted :: !Int
  , traceConstituentEvaluationWork :: !EvaluationWork
  , traceCanonicalizationWork :: !CanonicalizationWork
  , traceCoverageCanonicalizationWork :: !CanonicalizationWork
  } deriving (Eq, Show)

-- | Complete deterministic result consumed by Trace validation.
data TraceEvaluationResult = TraceEvaluationResult
  { storedInterventions :: ![NodeId ('ContextKind 'Intervention)]
  , storedAddressedIndex :: !(Map
                                (NodeId ('ContextKind 'Intervention))
                                (Set (NodeId ('ContextKind 'Need))))
  , storedTraceMap :: !(Map EffectTraceId EffectTrace)
  , storedCoveredPairs :: !(Set AddressedNeed)
  , storedTraceWork :: !TraceEvaluationWork
  }

data AddressedCanonicalization = AddressedCanonicalization
  { canonicalAddressedValues :: !(Set AddressedNeed)
  , canonicalAddressedIndex :: !(Map
                                   (NodeId ('ContextKind 'Intervention))
                                   (Set (NodeId ('ContextKind 'Need))))
  , canonicalAddressedWork :: !CanonicalizationWork
  }

data CanonicalSet value = CanonicalSet
  { canonicalSetValues :: !(Set value)
  , canonicalSetWork :: !CanonicalizationWork
  }

data InterventionEnumeration = InterventionEnumeration
  { enumeratedInterventions :: ![NodeId ('ContextKind 'Intervention)]
  , interventionDomainValuesRead :: !Int
  }

data TraceFold = TraceFold
  { foldedTraceMap :: !(Map EffectTraceId EffectTrace)
  , foldedCoveredPairs :: !(Set AddressedNeed)
  , foldedAnchorDomainsInspected :: !Int
  , foldedEmptyAnchorDomainsSkipped :: !Int
  , foldedConstituentPlansExecuted :: !Int
  , foldedConstituentEvaluationWork :: !EvaluationWork
  , foldedTraceCanonicalizationWork :: !CanonicalizationWork
  , foldedCoverageCanonicalizationWork :: !CanonicalizationWork
  }

-- | Execute each typed trace rule once at its declared lifecycle boundary.
evaluateEffectTraces :: PreparedMacroEvidence -> TraceEvaluationResult
evaluateEffectTraces prepared =
  TraceEvaluationResult
    { storedInterventions = interventions
    , storedAddressedIndex = addressedIndex
    , storedTraceMap = traces
    , storedCoveredPairs = foldedCoveredPairs traceFold
    , storedTraceWork =
        TraceEvaluationWork
          { traceInterventionDomainValuesRead = interventionWork
          , traceAddressedEvaluationWork = evaluationWork addressedEvaluation
          , traceAddressedCanonicalizationWork = addressedWork
          , traceContextEvaluationWork = evaluationWork contextEvaluation
          , traceContextCanonicalizationWork = contextWork
          , traceAnchorDomainsInspected = foldedAnchorDomainsInspected traceFold
          , traceEmptyAnchorDomainsSkipped =
              foldedEmptyAnchorDomainsSkipped traceFold
          , traceConstituentPlansExecuted =
              foldedConstituentPlansExecuted traceFold
          , traceConstituentEvaluationWork =
              foldedConstituentEvaluationWork traceFold
          , traceCanonicalizationWork =
              foldedTraceCanonicalizationWork traceFold
          , traceCoverageCanonicalizationWork =
              foldedCoverageCanonicalizationWork traceFold
          }
    }
  where
    index = preparedRelationalIndex prepared
    InterventionEnumeration interventions interventionWork =
      enumerateInterventions (nodeDomainFor (SContextKind SIntervention) index)
    addressedEvaluation = runEnumerate index (addressedNeedRule prepared)
    AddressedCanonicalization _ addressedIndex addressedWork =
      canonicalizeAddressedNeeds (evaluationResult addressedEvaluation)
    contextEvaluation = runEnumerate index (effectTraceContextRule prepared)
    CanonicalSet contexts contextWork =
      canonicalizeRows (evaluationResult contextEvaluation)
    traceFold =
      foldl'
        (evaluateContext prepared index)
        emptyTraceFold
        (Set.toAscList contexts)
    traces = foldedTraceMap traceFold

emptyTraceFold :: TraceFold
emptyTraceFold =
  TraceFold
    { foldedTraceMap = Map.empty
    , foldedCoveredPairs = Set.empty
    , foldedAnchorDomainsInspected = 0
    , foldedEmptyAnchorDomainsSkipped = 0
    , foldedConstituentPlansExecuted = 0
    , foldedConstituentEvaluationWork = mempty
    , foldedTraceCanonicalizationWork = mempty
    , foldedCoverageCanonicalizationWork = mempty
    }

evaluateContext ::
     PreparedMacroEvidence
  -> RelationalIndex
  -> TraceFold
  -> EffectTraceContext
  -> TraceFold
evaluateContext prepared index initial context =
  let capability =
        inspectAnchor
          prepared
          index
          context
          BusinessCapabilityConstituentRule
          initial
      process =
        inspectAnchor
          prepared
          index
          context
          BusinessProcessConstituentRule
          capability
      object =
        inspectAnchor
          prepared
          index
          context
          BusinessObjectConstituentRule
          process
   in inspectAnchor prepared index context ValueStreamConstituentRule object

inspectAnchor ::
     PreparedMacroEvidence
  -> RelationalIndex
  -> EffectTraceContext
  -> EffectTraceConstituentRule anchor
  -> TraceFold
  -> TraceFold
inspectAnchor prepared index context rule current =
  if domainSize anchorDomain == 0
    then current
           { foldedAnchorDomainsInspected =
               foldedAnchorDomainsInspected current + 1
           , foldedEmptyAnchorDomainsSkipped =
               foldedEmptyAnchorDomainsSkipped current + 1
           }
    else case runEnumerate
                index
                (effectTraceConstituentRule prepared context rule) of
           Evaluation constituents work ->
             foldl'
               (insertTrace context anchor)
               current
                 { foldedAnchorDomainsInspected =
                     foldedAnchorDomainsInspected current + 1
                 , foldedConstituentPlansExecuted =
                     foldedConstituentPlansExecuted current + 1
                 , foldedConstituentEvaluationWork =
                     foldedConstituentEvaluationWork current <> work
                 }
               constituents
  where
    anchor = effectTraceConstituentAnchor rule
    anchorDomain =
      preparedSituationAnchorDomain
        prepared
        (traceContextSituation context)
        anchor

insertTrace ::
     EffectTraceContext
  -> SSituationAnchor anchor
  -> TraceFold
  -> EffectTraceConstituents anchor
  -> TraceFold
insertTrace context anchor current constituents =
  case Map.lookup identifier traces of
    Just _ ->
      current
        { foldedTraceCanonicalizationWork =
            canonicalizationDuplicate (foldedTraceCanonicalizationWork current)
        }
    Nothing ->
      insertTraceCoverage
        trace
        current
          { foldedTraceMap = Map.insert identifier trace traces
          , foldedTraceCanonicalizationWork =
              canonicalizationUnique (foldedTraceCanonicalizationWork current)
          }
  where
    trace = effectTraceFromTyped context anchor constituents
    identifier = traceIdentifier trace
    traces = foldedTraceMap current

insertTraceCoverage :: EffectTrace -> TraceFold -> TraceFold
insertTraceCoverage trace current
  | Set.member addressed covered =
    current
      { foldedCoverageCanonicalizationWork =
          canonicalizationDuplicate (foldedCoverageCanonicalizationWork current)
      }
  | otherwise =
    current
      { foldedCoveredPairs = Set.insert addressed covered
      , foldedCoverageCanonicalizationWork =
          canonicalizationUnique (foldedCoverageCanonicalizationWork current)
      }
  where
    addressed = effectTraceCoveredPair trace
    covered = foldedCoveredPairs current

enumerateInterventions ::
     Domain ('ContextKind 'Intervention) -> InterventionEnumeration
enumerateInterventions =
  foldr prependIntervention (InterventionEnumeration [] 0) . domainToAscList

prependIntervention ::
     NodeId ('ContextKind 'Intervention)
  -> InterventionEnumeration
  -> InterventionEnumeration
prependIntervention intervention current =
  InterventionEnumeration
    { enumeratedInterventions = intervention : enumeratedInterventions current
    , interventionDomainValuesRead = interventionDomainValuesRead current + 1
    }

canonicalizeRows :: Ord value => [value] -> CanonicalSet value
canonicalizeRows = foldl' insertCanonicalRow (CanonicalSet Set.empty mempty)

canonicalizeAddressedNeeds :: [AddressedNeed] -> AddressedCanonicalization
canonicalizeAddressedNeeds =
  foldl'
    insertAddressedNeed
    (AddressedCanonicalization Set.empty Map.empty mempty)

insertAddressedNeed ::
     AddressedCanonicalization -> AddressedNeed -> AddressedCanonicalization
insertAddressedNeed current addressed
  | Set.member addressed values =
    current
      { canonicalAddressedWork =
          canonicalizationDuplicate (canonicalAddressedWork current)
      }
  | otherwise =
    AddressedCanonicalization
      { canonicalAddressedValues = Set.insert addressed values
      , canonicalAddressedIndex =
          Map.insertWith Set.union intervention (Set.singleton need) index
      , canonicalAddressedWork =
          canonicalizationUnique (canonicalAddressedWork current)
      }
  where
    values = canonicalAddressedValues current
    index = canonicalAddressedIndex current
    intervention = addressedNeedIntervention addressed
    need = addressedNeedNeed addressed

insertCanonicalRow ::
     Ord value => CanonicalSet value -> value -> CanonicalSet value
insertCanonicalRow current value
  | Set.member value values =
    current {canonicalSetWork = canonicalizationDuplicate work}
  | otherwise =
    CanonicalSet
      { canonicalSetValues = Set.insert value values
      , canonicalSetWork = canonicalizationUnique work
      }
  where
    values = canonicalSetValues current
    work = canonicalSetWork current

canonicalizationUnique :: CanonicalizationWork -> CanonicalizationWork
canonicalizationUnique work =
  work
    { canonicalizationRowsRead = canonicalizationRowsRead work + 1
    , canonicalizationUniqueRows = canonicalizationUniqueRows work + 1
    }

canonicalizationDuplicate :: CanonicalizationWork -> CanonicalizationWork
canonicalizationDuplicate work =
  work
    { canonicalizationRowsRead = canonicalizationRowsRead work + 1
    , canonicalizationDuplicateRows = canonicalizationDuplicateRows work + 1
    }

-- | Enumerate Context-typed Intervention identifiers in ascending order.
traceEvaluationInterventions ::
     TraceEvaluationResult -> [NodeId ('ContextKind 'Intervention)]
traceEvaluationInterventions = storedInterventions

-- | Enumerate one Intervention's independently derived Needs in ascending order.
traceEvaluationAddressedNeedsFor ::
     TraceEvaluationResult
  -> NodeId ('ContextKind 'Intervention)
  -> [NodeId ('ContextKind 'Need)]
traceEvaluationAddressedNeedsFor result intervention =
  maybe [] Set.toAscList (Map.lookup intervention (storedAddressedIndex result))

-- | Read the canonical trace map keyed by exact public identity.
traceEvaluationTraceMap ::
     TraceEvaluationResult -> Map EffectTraceId EffectTrace
traceEvaluationTraceMap = storedTraceMap

-- | Enumerate canonical traces in public identity order.
traceEvaluationTraces :: TraceEvaluationResult -> [EffectTrace]
traceEvaluationTraces = Map.elems . storedTraceMap

-- | Test typed Intervention-to-Need coverage derived from canonical traces.
traceEvaluationCovers :: TraceEvaluationResult -> AddressedNeed -> Bool
traceEvaluationCovers result addressed =
  Set.member addressed (storedCoveredPairs result)

-- | Read the exact work performed after shared preparation.
traceEvaluationWork :: TraceEvaluationResult -> TraceEvaluationWork
traceEvaluationWork = storedTraceWork
