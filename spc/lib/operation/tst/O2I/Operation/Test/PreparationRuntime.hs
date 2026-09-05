{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.PreparationRuntime
  ( tests
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.ArchiMate.Profile.Notation
  ( canonicalOccurrenceOrdinal
  , canonicalViewOccurrence
  )
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , compiledProfileDescriptor
  , foldProfileDescriptor
  )
import O2I.Core.Identity (modelIdentity, modelIdentityText)
import O2I.Operation.Acquisition (acquireSource, acquiredModelSource, fileInput)
import O2I.Operation.Acquisition.Internal
  ( AcquiredModelSource(..)
  , AcquiredSource(..)
  )
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Failure
import qualified O2I.Operation.Human.Failure.Internal as HumanFailure
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Preparation
import O2I.Operation.Profile
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import O2I.Operation.Request
import O2I.Operation.Rule.Catalog
  ( OperationRule
  , operationRuleIdText
  , operationRuleIdentity
  )
import O2I.Operation.Test.AdapterSupport
  ( compileCompleteAdapter
  , nativeRuleSpec
  , resolveNativeRule
  )
import O2I.Operation.View
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertFailure, testCase)

tests :: TestTree
tests =
  testGroup
    "shared preparation runtime"
    [ testCase "executes the accepted prefix and delays exact inputs" accepted
    , testCase
        "derives the prepared model from the exact acquired bytes"
        acquiredOwnerModelMutation
    , testCase "retains every Adapter-selection branch" adapterSelectionCases
    , testCase "retains the exact Adapter-decode cause" adapterDecodeCase
    , testCase "retains invalid marker evidence" invalidMarkerCase
    , testCase "retains all six Profile-resolution failures" resolutionCases
    , testCase "retains both Profile-compatibility failures" compatibilityCases
    , testCase "retains all four View-selection failures" viewCases
    ]

data InputObservation
  = ValidationInputs [Text]
  | TraceInputs
  | QualificationInputs [Text]
  | ReadinessInputs Text [Text]
  | AssessmentInputs Text [Text]
  deriving (Eq, Show)

data SuccessfulPrefix =
  SuccessfulPrefix !Text !Text !Natural !InputObservation
  deriving (Eq, Show)

data CauseObservation
  = SelectionUnknown !Text
  | SelectionRecognition !Text !Int
  | SelectionNoMatch
  | SelectionMultiple ![Text]
  | DecodeRejected !Text !Int
  | MarkerRejected !Int
  | ResolutionMissing !Text
  | ResolutionProperties !Text !Int
  | ResolutionValues !Text !Int
  | ResolutionKind !Text !Text
  | ResolutionGrammar !Text !Text
  | ResolutionUnknown !Text !Text
  | CompatibilityAdapter !Text ![Text]
  | CompatibilityNotation !Text !Text
  | ViewUnknown
  | ViewAmbiguousName !Int
  | ViewAmbiguousIdentity !Int
  | ViewWrongFamily
  deriving (Eq, Show)

data FailureObservation =
  FailureObservation
    !Text
    !Text
    !CauseObservation
    !CauseObservation
    ![Text]
    ![Text]
  deriving (Eq, Show)

accepted :: Assertion
accepted = do
  environment <- acceptedEnvironment acceptedDraft
  first <- reference "first"
  second <- reference "second"
  identity <- requireRight (modelIdentity "view")
  let selector = viewByIdentity identity
      cases =
        [ (validationRequest selector [first], ValidationInputs ["first"])
        , (traceRequest selector, TraceInputs)
        , ( qualificationRequest selector [first, second]
          , QualificationInputs ["first", "second"])
        , ( readinessRequest selector first [second]
          , ReadinessInputs "first" ["second"])
        , ( assessmentRequest selector first [second]
          , AssessmentInputs "first" ["second"])
        ]
  mapM_
    (\(request, inputs) ->
       runPrefix environment Nothing request
         @?= Right (SuccessfulPrefix "amx" "o2i.archimate-profile@0.3" 1 inputs))
    cases

acquiredOwnerModelMutation :: Assertion
acquiredOwnerModelMutation = do
  adapter <- ownerVerticalAdapter
  adapters <- collection [adapter]
  profileInventory <- profiles
  viewIdentity <- requireRight (modelIdentity "view")
  acquired <-
    acquireFixture ModelRole 0 "owner-model-mutated" "owner-model-mutated.amx"
  model <-
    case acquiredModelSource acquired of
      Nothing ->
        assertFailure "model role was not retained" >> fail "unreachable"
      Just value -> pure value
  case withPreparedSelectedView
         adapters
         profileInventory
         Nothing
         (traceRequest (viewByIdentity viewIdentity))
         model
         (const (Left ()))
         (\_ _ _ _ _ _ _ _ -> Right ()) of
    Left () -> pure ()
    Right () ->
      assertFailure "changed acquired bytes did not change the prepared model"

acquireFixture :: SourceRole -> Natural -> Text -> FilePath -> IO AcquiredSource
acquireFixture role ordinal referenceText fileName = do
  sourceReference <- reference referenceText
  input <-
    requireRight (fileInput sourceReference ("tst" </> "fixtures" </> fileName))
  result <- acquireSource role (sourceOrdinal ordinal) input
  case result of
    Left _ -> assertFailure "fixture acquisition failed" >> fail "unreachable"
    Right acquired -> pure acquired

adapterSelectionCases :: Assertion
adapterSelectionCases = do
  profileInventory <- profiles
  model <- acquiredModel
  matching <- simpleAdapter "amx" "archimate-3.2" True acceptedDraft
  other <- simpleAdapter "other" "archimate-3.2" True acceptedDraft
  unmatched <- simpleAdapter "none" "archimate-3.2" False acceptedDraft
  recognition <- recognitionFailureAdapter "broken"
  matchingCollection <- collection [matching]
  noMatchCollection <- collection [unmatched]
  recognitionCollection <- collection [recognition]
  multipleCollection <- collection [matching, other]
  missing <- requireRight (mkAdapterId "missing")
  let request = traceRequest (viewByName "Main")
  assertTerminatingFailure
    (runtimeEnvironment matchingCollection profileInventory model)
    (Just missing)
    request
    (failure
       "preparation.adapter-selection"
       adapterSelectionStage
       (SelectionUnknown "missing"))
  assertTerminatingFailure
    (runtimeEnvironment recognitionCollection profileInventory model)
    Nothing
    request
    (failure
       "preparation.adapter-selection"
       adapterSelectionStage
       (SelectionRecognition "broken" 1))
  assertTerminatingFailure
    (runtimeEnvironment noMatchCollection profileInventory model)
    Nothing
    request
    (failure
       "preparation.adapter-selection"
       adapterSelectionStage
       SelectionNoMatch)
  assertTerminatingFailure
    (runtimeEnvironment multipleCollection profileInventory model)
    Nothing
    request
    (failure
       "preparation.adapter-selection"
       adapterSelectionStage
       (SelectionMultiple ["amx", "other"]))

adapterDecodeCase :: Assertion
adapterDecodeCase = do
  profileInventory <- profiles
  model <- acquiredModel
  adapter <- decodeFailureAdapter "amx"
  adapters <- collection [adapter]
  assertTerminatingFailure
    (runtimeEnvironment adapters profileInventory model)
    Nothing
    (traceRequest (viewByName "Main"))
    (failure
       "preparation.adapter-decode"
       adapterDecodeStage
       (DecodeRejected "amx" 1))

