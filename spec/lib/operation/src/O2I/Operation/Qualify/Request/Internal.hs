-- | Private representation of Qualify requests.
module O2I.Operation.Qualify.Request.Internal
  ( QualifySelectorCategory(..)
  , QualifyRequestDefect(..)
  , QualifyRequest(..)
  ) where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.View (ViewSelector)

-- | Closed selector category used by request validation.
data QualifySelectorCategory
  = QualifyNeedSelectorCategory
  | QualifyStrategySelectorCategory
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why no contract-valid Qualify request can be constructed.
data QualifyRequestDefect =
  DuplicateQualifySelector !QualifySelectorCategory !ModelIdentity
  deriving (Eq, Ord, Show)

-- | One exact selected-View qualification request.
--
-- Strategies are mandatory. An empty Need selection requests every Need
-- subject discovered in the prepared selected View. Supplemental inputs are
-- retained in caller order for the shared Semantics binding stage.
data QualifyRequest =
  QualifyRequest
    !InputSource
    !ViewSelector
    !(Maybe AdapterId)
    !(NonEmpty ModelIdentity)
    ![ModelIdentity]
    ![InputSource]
  deriving (Show)
