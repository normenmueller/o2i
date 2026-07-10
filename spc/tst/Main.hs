module Main where

import O2I

main :: IO ()
main =
  mapM_
    assert
    [ ("empty model is structurally well-formed", wfModel emptyModel)
    , ( "model with unresolved intervention is structurally well-formed"
      , wfModel unresolvedIntervention)
    , ( "model with unresolved intervention is not a valid effect model"
      , not (validEffectModel unresolvedIntervention))
    , ( "invalid primitive placement is rejected"
      , not (wfModel invalidPlacement))
    , ( "invalid relation domain is rejected"
      , not (wfModel invalidRelationDomain))
    , ( "macro relation without evidence is rejected"
      , not (wfModel missingEvidence))
    , ( "effect-relevant need is recognized"
      , effRelevant sampleEffectModel needId)
    , ("complete effect model is valid", validEffectModel sampleEffectModel)
    , ( "need without surface evidence is not effect-relevant"
      , not (effRelevant withoutSurfaceEvidence needId))
    , ("complete effect trace is valid", validEffectTrace)
    , ( "effect trace requires framed measure evidence"
      , not (validTrace withoutFrameEvidence))
    , ( "valid effect model requires framed measure evidence"
      , not (validEffectModel withoutFrameEvidence))
    , ( "effect trace requires situation change evidence"
      , not (validTrace withoutChangeEvidence))
    , ( "valid effect model requires situation change evidence"
      , not (validEffectModel withoutChangeEvidence))
    , ( "effect trace requires measurement evidence"
      , not (validTrace withoutMeasureEvidence))
    , ( "valid effect model requires measurement evidence"
      , not (validEffectModel withoutMeasureEvidence))
    , ( "effect trace requires direct intervention evidence"
      , not (validTrace withoutDirectsInterventionEvidence))
    , ( "valid effect model requires direct intervention evidence"
      , not (validEffectModel withoutDirectsInterventionEvidence))
    , ( "valid effect model rejects additional untraced addressed need"
      , not (validEffectModel withAdditionalUntracedNeed))
    ]

assert :: (String, Bool) -> IO ()
assert (label, condition) =
  if condition
    then pure ()
    else fail ("failed: " ++ label)

validEffectTrace :: Bool
validEffectTrace = validTrace sampleEffectModel

validTrace :: Model -> Bool
validTrace model =
  effectTrace model strategyId needId interventionId measureId situationId

emptyModel :: Model
emptyModel =
  Model
    { contextNodes = []
    , primitiveNodes = []
    , structuringNodes = []
    , anchorNodes = []
    , edges = []
    }

invalidPlacement :: Model
invalidPlacement =
  emptyModel
    { contextNodes = [ContextNode ethosId Ethos]
    , primitiveNodes = [PrimitiveNode invalidObjectiveId ethosId Objective]
    }

invalidRelationDomain :: Model
invalidRelationDomain =
  emptyModel
    { contextNodes = [ContextNode strategyId Strategy, ContextNode needId Need]
    , edges =
        [Edge (CtxRef needId) (SomeRelation QualifiesNeed) (CtxRef strategyId)]
    }

missingEvidence :: Model
missingEvidence =
  emptyModel
    { contextNodes = [ContextNode strategyId Strategy, ContextNode needId Need]
    , edges =
        [Edge (CtxRef strategyId) (SomeRelation QualifiesNeed) (CtxRef needId)]
    }

unresolvedIntervention :: Model
unresolvedIntervention =
  emptyModel {contextNodes = [ContextNode interventionId Intervention]}

withoutSurfaceEvidence :: Model
withoutSurfaceEvidence =
  sampleEffectModel
    { edges =
        removeEdge
          (Edge
             (AnchorRef situationAnchorId)
             (SomeRelation AnchorsNeedDriver)
             (PrimRef needDriverId))
          (edges sampleEffectModel)
    }

withoutFrameEvidence :: Model
withoutFrameEvidence =
  sampleEffectModel
    { edges =
        removeEdge
          (Edge
             (PrimRef strategyKeyResultId)
             (SomeRelation DeterminesMeasureDomain)
             (StructRef measureDomainId))
          (edges sampleEffectModel)
    }

