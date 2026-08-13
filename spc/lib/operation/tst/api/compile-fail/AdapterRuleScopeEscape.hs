{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE RankNTypes #-}

module AdapterRuleScopeEscape where

import O2I.Operation.Adapter.Authoring

invalidDefinition :: NativeAdapterRule scope -> NativeAdapterRule escaped
invalidDefinition = id
