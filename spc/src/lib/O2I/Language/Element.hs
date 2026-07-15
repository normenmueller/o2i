{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}

-- | Type universes and singleton witnesses of the O2I semantic language.
--
-- Language modules define admissible O2I vocabulary independently of any
-- concrete graph. Graph modules instantiate this vocabulary; Validation
-- modules establish semantic claims about those graph instances.
module O2I.Language.Element
  ( RawNodeId(..)
  , NodeId
  , unNodeId
  , ContextRef
  , contextRefId
  , mkNodeId
  , mkContextRef
  , Context(..)
  , Primitive(..)
  , Structuring(..)
  , PerformanceDimensionRole(..)
  , PerformanceDimensionRoleCode(..)
  , PerformanceDimensionRoleName(..)
  , SomePerformanceDimensionRole(..)
  , SituationAnchor(..)
  , NodeKind(..)
  , SContext(..)
  , SPrimitive(..)
  , SSituationAnchor(..)
  , SNodeKind(..)
  , NodeKindValue(..)
  , SomeSContext(..)
  , SomeSPrimitive(..)
  , SomeSAnchor(..)
  , performanceDimensionRoleCode
  , performanceDimensionRoleCodeOf
  , performanceDimensionRoleName
  , performanceDimensionRoleNameOf
  , performanceDimensionRoleContext
  , performanceDimensionRoleMember
  , performanceDimensionMembershipRelationName
  , performanceDimensionRoleIdentity
  , allPerformanceDimensionRoles
  , reifyPerformanceDimensionRole
  , lookupPerformanceDimensionRole
  , contextValue
  , primitiveValue
  , anchorValue
  , nodeKindValue
  , someSContext
  , someSPrimitive
  , someSAnchor
  , eqSNodeKind
  ) where

import Data.Text (Text)
import Data.Type.Equality ((:~:)(Refl))

-- | Stable, untyped identifier supplied by a raw graph.
newtype RawNodeId = RawNodeId
  { rawNodeIdText :: Text -- ^ Identifier text; uniqueness is validated later.
  } deriving (Eq, Ord, Show)

type role NodeId nominal

-- | Opaque identifier whose node kind was established by validation.
newtype NodeId (kind :: NodeKind) =
  NodeId RawNodeId
  deriving (Eq, Ord, Show)

type role ContextRef nominal

-- | Opaque reference to a context whose type was established by validation.
newtype ContextRef (context :: Context) =
  ContextRef RawNodeId
  deriving (Eq, Ord, Show)

-- | Erase the validated node-kind index for runtime lookup.
unNodeId :: NodeId kind -> RawNodeId
unNodeId (NodeId identifier) = identifier

-- | Read the runtime identifier of a validated Context reference.
contextRefId :: ContextRef context -> RawNodeId
contextRefId (ContextRef identifier) = identifier

-- | Internally wrap an identifier after its node kind has been validated.
mkNodeId :: RawNodeId -> NodeId kind
mkNodeId = NodeId

-- | Internally wrap an identifier after its Context has been validated.
mkContextRef :: RawNodeId -> ContextRef context
mkContextRef = ContextRef

-- * Type universes
-- ** Contexts
-- | Closed universe of O2I interpretation contexts.
data Context
  = Ethos -- ^ Normative principles for what an actor stands for.
  | Mission -- ^ Enduring reason and motivating purpose.
  | Vision -- ^ Desired future orientation.
  | Strategy -- ^ Coherent strategic path decision.
  | Situation -- ^ Business-architecture setting in which needs surface.
  | Need -- ^ Situated requirement for change.
  | Intervention -- ^ Deliberate action that addresses a need.
  | Measure -- ^ Observation and target frame for effect evidence.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Primitives
-- | Closed universe of reusable semantic primitives.
data Primitive
  = Principle -- ^ Normative or guiding rule.
  | Driver -- ^ Motivating condition or diagnosed challenge.
  | Objective -- ^ Qualitative intended state.
  | KeyResult -- ^ Quantified result that substantiates an objective.
  | KPI -- ^ Stable definition of an observed quantity.
  | Action -- ^ Deliberate action hypothesis or commitment.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Structuring
