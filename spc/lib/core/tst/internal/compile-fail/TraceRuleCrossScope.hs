{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module TraceRuleCrossScope where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Types

data ForeignScope

foreignStrategy :: Bound ForeignScope ('ContextKind 'Strategy)
foreignStrategy = undefined

invalidCrossScopeRule :: CompiledPlan EffectTraceContext
invalidCrossScopeRule =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "intervention")))
    addressesNeed
    (singletonDomain (mkNodeId (RawNodeId "need"))) $ \intervention need addressed ->
    constrainExisting foreignStrategy qualifiesNeed need $ \qualifies ->
      finish
        (projectOccurrence
           addressed
           (\addressedOccurrence qualifiesOccurrence ->
              EffectTraceContext
                { traceContextVision = mkNodeId (RawNodeId "vision")
                , traceContextStrategy =
                    projectedOccurrenceFrom qualifiesOccurrence
                , traceContextNeed = projectedOccurrenceTo addressedOccurrence
                , traceContextIntervention =
                    projectedOccurrenceFrom addressedOccurrence
                , traceContextMeasure = mkNodeId (RawNodeId "measure")
                , traceContextSituation = mkNodeId (RawNodeId "situation")
                })
           `appendOccurrence` qualifies)
