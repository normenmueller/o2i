-- | Validation rules over the generic concrete O2I model graph.
module O2I.Validation
  ( wfModel
  , validEffectModel
  , hasCompleteEffectTraceForIntervention
  , wfPrimitivePlacement
  , wfStructuringPlacement
  , wfAnchorPlacement
  , wfEdge
  , wfContextEvidence
  , wfIntervention
  , effRelevant
  , visibleInSituation
  , qualifiedByStrategy
  , effectTrace
  , anyEffectTraceEvidence
  ) where

import O2I.Elements
import O2I.Graph
import O2I.Relation

-- * Validation
wfModel :: Model -> Bool
wfModel m =
  uniqueIds (contextIds m)
    && uniqueIds (primitiveIds m)
    && uniqueIds (structuringIds m)
    && uniqueIds (anchorIds m)
    && all (wfPrimitivePlacement m) (primitiveNodes m)
    && all (wfStructuringPlacement m) (structuringNodes m)
    && all (wfAnchorPlacement m) (anchorNodes m)
    && all (wfEdge m) (edges m)
    && all (wfContextEvidence m) (edges m)

validEffectModel :: Model -> Bool
validEffectModel m =
  wfModel m && all (hasCompleteEffectTraceForIntervention m) (interventionIds m)

hasCompleteEffectTraceForIntervention :: Model -> ContextId -> Bool
hasCompleteEffectTraceForIntervention m intervention =
  wfIntervention m intervention
    && all
         (hasCompleteEffectTraceForInterventionNeed m intervention)
         (addressedNeeds m intervention)

hasCompleteEffectTraceForInterventionNeed ::
     Model -> ContextId -> ContextId -> Bool
hasCompleteEffectTraceForInterventionNeed m intervention need =
  any
    (\strategy ->
       any
         (\measure ->
            any
              (effectTrace m strategy need intervention measure)
              (situationIds m))
         (measureIds m))
    (strategyIds m)

wfPrimitivePlacement :: Model -> PrimitiveNode -> Bool
wfPrimitivePlacement m (PrimitiveNode _ c p) =
  maybe False (`allowedInterpretation` p) (contextKind m c)

wfStructuringPlacement :: Model -> StructuringNode -> Bool
wfStructuringPlacement m (StructuringNode _ c Domain) =
  contextKind m c `elem` [Just Strategy, Just Measure]

wfAnchorPlacement :: Model -> AnchorNode -> Bool
wfAnchorPlacement m (AnchorNode _ c _) = contextKind m c == Just Situation

wfEdge :: Model -> Edge -> Bool
wfEdge m (Edge from rel to) =
  case (nodeKindValue m from, nodeKindValue m to) of
    (Just fromKind, Just toKind) ->
      relationDomain rel `matchesDomain` (fromKind, toKind)
    _ -> False

wfContextEvidence :: Model -> Edge -> Bool
wfContextEvidence m (Edge (CtxRef from) rel (CtxRef to)) =
  case contextRelationDomain rel of
    Just (fromKind, toKind)
      | contextKind m from == Just fromKind && contextKind m to == Just toKind ->
        hasContextEvidence m from rel to
    _ -> True
wfContextEvidence _ _ = True

wfIntervention :: Model -> ContextId -> Bool
wfIntervention m intervention = not (null needs) && all (effRelevant m) needs
  where
    needs = addressedNeeds m intervention

effRelevant :: Model -> ContextId -> Bool
effRelevant m need = visibleInSituation m need && qualifiedByStrategy m need

visibleInSituation :: Model -> ContextId -> Bool
visibleInSituation m need = any surfacesWithEvidence (situationIds m)
  where
    surfacesWithEvidence situation =
      hasEdge m (CtxRef situation) (SomeRelation SurfacesNeed) (CtxRef need)
        && hasSurfacesNeedEvidence m situation need

qualifiedByStrategy :: Model -> ContextId -> Bool
qualifiedByStrategy m need = any qualifiesNeed (strategyIds m)
  where
    qualifiesNeed strategy =
      hasEdge m (CtxRef strategy) (SomeRelation QualifiesNeed) (CtxRef need)
        && hasQualifiesNeedEvidence m strategy need

-- ** Effect trace
effectTrace ::
     Model
  -> ContextId
  -> ContextId
  -> ContextId
  -> ContextId
  -> ContextId
  -> Bool
