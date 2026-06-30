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
  | Gap
  deriving (Eq, Show)

-- ** Structuring
data Structuring
  = Domain
  | CSF
  deriving (Eq, Show)

-- ** Typed instances
newtype Ctx (c :: Context) =
  Ctx ContextId

newtype Prim (p :: Primitive) =
  Prim PrimitiveId

newtype Struct (s :: Structuring) =
  Struct StructuringId

-- * Type-level relations
-- ** Context relations
data ContextRelation (from :: Context) (to :: Context) where
  GuidesMission :: ContextRelation Ethos Mission
  GroundsVision :: ContextRelation Mission Vision
  GuidesVision :: ContextRelation Ethos Vision
  OrientsStrategy :: ContextRelation Vision Strategy
  DirectsStrategy :: ContextRelation Strategy Strategy
  QualifiesNeed :: ContextRelation Strategy Need
  SurfacesNeed :: ContextRelation Situation Need
  RefinesNeed :: ContextRelation Need Need
  AddressesNeed :: ContextRelation Intervention Need
  DirectsIntervention :: ContextRelation Strategy Intervention
  ChangesSituation :: ContextRelation Intervention Situation
  SetsTargetForMeasure :: ContextRelation Intervention Measure
  MeasuresSituation :: ContextRelation Measure Situation
  FramesMeasure :: ContextRelation Strategy Measure

-- ** Primitive nodes
data Node
  = PrimitiveNode Primitive
  | StructuringNode Structuring

-- ** Primitive relations
data PrimitiveRelation (from :: Node) (to :: Node) where
  GuidesDriver
    :: PrimitiveRelation (PrimitiveNode Principle) (PrimitiveNode Driver)
  GuidesObjective
    :: PrimitiveRelation (PrimitiveNode Principle) (PrimitiveNode Objective)
  MotivatesObjective
    :: PrimitiveRelation (PrimitiveNode Driver) (PrimitiveNode Objective)
  DeterminesDomain
    :: PrimitiveRelation (PrimitiveNode Driver) (StructuringNode Domain)
  ContainsKPI
    :: PrimitiveRelation (StructuringNode Domain) (PrimitiveNode KPI)
  TranslatesIntoObjective
    :: PrimitiveRelation (PrimitiveNode KeyResult) (PrimitiveNode Objective)
  SubstantiatesObjective
    :: PrimitiveRelation (PrimitiveNode KeyResult) (PrimitiveNode Objective)
  SetsTargetForKPI
    :: PrimitiveRelation (PrimitiveNode KeyResult) (PrimitiveNode KPI)
  RefinesKPI :: PrimitiveRelation (PrimitiveNode KPI) (PrimitiveNode KPI)
  ActionContributesToKR
    :: PrimitiveRelation (PrimitiveNode Action) (PrimitiveNode KeyResult)
  ActionAddressesGap
    :: PrimitiveRelation (PrimitiveNode Action) (PrimitiveNode Gap)

-- ** Interpretations
data Interpretation (ctx :: Context) (prim :: Primitive) where
  PrincipleInEthos :: Interpretation Ethos Principle
  DriverInMission :: Interpretation Mission Driver
  ObjectiveInVision :: Interpretation Vision Objective
  ObjectiveInStrategy :: Interpretation Strategy Objective
  KeyResultInStrategy :: Interpretation Strategy KeyResult
  ActionInStrategy :: Interpretation Strategy Action
  DriverInNeed :: Interpretation Need Driver
  ObjectiveInNeed :: Interpretation Need Objective
  ActionInIntervention :: Interpretation Intervention Action
  KPIInMeasure :: Interpretation Measure KPI
  GapInSituation :: Interpretation Situation Gap

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

data NodeRef
  = PrimRef PrimitiveId
  | StructRef StructuringId
  deriving (Eq, Show)

data SomeContextRelation where
  SomeContextRelation :: ContextRelation from to -> SomeContextRelation

instance Eq SomeContextRelation where
  left == right =
    contextRelationLabel left == contextRelationLabel right
      && contextRelationDomain left == contextRelationDomain right

instance Show SomeContextRelation where
  show = contextRelationLabel

data SomePrimitiveRelation where
  SomePrimitiveRelation :: PrimitiveRelation from to -> SomePrimitiveRelation

instance Eq SomePrimitiveRelation where
  left == right =
    primitiveRelationLabel left == primitiveRelationLabel right
      && primitiveRelationDomain left == primitiveRelationDomain right

