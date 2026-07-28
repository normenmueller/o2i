{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Graph builders for private effect-trace search scenarios.
module O2I.Validation.Trace.Search.Test.Scenarios where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Interpretation
import O2I.Language.Relation
import O2I.Validation.Trace.Search
import O2I.Validation.Trace.Search.Test.Fixture

searchGraph :: Int -> Int -> ([SomeEdge] -> [SomeEdge]) -> TraceSearchResult
searchGraph pathCount unreachableCount orderEdges =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ concatMap pathNodes [1 .. pathCount]
          ++ unreachableNodes unreachableCount)
       (orderEdges (fixedEdges ++ concatMap pathEdges [1 .. pathCount])))
    strategyRoles

searchGraphWithMismatchedSpines :: Int -> TraceSearchResult
searchGraphWithMismatchedSpines fanOut =
  searchGraphWithAdditions
    (concatMap mismatchedSpineNodes [1 .. fanOut])
    (concatMap mismatchedSpineEdges [1 .. fanOut])

searchGraphWithUnconstitutedAnchors :: Int -> TraceSearchResult
searchGraphWithUnconstitutedAnchors fanOut =
  searchGraphWithAdditions
    (concatMap unconstitutedAnchorNodes [1 .. fanOut])
    (concatMap unconstitutedAnchorEdges [1 .. fanOut])

searchGraphWithStrategySituationFanOut :: Int -> TraceSearchResult
searchGraphWithStrategySituationFanOut fanOut =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap strategySituationNodes [1 .. fanOut])
       (fixedEdges
          ++ pathEdges 1
          ++ concatMap strategySituationEdges [1 .. fanOut]))
    (strategyRolesWithFanOut fanOut)

searchGraphWithTargetMeasureSituationFanOut :: Int -> TraceSearchResult
searchGraphWithTargetMeasureSituationFanOut fanOut =
  searchGraphWithAdditions
    (concatMap targetMeasureSituationNodes [1 .. fanOut])
    (concatMap targetMeasureSituationEdges [1 .. fanOut])

searchGraphWithAddressedNeedMeasureFanOut :: Int -> TraceSearchResult
searchGraphWithAddressedNeedMeasureFanOut fanOut =
  deriveTracePaths
    (mkGraph
       ([ contextNode needMeasureVisionId SVision
        , contextNode needMeasureInterventionId SIntervention
        ]
          ++ concatMap needMeasureNodes [1 .. fanOut])
       (concatMap needMeasureEdges [1 .. fanOut]))
    (needMeasureRoles fanOut)

searchGraphWithStrategyActionFanOut :: Int -> TraceSearchResult
searchGraphWithStrategyActionFanOut fanOut =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap strategyActionFanOutNodes [1 .. fanOut])
       (fixedEdges
          ++ pathEdges 1
          ++ concatMap strategyActionFanOutEdges [1 .. fanOut]))
    (strategyActionFanOutRoles fanOut)

searchGraphWithNeedObjectiveFanOut :: Int -> TraceSearchResult
searchGraphWithNeedObjectiveFanOut fanOut =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap needObjectiveFanOutNodes [1 .. fanOut])
       (fixedEdges
          ++ pathEdges 1
          ++ concatMap needObjectiveFanOutEdges [1 .. fanOut]))
    (needObjectiveFanOutRoles fanOut)

searchGraphWithAnchorRelationFanOut :: Int -> TraceSearchResult
searchGraphWithAnchorRelationFanOut fanOut =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap anchorRelationFanOutNodes [1 .. fanOut])
       (fixedEdges
          ++ pathEdges 1
          ++ concatMap anchorRelationFanOutEdges [1 .. fanOut]))
    strategyRoles

searchGraphWithVisionFanOut ::
     Int -> ([SomeEdge] -> [SomeEdge]) -> TraceSearchResult
