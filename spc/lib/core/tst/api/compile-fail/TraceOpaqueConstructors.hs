module TraceOpaqueConstructors where

import O2I.Trace

forgeIdentity :: TraceIdentity
forgeIdentity = TraceIdentity undefined undefined

forgeBound :: BoundTraceIdentity scope
forgeBound = BoundTraceIdentity undefined

forgeComplete :: CompleteWitness scope
forgeComplete = CompleteWitness undefined undefined undefined

forgePartial :: PartialTrace scope
forgePartial = PartialTrace undefined undefined undefined undefined
