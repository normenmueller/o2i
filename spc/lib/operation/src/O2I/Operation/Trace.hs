-- | Selected-View Trace orchestration.
--
-- The runtime executes shared preparation and the fixed Notation, Profile,
-- Structure, and Semantics prerequisites before invoking Core Trace. A
-- Semantics-unavailable result still carries the model proof required by Trace;
-- semantic rejection remains a prerequisite rejection.
module O2I.Operation.Trace
  ( runTrace
  ) where

import O2I.Operation.Trace.Runtime.Internal (runTrace)
