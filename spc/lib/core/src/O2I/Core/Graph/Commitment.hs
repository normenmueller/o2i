-- | Explicit commitment of one persisted O2I proposition.
module O2I.Core.Graph.Commitment
  ( Commitment(..)
  ) where

-- | Whether a proposition is proposed or asserted as semantically valid.
--
-- Commitment is graph evidence. Later semantic stages decide which
-- obligations an asserted proposition must satisfy.
data Commitment
  = Candidate
    -- ^ Proposed evidence that cannot satisfy an asserted obligation.
  | Asserted
    -- ^ Evidence asserted as semantically valid by the model.
  deriving (Bounded, Enum, Eq, Ord, Show)
