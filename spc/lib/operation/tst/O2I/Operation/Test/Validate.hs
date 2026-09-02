{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Validate
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
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Resolution (compiledProfileDescriptor)
import O2I.Core.Identity (modelIdentity, modelIdentityText)
import O2I.Operation.Acquisition (InputSource, fileInput)
import O2I.Operation.Acquisition.Internal (acquireWith)
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Command.Error (commandErrorCode, validateCommandError)
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Internal
  ( SupplementalDiagnosticGroup(..)
  , SupplementalDiagnosticGroups(..)
  )
import O2I.Operation.Diagnostic.Machine (encodePreparedDiagnosticDocument)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , canonicalFragmentBytes
  )
import O2I.Operation.Failure (commonFailureCode)
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( emptySupplementalDiagnosticGroupFragments
  , foldPreparedDiagnosticDocumentFragments
  )
import O2I.Operation.Profile
import O2I.Operation.Provenance
import O2I.Operation.Schema (schemaVariantText)
import O2I.Operation.Test.AdapterSupport (compileCompleteAdapter)
import O2I.Operation.Validate (runValidate)
import O2I.Operation.Validate.Machine
import O2I.Operation.Validate.Request
import O2I.Operation.Validate.Result
import qualified O2I.Operation.Validate.Result.Internal as ValidateInternal
import O2I.Operation.Validate.Runtime.Internal (runValidateWith)
import O2I.Operation.View (ViewSelector, viewByName)
import O2I.Semantics
  ( CollectiveFitUnavailableReason(..)
  , StrategyFormulationUnavailableReason(..)
  )
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "validate runtime"
    [ requestProjectionTests
    , positiveLevelTests
    , firstFailureStageTests
    , failureBoundaryTests
    , noLaterExecutionTests
    , testCase
        "retains Core unavailability without supplemental Binding defects"
        coreUnavailableWithoutSupplements
    , testCase "retains Binding-only unavailability" bindingOnlyUnavailable
    , testCase
        "retains partial Binding and independent Semantics diagnostics"
        partialBindingWithSemanticDiagnostics
    , privateMachineFragmentTests
    , validateMachineDocumentTests
    ]

validateMachineDocumentTests :: TestTree
validateMachineDocumentTests =
  testGroup
    "closed Validate machine documents"
    [ testCase "encode all four accepted levels" acceptedMachineDocuments
    , testCase "encode the exact first rejecting stage" rejectedMachineDocuments
    , testCase
        "encode Binding-only Core-only and combined unavailability"
        unavailableMachineDocuments
    , testCase
        "encode every closed Core unavailability witness mapping"
        closedCoreUnavailabilityWitnessDocuments
    , testCase
        "retain ordered pre-Binding supplements without an ordinal field"
        preBindingMachineSupplements
    , testCase
        "keep pre-preparation failure outside the Operation envelope"
        failedMachineDocument
    ]

acceptedMachineDocuments :: Assertion
acceptedMachineDocuments = do
  tool <- validateTool
  mapM_
    (\(level, expected) -> do
       result <- runFixtureAt emptyValidateDraft level []
       document <- requireValidateDocument tool result
       schemaVariantText (validateResultDocumentVariant document) @?= expected
       assertValidateSchema (encodeValidateResultDocument document))
    [ (notationValidationLevel, "notation-validation-accepted")
    , (profileValidationLevel, "profile-validation-accepted")
    , (structureValidationLevel, "structure-validation-accepted")
    , (semanticsValidationLevel, "semantics-validation-accepted")
    ]

rejectedMachineDocuments :: Assertion
rejectedMachineDocuments = do
  tool <- validateTool
  mapM_
    (\(draft, expectedLevel, expectedVariant) -> do
       result <- runFixture draft []
       foldValidateResult
         (const (assertFailure "rejection fixture failed"))
         (const (assertFailure "rejection fixture was accepted"))
         (\prepared -> preparedValidationLevel prepared @?= expectedLevel)
         (\_ _ -> assertFailure "rejection fixture was unavailable")
         result
       document <- requireValidateDocument tool result
       schemaVariantText (validateResultDocumentVariant document)
         @?= expectedVariant
       assertValidateSchema (encodeValidateResultDocument document))
    [ ( notationRejectedDraft
      , notationValidationLevel
      , "notation-validation-rejected")
    , ( profileRejectedDraft
      , profileValidationLevel
      , "profile-validation-rejected")
    , ( structureRejectedDraft
      , structureValidationLevel
      , "structure-validation-rejected")
    , ( semanticsRejectedDraft
      , semanticsValidationLevel
      , "semantics-validation-rejected")
    ]

