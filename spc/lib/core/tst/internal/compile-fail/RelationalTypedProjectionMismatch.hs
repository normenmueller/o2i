{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalTypedProjectionMismatch where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

invalidProjection :: CompiledPlan [ProjectedPremise]
invalidProjection =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "strategy")))
    qualifiesNeed
    (singletonDomain (mkNodeId (RawNodeId "need")))
    (\_ _ premise -> finish (projectPremise premise))
