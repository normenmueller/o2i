{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

-- | O2I types: contexts, primitives, and interpretations.
module O2I.Elements
  ( ContextId(..)
  , PrimitiveId(..)
  , StructuringId(..)
  , AnchorId(..)
  , Context(..)
  , Primitive(..)
  , Structuring(..)
  , SituationAnchor(..)
  , NodeKind(..)
  , Ctx(..)
  , Prim(..)
  , Struct(..)
  , Anchor(..)
  , Interpretation(..)
  , SomeInterpretation(..)
  , interpretationDomain
  , allInterpretations
  , lookupInterpretation
  , allowedInterpretation
  ) where

import Data.List (find)
import Data.Maybe (isJust)

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

-- ** Typed handles
newtype Ctx (c :: Context) =
  Ctx ContextId

newtype Prim (c :: Context) (p :: Primitive) =
  Prim PrimitiveId

newtype Struct (c :: Context) (s :: Structuring) =
  Struct StructuringId

newtype Anchor (a :: SituationAnchor) =
  Anchor AnchorId

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

data SomeInterpretation where
  SomeInterpretation :: Interpretation ctx prim -> SomeInterpretation

interpretationDomain :: Interpretation ctx prim -> (Context, Primitive)
interpretationDomain PrincipleInEthos = (Ethos, Principle)
interpretationDomain DriverInMission = (Mission, Driver)
interpretationDomain ObjectiveInVision = (Vision, Objective)
interpretationDomain DriverInStrategy = (Strategy, Driver)
interpretationDomain ObjectiveInStrategy = (Strategy, Objective)
interpretationDomain PrincipleInStrategy = (Strategy, Principle)
interpretationDomain KeyResultInStrategy = (Strategy, KeyResult)
interpretationDomain ActionInStrategy = (Strategy, Action)
interpretationDomain DriverInNeed = (Need, Driver)
interpretationDomain ObjectiveInNeed = (Need, Objective)
interpretationDomain ActionInIntervention = (Intervention, Action)
interpretationDomain KeyResultInIntervention = (Intervention, KeyResult)
interpretationDomain KPIInMeasure = (Measure, KPI)

allInterpretations :: [SomeInterpretation]
allInterpretations =
  [ SomeInterpretation PrincipleInEthos
  , SomeInterpretation DriverInMission
  , SomeInterpretation ObjectiveInVision
  , SomeInterpretation DriverInStrategy
  , SomeInterpretation ObjectiveInStrategy
  , SomeInterpretation PrincipleInStrategy
  , SomeInterpretation KeyResultInStrategy
  , SomeInterpretation ActionInStrategy
  , SomeInterpretation DriverInNeed
  , SomeInterpretation ObjectiveInNeed
  , SomeInterpretation ActionInIntervention
  , SomeInterpretation KeyResultInIntervention
  , SomeInterpretation KPIInMeasure
  ]

lookupInterpretation :: Context -> Primitive -> Maybe SomeInterpretation
lookupInterpretation ctx prim = find matches allInterpretations
  where
    matches (SomeInterpretation interpretation) =
      interpretationDomain interpretation == (ctx, prim)

allowedInterpretation :: Context -> Primitive -> Bool
allowedInterpretation ctx prim = isJust (lookupInterpretation ctx prim)
-- * End of elements
