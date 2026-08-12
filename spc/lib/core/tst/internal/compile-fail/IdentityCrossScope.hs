module IdentityCrossScope where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity

sameScope :: SelectedViewScope scope -> SelectedViewScope scope -> ()
sameScope _ _ = ()

invalidCrossScope ::
     ModelIdentityIndex
  -> Either
       (NonEmpty SelectedViewScopeDefect)
       (Either (NonEmpty SelectedViewScopeDefect) ())
invalidCrossScope index =
  withSelectedViewScope index [] $ \left ->
    withSelectedViewScope index [] $ \right -> sameScope left right
