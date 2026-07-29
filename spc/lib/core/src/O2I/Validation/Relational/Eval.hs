{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE NamedFieldPuns #-}

-- | Private variable-at-a-time evaluation of constructive typed plans.
module O2I.Validation.Relational.Eval
  ( Evaluation(..)
  , EvaluationWork(..)
  , runExists
  , runEnumerate
  ) where

import qualified Data.IntMap.Strict as IntMap
import Data.IntMap.Strict (IntMap)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Type.Equality ((:~:)(Refl))
import O2I.Language.Element
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Internal

-- | Exact counters for the named executor operations.
data EvaluationWork = EvaluationWork
  { workVariableFrames :: !Int -- ^ Variable recursion frames entered.
  , workConstraintScans :: !Int -- ^ Premises inspected.
  , workIndexDomainProbes :: !Int -- ^ Addressed index domains requested.
  , workDomainSizeComparisons :: !Int -- ^ Candidate sizes compared.
  , workDomainValuesVisited :: !Int -- ^ Smallest-domain values inspected.
  , workIntersectionMembershipProbes :: !Int -- ^ Set memberships tested.
  , workBindingAttempts :: !Int -- ^ Typed binding extensions attempted.
  , workCompleteNodeBindings :: !Int -- ^ Full variable bindings reached.
  , workEdgeBucketProbes :: !Int -- ^ Exact occurrence buckets requested.
  , workExactOccurrenceReads :: !Int -- ^ Exact occurrences inspected.
  , workResultsEmitted :: !Int -- ^ Occurrence-expanded rows emitted.
  } deriving (Eq, Show)

instance Semigroup EvaluationWork where
  left <> right =
    EvaluationWork
      { workVariableFrames = workVariableFrames left + workVariableFrames right
      , workConstraintScans =
          workConstraintScans left + workConstraintScans right
      , workIndexDomainProbes =
          workIndexDomainProbes left + workIndexDomainProbes right
      , workDomainSizeComparisons =
          workDomainSizeComparisons left + workDomainSizeComparisons right
      , workDomainValuesVisited =
          workDomainValuesVisited left + workDomainValuesVisited right
      , workIntersectionMembershipProbes =
          workIntersectionMembershipProbes left
            + workIntersectionMembershipProbes right
      , workBindingAttempts =
          workBindingAttempts left + workBindingAttempts right
      , workCompleteNodeBindings =
          workCompleteNodeBindings left + workCompleteNodeBindings right
      , workEdgeBucketProbes =
          workEdgeBucketProbes left + workEdgeBucketProbes right
      , workExactOccurrenceReads =
          workExactOccurrenceReads left + workExactOccurrenceReads right
      , workResultsEmitted = workResultsEmitted left + workResultsEmitted right
      }

instance Monoid EvaluationWork where
  mempty = EvaluationWork 0 0 0 0 0 0 0 0 0 0 0

-- | Evaluation result paired with only the work actually performed.
data Evaluation result = Evaluation
  { evaluationResult :: result
  , evaluationWork :: EvaluationWork
  } deriving (Eq, Show)

newtype Builder value =
  Builder ([value] -> [value])

emptyBuilder :: Builder value
emptyBuilder = Builder id

singletonBuilder :: value -> Builder value
singletonBuilder value = Builder (value :)

appendBuilder :: Builder value -> Builder value -> Builder value
appendBuilder (Builder left) (Builder right) = Builder (left . right)

buildList :: Builder value -> [value]
buildList (Builder build) = build []

-- | Scope-local typed bindings. Keys are allocated only by plan construction.
newtype Bindings scope =
  Bindings (IntMap RawNodeId)

emptyBindings :: Bindings scope
emptyBindings = Bindings IntMap.empty

bindValue :: Bound scope kind -> NodeId kind -> Bindings scope -> Bindings scope
bindValue bound value (Bindings bindings) =
  Bindings (IntMap.insert (boundKey bound) (unNodeId value) bindings)

lookupValue :: Bound scope kind -> Bindings scope -> Maybe (NodeId kind)
lookupValue bound (Bindings bindings) =
  mkNodeId <$> IntMap.lookup (boundKey bound) bindings

-- | Stop at the first complete typed witness without constructing a row.
runExists :: RelationalIndex -> CompiledPlan row -> Evaluation Bool
runExists index compiled =
  withCompiledPlan compiled $ \bounds premises _ ->
    let (found, work) =
          existsVariables
            index
            (premisesToList premises)
            (NonEmpty.toList bounds)
            emptyBindings
     in Evaluation found work

-- | Enumerate deterministic rows from complete bindings and exact occurrences.
runEnumerate :: RelationalIndex -> CompiledPlan row -> Evaluation [row]
runEnumerate index compiled =
  withCompiledPlan compiled $ \bounds premises projection ->
    let (rows, work) =
          enumerateVariables
            index
            premises
            projection
            (NonEmpty.toList bounds)
            emptyBindings
     in Evaluation (buildList rows) work

existsVariables ::
     RelationalIndex
  -> [SomePremise scope]
  -> [SomeBound scope]
  -> Bindings scope
  -> (Bool, EvaluationWork)
existsVariables index premises [] bindings =
  let complete = mempty {workCompleteNodeBindings = 1}
      (found, work) = existsOccurrences index premises bindings
   in (found, complete <> work)
existsVariables index premises (SomeBound bound:rest) bindings =
  let (domains, probeWork) = candidateDomains index bound premises bindings
      (selected, guards, comparisons) = selectSmallest domains
      frameWork =
        mempty {workVariableFrames = 1, workDomainSizeComparisons = comparisons}
      (found, branchWork) =
        existsCandidates
          index
          premises
          rest
          bound
          guards
          (domainToAscList selected)
          bindings
   in (found, frameWork <> probeWork <> branchWork)

existsCandidates ::
     RelationalIndex
  -> [SomePremise scope]
  -> [SomeBound scope]
  -> Bound scope kind
  -> [Domain kind]
  -> [NodeId kind]
  -> Bindings scope
  -> (Bool, EvaluationWork)
existsCandidates _ _ _ _ _ [] _ = (False, mempty)
existsCandidates index premises rest bound guards (value:values) bindings =
  let visit = mempty {workDomainValuesVisited = 1}
      (admitted, membership) = admittedByAll value guards
   in if not admitted
        then let (found, remaining) =
                   existsCandidates
                     index
                     premises
                     rest
                     bound
                     guards
                     values
                     bindings
              in (found, visit <> membership <> remaining)
        else let attempt = mempty {workBindingAttempts = 1}
                 (found, nested) =
                   existsVariables
                     index
                     premises
                     rest
                     (bindValue bound value bindings)
              in if found
                   then (True, visit <> membership <> attempt <> nested)
                   else let (remainingFound, remaining) =
                              existsCandidates
                                index
                                premises
                                rest
                                bound
                                guards
                                values
                                bindings
                         in ( remainingFound
                            , visit
                                <> membership
                                <> attempt
                                <> nested
                                <> remaining)

enumerateVariables ::
     RelationalIndex
  -> Premises scope shape
  -> Projection mode scope shape row
  -> [SomeBound scope]
  -> Bindings scope
  -> (Builder row, EvaluationWork)
enumerateVariables index premises projection [] bindings =
  let complete = mempty {workCompleteNodeBindings = 1}
      (rows, work) = enumerateOccurrences index premises projection bindings
   in (rows, complete <> work)
enumerateVariables index premises projection (SomeBound bound:rest) bindings =
  let (domains, probeWork) =
        candidateDomains index bound (premisesToList premises) bindings
      (selected, guards, comparisons) = selectSmallest domains
      frameWork =
        mempty {workVariableFrames = 1, workDomainSizeComparisons = comparisons}
      (rows, branchWork) =
        enumerateCandidates
          index
          premises
          projection
          rest
          bound
          guards
          (domainToAscList selected)
          bindings
   in (rows, frameWork <> probeWork <> branchWork)

enumerateCandidates ::
     RelationalIndex
  -> Premises scope shape
  -> Projection mode scope shape row
  -> [SomeBound scope]
  -> Bound scope kind
  -> [Domain kind]
  -> [NodeId kind]
  -> Bindings scope
  -> (Builder row, EvaluationWork)
enumerateCandidates _ _ _ _ _ _ [] _ = (emptyBuilder, mempty)
enumerateCandidates index premises projection rest bound guards (value:values) bindings =
  let visit = mempty {workDomainValuesVisited = 1}
      (admitted, membership) = admittedByAll value guards
      (remainingRows, remainingWork) =
        enumerateCandidates
          index
          premises
          projection
          rest
          bound
          guards
          values
          bindings
   in if not admitted
        then (remainingRows, visit <> membership <> remainingWork)
        else let attempt = mempty {workBindingAttempts = 1}
                 (nestedRows, nestedWork) =
                   enumerateVariables
                     index
                     premises
                     projection
                     rest
                     (bindValue bound value bindings)
              in ( appendBuilder nestedRows remainingRows
                 , visit <> membership <> attempt <> nestedWork <> remainingWork)

candidateDomains ::
     RelationalIndex
  -> Bound scope kind
  -> [SomePremise scope]
  -> Bindings scope
  -> (NonEmpty (Domain kind), EvaluationWork)
candidateDomains index bound premises bindings =
  let (restricted, work) = premiseDomains index bound premises bindings
   in (boundDomain bound NonEmpty.:| restricted, work)

premiseDomains ::
     RelationalIndex
  -> Bound scope kind
  -> [SomePremise scope]
  -> Bindings scope
  -> ([Domain kind], EvaluationWork)
premiseDomains _ _ [] _ = ([], mempty)
premiseDomains index bound (SomePremise premise:rest) bindings =
  let scan = mempty {workConstraintScans = 1}
      (candidate, candidateWork) = premiseDomain index bound premise bindings
      (remaining, remainingWork) = premiseDomains index bound rest bindings
   in case candidate of
        Nothing -> (remaining, scan <> candidateWork <> remainingWork)
        Just domain ->
          (domain : remaining, scan <> candidateWork <> remainingWork)

premiseDomain ::
     RelationalIndex
  -> Bound scope kind
  -> Premise (PremiseKey scope token) from to
  -> Bindings scope
  -> (Maybe (Domain kind), EvaluationWork)
premiseDomain index bound premise bindings =
  case sameBound (premiseFrom premise) (premiseTo premise) of
    Just Refl ->
      case sameBound bound (premiseFrom premise) of
        Just Refl -> (Just (premiseLoopDomain premise index), indexProbe)
        Nothing -> (Nothing, mempty)
    Nothing ->
      case sameBound bound (premiseFrom premise) of
        Just Refl ->
          let domain =
                case lookupValue (premiseTo premise) bindings of
                  Nothing -> premiseSourceDomain premise index
                  Just target -> premisePredecessors premise target index
           in (Just domain, indexProbe)
        Nothing ->
          case sameBound bound (premiseTo premise) of
            Just Refl ->
              let domain =
                    case lookupValue (premiseFrom premise) bindings of
                      Nothing -> premiseTargetDomain premise index
                      Just source -> premiseSuccessors premise source index
               in (Just domain, indexProbe)
            Nothing -> (Nothing, mempty)
  where
    indexProbe = mempty {workIndexDomainProbes = 1}

selectSmallest :: NonEmpty (Domain kind) -> (Domain kind, [Domain kind], Int)
selectSmallest (first NonEmpty.:| rest) = choose first [] rest
  where
    choose selected guards [] = (selected, reverse guards, 0)
    choose selected guards (candidate:candidates)
      | domainSize candidate < domainSize selected =
        let (smallest, remaining, comparisons) =
              choose candidate (selected : guards) candidates
         in (smallest, remaining, comparisons + 1)
      | otherwise =
        let (smallest, remaining, comparisons) =
              choose selected (candidate : guards) candidates
         in (smallest, remaining, comparisons + 1)

admittedByAll :: NodeId kind -> [Domain kind] -> (Bool, EvaluationWork)
admittedByAll _ [] = (True, mempty)
admittedByAll value (domain:rest) =
  let probe = mempty {workIntersectionMembershipProbes = 1}
   in if domainMember value domain
        then let (admitted, work) = admittedByAll value rest
              in (admitted, probe <> work)
        else (False, probe)

existsOccurrences ::
     RelationalIndex
  -> [SomePremise scope]
  -> Bindings scope
  -> (Bool, EvaluationWork)
existsOccurrences _ [] _ = (True, mempty)
existsOccurrences index (SomePremise premise:rest) bindings =
  let scan = mempty {workConstraintScans = 1}
      probe = mempty {workEdgeBucketProbes = 1}
   in case boundPremiseOccurrences index premise bindings of
        [] -> (False, scan <> probe)
        _:_ ->
          let readOne = mempty {workExactOccurrenceReads = 1}
              (found, remaining) = existsOccurrences index rest bindings
           in (found, scan <> probe <> readOne <> remaining)

data OccurrenceDomains scope shape where
  OccurrenceDomainNil :: OccurrenceDomains scope 'EmptyPremises
  OccurrenceDomainSnoc
    :: OccurrenceDomains scope shape
    -> Premise (PremiseKey scope token) from to
    -> [EdgeOccurrence from to]
    -> OccurrenceDomains scope ('SnocPremise shape token from to)

enumerateOccurrences ::
     RelationalIndex
  -> Premises scope shape
  -> Projection mode scope shape row
  -> Bindings scope
  -> (Builder row, EvaluationWork)
enumerateOccurrences index premises projection bindings =
  let (domains, probeWork) = occurrenceDomains index premises bindings
      (rows, occurrenceWork) =
        enumerateMatched
          domains
          (\matched ->
             ( singletonBuilder (applyProjection projection matched)
             , mempty {workResultsEmitted = 1}))
   in (rows, probeWork <> occurrenceWork)

occurrenceDomains ::
     RelationalIndex
  -> Premises scope shape
  -> Bindings scope
  -> (OccurrenceDomains scope shape, EvaluationWork)
occurrenceDomains _ PremiseNil _ = (OccurrenceDomainNil, mempty)
occurrenceDomains index (PremiseSnoc premises premise) bindings =
  let (prefix, prefixWork) = occurrenceDomains index premises bindings
      scan = mempty {workConstraintScans = 1}
      probe = mempty {workEdgeBucketProbes = 1}
      occurrences = boundPremiseOccurrences index premise bindings
   in ( OccurrenceDomainSnoc prefix premise occurrences
      , prefixWork <> scan <> probe)

boundPremiseOccurrences ::
     RelationalIndex
  -> Premise (PremiseKey scope token) from to
  -> Bindings scope
  -> [EdgeOccurrence from to]
boundPremiseOccurrences index premise bindings =
  case ( lookupValue (premiseFrom premise) bindings
       , lookupValue (premiseTo premise) bindings) of
    (Just source, Just target) ->
      exactPremiseOccurrences premise source target index
    _ -> []

enumerateMatched ::
     OccurrenceDomains scope shape
  -> (MatchedPremises scope shape -> (Builder row, EvaluationWork))
  -> (Builder row, EvaluationWork)
enumerateMatched OccurrenceDomainNil emit = emit emptyMatchedPremises
enumerateMatched (OccurrenceDomainSnoc prefix premise occurrences) emit =
  enumerateMatched
    prefix
    (\matched -> selectOccurrences premise occurrences matched emit)

selectOccurrences ::
     Premise (PremiseKey scope token) from to
  -> [EdgeOccurrence from to]
  -> MatchedPremises scope shape
  -> (MatchedPremises scope ('SnocPremise shape token from to) -> ( Builder row
                                                                  , EvaluationWork))
  -> (Builder row, EvaluationWork)
selectOccurrences _ [] _ _ = (emptyBuilder, mempty)
selectOccurrences premise (occurrence:occurrences) matched emit =
  let readOne = mempty {workExactOccurrenceReads = 1}
      (nestedRows, nestedWork) =
        emit (appendMatchedPremise matched premise occurrence)
      (remainingRows, remainingWork) =
        selectOccurrences premise occurrences matched emit
   in ( appendBuilder nestedRows remainingRows
      , readOne <> nestedWork <> remainingWork)