instance Show SomePrimitiveRelation where
  show = primitiveRelationLabel

data ContextEdge =
  ContextEdge ContextId SomeContextRelation ContextId
  deriving (Eq, Show)

data PrimitiveEdge =
  PrimitiveEdge NodeRef SomePrimitiveRelation NodeRef
  deriving (Eq, Show)

data Model = Model
  { contextNodes :: [ContextNode]
  , primitiveNodes :: [PrimitiveNodeInstance]
  , structuringNodes :: [StructuringNodeInstance]
  , contextEdges :: [ContextEdge]
  , primitiveEdges :: [PrimitiveEdge]
  } deriving (Eq, Show)

-- * Validation
wfModel :: Model -> Bool
wfModel m =
  uniqueIds (contextIds m)
    && uniqueIds (primitiveIds m)
    && uniqueIds (structuringIds m)
    && all (wfPrimitivePlacement m) (primitiveNodes m)
    && all (wfStructuringPlacement m) (structuringNodes m)
    && all (wfContextEdge m) (contextEdges m)
    && all (wfPrimitiveEdge m) (primitiveEdges m)
    && all (wfIntervention m) (interventionIds m)

wfPrimitivePlacement :: Model -> PrimitiveNodeInstance -> Bool
wfPrimitivePlacement m (PrimitiveNodeInstance _ c p) =
  maybe False (`allowedInterpretation` p) (contextKind m c)

wfContextEdge :: Model -> ContextEdge -> Bool
wfContextEdge m (ContextEdge from rel to) =
  case (contextKind m from, contextKind m to) of
    (Just fromKind, Just toKind) ->
      contextRelationDomain rel == (fromKind, toKind)
    _ -> False

wfPrimitiveEdge :: Model -> PrimitiveEdge -> Bool
wfPrimitiveEdge m (PrimitiveEdge from rel to) =
  case (nodeKind m from, nodeKind m to) of
    (Just fromKind, Just toKind) ->
      primitiveRelationDomain rel == (fromKind, toKind)
    _ -> False

wfStructuringPlacement :: Model -> StructuringNodeInstance -> Bool
wfStructuringPlacement m (StructuringNodeInstance _ c _) =
  contextKind m c /= Nothing

wfIntervention :: Model -> ContextId -> Bool
wfIntervention m intervention =
  all (effRelevant m) (addressedNeeds m intervention)

effRelevant :: Model -> ContextId -> Bool
effRelevant m need =
  hasIncoming m (SomeContextRelation SurfacesNeed) Situation need
    && qualifiedByStrategy m need

qualifiedByStrategy :: Model -> ContextId -> Bool
qualifiedByStrategy m need = any qualifiesNeed (strategyIds m)
  where
    qualifiesNeed strategy =
      hasEdge m strategy (SomeContextRelation QualifiesNeed) need
        && hasQualifiesNeedEvidence m strategy need

hasQualifiesNeedEvidence :: Model -> ContextId -> ContextId -> Bool
hasQualifiesNeedEvidence m strategy need =
  any (\pattern -> pattern m strategy need) qualifiesNeedEvidencePatterns

qualifiesNeedEvidencePatterns :: [Model -> ContextId -> ContextId -> Bool]
qualifiesNeedEvidencePatterns = [keyResultTranslatesIntoNeedObjective]

keyResultTranslatesIntoNeedObjective :: Model -> ContextId -> ContextId -> Bool
keyResultTranslatesIntoNeedObjective m strategy need =
  any isEvidence (primitiveEdges m)
  where
    isEvidence (PrimitiveEdge (PrimRef from) (SomePrimitiveRelation TranslatesIntoObjective) (PrimRef to)) =
      primitiveInContext m from strategy KeyResult
        && primitiveInContext m to need Objective
    isEvidence _ = False

effectTrace :: Model -> ContextId -> ContextId -> ContextId -> ContextId -> Bool
effectTrace m need intervention measure situation =
  effRelevant m need
    && hasEdge m intervention (SomeContextRelation AddressesNeed) need
    && hasEdge m intervention (SomeContextRelation ChangesSituation) situation
    && hasEdge m intervention (SomeContextRelation SetsTargetForMeasure) measure
    && hasEdge m measure (SomeContextRelation MeasuresSituation) situation

