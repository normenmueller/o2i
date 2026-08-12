{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Failure
  ( tests
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile as ArchiMate
import O2I.Operation.Acquisition
import O2I.Operation.Acquisition.Internal (AcquisitionFailure(..))
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Adapter.Internal (AdapterSelectionError(..))
import O2I.Operation.Failure
import O2I.Operation.Failure.Internal
import O2I.Operation.Preparation
import O2I.Operation.Profile.Internal
import O2I.Operation.Provenance
import O2I.Operation.Rule.Catalog
import O2I.Operation.View
import O2I.Operation.View.Internal (ViewSelectionFailure(..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "failure"
    [ testCase "classifies every preparation branch" preparationBranches
    , testCase
        "binds all decode diagnostics to the executed adapter"
        decodeBinding
    , testCase
        "keeps command failures separate and provenance-free"
        commandBoundary
    , testCase "folds the common failure boundary" commonBoundary
    ]

preparationBranches :: Assertion
preparationBranches = do
  adapterIdentifier <- requireRight (mkAdapterId "missing")
  descriptor <- testDescriptor
  profileDescriptor <-
    case ArchiMate.compiledProfileInventory of
      value:_ -> pure value
      [] ->
        assertFailure "compiled Profile inventory is empty"
          >> fail "unreachable"
  let rule = operationRule
      selectedProfile = ResolvedProfile profileDescriptor
      failures =
        [ AdapterSelectionPreparationFailure (UnknownAdapter adapterIdentifier)
        , ProfileMarkerPreparationFailure []
        , ProfileResolutionPreparationFailure
            (ProfileReferenceMissing rule "o2i.profile")
        , ProfileCompatibilityPreparationFailure
            (ProfileAdapterIdNotAdmitted rule selectedProfile descriptor [])
        , ViewSelectionPreparationFailure
            (ViewSelectionUnknown (viewByName "missing"))
        ]
  fmap preparationFailureStage failures
    @?= [ adapterSelectionStage
        , profileMarkerStage
        , profileResolutionStage
        , profileCompatibilityStage
        , viewSelectionStage
        ]
  fmap failureTag failures @?= ([0, 2, 3, 4, 5] :: [Int])
  where
    failureTag =
      foldPreparationFailure
        (const 0)
        (\_ _ -> 1)
        (const 2)
        (const 3)
        (const 4)
        (const 5)

decodeBinding :: Assertion
decodeBinding = do
  descriptor <- testDescriptor
  definition <- testAdapterRuleDefinition
  compiled <-
    requireRight
      (compileAdapter
         descriptor
         ((\rule ->
             let first = decodeDiagnostic rule (unlocatedOccurrence :| [])
                 second = decodeDiagnostic rule (unlocatedOccurrence :| [])
              in adapterBehavior
                   (const recognitionMatch)
                   (const (decodeFailure (first :| [second]))))
            <$> decodeRule definition))
  collection <- requireRight (compileAdapterCollection (compiled :| []))
  selected <- requireSelected (selectAdapter collection Nothing modelBytes)
  failure <-
    maybe
      (assertFailure "decode failure was not retained" >> fail "unreachable")
      pure
      (adapterDecodeFailure (runSelectedAdapter selected modelBytes))
  preparationFailureStage failure @?= adapterDecodeStage
  foldPreparationFailure
    (const (assertFailure "unexpected selection failure"))
    (\boundDescriptor diagnostics -> do
       adapterIdText (adapterDescriptorId boundDescriptor) @?= "test"
       NonEmpty.length diagnostics @?= 2)
    (const (assertFailure "unexpected marker failure"))
    (const (assertFailure "unexpected profile failure"))
    (const (assertFailure "unexpected compatibility failure"))
    (const (assertFailure "unexpected view failure"))
    failure

commandBoundary :: Assertion
commandBoundary = do
  reference <- requireRight (mkSourceReference "stdin")
  let acquisition =
        AcquisitionFailure (standardInput reference) (userError "unavailable")
      failure = inputAcquisitionFailure acquisition
  commandFailureCode failure @?= "command.input-io"
  foldCommandFailure
    (\retained ->
       inputSourceReference (acquisitionFailureSource retained) @?= reference)
    failure

commonBoundary :: Assertion
commonBoundary = do
  reference <- requireRight (mkSourceReference "stdin")
  let acquisition =
        AcquisitionFailure (standardInput reference) (userError "unavailable")
      command = commandFailure (inputAcquisitionFailure acquisition)
      prepared = preparationFailure (ProfileMarkerPreparationFailure [])
  commonFailureCode command @?= "command.input-io"
  commonFailureCode prepared @?= "preparation.profile-marker"
  foldCommonFailure (const (0 :: Int)) (const 1) command @?= 0
  foldCommonFailure (const (0 :: Int)) (const 1) prepared @?= 1

operationRule :: OperationRule
operationRule = NonEmpty.head (operationRuleCatalogEntries operationRuleCatalog)

testDescriptor :: IO AdapterDescriptor
testDescriptor = do
  identifier <- requireRight (mkAdapterId "test")
  requireRight (mkAdapterDescriptor identifier "Test" "1" "test")

testAdapterRuleDefinition :: IO AdapterRuleDefinition
testAdapterRuleDefinition =
  requireRight
    (mkAdapterRuleDefinition "native.invalid" "expectation" "meaning" "action")

modelBytes :: ByteString
modelBytes = "model"

requireSelected :: AdapterSelection -> IO SelectedAdapter
requireSelected =
  foldAdapterSelection
    (const (assertFailure "expected selected adapter" >> fail "unreachable"))
    pure

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
