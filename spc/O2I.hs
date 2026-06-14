{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

module O2I where

newtype ContextId =
  ContextId String

newtype PrimitiveId =
  PrimitiveId String

newtype StructuringId =
  StructuringId String

-- * Contexts
data Context
  = Ethos
  | Mission
  | Vision
  | Strategy
  | Need
  | Intervention
  | Measure
  | Situation

-- * Primitives
data Primitive
  = Principle
  | Driver
  | Objective
  | KeyResult
  | KPI
  | Action
  | Gap

-- * Structuring
data Structuring =
  KPIDomain

-- * Typed instances
newtype Ctx (c :: Context) =
  Ctx ContextId

newtype Prim (p :: Primitive) =
  Prim PrimitiveId

newtype Struct (s :: Structuring) =
  Struct StructuringId

-- * Context relations
data ContextRelation (from :: Context) (to :: Context) where
  GuidesMission :: ContextRelation Ethos Mission
  MotivatesVision :: ContextRelation Mission Vision
  GuidesVision :: ContextRelation Ethos Vision
  OrientsStrategy :: ContextRelation Vision Strategy
  DirectsStrategy :: ContextRelation Strategy Strategy
  ContributesToStrategy :: ContextRelation Strategy Strategy
  QualifiesNeed :: ContextRelation Strategy Need
  SurfacesNeed :: ContextRelation Situation Need
  RefinesNeed :: ContextRelation Need Need
  IsGroundedInSituation :: ContextRelation Need Situation
  NeedContributesToStrategy :: ContextRelation Need Strategy
  AddressesNeed :: ContextRelation Intervention Need
  RequiresIntervention :: ContextRelation Need Intervention
  DirectsIntervention :: ContextRelation Strategy Intervention
  InterventionContributesToStrategy :: ContextRelation Intervention Strategy
  ChangesSituation :: ContextRelation Intervention Situation
  SetsTargetForMeasure :: ContextRelation Intervention Measure
  MeasuresSituation :: ContextRelation Measure Situation
  FramesMeasure :: ContextRelation Strategy Measure

-- * Primitive nodes
data Node
  = PrimitiveNode Primitive
  | StructuringNode Structuring

-- * Primitive relations
data PrimitiveRelation (from :: Node) (to :: Node) where
  GuidesDriver
    :: PrimitiveRelation (PrimitiveNode Principle) (PrimitiveNode Driver)
  GuidesObjective
    :: PrimitiveRelation (PrimitiveNode Principle) (PrimitiveNode Objective)
  MotivatesObjective
    :: PrimitiveRelation (PrimitiveNode Driver) (PrimitiveNode Objective)
  DeterminesKPIDomain
    :: PrimitiveRelation (PrimitiveNode Driver) (StructuringNode KPIDomain)
  ContainsKPI
    :: PrimitiveRelation (StructuringNode KPIDomain) (PrimitiveNode KPI)
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

-- * Well-formedness invariants
wfEthos :: Ctx Ethos -> Bool
wfEthos e = length (principlesIn e) >= 1

wfMission :: Ctx Mission -> Bool
wfMission m = length (driversIn m) >= 1

wfVision :: Ctx Vision -> Bool
wfVision v = length (objectivesIn v) >= 1

effRelevant :: Ctx Need -> Bool
effRelevant need = surfacedInSituation need && qualifiedByStrategy need

wfIntervention :: Ctx Intervention -> Bool
wfIntervention i = all effRelevant (addressedNeeds i)

wfGap :: Prim Gap -> Bool
wfGap g = existsTargetValue g && existsActualValue g

-- * Well-formedness support
principlesIn :: Ctx Ethos -> [Prim Principle]
principlesIn = undefined

driversIn :: Ctx Mission -> [Prim Driver]
driversIn = undefined

objectivesIn :: Ctx Vision -> [Prim Objective]
objectivesIn = undefined

surfacedInSituation :: Ctx Need -> Bool
surfacedInSituation = undefined

qualifiedByStrategy :: Ctx Need -> Bool
qualifiedByStrategy = undefined

addressedNeeds :: Ctx Intervention -> [Ctx Need]
addressedNeeds = undefined

existsTargetValue :: Prim Gap -> Bool
existsTargetValue = undefined

existsActualValue :: Prim Gap -> Bool
existsActualValue = undefined
