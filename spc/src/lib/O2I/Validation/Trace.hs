{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Relational effect-trace derivation and validation.
--
-- Trace validation derives complete paths only from semantically valid O2I
-- graphs; it does not assess empirical observations.
module O2I.Validation.Trace
  ( EffectTrace
  , EffectTraceId
  , TraceableEffectModel
  , TraceabilityError(..)
  , validateTraceability
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , traceStrategy
  , traceStrategyKeyResult
  , traceNeed
  , traceIntervention
  , traceInterventionKeyResult
  , traceKPI
  , traceAnchor
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Validation (Validation(..))
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Semantics

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

-- | Stable identity derived from every constituent of one complete trace.
newtype EffectTraceId =
  EffectTraceId EffectTraceKey
  deriving (Eq, Ord, Show)

-- | Read-only projection of one complete relational effect path.
--
-- Strategy roles are derived exclusively from its validated formulation.
data EffectTrace = EffectTrace
  { effectTraceIdentifier :: EffectTraceId
  , effectTraceStrategy :: RawNodeId
  , effectTraceStrategyKeyResult :: RawNodeId
  , effectTraceIntervention :: RawNodeId
  , effectTraceNeed :: RawNodeId
  , effectTraceInterventionKeyResult :: RawNodeId
  , effectTraceKPI :: RawNodeId
  , effectTraceAnchor :: RawNodeId
  } deriving (Eq, Show)

-- | Opaque semantic model with at least one complete effect trace and full
-- trace coverage for every Need addressed by every Intervention.
data TraceableEffectModel = TraceableEffectModel
  { traceableSemanticallyValidModel :: SemanticallyValidModel
  , validatedTraces :: NonEmpty.NonEmpty EffectTrace
  , traceIndex :: Map EffectTraceId EffectTrace
  }

-- | Violations of relational effect traceability.
data TraceabilityError
  = NoIntervention
    -- ^ The model contains no Intervention from which a trace can be derived.
  | InterventionWithoutNeed RawNodeId
    -- ^ An Intervention addresses no Need.
  | MissingMacroEvidence RawNodeId RelationName RawNodeId
    -- ^ A context macrorelation lacks its required primitive evidence.
  | MissingEffectTrace RawNodeId RawNodeId
    -- ^ An Intervention/Need pair has no complete relational effect path.
  deriving (Eq, Show)

-- * Traceability validation
-- | Derive and validate relational effect traces from a semantic model.
--
-- This stage relies on established Need and Strategy invariants. It requires
-- primitive evidence for every macrorelation and a complete path for every
-- addressed Need. It does not assess observations or causal attribution.
validateTraceability ::
     SemanticallyValidModel
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
validateTraceability semantic =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty traces of
        Just nonEmptyTraces ->
          Success
            TraceableEffectModel
              { traceableSemanticallyValidModel = semantic
              , validatedTraces = nonEmptyTraces
              , traceIndex = indexedTraces
              }
        Nothing -> Failure (NonEmpty.singleton NoIntervention)
  where
    graph = modelGraph semantic
    interventions = contextNodesOf graph Intervention
    indexedTraces =
      Map.fromList
        [(traceIdentifier trace, trace) | trace <- traceCandidates semantic]
    traces = Map.elems indexedTraces
    addressed intervention =
      outgoingContextTargets graph intervention (nameOf addressesNeed)
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
    errors = macroEvidenceErrors semantic ++ interventionErrors

matchesInterventionNeed :: RawNodeId -> RawNodeId -> EffectTrace -> Bool
matchesInterventionNeed intervention need trace =
  effectTraceIntervention trace == intervention && effectTraceNeed trace == need

-- | Enumerate all distinct validated effect traces.
effectTraces :: TraceableEffectModel -> NonEmpty.NonEmpty EffectTrace
effectTraces = validatedTraces

-- | Resolve a trace identifier within its validated traceable model.
lookupEffectTrace :: TraceableEffectModel -> EffectTraceId -> Maybe EffectTrace
lookupEffectTrace model identifier = Map.lookup identifier (traceIndex model)

-- | Read the stable identity of an effect trace.
traceIdentifier :: EffectTrace -> EffectTraceId
traceIdentifier = effectTraceIdentifier

-- | Read the Strategy that governs an effect trace.
traceStrategy :: EffectTrace -> ContextRef 'Strategy
traceStrategy = ContextRef . effectTraceStrategy

-- | Read the strategic Key Result connected to an effect trace.
traceStrategyKeyResult ::
     EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'KeyResult)
traceStrategyKeyResult = NodeId . effectTraceStrategyKeyResult

-- | Read the Need context justified by an effect trace.
traceNeed :: EffectTrace -> ContextRef 'Need
traceNeed = ContextRef . effectTraceNeed

-- | Read the Intervention that realizes an effect trace.
traceIntervention :: EffectTrace -> ContextRef 'Intervention
traceIntervention = ContextRef . effectTraceIntervention

-- | Read the Intervention Key Result that operationalizes the traced Need.
traceInterventionKeyResult :: EffectTrace -> RawNodeId
traceInterventionKeyResult = effectTraceInterventionKeyResult

-- | Read the KPI used to observe the traced Situation anchor.
traceKPI :: EffectTrace -> RawNodeId
traceKPI = effectTraceKPI

-- | Read the Situation anchor changed and measured by the trace.
traceAnchor :: EffectTrace -> RawNodeId
traceAnchor = effectTraceAnchor

traceCandidates :: SemanticallyValidModel -> [EffectTrace]
traceCandidates semantic = do
  vision <- contextNodesOf graph Vision
  strategy <- contextNodesOf graph Strategy
  formulation <-
    case Map.lookup strategy (strategyFormulations semantic) of
      Just validated -> [strategyFormulationData validated]
      Nothing -> []
  need <- contextNodesOf graph Need
  intervention <- contextNodesOf graph Intervention
  measure <- contextNodesOf graph Measure
  situation <- contextNodesOf graph Situation
  require (has graph vision orientsStrategy strategy)
  require (has graph strategy qualifiesNeed need)
  require (has graph situation surfacesNeed need)
  require (has graph strategy directsIntervention intervention)
  require (has graph intervention addressesNeed need)
  require (has graph intervention changesSituation situation)
  require (has graph strategy framesMeasure measure)
  require (has graph intervention setsTargetForMeasure measure)
  require (has graph measure measuresSituation situation)
  visionObjective <- primitiveNodesIn graph vision Objective
  strategyObjective <- [rawFormulationIntent formulation]
  require
    (has
       graph
       visionObjective
       orientsVisionObjectiveToStrategyObjective
       strategyObjective)
  strategyDriver <- [rawFormulationDiagnosis formulation]
  require
    $ has
        graph
        strategyDriver
        groundsStrategyDriverToObjective
        strategyObjective
  strategyKeyResult <- NonEmpty.toList (rawFormulationKeyResults formulation)
  require
    (has
       graph
       strategyKeyResult
       substantiatesStrategyKeyResultObjective
       strategyObjective)
  strategyAction <- NonEmpty.toList (rawFormulationActions formulation)
  require
    (has
       graph
       strategyAction
       contributesStrategyActionToKeyResult
       strategyKeyResult)
  needDriver <- primitiveNodesIn graph need Driver
  needObjective <- primitiveNodesIn graph need Objective
  require (has graph needDriver groundsNeedDriverToObjective needObjective)
  require
    (has
       graph
       strategyKeyResult
       translatesStrategyKeyResultToNeedObjective
       needObjective)
  interventionAction <- primitiveNodesIn graph intervention Action
  require
    (has
       graph
       strategyAction
       guidesStrategyActionToInterventionAction
       interventionAction)
  interventionKeyResult <- primitiveNodesIn graph intervention KeyResult
  require
    (has
       graph
       interventionAction
       contributesInterventionActionToKeyResult
       interventionKeyResult)
  require
    (has
       graph
       interventionKeyResult
       substantiatesInterventionKeyResultNeedObjective
       needObjective)
  require
    (has
       graph
       interventionKeyResult
       contributesInterventionKeyResultToStrategyKeyResult
       strategyKeyResult)
  domain <- structuringNodesIn graph measure Domain
  require (has graph strategyDriver indicatesMeasureDomain domain)
  require (has graph strategyKeyResult determinesMeasureDomain domain)
  kpi <- primitiveNodesIn graph measure KPI
  require (has graph domain containsMeasureKPI kpi)
  require (has graph interventionKeyResult setsTargetForMeasureKPI kpi)
  anchor <- anchorNodesIn graph situation
  require
    (hasAnchor
       graph
       situation
       (nameOf (constitutedByAnchor SBusinessCapability))
       anchor)
  require
    (hasAnchor
       graph
       anchor
       (nameOf (anchorsNeedDriver SBusinessCapability))
       needDriver)
  require
    (hasAnchor
       graph
       interventionAction
       (nameOf (changesAnchor SBusinessCapability))
       anchor)
  require
    (hasAnchor graph kpi (nameOf (measuresAnchor SBusinessCapability)) anchor)
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
      , effectTraceStrategy = strategy
      , effectTraceStrategyKeyResult = strategyKeyResult
      , effectTraceIntervention = intervention
      , effectTraceNeed = need
      , effectTraceInterventionKeyResult = interventionKeyResult
      , effectTraceKPI = kpi
      , effectTraceAnchor = anchor
      }
  where
    graph = modelGraph semantic

require :: Bool -> [()]
require True = [()]
require False = []

has :: WellFormedGraph -> RawNodeId -> Relation from to -> RawNodeId -> Bool
has graph from relation to = hasEdge graph from (nameOf relation) to

hasAnchor :: WellFormedGraph -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasAnchor = hasEdge

nameOf :: Relation from to -> RelationName
nameOf = relationName . relationSpec

macroEvidenceErrors :: SemanticallyValidModel -> [TraceabilityError]
macroEvidenceErrors semantic =
  [ MissingMacroEvidence from relationName' to
  | SomeEdge edge <- graphEdges graph
  , let relation = edgeRelation edge
  , MacroRelation evidenceKind <- [relationSemantics (relationSpec relation)]
  , let relationName' = nameOf relation
  , let from = unNodeId (edgeFrom edge)
  , let to = unNodeId (edgeTo edge)
  , not (hasMacroEvidence semantic evidenceKind from to)
  ]
  where
    graph = modelGraph semantic

hasMacroEvidence ::
     SemanticallyValidModel
  -> MacroEvidenceKind
  -> RawNodeId
  -> RawNodeId
  -> Bool
hasMacroEvidence semantic evidenceKind from to =
  case evidenceKind of
    GuidesMissionEvidence ->
      anyRelation Principle guidesEthosPrincipleToMissionDriver Driver
    GroundsVisionEvidence ->
      anyRelation Driver groundsMissionDriverToVisionObjective Objective
    GuidesVisionEvidence ->
      anyRelation Principle guidesEthosPrincipleToVisionObjective Objective
    OrientsStrategyEvidence ->
      anyBetween
        (primitiveNodesIn graph from Objective)
        orientsVisionObjectiveToStrategyObjective
        (strategyIntents to)
    DirectsStrategyEvidence ->
      anyBetween
        (strategyPolicies from)
        guidesStrategyPrincipleToPrinciple
        (strategyPolicies to)
    ContributesToStrategyEvidence ->
      anyBetween
        (strategyKeyResults from)
        contributesStrategyKeyResultToKeyResult
        (strategyKeyResults to)
        || anyBetween
             (strategyActions from)
             contributesStrategyActionToAction
             (strategyActions to)
    QualifiesNeedEvidence ->
      anyBetween
        (strategyKeyResults from)
        translatesStrategyKeyResultToNeedObjective
        (primitiveNodesIn graph to Objective)
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
      anyBetween
        (strategyActions from)
        guidesStrategyActionToInterventionAction
        (primitiveNodesIn graph to Action)
    ChangesSituationEvidence ->
      anyPrimitiveToAnchor Action (nameOf (changesAnchor SBusinessCapability))
    SetsTargetForMeasureEvidence ->
      anyRelation KeyResult setsTargetForMeasureKPI KPI
    MeasuresSituationEvidence ->
      anyPrimitiveToAnchor KPI (nameOf (measuresAnchor SBusinessCapability))
    FramesMeasureEvidence -> anyFramesEvidence
  where
    graph = modelGraph semantic
    anyRelation fromPrimitive primitiveRelation toPrimitive =
      anyBetween
        (primitiveNodesIn graph from fromPrimitive)
        primitiveRelation
        (primitiveNodesIn graph to toPrimitive)
    anyBetween sources relation targets =
      or
        [ has graph source relation target
        | source <- sources
        , target <- targets
        ]
    strategyRole selector strategy =
      case Map.lookup strategy (strategyFormulations semantic) of
        Just formulation -> selector (strategyFormulationData formulation)
        Nothing -> []
    strategyIntents = strategyRole (pure . rawFormulationIntent)
    strategyPolicies = strategyRole (pure . rawFormulationGuidingPolicy)
    strategyActions = strategyRole (NonEmpty.toList . rawFormulationActions)
    strategyKeyResults =
      strategyRole (NonEmpty.toList . rawFormulationKeyResults)
    strategyDiagnoses = strategyRole (pure . rawFormulationDiagnosis)
    constituted = nameOf (constitutedByAnchor SBusinessCapability)
    anyAnchorToPrimitive anchorRelation toPrimitive =
      or
        [ hasAnchor graph from constituted anchor
          && hasAnchor graph anchor anchorRelation target
        | anchor <- anchorNodesIn graph from
        , target <- primitiveNodesIn graph to toPrimitive
        ]
    anyPrimitiveToAnchor fromPrimitive primitiveRelation =
      or
        [ hasAnchor graph to constituted anchor
          && hasAnchor graph source primitiveRelation anchor
        | source <- primitiveNodesIn graph from fromPrimitive
        , anchor <- anchorNodesIn graph to
        ]
    anyFramesEvidence =
      or
        [ has graph driver indicatesMeasureDomain domain
          && has graph keyResult determinesMeasureDomain domain
          && has graph domain containsMeasureKPI kpi
        | driver <- strategyDiagnoses from
        , keyResult <- strategyKeyResults from
        , domain <- structuringNodesIn graph to Domain
        , kpi <- primitiveNodesIn graph to KPI
        ]