-- | Closed universe of semantic organization outside Context and Primitive.
data Structuring =
  PerformanceDimension
    -- ^ Closed performance dimension owned by Strategy or Measure.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed proof of one admissible PerformanceDimension role and member kind.
--
-- No constructor exists for another Context or Primitive membership.
data PerformanceDimensionRole (context :: Context) (member :: Primitive) where
  StrategySuccessDimension :: PerformanceDimensionRole 'Strategy 'KeyResult
    -- ^ Strategy success dimension containing Strategy Key Results.
  MeasureMeasurementDimension :: PerformanceDimensionRole 'Measure 'KPI
    -- ^ Measure measurement dimension containing Measure KPIs.

deriving instance Show (PerformanceDimensionRole context member)

-- | Stable finite identity of an admissible PerformanceDimension role.
data PerformanceDimensionRoleCode
  = StrategySuccessDimensionCode -- ^ Code for 'StrategySuccessDimension'.
  | MeasureMeasurementDimensionCode -- ^ Code for 'MeasureMeasurementDimension'.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Stable semantic name of a PerformanceDimension role.
newtype PerformanceDimensionRoleName = PerformanceDimensionRoleName
  { performanceDimensionRoleNameText :: Text -- ^ Machine-readable role name.
  } deriving (Eq, Ord, Show)

-- ** Situation anchors
-- | Business-architecture forms that can constitute a Situation.
data SituationAnchor
  = BusinessCapability -- ^ Ability the business possesses or requires.
  | BusinessProcess -- ^ Structured business behavior.
  | BusinessObject -- ^ Business-relevant information or concept.
  | BusinessRole -- ^ Organizational responsibility or participation.
  | ValueStream -- ^ End-to-end progression that creates value.
  | RegulatoryConstraint -- ^ Externally imposed business constraint.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- ** Node kinds
-- | Type-level classification of every admissible graph node.
data NodeKind
  = ContextKind Context -- ^ Context node of the indexed context.
  | PrimitiveKind Context Primitive -- ^ Primitive interpreted in a context.
  | StructuringKind Context Structuring -- ^ Structure owned by a context.
  | AnchorKind SituationAnchor -- ^ Situation anchor of the indexed form.

-- * Singleton witnesses
-- | Singleton witness that reifies a type-level 'Context'.
data SContext (context :: Context) where
  SEthos :: SContext 'Ethos -- ^ Witness 'Ethos'.
  SMission :: SContext 'Mission -- ^ Witness 'Mission'.
  SVision :: SContext 'Vision -- ^ Witness 'Vision'.
  SStrategy :: SContext 'Strategy -- ^ Witness 'Strategy'.
  SSituation :: SContext 'Situation -- ^ Witness 'Situation'.
  SNeed :: SContext 'Need -- ^ Witness 'Need'.
  SIntervention :: SContext 'Intervention -- ^ Witness 'Intervention'.
  SMeasure :: SContext 'Measure -- ^ Witness 'Measure'.

deriving instance Show (SContext context)

-- | Singleton witness that reifies a type-level 'Primitive'.
data SPrimitive (primitive :: Primitive) where
  SPrinciple :: SPrimitive 'Principle -- ^ Witness 'Principle'.
  SDriver :: SPrimitive 'Driver -- ^ Witness 'Driver'.
  SObjective :: SPrimitive 'Objective -- ^ Witness 'Objective'.
  SKeyResult :: SPrimitive 'KeyResult -- ^ Witness 'KeyResult'.
  SKPI :: SPrimitive 'KPI -- ^ Witness 'KPI'.
  SAction :: SPrimitive 'Action -- ^ Witness 'Action'.

deriving instance Show (SPrimitive primitive)

-- | Existential role for heterogeneous runtime interpretation.
data SomePerformanceDimensionRole where
  SomePerformanceDimensionRole
    :: PerformanceDimensionRole context member -> SomePerformanceDimensionRole
    -- ^ Hide role indices while retaining their closed witness.

instance Eq SomePerformanceDimensionRole where
  left == right =
    performanceDimensionRoleCodeOf left == performanceDimensionRoleCodeOf right

instance Show SomePerformanceDimensionRole where
  show = show . performanceDimensionRoleNameOf

