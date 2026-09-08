module TracePublicApi where

import Data.ByteString (ByteString)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Trace (runTrace)
import O2I.Operation.Trace.Machine
  ( encodeTraceResultDocument
  , traceResultDocument
  )
import O2I.Operation.Trace.Request (traceRequest)
import O2I.Operation.Trace.Result (TraceFailure)
import O2I.Operation.View (ViewSelector)

traceDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> InputSource
  -> ViewSelector
  -> IO (Either TraceFailure ByteString)
traceDocument tool adapters profiles model view =
  fmap
    (fmap encodeTraceResultDocument . traceResultDocument tool)
    (runTrace adapters profiles (traceRequest model view Nothing))
