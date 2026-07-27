{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Shared fixtures and validation helpers for O2I domain tests.
module O2I.Test.Support where

import Data.List (nub)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Data.Time (UTCTime(..), fromGregorian, secondsToDiffTime)
import O2I
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

withWellFormed :: RawGraph -> (WellFormedGraph -> Assertion) -> Assertion
withWellFormed raw action =
  case validateStructure raw of
    StructureModelRejected errors ->
      assertFailure ("structural errors: " ++ show errors)
    StructureAccepted assessment -> action (structuralGraph assessment)
    StructureInternalFailure internal ->
      assertFailure ("internal structural failure: " ++ show internal)

withContextRef ::
     WellFormedGraph
  -> SContext context
  -> RawNodeId
  -> (ContextRef context -> Assertion)
  -> Assertion
withContextRef graph context identifier action =
  case lookupContextRef graph context identifier of
    Nothing -> assertFailure "validated Context reference was not found"
    Just reference -> action reference

withSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> (ContextRef context -> Assertion)
  -> Assertion
withSemanticContextRef model context identifier action =
  case lookupSemanticContextRef model context identifier of
    Nothing -> assertFailure "semantic Context reference was not found"
    Just reference -> action reference

withOnlyReadyIntervention ::
     EvidenceReadyModel -> (ContextRef 'Intervention -> Assertion) -> Assertion
withOnlyReadyIntervention ready action =
  case readyInterventions ready of
    [intervention] -> action intervention
    interventions ->
      assertFailure
        ("expected one ready Intervention, got " ++ show (length interventions))

withTraceable :: RawGraph -> (TraceableEffectModel -> Assertion) -> Assertion
withTraceable raw action =
  withSemanticallyValid raw [sampleStrategyFormulation] $ \model ->
    case validateTraceability model of
      Failure errors -> assertFailure ("traceability errors: " ++ show errors)
      Success traceable -> action traceable

withSemanticallyValid ::
     RawGraph
  -> [RawStrategyFormulation]
  -> (SemanticallyValidModel -> Assertion)
  -> Assertion
withSemanticallyValid raw formulations action =
  case validateSemanticRaw raw formulations of
    Failure errors -> assertFailure ("semantic errors: " ++ show errors)
    Success model -> action model

validateSemanticRaw ::
     RawGraph
  -> [RawStrategyFormulation]
  -> Validation (NonEmpty.NonEmpty ModelInvariantError) SemanticallyValidModel
validateSemanticRaw raw formulations =
  case validateStructure raw of
    StructureModelRejected errors ->
      error ("test fixture has structural errors: " ++ show errors)
    StructureAccepted structure ->
      let assessment =
            assessSemantics structure (map assertedClaim formulations)
       in case modelAssessmentStatus assessment of
            SemanticsRejected _ ->
              case NonEmpty.nonEmpty (assessmentInvariantErrors assessment) of
                Just errors -> Failure errors
                Nothing -> error "test fixture failed outside Context semantics"
            SemanticsPending _ ->
              error "asserted test fixture produced pending semantics"
            SemanticsAccepted model -> Success model
    StructureInternalFailure internal ->
      error ("test fixture triggered internal failure: " ++ show internal)

assessSemantics ::
     StructuralAssessment -> [Claim RawStrategyFormulation] -> ModelAssessment
assessSemantics structure formulations =
  assessModelSemantics
    structure
    ModelSemanticsInput
      { modelStrategyClaims = formulations
      , modelCollectiveClaims = []
      , modelCollectiveFitEvidence = []
      }

assertSemanticErrors :: RawGraph -> [ModelInvariantError] -> Assertion
assertSemanticErrors raw expected =
  assertSemanticErrorsWith raw [sampleStrategyFormulation] expected

assertSemanticErrorsWith ::
     RawGraph -> [RawStrategyFormulation] -> [ModelInvariantError] -> Assertion
assertSemanticErrorsWith raw formulations expected =
  case validateSemanticRaw raw formulations of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "semantically invalid model was accepted"

assertStructuralErrors :: [StructuralError] -> StructureResult -> Assertion
assertStructuralErrors expected result =
  case result of
    StructureModelRejected errors -> NonEmpty.toList errors @?= expected
    StructureAccepted _ ->
      assertFailure "structurally invalid graph was accepted"
    StructureInternalFailure internal ->
      assertFailure
        ("unexpected internal structural failure: " ++ show internal)

assertStructureAccepted :: StructureResult -> Assertion
assertStructureAccepted result =
  case result of
    StructureAccepted _ -> pure ()
    StructureModelRejected errors ->
      assertFailure ("structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      assertFailure ("internal structural failure: " ++ show internal)

assertTraceabilityErrors ::
     [TraceabilityError]
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
  -> Assertion
assertTraceabilityErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "untraceable effect model was accepted"

assertReadinessErrors ::
     [EvidenceReadinessError]
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
  -> Assertion
assertReadinessErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid evidence readiness was accepted"

assertEvidenceErrors ::
     [EvidenceError]
  -> Validation (NonEmpty.NonEmpty EvidenceError) EvidenceAssessedModel
  -> Assertion
assertEvidenceErrors expected result =
  case result of
    Failure errors -> NonEmpty.toList errors @?= expected
    Success _ -> assertFailure "invalid evidence was accepted"

withReady ::
     RawGraph
  -> [RawStrategyFormulation]
  -> (EvidenceReadyModel -> Assertion)
  -> Assertion
withReady raw formulations action =
  withSemanticallyValid raw formulations $ \semantic ->
    case validateTraceability semantic of
      Failure errors -> assertFailure ("traceability errors: " ++ show errors)
      Success traceable ->
        case validateEvidenceReadinessAt
               readinessDate
               traceable
               (definitionsFor traceable)
               (plannedStartsFor traceable)
               (map planForTrace (NonEmpty.toList (effectTraces traceable))) of
          Failure errors -> assertFailure ("readiness errors: " ++ show errors)
          Success ready -> action ready

withReadyPlan ::
     (EvidencePlan -> EvidencePlan)
  -> (EvidenceReadyModel -> EffectTrace -> Assertion)
  -> Assertion
withReadyPlan transform action =
  withTraceable sampleGraph $ \traceable ->
    let trace = NonEmpty.head (effectTraces traceable)
        plan = transform (planForTrace trace)
     in case validateEvidenceReadinessAt
               readinessDate
               traceable
               (definitionsFor traceable)
               (plannedStartsFor traceable)
               [plan] of
          Failure errors -> assertFailure ("readiness errors: " ++ show errors)
          Success ready -> action ready trace

readinessFailureTest ::
     TestName
  -> UTCTime
  -> (EvidencePlan -> EvidencePlan)
  -> (EffectTraceId -> [EvidenceReadinessError])
  -> TestTree
readinessFailureTest name checkedAt transform expected =
  testCase name
    $ withTraceable sampleGraph
    $ \traceable ->
        let trace = NonEmpty.head (effectTraces traceable)
            plan = transform (planForTrace trace)
         in assertReadinessErrors
              (expected (traceIdentifier trace))
              (validateEvidenceReadinessAt
                 checkedAt
                 traceable
                 (definitionsFor traceable)
                 (plannedStartsFor traceable)
                 [plan])

evidenceFailureTest ::
     TestName
  -> (Observation -> Observation)
  -> (EffectTraceId -> ContextRef 'Intervention -> [EvidenceError])
  -> TestTree
evidenceFailureTest name transform expected =
  evidenceFailureAtTest name assessmentDate transform expected

evidenceFailureAtTest ::
     TestName
  -> UTCTime
  -> (Observation -> Observation)
  -> (EffectTraceId -> ContextRef 'Intervention -> [EvidenceError])
  -> TestTree
evidenceFailureAtTest name assessedAt transform expected =
  testCase name
    $ withReadyPlan id
    $ \ready trace ->
        let observation' = transform (observation 75 followUpDate)
            followUp = FollowUpObservation (traceIdentifier trace) observation'
         in assertEvidenceErrors
              (expected (traceIdentifier trace) (traceIntervention trace))
              (assessEffectEvidenceAt
                 assessedAt
                 ready
                 [sampleActualStart]
                 [followUp])

assertEffectiveNeed ::
     (EvidencePlan -> EvidencePlan) -> Rational -> Bool -> Assertion
assertEffectiveNeed transform followValue expected =
  withReadyPlan transform $ \ready trace ->
    let followUp = followUpForTrace trace followValue followUpDate
     in case assessEffectEvidenceAt
               assessmentDate
               ready
               [sampleActualStart]
               [followUp] of
          Failure errors -> assertFailure ("evidence errors: " ++ show errors)
          Success assessed ->
            isEffectiveNeed assessed (traceNeed trace) @?= expected

withAssessed ::
     (EvidencePlan -> EvidencePlan)
  -> Rational
  -> UTCTime
  -> (EvidenceAssessedModel -> EffectAssessment -> Assertion)
  -> Assertion
withAssessed transform followValue followTimestamp action =
  withReadyPlan transform $ \ready trace ->
    case assessEffectEvidenceAt
           assessmentDate
           ready
           [sampleActualStart]
           [followUpForTrace trace followValue followTimestamp] of
      Failure errors -> assertFailure ("evidence errors: " ++ show errors)
      Success assessed ->
        action assessed (NonEmpty.head (effectAssessments assessed))

traceabilityFails :: RawGraph -> Bool
traceabilityFails raw =
  case validateSemanticRaw raw [sampleStrategyFormulation] of
    Failure _ -> True
    Success model ->
      case validateTraceability model of
        Failure _ -> True
        Success _ -> False

traceabilitySucceeds :: RawGraph -> Bool
traceabilitySucceeds raw =
  case validateSemanticRaw raw [sampleStrategyFormulation] of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success _ -> True

evidenceSucceeds :: (EvidencePlan -> EvidencePlan) -> Rational -> Bool
evidenceSucceeds transform followValue =
  case validateSemanticRaw sampleGraph [sampleStrategyFormulation] of
    Failure _ -> False
    Success model ->
      case validateTraceability model of
        Failure _ -> False
        Success traceable ->
          let trace = NonEmpty.head (effectTraces traceable)
              plan = transform (planForTrace trace)
           in case validateEvidenceReadinessAt
                     readinessDate
                     traceable
                     (definitionsFor traceable)
                     (plannedStartsFor traceable)
                     [plan] of
                Failure _ -> False
                Success ready ->
                  case assessEffectEvidenceAt
                         assessmentDate
                         ready
                         [sampleActualStart]
                         [followUpForTrace trace followValue followUpDate] of
                    Failure _ -> False
                    Success assessed ->
                      effectResult (NonEmpty.head (effectAssessments assessed))
                        == Satisfied

directionalEvidenceSucceeds :: Bool -> Integer -> Bool
directionalEvidenceSucceeds increases threshold =
  if increases
    then evidenceSucceeds
           (\plan -> plan {effectCriterion = AbsoluteIncreaseByAtLeast delta})
           (40 + amount)
    else evidenceSucceeds
           (\plan ->
              plan
                { baseline = observation 100 baselineDate
                , effectCriterion = AbsoluteDecreaseByAtLeast delta
                , targetCriterion = AtMost (Level 100)
                })
           (100 - amount)
  where
    amount = fromInteger threshold
    delta = Delta amount

assertSuccess :: Validation errors result -> Assertion
assertSuccess (Success _) = pure ()
assertSuccess (Failure _) = assertFailure "expected validation success"

emptyGraph :: RawGraph
emptyGraph = RawGraph [] []

strategySuccessPerformanceDimensionGraph :: RawGraph
strategySuccessPerformanceDimensionGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
    , RawStructuringNode
        strategyPerformanceDimensionId
        strategyId
        PerformanceDimension
    ]
    [ edge
        strategyPerformanceDimensionId
        (containsPerformanceDimension StrategySuccessDimension)
        strategyKeyResultId
    ]

measureMeasurementPerformanceDimensionGraph :: RawGraph
measureMeasurementPerformanceDimensionGraph =
  RawGraph
    [ RawContextNode measureId Measure
    , RawPrimitiveNode measureKpiId measureId KPI
    , RawStructuringNode
        measurePerformanceDimensionId
        measureId
        PerformanceDimension
    ]
    [ edge
        measurePerformanceDimensionId
        (containsPerformanceDimension MeasureMeasurementDimension)
        measureKpiId
    ]

strategySuccessDimensionWithActionGraph :: RawGraph
strategySuccessDimensionWithActionGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawPrimitiveNode strategyActionId strategyId Action
    , RawStructuringNode
        strategyPerformanceDimensionId
        strategyId
        PerformanceDimension
    ]
    [ RawEdge
        strategyPerformanceDimensionId
        (relationNameFor (containsPerformanceDimension StrategySuccessDimension))
        strategyActionId
    ]

rawPerformanceDimensionOwnershipMatchesRegistry :: Context -> Bool
rawPerformanceDimensionOwnershipMatchesRegistry context =
  case (lookupPerformanceDimensionRole context, validateStructure raw) of
    (Just _, StructureAccepted assessment) ->
      case lookupNode (structuralGraph assessment) genericPerformanceDimensionId of
        Just node -> someNodeOwner node == Just performanceDimensionOwnerId
        Nothing -> False
    (Nothing, StructureModelRejected errors) ->
      NonEmpty.toList errors
        == [ InvalidStructuringContext
               genericPerformanceDimensionId
               context
               PerformanceDimension
           ]
    _ -> False
  where
    raw =
      RawGraph
        [ RawContextNode performanceDimensionOwnerId context
        , RawStructuringNode
            genericPerformanceDimensionId
            performanceDimensionOwnerId
            PerformanceDimension
        ]
        []

sampleGraph :: RawGraph
sampleGraph = RawGraph sampleNodes sampleEdges

unqualifiedNeedGraph :: RawGraph
unqualifiedNeedGraph =
  sampleGraph
    { rawEdges =
        filter
          (`notElem` [ edge strategyId qualifiesNeed needId
                     , edge
                         strategyKeyResultId
                         translatesStrategyKeyResultToNeedObjective
                         needObjectiveId
                     ])
          (rawEdges sampleGraph)
    }

sampleStrategyFormulation :: RawStrategyFormulation
sampleStrategyFormulation =
  RawStrategyFormulation
    { rawFormulationStrategy = strategyId
    , rawFormulationScope = "enterprise" NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "enterprise"
          , anchoringDecisionLevel = "executive"
          , anchoringResponsibilities = "strategy owner" NonEmpty.:| []
          , anchoringDecisionPaths = "portfolio governance" NonEmpty.:| []
          , anchoringImplementationLogic = "coherent action commitments"
          }
    , rawFormulationGuardrails = "evidence before assumption" NonEmpty.:| []
    , rawFormulationDiagnosis = strategyDriverId
    , rawFormulationIntent = strategyObjectiveId
    , rawFormulationGuidingPolicy = strategyPrincipleId
    , rawFormulationPositioning = "shared understanding" NonEmpty.:| []
    , rawFormulationTradeOffs = "traceability over speed" NonEmpty.:| []
    , rawFormulationActions = strategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = strategyKeyResultId NonEmpty.:| []
    , rawFormulationFitRationale = "actions substantiate intent" NonEmpty.:| []
    }

blankStrategyFormulation :: RawStrategyFormulation
blankStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationScope = " " NonEmpty.:| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = " "
          , anchoringResponsibilityScope = " "
          , anchoringDecisionLevel = " "
          , anchoringResponsibilities = " " NonEmpty.:| []
          , anchoringDecisionPaths = " " NonEmpty.:| []
          , anchoringImplementationLogic = " "
          }
    , rawFormulationGuardrails = " " NonEmpty.:| []
    , rawFormulationPositioning = " " NonEmpty.:| []
    , rawFormulationTradeOffs = " " NonEmpty.:| []
    , rawFormulationFitRationale = " " NonEmpty.:| []
    }

