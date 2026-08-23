module OwnerSupplementalRoleRequired where

import O2I.Operation.Acquisition
import O2I.Operation.Diagnostic.Owner.Source
import O2I.Structure

bindGeneric ::
     PreparedScope authority profile document scope
  -> AcquiredSource
  -> WellFormedGraph scope
  -> Maybe ()
bindGeneric scope source graph =
  withSupplementalOwnerBinding
    scope
    [source]
    graph
    (const Nothing)
    (const Nothing)
    (const (Just ()))
