{-# LANGUAGE OverloadedStrings #-}

module O2I.Adapter.AMX.Test.Contract
  ( contractTests
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text.Encoding as TextEncoding
import O2I.Adapter.AMX
import O2I.Adapter.AMX.Test.Fixture (fixtureBytes)
import qualified O2I.ArchiMate.Profile as Profile
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
  ( adapterBehavior
  , compileAdapter
  , compileAdapterCollection
  , mkAdapterDescriptor
  , mkAdapterId
  , mkAdapterRuleDefinition
  , noRecognitionMatch
  , recognitionMatch
  , recognitionRule
  )
import O2I.Operation.Profile
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

contractTests :: TestTree
contractTests =
  testGroup
    "contract"
    [ testCase "compiles one immutable AMX adapter" compileTest
    , testCase
        "matches the real compiled ArchiMate Profile"
        profileCompatibilityTest
    , testCase "publishes the closed native rule inventory" inventoryTest
    , testCase "recognizes exact native AMX" recognitionTest
    , testCase "treats another XML root as no match" noMatchTest
    , testCase
        "reports unclassifiable XML at recognition"
        recognitionFailureTest
    , testCase
        "retains the native signal across malformed UTF-8"
        malformedUtf8RecognitionTest
    , testCase "classifies every malformed input as failure" malformedInputTest
    , testCase
        "does not claim unrelated representations"
        unrelatedRepresentationTest
    , testCase
        "does not veto another adapter's non-XML representation"
        unrelatedAdapterSelectionTest
    , testCase
        "rejects another malformed XML representation"
        unrelatedMalformedXmlTest
    , testCase
        "rejects malformed input containing incidental namespace text"
        exactRootSignalTest
    , testCase
        "rejects malformed namespace collisions at the root"
        namespaceCollisionTest
    , testCase
        "rejects lexically invalid root whitespace"
        invalidRootWhitespaceTest
    , testCase
        "rejects malformed content before the native root"
        invalidRootPrefixTest
    , testCase
        "rejects an invalid attribute QName before the native binding"
        invalidAttributeQNameTest
    , testCase
        "rejects attributes without XML separators"
        missingAttributeSeparatorTest
    , testCase
        "rejects invalid XML lexemes before the native root"
        invalidPreOwnershipLexemeTest
    , testCase
        "retains ownership after a proven native namespace binding"
        provenOwnershipTest
    , testCase
        "retains ownership across a forbidden internal DTD subset"
        internalSubsetRecognitionTest
    , testCase
        "retains ownership across legal DTD lexical states"
        internalSubsetLexicalStateTest
    , testCase
        "rejects an unrelated declaration before the native root"
        unrelatedDeclarationTest
    , testCase
        "recognizes exact native AMX after a long legal prolog"
        longPrologTest
    , testCase
        "retains the exact native signal for unsupported UTF-16"
        unsupportedEncodingSignalTest
    , testCase
        "retains exact native signals for BOM-less UTF-16 and UTF-32"
        unsupportedBomlessEncodingSignalTest
    , testCase
        "normalizes namespace character references during recognition"
        normalizedNamespaceSignalTest
    , testCase
        "applies XML end-of-line normalization during recognition"
        namespaceEndOfLineRecognitionTest
    , testCase
        "recognizes exact native AMX with a large opening tag"
        largeOpeningTagTest
    , testCase
        "rejects wrong native root after explicit selection"
        explicitDecodeTest
    ]

compileTest :: Assertion
compileTest = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  map
    descriptorSnapshot
    (NonEmpty.toList (adapterCollectionContracts collection))
    @?= [("amx", "Archi Model XML", "5.0.0-v1", "archimate-3.2")]

profileCompatibilityTest :: Assertion
profileCompatibilityTest = do
  selected <- requireImplicitSelection profiledModel
  draft <- requireDecodedDraft selected profiledModel
  inventory <-
    foldProfileInventoryCompilation
      (const
         (assertFailure "real compiled Profile inventory was invalid"
            >> fail "unreachable"))
      pure
      (compileProfileInventory Profile.compiledProfileInventory)
  evidence <-
    foldProfileMarkerEvidenceOutcome
      (const
         (assertFailure "real AMX Profile marker evidence was rejected"
            >> fail "unreachable"))
      pure
      (prepareProfileMarkerEvidence
         (Notation.assessMarkerEvidence (Notation.buildCanonicalDocument draft)))
  resolved <-
    foldProfileResolution
      (\_ _ -> unresolved)
      (\_ _ _ -> unresolved)
      (\_ _ _ _ -> unresolved)
      (\_ _ _ _ -> unresolved)
      (\_ _ _ -> unresolved)
      (\_ _ _ -> unresolved)
      pure
      (resolveProfile inventory evidence)
  foldProfileCompatibility
    (\_ _ _ _ -> assertFailure "real AMX adapter was not admitted")
    (\_ _ _ _ _ -> assertFailure "real AMX notation did not match")
    (\_ _ notation -> notation @?= "archimate-3.2")
    (checkProfileCompatibility resolved selected)
  where
    unresolved =
      assertFailure "real AMX Profile marker did not resolve"
        >> fail "unreachable"

inventoryTest :: Assertion
inventoryTest = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
  map ruleSnapshot (NonEmpty.toList (adapterContractRules contract))
    @?= expectedRuleInventory

recognitionTest :: Assertion
recognitionTest = do
  fixture <- fixtureBytes "native-minimal"
  selection <- implicitSelection fixture
  foldAdapterSelection
    (const (assertFailure "native AMX was not selected"))
    (const (pure ()))
    selection

noMatchTest :: Assertion
noMatchTest = do
  fixtures <-
    mapM
      fixtureBytes
      [ "decode-wrong-root"
      , "decode-native-version-wrong"
      , "decode-native-version-missing"
      , "decode-native-version-namespaced"
      ]
  mapM_ assertNoMatch fixtures

recognitionFailureTest :: Assertion
recognitionFailureTest = do
  fixture <- fixtureBytes "decode-malformed-xml"
  selection <- implicitSelection fixture
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (\failures ->
          map recognitionFailureSnapshot (NonEmpty.toList failures)
            @?= [("amx", ["o2i.amx.recognition.xml-well-formedness"], [])])
       (assertFailure "malformed XML became a clean no-match")
       (const (assertFailure "malformed XML became multiple matches")))
    (const (assertFailure "malformed XML selected AMX"))
    selection

malformedUtf8RecognitionTest :: Assertion
malformedUtf8RecognitionTest = do
  fixture <- fixtureBytes "decode-invalid-utf8"
  selection <- implicitSelection fixture
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (pure ()))
       (assertFailure "malformed native UTF-8 became a clean no-match")
       (const (assertFailure "malformed native UTF-8 produced matches")))
    (const (assertFailure "malformed native UTF-8 selected AMX"))
    selection