searchGraphWithVisionFanOut fanOut orderEdges =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap visionFanOutNodes [1 .. fanOut]
          ++ concatMap mismatchedSpineNodes [1 .. fanOut])
       (orderEdges
          (fixedEdges
             ++ pathEdges 1
             ++ concatMap visionFanOutEdges [1 .. fanOut]
             ++ concatMap mismatchedSpineEdges [1 .. fanOut])))
    strategyRoles

searchGraphWithConvergentKeyResults ::
     Int -> ([SomeEdge] -> [SomeEdge]) -> TraceSearchResult
searchGraphWithConvergentKeyResults fanOut orderEdges =
  deriveTracePaths
    (mkGraph
       (fixedNodes
          ++ pathNodes 1
          ++ concatMap convergentKeyResultNodes [1 .. fanOut])
       (orderEdges
          (fixedEdges
             ++ pathEdges 1
             ++ concatMap convergentKeyResultEdges [1 .. fanOut])))
    (convergentKeyResultRoles fanOut)

searchGraphWithFirstThreeWayGuardRejection :: TraceSearchResult
searchGraphWithFirstThreeWayGuardRejection =
  searchGraphWithAdditions
    threeWayRejectionNodes
    firstThreeWayGuardRejectionEdges

searchGraphWithSecondThreeWayGuardRejection :: TraceSearchResult
searchGraphWithSecondThreeWayGuardRejection =
  searchGraphWithAdditions
    threeWayRejectionNodes
    secondThreeWayGuardRejectionEdges

searchGraphWithAdditions :: [SomeNode] -> [SomeEdge] -> TraceSearchResult
searchGraphWithAdditions nodes edges =
  deriveTracePaths
    (mkGraph
       (fixedNodes ++ pathNodes 1 ++ nodes)
       (fixedEdges ++ pathEdges 1 ++ edges))
    strategyRoles

mkGraph :: [SomeNode] -> [SomeEdge] -> WellFormedGraph
mkGraph nodes =
  mkWellFormedGraph (Map.fromList [(someNodeId node, node) | node <- nodes])

fixedNodes :: [SomeNode]
fixedNodes =
  [ contextNode visionId SVision
  , contextNode strategyId SStrategy
  , contextNode needId SNeed
  , contextNode interventionId SIntervention
  , contextNode measureId SMeasure
  , contextNode situationId SSituation
  , primitiveNode
      visionObjectiveId
      visionId
      SVision
      SObjective
      ObjectiveInVision
  , primitiveNode strategyDriverId strategyId SStrategy SDriver DriverInStrategy
  , primitiveNode
      strategyObjectiveId
      strategyId
      SStrategy
      SObjective
      ObjectiveInStrategy
  , primitiveNode
      strategyKeyResultId
      strategyId
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyActionId strategyId SStrategy SAction ActionInStrategy
  ]

fixedEdges :: [SomeEdge]
fixedEdges =
  [ typedEdge visionId orientsStrategy strategyId
  , typedEdge strategyId qualifiesNeed needId
  , typedEdge situationId surfacesNeed needId
  , typedEdge strategyId directsIntervention interventionId
  , typedEdge interventionId addressesNeed needId
  , typedEdge interventionId changesSituation situationId
  , typedEdge strategyId framesMeasure measureId
  , typedEdge interventionId setsTargetForMeasure measureId
  , typedEdge measureId measuresSituation situationId
  , typedEdge
      visionObjectiveId
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  , typedEdge
      strategyDriverId
      groundsStrategyDriverToObjective
      strategyObjectiveId
  , typedEdge
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , typedEdge
      strategyActionId
      contributesStrategyActionToKeyResult
      strategyKeyResultId
  ]

pathNodes :: Int -> [SomeNode]
pathNodes ordinal = spineNodes (pathId ordinal)

