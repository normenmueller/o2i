-- | Cumulative Validate orchestration.
--
-- The runtime executes the accepted shared preparation prefix, then the
-- requested owner stages in their fixed order. Acquisition is the only effect
-- boundary; every assessment remains a total owner function.
module O2I.Operation.Validate
  ( runValidate
  ) where

import O2I.Operation.Validate.Runtime.Internal (runValidate)