data PerformanceDimensionRoleSpec context member = PerformanceDimensionRoleSpec
  { roleSpecCode :: PerformanceDimensionRoleCode
  , roleSpecName :: PerformanceDimensionRoleName
  , roleSpecContext :: SContext context
  , roleSpecMember :: SPrimitive member
  , roleSpecMembershipName :: Text
  }

performanceDimensionRoleSpec ::
     PerformanceDimensionRole context member
  -> PerformanceDimensionRoleSpec context member
performanceDimensionRoleSpec StrategySuccessDimension =
  PerformanceDimensionRoleSpec
    { roleSpecCode = StrategySuccessDimensionCode
    , roleSpecName = PerformanceDimensionRoleName "strategy-success-dimension"
    , roleSpecContext = SStrategy
    , roleSpecMember = SKeyResult
    , roleSpecMembershipName =
        "strategy-performance-dimension-contains-strategy-key-result"
    }
performanceDimensionRoleSpec MeasureMeasurementDimension =
  PerformanceDimensionRoleSpec
    { roleSpecCode = MeasureMeasurementDimensionCode
    , roleSpecName =
        PerformanceDimensionRoleName "measure-measurement-dimension"
    , roleSpecContext = SMeasure
    , roleSpecMember = SKPI
    , roleSpecMembershipName =
        "measure-performance-dimension-contains-measure-kpi"
    }

-- | Return the stable code of a statically known PerformanceDimension role.
performanceDimensionRoleCode ::
     PerformanceDimensionRole context member -> PerformanceDimensionRoleCode
performanceDimensionRoleCode = roleSpecCode . performanceDimensionRoleSpec

-- | Return the stable code of an existential PerformanceDimension role.
performanceDimensionRoleCodeOf ::
     SomePerformanceDimensionRole -> PerformanceDimensionRoleCode
performanceDimensionRoleCodeOf (SomePerformanceDimensionRole role) =
  performanceDimensionRoleCode role

-- | Return the stable name of a statically known PerformanceDimension role.
performanceDimensionRoleName ::
     PerformanceDimensionRole context member -> PerformanceDimensionRoleName
performanceDimensionRoleName = roleSpecName . performanceDimensionRoleSpec

-- | Return the stable name of an existential PerformanceDimension role.
performanceDimensionRoleNameOf ::
     SomePerformanceDimensionRole -> PerformanceDimensionRoleName
performanceDimensionRoleNameOf (SomePerformanceDimensionRole role) =
  performanceDimensionRoleName role

-- | Reify the owning Context of a PerformanceDimension role.
performanceDimensionRoleContext ::
     PerformanceDimensionRole context member -> SContext context
performanceDimensionRoleContext = roleSpecContext . performanceDimensionRoleSpec

-- | Reify the only admissible member Primitive of a PerformanceDimension role.
performanceDimensionRoleMember ::
     PerformanceDimensionRole context member -> SPrimitive member
performanceDimensionRoleMember = roleSpecMember . performanceDimensionRoleSpec

-- | Return the stable serialized name of the role's membership relation.
performanceDimensionMembershipRelationName ::
     PerformanceDimensionRole context member -> Text
performanceDimensionMembershipRelationName =
  roleSpecMembershipName . performanceDimensionRoleSpec

-- | Project stable identity, name, Context, and member Primitive.
performanceDimensionRoleIdentity ::
     SomePerformanceDimensionRole
  -> ( PerformanceDimensionRoleCode
     , PerformanceDimensionRoleName
     , Context
     , Primitive)
performanceDimensionRoleIdentity (SomePerformanceDimensionRole role) =
  ( performanceDimensionRoleCode role
  , performanceDimensionRoleName role
  , contextValue (performanceDimensionRoleContext role)
  , primitiveValue (performanceDimensionRoleMember role))

-- | Complete registry of the two admissible PerformanceDimension roles.
allPerformanceDimensionRoles :: [SomePerformanceDimensionRole]
allPerformanceDimensionRoles =
  map reifyPerformanceDimensionRole [minBound .. maxBound]

-- | Reify a stable PerformanceDimension-role code as a typed witness.
reifyPerformanceDimensionRole ::
     PerformanceDimensionRoleCode -> SomePerformanceDimensionRole
