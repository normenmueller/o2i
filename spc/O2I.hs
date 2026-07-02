{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

module O2I where

newtype ContextId =
  ContextId String
  deriving (Eq, Show)

newtype PrimitiveId =
  PrimitiveId String
  deriving (Eq, Show)

newtype StructuringId =
  StructuringId String
  deriving (Eq, Show)

newtype AnchorId =
  AnchorId String
  deriving (Eq, Show)

-- * Types
-- ** Contexts
data Context
  = Ethos
  | Mission
  | Vision
  | Strategy
  | Situation
  | Need
  | Intervention
  | Measure
  deriving (Eq, Show)

-- ** Primitives
data Primitive
  = Principle
  | Driver
  | Objective
  | KeyResult
  | KPI
  | Action
  deriving (Eq, Show)

-- ** Structuring
data Structuring =
  Domain
  deriving (Eq, Show)

-- ** Situation anchors
data SituationAnchor
  = BusinessCapability
  | BusinessProcess
  | BusinessObject
  | BusinessRole
  | ValueStream
  | RegulatoryConstraint
  deriving (Eq, Show)

-- ** Node kinds
data NodeKind
  = ContextKind Context
  | PrimitiveKind Context Primitive
  | StructuringKind Context Structuring
  | AnchorKind SituationAnchor

-- ** Typed instances
newtype Ctx (c :: Context) =
  Ctx ContextId

newtype Prim (c :: Context) (p :: Primitive) =
  Prim PrimitiveId

newtype Struct (c :: Context) (s :: Structuring) =
  Struct StructuringId

newtype Anchor (a :: SituationAnchor) =
  Anchor AnchorId

-- * Type-level relations
-- ** Semantic relations
data Relation (from :: NodeKind) (to :: NodeKind)
  -- *** Context macrorelations
 where
  GuidesMission :: Relation (ContextKind Ethos) (ContextKind Mission)
  GroundsVision :: Relation (ContextKind Mission) (ContextKind Vision)
  GuidesVision :: Relation (ContextKind Ethos) (ContextKind Vision)
  OrientsStrategy :: Relation (ContextKind Vision) (ContextKind Strategy)
  DirectsStrategy :: Relation (ContextKind Strategy) (ContextKind Strategy)
  ContributesToStrategy
    :: Relation (ContextKind Strategy) (ContextKind Strategy)
  QualifiesNeed :: Relation (ContextKind Strategy) (ContextKind Need)
  SurfacesNeed :: Relation (ContextKind Situation) (ContextKind Need)
  AddressesNeed :: Relation (ContextKind Intervention) (ContextKind Need)
  DirectsIntervention
    :: Relation (ContextKind Strategy) (ContextKind Intervention)
  ChangesSituation
    :: Relation (ContextKind Intervention) (ContextKind Situation)
  SetsTargetForMeasure
    :: Relation (ContextKind Intervention) (ContextKind Measure)
  MeasuresSituation :: Relation (ContextKind Measure) (ContextKind Situation)
  FramesMeasure :: Relation (ContextKind Strategy) (ContextKind Measure)
  -- *** Situation anchor relations
  ConstitutedByAnchor :: Relation (ContextKind Situation) (AnchorKind anchor)
  -- *** Primitive evidence relations
  -- **** Orientation and strategy evidence
  GuidesEthosPrincipleToMissionDriver
    :: Relation (PrimitiveKind Ethos Principle) (PrimitiveKind Mission Driver)
  GuidesEthosPrincipleToVisionObjective
    :: Relation (PrimitiveKind Ethos Principle) (PrimitiveKind Vision Objective)
  GroundsMissionDriverToVisionObjective
    :: Relation (PrimitiveKind Mission Driver) (PrimitiveKind Vision Objective)
  OrientsVisionObjectiveToStrategyObjective
    :: Relation
         (PrimitiveKind Vision Objective)
         (PrimitiveKind Strategy Objective)
  GroundsStrategyDriverToObjective
    :: Relation
         (PrimitiveKind Strategy Driver)
         (PrimitiveKind Strategy Objective)
  SubstantiatesStrategyKeyResultObjective
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Strategy Objective)
  GuidesStrategyPrincipleToAction
    :: Relation
         (PrimitiveKind Strategy Principle)
         (PrimitiveKind Strategy Action)
  ContributesStrategyActionToKeyResult
    :: Relation
         (PrimitiveKind Strategy Action)
         (PrimitiveKind Strategy KeyResult)
  GuidesStrategyPrincipleToPrinciple
    :: Relation
         (PrimitiveKind Strategy Principle)
         (PrimitiveKind Strategy Principle)
  ContributesStrategyKeyResultToKeyResult
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Strategy KeyResult)
  ContributesStrategyActionToAction
    :: Relation (PrimitiveKind Strategy Action) (PrimitiveKind Strategy Action)
  -- **** Need and measurement evidence
  TranslatesStrategyKeyResultToNeedObjective
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Need Objective)
  GroundsNeedDriverToObjective
    :: Relation (PrimitiveKind Need Driver) (PrimitiveKind Need Objective)
  AnchorsNeedDriver :: Relation (AnchorKind anchor) (PrimitiveKind Need Driver)
  IndicatesMeasureDomain
    :: Relation (PrimitiveKind Strategy Driver) (StructuringKind Measure Domain)
  DeterminesMeasureDomain
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (StructuringKind Measure Domain)
  ContainsStrategyKeyResult
    :: Relation
         (StructuringKind Strategy Domain)
         (PrimitiveKind Strategy KeyResult)
  ContainsMeasureKPI
    :: Relation (StructuringKind Measure Domain) (PrimitiveKind Measure KPI)
  -- **** Intervention and effect evidence
  GuidesStrategyActionToInterventionAction
    :: Relation
         (PrimitiveKind Strategy Action)
         (PrimitiveKind Intervention Action)
  ContributesInterventionActionToKeyResult
    :: Relation
         (PrimitiveKind Intervention Action)
         (PrimitiveKind Intervention KeyResult)
  SubstantiatesInterventionKeyResultNeedObjective
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Need Objective)
  ContributesInterventionKeyResultToStrategyKeyResult
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Strategy KeyResult)
  SetsTargetForMeasureKPI
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Measure KPI)
  ChangesAnchor
    :: Relation (PrimitiveKind Intervention Action) (AnchorKind anchor)
  MeasuresAnchor :: Relation (PrimitiveKind Measure KPI) (AnchorKind anchor)

