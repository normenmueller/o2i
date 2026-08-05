-- | Collective Strategy contribution through coordinated interaction.
--
-- A Candidate retains diagnostics and never constructs a semantic witness.
-- An Asserted proposition requires a Closed participant set and exactly one
-- homogeneous, provenance-bound Primitive-evidence graph.
module O2I.Validation.Collective.Contribution
  ( CollectiveContributionEvidenceRef(..)
  , CollectiveFanInStructuralError(..)
  , CollectiveFanInStructuralWork(..)
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
  , ValidatedContributionGraph
  , CollectiveStrategyContribution
  , CandidateCollectiveStrategyContribution
  , ValidatedCollectiveStrategyContributions
  , collectiveStrategyContributions
  , collectiveContributionId
  , collectiveContributionParticipants
  , collectiveContributionTarget
  , collectiveContributionEvidenceReference
  , collectiveContributionRationales
  , collectiveContributionPrimitiveGraph
  , contributionGraphMode
  , contributionGraphNodes
  , contributionGraphOccurrences
  , candidateCollectiveContributionClaim
  , candidateCollectiveContributionIssues
  ) where

import O2I.Validation.Collective.Contribution.Eval
import O2I.Validation.Collective.Contribution.Types
import O2I.Validation.Collective.FanIn
  ( CollectiveFanInStructuralError(..)
  , CollectiveFanInStructuralWork(..)
  )