invalidRoleStrategyFormulation :: RawStrategyFormulation
invalidRoleStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationDiagnosis = needDriverId
    , rawFormulationIntent = strategyDriverId
    , rawFormulationGuidingPolicy = strategyObjectiveId
    , rawFormulationActions = interventionActionId NonEmpty.:| []
    , rawFormulationKeyResults = interventionKeyResultId NonEmpty.:| []
    }

duplicateReferenceStrategyFormulation :: RawStrategyFormulation
duplicateReferenceStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationActions = strategyActionId NonEmpty.:| [strategyActionId]
    , rawFormulationKeyResults =
        strategyKeyResultId NonEmpty.:| [strategyKeyResultId]
    }

withoutEdge :: RawEdge -> RawGraph -> RawGraph
withoutEdge removed raw = raw {rawEdges = filter (/= removed) (rawEdges raw)}

removeNode :: RawNodeId -> RawGraph -> RawGraph
removeNode identifier raw =
  raw
    { rawNodes = filter ((/= identifier) . rawNodeIdentifier) (rawNodes raw)
    , rawEdges =
        filter
          (\candidate ->
             rawEdgeFrom candidate /= identifier
               && rawEdgeTo candidate /= identifier)
          (rawEdges raw)
    }

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier (RawContextNode identifier _) = identifier
rawNodeIdentifier (RawPrimitiveNode identifier _ _) = identifier
rawNodeIdentifier (RawStructuringNode identifier _ _) = identifier
rawNodeIdentifier (RawAnchorNode identifier _) = identifier

