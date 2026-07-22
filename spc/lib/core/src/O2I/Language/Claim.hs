-- | Commitment of notation-independent model propositions.
module O2I.Language.Claim
  ( Commitment(..)
  , Claim
  , claimWithCommitment
  , candidateClaim
  , assertedClaim
  , claimCommitment
  , claimedProposition
  ) where

-- | Whether a model proposition is proposed or asserted as semantically true.
--
-- Candidate propositions remain inspectable but never enter validated O2I
-- semantics. Asserted propositions must satisfy every applicable dependency
-- and validation obligation.
data Commitment
  = Candidate
  | Asserted
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One proposition paired with its explicit commitment.
--
-- The constructor is private so commitment can only be observed through the
-- total projections and can never be changed by record update.
data Claim proposition =
  Claim Commitment proposition
  deriving (Eq, Ord, Show)

-- | Construct a claim with an explicit commitment.
claimWithCommitment :: Commitment -> proposition -> Claim proposition
claimWithCommitment = Claim

-- | Construct a proposed proposition excluded from validated semantics.
candidateClaim :: proposition -> Claim proposition
candidateClaim = Claim Candidate

-- | Construct a proposition asserted as semantically true.
assertedClaim :: proposition -> Claim proposition
assertedClaim = Claim Asserted

-- | Read the explicit commitment of one proposition.
claimCommitment :: Claim proposition -> Commitment
claimCommitment (Claim commitment _) = commitment

-- | Read the proposition carried by one claim.
claimedProposition :: Claim proposition -> proposition
claimedProposition (Claim _ proposition) = proposition