malformedInputTest :: Assertion
malformedInputTest =
  mapM_
    assertRecognitionFailed
    [ "<a:model note=\""
        <> ByteString.singleton 0xFF
        <> "\" "
        <> ownershipBinding
        <> closeRoot
    , "<a:model note=\"\0\" " <> ownershipBinding <> closeRoot
    , "<a:model " <> ownershipBinding <> " note=\"" <> ByteString.singleton 0xFF
    , "<a:model " <> ownershipBinding <> " note=\"\0"
    ]
  where
    ownershipBinding = "xmlns:a=\"http://www.archimatetool.com/archimate\""
    closeRoot = " version=\"5.0.0\"/>"

explicitDecodeTest :: Assertion
explicitDecodeTest = do
  wrongRoot <- fixtureBytes "decode-wrong-root"
  wrongVersion <- fixtureBytes "decode-native-version-wrong"
  missingVersion <- fixtureBytes "decode-native-version-missing"
  malformedAMX <- fixtureBytes "decode-malformed-xml"
  wrongRootDiagnostics <- explicitDiagnostics wrongRoot
  map diagnosticSnapshot (NonEmpty.toList wrongRootDiagnostics)
    @?= [("o2i.amx.decode.root-qname", ["{urn:not-archi}model[1]"])]
  wrongVersionDiagnostics <- explicitDiagnostics wrongVersion
  map diagnosticSnapshot (NonEmpty.toList wrongVersionDiagnostics)
    @?= [ ( "o2i.amx.decode.native-version"
          , ["{http://www.archimatetool.com/archimate}model[1]", "version[1]"])
        ]
  missingVersionDiagnostics <- explicitDiagnostics missingVersion
  map diagnosticSnapshot (NonEmpty.toList missingVersionDiagnostics)
    @?= [ ( "o2i.amx.decode.native-version"
          , ["{http://www.archimatetool.com/archimate}model[1]"])
        ]
  malformedDiagnostics <- explicitDiagnostics malformedAMX
  map diagnosticSnapshot (NonEmpty.toList malformedDiagnostics)
    @?= [("o2i.amx.decode.xml-well-formedness", [])]