pathEdges :: Int -> [SomeEdge]
pathEdges ordinal =
  spineEdges identify
    ++ [ typedEdge
           situationId
           (constitutedByAnchor SBusinessCapability)
           (identify "situation-anchor")
       ]
  where
    identify = pathId ordinal

visionFanOutNodes :: Int -> [SomeNode]
visionFanOutNodes ordinal =
  [ contextNode vision SVision
  , primitiveNode objective vision SVision SObjective ObjectiveInVision
  ]
  where
    vision = visionFanOutId ordinal "vision"
    objective = visionFanOutId ordinal "vision-objective"

visionFanOutEdges :: Int -> [SomeEdge]
visionFanOutEdges ordinal =
  [ typedEdge vision orientsStrategy strategyId
  , typedEdge
      objective
      orientsVisionObjectiveToStrategyObjective
      strategyObjectiveId
  ]
  where
    vision = visionFanOutId ordinal "vision"
    objective = visionFanOutId ordinal "vision-objective"

convergentKeyResultNodes :: Int -> [SomeNode]
convergentKeyResultNodes ordinal =
  [ primitiveNode
      strategyKeyResult
      strategyId
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyAction strategyId SStrategy SAction ActionInStrategy
  , primitiveNode needObjective needId SNeed SObjective ObjectiveInNeed
  , primitiveNode
      interventionKeyResult
      interventionId
      SIntervention
      SKeyResult
      KeyResultInIntervention
  ]
  where
    strategyKeyResult = convergentStrategyKeyResultId ordinal
    strategyAction = convergentStrategyActionId ordinal
    needObjective = convergentNeedObjectiveId ordinal
    interventionKeyResult = convergentInterventionKeyResultId ordinal

convergentKeyResultEdges :: Int -> [SomeEdge]
convergentKeyResultEdges ordinal =
  [ typedEdge
      strategyKeyResult
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , typedEdge
      strategyAction
      contributesStrategyActionToKeyResult
      strategyKeyResult
  , typedEdge
      strategyAction
      guidesStrategyActionToInterventionAction
      (pathId 1 "intervention-action")
  , typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , typedEdge
      (pathId 1 "need-driver")
      groundsNeedDriverToObjective
      needObjective
  , typedEdge
      strategyKeyResult
      determinesMeasurePerformanceDimension
      (pathId 1 "measure-dimension")
  , typedEdge
      (pathId 1 "intervention-action")
      contributesInterventionActionToKeyResult
      interventionKeyResult
  , typedEdge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , typedEdge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , typedEdge
      interventionKeyResult
      setsTargetForMeasureKPI
      (pathId 1 "measure-kpi")
  ]
  where
    strategyKeyResult = convergentStrategyKeyResultId ordinal
    strategyAction = convergentStrategyActionId ordinal
    needObjective = convergentNeedObjectiveId ordinal
    interventionKeyResult = convergentInterventionKeyResultId ordinal

threeWayRejectionNodes :: [SomeNode]
threeWayRejectionNodes =
  [ primitiveNode threeWayCandidateId needId SNeed SObjective ObjectiveInNeed
  , primitiveNode threeWayFillerId needId SNeed SObjective ObjectiveInNeed
  ]

firstThreeWayGuardRejectionEdges :: [SomeEdge]
firstThreeWayGuardRejectionEdges =
  [ typedEdge
      (pathId 1 "need-driver")
      groundsNeedDriverToObjective
      threeWayCandidateId
  , typedEdge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      threeWayFillerId
  , typedEdge
      (pathId 1 "intervention-key-result")
      substantiatesInterventionKeyResultNeedObjective
      threeWayCandidateId
  ]

secondThreeWayGuardRejectionEdges :: [SomeEdge]
secondThreeWayGuardRejectionEdges =
  [ typedEdge
      (pathId 1 "need-driver")
      groundsNeedDriverToObjective
      threeWayCandidateId
  , typedEdge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      threeWayCandidateId
  , typedEdge
      (pathId 1 "intervention-key-result")
      substantiatesInterventionKeyResultNeedObjective
      threeWayFillerId
  ]

