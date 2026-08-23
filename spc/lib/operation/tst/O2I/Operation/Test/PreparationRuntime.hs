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
import O2I.ArchiMate.Profile.Notation
  ( canonicalOccurrenceOrdinal
  , canonicalViewOccurrence
  )
import O2I.ArchiMate.Profile.Resolution (compiledProfileDescriptor)
import O2I.Core.Identity (modelIdentity)
import O2I.Operation.Acquisition (acquireSource, acquiredModelSource, fileInput)
import O2I.Operation.Acquisition.Internal
  ( AcquiredModelSource(..)
  , AcquiredSource(..)
  )
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Failure
import O2I.Operation.Preparation
import O2I.Operation.Profile
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import O2I.Operation.Request
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
  FailureObservation !Text !Text !CauseObservation
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
  actual @?= Left expected
  readIORef completions >>= (@?= 0)

failure :: Text -> PreparationStage -> CauseObservation -> FailureObservation
failure code stage = FailureObservation code (preparationStageText stage)

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

observeResolution :: ProfileResolution -> CauseObservation
observeResolution =
  foldProfileResolution
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
    (const (ResolutionMissing "unexpected-resolved-profile"))

observeCompatibility :: ProfileCompatibility -> CauseObservation
observeCompatibility =
  foldProfileCompatibility
    (\_ _ descriptor admitted ->
       CompatibilityAdapter (descriptorId descriptor) admitted)
    (\_ _ _ profileNotation adapterNotation ->
       CompatibilityNotation profileNotation adapterNotation)
    (\_ _ _ -> CompatibilityAdapter "unexpected-compatible-profile" [])

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
  descriptor <- adapterDescriptor identifier "archimate-3.2"
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
