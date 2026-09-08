module TraceCrossScope where

import O2I.Trace (BoundTraceIdentity)

crossScope :: BoundTraceIdentity firstScope -> BoundTraceIdentity secondScope
crossScope = id