withoutChangeEvidence :: Model
withoutChangeEvidence =
  sampleEffectModel
    { edges =
        removeEdge
          (Edge
             (PrimRef interventionActionId)
             (SomeRelation ChangesAnchor)
             (AnchorRef situationAnchorId))
          (edges sampleEffectModel)
    }

withoutMeasureEvidence :: Model
withoutMeasureEvidence =
  sampleEffectModel
    { edges =
        removeEdge
          (Edge
             (PrimRef measureKpiId)
             (SomeRelation MeasuresAnchor)
             (AnchorRef situationAnchorId))
          (edges sampleEffectModel)
    }

withoutDirectsInterventionEvidence :: Model
withoutDirectsInterventionEvidence =
  sampleEffectModel
    { edges =
        removeEdge
          (Edge
             (PrimRef strategyActionId)
             (SomeRelation GuidesStrategyActionToInterventionAction)
             (PrimRef interventionActionId))
          (edges sampleEffectModel)
    }

withAdditionalUntracedNeed :: Model
withAdditionalUntracedNeed =
  sampleEffectModel
    { contextNodes =
        ContextNode additionalNeedId Need : contextNodes sampleEffectModel
    , primitiveNodes =
        PrimitiveNode additionalNeedObjectiveId additionalNeedId Objective
          : primitiveNodes sampleEffectModel
    , edges =
        [ Edge
            (CtxRef interventionId)
            (SomeRelation AddressesNeed)
            (CtxRef additionalNeedId)
        , Edge
            (PrimRef interventionKeyResultId)
            (SomeRelation SubstantiatesInterventionKeyResultNeedObjective)
            (PrimRef additionalNeedObjectiveId)
        ]
          ++ edges sampleEffectModel
    }

removeEdge :: Edge -> [Edge] -> [Edge]
removeEdge edgeToRemove = filter (/= edgeToRemove)

