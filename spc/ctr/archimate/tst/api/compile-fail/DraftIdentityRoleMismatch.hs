{-# LANGUAGE OverloadedStrings #-}

module DraftIdentityRoleMismatch where

import qualified O2I.ArchiMate.Profile.Draft as Draft

location :: Draft.DraftLocation
location =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing "model") 0)
       [])
    Nothing

viewIdentity :: Draft.DraftIdentity Draft.ViewRole
viewIdentity = Draft.draftIdentity [Draft.draftTextScalar "view" location]

invalidRoot :: Draft.ModelRootDraft
invalidRoot = Draft.modelRootDraft viewIdentity location []