reifyPerformanceDimensionRole StrategySuccessDimensionCode =
  SomePerformanceDimensionRole StrategySuccessDimension
reifyPerformanceDimensionRole MeasureMeasurementDimensionCode =
  SomePerformanceDimensionRole MeasureMeasurementDimension

-- | Resolve the unique PerformanceDimension role admitted for a runtime Context.
--
-- 'Nothing' means that the Context cannot own a PerformanceDimension.
lookupPerformanceDimensionRole :: Context -> Maybe SomePerformanceDimensionRole
lookupPerformanceDimensionRole context = go allPerformanceDimensionRoles
  where
    go [] = Nothing
    go (candidate@(SomePerformanceDimensionRole role):rest)
      | contextValue (performanceDimensionRoleContext role) == context =
        Just candidate
      | otherwise = go rest

-- | Singleton witness that reifies a type-level 'SituationAnchor'.
data SSituationAnchor (anchor :: SituationAnchor) where
  SBusinessCapability :: SSituationAnchor 'BusinessCapability
    -- ^ Witness 'BusinessCapability'.
  SBusinessProcess :: SSituationAnchor 'BusinessProcess
    -- ^ Witness 'BusinessProcess'.
  SBusinessObject :: SSituationAnchor 'BusinessObject
    -- ^ Witness 'BusinessObject'.
  SBusinessRole :: SSituationAnchor 'BusinessRole
    -- ^ Witness 'BusinessRole'.
  SValueStream :: SSituationAnchor 'ValueStream
    -- ^ Witness 'ValueStream'.
  SRegulatoryConstraint :: SSituationAnchor 'RegulatoryConstraint
    -- ^ Witness 'RegulatoryConstraint'.

deriving instance Show (SSituationAnchor anchor)

