{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric.Natural (Natural)
import qualified O2I.Assessment as Assessment
import qualified O2I.Assessment.Decode as Decode
import qualified O2I.Assessment.Eval as Eval
import qualified O2I.Assessment.Internal as Internal
import O2I.Core.Contract (CoreQualifiedEndpointId, coreRuleIdText)
import O2I.Core.Graph.Commitment (Commitment(Asserted))
import O2I.Core.Graph.Observation.Internal
  ( CarrierObservation(..)
  , ContextualizationObservation(..)
  , RelationObservation(..)
  , ScopedGraphOccurrence(..)
  )
import O2I.Core.Identity
  ( ModelIdentity
  , ModelOccurrence
  , OccurrenceIdentity
  , buildModelIdentityIndex
  , modelIdentity
  , modelOccurrence
  , modelOccurrenceIdentity
  , occurrenceIdentity
  )
import O2I.Core.Identity.Internal (SelectedViewScope, withSelectedViewScope)
import O2I.Input.Internal.Text (canonicalizeFachlicheText)
import O2I.Input.Internal.Types
  ( BoundSupplementalInputs(..)
  , FachlicheText(..)
  , StrategyAnchoring(..)
  , StrategyFormulationInput(..)
  , SupplementalInput(..)
  , SupplementalInputOrdinal(..)
  , SupplementalInputSet(..)
  )
import qualified O2I.Readiness as Readiness
import qualified O2I.Readiness.Internal as ReadinessInternal
import qualified O2I.Semantics as Semantics
import O2I.Semantics.Vocabulary (endpointStrategyPrinciple, tokenGuides)
import O2I.Structure.Internal (WellFormedGraph(..))
import O2I.Trace
  ( TraceVariable(..)
  , traceIdentityBinding
  , traceIdentityGraphIdentity
  )
import O2I.Trace.Grammar
  ( TraceOwnershipSlot
  , TraceRelationSlot
  , traceOwnershipSlotId
  , traceOwnershipSlotVariables
  , traceOwnershipSlots
  , traceRelationSlotId
  , traceRelationSlotToken
  , traceRelationSlotVariables
  , traceRelationSlots
  , traceVariableEndpoint
  , traceVariableId
  , traceVariables
  )
import qualified O2I.Trace.Internal as TraceInternal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core Assessment"
    [ testCase "closes the exact fifteen-rule inventory" exactRuleInventory
    , testCase "decodes the exact AssessmentBundleInput schema" validDecode
    , testCase
        "canonical observation identity failures remain decoder evidence"
        observationIdentityDecodeBoundary
    , testCase
        "prepares and assesses from reconstructed same-invocation evidence"
        prepareSubjectAvailable
    , testCase
        "reports unavailable when same-invocation semantics lacks the strategy proof"
        prepareSubjectUnavailable
    , testCase
        "collection coverage failure suppresses every item"
        coverageSuppression
    , testCase
        "duplicate observation identity suppresses every item"
        uniquenessSuppression
    , testCase
        "actual-start slot mismatch uses the owning cardinality rule"
        actualStartBinding
    , testCase
        "collection chronology suppresses every item"
        chronologySuppression
    , testCase
        "mixed invalid and assessed outcomes preserve source order"
        mixedSourceOrder
    , testCase
        "covers every direct observation validation rule branch"
        directItemRuleBranches
    , testCase
        "effect and target results remain independent"
        independentEffectAndTarget
    , testCase
        "relative effect with zero baseline is explicitly not assessable"
        relativeZeroBaseline
    , testCase
        "negative baselines use their absolute denominator"
        negativeBaseline
    , testCase
        "ordinal and categorical formulae are closed"
        closedDomainFormulae
    , testCase "every assessed item retains both fixed limitations" limitations
    , testCase
        "all valid items promote proof independent of criterion satisfaction"
        proofPromotion
    , testCase
        "private counters cover valid and invalid addressed item work"
        workCounters
    , testCase
        "domain and criterion indexes are built once per collection"
        indexWork
    , testCase
        "isolates input, trace, criteria, and retention work counters"
        isolatedWorkCounters
    ]

exactRuleInventory :: IO ()
exactRuleInventory =
  map
    (coreRuleIdText . Internal.assessmentRuleId)
    ([minBound .. maxBound] :: [Internal.AssessmentRule])
    @?= [ "core.assessment.actual-start.cardinality"
        , "core.assessment.actual-start.chronology"
        , "core.assessment.anchor.identity"
        , "core.assessment.chronology.observation"
        , "core.assessment.coverage.trace-observation"
        , "core.assessment.effect-criterion.apply"
        , "core.assessment.identity.observation"
        , "core.assessment.identity.observation-uniqueness"
        , "core.assessment.kpi.identity"
        , "core.assessment.limitations.required"
        , "core.assessment.readiness.reconstructed-proof"
        , "core.assessment.source.nonempty"
        , "core.assessment.target-criterion.apply"
        , "core.assessment.trace.identity"
        , "core.assessment.value-domain.observation"
        ]

validDecode :: IO ()
validDecode = do
  bundle <- decoded (bundleJson quantitativeReadiness [observation "20" "04"])
  Assessment.assessmentInputOrdinalValue
    (Assessment.assessmentBundleInputOrdinal bundle)
    @?= 7
  Readiness.utcTimestampText (Assessment.assessmentAssessedAt bundle)
    @?= "2026-01-01T00:06:00Z"
  map
    (Assessment.observationOrdinalValue . Assessment.observationOrdinal)
    (Assessment.assessmentObservations bundle)
    @?= [0]
  case Assessment.assessmentObservations bundle of
    [item] ->
      Assessment.assessmentBundleTraceIdentity bundle
        @?= Assessment.observationTraceIdentity item
    _ -> fail "decoded bundle did not retain exactly one observation"

observationIdentityDecodeBoundary :: IO ()
observationIdentityDecodeBoundary = do
  inputDefectKinds
    (decode
       (bundleJson
          quantitativeReadiness
          [ Text.replace
              "2026-01-01T00:04:00Z"
              "not-a-time"
              (observation "20" "04")
          ]))
    @?= [ReadinessInternal.EvidenceInputScalarGrammarInvalid]
  inputDefectKinds
    (decode
       (bundleJson
          quantitativeReadiness
          [Text.replace "\"measureKpi\":\"kpi\"," "" (observation "20" "04")]))
    @?= [ReadinessInternal.EvidenceInputRequiredMemberMissing]

prepareSubjectAvailable :: IO ()
prepareSubjectAvailable = do
  bundle <- decoded (bundleJson quantitativeReadiness [observation "20" "04"])
  withAssessmentFixture bundle True $ \model semantics bound ->
    Assessment.foldAssessmentSubjectAssessment
      (\_ _ reasons ->
         fail
           ("same-invocation subject unexpectedly unavailable: "
              ++ show (NonEmpty.length reasons)))
      (\subject -> do
         Assessment.assessmentSubjectGraphIdentity subject
           @?= traceIdentityGraphIdentity
                 (Assessment.assessmentBundleTraceIdentity bundle)
         Assessment.assessmentSubjectTraceIdentity subject
           @?= Assessment.assessmentBundleTraceIdentity bundle
         Assessment.assessmentDisposition (Assessment.assessEvidence subject)
           @?= Assessment.AssessmentEvidenceAssessedDisposition)
      (Assessment.prepareAssessmentSubject model semantics bound)

prepareSubjectUnavailable :: IO ()
prepareSubjectUnavailable = do
  bundle <- decoded (bundleJson quantitativeReadiness [observation "20" "04"])
  withAssessmentFixture bundle False $ \model semantics bound ->
    Assessment.foldAssessmentSubjectAssessment
      (\graph trace reasons -> do
         graph
           @?= traceIdentityGraphIdentity
                 (Assessment.assessmentBundleTraceIdentity bundle)
         trace @?= Assessment.assessmentBundleTraceIdentity bundle
         map
           (Assessment.foldAssessmentSubjectUnavailableReason
              (const True)
              (\_ _ -> False))
           (NonEmpty.toList reasons)
           @?= [True])
      (\_ -> fail "missing same-invocation strategy proof became available")
      (Assessment.prepareAssessmentSubject model semantics bound)

coverageSuppression :: IO ()
coverageSuppression = do
  (result, work) <- evaluated quantitativeReadiness []
  Assessment.assessmentDisposition result
    @?= Assessment.AssessmentInputInvalidDisposition
  diagnosticRules (Assessment.assessmentCollectionDiagnostics result)
    @?= ["core.assessment.coverage.trace-observation"]
  length (Assessment.assessmentObservationResults result) @?= 0
  Internal.assessmentTransitions work @?= 0
  Internal.assessmentAddressedObservationSupport work @?= 0

uniquenessSuppression :: IO ()
uniquenessSuppression = do
  let duplicate = observation "20" "04"
  (result, work) <- evaluated quantitativeReadiness [duplicate, duplicate]
  diagnosticRules (Assessment.assessmentCollectionDiagnostics result)
    @?= ["core.assessment.identity.observation-uniqueness"]
  length (Assessment.assessmentObservationResults result) @?= 0
  Internal.assessmentTransitions work @?= 0

actualStartBinding :: IO ()
actualStartBinding = do
  bundle <-
    decoded
      (Text.replace
         "\"actualStart\":{\"intervention\":\"intervention\""
         "\"actualStart\":{\"intervention\":\"other-intervention\""
         (bundleJson quantitativeReadiness [observation "20" "04"]))
  let result = Assessment.assessEvidence (subjectFrom bundle)
  diagnosticRules (Assessment.assessmentCollectionDiagnostics result)
    @?= ["core.assessment.actual-start.cardinality"]
  length (Assessment.assessmentObservationResults result) @?= 0

chronologySuppression :: IO ()
chronologySuppression = do
  bundle <-
    decoded
      (Text.replace
         "\"actualStartAt\":\"2026-01-01T00:00:03Z\""
         "\"actualStartAt\":\"2026-01-01T00:00:02Z\""
         (bundleJson quantitativeReadiness [observation "20" "04"]))
  let result = Assessment.assessEvidence (subjectFrom bundle)
  diagnosticRules (Assessment.assessmentCollectionDiagnostics result)
    @?= ["core.assessment.actual-start.chronology"]
  length (Assessment.assessmentObservationResults result) @?= 0

mixedSourceOrder :: IO ()
mixedSourceOrder = do
  let foreignObservation =
        Text.replace
          "\"measureKpi\":\"kpi\""
          "\"measureKpi\":\"foreign-kpi\""
          (observation "18" "05")
  (result, work) <-
    evaluated
      quantitativeReadiness
      [observation "20" "04", foreignObservation, observation "21" "06"]
  Assessment.assessmentDisposition result
    @?= Assessment.AssessmentObservationsInvalidDisposition
  let outcomes = Assessment.assessmentObservationResults result
  map outcomeOrdinal outcomes @?= [0, 1, 2]
  map outcomeTag outcomes @?= ["assessed", "invalid", "assessed"]
  case outcomes of
    [_, middle, _] ->
      itemDiagnosticRules middle
        @?= ["core.assessment.kpi.identity", "core.assessment.trace.identity"]
    _ -> fail "mixed result lost source items"
  Internal.assessmentSubmittedObservations work @?= 3
  Internal.assessmentAddressedObservationSupport work @?= 9
  Internal.assessmentTransitions work @?= 3

directItemRuleBranches :: IO ()
directItemRuleBranches = do
  validBundle <-
    decoded (bundleJson quantitativeReadiness [observation "20" "04"])
  let sourceResult =
        fst
          (Eval.assessEvidenceWithWorkInternal
             (subjectFrom (withEmptyObservationSource validBundle)))
  itemDiagnosticRules (onlyOutcome sourceResult)
    @?= ["core.assessment.source.nonempty"]
  let early =
        Text.replace
          "2026-01-01T00:04:00Z"
          "2026-01-01T00:00:03Z"
          (observation "20" "04")
  (chronologyResult, _) <- evaluated quantitativeReadiness [early]
  itemDiagnosticRules (onlyOutcome chronologyResult)
    @?= ["core.assessment.chronology.observation"]
  let wrongUnit =
        observationValue
          "{\"kind\":\"quantitative\",\"value\":\"20\",\"unit\":\"seconds\"}"
          "04"
  (domainResult, _) <- evaluated quantitativeReadiness [wrongUnit]
  itemDiagnosticRules (onlyOutcome domainResult)
    @?= ["core.assessment.value-domain.observation"]
  let foreignAnchor =
        Text.replace
          "\"situationAnchor\":\"anchor\""
          "\"situationAnchor\":\"foreign-anchor\""
          (observation "20" "04")
  (anchorResult, _) <- evaluated quantitativeReadiness [foreignAnchor]
  itemDiagnosticRules (onlyOutcome anchorResult)
    @?= ["core.assessment.anchor.identity", "core.assessment.trace.identity"]

independentEffectAndTarget :: IO ()
independentEffectAndTarget = do
  (effectful, _) <- evaluated quantitativeReadiness [observation "17" "04"]
  assessedKinds (onlyOutcome effectful)
    @?= ( Assessment.EffectSatisfiedKind
        , Assessment.TargetNotSatisfiedInObservationKind)
  (afterDue, _) <- evaluated quantitativeReadiness [observation "21" "06"]
  assessedKinds (onlyOutcome afterDue)
    @?= ( Assessment.EffectSatisfiedKind
        , Assessment.TargetSatisfiedInObservationAfterDueKind)
  (neither, _) <- evaluated quantitativeReadiness [observation "12" "04"]
  assessedKinds (onlyOutcome neither)
    @?= ( Assessment.EffectNotSatisfiedKind
        , Assessment.TargetNotSatisfiedInObservationKind)

relativeZeroBaseline :: IO ()
relativeZeroBaseline = do
  let readiness =
        readinessJson
          quantitativeDomain
          (quantitativeValue "0")
          "{\"kind\":\"quantitative-relative\",\"minimumDirectionAdjustedRatio\":\"0.1\"}"
          quantitativeTarget
  (result, _) <- evaluated readiness [observation "1" "04"]
  fst (assessedKinds (onlyOutcome result))
    @?= Assessment.EffectNotAssessableZeroBaselineKind

negativeBaseline :: IO ()
negativeBaseline = do
  let readiness =
        readinessJson
          quantitativeDomain
          (quantitativeValue "-10")
          "{\"kind\":\"quantitative-relative\",\"minimumDirectionAdjustedRatio\":\"0.5\"}"
          quantitativeTarget
  (result, _) <-
    evaluated readiness [observationValue (quantitativeValue "-5") "04"]
  fst (assessedKinds (onlyOutcome result)) @?= Assessment.EffectSatisfiedKind

closedDomainFormulae :: IO ()
closedDomainFormulae = do
  let ordinalReadiness =
        readinessJson
          "{\"kind\":\"ordinal\",\"scaleId\":\"scale\",\"orderedLevels\":[\"low\",\"mid\",\"high\"],\"effectDirection\":\"increase\"}"
          "{\"kind\":\"ordinal\",\"scaleId\":\"scale\",\"level\":\"low\"}"
          "{\"kind\":\"ordinal-steps\",\"minimumDirectionAdjustedSteps\":2}"
          "{\"kind\":\"ordinal-threshold\",\"comparison\":\"at-least-rank\",\"scaleId\":\"scale\",\"targetLevel\":\"high\"}"
      ordinalObservation =
        observationValue
          "{\"kind\":\"ordinal\",\"scaleId\":\"scale\",\"level\":\"high\"}"
          "04"
  (ordinalResult, _) <- evaluated ordinalReadiness [ordinalObservation]
  assessedKinds (onlyOutcome ordinalResult)
    @?= ( Assessment.EffectSatisfiedKind
        , Assessment.TargetSatisfiedInObservationByDueKind)
  let categoricalReadiness =
        readinessJson
          "{\"kind\":\"categorical\",\"admittedValues\":[\"a\",\"b\"]}"
          "{\"kind\":\"categorical\",\"value\":\"a\"}"
          "{\"kind\":\"categorical-transition\",\"acceptedValues\":[\"b\"]}"
          "{\"kind\":\"categorical-membership\",\"acceptedValues\":[\"b\"]}"
      categoricalObservation =
        observationValue "{\"kind\":\"categorical\",\"value\":\"b\"}" "04"
  (categoricalResult, _) <-
    evaluated categoricalReadiness [categoricalObservation]
  assessedKinds (onlyOutcome categoricalResult)
    @?= ( Assessment.EffectSatisfiedKind
        , Assessment.TargetSatisfiedInObservationByDueKind)

limitations :: IO ()
limitations = do
  (result, _) <- evaluated quantitativeReadiness [observation "20" "04"]
  let actual =
        Assessment.foldObservationAssessment
          (\_ _ -> error "expected assessed observation")
          (\_ _ _ values -> NonEmpty.toList values)
          (onlyOutcome result)
  actual
    @?= [ Assessment.CausalityNotEstablishedLimitation
        , Assessment.FirstTargetAttainmentTimeNotEstablishedLimitation
        ]

proofPromotion :: IO ()
proofPromotion = do
  (result, _) <- evaluated quantitativeReadiness [observation "12" "04"]
  Assessment.assessmentDisposition result
    @?= Assessment.AssessmentEvidenceAssessedDisposition
  case Assessment.evidenceAssessedProof result of
    Nothing -> fail "valid non-satisfying evidence did not promote"
    Just proof -> Assessment.evidenceAssessedObservationCount proof @?= 1

workCounters :: IO ()
workCounters = do
  let observations count =
        [ observation (Text.pack (show (20 + index))) (twoDigits (4 + index))
        | index <- [0 .. count - 1]
        ]
  (_, small) <-
    evaluatedWithAssessmentTime 59 quantitativeReadiness (observations 2)
  (_, large) <-
    evaluatedWithAssessmentTime 59 quantitativeReadiness (observations 50)
  Internal.assessmentSubmittedObservations large
    - Internal.assessmentSubmittedObservations small @?= 48
  Internal.assessmentAddressedObservationSupport large
    - Internal.assessmentAddressedObservationSupport small @?= 3 * 48
  Internal.assessmentTransitions large
    - Internal.assessmentTransitions small @?= 48
  assertBool
    "source-ordered item keys contribute their exact scalar lengths"
    (Internal.assessmentOrderingKeyScalars large
       > Internal.assessmentOrderingKeyScalars small)
  let foreignObservation =
        Text.replace
          "\"situationAnchor\":\"anchor\""
          "\"situationAnchor\":\"foreign-anchor\""
          (observation "20" "04")
  (_, invalidWork) <- evaluated quantitativeReadiness [foreignObservation]
  Internal.assessmentSubmittedObservations invalidWork @?= 1
  Internal.assessmentAddressedObservationSupport invalidWork @?= 3
  Internal.assessmentTransitions invalidWork @?= 1
  let (_, shortKeyWork) = malformedKeyWork "x"
      (_, longKeyWork) = malformedKeyWork (Text.replicate 1024 "x")
  Internal.assessmentOrderingEntries longKeyWork
    @?= Internal.assessmentOrderingEntries shortKeyWork
  assertBool
    "long decoder keys contribute visited and retained scalar work"
    (Internal.assessmentOrderingKeyScalars longKeyWork
       - Internal.assessmentOrderingKeyScalars shortKeyWork
       >= 1023)
  where
    malformedKeyWork key =
      Decode.decodeAssessmentBundleInputWithWorkInternal
        (Internal.AssessmentInputOrdinal 7)
        (encode ("{\"type\":\"AssessmentBundleInput\",\"" <> key <> "\":0}"))

indexWork :: IO ()
indexWork = do
  (_, smallOne) <-
    evaluated
      (categoricalIndexReadiness 2)
      [categoricalIndexObservation "v1" "04"]
  (_, largeOne) <-
    evaluated
      (categoricalIndexReadiness 50)
      [categoricalIndexObservation "v1" "04"]
  Internal.assessmentIndexEntries largeOne
    - Internal.assessmentIndexEntries smallOne @?= 3 * 48
  (_, largeMany) <-
    evaluatedWithAssessmentTime
      59
      (categoricalIndexReadiness 50)
      [ categoricalIndexObservation "v1" (twoDigits (4 + index))
      | index <- [0 .. 40]
      ]
  Internal.assessmentIndexEntries largeMany
    - Internal.assessmentIndexEntries largeOne @?= 40
  Internal.assessmentAddressedObservationSupport largeMany
    - Internal.assessmentAddressedObservationSupport largeOne @?= 3 * 40

categoricalIndexReadiness :: Int -> Text
categoricalIndexReadiness count =
  readinessJson
    ("{\"kind\":\"categorical\",\"admittedValues\":" <> values <> "}")
    "{\"kind\":\"categorical\",\"value\":\"v0\"}"
    ("{\"kind\":\"categorical-transition\",\"acceptedValues\":"
       <> accepted
       <> "}")
    ("{\"kind\":\"categorical-membership\",\"acceptedValues\":"
       <> accepted
       <> "}")
  where
    quotedValues =
      ["\"v" <> Text.pack (show index) <> "\"" | index <- [0 .. count - 1]]
    values = "[" <> Text.intercalate "," quotedValues <> "]"
    accepted = "[" <> Text.intercalate "," (drop 1 quotedValues) <> "]"

categoricalIndexObservation :: Text -> Text -> Text
categoricalIndexObservation value minute =
  observationValue
    ("{\"kind\":\"categorical\",\"value\":\"" <> value <> "\"}")
    minute

isolatedWorkCounters :: IO ()
isolatedWorkCounters = do
  let sourceBundle source =
        Text.replace
          "\"source\":\"observation-source\""
          ("\"source\":\"" <> source <> "\"")
          (bundleJson quantitativeReadiness [observation "20" "04"])
      decodeWork readiness =
        snd
          (Decode.decodeAssessmentBundleInputWithWorkInternal
             (Internal.AssessmentInputOrdinal 7)
             (encode
                (bundleJson readiness [categoricalIndexObservation "v1" "04"])))
      smallInput = decodeWork (categoricalIndexReadiness 2)
      largeInput = decodeWork (categoricalIndexReadiness 50)
  assertBool
    "X_a explicit occurrences scale without diagnostic retention"
    (Internal.assessmentInputOccurrences largeInput
       > Internal.assessmentInputOccurrences smallInput)
  Internal.assessmentRetainedEntries largeInput @?= 0
  Internal.assessmentRetainedEntries smallInput @?= 0
  bundle <- decoded (sourceBundle "observation-source")
  let evaluatedCounts support criteria =
        snd
          (Eval.assessEvidenceWithWorkInternal
             (subjectFromCounts support criteria bundle))
      base = evaluatedCounts 41 17
      traceScaled = evaluatedCounts 4101 17
      criteriaScaled = evaluatedCounts 41 1700
  Internal.assessmentTraceSupportOccurrences traceScaled
    - Internal.assessmentTraceSupportOccurrences base @?= 4060
  Internal.assessmentReadinessCriteriaEvaluated traceScaled
    @?= Internal.assessmentReadinessCriteriaEvaluated base
  Internal.assessmentReadinessCriteriaEvaluated criteriaScaled
    - Internal.assessmentReadinessCriteriaEvaluated base @?= 1683
  Internal.assessmentTraceSupportOccurrences criteriaScaled
    @?= Internal.assessmentTraceSupportOccurrences base
  let invalidObservation =
        Text.replace
          "2026-01-01T00:04:00Z"
          "2026-01-01T00:00:03Z"
          (Text.replace
             "\"situationAnchor\":\"anchor\""
             "\"situationAnchor\":\"foreign-anchor\""
             (observationValue
                "{\"kind\":\"quantitative\",\"value\":\"20\",\"unit\":\"seconds\"}"
                "04"))
  decodedInvalidBundle <-
    decoded (bundleJson quantitativeReadiness [invalidObservation])
  let invalidBundle = withEmptyObservationSource decodedInvalidBundle
      invalidWork =
        snd
          (Eval.assessEvidenceWithWorkInternal
             (subjectFromCounts 41 17 invalidBundle))
  Internal.assessmentSubmittedObservations invalidWork
    @?= Internal.assessmentSubmittedObservations base
  Internal.assessmentAddressedObservationSupport invalidWork
    @?= Internal.assessmentAddressedObservationSupport base
  Internal.assessmentTransitions invalidWork
    @?= Internal.assessmentTransitions base
  assertBool
    "retention scales with independent item defects; D_a coupling is structural"
    (Internal.assessmentRetainedEntries invalidWork
       > Internal.assessmentRetainedEntries base)

evaluated ::
     Text
  -> [Text]
  -> IO (Internal.AssessmentResult scope, Internal.AssessmentWork)
evaluated = evaluatedWithAssessmentTime 6

evaluatedWithAssessmentTime ::
     Int
  -> Text
  -> [Text]
  -> IO (Internal.AssessmentResult scope, Internal.AssessmentWork)
evaluatedWithAssessmentTime hour readiness observations = do
  bundle <- decoded (bundleJsonAt hour readiness observations)
  pure (Eval.assessEvidenceWithWorkInternal (subjectFrom bundle))

subjectFrom ::
     Internal.AssessmentBundleInput -> Internal.AssessmentSubject scope
subjectFrom = subjectFromCounts 41 17

subjectFromCounts ::
     Int
  -> Int
  -> Internal.AssessmentBundleInput
  -> Internal.AssessmentSubject scope
subjectFromCounts support criteria bundle =
  Internal.AssessmentSubject ready bound support criteria
  where
    readiness = Internal.storedAssessmentReadiness bundle
    trace =
      ReadinessInternal.storedEvidenceTrace
        (ReadinessInternal.storedEvidencePlan readiness)
    graph = traceIdentityGraphIdentity trace
    strategy = traceIdentityBinding trace StrategyVariable
    promoted = TraceInternal.PromotedTraceableEffectModel graph trace strategy
    ready = ReadinessInternal.EvidenceReadyProof graph trace promoted readiness
    boundReadiness =
      ReadinessInternal.BoundReadinessInput
        readiness
        (TraceInternal.BoundTraceIdentity trace)
    bound = Internal.BoundAssessmentBundleInput bundle boundReadiness

withEmptyObservationSource ::
     Internal.AssessmentBundleInput -> Internal.AssessmentBundleInput
withEmptyObservationSource bundle =
  case Internal.storedObservations bundle of
    observationItem:remaining ->
      Internal.AssessmentBundleInput
        (Internal.storedAssessmentOrdinal bundle)
        (Internal.storedAssessmentReadiness bundle)
        (Internal.storedAssessedAt bundle)
        (Internal.storedActualStart bundle)
        (emptySource observationItem : remaining)
    [] -> error "defensive source fixture requires one observation"
  where
    emptySource observationItem =
      Internal.Observation
        (Internal.storedObservationOrdinal observationItem)
        (Internal.storedObservationTrace observationItem)
        (Internal.storedObservedAt observationItem)
        (ReadinessInternal.CanonicalText "")
        (Internal.storedObservationValue observationItem)

withAssessmentFixture ::
     Internal.AssessmentBundleInput
  -> Bool
  -> (forall scope. Semantics.SemanticallyValidModel scope -> Semantics.SemanticAssessment
                                                                scope -> Internal.BoundAssessmentBundleInput
                                                                           scope -> IO
                                                                                      ())
  -> IO ()
withAssessmentFixture bundle includeStrategy inspect =
  case buildModelIdentityIndex (selectedViewOccurrence : modelOccurrences) of
    Left defects ->
      fail ("Assessment identity fixture rejected: " ++ show defects)
    Right index ->
      case withSelectedViewScope
             index
             selectedViewOccurrence
             (map modelOccurrenceIdentity modelOccurrences)
             buildScoped of
        Left defects ->
          fail ("Assessment selected-View fixture rejected: " ++ show defects)
        Right assertion -> assertion
  where
    trace = Assessment.assessmentBundleTraceIdentity bundle
    modelOccurrences = assessmentModelOccurrences trace
    buildScoped selectedScope =
      let graph = assessmentGraph selectedScope trace
          inputs =
            BoundSupplementalInputs
              (SupplementalInputSet
                 (if includeStrategy
                    then [ StrategyFormulationSupplement
                             ()
                             (SupplementalInputOrdinal 0)
                             (strategyFormulation trace)
                         ]
                    else []))
              Set.empty
          semantics = Semantics.assessSemantics graph inputs
       in case Semantics.semanticallyValidModel semantics of
            Nothing ->
              Semantics.foldSemanticAssessment
                (\defects ->
                   fail
                     ("Assessment semantic fixture was rejected: "
                        ++ show
                             (map
                                (coreRuleIdText
                                   . Semantics.semanticDiagnosticRule)
                                (NonEmpty.toList defects))))
                (fail "rejected fixture unexpectedly reported unavailable")
                (const (fail "rejected fixture unexpectedly retained a model"))
                semantics
            Just model ->
              Assessment.foldAssessmentInputBinding
                (\_ defects ->
                   fail
                     ("Assessment binding fixture rejected: "
                        ++ show (NonEmpty.length defects)))
                (inspect model semantics)
                (Assessment.bindAssessmentBundleInput graph bundle)

assessmentGraph ::
     SelectedViewScope scope
  -> TraceInternal.TraceIdentity
  -> WellFormedGraph scope
assessmentGraph selectedScope trace =
  WellFormedGraph selectedScope carriers ownerships relations []
  where
    scoped = ScopedGraphOccurrence
    carriers =
      [ CarrierObservation
        (scoped (carrierOccurrence variable))
        (traceIdentityBinding trace variable)
        (variableEndpoint variable)
        Asserted
      | variable <- traceVariables
      ]
        <> [ CarrierObservation
               (scoped strategyPrincipleOccurrence)
               strategyPrincipleIdentity
               endpointStrategyPrinciple
               Asserted
           ]
    relations =
      [ RelationObservation
        (scoped (relationOccurrence slot))
        (scoped (carrierOccurrence source))
        (traceRelationSlotToken slot)
        (scoped (carrierOccurrence target))
        Asserted
      | slot <- traceRelationSlots
      , let (source, target) = traceRelationSlotVariables slot
      ]
        <> [ RelationObservation
               (scoped strategyPrincipleGuidesOccurrence)
               (scoped strategyPrincipleOccurrence)
               tokenGuides
               (scoped (carrierOccurrence StrategyActionVariable))
               Asserted
           ]
    ownerships =
      [ ContextualizationObservation
        (scoped (ownershipOccurrence slot))
        (scoped (carrierOccurrence owner))
        (scoped (carrierOccurrence member))
        Asserted
      | slot <- traceOwnershipSlots
      , let (owner, member) = traceOwnershipSlotVariables slot
      ]
        <> [ ContextualizationObservation
               (scoped strategyPrincipleOwnershipOccurrence)
               (scoped (carrierOccurrence StrategyVariable))
               (scoped strategyPrincipleOccurrence)
               Asserted
           ]

assessmentModelOccurrences :: TraceInternal.TraceIdentity -> [ModelOccurrence]
assessmentModelOccurrences trace =
  [ modelOccurrence
    (carrierOccurrence variable)
    (traceIdentityBinding trace variable)
  | variable <- traceVariables
  ]
    <> [ modelOccurrence strategyPrincipleOccurrence strategyPrincipleIdentity
       , fixtureOccurrence
           strategyPrincipleOwnershipOccurrence
           "ownership-strategy-principle"
       , fixtureOccurrence
           strategyPrincipleGuidesOccurrence
           "relation-strategy-principle-guides-action"
       ]
    <> [ fixtureOccurrence
         (relationOccurrence slot)
         ("relation-" <> traceRelationSlotId slot)
       | slot <- traceRelationSlots
       ]
    <> [ fixtureOccurrence
         (ownershipOccurrence slot)
         ("ownership-" <> traceOwnershipSlotId slot)
       | slot <- traceOwnershipSlots
       ]

selectedViewOccurrence :: ModelOccurrence
selectedViewOccurrence =
  fixtureOccurrence (occurrenceValue "selected-view") "graph"

carrierOccurrence :: TraceVariable -> OccurrenceIdentity
carrierOccurrence variable =
  occurrenceValue ("carrier-" <> traceVariableId variable)

relationOccurrence :: TraceRelationSlot -> OccurrenceIdentity
relationOccurrence slot =
  occurrenceValue ("relation-" <> traceRelationSlotId slot)

ownershipOccurrence :: TraceOwnershipSlot -> OccurrenceIdentity
ownershipOccurrence slot =
  occurrenceValue ("ownership-" <> traceOwnershipSlotId slot)

strategyPrincipleOccurrence :: OccurrenceIdentity
strategyPrincipleOccurrence = occurrenceValue "carrier-strategy-principle"

strategyPrincipleOwnershipOccurrence :: OccurrenceIdentity
strategyPrincipleOwnershipOccurrence =
  occurrenceValue "ownership-strategy-principle"

strategyPrincipleGuidesOccurrence :: OccurrenceIdentity
strategyPrincipleGuidesOccurrence =
  occurrenceValue "relation-strategy-principle-guides-action"

strategyPrincipleIdentity :: ModelIdentity
strategyPrincipleIdentity = modelIdentityValue "strategy-principle"

variableEndpoint :: TraceVariable -> CoreQualifiedEndpointId
variableEndpoint variable =
  case traceVariableEndpoint variable of
    endpoint:_ -> endpoint
    [] -> error "Trace variable fixture lost its admitted endpoint"

fixtureOccurrence :: OccurrenceIdentity -> Text -> ModelOccurrence
fixtureOccurrence occurrenceName modelName =
  modelOccurrence occurrenceName (modelIdentityValue modelName)

occurrenceValue :: Text -> OccurrenceIdentity
occurrenceValue value =
  case occurrenceIdentity value of
    Left defect -> error (show defect)
    Right identity -> identity

modelIdentityValue :: Text -> ModelIdentity
modelIdentityValue value =
  case modelIdentity value of
    Left defect -> error (show defect)
    Right identity -> identity

strategyFormulation :: TraceInternal.TraceIdentity -> StrategyFormulationInput
strategyFormulation trace =
  StrategyFormulationInput
    { formulationStrategy = binding StrategyVariable
    , formulationScope = fachliche :| []
    , formulationAnchoring =
        StrategyAnchoring
          fachliche
          fachliche
          fachliche
          (fachliche :| [])
          (fachliche :| [])
          fachliche
    , formulationDerivedGuardrails = fachliche :| []
    , formulationDiagnosis = binding StrategyDriverVariable
    , formulationIntent = binding StrategyObjectiveVariable
    , formulationGuidingPolicy = strategyPrincipleIdentity
    , formulationPositioning = fachliche :| []
    , formulationTradeOffs = fachliche :| []
    , formulationActions = binding StrategyActionVariable :| []
    , formulationKeyResults = binding StrategyKeyResultVariable :| []
    , formulationFitRationale = fachliche :| []
    }
  where
    binding = traceIdentityBinding trace
    fachliche =
      FachlicheText
        (case canonicalizeFachlicheText "fixture" of
           Left defect -> error (show defect)
           Right value -> value)

onlyOutcome ::
     Internal.AssessmentResult scope -> Internal.ObservationAssessment scope
onlyOutcome result =
  case Assessment.assessmentObservationResults result of
    [outcome] -> outcome
    _ -> error "expected exactly one observation outcome"

outcomeOrdinal :: Internal.ObservationAssessment scope -> Natural
outcomeOrdinal =
  Assessment.foldObservationAssessment
    (\item _ -> ordinal item)
    (\item _ _ _ -> ordinal item)
  where
    ordinal = Assessment.observationOrdinalValue . Assessment.observationOrdinal

outcomeTag :: Internal.ObservationAssessment scope -> Text
outcomeTag =
  Assessment.foldObservationAssessment
    (\_ _ -> "invalid")
    (\_ _ _ _ -> "assessed")

itemDiagnosticRules :: Internal.ObservationAssessment scope -> [Text]
itemDiagnosticRules =
  Assessment.foldObservationAssessment
    (\_ defects -> diagnosticRules (NonEmpty.toList defects))
    (\_ _ _ _ -> [])

assessedKinds ::
     Internal.ObservationAssessment scope
  -> (Assessment.EffectResultKind, Assessment.TargetAttainmentKind)
assessedKinds =
  Assessment.foldObservationAssessment
    (\_ _ -> error "expected assessed observation")
    (\_ effect target _ ->
       ( Assessment.effectResultKind effect
       , Assessment.targetAttainmentKind target))

diagnosticRules :: [Assessment.AssessmentDiagnosticEvidence scope] -> [Text]
diagnosticRules = map (coreRuleIdText . Assessment.assessmentDiagnosticRule)

decoded :: Text -> IO Internal.AssessmentBundleInput
decoded source =
  case decode source of
    Left defects -> fail (show defects)
    Right bundle -> pure bundle

decode ::
     Text
  -> Either
       (NonEmpty Internal.AssessmentInputDefect)
       Internal.AssessmentBundleInput
decode =
  Assessment.decodeAssessmentBundleInput (Assessment.assessmentInputOrdinal 7)
    . encode

inputDefectKinds ::
     Either (NonEmpty Internal.AssessmentInputDefect) value
  -> [ReadinessInternal.EvidenceInputDefectKind]
inputDefectKinds result =
  case result of
    Left defects ->
      map Assessment.assessmentInputDefectKind (NonEmpty.toList defects)
    Right _ -> []

bundleJson :: Text -> [Text] -> Text
bundleJson = bundleJsonAt 6

bundleJsonAt :: Int -> Text -> [Text] -> Text
bundleJsonAt assessedHour readiness observations =
  Text.concat
    [ "{\"type\":\"AssessmentBundleInput\",\"readiness\":"
    , readiness
    , ",\"assessedAt\":\"2026-01-01T00:"
    , twoDigits assessedHour
    , ":00Z\",\"actualStart\":{\"intervention\":\"intervention\",\"actualStartAt\":\"2026-01-01T00:00:03Z\"},\"observations\":["
    , Text.intercalate "," observations
    , "]}"
    ]

observation :: Text -> Text -> Text
observation value = observationValue (quantitativeValue value)

observationValue :: Text -> Text -> Text
observationValue value minute =
  Text.concat
    [ "{\"trace\":"
    , traceJson
    , ",\"observedAt\":\"2026-01-01T00:"
    , minute
    , ":00Z\",\"source\":\"observation-source\",\"value\":"
    , value
    , "}"
    ]

quantitativeReadiness :: Text
quantitativeReadiness =
  readinessJson
    quantitativeDomain
    (quantitativeValue "10")
    "{\"kind\":\"quantitative-absolute\",\"minimumDirectionAdjustedDelta\":\"5\"}"
    quantitativeTarget

quantitativeDomain :: Text
quantitativeDomain =
  "{\"kind\":\"quantitative\",\"unit\":\"count\",\"effectDirection\":\"increase\"}"

quantitativeValue :: Text -> Text
quantitativeValue value =
  "{\"kind\":\"quantitative\",\"value\":\"" <> value <> "\",\"unit\":\"count\"}"

quantitativeTarget :: Text
quantitativeTarget =
  "{\"kind\":\"quantitative-threshold\",\"comparison\":\"at-least\",\"target\":\"20\",\"unit\":\"count\"}"

readinessJson :: Text -> Text -> Text -> Text -> Text
readinessJson domain baseline effect target =
  Text.concat
    [ "{\"type\":\"ReadinessInput\",\"readinessCheckedAt\":\"2026-01-01T00:00:02Z\",\"kpiDefinition\":{\"kpi\":\"kpi\",\"domain\":"
    , domain
    , ",\"measurementMethod\":\"method\",\"interpretation\":\"interpretation\"},\"plannedStart\":{\"intervention\":\"intervention\",\"plannedStartAt\":\"2026-01-01T00:00:03Z\"},\"evidencePlan\":{\"trace\":"
    , traceJson
    , ",\"baseline\":{\"observedAt\":\"2026-01-01T00:00:01Z\",\"source\":\"baseline-source\",\"value\":"
    , baseline
    , "},\"effectCriterion\":"
    , effect
    , ",\"targetCriterion\":"
    , target
    , ",\"targetDueAt\":\"2026-01-01T00:05:00Z\",\"source\":\"plan-source\",\"planEstablishedAt\":\"2026-01-01T00:00:00Z\"}}"
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

twoDigits :: Int -> Text
twoDigits value = Text.justifyRight 2 '0' (Text.pack (show value))

encode :: Text -> ByteString
encode = TextEncoding.encodeUtf8