explicitDiagnostics :: ByteString -> IO (NonEmpty AdapterDiagnostic)
explicitDiagnostics bytes = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  identifier <- requireRight (mkAdapterId "amx")
  selected <-
    foldAdapterSelection
      (const
         (assertFailure "explicit AMX selection failed" >> fail "unreachable"))
      pure
      (selectAdapter collection (Just identifier) bytes)
  foldDecodeOutcome
    pure
    (const
       (assertFailure "invalid native contract produced a Draft"
          >> fail "unreachable"))
    (adapterExecutionOutcome (runSelectedAdapter selected bytes))

unrelatedRepresentationTest :: Assertion
unrelatedRepresentationTest =
  assertRecognitionFailed "{\"format\":\"another-adapter\"}"

unrelatedAdapterSelectionTest :: Assertion
unrelatedAdapterSelectionTest = do
  amx <- requireAdapter
  other <- requireUnrelatedAdapter
  collection <- requireRight (compileAdapterCollection (amx :| [other]))
  selected <-
    foldAdapterSelection
      (const
         (assertFailure "unrelated adapter selection failed"
            >> fail "unreachable"))
      pure
      (selectAdapter collection Nothing unrelatedRepresentation)
  adapterIdText (adapterDescriptorId (selectedAdapterDescriptor selected))
    @?= "another-adapter"

unrelatedMalformedXmlTest :: Assertion
unrelatedMalformedXmlTest = assertRecognitionFailed "<future"

exactRootSignalTest :: Assertion
exactRootSignalTest =
  assertRecognitionFailed
    "<future:model note=\"http://www.archimatetool.com/archimate\""

namespaceCollisionTest :: Assertion
namespaceCollisionTest =
  assertRecognitionFailed
    "<f:model xmlns:f=\"urn:future\" xmlns:a=\"http://www.archimatetool.com/archimate\""

invalidRootWhitespaceTest :: Assertion
invalidRootWhitespaceTest =
  assertRecognitionFailed
    "< a:model xmlns:a=\"http://www.archimatetool.com/archimate\""

invalidRootPrefixTest :: Assertion
invalidRootPrefixTest =
  assertRecognitionFailed
    "broken<a:model xmlns:a=\"http://www.archimatetool.com/archimate\""

invalidAttributeQNameTest :: Assertion
invalidAttributeQNameTest =
  assertRecognitionFailed
    "<a:model 1broken=\"value\" xmlns:a=\"http://www.archimatetool.com/archimate\""

missingAttributeSeparatorTest :: Assertion
missingAttributeSeparatorTest =
  assertRecognitionFailed
    "<a:model note=\"x\"xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"

