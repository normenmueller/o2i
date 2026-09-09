{-# LANGUAGE OverloadedStrings #-}

-- | Closed, companion-defined effect-trace grammar.
module O2I.Trace.Grammar
  ( TraceVariable(..)
  , traceVariables
  , traceVariableId
  , traceVariableEndpoint
  , TraceRelationSlot(..)
  , traceRelationSlots
  , traceRelationSlotId
  , traceRelationSlotVariables
  , traceRelationSlotToken
  , TraceOwnershipSlot(..)
  , traceOwnershipSlots
  , traceOwnershipSlotId
  , traceOwnershipSlotVariables
  , TraceSlot(..)
  , traceSlots
  , traceSlotId
  , traceSlotVariables
  , traceSlotRuleId
  , rootSlot
  ) where

import Data.Text (Text)
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreRelationToken
  , CoreRuleId
  )
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal
  ( CoreQualifiedEndpointId(..)
  , CoreRelationToken(..)
  , CoreRuleId(..)
  )

-- | Exact variable order of @traceSemantics.variableCatalog@.
data TraceVariable
  = VisionVariable
  | StrategyVariable
  | NeedVariable
  | InterventionVariable
  | MeasureVariable
  | SituationVariable
  | VisionObjectiveVariable
  | StrategyDriverVariable
  | StrategyObjectiveVariable
  | StrategyActionVariable
  | StrategyKeyResultVariable
  | NeedDriverVariable
  | NeedObjectiveVariable
  | InterventionActionVariable
  | InterventionKeyResultVariable
  | MeasurePerformanceDimensionVariable
  | MeasureKpiVariable
  | SituationAnchorVariable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Every fixed Trace variable in companion order.
traceVariables :: [TraceVariable]
traceVariables = [minBound .. maxBound]

-- | Stable machine identifier of one fixed variable.
traceVariableId :: TraceVariable -> Text
traceVariableId variable =
  case variable of
    VisionVariable -> "vision"
    StrategyVariable -> "strategy"
    NeedVariable -> "need"
    InterventionVariable -> "intervention"
    MeasureVariable -> "measure"
    SituationVariable -> "situation"
    VisionObjectiveVariable -> "visionObjective"
    StrategyDriverVariable -> "strategyDriver"
    StrategyObjectiveVariable -> "strategyObjective"
    StrategyActionVariable -> "strategyAction"
    StrategyKeyResultVariable -> "strategyKeyResult"
    NeedDriverVariable -> "needDriver"
    NeedObjectiveVariable -> "needObjective"
    InterventionActionVariable -> "interventionAction"
    InterventionKeyResultVariable -> "interventionKeyResult"
    MeasurePerformanceDimensionVariable -> "measurePerformanceDimension"
    MeasureKpiVariable -> "measureKpi"
    SituationAnchorVariable -> "situationAnchor"

traceVariableEndpoint :: TraceVariable -> [CoreQualifiedEndpointId]
traceVariableEndpoint variable =
  map endpoint
    $ case variable of
        VisionVariable -> [Generated.GeneratedEndpointContextVision]
        StrategyVariable -> [Generated.GeneratedEndpointContextStrategy]
        NeedVariable -> [Generated.GeneratedEndpointContextNeed]
        InterventionVariable -> [Generated.GeneratedEndpointContextIntervention]
        MeasureVariable -> [Generated.GeneratedEndpointContextMeasure]
        SituationVariable -> [Generated.GeneratedEndpointContextSituation]
        VisionObjectiveVariable ->
          [Generated.GeneratedEndpointPrimitiveVisionObjective]
        StrategyDriverVariable ->
          [Generated.GeneratedEndpointPrimitiveStrategyDriver]
        StrategyObjectiveVariable ->
          [Generated.GeneratedEndpointPrimitiveStrategyObjective]
        StrategyActionVariable ->
          [Generated.GeneratedEndpointPrimitiveStrategyAction]
        StrategyKeyResultVariable ->
          [Generated.GeneratedEndpointPrimitiveStrategyKeyResult]
        NeedDriverVariable -> [Generated.GeneratedEndpointPrimitiveNeedDriver]
        NeedObjectiveVariable ->
          [Generated.GeneratedEndpointPrimitiveNeedObjective]
        InterventionActionVariable ->
          [Generated.GeneratedEndpointPrimitiveInterventionAction]
        InterventionKeyResultVariable ->
          [Generated.GeneratedEndpointPrimitiveInterventionKeyResult]
        MeasurePerformanceDimensionVariable ->
          [Generated.GeneratedEndpointStructuringMeasurePerformanceDimension]
        MeasureKpiVariable -> [Generated.GeneratedEndpointPrimitiveMeasureKpi]
        SituationAnchorVariable ->
          [ Generated.GeneratedEndpointSituationAnchorBusinessCapability
          , Generated.GeneratedEndpointSituationAnchorBusinessObject
          , Generated.GeneratedEndpointSituationAnchorBusinessProcess
          , Generated.GeneratedEndpointSituationAnchorValueStream
          ]
  where
    endpoint = CoreQualifiedEndpointId

