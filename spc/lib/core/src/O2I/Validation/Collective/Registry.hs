-- | Closed typed dispatch registry of admitted collective fan-in families.
module O2I.Validation.Collective.Registry
  ( RawCollectiveFanInClaim(..)
  , RawCollectiveFanInEvidence(..)
  , collectiveFanInClaimFamily
  , collectiveFanInClaimId
  ) where

import O2I.Language.Claim
import O2I.Validation.Collective
import O2I.Validation.Collective.Contribution

-- | One typed claim from the closed family registry.
data RawCollectiveFanInClaim
  = CollectiveStrategyRealizationClaim (Claim RawCollectiveStrategyRealization)
  | CollectiveStrategyContributionClaim
      (Claim RawCollectiveStrategyContribution)
  deriving (Eq, Show)

-- | One family-owned evidence bundle from the closed registry.
data RawCollectiveFanInEvidence
  = CollectiveStrategyRealizationEvidence RawCollectiveFitEvidence
  | CollectiveStrategyContributionEvidence RawCollectiveContributionEvidence
  deriving (Eq, Show)

-- | Dispatch one claim to its closed fachliche family.
collectiveFanInClaimFamily :: RawCollectiveFanInClaim -> PropositionFamily
collectiveFanInClaimFamily claim =
  case claim of
    CollectiveStrategyRealizationClaim _ -> CollectiveStrategyRealizationFamily
    CollectiveStrategyContributionClaim _ ->
      CollectiveStrategyContributionFamily

-- | Read the globally unique claim identity independent of family.
collectiveFanInClaimId :: RawCollectiveFanInClaim -> ClaimId
collectiveFanInClaimId claim =
  case claim of
    CollectiveStrategyRealizationClaim realization ->
      rawRealizationId (claimedProposition realization)
    CollectiveStrategyContributionClaim contribution ->
      rawContributionId (claimedProposition contribution)
