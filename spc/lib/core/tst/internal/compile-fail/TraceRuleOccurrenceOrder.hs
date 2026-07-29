{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module TraceRuleOccurrenceOrder where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Types

invalidOccurrenceOrder :: CompiledPlan AddressedNeed
invalidOccurrenceOrder =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "intervention")))
    addressesNeed
    (singletonDomain (mkNodeId (RawNodeId "need"))) $ \intervention need first ->
    constrainExisting intervention addressesNeed need $ \second ->
      finish
        (projectOccurrence
           second
           (\secondOccurrence _ ->
              AddressedNeed
                { addressedNeedIntervention =
                    projectedOccurrenceFrom secondOccurrence
                , addressedNeedNeed = projectedOccurrenceTo secondOccurrence
                })
           `appendOccurrence` first)
