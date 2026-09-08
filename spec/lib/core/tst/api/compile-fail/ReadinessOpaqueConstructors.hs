module ReadinessOpaqueConstructors where

import O2I.Readiness

forgeInput :: ReadinessInput
forgeInput = ReadinessInput undefined undefined undefined undefined undefined

forgeBound :: BoundReadinessInput scope
forgeBound = BoundReadinessInput undefined undefined

forgeReady :: EvidenceReadyProof scope
forgeReady = EvidenceReadyProof undefined undefined undefined undefined
