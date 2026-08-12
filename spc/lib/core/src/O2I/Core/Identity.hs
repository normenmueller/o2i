{-# LANGUAGE RankNTypes #-}

-- | Profile-neutral identity and selected-View scope boundary.
--
-- A model occurrence carries only its canonical occurrence identity and its
-- exact model identity. In particular, this module neither stores nor derives
-- an O2I type before selected-View membership has been established.
module O2I.Core.Identity
  ( ModelIdentity
  , ModelIdentityDefect(..)
  , modelIdentity
  , modelIdentityText
  , OccurrenceIdentity
  , OccurrenceIdentityDefect(..)
  , occurrenceIdentity
  , occurrenceIdentityText
  , ModelOccurrence
  , modelOccurrence
  , modelOccurrenceIdentity
  , modelOccurrenceModelIdentity
  , ModelIdentityIndex
  , IdentityIndexDefect
  , identityIndexDefectOccurrence
  , identityIndexDefectModelIdentities
  , buildModelIdentityIndex
  , SelectedViewScope
  , SelectedViewScopeDefect
  , SelectedViewScopeDefectKind(..)
  , selectedViewScopeDefectKind
  , selectedViewScopeDefectOccurrence
  , selectedViewScopeDefectCardinality
  , withSelectedViewScope
  ) where

import O2I.Core.Identity.Internal
