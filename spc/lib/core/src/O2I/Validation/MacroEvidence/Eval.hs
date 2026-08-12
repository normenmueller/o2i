-- | Exact execution of already prepared macro-evidence claims.
module O2I.Validation.MacroEvidence.Eval
  ( preparedMacroEvidenceWitnesses
  , preparedMacroEvidenceWitnessesWithWork
  , preparedMacroEvidenceExists
  , preparedMacroEvidenceExistsWithWork
  , canonicalizeMacroOccurrences
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Graph.Raw
import O2I.Language.Element (RawNodeId)
import O2I.Language.Macro
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.MacroEvidence.Types
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Types

-- | Canonical identity of one complete persisted occurrence selection.
newtype OccurrenceVector =
  OccurrenceVector (NonEmpty Int)
  deriving (Eq, Ord, Show)

-- | Enumerate witnesses in registry-alternative and occurrence order.
preparedMacroEvidenceWitnesses ::
     PreparedMacroEvidence -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
preparedMacroEvidenceWitnesses prepared =
  fst . preparedMacroEvidenceWitnessesWithWork prepared

-- | Enumerate exact witnesses with only the claim-local work performed.
preparedMacroEvidenceWitnessesWithWork ::
     PreparedMacroEvidence
  -> MacroClaim RawNodeId
  -> ([MacroEvidenceWitness], MacroEvidenceWork)
preparedMacroEvidenceWitnessesWithWork prepared claim =
  case preparedClaimAlternatives prepared claim of
    Nothing -> ([], mempty {macroPreparedClaimLookups = 1})
    Just alternatives ->
      let (witnesses, work) =
            enumerateAlternatives prepared (NonEmpty.toList alternatives)
       in (witnesses, work {macroPreparedClaimLookups = 1})

-- | Decide exact evidence without constructing witness rows.
preparedMacroEvidenceExists ::
     PreparedMacroEvidence -> MacroClaim RawNodeId -> Bool
preparedMacroEvidenceExists prepared =
  fst . preparedMacroEvidenceExistsWithWork prepared

-- | Decide exact evidence with truthful alternative short-circuit work.
preparedMacroEvidenceExistsWithWork ::
     PreparedMacroEvidence -> MacroClaim RawNodeId -> (Bool, MacroEvidenceWork)
preparedMacroEvidenceExistsWithWork prepared claim =
  case preparedClaimAlternatives prepared claim of
    Nothing -> (False, mempty {macroPreparedClaimLookups = 1})
    Just alternatives ->
      let (found, work) =
            existsAlternative prepared (NonEmpty.toList alternatives)
       in (found, work {macroPreparedClaimLookups = 1})

enumerateAlternatives ::
     PreparedMacroEvidence
  -> [CompiledMacroAlternative]
  -> ([MacroEvidenceWitness], MacroEvidenceWork)
enumerateAlternatives _ [] = ([], mempty)
enumerateAlternatives prepared (alternative:rest) =
  let Evaluation rows relationalWork =
        runEnumerate
          (preparedRelationalIndex prepared)
          (compiledMacroPlan alternative)
      (witnesses, canonicalInsertions, witnessesEmitted) =
        canonicalizeMacroOccurrences (map projectMacroOccurrences rows)
      currentWork =
        mempty
          { macroAlternativesVisited = 1
          , macroRelationalWork = relationalWork
          , macroCanonicalInsertions = canonicalInsertions
          , macroWitnessesEmitted = witnessesEmitted
          }
      (remaining, remainingWork) = enumerateAlternatives prepared rest
   in (witnesses ++ remaining, currentWork <> remainingWork)

existsAlternative ::
     PreparedMacroEvidence
  -> [CompiledMacroAlternative]
  -> (Bool, MacroEvidenceWork)
existsAlternative _ [] = (False, mempty)
existsAlternative prepared (alternative:rest) =
  let Evaluation found relationalWork =
        runExists
          (preparedRelationalIndex prepared)
          (compiledMacroPlan alternative)
      currentWork =
        mempty
          {macroAlternativesVisited = 1, macroRelationalWork = relationalWork}
   in if found
        then (True, currentWork)
        else let (remaining, remainingWork) = existsAlternative prepared rest
              in (remaining, currentWork <> remainingWork)

-- | Canonicalize private occurrence rows without dropping key collisions.
canonicalizeMacroOccurrences ::
     [NonEmpty MacroPremiseOccurrence] -> ([MacroEvidenceWitness], Int, Int)
canonicalizeMacroOccurrences occurrences = (witnesses, insertions, emitted)
  where
    (canonicalRows, insertions) =
      foldl' insertOccurrenceRow (Map.empty, 0) occurrences
    (witnesses, emitted) = emitCanonicalRows canonicalRows

insertOccurrenceRow ::
     (Map OccurrenceVector (NonEmpty (NonEmpty MacroPremiseOccurrence)), Int)
  -> NonEmpty MacroPremiseOccurrence
  -> (Map OccurrenceVector (NonEmpty (NonEmpty MacroPremiseOccurrence)), Int)
insertOccurrenceRow (rows, insertions) occurrences =
  ( Map.insertWith appendCollision key (occurrences NonEmpty.:| []) rows
  , insertions + 1)
  where
    key = OccurrenceVector (fmap macroPremiseOccurrenceOrdinal occurrences)
    appendCollision new existing = existing <> new

emitCanonicalRows ::
     Map OccurrenceVector (NonEmpty (NonEmpty MacroPremiseOccurrence))
  -> ([MacroEvidenceWitness], Int)
emitCanonicalRows =
  foldr emitRow ([], 0) . concatMap NonEmpty.toList . Map.elems
  where
    emitRow occurrences (witnesses, emitted) =
      (MacroEvidenceWitness occurrences : witnesses, emitted + 1)

projectMacroOccurrences ::
     NonEmpty ProjectedPremise -> NonEmpty MacroPremiseOccurrence
projectMacroOccurrences = fmap projectMacroOccurrence

projectMacroOccurrence :: ProjectedPremise -> MacroPremiseOccurrence
projectMacroOccurrence premise =
  MacroPremiseOccurrence
    { macroPremiseOccurrenceOrdinal = projectedPremiseOrdinal premise
    , macroPremiseOccurrenceEdge =
        RawEdge
          { rawEdgeFrom = projectedPremiseRawFrom premise
          , rawEdgeRelation = projectedPremiseRelationName premise
          , rawEdgeTo = projectedPremiseRawTo premise
          }
    }