invalidMarkerCase :: Assertion
invalidMarkerCase = do
  environment <- acceptedEnvironment invalidMarkerDraft
  assertTerminatingFailure
    environment
    Nothing
    (traceRequest (viewByName "Main"))
    (failure "preparation.profile-marker" profileMarkerStage (MarkerRejected 1))

resolutionCases :: Assertion
resolutionCases = do
  let cases =
        [ ( markerlessDraft
          , "bootstrap.profile-reference.missing"
          , ResolutionMissing "o2i.profile")
        , ( propertyMultiplicityDraft
          , "bootstrap.profile-reference.property-multiplicity"
          , ResolutionProperties "o2i.profile" 2)
        , ( valueMultiplicityDraft
          , "bootstrap.profile-reference.value-multiplicity"
          , ResolutionValues "o2i.profile" 2)
        , ( valueKindDraft
          , "bootstrap.profile-reference.value-kind"
          , ResolutionKind "o2i.profile" "boolean")
        , ( grammarDraft
          , "bootstrap.profile-reference.grammar"
          , ResolutionGrammar "o2i.profile" "invalid")
        , ( unknownProfileDraft
          , "bootstrap.profile-reference.unknown"
          , ResolutionUnknown "o2i.profile" "unknown.profile@1.2")
        ]
  mapM_
    (\(draft, code, cause) -> do
       environment <- acceptedEnvironment draft
       assertTerminatingFailure
         environment
         Nothing
         (traceRequest (viewByName "Main"))
         (failure code profileResolutionStage cause))
    cases

compatibilityCases :: Assertion
compatibilityCases = do
  profileInventory <- profiles
  model <- acquiredModel
  unadmitted <- simpleAdapter "other" "archimate-3.2" True acceptedDraft
  mismatch <- simpleAdapter "amx" "other-notation" True acceptedDraft
  unadmittedCollection <- collection [unadmitted]
  mismatchCollection <- collection [mismatch]
  let request = traceRequest (viewByName "Main")
  assertTerminatingFailure
    (runtimeEnvironment unadmittedCollection profileInventory model)
    Nothing
    request
    (failure
       "bootstrap.profile-adapter.adapter-id"
       profileCompatibilityStage
       (CompatibilityAdapter "other" ["amx"]))
  assertTerminatingFailure
    (runtimeEnvironment mismatchCollection profileInventory model)
    Nothing
    request
    (failure
       "bootstrap.profile-adapter.notation"
       profileCompatibilityStage
       (CompatibilityNotation "archimate-3.2" "other-notation"))

viewCases :: Assertion
viewCases = do
  identity <- requireRight (modelIdentity "shared")
  elementIdentity <- requireRight (modelIdentity "element")
  let cases =
        [ (acceptedDraft, viewByName "Absent", ViewUnknown)
        , (duplicateNameDraft, viewByName "Repeated", ViewAmbiguousName 2)
        , ( duplicateIdentityDraft
          , viewByIdentity identity
          , ViewAmbiguousIdentity 2)
        , (wrongFamilyDraft, viewByIdentity elementIdentity, ViewWrongFamily)
        ]
  mapM_
    (\(draft, selector, cause) -> do
       environment <- acceptedEnvironment draft
       assertTerminatingFailure
         environment
         Nothing
         (traceRequest selector)
         (failure "preparation.view-selection" viewSelectionStage cause))
    cases

data RuntimeEnvironment =
  RuntimeEnvironment !AdapterCollection !ProfileInventory !AcquiredModelSource

runtimeEnvironment ::
     AdapterCollection
  -> ProfileInventory
  -> AcquiredSource
  -> RuntimeEnvironment
runtimeEnvironment adapters profileInventory model =
  RuntimeEnvironment adapters profileInventory (AcquiredModelSource model)

acceptedEnvironment :: Draft.ProfileDraft -> IO RuntimeEnvironment
acceptedEnvironment draft = do
  adapter <- simpleAdapter "amx" "archimate-3.2" True draft
  adapters <- collection [adapter]
  profileInventory <- profiles
  RuntimeEnvironment adapters profileInventory . AcquiredModelSource
    <$> acquiredModel

runPrefix ::
     RuntimeEnvironment
  -> Maybe AdapterId
  -> RequestedContract
  -> Either FailureObservation SuccessfulPrefix
runPrefix (RuntimeEnvironment adapters profileInventory model) requestedAdapter request =
  withPreparedSelectedView
    adapters
    profileInventory
    requestedAdapter
    request
    model
    (Left . observeFailure)
    (\_ selected resolved _ _ selectedView _ inputs ->
       Right
         (SuccessfulPrefix
            (adapterIdText
               (adapterDescriptorId (selectedAdapterDescriptor selected)))
            (resolvedProfileReference resolved)
            (canonicalOccurrenceOrdinal
               (canonicalViewOccurrence (selectedViewDescriptor selectedView)))
            (observeInputs inputs)))

assertTerminatingFailure ::
     RuntimeEnvironment
  -> Maybe AdapterId
  -> RequestedContract
  -> FailureObservation
  -> Assertion
assertTerminatingFailure (RuntimeEnvironment adapters profileInventory model) requestedAdapter request expected = do
  completions <- newIORef (0 :: Int)
  actual <-
    withPreparedSelectedView
      adapters
      profileInventory
      requestedAdapter
      request
      model
      (pure . Left . observeFailure)
      (\_ _ _ _ _ _ _ _ -> do
         modifyIORef' completions (+ 1)
         pure (Right (SuccessfulPrefix "unexpected" "unexpected" 0 TraceInputs)))
  case (actual, expected) of
    (Left (FailureObservation actualCode actualStage rawCause humanCause rawExact humanExact), FailureObservation expectedCode expectedStage expectedCause _ _ _) -> do
      (actualCode, actualStage, rawCause)
        @?= (expectedCode, expectedStage, expectedCause)
      humanCause @?= rawCause
      humanExact @?= rawExact
    (Right successful, _) ->
      assertFailure ("unexpected preparation success: " <> show successful)
  readIORef completions >>= (@?= 0)

failure :: Text -> PreparationStage -> CauseObservation -> FailureObservation
failure code stage cause =
  FailureObservation code (preparationStageText stage) cause cause [] []

observeFailure :: PreparationFailure -> FailureObservation
observeFailure value =
  FailureObservation
    (preparationFailureCode value)
    (preparationStageText (preparationFailureStage value))
    (foldPreparationFailure
       observeSelection
       (\descriptor diagnostics ->
          DecodeRejected (descriptorId descriptor) (NonEmpty.length diagnostics))
       (MarkerRejected . length)
       observeResolution
       observeCompatibility
       observeView
       value)
    (observeHumanPreparation (HumanFailure.projectHumanPreparationFailure value))
    (observeRawPreparationExact value)
    (observeHumanPreparationExact
       (HumanFailure.projectHumanPreparationFailure value))

observeHumanPreparation ::
     HumanFailure.HumanPreparationFailure -> CauseObservation
