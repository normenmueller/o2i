-- | Capability-neutral propagation of internal contract failures.
--
-- A capability owns its closed cause vocabulary and completed value. The
-- closed sum has no completed-value position in its failure alternative and
-- makes failure terminal under both mapping and sequencing. It cannot prove
-- that an arbitrary capability-owned cause itself is context-free; each
-- capability must enforce that property in its closed cause ADT.
module O2I.Operation.Result.Internal
  ( InternalResult
  , internalFailureResult
  , completedInternalResult
  , mapInternalResult
  , andThenInternalResult
  , foldInternalResult
  ) where

-- | One terminal internal cause or one completed capability value.
data InternalResult failure value
  = InternalFailureResult !failure
  | CompletedInternalResult !value
  deriving (Eq, Show)

-- | Terminate with one capability-owned closed internal cause.
internalFailureResult :: failure -> InternalResult failure value
internalFailureResult = InternalFailureResult

-- | Admit one completed capability value.
completedInternalResult :: value -> InternalResult failure value
completedInternalResult = CompletedInternalResult

-- | Transform only a completed value.
mapInternalResult ::
     (value -> mapped)
  -> InternalResult failure value
  -> InternalResult failure mapped
mapInternalResult transform result =
  case result of
    InternalFailureResult failure -> InternalFailureResult failure
    CompletedInternalResult value -> CompletedInternalResult (transform value)

-- | Continue only after completion; an internal cause terminates immediately.
andThenInternalResult ::
     InternalResult failure value
  -> (value -> InternalResult failure mapped)
  -> InternalResult failure mapped
andThenInternalResult result continue =
  case result of
    InternalFailureResult failure -> InternalFailureResult failure
    CompletedInternalResult value -> continue value

-- | Consume both closed result alternatives.
foldInternalResult ::
     (failure -> result)
  -> (value -> result)
  -> InternalResult failure value
  -> result
foldInternalResult failed completed result =
  case result of
    InternalFailureResult failure -> failed failure
    CompletedInternalResult value -> completed value