invalidPreOwnershipLexemeTest :: Assertion
invalidPreOwnershipLexemeTest =
  mapM_
    assertRecognitionFailed
    [ "<a:model xmlns:a=\"http://www.archi&#X6D;atetool.com/archimate\" version=\"5.0.0\"/>"
    , "<a:model xmlns:a=\"http://www.archi&# 109;atetool.com/archimate\" version=\"5.0.0\"/>"
    , "<!DOCTYPE ???><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<!DOCTYPE model PUBLIC \"bad[public\" \"system\"><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<!DOCTYPE model [garbage]><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<!DOCTYPE model [<!UNKNOWN value>]><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<a:model note=\"one\" note=\"two\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<a:model xmlns:xmlns=\"urn:forbidden\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<a:model xmlns:x=\"urn:same\" xmlns:y=\"urn:same\" x:value=\"one\" y:value=\"two\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    ]

provenOwnershipTest :: Assertion
provenOwnershipTest =
  mapM_
    assertRecognitionFailed
    [ "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" broken="
    , "<a:model x:value=\"pending\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    ]

internalSubsetRecognitionTest :: Assertion
internalSubsetRecognitionTest = do
  fixture <- fixtureBytes "decode-dtd-internal-entity"
  selection <- implicitSelection fixture
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (\failures ->
          map recognitionFailureSnapshot (NonEmpty.toList failures)
            @?= [("amx", ["o2i.amx.recognition.xml-facility"], [])])
       (assertFailure "forbidden native DTD became a clean no-match")
       (const (assertFailure "forbidden native DTD produced matches")))
    (const (assertFailure "forbidden native DTD selected AMX"))
    selection

internalSubsetLexicalStateTest :: Assertion
internalSubsetLexicalStateTest =
  mapM_
    assertRecognitionFailure
    [ "<!DOCTYPE model [<!-- ] > --><!ENTITY value \"quoted ] >\">]><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    , "<!DOCTYPE model [<?probe ] >?><!ENTITY value \"quoted\">]><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    ]
  where
    assertRecognitionFailure input = do
      selection <- implicitSelection input
      foldAdapterSelection
        (foldAdapterSelectionError
           (const (assertFailure "unexpected explicit lookup failure"))
           (const (pure ()))
           (assertFailure
              ("legal DTD lexical state lost native ownership: " <> show input))
           (const (assertFailure "forbidden DTD produced matches")))
        (const (assertFailure "forbidden DTD selected AMX"))
        selection

unrelatedDeclarationTest :: Assertion
unrelatedDeclarationTest =
  assertRecognitionFailed
    "<!future><a:model xmlns:a=\"http://www.archimatetool.com/archimate\""

longPrologTest :: Assertion
longPrologTest = do
  selection <-
    implicitSelection
      ("<!--" <> ByteString.replicate 8200 120 <> "-->" <> validModel)
  foldAdapterSelection
    (const (assertFailure "native AMX after a long prolog was not selected"))
    (const (pure ()))
    selection

unsupportedEncodingSignalTest :: Assertion
unsupportedEncodingSignalTest = do
  fixture <- fixtureBytes "decode-unsupported-encoding"
  selection <- implicitSelection fixture
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (pure ()))
       (assertFailure "unsupported native UTF-16 became a clean no-match")
       (const (assertFailure "unsupported native UTF-16 produced matches")))
    (const (assertFailure "unsupported native UTF-16 selected AMX"))
    selection

unsupportedBomlessEncodingSignalTest :: Assertion
unsupportedBomlessEncodingSignalTest =
  mapM_
    assertUnsupportedSignal
    [ TextEncoding.encodeUtf16LE validModelText
    , TextEncoding.encodeUtf16BE validModelText
    , TextEncoding.encodeUtf32LE validModelText
    , TextEncoding.encodeUtf32BE validModelText
    ]

assertUnsupportedSignal :: ByteString -> Assertion
assertUnsupportedSignal bytes = do
  selection <- implicitSelection bytes
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (pure ()))
       (assertFailure "unsupported native encoding became a clean no-match")
       (const (assertFailure "unsupported native encoding produced matches")))
    (const (assertFailure "unsupported native encoding selected AMX"))
    selection

