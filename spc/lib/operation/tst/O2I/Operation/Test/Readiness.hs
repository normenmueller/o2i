{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Readiness
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.IORef
import Data.JSON.JSONSchema (validateJSONSchema)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquisitionFailure
  , InputSource
  , fileInput
  )
import O2I.Operation.Acquisition.Internal (acquireWith)
import O2I.Operation.Command.Error (commandErrorCode, readinessCommandError)
import O2I.Operation.Command.Error.Machine
import qualified O2I.Operation.Human.Diagnostic as HumanDiagnostic
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import O2I.Operation.Provenance (SourceOrdinal, SourceRole, mkSourceReference)
import qualified O2I.Operation.Readiness.Human as Human
import O2I.Operation.Readiness.Machine
import O2I.Operation.Readiness.Request
import O2I.Operation.Readiness.Result
import O2I.Operation.Readiness.Runtime.Internal (runReadinessWith)
import O2I.Operation.Schema (schemaVariantText)
import qualified O2I.Operation.Test.HumanFailureCorrespondence as FailureCorrespondence
import qualified O2I.Operation.Test.ReportEnvelope as ReportEnvelope
import O2I.Operation.Test.Trace
  ( fixtureModelInput
  , notationRejectedDraft
  , profileRejectedDraft
  , readinessContractDraft
  , structureRejectedDraft
  , traceContractDraft
  , withFixtureEnvironment
  )
import O2I.Operation.View (foldViewSelector, viewByName)
import qualified O2I.Readiness as CoreReadiness
import OperationReportPublicObserver
  ( ObservedReportContract
  , ObservedReportOperation(..)
  )
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "Readiness operation"
    [ testCase "keeps the exact closed request" exactRequest
    , testCase "acquires inputs in stage order" acquisitionOrder
    , testCase "rejects every prerequisite at its exact stage" prerequisites
    , testCase
        "keeps malformed evidence outside the machine envelope"
        malformedEvidence
    , testCase
        "lifts malformed supplemental input through the real Left branch"
        malformedSupplemental
    , testCase "reports binding unavailability" bindingUnavailable
    , testCase "reports reconstruction unavailability" reconstructionUnavailable
    , testCase "reports a failed criterion as not ready" notReady
    , testCase "accepts complete readiness evidence" ready
    , testCase "encodes every result variant against its Schema" machineVariants
    , testCase
        "projects every real terminal branch with its complete context"
        humanVariants
    ]

exactRequest :: Assertion
exactRequest = do
  model <- fixtureModelInput
  evidence <- input "readiness" "readiness.json"
  supplement <- input "supplement" "supplement.json"
  let request =
        readinessRequest
          model
          (viewByName "Binding")
          Nothing
          evidence
          [supplement]
  readinessModelInput request @?= model
  readinessEvidenceInput request @?= evidence
  readinessSupplementalInputs request @?= [supplement]
  foldReadinessRequest
    (\actualModel selector adapter actualEvidence supplements -> do
       actualModel @?= model
       foldViewSelector
         (@?= "Binding")
         (const (assertFailure "identity selector"))
         selector
       adapter @?= Nothing
       actualEvidence @?= evidence
       supplements @?= [supplement])
    request

acquisitionOrder :: Assertion
acquisitionOrder = do
  complete <- observedRun (traceContractDraft Nothing False) quantitativeJson []
  length complete @?= 2
  last complete @?= "readiness.json"
  mapM_
    (\draft -> do
       observed <- observedRun draft quantitativeJson []
       length observed @?= 1)
    [notationRejectedDraft, profileRejectedDraft]
  supplement <- input "supplement" "supplement.json"
  observed <-
    observedRun (traceContractDraft Nothing False) quantitativeJson [supplement]
  map (Text.pack . reverse . takeWhile (/= '/') . reverse) observed
    @?= ["owner-model.amx", "readiness.json", "supplement.json"]

prerequisites :: Assertion
prerequisites =
  mapM_
    (\(expected, draft) -> do
       result <- runFixture draft quantitativeJson
       foldReadinessResult
         (const (assertFailure "prerequisite fixture failed"))
         (\stage _ -> readinessPrerequisiteText stage @?= expected)
         (\_ _ -> assertFailure "prerequisite fixture became unavailable")
         (\_ _ -> assertFailure "prerequisite fixture became not ready")
         (\_ _ -> assertFailure "prerequisite fixture became ready")
         result)
    [ ("notation", notationRejectedDraft)
    , ("profile", profileRejectedDraft)
    , ("structure", structureRejectedDraft)
    , ( "semantics"
      , readinessContractDraft
          (Just "strategy-principle-guides-strategy-action"))
    ]

