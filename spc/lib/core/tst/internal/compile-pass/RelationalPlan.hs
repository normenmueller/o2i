{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalPlan where

import Data.List.NonEmpty (NonEmpty)
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

strategyDomain :: Domain ('ContextKind 'Strategy)
strategyDomain = singletonDomain (mkNodeId (RawNodeId "strategy"))

interventionDomain :: Domain ('ContextKind 'Intervention)
interventionDomain = singletonDomain (mkNodeId (RawNodeId "intervention"))

needDomain :: Domain ('ContextKind 'Need)
needDomain = singletonDomain (mkNodeId (RawNodeId "need"))

readableConnectedPlan :: CompiledPlan (NonEmpty ProjectedPremise)
readableConnectedPlan =
  rootAtom strategyDomain directsIntervention interventionDomain $ \strategy intervention directsPremise ->
    extendForward intervention addressesNeed needDomain $ \need addressesPremise ->
      constrainExisting strategy qualifiesNeed need $ \qualifiesPremise ->
        finish
          (appendProjectedPremise
             (appendProjectedPremise
                (projectPremise directsPremise)
                addressesPremise)
             qualifiesPremise)