effectTrace m strategy need intervention measure situation =
  wfModel m
    && effRelevant m need
    && hasEdge m (CtxRef strategy) (SomeRelation QualifiesNeed) (CtxRef need)
    && hasEdge
         m
         (CtxRef strategy)
         (SomeRelation DirectsIntervention)
         (CtxRef intervention)
    && hasEdge
         m
         (CtxRef intervention)
         (SomeRelation AddressesNeed)
         (CtxRef need)
    && hasEdge
         m
         (CtxRef intervention)
         (SomeRelation ChangesSituation)
         (CtxRef situation)
    && hasEdge
         m
         (CtxRef intervention)
         (SomeRelation SetsTargetForMeasure)
         (CtxRef measure)
    && hasEdge
         m
         (CtxRef measure)
         (SomeRelation MeasuresSituation)
         (CtxRef situation)
    && hasEdge m (CtxRef strategy) (SomeRelation FramesMeasure) (CtxRef measure)
    && hasEdge m (CtxRef situation) (SomeRelation SurfacesNeed) (CtxRef need)
    && hasSurfacesNeedEvidence m situation need
    && anyEffectTraceEvidence m strategy need intervention measure situation

anyEffectTraceEvidence ::
     Model
  -> ContextId
  -> ContextId
  -> ContextId
  -> ContextId
  -> ContextId
  -> Bool
anyEffectTraceEvidence m strategy need intervention measure situation =
  any strategyDriverTrace (primitiveRefsInContext m strategy Driver)
  where
    strategyDriverTrace sdrv =
      any
        (strategyObjectiveTrace sdrv)
        (primitiveRefsInContext m strategy Objective)
    strategyObjectiveTrace sdrv sobj =
      hasEdge m sdrv (SomeRelation GroundsStrategyDriverToObjective) sobj
        && any
             (strategyKeyResultTrace sdrv sobj)
             (primitiveRefsInContext m strategy KeyResult)
    strategyKeyResultTrace sdrv sobj skr =
      hasEdge m skr (SomeRelation SubstantiatesStrategyKeyResultObjective) sobj
        && any (needDriverTrace sdrv skr) (primitiveRefsInContext m need Driver)
    needDriverTrace sdrv skr ndr =
      any
        (needObjectiveTrace sdrv skr ndr)
        (primitiveRefsInContext m need Objective)
    needObjectiveTrace sdrv skr ndr nobj =
      hasEdge m ndr (SomeRelation GroundsNeedDriverToObjective) nobj
        && hasEdge
             m
             skr
             (SomeRelation TranslatesStrategyKeyResultToNeedObjective)
             nobj
        && any
             (interventionKeyResultTrace sdrv skr ndr nobj)
             (primitiveRefsInContext m intervention KeyResult)
    interventionKeyResultTrace sdrv skr ndr nobj ikr =
      hasEdge
        m
        ikr
        (SomeRelation SubstantiatesInterventionKeyResultNeedObjective)
        nobj
        && hasEdge
             m
             ikr
             (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult)
             skr
        && any
             (measureDomainTrace sdrv skr ndr ikr)
             (structuringRefsInContext m measure Domain)
    measureDomainTrace sdrv skr ndr ikr domain =
      hasEdge m sdrv (SomeRelation IndicatesMeasureDomain) domain
        && hasEdge m skr (SomeRelation DeterminesMeasureDomain) domain
        && any
             (kpiTrace skr ndr ikr domain)
             (primitiveRefsInContext m measure KPI)
    kpiTrace skr ndr ikr domain kpi =
      hasEdge m domain (SomeRelation ContainsMeasureKPI) kpi
        && hasEdge m ikr (SomeRelation SetsTargetForMeasureKPI) kpi
        && any (anchorTrace skr ndr ikr kpi) (anchorRefsInContext m situation)
    anchorTrace skr ndr ikr kpi anchor =
      hasEdge m (CtxRef situation) (SomeRelation ConstitutedByAnchor) anchor
        && hasEdge m anchor (SomeRelation AnchorsNeedDriver) ndr
        && hasEdge m kpi (SomeRelation MeasuresAnchor) anchor
        && any
             (interventionActionTrace skr ikr anchor)
             (primitiveRefsInContext m intervention Action)
    interventionActionTrace skr ikr anchor ia =
      hasEdge m ia (SomeRelation ChangesAnchor) anchor
        && hasEdge
             m
             ia
             (SomeRelation ContributesInterventionActionToKeyResult)
             ikr
        && any
             (strategyActionTrace skr ia)
             (primitiveRefsInContext m strategy Action)
    strategyActionTrace skr ia sa =
      hasEdge m sa (SomeRelation GuidesStrategyActionToInterventionAction) ia
        && hasEdge m sa (SomeRelation ContributesStrategyActionToKeyResult) skr