threeWayCandidateId, threeWayFillerId :: RawNodeId
threeWayCandidateId = threeWayRejectionId "candidate"

threeWayFillerId = threeWayRejectionId "filler"

strategyActionFanOutNodes :: Int -> [SomeNode]
strategyActionFanOutNodes ordinal =
  [ primitiveNode keyResult strategyId SStrategy SKeyResult KeyResultInStrategy
  , primitiveNode action strategyId SStrategy SAction ActionInStrategy
  ]
  where
    identify = strategyActionFanOutId ordinal
    keyResult = identify "strategy-key-result"
    action = identify "strategy-action"

strategyActionFanOutEdges :: Int -> [SomeEdge]
strategyActionFanOutEdges ordinal =
  [ typedEdge
      keyResult
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , typedEdge action contributesStrategyActionToKeyResult keyResult
  ]
    ++ spineEdgesFor strategyDriverId keyResult action (pathId 1)
  where
    identify = strategyActionFanOutId ordinal
    keyResult = identify "strategy-key-result"
    action = identify "strategy-action"

needObjectiveFanOutNodes :: Int -> [SomeNode]
needObjectiveFanOutNodes ordinal =
  primitiveNode keyResult strategyId SStrategy SKeyResult KeyResultInStrategy
    : spineNodes identify
  where
    identify = needObjectiveFanOutId ordinal
    keyResult = identify "strategy-key-result"

needObjectiveFanOutEdges :: Int -> [SomeEdge]
needObjectiveFanOutEdges ordinal =
  [ typedEdge
      keyResult
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  , typedEdge strategyActionId contributesStrategyActionToKeyResult keyResult
  ]
    ++ spineEdgesFor strategyDriverId keyResult strategyActionId identify
    ++ [ typedEdge
           situationId
           (constitutedByAnchor SBusinessCapability)
           (identify "situation-anchor")
       ]
  where
    identify = needObjectiveFanOutId ordinal
    keyResult = identify "strategy-key-result"

anchorRelationFanOutNodes :: Int -> [SomeNode]
anchorRelationFanOutNodes ordinal =
  [ performanceDimensionNode dimension measureId
  , primitiveNode kpi measureId SMeasure SKPI KPIInMeasure
  , anchorNode anchor
  ]
  where
    identify = anchorRelationFanOutId ordinal
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    anchor = identify "situation-anchor"

anchorRelationFanOutEdges :: Int -> [SomeEdge]
anchorRelationFanOutEdges ordinal =
  [ typedEdge strategyDriverId indicatesMeasurePerformanceDimension dimension
  , typedEdge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      kpi
  , typedEdge (pathId 1 "intervention-key-result") setsTargetForMeasureKPI kpi
  , typedEdge
      anchor
      (anchorsNeedDriver SBusinessCapability)
      (pathId 1 "need-driver")
  , typedEdge
      (pathId 1 "intervention-action")
      (changesAnchor SBusinessCapability)
      anchor
  , typedEdge kpi (measuresAnchor SBusinessCapability) anchor
  , typedEdge situationId (constitutedByAnchor SBusinessCapability) anchor
  ]
  where
    identify = anchorRelationFanOutId ordinal
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    anchor = identify "situation-anchor"

spineNodes :: (Text.Text -> RawNodeId) -> [SomeNode]
spineNodes identify =
  [ primitiveNode needDriver needId SNeed SDriver DriverInNeed
  , primitiveNode needObjective needId SNeed SObjective ObjectiveInNeed
  , primitiveNode
      interventionAction
      interventionId
      SIntervention
      SAction
      ActionInIntervention
  , primitiveNode
      interventionKeyResult
      interventionId
      SIntervention
      SKeyResult
      KeyResultInIntervention
  , performanceDimensionNode dimension measureId
  , primitiveNode measureKpi measureId SMeasure SKPI KPIInMeasure
  , anchorNode situationAnchor
  ]
  where
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    measureKpi = identify "measure-kpi"
    situationAnchor = identify "situation-anchor"

