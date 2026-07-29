{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Private declarative rules for typed effect-trace derivation.
module O2I.Validation.Trace.Rule
  ( EffectTraceConstituentRule(..)
  , effectTraceConstituentAnchor
  , addressedNeedRule
  , effectTraceContextRule
  , effectTraceConstituentRule
  ) where

import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Types
import O2I.Validation.Trace.Types

-- | Closed static alternatives for Situation-anchor constituent proof.
data EffectTraceConstituentRule anchor where
  BusinessCapabilityConstituentRule
    :: EffectTraceConstituentRule 'BusinessCapability
  BusinessProcessConstituentRule :: EffectTraceConstituentRule 'BusinessProcess
  BusinessObjectConstituentRule :: EffectTraceConstituentRule 'BusinessObject
  ValueStreamConstituentRule :: EffectTraceConstituentRule 'ValueStream

-- | Recover the exact anchor witness selected by one constituent rule.
effectTraceConstituentAnchor ::
     EffectTraceConstituentRule anchor -> SSituationAnchor anchor
effectTraceConstituentAnchor rule =
  case rule of
    BusinessCapabilityConstituentRule -> SBusinessCapability
    BusinessProcessConstituentRule -> SBusinessProcess
    BusinessObjectConstituentRule -> SBusinessObject
    ValueStreamConstituentRule -> SValueStream

-- | Derive persisted Intervention-to-Need diagnostic pairs independently.
addressedNeedRule :: PreparedMacroEvidence -> CompiledPlan AddressedNeed
addressedNeedRule prepared =
  rootAtom
    (preparedContextDomain prepared SIntervention)
    addressesNeed
    (preparedContextDomain prepared SNeed) $ \_ _ addressed ->
    finish (projectOccurrence addressed addressedNeedFromOccurrence)

addressedNeedFromOccurrence ::
     ProjectedOccurrence ('ContextKind 'Intervention) ('ContextKind 'Need)
  -> AddressedNeed
addressedNeedFromOccurrence occurrence =
  AddressedNeed
    { addressedNeedIntervention = projectedOccurrenceFrom occurrence
    , addressedNeedNeed = projectedOccurrenceTo occurrence
    }

-- | Derive one connected nine-relation Context skeleton.
effectTraceContextRule ::
     PreparedMacroEvidence -> CompiledPlan EffectTraceContext
effectTraceContextRule prepared =
  rootAtom
    (preparedContextDomain prepared SIntervention)
    addressesNeed
    (preparedContextDomain prepared SNeed) $ \intervention need addressed ->
    extendBackward (preparedContextDomain prepared SStrategy) qualifiesNeed need $ \strategy qualifies ->
      constrainExisting strategy directsIntervention intervention $ \directs ->
        extendForward
          strategy
          framesMeasure
          (preparedContextDomain prepared SMeasure) $ \measure frames ->
          constrainExisting intervention setsTargetForMeasure measure $ \setsTarget ->
            extendForward
              measure
              measuresSituation
              (preparedContextDomain prepared SSituation) $ \situation measures ->
              constrainExisting intervention changesSituation situation $ \changes ->
                constrainExisting situation surfacesNeed need $ \surfaces ->
                  extendBackward
                    (preparedContextDomain prepared SVision)
                    orientsStrategy
                    strategy $ \_ orients ->
                    let p1 = projectOccurrence addressed contextFromOccurrences
                        p2 = appendOccurrence p1 qualifies
                        p3 = appendOccurrence p2 directs
                        p4 = appendOccurrence p3 frames
                        p5 = appendOccurrence p4 setsTarget
                        p6 = appendOccurrence p5 measures
                        p7 = appendOccurrence p6 changes
                        p8 = appendOccurrence p7 surfaces
                        p9 = appendOccurrence p8 orients
                     in finish p9

contextFromOccurrences ::
     ProjectedOccurrence ('ContextKind 'Intervention) ('ContextKind 'Need)
  -> ProjectedOccurrence ('ContextKind 'Strategy) ('ContextKind 'Need)
  -> ProjectedOccurrence ('ContextKind 'Strategy) ('ContextKind 'Intervention)
  -> ProjectedOccurrence ('ContextKind 'Strategy) ('ContextKind 'Measure)
  -> ProjectedOccurrence ('ContextKind 'Intervention) ('ContextKind 'Measure)
  -> ProjectedOccurrence ('ContextKind 'Measure) ('ContextKind 'Situation)
  -> ProjectedOccurrence ('ContextKind 'Intervention) ('ContextKind 'Situation)
  -> ProjectedOccurrence ('ContextKind 'Situation) ('ContextKind 'Need)
  -> ProjectedOccurrence ('ContextKind 'Vision) ('ContextKind 'Strategy)
  -> EffectTraceContext
contextFromOccurrences addressed qualifies _directs frames _setsTarget measures _changes _surfaces orients =
  EffectTraceContext
    { traceContextVision = projectedOccurrenceFrom orients
    , traceContextStrategy = projectedOccurrenceFrom qualifies
    , traceContextNeed = projectedOccurrenceTo addressed
    , traceContextIntervention = projectedOccurrenceFrom addressed
    , traceContextMeasure = projectedOccurrenceTo frames
    , traceContextSituation = projectedOccurrenceTo measures
    }

-- | Derive one owner-specific constituent proof for a Context skeleton.
effectTraceConstituentRule ::
     PreparedMacroEvidence
  -> EffectTraceContext
  -> EffectTraceConstituentRule anchor
  -> CompiledPlan (EffectTraceConstituents anchor)
effectTraceConstituentRule prepared context rule =
  rootAtom
    interventionKeyResults
    contributesInterventionKeyResultToStrategyKeyResult
    strategyKeyResults $ \interventionKeyResult strategyKeyResult interventionToStrategy ->
    extendBackward
      interventionActions
      contributesInterventionActionToKeyResult
      interventionKeyResult $ \interventionAction interventionActionToKeyResult ->
      extendBackward
        strategyActions
        guidesStrategyActionToInterventionAction
        interventionAction $ \strategyAction strategyGuidesInterventionAction ->
        constrainExisting
          strategyAction
          contributesStrategyActionToKeyResult
          strategyKeyResult $ \strategyActionToKeyResult ->
          extendForward
            strategyKeyResult
            substantiatesStrategyKeyResultObjective
            strategyObjectives $ \strategyObjective strategyKeyResultToObjective ->
            extendBackward
              strategyDrivers
              groundsStrategyDriverToObjective
              strategyObjective $ \strategyDriver strategyDriverToObjective ->
              extendBackward
                visionObjectives
                orientsVisionObjectiveToStrategyObjective
                strategyObjective $ \_ visionObjectiveToStrategyObjective ->
                extendForward
                  strategyKeyResult
                  translatesStrategyKeyResultToNeedObjective
                  needObjectives $ \needObjective strategyKeyResultToNeedObjective ->
                  extendBackward
                    needDrivers
                    groundsNeedDriverToObjective
                    needObjective $ \needDriver needDriverToObjective ->
                    constrainExisting
                      interventionKeyResult
                      substantiatesInterventionKeyResultNeedObjective
                      needObjective $ \interventionKeyResultToNeedObjective ->
                      extendForward
                        strategyDriver
                        indicatesMeasurePerformanceDimension
                        measureDimensions $ \measureDimension strategyDriverToDimension ->
                        constrainExisting
                          strategyKeyResult
                          determinesMeasurePerformanceDimension
                          measureDimension $ \strategyKeyResultToDimension ->
                          extendForward
                            measureDimension
                            (containsPerformanceDimension
                               MeasureMeasurementDimension)
                            measureKPIs $ \measureKPI dimensionContainsKPI ->
                            constrainExisting
                              interventionKeyResult
                              setsTargetForMeasureKPI
                              measureKPI $ \interventionKeyResultToKPI ->
                              extendForward
                                measureKPI
                                (measuresAnchor anchor)
                                anchors $ \anchorNode kpiMeasuresAnchor ->
                                constrainExisting
                                  interventionAction
                                  (changesAnchor anchor)
                                  anchorNode $ \interventionActionChangesAnchor ->
                                  constrainExisting
                                    anchorNode
                                    (anchorsNeedDriver anchor)
                                    needDriver $ \anchorAnchorsNeedDriver ->
                                    extendBackward
                                      situation
                                      (constitutedByAnchor anchor)
                                      anchorNode $ \_ situationConstitutedByAnchor ->
                                      let withInterventionToStrategy =
                                            projectOccurrence
                                              interventionToStrategy
                                              constituentsFromOccurrences
                                          withInterventionAction =
                                            appendOccurrence
                                              withInterventionToStrategy
                                              interventionActionToKeyResult
                                          withStrategyGuidance =
                                            appendOccurrence
                                              withInterventionAction
                                              strategyGuidesInterventionAction
                                          withStrategyActionContribution =
                                            appendOccurrence
                                              withStrategyGuidance
                                              strategyActionToKeyResult
                                          withStrategyResultEvidence =
                                            appendOccurrence
                                              withStrategyActionContribution
                                              strategyKeyResultToObjective
                                          withStrategyDiagnosis =
                                            appendOccurrence
                                              withStrategyResultEvidence
                                              strategyDriverToObjective
                                          withVisionOrientation =
                                            appendOccurrence
                                              withStrategyDiagnosis
                                              visionObjectiveToStrategyObjective
                                          withNeedTranslation =
                                            appendOccurrence
                                              withVisionOrientation
                                              strategyKeyResultToNeedObjective
                                          withNeedGrounding =
                                            appendOccurrence
                                              withNeedTranslation
                                              needDriverToObjective
                                          withNeedSubstantiation =
                                            appendOccurrence
                                              withNeedGrounding
                                              interventionKeyResultToNeedObjective
                                          withMeasurementIndication =
                                            appendOccurrence
                                              withNeedSubstantiation
                                              strategyDriverToDimension
                                          withMeasurementDetermination =
                                            appendOccurrence
                                              withMeasurementIndication
                                              strategyKeyResultToDimension
                                          withMeasuredKPI =
                                            appendOccurrence
                                              withMeasurementDetermination
                                              dimensionContainsKPI
                                          withKPITarget =
                                            appendOccurrence
                                              withMeasuredKPI
                                              interventionKeyResultToKPI
                                          withMeasuredAnchor =
                                            appendOccurrence
                                              withKPITarget
                                              kpiMeasuresAnchor
                                          withChangedAnchor =
                                            appendOccurrence
                                              withMeasuredAnchor
                                              interventionActionChangesAnchor
                                          withAnchoredNeed =
                                            appendOccurrence
                                              withChangedAnchor
                                              anchorAnchorsNeedDriver
                                          completeConstituentProof =
                                            appendOccurrence
                                              withAnchoredNeed
                                              situationConstitutedByAnchor
                                       in finish completeConstituentProof
  where
    anchor = effectTraceConstituentAnchor rule
    strategy = traceContextStrategy context
    need = traceContextNeed context
    intervention = traceContextIntervention context
    measure = traceContextMeasure context
    situation = singletonDomain (traceContextSituation context)
    interventionKeyResults =
      preparedOwnedPrimitiveDomain
        prepared
        intervention
        SIntervention
        SKeyResult
    strategyKeyResults =
      preparedStrategyRoleDomain prepared strategy StrategyKeyResultRole
    interventionActions =
      preparedOwnedPrimitiveDomain prepared intervention SIntervention SAction
    strategyActions =
      preparedStrategyRoleDomain prepared strategy StrategyCoherentActionRole
    strategyObjectives =
      preparedStrategyRoleDomain prepared strategy StrategyIntentRole
    strategyDrivers =
      preparedStrategyRoleDomain prepared strategy StrategyDiagnosisRole
    visionObjectives =
      preparedOwnedPrimitiveDomain
        prepared
        (traceContextVision context)
        SVision
        SObjective
    needObjectives = preparedOwnedPrimitiveDomain prepared need SNeed SObjective
    needDrivers = preparedOwnedPrimitiveDomain prepared need SNeed SDriver
    measureDimensions =
      preparedPerformanceDimensionDomain
        prepared
        measure
        MeasureMeasurementDimension
    measureKPIs = preparedOwnedPrimitiveDomain prepared measure SMeasure SKPI
    anchors =
      preparedSituationAnchorDomain
        prepared
        (traceContextSituation context)
        anchor

constituentsFromOccurrences ::
     ProjectedOccurrence
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Strategy 'KeyResult)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Intervention 'Action)
       ('PrimitiveKind 'Intervention 'KeyResult)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'Action)
       ('PrimitiveKind 'Intervention 'Action)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'Action)
       ('PrimitiveKind 'Strategy 'KeyResult)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('PrimitiveKind 'Strategy 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'Driver)
       ('PrimitiveKind 'Strategy 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Vision 'Objective)
       ('PrimitiveKind 'Strategy 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('PrimitiveKind 'Need 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Need 'Driver)
       ('PrimitiveKind 'Need 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Need 'Objective)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'Driver)
       ('StructuringKind 'Measure 'PerformanceDimension)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('StructuringKind 'Measure 'PerformanceDimension)
  -> ProjectedOccurrence
       ('StructuringKind 'Measure 'PerformanceDimension)
       ('PrimitiveKind 'Measure 'KPI)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Measure 'KPI)
  -> ProjectedOccurrence ('PrimitiveKind 'Measure 'KPI) ('AnchorKind anchor)
  -> ProjectedOccurrence
       ('PrimitiveKind 'Intervention 'Action)
       ('AnchorKind anchor)
  -> ProjectedOccurrence ('AnchorKind anchor) ('PrimitiveKind 'Need 'Driver)
  -> ProjectedOccurrence ('ContextKind 'Situation) ('AnchorKind anchor)
  -> EffectTraceConstituents anchor
constituentsFromOccurrences =
  \interventionToStrategy ->
    \interventionActionToKeyResult ->
      \strategyGuidesInterventionAction ->
        \_strategyActionToKeyResult ->
          \strategyKeyResultToObjective ->
            \strategyDriverToObjective ->
              \visionObjectiveToStrategyObjective ->
                \strategyKeyResultToNeedObjective ->
                  \needDriverToObjective ->
                    \_interventionKeyResultToNeedObjective ->
                      \strategyDriverToDimension ->
                        \_strategyKeyResultToDimension ->
                          \dimensionContainsKPI ->
                            \_interventionKeyResultToKPI ->
                              \kpiMeasuresAnchor ->
                                \_interventionActionChangesAnchor ->
                                  \_anchorAnchorsNeedDriver ->
                                    \_situationConstitutedByAnchor ->
                                      EffectTraceConstituents
                                        { constituentVisionObjective =
                                            projectedOccurrenceFrom
                                              visionObjectiveToStrategyObjective
                                        , constituentStrategyDriver =
                                            projectedOccurrenceFrom
                                              strategyDriverToObjective
                                        , constituentStrategyObjective =
                                            projectedOccurrenceTo
                                              strategyKeyResultToObjective
                                        , constituentStrategyKeyResult =
                                            projectedOccurrenceTo
                                              interventionToStrategy
                                        , constituentStrategyAction =
                                            projectedOccurrenceFrom
                                              strategyGuidesInterventionAction
                                        , constituentNeedDriver =
                                            projectedOccurrenceFrom
                                              needDriverToObjective
                                        , constituentNeedObjective =
                                            projectedOccurrenceTo
                                              strategyKeyResultToNeedObjective
                                        , constituentInterventionAction =
                                            projectedOccurrenceFrom
                                              interventionActionToKeyResult
                                        , constituentInterventionKeyResult =
                                            projectedOccurrenceFrom
                                              interventionToStrategy
                                        , constituentMeasurePerformanceDimension =
                                            projectedOccurrenceTo
                                              strategyDriverToDimension
                                        , constituentMeasureKPI =
                                            projectedOccurrenceTo
                                              dimensionContainsKPI
                                        , constituentSituationAnchor =
                                            projectedOccurrenceTo
                                              kpiMeasuresAnchor
                                        }

preparedContextDomain ::
     PreparedMacroEvidence -> SContext context -> Domain ('ContextKind context)
preparedContextDomain prepared context =
  nodeDomainFor (SContextKind context) (preparedRelationalIndex prepared)