twoPathGraph :: RawGraph
twoPathGraph =
  RawGraph (sampleNodes ++ secondPathNodes) (sampleEdges ++ secondPathEdges)

sharedKpiTwoPathGraph :: RawGraph
sharedKpiTwoPathGraph =
  RawGraph
    (sampleNodes ++ sharedKpiSecondPathNodes)
    (sampleEdges ++ sharedKpiSecondPathEdges)

sharedKpiSecondPathNodes :: [RawNode]
sharedKpiSecondPathNodes =
  [ RawPrimitiveNode (duplicateId needDriverId) needId Driver
  , RawPrimitiveNode (duplicateId needObjectiveId) needId Objective
  , RawPrimitiveNode (duplicateId interventionActionId) interventionId Action
  , RawPrimitiveNode
      (duplicateId interventionKeyResultId)
      interventionId
      KeyResult
  ]

sharedKpiSecondPathEdges :: [RawEdge]
sharedKpiSecondPathEdges =
  [ edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId needDriverId)
      groundsNeedDriverToObjective
      (duplicateId needObjectiveId)
  , anchorEdge
      situationAnchorId
      AnchorsNeedDriverFamily
      (duplicateId needDriverId)
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      (duplicateId interventionActionId)
  , edge
      (duplicateId interventionActionId)
      contributesInterventionActionToKeyResult
      (duplicateId interventionKeyResultId)
  , edge
      (duplicateId interventionKeyResultId)
      substantiatesInterventionKeyResultNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId interventionKeyResultId)
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge
      (duplicateId interventionKeyResultId)
      setsTargetForMeasureKPI
      measureKpiId
  , anchorEdge
      (duplicateId interventionActionId)
      ChangesAnchorFamily
      situationAnchorId
  ]

