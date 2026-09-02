{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Assess
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Foldable (toList)
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
import O2I.Operation.Assess.Machine
import O2I.Operation.Assess.Request
import O2I.Operation.Assess.Result
import O2I.Operation.Assess.Runtime.Internal (runAssessWith)
import O2I.Operation.Command.Error (assessCommandError, commandErrorCode)
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import O2I.Operation.Provenance
  ( SourceOrdinal
  , SourceRole(..)
  , mkSourceReference
  , sourceOrdinalValue
  )
import O2I.Operation.Schema (machineSchemaVariants, schemaVariantText)
import O2I.Operation.Test.Trace
  ( fixtureModelInput
  , notationRejectedDraft
  , profileRejectedDraft
  , readinessContractDraft
  , structureRejectedDraft
  , withFixtureEnvironment
  )
import O2I.Operation.View (foldViewSelector, viewByName)
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "Assessment operation"
    [ testCase "keeps the exact closed request" exactRequest
    , testCase "closes result exit classifications" exitClassifications
    , testCase "closes the exact machine variants" exactMachineVariants
    , testCase
        "acquires model bundle and supplements exactly once in order"
        acquisitionContract
    , testCase
        "fails fast without acquiring suppressed later sources"
        acquisitionFailFast
    , testCase
        "N-source acquisition work grows by exactly one call per source"
        acquisitionScaling
    , testCase
        "encodes every real terminal branch against the generated Schema"
        terminalMachineBranches
    , testCase
        "mixed results retain source order and complete raw evidence"
        mixedMachineEvidence
    , testCase
        "completed remains exit zero when effect and target are not satisfied"
        completedNegativeCriteria
    ]

exactRequest :: Assertion
exactRequest = do
  model <- input "model" "model.amx"
  bundle <- input "assessment" "assessment.json"
  supplement <- input "supplement" "supplement.json"
  let request =
        assessRequest model (viewByName "Binding") Nothing bundle [supplement]
  assessModelInput request @?= model
  assessBundleInput request @?= bundle
  assessSupplementalInputs request @?= [supplement]
  foldAssessRequest
    (\actualModel selector adapter actualBundle supplements -> do
       actualModel @?= model
       foldViewSelector
         (@?= "Binding")
         (const (assertFailure "identity selector"))
         selector
       adapter @?= Nothing
       actualBundle @?= bundle
       supplements @?= [supplement])
    request

exitClassifications :: Assertion
exitClassifications = do
  assessExitClassText assessSuccessExit @?= "success"
  assessExitCode assessSuccessExit @?= 0
  assessExitClassText assessPrimaryNegativeExit @?= "primary-negative"
  assessExitCode assessPrimaryNegativeExit @?= 1
  assessExitClassText assessOperationalFailureExit @?= "operational-failure"
  assessExitCode assessOperationalFailureExit @?= 2
  assessExitClassText assessSubjectUnavailableExit @?= "subject-unavailable"
  assessExitCode assessSubjectUnavailableExit @?= 3
  foldAssessExitClass
    "success"
    "negative"
    "operational"
    "unavailable"
    assessPrimaryNegativeExit
    @?= ("negative" :: String)

exactMachineVariants :: Assertion
exactMachineVariants =
  fmap
    schemaVariantText
    (NonEmpty.toList (machineSchemaVariants assessResultSchema))
    @?= [ "assess-prerequisite-rejected"
        , "assess-subject-unavailable"
        , "assess-collection-invalid"
        , "assess-observations-invalid"
        , "assess-completed"
        ]

acquisitionContract :: Assertion
acquisitionContract = do
  (_, events) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      ["strategy-0.json", "strategy-1.json"]
      Nothing
  events
    @?= [ (ModelRole, 0, "tst" </> "fixtures" </> "owner-model.amx")
        , (AssessmentRole, 0, "assessment.json")
        , (SupplementalRole, 0, "strategy-0.json")
        , (SupplementalRole, 1, "strategy-1.json")
        ]

acquisitionFailFast :: Assertion
acquisitionFailFast = do
  (_, modelEvents) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      ["strategy-0.json"]
      (Just ("tst" </> "fixtures" </> "owner-model.amx"))
  fmap third modelEvents @?= ["tst" </> "fixtures" </> "owner-model.amx"]
  (_, bundleEvents) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      ["strategy-0.json"]
      (Just "assessment.json")
  fmap third bundleEvents
    @?= ["tst" </> "fixtures" </> "owner-model.amx", "assessment.json"]
  (_, supplementEvents) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      ["strategy-0.json", "strategy-1.json", "strategy-2.json"]
      (Just "strategy-1.json")
  fmap third supplementEvents
    @?= [ "tst" </> "fixtures" </> "owner-model.amx"
        , "assessment.json"
        , "strategy-0.json"
        , "strategy-1.json"
        ]

acquisitionScaling :: Assertion
acquisitionScaling = do
  let paths :: Int -> [FilePath]
      paths count =
        ["strategy-" <> show index <> ".json" | index <- [0 .. count - 1]]
  (_, small) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      (paths 2)
      Nothing
  (_, large) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      (paths 50)
      Nothing
  length small @?= 4
  length large @?= 52
  length large - length small @?= 48
  fmap (\(role, ordinal, _) -> (role, ordinal)) (drop 2 large)
    @?= [(SupplementalRole, fromIntegral index) | index <- [0 .. 49 :: Int]]

terminalMachineBranches :: Assertion
terminalMachineBranches = do
  prerequisiteResults <-
    traverse
      (\draft -> runFixture draft completedBundle)
      [ notationRejectedDraft
      , profileRejectedDraft
      , structureRejectedDraft
      , readinessContractDraft
          (Just "strategy-principle-guides-strategy-action")
      ]
  binding <-
    runFixture
      (readinessContractDraft Nothing)
      (assessmentBundle
         (Text.replace
            "\"measureKpi\":\"measureKpi\""
            "\"measureKpi\":\"unknownKpi\""
            quantitativeReadiness)
         [observation "1.5" "04" "binding-source"])
  reconstruction <-
    runFixture
      (readinessContractDraft (Just "strategy-frames-measure"))
      completedBundle
  collection <-
    runFixture
      (readinessContractDraft Nothing)
      (assessmentBundle quantitativeReadiness [])
  mixed <- runFixture (readinessContractDraft Nothing) mixedBundle
  completed <- runFixture (readinessContractDraft Nothing) completedBundle
  mapM_
    (uncurry assertMachine)
    (map ((,) "assess-prerequisite-rejected") prerequisiteResults
       <> [ ("assess-subject-unavailable", binding)
          , ("assess-subject-unavailable", reconstruction)
          , ("assess-collection-invalid", collection)
          , ("assess-observations-invalid", mixed)
          , ("assess-completed", completed)
          ])
  failed <- runFixture (readinessContractDraft Nothing) "{}"
  foldAssessResult
    (\failure ->
       foldAssessFailure
         (const (assertFailure "malformed assessment became common failure"))
         (const (pure ()))
         (const
            (assertFailure "malformed assessment became supplemental failure"))
         (const (assertFailure "malformed assessment became owner failure"))
         failure)
    (\_ _ -> assertFailure "malformed assessment reached prerequisite")
    (\_ _ -> assertFailure "malformed assessment reached unavailability")
    (\_ _ -> assertFailure "malformed assessment reached collection")
    (\_ _ -> assertFailure "malformed assessment reached invalid observations")
    (\_ _ -> assertFailure "malformed assessment reached completion")
    failed
  assertAssessCommandError
    "assess.assessment-input"
    "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"assess-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"assess.assessment-input\",\"failure\":{\"category\":\"assessment-input\",\"diagnostics\":[{\"ruleId\":\"core.evidence-input.decode.discriminator\",\"inputOrdinals\":[0],\"reason\":\"discriminator-invalid\",\"fields\":[{\"name\":\"jsonPointer\",\"values\":[{\"kind\":\"text\",\"value\":\"/type\"}]},{\"name\":\"expected\",\"values\":[{\"kind\":\"text\",\"value\":\"AssessmentBundleInput\"}]}]}]}}"
    failed
  (supplementalFailed, _) <-
    observedRun
      (readinessContractDraft Nothing)
      completedBundle
      ["malformed-supplement.json"]
      Nothing
  foldAssessResult
    (\failure ->
       foldAssessFailure
         (const (assertFailure "malformed supplement became common failure"))
         (const (assertFailure "malformed supplement became assessment failure"))
         (const (pure ()))
         (const (assertFailure "malformed supplement became owner failure"))
         failure)
    (\_ _ -> assertFailure "malformed supplement reached prerequisite")
    (\_ _ -> assertFailure "malformed supplement reached unavailability")
    (\_ _ -> assertFailure "malformed supplement reached collection")
    (\_ _ -> assertFailure "malformed supplement reached invalid observations")
    (\_ _ -> assertFailure "malformed supplement reached completion")
    supplementalFailed
  assertAssessCommandError
    "assess.supplemental-input"
    "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"assess-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"assess.supplemental-input\",\"failure\":{\"category\":\"supplemental-input\",\"diagnostics\":[{\"ruleId\":\"core.supplemental.decode.json-syntax\",\"inputOrdinals\":[0],\"reason\":\"invalid-json-syntax\",\"fields\":[]}]}}"
    supplementalFailed

assertAssessCommandError ::
     Text -> ByteString.ByteString -> AssessResult -> Assertion
assertAssessCommandError expectedCode expectedBytes result = do
  tool <- testTool
  case assessResultDocument tool result of
    Left failure -> do
      let commandError = assessCommandError failure
          document = commandErrorDocument tool commandError
          encoded = encodeCommandErrorDocument document
      commandErrorCode commandError @?= expectedCode
      schemaVariantText (commandErrorDocumentVariant document)
        @?= "assess-failed"
      encoded @?= expectedBytes
      schema <- requireJson (LazyByteString.fromStrict commandErrorSchemaBytes)
      value <- requireStrictJson encoded
      validateJSONSchema schema value
        @? "Assessment command error violates its generated Schema"
    Right _ ->
      assertFailure "failed Assessment result acquired a machine envelope"

mixedMachineEvidence :: Assertion
mixedMachineEvidence = do
  result <- runFixture (readinessContractDraft Nothing) mixedBundle
  document <- requireMachine "assess-observations-invalid" result
  assessment <-
    decodeObject (encodeAssessResultDocument document)
      >>= objectMember "assessment"
      >>= requireObject
  observations <- objectMember "observations" assessment >>= requireArray
  traverse observationOrdinal observations >>= (@?= [0, 1, 2])
  traverse observationDisposition observations
    >>= (@?= [ "assessed-observation"
             , "invalid-observation"
             , "assessed-observation"
             ])
  traverse observationSource observations
    >>= (@?= ["sensor-A raw", "sensor-B raw", "sensor-C raw"])
  traverse observationQuantitativeValue observations
    >>= (@?= ["1.5", "1.7", "2.5"])
  assessedLimitations (observations !! 0)
    >>= (@?= [ "causality-not-established"
             , "first-target-attainment-time-not-established"
             ])
  assessedLimitations (observations !! 2)
    >>= (@?= [ "causality-not-established"
             , "first-target-attainment-time-not-established"
             ])

completedNegativeCriteria :: Assertion
completedNegativeCriteria = do
  result <- runFixture (readinessContractDraft Nothing) completedBundle
  assessResultExitClass result @?= assessSuccessExit
  document <- requireMachine "assess-completed" result
  root <- decodeObject (encodeAssessResultDocument document)
  execution <- objectMember "execution" root >>= requireObject
  objectMember "exitClass" execution >>= requireText >>= (@?= "success")
  objectMember "exitCode" execution >>= requireNatural >>= (@?= 0)
  assessment <- objectMember "assessment" root >>= requireObject
  observations <- objectMember "observations" assessment >>= requireArray
  case observations of
    [value] -> do
      observationObject <- requireObject value
      objectMember "effect" observationObject
        >>= requireText
        >>= (@?= "not-satisfied")
      objectMember "target" observationObject
        >>= requireText
        >>= (@?= "not-satisfied-in-observation")
    _ -> assertFailure "completed fixture lost its sole observation"

runFixture :: Draft.ProfileDraft -> Text -> IO AssessResult
runFixture draft bundle =
  fmap fst (observedRun draft bundle ["strategy-0.json"] Nothing)

observedRun ::
     Draft.ProfileDraft
  -> Text
  -> [FilePath]
  -> Maybe FilePath
  -> IO (AssessResult, [(SourceRole, Natural, FilePath)])
observedRun draft bundle supplementPaths failing = do
  model <- fixtureModelInput
  bundleInput <- input "assessment" "assessment.json"
  supplements <-
    traverse
      (\(index, path) -> input ("supplement-" <> Text.pack (show index)) path)
      (zip [0 :: Int ..] supplementPaths)
  events <- newIORef []
  withFixtureEnvironment draft $ \adapters profiles -> do
    result <-
      runAssessWith
        (fixtureAcquirer bundle events failing)
        adapters
        profiles
        (assessRequest
           model
           (viewByName "Binding")
           Nothing
           bundleInput
           supplements)
    observed <- readIORef events
    pure (result, observed)

fixtureAcquirer ::
     Text
  -> IORef [(SourceRole, Natural, FilePath)]
  -> Maybe FilePath
  -> SourceRole
  -> SourceOrdinal
  -> InputSource
  -> IO (Either AcquisitionFailure AcquiredSource)
fixtureAcquirer bundle events failing role ordinal source =
  acquireWith
    readFileBytes
    (ioError (userError "unexpected Assess stdin read"))
    role
    ordinal
    source
  where
    readFileBytes path = do
      modifyIORef' events (<> [(role, sourceOrdinalValue ordinal, path)])
      case failing of
        Just expected
          | expected == path -> ioError (userError "unavailable")
        _ ->
          pure
            (if path == "assessment.json"
               then TextEncoding.encodeUtf8 bundle
               else if "strategy-" `Text.isPrefixOf` Text.pack path
                      then TextEncoding.encodeUtf8 strategyInput
                      else ByteString.empty)

assertMachine :: Text -> AssessResult -> Assertion
assertMachine expected result = do
  document <- requireMachine expected result
  let encoded = encodeAssessResultDocument document
  encodeAssessResultDocument document @?= encoded
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.assess-v1.schema.json")
  schema <- requireJson schemaBytes
  value <- requireStrictJson encoded
  validateJSONSchema schema value
    @? ("Assessment machine document violates its generated Schema: "
          <> Text.unpack expected)

requireMachine :: Text -> AssessResult -> IO AssessResultDocument
requireMachine expected result = do
  tool <- testTool
  document <-
    case assessResultDocument tool result of
      Left _ ->
        assertFailure "prepared Assessment result has no document"
          >> fail "unreachable"
      Right value -> pure value
  schemaVariantText (assessResultDocumentVariant document) @?= expected
  pure document

testTool :: IO ToolDescriptor
testTool = requireRight (mkToolDescriptor "o2i" "0.3.0")

assessmentBundle :: Text -> [Text] -> Text
assessmentBundle readiness observations =
  Text.concat
    [ "{\"type\":\"AssessmentBundleInput\",\"readiness\":"
    , readiness
    , ",\"assessedAt\":\"2026-01-01T00:06:00Z\","
    , "\"actualStart\":{\"intervention\":\"intervention\","
    , "\"actualStartAt\":\"2026-01-01T00:00:03Z\"},\"observations\":["
    , Text.intercalate "," observations
    , "]}"
    ]

observation :: Text -> Text -> Text -> Text
observation value minute source =
  Text.concat
    [ "{\"trace\":"
    , traceIdentity
    , ",\"observedAt\":\"2026-01-01T00:"
    , minute
    , ":00Z\",\"source\":\""
    , source
    , "\",\"value\":{\"kind\":\"quantitative\",\"value\":\""
    , value
    , "\",\"unit\":\"count\"}}"
    ]

foreignObservation :: Text
foreignObservation =
  Text.replace
    "\"measureKpi\":\"measureKpi\""
    "\"measureKpi\":\"foreignKpi\""
    (observation "1.7" "05" "sensor-B raw")

completedBundle :: Text
completedBundle =
  assessmentBundle quantitativeReadiness [observation "1.5" "04" "sensor-A raw"]

mixedBundle :: Text
mixedBundle =
  assessmentBundle
    quantitativeReadiness
    [ observation "1.5" "04" "sensor-A raw"
    , foreignObservation
    , observation "2.5" "06" "sensor-C raw"
    ]

quantitativeReadiness :: Text
quantitativeReadiness =
  Text.concat
    [ "{\"type\":\"ReadinessInput\","
    , "\"readinessCheckedAt\":\"2026-01-01T00:00:02Z\","
    , "\"kpiDefinition\":{\"kpi\":\"measureKpi\","
    , "\"domain\":{\"kind\":\"quantitative\",\"unit\":\"count\",\"effectDirection\":\"increase\"},"
    , "\"measurementMethod\":\"method\",\"interpretation\":\"interpretation\"},"
    , "\"plannedStart\":{\"intervention\":\"intervention\",\"plannedStartAt\":\"2026-01-01T00:00:03Z\"},"
    , "\"evidencePlan\":{\"trace\":"
    , traceIdentity
    , ",\"baseline\":{\"observedAt\":\"2026-01-01T00:00:01Z\",\"source\":\"baseline-source\","
    , "\"value\":{\"kind\":\"quantitative\",\"value\":\"1.5\",\"unit\":\"count\"}},"
    , "\"effectCriterion\":{\"kind\":\"quantitative-absolute\",\"minimumDirectionAdjustedDelta\":\"1\"},"
    , "\"targetCriterion\":{\"kind\":\"quantitative-threshold\",\"comparison\":\"at-least\","
    , "\"target\":\"2\",\"unit\":\"count\"},\"targetDueAt\":\"2026-01-01T00:05:00Z\","
    , "\"source\":\"plan-source\",\"planEstablishedAt\":\"2026-01-01T00:00:00Z\"}}"
    ]

traceIdentity :: Text
traceIdentity =
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

strategyInput :: Text
strategyInput =
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

third :: (first, second, third) -> third
third (_, _, value) = value

observationOrdinal :: Aeson.Value -> IO Natural
observationOrdinal value =
  requireObject value >>= objectMember "sourceOrdinal" >>= requireNatural

observationDisposition :: Aeson.Value -> IO Text
observationDisposition value =
  requireObject value >>= objectMember "disposition" >>= requireText

observationSource :: Aeson.Value -> IO Text
observationSource value =
  requireObject value >>= objectMember "source" >>= requireText

observationQuantitativeValue :: Aeson.Value -> IO Text
observationQuantitativeValue value = do
  object <- requireObject value
  domain <- objectMember "value" object >>= requireObject
  objectMember "value" domain >>= requireText

assessedLimitations :: Aeson.Value -> IO [Text]
assessedLimitations value = do
  object <- requireObject value
  limitations <- objectMember "limitations" object >>= requireArray
  traverse requireText limitations

decodeObject :: ByteString.ByteString -> IO Aeson.Object
decodeObject encoded = requireStrictJson encoded >>= requireObject

objectMember :: Text -> Aeson.Object -> IO Aeson.Value
objectMember name object =
  case AesonKeyMap.lookup (AesonKey.fromText name) object of
    Nothing ->
      assertFailure ("missing member: " <> Text.unpack name)
        >> fail "unreachable"
    Just value -> pure value

requireObject :: Aeson.Value -> IO Aeson.Object
requireObject value =
  case value of
    Aeson.Object object -> pure object
    _ -> assertFailure "machine member is not an object" >> fail "unreachable"

requireArray :: Aeson.Value -> IO [Aeson.Value]
requireArray value =
  case value of
    Aeson.Array values -> pure (toList values)
    _ -> assertFailure "machine member is not an array" >> fail "unreachable"

requireText :: Aeson.Value -> IO Text
requireText value =
  case value of
    Aeson.String text -> pure text
    _ -> assertFailure "machine member is not text" >> fail "unreachable"

requireNatural :: Aeson.Value -> IO Natural
requireNatural value =
  case Aeson.fromJSON value of
    Aeson.Success natural -> pure natural
    Aeson.Error _ ->
      assertFailure "machine member is not natural" >> fail "unreachable"

requireJson :: LazyByteString.ByteString -> IO Aeson.Value
requireJson bytes =
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

requireStrictJson :: ByteString.ByteString -> IO Aeson.Value
requireStrictJson bytes =
  case Aeson.eitherDecodeStrict bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

input :: Text -> FilePath -> IO InputSource
input reference path = do
  sourceReference <- requireRight (mkSourceReference reference)
  requireRight (fileInput sourceReference path)

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
