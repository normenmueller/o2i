-- | Internal closed data for static Profile discovery.
module O2I.Operation.Discovery.Profile.Internal
  ( ProfileDiscoveryDefect(..)
  , ProfileDiscoveryCompilation(..)
  , ProfileDiscoveryRow(..)
  , ProfileDiscovery(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Text (Text)

-- | Missing or duplicate adapter identity in one Profile descriptor.
data ProfileDiscoveryDefect
  = MissingProfileAdapterId !Text
  | DuplicateProfileAdapterId !Text !Text
  deriving (Eq, Ord, Show)

-- | Failed validation or compiled static Profile discovery.
data ProfileDiscoveryCompilation
  = ProfileDiscoveryCompilationFailed !(NonEmpty ProfileDiscoveryDefect)
  | ProfileDiscoveryCompiled !ProfileDiscovery

-- | Descriptor-owned data for one discoverable Profile.
data ProfileDiscoveryRow =
  ProfileDiscoveryRow !Text !Text !Text !Text !(NonEmpty Text) !Text
  deriving (Eq, Ord, Show)

-- | Non-empty canonical Profile inventory with reference lookup.
data ProfileDiscovery =
  ProfileDiscovery
    !(NonEmpty ProfileDiscoveryRow)
    !(Map Text ProfileDiscoveryRow)