-- * Validation support
data NodeKind
  = PrimitiveKind Primitive
  | StructuringKind Structuring
  deriving (Eq, Show)

contextKind :: Model -> ContextId -> Maybe Context
contextKind m c = lookup c [(i, k) | ContextNode i k <- contextNodes m]

primitiveKind :: Model -> PrimitiveId -> Maybe Primitive
primitiveKind m p =
  lookup p [(i, k) | PrimitiveNodeInstance i _ k <- primitiveNodes m]

structuringKind :: Model -> StructuringId -> Maybe Structuring
structuringKind m s =
  lookup s [(i, k) | StructuringNodeInstance i _ k <- structuringNodes m]

nodeKind :: Model -> NodeRef -> Maybe NodeKind
nodeKind m (PrimRef p) = PrimitiveKind <$> primitiveKind m p
nodeKind m (StructRef s) = StructuringKind <$> structuringKind m s

primitiveInContext :: Model -> PrimitiveId -> ContextId -> Primitive -> Bool
primitiveInContext m p c expected = any matches (primitiveNodes m)
  where
    matches (PrimitiveNodeInstance p' c' actual) =
      p == p' && c == c' && expected == actual

strategyIds :: Model -> [ContextId]
strategyIds m = [i | ContextNode i Strategy <- contextNodes m]

interventionIds :: Model -> [ContextId]
interventionIds m = [i | ContextNode i Intervention <- contextNodes m]

addressedNeeds :: Model -> ContextId -> [ContextId]
addressedNeeds m intervention =
  [ to
  | ContextEdge from rel to <- contextEdges m
  , from == intervention
  , rel == SomeContextRelation AddressesNeed
  ]

hasEdge :: Model -> ContextId -> SomeContextRelation -> ContextId -> Bool
hasEdge m from rel to = ContextEdge from rel to `elem` contextEdges m

hasIncoming :: Model -> SomeContextRelation -> Context -> ContextId -> Bool
hasIncoming m rel fromKind to = any matches (contextEdges m)
  where
    matches (ContextEdge from rel' to') =
      rel == rel' && to == to' && contextKind m from == Just fromKind

allowedInterpretation :: Context -> Primitive -> Bool
allowedInterpretation Ethos Principle = True
allowedInterpretation Mission Driver = True
allowedInterpretation Vision Objective = True
allowedInterpretation Strategy Objective = True
allowedInterpretation Strategy KeyResult = True
allowedInterpretation Strategy Action = True
allowedInterpretation Need Driver = True
allowedInterpretation Need Objective = True
allowedInterpretation Intervention Action = True
allowedInterpretation Measure KPI = True
allowedInterpretation Situation Gap = True
allowedInterpretation _ _ = False

contextIds :: Model -> [ContextId]
contextIds m = [i | ContextNode i _ <- contextNodes m]

primitiveIds :: Model -> [PrimitiveId]
primitiveIds m = [i | PrimitiveNodeInstance i _ _ <- primitiveNodes m]

structuringIds :: Model -> [StructuringId]
structuringIds m = [i | StructuringNodeInstance i _ _ <- structuringNodes m]

uniqueIds :: Eq a => [a] -> Bool
uniqueIds [] = True
uniqueIds (x:xs) = x `notElem` xs && uniqueIds xs

contextRelationLabel :: SomeContextRelation -> String
contextRelationLabel (SomeContextRelation GuidesMission) = "guides"
contextRelationLabel (SomeContextRelation GroundsVision) = "grounds"
contextRelationLabel (SomeContextRelation GuidesVision) = "guides"
contextRelationLabel (SomeContextRelation OrientsStrategy) = "orients"
contextRelationLabel (SomeContextRelation DirectsStrategy) = "directs"
contextRelationLabel (SomeContextRelation QualifiesNeed) = "qualifies"
contextRelationLabel (SomeContextRelation SurfacesNeed) = "surfaces"
contextRelationLabel (SomeContextRelation RefinesNeed) = "refines"
contextRelationLabel (SomeContextRelation AddressesNeed) = "addresses"
contextRelationLabel (SomeContextRelation DirectsIntervention) = "directs"
contextRelationLabel (SomeContextRelation ChangesSituation) = "changes"
contextRelationLabel (SomeContextRelation SetsTargetForMeasure) =
  "sets-target-for"
contextRelationLabel (SomeContextRelation MeasuresSituation) = "measures"
contextRelationLabel (SomeContextRelation FramesMeasure) = "frames"