-- * Validation support
uniqueIds :: Eq a => [a] -> Bool
uniqueIds [] = True
uniqueIds (x:xs) = x `notElem` xs && uniqueIds xs

contextRelationDomain :: SomeRelation -> Maybe (Context, Context)
contextRelationDomain rel =
  case relationDomain rel of
    (Exact (ContextNodeKind from), Exact (ContextNodeKind to)) ->
      Just (from, to)
    _ -> Nothing

-- * Evidence patterns
hasContextEvidence :: Model -> ContextId -> SomeRelation -> ContextId -> Bool
hasContextEvidence m from rel to
  | rel == SomeRelation GuidesMission = hasGuidesMissionEvidence m from to
  | rel == SomeRelation GuidesVision = hasGuidesVisionEvidence m from to
  | rel == SomeRelation GroundsVision = hasGroundsVisionEvidence m from to
  | rel == SomeRelation OrientsStrategy = hasOrientsStrategyEvidence m from to
  | rel == SomeRelation DirectsStrategy = hasDirectsStrategyEvidence m from to
  | rel == SomeRelation ContributesToStrategy =
    hasContributesToStrategyEvidence m from to
  | rel == SomeRelation QualifiesNeed = hasQualifiesNeedEvidence m from to
  | rel == SomeRelation SurfacesNeed = hasSurfacesNeedEvidence m from to
  | rel == SomeRelation AddressesNeed = hasAddressesNeedEvidence m from to
  | rel == SomeRelation DirectsIntervention =
    hasDirectsInterventionEvidence m from to
  | rel == SomeRelation ChangesSituation = hasChangesSituationEvidence m from to
  | rel == SomeRelation SetsTargetForMeasure =
    hasSetsTargetForMeasureEvidence m from to
  | rel == SomeRelation MeasuresSituation =
    hasMeasuresSituationEvidence m from to
  | rel == SomeRelation FramesMeasure = hasFramesMeasureEvidence m from to
  | otherwise = True

hasGuidesMissionEvidence :: Model -> ContextId -> ContextId -> Bool
hasGuidesMissionEvidence m ethos mission =
  anyEdge
    m
    (primitiveRefsInContext m ethos Principle)
    (SomeRelation GuidesEthosPrincipleToMissionDriver)
    (primitiveRefsInContext m mission Driver)

hasGuidesVisionEvidence :: Model -> ContextId -> ContextId -> Bool
hasGuidesVisionEvidence m ethos vision =
  anyEdge
    m
    (primitiveRefsInContext m ethos Principle)
    (SomeRelation GuidesEthosPrincipleToVisionObjective)
    (primitiveRefsInContext m vision Objective)

hasGroundsVisionEvidence :: Model -> ContextId -> ContextId -> Bool
hasGroundsVisionEvidence m mission vision =
  anyEdge
    m
    (primitiveRefsInContext m mission Driver)
    (SomeRelation GroundsMissionDriverToVisionObjective)
    (primitiveRefsInContext m vision Objective)

hasOrientsStrategyEvidence :: Model -> ContextId -> ContextId -> Bool
hasOrientsStrategyEvidence m vision strategy =
  anyEdge
    m
    (primitiveRefsInContext m vision Objective)
    (SomeRelation OrientsVisionObjectiveToStrategyObjective)
    (primitiveRefsInContext m strategy Objective)

hasDirectsStrategyEvidence :: Model -> ContextId -> ContextId -> Bool
hasDirectsStrategyEvidence m higher lower =
  anyEdge
    m
    (primitiveRefsInContext m higher Principle)
    (SomeRelation GuidesStrategyPrincipleToPrinciple)
    (primitiveRefsInContext m lower Principle)

