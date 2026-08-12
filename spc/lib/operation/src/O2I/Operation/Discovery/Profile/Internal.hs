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

data ProfileDiscoveryDefect
  = MissingProfileAdapterId !Text
  | DuplicateProfileAdapterId !Text !Text
  deriving (Eq, Ord, Show)

data ProfileDiscoveryCompilation
  = ProfileDiscoveryCompilationFailed !(NonEmpty ProfileDiscoveryDefect)
  | ProfileDiscoveryCompiled !ProfileDiscovery

data ProfileDiscoveryRow =
  ProfileDiscoveryRow !Text !Text !Text !Text !(NonEmpty Text) !Text
  deriving (Eq, Ord, Show)

data ProfileDiscovery =
  ProfileDiscovery
    !(NonEmpty ProfileDiscoveryRow)
    !(Map Text ProfileDiscoveryRow)