unavailableMachineDocuments :: Assertion
unavailableMachineDocuments = do
  tool <- validateTool
  supplemental <- fixtureInput "supplement" "owner-source-strategy.json"
  results <-
    sequence
      [ runFixture bindingOwnerDraft []
      , runFixture emptyValidateDraft [supplemental]
      , runFixture bindingAndSemanticRejectedDraft [supplemental]
      ]
  mapM_
    (\result -> do
       document <- requireValidateDocument tool result
       schemaVariantText (validateResultDocumentVariant document)
         @?= "semantics-validation-unavailable"
       assertValidateSchema (encodeValidateResultDocument document))
    results

closedCoreUnavailabilityWitnessDocuments :: Assertion
closedCoreUnavailabilityWitnessDocuments = do
  tool <- validateTool
  prepared <- requireUnavailablePrepared =<< runFixture bindingOwnerDraft []
  strategy <- requireRight (modelIdentity "strategy")
  claim <- requireRight (modelIdentity "claim")
  participant <- requireRight (modelIdentity "participant")
  blocker <- requireRight (modelIdentity "blocker")
  let collectiveReasons =
        CollectiveFitInputMissing
          :| [ CollectiveFitIdentityUnresolved
             , ParticipantStrategyFormulationUnavailable
             , ParticipantStrategyFormulationInvalid
             , TargetStrategyFormulationUnavailable
             , TargetStrategyFormulationInvalid
             ]
      cases =
        [ ( ValidateInternal.ValidateStrategyFormulationUnavailable
              strategy
              StrategyFormulationInputMissing
          , Aeson.object
              [ "kind" Aeson..= ("strategy-formulation" :: Text)
              , "subject" Aeson..= ("strategy" :: Text)
              , "reason" Aeson..= ("input-missing" :: Text)
              ])
        , ( ValidateInternal.ValidateStrategyFormulationUnavailable
              strategy
              StrategyFormulationIdentityUnresolved
          , Aeson.object
              [ "kind" Aeson..= ("strategy-formulation" :: Text)
              , "subject" Aeson..= ("strategy" :: Text)
              , "reason" Aeson..= ("identity-unresolved" :: Text)
              ])
        , ( ValidateInternal.ValidateCollectiveFitUnavailable
              claim
              collectiveReasons
              [blocker]
          , Aeson.object
              [ "kind" Aeson..= ("collective-fit" :: Text)
              , "subject" Aeson..= ("claim" :: Text)
              , "reasons"
                  Aeson..= [ "collective-fit-input-missing" :: Text
                           , "collective-fit-identity-unresolved"
                           , "participant-strategy-formulation-unavailable"
                           , "participant-strategy-formulation-invalid"
                           , "target-strategy-formulation-unavailable"
                           , "target-strategy-formulation-invalid"
                           ]
              , "blockers" Aeson..= ["blocker" :: Text]
              ])
        , ( ValidateInternal.ValidateCollectiveCoverageUnavailable
              claim
              [blocker]
          , Aeson.object
              [ "kind" Aeson..= ("collective-coverage" :: Text)
              , "subject" Aeson..= ("claim" :: Text)
              , "blockers" Aeson..= ["blocker" :: Text]
              ])
        , ( ValidateInternal.ValidatePrimitiveSupportUnavailable
              claim
              participant
              (CollectiveFitInputMissing :| [])
              [blocker]
          , Aeson.object
              [ "kind" Aeson..= ("primitive-support" :: Text)
              , "subject" Aeson..= ("claim" :: Text)
              , "participant" Aeson..= ("participant" :: Text)
              , "reasons" Aeson..= ["collective-fit-input-missing" :: Text]
              , "blockers" Aeson..= ["blocker" :: Text]
              ])
        ]
  mapM_ (assertCoreWitnessDocument tool prepared) cases

assertCoreWitnessDocument ::
     ToolDescriptor
  -> PreparedValidation
  -> (ValidateInternal.ValidateUnavailabilityWitness, Aeson.Value)
  -> Assertion
assertCoreWitnessDocument tool prepared (witness, expected) = do
  document <-
    requireValidateDocument
      tool
      (ValidateInternal.ValidateUnavailable (witness :| []) prepared)
  let encoded = encodeValidateResultDocument document
  root <- decodeObject encoded
  execution <- requireObjectMember "execution" root
  witnesses <- requireArrayMember "coreWitnesses" execution
  witnesses @?= [expected]
  assertValidateSchema encoded

requireUnavailablePrepared :: ValidateResult -> IO PreparedValidation
requireUnavailablePrepared =
  foldValidateResult
    (const (assertFailure "unavailability fixture failed" >> fail "unreachable"))
    (const
       (assertFailure "unavailability fixture was accepted"
          >> fail "unreachable"))
    (const
       (assertFailure "unavailability fixture was rejected"
          >> fail "unreachable"))
    (const pure)