normalizedNamespaceSignalTest :: Assertion
normalizedNamespaceSignalTest = do
  selection <-
    implicitSelection
      "<a:model xmlns:a=\"http://www.archi&#109;atetool.com/archimate\" version=\"5.0.0\"/>"
  foldAdapterSelection
    (const (assertFailure "normalized native namespace was not selected"))
    (const (pure ()))
    selection

namespaceEndOfLineRecognitionTest :: Assertion
namespaceEndOfLineRecognitionTest = do
  let duplicate =
        "<a:model x:value=\"one\" y:value=\"two\" xmlns:x=\"urn:\r\nsame\" xmlns:y=\"urn:\nsame\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
      distinct =
        "<a:model x:value=\"one\" y:value=\"two\" xmlns:x=\"urn:\r\nsame\" xmlns:y=\"urn:  same\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
  assertRecognitionFailed duplicate
  selected <- requireImplicitSelection distinct
  selectedDescriptorSnapshot selected
    @?= ("amx", "Archi Model XML", "5.0.0-v1", "archimate-3.2")

largeOpeningTagTest :: Assertion
largeOpeningTagTest = do
  let model =
        "<a:model note=\""
          <> ByteString.replicate (1024 * 1024) 120
          <> "\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
  _ <- requireImplicitSelection model
  pure ()

implicitSelection :: ByteString -> IO AdapterSelection
implicitSelection bytes = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  pure (selectAdapter collection Nothing bytes)

requireImplicitSelection :: ByteString -> IO SelectedAdapter
requireImplicitSelection bytes = do
  selection <- implicitSelection bytes
  foldAdapterSelection
    (const (assertFailure "expected AMX to be selected" >> fail "unreachable"))
    pure
    selection

requireDecodedDraft :: SelectedAdapter -> ByteString -> IO Draft.ProfileDraft
requireDecodedDraft selected bytes =
  foldDecodeOutcome
    (const (assertFailure "expected AMX to decode" >> fail "unreachable"))
    pure
    (adapterExecutionOutcome (runSelectedAdapter selected bytes))

assertNoMatch :: ByteString -> Assertion
assertNoMatch bytes = do
  selection <- implicitSelection bytes
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "format mismatch became recognition failure"))
       (pure ())
       (const (assertFailure "format mismatch produced multiple matches")))
    (const (assertFailure "format mismatch selected AMX"))
    selection

assertRecognitionFailed :: ByteString -> Assertion
assertRecognitionFailed bytes = do
  selection <- implicitSelection bytes
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (pure ()))
       (assertFailure "malformed input became a clean no-match")
       (const (assertFailure "malformed input produced multiple matches")))
    (const (assertFailure "malformed input selected AMX"))
    selection

descriptorSnapshot :: CompiledAdapterContract -> (Text, Text, Text, Text)
descriptorSnapshot contract =
  foldAdapterDescriptor
    (\identifier name version notation ->
       (adapterIdText identifier, name, version, notation))
    (adapterContractDescriptor contract)

selectedDescriptorSnapshot :: SelectedAdapter -> (Text, Text, Text, Text)
selectedDescriptorSnapshot =
  foldAdapterDescriptor
    (\identifier name version notation ->
       (adapterIdText identifier, name, version, notation))
    . selectedAdapterDescriptor

ruleSnapshot :: AdapterRule -> (Text, Text)
ruleSnapshot rule =
  ( adapterRuleIdText (adapterRuleId rule)
  , adapterRuleStageText (adapterRuleStage rule))

diagnosticId :: AdapterDiagnostic -> Text
diagnosticId = adapterRuleIdText . adapterRuleId . adapterDiagnosticRule

diagnosticSnapshot :: AdapterDiagnostic -> (Text, [Text])
diagnosticSnapshot diagnostic =
  ( diagnosticId diagnostic
  , concatMap
      occurrencePath
      (NonEmpty.toList (adapterDiagnosticOccurrences diagnostic)))

