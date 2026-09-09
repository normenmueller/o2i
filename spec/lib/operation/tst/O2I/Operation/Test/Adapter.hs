{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Operation.Test.Adapter
  ( tests
  ) where

import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.IORef
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.ArchiMate.Profile.Notation
  ( allArchiMateNotationIssueKinds
  , archiMateNotationIssueKindToken
  )
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
    , testCase "one match ignores an unrelated failure" precedenceTest
    , testCase "recognition failures are retained" recognitionFailureTest
    , testCase "no implicit match is explicit" noMatchTest
    , testCase "multiple matches are canonical" multipleMatchTest
    , testCase "selected decode is final" decodeTest
    , testCase
        "compilation rejects a missing Profile-kind binding"
        missingKindTest
    , testCase
        "compilation rejects duplicate Profile-kind bindings"
        duplicateKindTest
    , testCase "compilation rejects owner-stage mismatch" stageMismatchTest
    , testCase "compilation rejects duplicate rule identities" duplicateRuleTest
    , testCase "compiled rules are canonically ordered" ruleOrderTest
    , testCase "static contracts expose all Profile bindings" contractTest
    ]

explicitTest :: Assertion
explicitTest = do
  calls <- newIORef (0 :: Int)
  firstAdapter <- countedAdapter "first" calls True
  secondAdapter <- countedAdapter "second" calls True
  collection <-
    requireRight (compileAdapterCollection (secondAdapter :| [firstAdapter]))
  identifier <- requireRight (mkAdapterId "second")
  selected <- requireSelected (selectAdapter collection (Just identifier) bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "second"
  readIORef calls >>= (@?= 0)

implicitTest :: Assertion
implicitTest = do
  firstCalls <- newIORef (0 :: Int)
  secondCalls <- newIORef (0 :: Int)
  firstAdapter <- countedAdapter "first" firstCalls False
  secondAdapter <- countedAdapter "second" secondCalls True
  collection <-
    requireRight (compileAdapterCollection (secondAdapter :| [firstAdapter]))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "second"
  readIORef firstCalls >>= (@?= 1)
  readIORef secondCalls >>= (@?= 1)

precedenceTest :: Assertion
precedenceTest = do
  matched <- staticAdapter "first" True
  failed <- recognitionFailureAdapter "second"
  collection <- requireRight (compileAdapterCollection (matched :| [failed]))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  descriptorIdentifier (selectedAdapterDescriptor selected) @?= "first"

recognitionFailureTest :: Assertion
recognitionFailureTest = do
  unmatched <- staticAdapter "first" False
  failed <- recognitionFailureAdapter "second"
  collection <- requireRight (compileAdapterCollection (unmatched :| [failed]))
  selectionFailureTag (selectAdapter collection Nothing bytes)
    @?= "recognition-failed:second"

noMatchTest :: Assertion
noMatchTest = do
  adapter <- staticAdapter "first" False
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  selectionFailureTag (selectAdapter collection Nothing bytes) @?= "no-match"

multipleMatchTest :: Assertion
multipleMatchTest = do
  firstAdapter <- staticAdapter "first" True
  secondAdapter <- staticAdapter "second" True
  collection <-
    requireRight (compileAdapterCollection (secondAdapter :| [firstAdapter]))
  selectionFailureTag (selectAdapter collection Nothing bytes)
    @?= "multiple:first,second"

decodeTest :: Assertion
decodeTest = do
  descriptor <- staticDescriptor "first"
  spec <- staticNativeSpec "native.invalid"
  adapter <-
    compileTestAdapter descriptor [spec] $ \rules -> do
      rule <- resolveNative rules spec decodeRule
      pure
        (adapterBehavior
           (const recognitionMatch)
           (const
              (decodeFailure
                 (decodeDiagnostic rule (unlocatedOccurrence :| []) :| []))))
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  selected <- requireSelected (selectAdapter collection Nothing bytes)
  foldAdapterExecution
    (\descriptorValue rules outcome -> do
       descriptorIdentifier descriptorValue @?= "first"
       NonEmpty.length rules @?= 39
       foldDecodeOutcome
         (\diagnostics -> NonEmpty.length diagnostics @?= 1)
         (const (assertFailure "decode failure became a Draft"))
         outcome)
    (runSelectedAdapter selected bytes)

missingKindTest :: Assertion
missingKindTest = do
  descriptor <- staticDescriptor "missing"
  bindings <- notationBindings
  case NonEmpty.nonEmpty (drop 1 bindings) of
    Nothing -> assertFailure "notation inventory unexpectedly empty"
    Just incomplete ->
      case compileAdapter descriptor incomplete (const (pure inertBehavior)) of
        Left defects ->
          length
            [() | MissingArchiMateNotationRule _ <- NonEmpty.toList defects]
            @?= 1
        Right _ -> assertFailure "incomplete notation binding was accepted"

duplicateKindTest :: Assertion
duplicateKindTest = do
  descriptor <- staticDescriptor "duplicate-kind"
  bindings <- notationBindings
  let duplicate = NonEmpty.head (NonEmpty.fromList bindings)
  case compileAdapter
         descriptor
         (duplicate :| bindings)
         (const (pure inertBehavior)) of
    Left defects ->
      length [() | DuplicateArchiMateNotationRule _ <- NonEmpty.toList defects]
        @?= 1
    Right _ -> assertFailure "duplicate notation binding was accepted"

stageMismatchTest :: Assertion
stageMismatchTest = do
  descriptor <- staticDescriptor "stage-mismatch"
  spec <-
    requireRight
      (mkAdapterRuleSpec "native.wrong" notationRuleStage "e" "m" "a")
  bindings <- notationBindings
  case compileAdapter
         descriptor
         (nativeAdapterRule spec :| bindings)
         (const (pure inertBehavior)) of
    Left defects ->
      length [() | AdapterRuleStageMismatch {} <- NonEmpty.toList defects] @?= 1
    Right _ -> assertFailure "owner-stage mismatch was accepted"

duplicateRuleTest :: Assertion
duplicateRuleTest = do
  descriptor <- staticDescriptor "duplicate-rule"
  spec <- staticNativeSpec "duplicate"
  bindings <- notationBindings
  case compileAdapter
         descriptor
         (nativeAdapterRule spec :| nativeAdapterRule spec : bindings)
         (const (pure inertBehavior)) of
    Left defects ->
      length [() | DuplicateAdapterRuleIdentifier _ <- NonEmpty.toList defects]
        @?= 1
    Right _ -> assertFailure "duplicate rule identity was accepted"

ruleOrderTest :: Assertion
ruleOrderTest = do
  descriptor <- staticDescriptor "ordered"
  later <- staticNativeSpec "zeta"
  earlier <- staticNativeSpec "alpha"
  adapter <-
    compileTestAdapter descriptor [later, earlier] (const (pure inertBehavior))
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  let identifiers =
        fmap
          (adapterRuleIdText . adapterRuleId)
          (adapterContractRules
             (NonEmpty.head (adapterCollectionContracts collection)))
  NonEmpty.head identifiers @?= "alpha"
  NonEmpty.last identifiers @?= "zeta"

contractTest :: Assertion
contractTest = do
  adapter <- staticAdapter "first" True
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
  NonEmpty.length (adapterContractRules contract) @?= 39
  mapM_
    (\kind ->
       case lookupArchiMateNotationRule kind contract of
         Nothing -> assertFailure "compiled Profile-kind binding is missing"
         Just rule -> adapterRuleStage rule @?= notationRuleStage)
    (NonEmpty.toList allArchiMateNotationIssueKinds)

staticAdapter :: Text -> Bool -> IO Adapter
staticAdapter identifier matches = do
  descriptor <- staticDescriptor identifier
  spec <- staticNativeSpec (identifier <> ".native")
  compileTestAdapter descriptor [spec] $ \rules -> do
    _ <- resolveNative rules spec decodeRule
    pure
      (adapterBehavior
         (const
            (if matches
               then recognitionMatch
               else noRecognitionMatch))
         missingDraft)

countedAdapter :: Text -> IORef Int -> Bool -> IO Adapter
countedAdapter identifier calls matches = do
  descriptor <- staticDescriptor identifier
  spec <- staticNativeSpec (identifier <> ".native")
  compileTestAdapter descriptor [spec] $ \rules -> do
    _ <- resolveNative rules spec decodeRule
    pure (adapterBehavior (countedRecognition calls matches) missingDraft)

recognitionFailureAdapter :: Text -> IO Adapter
recognitionFailureAdapter identifier = do
  descriptor <- staticDescriptor identifier
  spec <- staticNativeSpec (identifier <> ".recognition")
  compileTestAdapter descriptor [spec] $ \rules -> do
    rule <- resolveNative rules spec recognitionRule
    pure
      (adapterBehavior
         (const
            (recognitionFailure
               (recognitionDiagnostic rule (unlocatedOccurrence :| []) :| [])))
         missingDraft)

compileTestAdapter ::
     AdapterDescriptor
  -> [AdapterRuleSpec]
  -> (forall scope. AdapterRules scope -> Either
                                            (NonEmpty AdapterCompilationDefect)
                                            (AdapterBehavior scope))
  -> IO Adapter
compileTestAdapter descriptor nativeSpecs define = do
  bindings <- notationBindings
  requireRight
    (compileAdapter
       descriptor
       (case map nativeAdapterRule nativeSpecs <> bindings of
          firstBinding:rest -> firstBinding :| rest
          [] -> error "closed notation inventory is empty")
       define)

notationBindings :: IO [AdapterRuleBinding]
notationBindings =
  traverse binding (NonEmpty.toList allArchiMateNotationIssueKinds)
  where
    binding kind =
      archiMateNotationRule kind
        <$> requireRight
              (mkAdapterRuleSpec
                 ("notation." <> archiMateNotationIssueKindToken kind)
                 notationRuleStage
                 "expectation"
                 "meaning"
                 "action")

staticDescriptor :: Text -> IO AdapterDescriptor
staticDescriptor identifier = do
  adapterIdentifier <- requireRight (mkAdapterId identifier)
  requireRight (mkAdapterDescriptor adapterIdentifier identifier "1" "test")

staticNativeSpec :: Text -> IO AdapterRuleSpec
staticNativeSpec identifier =
  requireRight
    (mkAdapterRuleSpec
       identifier
       preparationRuleStage
       "expectation"
       "meaning"
       "action")

resolveNative ::
     AdapterRules scope
  -> AdapterRuleSpec
  -> (NativeAdapterRule scope -> rule)
  -> Either (NonEmpty AdapterCompilationDefect) rule
resolveNative rules spec restrict =
  first
    pure
    (restrict <$> lookupNativeAdapterRule rules (adapterRuleSpecId spec))

inertBehavior :: AdapterBehavior scope
inertBehavior = adapterBehavior (const recognitionMatch) missingDraft

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
