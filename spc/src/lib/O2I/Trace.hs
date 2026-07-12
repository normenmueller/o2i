{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Relational effect traces and traceability validation.
module O2I.Trace
  ( EffectTrace
  , EffectTraceId
  , TraceableEffectModel
  , TraceabilityError(..)
  , validateTraceability
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , traceNeed
  , traceInterventionKeyResult
  , traceKPI
  , traceAnchor
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Validation (Validation(..))
import O2I.Model
import O2I.Relation
import O2I.Types

-- * Effect trace
data EffectTraceKey = EffectTraceKey
  { keyVision :: RawNodeId
  , keyVisionObjective :: RawNodeId
  , keyStrategy :: RawNodeId
  , keyStrategyDriver :: RawNodeId
  , keyStrategyObjective :: RawNodeId
  , keyStrategyKeyResult :: RawNodeId
  , keyStrategyAction :: RawNodeId
  , keyNeed :: RawNodeId
  , keyNeedDriver :: RawNodeId
  , keyNeedObjective :: RawNodeId
  , keyIntervention :: RawNodeId
  , keyInterventionAction :: RawNodeId
  , keyInterventionKeyResult :: RawNodeId
  , keyMeasure :: RawNodeId
  , keyMeasureDomain :: RawNodeId
  , keyMeasureKPI :: RawNodeId
  , keySituation :: RawNodeId
  , keySituationAnchor :: RawNodeId
  } deriving (Eq, Ord, Show)

newtype EffectTraceId =
  EffectTraceId EffectTraceKey
  deriving (Eq, Ord, Show)

data EffectTrace = EffectTrace
  { effectTraceIdentifier :: EffectTraceId
  , effectTraceIntervention :: RawNodeId
  , effectTraceNeed :: RawNodeId
  , effectTraceInterventionKeyResult :: RawNodeId
  , effectTraceKPI :: RawNodeId
  , effectTraceAnchor :: RawNodeId
  } deriving (Eq, Show)

data TraceableEffectModel = TraceableEffectModel
  { traceableWellFormedModel :: WellFormedModel
  , validatedTraces :: NonEmpty.NonEmpty EffectTrace
  , traceIndex :: Map EffectTraceId EffectTrace
  }

data TraceabilityError
  = NoIntervention
  | InterventionWithoutNeed RawNodeId
  | MissingMacroEvidence RawNodeId RelationName RawNodeId
  | MissingEffectTrace RawNodeId RawNodeId
  deriving (Eq, Show)

-- * Traceability validation
validateTraceability ::
     WellFormedModel
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
validateTraceability model =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty traces of
        Just nonEmptyTraces ->
          Success
            TraceableEffectModel
              { traceableWellFormedModel = model
              , validatedTraces = nonEmptyTraces
              , traceIndex = indexedTraces
              }
        Nothing -> Failure (NonEmpty.singleton NoIntervention)
  where
    interventions = contextNodesOf model Intervention
    indexedTraces =
      Map.fromList
        [(traceIdentifier trace, trace) | trace <- traceCandidates model]
    traces = Map.elems indexedTraces
    addressed intervention =
      outgoingContextTargets model intervention (nameOf addressesNeed)
    interventionErrors
      | null interventions = [NoIntervention]
      | otherwise = concatMap errorsForIntervention interventions
    errorsForIntervention intervention =
      case addressed intervention of
        [] -> [InterventionWithoutNeed intervention]
        needs ->
          [ MissingEffectTrace intervention need
          | need <- needs
          , not (any (matchesInterventionNeed intervention need) traces)
          ]
    errors = macroEvidenceErrors model ++ interventionErrors

matchesInterventionNeed :: RawNodeId -> RawNodeId -> EffectTrace -> Bool
matchesInterventionNeed intervention need trace =
  effectTraceIntervention trace == intervention && effectTraceNeed trace == need

effectTraces :: TraceableEffectModel -> NonEmpty.NonEmpty EffectTrace
effectTraces = validatedTraces

lookupEffectTrace :: TraceableEffectModel -> EffectTraceId -> Maybe EffectTrace
lookupEffectTrace model identifier = Map.lookup identifier (traceIndex model)

traceIdentifier :: EffectTrace -> EffectTraceId
traceIdentifier = effectTraceIdentifier

traceNeed :: EffectTrace -> ContextRef 'Need
traceNeed = ContextRef . effectTraceNeed

traceInterventionKeyResult :: EffectTrace -> RawNodeId
traceInterventionKeyResult = effectTraceInterventionKeyResult

traceKPI :: EffectTrace -> RawNodeId
traceKPI = effectTraceKPI

traceAnchor :: EffectTrace -> RawNodeId
traceAnchor = effectTraceAnchor

traceCandidates :: WellFormedModel -> [EffectTrace]
traceCandidates model = do
  vision <- contextNodesOf model Vision
  strategy <- contextNodesOf model Strategy
  need <- contextNodesOf model Need
  intervention <- contextNodesOf model Intervention
  measure <- contextNodesOf model Measure
  situation <- contextNodesOf model Situation
  require (has model vision orientsStrategy strategy)
  require (has model strategy qualifiesNeed need)
  require (has model situation surfacesNeed need)
  require (has model strategy directsIntervention intervention)
  require (has model intervention addressesNeed need)
  require (has model intervention changesSituation situation)
  require (has model strategy framesMeasure measure)
  require (has model intervention setsTargetForMeasure measure)
  require (has model measure measuresSituation situation)
  visionObjective <- primitiveNodesIn model vision Objective
  strategyObjective <- primitiveNodesIn model strategy Objective
  require
    (has
       model
       visionObjective
       orientsVisionObjectiveToStrategyObjective
       strategyObjective)
  strategyDriver <- primitiveNodesIn model strategy Driver
  require
    (has model strategyDriver groundsStrategyDriverToObjective strategyObjective)
  strategyKeyResult <- primitiveNodesIn model strategy KeyResult
  require
    (has
       model
       strategyKeyResult
       substantiatesStrategyKeyResultObjective
       strategyObjective)
  strategyAction <- primitiveNodesIn model strategy Action
  require
    (has
       model
       strategyAction
       contributesStrategyActionToKeyResult
       strategyKeyResult)
  needDriver <- primitiveNodesIn model need Driver
  needObjective <- primitiveNodesIn model need Objective
  require (has model needDriver groundsNeedDriverToObjective needObjective)
  require
    (has
       model
       strategyKeyResult
       translatesStrategyKeyResultToNeedObjective
       needObjective)
  interventionAction <- primitiveNodesIn model intervention Action
  require
    (has
       model
       strategyAction
       guidesStrategyActionToInterventionAction
       interventionAction)
  interventionKeyResult <- primitiveNodesIn model intervention KeyResult
  require
    (has
       model
       interventionAction
       contributesInterventionActionToKeyResult
       interventionKeyResult)
  require
    (has
       model
       interventionKeyResult
       substantiatesInterventionKeyResultNeedObjective
       needObjective)
  require
    (has
       model
       interventionKeyResult
       contributesInterventionKeyResultToStrategyKeyResult
       strategyKeyResult)
  domain <- structuringNodesIn model measure Domain
  require (has model strategyDriver indicatesMeasureDomain domain)
  require (has model strategyKeyResult determinesMeasureDomain domain)
  kpi <- primitiveNodesIn model measure KPI
  require (has model domain containsMeasureKPI kpi)
  require (has model interventionKeyResult setsTargetForMeasureKPI kpi)
  anchor <- anchorNodesIn model situation
  require
    (hasAnchor
       model
       situation
       (nameOf (constitutedByAnchor SBusinessCapability))
       anchor)
  require
    (hasAnchor
       model
       anchor
       (nameOf (anchorsNeedDriver SBusinessCapability))
       needDriver)
  require
    (hasAnchor
       model
       interventionAction
       (nameOf (changesAnchor SBusinessCapability))
       anchor)
  require
    (hasAnchor model kpi (nameOf (measuresAnchor SBusinessCapability)) anchor)
  let key =
        EffectTraceKey
          { keyVision = vision
          , keyVisionObjective = visionObjective
          , keyStrategy = strategy
          , keyStrategyDriver = strategyDriver
          , keyStrategyObjective = strategyObjective
          , keyStrategyKeyResult = strategyKeyResult
          , keyStrategyAction = strategyAction
          , keyNeed = need
          , keyNeedDriver = needDriver
          , keyNeedObjective = needObjective
          , keyIntervention = intervention
          , keyInterventionAction = interventionAction
          , keyInterventionKeyResult = interventionKeyResult
          , keyMeasure = measure
          , keyMeasureDomain = domain
          , keyMeasureKPI = kpi
          , keySituation = situation
          , keySituationAnchor = anchor
          }
  pure
    EffectTrace
      { effectTraceIdentifier = EffectTraceId key
      , effectTraceIntervention = intervention
      , effectTraceNeed = need
      , effectTraceInterventionKeyResult = interventionKeyResult
      , effectTraceKPI = kpi
      , effectTraceAnchor = anchor
      }

require :: Bool -> [()]
require True = [()]
require False = []

has :: WellFormedModel -> RawNodeId -> Relation from to -> RawNodeId -> Bool
has model from relation to = hasEdge model from (nameOf relation) to

hasAnchor :: WellFormedModel -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasAnchor = hasEdge

nameOf :: Relation from to -> RelationName
nameOf = relationName . relationSpec

macroEvidenceErrors :: WellFormedModel -> [TraceabilityError]
macroEvidenceErrors model =
  [ MissingMacroEvidence from relationName' to
  | SomeEdge edge <- modelEdges model
  , let relation = edgeRelation edge
  , MacroRelation evidenceKind <- [relationSemantics (relationSpec relation)]
  , let relationName' = nameOf relation
  , let from = unNodeId (edgeFrom edge)
  , let to = unNodeId (edgeTo edge)
  , not (hasMacroEvidence model evidenceKind from to)
  ]

hasMacroEvidence ::
     WellFormedModel -> MacroEvidenceKind -> RawNodeId -> RawNodeId -> Bool
hasMacroEvidence model evidenceKind from to =
  case evidenceKind of
    GuidesMissionEvidence ->
      anyRelation Principle guidesEthosPrincipleToMissionDriver Driver
    GroundsVisionEvidence ->
      anyRelation Driver groundsMissionDriverToVisionObjective Objective
    GuidesVisionEvidence ->
      anyRelation Principle guidesEthosPrincipleToVisionObjective Objective
    OrientsStrategyEvidence ->
      anyRelation Objective orientsVisionObjectiveToStrategyObjective Objective
    DirectsStrategyEvidence ->
      anyRelation Principle guidesStrategyPrincipleToPrinciple Principle
    ContributesToStrategyEvidence ->
      anyRelation KeyResult contributesStrategyKeyResultToKeyResult KeyResult
        || anyRelation Action contributesStrategyActionToAction Action
    QualifiesNeedEvidence ->
      anyRelation KeyResult translatesStrategyKeyResultToNeedObjective Objective
    SurfacesNeedEvidence ->
      anyAnchorToPrimitive
        (nameOf (anchorsNeedDriver SBusinessCapability))
        Driver
    AddressesNeedEvidence ->
      anyRelation
        KeyResult
        substantiatesInterventionKeyResultNeedObjective
        Objective
    DirectsInterventionEvidence ->
      anyRelation Action guidesStrategyActionToInterventionAction Action
    ChangesSituationEvidence ->
      anyPrimitiveToAnchor Action (nameOf (changesAnchor SBusinessCapability))
    SetsTargetForMeasureEvidence ->
      anyRelation KeyResult setsTargetForMeasureKPI KPI
    MeasuresSituationEvidence ->
      anyPrimitiveToAnchor KPI (nameOf (measuresAnchor SBusinessCapability))
    FramesMeasureEvidence -> anyFramesEvidence
  where
    anyRelation fromPrimitive primitiveRelation toPrimitive =
      or
        [ has model source primitiveRelation target
        | source <- primitiveNodesIn model from fromPrimitive
        , target <- primitiveNodesIn model to toPrimitive
        ]
    constituted = nameOf (constitutedByAnchor SBusinessCapability)
    anyAnchorToPrimitive anchorRelation toPrimitive =
      or
        [ hasAnchor model from constituted anchor
          && hasAnchor model anchor anchorRelation target
        | anchor <- anchorNodesIn model from
        , target <- primitiveNodesIn model to toPrimitive
        ]
    anyPrimitiveToAnchor fromPrimitive primitiveRelation =
      or
        [ hasAnchor model to constituted anchor
          && hasAnchor model source primitiveRelation anchor
        | source <- primitiveNodesIn model from fromPrimitive
        , anchor <- anchorNodesIn model to
        ]
    anyFramesEvidence =
      or
        [ has model driver indicatesMeasureDomain domain
          && has model keyResult determinesMeasureDomain domain
          && has model domain containsMeasureKPI kpi
        | driver <- primitiveNodesIn model from Driver
        , keyResult <- primitiveNodesIn model from KeyResult
        , domain <- structuringNodesIn model to Domain
        , kpi <- primitiveNodesIn model to KPI
        ]
