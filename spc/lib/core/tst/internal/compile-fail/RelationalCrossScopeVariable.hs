{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalCrossScopeVariable where

import Data.List.NonEmpty (NonEmpty)
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

data ForeignScope

foreignStrategy :: Bound ForeignScope ('ContextKind 'Strategy)
foreignStrategy = undefined

invalidCrossScopePlan :: CompiledPlan (NonEmpty ProjectedPremise)
invalidCrossScopePlan =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "strategy")))
    qualifiesNeed
    (singletonDomain (mkNodeId (RawNodeId "need")))
    (\_ need premise ->
       constrainExisting
         foreignStrategy
         qualifiesNeed
         need
         (\constraint ->
            finish (appendProjectedPremise (projectPremise premise) constraint)))
