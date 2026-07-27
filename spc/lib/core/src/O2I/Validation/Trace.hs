{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Relational effect-trace derivation and validation.
--
-- Trace validation derives complete paths only from semantically valid O2I
-- graphs; it does not assess empirical observations.
module O2I.Validation.Trace
  ( EffectTrace
  , EffectTraceId
  , SomeSituationAnchorRef
  , TraceableEffectModel
  , TraceabilityError(..)
  , MacroEvidenceWitness
  , macroEvidenceWitnesses
  , macroEvidenceWitnessesFor
  , witnessPremises
  , validateTraceability
  , effectTraces
  , lookupEffectTrace
  , traceIdentifier
  , effectTraceIdText
  , traceVision
  , traceVisionObjective
  , traceStrategy
  , traceStrategyDriver
  , traceStrategyObjective
  , traceStrategyKeyResult
  , traceStrategyAction
  , traceNeed
  , traceNeedDriver
  , traceNeedObjective
  , traceIntervention
  , traceInterventionAction
  , traceInterventionKeyResult
  , traceMeasure
  , traceMeasurePerformanceDimension
  , traceKPI
  , traceSituation
  , traceSituationAnchor
  , situationAnchorRefId
  , situationAnchorRefKind
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as TextBuilder
import qualified Data.Text.Lazy.Builder.Int as TextBuilder
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Macro (MacroClaim)
import O2I.Language.Relation
import O2I.Validation.Semantics
import O2I.Validation.Trace.Evidence hiding
  ( macroEvidenceWitnesses
  , macroEvidenceWitnessesFor
  )
import qualified O2I.Validation.Trace.Evidence as Evidence

-- | Interpret the canonical macro rule against one completely validated
-- semantic model.
macroEvidenceWitnesses ::
     SemanticallyValidModel -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  Evidence.macroEvidenceWitnesses (modelContextSemantics semantic)

-- | Select exact witnesses for one registered Context macrorelation claim.
macroEvidenceWitnessesFor ::
     SemanticallyValidModel
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesFor semantic =
  Evidence.macroEvidenceWitnessesFor (modelContextSemantics semantic)

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
  , keyMeasurePerformanceDimension :: RawNodeId
  , keyMeasureKPI :: RawNodeId
  , keySituation :: RawNodeId
  , keySituationAnchor :: RawNodeId
  } deriving (Eq, Ord, Show)

-- | Stable identity derived from every constituent of one complete trace.
newtype EffectTraceId =
  EffectTraceId EffectTraceKey
  deriving (Eq, Ord, Show)

-- | Existential reference to a typed constituent of a 'Situation'.
--
-- Public clients inspect the opaque reference through 'situationAnchorRefId'
-- and 'situationAnchorRefKind'. The existential packaging retains the typed
-- identifier and its anchor-kind witness internally.
data SomeSituationAnchorRef where
  SomeSituationAnchorRef
    :: NodeId ('AnchorKind anchor)
    -> SSituationAnchor anchor
    -> SomeSituationAnchorRef
    -- ^ Hide the anchor index while retaining its witness and typed ID.

instance Eq SomeSituationAnchorRef where
  left == right =
    situationAnchorRefId left == situationAnchorRefId right
      && situationAnchorRefKind left == situationAnchorRefKind right

instance Show SomeSituationAnchorRef where
  show reference =
    show (situationAnchorRefId reference, situationAnchorRefKind reference)

-- | Read-only projection of one complete relational effect path.
--
-- Strategy roles are derived exclusively from its validated formulation.
data EffectTrace = EffectTrace
  { effectTraceIdentifier :: EffectTraceId
  , effectTraceVision :: ContextRef 'Vision
  , effectTraceVisionObjective :: NodeId ('PrimitiveKind 'Vision 'Objective)
  , effectTraceStrategy :: ContextRef 'Strategy
  , effectTraceStrategyDriver :: NodeId ('PrimitiveKind 'Strategy 'Driver)
  , effectTraceStrategyObjective :: NodeId ('PrimitiveKind 'Strategy 'Objective)
  , effectTraceStrategyKeyResult :: NodeId ('PrimitiveKind 'Strategy 'KeyResult)
  , effectTraceStrategyAction :: NodeId ('PrimitiveKind 'Strategy 'Action)
  , effectTraceNeed :: ContextRef 'Need
  , effectTraceNeedDriver :: NodeId ('PrimitiveKind 'Need 'Driver)
  , effectTraceNeedObjective :: NodeId ('PrimitiveKind 'Need 'Objective)
  , effectTraceIntervention :: ContextRef 'Intervention
  , effectTraceInterventionAction :: NodeId
      ('PrimitiveKind 'Intervention 'Action)
  , effectTraceInterventionKeyResult :: NodeId
      ('PrimitiveKind 'Intervention 'KeyResult)
  , effectTraceMeasure :: ContextRef 'Measure
  , effectTraceMeasurePerformanceDimension :: NodeId
      ('StructuringKind 'Measure 'PerformanceDimension)
  , effectTraceKPI :: NodeId ('PrimitiveKind 'Measure 'KPI)
  , effectTraceSituation :: ContextRef 'Situation
  , effectTraceSituationAnchor :: SomeSituationAnchorRef
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
-- This stage relies on established Situation, Need, and Strategy invariants.
-- It requires primitive evidence for every macrorelation and a complete path
-- for every addressed Need. It does not assess observations or causal
-- attribution.
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
    evidence = buildMacroEvidenceContext (modelContextSemantics semantic)
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
    errors = macroEvidenceErrors evidence ++ interventionErrors

matchesInterventionNeed :: RawNodeId -> RawNodeId -> EffectTrace -> Bool
matchesInterventionNeed intervention need trace =
  effectTraceIntervention trace == mkContextRef intervention
    && effectTraceNeed trace == mkContextRef need

-- | Enumerate all distinct validated effect traces.
effectTraces :: TraceableEffectModel -> NonEmpty.NonEmpty EffectTrace
effectTraces = validatedTraces

-- | Resolve a trace identifier within its validated traceable model.
lookupEffectTrace :: TraceableEffectModel -> EffectTraceId -> Maybe EffectTrace
lookupEffectTrace model identifier = Map.lookup identifier (traceIndex model)

-- | Read the stable identity of an effect trace.
traceIdentifier :: EffectTrace -> EffectTraceId
traceIdentifier = effectTraceIdentifier

-- | Canonically encode every constituent of an opaque effect-trace identity.
--
-- The versioned length framing is injective for arbitrary node identifier text
-- and independent of derived 'Show' representations.
effectTraceIdText :: EffectTraceId -> Text
effectTraceIdText (EffectTraceId (EffectTraceKey vision visionObjective strategy strategyDriver strategyObjective strategyKeyResult strategyAction need needDriver needObjective intervention interventionAction interventionKeyResult measure measurePerformanceDimension measureKPI situation situationAnchor)) =
  canonicalSequence
    ("o2i-effect-trace-v1"
       : map
           rawNodeIdText
           [ vision
           , visionObjective
           , strategy
           , strategyDriver
           , strategyObjective
           , strategyKeyResult
           , strategyAction
           , need
           , needDriver
           , needObjective
           , intervention
           , interventionAction
           , interventionKeyResult
           , measure
           , measurePerformanceDimension
           , measureKPI
           , situation
           , situationAnchor
           ])

canonicalSequence :: [Text] -> Text
canonicalSequence values =
  decimalText (length values) <> ";" <> Text.concat (map canonicalText values)

canonicalText :: Text -> Text
canonicalText value = decimalText (Text.length value) <> ":" <> value

decimalText :: Integral number => number -> Text
decimalText = LazyText.toStrict . TextBuilder.toLazyText . TextBuilder.decimal

-- | Read the Vision that orients the traced Strategy.
traceVision :: EffectTrace -> ContextRef 'Vision
traceVision = effectTraceVision

-- | Read the Vision Objective that orients the strategic intent.
traceVisionObjective ::
     EffectTrace -> NodeId ('PrimitiveKind 'Vision 'Objective)
traceVisionObjective = effectTraceVisionObjective

-- | Read the Strategy that governs an effect trace.
traceStrategy :: EffectTrace -> ContextRef 'Strategy
traceStrategy = effectTraceStrategy

-- | Read the strategic Driver that grounds the strategic intent.
traceStrategyDriver :: EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Driver)
traceStrategyDriver = effectTraceStrategyDriver

-- | Read the strategic Objective that expresses the strategic intent.
traceStrategyObjective ::
     EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Objective)
traceStrategyObjective = effectTraceStrategyObjective

-- | Read the strategic Key Result connected to an effect trace.
traceStrategyKeyResult ::
     EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'KeyResult)
traceStrategyKeyResult = effectTraceStrategyKeyResult

-- | Read the strategic Action that guides operational execution.
traceStrategyAction :: EffectTrace -> NodeId ('PrimitiveKind 'Strategy 'Action)
traceStrategyAction = effectTraceStrategyAction

-- | Read the Need context justified by an effect trace.
traceNeed :: EffectTrace -> ContextRef 'Need
traceNeed = effectTraceNeed

-- | Read the situated Driver that grounds the Need Objective.
traceNeedDriver :: EffectTrace -> NodeId ('PrimitiveKind 'Need 'Driver)
traceNeedDriver = effectTraceNeedDriver

-- | Read the required qualitative change expressed by the Need.
traceNeedObjective :: EffectTrace -> NodeId ('PrimitiveKind 'Need 'Objective)
traceNeedObjective = effectTraceNeedObjective

-- | Read the Intervention that realizes an effect trace.
traceIntervention :: EffectTrace -> ContextRef 'Intervention
traceIntervention = effectTraceIntervention

-- | Read the Intervention Action that changes the Situation anchor.
traceInterventionAction ::
     EffectTrace -> NodeId ('PrimitiveKind 'Intervention 'Action)
traceInterventionAction = effectTraceInterventionAction

-- | Read the Intervention Key Result that operationalizes the traced Need.
traceInterventionKeyResult ::
     EffectTrace -> NodeId ('PrimitiveKind 'Intervention 'KeyResult)
traceInterventionKeyResult = effectTraceInterventionKeyResult

-- | Read the Measure context that frames the trace's observations.
traceMeasure :: EffectTrace -> ContextRef 'Measure
traceMeasure = effectTraceMeasure

-- | Read the Measure measurement dimension determined by the Strategy.
traceMeasurePerformanceDimension ::
     EffectTrace -> NodeId ('StructuringKind 'Measure 'PerformanceDimension)
traceMeasurePerformanceDimension = effectTraceMeasurePerformanceDimension

-- | Read the KPI used to observe the traced Situation anchor.
traceKPI :: EffectTrace -> NodeId ('PrimitiveKind 'Measure 'KPI)
traceKPI = effectTraceKPI

-- | Read the Situation changed and observed by the trace.
traceSituation :: EffectTrace -> ContextRef 'Situation
traceSituation = effectTraceSituation

-- | Read the Situation anchor changed and measured by the trace.
traceSituationAnchor :: EffectTrace -> SomeSituationAnchorRef
traceSituationAnchor = effectTraceSituationAnchor

-- | Erase an existential Situation-anchor reference for runtime comparison.
situationAnchorRefId :: SomeSituationAnchorRef -> RawNodeId
situationAnchorRefId (SomeSituationAnchorRef identifier _) = unNodeId identifier

-- | Reify the anchor form of an existential Situation-anchor reference.
situationAnchorRefKind :: SomeSituationAnchorRef -> SituationAnchor
situationAnchorRefKind (SomeSituationAnchorRef _ anchor) = anchorValue anchor

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
  performanceDimensionReference <-
    performanceDimensionNodesIn
      graph
      (mkContextRef measure)
      MeasureMeasurementDimension
  let performanceDimension = unNodeId performanceDimensionReference
  require
    (has
       graph
       strategyDriver
       indicatesMeasurePerformanceDimension
       performanceDimension)
  require
    (has
       graph
       strategyKeyResult
       determinesMeasurePerformanceDimension
       performanceDimension)
  kpi <- primitiveNodesIn graph measure KPI
  require
    (has
       graph
       performanceDimension
       (containsPerformanceDimension MeasureMeasurementDimension)
       kpi)
  require (has graph interventionKeyResult setsTargetForMeasureKPI kpi)
  anchorReference <- situationAnchorReferencesIn graph situation
  let anchor = situationAnchorRefId anchorReference
  require
    (hasAnchor
       graph
       anchor
       (anchorRelationFamilyName AnchorsNeedDriverFamily)
       needDriver)
  require
    (hasAnchor
       graph
       interventionAction
       (anchorRelationFamilyName ChangesAnchorFamily)
       anchor)
  require
    (hasAnchor graph kpi (anchorRelationFamilyName MeasuresAnchorFamily) anchor)
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
          , keyMeasurePerformanceDimension = performanceDimension
          , keyMeasureKPI = kpi
          , keySituation = situation
          , keySituationAnchor = anchor
          }
  pure
    EffectTrace
      { effectTraceIdentifier = EffectTraceId key
      , effectTraceVision = mkContextRef vision
      , effectTraceVisionObjective = mkNodeId visionObjective
      , effectTraceStrategy = mkContextRef strategy
      , effectTraceStrategyDriver = mkNodeId strategyDriver
      , effectTraceStrategyObjective = mkNodeId strategyObjective
      , effectTraceStrategyKeyResult = mkNodeId strategyKeyResult
      , effectTraceStrategyAction = mkNodeId strategyAction
      , effectTraceNeed = mkContextRef need
      , effectTraceNeedDriver = mkNodeId needDriver
      , effectTraceNeedObjective = mkNodeId needObjective
      , effectTraceIntervention = mkContextRef intervention
      , effectTraceInterventionAction = mkNodeId interventionAction
      , effectTraceInterventionKeyResult = mkNodeId interventionKeyResult
      , effectTraceMeasure = mkContextRef measure
      , effectTraceMeasurePerformanceDimension = performanceDimensionReference
      , effectTraceKPI = mkNodeId kpi
      , effectTraceSituation = mkContextRef situation
      , effectTraceSituationAnchor = anchorReference
      }
  where
    graph = modelGraph semantic

require :: Bool -> [()]
require True = [()]
require False = []

situationAnchorReferencesIn ::
     WellFormedGraph -> RawNodeId -> [SomeSituationAnchorRef]
situationAnchorReferencesIn graph situation =
  [ SomeSituationAnchorRef identifier anchor
  | rawIdentifier <- constitutingAnchorNodes graph situation
  , Just (SomeNode (AnchorNode identifier anchor)) <-
      [lookupNode graph rawIdentifier]
  ]

has :: WellFormedGraph -> RawNodeId -> Relation from to -> RawNodeId -> Bool
has graph from relation to = hasEdge graph from (nameOf relation) to

hasAnchor :: WellFormedGraph -> RawNodeId -> RelationName -> RawNodeId -> Bool
hasAnchor = hasEdge

nameOf :: Relation from to -> RelationName
nameOf = relationName . relationSpec

macroEvidenceErrors :: MacroEvidenceContext -> [TraceabilityError]
macroEvidenceErrors evidence =
  [ MissingMacroEvidence
    (rawEdgeFrom conclusion)
    (rawEdgeRelation conclusion)
    (rawEdgeTo conclusion)
  | (conclusion, claim) <- macroEvidenceClaims evidence
  , null (macroEvidenceWitnessesIn evidence claim)
  ]
