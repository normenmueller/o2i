{-# LANGUAGE DataKinds #-}

-- | Typed vocabulary of collective Strategy contribution evidence.
module O2I.Validation.Collective.Contribution.Types
  ( CollectiveContributionEvidenceRef(..)
  , JointContributionRationaleRef(..)
  , RawJointContributionRationale(..)
  , RawBoundContributionGraph(..)
  , RawContributionEvidenceGraph(..)
  , RawCollectiveContributionEvidence(..)
  , RawCollectiveStrategyContribution(..)
  , PrimitiveContributionMode(..)
  , CollectiveStrategyContributionIssue(..)
  , CollectiveStrategyContributionError(..)
  , CollectiveContributionPreparationWork(..)
  , CollectiveContributionValidationWork(..)
  ) where

import Data.Text (Text)
import O2I.Graph.Raw (RawEdge)
import O2I.Language.Element (RawNodeId)
import O2I.Validation.Collective.FanIn
  ( CollectiveFanInStructuralError
  , CollectiveFanInStructuralWork
  )
import O2I.Validation.Collective.Types

-- | Stable reference to one collective-contribution evidence bundle.
newtype CollectiveContributionEvidenceRef = CollectiveContributionEvidenceRef
  { collectiveContributionEvidenceRefText :: Text
  } deriving (Eq, Ord, Show)

-- | Stable identity of one joint mechanism or interaction rationale.
newtype JointContributionRationaleRef = JointContributionRationaleRef
  { jointContributionRationaleRefText :: Text
  } deriving (Eq, Ord, Show)

-- | One source-near joint mechanism with explicit provenance.
data RawJointContributionRationale = RawJointContributionRationale
  { rawJointRationaleRef :: JointContributionRationaleRef
  , rawJointRationaleText :: Text
  , rawJointRationaleProvenance :: Text
  } deriving (Eq, Show)

-- | Raw homogeneous Primitive graph bound as one provenance envelope.
--
-- Every contained node and edge occurrence inherits the exact proposition,
-- rationale, and provenance binding of this envelope.
data RawBoundContributionGraph = RawBoundContributionGraph
  { rawContributionGraphClaim :: ClaimId
  , rawContributionGraphRationale :: JointContributionRationaleRef
  , rawContributionGraphProvenance :: Text
  , rawContributionGraphNodes :: [RawNodeId]
  , rawContributionGraphEdges :: [RawEdge]
  } deriving (Eq, Show)

-- | Closed raw mode selection for Primitive contribution evidence.
data RawContributionEvidenceGraph
  = RawKeyResultContributionGraph RawBoundContributionGraph
  | RawActionContributionGraph RawBoundContributionGraph
  deriving (Eq, Show)

-- | Family-owned evidence exactly bound to one collective proposition.
data RawCollectiveContributionEvidence = RawCollectiveContributionEvidence
  { rawContributionEvidenceRef :: CollectiveContributionEvidenceRef
  , rawContributionEvidenceClaim :: ClaimId
  , rawContributionEvidenceParticipants :: [RawNodeId]
  , rawContributionEvidenceTarget :: RawNodeId
  , rawJointContributionRationales :: [RawJointContributionRationale]
  , rawContributionPrimitiveGraph :: Maybe RawContributionEvidenceGraph
  } deriving (Eq, Show)

-- | Unchecked collective Strategy-contribution proposition.
--
-- Commitment belongs exclusively to the enclosing @Claim@.
data RawCollectiveStrategyContribution = RawCollectiveStrategyContribution
  { rawContributionId :: ClaimId
  , rawContributionParticipants :: [RawNodeId]
  , rawContributionTarget :: RawNodeId
  , rawContributionCompleteness :: ParticipantCompleteness
  , rawContributionEvidence :: CollectiveContributionEvidenceRef
  } deriving (Eq, Show)

-- | Closed validated Primitive-evidence mode.
data PrimitiveContributionMode
  = KeyResultContributionGraph
  | ActionContributionGraph
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Diagnostic family-evidence defect of one structurally valid proposition.
data CollectiveStrategyContributionIssue
  = CollectiveContributionSemanticEvaluationBlocked
    -- ^ Context semantics is unavailable; family evidence was not evaluated.
  | CollectiveContributionEvidenceNotFound CollectiveContributionEvidenceRef
  | CollectiveContributionEvidenceAmbiguous CollectiveContributionEvidenceRef
  | CollectiveContributionEvidenceClaimMismatch ClaimId ClaimId
  | CollectiveContributionParticipantsMismatch
  | CollectiveContributionTargetMismatch RawNodeId RawNodeId
  | MissingJointContributionRationale
  | BlankJointContributionRationaleReference
  | DuplicateJointContributionRationaleReference JointContributionRationaleRef
  | BlankJointContributionRationale JointContributionRationaleRef
  | BlankJointContributionRationaleProvenance JointContributionRationaleRef
  | AssertedCollectiveContributionMissingPrimitiveGraph
  | ContributionGraphClaimMismatch ClaimId ClaimId
  | ContributionGraphRationaleNotFound JointContributionRationaleRef
  | ContributionGraphProvenanceMismatch JointContributionRationaleRef
  | EmptyContributionPrimitiveGraph
  | DuplicateContributionGraphNode RawNodeId
  | DuplicateContributionGraphEdge RawEdge
  | UnknownContributionGraphNode RawNodeId
  | CandidateContributionGraphNode RawNodeId
  | InvalidContributionGraphNodeKind PrimitiveContributionMode RawNodeId
  | InvalidContributionGraphNodeOwner RawNodeId RawNodeId
  | ContributionGraphNodeOutsideFormulation RawNodeId RawNodeId
  | ContributionGraphMissingParticipant RawNodeId
  | ContributionGraphMissingTarget RawNodeId
  | ContributionGraphEdgeModeMismatch PrimitiveContributionMode RawEdge
  | ContributionGraphEdgeEndpointNotListed RawEdge RawNodeId
  | CandidateContributionGraphEdge RawEdge
  | ContributionGraphEdgeOccurrenceNotFound RawEdge
  | DisconnectedContributionPrimitiveGraph
  | ContributionGraphParticipantCannotReachTarget RawNodeId
  deriving (Eq, Show)

-- | Fatal structural defect or Asserted semantic deficiency.
data CollectiveStrategyContributionError
  = CollectiveContributionStructuralError CollectiveFanInStructuralError
  | DuplicateCollectiveContributionClaimId ClaimId
  | AssertedCollectiveContributionIssue
      ClaimId
      CollectiveStrategyContributionIssue
  deriving (Eq, Show)

-- | Exact one-time preparation work for contribution validation.
data CollectiveContributionPreparationWork = CollectiveContributionPreparationWork
  { contributionCandidateOccurrencesRead :: !Int
  , contributionCandidateIndexInsertions :: !Int
  , contributionEvidenceBundlesRead :: !Int
  , contributionEvidenceIndexInsertions :: !Int
  , contributionStrategyFormulationsRead :: !Int
  , contributionFormulationMemberInsertions :: !Int
  } deriving (Eq, Show)

instance Semigroup CollectiveContributionPreparationWork where
  left <> right =
    CollectiveContributionPreparationWork
      { contributionCandidateOccurrencesRead =
          contributionCandidateOccurrencesRead left
            + contributionCandidateOccurrencesRead right
      , contributionCandidateIndexInsertions =
          contributionCandidateIndexInsertions left
            + contributionCandidateIndexInsertions right
      , contributionEvidenceBundlesRead =
          contributionEvidenceBundlesRead left
            + contributionEvidenceBundlesRead right
      , contributionEvidenceIndexInsertions =
          contributionEvidenceIndexInsertions left
            + contributionEvidenceIndexInsertions right
      , contributionStrategyFormulationsRead =
          contributionStrategyFormulationsRead left
            + contributionStrategyFormulationsRead right
      , contributionFormulationMemberInsertions =
          contributionFormulationMemberInsertions left
            + contributionFormulationMemberInsertions right
      }

instance Monoid CollectiveContributionPreparationWork where
  mempty = CollectiveContributionPreparationWork 0 0 0 0 0 0

-- | Exact proposition-local work performed by contribution validation.
data CollectiveContributionValidationWork = CollectiveContributionValidationWork
  { contributionStructuralWork :: !CollectiveFanInStructuralWork
  , contributionEvidenceBucketProbes :: !Int
  , contributionEvidencePayloadReads :: !Int
  , contributionRationalesRead :: !Int
  , contributionNodeLookups :: !Int
  , contributionFormulationLookups :: !Int
  , contributionEdgeOccurrenceLookups :: !Int
  , contributionAdjacencyInsertions :: !Int
  , contributionTraversalNodeVisits :: !Int
  , contributionTraversalEdgeVisits :: !Int
  } deriving (Eq, Show)

instance Semigroup CollectiveContributionValidationWork where
  left <> right =
    CollectiveContributionValidationWork
      { contributionStructuralWork =
          contributionStructuralWork left <> contributionStructuralWork right
      , contributionEvidenceBucketProbes =
          contributionEvidenceBucketProbes left
            + contributionEvidenceBucketProbes right
      , contributionEvidencePayloadReads =
          contributionEvidencePayloadReads left
            + contributionEvidencePayloadReads right
      , contributionRationalesRead =
          contributionRationalesRead left + contributionRationalesRead right
      , contributionNodeLookups =
          contributionNodeLookups left + contributionNodeLookups right
      , contributionFormulationLookups =
          contributionFormulationLookups left
            + contributionFormulationLookups right
      , contributionEdgeOccurrenceLookups =
          contributionEdgeOccurrenceLookups left
            + contributionEdgeOccurrenceLookups right
      , contributionAdjacencyInsertions =
          contributionAdjacencyInsertions left
            + contributionAdjacencyInsertions right
      , contributionTraversalNodeVisits =
          contributionTraversalNodeVisits left
            + contributionTraversalNodeVisits right
      , contributionTraversalEdgeVisits =
          contributionTraversalEdgeVisits left
            + contributionTraversalEdgeVisits right
      }

instance Monoid CollectiveContributionValidationWork where
  mempty = CollectiveContributionValidationWork mempty 0 0 0 0 0 0 0 0 0