contextRelationDomain :: SomeContextRelation -> (Context, Context)
contextRelationDomain (SomeContextRelation GuidesMission) = (Ethos, Mission)
contextRelationDomain (SomeContextRelation GroundsVision) = (Mission, Vision)
contextRelationDomain (SomeContextRelation GuidesVision) = (Ethos, Vision)
contextRelationDomain (SomeContextRelation OrientsStrategy) = (Vision, Strategy)
contextRelationDomain (SomeContextRelation DirectsStrategy) =
  (Strategy, Strategy)
contextRelationDomain (SomeContextRelation QualifiesNeed) = (Strategy, Need)
contextRelationDomain (SomeContextRelation SurfacesNeed) = (Situation, Need)
contextRelationDomain (SomeContextRelation RefinesNeed) = (Need, Need)
contextRelationDomain (SomeContextRelation AddressesNeed) = (Intervention, Need)
contextRelationDomain (SomeContextRelation DirectsIntervention) =
  (Strategy, Intervention)
contextRelationDomain (SomeContextRelation ChangesSituation) =
  (Intervention, Situation)
contextRelationDomain (SomeContextRelation SetsTargetForMeasure) =
  (Intervention, Measure)
contextRelationDomain (SomeContextRelation MeasuresSituation) =
  (Measure, Situation)
contextRelationDomain (SomeContextRelation FramesMeasure) = (Strategy, Measure)

primitiveRelationLabel :: SomePrimitiveRelation -> String
primitiveRelationLabel (SomePrimitiveRelation GuidesDriver) = "guides"
primitiveRelationLabel (SomePrimitiveRelation GuidesObjective) = "guides"
primitiveRelationLabel (SomePrimitiveRelation MotivatesObjective) = "motivates"
primitiveRelationLabel (SomePrimitiveRelation DeterminesDomain) =
  "determines"
primitiveRelationLabel (SomePrimitiveRelation ContainsKPI) = "contains"
primitiveRelationLabel (SomePrimitiveRelation TranslatesIntoObjective) =
  "translates-into"
primitiveRelationLabel (SomePrimitiveRelation SubstantiatesObjective) =
  "substantiates"
primitiveRelationLabel (SomePrimitiveRelation SetsTargetForKPI) =
  "sets-target-for"
primitiveRelationLabel (SomePrimitiveRelation RefinesKPI) = "refines"
primitiveRelationLabel (SomePrimitiveRelation ActionContributesToKR) =
  "contributes-to"
primitiveRelationLabel (SomePrimitiveRelation ActionAddressesGap) = "addresses"

primitiveRelationDomain :: SomePrimitiveRelation -> (NodeKind, NodeKind)
primitiveRelationDomain (SomePrimitiveRelation GuidesDriver) =
  (PrimitiveKind Principle, PrimitiveKind Driver)
primitiveRelationDomain (SomePrimitiveRelation GuidesObjective) =
  (PrimitiveKind Principle, PrimitiveKind Objective)
primitiveRelationDomain (SomePrimitiveRelation MotivatesObjective) =
  (PrimitiveKind Driver, PrimitiveKind Objective)
primitiveRelationDomain (SomePrimitiveRelation DeterminesDomain) =
  (PrimitiveKind Driver, StructuringKind Domain)
primitiveRelationDomain (SomePrimitiveRelation ContainsKPI) =
  (StructuringKind Domain, PrimitiveKind KPI)
primitiveRelationDomain (SomePrimitiveRelation TranslatesIntoObjective) =
  (PrimitiveKind KeyResult, PrimitiveKind Objective)
primitiveRelationDomain (SomePrimitiveRelation SubstantiatesObjective) =
  (PrimitiveKind KeyResult, PrimitiveKind Objective)
primitiveRelationDomain (SomePrimitiveRelation SetsTargetForKPI) =
  (PrimitiveKind KeyResult, PrimitiveKind KPI)
primitiveRelationDomain (SomePrimitiveRelation RefinesKPI) =
  (PrimitiveKind KPI, PrimitiveKind KPI)
primitiveRelationDomain (SomePrimitiveRelation ActionContributesToKR) =
  (PrimitiveKind Action, PrimitiveKind KeyResult)
primitiveRelationDomain (SomePrimitiveRelation ActionAddressesGap) =
  (PrimitiveKind Action, PrimitiveKind Gap)