-- ** Interpretations
data Interpretation (ctx :: Context) (prim :: Primitive) where
  PrincipleInEthos :: Interpretation Ethos Principle
  DriverInMission :: Interpretation Mission Driver
  ObjectiveInVision :: Interpretation Vision Objective
  DriverInStrategy :: Interpretation Strategy Driver
  ObjectiveInStrategy :: Interpretation Strategy Objective
  PrincipleInStrategy :: Interpretation Strategy Principle
  KeyResultInStrategy :: Interpretation Strategy KeyResult
  ActionInStrategy :: Interpretation Strategy Action
  DriverInNeed :: Interpretation Need Driver
  ObjectiveInNeed :: Interpretation Need Objective
  ActionInIntervention :: Interpretation Intervention Action
  KeyResultInIntervention :: Interpretation Intervention KeyResult
  KPIInMeasure :: Interpretation Measure KPI

-- * Model instances
data ContextNode =
  ContextNode ContextId Context
  deriving (Eq, Show)

data PrimitiveNodeInstance =
  PrimitiveNodeInstance PrimitiveId ContextId Primitive
  deriving (Eq, Show)

data StructuringNodeInstance =
  StructuringNodeInstance StructuringId ContextId Structuring
  deriving (Eq, Show)

data AnchorNodeInstance =
  AnchorNodeInstance AnchorId ContextId SituationAnchor
  deriving (Eq, Show)

data NodeRef
  = CtxRef ContextId
  | PrimRef PrimitiveId
  | StructRef StructuringId
  | AnchorRef AnchorId
  deriving (Eq, Show)

data SomeRelation where
  SomeRelation :: Relation from to -> SomeRelation

