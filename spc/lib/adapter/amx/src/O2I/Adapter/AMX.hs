{-# LANGUAGE OverloadedStrings #-}

-- | Native Archi Model XML adapter for the O2I inspection pipeline.
module O2I.Adapter.AMX
  ( amxAdapter
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile
import O2I.Adapter.AMX.Internal.View
import O2I.Adapter.AMX.Internal.XML
import O2I.Inspection.Adapter

-- | Safe, deterministic adapter for native Archi Model XML version 5.0.0 and
-- O2I profile 0.3.
amxAdapter :: Adapter
amxAdapter =
  Adapter
    (adapterDescriptor ('a' :| "mx") ('A' :| "rchi Model XML") ('0' :| ".2"))
    decodeAMX
    amxDecodeDefectSpec
    resolveAMXView
    amxViewDefectSpec
    amxProfileContract
    observeAMXProfile
