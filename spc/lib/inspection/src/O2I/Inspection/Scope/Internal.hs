{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Internal semantic-scope closure implementation.
module O2I.Inspection.Scope.Internal
  ( ClosedScopeSummary(..)
  , ScopeDefect(..)
  , ScopeIssue(..)
  , ScopeResult(..)
  , SemanticallyClosedScope(..)
  , scopeDefectSpec
  , closeScope
  ) where

import Data.List (foldl')
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import qualified Data.Sequence as Sequence
import Data.Sequence (Seq((:<|)), (|>))
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I
  ( buildMacroFactIndex
  , macroClaims
  , macroDependencyEdge
  , macroScopeDependencies
  )
import O2I.Inspection.Diagnostic.Internal
import O2I.Inspection.Profile.Internal
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Direct and transitively closed occurrence cardinalities.
data ClosedScopeSummary = ClosedScopeSummary
  { directOccurrenceCount :: Natural
  , closedOccurrenceCount :: Natural
  } deriving (Eq, Show)

-- | Inspection-owned scope failures.
data ScopeDefect
  = EmptyO2IScope
  | UnresolvedReachedReference ReferenceOccurrence
  | AmbiguousReachedReference ReferenceOccurrence (NonEmpty SourceLocation)
  deriving (Eq, Show)

-- | Reached adapter defects are normalized before their existential type is
-- discarded; Inspection defects retain their closed constructor.
data ScopeIssue
  = ProfileIssue Diagnostic
  | InspectionScopeIssue (Located ScopeDefect)
  deriving (Eq, Show)

-- | Total scope-closure result.
data ScopeResult
  = ScopeRejected ClosedScopeSummary (NonEmpty ScopeIssue)
  | ScopeClosed SemanticallyClosedScope

-- | Opaque witness that the selected View and persisted profile index reached
-- a least fixed point without projection defects.
data SemanticallyClosedScope = SemanticallyClosedScope
  { closedScopeView :: ResolvedView
  , closedScopeSummary :: ClosedScopeSummary
  , closedScopeFacts :: [IndexedProfileFact]
  , closedScopeOccurrences :: Set OccurrenceId
  , closedScopeReasons :: Map OccurrenceId [InclusionReason]
  }

-- | Total stable diagnostic projection for every Inspection scope defect.
scopeDefectSpec :: ScopeDefect -> DiagnosticSpec
scopeDefectSpec EmptyO2IScope =
  modelSpec
    "o2i.inspection.scope.empty"
    "The selected View contains no reachable O2I occurrence."
    []
scopeDefectSpec (UnresolvedReachedReference reference) =
  modelSpec
    "o2i.inspection.scope.reference-unresolved"
    "A reached persisted reference resolves to no occurrence."
    [referenceSubject reference]
scopeDefectSpec (AmbiguousReachedReference reference locations) =
  modelSpec
    "o2i.inspection.scope.reference-ambiguous"
    "A reached persisted reference resolves to multiple occurrences."
    [ referenceSubject reference
    , DiagnosticSubject
        "match-count"
        (Text.pack (show (NonEmpty.length locations)))
    ]

-- | Compute the deterministic least fixed point and normalize only reached
-- profile defects.
closeScope :: ProfileIndex -> ScopeResult
closeScope (ProfileIndex contract view projection) =
  case NonEmpty.nonEmpty issues of
    Just failures -> ScopeRejected summary failures
    Nothing ->
      ScopeClosed
        SemanticallyClosedScope
          { closedScopeView = view
          , closedScopeSummary = summary
          , closedScopeFacts = facts
          , closedScopeOccurrences = reached
          , closedScopeReasons = reasons
          }
  where
    persistedFacts = resolvedProjectedFacts projection
    macroIndex =
      buildMacroFactIndex
        [(occurrence, node) | IndexedNode occurrence node _ <- persistedFacts]
        [(occurrence, edge) | IndexedEdge occurrence edge _ <- persistedFacts]
    macroDependencies =
      [ indexMacroDependency conclusion (macroDependencyEdge dependency)
      | (conclusion, claim) <- macroClaims macroIndex
      , dependency <- macroScopeDependencies macroIndex claim
      ]
    facts = persistedFacts ++ macroDependencies
    presentations =
      [(presentation, target) | IndexedSeed presentation target <- facts]
    seeds =
      concatMap
        (\(presentation, target) -> [presentation, target])
        presentations
    occurrenceLocations = locationsByOccurrence facts
    closure = closeOccurrences facts occurrenceLocations seeds
    reached = closureReached closure
    reasons = closureReasons closure
    summary =
      ClosedScopeSummary
        { directOccurrenceCount = fromIntegral (length presentations)
        , closedOccurrenceCount = fromIntegral (Set.size reached)
        }
    emptyIssues =
      [ InspectionScopeIssue (Located (resolvedViewLocation view) EmptyO2IScope)
      | Set.null reached
      ]
    profileIssues =
      [ ProfileIssue
        (diagnosticFromLocated
           ProfileStage
           (profileDefectSpec contract)
           (deferredDefect deferred))
      | deferred <- resolvedDeferredDefects projection
      , reachedDeferred reached deferred
      ]
    issues = emptyIssues ++ closureIssues closure ++ profileIssues

data Closure = Closure
  { closureReached :: Set OccurrenceId
  , closureReasons :: Map OccurrenceId [InclusionReason]
  , closureIssues :: [ScopeIssue]
  }

closeOccurrences ::
     [IndexedProfileFact]
  -> Map OccurrenceId SourceLocation
  -> [OccurrenceId]
  -> Closure
closeOccurrences facts locations seeds =
  go initialReached (Sequence.fromList uniqueSeeds) initialReasons []
  where
    uniqueSeeds = stableUnique seeds
    initialReached = Set.fromList uniqueSeeds
    initialReasons =
      Map.fromListWith
        appendReason
        [(seed, [DirectPresentation]) | seed <- seeds]
    dependencies =
      Map.fromListWith
        (flip (++))
        [ (source, [(target, reason)])
        | IndexedDependency source target reason <- facts
        ]
    references =
      Map.fromListWith
        (flip (++))
        [ (source, [(reference, matches, reason)])
        | IndexedReference source reference matches reason <- facts
        ]
    go reached Sequence.Empty reasons issues = Closure reached reasons issues
    go reached (current :<| queue) reasons issues =
      let directTargets = Map.findWithDefault [] current dependencies
          referenceTargets = Map.findWithDefault [] current references
          (reachedAfterDirect, queueAfterDirect, reasonsAfterDirect) =
            foldl' addDependency (reached, queue, reasons) directTargets
          (reachedAfterReferences, queueAfterReferences, reasonsAfterReferences, newIssues) =
            foldl'
              (addReference locations)
              (reachedAfterDirect, queueAfterDirect, reasonsAfterDirect, [])
              referenceTargets
       in go
            reachedAfterReferences
            queueAfterReferences
            reasonsAfterReferences
            (issues ++ newIssues)

addDependency ::
     (Set OccurrenceId, Seq OccurrenceId, Map OccurrenceId [InclusionReason])
  -> (OccurrenceId, InclusionReason)
  -> (Set OccurrenceId, Seq OccurrenceId, Map OccurrenceId [InclusionReason])
addDependency (reached, queue, reasons) (target, reason) =
  ( Set.insert target reached
  , if Set.member target reached
      then queue
      else queue |> target
  , Map.insertWith appendReason target [reason] reasons)

addReference ::
     Map OccurrenceId SourceLocation
  -> ( Set OccurrenceId
     , Seq OccurrenceId
     , Map OccurrenceId [InclusionReason]
     , [ScopeIssue])
  -> (ReferenceOccurrence, [OccurrenceId], InclusionReason)
  -> ( Set OccurrenceId
     , Seq OccurrenceId
     , Map OccurrenceId [InclusionReason]
     , [ScopeIssue])
addReference locations state (reference, matches, reason) =
  case matches of
    [] ->
      addIssue
        (referenceLocation reference)
        (UnresolvedReachedReference reference)
        state
    [target] ->
      let (reached, queue, reasons, issues) = state
          (nextReached, nextQueue, nextReasons) =
            addDependency (reached, queue, reasons) (target, reason)
       in (nextReached, nextQueue, nextReasons, issues)
    _:_:_ ->
      let matchLocations = mapMaybe (`Map.lookup` locations) matches
          retainedLocations =
            case NonEmpty.nonEmpty matchLocations of
              Just nonEmptyLocations -> nonEmptyLocations
              Nothing -> NonEmpty.singleton (referenceLocation reference)
       in addIssue
            (referenceLocation reference)
            (AmbiguousReachedReference reference retainedLocations)
            state

addIssue ::
     SourceLocation
  -> ScopeDefect
  -> ( Set OccurrenceId
     , Seq OccurrenceId
     , Map OccurrenceId [InclusionReason]
     , [ScopeIssue])
  -> ( Set OccurrenceId
     , Seq OccurrenceId
     , Map OccurrenceId [InclusionReason]
     , [ScopeIssue])
addIssue location defect (reached, queue, reasons, issues) =
  ( reached
  , queue
  , reasons
  , issues ++ [InspectionScopeIssue (Located location defect)])

locationsByOccurrence :: [IndexedProfileFact] -> Map OccurrenceId SourceLocation
locationsByOccurrence = Map.fromList . mapMaybe factLocation
  where
    factLocation (IndexedOccurrence occurrence location) =
      Just (occurrence, location)
    factLocation (IndexedNode occurrence _ location) =
      Just (occurrence, location)
    factLocation (IndexedEdge occurrence _ location) =
      Just (occurrence, location)
    factLocation _ = Nothing

reachedDeferred :: Set OccurrenceId -> DeferredProfileDefect defect -> Bool
reachedDeferred reached deferred =
  case defectApplicability deferred of
    GlobalProfileDefect -> True
    ReachedProfileDefect occurrences ->
      any (`Set.member` reached) (NonEmpty.toList occurrences)

appendReason :: [InclusionReason] -> [InclusionReason] -> [InclusionReason]
appendReason new old = old ++ filter (`notElem` old) new

stableUnique :: Ord value => [value] -> [value]
stableUnique = go Set.empty
  where
    go _ [] = []
    go seen (value:values)
      | Set.member value seen = go seen values
      | otherwise = value : go (Set.insert value seen) values

referenceSubject :: ReferenceOccurrence -> DiagnosticSubject
referenceSubject reference =
  DiagnosticSubject
    "reference"
    (occurrenceIdText (referenceOccurrenceId reference))

modelSpec :: Text.Text -> Text.Text -> [DiagnosticSubject] -> DiagnosticSpec
modelSpec code message subjects =
  DiagnosticSpec
    { specCode = DiagnosticCode code
    , specSeverity = ErrorSeverity
    , specDisposition = ModelFinding
    , specMessage = message
    , specSubjects = subjects
    , specData = Map.empty
    }