spineEdges :: (Text.Text -> RawNodeId) -> [SomeEdge]
spineEdges = spineEdgesFor strategyDriverId strategyKeyResultId strategyActionId

spineEdgesFor ::
     RawNodeId
  -> RawNodeId
  -> RawNodeId
  -> (Text.Text -> RawNodeId)
  -> [SomeEdge]
spineEdgesFor strategyDriver strategyKeyResult strategyAction identify =
  [ typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , typedEdge needDriver groundsNeedDriverToObjective needObjective
  , typedEdge
      strategyAction
      guidesStrategyActionToInterventionAction
      interventionAction
  , typedEdge
      interventionAction
      contributesInterventionActionToKeyResult
      interventionKeyResult
  , typedEdge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , typedEdge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , typedEdge strategyDriver indicatesMeasurePerformanceDimension dimension
  , typedEdge strategyKeyResult determinesMeasurePerformanceDimension dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpi
  , typedEdge interventionKeyResult setsTargetForMeasureKPI measureKpi
  , typedEdge situationAnchor (anchorsNeedDriver SBusinessCapability) needDriver
  , typedEdge
      interventionAction
      (changesAnchor SBusinessCapability)
      situationAnchor
  , typedEdge measureKpi (measuresAnchor SBusinessCapability) situationAnchor
  ]
  where
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    measureKpi = identify "measure-kpi"
    situationAnchor = identify "situation-anchor"

unreachableNodes :: Int -> [SomeNode]
unreachableNodes count =
  concatMap
    (\ordinal ->
       [ contextNode (unreachableId ordinal "ethos") SEthos
       , contextNode (unreachableId ordinal "mission") SMission
       , contextNode (unreachableId ordinal "vision") SVision
       , contextNode (unreachableId ordinal "strategy") SStrategy
       , contextNode (unreachableId ordinal "situation") SSituation
       , contextNode (unreachableId ordinal "need") SNeed
       , contextNode (unreachableId ordinal "intervention") SIntervention
       , contextNode (unreachableId ordinal "measure") SMeasure
       ])
    [1 .. count]

mismatchedSpineNodes :: Int -> [SomeNode]
mismatchedSpineNodes ordinal =
  spineNodes identify
    ++ [contextNode situation SSituation, anchorNode constitutingAnchor]
  where
    identify = mismatchedId ordinal
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

mismatchedSpineEdges :: Int -> [SomeEdge]
mismatchedSpineEdges ordinal =
  spineEdges identify
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           constitutingAnchor
       ]
  where
    identify = mismatchedId ordinal
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

unconstitutedAnchorNodes :: Int -> [SomeNode]
unconstitutedAnchorNodes ordinal =
  spineNodes (unconstitutedId ordinal)
    ++ [contextNode (liveSituationId ordinal) SSituation]

unconstitutedAnchorEdges :: Int -> [SomeEdge]
unconstitutedAnchorEdges ordinal =
  spineEdges (unconstitutedId ordinal)
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           (pathId 1 "situation-anchor")
       ]
  where
    situation = liveSituationId ordinal

strategySituationNodes :: Int -> [SomeNode]
strategySituationNodes ordinal =
  [ contextNode vision SVision
  , contextNode strategy SStrategy
  , primitiveNode visionObjective vision SVision SObjective ObjectiveInVision
  , primitiveNode driver strategy SStrategy SDriver DriverInStrategy
  , primitiveNode
      strategyObjective
      strategy
      SStrategy
      SObjective
      ObjectiveInStrategy
  , primitiveNode
      strategyKeyResult
      strategy
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyAction strategy SStrategy SAction ActionInStrategy
  , contextNode situation SSituation
  , anchorNode constitutingAnchor
  ]
  where
    identify = strategySituationId ordinal
    vision = identify "vision"
    strategy = identify "strategy"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

