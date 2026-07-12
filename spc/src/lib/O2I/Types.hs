{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}

-- | O2I type universes, typed identifiers, and interpretations.
module O2I.Types
  ( RawNodeId(..)
  , NodeId(..)
  , ContextRef(..)
  , Context(..)
  , Primitive(..)
  , Structuring(..)
  , SituationAnchor(..)
  , NodeKind(..)
  , SContext(..)
  , SPrimitive(..)
  , SStructuring(..)
  , SSituationAnchor(..)
  , SNodeKind(..)
  , NodeKindValue(..)
  , SomeSContext(..)
  , SomeSPrimitive(..)
  , SomeSStructuring(..)
  , SomeSAnchor(..)
  , contextValue
  , primitiveValue
  , structuringValue
  , anchorValue
  , nodeKindValue
  , someSContext
  , someSPrimitive
  , someSStructuring
  , someSAnchor
  , eqSNodeKind
  , Interpretation(..)
  , InterpretationCode(..)
  , InterpretationSpec(..)
  , SomeInterpretation(..)
  , interpretationSpec
  , interpretationCodeOf
  , interpretationIdentity
  , allInterpretations
  , lookupInterpretation
  ) where

import Data.Text (Text)
import Data.Type.Equality ((:~:)(Refl))

newtype RawNodeId = RawNodeId
  { rawNodeIdText :: Text
  } deriving (Eq, Ord, Show)

newtype NodeId (kind :: NodeKind) = NodeId
  { unNodeId :: RawNodeId
  } deriving (Eq, Ord, Show)

newtype ContextRef (context :: Context) = ContextRef
  { contextRefId :: RawNodeId
  } deriving (Eq, Ord, Show)

-- * Type universes
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
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Primitives
data Primitive
  = Principle
  | Driver
  | Objective
  | KeyResult
  | KPI
  | Action
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Structuring
data Structuring =
  Domain
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Situation anchors
data SituationAnchor
  = BusinessCapability
  | BusinessProcess
  | BusinessObject
  | BusinessRole
  | ValueStream
  | RegulatoryConstraint
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Node kinds
data NodeKind
  = ContextKind Context
  | PrimitiveKind Context Primitive
  | StructuringKind Context Structuring
  | AnchorKind SituationAnchor

-- * Singleton witnesses
data SContext (context :: Context) where
  SEthos :: SContext 'Ethos
  SMission :: SContext 'Mission
  SVision :: SContext 'Vision
  SStrategy :: SContext 'Strategy
  SSituation :: SContext 'Situation
  SNeed :: SContext 'Need
  SIntervention :: SContext 'Intervention
  SMeasure :: SContext 'Measure

deriving instance Show (SContext context)

data SPrimitive (primitive :: Primitive) where
  SPrinciple :: SPrimitive 'Principle
  SDriver :: SPrimitive 'Driver
  SObjective :: SPrimitive 'Objective
  SKeyResult :: SPrimitive 'KeyResult
  SKPI :: SPrimitive 'KPI
  SAction :: SPrimitive 'Action

deriving instance Show (SPrimitive primitive)

data SStructuring (structuring :: Structuring) where
  SDomain :: SStructuring 'Domain

deriving instance Show (SStructuring structuring)

data SSituationAnchor (anchor :: SituationAnchor) where
  SBusinessCapability :: SSituationAnchor 'BusinessCapability
  SBusinessProcess :: SSituationAnchor 'BusinessProcess
  SBusinessObject :: SSituationAnchor 'BusinessObject
  SBusinessRole :: SSituationAnchor 'BusinessRole
  SValueStream :: SSituationAnchor 'ValueStream
  SRegulatoryConstraint :: SSituationAnchor 'RegulatoryConstraint

deriving instance Show (SSituationAnchor anchor)

