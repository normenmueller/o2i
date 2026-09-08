{-# LANGUAGE ExplicitNamespaces #-}

-- | Complete terminal-neutral human projection of View discovery.
module O2I.Operation.Discovery.View.Human
  ( type HumanViewDiscovery
  , viewHumanDiscovery
  , foldHumanViewDiscovery
  ) where

import O2I.Operation.Discovery.View
  ( ViewDiscovery
  , ViewDiscoveryFailure
  , foldViewDiscoveryResult
  )
import O2I.Operation.Human.Value
  ( HumanAdapterDescriptor
  , HumanSourceIdentity
  , HumanViewDescriptor
  )
import O2I.Operation.Human.Value.Internal
  ( projectAdapterDescriptor
  , projectSourceIdentity
  , projectViewDescriptor
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldViewReport)

-- | Complete failure or successful View-discovery projection.
data HumanViewDiscovery
  = HumanViewDiscoveryFailed ViewDiscoveryFailure
  | HumanViewsDiscovered
      ReportEnvelope
      HumanSourceIdentity
      HumanAdapterDescriptor
      [HumanViewDescriptor]

-- | Project View discovery without rendering or reconstructing its values.
viewHumanDiscovery :: ToolDescriptor -> ViewDiscovery -> HumanViewDiscovery
viewHumanDiscovery tool =
  foldViewReport
    tool
    HumanViewDiscoveryFailed
    (\envelope result ->
       foldViewDiscoveryResult
         (\source adapter _ views ->
            HumanViewsDiscovered
              envelope
              (projectSourceIdentity source)
              (projectAdapterDescriptor adapter)
              (map projectViewDescriptor views))
         result)

-- | Eliminate failure or consume every successful discovery field.
foldHumanViewDiscovery ::
     (ViewDiscoveryFailure -> result)
  -> (ReportEnvelope -> HumanSourceIdentity -> HumanAdapterDescriptor -> [HumanViewDescriptor] -> result)
  -> HumanViewDiscovery
  -> result
foldHumanViewDiscovery failed discovered result =
  case result of
    HumanViewDiscoveryFailed failure -> failed failure
    HumanViewsDiscovered envelope source adapter views ->
      discovered envelope source adapter views
