{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}

-- | Private typed rows produced by declarative effect-trace rules.
module O2I.Validation.Trace.Types
  ( AddressedNeed(..)
  , EffectTraceContext(..)
  , EffectTraceConstituents(..)
  ) where

import O2I.Language.Element

-- | One persisted Intervention-to-Need diagnostic pair.
data AddressedNeed = AddressedNeed
  { addressedNeedIntervention :: NodeId ('ContextKind 'Intervention)
  , addressedNeedNeed :: NodeId ('ContextKind 'Need)
  } deriving (Eq, Ord, Show)

-- | Context skeleton required by one complete effect trace.
data EffectTraceContext = EffectTraceContext
  { traceContextVision :: NodeId ('ContextKind 'Vision)
  , traceContextStrategy :: NodeId ('ContextKind 'Strategy)
  , traceContextNeed :: NodeId ('ContextKind 'Need)
  , traceContextIntervention :: NodeId ('ContextKind 'Intervention)
  , traceContextMeasure :: NodeId ('ContextKind 'Measure)
  , traceContextSituation :: NodeId ('ContextKind 'Situation)
  } deriving (Eq, Ord, Show)

-- | Complete owner-specific constituent proof for one static anchor kind.
data EffectTraceConstituents (anchor :: SituationAnchor) = EffectTraceConstituents
  { constituentVisionObjective :: NodeId ('PrimitiveKind 'Vision 'Objective)
  , constituentStrategyDriver :: NodeId ('PrimitiveKind 'Strategy 'Driver)
  , constituentStrategyObjective :: NodeId ('PrimitiveKind 'Strategy 'Objective)
  , constituentStrategyKeyResult :: NodeId ('PrimitiveKind 'Strategy 'KeyResult)
  , constituentStrategyAction :: NodeId ('PrimitiveKind 'Strategy 'Action)
  , constituentNeedDriver :: NodeId ('PrimitiveKind 'Need 'Driver)
  , constituentNeedObjective :: NodeId ('PrimitiveKind 'Need 'Objective)
  , constituentInterventionAction :: NodeId
      ('PrimitiveKind 'Intervention 'Action)
  , constituentInterventionKeyResult :: NodeId
      ('PrimitiveKind 'Intervention 'KeyResult)
  , constituentMeasurePerformanceDimension :: NodeId
      ('StructuringKind 'Measure 'PerformanceDimension)
  , constituentMeasureKPI :: NodeId ('PrimitiveKind 'Measure 'KPI)
  , constituentSituationAnchor :: NodeId ('AnchorKind anchor)
  } deriving (Eq, Ord, Show)