observeHumanPreparation =
  HumanFailure.foldHumanPreparationFailure
    (\_ selection ->
       HumanFailure.foldHumanAdapterSelectionFailure
         SelectionUnknown
         (\failures ->
            let (descriptor, diagnostics) = NonEmpty.head failures
             in SelectionRecognition
                  (humanDescriptorId descriptor)
                  (NonEmpty.length diagnostics))
         SelectionNoMatch
         (SelectionMultiple . map humanDescriptorId . NonEmpty.toList)
         selection)
    (\_ descriptor diagnostics ->
       DecodeRejected
         (humanDescriptorId descriptor)
         (NonEmpty.length diagnostics))
    (\_ candidates -> MarkerRejected (length candidates))
    (\_ resolution ->
       HumanFailure.foldHumanProfileResolutionFailure
         (\_ key -> ResolutionMissing key)
         (\_ key properties -> ResolutionProperties key (length properties))
         (\_ key _ values -> ResolutionValues key (length values))
         (\_ key _ kind ->
            ResolutionKind
              key
              (HumanFailure.foldHumanFailureDraftValueKind
                 "text"
                 "boolean"
                 "number"
                 "native-name"
                 id
                 kind))
         (\_ key value -> ResolutionGrammar key (humanDraftScalarText value))
         (\_ key referenceValue -> ResolutionUnknown key referenceValue)
         resolution)
    (\_ compatibility ->
       HumanFailure.foldHumanProfileCompatibilityFailure
         (\_ _ descriptor admitted ->
            CompatibilityAdapter (humanDescriptorId descriptor) admitted)
         (\_ _ _ profileNotation adapterNotation ->
            CompatibilityNotation profileNotation adapterNotation)
         compatibility)
    (\_ viewFailure ->
       HumanFailure.foldHumanViewSelectionFailure
         (\_ -> ViewUnknown)
         (\_ candidates -> ViewAmbiguousName (NonEmpty.length candidates))
         (\_ candidates -> ViewAmbiguousIdentity (NonEmpty.length candidates))
         (\_ _ -> ViewWrongFamily)
         viewFailure)

observeRawPreparationExact :: PreparationFailure -> [Text]
observeRawPreparationExact failureValue =
  preparationFailureCode failureValue
    : foldPreparationFailure
        (("adapter-selection" :) . observeRawAdapterSelection)
        (\descriptor diagnostics ->
           "adapter-decode"
             : observeRawAdapterDescriptor descriptor
                 <> observeItems
                      observeRawAdapterDiagnostic
                      (NonEmpty.toList diagnostics))
        (("profile-marker" :) . observeItems observeRawMarkerCandidate)
        (("profile-resolution" :) . observeRawProfileResolution)
        (("profile-compatibility" :) . observeRawProfileCompatibility)
        (("view-selection" :) . observeRawViewSelection)
        failureValue

observeHumanPreparationExact :: HumanFailure.HumanPreparationFailure -> [Text]
observeHumanPreparationExact =
  HumanFailure.foldHumanPreparationFailure
    (\code failureValue ->
       code : "adapter-selection" : observeHumanAdapterSelection failureValue)
    (\code descriptor diagnostics ->
       code
         : "adapter-decode"
         : observeHumanAdapterDescriptor descriptor
             <> observeItems
                  observeHumanAdapterDiagnostic
                  (NonEmpty.toList diagnostics))
    (\code candidates ->
       code
         : "profile-marker"
         : observeItems observeHumanMarkerCandidate candidates)
    (\code failureValue ->
       code : "profile-resolution" : observeHumanProfileResolution failureValue)
    (\code failureValue ->
       code
         : "profile-compatibility"
         : observeHumanProfileCompatibility failureValue)
    (\code failureValue ->
       code : "view-selection" : observeHumanViewSelection failureValue)

observeRawAdapterSelection :: AdapterSelectionError -> [Text]
observeRawAdapterSelection =
  foldAdapterSelectionError
    (\identifier -> ["unknown", adapterIdText identifier])
    (\failures ->
       "recognition"
         : observeItems
             (\(descriptor, diagnostics) ->
                observeRawAdapterDescriptor descriptor
                  <> observeItems
                       observeRawAdapterDiagnostic
                       (NonEmpty.toList diagnostics))
             (NonEmpty.toList failures))
    ["no-match"]
    (\descriptors ->
       "multiple"
         : observeItems
             observeRawAdapterDescriptor
             (NonEmpty.toList descriptors))

observeHumanAdapterSelection ::
     HumanFailure.HumanAdapterSelectionFailure -> [Text]
observeHumanAdapterSelection =
  HumanFailure.foldHumanAdapterSelectionFailure
    (\identifier -> ["unknown", identifier])
    (\failures ->
       "recognition"
         : observeItems
             (\(descriptor, diagnostics) ->
                observeHumanAdapterDescriptor descriptor
                  <> observeItems
                       observeHumanAdapterDiagnostic
                       (NonEmpty.toList diagnostics))
             (NonEmpty.toList failures))
    ["no-match"]
    (\descriptors ->
       "multiple"
         : observeItems
             observeHumanAdapterDescriptor
             (NonEmpty.toList descriptors))

observeRawAdapterDescriptor :: AdapterDescriptor -> [Text]
observeRawAdapterDescriptor =
  foldAdapterDescriptor $ \identifier name version notation ->
    [adapterIdText identifier, name, version, notation]

observeHumanAdapterDescriptor :: HumanValue.HumanAdapterDescriptor -> [Text]
observeHumanAdapterDescriptor =
  HumanValue.foldHumanAdapterDescriptor $ \identifier name version notation ->
    [identifier, name, version, notation]

observeRawAdapterDiagnostic :: AdapterDiagnostic -> [Text]
observeRawAdapterDiagnostic diagnostic =
  observeRawAdapterRule (adapterDiagnosticRule diagnostic)
    <> observeItems
         observeRawAdapterOccurrence
         (NonEmpty.toList (adapterDiagnosticOccurrences diagnostic))

observeHumanAdapterDiagnostic ::
     HumanFailure.HumanFailureAdapterDiagnostic -> [Text]
observeHumanAdapterDiagnostic =
  HumanFailure.foldHumanFailureAdapterDiagnostic $ \rule occurrences ->
    observeHumanAdapterRule rule
      <> observeItems
           observeHumanAdapterOccurrence
           (NonEmpty.toList occurrences)

observeRawAdapterRule :: AdapterRule -> [Text]
observeRawAdapterRule =
  foldAdapterRule $ \identity stage expectation meaning action ->
    [ adapterRuleIdText identity
    , foldAdapterRuleStage "preparation" "notation" stage
    , expectation
    , meaning
    , action
    ]

observeHumanAdapterRule :: HumanFailure.HumanFailureAdapterRule -> [Text]
observeHumanAdapterRule =
  HumanFailure.foldHumanFailureAdapterRule $ \identity stage expectation meaning action ->
    [ identity
    , HumanFailure.foldHumanFailureAdapterRuleStage
        "preparation"
        "notation"
        stage
    , expectation
    , meaning
    , action
    ]

observeRawAdapterOccurrence :: AdapterOccurrence -> [Text]
observeRawAdapterOccurrence =
  foldAdapterOccurrence ["unlocated"] (("located" :) . observeRawNativeLocation)

observeHumanAdapterOccurrence ::
     HumanFailure.HumanFailureAdapterOccurrence -> [Text]
observeHumanAdapterOccurrence =
  HumanFailure.foldHumanFailureAdapterOccurrence $ \locationValue ->
    case locationValue of
      Nothing -> ["unlocated"]
      Just locationValue' ->
        "located" : observeHumanNativeLocation locationValue'