malformedEvidence :: Assertion
malformedEvidence = do
  result <- runFixture (traceContractDraft Nothing False) "{}"
  foldReadinessResult
    (\failure ->
       foldReadinessFailure
         (const (assertFailure "malformed evidence became common failure"))
         (const (pure ()))
         (const (assertFailure "malformed evidence became supplemental failure"))
         (const (assertFailure "malformed evidence became owner failure"))
         failure)
    (\_ _ -> assertFailure "malformed evidence reached prerequisite")
    (\_ _ -> assertFailure "malformed evidence reached unavailability")
    (\_ _ -> assertFailure "malformed evidence reached not ready")
    (\_ _ -> assertFailure "malformed evidence reached ready")
    result
  assertReadinessCommandError
    "readiness.evidence-input"
    "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"readiness-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"readiness.evidence-input\",\"failure\":{\"category\":\"evidence-input\",\"diagnostics\":[{\"ruleId\":\"core.evidence-input.decode.discriminator\",\"inputOrdinals\":[0],\"reason\":\"discriminator-invalid\",\"fields\":[{\"name\":\"jsonPointer\",\"values\":[{\"kind\":\"text\",\"value\":\"/type\"}]},{\"name\":\"expected\",\"values\":[{\"kind\":\"text\",\"value\":\"ReadinessInput\"}]}]}]}}"
    result

malformedSupplemental :: Assertion
malformedSupplemental = do
  model <- fixtureModelInput
  evidence <- input "readiness" "readiness.json"
  supplement <- input "supplement" "malformed-supplement.json"
  result <-
    withFixtureEnvironment (traceContractDraft Nothing False) $ \adapters profiles ->
      runReadinessWith
        (fixtureAcquirer quantitativeJson Nothing)
        adapters
        profiles
        (readinessRequest
           model
           (viewByName "Binding")
           Nothing
           evidence
           [supplement])
  foldReadinessResult
    (\failure ->
       foldReadinessFailure
         (const (assertFailure "malformed supplement became common failure"))
         (const (assertFailure "malformed supplement became evidence failure"))
         (const (pure ()))
         (const (assertFailure "malformed supplement became owner failure"))
         failure)
    (\_ _ -> assertFailure "malformed supplement reached prerequisite")
    (\_ _ -> assertFailure "malformed supplement reached unavailability")
    (\_ _ -> assertFailure "malformed supplement reached not ready")
    (\_ _ -> assertFailure "malformed supplement reached ready")
    result
  assertReadinessCommandError
    "readiness.supplemental-input"
    "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"readiness-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"readiness.supplemental-input\",\"failure\":{\"category\":\"supplemental-input\",\"diagnostics\":[{\"ruleId\":\"core.supplemental.decode.json-syntax\",\"inputOrdinals\":[0],\"reason\":\"invalid-json-syntax\",\"fields\":[]}]}}"
    result

assertReadinessCommandError ::
     Text -> ByteString.ByteString -> ReadinessResult -> Assertion
assertReadinessCommandError expectedCode expectedBytes result = do
  tool <- testTool
  case readinessResultDocument tool result of
    Left failure -> do
      let commandError = readinessCommandError failure
          document = commandErrorDocument tool commandError
          encoded = encodeCommandErrorDocument document
      commandErrorCode commandError @?= expectedCode
      schemaVariantText (commandErrorDocumentVariant document)
        @?= "readiness-failed"
      encoded @?= expectedBytes
      assertCommandErrorSchema encoded
    Right _ ->
      assertFailure "failed Readiness result acquired a machine envelope"

bindingUnavailable :: Assertion
bindingUnavailable = do
  result <- bindingUnavailableResult
  foldReadinessResult
    (const (assertFailure "binding fixture failed"))
    (\_ _ -> assertFailure "binding fixture rejected a prerequisite")
    (\unavailable _ ->
       foldReadinessUnavailable
         (\_ _ -> pure ())
         (\_ _ _ -> assertFailure "binding fixture reached reconstruction")
         unavailable)
    (\_ _ -> assertFailure "binding fixture became not ready")
    (\_ _ -> assertFailure "binding fixture became ready")
    result

