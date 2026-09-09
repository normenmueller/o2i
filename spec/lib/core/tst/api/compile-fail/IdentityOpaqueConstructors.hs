module IdentityOpaqueConstructors where

import O2I.Core.Identity

invalidModelIdentity :: ModelIdentity
invalidModelIdentity = ModelIdentity undefined

invalidOccurrenceIdentity :: OccurrenceIdentity
invalidOccurrenceIdentity = OccurrenceIdentity undefined

invalidModelOccurrence :: ModelOccurrence
invalidModelOccurrence = ModelOccurrence undefined undefined

invalidModelIdentityIndex :: ModelIdentityIndex
invalidModelIdentityIndex = ModelIdentityIndex undefined undefined

invalidIdentityIndexDefect :: IdentityIndexDefect
invalidIdentityIndexDefect = IdentityIndexDefect undefined undefined

invalidSelectedViewScope :: SelectedViewScope scope
invalidSelectedViewScope = SelectedViewScope undefined undefined undefined

invalidSelectedViewScopeDefect :: SelectedViewScopeDefect
invalidSelectedViewScopeDefect =
  SelectedViewScopeDefect UnknownSelectedViewOccurrence undefined 1