data RelationKey
  = RKGuidesMission
  | RKGroundsVision
  | RKGuidesVision
  | RKOrientsStrategy
  | RKDirectsStrategy
  | RKContributesToStrategy
  | RKQualifiesNeed
  | RKSurfacesNeed
  | RKAddressesNeed
  | RKDirectsIntervention
  | RKChangesSituation
  | RKSetsTargetForMeasure
  | RKMeasuresSituation
  | RKFramesMeasure
  | RKConstitutedByAnchor
  | RKGuidesEthosPrincipleToMissionDriver
  | RKGuidesEthosPrincipleToVisionObjective
  | RKGroundsMissionDriverToVisionObjective
  | RKOrientsVisionObjectiveToStrategyObjective
  | RKGroundsStrategyDriverToObjective
  | RKSubstantiatesStrategyKeyResultObjective
  | RKGuidesStrategyPrincipleToAction
  | RKContributesStrategyActionToKeyResult
  | RKGuidesStrategyPrincipleToPrinciple
  | RKContributesStrategyKeyResultToKeyResult
  | RKContributesStrategyActionToAction
  | RKTranslatesStrategyKeyResultToNeedObjective
  | RKGroundsNeedDriverToObjective
  | RKAnchorsNeedDriver
  | RKIndicatesMeasureDomain
  | RKDeterminesMeasureDomain
  | RKContainsStrategyKeyResult
  | RKContainsMeasureKPI
  | RKGuidesStrategyActionToInterventionAction
  | RKContributesInterventionActionToKeyResult
  | RKSubstantiatesInterventionKeyResultNeedObjective
  | RKContributesInterventionKeyResultToStrategyKeyResult
  | RKSetsTargetForMeasureKPI
  | RKChangesAnchor
  | RKMeasuresAnchor
  deriving (Eq, Show)

instance Eq SomeRelation where
  left == right = relationKey left == relationKey right

instance Show SomeRelation where
  show = relationLabel

data Edge =
  Edge NodeRef SomeRelation NodeRef
  deriving (Eq, Show)

data Model = Model
  { contextNodes :: [ContextNode]
  , primitiveNodes :: [PrimitiveNodeInstance]
  , structuringNodes :: [StructuringNodeInstance]
  , anchorNodes :: [AnchorNodeInstance]
  , edges :: [Edge]
  } deriving (Eq, Show)

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
    && all (wfIntervention m) (interventionIds m)

wfPrimitivePlacement :: Model -> PrimitiveNodeInstance -> Bool
wfPrimitivePlacement m (PrimitiveNodeInstance _ c p) =
  maybe False (`allowedInterpretation` p) (contextKind m c)

wfStructuringPlacement :: Model -> StructuringNodeInstance -> Bool
wfStructuringPlacement m (StructuringNodeInstance _ c Domain) =
  contextKind m c `elem` [Just Strategy, Just Measure]

wfAnchorPlacement :: Model -> AnchorNodeInstance -> Bool
wfAnchorPlacement m (AnchorNodeInstance _ c _) =
  contextKind m c == Just Situation

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
effRelevant m need =
  hasIncomingContextEdge m (SomeRelation SurfacesNeed) Situation need
    && qualifiedByStrategy m need

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
data NodeKindValue
  = ContextNodeKind Context
  | PrimitiveNodeKind Context Primitive
  | StructuringNodeKind Context Structuring
  | AnchorNodeKind SituationAnchor
  deriving (Eq, Show)

data NodeKindPattern
  = Exact NodeKindValue
  | AnyAnchor
  deriving (Eq, Show)

type RelationDomain = (NodeKindPattern, NodeKindPattern)

matchesDomain :: RelationDomain -> (NodeKindValue, NodeKindValue) -> Bool
matchesDomain (fromPattern, toPattern) (fromKind, toKind) =
  matchesKind fromPattern fromKind && matchesKind toPattern toKind

matchesKind :: NodeKindPattern -> NodeKindValue -> Bool
matchesKind (Exact expected) actual = expected == actual
matchesKind AnyAnchor (AnchorNodeKind _) = True
matchesKind AnyAnchor _ = False

nodeKindValue :: Model -> NodeRef -> Maybe NodeKindValue
nodeKindValue m (CtxRef c) = ContextNodeKind <$> contextKind m c
nodeKindValue m (PrimRef p) =
  (\(c, k) -> PrimitiveNodeKind c k) <$> primitiveContextAndKind m p
