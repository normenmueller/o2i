module IdentityCrossScope where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity

sameScope :: SelectedViewScope scope -> SelectedViewScope scope -> ()
sameScope _ _ = ()

invalidCrossScope ::
     ModelIdentityIndex
  -> ModelOccurrence
  -> Either
       (NonEmpty SelectedViewScopeDefect)
       (Either (NonEmpty SelectedViewScopeDefect) ())
invalidCrossScope index selectedView =
  withSelectedViewScope index selectedView [] $ \left ->
    withSelectedViewScope index selectedView [] $ \right -> sameScope left right