reconstructionUnavailable :: Assertion
reconstructionUnavailable = do
  result <- reconstructionUnavailableResult
  foldReadinessResult
    (const (assertFailure "reconstruction fixture failed"))
    (\_ _ -> assertFailure "reconstruction fixture rejected a prerequisite")
    (\unavailable _ ->
       foldReadinessUnavailable
         (\_ _ -> assertFailure "reconstruction fixture stopped at binding")
         (\_ _ _ -> pure ())
         unavailable)
    (\_ _ -> assertFailure "reconstruction fixture became not ready")
    (\_ _ -> assertFailure "reconstruction fixture became ready")
    result

notReady :: Assertion
notReady = do
  result <- notReadyResult
  foldReadinessResult
    (const (assertFailure "not-ready fixture failed"))
    (\_ _ -> assertFailure "not-ready fixture rejected a prerequisite")
    (\unavailable _ ->
       assertFailure
         ("not-ready fixture became unavailable: "
            <> unavailableDescription unavailable))
    (\_ _ -> pure ())
    (\_ _ -> assertFailure "not-ready fixture became ready")
    result

ready :: Assertion
ready = do
  result <- readyResult
  foldReadinessResult
    (const (assertFailure "ready fixture failed"))
    (\_ _ -> assertFailure "ready fixture rejected a prerequisite")
    (\unavailable _ ->
       assertFailure
         ("ready fixture became unavailable: "
            <> unavailableDescription unavailable))
    (\_ _ -> assertFailure "ready fixture became not ready")
    (\_ _ -> pure ())
    result

machineVariants :: Assertion
machineVariants = do
  prerequisiteResults <-
    traverse
      (\draft -> runFixture draft quantitativeJson)
      [ notationRejectedDraft
      , profileRejectedDraft
      , structureRejectedDraft
      , readinessContractDraft
          (Just "strategy-principle-guides-strategy-action")
      ]
  binding <- bindingUnavailableResult
  reconstruction <- reconstructionUnavailableResult
  rejected <- notReadyResult
  accepted <- readyResult
  mapM_
    (uncurry assertMachine)
    (map ((,) "readiness-prerequisite-rejected") prerequisiteResults
       <> [ ("readiness-subject-unavailable", binding)
          , ("readiness-subject-unavailable", reconstruction)
          , ("readiness-not-ready", rejected)
          , ("readiness-ready", accepted)
          ])