-- | Exact relation-slot order of the companion.
data TraceRelationSlot
  = InterventionAddressesNeed
  | StrategyQualifiesNeed
  | StrategyDirectsIntervention
  | VisionOrientsStrategy
  | StrategyFramesMeasure
  | InterventionSetsTargetForMeasure
  | InterventionChangesSituation
  | MeasureMeasuresSituation
  | SituationSurfacesNeed
  | NeedDriverGroundsNeedObjective
  | StrategyKeyResultTranslatesIntoNeedObjective
  | StrategyDriverGroundsStrategyObjective
  | VisionObjectiveOrientsStrategyObjective
  | StrategyKeyResultSubstantiatesStrategyObjective
  | StrategyActionContributesToStrategyKeyResult
  | StrategyActionGuidesInterventionAction
  | InterventionActionContributesToInterventionKeyResult
  | InterventionKeyResultContributesToStrategyKeyResult
  | InterventionKeyResultSubstantiatesNeedObjective
  | StrategyDriverIndicatesMeasurePerformanceDimension
  | StrategyKeyResultDeterminesMeasurePerformanceDimension
  | MeasurePerformanceDimensionContainsMeasureKpi
  | InterventionKeyResultSetsTargetForMeasureKpi
  | MeasureKpiMeasuresSituationAnchor
  | InterventionActionChangesSameSituationAnchor
  | SituationAnchorAnchorsNeedDriver
  | SituationIsConstitutedBySameSituationAnchor
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Every fixed relation slot in companion order.
traceRelationSlots :: [TraceRelationSlot]
traceRelationSlots = [minBound .. maxBound]

