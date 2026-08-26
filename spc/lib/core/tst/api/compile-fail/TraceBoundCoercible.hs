module TraceBoundCoercible where

import Data.Coerce (coerce)
import O2I.Trace (BoundTraceIdentity)

coerceScope :: BoundTraceIdentity firstScope -> BoundTraceIdentity secondScope
coerceScope = coerce
