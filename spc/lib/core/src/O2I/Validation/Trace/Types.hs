{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Private typed effect-trace representation and construction boundary.
module O2I.Validation.Trace.Types
  ( AddressedNeed(..)
  , EffectTraceContext(..)
  , EffectTraceConstituents(..)
  , EffectTrace
  , EffectTraceId
  , SomeSituationAnchorRef
  , effectTraceFromTyped
  , effectTraceCoveredPair
  , traceIdentifier
  , effectTraceIdText
  , traceVision
  , traceVisionObjective
  , traceStrategy
  , traceStrategyDriver
  , traceStrategyObjective
  , traceStrategyKeyResult
  , traceStrategyAction
  , traceNeed
  , traceNeedDriver
  , traceNeedObjective
  , traceIntervention
  , traceInterventionAction
  , traceInterventionKeyResult
  , traceMeasure
  , traceMeasurePerformanceDimension
  , traceKPI
  , traceSituation
  , traceSituationAnchor
  , situationAnchorRefId
  , situationAnchorRefKind
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as TextBuilder
import qualified Data.Text.Lazy.Builder.Int as TextBuilder
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

data EffectTraceKey = EffectTraceKey
  { keyVision :: RawNodeId
  , keyVisionObjective :: RawNodeId
  , keyStrategy :: RawNodeId
  , keyStrategyDriver :: RawNodeId
  , keyStrategyObjective :: RawNodeId
  , keyStrategyKeyResult :: RawNodeId
  , keyStrategyAction :: RawNodeId
  , keyNeed :: RawNodeId
  , keyNeedDriver :: RawNodeId
  , keyNeedObjective :: RawNodeId
  , keyIntervention :: RawNodeId
  , keyInterventionAction :: RawNodeId
  , keyInterventionKeyResult :: RawNodeId
  , keyMeasure :: RawNodeId
  , keyMeasurePerformanceDimension :: RawNodeId
  , keyMeasureKPI :: RawNodeId
  , keySituation :: RawNodeId
  , keySituationAnchor :: RawNodeId
  } deriving (Eq, Ord, Show)

-- | Stable identity derived from every constituent of one complete trace.
newtype EffectTraceId =
  EffectTraceId EffectTraceKey
  deriving (Eq, Ord, Show)

-- | Existential reference to a typed constituent of a 'Situation'.
data SomeSituationAnchorRef where
  SomeSituationAnchorRef
    :: NodeId ('AnchorKind anchor)
    -> SSituationAnchor anchor
    -> SomeSituationAnchorRef

instance Eq SomeSituationAnchorRef where
  left == right =
    situationAnchorRefId left == situationAnchorRefId right
      && situationAnchorRefKind left == situationAnchorRefKind right

instance Show SomeSituationAnchorRef where
  show reference =
    show (situationAnchorRefId reference, situationAnchorRefKind reference)

-- | Read-only projection of one complete relational effect path.
data EffectTrace = EffectTrace
  { effectTraceIdentifier :: EffectTraceId
  , effectTraceVisionNode :: NodeId ('ContextKind 'Vision)
  , effectTraceVisionObjective :: NodeId ('PrimitiveKind 'Vision 'Objective)
  , effectTraceStrategyNode :: NodeId ('ContextKind 'Strategy)
  , effectTraceStrategyDriver :: NodeId ('PrimitiveKind 'Strategy 'Driver)
  , effectTraceStrategyObjective :: NodeId ('PrimitiveKind 'Strategy 'Objective)
  , effectTraceStrategyKeyResult :: NodeId ('PrimitiveKind 'Strategy 'KeyResult)
  , effectTraceStrategyAction :: NodeId ('PrimitiveKind 'Strategy 'Action)
  , effectTraceNeedNode :: NodeId ('ContextKind 'Need)
  , effectTraceNeedDriver :: NodeId ('PrimitiveKind 'Need 'Driver)
  , effectTraceNeedObjective :: NodeId ('PrimitiveKind 'Need 'Objective)
  , effectTraceInterventionNode :: NodeId ('ContextKind 'Intervention)
  , effectTraceInterventionAction :: NodeId
      ('PrimitiveKind 'Intervention 'Action)
  , effectTraceInterventionKeyResult :: NodeId
      ('PrimitiveKind 'Intervention 'KeyResult)
  , effectTraceMeasureNode :: NodeId ('ContextKind 'Measure)
  , effectTraceMeasurePerformanceDimension :: NodeId
      ('StructuringKind 'Measure 'PerformanceDimension)
  , effectTraceKPI :: NodeId ('PrimitiveKind 'Measure 'KPI)
  , effectTraceSituationNode :: NodeId ('ContextKind 'Situation)
  , effectTraceSituationAnchor :: SomeSituationAnchorRef
  } deriving (Eq)

instance Show EffectTrace where
  showsPrec precedence trace =
    showParen (precedence > 10)
      $ showString "EffectTrace {effectTraceIdentifier = "
          . shows (traceIdentifier trace)
          . showString ", effectTraceVision = "
          . shows (traceVision trace)
          . showString ", effectTraceVisionObjective = "
          . shows (traceVisionObjective trace)
          . showString ", effectTraceStrategy = "
          . shows (traceStrategy trace)
          . showString ", effectTraceStrategyDriver = "
          . shows (traceStrategyDriver trace)
          . showString ", effectTraceStrategyObjective = "
          . shows (traceStrategyObjective trace)
          . showString ", effectTraceStrategyKeyResult = "
          . shows (traceStrategyKeyResult trace)
          . showString ", effectTraceStrategyAction = "
          . shows (traceStrategyAction trace)
          . showString ", effectTraceNeed = "
          . shows (traceNeed trace)
          . showString ", effectTraceNeedDriver = "
          . shows (traceNeedDriver trace)
          . showString ", effectTraceNeedObjective = "
          . shows (traceNeedObjective trace)
          . showString ", effectTraceIntervention = "
          . shows (traceIntervention trace)
          . showString ", effectTraceInterventionAction = "
          . shows (traceInterventionAction trace)
          . showString ", effectTraceInterventionKeyResult = "
          . shows (traceInterventionKeyResult trace)
          . showString ", effectTraceMeasure = "
          . shows (traceMeasure trace)
          . showString ", effectTraceMeasurePerformanceDimension = "
          . shows (traceMeasurePerformanceDimension trace)
          . showString ", effectTraceKPI = "
          . shows (traceKPI trace)
          . showString ", effectTraceSituation = "
          . shows (traceSituation trace)
          . showString ", effectTraceSituationAnchor = "
          . shows (traceSituationAnchor trace)
          . showString "}"

-- | Construct one complete trace exclusively from endpoint-typed rule rows.
effectTraceFromTyped ::
     EffectTraceContext
  -> SSituationAnchor anchor
  -> EffectTraceConstituents anchor
  -> EffectTrace
effectTraceFromTyped context anchor constituents =
  EffectTrace
    { effectTraceIdentifier = EffectTraceId key
    , effectTraceVisionNode = vision
    , effectTraceVisionObjective = visionObjective
    , effectTraceStrategyNode = strategy
    , effectTraceStrategyDriver = strategyDriver
    , effectTraceStrategyObjective = strategyObjective
    , effectTraceStrategyKeyResult = strategyKeyResult
    , effectTraceStrategyAction = strategyAction
    , effectTraceNeedNode = need
    , effectTraceNeedDriver = needDriver
    , effectTraceNeedObjective = needObjective
    , effectTraceInterventionNode = intervention
    , effectTraceInterventionAction = interventionAction
    , effectTraceInterventionKeyResult = interventionKeyResult
    , effectTraceMeasureNode = measure
    , effectTraceMeasurePerformanceDimension = measurePerformanceDimension
    , effectTraceKPI = measureKPI
    , effectTraceSituationNode = situation
    , effectTraceSituationAnchor = SomeSituationAnchorRef situationAnchor anchor
    }
  where
    vision = traceContextVision context
    strategy = traceContextStrategy context
    need = traceContextNeed context
    intervention = traceContextIntervention context
    measure = traceContextMeasure context
    situation = traceContextSituation context
    visionObjective = constituentVisionObjective constituents
    strategyDriver = constituentStrategyDriver constituents
    strategyObjective = constituentStrategyObjective constituents
    strategyKeyResult = constituentStrategyKeyResult constituents
    strategyAction = constituentStrategyAction constituents
    needDriver = constituentNeedDriver constituents
    needObjective = constituentNeedObjective constituents
    interventionAction = constituentInterventionAction constituents
    interventionKeyResult = constituentInterventionKeyResult constituents
    measurePerformanceDimension =
      constituentMeasurePerformanceDimension constituents
    measureKPI = constituentMeasureKPI constituents
    situationAnchor = constituentSituationAnchor constituents
    key =
      EffectTraceKey
        { keyVision = unNodeId vision
        , keyVisionObjective = unNodeId visionObjective
        , keyStrategy = unNodeId strategy
        , keyStrategyDriver = unNodeId strategyDriver
        , keyStrategyObjective = unNodeId strategyObjective
        , keyStrategyKeyResult = unNodeId strategyKeyResult
        , keyStrategyAction = unNodeId strategyAction
        , keyNeed = unNodeId need
        , keyNeedDriver = unNodeId needDriver
        , keyNeedObjective = unNodeId needObjective
        , keyIntervention = unNodeId intervention
        , keyInterventionAction = unNodeId interventionAction
        , keyInterventionKeyResult = unNodeId interventionKeyResult
        , keyMeasure = unNodeId measure
        , keyMeasurePerformanceDimension = unNodeId measurePerformanceDimension
        , keyMeasureKPI = unNodeId measureKPI
        , keySituation = unNodeId situation
        , keySituationAnchor = unNodeId situationAnchor
        }

contextNodeToRef :: NodeId ('ContextKind context) -> ContextRef context
contextNodeToRef = mkContextRef . unNodeId

-- | Read the Intervention-to-Need pair covered by one complete trace.
effectTraceCoveredPair :: EffectTrace -> AddressedNeed
effectTraceCoveredPair trace =
  AddressedNeed
    { addressedNeedIntervention = effectTraceInterventionNode trace
    , addressedNeedNeed = effectTraceNeedNode trace
    }

-- | Read the stable identity of an effect trace.
traceIdentifier :: EffectTrace -> EffectTraceId
traceIdentifier = effectTraceIdentifier

-- | Canonically encode every constituent of an opaque effect-trace identity.
effectTraceIdText :: EffectTraceId -> Text
effectTraceIdText (EffectTraceId (EffectTraceKey vision visionObjective strategy strategyDriver strategyObjective strategyKeyResult strategyAction need needDriver needObjective intervention interventionAction interventionKeyResult measure measurePerformanceDimension measureKPI situation situationAnchor)) =
  canonicalSequence
    ("o2i-effect-trace-v1"
       : map
           rawNodeIdText
           [ vision
           , visionObjective
           , strategy
           , strategyDriver
           , strategyObjective
           , strategyKeyResult
           , strategyAction
           , need
           , needDriver
           , needObjective
           , intervention
           , interventionAction
           , interventionKeyResult
           , measure
           , measurePerformanceDimension
           , measureKPI
           , situation
           , situationAnchor
           ])

canonicalSequence :: [Text] -> Text
canonicalSequence values =
  decimalText (length values) <> ";" <> Text.concat (map canonicalText values)

canonicalText :: Text -> Text
canonicalText value = decimalText (Text.length value) <> ":" <> value

decimalText :: Integral number => number -> Text
decimalText = LazyText.toStrict . TextBuilder.toLazyText . TextBuilder.decimal

-- | Read the Vision that orients the traced Strategy.
traceVision :: EffectTrace -> ContextRef 'Vision
traceVision = contextNodeToRef . effectTraceVisionNode

-- | Read the Vision Objective that orients the strategic intent.
traceVisionObjective ::
     EffectTrace -> NodeId ('PrimitiveKind 'Vision 'Objective)
traceVisionObjective = effectTraceVisionObjective

-- | Read the Strategy that governs an effect trace.
traceStrategy :: EffectTrace -> ContextRef 'Strategy
traceStrategy = contextNodeToRef . effectTraceStrategyNode

-- | Read the strategic Driver that grounds the strategic intent.
traceStrategyDriver :: EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Driver)
traceStrategyDriver = effectTraceStrategyDriver

-- | Read the strategic Objective that expresses the strategic intent.
traceStrategyObjective ::
     EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Objective)
traceStrategyObjective = effectTraceStrategyObjective

-- | Read the strategic Key Result connected to an effect trace.
traceStrategyKeyResult ::
     EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'KeyResult)
traceStrategyKeyResult = effectTraceStrategyKeyResult

-- | Read the strategic Action that guides operational execution.
traceStrategyAction :: EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Action)
traceStrategyAction = effectTraceStrategyAction

-- | Read the Need context justified by an effect trace.
traceNeed :: EffectTrace -> ContextRef 'Need
traceNeed = contextNodeToRef . effectTraceNeedNode

-- | Read the situated Driver that grounds the Need Objective.
traceNeedDriver :: EffectTrace -> NodeId ('PrimitiveKind 'Need 'Driver)
traceNeedDriver = effectTraceNeedDriver

-- | Read the required qualitative change expressed by the Need.
traceNeedObjective :: EffectTrace -> NodeId ('PrimitiveKind 'Need 'Objective)
traceNeedObjective = effectTraceNeedObjective

-- | Read the Intervention that realizes an effect trace.
traceIntervention :: EffectTrace -> ContextRef 'Intervention
traceIntervention = contextNodeToRef . effectTraceInterventionNode

-- | Read the Intervention Action that changes the Situation anchor.
traceInterventionAction ::
     EffectTrace -> NodeId ('PrimitiveKind 'Intervention 'Action)
traceInterventionAction = effectTraceInterventionAction

-- | Read the Intervention Key Result that operationalizes the traced Need.
traceInterventionKeyResult ::
     EffectTrace -> NodeId ('PrimitiveKind 'Intervention 'KeyResult)
traceInterventionKeyResult = effectTraceInterventionKeyResult

-- | Read the Measure context that frames the trace's observations.
traceMeasure :: EffectTrace -> ContextRef 'Measure
traceMeasure = contextNodeToRef . effectTraceMeasureNode

-- | Read the Measure measurement dimension determined by the Strategy.
traceMeasurePerformanceDimension ::
     EffectTrace -> NodeId ('StructuringKind 'Measure 'PerformanceDimension)
traceMeasurePerformanceDimension = effectTraceMeasurePerformanceDimension

-- | Read the KPI used to observe the traced Situation anchor.
traceKPI :: EffectTrace -> NodeId ('PrimitiveKind 'Measure 'KPI)
traceKPI = effectTraceKPI

-- | Read the Situation changed and observed by the trace.
traceSituation :: EffectTrace -> ContextRef 'Situation
traceSituation = contextNodeToRef . effectTraceSituationNode

-- | Read the Situation anchor changed and measured by the trace.
traceSituationAnchor :: EffectTrace -> SomeSituationAnchorRef
traceSituationAnchor = effectTraceSituationAnchor

-- | Erase an existential Situation-anchor reference for runtime comparison.
situationAnchorRefId :: SomeSituationAnchorRef -> RawNodeId
situationAnchorRefId (SomeSituationAnchorRef identifier _) = unNodeId identifier

-- | Reify the anchor form of an existential Situation-anchor reference.
situationAnchorRefKind :: SomeSituationAnchorRef -> SituationAnchor
situationAnchorRefKind (SomeSituationAnchorRef _ anchor) = anchorValue anchor
