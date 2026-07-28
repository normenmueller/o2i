{-# LANGUAGE DataKinds #-}

-- | Ex-ante readiness validation for empirical effect evidence.
--
-- Readiness fixes one stable definition for every traced KPI, one complete
-- evidence plan for every validated effect trace, and one canonical planned
-- start for every traced Intervention. It does not assess execution timing or
-- follow-up observations.
module O2I.Validation.Readiness
  ( Unit(..)
  , Level(..)
  , Delta(..)
  , ValueDomain(..)
  , RelativeChange(..)
  , RawKPIDefinition(..)
  , KPIDefinition
  , kpiDefinitionKPI
  , kpiDefinitionUnit
  , kpiDefinitionDomain
  , kpiDefinitionMeasurementMethod
  , kpiDefinitionInterpretation
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , PlannedInterventionStart(..)
  , EvidencePlan(..)
  , EvidenceReadyModel
  , EvidenceReadinessError(..)
  , validateEvidenceReadinessAt
  , kpiDefinitions
  , lookupKPIDefinition
  , evidencePlans
  , readinessCheckedAt
  , plannedInterventionStarts
  , readyEffectTraces
  , readyInterventions
  , readyTracesForIntervention
  , readyTraceableModel
  , lookupEvidencePlan
  , levelInDomain
  ) where

import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Data.Validation (Validation(..))
import O2I.Language.Element
import O2I.Validation.Trace

-- * Evidence design
-- | Stable unit declared once for a KPI definition.
data Unit
  = PercentagePoints -- ^ Percentage levels and percentage-point deltas.
  | NamedUnit Text -- ^ Extensible non-percentage unit with a nonblank name.
  deriving (Eq, Ord, Show)

-- | Exact KPI level, distinct from a change between levels.
data Level = Level
  { levelValue :: Rational -- ^ Numeric position within the declared domain.
  } deriving (Eq, Ord, Show)

-- | Exact absolute change, distinct from a KPI level.
data Delta = Delta
  { deltaValue :: Rational -- ^ Absolute displacement between KPI levels.
  } deriving (Eq, Ord, Show)

-- | Inclusive domain of admissible KPI levels.
data ValueDomain
  = UnboundedDomain -- ^ Every rational level is admissible.
  | LowerBoundedDomain Level -- ^ Levels at or above the bound are admissible.
  | UpperBoundedDomain Level -- ^ Levels at or below the bound are admissible.
  | BoundedDomain Level Level -- ^ Inclusive lower and upper level bounds.
  deriving (Eq, Ord, Show)

-- | Exact unitless ratio for a relative change criterion.
--
-- For example, @RelativeChange (1 / 10)@ denotes a ten-percent relative
-- change. Validation requires a strictly positive ratio and a nonzero
-- baseline.
newtype RelativeChange = RelativeChange
  { relativeChangeRatio :: Rational -- ^ Ratio relative to baseline magnitude.
  } deriving (Eq, Show)

-- | Unchecked definition submitted for a raw KPI identifier.
data RawKPIDefinition = RawKPIDefinition
  { rawDefinitionKPI :: RawNodeId -- ^ KPI identifier to define.
  , rawDefinitionUnit :: Unit -- ^ Stable unit for levels and deltas.
  , rawDefinitionDomain :: ValueDomain -- ^ Admissible KPI levels.
  , rawDefinitionMeasurementMethod :: Text
    -- ^ Stable method by which observations are produced.
  , rawDefinitionInterpretation :: Text
    -- ^ Stable subject-matter reading of observed levels and changes.
  } deriving (Eq, Show)

-- | Validated stable definition of one typed Measure KPI.
--
-- Construction is restricted to evidence-readiness validation. Exactly one
-- definition exists for every distinct KPI used by the validated traces.
data KPIDefinition =
  KPIDefinition
    (NodeId ('PrimitiveKind 'Measure 'KPI))
    Unit
    ValueDomain
    Text
    Text
  deriving (Eq, Show)

-- | Project the structurally validated KPI governed by this definition.
kpiDefinitionKPI :: KPIDefinition -> NodeId ('PrimitiveKind 'Measure 'KPI)
kpiDefinitionKPI (KPIDefinition kpi _ _ _ _) = kpi

-- | Project the stable unit for all levels and deltas.
kpiDefinitionUnit :: KPIDefinition -> Unit
kpiDefinitionUnit (KPIDefinition _ unit _ _ _) = unit

-- | Project the validated domain of admissible KPI levels.
kpiDefinitionDomain :: KPIDefinition -> ValueDomain
kpiDefinitionDomain (KPIDefinition _ _ domain _ _) = domain

-- | Project the validated nonblank measurement method.
kpiDefinitionMeasurementMethod :: KPIDefinition -> Text
kpiDefinitionMeasurementMethod (KPIDefinition _ _ _ method _) = method

-- | Project the validated nonblank subject-matter interpretation.
kpiDefinitionInterpretation :: KPIDefinition -> Text
kpiDefinitionInterpretation (KPIDefinition _ _ _ _ interpretation) =
  interpretation

type KPIDefinitionRegistry
  = Map (NodeId ('PrimitiveKind 'Measure 'KPI)) KPIDefinition

-- | Human-auditable provenance of a plan or observation.
newtype EvidenceSource = EvidenceSource
  { evidenceSourceName :: Text -- ^ Nonblank provenance description.
  } deriving (Eq, Ord, Show)

-- | One timestamped KPI level at a Situation anchor.
--
-- The raw KPI identifier selects the validated definition that supplies the
-- stable unit and admissible value domain.
data Observation = Observation
  { observationKPI :: RawNodeId -- ^ Observed KPI; must match the trace.
  , observationAnchor :: RawNodeId -- ^ Anchor; must match the trace.
  , observedAt :: UTCTime -- ^ Observation timestamp.
  , observedLevel :: Level -- ^ Observed level in the KPI definition's unit.
  , observationSource :: EvidenceSource -- ^ Auditable provenance.
  } deriving (Eq, Show)

-- | Required direction and minimum magnitude of observed change.
--
-- Absolute criteria compare levels using the KPI definition's unit. Relative
-- criteria compare the directional delta with the absolute baseline level.
data EffectCriterion
  = AbsoluteIncreaseByAtLeast Delta
    -- ^ Require at least this positive absolute increase.
  | AbsoluteDecreaseByAtLeast Delta
    -- ^ Require at least this positive absolute decrease.
  | RelativeIncreaseByAtLeast RelativeChange
    -- ^ Require at least this positive relative increase.
  | RelativeDecreaseByAtLeast RelativeChange
    -- ^ Require at least this positive relative decrease.
  deriving (Eq, Show)

-- | Required absolute target range at follow-up.
data TargetCriterion
  = AtLeast Level -- ^ Require a level at or above the threshold.
  | AtMost Level -- ^ Require a level at or below the threshold.
  | Within Level Level -- ^ Require an inclusive lower/upper level range.
  deriving (Eq, Show)

-- | Planned temporal boundary shared by every trace of one Intervention.
data PlannedInterventionStart = PlannedInterventionStart
  { plannedIntervention :: RawNodeId
    -- ^ Raw Intervention identifier submitted for validation.
  , plannedStartAt :: UTCTime -- ^ Planned start fixed before execution.
  } deriving (Eq, Show)

-- | Ex-ante evidence design fixed for one effect trace.
--
-- The trace identifies the typed KPI and therefore its validated definition.
data EvidencePlan = EvidencePlan
  { plannedTrace :: EffectTraceId -- ^ Trace governed by this plan.
  , establishedAt :: UTCTime -- ^ Time at which the plan was fixed.
  , targetDueAt :: UTCTime
    -- ^ Absolute due time, fixed ex ante and later applied to observations.
  , planSource :: EvidenceSource -- ^ Provenance of the evidence design.
  , baseline :: Observation -- ^ Observation fixed before intervention.
  , effectCriterion :: EffectCriterion -- ^ Required observed change.
  , targetCriterion :: TargetCriterion -- ^ Required absolute target.
  } deriving (Eq, Show)

-- * Evidence-ready model
-- | Opaque traceable model with canonical planned timing and one valid ex-ante
-- plan per effect trace.
--
-- Success establishes complete timing and plan coverage, trace alignment,
-- @establishedAt <= checkedAt < plannedStartAt@, one stable definition per KPI,
-- domain-valid levels and criteria, and auditable provenance.
data EvidenceReadyModel = EvidenceReadyModel
  { validatedTraceableModel :: TraceableEffectModel
  , validatedReadinessCheckedAt :: UTCTime
  , validatedKPIDefinitions :: Map
      (NodeId ('PrimitiveKind 'Measure 'KPI))
      KPIDefinition
  , validatedEvidencePlans :: NonEmpty.NonEmpty EvidencePlan
  , evidencePlanIndex :: Map EffectTraceId EvidencePlan
  , validatedPlannedStarts :: Map
      (ContextRef 'Intervention)
      PlannedInterventionStart
  }

-- | Violations detected while validating ex-ante evidence readiness.
data EvidenceReadinessError
  = UnknownKPIDefinition RawNodeId
    -- ^ A definition refers to no KPI in the validated traces.
  | DuplicateKPIDefinition RawNodeId Int
    -- ^ The same complete definition was submitted more than once.
  | ConflictingKPIDefinition RawNodeId Int
    -- ^ Incompatible definitions were submitted for the same KPI.
  | MissingKPIDefinition (NodeId ('PrimitiveKind 'Measure 'KPI))
    -- ^ A KPI used by a validated trace has no submitted definition.
  | InvalidKPIValueDomain RawNodeId ValueDomain
    -- ^ A bounded domain has an upper bound below its lower bound.
  | EmptyKPIUnit RawNodeId
    -- ^ A named KPI unit is blank.
  | EmptyKPIMeasurementMethod RawNodeId
    -- ^ A KPI definition has no measurement method.
  | EmptyKPIInterpretation RawNodeId
    -- ^ A KPI definition has no subject-matter interpretation.
  | UnknownPlannedInterventionStart RawNodeId
    -- ^ A timing record refers to no Intervention in a validated trace.
  | DuplicatePlannedInterventionStart RawNodeId Int
    -- ^ More than one planned start was supplied for one Intervention.
  | MissingPlannedInterventionStart (ContextRef 'Intervention)
    -- ^ A traced Intervention has no canonical planned start.
  | ReadinessCheckedAtOrAfterPlannedStart (ContextRef 'Intervention)
    -- ^ Readiness was not established before the planned start.
  | UnknownEvidencePlanTrace EffectTraceId
    -- ^ A plan refers to no trace in the supplied traceable model.
  | DuplicateEvidencePlan EffectTraceId Int
    -- ^ More than one plan targets the same effect trace.
  | MissingEvidencePlan EffectTraceId
    -- ^ A validated effect trace has no evidence plan.
  | PlanEstablishedAfterCheck EffectTraceId
    -- ^ The plan was established after the readiness check.
  | BaselineObservedAfterCheck EffectTraceId
    -- ^ The baseline was observed after the readiness check.
  | InvalidTargetDueDate EffectTraceId
    -- ^ The absolute target due time is not after the planned start.
  | BaselineKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline KPI differs from the traced KPI.
  | BaselineAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline anchor differs from the traced anchor.
  | InvalidEffectCriterion EffectTraceId
    -- ^ An absolute magnitude or relative ratio is not strictly positive.
  | RelativeEffectCriterionWithZeroBaseline EffectTraceId
    -- ^ Relative change is undefined for the plan's zero baseline.
  | InvalidTargetCriterion EffectTraceId
    -- ^ A target range has an inverted lower and upper level.
  | BaselineLevelOutsideDomain EffectTraceId Level ValueDomain
    -- ^ The baseline level lies outside the KPI's declared domain.
  | EffectCriterionOutsideDomain EffectTraceId Level ValueDomain
    -- ^ The criterion's implied endpoint lies outside the KPI domain.
  | TargetCriterionOutsideDomain EffectTraceId Level ValueDomain
    -- ^ A target level lies outside the KPI's declared domain.
  | EmptyPlanSource EffectTraceId
    -- ^ The evidence plan has blank provenance.
  | EmptyBaselineSource EffectTraceId
    -- ^ The baseline observation has blank provenance.
  deriving (Eq, Show)

-- * Readiness validation interface
-- | Validate KPI definitions, canonical timing, and one plan per effect trace.
--
-- Plan establishment and baseline observation may equal the explicit check
-- time. The check must strictly precede each canonical planned start. A target
-- due time is an absolute deadline and must follow that planned start. Exactly
-- one valid definition is required for every distinct KPI used by the traces.
-- Unchecked plans are a list so that explicit emptiness is reported together
-- with every independent definition and timing defect.
validateEvidenceReadinessAt ::
     UTCTime
  -> TraceableEffectModel
  -> [RawKPIDefinition]
  -> [PlannedInterventionStart]
  -> [EvidencePlan]
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
-- * Readiness validation implementation
validateEvidenceReadinessAt checkedAt model rawDefinitions starts plans =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      case NonEmpty.nonEmpty plans of
        Just validatedPlans ->
          Success
            EvidenceReadyModel
              { validatedTraceableModel = model
              , validatedReadinessCheckedAt = checkedAt
              , validatedKPIDefinitions = definitionRegistry
              , validatedEvidencePlans = validatedPlans
              , evidencePlanIndex = Map.map NonEmpty.head planIndex
              , validatedPlannedStarts = validatedStarts
              }
        Nothing -> Failure emptyPlanCoverage
  where
    planIndex = plansByTrace plans
    startIndex = startsByIntervention starts
    traces = NonEmpty.toList (effectTraces model)
    tracedKPIs = sort (nub (map traceKPI traces))
    definitionIndex = definitionsByKPI rawDefinitions
    definitionRegistry = buildKPIDefinitionRegistry tracedKPIs definitionIndex
    interventions = tracedInterventions traces
    validatedStarts =
      Map.fromList
        [ (intervention, record)
        | intervention <- interventions
        , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
        ]
    errors =
      kpiDefinitionErrors tracedKPIs definitionIndex rawDefinitions
        ++ plannedStartErrors checkedAt interventions startIndex
        ++ duplicatePlanErrors planIndex
        ++ concatMap
             (planErrors checkedAt model definitionRegistry startIndex)
             plans
        ++ missingPlanErrors
    missingPlanErrors =
      [ MissingEvidencePlan identifier
      | trace <- traces
      , let identifier = traceIdentifier trace
      , Map.notMember identifier planIndex
      ]
    emptyPlanCoverage =
      fmap (MissingEvidencePlan . traceIdentifier) (effectTraces model)

definitionsByKPI ::
     [RawKPIDefinition] -> Map RawNodeId (NonEmpty.NonEmpty RawKPIDefinition)
definitionsByKPI =
  Map.fromListWith (<>)
    . map (\definition -> (rawDefinitionKPI definition, pure definition))

kpiDefinitionErrors ::
     [NodeId ('PrimitiveKind 'Measure 'KPI)]
  -> Map RawNodeId (NonEmpty.NonEmpty RawKPIDefinition)
  -> [RawKPIDefinition]
  -> [EvidenceReadinessError]
kpiDefinitionErrors tracedKPIs definitionIndex rawDefinitions =
  unknownErrors ++ multiplicityErrors ++ missingErrors ++ contentErrors
  where
    tracedIdentifiers = map unNodeId tracedKPIs
    unknownErrors =
      [ UnknownKPIDefinition identifier
      | identifier <- Map.keys definitionIndex
      , identifier `notElem` tracedIdentifiers
      ]
    multiplicityErrors =
      concatMap errorsForMultiplicity (Map.toList definitionIndex)
    errorsForMultiplicity (identifier, definitions)
      | NonEmpty.length definitions <= 1 = []
      | all (== NonEmpty.head definitions) (NonEmpty.tail definitions) =
        [DuplicateKPIDefinition identifier (NonEmpty.length definitions)]
      | otherwise =
        [ConflictingKPIDefinition identifier (NonEmpty.length definitions)]
    missingErrors =
      [ MissingKPIDefinition kpi
      | kpi <- tracedKPIs
      , Map.notMember (unNodeId kpi) definitionIndex
      ]
    contentErrors = concatMap rawKPIDefinitionErrors rawDefinitions

rawKPIDefinitionErrors :: RawKPIDefinition -> [EvidenceReadinessError]
rawKPIDefinitionErrors definition =
  [InvalidKPIValueDomain identifier domain | not (validValueDomain domain)]
    ++ [EmptyKPIUnit identifier | blankUnit (rawDefinitionUnit definition)]
    ++ [ EmptyKPIMeasurementMethod identifier
       | blankText (rawDefinitionMeasurementMethod definition)
       ]
    ++ [ EmptyKPIInterpretation identifier
       | blankText (rawDefinitionInterpretation definition)
       ]
  where
    identifier = rawDefinitionKPI definition
    domain = rawDefinitionDomain definition

buildKPIDefinitionRegistry ::
     [NodeId ('PrimitiveKind 'Measure 'KPI)]
  -> Map RawNodeId (NonEmpty.NonEmpty RawKPIDefinition)
  -> KPIDefinitionRegistry
buildKPIDefinitionRegistry tracedKPIs definitionIndex =
  Map.fromList
    [ (kpi, validateDefinition kpi rawDefinition)
    | kpi <- tracedKPIs
    , Just rawDefinition <- [uniqueRecord (unNodeId kpi) definitionIndex]
    , null (rawKPIDefinitionErrors rawDefinition)
    ]

validateDefinition ::
     NodeId ('PrimitiveKind 'Measure 'KPI) -> RawKPIDefinition -> KPIDefinition
validateDefinition kpi rawDefinition =
  KPIDefinition
    kpi
    (rawDefinitionUnit rawDefinition)
    (rawDefinitionDomain rawDefinition)
    (Text.strip (rawDefinitionMeasurementMethod rawDefinition))
    (Text.strip (rawDefinitionInterpretation rawDefinition))

tracedInterventions :: [EffectTrace] -> [ContextRef 'Intervention]
tracedInterventions = sort . nub . map traceIntervention

startsByIntervention ::
     [PlannedInterventionStart]
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
startsByIntervention =
  Map.fromListWith (<>)
    . map (\start -> (plannedIntervention start, pure start))

plannedStartErrors ::
     UTCTime
  -> [ContextRef 'Intervention]
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
  -> [EvidenceReadinessError]
plannedStartErrors checkedAt interventions startIndex =
  [ UnknownPlannedInterventionStart intervention
  | intervention <- Map.keys startIndex
  , intervention `notElem` map contextRefId interventions
  ]
    ++ [ DuplicatePlannedInterventionStart
         intervention
         (NonEmpty.length records)
       | (intervention, records) <- Map.toList startIndex
       , NonEmpty.length records > 1
       ]
    ++ [ MissingPlannedInterventionStart intervention
       | intervention <- interventions
       , Map.notMember (contextRefId intervention) startIndex
       ]
    ++ [ ReadinessCheckedAtOrAfterPlannedStart intervention
       | intervention <- interventions
       , Just record <- [uniqueRecord (contextRefId intervention) startIndex]
       , checkedAt >= plannedStartAt record
       ]

uniqueRecord ::
     Ord key => key -> Map key (NonEmpty.NonEmpty value) -> Maybe value
uniqueRecord key index = do
  records <- Map.lookup key index
  case NonEmpty.toList records of
    [record] -> Just record
    _ -> Nothing

plansByTrace ::
     [EvidencePlan] -> Map EffectTraceId (NonEmpty.NonEmpty EvidencePlan)
plansByTrace =
  Map.fromListWith (<>) . map (\plan -> (plannedTrace plan, pure plan))

duplicatePlanErrors ::
     Map EffectTraceId (NonEmpty.NonEmpty EvidencePlan)
  -> [EvidenceReadinessError]
duplicatePlanErrors planIndex =
  [ DuplicateEvidencePlan identifier (NonEmpty.length plans)
  | (identifier, plans) <- Map.toList planIndex
  , NonEmpty.length plans > 1
  ]

planErrors ::
     UTCTime
  -> TraceableEffectModel
  -> KPIDefinitionRegistry
  -> Map RawNodeId (NonEmpty.NonEmpty PlannedInterventionStart)
  -> EvidencePlan
  -> [EvidenceReadinessError]
planErrors checkedAt model definitionRegistry startIndex plan =
  case lookupEffectTrace model (plannedTrace plan) of
    Nothing -> [UnknownEvidencePlanTrace (plannedTrace plan)]
    Just trace ->
      timeErrors trace
        ++ bindingErrors trace
        ++ criterionErrors trace
        ++ definitionErrors trace
        ++ provenanceErrors trace
  where
    baselineObservation = baseline plan
    timeErrors trace =
      [ PlanEstablishedAfterCheck (traceIdentifier trace)
      | establishedAt plan > checkedAt
      ]
        ++ [ BaselineObservedAfterCheck (traceIdentifier trace)
           | observedAt baselineObservation > checkedAt
           ]
        ++ [ InvalidTargetDueDate (traceIdentifier trace)
           | Just start <-
               [ uniqueRecord
                   (contextRefId (traceIntervention trace))
                   startIndex
               ]
           , targetDueAt plan <= plannedStartAt start
           ]
    bindingErrors trace =
      [ BaselineKPIMismatch
        (traceIdentifier trace)
        (unNodeId (traceKPI trace))
        (observationKPI baselineObservation)
      | observationKPI baselineObservation /= unNodeId (traceKPI trace)
      ]
        ++ [ BaselineAnchorMismatch
             (traceIdentifier trace)
             (situationAnchorRefId (traceSituationAnchor trace))
             (observationAnchor baselineObservation)
           | observationAnchor baselineObservation
               /= situationAnchorRefId (traceSituationAnchor trace)
           ]
    criterionErrors trace =
      [ InvalidEffectCriterion (traceIdentifier trace)
      | not (validEffectCriterion (effectCriterion plan))
      ]
        ++ [ RelativeEffectCriterionWithZeroBaseline (traceIdentifier trace)
           | isRelativeCriterion (effectCriterion plan)
           , levelValue (observedLevel baselineObservation) == 0
           ]
        ++ [ InvalidTargetCriterion (traceIdentifier trace)
           | not (validTargetCriterion (targetCriterion plan))
           ]
    definitionErrors trace =
      case Map.lookup (traceKPI trace) definitionRegistry of
        Nothing -> []
        Just definition -> domainErrors trace definition
    domainErrors trace definition =
      baselineErrors ++ effectErrors ++ targetErrors
      where
        identifier = traceIdentifier trace
        domain = kpiDefinitionDomain definition
        baselineLevel = observedLevel baselineObservation
        baselineValid = levelInDomain domain baselineLevel
        baselineErrors =
          [ BaselineLevelOutsideDomain identifier baselineLevel domain
          | not baselineValid
          ]
        effectErrors =
          [ EffectCriterionOutsideDomain identifier endpoint domain
          | baselineValid
          , validEffectCriterion (effectCriterion plan)
          , not
              (isRelativeCriterion (effectCriterion plan)
                 && levelValue baselineLevel == 0)
          , let endpoint =
                  effectCriterionEndpoint baselineLevel (effectCriterion plan)
          , not (levelInDomain domain endpoint)
          ]
        targetErrors =
          [ TargetCriterionOutsideDomain identifier target domain
          | target <- nub (targetCriterionLevels (targetCriterion plan))
          , not (levelInDomain domain target)
          ]
    provenanceErrors trace =
      [EmptyPlanSource (traceIdentifier trace) | blankSource (planSource plan)]
        ++ [ EmptyBaselineSource (traceIdentifier trace)
           | blankSource (observationSource baselineObservation)
           ]

validEffectCriterion :: EffectCriterion -> Bool
validEffectCriterion (AbsoluteIncreaseByAtLeast delta) = deltaValue delta > 0
validEffectCriterion (AbsoluteDecreaseByAtLeast delta) = deltaValue delta > 0
validEffectCriterion (RelativeIncreaseByAtLeast change) =
  relativeChangeRatio change > 0
validEffectCriterion (RelativeDecreaseByAtLeast change) =
  relativeChangeRatio change > 0

isRelativeCriterion :: EffectCriterion -> Bool
isRelativeCriterion (RelativeIncreaseByAtLeast _) = True
isRelativeCriterion (RelativeDecreaseByAtLeast _) = True
isRelativeCriterion _ = False

validTargetCriterion :: TargetCriterion -> Bool
validTargetCriterion (AtLeast _) = True
validTargetCriterion (AtMost _) = True
validTargetCriterion (Within lower upper) = levelValue lower <= levelValue upper

validValueDomain :: ValueDomain -> Bool
validValueDomain (BoundedDomain lower upper) =
  levelValue lower <= levelValue upper
validValueDomain _ = True

levelInDomain :: ValueDomain -> Level -> Bool
levelInDomain UnboundedDomain _ = True
levelInDomain (LowerBoundedDomain lower) level = level >= lower
levelInDomain (UpperBoundedDomain upper) level = level <= upper
levelInDomain (BoundedDomain lower upper) level =
  level >= lower && level <= upper

effectCriterionEndpoint :: Level -> EffectCriterion -> Level
effectCriterionEndpoint baselineLevel criterion =
  Level
    (case criterion of
       AbsoluteIncreaseByAtLeast delta -> before + deltaValue delta
       AbsoluteDecreaseByAtLeast delta -> before - deltaValue delta
       RelativeIncreaseByAtLeast change ->
         before + abs before * relativeChangeRatio change
       RelativeDecreaseByAtLeast change ->
         before - abs before * relativeChangeRatio change)
  where
    before = levelValue baselineLevel

targetCriterionLevels :: TargetCriterion -> [Level]
targetCriterionLevels (AtLeast level) = [level]
targetCriterionLevels (AtMost level) = [level]
targetCriterionLevels (Within lower upper) = [lower, upper]

blankUnit :: Unit -> Bool
blankUnit PercentagePoints = False
blankUnit (NamedUnit name) = Text.null (Text.strip name)

blankText :: Text -> Bool
blankText = Text.null . Text.strip

blankSource :: EvidenceSource -> Bool
blankSource = blankText . evidenceSourceName

-- * Validated readiness access
-- | Enumerate the validated KPI definitions shared by all ready traces.
kpiDefinitions :: EvidenceReadyModel -> [KPIDefinition]
kpiDefinitions = Map.elems . validatedKPIDefinitions

-- | Resolve the stable definition of a typed KPI in an evidence-ready model.
lookupKPIDefinition ::
     EvidenceReadyModel
  -> NodeId ('PrimitiveKind 'Measure 'KPI)
  -> Maybe KPIDefinition
lookupKPIDefinition model kpi = Map.lookup kpi (validatedKPIDefinitions model)

-- | Enumerate all validated ex-ante evidence plans.
evidencePlans :: EvidenceReadyModel -> NonEmpty.NonEmpty EvidencePlan
evidencePlans = validatedEvidencePlans

-- | Read the time at which evidence readiness was validated.
readinessCheckedAt :: EvidenceReadyModel -> UTCTime
readinessCheckedAt = validatedReadinessCheckedAt

-- | Enumerate canonical planned starts for all traced Interventions.
plannedInterventionStarts :: EvidenceReadyModel -> [PlannedInterventionStart]
plannedInterventionStarts = Map.elems . validatedPlannedStarts

-- | Enumerate all complete effect traces covered by validated plans.
readyEffectTraces :: EvidenceReadyModel -> NonEmpty.NonEmpty EffectTrace
readyEffectTraces = effectTraces . validatedTraceableModel

-- | Enumerate all Interventions with validated canonical planned timing.
readyInterventions :: EvidenceReadyModel -> [ContextRef 'Intervention]
readyInterventions = Map.keys . validatedPlannedStarts

-- | Find all evidence-ready traces for one Intervention.
readyTracesForIntervention ::
     EvidenceReadyModel -> ContextRef 'Intervention -> [EffectTrace]
readyTracesForIntervention model intervention =
  filter
    ((== intervention) . traceIntervention)
    (NonEmpty.toList (readyEffectTraces model))

-- | Access the traceable model underlying evidence readiness.
readyTraceableModel :: EvidenceReadyModel -> TraceableEffectModel
readyTraceableModel = validatedTraceableModel

-- | Resolve the fixed evidence plan for a validated trace identifier.
lookupEvidencePlan :: EvidenceReadyModel -> EffectTraceId -> Maybe EvidencePlan
lookupEvidencePlan model identifier =
  Map.lookup identifier (evidencePlanIndex model)