data SNodeKind (kind :: NodeKind) where
  SContextKind :: SContext context -> SNodeKind ('ContextKind context)
  SPrimitiveKind
    :: SContext context
    -> SPrimitive primitive
    -> SNodeKind ('PrimitiveKind context primitive)
  SStructuringKind
    :: SContext context
    -> SStructuring structuring
    -> SNodeKind ('StructuringKind context structuring)
  SAnchorKind :: SSituationAnchor anchor -> SNodeKind ('AnchorKind anchor)

deriving instance Show (SNodeKind kind)

data SomeSContext where
  SomeSContext :: SContext context -> SomeSContext

data SomeSPrimitive where
  SomeSPrimitive :: SPrimitive primitive -> SomeSPrimitive

data SomeSStructuring where
  SomeSStructuring :: SStructuring structuring -> SomeSStructuring

data SomeSAnchor where
  SomeSAnchor :: SSituationAnchor anchor -> SomeSAnchor

contextValue :: SContext context -> Context
contextValue SEthos = Ethos
contextValue SMission = Mission
contextValue SVision = Vision
contextValue SStrategy = Strategy
contextValue SSituation = Situation
contextValue SNeed = Need
contextValue SIntervention = Intervention
contextValue SMeasure = Measure

primitiveValue :: SPrimitive primitive -> Primitive
primitiveValue SPrinciple = Principle
primitiveValue SDriver = Driver
primitiveValue SObjective = Objective
primitiveValue SKeyResult = KeyResult
primitiveValue SKPI = KPI
primitiveValue SAction = Action

structuringValue :: SStructuring structuring -> Structuring
structuringValue SDomain = Domain

anchorValue :: SSituationAnchor anchor -> SituationAnchor
anchorValue SBusinessCapability = BusinessCapability
anchorValue SBusinessProcess = BusinessProcess
anchorValue SBusinessObject = BusinessObject
anchorValue SBusinessRole = BusinessRole
anchorValue SValueStream = ValueStream
anchorValue SRegulatoryConstraint = RegulatoryConstraint

nodeKindValue :: SNodeKind kind -> NodeKindValue
nodeKindValue (SContextKind context) = ContextNodeKind (contextValue context)
nodeKindValue (SPrimitiveKind context primitive) =
  PrimitiveNodeKind (contextValue context) (primitiveValue primitive)
nodeKindValue (SStructuringKind context structuring) =
  StructuringNodeKind (contextValue context) (structuringValue structuring)
nodeKindValue (SAnchorKind anchor) = AnchorNodeKind (anchorValue anchor)

data NodeKindValue
  = ContextNodeKind Context
  | PrimitiveNodeKind Context Primitive
  | StructuringNodeKind Context Structuring
  | AnchorNodeKind SituationAnchor
  deriving (Eq, Ord, Show)

someSContext :: Context -> SomeSContext
someSContext Ethos = SomeSContext SEthos
someSContext Mission = SomeSContext SMission
someSContext Vision = SomeSContext SVision
someSContext Strategy = SomeSContext SStrategy
someSContext Situation = SomeSContext SSituation
someSContext Need = SomeSContext SNeed
someSContext Intervention = SomeSContext SIntervention
someSContext Measure = SomeSContext SMeasure

someSPrimitive :: Primitive -> SomeSPrimitive
someSPrimitive Principle = SomeSPrimitive SPrinciple
someSPrimitive Driver = SomeSPrimitive SDriver
someSPrimitive Objective = SomeSPrimitive SObjective
someSPrimitive KeyResult = SomeSPrimitive SKeyResult
someSPrimitive KPI = SomeSPrimitive SKPI
someSPrimitive Action = SomeSPrimitive SAction

someSStructuring :: Structuring -> SomeSStructuring
someSStructuring Domain = SomeSStructuring SDomain

someSAnchor :: SituationAnchor -> SomeSAnchor
someSAnchor BusinessCapability = SomeSAnchor SBusinessCapability
someSAnchor BusinessProcess = SomeSAnchor SBusinessProcess
someSAnchor BusinessObject = SomeSAnchor SBusinessObject
someSAnchor BusinessRole = SomeSAnchor SBusinessRole
someSAnchor ValueStream = SomeSAnchor SValueStream
someSAnchor RegulatoryConstraint = SomeSAnchor SRegulatoryConstraint

eqSNodeKind :: SNodeKind left -> SNodeKind right -> Maybe (left :~: right)
eqSNodeKind (SContextKind left) (SContextKind right) = do
  Refl <- eqSContext left right
  pure Refl
eqSNodeKind (SPrimitiveKind lc lp) (SPrimitiveKind rc rp) = do
  Refl <- eqSContext lc rc
  Refl <- eqSPrimitive lp rp
  pure Refl
eqSNodeKind (SStructuringKind lc ls) (SStructuringKind rc rs) = do
  Refl <- eqSContext lc rc
  Refl <- eqSStructuring ls rs
  pure Refl
eqSNodeKind (SAnchorKind left) (SAnchorKind right) = do
  Refl <- eqSAnchor left right
  pure Refl
eqSNodeKind _ _ = Nothing

eqSContext :: SContext left -> SContext right -> Maybe (left :~: right)
eqSContext SEthos SEthos = Just Refl
eqSContext SMission SMission = Just Refl
eqSContext SVision SVision = Just Refl
eqSContext SStrategy SStrategy = Just Refl
eqSContext SSituation SSituation = Just Refl
eqSContext SNeed SNeed = Just Refl
eqSContext SIntervention SIntervention = Just Refl
eqSContext SMeasure SMeasure = Just Refl
eqSContext _ _ = Nothing

eqSPrimitive :: SPrimitive left -> SPrimitive right -> Maybe (left :~: right)
eqSPrimitive SPrinciple SPrinciple = Just Refl
eqSPrimitive SDriver SDriver = Just Refl
eqSPrimitive SObjective SObjective = Just Refl
eqSPrimitive SKeyResult SKeyResult = Just Refl
eqSPrimitive SKPI SKPI = Just Refl
eqSPrimitive SAction SAction = Just Refl
eqSPrimitive _ _ = Nothing

eqSStructuring ::
     SStructuring left -> SStructuring right -> Maybe (left :~: right)
eqSStructuring SDomain SDomain = Just Refl

eqSAnchor ::
     SSituationAnchor left -> SSituationAnchor right -> Maybe (left :~: right)
eqSAnchor SBusinessCapability SBusinessCapability = Just Refl
eqSAnchor SBusinessProcess SBusinessProcess = Just Refl
eqSAnchor SBusinessObject SBusinessObject = Just Refl
eqSAnchor SBusinessRole SBusinessRole = Just Refl
eqSAnchor SValueStream SValueStream = Just Refl
eqSAnchor SRegulatoryConstraint SRegulatoryConstraint = Just Refl
eqSAnchor _ _ = Nothing

-- * Contextual interpretations
-- ** Interpretations
data Interpretation (context :: Context) (primitive :: Primitive) where
  PrincipleInEthos :: Interpretation 'Ethos 'Principle
  DriverInMission :: Interpretation 'Mission 'Driver
  ObjectiveInVision :: Interpretation 'Vision 'Objective
  DriverInStrategy :: Interpretation 'Strategy 'Driver
  ObjectiveInStrategy :: Interpretation 'Strategy 'Objective
  PrincipleInStrategy :: Interpretation 'Strategy 'Principle
  KeyResultInStrategy :: Interpretation 'Strategy 'KeyResult
  ActionInStrategy :: Interpretation 'Strategy 'Action
  DriverInNeed :: Interpretation 'Need 'Driver
  ObjectiveInNeed :: Interpretation 'Need 'Objective
  ActionInIntervention :: Interpretation 'Intervention 'Action
  KeyResultInIntervention :: Interpretation 'Intervention 'KeyResult
  KPIInMeasure :: Interpretation 'Measure 'KPI

deriving instance Show (Interpretation context primitive)

-- ** Interpretation registry
data InterpretationSpec context primitive = InterpretationSpec
  { interpretationCode :: InterpretationCode
  , interpretationContext :: SContext context
  , interpretationPrimitive :: SPrimitive primitive
  , interpretationWitness :: Interpretation context primitive
  }

data SomeInterpretation where
  SomeInterpretation
    :: InterpretationSpec context primitive -> SomeInterpretation

instance Show SomeInterpretation where
  show (SomeInterpretation spec) = show (interpretationCode spec)

data InterpretationCode
  = PrincipleInEthosCode
  | DriverInMissionCode
  | ObjectiveInVisionCode
  | DriverInStrategyCode
  | ObjectiveInStrategyCode
  | PrincipleInStrategyCode
  | KeyResultInStrategyCode
  | ActionInStrategyCode
  | DriverInNeedCode
  | ObjectiveInNeedCode
  | ActionInInterventionCode
  | KeyResultInInterventionCode
  | KPIInMeasureCode
  deriving (Bounded, Enum, Eq, Ord, Show)

interpretationSpec ::
     Interpretation context primitive -> InterpretationSpec context primitive
interpretationSpec PrincipleInEthos =
  InterpretationSpec PrincipleInEthosCode SEthos SPrinciple PrincipleInEthos
interpretationSpec DriverInMission =
  InterpretationSpec DriverInMissionCode SMission SDriver DriverInMission
interpretationSpec ObjectiveInVision =
  InterpretationSpec ObjectiveInVisionCode SVision SObjective ObjectiveInVision
interpretationSpec DriverInStrategy =
  InterpretationSpec DriverInStrategyCode SStrategy SDriver DriverInStrategy
interpretationSpec ObjectiveInStrategy =
  InterpretationSpec
    ObjectiveInStrategyCode
    SStrategy
    SObjective
    ObjectiveInStrategy
interpretationSpec PrincipleInStrategy =
  InterpretationSpec
    PrincipleInStrategyCode
    SStrategy
    SPrinciple
    PrincipleInStrategy
interpretationSpec KeyResultInStrategy =
  InterpretationSpec
    KeyResultInStrategyCode
    SStrategy
    SKeyResult
    KeyResultInStrategy
interpretationSpec ActionInStrategy =
  InterpretationSpec ActionInStrategyCode SStrategy SAction ActionInStrategy
interpretationSpec DriverInNeed =
  InterpretationSpec DriverInNeedCode SNeed SDriver DriverInNeed
interpretationSpec ObjectiveInNeed =
  InterpretationSpec ObjectiveInNeedCode SNeed SObjective ObjectiveInNeed
interpretationSpec ActionInIntervention =
  InterpretationSpec
    ActionInInterventionCode
    SIntervention
    SAction
    ActionInIntervention
interpretationSpec KeyResultInIntervention =
  InterpretationSpec
    KeyResultInInterventionCode
    SIntervention
    SKeyResult
    KeyResultInIntervention
interpretationSpec KPIInMeasure =
  InterpretationSpec KPIInMeasureCode SMeasure SKPI KPIInMeasure

allInterpretations :: [SomeInterpretation]
allInterpretations = map interpretationFromCode [minBound .. maxBound]

interpretationFromCode :: InterpretationCode -> SomeInterpretation
interpretationFromCode PrincipleInEthosCode =
  SomeInterpretation (interpretationSpec PrincipleInEthos)
interpretationFromCode DriverInMissionCode =
  SomeInterpretation (interpretationSpec DriverInMission)
interpretationFromCode ObjectiveInVisionCode =
  SomeInterpretation (interpretationSpec ObjectiveInVision)
interpretationFromCode DriverInStrategyCode =
  SomeInterpretation (interpretationSpec DriverInStrategy)
interpretationFromCode ObjectiveInStrategyCode =
  SomeInterpretation (interpretationSpec ObjectiveInStrategy)
interpretationFromCode PrincipleInStrategyCode =
  SomeInterpretation (interpretationSpec PrincipleInStrategy)
interpretationFromCode KeyResultInStrategyCode =
  SomeInterpretation (interpretationSpec KeyResultInStrategy)
interpretationFromCode ActionInStrategyCode =
  SomeInterpretation (interpretationSpec ActionInStrategy)
interpretationFromCode DriverInNeedCode =
  SomeInterpretation (interpretationSpec DriverInNeed)
interpretationFromCode ObjectiveInNeedCode =
  SomeInterpretation (interpretationSpec ObjectiveInNeed)
interpretationFromCode ActionInInterventionCode =
  SomeInterpretation (interpretationSpec ActionInIntervention)
interpretationFromCode KeyResultInInterventionCode =
  SomeInterpretation (interpretationSpec KeyResultInIntervention)
interpretationFromCode KPIInMeasureCode =
  SomeInterpretation (interpretationSpec KPIInMeasure)

lookupInterpretation :: Context -> Primitive -> Maybe SomeInterpretation
lookupInterpretation context primitive = go allInterpretations
  where
    go [] = Nothing
    go (candidate@(SomeInterpretation spec):rest)
      | contextValue (interpretationContext spec) == context
          && primitiveValue (interpretationPrimitive spec) == primitive =
        Just candidate
      | otherwise = go rest

interpretationCodeOf :: SomeInterpretation -> InterpretationCode
interpretationCodeOf (SomeInterpretation spec) = interpretationCode spec

interpretationIdentity :: SomeInterpretation -> (Context, Primitive)
interpretationIdentity (SomeInterpretation spec) =
  ( contextValue (interpretationContext spec)
  , primitiveValue (interpretationPrimitive spec))