observeRawNativeLocation :: NativeLocation -> [Text]
observeRawNativeLocation =
  foldNativeLocation
    (\offset -> ["byte-offset", naturalText offset])
    (\line column -> ["line-column", naturalText line, naturalText column])
    (\path -> "path" : observeItems pureText (NonEmpty.toList path))

observeHumanNativeLocation :: HumanFailure.HumanFailureNativeLocation -> [Text]
observeHumanNativeLocation =
  HumanFailure.foldHumanFailureNativeLocation
    (\offset -> ["byte-offset", naturalText offset])
    (\line column -> ["line-column", naturalText line, naturalText column])
    (\path -> "path" : observeItems pureText (NonEmpty.toList path))

observeRawProfileResolution :: ProfileResolutionFailure -> [Text]
observeRawProfileResolution =
  foldProfileResolutionFailure
    (\rule key -> ["missing", observeOperationRule rule, key])
    (\rule key properties ->
       ["property-multiplicity", observeOperationRule rule, key]
         <> observeItems observeRawCanonicalProperty properties)
    (\rule key property values ->
       ["value-multiplicity", observeOperationRule rule, key]
         <> observeRawCanonicalProperty property
         <> observeItems observeRawDraftScalar values)
    (\rule key scalarValue kind ->
       ["value-kind", observeOperationRule rule, key]
         <> observeRawDraftScalar scalarValue
         <> [observeRawDraftValueKind kind])
    (\rule key scalarValue ->
       ["grammar", observeOperationRule rule, key]
         <> observeRawDraftScalar scalarValue)
    (\rule key referenceValue ->
       ["unknown", observeOperationRule rule, key, referenceValue])

observeHumanProfileResolution ::
     HumanFailure.HumanProfileResolutionFailure -> [Text]
observeHumanProfileResolution =
  HumanFailure.foldHumanProfileResolutionFailure
    (\rule key -> ["missing", rule, key])
    (\rule key properties ->
       ["property-multiplicity", rule, key]
         <> observeItems observeHumanCanonicalProperty properties)
    (\rule key property values ->
       ["value-multiplicity", rule, key]
         <> observeHumanCanonicalProperty property
         <> observeItems observeHumanDraftScalar values)
    (\rule key scalarValue kind ->
       ["value-kind", rule, key]
         <> observeHumanDraftScalar scalarValue
         <> [observeHumanDraftValueKind kind])
    (\rule key scalarValue ->
       ["grammar", rule, key] <> observeHumanDraftScalar scalarValue)
    (\rule key referenceValue -> ["unknown", rule, key, referenceValue])

observeRawProfileCompatibility :: ProfileCompatibilityFailure -> [Text]
observeRawProfileCompatibility =
  foldProfileCompatibilityFailure
    (\rule profile descriptor admitted ->
       ["adapter-not-admitted", observeOperationRule rule]
         <> observeRawProfileDescriptor (resolvedProfileDescriptor profile)
         <> observeRawAdapterDescriptor descriptor
         <> observeItems pureText admitted)
    (\rule profile descriptor profileNotation adapterNotation ->
       ["notation-mismatch", observeOperationRule rule]
         <> observeRawProfileDescriptor (resolvedProfileDescriptor profile)
         <> observeRawAdapterDescriptor descriptor
         <> [profileNotation, adapterNotation])

observeHumanProfileCompatibility ::
     HumanFailure.HumanProfileCompatibilityFailure -> [Text]
observeHumanProfileCompatibility =
  HumanFailure.foldHumanProfileCompatibilityFailure
    (\rule profile descriptor admitted ->
       ["adapter-not-admitted", rule]
         <> observeHumanProfileDescriptor profile
         <> observeHumanAdapterDescriptor descriptor
         <> observeItems pureText admitted)
    (\rule profile descriptor profileNotation adapterNotation ->
       ["notation-mismatch", rule]
         <> observeHumanProfileDescriptor profile
         <> observeHumanAdapterDescriptor descriptor
         <> [profileNotation, adapterNotation])

observeRawProfileDescriptor :: ProfileDescriptor -> [Text]
observeRawProfileDescriptor =
  foldProfileDescriptor $ \identity token version notation adapters digest ->
    [identity, token, version, notation]
      <> observeItems pureText adapters
      <> [digest]

observeHumanProfileDescriptor :: HumanValue.HumanProfileDescriptor -> [Text]
observeHumanProfileDescriptor =
  HumanValue.foldHumanProfileDescriptor $ \identity token version notation adapters digest ->
    [identity, token, version, notation]
      <> observeItems pureText adapters
      <> [digest]

observeRawViewSelection :: ViewSelectionFailure document -> [Text]
observeRawViewSelection =
  foldViewSelectionFailure
    (\selector -> ["unknown"] <> observeRawViewSelector selector)
    (\selector candidates ->
       ["ambiguous-name"]
         <> observeRawViewSelector selector
         <> observeItems observeRawViewDescriptor (NonEmpty.toList candidates))
    (\selector candidates ->
       ["ambiguous-identity"]
         <> observeRawViewSelector selector
         <> observeItems observeRawViewCandidate (NonEmpty.toList candidates))
    (\selector candidate ->
       ["wrong-family"]
         <> observeRawViewSelector selector
         <> observeRawViewCandidate candidate)

observeHumanViewSelection :: HumanFailure.HumanViewSelectionFailure -> [Text]
observeHumanViewSelection =
  HumanFailure.foldHumanViewSelectionFailure
    (\selector -> ["unknown"] <> observeHumanViewSelector selector)
    (\selector candidates ->
       ["ambiguous-name"]
         <> observeHumanViewSelector selector
         <> observeItems observeHumanViewDescriptor (NonEmpty.toList candidates))
    (\selector candidates ->
       ["ambiguous-identity"]
         <> observeHumanViewSelector selector
         <> observeItems observeHumanViewCandidate (NonEmpty.toList candidates))
    (\selector candidate ->
       ["wrong-family"]
         <> observeHumanViewSelector selector
         <> observeHumanViewCandidate candidate)

observeRawViewSelector :: ViewSelector -> [Text]
observeRawViewSelector =
  foldViewSelector
    (\name -> ["name", name])
    (\identity -> ["identity", modelIdentityText identity])

observeHumanViewSelector :: HumanValue.HumanViewSelector -> [Text]
observeHumanViewSelector =
  HumanValue.foldHumanViewSelector
    (\name -> ["name", name])
    (\identity -> ["identity", HumanValue.foldHumanModelIdentity id identity])

observeRawViewDescriptor :: Notation.CanonicalView document -> [Text]
observeRawViewDescriptor descriptor =
  observeRawCanonicalOccurrence (Notation.canonicalViewOccurrence descriptor)
    <> observeRawIdentityOutcome (Notation.canonicalViewIdentity descriptor)
    <> observeItems
         observeRawCanonicalField
         (Notation.canonicalViewNameFields descriptor)
    <> observeRawSourceLocation (Notation.canonicalViewLocation descriptor)

observeHumanViewDescriptor :: HumanValue.HumanViewDescriptor -> [Text]
observeHumanViewDescriptor =
  HumanValue.foldHumanViewDescriptor $ \occurrence identity fields locationValue ->
    observeHumanCanonicalOccurrence occurrence
      <> observeHumanIdentityOutcome identity
      <> observeItems observeHumanCanonicalField fields
      <> observeHumanSourceLocation locationValue

