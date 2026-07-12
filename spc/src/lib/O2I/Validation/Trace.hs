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
  , traceNeed
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
    model = semanticModel semantic
    interventions = contextNodesOf model Intervention
    indexedTraces =
      Map.fromList
        [(traceIdentifier trace, trace) | trace <- traceCandidates semantic]
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

-- | Read the Need context justified by an effect trace.
traceNeed :: EffectTrace -> ContextRef 'Need
traceNeed = ContextRef . effectTraceNeed

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
  vision <- contextNodesOf model Vision
  strategy <- contextNodesOf model Strategy
  formulation <-
    case Map.lookup strategy (strategyFormulations semantic) of
      Just validated -> [strategyFormulationData validated]
      Nothing -> []
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
  strategyObjective <- [rawFormulationIntent formulation]
  require
    (has
       model
       visionObjective
       orientsVisionObjectiveToStrategyObjective
       strategyObjective)
  strategyDriver <- [rawFormulationDiagnosis formulation]
  require
    $ has
        model
        strategyDriver
        groundsStrategyDriverToObjective
        strategyObjective
  strategyKeyResult <- NonEmpty.toList (rawFormulationKeyResults formulation)
  require
    (has
       model
       strategyKeyResult
       substantiatesStrategyKeyResultObjective
       strategyObjective)
  strategyAction <- NonEmpty.toList (rawFormulationActions formulation)
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
  where
    model = semanticModel semantic

require :: Bool -> [()]
require True = [()]
require False = []

has :: WellFormedGraph -> RawNodeId -> Relation from to -> RawNodeId -> Bool
has model from relation to = hasEdge model from (nameOf relation) to

hasAnchor :: WellFormedGraph -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasAnchor = hasEdge

nameOf :: Relation from to -> RelationName
nameOf = relationName . relationSpec

macroEvidenceErrors :: SemanticallyValidModel -> [TraceabilityError]
macroEvidenceErrors semantic =
  [ MissingMacroEvidence from relationName' to
  | SomeEdge edge <- modelEdges model
  , let relation = edgeRelation edge
  , MacroRelation evidenceKind <- [relationSemantics (relationSpec relation)]
  , let relationName' = nameOf relation
  , let from = unNodeId (edgeFrom edge)
  , let to = unNodeId (edgeTo edge)
  , not (hasMacroEvidence semantic evidenceKind from to)
  ]
  where
    model = semanticModel semantic

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
        (primitiveNodesIn model from Objective)
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
        (primitiveNodesIn model to Objective)
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
        (primitiveNodesIn model to Action)
    ChangesSituationEvidence ->
      anyPrimitiveToAnchor Action (nameOf (changesAnchor SBusinessCapability))
    SetsTargetForMeasureEvidence ->
      anyRelation KeyResult setsTargetForMeasureKPI KPI
    MeasuresSituationEvidence ->
      anyPrimitiveToAnchor KPI (nameOf (measuresAnchor SBusinessCapability))
    FramesMeasureEvidence -> anyFramesEvidence
  where
    model = semanticModel semantic
    anyRelation fromPrimitive primitiveRelation toPrimitive =
      anyBetween
        (primitiveNodesIn model from fromPrimitive)
        primitiveRelation
        (primitiveNodesIn model to toPrimitive)
    anyBetween sources relation targets =
      or
        [ has model source relation target
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
        | driver <- strategyDiagnoses from
        , keyResult <- strategyKeyResults from
        , domain <- structuringNodesIn model to Domain
        , kpi <- primitiveNodesIn model to KPI
        ]