preBindingMachineSupplements :: Assertion
preBindingMachineSupplements = do
  tool <- validateTool
  first <- fixtureInput "first" "owner-source-strategy.json"
  second <- fixtureInput "second" "owner-source-strategy-2.json"
  result <- runFixture structureRejectedDraft [first, second]
  document <- requireValidateDocument tool result
  encoded <- decodeObject (encodeValidateResultDocument document)
  context <- requireObjectMember "context" encoded
  supplements <- requireArrayMember "supplements" context
  references <-
    traverse
      (\value ->
         case value of
           Aeson.Object source -> do
             assertBool
               "Validate supplement duplicated its positional ordinal"
               (not (AesonKeyMap.member "ordinal" source))
             requireEmptyDiagnostics source
           _ ->
             assertFailure "Validate supplement is not an object"
               >> fail "unreachable")
      supplements
  references @?= ["first", "second"]
  assertValidateSchema (encodeValidateResultDocument document)

failedMachineDocument :: Assertion
failedMachineDocument = do
  tool <- validateTool
  model <- fixtureInput "missing-model" "validate-model-does-not-exist"
  result <-
    runFixtureRequest
      emptyValidateDraft
      (requestAt notationValidationLevel model (viewByName "Binding") [])
  case validateResultDocument tool result of
    Left _ -> pure ()
    Right _ -> assertFailure "command failure acquired an Operation envelope"

validateTool :: IO ToolDescriptor
validateTool = requireRight (mkToolDescriptor "o2i" "0.3.0")

requireValidateDocument ::
     ToolDescriptor -> ValidateResult -> IO ValidateResultDocument
requireValidateDocument tool result =
  case validateResultDocument tool result of
    Left _ ->
      assertFailure "prepared result became a machine failure"
        >> fail "unreachable"
    Right document -> pure document

assertValidateSchema :: ByteString.ByteString -> Assertion
assertValidateSchema encoded = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.validate-v1.schema.json")
  schema <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  document <- decodeValue encoded
  validateJSONSchema schema document
    @? "Validate machine document violates its generated Schema"

privateMachineFragmentTests :: TestTree
privateMachineFragmentTests =
  testGroup
    "shared private machine fragments"
    [ testCase
        "projects one authority-correlated common document"
        commonDocumentFragments
    , testCase
        "projects acquired pre-Binding sources as ordered empty groups"
        preBindingSourceFragments
    ]

commonDocumentFragments :: Assertion
commonDocumentFragments = do
  supplemental <- fixtureInput "supplement" "owner-source-strategy.json"
  result <- runFixture bindingAndSemanticRejectedDraft [supplemental]
  foldValidateResult
    (const (assertFailure "fragment fixture failed"))
    (const (assertFailure "fragment fixture was accepted"))
    (const (assertFailure "fragment fixture was rejected"))
    (\_ prepared -> do
       let document = preparedValidationDiagnostics prepared
       encoded <- decodeObject (encodePreparedDiagnosticDocument document)
       expectedAuthority <- requireMember "authority" encoded
       expectedDiagnostics <- requireMember "modelDiagnostics" encoded
       expectedSources <- requireObjectMember "supplementalSources" encoded
       foldPreparedDiagnosticDocumentFragments
         (\authority diagnostics groups -> do
            actualAuthority <- decodeFragment authority
            actualDiagnostics <- traverse decodeFragment diagnostics
            actualGroups <- traverse decodeFragment groups
            actualAuthority @?= expectedAuthority
            Aeson.toJSON actualDiagnostics @?= expectedDiagnostics
            Aeson.toJSON actualGroups
              @?= Aeson.toJSON (map snd (AesonKeyMap.toList expectedSources)))
         document)
    result

preBindingSourceFragments :: Assertion
preBindingSourceFragments = do
  first <- fixtureInput "first" "owner-source-strategy.json"
  second <- fixtureInput "second" "owner-source-strategy-2.json"
  result <- runFixture structureRejectedDraft [first, second]
  foldValidateResult
    (const (assertFailure "Structure fragment fixture failed"))
    (const (assertFailure "Structure fragment fixture was accepted"))
    (\prepared ->
       foldPreparedValidation
         (\_ _ _ supplements _ -> do
            groups <-
              traverse
                (decodeObject . canonicalFragmentBytes)
                (emptySupplementalDiagnosticGroupFragments supplements)
            references <- traverse requireEmptyDiagnostics groups
            references @?= ["first", "second"])
         prepared)
    (\_ _ -> assertFailure "Structure fragment fixture reached Binding")
    result