strategySituationEdges :: Int -> [SomeEdge]
strategySituationEdges ordinal =
  [ typedEdge vision orientsStrategy strategy
  , typedEdge strategy qualifiesNeed needId
  , typedEdge strategy directsIntervention interventionId
  , typedEdge strategy framesMeasure measureId
  , typedEdge
      visionObjective
      orientsVisionObjectiveToStrategyObjective
      strategyObjective
  , typedEdge driver groundsStrategyDriverToObjective strategyObjective
  , typedEdge
      strategyKeyResult
      substantiatesStrategyKeyResultObjective
      strategyObjective
  , typedEdge
      strategyAction
      contributesStrategyActionToKeyResult
      strategyKeyResult
  , typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      (pathId 1 "need-objective")
  , typedEdge
      strategyAction
      guidesStrategyActionToInterventionAction
      (pathId 1 "intervention-action")
  , typedEdge
      (pathId 1 "intervention-key-result")
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , typedEdge
      driver
      indicatesMeasurePerformanceDimension
      (pathId 1 "measure-dimension")
  ]
    ++ macroSituationEdges situation
    ++ [ typedEdge
           situation
           (constitutedByAnchor SBusinessCapability)
           constitutingAnchor
       ]
  where
    identify = strategySituationId ordinal
    vision = identify "vision"
    strategy = identify "strategy"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    situation = identify "situation"
    constitutingAnchor = identify "constituting-anchor"

targetMeasureSituationNodes :: Int -> [SomeNode]
targetMeasureSituationNodes ordinal =
  [ contextNode measure SMeasure
  , contextNode situation SSituation
  , performanceDimensionNode dimension measure
  , primitiveNode kpi measure SMeasure SKPI KPIInMeasure
  , contextNode pairWideStrategy SStrategy
  ]
  where
    identify = targetMeasureSituationId ordinal
    measure = identify "measure"
    situation = identify "situation"
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    pairWideStrategy = identify "pair-wide-strategy"

targetMeasureSituationEdges :: Int -> [SomeEdge]
targetMeasureSituationEdges ordinal =
  [ typedEdge interventionId setsTargetForMeasure measure
  , typedEdge strategyId framesMeasure measure
  , typedEdge measure measuresSituation situation
  , typedEdge interventionId changesSituation situation
  , typedEdge situation surfacesNeed needId
  , typedEdge
      situation
      (constitutedByAnchor SBusinessCapability)
      (pathId 1 "situation-anchor")
  , typedEdge strategyDriverId indicatesMeasurePerformanceDimension dimension
  , typedEdge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      kpi
  , typedEdge (pathId 1 "intervention-key-result") setsTargetForMeasureKPI kpi
  , typedEdge
      kpi
      (measuresAnchor SBusinessCapability)
      (pathId 1 "situation-anchor")
  , typedEdge pairWideStrategy qualifiesNeed needId
  , typedEdge pairWideStrategy directsIntervention interventionId
  ]
  where
    identify = targetMeasureSituationId ordinal
    measure = identify "measure"
    situation = identify "situation"
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    pairWideStrategy = identify "pair-wide-strategy"