secondPathNodes :: [RawNode]
secondPathNodes =
  [ RawPrimitiveNode (duplicateId needDriverId) needId Driver
  , RawPrimitiveNode (duplicateId needObjectiveId) needId Objective
  , RawPrimitiveNode (duplicateId interventionActionId) interventionId Action
  , RawPrimitiveNode
      (duplicateId interventionKeyResultId)
      interventionId
      KeyResult
  , RawPrimitiveNode (duplicateId measureKpiId) measureId KPI
  , RawStructuringNode
      (duplicateId measurePerformanceDimensionId)
      measureId
      PerformanceDimension
  , RawAnchorNode (duplicateId situationAnchorId) BusinessCapability
  ]

secondPathEdges :: [RawEdge]
secondPathEdges =
  [ edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId needDriverId)
      groundsNeedDriverToObjective
      (duplicateId needObjectiveId)
  , anchorEdge
      situationId
      ConstitutedByAnchorFamily
      (duplicateId situationAnchorId)
  , anchorEdge
      (duplicateId situationAnchorId)
      AnchorsNeedDriverFamily
      (duplicateId needDriverId)
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      (duplicateId interventionActionId)
  , edge
      (duplicateId interventionActionId)
      contributesInterventionActionToKeyResult
      (duplicateId interventionKeyResultId)
  , edge
      (duplicateId interventionKeyResultId)
      substantiatesInterventionKeyResultNeedObjective
      (duplicateId needObjectiveId)
  , edge
      (duplicateId interventionKeyResultId)
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      (duplicateId measurePerformanceDimensionId)
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      (duplicateId measurePerformanceDimensionId)
  , edge
      (duplicateId measurePerformanceDimensionId)
      (containsPerformanceDimension MeasureMeasurementDimension)
      (duplicateId measureKpiId)
  , edge
      (duplicateId interventionKeyResultId)
      setsTargetForMeasureKPI
      (duplicateId measureKpiId)
  , anchorEdge
      (duplicateId interventionActionId)
      ChangesAnchorFamily
      (duplicateId situationAnchorId)
  , anchorEdge
      (duplicateId measureKpiId)
      MeasuresAnchorFamily
      (duplicateId situationAnchorId)
  ]

unlistedStrategyPathGraph :: RawGraph
unlistedStrategyPathGraph =
  RawGraph
    (sampleNodes ++ map duplicateChild childNodes)
    (sampleEdges ++ map duplicateEdge evidenceEdges)
  where
    childNodes = filter (not . isContextNode) sampleNodes
    evidenceEdges =
      filter
        (\candidate ->
           not
             (isContextId (rawEdgeFrom candidate)
                && isContextId (rawEdgeTo candidate)))
        sampleEdges

