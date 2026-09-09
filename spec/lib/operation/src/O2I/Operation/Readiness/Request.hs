{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed selected-View evidence-readiness requests.
module O2I.Operation.Readiness.Request
  ( type ReadinessRequest
  , readinessRequest
  , readinessModelInput
  , readinessViewSelector
  , readinessAdapterId
  , readinessEvidenceInput
  , readinessSupplementalInputs
  , foldReadinessRequest
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Readiness.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Request evidence readiness for one explicit input and selected View.
readinessRequest ::
     InputSource
  -> ViewSelector
  -> Maybe AdapterId
  -> InputSource
  -> [InputSource]
  -> ReadinessRequest
readinessRequest = ReadinessRequest

-- | Exact physical model source retained by the request.
readinessModelInput :: ReadinessRequest -> InputSource
readinessModelInput (ReadinessRequest model _ _ _ _) = model

-- | Exact mandatory View selector retained without normalization.
readinessViewSelector :: ReadinessRequest -> ViewSelector
readinessViewSelector (ReadinessRequest _ selector _ _ _) = selector

-- | Optional exact compiled Adapter identifier.
readinessAdapterId :: ReadinessRequest -> Maybe AdapterId
readinessAdapterId (ReadinessRequest _ _ adapter _ _) = adapter

-- | Exact mandatory Readiness input source retained without acquisition.
readinessEvidenceInput :: ReadinessRequest -> InputSource
readinessEvidenceInput (ReadinessRequest _ _ _ input _) = input

-- | Ordered Semantics supplemental sources retained without acquisition.
readinessSupplementalInputs :: ReadinessRequest -> [InputSource]
readinessSupplementalInputs (ReadinessRequest _ _ _ _ supplements) = supplements

-- | Consume the complete immutable request without exposing its constructor.
foldReadinessRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> InputSource -> [InputSource] -> result)
  -> ReadinessRequest
  -> result
foldReadinessRequest consume (ReadinessRequest model view adapter input supplements) =
  consume model view adapter input supplements
