-- | AMX profile contract and observation boundary.
module O2I.Adapter.AMX.Internal.Profile
  ( amxProfileContract
  , observeAMXProfile
  ) where

import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Projection
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Complete AMX profile contract paired with the adapter.
amxProfileContract ::
     O2IProfileContract SourcePosition AMXProfileFact AMXProfileDefect
amxProfileContract =
  O2IProfileContract
    { projectProfileSnapshot = projectAMXProfile
    , profileDefectSpec = amxProfileDefectSpec
    }

-- | Observe the exact decoded document and already validated selected View.
observeAMXProfile ::
     AMXDocument
  -> AMXSelectedView
  -> ProfileSnapshot SourcePosition AMXProfileFact
observeAMXProfile document selected =
  profileSnapshot
    (Located
       (amxElementLocation (selectedViewElement selected))
       (AMXProfileFact document selected))
