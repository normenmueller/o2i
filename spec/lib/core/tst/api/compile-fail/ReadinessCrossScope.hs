module ReadinessCrossScope where

import O2I.Readiness (BoundReadinessInput, EvidenceReadyProof)

crossBound :: BoundReadinessInput firstScope -> BoundReadinessInput secondScope
crossBound = id

crossProof :: EvidenceReadyProof firstScope -> EvidenceReadyProof secondScope
crossProof = id