nodeKindValue m (StructRef s) =
  (\(c, k) -> StructuringNodeKind c k) <$> structuringContextAndKind m s
nodeKindValue m (AnchorRef a) = AnchorNodeKind <$> anchorKind m a

contextKind :: Model -> ContextId -> Maybe Context
contextKind m c = lookup c [(i, k) | ContextNode i k <- contextNodes m]

primitiveContextAndKind :: Model -> PrimitiveId -> Maybe (Context, Primitive)
primitiveContextAndKind m p =
  case [(c, k) | PrimitiveNodeInstance i c k <- primitiveNodes m, i == p] of
    (c, k):_ -> (, k) <$> contextKind m c
    [] -> Nothing

structuringContextAndKind ::
     Model -> StructuringId -> Maybe (Context, Structuring)
structuringContextAndKind m s =
  case [(c, k) | StructuringNodeInstance i c k <- structuringNodes m, i == s] of
    (c, k):_ -> (, k) <$> contextKind m c
    [] -> Nothing

anchorKind :: Model -> AnchorId -> Maybe SituationAnchor
anchorKind m a = lookup a [(i, k) | AnchorNodeInstance i _ k <- anchorNodes m]

contextIds :: Model -> [ContextId]
contextIds m = [i | ContextNode i _ <- contextNodes m]

primitiveIds :: Model -> [PrimitiveId]
primitiveIds m = [i | PrimitiveNodeInstance i _ _ <- primitiveNodes m]

structuringIds :: Model -> [StructuringId]
structuringIds m = [i | StructuringNodeInstance i _ _ <- structuringNodes m]

anchorIds :: Model -> [AnchorId]
anchorIds m = [i | AnchorNodeInstance i _ _ <- anchorNodes m]

strategyIds :: Model -> [ContextId]
strategyIds m = [i | ContextNode i Strategy <- contextNodes m]

interventionIds :: Model -> [ContextId]
interventionIds m = [i | ContextNode i Intervention <- contextNodes m]

uniqueIds :: Eq a => [a] -> Bool
uniqueIds [] = True
uniqueIds (x:xs) = x `notElem` xs && uniqueIds xs

allowedInterpretation :: Context -> Primitive -> Bool
allowedInterpretation Ethos Principle = True
allowedInterpretation Mission Driver = True
allowedInterpretation Vision Objective = True
allowedInterpretation Strategy Driver = True
allowedInterpretation Strategy Objective = True
allowedInterpretation Strategy Principle = True
allowedInterpretation Strategy KeyResult = True
allowedInterpretation Strategy Action = True
allowedInterpretation Need Driver = True
allowedInterpretation Need Objective = True
allowedInterpretation Intervention Action = True
allowedInterpretation Intervention KeyResult = True
allowedInterpretation Measure KPI = True
allowedInterpretation _ _ = False

hasEdge :: Model -> NodeRef -> SomeRelation -> NodeRef -> Bool
hasEdge m from rel to = Edge from rel to `elem` edges m

hasIncomingContextEdge :: Model -> SomeRelation -> Context -> ContextId -> Bool
hasIncomingContextEdge m rel fromKind to = any matches (edges m)
  where
    matches (Edge (CtxRef from) rel' (CtxRef to')) =
      rel == rel' && to == to' && contextKind m from == Just fromKind
    matches _ = False

contextRelationDomain :: SomeRelation -> Maybe (Context, Context)
contextRelationDomain rel =
  case relationDomain rel of
    (Exact (ContextNodeKind from), Exact (ContextNodeKind to)) ->
      Just (from, to)
    _ -> Nothing

