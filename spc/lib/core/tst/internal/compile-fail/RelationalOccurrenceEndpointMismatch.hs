{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalOccurrenceEndpointMismatch where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

data InvalidRow = InvalidRow
  { invalidNeedSource :: NodeId ('ContextKind 'Need)
  }

invalidEndpointProjection :: CompiledPlan InvalidRow
invalidEndpointProjection =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "intervention")))
    addressesNeed
    (singletonDomain (mkNodeId (RawNodeId "need")))
    (\_ _ premise ->
       finish
         (projectOccurrence
            premise
            (\occurrence ->
               InvalidRow
                 {invalidNeedSource = projectedOccurrenceFrom occurrence})))
