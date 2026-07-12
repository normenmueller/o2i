{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}

-- | Type universes and singleton witnesses of the O2I semantic language.
--
-- Language modules define admissible O2I vocabulary independently of any
-- concrete graph. Graph modules instantiate this vocabulary; Validation
-- modules establish semantic claims about those graph instances.
module O2I.Language.Element
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
  ) where

import Data.Text (Text)
import Data.Type.Equality ((:~:)(Refl))

-- | Stable, untyped identifier supplied by a raw graph.
newtype RawNodeId = RawNodeId
  { rawNodeIdText :: Text -- ^ Identifier text; uniqueness is validated later.
  } deriving (Eq, Ord, Show)

-- | Identifier indexed by the statically known kind of its node.
newtype NodeId (kind :: NodeKind) = NodeId
  { unNodeId :: RawNodeId -- ^ Erase the kind index for runtime lookup.
  } deriving (Eq, Ord, Show)

-- | Reference to a context whose context type is known statically.
newtype ContextRef (context :: Context) = ContextRef
  { contextRefId :: RawNodeId -- ^ Runtime identifier of the context node.
  } deriving (Eq, Ord, Show)

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
  Domain -- ^ Named semantic domain that groups related model elements.
  deriving (Bounded, Enum, Eq, Ord, Show)

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

-- | Singleton witness that reifies a type-level 'Structuring'.
data SStructuring (structuring :: Structuring) where
  SDomain :: SStructuring 'Domain -- ^ Witness 'Domain'.

deriving instance Show (SStructuring structuring)

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
  SStructuringKind
    :: SContext context
    -> SStructuring structuring
    -> SNodeKind ('StructuringKind context structuring)
    -- ^ Witness a contextualized structuring-node kind.
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

-- | Existential structuring witness for runtime reification.
data SomeSStructuring where
  SomeSStructuring :: SStructuring structuring -> SomeSStructuring
    -- ^ Hide the structuring index while retaining its witness.

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

-- | Project a singleton structuring witness to its runtime value.
structuringValue :: SStructuring structuring -> Structuring
structuringValue SDomain = Domain

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
nodeKindValue (SStructuringKind context structuring) =
  StructuringNodeKind (contextValue context) (structuringValue structuring)
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

-- | Reify any runtime structuring value as an existential singleton witness.
someSStructuring :: Structuring -> SomeSStructuring
someSStructuring Domain = SomeSStructuring SDomain

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