humanVariants :: Assertion
humanVariants = do
  failed <- runFixture (traceContractDraft Nothing False) "{}"
  prerequisite <- runFixture notationRejectedDraft quantitativeJson
  binding <- bindingUnavailableResult
  reconstruction <- reconstructionUnavailableResult
  rejected <- notReadyResult
  accepted <- readyResult
  tool <- ReportEnvelope.hostileTool
  assertHuman tool "failed" ReportEnvelope.contractsWithoutCore failed
  assertHuman tool "prerequisite" ReportEnvelope.contractsWithCore prerequisite
  assertHuman
    tool
    "binding-unavailable"
    ReportEnvelope.contractsWithCore
    binding
  assertHuman
    tool
    "reconstruction-unavailable"
    ReportEnvelope.contractsWithCore
    reconstruction
  assertHuman tool "not-ready" ReportEnvelope.contractsWithCore rejected
  assertHuman tool "ready" ReportEnvelope.contractsWithCore accepted
  where
    assertHuman ::
         ToolDescriptor
      -> Text
      -> NonEmpty.NonEmpty ObservedReportContract
      -> ReadinessResult
      -> Assertion
    assertHuman tool expected contracts result =
      Human.foldHumanReadinessReport
        (\failureValue -> do
           expected @?= "failed"
           raw <- observeRawReadinessFailure result
           human <- observeHumanReadinessFailure failureValue
           human @?= raw)
        (\_ context -> do
           expected @?= "prerequisite"
           assertContext tool result contracts False context)
        (\unavailable context -> do
           branch <-
             Human.foldHumanReadinessUnavailable
               (\_ _ -> pure "binding-unavailable")
               (\_ _ _ -> pure "reconstruction-unavailable")
               unavailable
           expected @?= branch
           assertContext tool result contracts True context)
        (\_ context -> do
           expected @?= "not-ready"
           assertContext tool result contracts True context)
        (\_ context -> do
           expected @?= "ready"
           assertContext tool result contracts True context)
        (Human.readinessHumanReport tool result)
    observeRawReadinessFailure result =
      foldReadinessResult
        (foldReadinessFailure
           (pure . (: []) . FailureCorrespondence.observeRawCommonFailure)
           (pure
              . map FailureCorrespondence.observeRawReadinessInputDefect
              . NonEmpty.toList)
           (pure
              . map FailureCorrespondence.observeRawSupplementalInputDefect
              . NonEmpty.toList)
           (\_ -> unexpected "Readiness owner failure in input fixture"))
        (\_ _ -> unexpected "Readiness prerequisite in failed fixture")
        (\_ _ -> unexpected "Readiness unavailability in failed fixture")
        (\_ _ -> unexpected "Readiness not-ready result in failed fixture")
        (\_ _ -> unexpected "Readiness ready result in failed fixture")
        result
    observeHumanReadinessFailure failureValue =
      Human.foldHumanReadinessFailure
        (pure . (: []) . FailureCorrespondence.observeHumanCommonFailure)
        (pure
           . map FailureCorrespondence.observeHumanInputDefect
           . NonEmpty.toList)
        (pure
           . map FailureCorrespondence.observeHumanSupplementalInputDefect
           . NonEmpty.toList)
        (\_ -> unexpected "Readiness model-role failure in input fixture")
        (\_ -> unexpected "Readiness evidence-role failure in input fixture")
        (\_ -> unexpected "Readiness supplemental-role failure in input fixture")
        (\_ -> unexpected "Readiness adapter failure in input fixture")
        (\_ -> unexpected "Readiness notation failure in input fixture")
        (\_ -> unexpected "Readiness Profile failure in input fixture")
        (\_ -> unexpected "Readiness identity failure in input fixture")
        (\_ -> unexpected "Readiness scope failure in input fixture")
        (\_ -> unexpected "Readiness Structure failure in input fixture")
        (\_ -> unexpected "Readiness provenance failure in input fixture")
        (\_ -> unexpected "Readiness semantic failure in input fixture")
        failureValue
    unexpected message = assertFailure message >> fail "unreachable"
    assertContext ::
         ToolDescriptor
      -> ReadinessResult
      -> NonEmpty.NonEmpty ObservedReportContract
      -> Bool
      -> Human.HumanReadinessContext
      -> Assertion
    assertContext tool result contracts completed context = do
      document <-
        case readinessResultDocument tool result of
          Left _ ->
            assertFailure "prepared Readiness result has no document"
              >> fail "unreachable"
          Right value -> pure value
      Human.foldHumanReadinessContext
        (\envelope request model evidence supplements _ diagnostics -> do
           ReportEnvelope.assertPreparedEnvelope
             readinessResultSchema
             (readinessResultDocumentVariant document)
             ObservedReadinessReportOperation
             contracts
             envelope
           Human.foldHumanReadinessRequest
             (\modelInput view adapter evidenceInput supplementInputs -> do
                assertFile
                  "model"
                  ("tst" </> "fixtures" </> "owner-model.amx")
                  modelInput
                HumanValue.foldHumanViewSelector
                  (@?= "Binding")
                  (const
                     (assertFailure "Readiness request changed selector kind"))
                  view
                HumanValue.foldHumanAdapterSelection
                  (pure ())
                  (const
                     (assertFailure
                        "Readiness request changed adapter selection"))
                  adapter
                assertFile "readiness" "readiness.json" evidenceInput
                length supplementInputs @?= 1)
             request
           assertSource "model" "model" 0 model
           if completed
             then do
               maybe
                 (assertFailure "prepared Readiness lost acquired evidence")
                 (assertSource "readiness" "readiness" 0)
                 evidence
               length supplements @?= 1
               mapM_ (assertSource "supplemental" "strategy" 0) supplements
             else do
               case evidence of
                 Nothing -> pure ()
                 Just _ ->
                   assertFailure
                     "early prerequisite unexpectedly acquired evidence"
               assertBool
                 "early prerequisite unexpectedly acquired supplements"
                 (null supplements)
           let diagnosticModel =
                 HumanValue.foldHumanSourceIdentity
                   (\role ordinal reference digest ->
                      (sourceRole role, ordinal, reference, digest))
                   (HumanDiagnostic.humanDiagnosticDocumentModelSource
                      diagnostics)
               contextModel =
                 HumanValue.foldHumanSourceIdentity
                   (\role ordinal reference digest ->
                      (sourceRole role, ordinal, reference, digest))
                   model
           diagnosticModel @?= contextModel)
        context
    assertFile :: Text -> FilePath -> HumanValue.HumanInputSource -> Assertion
    assertFile reference path =
      HumanValue.foldHumanInputSource
        (\actualReference actualPath -> do
           actualReference @?= reference
           actualPath @?= path)
        (const (assertFailure "Readiness file input became standard input"))
    assertSource ::
         Text -> Text -> Natural -> HumanValue.HumanSourceIdentity -> Assertion
    assertSource role reference ordinal =
      HumanValue.foldHumanSourceIdentity
        (\actualRole actualOrdinal actualReference digest -> do
           sourceRole actualRole @?= role
           actualOrdinal @?= ordinal
           actualReference @?= reference
           assertBool "Readiness source digest is empty" (digest /= ""))
    sourceRole :: HumanValue.HumanSourceRole -> Text
    sourceRole =
      HumanValue.foldHumanSourceRole
        "model"
        "supplemental"
        "readiness"
        "assessment"

