{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned Readiness prerequisite reconstruction and criteria evaluation.
module O2I.Readiness.Eval
  ( prepareReadinessSubjectInternal
  , assessReadinessInternal
  , assessReadinessWithWorkInternal
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Core.Contract (CoreRuleId, coreRuleIdText)
import O2I.Core.Identity (modelIdentityText)
import O2I.Readiness.Internal
import O2I.Semantics (SemanticAssessment, SemanticallyValidModel)
import O2I.Semantics.Internal (semanticallyValidModelGraphIdentity)
import O2I.Trace
  ( SuppliedCompleteTrace
  , TraceVariable(..)
  , boundTraceIdentity
  , promotedTraceGraphIdentity
  , promotedTraceIdentity
  , promotedTraceableEffectModel
  , reconstructTraceableEffectModel
  , suppliedCompleteOwnershipSupport
  , suppliedCompleteRelationSupport
  , suppliedCompleteTrace
  , suppliedTraceUnavailableReasons
  , traceIdentityBinding
  , traceIdentityBindings
  , traceIdentityGraphIdentity
  , tracePromotionUnavailableReasons
  , traceSupportOccurrences
  , validateSuppliedTrace
  )

prepareReadinessSubjectInternal ::
     SemanticallyValidModel scope
  -> SemanticAssessment scope
  -> BoundReadinessInput scope
  -> ReadinessSubjectAssessment scope
prepareReadinessSubjectInternal model semantics bound =
  case suppliedCompleteTrace suppliedAssessment of
    Nothing ->
      ReadinessSubjectUnavailable
        graph
        identity
        (nonEmptyReasons
           (map
              ReadinessSuppliedTraceUnavailable
              (suppliedTraceUnavailableReasons suppliedAssessment)))
    Just supplied ->
      let promotion = reconstructTraceableEffectModel model semantics supplied
       in case promotedTraceableEffectModel promotion of
            Nothing ->
              ReadinessSubjectUnavailable
                graph
                identity
                (nonEmptyReasons
                   (map
                      ReadinessPromotionUnavailable
                      (tracePromotionUnavailableReasons promotion)))
            Just promoted ->
              ReadinessSubjectAvailable
                (ReadinessSubject promoted bound (supportCount supplied))
  where
    identity = boundTraceIdentity (storedBoundReadinessTrace bound)
    graph = semanticallyValidModelGraphIdentity model
    suppliedAssessment =
      validateSuppliedTrace model (storedBoundReadinessTrace bound)

supportCount :: SuppliedCompleteTrace scope -> Int
supportCount supplied =
  sum
    (map
       (length . traceSupportOccurrences)
       (suppliedCompleteRelationSupport supplied
          <> suppliedCompleteOwnershipSupport supplied))

assessReadinessInternal :: ReadinessSubject scope -> ReadinessAssessment scope
assessReadinessInternal = fst . assessReadinessWithWorkInternal

assessReadinessWithWorkInternal ::
     ReadinessSubject scope -> (ReadinessAssessment scope, ReadinessWork)
assessReadinessWithWorkInternal subject = (assessment, work)
  where
    promoted = storedReadinessPromotedTrace subject
    bound = storedReadinessBoundInput subject
    input = storedBoundReadinessInput bound
    graph = promotedTraceGraphIdentity promoted
    trace = promotedTraceIdentity promoted
    kpi = storedKpiDefinition input
    plan = storedEvidencePlan input
    planned = storedPlannedStart input
    expectedKpi = traceIdentityBinding trace MeasureKpiVariable
    expectedIntervention = traceIdentityBinding trace InterventionVariable
    kpiKey = KPIDefinitionSlotKey expectedKpi
    plannedKey = PlannedStartSlotKey expectedIntervention
    planKey = EvidencePlanSlotKey trace
    kpiBound = storedKpiIdentity kpi == expectedKpi
    interventionBound =
      storedPlannedIntervention planned == expectedIntervention
    planBound = storedEvidenceTrace plan == trace
    kpiAndPlanBound = kpiBound && planBound
    planAndInterventionBound = planBound && interventionBound
    criteria =
      [ criterion ReadinessKpiDefinitionCardinality kpiKey kpiBound
      , criterion ReadinessPlannedStartCardinality plannedKey interventionBound
      , criterion ReadinessEvidencePlanCardinality planKey planBound
      ]
        <> guarded
             kpiBound
             [ criterion
                 ReadinessKpiDefinitionUnit
                 kpiKey
                 (validDomainUnit (storedKpiDomain kpi))
             , criterion
                 ReadinessKpiDefinitionValueDomain
                 kpiKey
                 (validValueDomain (storedKpiDomain kpi))
             , criterion
                 ReadinessKpiDefinitionMeasurementMethod
                 kpiKey
                 (validCanonicalText (storedMeasurementMethod kpi))
             , criterion
                 ReadinessKpiDefinitionInterpretation
                 kpiKey
                 (validCanonicalText (storedInterpretation kpi))
             ]
        <> guarded
             planBound
             [ criterion
                 ReadinessEvidencePlanSource
                 planKey
                 (validCanonicalText (storedEvidencePlanSource plan)
                    && validCanonicalText
                         (storedBaselineSource (storedBaseline plan)))
             , criterion
                 ReadinessBaselineChronology
                 planKey
                 (validBaselineChronology input)
             ]
        <> guarded
             planAndInterventionBound
             [ criterion
                 ReadinessEvidencePlanChronology
                 planKey
                 (validChronology input)
             , criterion
                 ReadinessTargetCriterionDue
                 planKey
                 (storedPlannedStartAt planned < storedTargetDueAt plan)
             ]
        <> guarded
             kpiAndPlanBound
             ([ criterion ReadinessBaselineIdentity planKey True
              , criterion
                  ReadinessBaselineValueDomain
                  planKey
                  (domainContains
                     (storedKpiDomain kpi)
                     (storedBaselineValue (storedBaseline plan)))
              , criterion
                  ReadinessEffectCriterionKind
                  planKey
                  (effectKindCompatible
                     (storedKpiDomain kpi)
                     (storedEffectCriterion plan))
              ]
                <> guarded
                     (effectKindCompatible
                        (storedKpiDomain kpi)
                        (storedEffectCriterion plan))
                     [ criterion
                         ReadinessEffectCriterionValueDomain
                         planKey
                         (effectCriterionInDomain
                            (storedKpiDomain kpi)
                            (storedEffectCriterion plan))
                     ]
                <> [ criterion
                       ReadinessTargetCriterionKind
                       planKey
                       (targetKindCompatible
                          (storedKpiDomain kpi)
                          (storedTargetCriterion plan))
                   ]
                <> guarded
                     (targetKindCompatible
                        (storedKpiDomain kpi)
                        (storedTargetCriterion plan))
                     [ criterion
                         ReadinessTargetCriterionValueDomain
                         planKey
                         (targetCriterionInDomain
                            (storedKpiDomain kpi)
                            (storedTargetCriterion plan))
                     ])
    defects =
      sortReadinessDefects
        [ ReadinessDefect ruleId key
        | Criterion ruleId key satisfied <- criteria
        , not satisfied
        ]
    assessment =
      case defects of
        first:remaining -> ReadinessNotReady graph trace (first :| remaining)
        [] -> ReadinessReady (EvidenceReadyProof graph trace promoted input)
    entries = 1 + length defects
    keyScalars =
      evidenceKeyScalarLength (ReadinessSubjectKey graph trace)
        + sum
            [ Text.length (coreRuleIdText (storedReadinessDefectRule defect))
              + evidenceKeyScalarLength (storedReadinessDefectKey defect)
            | defect <- defects
            ]
    work =
      emptyReadinessWork
        { readinessInputOccurrences = readinessInputSize input
        , readinessSuppliedSupportOccurrences =
            storedReadinessSuppliedSupportCount subject
        , readinessCriteriaEvaluated = length criteria
        , readinessOrderingEntries = entries
        , readinessOrderingKeyScalars = keyScalars
        , readinessRetainedEntries = entries
        }

data Criterion =
  Criterion !CoreRuleId !ReadinessEvidenceKey !Bool

criterion :: ReadinessRule -> ReadinessEvidenceKey -> Bool -> Criterion
criterion readinessRule = Criterion (readinessRuleId readinessRule)

guarded :: Bool -> [value] -> [value]
guarded condition values =
  if condition
    then values
    else []

validDomainUnit :: ValueDomain -> Bool
validDomainUnit domain =
  case domain of
    QuantitativeDomain (Unit value) _ -> not (Text.null value)
    _ -> True

validValueDomain :: ValueDomain -> Bool
validValueDomain domain =
  case domain of
    QuantitativeDomain (Unit value) _ -> not (Text.null value)
    OrdinalDomain _ levels _ -> NonEmpty.length levels >= 2
    CategoricalDomain values -> not (null values)

validCanonicalText :: CanonicalText -> Bool
validCanonicalText (CanonicalText value) = not (Text.null value)

validChronology :: ReadinessInput -> Bool
validChronology input =
  established <= observed
    && observed <= checked
    && checked < planned
    && planned < due
  where
    plan = storedEvidencePlan input
    established = storedPlanEstablishedAt plan
    observed = storedBaselineObservedAt (storedBaseline plan)
    checked = storedReadinessCheckedAt input
    planned = storedPlannedStartAt (storedPlannedStart input)
    due = storedTargetDueAt plan

validBaselineChronology :: ReadinessInput -> Bool
validBaselineChronology input =
  storedPlanEstablishedAt plan <= storedBaselineObservedAt (storedBaseline plan)
    && storedBaselineObservedAt (storedBaseline plan)
         <= storedReadinessCheckedAt input
  where
    plan = storedEvidencePlan input

domainContains :: ValueDomain -> DomainValue -> Bool
domainContains domain value =
  case (domain, value) of
    (QuantitativeDomain expected _, QuantitativeValue _ actual) ->
      expected == actual
    (OrdinalDomain scale levels _, OrdinalValue actualScale level) ->
      scale == actualScale && level `elem` NonEmpty.toList levels
    (CategoricalDomain admitted, CategoricalValue actual) ->
      actual `elem` NonEmpty.toList admitted
    _ -> False

effectKindCompatible :: ValueDomain -> EffectCriterion -> Bool
effectKindCompatible domain criterionValue =
  case (domain, criterionValue) of
    (QuantitativeDomain {}, QuantitativeAbsoluteEffect {}) -> True
    (QuantitativeDomain {}, QuantitativeRelativeEffect {}) -> True
    (OrdinalDomain {}, OrdinalStepsEffect {}) -> True
    (CategoricalDomain {}, CategoricalTransitionEffect {}) -> True
    _ -> False

effectCriterionInDomain :: ValueDomain -> EffectCriterion -> Bool
effectCriterionInDomain domain criterionValue =
  case (domain, criterionValue) of
    (QuantitativeDomain {}, QuantitativeAbsoluteEffect {}) -> True
    (QuantitativeDomain {}, QuantitativeRelativeEffect {}) -> True
    (OrdinalDomain _ levels _, OrdinalStepsEffect steps) ->
      steps <= fromIntegral (NonEmpty.length levels - 1)
    (CategoricalDomain admitted, CategoricalTransitionEffect accepted) ->
      orderedSubset accepted admitted
    _ -> False

targetKindCompatible :: ValueDomain -> TargetCriterion -> Bool
targetKindCompatible domain criterionValue =
  case (domain, criterionValue) of
    (QuantitativeDomain {}, QuantitativeThreshold {}) -> True
    (OrdinalDomain {}, OrdinalThreshold {}) -> True
    (CategoricalDomain {}, CategoricalMembership {}) -> True
    _ -> False

targetCriterionInDomain :: ValueDomain -> TargetCriterion -> Bool
targetCriterionInDomain domain criterionValue =
  case (domain, criterionValue) of
    (QuantitativeDomain expected _, QuantitativeThreshold _ _ actual) ->
      expected == actual
    (OrdinalDomain scale levels _, OrdinalThreshold _ actualScale level) ->
      scale == actualScale && level `elem` NonEmpty.toList levels
    (CategoricalDomain admitted, CategoricalMembership accepted) ->
      orderedSubset accepted admitted
    _ -> False

orderedSubset :: Ord value => NonEmpty value -> NonEmpty value -> Bool
orderedSubset subset superset =
  go (NonEmpty.toList subset) (NonEmpty.toList superset)
  where
    go [] _ = True
    go _ [] = False
    go left@(candidate:remaining) (admitted:rest) =
      case compare candidate admitted of
        LT -> False
        EQ -> go remaining rest
        GT -> go left rest

readinessInputSize :: ReadinessInput -> Int
readinessInputSize input =
  1
    + length (traceIdentityBindings (storedEvidenceTrace plan))
    + domainSize (storedKpiDomain kpi)
    + valueSize (storedBaselineValue (storedBaseline plan))
    + effectSize (storedEffectCriterion plan)
    + targetSize (storedTargetCriterion plan)
  where
    kpi = storedKpiDefinition input
    plan = storedEvidencePlan input
    domainSize domain =
      case domain of
        QuantitativeDomain {} -> 1
        OrdinalDomain _ levels _ -> NonEmpty.length levels
        CategoricalDomain values -> NonEmpty.length values
    valueSize _ = 1
    effectSize value =
      case value of
        CategoricalTransitionEffect values -> NonEmpty.length values
        _ -> 1
    targetSize value =
      case value of
        CategoricalMembership values -> NonEmpty.length values
        _ -> 1

evidenceKeyScalarLength :: ReadinessEvidenceKey -> Int
evidenceKeyScalarLength key =
  case key of
    ReadinessSubjectKey graph trace -> identityLength graph + traceLength trace
    KPIDefinitionSlotKey kpi -> identityLength kpi
    PlannedStartSlotKey intervention -> identityLength intervention
    EvidencePlanSlotKey trace -> traceLength trace
  where
    identityLength = Text.length . modelIdentityText
    traceLength trace =
      identityLength (traceIdentityGraphIdentity trace)
        + sum
            [ identityLength identity
            | (_, identity) <- traceIdentityBindings trace
            ]

nonEmptyReasons ::
     [ReadinessSubjectUnavailableReason]
  -> NonEmpty ReadinessSubjectUnavailableReason
nonEmptyReasons reasons =
  case reasons of
    first:remaining -> first :| remaining
    [] -> error "Readiness prerequisite failure must retain a reason"