occurrencePath :: AdapterOccurrence -> [Text]
occurrencePath =
  foldAdapterOccurrence
    []
    (foldNativeLocation (const []) (\_ _ -> []) NonEmpty.toList)

descriptorId :: AdapterDescriptor -> Text
descriptorId = adapterIdText . adapterDescriptorId

recognitionFailureSnapshot ::
     (AdapterDescriptor, NonEmpty AdapterDiagnostic) -> (Text, [Text], [Text])
recognitionFailureSnapshot (descriptor, diagnostics) =
  ( descriptorId descriptor
  , map diagnosticId (NonEmpty.toList diagnostics)
  , concatMap
      (concatMap occurrencePath . NonEmpty.toList . adapterDiagnosticOccurrences)
      (NonEmpty.toList diagnostics))

expectedRuleInventory :: [(Text, Text)]
expectedRuleInventory =
  [ ("o2i.amx.decode.encoding", "decode")
  , ("o2i.amx.decode.input-byte-limit", "decode")
  , ("o2i.amx.decode.native-version", "decode")
  , ("o2i.amx.decode.root-qname", "decode")
  , ("o2i.amx.decode.utf8", "decode")
  , ("o2i.amx.decode.xml-attribute-limit", "decode")
  , ("o2i.amx.decode.xml-depth-limit", "decode")
  , ("o2i.amx.decode.xml-element-limit", "decode")
  , ("o2i.amx.decode.xml-facility", "decode")
  , ("o2i.amx.decode.xml-scalar", "decode")
  , ("o2i.amx.decode.xml-text-limit", "decode")
  , ("o2i.amx.decode.xml-well-formedness", "decode")
  , ("o2i.amx.recognition.encoding", "recognition")
  , ("o2i.amx.recognition.input-byte-limit", "recognition")
  , ("o2i.amx.recognition.utf8", "recognition")
  , ("o2i.amx.recognition.xml-attribute-limit", "recognition")
  , ("o2i.amx.recognition.xml-depth-limit", "recognition")
  , ("o2i.amx.recognition.xml-element-limit", "recognition")
  , ("o2i.amx.recognition.xml-facility", "recognition")
  , ("o2i.amx.recognition.xml-scalar", "recognition")
  , ("o2i.amx.recognition.xml-text-limit", "recognition")
  , ("o2i.amx.recognition.xml-well-formedness", "recognition")
  ]

requireAdapter :: IO Adapter
requireAdapter =
  case amxAdapter of
    Left _ ->
      assertFailure "static AMX adapter failed to compile" >> fail "unreachable"
    Right adapter -> pure adapter

requireUnrelatedAdapter :: IO Adapter
requireUnrelatedAdapter = do
  identifier <- requireRight (mkAdapterId "another-adapter")
  descriptor <-
    requireRight
      (mkAdapterDescriptor identifier "Another adapter" "1" "another-notation")
  definition <-
    requireRight
      (mkAdapterRuleDefinition
         "another-adapter.recognition"
         "Recognize the exact test representation."
         "The representation belongs to the other adapter."
         "Select the other adapter.")
  requireRight
    (compileAdapter
       descriptor
       ((\_ ->
           adapterBehavior
             (\input ->
                if input == unrelatedRepresentation
                  then recognitionMatch
                  else noRecognitionMatch)
             (const (error "decode is outside this selection test")))
          <$> recognitionRule definition))

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

validModel, profiledModel, unrelatedRepresentation :: ByteString
validModel = TextEncoding.encodeUtf8 validModelText

profiledModel =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" id=\"model\" version=\"5.0.0\"><property key=\"o2i.profile\" value=\"o2i.archimate-profile@0.3\"/></a:model>"

unrelatedRepresentation = "{\"format\":\"another-adapter\"}"

validModelText :: Text
validModelText =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
