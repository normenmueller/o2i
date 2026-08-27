module TraceResultOpaqueConstructor where

import O2I.Operation.Trace.Result

invalid :: TraceResult
invalid = TraceFailed undefined