-- | Singleton witness for a complete type-level 'NodeKind'.
data SNodeKind (kind :: NodeKind) where
  SContextKind :: SContext context -> SNodeKind ('ContextKind context)
    -- ^ Witness a context-node kind.
  SPrimitiveKind
    :: SContext context
    -> SPrimitive primitive
    -> SNodeKind ('PrimitiveKind context primitive)
    -- ^ Witness a contextualized primitive-node kind.
  SPerformanceDimensionKind
    :: PerformanceDimensionRole context member
    -> SNodeKind ('StructuringKind context 'PerformanceDimension)
    -- ^ Witness a PerformanceDimension-node kind through its closed role.
  SAnchorKind :: SSituationAnchor anchor -> SNodeKind ('AnchorKind anchor)
    -- ^ Witness a Situation-anchor node kind.

deriving instance Show (SNodeKind kind)

-- | Existential context witness used when the context is known only at runtime.
data SomeSContext where
  SomeSContext :: SContext context -> SomeSContext
    -- ^ Hide the context index while retaining its witness.

-- | Existential primitive witness for runtime reification.
data SomeSPrimitive where
  SomeSPrimitive :: SPrimitive primitive -> SomeSPrimitive
    -- ^ Hide the primitive index while retaining its witness.

-- | Existential Situation-anchor witness for runtime reification.
data SomeSAnchor where
  SomeSAnchor :: SSituationAnchor anchor -> SomeSAnchor
    -- ^ Hide the anchor index while retaining its witness.

-- | Project a singleton context witness to its runtime value.
contextValue :: SContext context -> Context
contextValue SEthos = Ethos
contextValue SMission = Mission
contextValue SVision = Vision
contextValue SStrategy = Strategy
contextValue SSituation = Situation
contextValue SNeed = Need
contextValue SIntervention = Intervention
contextValue SMeasure = Measure

-- | Project a singleton primitive witness to its runtime value.
primitiveValue :: SPrimitive primitive -> Primitive
primitiveValue SPrinciple = Principle
primitiveValue SDriver = Driver
primitiveValue SObjective = Objective
primitiveValue SKeyResult = KeyResult
primitiveValue SKPI = KPI
primitiveValue SAction = Action

-- | Project a singleton anchor witness to its runtime value.
anchorValue :: SSituationAnchor anchor -> SituationAnchor
anchorValue SBusinessCapability = BusinessCapability
anchorValue SBusinessProcess = BusinessProcess
anchorValue SBusinessObject = BusinessObject
anchorValue SBusinessRole = BusinessRole
anchorValue SValueStream = ValueStream
anchorValue SRegulatoryConstraint = RegulatoryConstraint

-- | Erase a node-kind singleton while retaining its complete classification.
nodeKindValue :: SNodeKind kind -> NodeKindValue
nodeKindValue (SContextKind context) = ContextNodeKind (contextValue context)
nodeKindValue (SPrimitiveKind context primitive) =
  PrimitiveNodeKind (contextValue context) (primitiveValue primitive)
nodeKindValue (SPerformanceDimensionKind role) =
  StructuringNodeKind
    (contextValue (performanceDimensionRoleContext role))
    PerformanceDimension
nodeKindValue (SAnchorKind anchor) = AnchorNodeKind (anchorValue anchor)

-- | Runtime projection of a type-level 'NodeKind'.
data NodeKindValue
  = ContextNodeKind Context -- ^ A context node.
  | PrimitiveNodeKind Context Primitive -- ^ A contextualized primitive.
  | StructuringNodeKind Context Structuring -- ^ A contextual structure.
  | AnchorNodeKind SituationAnchor -- ^ A Situation anchor.
  deriving (Eq, Ord, Show)

-- | Reify any runtime context as an existential singleton witness.
someSContext :: Context -> SomeSContext
someSContext Ethos = SomeSContext SEthos
someSContext Mission = SomeSContext SMission
someSContext Vision = SomeSContext SVision
someSContext Strategy = SomeSContext SStrategy
someSContext Situation = SomeSContext SSituation
someSContext Need = SomeSContext SNeed
someSContext Intervention = SomeSContext SIntervention
someSContext Measure = SomeSContext SMeasure

-- | Reify any runtime primitive as an existential singleton witness.
someSPrimitive :: Primitive -> SomeSPrimitive
someSPrimitive Principle = SomeSPrimitive SPrinciple
someSPrimitive Driver = SomeSPrimitive SDriver
someSPrimitive Objective = SomeSPrimitive SObjective
someSPrimitive KeyResult = SomeSPrimitive SKeyResult
someSPrimitive KPI = SomeSPrimitive SKPI
someSPrimitive Action = SomeSPrimitive SAction

-- | Reify any runtime Situation anchor as an existential singleton witness.
someSAnchor :: SituationAnchor -> SomeSAnchor
someSAnchor BusinessCapability = SomeSAnchor SBusinessCapability
someSAnchor BusinessProcess = SomeSAnchor SBusinessProcess
someSAnchor BusinessObject = SomeSAnchor SBusinessObject
someSAnchor BusinessRole = SomeSAnchor SBusinessRole
someSAnchor ValueStream = SomeSAnchor SValueStream
someSAnchor RegulatoryConstraint = SomeSAnchor SRegulatoryConstraint

-- | Decide equality of two node-kind witnesses and return type equality proof.
eqSNodeKind :: SNodeKind left -> SNodeKind right -> Maybe (left :~: right)
eqSNodeKind (SContextKind left) (SContextKind right) = do
  Refl <- eqSContext left right
  pure Refl
eqSNodeKind (SPrimitiveKind lc lp) (SPrimitiveKind rc rp) = do
  Refl <- eqSContext lc rc
  Refl <- eqSPrimitive lp rp
  pure Refl
eqSNodeKind (SPerformanceDimensionKind left) (SPerformanceDimensionKind right) = do
  Refl <-
    eqSContext
      (performanceDimensionRoleContext left)
      (performanceDimensionRoleContext right)
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

eqSAnchor ::
     SSituationAnchor left -> SSituationAnchor right -> Maybe (left :~: right)
eqSAnchor SBusinessCapability SBusinessCapability = Just Refl
eqSAnchor SBusinessProcess SBusinessProcess = Just Refl
eqSAnchor SBusinessObject SBusinessObject = Just Refl
eqSAnchor SBusinessRole SBusinessRole = Just Refl
eqSAnchor SValueStream SValueStream = Just Refl
eqSAnchor SRegulatoryConstraint SRegulatoryConstraint = Just Refl
eqSAnchor _ _ = Nothing
