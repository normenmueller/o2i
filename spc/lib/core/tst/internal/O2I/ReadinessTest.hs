{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Core.Contract (coreRuleIdText)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal (CoreQualifiedEndpointId(..))
import O2I.Core.Graph.Commitment (Commitment(Asserted))
import O2I.Core.Graph.Observation.Internal
  ( CarrierObservation(..)
  , ScopedGraphOccurrence(..)
  )
import O2I.Core.Identity
  ( ModelIdentity
  , ModelOccurrence
  , OccurrenceIdentity
  , buildModelIdentityIndex
  , modelIdentity
  , modelIdentityText
  , modelOccurrence
  , occurrenceIdentity
  )
import O2I.Core.Identity.Internal (withSelectedViewScope)
import qualified O2I.Readiness as Readiness
import qualified O2I.Readiness.Decode as Decode
import qualified O2I.Readiness.Eval as Eval
import qualified O2I.Readiness.Internal as Internal
import O2I.Structure.Internal (WellFormedGraph(..))
import O2I.Trace
  ( TraceVariable(..)
  , mkTraceIdentity
  , traceIdentityBinding
  , traceIdentityBindings
  , traceIdentityGraphIdentity
  )
import qualified O2I.Trace.Internal as TraceInternal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core Readiness"
    [ testCase "closes the exact seventeen-rule inventory" exactRuleInventory
    , testCase "decodes the exact ReadinessInput schema" validDecode
    , testCase
        "rejects AssessmentBundleInput at the discriminator"
        readinessOnly
    , testCase "decoder phases suppress all later phases" phaseSuppression
    , testCase "schema defects accumulate in canonical order" schemaAccumulation
    , testCase "numeric integer lexemes remain schema exact" integerLexeme
    , testCase "Gregorian timestamp validation is total" invalidCalendarDate
    , testCase "canonical set arrays are deterministically sorted" canonicalSets
    , testCase
        "normalization collisions remain distinct from source duplicates"
        arrayCollisions
    , testCase "ordinal levels preserve author order" ordinalOrder
    , testCase
        "ModelIdentity scalar evidence retains exact indexes"
        identityScalarEvidence
    , testCase "binds every independent Readiness identity site" completeBinding
    , testCase
        "binding reports unknown graph identity before subject reconstruction"
        unknownGraphBinding
    , testCase "binding preserves ambiguity precedence" ambiguousBinding
    , testCase "binding reports an out-of-View identity" outOfViewBinding
    , testCase
        "binding reports the resolved wrong qualified type"
        wrongTypeBinding
    , testCase "binding accepts every Situation Anchor kind" acceptedAnchorKinds
    , testCase
        "wrong-type Situation Anchor reports the complete admitted union"
        wrongTypeAnchorBinding
    , testCase "binding orders sites before rule kinds" bindingCanonicalOrder
    , testCase
        "all seventeen criteria construct the opaque proof"
        readyAssessment
    , testCase
        "KPI binding failure suppresses only KPI-derived criteria"
        kpiBindingSuppression
    , testCase
        "planned-start binding failure suppresses only chronology and due"
        plannedStartBindingSuppression
    , testCase
        "evidence-plan binding failure suppresses only plan-derived criteria"
        evidencePlanBindingSuppression
    , testCase
        "combined binding failures retain only independent cardinalities"
        combinedBindingSuppression
    , testCase "NotReady diagnostics use canonical rule order" diagnosticOrder
    , testCase "private counters expose each adversarial variable" workCounters
    ]

exactRuleInventory :: IO ()
exactRuleInventory =
  map
    (coreRuleIdText . Internal.readinessRuleId)
    ([minBound .. maxBound] :: [Internal.ReadinessRule])
    @?= [ "core.readiness.kpi-definition.cardinality"
        , "core.readiness.kpi-definition.unit"
        , "core.readiness.kpi-definition.value-domain"
        , "core.readiness.kpi-definition.measurement-method"
        , "core.readiness.kpi-definition.interpretation"
        , "core.readiness.planned-start.cardinality"
        , "core.readiness.evidence-plan.cardinality"
        , "core.readiness.evidence-plan.source"
        , "core.readiness.evidence-plan.chronology"
        , "core.readiness.baseline.identity"
        , "core.readiness.baseline.value-domain"
        , "core.readiness.baseline.chronology"
        , "core.readiness.effect-criterion.kind"
        , "core.readiness.effect-criterion.value-domain"
        , "core.readiness.target-criterion.kind"
        , "core.readiness.target-criterion.value-domain"
        , "core.readiness.target-criterion.due"
        ]

validDecode :: IO ()
validDecode = do
  input <- decoded quantitativeJson
  Readiness.readinessInputOrdinalValue (Readiness.readinessInputOrdinalOf input)
    @?= 7
  Readiness.utcTimestampText (Readiness.readinessCheckedAt input)
    @?= "2026-01-01T00:00:02Z"
  let trace =
        Readiness.evidencePlanTraceIdentity
          (Readiness.readinessEvidencePlan input)
  modelIdentityText (traceIdentityGraphIdentity trace) @?= "graph"
  modelIdentityText (traceIdentityBinding trace MeasureKpiVariable) @?= "kpi"
  let baselineValue =
        Readiness.baselineValue
          (Readiness.evidencePlanBaseline
             (Readiness.readinessEvidencePlan input))
      decimal =
        Readiness.foldDomainValue
          (\value _ -> value)
          (\_ _ -> error "unexpected ordinal value")
          (\_ -> error "unexpected categorical value")
          baselineValue
  Readiness.canonicalDecimalText decimal @?= "1.5"

readinessOnly :: IO ()
readinessOnly =
  defectKinds (decodeText "{\"type\":\"AssessmentBundleInput\"}")
    @?= [Internal.EvidenceInputDiscriminatorInvalid]

phaseSuppression :: IO ()
phaseSuppression = do
  defectKinds
    (Readiness.decodeReadinessInput
       (Readiness.readinessInputOrdinal 7)
       (ByteString.pack [0xc3, 0x28]))
    @?= [Internal.EvidenceInputInvalidUtf8]
  defectKinds (decodeText "{") @?= [Internal.EvidenceInputInvalidJsonSyntax]
  defectKinds
    (decodeText "{\"type\":\"ReadinessInput\",\"type\":\"ReadinessInput\"}")
    @?= [Internal.EvidenceInputDuplicateObjectMember]
  defectKinds (decodeText "[]")
    @?= [Internal.EvidenceInputTopLevelObjectRequired]

schemaAccumulation :: IO ()
schemaAccumulation =
  defectKinds (decodeText "{\"type\":\"ReadinessInput\",\"unknown\":0}")
    @?= replicate 4 Internal.EvidenceInputRequiredMemberMissing
    <> [Internal.EvidenceInputUnknownMember]

integerLexeme :: IO ()
integerLexeme = do
  defectKinds (decodeText (ordinalJsonWithSteps "1e0"))
    @?= [Internal.EvidenceInputScalarGrammarInvalid]
  input <- decoded (ordinalJsonWithSteps "1")
  case Internal.storedEffectCriterion (Internal.storedEvidencePlan input) of
    Internal.OrdinalStepsEffect steps -> steps @?= 1
    _ -> fail "ordinal criterion was not retained"

invalidCalendarDate :: IO ()
invalidCalendarDate =
  defectKinds
    (decodeText
       (Text.replace
          "2026-01-01T00:00:02Z"
          "2026-02-30T00:00:02Z"
          quantitativeJson))
    @?= [Internal.EvidenceInputScalarGrammarInvalid]

canonicalSets :: IO ()
canonicalSets = do
  input <- decoded categoricalJson
  let kpiValues =
        case Internal.storedKpiDomain (Internal.storedKpiDefinition input) of
          Internal.CategoricalDomain values -> values
          _ -> error "categorical domain was not retained"
      plan = Internal.storedEvidencePlan input
      effectValues =
        case Internal.storedEffectCriterion plan of
          Internal.CategoricalTransitionEffect values -> values
          _ -> error "categorical effect was not retained"
      targetValues =
        case Internal.storedTargetCriterion plan of
          Internal.CategoricalMembership values -> values
          _ -> error "categorical target was not retained"
  texts kpiValues @?= ["a", "z"]
  texts effectValues @?= ["a", "z"]
  texts targetValues @?= ["a", "z"]

arrayCollisions :: IO ()
arrayCollisions = do
  defectKinds
    (decodeText
       (Text.replace
          "\"admittedValues\":[\"z\",\"a\"]"
          "\"admittedValues\":[\"Caf\\u00e9\",\"Cafe\\u0301\"]"
          categoricalJson))
    @?= [Internal.EvidenceInputNormalizationCollision]
  defectKinds
    (decodeText
       (Text.replace
          "\"admittedValues\":[\"z\",\"a\"]"
          "\"admittedValues\":[\"a\",\"a\"]"
          categoricalJson))
    @?= [Internal.EvidenceInputArrayDistinctnessInvalid]

ordinalOrder :: IO ()
ordinalOrder = do
  input <- decoded (ordinalJsonWithSteps "1")
  case Internal.storedKpiDomain (Internal.storedKpiDefinition input) of
    Internal.OrdinalDomain _ levels _ -> texts levels @?= ["high", "low"]
    _ -> fail "ordinal domain was not retained"

identityScalarEvidence :: IO ()
identityScalarEvidence = do
  let source =
        Text.replace
          "\"kpi\":\"kpi\""
          "\"kpi\":\"a\\u0000b\\u0000\""
          quantitativeJson
  case decodeText source of
    Right _ -> fail "NUL-bearing ModelIdentity was accepted"
    Left defects -> do
      map Internal.storedEvidenceInputDefectKind (NonEmpty.toList defects)
        @?= replicate 2 Internal.EvidenceInputModelIdentityContainsNul
      map naturalSubjects (NonEmpty.toList defects) @?= [[1], [3]]

readyAssessment :: IO ()
readyAssessment = do
  input <- decoded quantitativeJson
  let (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal (subjectFrom 41 input)
  Readiness.readinessDisposition assessment
    @?= Readiness.ReadinessReadyDisposition
  Internal.readinessCriteriaEvaluated evidence @?= 17
  Internal.readinessSuppliedSupportOccurrences evidence @?= 41
  Internal.readinessRetainedEntries evidence @?= 1
  case Readiness.evidenceReadyProof assessment of
    Nothing -> fail "ready result did not retain its proof"
    Just proof -> do
      Readiness.evidenceReadyInput proof @?= input
      modelIdentityText (Readiness.evidenceReadyGraphIdentity proof) @?= "graph"
      modelIdentityText
        (traceIdentityBinding
           (Readiness.evidenceReadyTraceIdentity proof)
           StrategyVariable)
        @?= "strategy"

kpiBindingSuppression :: IO ()
kpiBindingSuppression = do
  input <- decoded quantitativeJson
  let trace = inputTrace input
      kpi = Internal.storedKpiDefinition input
      plan = Internal.storedEvidencePlan input
      mismatched =
        replacePlan
          (Internal.EvidencePlan
             trace
             (Internal.storedBaseline plan)
             (Internal.CategoricalTransitionEffect
                (Internal.CanonicalText "foreign-effect" :| []))
             (Internal.OrdinalThreshold
                Internal.OrdinalAtLeastRank
                (Internal.CanonicalText "foreign-scale")
                (Internal.CanonicalText "foreign-level"))
             (Internal.storedReadinessCheckedAt input)
             (Internal.CanonicalText "")
             (Internal.storedPlanEstablishedAt plan))
          (replaceKpi
             (Internal.KPIDefinition
                (identity "other-kpi")
                (Internal.storedKpiDomain kpi)
                (Internal.CanonicalText "")
                (Internal.storedInterpretation kpi))
             input)
      (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal
          (subjectFromTrace 0 trace mismatched)
  Internal.readinessCriteriaEvaluated evidence @?= 7
  diagnosticRules assessment
    @?= [ "core.readiness.evidence-plan.chronology"
        , "core.readiness.evidence-plan.source"
        , "core.readiness.kpi-definition.cardinality"
        , "core.readiness.target-criterion.due"
        ]

plannedStartBindingSuppression :: IO ()
plannedStartBindingSuppression = do
  input <- decoded quantitativeJson
  let trace = inputTrace input
      kpi = Internal.storedKpiDefinition input
      plan = Internal.storedEvidencePlan input
      baseline = Internal.storedBaseline plan
      due = Internal.storedTargetDueAt plan
      mismatched =
        replacePlan
          (Internal.EvidencePlan
             trace
             (Internal.BaselineObservation
                due
                (Internal.storedBaselineSource baseline)
                (Internal.CategoricalValue
                   (Internal.CanonicalText "foreign-baseline")))
             (Internal.storedEffectCriterion plan)
             (Internal.storedTargetCriterion plan)
             due
             (Internal.CanonicalText "")
             (Internal.storedPlanEstablishedAt plan))
          (replacePlannedStart
             (Internal.PlannedInterventionStart
                (identity "other-intervention")
                due)
             (replaceKpi
                (Internal.KPIDefinition
                   (Internal.storedKpiIdentity kpi)
                   (Internal.storedKpiDomain kpi)
                   (Internal.CanonicalText "")
                   (Internal.storedInterpretation kpi))
                input))
      (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal
          (subjectFromTrace 0 trace mismatched)
      rules = diagnosticRules assessment
  Internal.readinessCriteriaEvaluated evidence @?= 15
  rules
    @?= [ "core.readiness.baseline.chronology"
        , "core.readiness.baseline.value-domain"
        , "core.readiness.evidence-plan.source"
        , "core.readiness.kpi-definition.measurement-method"
        , "core.readiness.planned-start.cardinality"
        ]
  assertBool
    "planned-start-derived chronology and due rules stay suppressed"
    ("core.readiness.evidence-plan.chronology" `notElem` rules
       && "core.readiness.target-criterion.due" `notElem` rules)

evidencePlanBindingSuppression :: IO ()
evidencePlanBindingSuppression = do
  input <- decoded quantitativeJson
  let trace = inputTrace input
      foreignTrace =
        traceWithBinding StrategyVariable (identity "foreign-strategy") trace
      kpi = Internal.storedKpiDefinition input
      plan = Internal.storedEvidencePlan input
      baseline = Internal.storedBaseline plan
      mismatched =
        replacePlan
          (Internal.EvidencePlan
             foreignTrace
             (Internal.BaselineObservation
                (Internal.storedTargetDueAt plan)
                (Internal.CanonicalText "")
                (Internal.CategoricalValue
                   (Internal.CanonicalText "foreign-baseline")))
             (Internal.CategoricalTransitionEffect
                (Internal.CanonicalText "foreign-effect" :| []))
             (Internal.OrdinalThreshold
                Internal.OrdinalAtLeastRank
                (Internal.CanonicalText "foreign-scale")
                (Internal.CanonicalText "foreign-level"))
             (Internal.storedReadinessCheckedAt input)
             (Internal.CanonicalText "")
             (Internal.storedBaselineObservedAt baseline))
          (replaceKpi
             (Internal.KPIDefinition
                (Internal.storedKpiIdentity kpi)
                (Internal.storedKpiDomain kpi)
                (Internal.CanonicalText "")
                (Internal.storedInterpretation kpi))
             input)
      (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal
          (subjectFromTrace 0 trace mismatched)
  Internal.readinessCriteriaEvaluated evidence @?= 7
  diagnosticRules assessment
    @?= [ "core.readiness.evidence-plan.cardinality"
        , "core.readiness.kpi-definition.measurement-method"
        ]

combinedBindingSuppression :: IO ()
combinedBindingSuppression = do
  input <- decoded quantitativeJson
  let trace = inputTrace input
      foreignTrace =
        traceWithBinding StrategyVariable (identity "foreign-strategy") trace
      kpi = Internal.storedKpiDefinition input
      plan = Internal.storedEvidencePlan input
      mismatched =
        replacePlan
          (Internal.EvidencePlan
             foreignTrace
             (Internal.storedBaseline plan)
             (Internal.CategoricalTransitionEffect
                (Internal.CanonicalText "foreign-effect" :| []))
             (Internal.OrdinalThreshold
                Internal.OrdinalAtLeastRank
                (Internal.CanonicalText "foreign-scale")
                (Internal.CanonicalText "foreign-level"))
             (Internal.storedReadinessCheckedAt input)
             (Internal.CanonicalText "")
             (Internal.storedPlanEstablishedAt plan))
          (replacePlannedStart
             (Internal.PlannedInterventionStart
                (identity "other-intervention")
                (Internal.storedTargetDueAt plan))
             (replaceKpi
                (Internal.KPIDefinition
                   (identity "other-kpi")
                   (Internal.storedKpiDomain kpi)
                   (Internal.CanonicalText "")
                   (Internal.storedInterpretation kpi))
                input))
      (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal
          (subjectFromTrace 0 trace mismatched)
  Internal.readinessCriteriaEvaluated evidence @?= 3
  diagnosticRules assessment
    @?= [ "core.readiness.evidence-plan.cardinality"
        , "core.readiness.kpi-definition.cardinality"
        , "core.readiness.planned-start.cardinality"
        ]

diagnosticOrder :: IO ()
diagnosticOrder = do
  input <- decoded quantitativeJson
  let plan = Internal.storedEvidencePlan input
      incompatible =
        replacePlan
          (Internal.EvidencePlan
             (Internal.storedEvidenceTrace plan)
             (Internal.storedBaseline plan)
             (Internal.CategoricalTransitionEffect
                (Internal.CanonicalText "x" :| []))
             (Internal.OrdinalThreshold
                Internal.OrdinalAtLeastRank
                (Internal.CanonicalText "scale")
                (Internal.CanonicalText "level"))
             (Internal.storedTargetDueAt plan)
             (Internal.storedEvidencePlanSource plan)
             (Internal.storedPlanEstablishedAt plan))
          input
      (assessment, evidence) =
        Eval.assessReadinessWithWorkInternal (subjectFrom 0 incompatible)
  Internal.readinessCriteriaEvaluated evidence @?= 15
  Internal.readinessOrderingEntries evidence @?= 3
  Internal.readinessRetainedEntries evidence @?= 3
  diagnosticRules assessment
    @?= [ "core.readiness.effect-criterion.kind"
        , "core.readiness.target-criterion.kind"
        ]

workCounters :: IO ()
workCounters = do
  base <- decoded categoricalJson
  let small = categoricalInput 2 base
      large = categoricalInput 200 base
      (_, smallWork) =
        Eval.assessReadinessWithWorkInternal (subjectFrom 3 small)
      (_, largeWork) =
        Eval.assessReadinessWithWorkInternal (subjectFrom 303 large)
      (_, decodeWork) =
        Decode.decodeReadinessInputWithWorkInternal
          (Internal.ReadinessInputOrdinal 7)
          (encode categoricalJson)
      (_, shortKeyWork) = malformedKeyWork "x"
      (_, longKeyWork) = malformedKeyWork (Text.replicate 1024 "x")
  Internal.readinessInputOccurrences largeWork
    - Internal.readinessInputOccurrences smallWork @?= 3 * (200 - 2)
  Internal.readinessSuppliedSupportOccurrences smallWork @?= 3
  Internal.readinessSuppliedSupportOccurrences largeWork @?= 303
  Internal.readinessCriteriaEvaluated largeWork @?= 17
  Internal.readinessInputOccurrences decodeWork @?= Text.length categoricalJson
  assertBool
    "ordering keys retain an explicit scalar-length counter"
    (Internal.readinessOrderingKeyScalars largeWork > 0)
  Internal.readinessOrderingEntries longKeyWork
    @?= Internal.readinessOrderingEntries shortKeyWork
  assertBool
    "long diagnostic keys contribute their retained scalar length"
    (Internal.readinessOrderingKeyScalars longKeyWork
       - Internal.readinessOrderingKeyScalars shortKeyWork
       >= 1023)
  where
    malformedKeyWork key =
      Decode.decodeReadinessInputWithWorkInternal
        (Internal.ReadinessInputOrdinal 7)
        (encode ("{\"type\":\"ReadinessInput\",\"" <> key <> "\":0}"))

completeBinding :: IO ()
completeBinding = do
  input <- decoded quantitativeJson
  withBindingGraph [] [] $ \graph ->
    case Readiness.foldReadinessInputBinding
           (\_ defects -> Left defects)
           Right
           (Readiness.bindReadinessInput graph input) of
      Left defects -> fail (show defects)
      Right bound -> Readiness.boundReadinessInput bound @?= input

unknownGraphBinding :: IO ()
unknownGraphBinding = do
  input <-
    decoded
      (Text.replace
         "\"graphIdentity\":\"graph\""
         "\"graphIdentity\":\"foreign\""
         quantitativeJson)
  withBindingGraph [] [] $ \graph -> do
    let defects = bindingDefects graph input
    map Readiness.evidenceInputDefectKind defects
      @?= [Internal.EvidenceInputIdentityUnknown]
    map Readiness.evidenceInputDefectPointer defects
      @?= ["/evidencePlan/trace/graphIdentity"]

ambiguousBinding :: IO ()
ambiguousBinding = do
  input <- decoded quantitativeJson
  let alias = modelOccurrence (occurrence "kpi-alias") (identity "kpi")
  withBindingGraph [alias] [occurrence "kpi-alias"] $ \graph ->
    map Readiness.evidenceInputDefectKind (bindingDefects graph input)
      @?= replicate 2 Internal.EvidenceInputIdentityAmbiguous

outOfViewBinding :: IO ()
outOfViewBinding = do
  input <-
    decoded
      (Text.replace "\"kpi\":\"kpi\"" "\"kpi\":\"outside-kpi\"" quantitativeJson)
  let outside =
        modelOccurrence (occurrence "outside-kpi") (identity "outside-kpi")
  withBindingGraph [outside] [] $ \graph ->
    map Readiness.evidenceInputDefectKind (bindingDefects graph input)
      @?= [Internal.EvidenceInputIdentityOutOfSelectedView]

wrongTypeBinding :: IO ()
wrongTypeBinding = do
  input <-
    decoded
      (Text.replace "\"kpi\":\"kpi\"" "\"kpi\":\"vision\"" quantitativeJson)
  withBindingGraph [] [] $ \graph ->
    map Readiness.evidenceInputDefectKind (bindingDefects graph input)
      @?= [Internal.EvidenceInputIdentityWrongType]

acceptedAnchorKinds :: IO ()
acceptedAnchorKinds = do
  input <- decoded quantitativeJson
  mapM_
    (\anchorEndpoint ->
       withBindingGraphForAnchor anchorEndpoint [] [] $ \graph ->
         bindingDefects graph input @?= [])
    [ Generated.GeneratedEndpointSituationAnchorBusinessCapability
    , Generated.GeneratedEndpointSituationAnchorBusinessProcess
    , Generated.GeneratedEndpointSituationAnchorBusinessObject
    , Generated.GeneratedEndpointSituationAnchorValueStream
    ]

wrongTypeAnchorBinding :: IO ()
wrongTypeAnchorBinding = do
  input <-
    decoded
      (Text.replace
         "\"situationAnchor\":\"anchor\""
         "\"situationAnchor\":\"vision\""
         quantitativeJson)
  withBindingGraph [] [] $ \graph ->
    case bindingDefects graph input of
      [defect] -> do
        Readiness.evidenceInputDefectKind defect
          @?= Internal.EvidenceInputIdentityWrongType
        Readiness.evidenceInputDefectPointer defect
          @?= "/evidencePlan/trace/bindings/situationAnchor"
        qualifiedTypeSubjects defect
          @?= [ CoreQualifiedEndpointId
                  Generated.GeneratedEndpointSituationAnchorBusinessCapability
              , CoreQualifiedEndpointId
                  Generated.GeneratedEndpointSituationAnchorBusinessProcess
              , CoreQualifiedEndpointId
                  Generated.GeneratedEndpointSituationAnchorBusinessObject
              , CoreQualifiedEndpointId
                  Generated.GeneratedEndpointSituationAnchorValueStream
              ]
      defects -> fail ("unexpected Situation Anchor defects: " ++ show defects)

bindingCanonicalOrder :: IO ()
bindingCanonicalOrder = do
  input <-
    decoded
      (Text.replace
         "\"kpi\":\"kpi\""
         "\"kpi\":\"unknown-kpi\""
         (Text.replace
            "\"vision\":\"vision\""
            "\"vision\":\"kpi\""
            quantitativeJson))
  withBindingGraph [] [] $ \graph -> do
    let defects = bindingDefects graph input
    map Readiness.evidenceInputDefectPointer defects
      @?= ["/evidencePlan/trace/bindings/vision", "/kpiDefinition/kpi"]
    map Readiness.evidenceInputDefectKind defects
      @?= [ Internal.EvidenceInputIdentityWrongType
          , Internal.EvidenceInputIdentityUnknown
          ]

bindingDefects ::
     WellFormedGraph scope
  -> Internal.ReadinessInput
  -> [Internal.EvidenceInputDefect]
bindingDefects graph input =
  Readiness.foldReadinessInputBinding
    (\_ defects -> NonEmpty.toList defects)
    (const [])
    (Readiness.bindReadinessInput graph input)

withBindingGraph ::
     [ModelOccurrence]
  -> [OccurrenceIdentity]
  -> (forall scope. WellFormedGraph scope -> IO ())
  -> IO ()
withBindingGraph extra selectedExtra inspect =
  withBindingGraphFixtures carrierFixtures extra selectedExtra inspect

withBindingGraphForAnchor ::
     Generated.GeneratedQualifiedEndpoint
  -> [ModelOccurrence]
  -> [OccurrenceIdentity]
  -> (forall scope. WellFormedGraph scope -> IO ())
  -> IO ()
withBindingGraphForAnchor anchorEndpoint =
  withBindingGraphFixtures (carrierFixturesForAnchor anchorEndpoint)

withBindingGraphFixtures ::
     [( TraceVariable
      , OccurrenceIdentity
      , ModelIdentity
      , Generated.GeneratedQualifiedEndpoint)]
  -> [ModelOccurrence]
  -> [OccurrenceIdentity]
  -> (forall scope. WellFormedGraph scope -> IO ())
  -> IO ()
withBindingGraphFixtures fixtures extra selectedExtra inspect =
  case buildModelIdentityIndex (viewOccurrence : carrierOccurrences <> extra) of
    Left defects -> fail (show defects)
    Right index ->
      case withSelectedViewScope
             index
             viewOccurrence
             (map (\(_, occurrenceId, _, _) -> occurrenceId) fixtures
                <> selectedExtra)
             (\scope ->
                inspect
                  (WellFormedGraph scope (map (carrier scope) fixtures) [] [] [])) of
        Left defects -> fail (show defects)
        Right assertion -> assertion
  where
    viewOccurrence =
      modelOccurrence (occurrence "selected-view") (identity "graph")
    carrierOccurrences =
      [ modelOccurrence occurrenceId modelId
      | (_, occurrenceId, modelId, _) <- fixtures
      ]
    carrier _ (_, occurrenceId, modelId, endpointId) =
      CarrierObservation
        (ScopedGraphOccurrence occurrenceId)
        modelId
        (CoreQualifiedEndpointId endpointId)
        Asserted

carrierFixtures ::
     [( TraceVariable
      , OccurrenceIdentity
      , ModelIdentity
      , Generated.GeneratedQualifiedEndpoint)]
carrierFixtures =
  [ fixture VisionVariable "vision" Generated.GeneratedEndpointContextVision
  , fixture
      StrategyVariable
      "strategy"
      Generated.GeneratedEndpointContextStrategy
  , fixture NeedVariable "need" Generated.GeneratedEndpointContextNeed
  , fixture
      InterventionVariable
      "intervention"
      Generated.GeneratedEndpointContextIntervention
  , fixture MeasureVariable "measure" Generated.GeneratedEndpointContextMeasure
  , fixture
      SituationVariable
      "situation"
      Generated.GeneratedEndpointContextSituation
  , fixture
      VisionObjectiveVariable
      "vision-objective"
      Generated.GeneratedEndpointPrimitiveVisionObjective
  , fixture
      StrategyDriverVariable
      "strategy-driver"
      Generated.GeneratedEndpointPrimitiveStrategyDriver
  , fixture
      StrategyObjectiveVariable
      "strategy-objective"
      Generated.GeneratedEndpointPrimitiveStrategyObjective
  , fixture
      StrategyActionVariable
      "strategy-action"
      Generated.GeneratedEndpointPrimitiveStrategyAction
  , fixture
      StrategyKeyResultVariable
      "strategy-key-result"
      Generated.GeneratedEndpointPrimitiveStrategyKeyResult
  , fixture
      NeedDriverVariable
      "need-driver"
      Generated.GeneratedEndpointPrimitiveNeedDriver
  , fixture
      NeedObjectiveVariable
      "need-objective"
      Generated.GeneratedEndpointPrimitiveNeedObjective
  , fixture
      InterventionActionVariable
      "intervention-action"
      Generated.GeneratedEndpointPrimitiveInterventionAction
  , fixture
      InterventionKeyResultVariable
      "intervention-key-result"
      Generated.GeneratedEndpointPrimitiveInterventionKeyResult
  , fixture
      MeasurePerformanceDimensionVariable
      "performance-dimension"
      Generated.GeneratedEndpointStructuringMeasurePerformanceDimension
  , fixture
      MeasureKpiVariable
      "kpi"
      Generated.GeneratedEndpointPrimitiveMeasureKpi
  , fixture
      SituationAnchorVariable
      "anchor"
      Generated.GeneratedEndpointSituationAnchorBusinessCapability
  ]
  where
    fixture variable modelId endpointId =
      (variable, occurrence ("occ-" <> modelId), identity modelId, endpointId)

carrierFixturesForAnchor ::
     Generated.GeneratedQualifiedEndpoint
  -> [( TraceVariable
      , OccurrenceIdentity
      , ModelIdentity
      , Generated.GeneratedQualifiedEndpoint)]
carrierFixturesForAnchor anchorEndpoint =
  [ if variable == SituationAnchorVariable
    then (variable, occurrenceId, modelId, anchorEndpoint)
    else fixture
  | fixture@(variable, occurrenceId, modelId, _) <- carrierFixtures
  ]

occurrence :: Text -> OccurrenceIdentity
occurrence source =
  case occurrenceIdentity source of
    Left failure -> error (show failure)
    Right value -> value

subjectFrom :: Int -> Internal.ReadinessInput -> Internal.ReadinessSubject ()
subjectFrom support input = subjectFromTrace support (inputTrace input) input

subjectFromTrace ::
     Int
  -> TraceInternal.TraceIdentity
  -> Internal.ReadinessInput
  -> Internal.ReadinessSubject ()
subjectFromTrace support trace input =
  Internal.ReadinessSubject promoted bound support
  where
    graph = traceIdentityGraphIdentity trace
    strategy = traceIdentityBinding trace StrategyVariable
    promoted = TraceInternal.PromotedTraceableEffectModel graph trace strategy
    bound =
      Internal.BoundReadinessInput
        input
        (TraceInternal.BoundTraceIdentity (inputTrace input))

inputTrace :: Internal.ReadinessInput -> TraceInternal.TraceIdentity
inputTrace = Internal.storedEvidenceTrace . Internal.storedEvidencePlan

traceWithBinding ::
     TraceVariable
  -> ModelIdentity
  -> TraceInternal.TraceIdentity
  -> TraceInternal.TraceIdentity
traceWithBinding selected replacement trace =
  case mkTraceIdentity
         (traceIdentityGraphIdentity trace)
         [ ( variable
           , if variable == selected
               then replacement
               else current)
         | (variable, current) <- traceIdentityBindings trace
         ] of
    Nothing -> error "test replaced one binding in a complete Trace"
    Just updated -> updated

replaceKpi ::
     Internal.KPIDefinition
  -> Internal.ReadinessInput
  -> Internal.ReadinessInput
replaceKpi kpi input =
  Internal.ReadinessInput
    (Internal.storedReadinessOrdinal input)
    (Internal.storedReadinessCheckedAt input)
    kpi
    (Internal.storedPlannedStart input)
    (Internal.storedEvidencePlan input)

replacePlannedStart ::
     Internal.PlannedInterventionStart
  -> Internal.ReadinessInput
  -> Internal.ReadinessInput
replacePlannedStart planned input =
  Internal.ReadinessInput
    (Internal.storedReadinessOrdinal input)
    (Internal.storedReadinessCheckedAt input)
    (Internal.storedKpiDefinition input)
    planned
    (Internal.storedEvidencePlan input)

replacePlan ::
     Internal.EvidencePlan -> Internal.ReadinessInput -> Internal.ReadinessInput
replacePlan plan input =
  Internal.ReadinessInput
    (Internal.storedReadinessOrdinal input)
    (Internal.storedReadinessCheckedAt input)
    (Internal.storedKpiDefinition input)
    (Internal.storedPlannedStart input)
    plan

categoricalInput :: Int -> Internal.ReadinessInput -> Internal.ReadinessInput
categoricalInput count input =
  replacePlan updatedPlan (replaceKpi updatedKpi input)
  where
    values = canonicalValues count
    first = NonEmpty.head values
    kpi = Internal.storedKpiDefinition input
    plan = Internal.storedEvidencePlan input
    baseline = Internal.storedBaseline plan
    updatedKpi =
      Internal.KPIDefinition
        (Internal.storedKpiIdentity kpi)
        (Internal.CategoricalDomain values)
        (Internal.storedMeasurementMethod kpi)
        (Internal.storedInterpretation kpi)
    updatedPlan =
      Internal.EvidencePlan
        (Internal.storedEvidenceTrace plan)
        (Internal.BaselineObservation
           (Internal.storedBaselineObservedAt baseline)
           (Internal.storedBaselineSource baseline)
           (Internal.CategoricalValue first))
        (Internal.CategoricalTransitionEffect values)
        (Internal.CategoricalMembership values)
        (Internal.storedTargetDueAt plan)
        (Internal.storedEvidencePlanSource plan)
        (Internal.storedPlanEstablishedAt plan)

canonicalValues :: Int -> NonEmpty Internal.CanonicalText
canonicalValues count =
  case NonEmpty.nonEmpty
         [ Internal.CanonicalText ("v" <> Text.pack (show index))
         | index <- [1 .. count]
         ] of
    Nothing -> error "test requires a positive cardinality"
    Just values -> values

diagnosticRules :: Readiness.ReadinessAssessment scope -> [Text]
diagnosticRules =
  map (coreRuleIdText . Readiness.readinessDiagnosticRule)
    . Readiness.readinessDiagnostics

naturalSubjects :: Internal.EvidenceInputDefect -> [Integer]
naturalSubjects defect =
  [ toInteger value
  | Internal.EvidenceInputNaturalSubject _ value <-
      NonEmpty.toList (Internal.storedEvidenceInputDefectSubjects defect)
  ]

qualifiedTypeSubjects ::
     Internal.EvidenceInputDefect -> [CoreQualifiedEndpointId]
qualifiedTypeSubjects defect =
  [ endpointId
  | Internal.EvidenceInputQualifiedTypeSubject _ endpointId <-
      NonEmpty.toList (Internal.storedEvidenceInputDefectSubjects defect)
  ]

defectKinds ::
     Either (NonEmpty Internal.EvidenceInputDefect) value
  -> [Internal.EvidenceInputDefectKind]
defectKinds result =
  case result of
    Left defects ->
      map Internal.storedEvidenceInputDefectKind (NonEmpty.toList defects)
    Right _ -> []

decoded :: Text -> IO Internal.ReadinessInput
decoded source =
  case decodeText source of
    Left defects -> fail (show defects)
    Right input -> pure input

decodeText ::
     Text
  -> Either (NonEmpty Internal.EvidenceInputDefect) Internal.ReadinessInput
decodeText =
  Readiness.decodeReadinessInput (Readiness.readinessInputOrdinal 7) . encode

identity :: Text -> ModelIdentity
identity source =
  case modelIdentity source of
    Left failure -> error (show failure)
    Right value -> value

texts :: NonEmpty Internal.CanonicalText -> [Text]
texts = map (\(Internal.CanonicalText value) -> value) . NonEmpty.toList

encode :: Text -> ByteString
encode = TextEncoding.encodeUtf8

quantitativeJson, categoricalJson :: Text
quantitativeJson =
  readinessJson
    "{\"kind\":\"quantitative\",\"unit\":\"count\",\"effectDirection\":\"increase\"}"
    "{\"kind\":\"quantitative\",\"value\":\"1.5\",\"unit\":\"count\"}"
    "{\"kind\":\"quantitative-absolute\",\"minimumDirectionAdjustedDelta\":\"1\"}"
    "{\"kind\":\"quantitative-threshold\",\"comparison\":\"at-least\",\"target\":\"2\",\"unit\":\"count\"}"

categoricalJson =
  readinessJson
    "{\"kind\":\"categorical\",\"admittedValues\":[\"z\",\"a\"]}"
    "{\"kind\":\"categorical\",\"value\":\"a\"}"
    "{\"kind\":\"categorical-transition\",\"acceptedValues\":[\"z\",\"a\"]}"
    "{\"kind\":\"categorical-membership\",\"acceptedValues\":[\"z\",\"a\"]}"

ordinalJsonWithSteps :: Text -> Text
ordinalJsonWithSteps steps =
  readinessJson
    "{\"kind\":\"ordinal\",\"scaleId\":\"scale\",\"orderedLevels\":[\"high\",\"low\"],\"effectDirection\":\"decrease\"}"
    "{\"kind\":\"ordinal\",\"scaleId\":\"scale\",\"level\":\"high\"}"
    ("{\"kind\":\"ordinal-steps\",\"minimumDirectionAdjustedSteps\":"
       <> steps
       <> "}")
    "{\"kind\":\"ordinal-threshold\",\"comparison\":\"at-most-rank\",\"scaleId\":\"scale\",\"targetLevel\":\"low\"}"

readinessJson :: Text -> Text -> Text -> Text -> Text
readinessJson domain baseline effect target =
  Text.concat
    [ "{\"type\":\"ReadinessInput\","
    , "\"readinessCheckedAt\":\"2026-01-01T00:00:02Z\","
    , "\"kpiDefinition\":{\"kpi\":\"kpi\",\"domain\":"
    , domain
    , ",\"measurementMethod\":\"method\",\"interpretation\":\"interpretation\"},"
    , "\"plannedStart\":{\"intervention\":\"intervention\",\"plannedStartAt\":\"2026-01-01T00:00:03Z\"},"
    , "\"evidencePlan\":{\"trace\":"
    , traceJson
    , ",\"baseline\":{\"observedAt\":\"2026-01-01T00:00:01Z\",\"source\":\"baseline-source\",\"value\":"
    , baseline
    , "},\"effectCriterion\":"
    , effect
    , ",\"targetCriterion\":"
    , target
    , ",\"targetDueAt\":\"2026-01-01T00:00:04Z\",\"source\":\"plan-source\",\"planEstablishedAt\":\"2026-01-01T00:00:00Z\"}}"
    ]

traceJson :: Text
traceJson =
  "{\"graphIdentity\":\"graph\",\"bindings\":{"
    <> Text.intercalate
         ","
         [ "\"vision\":\"vision\""
         , "\"strategy\":\"strategy\""
         , "\"need\":\"need\""
         , "\"intervention\":\"intervention\""
         , "\"measure\":\"measure\""
         , "\"situation\":\"situation\""
         , "\"visionObjective\":\"vision-objective\""
         , "\"strategyDriver\":\"strategy-driver\""
         , "\"strategyObjective\":\"strategy-objective\""
         , "\"strategyAction\":\"strategy-action\""
         , "\"strategyKeyResult\":\"strategy-key-result\""
         , "\"needDriver\":\"need-driver\""
         , "\"needObjective\":\"need-objective\""
         , "\"interventionAction\":\"intervention-action\""
         , "\"interventionKeyResult\":\"intervention-key-result\""
         , "\"measurePerformanceDimension\":\"performance-dimension\""
         , "\"measureKpi\":\"kpi\""
         , "\"situationAnchor\":\"anchor\""
         ]
    <> "}}"