unlistedQualifiesGraph :: RawGraph
unlistedQualifiesGraph =
  replaceStrategyEvidence
    [RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult]
    [ edge
        strategyKeyResultId
        translatesStrategyKeyResultToNeedObjective
        needObjectiveId
    ]
    [ edge
        unlistedStrategyKeyResultId
        translatesStrategyKeyResultToNeedObjective
        needObjectiveId
    ]

unlistedDirectsInterventionGraph :: RawGraph
unlistedDirectsInterventionGraph =
  replaceStrategyEvidence
    [RawPrimitiveNode unlistedStrategyActionId strategyId Action]
    [ edge
        strategyActionId
        guidesStrategyActionToInterventionAction
        interventionActionId
    ]
    [ edge
        unlistedStrategyActionId
        guidesStrategyActionToInterventionAction
        interventionActionId
    ]

unlistedFramesGraph :: RawGraph
unlistedFramesGraph =
  replaceStrategyEvidence
    [ RawPrimitiveNode unlistedStrategyDriverId strategyId Driver
    , RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult
    ]
    [ edge
        strategyDriverId
        indicatesMeasurePerformanceDimension
        measurePerformanceDimensionId
    , edge
        strategyKeyResultId
        determinesMeasurePerformanceDimension
        measurePerformanceDimensionId
    ]
    [ edge
        unlistedStrategyDriverId
        indicatesMeasurePerformanceDimension
        measurePerformanceDimensionId
    , edge
        unlistedStrategyKeyResultId
        determinesMeasurePerformanceDimension
        measurePerformanceDimensionId
    ]

replaceStrategyEvidence :: [RawNode] -> [RawEdge] -> [RawEdge] -> RawGraph
replaceStrategyEvidence addedNodes removedEdges addedEdges =
  sampleGraph
    { rawNodes = addedNodes ++ rawNodes sampleGraph
    , rawEdges =
        addedEdges ++ filter (`notElem` removedEdges) (rawEdges sampleGraph)
    }

unlistedDirectsStrategyGraph :: RawGraph
unlistedDirectsStrategyGraph =
  twoStrategyGraph
    (edge strategyId directsStrategy secondStrategyId)
    [ RawPrimitiveNode unlistedStrategyPrincipleId strategyId Principle
    , RawPrimitiveNode
        secondUnlistedStrategyPrincipleId
        secondStrategyId
        Principle
    ]
    [ edge
        unlistedStrategyPrincipleId
        guidesStrategyPrincipleToPrinciple
        secondUnlistedStrategyPrincipleId
    ]

unlistedContributesStrategyGraph :: RawGraph
unlistedContributesStrategyGraph =
  twoStrategyGraph
    (edge strategyId contributesToStrategy secondStrategyId)
    [ RawPrimitiveNode unlistedStrategyKeyResultId strategyId KeyResult
    , RawPrimitiveNode
        secondUnlistedStrategyKeyResultId
        secondStrategyId
        KeyResult
    , RawPrimitiveNode unlistedStrategyActionId strategyId Action
    , RawPrimitiveNode secondUnlistedStrategyActionId secondStrategyId Action
    ]
    [ edge
        unlistedStrategyKeyResultId
        contributesStrategyKeyResultToKeyResult
        secondUnlistedStrategyKeyResultId
    , edge
        unlistedStrategyActionId
        contributesStrategyActionToAction
        secondUnlistedStrategyActionId
    ]

twoStrategyGraph :: RawEdge -> [RawNode] -> [RawEdge] -> RawGraph
twoStrategyGraph macro addedNodes addedEdges =
  sampleGraph
    { rawNodes =
        RawContextNode secondStrategyId Strategy
          : secondStrategyNodes
          ++ addedNodes
          ++ rawNodes sampleGraph
    , rawEdges =
        macro : secondStrategyMinimumEdges ++ addedEdges ++ rawEdges sampleGraph
    }

secondStrategyNodes :: [RawNode]
secondStrategyNodes =
  [ RawPrimitiveNode secondStrategyDriverId secondStrategyId Driver
  , RawPrimitiveNode secondStrategyObjectiveId secondStrategyId Objective
  , RawPrimitiveNode secondStrategyPrincipleId secondStrategyId Principle
  , RawPrimitiveNode secondStrategyKeyResultId secondStrategyId KeyResult
  , RawPrimitiveNode secondStrategyActionId secondStrategyId Action
  ]

secondStrategyCoherenceEdges :: [RawEdge]
secondStrategyCoherenceEdges =
  [ edge
      secondStrategyDriverId
      groundsStrategyDriverToObjective
      secondStrategyObjectiveId
  , edge
      secondStrategyPrincipleId
      guidesStrategyPrincipleToAction
      secondStrategyActionId
  , edge
      secondStrategyActionId
      contributesStrategyActionToKeyResult
      secondStrategyKeyResultId
  , edge
      secondStrategyKeyResultId
      substantiatesStrategyKeyResultObjective
      secondStrategyObjectiveId
  ]

secondStrategyMinimumEdges :: [RawEdge]
secondStrategyMinimumEdges =
  edge
    visionObjectiveId
    orientsVisionObjectiveToStrategyObjective
    secondStrategyObjectiveId
    : secondStrategyCoherenceEdges

secondStrategyFormulation :: RawStrategyFormulation
secondStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationStrategy = secondStrategyId
    , rawFormulationDiagnosis = secondStrategyDriverId
    , rawFormulationIntent = secondStrategyObjectiveId
    , rawFormulationGuidingPolicy = secondStrategyPrincipleId
    , rawFormulationActions = secondStrategyActionId NonEmpty.:| []
    , rawFormulationKeyResults = secondStrategyKeyResultId NonEmpty.:| []
    }