-- | Stable machine identifier of one relation slot.
traceRelationSlotId :: TraceRelationSlot -> Text
traceRelationSlotId slot =
  case slot of
    InterventionAddressesNeed -> "intervention-addresses-need"
    StrategyQualifiesNeed -> "strategy-qualifies-need"
    StrategyDirectsIntervention -> "strategy-directs-intervention"
    VisionOrientsStrategy -> "vision-orients-strategy"
    StrategyFramesMeasure -> "strategy-frames-measure"
    InterventionSetsTargetForMeasure -> "intervention-sets-target-for-measure"
    InterventionChangesSituation -> "intervention-changes-situation"
    MeasureMeasuresSituation -> "measure-measures-situation"
    SituationSurfacesNeed -> "situation-surfaces-need"
    NeedDriverGroundsNeedObjective -> "need-driver-grounds-need-objective"
    StrategyKeyResultTranslatesIntoNeedObjective ->
      "strategy-key-result-translates-into-need-objective"
    StrategyDriverGroundsStrategyObjective ->
      "strategy-driver-grounds-strategy-objective"
    VisionObjectiveOrientsStrategyObjective ->
      "vision-objective-orients-strategy-objective"
    StrategyKeyResultSubstantiatesStrategyObjective ->
      "strategy-key-result-substantiates-strategy-objective"
    StrategyActionContributesToStrategyKeyResult ->
      "strategy-action-contributes-to-strategy-key-result"
    StrategyActionGuidesInterventionAction ->
      "strategy-action-guides-intervention-action"
    InterventionActionContributesToInterventionKeyResult ->
      "intervention-action-contributes-to-intervention-key-result"
    InterventionKeyResultContributesToStrategyKeyResult ->
      "intervention-key-result-contributes-to-strategy-key-result"
    InterventionKeyResultSubstantiatesNeedObjective ->
      "intervention-key-result-substantiates-need-objective"
    StrategyDriverIndicatesMeasurePerformanceDimension ->
      "strategy-driver-indicates-measure-performance-dimension"
    StrategyKeyResultDeterminesMeasurePerformanceDimension ->
      "strategy-key-result-determines-measure-performance-dimension"
    MeasurePerformanceDimensionContainsMeasureKpi ->
      "measure-performance-dimension-contains-measure-kpi"
    InterventionKeyResultSetsTargetForMeasureKpi ->
      "intervention-key-result-sets-target-for-measure-kpi"
    MeasureKpiMeasuresSituationAnchor -> "measure-kpi-measures-situation-anchor"
    InterventionActionChangesSameSituationAnchor ->
      "intervention-action-changes-same-situation-anchor"
    SituationAnchorAnchorsNeedDriver -> "situation-anchor-anchors-need-driver"
    SituationIsConstitutedBySameSituationAnchor ->
      "situation-is-constituted-by-same-situation-anchor"

traceRelationSlotVariables ::
     TraceRelationSlot -> (TraceVariable, TraceVariable)
traceRelationSlotVariables slot =
  case slot of
    InterventionAddressesNeed -> (InterventionVariable, NeedVariable)
    StrategyQualifiesNeed -> (StrategyVariable, NeedVariable)
    StrategyDirectsIntervention -> (StrategyVariable, InterventionVariable)
    VisionOrientsStrategy -> (VisionVariable, StrategyVariable)
    StrategyFramesMeasure -> (StrategyVariable, MeasureVariable)
    InterventionSetsTargetForMeasure -> (InterventionVariable, MeasureVariable)
    InterventionChangesSituation -> (InterventionVariable, SituationVariable)
    MeasureMeasuresSituation -> (MeasureVariable, SituationVariable)
    SituationSurfacesNeed -> (SituationVariable, NeedVariable)
    NeedDriverGroundsNeedObjective ->
      (NeedDriverVariable, NeedObjectiveVariable)
    StrategyKeyResultTranslatesIntoNeedObjective ->
      (StrategyKeyResultVariable, NeedObjectiveVariable)
    StrategyDriverGroundsStrategyObjective ->
      (StrategyDriverVariable, StrategyObjectiveVariable)
    VisionObjectiveOrientsStrategyObjective ->
      (VisionObjectiveVariable, StrategyObjectiveVariable)
    StrategyKeyResultSubstantiatesStrategyObjective ->
      (StrategyKeyResultVariable, StrategyObjectiveVariable)
    StrategyActionContributesToStrategyKeyResult ->
      (StrategyActionVariable, StrategyKeyResultVariable)
    StrategyActionGuidesInterventionAction ->
      (StrategyActionVariable, InterventionActionVariable)
    InterventionActionContributesToInterventionKeyResult ->
      (InterventionActionVariable, InterventionKeyResultVariable)
    InterventionKeyResultContributesToStrategyKeyResult ->
      (InterventionKeyResultVariable, StrategyKeyResultVariable)
    InterventionKeyResultSubstantiatesNeedObjective ->
      (InterventionKeyResultVariable, NeedObjectiveVariable)
    StrategyDriverIndicatesMeasurePerformanceDimension ->
      (StrategyDriverVariable, MeasurePerformanceDimensionVariable)
    StrategyKeyResultDeterminesMeasurePerformanceDimension ->
      (StrategyKeyResultVariable, MeasurePerformanceDimensionVariable)
    MeasurePerformanceDimensionContainsMeasureKpi ->
      (MeasurePerformanceDimensionVariable, MeasureKpiVariable)
    InterventionKeyResultSetsTargetForMeasureKpi ->
      (InterventionKeyResultVariable, MeasureKpiVariable)
    MeasureKpiMeasuresSituationAnchor ->
      (MeasureKpiVariable, SituationAnchorVariable)
    InterventionActionChangesSameSituationAnchor ->
      (InterventionActionVariable, SituationAnchorVariable)
    SituationAnchorAnchorsNeedDriver ->
      (SituationAnchorVariable, NeedDriverVariable)
    SituationIsConstitutedBySameSituationAnchor ->
      (SituationVariable, SituationAnchorVariable)

