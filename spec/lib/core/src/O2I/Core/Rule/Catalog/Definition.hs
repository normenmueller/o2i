-- | Private static ownership of compiled Core rule explanations.
module O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(..)
  , ruleDefinition
  , ruleDefinitionAction
  , ruleDefinitionExpectation
  , ruleDefinitionIdentity
  , ruleDefinitionMeaning
  , ruleDefinitionStage
  ) where

import Data.Text (Text)
import O2I.Core.Contract.Internal (CoreRuleId(..))

-- | Closed processing stage that owns one Core rule.
data CoreRuleStage
  = CapabilityInputStage
  | QualificationStage
  | ReadinessAndAssessmentStage
  | SemanticsStage
  | StructureStage
  | TraceStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One compiled rule definition and its non-semantic explanation.
--
-- The texts are static projections only. Core evaluators neither consume this
-- type nor select behavior from any of its fields.
data CoreRuleDefinition =
  CoreRuleDefinition !CoreRuleId !CoreRuleStage !Text !Text !Text
  deriving (Eq, Ord, Show)

-- | Define one exact Core-owned rule explanation.
ruleDefinition ::
     Text -> CoreRuleStage -> Text -> Text -> Text -> CoreRuleDefinition
ruleDefinition identifier stage expectation meaning action =
  CoreRuleDefinition (CoreRuleId identifier) stage expectation meaning action

-- | Project the rule identity owned by this definition.
ruleDefinitionIdentity :: CoreRuleDefinition -> CoreRuleId
ruleDefinitionIdentity (CoreRuleDefinition identifier _ _ _ _) = identifier

-- | Project the closed stage owned by this definition.
ruleDefinitionStage :: CoreRuleDefinition -> CoreRuleStage
ruleDefinitionStage (CoreRuleDefinition _ stage _ _ _) = stage

-- | Project the normative expectation owned by this definition.
ruleDefinitionExpectation :: CoreRuleDefinition -> Text
ruleDefinitionExpectation (CoreRuleDefinition _ _ expectation _ _) = expectation

-- | Project the presentation meaning owned by this definition.
ruleDefinitionMeaning :: CoreRuleDefinition -> Text
ruleDefinitionMeaning (CoreRuleDefinition _ _ _ meaning _) = meaning

-- | Project the presentation action owned by this definition.
ruleDefinitionAction :: CoreRuleDefinition -> Text
ruleDefinitionAction (CoreRuleDefinition _ _ _ _ action) = action