observeRawViewCandidate :: ViewSelectionCandidate document -> [Text]
observeRawViewCandidate =
  foldViewSelectionCandidate $ \occurrence family identity locationValue ->
    observeRawCanonicalOccurrence occurrence
      <> [observeRawRecordFamily family]
      <> observeMaybe (pureText . modelIdentityText) identity
      <> observeRawSourceLocation locationValue

observeHumanViewCandidate ::
     HumanFailure.HumanFailureViewSelectionCandidate -> [Text]
observeHumanViewCandidate =
  HumanFailure.foldHumanFailureViewSelectionCandidate $ \occurrence family identity locationValue ->
    observeHumanCanonicalOccurrence occurrence
      <> [observeHumanRecordFamily family]
      <> observeMaybe
           (\value -> [HumanValue.foldHumanModelIdentity id value])
           identity
      <> observeHumanSourceLocation locationValue

observeRawMarkerCandidate :: Notation.MarkerCandidate -> [Text]
observeRawMarkerCandidate candidate =
  observeRawCanonicalProperty (Notation.markerCandidateProperty candidate)
    <> observeItems
         observeRawCanonicalField
         (Notation.markerCandidateDefinitionFields candidate)
    <> Notation.foldMarkerKeyOutcome
         ["key-missing"]
         (\values -> "key-multiple" : observeItems observeRawDraftScalar values)
         (("key-non-text" :) . observeRawDraftScalar)
         (("key-exact" :) . observeRawDraftScalar)
         (("key-other" :) . observeRawDraftScalar)
         (("key-reference-rejected" :) . observeRawCanonicalReference)
         (Notation.markerCandidateKeyOutcome candidate)

observeHumanMarkerCandidate ::
     HumanFailure.HumanFailureMarkerCandidate -> [Text]
observeHumanMarkerCandidate =
  HumanFailure.foldHumanFailureMarkerCandidate $ \property fields outcome ->
    observeHumanCanonicalProperty property
      <> observeItems observeHumanCanonicalField fields
      <> HumanFailure.foldHumanFailureMarkerKeyOutcome
           ["key-missing"]
           (\values ->
              "key-multiple" : observeItems observeHumanDraftScalar values)
           (("key-non-text" :) . observeHumanDraftScalar)
           (("key-exact" :) . observeHumanDraftScalar)
           (("key-other" :) . observeHumanDraftScalar)
           (("key-reference-rejected" :) . observeHumanCanonicalReference)
           outcome

observeRawCanonicalProperty :: Notation.CanonicalProperty -> [Text]
observeRawCanonicalProperty property =
  observeRawCanonicalOccurrence (Notation.canonicalPropertyOccurrence property)
    <> observeRawCanonicalOccurrence (Notation.canonicalPropertyOwner property)
    <> [observeRawRecordFamily (Notation.canonicalPropertyOwnerFamily property)]
    <> observeRawSourceLocation (Notation.canonicalPropertyLocation property)
    <> observeItems
         observeRawDraftScalar
         (Notation.canonicalPropertyValues property)
    <> observeItems
         observeRawOpaqueEvidence
         (Notation.canonicalPropertyOpaqueEvidence property)
    <> Notation.foldCanonicalPropertyKey
         (\values -> "direct-key" : observeItems observeRawDraftScalar values)
         (("referenced-key" :) . observeRawCanonicalReference)
         property

observeHumanCanonicalProperty ::
     HumanFailure.HumanFailureCanonicalProperty -> [Text]
observeHumanCanonicalProperty =
  HumanFailure.foldHumanFailureCanonicalProperty $ \occurrence owner family locationValue values opaque key ->
    observeHumanCanonicalOccurrence occurrence
      <> observeHumanCanonicalOccurrence owner
      <> [observeHumanRecordFamily family]
      <> observeHumanSourceLocation locationValue
      <> observeItems observeHumanDraftScalar values
      <> observeItems observeHumanOpaqueEvidence opaque
      <> HumanFailure.foldHumanFailurePropertyKey
           (\keyValues ->
              "direct-key" : observeItems observeHumanDraftScalar keyValues)
           (("referenced-key" :) . observeHumanCanonicalReference)
           key

observeRawCanonicalReference :: Notation.CanonicalReference -> [Text]
observeRawCanonicalReference referenceValue =
  observeRawCanonicalOccurrence
    (Notation.canonicalReferenceOccurrence referenceValue)
    <> observeRawCanonicalOccurrence
         (Notation.canonicalReferenceOwner referenceValue)
    <> [ observeRawReferenceField
           (Notation.canonicalReferenceField referenceValue)
       , observeRawRecordFamily
           (Notation.canonicalReferenceExpectedFamily referenceValue)
       ]
    <> observeRawSourceLocation
         (Notation.canonicalReferenceLocation referenceValue)
    <> observeRawReferenceOutcome
         (Notation.canonicalReferenceOutcome referenceValue)

observeHumanCanonicalReference ::
     HumanFailure.HumanFailureCanonicalReference -> [Text]
observeHumanCanonicalReference =
  HumanFailure.foldHumanFailureCanonicalReference $ \occurrence owner field family locationValue outcome ->
    observeHumanCanonicalOccurrence occurrence
      <> observeHumanCanonicalOccurrence owner
      <> [observeHumanReferenceField field, observeHumanRecordFamily family]
      <> observeHumanSourceLocation locationValue
      <> observeHumanReferenceOutcome outcome

observeRawReferenceOutcome :: Notation.ReferenceOutcome -> [Text]
observeRawReferenceOutcome =
  Notation.foldReferenceOutcome
    (("identity-invalid" :) . observeRawIdentityOutcome)
    (\scalarValue identity ->
       ["target-missing"]
         <> observeRawDraftScalar scalarValue
         <> [modelIdentityText identity])
    (\scalarValue identity family targets ->
       ["target-wrong-family"]
         <> observeRawDraftScalar scalarValue
         <> [modelIdentityText identity, observeRawRecordFamily family]
         <> observeItems observeRawCanonicalTarget targets)
    (\scalarValue identity family targets ->
       ["target-family-ambiguous"]
         <> observeRawDraftScalar scalarValue
         <> [modelIdentityText identity, observeRawRecordFamily family]
         <> observeItems observeRawCanonicalTarget targets)
    (\scalarValue identity target ->
       ["target-resolved"]
         <> observeRawDraftScalar scalarValue
         <> [modelIdentityText identity]
         <> observeRawCanonicalTarget target)

observeHumanReferenceOutcome ::
     HumanFailure.HumanFailureReferenceOutcome -> [Text]
observeHumanReferenceOutcome =
  HumanFailure.foldHumanFailureReferenceOutcome
    (("identity-invalid" :) . observeHumanIdentityOutcome)
    (\scalarValue identity ->
       ["target-missing"]
         <> observeHumanDraftScalar scalarValue
         <> [HumanValue.foldHumanModelIdentity id identity])
    (\scalarValue identity family targets ->
       ["target-wrong-family"]
         <> observeHumanDraftScalar scalarValue
         <> [ HumanValue.foldHumanModelIdentity id identity
            , observeHumanRecordFamily family
            ]
         <> observeItems observeHumanCanonicalTarget targets)
    (\scalarValue identity family targets ->
       ["target-family-ambiguous"]
         <> observeHumanDraftScalar scalarValue
         <> [ HumanValue.foldHumanModelIdentity id identity
            , observeHumanRecordFamily family
            ]
         <> observeItems observeHumanCanonicalTarget targets)
    (\scalarValue identity target ->
       ["target-resolved"]
         <> observeHumanDraftScalar scalarValue
         <> [HumanValue.foldHumanModelIdentity id identity]
         <> observeHumanCanonicalTarget target)