traceRelationSlotToken :: TraceRelationSlot -> CoreRelationToken
traceRelationSlotToken slot =
  CoreRelationToken
    $ case slot of
        InterventionAddressesNeed -> Generated.GeneratedTokenAddresses
        StrategyQualifiesNeed -> Generated.GeneratedTokenQualifies
        StrategyDirectsIntervention -> Generated.GeneratedTokenDirects
        VisionOrientsStrategy -> Generated.GeneratedTokenOrients
        StrategyFramesMeasure -> Generated.GeneratedTokenFrames
        InterventionSetsTargetForMeasure ->
          Generated.GeneratedTokenSetsTargetFor
        InterventionChangesSituation -> Generated.GeneratedTokenChanges
        MeasureMeasuresSituation -> Generated.GeneratedTokenMeasures
        SituationSurfacesNeed -> Generated.GeneratedTokenSurfaces
        NeedDriverGroundsNeedObjective -> Generated.GeneratedTokenGrounds
        StrategyKeyResultTranslatesIntoNeedObjective ->
          Generated.GeneratedTokenTranslatesInto
        StrategyDriverGroundsStrategyObjective ->
          Generated.GeneratedTokenGrounds
        VisionObjectiveOrientsStrategyObjective ->
          Generated.GeneratedTokenOrients
        StrategyKeyResultSubstantiatesStrategyObjective ->
          Generated.GeneratedTokenSubstantiates
        StrategyActionContributesToStrategyKeyResult ->
          Generated.GeneratedTokenContributesTo
        StrategyActionGuidesInterventionAction -> Generated.GeneratedTokenGuides
        InterventionActionContributesToInterventionKeyResult ->
          Generated.GeneratedTokenContributesTo
        InterventionKeyResultContributesToStrategyKeyResult ->
          Generated.GeneratedTokenContributesTo
        InterventionKeyResultSubstantiatesNeedObjective ->
          Generated.GeneratedTokenSubstantiates
        StrategyDriverIndicatesMeasurePerformanceDimension ->
          Generated.GeneratedTokenIndicates
        StrategyKeyResultDeterminesMeasurePerformanceDimension ->
          Generated.GeneratedTokenDetermines
        MeasurePerformanceDimensionContainsMeasureKpi ->
          Generated.GeneratedTokenContains
        InterventionKeyResultSetsTargetForMeasureKpi ->
          Generated.GeneratedTokenSetsTargetFor
        MeasureKpiMeasuresSituationAnchor -> Generated.GeneratedTokenMeasures
        InterventionActionChangesSameSituationAnchor ->
          Generated.GeneratedTokenChanges
        SituationAnchorAnchorsNeedDriver -> Generated.GeneratedTokenAnchors
        SituationIsConstitutedBySameSituationAnchor ->
          Generated.GeneratedTokenIsConstitutedBy

-- | Exact ownership-slot order of the companion.
data TraceOwnershipSlot
  = VisionObjectiveAtVision
  | StrategyDriverAtStrategy
  | StrategyObjectiveAtStrategy
  | StrategyActionAtStrategy
  | StrategyKeyResultAtStrategy
  | NeedDriverAtNeed
  | NeedObjectiveAtNeed
  | InterventionActionAtIntervention
  | InterventionKeyResultAtIntervention
  | MeasurePerformanceDimensionAtMeasure
  | MeasureKpiAtMeasure
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Every fixed ownership slot in companion order.
traceOwnershipSlots :: [TraceOwnershipSlot]
traceOwnershipSlots = [minBound .. maxBound]