hasContributesToStrategyEvidence :: Model -> ContextId -> ContextId -> Bool
hasContributesToStrategyEvidence m lower higher =
  anyEdge
    m
    (primitiveRefsInContext m lower KeyResult)
    (SomeRelation ContributesStrategyKeyResultToKeyResult)
    (primitiveRefsInContext m higher KeyResult)
    || anyEdge
         m
         (primitiveRefsInContext m lower Action)
         (SomeRelation ContributesStrategyActionToAction)
         (primitiveRefsInContext m higher Action)

hasQualifiesNeedEvidence :: Model -> ContextId -> ContextId -> Bool
hasQualifiesNeedEvidence m strategy need =
  anyEdge
    m
    (primitiveRefsInContext m strategy KeyResult)
    (SomeRelation TranslatesStrategyKeyResultToNeedObjective)
    (primitiveRefsInContext m need Objective)

hasSurfacesNeedEvidence :: Model -> ContextId -> ContextId -> Bool
hasSurfacesNeedEvidence m situation need =
  any
    (\anchor ->
       hasEdge m (CtxRef situation) (SomeRelation ConstitutedByAnchor) anchor
         && anyEdge
              m
              [anchor]
              (SomeRelation AnchorsNeedDriver)
              (primitiveRefsInContext m need Driver))
    (anchorRefsInContext m situation)

hasAddressesNeedEvidence :: Model -> ContextId -> ContextId -> Bool
hasAddressesNeedEvidence m intervention need =
  anyEdge
    m
    (primitiveRefsInContext m intervention KeyResult)
    (SomeRelation SubstantiatesInterventionKeyResultNeedObjective)
    (primitiveRefsInContext m need Objective)

hasDirectsInterventionEvidence :: Model -> ContextId -> ContextId -> Bool
hasDirectsInterventionEvidence m strategy intervention =
  anyEdge
    m
    (primitiveRefsInContext m strategy Action)
    (SomeRelation GuidesStrategyActionToInterventionAction)
    (primitiveRefsInContext m intervention Action)

hasChangesSituationEvidence :: Model -> ContextId -> ContextId -> Bool
hasChangesSituationEvidence m intervention situation =
  any
    (\anchor ->
       hasEdge m (CtxRef situation) (SomeRelation ConstitutedByAnchor) anchor
         && anyEdge
              m
              (primitiveRefsInContext m intervention Action)
              (SomeRelation ChangesAnchor)
              [anchor])
    (anchorRefsInContext m situation)

hasSetsTargetForMeasureEvidence :: Model -> ContextId -> ContextId -> Bool
hasSetsTargetForMeasureEvidence m intervention measure =
  anyEdge
    m
    (primitiveRefsInContext m intervention KeyResult)
    (SomeRelation SetsTargetForMeasureKPI)
    (primitiveRefsInContext m measure KPI)

hasMeasuresSituationEvidence :: Model -> ContextId -> ContextId -> Bool
hasMeasuresSituationEvidence m measure situation =
  any
    (\anchor ->
       hasEdge m (CtxRef situation) (SomeRelation ConstitutedByAnchor) anchor
         && anyEdge
              m
              (primitiveRefsInContext m measure KPI)
              (SomeRelation MeasuresAnchor)
              [anchor])
    (anchorRefsInContext m situation)

hasFramesMeasureEvidence :: Model -> ContextId -> ContextId -> Bool
hasFramesMeasureEvidence m strategy measure =
  any
    (\domain ->
       hasIndicatedMeasureDomain m strategy domain
         && anyEdge
              m
              (primitiveRefsInContext m strategy KeyResult)
              (SomeRelation DeterminesMeasureDomain)
              [domain]
         && anyEdge
              m
              [domain]
              (SomeRelation ContainsMeasureKPI)
              (primitiveRefsInContext m measure KPI))
    (structuringRefsInContext m measure Domain)

hasIndicatedMeasureDomain :: Model -> ContextId -> NodeRef -> Bool
hasIndicatedMeasureDomain m strategy domain =
  anyEdge
    m
    (primitiveRefsInContext m strategy Driver)
    (SomeRelation IndicatesMeasureDomain)
    [domain]

anyEdge :: Model -> [NodeRef] -> SomeRelation -> [NodeRef] -> Bool
anyEdge m fromRefs rel toRefs =
  any (\from -> any (\to -> hasEdge m from rel to) toRefs) fromRefs
