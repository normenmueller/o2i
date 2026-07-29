{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module TraceRuleEndpointMismatch where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Types

invalidEndpointRule :: CompiledPlan AddressedNeed
invalidEndpointRule =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "intervention")))
    addressesNeed
    strategyDomain $ \_ _ addressed ->
    finish
      (projectOccurrence
         addressed
         (\occurrence ->
            AddressedNeed
              { addressedNeedIntervention = projectedOccurrenceFrom occurrence
              , addressedNeedNeed = projectedOccurrenceTo occurrence
              }))

strategyDomain :: Domain ('ContextKind 'Strategy)
strategyDomain = singletonDomain (mkNodeId (RawNodeId "strategy"))
