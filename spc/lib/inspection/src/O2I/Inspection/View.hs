-- | Exact View selection and resolution domain.
module O2I.Inspection.View
  ( ViewSelector(..)
  , ViewCandidate(..)
  , ResolvedView(..)
  , ObservedViewResolution(..)
  , ViewAttempt(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Inspection.Provenance

-- | Exact selected-View request.
data ViewSelector
  = ViewByName Text
  | ViewById Text
  deriving (Eq, Ord, Show)

-- | One persisted View matching a selector.
data ViewCandidate = ViewCandidate
  { viewCandidateId :: Text
  , viewCandidateName :: Text
  , viewCandidateLocation :: SourceLocation
  } deriving (Eq, Ord, Show)

-- | Exact resolved View identity.
data ResolvedView = ResolvedView
  { resolvedViewId :: Text
  , resolvedViewName :: Text
  , resolvedViewLocation :: SourceLocation
  } deriving (Eq, Ord, Show)

-- | Facts safely observable when View resolution fails.
data ObservedViewResolution
  = NoViewMatch
  | OneViewMatch ViewCandidate
  | MultipleViewMatches (NonEmpty ViewCandidate)
  deriving (Eq, Show)

-- | Total exact-View resolution result.
data ViewAttempt defect selectedView
  = ViewFailed ObservedViewResolution (NonEmpty (Located defect))
  | ViewPassed ResolvedView selectedView
