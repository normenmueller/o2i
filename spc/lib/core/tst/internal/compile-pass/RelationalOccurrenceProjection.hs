{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalOccurrenceProjection where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

data AddressedNeed = AddressedNeed
  { addressedIntervention :: NodeId ('ContextKind 'Intervention)
  , addressedNeed :: NodeId ('ContextKind 'Need)
  , addressedOrdinal :: Int
  }

interventionDomain :: Domain ('ContextKind 'Intervention)
interventionDomain = singletonDomain (mkNodeId (RawNodeId "intervention"))

needDomain :: Domain ('ContextKind 'Need)
needDomain = singletonDomain (mkNodeId (RawNodeId "need"))

readableOccurrenceProjection :: CompiledPlan AddressedNeed
readableOccurrenceProjection =
  rootAtom interventionDomain addressesNeed needDomain $ \_ _ premise ->
    finish
      (projectOccurrence
         premise
         (\occurrence ->
            AddressedNeed
              { addressedIntervention = projectedOccurrenceFrom occurrence
              , addressedNeed = projectedOccurrenceTo occurrence
              , addressedOrdinal = projectedOccurrenceOrdinal occurrence
              }))
