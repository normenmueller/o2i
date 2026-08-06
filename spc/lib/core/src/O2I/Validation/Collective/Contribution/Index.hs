{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | One-time indexes used by collective-contribution validation.
module O2I.Validation.Collective.Contribution.Index
  ( PreparedCollectiveContribution
  , ContributionOccurrence(..)
  , ContributionEvidenceResolution(..)
  , prepareCollectiveContribution
  , preparedContributionStructure
  , lookupContributionEvidence
  , lookupContributionNode
  , lookupContributionOccurrence
  , contributionFormulationContains
  , collectiveContributionPreparationWork
  ) where

import Data.List (foldl')
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Collective.Contribution.Types
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.Relational.Index
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure.Internal

data PreparedCollectiveContribution = PreparedCollectiveContribution
  { storedContributionStructure :: StructuralAssessment
  , storedContributionRelations :: RelationalIndex
  , storedCandidateEdges :: Set RawEdge
  , storedContributionKeyResults :: Map RawNodeId (Set RawNodeId)
  , storedContributionActions :: Map RawNodeId (Set RawNodeId)
  , storedContributionEvidence :: Map
      CollectiveContributionEvidenceRef
      ContributionEvidenceBucket
  , storedContributionPreparationWork :: CollectiveContributionPreparationWork
  }

-- | Resolution of one exact raw occurrence against prepared model indexes.
data ContributionOccurrence
  = AssertedContributionOccurrence !Int RawEdge
  | CandidateContributionOccurrence RawEdge
  | MissingContributionOccurrence RawEdge
  deriving (Eq, Show)

data ContributionEvidenceBucket
  = UniqueContributionEvidenceBucket !RawCollectiveContributionEvidence
  | AmbiguousContributionEvidenceBucket

-- | Exact resolution of one evidence reference against the prepared index.
data ContributionEvidenceResolution
  = MissingContributionEvidence
  | UniqueContributionEvidence !RawCollectiveContributionEvidence
  | AmbiguousContributionEvidence
  deriving (Eq, Show)

-- | Prepare all model-wide indexes exactly once.
prepareCollectiveContribution ::
     StructuralAssessment
  -> ContextSemantics
  -> PreparedMacroEvidence
  -> Set RawEdge
  -> [RawCollectiveContributionEvidence]
  -> PreparedCollectiveContribution
prepareCollectiveContribution structure semantic macro candidateEdges evidence =
  PreparedCollectiveContribution
    { storedContributionStructure = structure
    , storedContributionRelations = preparedRelationalIndex macro
    , storedCandidateEdges = candidateEdges
    , storedContributionKeyResults = keyResults
    , storedContributionActions = actions
    , storedContributionEvidence = evidenceIndex
    , storedContributionPreparationWork =
        CollectiveContributionPreparationWork
          { contributionEvidenceBundlesRead = evidenceReads
          , contributionEvidenceIndexInsertions = evidenceInsertions
          , contributionStrategyFormulationsRead = formulationReads
          , contributionFormulationMemberInsertions = formulationMembers
          }
    }
  where
    formulations = Map.toList (contextStrategyFormulations semantic)
    (keyResults, actions, formulationReads, formulationMembers) =
      foldl' insertFormulation (Map.empty, Map.empty, 0, 0) formulations
    insertFormulation (keyResultIndex, actionIndex, sourceReads, membersRead) (strategy, formulation) =
      ( Map.insert strategy keyResultSet keyResultIndex
      , Map.insert strategy actionSet actionIndex
      , sourceReads + 1
      , membersRead + Set.size keyResultSet + Set.size actionSet)
      where
        raw = strategyFormulationData formulation
        keyResultSet =
          Set.fromList (NonEmpty.toList (rawFormulationKeyResults raw))
        actionSet = Set.fromList (NonEmpty.toList (rawFormulationActions raw))
    (evidenceIndex, evidenceReads, evidenceInsertions) =
      foldl' insertEvidence (Map.empty, 0, 0) evidence
    insertEvidence (index, sourceReads, insertions) value =
      ( Map.insertWith
          combineEvidence
          (rawContributionEvidenceRef value)
          (UniqueContributionEvidenceBucket value)
          index
      , sourceReads + 1
      , insertions + 1)
    combineEvidence _new _existing = AmbiguousContributionEvidenceBucket

preparedContributionStructure ::
     PreparedCollectiveContribution -> StructuralAssessment
preparedContributionStructure = storedContributionStructure

lookupContributionEvidence ::
     CollectiveContributionEvidenceRef
  -> PreparedCollectiveContribution
  -> ContributionEvidenceResolution
lookupContributionEvidence reference prepared =
  case Map.lookup reference (storedContributionEvidence prepared) of
    Nothing -> MissingContributionEvidence
    Just (UniqueContributionEvidenceBucket evidence) ->
      UniqueContributionEvidence evidence
    Just AmbiguousContributionEvidenceBucket -> AmbiguousContributionEvidence

lookupContributionNode ::
     RawNodeId -> PreparedCollectiveContribution -> Maybe SomeNode
lookupContributionNode identifier = lookupNodeById
  where
    lookupNodeById prepared =
      lookupNode
        (structuralAssessmentGraph (storedContributionStructure prepared))
        identifier

lookupContributionOccurrence ::
     PrimitiveContributionMode
  -> RawEdge
  -> PreparedCollectiveContribution
  -> ContributionOccurrence
lookupContributionOccurrence mode edge prepared
  | [ordinal] <- assertedOrdinals = AssertedContributionOccurrence ordinal edge
  | Set.member edge (storedCandidateEdges prepared) =
    CandidateContributionOccurrence edge
  | otherwise = MissingContributionOccurrence edge
  where
    assertedOrdinals =
      case mode of
        KeyResultContributionGraph ->
          exactRelationOccurrenceOrdinals
            contributesStrategyKeyResultToKeyResult
            (mkNodeId (rawEdgeFrom edge))
            (mkNodeId (rawEdgeTo edge))
            (storedContributionRelations prepared)
        ActionContributionGraph ->
          exactRelationOccurrenceOrdinals
            contributesStrategyActionToAction
            (mkNodeId (rawEdgeFrom edge))
            (mkNodeId (rawEdgeTo edge))
            (storedContributionRelations prepared)

-- | Test one Primitive against its owner's prepared Strategy formulation.
contributionFormulationContains ::
     PrimitiveContributionMode
  -> RawNodeId
  -> RawNodeId
  -> PreparedCollectiveContribution
  -> Bool
contributionFormulationContains mode owner identifier prepared =
  maybe False (Set.member identifier) (Map.lookup owner formulations)
  where
    formulations =
      case mode of
        KeyResultContributionGraph -> storedContributionKeyResults prepared
        ActionContributionGraph -> storedContributionActions prepared

collectiveContributionPreparationWork ::
     PreparedCollectiveContribution -> CollectiveContributionPreparationWork
collectiveContributionPreparationWork = storedContributionPreparationWork