observeRawCanonicalTarget :: Notation.CanonicalTarget -> [Text]
observeRawCanonicalTarget target =
  observeRawCanonicalOccurrence (Notation.canonicalTargetOccurrence target)
    <> [ observeRawRecordFamily (Notation.canonicalTargetFamily target)
       , modelIdentityText (Notation.canonicalTargetIdentity target)
       ]
    <> observeRawSourceLocation (Notation.canonicalTargetLocation target)
    <> observeItems
         observeRawCanonicalField
         (Notation.canonicalTargetFields target)

observeHumanCanonicalTarget ::
     HumanFailure.HumanFailureCanonicalTarget -> [Text]
observeHumanCanonicalTarget =
  HumanFailure.foldHumanFailureCanonicalTarget $ \occurrence family identity locationValue fields ->
    observeHumanCanonicalOccurrence occurrence
      <> [ observeHumanRecordFamily family
         , HumanValue.foldHumanModelIdentity id identity
         ]
      <> observeHumanSourceLocation locationValue
      <> observeItems observeHumanCanonicalField fields

observeRawOpaqueEvidence :: Draft.DraftOpaqueEvidence -> [Text]
observeRawOpaqueEvidence evidence =
  [ Draft.foldDraftOpaquePosition
      "attribute"
      "child"
      (Draft.draftOpaquePosition evidence)
  ]
    <> observeRawNativeName (Draft.draftOpaqueName evidence)
    <> observeItems observeRawDraftScalar (Draft.draftOpaqueScalars evidence)
    <> observeRawSourceLocation (Draft.draftOpaqueLocation evidence)

observeHumanOpaqueEvidence :: HumanFailure.HumanFailureOpaqueEvidence -> [Text]
observeHumanOpaqueEvidence =
  HumanFailure.foldHumanFailureOpaqueEvidence $ \position namespace localName values locationValue ->
    [HumanFailure.foldHumanFailureOpaquePosition "attribute" "child" position]
      <> observeMaybe pureText namespace
      <> [localName]
      <> observeItems observeHumanDraftScalar values
      <> observeHumanSourceLocation locationValue

observeRawCanonicalField :: Notation.CanonicalField -> [Text]
observeRawCanonicalField field =
  [observeRawFieldKind (Notation.canonicalFieldKind field)]
    <> observeItems observeRawDraftScalar (Notation.canonicalFieldScalars field)
    <> observeRawSourceLocation (Notation.canonicalFieldLocation field)

observeHumanCanonicalField :: HumanValue.HumanCanonicalField -> [Text]
observeHumanCanonicalField =
  HumanValue.foldHumanCanonicalField $ \kind values locationValue ->
    [kind]
      <> observeItems observeHumanDraftScalar values
      <> observeHumanSourceLocation locationValue

observeRawIdentityOutcome :: Notation.IdentityOutcome -> [Text]
observeRawIdentityOutcome =
  Notation.foldIdentityOutcome
    ["identity-missing"]
    (\values -> "identity-multiple" : observeItems observeRawDraftScalar values)
    (\scalarValue reason ->
       ["identity-invalid"]
         <> observeRawDraftScalar scalarValue
         <> [ Notation.foldIdentityInvalidReason
                (\kind -> "non-text:" <> observeRawDraftValueKind kind)
                "empty"
                "nul"
                "surrogate"
                reason
            ])
    (\scalarValue identity ->
       ["identity-resolved"]
         <> observeRawDraftScalar scalarValue
         <> [modelIdentityText identity])

observeHumanIdentityOutcome :: HumanValue.HumanIdentityOutcome -> [Text]
observeHumanIdentityOutcome =
  HumanValue.foldHumanIdentityOutcome
    ["identity-missing"]
    (\values ->
       "identity-multiple" : observeItems observeHumanDraftScalar values)
    (\scalarValue reason ->
       ["identity-invalid"]
         <> observeHumanDraftScalar scalarValue
         <> [ HumanValue.foldHumanIdentityInvalidReason
                (\kind -> "non-text:" <> kind)
                "empty"
                "nul"
                "surrogate"
                reason
            ])
    (\scalarValue identity ->
       ["identity-resolved"]
         <> observeHumanDraftScalar scalarValue
         <> [HumanValue.foldHumanModelIdentity id identity])

observeRawDraftScalar :: Draft.DraftScalar -> [Text]
observeRawDraftScalar scalarValue =
  Draft.foldDraftScalarValue
    (\value -> ["text", value])
    (\value -> ["boolean", booleanText value])
    (\value -> ["number", value])
    (\value -> "native-name" : observeRawNativeName value)
    (\kind value -> ["other", kind, value])
    scalarValue
    <> observeRawSourceLocation (Draft.draftScalarLocation scalarValue)

observeHumanDraftScalar :: HumanValue.HumanDraftScalar -> [Text]
observeHumanDraftScalar =
  HumanValue.foldHumanDraftScalar $ \value locationValue ->
    HumanValue.foldHumanScalarValue
      (\retained -> ["text", retained])
      (\retained -> ["boolean", booleanText retained])
      (\retained -> ["number", retained])
      (\retained -> "native-name" : observeHumanNativeName retained)
      (\kind retained -> ["other", kind, retained])
      value
      <> observeHumanSourceLocation locationValue

observeRawSourceLocation :: Draft.DraftLocation -> [Text]
observeRawSourceLocation locationValue =
  Draft.foldDraftSourcePath
    (\first rest -> observeItems observeRawPathStep (first : rest))
    (Draft.draftLocationPath locationValue)
    <> observeMaybe observeRawSourceSpan (Draft.draftLocationSpan locationValue)

observeHumanSourceLocation :: HumanValue.HumanSourceLocation -> [Text]
observeHumanSourceLocation =
  HumanValue.foldHumanSourceLocation $ \path sourceSpan ->
    observeItems observeHumanPathStep (NonEmpty.toList path)
      <> observeMaybe observeHumanSourceSpan sourceSpan

observeRawPathStep :: Draft.DraftPathStep -> [Text]
observeRawPathStep step =
  observeRawNativeName (Draft.draftPathStepName step)
    <> [naturalText (Draft.draftPathStepOrdinal step)]

observeHumanPathStep :: HumanValue.HumanSourcePathStep -> [Text]
observeHumanPathStep =
  HumanValue.foldHumanSourcePathStep $ \name ordinal ->
    observeHumanNativeName name <> [naturalText ordinal]

observeRawNativeName :: Draft.DraftNativeName -> [Text]
observeRawNativeName name =
  observeMaybe pureText (Draft.draftNativeNamespace name)
    <> [Draft.draftNativeLocalName name]

observeHumanNativeName :: HumanValue.HumanNativeName -> [Text]
observeHumanNativeName =
  HumanValue.foldHumanNativeName $ \namespace localName ->
    observeMaybe pureText namespace <> [localName]

observeRawSourceSpan :: Draft.DraftSourceSpan -> [Text]
observeRawSourceSpan sourceSpan =
  observeRawSourcePosition (Draft.draftSpanStart sourceSpan)
    <> observeRawSourcePosition (Draft.draftSpanEnd sourceSpan)

observeHumanSourceSpan :: HumanValue.HumanSourceSpan -> [Text]
observeHumanSourceSpan =
  HumanValue.foldHumanSourceSpan $ \start end ->
    observeHumanSourcePosition start <> observeHumanSourcePosition end