requireEmptyDiagnostics :: Aeson.Object -> IO Text
requireEmptyDiagnostics group = do
  reference <- requireMember "reference" group
  diagnostics <- requireMember "diagnostics" group
  diagnostics @?= Aeson.toJSON ([] :: [Aeson.Value])
  case reference of
    Aeson.String value -> pure value
    _ ->
      assertFailure "supplemental reference is not text" >> fail "unreachable"

decodeFragment :: CanonicalFragment -> IO Aeson.Value
decodeFragment = decodeValue . canonicalFragmentBytes

decodeValue :: ByteString.ByteString -> IO Aeson.Value
decodeValue bytes =
  case Aeson.eitherDecodeStrict' bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

decodeObject :: ByteString.ByteString -> IO Aeson.Object
decodeObject bytes = do
  value <- decodeValue bytes
  case value of
    Aeson.Object object -> pure object
    _ -> assertFailure "machine fragment is not an object" >> fail "unreachable"

requireObjectMember :: Text -> Aeson.Object -> IO Aeson.Object
requireObjectMember name object = do
  value <- requireMember name object
  case value of
    Aeson.Object nested -> pure nested
    _ -> assertFailure "machine member is not an object" >> fail "unreachable"

requireArrayMember :: Text -> Aeson.Object -> IO [Aeson.Value]
requireArrayMember name object = do
  value <- requireMember name object
  case value of
    Aeson.Array values -> pure (toList values)
    _ -> assertFailure "machine member is not an array" >> fail "unreachable"

requireMember :: Text -> Aeson.Object -> IO Aeson.Value
requireMember name object =
  case AesonKeyMap.lookup (AesonKey.fromText name) object of
    Nothing -> assertFailure "machine member is missing" >> fail "unreachable"
    Just value -> pure value

firstFailureStageTests :: TestTree
firstFailureStageTests =
  testGroup
    "stops at the first failed requested stage"
    [ rejectedAt "notation" notationRejectedDraft
    , rejectedAt "profile" profileRejectedDraft
    , rejectedAt "structure" structureRejectedDraft
    , rejectedAt "semantics" semanticsRejectedDraft
    ]
  where
    rejectedAt expectedStage draft =
      testCase ("rejects at " <> Text.unpack expectedStage) $ do
        result <- runFixture draft []
        validateResultDisposition result @?= Just validationRejected
        foldValidateResult
          (const (assertFailure "stage rejection became a failure"))
          (const (assertFailure "invalid model was accepted"))
          (\prepared -> do
             let (stages, bindingCounts) = observePreparedDiagnostics prepared
             assertBool
               "rejection emitted no stage diagnostic"
               (not (null stages))
             last stages @?= expectedStage
             bindingCounts @?= [])
          (\_ _ -> assertFailure "stage rejection became unavailable")
          result

failureBoundaryTests :: TestTree
failureBoundaryTests =
  testGroup
    "keeps command preparation decode and set failures terminal"
    [ testCase "model acquisition is a command failure" $ do
        model <- fixtureInput "missing-model" "validate-model-does-not-exist"
        result <-
          runFixtureRequest
            emptyValidateDraft
            (requestAt notationValidationLevel model (viewByName "Binding") [])
        assertCommonFailureCode "command.input-io" result
    , testCase "View preparation failure precedes assessment" $ do
        model <- fixtureInput "model" "owner-model.amx"
        result <-
          runFixtureRequest
            emptyValidateDraft
            (requestAt semanticsValidationLevel model (viewByName "Missing") [])
        assertCommonFailureCode "preparation.view-selection" result
    , testCase "supplement acquisition is a command failure" $ do
        missing <-
          fixtureInput "missing-supplement" "validate-supplement-does-not-exist"
        result <- runFixture emptyValidateDraft [missing]
        assertCommonFailureCode "command.input-io" result
    , testCase "decode accumulates each source first failure in ordinal order" $ do
        model <- memoryInput "model" "model"
        first <- memoryInput "invalid-first" "invalid-first"
        second <- memoryInput "invalid-second" "invalid-second"
        (result, observedPaths) <-
          runMemoryFixture
            emptyValidateDraft
            (requestAt
               semanticsValidationLevel
               model
               (viewByName "Binding")
               [first, second])
            [ ("model", ByteString.empty)
            , ("invalid-first", "{")
            , ("invalid-second", "[")
            ]
        assertSupplementalFailureCount 2 result
        observedPaths @?= ["model", "invalid-first", "invalid-second"]
    , testCase "decoded subject duplication terminates before Structure" $ do
        first <- fixtureInput "duplicate-first" "owner-source-strategy.json"
        second <- fixtureInput "duplicate-second" "owner-source-strategy.json"
        result <- runFixture structureRejectedDraft [first, second]
        assertSupplementalFailureCount 1 result
    ]

