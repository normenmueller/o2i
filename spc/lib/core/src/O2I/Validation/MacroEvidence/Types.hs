-- | Private result and work contracts for exact macro evidence.
module O2I.Validation.MacroEvidence.Types
  ( MacroPremiseOccurrence(..)
  , MacroEvidenceWitness(..)
  , validatedWitnessPremises
  , sameWitnessOccurrences
  , CollectiveMacroEvidence
  , collectiveMacroEvidence
  , collectiveContributionWitnesses
  , MacroEvidenceError(..)
  , MacroPreparationWork(..)
  , MacroEvidenceWork(..)
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I.Graph.Raw
import O2I.Language.Element (RawNodeId)
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index

-- | Missing Primitive substantiation for one asserted Context relation.
newtype MacroEvidenceError =
  MissingMacroEvidence RawEdge
  deriving (Eq, Show)

-- | One exact persisted premise occurrence retained by a macro witness.
data MacroPremiseOccurrence = MacroPremiseOccurrence
  { macroPremiseOccurrenceOrdinal :: !Int
  , macroPremiseOccurrenceEdge :: !RawEdge
  } deriving (Eq, Show)

-- | Opaque exact substantiation of one macrorelation through persisted edges.
newtype MacroEvidenceWitness = MacroEvidenceWitness
  { validatedWitnessOccurrences :: NonEmpty.NonEmpty MacroPremiseOccurrence
  }

instance Eq MacroEvidenceWitness where
  left == right =
    validatedWitnessPremises left == validatedWitnessPremises right

instance Show MacroEvidenceWitness where
  showsPrec precedence witness =
    showParen
      (precedence > 10)
      (showString "MacroEvidenceWitness {validatedWitnessPremises = "
         . shows (validatedWitnessPremises witness)
         . showString "}")

-- | Project exact premise occurrences to their stable public edge values.
validatedWitnessPremises :: MacroEvidenceWitness -> NonEmpty.NonEmpty RawEdge
validatedWitnessPremises =
  fmap macroPremiseOccurrenceEdge . validatedWitnessOccurrences

-- | Compare the exact persisted premise occurrences retained internally.
sameWitnessOccurrences :: MacroEvidenceWitness -> MacroEvidenceWitness -> Bool
sameWitnessOccurrences left right =
  validatedWitnessOccurrences left == validatedWitnessOccurrences right

-- | Narrow contribution-evidence interface consumed by Collective semantics.
--
-- The interface exposes neither prepared indices nor generic macro queries.
newtype CollectiveMacroEvidence =
  CollectiveMacroEvidence (RawNodeId -> RawNodeId -> [MacroEvidenceWitness])

-- | Construct the one contribution lookup required by Collective validation.
collectiveMacroEvidence ::
     (RawNodeId -> RawNodeId -> [MacroEvidenceWitness])
  -> CollectiveMacroEvidence
collectiveMacroEvidence = CollectiveMacroEvidence

-- | Enumerate exact evidence for one contributor and target Strategy.
collectiveContributionWitnesses ::
     CollectiveMacroEvidence -> RawNodeId -> RawNodeId -> [MacroEvidenceWitness]
collectiveContributionWitnesses (CollectiveMacroEvidence lookupEvidence) =
  lookupEvidence

-- | Exact work performed once while preparing one semantic model.
data MacroPreparationWork = MacroPreparationWork
  { preparationFactNodesRead :: !Int
  , preparationFactEdgesRead :: !Int
  , preparationRelationalIndexWork :: !IndexBuildWork
  , preparationDomainNodesRead :: !Int
  , preparationDomainEdgesRead :: !Int
  , preparationStrategyFormulationsRead :: !Int
  , preparationDomainLookups :: !Int
  , preparationDomainInsertions :: !Int
  , preparationClaimsRead :: !Int
  , preparationRegistryInsertions :: !Int
  , preparationPlansInstantiated :: !Int
  } deriving (Eq, Show)

-- | Exact work performed by one prepared macro-evidence query.
data MacroEvidenceWork = MacroEvidenceWork
  { macroPreparedClaimLookups :: !Int
  , macroAlternativesVisited :: !Int
  , macroRelationalWork :: !EvaluationWork
  , macroCanonicalInsertions :: !Int
  , macroWitnessesEmitted :: !Int
  } deriving (Eq, Show)

instance Semigroup MacroEvidenceWork where
  left <> right =
    MacroEvidenceWork
      { macroPreparedClaimLookups =
          macroPreparedClaimLookups left + macroPreparedClaimLookups right
      , macroAlternativesVisited =
          macroAlternativesVisited left + macroAlternativesVisited right
      , macroRelationalWork =
          macroRelationalWork left <> macroRelationalWork right
      , macroCanonicalInsertions =
          macroCanonicalInsertions left + macroCanonicalInsertions right
      , macroWitnessesEmitted =
          macroWitnessesEmitted left + macroWitnessesEmitted right
      }

instance Monoid MacroEvidenceWork where
  mempty = MacroEvidenceWork 0 0 mempty 0 0
