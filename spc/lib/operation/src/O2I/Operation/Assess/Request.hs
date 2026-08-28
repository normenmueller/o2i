{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed selected-View evidence-assessment requests.
module O2I.Operation.Assess.Request
  ( type AssessRequest
  , assessRequest
  , assessModelInput
  , assessViewSelector
  , assessAdapterId
  , assessBundleInput
  , assessSupplementalInputs
  , foldAssessRequest
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Assess.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Request evidence assessment for one explicit bundle and selected View.
assessRequest ::
     InputSource
  -> ViewSelector
  -> Maybe AdapterId
  -> InputSource
  -> [InputSource]
  -> AssessRequest
assessRequest = AssessRequest

-- | Exact physical model source retained by the request.
assessModelInput :: AssessRequest -> InputSource
assessModelInput (AssessRequest model _ _ _ _) = model

-- | Exact mandatory View selector retained without normalization.
assessViewSelector :: AssessRequest -> ViewSelector
assessViewSelector (AssessRequest _ selector _ _ _) = selector

-- | Optional exact compiled Adapter identifier.
assessAdapterId :: AssessRequest -> Maybe AdapterId
assessAdapterId (AssessRequest _ _ adapter _ _) = adapter

-- | Exact mandatory Assessment bundle source retained without acquisition.
assessBundleInput :: AssessRequest -> InputSource
assessBundleInput (AssessRequest _ _ _ input _) = input

-- | Ordered Semantics supplemental sources retained without acquisition.
assessSupplementalInputs :: AssessRequest -> [InputSource]
assessSupplementalInputs (AssessRequest _ _ _ _ supplements) = supplements

-- | Consume the complete immutable request without exposing its constructor.
foldAssessRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> InputSource -> [InputSource] -> result)
  -> AssessRequest
  -> result
foldAssessRequest consume (AssessRequest model view adapter input supplements) =
  consume model view adapter input supplements
