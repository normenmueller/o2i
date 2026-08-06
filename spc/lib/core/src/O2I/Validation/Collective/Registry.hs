-- | Public types of the closed collective fan-in registry.
--
-- Registry preparation and family dispatch remain internal to complete model
-- semantics. This facade exposes only persisted input, diagnostics, and
-- truthful preparation work.
module O2I.Validation.Collective.Registry
  ( RawCollectiveFanInClaim(..)
  , RawCollectiveFanInEvidence(..)
  , CollectiveRegistryError(..)
  , CollectiveRegistryPreparationWork(..)
  , collectiveFanInClaimFamily
  , collectiveFanInClaimId
  ) where

import O2I.Validation.Collective.Registry.Internal