duplicateChild :: RawNode -> RawNode
duplicateChild (RawPrimitiveNode identifier owner primitive) =
  RawPrimitiveNode (duplicateId identifier) owner primitive
duplicateChild (RawStructuringNode identifier owner structuring) =
  RawStructuringNode (duplicateId identifier) owner structuring
duplicateChild (RawAnchorNode identifier anchor) =
  RawAnchorNode (duplicateId identifier) anchor
duplicateChild node@(RawContextNode _ _) = node

duplicateEdge :: RawEdge -> RawEdge
duplicateEdge candidate =
  candidate
    { rawEdgeFrom = duplicateIfChild (rawEdgeFrom candidate)
    , rawEdgeTo = duplicateIfChild (rawEdgeTo candidate)
    }

duplicateIfChild :: RawNodeId -> RawNodeId
duplicateIfChild identifier
  | isContextId identifier = identifier
  | otherwise = duplicateId identifier

duplicateId :: RawNodeId -> RawNodeId
duplicateId (RawNodeId identifier) = RawNodeId ("second-" <> identifier)

isContextNode :: RawNode -> Bool
isContextNode (RawContextNode _ _) = True
isContextNode _ = False

isContextId :: RawNodeId -> Bool
isContextId identifier =
  identifier
    `elem` [ ethosId
           , missionId
           , visionId
           , strategyId
           , needId
           , interventionId
           , measureId
           , situationId
           ]

graphWithAnchor :: SituationAnchor -> RawGraph
graphWithAnchor anchor =
  sampleGraph {rawNodes = map replaceAnchor (rawNodes sampleGraph)}
  where
    replaceAnchor (RawAnchorNode identifier _) = RawAnchorNode identifier anchor
    replaceAnchor node = node

sampleNodes :: [RawNode]
sampleNodes =
  [ RawContextNode ethosId Ethos
  , RawContextNode missionId Mission
  , RawContextNode visionId Vision
  , RawContextNode strategyId Strategy
  , RawContextNode needId Need
  , RawContextNode interventionId Intervention
  , RawContextNode measureId Measure
  , RawContextNode situationId Situation
  , RawPrimitiveNode ethosPrincipleId ethosId Principle
  , RawPrimitiveNode missionDriverId missionId Driver
  , RawPrimitiveNode visionObjectiveId visionId Objective
  , RawPrimitiveNode strategyDriverId strategyId Driver
  , RawPrimitiveNode strategyObjectiveId strategyId Objective
  , RawPrimitiveNode strategyPrincipleId strategyId Principle
  , RawPrimitiveNode strategyKeyResultId strategyId KeyResult
  , RawPrimitiveNode strategyActionId strategyId Action
  , RawPrimitiveNode needDriverId needId Driver
  , RawPrimitiveNode needObjectiveId needId Objective
  , RawPrimitiveNode interventionActionId interventionId Action
  , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
  , RawPrimitiveNode measureKpiId measureId KPI
  , RawStructuringNode
      measurePerformanceDimensionId
      measureId
      PerformanceDimension
  , RawAnchorNode situationAnchorId BusinessCapability
  ]

sampleEdges :: [RawEdge]
sampleEdges =
  [ edge visionId orientsStrategy strategyId
  , edge strategyId qualifiesNeed needId
  , edge situationId surfacesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId addressesNeed needId
  , edge interventionId changesSituation situationId
  , edge strategyId framesMeasure measureId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , edge strategyDriverId groundsStrategyDriverToObjective strategyObjectiveId
  , edge strategyPrincipleId guidesStrategyPrincipleToAction strategyActionId
  , edge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , edge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  , edge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      needObjectiveId
  , edge needDriverId groundsNeedDriverToObjective needObjectiveId
  , anchorEdge situationId ConstitutedByAnchorFamily situationAnchorId
  , anchorEdge situationAnchorId AnchorsNeedDriverFamily needDriverId
  , edge
      strategyActionId
      guidesStrategyActionToInterventionAction
      interventionActionId
  , edge
      interventionActionId
      contributesInterventionActionToKeyResult
      interventionKeyResultId
  , edge
      interventionKeyResultId
      substantiatesInterventionKeyResultNeedObjective
      needObjectiveId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  , edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      measurePerformanceDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpiId
  , edge interventionKeyResultId setsTargetForMeasureKPI measureKpiId
  , anchorEdge interventionActionId ChangesAnchorFamily situationAnchorId
  , anchorEdge measureKpiId MeasuresAnchorFamily situationAnchorId
  , edge ethosPrincipleId guidesEthosPrincipleToMissionDriver missionDriverId
  , edge missionDriverId groundsMissionDriverToVisionObjective visionObjectiveId
  , edge
      ethosPrincipleId
      guidesEthosPrincipleToVisionObjective
      visionObjectiveId
  ]

edge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
edge from relation to = RawEdge from (relationNameFor relation) to

anchorEdge :: RawNodeId -> AnchorRelationFamily -> RawNodeId -> RawEdge
anchorEdge from family to = RawEdge from (anchorRelationFamilyName family) to

multiplyInvalidGraph :: RawGraph
multiplyInvalidGraph =
  RawGraph
    [ RawContextNode strategyId Strategy
    , RawContextNode strategyId Need
    , RawPrimitiveNode needObjectiveId missingId KPI
    ]
    [RawEdge missingId (RelationName "unknown") strategyId]

