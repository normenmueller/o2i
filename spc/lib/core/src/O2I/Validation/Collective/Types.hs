-- | Shared vocabulary for typed collective Strategy fan-in propositions.
module O2I.Validation.Collective.Types
  ( ClaimId(..)
  , PropositionFamily(..)
  , allPropositionFamilies
  , ParticipantCompleteness(..)
  , CollectiveFitEvidenceRef(..)
  , RawMutualCoherenceEvidence(..)
  , RawContributorCompatibilityEvidence(..)
  , RawCollectiveFitEvidence(..)
  , CollectiveParticipantRole(..)
  , CollectiveFitDimension(..)
  , CollectiveStrategyRealizationIssue(..)
  ) where

import Data.Text (Text)
import O2I.Language.Element (RawNodeId)

-- | Stable occurrence identity of one collective proposition.
newtype ClaimId = ClaimId
  { claimIdText :: Text
  } deriving (Eq, Ord, Show)

-- | Closed registry of admitted collective fan-in families.
--
-- A new constructor requires a family-owned evidence validator. The registry
-- is deliberately not an open relation-name dispatch.
data PropositionFamily
  = CollectiveStrategyRealizationFamily
  | CollectiveStrategyContributionFamily
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Enumerate the closed family registry in stable declaration order.
allPropositionFamilies :: [PropositionFamily]
allPropositionFamilies = [minBound .. maxBound]

-- | Whether the persisted participant set is explicitly complete.
--
-- Completeness describes the participant set, not proposition commitment and
-- not the subset displayed by a View.
data ParticipantCompleteness
  = Open
  | Closed
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Stable reference to one structured collective-Fit evidence bundle.
newtype CollectiveFitEvidenceRef = CollectiveFitEvidenceRef
  { collectiveFitEvidenceRefText :: Text
  } deriving (Eq, Ord, Show)

-- | Pairwise rationale that two contributors are mutually coherent.
data RawMutualCoherenceEvidence = RawMutualCoherenceEvidence
  { rawCoherenceContributorA :: RawNodeId
  , rawCoherenceContributorB :: RawNodeId
  , rawCoherenceRationale :: Text
  } deriving (Eq, Show)

-- | One contributor's compatibility with the target Strategy constraints.
data RawContributorCompatibilityEvidence = RawContributorCompatibilityEvidence
  { rawCompatibilityContributor :: RawNodeId
  , rawGuidingPolicyCompatibilityRationale :: Text
  , rawTradeOffCompatibilityRationale :: Text
  } deriving (Eq, Show)

-- | Structured collective-Fit evidence bound to one participant set.
data RawCollectiveFitEvidence = RawCollectiveFitEvidence
  { rawFitEvidenceRef :: CollectiveFitEvidenceRef
  , rawFitContributors :: [RawNodeId]
  , rawFitTarget :: RawNodeId
  , rawMutualCoherenceEvidence :: [RawMutualCoherenceEvidence]
  , rawFitTargetGuidingPolicy :: RawNodeId
  , rawFitTargetTradeOffs :: [Text]
    -- ^ Source-near target exclusions; order and repetition are not semantic.
  , rawContributorCompatibilityEvidence :: [RawContributorCompatibilityEvidence]
  , rawViableInteractionEvidence :: [Text]
  } deriving (Eq, Show)

-- | Required dimension of structured collective Fit.
data CollectiveFitDimension
  = MutualCoherenceFit
  | GuidingPolicyCompatibilityFit
  | TradeOffCompatibilityFit
  | ViableInteractionFit
  deriving (Eq, Ord, Show)

-- | Participant position used by precise collective diagnostics.
data CollectiveParticipantRole
  = CollectiveContributor
  | CollectiveTarget
  deriving (Eq, Ord, Show)

-- | Semantic diagnostic state of one structurally valid collective claim.
--
-- A blocked evaluation records unavailable Context semantics; every other
-- constructor records a deficiency found by completed semantic evaluation.
data CollectiveStrategyRealizationIssue
  = CollectiveSemanticEvaluationBlocked
    -- ^ Context semantics is unavailable; no semantic claim was evaluated.
  | CandidateParticipantSemanticsUnavailable CollectiveParticipantRole RawNodeId
    -- ^ A Candidate Strategy participant has no validated Context semantics.
  | CollectiveFitEvidenceNotFound CollectiveFitEvidenceRef
  | CollectiveFitEvidenceAmbiguous CollectiveFitEvidenceRef
  | MissingContributorContribution RawNodeId RawNodeId
  | UncoveredTargetKeyResult RawNodeId
  | UncoveredTargetAction RawNodeId
  | CollectiveFitContributorsMismatch
  | CollectiveFitTargetMismatch RawNodeId RawNodeId
  | InvalidMutualCoherencePair RawNodeId RawNodeId
  | DuplicateMutualCoherencePair RawNodeId RawNodeId
  | MissingMutualCoherencePair RawNodeId RawNodeId
  | EmptyCollectiveFitEvidence CollectiveFitDimension
  | InvalidContributorCompatibilityContributor RawNodeId
  | DuplicateContributorCompatibilityContributor RawNodeId
  | MissingContributorCompatibilityEvidence RawNodeId CollectiveFitDimension
  | EmptyContributorCompatibilityEvidence RawNodeId CollectiveFitDimension
  | CollectiveFitGuidingPolicyMismatch RawNodeId RawNodeId
  | CollectiveFitTradeOffsMismatch
  | MissingTargetStrategyFormulation RawNodeId
  deriving (Eq, Show)