sampleEffectModel :: Model
sampleEffectModel =
  Model
    { contextNodes =
        [ ContextNode strategyId Strategy
        , ContextNode needId Need
        , ContextNode interventionId Intervention
        , ContextNode measureId Measure
        , ContextNode situationId Situation
        ]
    , primitiveNodes =
        [ PrimitiveNode strategyDriverId strategyId Driver
        , PrimitiveNode strategyObjectiveId strategyId Objective
        , PrimitiveNode strategyKeyResultId strategyId KeyResult
        , PrimitiveNode strategyActionId strategyId Action
        , PrimitiveNode needDriverId needId Driver
        , PrimitiveNode needObjectiveId needId Objective
        , PrimitiveNode interventionActionId interventionId Action
        , PrimitiveNode interventionKeyResultId interventionId KeyResult
        , PrimitiveNode measureKpiId measureId KPI
        ]
    , structuringNodes = [StructuringNode measureDomainId measureId Domain]
    , anchorNodes =
        [AnchorNode situationAnchorId situationId BusinessCapability]
    , edges =
        [ Edge (CtxRef strategyId) (SomeRelation QualifiesNeed) (CtxRef needId)
        , Edge
            (CtxRef strategyId)
            (SomeRelation DirectsIntervention)
            (CtxRef interventionId)
        , Edge
            (CtxRef interventionId)
            (SomeRelation AddressesNeed)
            (CtxRef needId)
        , Edge
            (CtxRef interventionId)
            (SomeRelation ChangesSituation)
            (CtxRef situationId)
        , Edge
            (CtxRef interventionId)
            (SomeRelation SetsTargetForMeasure)
            (CtxRef measureId)
        , Edge
            (CtxRef measureId)
            (SomeRelation MeasuresSituation)
            (CtxRef situationId)
        , Edge
            (CtxRef strategyId)
            (SomeRelation FramesMeasure)
            (CtxRef measureId)
        , Edge (CtxRef situationId) (SomeRelation SurfacesNeed) (CtxRef needId)
        , Edge
            (CtxRef situationId)
            (SomeRelation ConstitutedByAnchor)
            (AnchorRef situationAnchorId)
        , Edge
            (PrimRef strategyDriverId)
            (SomeRelation GroundsStrategyDriverToObjective)
            (PrimRef strategyObjectiveId)
        , Edge
            (PrimRef strategyKeyResultId)
            (SomeRelation SubstantiatesStrategyKeyResultObjective)
            (PrimRef strategyObjectiveId)
        , Edge
            (PrimRef strategyActionId)
            (SomeRelation ContributesStrategyActionToKeyResult)
            (PrimRef strategyKeyResultId)
        , Edge
            (PrimRef strategyKeyResultId)
            (SomeRelation TranslatesStrategyKeyResultToNeedObjective)
            (PrimRef needObjectiveId)
        , Edge
            (PrimRef needDriverId)
            (SomeRelation GroundsNeedDriverToObjective)
            (PrimRef needObjectiveId)
        , Edge
            (AnchorRef situationAnchorId)
            (SomeRelation AnchorsNeedDriver)
            (PrimRef needDriverId)
        , Edge
            (PrimRef strategyDriverId)
            (SomeRelation IndicatesMeasureDomain)
            (StructRef measureDomainId)
        , Edge
            (PrimRef strategyKeyResultId)
            (SomeRelation DeterminesMeasureDomain)
            (StructRef measureDomainId)
        , Edge
            (StructRef measureDomainId)
            (SomeRelation ContainsMeasureKPI)
            (PrimRef measureKpiId)
        , Edge
            (PrimRef strategyActionId)
            (SomeRelation GuidesStrategyActionToInterventionAction)
            (PrimRef interventionActionId)
        , Edge
            (PrimRef interventionActionId)
            (SomeRelation ContributesInterventionActionToKeyResult)
            (PrimRef interventionKeyResultId)
        , Edge
            (PrimRef interventionKeyResultId)
            (SomeRelation SubstantiatesInterventionKeyResultNeedObjective)
            (PrimRef needObjectiveId)
        , Edge
            (PrimRef interventionKeyResultId)
            (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult)
            (PrimRef strategyKeyResultId)
        , Edge
            (PrimRef interventionKeyResultId)
            (SomeRelation SetsTargetForMeasureKPI)
            (PrimRef measureKpiId)
        , Edge
            (PrimRef interventionActionId)
            (SomeRelation ChangesAnchor)
            (AnchorRef situationAnchorId)
        , Edge
            (PrimRef measureKpiId)
            (SomeRelation MeasuresAnchor)
            (AnchorRef situationAnchorId)
        ]
    }

ethosId :: ContextId
ethosId = ContextId "ethos"

strategyId :: ContextId
strategyId = ContextId "strategy"

needId :: ContextId
needId = ContextId "need"

additionalNeedId :: ContextId
additionalNeedId = ContextId "additional-need"

interventionId :: ContextId
interventionId = ContextId "intervention"

measureId :: ContextId
measureId = ContextId "measure"

situationId :: ContextId
situationId = ContextId "situation"

invalidObjectiveId :: PrimitiveId
invalidObjectiveId = PrimitiveId "invalid-objective"

strategyDriverId :: PrimitiveId
strategyDriverId = PrimitiveId "strategy-driver"

strategyObjectiveId :: PrimitiveId
strategyObjectiveId = PrimitiveId "strategy-objective"

strategyKeyResultId :: PrimitiveId
strategyKeyResultId = PrimitiveId "strategy-key-result"

strategyActionId :: PrimitiveId
strategyActionId = PrimitiveId "strategy-action"

needDriverId :: PrimitiveId
needDriverId = PrimitiveId "need-driver"

needObjectiveId :: PrimitiveId
needObjectiveId = PrimitiveId "need-objective"

additionalNeedObjectiveId :: PrimitiveId
additionalNeedObjectiveId = PrimitiveId "additional-need-objective"

interventionActionId :: PrimitiveId
interventionActionId = PrimitiveId "intervention-action"

interventionKeyResultId :: PrimitiveId
interventionKeyResultId = PrimitiveId "intervention-key-result"

measureKpiId :: PrimitiveId
measureKpiId = PrimitiveId "measure-kpi"

measureDomainId :: StructuringId
measureDomainId = StructuringId "measure-domain"

situationAnchorId :: AnchorId
situationAnchorId = AnchorId "situation-anchor"
