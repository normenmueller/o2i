{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed Trace requests without supplemental inputs.
module O2I.Operation.Trace.Request
  ( type TraceRequest
  , traceRequest
  , traceModelInput
  , traceViewSelector
  , traceAdapterId
  , foldTraceRequest
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Trace.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Request Trace evaluation for one model and selected View.
traceRequest :: InputSource -> ViewSelector -> Maybe AdapterId -> TraceRequest
traceRequest = TraceRequest

-- | Exact physical model source retained by the request.
traceModelInput :: TraceRequest -> InputSource
traceModelInput (TraceRequest model _ _) = model

-- | Exact mandatory View selector retained without normalization.
traceViewSelector :: TraceRequest -> ViewSelector
traceViewSelector (TraceRequest _ selector _) = selector

-- | Optional exact compiled Adapter identifier.
traceAdapterId :: TraceRequest -> Maybe AdapterId
traceAdapterId (TraceRequest _ _ adapter) = adapter

-- | Consume the complete immutable request without exposing its constructor.
foldTraceRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> result)
  -> TraceRequest
  -> result
foldTraceRequest consume (TraceRequest model selector adapter) =
  consume model selector adapter
