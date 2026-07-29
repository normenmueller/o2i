{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalEndpointVariableMismatch where

import Data.List.NonEmpty (NonEmpty)
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

invalidPlan :: CompiledPlan (NonEmpty ProjectedPremise)
invalidPlan =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "strategy")))
    directsIntervention
    needDomain
    (\_ _ premise -> finish (projectPremise premise))

needDomain :: Domain ('ContextKind 'Need)
needDomain = singletonDomain (mkNodeId (RawNodeId "need"))
