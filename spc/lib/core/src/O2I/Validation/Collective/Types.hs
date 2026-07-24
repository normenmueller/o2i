-- | Shared vocabulary for collective Strategy realization and Fit assessment.
module O2I.Validation.Collective.Types
  ( CollectiveFitEvidenceRef(..)
  , RawMutualCoherenceEvidence(..)
  , RawContributorCompatibilityEvidence(..)
  , RawCollectiveFitEvidence(..)
  , CollectiveFitDimension(..)
  , CollectiveStrategyRealizationIssue(..)
  ) where

import Data.Text (Text)
import O2I.Language.Element (RawNodeId)

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

-- | Semantic deficiency of one structurally valid collective claim.
data CollectiveStrategyRealizationIssue
  = CollectiveFitEvidenceNotFound CollectiveFitEvidenceRef
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
