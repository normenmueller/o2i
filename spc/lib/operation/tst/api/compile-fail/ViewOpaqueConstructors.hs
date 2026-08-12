{-# LANGUAGE OverloadedStrings #-}

module ViewOpaqueConstructors where

import O2I.Operation.View

invalidSelector :: ViewSelector
invalidSelector = ViewNameSelector "Main"