-- | Stable machine identifier of one ownership slot.
traceOwnershipSlotId :: TraceOwnershipSlot -> Text
traceOwnershipSlotId slot =
  case slot of
    VisionObjectiveAtVision -> "vision-objective-at-vision"
    StrategyDriverAtStrategy -> "strategy-driver-at-strategy"
    StrategyObjectiveAtStrategy -> "strategy-objective-at-strategy"
    StrategyActionAtStrategy -> "strategy-action-at-strategy"
    StrategyKeyResultAtStrategy -> "strategy-key-result-at-strategy"
    NeedDriverAtNeed -> "need-driver-at-need"
    NeedObjectiveAtNeed -> "need-objective-at-need"
    InterventionActionAtIntervention -> "intervention-action-at-intervention"
    InterventionKeyResultAtIntervention ->
      "intervention-key-result-at-intervention"
    MeasurePerformanceDimensionAtMeasure ->
      "measure-performance-dimension-at-measure"
    MeasureKpiAtMeasure -> "measure-kpi-at-measure"

-- | Return context first and member second, matching bound-endpoint order.
traceOwnershipSlotVariables ::
     TraceOwnershipSlot -> (TraceVariable, TraceVariable)
traceOwnershipSlotVariables slot =
  case slot of
    VisionObjectiveAtVision -> (VisionVariable, VisionObjectiveVariable)
    StrategyDriverAtStrategy -> (StrategyVariable, StrategyDriverVariable)
    StrategyObjectiveAtStrategy -> (StrategyVariable, StrategyObjectiveVariable)
    StrategyActionAtStrategy -> (StrategyVariable, StrategyActionVariable)
    StrategyKeyResultAtStrategy -> (StrategyVariable, StrategyKeyResultVariable)
    NeedDriverAtNeed -> (NeedVariable, NeedDriverVariable)
    NeedObjectiveAtNeed -> (NeedVariable, NeedObjectiveVariable)
    InterventionActionAtIntervention ->
      (InterventionVariable, InterventionActionVariable)
    InterventionKeyResultAtIntervention ->
      (InterventionVariable, InterventionKeyResultVariable)
    MeasurePerformanceDimensionAtMeasure ->
      (MeasureVariable, MeasurePerformanceDimensionVariable)
    MeasureKpiAtMeasure -> (MeasureVariable, MeasureKpiVariable)

-- | Closed union of the 27 relation and 11 ownership slots.
data TraceSlot
  = RelationTraceSlot !TraceRelationSlot
  | OwnershipTraceSlot !TraceOwnershipSlot
  deriving (Eq, Ord, Show)

-- | All 38 fixed Trace slots in exact evaluation order.
traceSlots :: [TraceSlot]
traceSlots =
  map RelationTraceSlot traceRelationSlots
    ++ map OwnershipTraceSlot traceOwnershipSlots

-- | Stable machine identifier of one fixed slot.
traceSlotId :: TraceSlot -> Text
traceSlotId slot =
  case slot of
    RelationTraceSlot relationSlot -> traceRelationSlotId relationSlot
    OwnershipTraceSlot ownershipSlot -> traceOwnershipSlotId ownershipSlot

traceSlotVariables :: TraceSlot -> (TraceVariable, TraceVariable)
traceSlotVariables slot =
  case slot of
    RelationTraceSlot relationSlot -> traceRelationSlotVariables relationSlot
    OwnershipTraceSlot ownershipSlot ->
      traceOwnershipSlotVariables ownershipSlot

-- | Core rule identifier that owns one fixed slot.
traceSlotRuleId :: TraceSlot -> CoreRuleId
traceSlotRuleId slot =
  CoreRuleId
    (case slot of
       RelationTraceSlot _ -> "core.trace.slot." <> traceSlotId slot
       OwnershipTraceSlot _ -> "core.trace.ownership." <> traceSlotId slot)

rootSlot :: TraceRelationSlot
rootSlot = InterventionAddressesNeed