noLaterExecutionTests :: TestTree
noLaterExecutionTests =
  testGroup
    "does not execute a later stage"
    [ noSupplementReadAfter "notation" notationRejectedDraft
    , noSupplementReadAfter "profile" profileRejectedDraft
    , testCase "supplement decode precedes Structure assessment" $ do
        model <- memoryInput "model" "model"
        invalid <- memoryInput "invalid" "invalid"
        (result, observedPaths) <-
          runMemoryFixture
            structureRejectedDraft
            (requestAt
               semanticsValidationLevel
               model
               (viewByName "Binding")
               [invalid])
            [("model", ByteString.empty), ("invalid", "{")]
        assertSupplementalFailureCount 1 result
        observedPaths @?= ["model", "invalid"]
    , testCase "Structure rejection retains sources but never binds" $ do
        source <- fixtureInput "supplement" "owner-source-strategy.json"
        result <- runFixture structureRejectedDraft [source]
        foldValidateResult
          (const (assertFailure "Structure rejection became a failure"))
          (const (assertFailure "Structure-invalid model was accepted"))
          (\prepared ->
             foldPreparedValidation
               (\_ _ _ supplements diagnostics -> do
                  length supplements @?= 1
                  foldPreparedDiagnosticDocument
                    (\_ _ (SupplementalDiagnosticGroups groups) ->
                       length groups @?= 0)
                    diagnostics)
               prepared)
          (\_ _ -> assertFailure "Binding ran after Structure rejection")
          result
    , testCase "supplement acquisition fails fast without reading later input" $ do
        model <- memoryInput "model" "model"
        missing <- memoryInput "missing" "missing"
        later <- memoryInput "later" "later"
        (result, observedPaths) <-
          runMemoryFixture
            emptyValidateDraft
            (requestAt
               semanticsValidationLevel
               model
               (viewByName "Binding")
               [missing, later])
            [("model", ByteString.empty), ("later", "{")]
        assertCommonFailureCode "command.input-io" result
        observedPaths @?= ["model", "missing"]
    ]
  where
    noSupplementReadAfter expectedStage draft =
      testCase ("does not read supplements after " <> expectedStage) $ do
        model <- memoryInput "model" "model"
        supplement <- memoryInput "supplement" "supplement"
        (result, observedPaths) <-
          runMemoryFixture
            draft
            (requestAt
               semanticsValidationLevel
               model
               (viewByName "Binding")
               [supplement])
            [("model", ByteString.empty)]
        validateResultDisposition result @?= Just validationRejected
        observedPaths @?= ["model"]

assertCommonFailureCode :: Text -> ValidateResult -> Assertion
assertCommonFailureCode expected =
  foldValidateResult
    (foldValidateFailure
       (\common -> commonFailureCode common @?= expected)
       (const (assertFailure "expected a common failure"))
       (const (assertFailure "expected a common failure")))
    (const (assertFailure "expected a failure"))
    (const (assertFailure "expected a failure"))
    (\_ _ -> assertFailure "expected a failure")

assertSupplementalFailureCount :: Int -> ValidateResult -> Assertion
assertSupplementalFailureCount expected =
  foldValidateResult
    (\failure -> do
       foldValidateFailure
         (const (assertFailure "expected a supplemental-input failure"))
         (\defects -> NonEmpty.length defects @?= expected)
         (const (assertFailure "expected a supplemental-input failure"))
         failure
       tool <- validateTool
       let commandError = validateCommandError failure
           document = commandErrorDocument tool commandError
           encoded = encodeCommandErrorDocument document
       commandErrorCode commandError @?= "validate.supplemental-input"
       schemaVariantText (commandErrorDocumentVariant document)
         @?= "validate-failed"
       case expected of
         2 ->
           encoded
             @?= "{\"schema\":\"o2i.command-error/v1\",\"kind\":\"validate-failed\",\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0\"},\"code\":\"validate.supplemental-input\",\"failure\":{\"category\":\"supplemental-input\",\"diagnostics\":[{\"ruleId\":\"core.supplemental.decode.json-syntax\",\"inputOrdinals\":[0],\"reason\":\"invalid-json-syntax\",\"fields\":[]},{\"ruleId\":\"core.supplemental.decode.json-syntax\",\"inputOrdinals\":[1],\"reason\":\"invalid-json-syntax\",\"fields\":[]}]}}"
         _ -> pure ()
       assertCommandErrorSchema encoded)
    (const (assertFailure "expected a failure"))
    (const (assertFailure "expected a failure"))
    (\_ _ -> assertFailure "expected a failure")

