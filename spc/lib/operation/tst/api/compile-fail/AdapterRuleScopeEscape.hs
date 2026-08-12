{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE RankNTypes #-}

module AdapterRuleScopeEscape where

import O2I.Operation.Adapter.Authoring

invalidDefinition ::
     AdapterRuleDefinition
  -> (forall scope. AdapterDefinition scope (RecognitionRule escaped))
invalidDefinition = recognitionRule