relationKey :: SomeRelation -> RelationKey
relationKey (SomeRelation GuidesMission) = RKGuidesMission
relationKey (SomeRelation GroundsVision) = RKGroundsVision
relationKey (SomeRelation GuidesVision) = RKGuidesVision
relationKey (SomeRelation OrientsStrategy) = RKOrientsStrategy
relationKey (SomeRelation DirectsStrategy) = RKDirectsStrategy
relationKey (SomeRelation ContributesToStrategy) = RKContributesToStrategy
relationKey (SomeRelation QualifiesNeed) = RKQualifiesNeed
relationKey (SomeRelation SurfacesNeed) = RKSurfacesNeed
relationKey (SomeRelation AddressesNeed) = RKAddressesNeed
relationKey (SomeRelation DirectsIntervention) = RKDirectsIntervention
relationKey (SomeRelation ChangesSituation) = RKChangesSituation
relationKey (SomeRelation SetsTargetForMeasure) = RKSetsTargetForMeasure
relationKey (SomeRelation MeasuresSituation) = RKMeasuresSituation
relationKey (SomeRelation FramesMeasure) = RKFramesMeasure
relationKey (SomeRelation ConstitutedByAnchor) = RKConstitutedByAnchor
relationKey (SomeRelation GuidesEthosPrincipleToMissionDriver) =
  RKGuidesEthosPrincipleToMissionDriver
relationKey (SomeRelation GuidesEthosPrincipleToVisionObjective) =
  RKGuidesEthosPrincipleToVisionObjective
relationKey (SomeRelation GroundsMissionDriverToVisionObjective) =
  RKGroundsMissionDriverToVisionObjective