bindingUnavailableResult :: IO ReadinessResult
bindingUnavailableResult =
  runFixture
    (readinessContractDraft Nothing)
    (Text.replace
       "\"kpi\":\"measureKpi\""
       "\"kpi\":\"unknownKpi\""
       quantitativeJson)

reconstructionUnavailableResult :: IO ReadinessResult
reconstructionUnavailableResult =
  runFixture
    (readinessContractDraft (Just "strategy-frames-measure"))
    quantitativeJson

notReadyResult :: IO ReadinessResult
notReadyResult =
  runFixture
    (readinessContractDraft Nothing)
    (Text.replace
       "\"target\":\"2\",\"unit\":\"count\""
       "\"target\":\"2\",\"unit\":\"seconds\""
       quantitativeJson)

readyResult :: IO ReadinessResult
readyResult = runFixture (readinessContractDraft Nothing) quantitativeJson

unavailableDescription :: ReadinessUnavailable -> String
unavailableDescription =
  foldReadinessUnavailable
    (\_ defects ->
       show
         (map CoreReadiness.evidenceInputDefectKind (NonEmpty.toList defects)))
    (\_ _ reasons ->
       show
         (map
            (CoreReadiness.foldReadinessSubjectUnavailableReason show show)
            (NonEmpty.toList reasons)))

runFixture :: Draft.ProfileDraft -> Text -> IO ReadinessResult
runFixture draft evidence = do
  model <- fixtureModelInput
  evidenceInput <- input "readiness" "readiness.json"
  strategyInput <- input "strategy" "strategy.json"
  withFixtureEnvironment draft $ \adapters profiles ->
    runReadinessWith
      (fixtureAcquirer evidence Nothing)
      adapters
      profiles
      (readinessRequest
         model
         (viewByName "Binding")
         Nothing
         evidenceInput
         [strategyInput])

observedRun :: Draft.ProfileDraft -> Text -> [InputSource] -> IO [FilePath]
observedRun draft evidence supplements = do
  model <- fixtureModelInput
  evidenceInput <- input "readiness" "readiness.json"
  observed <- newIORef []
  withFixtureEnvironment draft $ \adapters profiles -> do
    _ <-
      runReadinessWith
        (fixtureAcquirer evidence (Just observed))
        adapters
        profiles
        (readinessRequest
           model
           (viewByName "Binding")
           Nothing
           evidenceInput
           supplements)
    readIORef observed

fixtureAcquirer ::
     Text
  -> Maybe (IORef [FilePath])
  -> SourceRole
  -> SourceOrdinal
  -> InputSource
  -> IO (Either AcquisitionFailure AcquiredSource)
