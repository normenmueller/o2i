{-# LANGUAGE DataKinds #-}

-- | Ex-ante readiness validation for empirical effect evidence.
--
-- Readiness fixes one complete evidence plan for every validated effect trace
-- before its Intervention starts. It does not assess follow-up observations.
module O2I.Validation.Readiness
  ( Unit(..)
  , Quantity(..)
  , EvidenceSource(..)
  , Observation(..)
  , EffectCriterion(..)
  , TargetCriterion(..)
  , EvidencePlan(..)
  , EvidenceReadyModel
  , EvidenceReadinessError(..)
  , validateEvidenceReadinessAt
  , evidencePlans
  , readyEffectTraces
  , readyTracesForIntervention
  , readyTraceableModel
  , lookupEvidencePlan
  ) where

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
-- | Named measurement unit shared by observations and criteria.
newtype Unit = Unit
  { unitName :: Text -- ^ Nonblank unit name required by validation.
  } deriving (Eq, Ord, Show)

-- | Exact measured or criterion value with its unit.
data Quantity = Quantity
  { magnitude :: Rational -- ^ Exact numeric magnitude.
  , unit :: Unit -- ^ Semantic unit of the magnitude.
  } deriving (Eq, Show)

-- | Human-auditable provenance of a plan or observation.
newtype EvidenceSource = EvidenceSource
  { evidenceSourceName :: Text -- ^ Nonblank provenance description.
  } deriving (Eq, Ord, Show)

-- | One timestamped observation of a KPI at a Situation anchor.
data Observation = Observation
  { observationKPI :: RawNodeId -- ^ Observed KPI; must match the trace.
  , observationAnchor :: RawNodeId -- ^ Anchor; must match the trace.
  , observedAt :: UTCTime -- ^ Observation timestamp.
  , observedValue :: Quantity -- ^ Observed quantity.
  , observationSource :: EvidenceSource -- ^ Auditable provenance.
  } deriving (Eq, Show)

-- | Required direction and minimum magnitude of observed change.
data EffectCriterion
  = IncreaseByAtLeast Quantity -- ^ Require at least this positive increase.
  | DecreaseByAtLeast Quantity -- ^ Require at least this positive decrease.
  deriving (Eq, Show)

-- | Required absolute target range at follow-up.
data TargetCriterion
  = AtLeast Quantity -- ^ Require a value at or above the threshold.
  | AtMost Quantity -- ^ Require a value at or below the threshold.
  | Within Quantity Quantity -- ^ Require an inclusive lower/upper range.
  deriving (Eq, Show)

-- | Ex-ante evidence design fixed for one effect trace.
data EvidencePlan = EvidencePlan
  { plannedTrace :: EffectTraceId -- ^ Trace governed by this plan.
  , establishedAt :: UTCTime -- ^ Time at which the plan was fixed.
  , interventionStartedAt :: UTCTime -- ^ Intervention start time.
  , targetDueAt :: UTCTime -- ^ Due date for target attainment.
  , planSource :: EvidenceSource -- ^ Provenance of the evidence design.
  , baseline :: Observation -- ^ Observation fixed before intervention.
  , effectCriterion :: EffectCriterion -- ^ Required observed change.
  , targetCriterion :: TargetCriterion -- ^ Required absolute target.
  } deriving (Eq, Show)

-- * Evidence-ready model
-- | Opaque traceable model with one valid ex-ante plan per effect trace.
--
-- Success establishes complete plan coverage, trace alignment, valid timing,
-- compatible units and criteria, and auditable plan and baseline provenance.
data EvidenceReadyModel = EvidenceReadyModel
  { validatedTraceableModel :: TraceableEffectModel
  , validatedEvidencePlans :: NonEmpty.NonEmpty EvidencePlan
  , evidencePlanIndex :: Map EffectTraceId EvidencePlan
  }

-- | Violations detected while validating ex-ante evidence readiness.
data EvidenceReadinessError
  = UnknownEvidencePlanTrace EffectTraceId
    -- ^ A plan refers to no trace in the supplied traceable model.
  | DuplicateEvidencePlan EffectTraceId Int
    -- ^ More than one plan targets the same effect trace.
  | MissingEvidencePlan EffectTraceId
    -- ^ A validated effect trace has no evidence plan.
  | PlanEstablishedAfterCheck EffectTraceId
    -- ^ The plan was established after the readiness check.
  | ReadinessCheckedAtOrAfterIntervention EffectTraceId
    -- ^ Readiness was checked no earlier than the Intervention start.
  | BaselineObservedAfterCheck EffectTraceId
    -- ^ The baseline was observed after the readiness check.
  | BaselineObservedAtOrAfterIntervention EffectTraceId
    -- ^ The baseline was not observed before the Intervention start.
  | InvalidTargetDueDate EffectTraceId
    -- ^ The target due date is not after the Intervention start.
  | BaselineKPIMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline KPI differs from the traced KPI.
  | BaselineAnchorMismatch EffectTraceId RawNodeId RawNodeId
    -- ^ The baseline anchor differs from the traced anchor.
  | CriterionUnitMismatch EffectTraceId Unit Unit
    -- ^ A criterion unit differs from the baseline unit.
  | InvalidEffectCriterion EffectTraceId
    -- ^ The minimum effect magnitude is not strictly positive.
  | InvalidTargetCriterion EffectTraceId
    -- ^ Target bounds use different units or an inverted range.
  | EmptyUnit EffectTraceId
    -- ^ The baseline or a criterion has a blank unit.
  | EmptyPlanSource EffectTraceId
    -- ^ The evidence plan has blank provenance.
  | EmptyBaselineSource EffectTraceId
    -- ^ The baseline observation has blank provenance.
  deriving (Eq, Show)

-- * Readiness validation
-- | Validate exactly one ex-ante evidence plan for every effect trace.
--
-- The check time is explicit and must fall at or after plan establishment but
-- before every planned Intervention starts. Success fixes trace-aligned
-- baselines, criteria, target timing, and provenance before execution.
validateEvidenceReadinessAt ::
     UTCTime
  -> TraceableEffectModel
  -> NonEmpty.NonEmpty EvidencePlan
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
validateEvidenceReadinessAt checkedAt model plans =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      Success
        EvidenceReadyModel
          { validatedTraceableModel = model
          , validatedEvidencePlans = plans
          , evidencePlanIndex = Map.map NonEmpty.head planIndex
          }
  where
    planList = NonEmpty.toList plans
    planIndex = plansByTrace planList
    traces = NonEmpty.toList (effectTraces model)
    errors =
      duplicatePlanErrors planIndex
        ++ concatMap (planErrors checkedAt model) planList
        ++ [ MissingEvidencePlan identifier
           | trace <- traces
           , let identifier = traceIdentifier trace
           , Map.notMember identifier planIndex
           ]

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
     UTCTime -> TraceableEffectModel -> EvidencePlan -> [EvidenceReadinessError]
planErrors checkedAt model plan =
  case lookupEffectTrace model (plannedTrace plan) of
    Nothing -> [UnknownEvidencePlanTrace (plannedTrace plan)]
    Just trace ->
      timeErrors trace
        ++ bindingErrors trace
        ++ unitErrors trace
        ++ criterionErrors trace
        ++ provenanceErrors trace
  where
    baselineObservation = baseline plan
    baselineUnit = unit (observedValue baselineObservation)
    timeErrors trace =
      [ PlanEstablishedAfterCheck (traceIdentifier trace)
      | establishedAt plan > checkedAt
      ]
        ++ [ ReadinessCheckedAtOrAfterIntervention (traceIdentifier trace)
           | checkedAt >= interventionStartedAt plan
           ]
        ++ [ BaselineObservedAfterCheck (traceIdentifier trace)
           | observedAt baselineObservation > checkedAt
           ]
        ++ [ BaselineObservedAtOrAfterIntervention (traceIdentifier trace)
           | observedAt baselineObservation >= interventionStartedAt plan
           ]
        ++ [ InvalidTargetDueDate (traceIdentifier trace)
           | targetDueAt plan <= interventionStartedAt plan
           ]
    bindingErrors trace =
      [ BaselineKPIMismatch
        (traceIdentifier trace)
        (traceKPI trace)
        (observationKPI baselineObservation)
      | observationKPI baselineObservation /= traceKPI trace
      ]
        ++ [ BaselineAnchorMismatch
             (traceIdentifier trace)
             (traceAnchor trace)
             (observationAnchor baselineObservation)
           | observationAnchor baselineObservation /= traceAnchor trace
           ]
    unitErrors trace =
      [ CriterionUnitMismatch (traceIdentifier trace) baselineUnit criterionUnit
      | criterionUnit <- criterionUnits plan
      , criterionUnit /= baselineUnit
      ]
    criterionErrors trace =
      [ InvalidEffectCriterion (traceIdentifier trace)
      | not (validEffectCriterion (effectCriterion plan))
      ]
        ++ [ InvalidTargetCriterion (traceIdentifier trace)
           | not (validTargetCriterion (targetCriterion plan))
           ]
        ++ [ EmptyUnit (traceIdentifier trace)
           | any blankUnit (baselineUnit : criterionUnits plan)
           ]
    provenanceErrors trace =
      [EmptyPlanSource (traceIdentifier trace) | blankSource (planSource plan)]
        ++ [ EmptyBaselineSource (traceIdentifier trace)
           | blankSource (observationSource baselineObservation)
           ]

criterionUnits :: EvidencePlan -> [Unit]
criterionUnits plan =
  effectUnits (effectCriterion plan) ++ targetUnits (targetCriterion plan)
  where
    effectUnits (IncreaseByAtLeast quantity) = [unit quantity]
    effectUnits (DecreaseByAtLeast quantity) = [unit quantity]
    targetUnits (AtLeast quantity) = [unit quantity]
    targetUnits (AtMost quantity) = [unit quantity]
    targetUnits (Within lower upper) = [unit lower, unit upper]

validEffectCriterion :: EffectCriterion -> Bool
validEffectCriterion (IncreaseByAtLeast quantity) = magnitude quantity > 0
validEffectCriterion (DecreaseByAtLeast quantity) = magnitude quantity > 0

validTargetCriterion :: TargetCriterion -> Bool
validTargetCriterion (AtLeast _) = True
validTargetCriterion (AtMost _) = True
validTargetCriterion (Within lower upper) =
  unit lower == unit upper && magnitude lower <= magnitude upper

blankUnit :: Unit -> Bool
blankUnit = Text.null . Text.strip . unitName

blankSource :: EvidenceSource -> Bool
blankSource = Text.null . Text.strip . evidenceSourceName

-- * Validated readiness access
-- | Enumerate all validated ex-ante evidence plans.
evidencePlans :: EvidenceReadyModel -> NonEmpty.NonEmpty EvidencePlan
evidencePlans = validatedEvidencePlans

-- | Enumerate all complete effect traces covered by validated plans.
readyEffectTraces :: EvidenceReadyModel -> NonEmpty.NonEmpty EffectTrace
readyEffectTraces = effectTraces . validatedTraceableModel

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
