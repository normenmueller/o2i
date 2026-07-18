{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Semantic completeness of structurally valid O2I graphs.
--
-- This validation stage establishes global Situation and Need invariants and
-- complete, coherent Strategy formulations before effect traces may be derived.
module O2I.Validation.Semantics
  ( StrategyAnchoring(..)
  , RawStrategyFormulation(..)
  , StrategyFormulation
  , StrategyTextField(..)
  , StrategyPrimitiveRole(..)
  , ModelInvariantError(..)
  , SemanticallyValidModel
  , validateModelSemantics
  , modelGraph
  , strategyFormulations
  , strategyFormulationData
  , lookupSemanticContextRef
  , qualifyingStrategies
  ) where

import Data.List (group, nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation

-- * Strategy formulation input
-- | Organizational and procedural anchoring of a Strategy.
data StrategyAnchoring = StrategyAnchoring
  { anchoringPeriod :: Text -- ^ Temporal applicability.
  , anchoringResponsibilityScope :: Text -- ^ Organizational ownership scope.
  , anchoringDecisionLevel :: Text -- ^ Authorized decision level.
  , anchoringResponsibilities :: NonEmpty Text -- ^ Accountable roles or bodies.
  , anchoringDecisionPaths :: NonEmpty Text -- ^ Governing decision paths.
  , anchoringImplementationLogic :: Text -- ^ Logic that carries execution.
  } deriving (Eq, Show)

-- | Unchecked formulation of the mandatory constituents of one Strategy.
data RawStrategyFormulation = RawStrategyFormulation
  { rawFormulationStrategy :: RawNodeId -- ^ Strategy context being formulated.
  , rawFormulationScope :: NonEmpty Text -- ^ Declared applicability boundaries.
  , rawFormulationAnchoring :: StrategyAnchoring -- ^ Organizational embedding.
  , rawFormulationGuardrails :: NonEmpty Text -- ^ Constraints inherited or set.
  , rawFormulationDiagnosis :: RawNodeId -- ^ Strategy Driver reference.
  , rawFormulationIntent :: RawNodeId -- ^ Strategy Objective reference.
  , rawFormulationGuidingPolicy :: RawNodeId -- ^ Strategy Principle reference.
  , rawFormulationPositioning :: NonEmpty Text -- ^ Distinct strategic position.
  , rawFormulationTradeOffs :: NonEmpty Text -- ^ Explicit strategic exclusions.
  , rawFormulationActions :: NonEmpty RawNodeId -- ^ Coherent Action references.
  , rawFormulationKeyResults :: NonEmpty RawNodeId -- ^ Strategic Key Results.
  , rawFormulationFitRationale :: NonEmpty Text -- ^ Stated coherence rationale.
  } deriving (Eq, Show)

-- | A Strategy formulation whose completeness and coherence are established.
newtype StrategyFormulation = StrategyFormulation
  { validatedStrategyFormulation :: RawStrategyFormulation
    -- ^ Source formulation whose invariants have been established.
  } deriving (Eq, Show)

-- | Text-bearing fields whose entries must carry semantic content.
data StrategyTextField
  = ScopeField -- ^ Applicability scope.
  | PeriodField -- ^ Temporal applicability.
  | ResponsibilityScopeField -- ^ Organizational ownership scope.
  | DecisionLevelField -- ^ Authorized decision level.
  | ResponsibilitiesField -- ^ Accountable roles or bodies.
  | DecisionPathsField -- ^ Governing decision paths.
  | ImplementationLogicField -- ^ Execution-carrying logic.
  | GuardrailsField -- ^ Constraints inherited or set.
  | PositioningField -- ^ Distinct strategic position.
  | TradeOffsField -- ^ Explicit strategic exclusions.
  | FitRationaleField -- ^ Coherence rationale.
  deriving (Eq, Ord, Show)

-- | Primitive roles required by a complete Strategy formulation.
data StrategyPrimitiveRole
  = DiagnosisRole -- ^ Driver expressing the decisive challenge.
  | IntentRole -- ^ Objective expressing the intended contribution.
  | GuidingPolicyRole -- ^ Principle expressing the chosen approach.
  | CoherentActionRole -- ^ Action expressing a strategic commitment.
  | StrategicKeyResultRole -- ^ Key Result expressing strategic evidence.
  deriving (Eq, Ord, Show)

-- | Accumulated semantic invariant violations.
data ModelInvariantError
  = SituationWithoutConstitutingAnchor RawNodeId
    -- ^ A Situation has no admissible anchor that constitutes it.
  | NeedWithoutDriver RawNodeId
    -- ^ A Need has no Driver that states its situated motivation.
  | NeedWithoutObjective RawNodeId
    -- ^ A Need has no Objective that states the required change.
  | NeedWithoutSurfacingSituation RawNodeId
    -- ^ No Situation surfaces the Need through the context relation.
  | UnanchoredNeedDriver RawNodeId RawNodeId
    -- ^ A Need Driver is not attached to a constituent Situation anchor.
  | UngroundedNeedObjective RawNodeId RawNodeId
    -- ^ A Need Objective is not grounded by a Driver of the same Need.
  | StrategyWithoutFormulation RawNodeId
    -- ^ A Strategy context has no submitted formulation.
  | DuplicateStrategyFormulation RawNodeId
    -- ^ More than one formulation targets the same Strategy context.
  | UnknownFormulationStrategy RawNodeId
    -- ^ A formulation targets an unknown graph node.
  | FormulationForNonStrategy RawNodeId NodeKindValue
    -- ^ A formulation targets a node that is not a Strategy context.
  | EmptyStrategyText RawNodeId StrategyTextField
    -- ^ A mandatory textual Strategy constituent is blank.
  | DuplicateStrategyPrimitiveReference
      RawNodeId
      StrategyPrimitiveRole
      RawNodeId
    -- ^ A repeated reference occurs within a multi-valued Strategy role.
  | InvalidStrategyPrimitiveReference
      RawNodeId
      StrategyPrimitiveRole
      RawNodeId
      Primitive
    -- ^ A role reference has the wrong owner, kind, or identifier.
  | StrategyActionWithoutKeyResult RawNodeId RawNodeId
    -- ^ A coherent Action contributes to no listed strategic Key Result.
  | MissingStrategyCoherence RawNodeId RawNodeId RelationName RawNodeId
    -- ^ A required relation between valid formulation roles is absent.
  deriving (Eq, Show)

-- | A structurally valid graph with complete Situation, Need, and Strategy
-- semantics.
data SemanticallyValidModel = SemanticallyValidModel
  { semanticallyValidGraph :: WellFormedGraph -- ^ Structurally valid graph.
  , semanticallyValidStrategies :: Map RawNodeId StrategyFormulation
    -- ^ Exactly one complete formulation for every Strategy context.
  }

-- * Semantic validation
-- | Establish global Situation and Need invariants and complete Strategy
-- formulations.
--
-- The input graph must already be structurally valid. Independent semantic
-- errors accumulate. Success guarantees every Situation has a constituting
-- anchor, every Need is situated and grounded, and every Strategy has one
-- nonblank, role-correct, coherent formulation.
validateModelSemantics ::
     WellFormedGraph
  -> [RawStrategyFormulation]
  -> Validation (NonEmpty ModelInvariantError) SemanticallyValidModel
validateModelSemantics graph rawFormulations =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      Success
        SemanticallyValidModel
          { semanticallyValidGraph = graph
          , semanticallyValidStrategies =
              Map.fromList
                [ ( rawFormulationStrategy formulation
                  , StrategyFormulation formulation)
                | formulation <- rawFormulations
                ]
          }
  where
    errors =
      situationErrors graph
        ++ needErrors graph
        ++ formulationCoverageErrors graph rawFormulations
        ++ concatMap (formulationErrors graph) rawFormulations

-- * Validated model access
-- | Access the structurally well-formed graph underlying semantic validation.
modelGraph :: SemanticallyValidModel -> WellFormedGraph
modelGraph = semanticallyValidGraph

-- | Access the complete Strategy formulations indexed by Strategy context.
strategyFormulations ::
     SemanticallyValidModel -> Map RawNodeId StrategyFormulation
strategyFormulations = semanticallyValidStrategies

-- | Access the validated source data of one Strategy formulation.
strategyFormulationData :: StrategyFormulation -> RawStrategyFormulation
strategyFormulationData = validatedStrategyFormulation

-- | Resolve a raw identifier as a typed Context in a semantic model.
lookupSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> Maybe (ContextRef context)
lookupSemanticContextRef semantic = lookupContextRef (modelGraph semantic)

-- | Find Strategies that qualify one situated Need.
--
-- A result requires both the Strategy-to-Need macrorelation and its primitive
-- evidence from a Key Result listed in that Strategy's validated formulation
-- to an Objective owned by the requested Need. An empty result means that the
-- Need is situated but not strategically qualified.
qualifyingStrategies ::
     SemanticallyValidModel -> ContextRef 'Need -> [ContextRef 'Strategy]
qualifyingStrategies semantic need =
  [ mkContextRef strategy
  | strategy <- contextNodesOf graph Strategy
  , hasRelation graph strategy qualifiesNeed needIdentifier
  , Just formulation <- [Map.lookup strategy (strategyFormulations semantic)]
  , let keyResults =
          NonEmpty.toList
            (rawFormulationKeyResults (strategyFormulationData formulation))
  , any
      (\keyResult ->
         any
           (hasRelation
              graph
              keyResult
              translatesStrategyKeyResultToNeedObjective)
           needObjectives)
      keyResults
  ]
  where
    graph = modelGraph semantic
    needIdentifier = contextRefId need
    needObjectives = primitiveNodesIn graph needIdentifier Objective

situationErrors :: WellFormedGraph -> [ModelInvariantError]
situationErrors graph =
  [ SituationWithoutConstitutingAnchor situation
  | situation <- contextNodesOf graph Situation
  , null (constitutingAnchorNodes graph situation)
  ]

needErrors :: WellFormedGraph -> [ModelInvariantError]
needErrors graph = concatMap errorsForNeed (contextNodesOf graph Need)
  where
    errorsForNeed need =
      missingDriverErrors
        ++ missingObjectiveErrors
        ++ missingSituationErrors
        ++ concatMap driverErrors drivers
        ++ concatMap objectiveErrors objectives
      where
        drivers = primitiveNodesIn graph need Driver
        objectives = primitiveNodesIn graph need Objective
        situations = surfacingSituations graph need
        situatedAnchors = concatMap (constitutingAnchorNodes graph) situations
        missingDriverErrors = [NeedWithoutDriver need | null drivers]
        missingObjectiveErrors = [NeedWithoutObjective need | null objectives]
        missingSituationErrors =
          [NeedWithoutSurfacingSituation need | null situations]
        driverErrors driver =
          [ UnanchoredNeedDriver need driver
          | not (any (`anchorsDriver` driver) situatedAnchors)
          ]
        objectiveErrors objective =
          [ UngroundedNeedObjective need objective
          | not
              (any
                 (\driver ->
                    hasRelation
                      graph
                      driver
                      groundsNeedDriverToObjective
                      objective)
                 drivers)
          ]
        anchorsDriver anchor driver =
          any
            (\relation -> hasEdge graph anchor relation driver)
            anchorNeedDriverRelationNames

surfacingSituations :: WellFormedGraph -> RawNodeId -> [RawNodeId]
surfacingSituations graph need =
  [ situation
  | situation <- contextNodesOf graph Situation
  , hasRelation graph situation surfacesNeed need
  ]

formulationCoverageErrors ::
     WellFormedGraph -> [RawStrategyFormulation] -> [ModelInvariantError]
formulationCoverageErrors graph formulations = missingErrors ++ duplicateErrors
  where
    strategies = contextNodesOf graph Strategy
    formulationIds = map rawFormulationStrategy formulations
    missingErrors =
      [ StrategyWithoutFormulation strategy
      | strategy <- strategies
      , strategy `notElem` formulationIds
      ]
    duplicateErrors =
      [ DuplicateStrategyFormulation strategy
      | strategy <- duplicates formulationIds
      ]

formulationErrors ::
     WellFormedGraph -> RawStrategyFormulation -> [ModelInvariantError]
formulationErrors graph formulation =
  contextErrors
    ++ textErrors formulation
    ++ duplicateReferenceErrors formulation
    ++ if null contextErrors
         then primitiveErrors ++ coherenceErrors graph formulation
         else []
  where
    contextErrors = strategyReferenceErrors graph formulation
    primitiveErrors = primitiveReferenceErrors graph formulation

strategyReferenceErrors ::
     WellFormedGraph -> RawStrategyFormulation -> [ModelInvariantError]
strategyReferenceErrors graph formulation =
  case lookupNode graph strategy of
    Nothing -> [UnknownFormulationStrategy strategy]
    Just (SomeNode (ContextNode _ context))
      | contextValue context == Strategy -> []
      | otherwise ->
        [ FormulationForNonStrategy
            strategy
            (ContextNodeKind (contextValue context))
        ]
    Just (SomeNode node) ->
      [FormulationForNonStrategy strategy (nodeKindValue (nodeKind node))]
  where
    strategy = rawFormulationStrategy formulation

textErrors :: RawStrategyFormulation -> [ModelInvariantError]
textErrors formulation =
  [ EmptyStrategyText strategy field
  | (field, values) <- textFields formulation
  , any (Text.null . Text.strip) values
  ]
  where
    strategy = rawFormulationStrategy formulation

textFields :: RawStrategyFormulation -> [(StrategyTextField, [Text])]
textFields formulation =
  [ (ScopeField, NonEmpty.toList (rawFormulationScope formulation))
  , (PeriodField, [anchoringPeriod anchoring])
  , (ResponsibilityScopeField, [anchoringResponsibilityScope anchoring])
  , (DecisionLevelField, [anchoringDecisionLevel anchoring])
  , ( ResponsibilitiesField
    , NonEmpty.toList (anchoringResponsibilities anchoring))
  , (DecisionPathsField, NonEmpty.toList (anchoringDecisionPaths anchoring))
  , (ImplementationLogicField, [anchoringImplementationLogic anchoring])
  , (GuardrailsField, NonEmpty.toList (rawFormulationGuardrails formulation))
  , (PositioningField, NonEmpty.toList (rawFormulationPositioning formulation))
  , (TradeOffsField, NonEmpty.toList (rawFormulationTradeOffs formulation))
  , ( FitRationaleField
    , NonEmpty.toList (rawFormulationFitRationale formulation))
  ]
  where
    anchoring = rawFormulationAnchoring formulation

duplicateReferenceErrors :: RawStrategyFormulation -> [ModelInvariantError]
duplicateReferenceErrors formulation = concatMap errorsForRole roleReferences
  where
    strategy = rawFormulationStrategy formulation
    roleReferences =
      [ ( CoherentActionRole
        , NonEmpty.toList (rawFormulationActions formulation))
      , ( StrategicKeyResultRole
        , NonEmpty.toList (rawFormulationKeyResults formulation))
      ]
    errorsForRole (role, references) =
      [ DuplicateStrategyPrimitiveReference strategy role reference
      | reference <- duplicates references
      ]

primitiveReferenceErrors ::
     WellFormedGraph -> RawStrategyFormulation -> [ModelInvariantError]
primitiveReferenceErrors graph formulation =
  concatMap validateReference references
  where
    strategy = rawFormulationStrategy formulation
    references =
      nub
        ([ (DiagnosisRole, Driver, rawFormulationDiagnosis formulation)
         , (IntentRole, Objective, rawFormulationIntent formulation)
         , ( GuidingPolicyRole
           , Principle
           , rawFormulationGuidingPolicy formulation)
         ]
           ++ map
                (\reference -> (CoherentActionRole, Action, reference))
                (NonEmpty.toList (rawFormulationActions formulation))
           ++ map
                (\reference -> (StrategicKeyResultRole, KeyResult, reference))
                (NonEmpty.toList (rawFormulationKeyResults formulation)))
    validateReference (role, primitive, reference) =
      [ InvalidStrategyPrimitiveReference strategy role reference primitive
      | not (validPrimitiveReference graph strategy primitive reference)
      ]

coherenceErrors ::
     WellFormedGraph -> RawStrategyFormulation -> [ModelInvariantError]
coherenceErrors graph formulation =
  diagnosisErrors ++ policyErrors ++ actionErrors ++ keyResultErrors
  where
    strategy = rawFormulationStrategy formulation
    diagnosis = rawFormulationDiagnosis formulation
    intent = rawFormulationIntent formulation
    policy = rawFormulationGuidingPolicy formulation
    valid primitive reference =
      validPrimitiveReference graph strategy primitive reference
    validDiagnosis = valid Driver diagnosis
    validIntent = valid Objective intent
    validPolicy = valid Principle policy
    actions =
      filter
        (valid Action)
        (nub (NonEmpty.toList (rawFormulationActions formulation)))
    keyResults =
      filter
        (valid KeyResult)
        (nub (NonEmpty.toList (rawFormulationKeyResults formulation)))
    missing ::
         RawNodeId -> Relation from to -> RawNodeId -> [ModelInvariantError]
    missing from relation to =
      [ MissingStrategyCoherence strategy from (relationNameFor relation) to
      | not (hasRelation graph from relation to)
      ]
    diagnosisErrors =
      [ error'
      | validDiagnosis && validIntent
      , error' <- missing diagnosis groundsStrategyDriverToObjective intent
      ]
    policyErrors =
      [ error'
      | validPolicy
      , action <- actions
      , error' <- missing policy guidesStrategyPrincipleToAction action
      ]
    actionErrors =
      [ StrategyActionWithoutKeyResult strategy action
      | action <- actions
      , not (null keyResults)
      , not
          (any
             (hasRelation graph action contributesStrategyActionToKeyResult)
             keyResults)
      ]
    keyResultErrors =
      [ error'
      | validIntent
      , keyResult <- keyResults
      , error' <-
          missing keyResult substantiatesStrategyKeyResultObjective intent
      ]

validPrimitiveReference ::
     WellFormedGraph -> RawNodeId -> Primitive -> RawNodeId -> Bool
validPrimitiveReference graph strategy primitive reference =
  reference `elem` primitiveNodesIn graph strategy primitive

hasRelation ::
     WellFormedGraph -> RawNodeId -> Relation from to -> RawNodeId -> Bool
hasRelation graph from relation = hasEdge graph from (relationNameFor relation)

anchorNeedDriverRelationNames :: [RelationName]
anchorNeedDriverRelationNames =
  [ relationNameFor (anchorsNeedDriver SBusinessCapability)
  , relationNameFor (anchorsNeedDriver SBusinessProcess)
  , relationNameFor (anchorsNeedDriver SBusinessObject)
  , relationNameFor (anchorsNeedDriver SBusinessRole)
  , relationNameFor (anchorsNeedDriver SValueStream)
  , relationNameFor (anchorsNeedDriver SRegulatoryConstraint)
  ]

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort
