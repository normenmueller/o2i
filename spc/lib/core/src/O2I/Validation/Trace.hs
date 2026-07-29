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
import O2I.Language.Element
import O2I.Language.Macro (MacroClaim)
import O2I.Language.Relation
import O2I.Validation.MacroEvidence
import qualified O2I.Validation.MacroEvidence as Evidence
import O2I.Validation.Semantics
import O2I.Validation.Trace.Search

-- | Interpret the canonical macro rule against one completely validated
-- semantic model.
macroEvidenceWitnesses ::
     SemanticallyValidModel -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  Evidence.macroEvidenceWitnessesIn (modelPreparedMacroEvidence semantic)

-- | Select exact witnesses for one registered Context macrorelation claim.
macroEvidenceWitnessesFor ::
     SemanticallyValidModel
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesFor semantic =
  Evidence.macroEvidenceWitnessesForIn (modelPreparedMacroEvidence semantic)

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

-- * Traceability validation interface
-- | Derive and validate relational effect traces from a semantic model.
--
-- This stage relies on established Situation, Need, and Strategy invariants.
-- It requires primitive evidence for every macrorelation and a complete path
-- for every addressed Need. It does not assess observations or causal
-- attribution.
validateTraceability ::
     SemanticallyValidModel
  -> Validation (NonEmpty.NonEmpty TraceabilityError) TraceableEffectModel
-- * Traceability validation implementation
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
    evidence = modelPreparedMacroEvidence semantic
    searched =
      deriveTracePaths
        graph
        (Map.map
           (traceStrategyRoles . strategyFormulationData)
           (strategyFormulations semantic))
    interventions = searchInterventions searched
    indexedTraces =
      Map.fromList
        [ (traceIdentifier trace, trace)
        | path <- searchPaths searched
        , let trace = effectTraceFromPath path
        ]
    traces = Map.elems indexedTraces
    interventionErrors
      | null interventions = [NoIntervention]
      | otherwise = concatMap errorsForIntervention interventions
    errorsForIntervention intervention =
      case searchAddressedNeeds searched intervention of
        [] -> [InterventionWithoutNeed intervention]
        needs ->
          [ MissingEffectTrace intervention need
          | need <- needs
          , not (searchCovers searched intervention need)
          ]
    errors = macroEvidenceErrors evidence ++ interventionErrors

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

traceStrategyRoles :: RawStrategyFormulation -> TraceStrategyRoles
traceStrategyRoles formulation =
  TraceStrategyRoles
    { traceRoleDriver = rawFormulationDiagnosis formulation
    , traceRoleObjective = rawFormulationIntent formulation
    , traceRoleKeyResults =
        NonEmpty.toList (rawFormulationKeyResults formulation)
    , traceRoleActions = NonEmpty.toList (rawFormulationActions formulation)
    }

effectTraceFromPath :: TracePath -> EffectTrace
effectTraceFromPath path =
  EffectTrace
    { effectTraceIdentifier = EffectTraceId key
    , effectTraceVision = mkContextRef (pathVision path)
    , effectTraceVisionObjective = mkNodeId (pathVisionObjective path)
    , effectTraceStrategy = mkContextRef (pathStrategy path)
    , effectTraceStrategyDriver = mkNodeId (pathStrategyDriver path)
    , effectTraceStrategyObjective = mkNodeId (pathStrategyObjective path)
    , effectTraceStrategyKeyResult = mkNodeId (pathStrategyKeyResult path)
    , effectTraceStrategyAction = mkNodeId (pathStrategyAction path)
    , effectTraceNeed = mkContextRef (pathNeed path)
    , effectTraceNeedDriver = mkNodeId (pathNeedDriver path)
    , effectTraceNeedObjective = mkNodeId (pathNeedObjective path)
    , effectTraceIntervention = mkContextRef (pathIntervention path)
    , effectTraceInterventionAction = mkNodeId (pathInterventionAction path)
    , effectTraceInterventionKeyResult =
        mkNodeId (pathInterventionKeyResult path)
    , effectTraceMeasure = mkContextRef (pathMeasure path)
    , effectTraceMeasurePerformanceDimension =
        mkNodeId (pathMeasurePerformanceDimension path)
    , effectTraceKPI = mkNodeId (pathMeasureKPI path)
    , effectTraceSituation = mkContextRef (pathSituation path)
    , effectTraceSituationAnchor = anchorReference
    }
  where
    key =
      EffectTraceKey
        { keyVision = pathVision path
        , keyVisionObjective = pathVisionObjective path
        , keyStrategy = pathStrategy path
        , keyStrategyDriver = pathStrategyDriver path
        , keyStrategyObjective = pathStrategyObjective path
        , keyStrategyKeyResult = pathStrategyKeyResult path
        , keyStrategyAction = pathStrategyAction path
        , keyNeed = pathNeed path
        , keyNeedDriver = pathNeedDriver path
        , keyNeedObjective = pathNeedObjective path
        , keyIntervention = pathIntervention path
        , keyInterventionAction = pathInterventionAction path
        , keyInterventionKeyResult = pathInterventionKeyResult path
        , keyMeasure = pathMeasure path
        , keyMeasurePerformanceDimension = pathMeasurePerformanceDimension path
        , keyMeasureKPI = pathMeasureKPI path
        , keySituation = pathSituation path
        , keySituationAnchor = pathSituationAnchor path
        }
    anchorReference =
      case someSAnchor (pathSituationAnchorKind path) of
        SomeSAnchor anchor ->
          SomeSituationAnchorRef (mkNodeId (pathSituationAnchor path)) anchor

macroEvidenceErrors :: PreparedMacroEvidence -> [TraceabilityError]
macroEvidenceErrors evidence =
  [ MissingMacroEvidence
    (rawEdgeFrom conclusion)
    (rawEdgeRelation conclusion)
    (rawEdgeTo conclusion)
  | (conclusion, claim) <- macroEvidenceClaims evidence
  , not (macroEvidenceExistsIn evidence claim)
  ]