needMeasureNodes :: Int -> [SomeNode]
needMeasureNodes ordinal =
  [ contextNode need SNeed
  , contextNode measure SMeasure
  , contextNode strategy SStrategy
  , contextNode situation SSituation
  , primitiveNode
      visionObjective
      needMeasureVisionId
      SVision
      SObjective
      ObjectiveInVision
  , primitiveNode driver strategy SStrategy SDriver DriverInStrategy
  , primitiveNode
      strategyObjective
      strategy
      SStrategy
      SObjective
      ObjectiveInStrategy
  , primitiveNode
      strategyKeyResult
      strategy
      SStrategy
      SKeyResult
      KeyResultInStrategy
  , primitiveNode strategyAction strategy SStrategy SAction ActionInStrategy
  , primitiveNode needDriver need SNeed SDriver DriverInNeed
  , primitiveNode needObjective need SNeed SObjective ObjectiveInNeed
  , primitiveNode
      interventionAction
      needMeasureInterventionId
      SIntervention
      SAction
      ActionInIntervention
  , primitiveNode
      interventionKeyResult
      needMeasureInterventionId
      SIntervention
      SKeyResult
      KeyResultInIntervention
  , performanceDimensionNode dimension measure
  , primitiveNode kpi measure SMeasure SKPI KPIInMeasure
  , anchorNode anchor
  ]
  where
    identify = needMeasureId ordinal
    need = identify "need"
    measure = identify "measure"
    strategy = identify "strategy"
    situation = identify "situation"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    anchor = identify "anchor"

needMeasureEdges :: Int -> [SomeEdge]
needMeasureEdges ordinal =
  [ typedEdge needMeasureVisionId orientsStrategy strategy
  , typedEdge strategy qualifiesNeed need
  , typedEdge strategy directsIntervention needMeasureInterventionId
  , typedEdge strategy framesMeasure measure
  , typedEdge needMeasureInterventionId addressesNeed need
  , typedEdge needMeasureInterventionId setsTargetForMeasure measure
  , typedEdge measure measuresSituation situation
  , typedEdge needMeasureInterventionId changesSituation situation
  , typedEdge situation surfacesNeed need
  , typedEdge
      visionObjective
      orientsVisionObjectiveToStrategyObjective
      strategyObjective
  , typedEdge driver groundsStrategyDriverToObjective strategyObjective
  , typedEdge
      strategyKeyResult
      substantiatesStrategyKeyResultObjective
      strategyObjective
  , typedEdge
      strategyAction
      contributesStrategyActionToKeyResult
      strategyKeyResult
  , typedEdge
      strategyKeyResult
      translatesStrategyKeyResultToNeedObjective
      needObjective
  , typedEdge needDriver groundsNeedDriverToObjective needObjective
  , typedEdge
      strategyAction
      guidesStrategyActionToInterventionAction
      interventionAction
  , typedEdge
      interventionAction
      contributesInterventionActionToKeyResult
      interventionKeyResult
  , typedEdge
      interventionKeyResult
      substantiatesInterventionKeyResultNeedObjective
      needObjective
  , typedEdge
      interventionKeyResult
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResult
  , typedEdge driver indicatesMeasurePerformanceDimension dimension
  , typedEdge strategyKeyResult determinesMeasurePerformanceDimension dimension
  , typedEdge
      dimension
      (containsPerformanceDimension MeasureMeasurementDimension)
      kpi
  , typedEdge interventionKeyResult setsTargetForMeasureKPI kpi
  , typedEdge anchor (anchorsNeedDriver SBusinessCapability) needDriver
  , typedEdge interventionAction (changesAnchor SBusinessCapability) anchor
  , typedEdge kpi (measuresAnchor SBusinessCapability) anchor
  , typedEdge situation (constitutedByAnchor SBusinessCapability) anchor
  ]
  where
    identify = needMeasureId ordinal
    need = identify "need"
    measure = identify "measure"
    strategy = identify "strategy"
    situation = identify "situation"
    visionObjective = identify "vision-objective"
    driver = identify "strategy-driver"
    strategyObjective = identify "strategy-objective"
    strategyKeyResult = identify "strategy-key-result"
    strategyAction = identify "strategy-action"
    needDriver = identify "need-driver"
    needObjective = identify "need-objective"
    interventionAction = identify "intervention-action"
    interventionKeyResult = identify "intervention-key-result"
    dimension = identify "measure-dimension"
    kpi = identify "measure-kpi"
    anchor = identify "anchor"