invalidRelationEndpointsGraph :: RawGraph
invalidRelationEndpointsGraph =
  RawGraph
    [RawContextNode strategyId Strategy, RawContextNode needId Need]
    [edge needId qualifiesNeed strategyId]

independentlyInvalidEdgeGraph :: RawGraph
independentlyInvalidEdgeGraph =
  RawGraph
    []
    [ RawEdge
        (RawNodeId "unknown-from")
        (RelationName "unknown")
        (RawNodeId "unknown-to")
    ]

unknownEndpointGraph :: QC.Gen RawGraph
unknownEndpointGraph = do
  suffix <- QC.listOf1 (QC.elements ['a' .. 'z'])
  let from = RawNodeId ("unknown-from-" <> Text.pack suffix)
      to = RawNodeId ("unknown-to-" <> Text.pack suffix)
  pure (RawGraph [] [RawEdge from (RelationName "unknown") to])

additionalUntracedNeedGraph :: RawGraph
additionalUntracedNeedGraph =
  sampleGraph
    { rawNodes =
        RawContextNode additionalNeedId Need
          : RawPrimitiveNode additionalNeedDriverId additionalNeedId Driver
          : RawPrimitiveNode
              additionalNeedObjectiveId
              additionalNeedId
              Objective
          : rawNodes sampleGraph
    , rawEdges =
        edge interventionId addressesNeed additionalNeedId
          : edge situationId surfacesNeed additionalNeedId
          : anchorEdge
              situationAnchorId
              AnchorsNeedDriverFamily
              additionalNeedDriverId
          : edge
              additionalNeedDriverId
              groundsNeedDriverToObjective
              additionalNeedObjectiveId
          : edge
              interventionKeyResultId
              substantiatesInterventionKeyResultNeedObjective
              additionalNeedObjectiveId
          : rawEdges sampleGraph
    }

macroWithoutEvidenceGraph :: RawGraph
macroWithoutEvidenceGraph =
  sampleGraph
    { rawNodes =
        RawContextNode secondMissionId Mission
          : RawPrimitiveNode secondMissionDriverId secondMissionId Driver
          : rawNodes sampleGraph
    , rawEdges =
        edge secondMissionId groundsVision visionId
          : edge
              ethosPrincipleId
              guidesEthosPrincipleToMissionDriver
              secondMissionDriverId
          : rawEdges sampleGraph
    }

planForTrace :: EffectTrace -> EvidencePlan
planForTrace trace =
  EvidencePlan
    { plannedTrace = traceIdentifier trace
    , establishedAt = criteriaDate
    , targetDueAt = targetDate
    , planSource = EvidenceSource "approved measurement plan"
    , baseline = alignObservation trace (observation 40 baselineDate)
    , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 10)
    , targetCriterion = AtLeast (Level 70)
    }

definitionsFor :: TraceableEffectModel -> [RawKPIDefinition]
definitionsFor model =
  [ sampleKPIDefinition {rawDefinitionKPI = identifier}
  | identifier <-
      nub (map (unNodeId . traceKPI) (NonEmpty.toList (effectTraces model)))
  ]

sampleKPIDefinition :: RawKPIDefinition
sampleKPIDefinition =
  RawKPIDefinition
    { rawDefinitionKPI = measureKpiId
    , rawDefinitionUnit = percent
    , rawDefinitionDomain = percentageDomain
    , rawDefinitionMeasurementMethod = "monthly controlled measurement"
    , rawDefinitionInterpretation = "higher levels indicate better outcomes"
    }

plannedStartsFor :: TraceableEffectModel -> [PlannedInterventionStart]
plannedStartsFor model =
  [ samplePlannedStart {plannedIntervention = contextRefId intervention}
  | intervention <-
      nub (map traceIntervention (NonEmpty.toList (effectTraces model)))
  ]

samplePlannedStart :: PlannedInterventionStart
samplePlannedStart =
  PlannedInterventionStart
    {plannedIntervention = interventionId, plannedStartAt = interventionDate}

sampleActualStart :: ActualInterventionStart
sampleActualStart =
  ActualInterventionStart
    {actualIntervention = interventionId, actualStartAt = interventionDate}

followUpForTrace :: EffectTrace -> Rational -> UTCTime -> FollowUpObservation
followUpForTrace trace value observationTime =
  FollowUpObservation
    { followUpTrace = traceIdentifier trace
    , followUpObservation =
        alignObservation trace (observation value observationTime)
    }

alignObservation :: EffectTrace -> Observation -> Observation
alignObservation trace item =
  item
    { observationKPI = unNodeId (traceKPI trace)
    , observationAnchor = situationAnchorRefId (traceSituationAnchor trace)
    }

followUpsForReady ::
     EvidenceReadyModel -> Rational -> UTCTime -> [FollowUpObservation]
followUpsForReady ready value observationTime =
  map
    (\trace -> followUpForTrace trace value observationTime)
    (NonEmpty.toList (readyEffectTraces ready))

mapBaseline :: (Observation -> Observation) -> EvidencePlan -> EvidencePlan
mapBaseline transform plan = plan {baseline = transform (baseline plan)}

observation :: Rational -> UTCTime -> Observation
observation value observedTimestamp =
  Observation
    { observationKPI = measureKpiId
    , observationAnchor = situationAnchorId
    , observedAt = observedTimestamp
    , observedLevel = Level value
    , observationSource = EvidenceSource "decision registry"
    }

criteriaDate, baselineDate, beforeReadinessDate, readinessDate :: UTCTime
criteriaDate = timestamp 2025 12 1

baselineDate = timestamp 2026 1 1

beforeReadinessDate = timestamp 2026 1 10