fixtureAcquirer evidence observed =
  acquireWith
    (\path -> do
       maybe
         (pure ())
         (\reference -> modifyIORef' reference (<> [path]))
         observed
       pure
         (if path == "readiness.json"
            then TextEncoding.encodeUtf8 evidence
            else if path == "strategy.json"
                   then TextEncoding.encodeUtf8 strategyJson
                   else ByteString.empty))
    (ioError (userError "unexpected Readiness stdin read"))

assertMachine :: Text -> ReadinessResult -> Assertion
assertMachine expected result = do
  tool <- testTool
  document <-
    case readinessResultDocument tool result of
      Left _ ->
        assertFailure "completed Readiness result has no document"
          >> fail "unreachable"
      Right value -> pure value
  schemaVariantText (readinessResultDocumentVariant document) @?= expected
  let encoded = encodeReadinessResultDocument document
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.readiness-v1.schema.json")
  schema <- requireJson schemaBytes
  value <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure message >> fail "unreachable"
      Right documentValue -> pure documentValue
  validateJSONSchema schema value
    @? "Readiness machine document violates its generated Schema"

assertCommandErrorSchema :: ByteString.ByteString -> Assertion
assertCommandErrorSchema encoded = do
  schema <- requireJson (LazyByteString.fromStrict commandErrorSchemaBytes)
  value <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure message >> fail "unreachable"
      Right documentValue -> pure documentValue
  validateJSONSchema schema value
    @? "Readiness command error violates the generated Schema"

testTool :: IO ToolDescriptor
testTool = requireRight (mkToolDescriptor "o2i" "0.3.0")

input :: Text -> FilePath -> IO InputSource
input reference path = do
  sourceReference <- requireRight (mkSourceReference reference)
  requireRight (fileInput sourceReference path)

requireJson :: LazyByteString.ByteString -> IO Aeson.Value
requireJson bytes =
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

quantitativeJson :: Text
quantitativeJson =
  Text.concat
    [ "{\"type\":\"ReadinessInput\","
    , "\"readinessCheckedAt\":\"2026-01-01T00:00:02Z\","
    , "\"kpiDefinition\":{\"kpi\":\"measureKpi\","
    , "\"domain\":{\"kind\":\"quantitative\",\"unit\":\"count\",\"effectDirection\":\"increase\"},"
    , "\"measurementMethod\":\"method\",\"interpretation\":\"interpretation\"},"
    , "\"plannedStart\":{\"intervention\":\"intervention\",\"plannedStartAt\":\"2026-01-01T00:00:03Z\"},"
    , "\"evidencePlan\":{\"trace\":"
    , traceJson
    , ",\"baseline\":{\"observedAt\":\"2026-01-01T00:00:01Z\",\"source\":\"baseline-source\","
    , "\"value\":{\"kind\":\"quantitative\",\"value\":\"1.5\",\"unit\":\"count\"}},"
    , "\"effectCriterion\":{\"kind\":\"quantitative-absolute\",\"minimumDirectionAdjustedDelta\":\"1\"},"
    , "\"targetCriterion\":{\"kind\":\"quantitative-threshold\",\"comparison\":\"at-least\","
    , "\"target\":\"2\",\"unit\":\"count\"},"
    , "\"targetDueAt\":\"2026-01-01T00:00:04Z\",\"source\":\"plan-source\","
    , "\"planEstablishedAt\":\"2026-01-01T00:00:00Z\"}}"
    ]

traceJson :: Text
traceJson =
  "{\"graphIdentity\":\"binding-view\",\"bindings\":{"
    <> Text.intercalate
         ","
         [ "\"vision\":\"vision\""
         , "\"strategy\":\"strategy\""
         , "\"need\":\"need\""
         , "\"intervention\":\"intervention\""
         , "\"measure\":\"measure\""
         , "\"situation\":\"situation\""
         , "\"visionObjective\":\"visionObjective\""
         , "\"strategyDriver\":\"strategyDriver\""
         , "\"strategyObjective\":\"strategyObjective\""
         , "\"strategyAction\":\"strategyAction\""
         , "\"strategyKeyResult\":\"strategyKeyResult\""
         , "\"needDriver\":\"needDriver\""
         , "\"needObjective\":\"needObjective\""
         , "\"interventionAction\":\"interventionAction\""
         , "\"interventionKeyResult\":\"interventionKeyResult\""
         , "\"measurePerformanceDimension\":\"measurePerformanceDimension\""
         , "\"measureKpi\":\"measureKpi\""
         , "\"situationAnchor\":\"situationAnchor\""
         ]
    <> "}}"

strategyJson :: Text
strategyJson =
  Text.concat
    [ "{\"type\":\"StrategyFormulationInput\",\"strategy\":\"strategy\","
    , "\"scope\":[\"scope\"],\"anchoring\":{\"period\":\"period\","
    , "\"responsibilityScope\":\"responsibility scope\",\"decisionLevel\":\"decision level\","
    , "\"responsibilities\":[\"responsibility\"],\"decisionPaths\":[\"decision path\"],"
    , "\"implementationLogic\":\"implementation logic\"},\"derivedGuardrails\":[\"guardrail\"],"
    , "\"diagnosis\":\"strategyDriver\",\"intent\":\"strategyObjective\","
    , "\"guidingPolicy\":\"strategyPrinciple\",\"positioning\":[\"positioning\"],"
    , "\"tradeOffs\":[\"trade-off\"],\"actions\":[\"strategyAction\"],"
    , "\"keyResults\":[\"strategyKeyResult\"],\"fitRationale\":[\"fit rationale\"]}"
    ]