assertCommandErrorSchema :: ByteString.ByteString -> Assertion
assertCommandErrorSchema encoded = do
  schema <-
    case Aeson.eitherDecodeStrict commandErrorSchemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  document <- decodeValue encoded
  validateJSONSchema schema document
    @? "Validate command error violates the generated Schema"

requestProjectionTests :: TestTree
requestProjectionTests =
  testCase "projects every closed request shape without supplemental leakage" $ do
    model <- fixtureInput "model" "owner-model.amx"
    supplement <- fixtureInput "supplement" "owner-source-strategy.json"
    adapter <- requireRight (mkAdapterId "amx")
    let selector = viewByName "Binding"
        requests =
          [ ( "notation"
            , notationValidationLevel
            , notationValidateRequest model selector (Just adapter)
            , [])
          , ( "profile"
            , profileValidationLevel
            , profileValidateRequest model selector (Just adapter)
            , [])
          , ( "structure"
            , structureValidationLevel
            , structureValidateRequest model selector (Just adapter)
            , [])
          , ( "semantics"
            , semanticsValidationLevel
            , semanticsValidateRequest
                model
                selector
                (Just adapter)
                [supplement]
            , [supplement])
          ]
    mapM_
      (\(branch, level, request, expectedSupplements) -> do
         validationLevelText (validateRequestLevel request) @?= branch
         validateRequestLevel request @?= level
         validateModelInput request @?= model
         validateAdapterId request @?= Just adapter
         validateSupplementalInputs request @?= expectedSupplements
         foldValidateRequest
           (\_ _ _ -> "notation")
           (\_ _ _ -> "profile")
           (\_ _ _ -> "structure")
           (\_ _ _ _ -> "semantics")
           request
           @?= branch)
      requests

positiveLevelTests :: TestTree
positiveLevelTests =
  testGroup
    "accepts every requested level"
    [ testCase (show level) $ do
      result <- runFixtureAt emptyValidateDraft level []
      validateResultDisposition result @?= Just validationAccepted
      foldValidateResult
        (const (assertFailure "positive Validate failed"))
        (\prepared -> preparedValidationLevel prepared @?= level)
        (const (assertFailure "positive Validate was rejected"))
        (\_ _ -> assertFailure "positive Validate was unavailable")
        result
    | level <-
        [ notationValidationLevel
        , profileValidationLevel
        , structureValidationLevel
        , semanticsValidationLevel
        ]
    ]

data WitnessObservation
  = BindingWitness !Integer
  | StrategyWitness !Text !StrategyFormulationUnavailableReason
  | OtherSemanticWitness
  deriving (Eq, Show)

coreUnavailableWithoutSupplements :: Assertion
coreUnavailableWithoutSupplements = do
  result <- runFixture bindingOwnerDraft []
  validateResultDisposition result @?= Just validationUnavailable
  foldValidateResult
    (const (assertFailure "Validate failed before preparation"))
    (const (assertFailure "Core-unavailable Validate was accepted"))
    (const (assertFailure "Core-unavailable Validate was rejected"))
    (\witnesses prepared -> do
       map observeWitness (NonEmpty.toList witnesses)
         @?= [StrategyWitness "strategy" StrategyFormulationInputMissing]
       let (stages, bindingCounts) = observePreparedDiagnostics prepared
       assertBool
         "pre-Semantics diagnostics escaped their Profile stage"
         (all (== "profile") stages)
       bindingCounts @?= [])
    result

bindingOnlyUnavailable :: Assertion
bindingOnlyUnavailable = do
  supplemental <- fixtureInput "supplement" "owner-source-strategy.json"
  result <- runFixture emptyValidateDraft [supplemental]
  validateResultDisposition result @?= Just validationUnavailable
  foldValidateResult
    (const (assertFailure "Binding-only Validate failed"))
    (const (assertFailure "Binding-only Validate was accepted"))
    (const (assertFailure "Binding-only Validate was rejected"))
    (\witnesses prepared -> do
       map observeWitness (NonEmpty.toList witnesses) @?= [BindingWitness 0]
       let (stages, bindingCounts) = observePreparedDiagnostics prepared
       assertBool
         "Binding-only unavailability manufactured a Semantics diagnostic"
         ("semantics" `notElem` stages)
       bindingCounts @?= [6])
    result

