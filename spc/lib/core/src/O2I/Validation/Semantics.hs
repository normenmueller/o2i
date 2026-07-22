{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Semantic completeness of structurally valid O2I graphs.
--
-- This validation stage establishes global Context minima and complete,
-- coherent Strategy formulations before effect traces may be derived.
module O2I.Validation.Semantics
  ( StrategyAnchoring(..)
  , RawStrategyFormulation(..)
  , StrategyFormulation
  , Elaboration(..)
  , Maturity(..)
  , CandidateModelProposition(..)
  , ModelAssessment
  , StrategyTextField(..)
  , StrategyPrimitiveRole(..)
  , ModelInvariantError(..)
  , SemanticallyValidModel
  , validateModelSemantics
  , assessModelSemantics
  , assessedSemanticModel
  , assessmentInvariantErrors
  , assessmentCandidatePropositions
  , contextElaboration
  , modelMaturity
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
import O2I.Graph.Raw (CandidateGraphProposition(..), RawEdge(..), RawNode(..))
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Macro (StrategyPrimitiveRole(..))
import O2I.Language.Relation
import O2I.Validation.Structure
  ( StructuralAssessment
  , structuralCandidatePropositions
  , structuralGraph
  )

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

-- | Derived availability of one Context's mandatory semantic content.
data Elaboration
  = Referenced
    -- ^ Asserted identity and type exist without a complete valid content bundle.
  | Elaborated
    -- ^ Mandatory asserted content passes semantic validation in this boundary.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Derived semantic maturity of one inspected model boundary.
data Maturity
  = Skeleton
    -- ^ No Context in scope has a complete validated content bundle.
  | Draft
    -- ^ Some content is elaborated while unresolved or invalid claims remain.
  | SemanticallyValid
    -- ^ No candidate remains and global semantic validation has succeeded.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Candidate proposition retained by model assessment and excluded from semantics.
data CandidateModelProposition
  = CandidateModelNode RawNode
    -- ^ Proposed element declaration.
  | CandidateModelEdge RawEdge
    -- ^ Proposed relation declaration.
  | CandidateStrategyFormulation RawNodeId
    -- ^ Proposed Strategy content bundle, identified by its Strategy Context.
  deriving (Eq, Show)

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

-- | Accumulated semantic invariant violations.
data ModelInvariantError
  = EthosWithoutPrinciple RawNodeId
    -- ^ An Ethos has no Principle expressing its normative content.
  | MissionWithoutDriver RawNodeId
    -- ^ A Mission has no Driver expressing its enduring contribution.
  | MissionWithoutEthosGuidance RawNodeId
    -- ^ No Ethos Principle guides a Driver owned by the Mission.
  | VisionWithoutObjective RawNodeId
    -- ^ A Vision has no Objective expressing an intended future state.
  | VisionWithoutMissionGrounding RawNodeId
    -- ^ No Mission Driver grounds an Objective owned by the Vision.
  | VisionWithoutEthosGuidance RawNodeId
    -- ^ No Ethos Principle guides an Objective owned by the Vision.
  | StrategyIntentWithoutVisionOrientation RawNodeId RawNodeId
    -- ^ No Vision Objective orients the Strategy formulation's intent.
  | SituationWithoutConstitutingAnchor RawNodeId
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
  | InterventionWithoutAction RawNodeId
    -- ^ An Intervention has no Action expressing its intended intervention.
  | InterventionWithoutKeyResult RawNodeId
    -- ^ An Intervention has no Key Result expressing its intended outcome.
  | InterventionWithoutActionContribution RawNodeId
    -- ^ No owned Intervention Action contributes to an owned Key Result.
  | MeasureWithoutPerformanceDimension RawNodeId
    -- ^ A Measure has no owned measurement PerformanceDimension.
  | MeasureWithoutKPI RawNodeId
    -- ^ A Measure has no owned KPI expressing an observable quantity.
  | MeasureWithoutKPIDimensionMembership RawNodeId
    -- ^ No owned measurement PerformanceDimension contains an owned KPI.
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

-- | A structurally valid graph with complete Context minima and Strategy
-- semantics.
data SemanticallyValidModel = SemanticallyValidModel
  { semanticallyValidGraph :: WellFormedGraph -- ^ Structurally valid graph.
  , semanticallyValidStrategies :: Map RawNodeId StrategyFormulation
    -- ^ Exactly one complete formulation for every Strategy context.
  }

-- | Opaque result of assessing asserted and candidate model propositions.
--
-- The assessment retains diagnostics and partial Context elaboration without
-- weakening 'SemanticallyValidModel'. A semantic model is exposed only when
-- no candidate remains and every asserted invariant has passed.
data ModelAssessment = ModelAssessment
  { assessedErrors :: [ModelInvariantError]
  , assessedCandidates :: [CandidateModelProposition]
  , assessedElaborations :: Map RawNodeId Elaboration
  , assessedModel :: Maybe SemanticallyValidModel
  , assessedMaturity :: Maturity
  }

-- * Semantic validation
-- | Establish global Context minima and complete Strategy formulations.
--
-- The input graph must already be structurally valid. Independent semantic
-- errors accumulate. Success guarantees every Ethos owns a Principle, every
-- Mission owns a Driver guided by some Ethos Principle, every Vision owns an
-- Objective with Mission grounding and Ethos guidance, every Strategy has one
-- Vision-oriented, nonblank, role-correct, coherent formulation, every
-- Situation has a constituting anchor, every Need is situated and grounded,
-- every Intervention connects an owned Action to an owned Key Result, and every
-- Measure groups an owned KPI in an owned measurement PerformanceDimension.
--
-- Orientation evidence is existential per Context requirement. Additional
-- owned Drivers or Objectives need not repeat the same evidence, and explicit
-- Context macrorelation edges are not required: persisted Primitive relations
-- are the semantic basis.
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
      orientationErrors graph
        ++ situationErrors graph
        ++ needErrors graph
        ++ interventionErrors graph
        ++ measureErrors graph
        ++ formulationCoverageErrors graph rawFormulations
        ++ concatMap (formulationErrors graph) rawFormulations
        ++ strategyOrientationErrors graph rawFormulations

-- | Assess explicit claim commitments without weakening semantic validation.
--
-- Candidate graph and Strategy-content propositions are retained as unresolved
-- findings and excluded from validation. Asserted propositions are validated
-- exactly as by 'validateModelSemantics'. A successful semantic artifact is
-- available only when no candidate proposition remains.
assessModelSemantics ::
     StructuralAssessment -> [Claim RawStrategyFormulation] -> ModelAssessment
assessModelSemantics structure formulationClaims =
  ModelAssessment
    { assessedErrors = errors
    , assessedCandidates = candidates
    , assessedElaborations = elaborations
    , assessedModel = semantic
    , assessedMaturity = maturity
    }
  where
    graph = structuralGraph structure
    assertedFormulations =
      [ claimedProposition formulation
      | formulation <- formulationClaims
      , claimCommitment formulation == Asserted
      ]
    candidates =
      map graphCandidate (structuralCandidatePropositions structure)
        ++ [ CandidateStrategyFormulation
             (rawFormulationStrategy (claimedProposition formulation))
           | formulation <- formulationClaims
           , claimCommitment formulation == Candidate
           ]
    validation = validateModelSemantics graph assertedFormulations
    allErrors =
      case validation of
        Failure failures -> NonEmpty.toList failures
        Success _ -> []
    errors = allErrors
    semantic =
      case (candidates, validation) of
        ([], Success model) -> Just model
        _ -> Nothing
    elaborations =
      Map.fromList
        [ (context, elaborationFor context allErrors)
        | context <- contextIdentifiers graph
        ]
    maturity
      | Just _ <- semantic = SemanticallyValid
      | Elaborated `elem` Map.elems elaborations = Draft
      | otherwise = Skeleton

-- | Read the exact semantic model, if every asserted claim validated and no
-- candidate remains.
assessedSemanticModel :: ModelAssessment -> Maybe SemanticallyValidModel
assessedSemanticModel = assessedModel

-- | Read every failed invariant over asserted propositions.
assessmentInvariantErrors :: ModelAssessment -> [ModelInvariantError]
assessmentInvariantErrors = assessedErrors

-- | Read candidate propositions excluded from validated semantics.
assessmentCandidatePropositions ::
     ModelAssessment -> [CandidateModelProposition]
assessmentCandidatePropositions = assessedCandidates

-- | Derive semantic-content availability for one asserted Context in scope.
--
-- Returns 'Nothing' when the identifier is not an asserted Context declaration
-- in this assessment boundary. Candidate content never yields 'Elaborated'.
contextElaboration :: ModelAssessment -> RawNodeId -> Maybe Elaboration
contextElaboration assessment identifier =
  Map.lookup identifier (assessedElaborations assessment)

-- | Read the maturity derived for this exact model assessment boundary.
modelMaturity :: ModelAssessment -> Maturity
modelMaturity = assessedMaturity

graphCandidate :: CandidateGraphProposition -> CandidateModelProposition
graphCandidate proposition =
  case proposition of
    CandidateNodeProposition node -> CandidateModelNode node
    CandidateEdgeProposition edge -> CandidateModelEdge edge

contextIdentifiers :: WellFormedGraph -> [RawNodeId]
contextIdentifiers graph =
  concatMap (contextNodesOf graph) [minBound .. maxBound]

elaborationFor :: RawNodeId -> [ModelInvariantError] -> Elaboration
elaborationFor context errors
  | any (elem context . invariantContexts) errors = Referenced
  | otherwise = Elaborated

invariantContexts :: ModelInvariantError -> [RawNodeId]
invariantContexts invariant =
  case invariant of
    EthosWithoutPrinciple context -> [context]
    MissionWithoutDriver context -> [context]
    MissionWithoutEthosGuidance context -> [context]
    VisionWithoutObjective context -> [context]
    VisionWithoutMissionGrounding context -> [context]
    VisionWithoutEthosGuidance context -> [context]
    StrategyIntentWithoutVisionOrientation context _ -> [context]
    SituationWithoutConstitutingAnchor context -> [context]
    NeedWithoutDriver context -> [context]
    NeedWithoutObjective context -> [context]
    NeedWithoutSurfacingSituation context -> [context]
    UnanchoredNeedDriver context _ -> [context]
    UngroundedNeedObjective context _ -> [context]
    InterventionWithoutAction context -> [context]
    InterventionWithoutKeyResult context -> [context]
    InterventionWithoutActionContribution context -> [context]
    MeasureWithoutPerformanceDimension context -> [context]
    MeasureWithoutKPI context -> [context]
    MeasureWithoutKPIDimensionMembership context -> [context]
    StrategyWithoutFormulation context -> [context]
    DuplicateStrategyFormulation context -> [context]
    UnknownFormulationStrategy context -> [context]
    FormulationForNonStrategy context _ -> [context]
    EmptyStrategyText context _ -> [context]
    DuplicateStrategyPrimitiveReference context _ _ -> [context]
    InvalidStrategyPrimitiveReference context _ _ _ -> [context]
    StrategyActionWithoutKeyResult context _ -> [context]
    MissingStrategyCoherence context _ _ _ -> [context]

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

orientationErrors :: WellFormedGraph -> [ModelInvariantError]
orientationErrors graph =
  concatMap ethosErrors (contextNodesOf graph Ethos)
    ++ concatMap missionErrors (contextNodesOf graph Mission)
    ++ concatMap visionErrors (contextNodesOf graph Vision)
  where
    ethosPrinciples = primitivesOwnedBy graph Ethos Principle
    missionDrivers = primitivesOwnedBy graph Mission Driver
    ethosErrors ethos =
      [EthosWithoutPrinciple ethos | null (principlesIn ethos)]
    missionErrors mission =
      let drivers = driversIn mission
       in [MissionWithoutDriver mission | null drivers]
            ++ [ MissionWithoutEthosGuidance mission
               | not (null drivers)
               , not
                   (hasEvidence
                      graph
                      ethosPrinciples
                      guidesEthosPrincipleToMissionDriver
                      drivers)
               ]
    visionErrors vision =
      let objectives = objectivesIn vision
       in [VisionWithoutObjective vision | null objectives]
            ++ [ VisionWithoutMissionGrounding vision
               | not (null objectives)
               , not
                   (hasEvidence
                      graph
                      missionDrivers
                      groundsMissionDriverToVisionObjective
                      objectives)
               ]
            ++ [ VisionWithoutEthosGuidance vision
               | not (null objectives)
               , not
                   (hasEvidence
                      graph
                      ethosPrinciples
                      guidesEthosPrincipleToVisionObjective
                      objectives)
               ]
    principlesIn owner = primitiveNodesIn graph owner Principle
    driversIn owner = primitiveNodesIn graph owner Driver
    objectivesIn owner = primitiveNodesIn graph owner Objective

primitivesOwnedBy :: WellFormedGraph -> Context -> Primitive -> [RawNodeId]
primitivesOwnedBy graph context primitive =
  concatMap
    (\owner -> primitiveNodesIn graph owner primitive)
    (contextNodesOf graph context)

hasEvidence ::
     WellFormedGraph -> [RawNodeId] -> Relation from to -> [RawNodeId] -> Bool
hasEvidence graph sources relation targets =
  any (\source -> any (hasRelation graph source relation) targets) sources

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

interventionErrors :: WellFormedGraph -> [ModelInvariantError]
interventionErrors graph =
  concatMap errorsForIntervention (contextNodesOf graph Intervention)
  where
    errorsForIntervention intervention =
      [InterventionWithoutAction intervention | null actions]
        ++ [InterventionWithoutKeyResult intervention | null keyResults]
        ++ [ InterventionWithoutActionContribution intervention
           | not (null actions)
           , not (null keyResults)
           , not
               (hasEvidence
                  graph
                  actions
                  contributesInterventionActionToKeyResult
                  keyResults)
           ]
      where
        actions = primitiveNodesIn graph intervention Action
        keyResults = primitiveNodesIn graph intervention KeyResult

measureErrors :: WellFormedGraph -> [ModelInvariantError]
measureErrors graph = concatMap errorsForMeasure (contextNodesOf graph Measure)
  where
    errorsForMeasure measure =
      [MeasureWithoutPerformanceDimension measure | null dimensions]
        ++ [MeasureWithoutKPI measure | null kpis]
        ++ [ MeasureWithoutKPIDimensionMembership measure
           | not (null dimensions)
           , not (null kpis)
           , not
               (hasEvidence
                  graph
                  dimensions
                  (containsPerformanceDimension MeasureMeasurementDimension)
                  kpis)
           ]
      where
        dimensions =
          map
            unNodeId
            (performanceDimensionNodesIn
               graph
               (mkContextRef measure)
               MeasureMeasurementDimension)
        kpis = primitiveNodesIn graph measure KPI

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

strategyOrientationErrors ::
     WellFormedGraph -> [RawStrategyFormulation] -> [ModelInvariantError]
strategyOrientationErrors graph formulations =
  concatMap errorsForStrategy (contextNodesOf graph Strategy)
  where
    visionObjectives = primitivesOwnedBy graph Vision Objective
    errorsForStrategy strategy =
      case filter ((== strategy) . rawFormulationStrategy) formulations of
        [formulation]
          | validPrimitiveReference graph strategy Objective intent ->
            [ StrategyIntentWithoutVisionOrientation strategy intent
            | not
                (hasEvidence
                   graph
                   visionObjectives
                   orientsVisionObjectiveToStrategyObjective
                   [intent])
            ]
          where intent = rawFormulationIntent formulation
        _ -> []

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
duplicates values = [first | first:_:_ <- group (sort values)]
