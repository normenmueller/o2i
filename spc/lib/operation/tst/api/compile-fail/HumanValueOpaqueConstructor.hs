{-# LANGUAGE OverloadedStrings #-}

module HumanValueOpaqueConstructor where

import O2I.Operation.Human.Value (HumanModelIdentity)

forged :: HumanModelIdentity
forged = HumanModelIdentity "forged"
