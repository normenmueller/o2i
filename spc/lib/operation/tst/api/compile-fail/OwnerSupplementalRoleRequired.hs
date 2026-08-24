module OwnerSupplementalRoleRequired where

import O2I.Operation.Acquisition
import O2I.Operation.Diagnostic.Owner.Source

admitGeneric ::
     PreparedAuthority authority profile document -> AcquiredSource -> Maybe ()
admitGeneric authority source =
  withAdmittedOwnerSupplementalInputs
    authority
    [source]
    (const Nothing)
    (const Nothing)
    (const (Just ()))