partialBindingWithSemanticDiagnostics :: Assertion
partialBindingWithSemanticDiagnostics = do
  supplemental <- fixtureInput "supplement" "owner-source-strategy.json"
  result <- runFixture bindingAndSemanticRejectedDraft [supplemental]
  validateResultDisposition result @?= Just validationUnavailable
  foldValidateResult
    (const (assertFailure "Validate failed before preparation"))
    (const (assertFailure "partially bound Validate was accepted"))
    (const (assertFailure "partially bound Validate was rejected"))
    (\witnesses prepared -> do
       map observeWitness (NonEmpty.toList witnesses) @?= [BindingWitness 0]
       let (stages, bindingCounts) = observePreparedDiagnostics prepared
       assertBool
         "independent Semantics diagnostics were suppressed"
         ("semantics" `elem` stages)
       bindingCounts @?= [6])
    result

runFixture :: Draft.ProfileDraft -> [InputSource] -> IO ValidateResult
runFixture draft = runFixtureAt draft semanticsValidationLevel

runFixtureAt ::
     Draft.ProfileDraft -> ValidationLevel -> [InputSource] -> IO ValidateResult
runFixtureAt draft level supplements = do
  model <- fixtureInput "model" "owner-model.amx"
  runFixtureRequest
    draft
    (requestAt level model (viewByName "Binding") supplements)

requestAt ::
     ValidationLevel
  -> InputSource
  -> ViewSelector
  -> [InputSource]
  -> ValidateRequest
requestAt level model selector supplements =
  foldValidationLevel
    (notationValidateRequest model selector Nothing)
    (profileValidateRequest model selector Nothing)
    (structureValidateRequest model selector Nothing)
    (semanticsValidateRequest model selector Nothing supplements)
    level

runFixtureRequest :: Draft.ProfileDraft -> ValidateRequest -> IO ValidateResult
runFixtureRequest draft request =
  withFixtureEnvironment draft $ \adapters profiles ->
    runValidate adapters profiles request

withFixtureEnvironment ::
     Draft.ProfileDraft
  -> (AdapterCollection -> ProfileInventory -> IO result)
  -> IO result
withFixtureEnvironment draft consume = do
  adapter <- validateAdapter draft
  adapters <- requireRight (compileAdapterCollection (adapter :| []))
  profiles <-
    foldProfileInventoryCompilation
      (const (assertFailure "Profile inventory rejected" >> fail "unreachable"))
      pure
      (compileProfileInventory [compiledProfileDescriptor])
  consume adapters profiles

validateAdapter :: Draft.ProfileDraft -> IO Adapter
validateAdapter draft = do
  identifier <- requireRight (mkAdapterId "amx")
  descriptor <-
    requireRight
      (mkAdapterDescriptor
         identifier
         "Validate test adapter"
         "1.0.0"
         "archimate-3.2")
  compileCompleteAdapter descriptor [] $ \_ ->
    Right
      (adapterBehavior (const recognitionMatch) (const (decodedDraft draft)))

fixtureInput :: Text -> FilePath -> IO InputSource
fixtureInput referenceText fileName = do
  reference <- requireRight (mkSourceReference referenceText)
  requireRight (fileInput reference ("tst" </> "fixtures" </> fileName))

memoryInput :: Text -> FilePath -> IO InputSource
memoryInput referenceText path = do
  reference <- requireRight (mkSourceReference referenceText)
  requireRight (fileInput reference path)

runMemoryFixture ::
     Draft.ProfileDraft
  -> ValidateRequest
  -> [(FilePath, ByteString.ByteString)]
  -> IO (ValidateResult, [FilePath])
runMemoryFixture draft request sources = do
  readLog <- newIORef []
  result <-
    withFixtureEnvironment draft $ \adapters profiles ->
      runValidateWith
        (acquireWith
           (\path -> do
              modifyIORef' readLog (<> [path])
              case lookup path sources of
                Nothing -> ioError (userError ("missing source: " <> path))
                Just bytes -> pure bytes)
           (ioError (userError "unexpected stdin read")))
        adapters
        profiles
        request
  observed <- readIORef readLog
  pure (result, observed)

observeWitness :: ValidateUnavailabilityWitness -> WitnessObservation
observeWitness =
  foldValidateUnavailabilityWitness
    (BindingWitness . fromIntegral . sourceOrdinalValue)
    (\subject reason -> StrategyWitness (modelIdentityText subject) reason)
    (\_ _ _ -> OtherSemanticWitness)
    (\_ _ -> OtherSemanticWitness)
    (\_ _ _ _ -> OtherSemanticWitness)

observePreparedDiagnostics :: PreparedValidation -> ([Text], [Int])
observePreparedDiagnostics prepared =
  foldPreparedDiagnosticDocument
    (\_ diagnostics groups ->
       (map preparedDiagnosticStage diagnostics, groupCounts groups))
    (preparedValidationDiagnostics prepared)
  where
    groupCounts (SupplementalDiagnosticGroups groups) =
      [length evidence | SupplementalDiagnosticGroup _ evidence <- groups]

