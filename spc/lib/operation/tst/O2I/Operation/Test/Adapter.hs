{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Adapter
  ( tests
  ) where

import Data.ByteString (ByteString)
import Data.IORef
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import System.IO.Unsafe (unsafePerformIO)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "adapter"
    [ testCase "explicit selection bypasses recognition" explicitTest
    , testCase "implicit selection recognizes every adapter once" implicitTest
    , testCase
        "one match ignores an unrelated recognition failure"
        uniqueMatchPrecedenceTest
    , testCase
        "recognition failures are reported without a match"
        recognitionFailureTest
    , testCase "no implicit match is explicit" noMatchTest
    , testCase "multiple implicit matches are explicit" multipleMatchTest
    , testCase
        "multiple matches remain ambiguous despite an unrelated failure"
        multipleMatchWithFailureTest
    , testCase "selected decode is final" decodeTest
    , testCase
        "adapter compilation rejects an empty rule inventory"
        emptyRulesTest
    , testCase
        "adapter compilation rejects duplicate cross-stage rule identities"
        duplicateRulesTest
    , testCase "adapter compilation orders its rule inventory" ruleOrderTest
    , testCase
        "adapter compilation scales to a large rule inventory"
        largeRuleInventoryTest
    , testCase "collections reject duplicate identities" duplicateTest
    , testCase "static contracts expose no execution choice" contractTest
    ]

explicitTest :: Assertion
explicitTest = do
  calls <- newIORef (0 :: Int)
  first <- countedAdapter "first" calls True
  second <- countedAdapter "second" calls True
  collection <- requireRight (compileAdapterCollection (second :| [first]))
  identifier <- requireRight (mkAdapterId "second")
  selected <- requireSelected (selectAdapter collection (Just identifier) bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "second"
  readIORef calls >>= (@?= 0)

implicitTest :: Assertion
implicitTest = do
  firstCalls <- newIORef (0 :: Int)
  secondCalls <- newIORef (0 :: Int)
  first <- countedAdapter "first" firstCalls False
  second <- countedAdapter "second" secondCalls True
  collection <- requireRight (compileAdapterCollection (second :| [first]))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "second"
  readIORef firstCalls >>= (@?= 1)
  readIORef secondCalls >>= (@?= 1)

uniqueMatchPrecedenceTest :: Assertion
uniqueMatchPrecedenceTest = do
  first <- staticAdapter "first" True
  second <- recognitionFailureAdapter "second"
  collection <- requireRight (compileAdapterCollection (first :| [second]))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "first"

recognitionFailureTest :: Assertion
recognitionFailureTest = do
  first <- staticAdapter "first" False
  second <- recognitionFailureAdapter "second"
  collection <- requireRight (compileAdapterCollection (first :| [second]))
  selectionFailureTag (selectAdapter collection Nothing bytes)
    @?= "recognition-failed:second"

noMatchTest :: Assertion
noMatchTest = do
  first <- staticAdapter "first" False
  collection <- requireRight (compileAdapterCollection (first :| []))
  selectionFailureTag (selectAdapter collection Nothing bytes) @?= "no-match"

multipleMatchTest :: Assertion
multipleMatchTest = do
  first <- staticAdapter "first" True
  second <- staticAdapter "second" True
  collection <- requireRight (compileAdapterCollection (second :| [first]))
  selectionFailureTag (selectAdapter collection Nothing bytes)
    @?= "multiple:first,second"

multipleMatchWithFailureTest :: Assertion
multipleMatchWithFailureTest = do
  first <- staticAdapter "first" True
  second <- staticAdapter "second" True
  third <- recognitionFailureAdapter "third"
  collection <-
    requireRight (compileAdapterCollection (third :| [second, first]))
  selectionFailureTag (selectAdapter collection Nothing bytes)
    @?= "multiple:first,second"

decodeTest :: Assertion
decodeTest = do
  descriptor <- staticDescriptor "first"
  definition <- staticRuleDefinition "native.invalid"
  value <-
    requireRight
      (compileAdapter
         descriptor
         ((\rule ->
             adapterBehavior
               (const recognitionMatch)
               (const
                  (decodeFailure
                     (decodeDiagnostic rule (unlocatedOccurrence :| []) :| []))))
            <$> decodeRule definition))
  collection <- requireRight (compileAdapterCollection (value :| []))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  foldAdapterExecution
    (\executionDescriptor rules outcome -> do
       descriptorIdentifier executionDescriptor @?= "first"
       NonEmpty.length rules @?= 1
       foldDecodeOutcome
         (\diagnostics -> NonEmpty.length diagnostics @?= 1)
         (const (assertFailure "decode failure became a Draft"))
         outcome)
    (runSelectedAdapter selected bytes)

emptyRulesTest :: Assertion
emptyRulesTest = do
  descriptor <- staticDescriptor "empty"
  case compileAdapter
         descriptor
         (pure (adapterBehavior (const recognitionMatch) missingDraft)) of
    Left defects -> defects @?= EmptyAdapterRuleInventory :| []
    Right _ -> assertFailure "empty adapter rule inventory was accepted"

duplicateRulesTest :: Assertion
duplicateRulesTest = do
  descriptor <- staticDescriptor "duplicate-rules"
  definition <- staticRuleDefinition "duplicate"
  case compileAdapter
         descriptor
         ((\_ _ -> adapterBehavior (const recognitionMatch) missingDraft)
            <$> recognitionRule definition
            <*> decodeRule definition) of
    Left defects ->
      foldMap
        (\defect ->
           case defect of
             DuplicateAdapterRuleIdentifier identifier ->
               [adapterRuleIdText identifier]
             EmptyAdapterRuleInventory -> [])
        defects
        @?= ["duplicate"]
    Right _ -> assertFailure "duplicate cross-stage rule was accepted"

ruleOrderTest :: Assertion
ruleOrderTest = do
  descriptor <- staticDescriptor "ordered"
  later <- staticRuleDefinition "zeta"
  earlier <- staticRuleDefinition "alpha"
  value <-
    requireRight
      (compileAdapter
         descriptor
         ((\_ _ -> adapterBehavior (const recognitionMatch) missingDraft)
            <$> decodeRule later
            <*> recognitionRule earlier))
  collection <- requireRight (compileAdapterCollection (value :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
  fmap (adapterRuleIdText . adapterRuleId) (adapterContractRules contract)
    @?= "alpha"
    :| ["zeta"]

largeRuleInventoryTest :: Assertion
largeRuleInventoryTest = do
  descriptor <- staticDescriptor "large-inventory"
  definitions <-
    traverse
      (staticRuleDefinition . ("rule-" <>) . Text.pack . show)
      [1 .. ruleCount]
  value <-
    requireRight
      (compileAdapter
         descriptor
         ((\_ -> adapterBehavior (const recognitionMatch) missingDraft)
            <$> traverse recognitionRule definitions))
  collection <- requireRight (compileAdapterCollection (value :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
  NonEmpty.length (adapterContractRules contract) @?= ruleCount
  where
    ruleCount = 20000

duplicateTest :: Assertion
duplicateTest = do
  first <- staticAdapter "same" True
  second <- staticAdapter "same" False
  case compileAdapterCollection (first :| [second]) of
    Left defects -> NonEmpty.length defects @?= 1
    Right _ -> assertFailure "duplicate adapter identity was accepted"

contractTest :: Assertion
contractTest = do
  first <- staticAdapter "first" True
  second <- staticAdapter "second" False
  collection <- requireRight (compileAdapterCollection (second :| [first]))
  let contracts = NonEmpty.toList (adapterCollectionContracts collection)
  map (descriptorIdentifier . adapterContractDescriptor) contracts
    @?= ["first", "second"]
  identifier <- requireRight (mkAdapterId "second")
  contract <-
    maybe
      (assertFailure "compiled adapter contract is missing"
         >> fail "unreachable")
      pure
      (lookupAdapterContract identifier collection)
  foldAdapterContract
    (\descriptor rules -> do
       descriptorIdentifier descriptor @?= "second"
       fmap (adapterRuleIdText . adapterRuleId) rules @?= "second.native" :| [])
    contract

staticAdapter :: Text -> Bool -> IO Adapter
staticAdapter identifier matches = do
  descriptor <- staticDescriptor identifier
  definition <- staticRuleDefinition (identifier <> ".native")
  requireRight
    (compileAdapter
       descriptor
       ((\_ ->
           adapterBehavior
             (const
                (if matches
                   then recognitionMatch
                   else noRecognitionMatch))
             missingDraft)
          <$> decodeRule definition))

countedAdapter :: Text -> IORef Int -> Bool -> IO Adapter
countedAdapter identifier calls matches = do
  descriptor <- staticDescriptor identifier
  definition <- staticRuleDefinition (identifier <> ".native")
  requireRight
    (compileAdapter
       descriptor
       ((\_ -> adapterBehavior (countedRecognition calls matches) missingDraft)
          <$> decodeRule definition))

recognitionFailureAdapter :: Text -> IO Adapter
recognitionFailureAdapter identifier = do
  descriptor <- staticDescriptor identifier
  definition <- staticRuleDefinition (identifier <> ".recognition")
  requireRight
    (compileAdapter
       descriptor
       ((\rule ->
           adapterBehavior
             (const
                (recognitionFailure
                   (recognitionDiagnostic rule (unlocatedOccurrence :| []) :| [])))
             missingDraft)
          <$> recognitionRule definition))

staticDescriptor :: Text -> IO AdapterDescriptor
staticDescriptor identifier = do
  adapterIdentifier <- requireRight (mkAdapterId identifier)
  requireRight (mkAdapterDescriptor adapterIdentifier identifier "1" "test")

staticRuleDefinition :: Text -> IO AdapterRuleDefinition
staticRuleDefinition identifier =
  requireRight
    (mkAdapterRuleDefinition identifier "expectation" "meaning" "action")

missingDraft :: ByteString -> DecodeResult scope
missingDraft _ = error "decode is outside this selection test"

bytes :: ByteString
bytes = "model"

countedRecognition :: IORef Int -> Bool -> ByteString -> RecognitionResult scope
countedRecognition calls matches _ =
  unsafePerformIO
    (modifyIORef' calls (+ 1)
       >> pure
            (if matches
               then recognitionMatch
               else noRecognitionMatch))

{-# NOINLINE countedRecognition #-}
descriptorIdentifier :: AdapterDescriptor -> Text
descriptorIdentifier = adapterIdText . adapterDescriptorId

selectionFailureTag :: AdapterSelection -> Text
selectionFailureTag =
  foldAdapterSelection
    (foldAdapterSelectionError
       (\identifier -> "unknown:" <> adapterIdText identifier)
       (\failures ->
          "recognition-failed:"
            <> commaSeparated (fmap (descriptorIdentifier . fst) failures))
       "no-match"
       (\descriptors ->
          "multiple:" <> commaSeparated (fmap descriptorIdentifier descriptors)))
    (const "selected")

commaSeparated :: NonEmpty Text -> Text
commaSeparated = foldr1 (\left right -> left <> "," <> right)

requireSelected :: AdapterSelection -> IO SelectedAdapter
requireSelected =
  foldAdapterSelection
    (const (assertFailure "expected an adapter" >> fail "unreachable"))
    pure

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