observeRawSourcePosition :: Draft.DraftSourcePosition -> [Text]
observeRawSourcePosition position =
  [ naturalText (Draft.draftSourceLine position)
  , naturalText (Draft.draftSourceColumn position)
  ]
    <> observeMaybe (pureText . naturalText) (Draft.draftSourceOffset position)

observeHumanSourcePosition :: HumanValue.HumanSourcePosition -> [Text]
observeHumanSourcePosition =
  HumanValue.foldHumanSourcePosition $ \line column offset ->
    [naturalText line, naturalText column]
      <> observeMaybe (pureText . naturalText) offset

observeRawCanonicalOccurrence :: Notation.CanonicalOccurrence -> [Text]
observeRawCanonicalOccurrence occurrence =
  [ Notation.foldCanonicalOccurrenceKind
      "record"
      "property"
      "reference"
      (Notation.canonicalOccurrenceKind occurrence)
  , naturalText (Notation.canonicalOccurrenceOrdinal occurrence)
  ]

observeHumanCanonicalOccurrence :: HumanValue.HumanCanonicalOccurrence -> [Text]
observeHumanCanonicalOccurrence =
  HumanValue.foldHumanCanonicalOccurrence $ \kind ordinal ->
    [ HumanValue.foldHumanCanonicalOccurrenceKind
        "record"
        "property"
        "reference"
        kind
    , naturalText ordinal
    ]

observeRawRecordFamily :: Draft.DraftRecordFamilyValue -> Text
observeRawRecordFamily =
  Draft.foldDraftRecordFamilyValue
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

observeHumanRecordFamily :: HumanFailure.HumanFailureRecordFamily -> Text
observeHumanRecordFamily =
  HumanFailure.foldHumanFailureRecordFamily
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

observeRawReferenceField :: Draft.DraftReferenceFieldValue -> Text
observeRawReferenceField =
  Draft.foldDraftReferenceFieldValue
    "property-definition"
    "relationship-source"
    "relationship-target"
    "view-node-element"
    "view-connection-relationship"
    "view-connection-source"
    "view-connection-target"

observeHumanReferenceField :: HumanFailure.HumanFailureReferenceField -> Text
observeHumanReferenceField =
  HumanFailure.foldHumanFailureReferenceField
    "property-definition"
    "relationship-source"
    "relationship-target"
    "view-node-element"
    "view-connection-relationship"
    "view-connection-source"
    "view-connection-target"

observeRawFieldKind :: Draft.DraftFieldValue -> Text
observeRawFieldKind =
  Draft.foldDraftFieldValue
    "type"
    "name"
    "documentation"
    "directed"
    "influence-strength"

observeRawDraftValueKind :: Draft.DraftValueKind -> Text
observeRawDraftValueKind =
  Draft.foldDraftValueKind "text" "boolean" "number" "native-name" id

observeHumanDraftValueKind :: HumanFailure.HumanFailureDraftValueKind -> Text
observeHumanDraftValueKind =
  HumanFailure.foldHumanFailureDraftValueKind
    "text"
    "boolean"
    "number"
    "native-name"
    id

observeOperationRule :: OperationRule -> Text
observeOperationRule = operationRuleIdText . operationRuleIdentity

observeItems :: (value -> [Text]) -> [value] -> [Text]
observeItems observe values =
  "items-begin"
    : concatMap (\value -> "item-begin" : observe value <> ["item-end"]) values
        <> ["items-end"]

observeMaybe :: (value -> [Text]) -> Maybe value -> [Text]
observeMaybe observe value =
  case value of
    Nothing -> ["nothing"]
    Just retained -> "just" : observe retained

pureText :: Text -> [Text]
pureText value = [value]

naturalText :: Natural -> Text
naturalText = Text.pack . show

booleanText :: Bool -> Text
booleanText value =
  if value
    then "true"
    else "false"

humanDescriptorId :: HumanValue.HumanAdapterDescriptor -> Text
humanDescriptorId =
  HumanValue.foldHumanAdapterDescriptor $ \identifier _ _ _ -> identifier

humanDraftScalarText :: HumanValue.HumanDraftScalar -> Text
humanDraftScalarText =
  HumanValue.foldHumanDraftScalar $ \value _ ->
    HumanValue.foldHumanScalarValue id boolean id native other value
  where
    boolean value =
      if value
        then "true"
        else "false"
    native name =
      HumanValue.foldHumanNativeName
        (\namespace value -> maybe "" (<> ":") namespace <> value)
        name
    other _ value = value

observeSelection :: AdapterSelectionError -> CauseObservation
observeSelection =
  foldAdapterSelectionError
    (SelectionUnknown . adapterIdText)
    (\failures ->
       let (descriptor, diagnostics) = NonEmpty.head failures
        in SelectionRecognition
             (descriptorId descriptor)
             (NonEmpty.length diagnostics))
    SelectionNoMatch
    (SelectionMultiple . fmap descriptorId . NonEmpty.toList)

observeResolution :: ProfileResolutionFailure -> CauseObservation
observeResolution =
  foldProfileResolutionFailure
    (\_ key -> ResolutionMissing key)
    (\_ key properties -> ResolutionProperties key (length properties))
    (\_ key _ values -> ResolutionValues key (length values))
    (\_ key _ kind ->
       ResolutionKind
         key
         (Draft.foldDraftValueKind
            "text"
            "boolean"
            "number"
            "native-name"
            id
            kind))
    (\_ key value -> ResolutionGrammar key (Draft.draftScalarText value))
    (\_ key referenceValue -> ResolutionUnknown key referenceValue)

observeCompatibility :: ProfileCompatibilityFailure -> CauseObservation
observeCompatibility =
  foldProfileCompatibilityFailure
    (\_ _ descriptor admitted ->
       CompatibilityAdapter (descriptorId descriptor) admitted)
    (\_ _ _ profileNotation adapterNotation ->
       CompatibilityNotation profileNotation adapterNotation)

observeView :: ViewSelectionFailure document -> CauseObservation
observeView =
  foldViewSelectionFailure
    (const ViewUnknown)
    (\_ candidates -> ViewAmbiguousName (NonEmpty.length candidates))
    (\_ candidates -> ViewAmbiguousIdentity (NonEmpty.length candidates))
    (\_ _ -> ViewWrongFamily)

observeInputs :: CapabilityInputReferences -> InputObservation
observeInputs =
  foldCapabilityInputReferences
    (ValidationInputs . fmap sourceReferenceText)
    TraceInputs
    (QualificationInputs . fmap sourceReferenceText)
    (\primary supplemental ->
       ReadinessInputs
         (sourceReferenceText primary)
         (fmap sourceReferenceText supplemental))
    (\primary supplemental ->
       AssessmentInputs
         (sourceReferenceText primary)
         (fmap sourceReferenceText supplemental))

descriptorId :: AdapterDescriptor -> Text
descriptorId = adapterIdText . adapterDescriptorId

profiles :: IO ProfileInventory
profiles =
  foldProfileInventoryCompilation
    (\_ -> assertFailure "Profile inventory rejected" >> fail "unreachable")
    pure
    (compileProfileInventory [compiledProfileDescriptor])