bindingOwnerDraft :: Draft.ProfileDraft
bindingOwnerDraft = validateDraft False

bindingAndSemanticRejectedDraft :: Draft.ProfileDraft
bindingAndSemanticRejectedDraft = validateDraft True

validateDraft :: Bool -> Draft.ProfileDraft
validateDraft includeNeed =
  validateDraftFrom
    ([("strategy", "Grouping", "Strategy")]
       <> if includeNeed
            then [("need", "Grouping", "Need")]
            else [])

emptyValidateDraft :: Draft.ProfileDraft
emptyValidateDraft = validateDraftFrom []

validateDraftFrom :: [(Text, Text, Text)] -> Draft.ProfileDraft
validateDraftFrom elements = validateDraftWithExtraMembers elements []

validateDraftWithExtraMembers ::
     [(Text, Text, Text)]
  -> [Draft.DraftMember Draft.ModelRootRole]
  -> Draft.ProfileDraft
validateDraftWithExtraMembers elements extras =
  Draft.profileDraft
    (Draft.modelRootDraft
       (draftIdentity "model")
       (draftLocation "model")
       (draftProperty "model-profile" "o2i.profile" "o2i.archimate-profile@0.3"
          : map (Draft.childRecordMember . uncurry3 typedElement) elements
              <> extras
              <> [ Draft.childRecordMember
                     (Draft.viewDraft
                        (draftIdentity "binding-view")
                        (draftLocation "binding-view")
                        (Draft.nameFieldMember
                           [ Draft.draftTextScalar
                               "Binding"
                               (draftLocation "view-name")
                           ]
                           (draftLocation "view-name-field")
                           : map
                               (Draft.childRecordMember . viewNode . first3)
                               elements))
                 ]))

typedElement :: Text -> Text -> Text -> Draft.ElementDraft
typedElement identifier archiMateType o2iType =
  Draft.elementDraft
    (draftIdentity identifier)
    (draftLocation identifier)
    [ Draft.typeFieldMember
        [ Draft.draftTextScalar
            archiMateType
            (draftLocation (identifier <> "-type"))
        ]
        (draftLocation (identifier <> "-type-field"))
    , draftProperty (identifier <> "-o2i-type") "o2i.type" o2iType
    , draftProperty (identifier <> "-commitment") "o2i.commitment" "asserted"
    ]

notationRejectedDraft :: Draft.ProfileDraft
notationRejectedDraft =
  validateDraftWithExtraMembers
    [("strategy", "Driver", "Strategy"), ("need", "Grouping", "Need")]
    [Draft.childRecordMember (typedElement "model" "Grouping" "Strategy")]

profileRejectedDraft :: Draft.ProfileDraft
profileRejectedDraft =
  validateDraftFrom
    [("strategy", "Driver", "Strategy"), ("need", "Grouping", "Need")]

structureRejectedDraft :: Draft.ProfileDraft
structureRejectedDraft =
  validateDraftFrom
    [ ("strategy", "Grouping", "Strategy")
    , ("driver", "Driver", "Driver")
    , ("need", "Grouping", "Need")
    ]

semanticsRejectedDraft :: Draft.ProfileDraft
semanticsRejectedDraft = validateDraftFrom [("need", "Grouping", "Need")]

first3 :: (first, second, third) -> first
first3 (value, _, _) = value

uncurry3 ::
     (first -> second -> third -> result) -> (first, second, third) -> result
uncurry3 function (first, second, third) = function first second third

viewNode :: Text -> Draft.ViewNodeDraft
viewNode target =
  Draft.viewNodeDraft
    (draftIdentity (target <> "-node"))
    (draftLocation (target <> "-node"))
    [ Draft.referenceMember
        (Draft.viewNodeElementReference
           (draftIdentity target)
           (draftLocation (target <> "-node-target")))
    ]

draftProperty :: Text -> Text -> Text -> Draft.DraftMember scope
draftProperty identifier key value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey
          [Draft.draftTextScalar key (draftLocation (identifier <> "-key"))])
       [Draft.draftTextScalar value (draftLocation (identifier <> "-value"))]
       (draftLocation identifier)
       [])

draftIdentity :: Text -> Draft.DraftIdentity scope
draftIdentity value =
  Draft.draftIdentity
    [Draft.draftTextScalar value (draftLocation (value <> "-identity"))]

draftLocation :: Text -> Draft.DraftLocation
draftLocation value =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing value) 1)
       [])
    Nothing

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