readinessDate = timestamp 2026 1 15

afterReadinessDate :: UTCTime
afterReadinessDate = timestamp 2026 1 20

interventionDate, afterInterventionDate, earlyTargetDate :: UTCTime
interventionDate = timestamp 2026 2 1

afterInterventionDate = timestamp 2026 3 1

earlyTargetDate = timestamp 2026 2 15

targetDate, followUpDate, laterFollowUpDate, assessmentDate :: UTCTime
targetDate = timestamp 2026 6 30

followUpDate = timestamp 2026 6 1

laterFollowUpDate = timestamp 2026 6 15

assessmentDate = timestamp 2026 7 1

lateObservationDate, lateAssessmentDate :: UTCTime
lateObservationDate = timestamp 2026 7 15

lateAssessmentDate = timestamp 2026 8 1

timestamp :: Integer -> Int -> Int -> UTCTime
timestamp year month day =
  UTCTime (fromGregorian year month day) (secondsToDiffTime 0)

percent, count :: Unit
percent = PercentagePoints

count = NamedUnit "count"

percentageDomain :: ValueDomain
percentageDomain = BoundedDomain (Level 0) (Level 100)

ethosId, missionId, visionId, strategyId, needId :: RawNodeId
ethosId = RawNodeId "ethos"

missionId = RawNodeId "mission"

visionId = RawNodeId "vision"

strategyId = RawNodeId "strategy"

needId = RawNodeId "need"

secondMissionId, secondMissionDriverId :: RawNodeId
secondMissionId = RawNodeId "second-mission"

secondMissionDriverId = RawNodeId "second-mission-driver"

additionalNeedId, interventionId :: RawNodeId
additionalNeedId = RawNodeId "additional-need"

interventionId = RawNodeId "intervention"

measureId, situationId, missingId :: RawNodeId
measureId = RawNodeId "measure"

situationId = RawNodeId "situation"

missingId = RawNodeId "missing"

ethosPrincipleId, missionDriverId, visionObjectiveId :: RawNodeId
ethosPrincipleId = RawNodeId "ethos-principle"

missionDriverId = RawNodeId "mission-driver"

visionObjectiveId = RawNodeId "vision-objective"

strategyDriverId, strategyObjectiveId :: RawNodeId
strategyDriverId = RawNodeId "strategy-driver"

strategyObjectiveId = RawNodeId "strategy-objective"

strategyPrincipleId, strategyKeyResultId, strategyActionId :: RawNodeId
strategyPrincipleId = RawNodeId "strategy-principle"

strategyKeyResultId = RawNodeId "strategy-key-result"

strategyActionId = RawNodeId "strategy-action"

needDriverId, additionalNeedDriverId :: RawNodeId
needDriverId = RawNodeId "need-driver"

additionalNeedDriverId = RawNodeId "additional-need-driver"

needObjectiveId, additionalNeedObjectiveId, interventionActionId :: RawNodeId
needObjectiveId = RawNodeId "need-objective"

additionalNeedObjectiveId = RawNodeId "additional-need-objective"

interventionActionId = RawNodeId "intervention-action"

interventionKeyResultId, measureKpiId, measurePerformanceDimensionId ::
     RawNodeId
interventionKeyResultId = RawNodeId "intervention-key-result"

measureKpiId = RawNodeId "measure-kpi"

measurePerformanceDimensionId = RawNodeId "measure-performance-dimension"

strategyPerformanceDimensionId, performanceDimensionOwnerId, genericPerformanceDimensionId ::
     RawNodeId
strategyPerformanceDimensionId = RawNodeId "strategy-performance-dimension"

performanceDimensionOwnerId = RawNodeId "performance-dimension-owner"

genericPerformanceDimensionId = RawNodeId "performance-dimension"

situationAnchorId :: RawNodeId
situationAnchorId = RawNodeId "situation-anchor"

secondStrategyId, secondStrategyDriverId, secondStrategyObjectiveId :: RawNodeId
secondStrategyId = RawNodeId "second-strategy"

secondStrategyDriverId = RawNodeId "second-strategy-driver"

secondStrategyObjectiveId = RawNodeId "second-strategy-objective"

secondStrategyPrincipleId, secondStrategyKeyResultId, secondStrategyActionId ::
     RawNodeId
secondStrategyPrincipleId = RawNodeId "second-strategy-principle"

secondStrategyKeyResultId = RawNodeId "second-strategy-key-result"

secondStrategyActionId = RawNodeId "second-strategy-action"

unlistedStrategyDriverId, unlistedStrategyObjectiveId :: RawNodeId
unlistedStrategyDriverId = RawNodeId "unlisted-strategy-driver"

unlistedStrategyObjectiveId = RawNodeId "unlisted-strategy-objective"

unlistedStrategyPrincipleId, unlistedStrategyKeyResultId :: RawNodeId
unlistedStrategyPrincipleId = RawNodeId "unlisted-strategy-principle"

unlistedStrategyKeyResultId = RawNodeId "unlisted-strategy-key-result"

unlistedStrategyActionId, secondUnlistedStrategyPrincipleId :: RawNodeId
unlistedStrategyActionId = RawNodeId "unlisted-strategy-action"

secondUnlistedStrategyPrincipleId =
  RawNodeId "second-unlisted-strategy-principle"

secondUnlistedStrategyKeyResultId, secondUnlistedStrategyActionId :: RawNodeId
secondUnlistedStrategyKeyResultId =
  RawNodeId "second-unlisted-strategy-key-result"

secondUnlistedStrategyActionId = RawNodeId "second-unlisted-strategy-action"
