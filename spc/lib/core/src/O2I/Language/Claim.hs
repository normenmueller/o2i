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

-- * Claim commitment
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
-- @Claim Candidate (Objective \@ Vision)@ denotes one proposed proposition:
-- the wrapper is 'Claim', 'Candidate' is its commitment, and the complete
-- contextualized Objective is its indivisible proposition. Persisted notation
-- may use several syntax constituents to encode that proposition, but carries
-- exactly one commitment at its designated proposition carrier.
--
-- The constructor is private so commitment can only be observed through the
-- total projections and can never be changed by record update.
data Claim proposition =
  Claim Commitment proposition
  deriving (Eq, Ord, Show)

-- * Claim construction and access
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