simpleAdapter :: Text -> Text -> Bool -> Draft.ProfileDraft -> IO Adapter
simpleAdapter identifier notation matches draft = do
  descriptor <- adapterDescriptor identifier notation
  compileCompleteAdapter descriptor [] $ \_ ->
    Right
      (adapterBehavior
         (const
            (if matches
               then recognitionMatch
               else noRecognitionMatch))
         (const (decodedDraft draft)))

ownerVerticalAdapter :: IO Adapter
ownerVerticalAdapter = do
  descriptor <- adapterDescriptor "amx" "archimate-3.2"
  definition <- nativeRuleSpec "decode.failed"
  compileCompleteAdapter descriptor [definition] $ \rules -> do
    rule <- resolveNativeRule rules definition decodeRule
    pure
      (adapterBehavior
         (\bytes ->
            case decodeOwnerVerticalDraft bytes of
              Nothing -> noRecognitionMatch
              Just _ -> recognitionMatch)
         (\bytes ->
            case decodeOwnerVerticalDraft bytes of
              Nothing ->
                decodeFailure
                  (decodeDiagnostic rule (unlocatedOccurrence :| []) :| [])
              Just draft -> decodedDraft draft))

decodeOwnerVerticalDraft :: ByteString -> Maybe Draft.ProfileDraft
decodeOwnerVerticalDraft bytes =
  case traverse splitOwnerModelField (ByteString.lines bytes) of
    Just [("profile", profile), ("view", viewIdentity), ("name", viewName)] ->
      Just
        (modelDraft
           [profileProperty [scalar (decodeOwnerModelText profile)]]
           [ view
               (decodeOwnerModelText viewIdentity)
               (decodeOwnerModelText viewName)
           ])
    _ -> Nothing

splitOwnerModelField :: ByteString -> Maybe (ByteString, ByteString)
splitOwnerModelField line =
  case ByteString.break (== '=') line of
    (_, value)
      | ByteString.null value -> Nothing
    (key, value) -> Just (key, ByteString.drop 1 value)

decodeOwnerModelText :: ByteString -> Text
decodeOwnerModelText = Text.pack . ByteString.unpack

recognitionFailureAdapter :: Text -> IO Adapter
recognitionFailureAdapter identifier = do
  descriptor <- adapterDescriptor identifier "archimate-3.2"
  definition <- nativeRuleSpec "recognition.failed"
  compileCompleteAdapter descriptor [definition] $ \rules -> do
    rule <- resolveNativeRule rules definition recognitionRule
    pure
      (adapterBehavior
         (const
            (recognitionFailure
               (recognitionDiagnostic rule (unlocatedOccurrence :| []) :| [])))
         (const (decodedDraft acceptedDraft)))

decodeFailureAdapter :: Text -> IO Adapter
decodeFailureAdapter identifier = do
  value <- requireRight (mkAdapterId identifier)
  descriptor <-
    requireRight
      (mkAdapterDescriptor
         value
         "adapter\n\"name\"\\raw"
         "version\tβ"
         "notation\n\"raw\"")
  definition <- nativeRuleSpec "decode.failed"
  compileCompleteAdapter descriptor [definition] $ \rules -> do
    rule <- resolveNativeRule rules definition decodeRule
    pure
      (adapterBehavior
         (const recognitionMatch)
         (const
            (decodeFailure
               (decodeDiagnostic rule (unlocatedOccurrence :| []) :| []))))

adapterDescriptor :: Text -> Text -> IO AdapterDescriptor
adapterDescriptor identifier notation = do
  value <- requireRight (mkAdapterId identifier)
  requireRight (mkAdapterDescriptor value identifier "1" notation)

collection :: [Adapter] -> IO AdapterCollection
collection adapters =
  case NonEmpty.nonEmpty adapters of
    Nothing -> assertFailure "empty Adapter fixture" >> fail "unreachable"
    Just values -> requireRight (compileAdapterCollection values)

acquiredModel :: IO AcquiredSource
acquiredModel = do
  modelReference <- reference "model"
  pure
    (AcquiredSource
       (sourceIdentityFromBytes
          ModelRole
          (sourceOrdinal 0)
          modelReference
          modelBytes)
       modelBytes)

acceptedDraft, markerlessDraft, invalidMarkerDraft :: Draft.ProfileDraft
acceptedDraft =
  modelDraft [profileProperty [scalar profileReference]] [view "view" "Main"]

markerlessDraft = modelDraft [] [view "view" "Main"]

invalidMarkerDraft =
  modelDraft [invalidProperty profileReference] [view "view" "Main"]

propertyMultiplicityDraft, valueMultiplicityDraft :: Draft.ProfileDraft
propertyMultiplicityDraft =
  modelDraft
    [ profileProperty [scalar profileReference]
    , profileProperty [scalar profileReference]
    ]
    [view "view" "Main"]

valueMultiplicityDraft =
  modelDraft
    [profileProperty [scalar profileReference, scalar profileReference]]
    [view "view" "Main"]

valueKindDraft, grammarDraft, unknownProfileDraft :: Draft.ProfileDraft
valueKindDraft =
  modelDraft
    [profileProperty [Draft.draftBooleanScalar True (location "boolean")]]
    [view "view" "Main"]

grammarDraft =
  modelDraft [profileProperty [scalar "invalid"]] [view "view" "Main"]

unknownProfileDraft =
  modelDraft
    [profileProperty [scalar "unknown.profile@1.2"]]
    [view "view" "Main"]

duplicateNameDraft, duplicateIdentityDraft, wrongFamilyDraft ::
     Draft.ProfileDraft
duplicateNameDraft =
  modelDraft
    [profileProperty [scalar profileReference]]
    [view "one" "Repeated", view "two" "Repeated"]

duplicateIdentityDraft =
  modelDraft
    [profileProperty [scalar profileReference]]
    [view "shared" "One", view "shared" "Two"]

wrongFamilyDraft =
  modelDraft [profileProperty [scalar profileReference]] [element "element"]

modelDraft ::
     [Draft.DraftMember Draft.ModelRootRole]
  -> [Draft.DraftMember Draft.ModelRootRole]
  -> Draft.ProfileDraft
modelDraft properties children =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [scalar "model"])
       (location "model")
       (properties <> children))

profileProperty :: [Draft.DraftScalar] -> Draft.DraftMember owner
profileProperty values =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey [scalar "o2i.profile"])
       values
       (location "profile")
       [])

invalidProperty :: Text -> Draft.DraftMember owner
invalidProperty value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey [])
       [scalar value]
       (location "invalid-profile")
       [])

view :: Text -> Text -> Draft.DraftMember Draft.ModelRootRole
view identifier name =
  Draft.childRecordMember
    (Draft.viewDraft
       (Draft.draftIdentity [scalar identifier])
       (location identifier)
       [Draft.nameFieldMember [scalar name] (location (identifier <> "-name"))])

element :: Text -> Draft.DraftMember Draft.ModelRootRole
element identifier =
  Draft.childRecordMember
    (Draft.elementDraft
       (Draft.draftIdentity [scalar identifier])
       (location identifier)
       [])

scalar :: Text -> Draft.DraftScalar
scalar value = Draft.draftTextScalar value (location value)

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 1)
       [])
    Nothing

profileReference :: Text
profileReference = "o2i.archimate-profile@0.3"

modelBytes :: ByteString
modelBytes = "model"

reference :: Text -> IO SourceReference
reference value = requireRight (mkSourceReference value)

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failureValue -> assertFailure (show failureValue) >> fail "unreachable"
    Right value -> pure value