relationKey (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  RKOrientsVisionObjectiveToStrategyObjective
relationKey (SomeRelation GroundsStrategyDriverToObjective) =
  RKGroundsStrategyDriverToObjective
relationKey (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  RKSubstantiatesStrategyKeyResultObjective
relationKey (SomeRelation GuidesStrategyPrincipleToAction) =
  RKGuidesStrategyPrincipleToAction
relationKey (SomeRelation ContributesStrategyActionToKeyResult) =
  RKContributesStrategyActionToKeyResult
relationKey (SomeRelation GuidesStrategyPrincipleToPrinciple) =
  RKGuidesStrategyPrincipleToPrinciple
relationKey (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  RKContributesStrategyKeyResultToKeyResult
relationKey (SomeRelation ContributesStrategyActionToAction) =
  RKContributesStrategyActionToAction
relationKey (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  RKTranslatesStrategyKeyResultToNeedObjective
relationKey (SomeRelation GroundsNeedDriverToObjective) =
  RKGroundsNeedDriverToObjective
relationKey (SomeRelation AnchorsNeedDriver) = RKAnchorsNeedDriver
relationKey (SomeRelation IndicatesMeasureDomain) = RKIndicatesMeasureDomain
relationKey (SomeRelation DeterminesMeasureDomain) = RKDeterminesMeasureDomain
relationKey (SomeRelation ContainsStrategyKeyResult) =
  RKContainsStrategyKeyResult
relationKey (SomeRelation ContainsMeasureKPI) = RKContainsMeasureKPI
relationKey (SomeRelation GuidesStrategyActionToInterventionAction) =
  RKGuidesStrategyActionToInterventionAction
relationKey (SomeRelation ContributesInterventionActionToKeyResult) =
  RKContributesInterventionActionToKeyResult
relationKey (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  RKSubstantiatesInterventionKeyResultNeedObjective
relationKey (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  RKContributesInterventionKeyResultToStrategyKeyResult
relationKey (SomeRelation SetsTargetForMeasureKPI) = RKSetsTargetForMeasureKPI
relationKey (SomeRelation ChangesAnchor) = RKChangesAnchor
relationKey (SomeRelation MeasuresAnchor) = RKMeasuresAnchor

relationLabel :: SomeRelation -> String
relationLabel (SomeRelation GuidesMission) = "guides"
relationLabel (SomeRelation GroundsVision) = "grounds"
relationLabel (SomeRelation GuidesVision) = "guides"
relationLabel (SomeRelation OrientsStrategy) = "orients"
relationLabel (SomeRelation DirectsStrategy) = "directs"
relationLabel (SomeRelation ContributesToStrategy) = "contributes-to"
relationLabel (SomeRelation QualifiesNeed) = "qualifies"
relationLabel (SomeRelation SurfacesNeed) = "surfaces"
relationLabel (SomeRelation AddressesNeed) = "addresses"
relationLabel (SomeRelation DirectsIntervention) = "directs"
relationLabel (SomeRelation ChangesSituation) = "changes"
relationLabel (SomeRelation SetsTargetForMeasure) = "sets-target-for"
relationLabel (SomeRelation MeasuresSituation) = "measures"
relationLabel (SomeRelation FramesMeasure) = "frames"
relationLabel (SomeRelation ConstitutedByAnchor) = "is-constituted-by"
relationLabel (SomeRelation GuidesEthosPrincipleToMissionDriver) = "guides"
relationLabel (SomeRelation GuidesEthosPrincipleToVisionObjective) = "guides"
relationLabel (SomeRelation GroundsMissionDriverToVisionObjective) = "grounds"
relationLabel (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  "orients"
relationLabel (SomeRelation GroundsStrategyDriverToObjective) = "grounds"
relationLabel (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  "substantiates"
relationLabel (SomeRelation GuidesStrategyPrincipleToAction) = "guides"
relationLabel (SomeRelation ContributesStrategyActionToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation GuidesStrategyPrincipleToPrinciple) = "guides"
relationLabel (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation ContributesStrategyActionToAction) =
  "contributes-to"
relationLabel (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  "translates-into"
relationLabel (SomeRelation GroundsNeedDriverToObjective) = "grounds"
relationLabel (SomeRelation AnchorsNeedDriver) = "anchors"
relationLabel (SomeRelation IndicatesMeasureDomain) = "indicates"
relationLabel (SomeRelation DeterminesMeasureDomain) = "determines"
relationLabel (SomeRelation ContainsStrategyKeyResult) = "contains"
relationLabel (SomeRelation ContainsMeasureKPI) = "contains"
relationLabel (SomeRelation GuidesStrategyActionToInterventionAction) = "guides"
relationLabel (SomeRelation ContributesInterventionActionToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  "substantiates"
relationLabel (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  "contributes-to"
relationLabel (SomeRelation SetsTargetForMeasureKPI) = "sets-target-for"
relationLabel (SomeRelation ChangesAnchor) = "changes"
relationLabel (SomeRelation MeasuresAnchor) = "measures"

relationDomain :: SomeRelation -> RelationDomain
relationDomain (SomeRelation GuidesMission) = contextDomain Ethos Mission
relationDomain (SomeRelation GroundsVision) = contextDomain Mission Vision
relationDomain (SomeRelation GuidesVision) = contextDomain Ethos Vision
relationDomain (SomeRelation OrientsStrategy) = contextDomain Vision Strategy
relationDomain (SomeRelation DirectsStrategy) = contextDomain Strategy Strategy
relationDomain (SomeRelation ContributesToStrategy) =
  contextDomain Strategy Strategy
relationDomain (SomeRelation QualifiesNeed) = contextDomain Strategy Need
relationDomain (SomeRelation SurfacesNeed) = contextDomain Situation Need
relationDomain (SomeRelation AddressesNeed) = contextDomain Intervention Need
relationDomain (SomeRelation DirectsIntervention) =
  contextDomain Strategy Intervention
relationDomain (SomeRelation ChangesSituation) =
  contextDomain Intervention Situation
relationDomain (SomeRelation SetsTargetForMeasure) =
  contextDomain Intervention Measure
relationDomain (SomeRelation MeasuresSituation) =
  contextDomain Measure Situation
relationDomain (SomeRelation FramesMeasure) = contextDomain Strategy Measure
relationDomain (SomeRelation ConstitutedByAnchor) =
  (Exact (ContextNodeKind Situation), AnyAnchor)
relationDomain (SomeRelation GuidesEthosPrincipleToMissionDriver) =
  primitiveDomain Ethos Principle Mission Driver
relationDomain (SomeRelation GuidesEthosPrincipleToVisionObjective) =
  primitiveDomain Ethos Principle Vision Objective
relationDomain (SomeRelation GroundsMissionDriverToVisionObjective) =
  primitiveDomain Mission Driver Vision Objective
relationDomain (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  primitiveDomain Vision Objective Strategy Objective
relationDomain (SomeRelation GroundsStrategyDriverToObjective) =
  primitiveDomain Strategy Driver Strategy Objective
relationDomain (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  primitiveDomain Strategy KeyResult Strategy Objective
relationDomain (SomeRelation GuidesStrategyPrincipleToAction) =
  primitiveDomain Strategy Principle Strategy Action
relationDomain (SomeRelation ContributesStrategyActionToKeyResult) =
  primitiveDomain Strategy Action Strategy KeyResult
relationDomain (SomeRelation GuidesStrategyPrincipleToPrinciple) =
  primitiveDomain Strategy Principle Strategy Principle
relationDomain (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  primitiveDomain Strategy KeyResult Strategy KeyResult
relationDomain (SomeRelation ContributesStrategyActionToAction) =
  primitiveDomain Strategy Action Strategy Action
relationDomain (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  primitiveDomain Strategy KeyResult Need Objective
relationDomain (SomeRelation GroundsNeedDriverToObjective) =
  primitiveDomain Need Driver Need Objective
relationDomain (SomeRelation AnchorsNeedDriver) =
  (AnyAnchor, Exact (PrimitiveNodeKind Need Driver))
relationDomain (SomeRelation IndicatesMeasureDomain) =
  ( Exact (PrimitiveNodeKind Strategy Driver)
  , Exact (StructuringNodeKind Measure Domain))
relationDomain (SomeRelation DeterminesMeasureDomain) =
  ( Exact (PrimitiveNodeKind Strategy KeyResult)
  , Exact (StructuringNodeKind Measure Domain))
relationDomain (SomeRelation ContainsStrategyKeyResult) =
  ( Exact (StructuringNodeKind Strategy Domain)
  , Exact (PrimitiveNodeKind Strategy KeyResult))
relationDomain (SomeRelation ContainsMeasureKPI) =
  ( Exact (StructuringNodeKind Measure Domain)
  , Exact (PrimitiveNodeKind Measure KPI))
relationDomain (SomeRelation GuidesStrategyActionToInterventionAction) =
  primitiveDomain Strategy Action Intervention Action
relationDomain (SomeRelation ContributesInterventionActionToKeyResult) =
  primitiveDomain Intervention Action Intervention KeyResult
relationDomain (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  primitiveDomain Intervention KeyResult Need Objective
relationDomain (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  primitiveDomain Intervention KeyResult Strategy KeyResult
relationDomain (SomeRelation SetsTargetForMeasureKPI) =
  primitiveDomain Intervention KeyResult Measure KPI
relationDomain (SomeRelation ChangesAnchor) =
  (Exact (PrimitiveNodeKind Intervention Action), AnyAnchor)
relationDomain (SomeRelation MeasuresAnchor) =
  (Exact (PrimitiveNodeKind Measure KPI), AnyAnchor)

contextDomain :: Context -> Context -> RelationDomain
contextDomain from to =
  (Exact (ContextNodeKind from), Exact (ContextNodeKind to))

primitiveDomain ::
     Context -> Primitive -> Context -> Primitive -> RelationDomain
primitiveDomain fromCtx fromPrim toCtx toPrim =
  ( Exact (PrimitiveNodeKind fromCtx fromPrim)
  , Exact (PrimitiveNodeKind toCtx toPrim))

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

primitiveRefsInContext :: Model -> ContextId -> Primitive -> [NodeRef]
primitiveRefsInContext m context primitive =
  [ PrimRef i
  | PrimitiveNodeInstance i c p <- primitiveNodes m
  , c == context
  , p == primitive
  ]

structuringRefsInContext :: Model -> ContextId -> Structuring -> [NodeRef]
structuringRefsInContext m context structuring =
  [ StructRef i
  | StructuringNodeInstance i c s <- structuringNodes m
  , c == context
  , s == structuring
  ]

anchorRefsInContext :: Model -> ContextId -> [NodeRef]
anchorRefsInContext m context =
  [AnchorRef i | AnchorNodeInstance i c _ <- anchorNodes m, c == context]

addressedNeeds :: Model -> ContextId -> [ContextId]
addressedNeeds m intervention =
  [ to
  | Edge (CtxRef from) rel (CtxRef to) <- edges m
  , from == intervention
  , rel == SomeRelation AddressesNeed
  ]
