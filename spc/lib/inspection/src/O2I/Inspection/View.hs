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
import O2I.Inspection.Cardinality
import O2I.Inspection.Provenance

-- | Exact selected-View request.
data ViewSelector
  = ViewByName Text
  | ViewById Text
  deriving (Eq, Ord, Show)

-- | One persisted View matching a selector.
data ViewCandidate location = ViewCandidate
  { viewCandidateId :: Text
  , viewCandidateName :: Text
  , viewCandidateLocation :: location
  } deriving (Eq, Ord, Show)

-- | Exact resolved View identity.
data ResolvedView location = ResolvedView
  { resolvedViewId :: Text
  , resolvedViewName :: Text
  , resolvedViewLocation :: location
  } deriving (Eq, Ord, Show)

-- | Facts safely observable when View resolution fails.
data ObservedViewResolution location
  = NoViewMatch
  | OneViewMatch (ViewCandidate location)
  | MultipleViewMatches (AtLeastTwo (ViewCandidate location))
  deriving (Eq, Show)

-- | Total exact-View resolution result.
data ViewAttempt location defect selectedView
  = ViewFailed
      (ObservedViewResolution location)
      (NonEmpty (Located location defect))
  | ViewPassed (ResolvedView location) selectedView
