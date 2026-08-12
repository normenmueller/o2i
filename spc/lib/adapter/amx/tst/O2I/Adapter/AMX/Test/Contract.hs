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
import O2I.Adapter.AMX.Internal.XML (hasNativeAMXSignal)
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring (compileAdapterCollection, mkAdapterId)
import Paths_o2i_amx (getDataFileName)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

contractTests :: TestTree
contractTests =
  testGroup
    "contract"
    [ testCase "compiles one immutable AMX adapter" compileTest
    , testCase "publishes the closed native rule inventory" inventoryTest
    , testCase "recognizes exact native AMX" recognitionTest
    , testCase "treats another XML root as no match" noMatchTest
    , testCase
        "reports unclassifiable XML at recognition"
        recognitionFailureTest
    , testCase
        "retains the native signal across malformed UTF-8"
        malformedUtf8RecognitionTest
    , testCase
        "respects the malformed-input ownership boundary"
        malformedInputOwnershipBoundaryTest
    , testCase
        "does not claim unrelated representations"
        unrelatedRepresentationTest
    , testCase
        "does not veto another malformed XML representation"
        unrelatedMalformedXmlTest
    , testCase
        "resolves the exact root namespace without substring claims"
        exactRootSignalTest
    , testCase
        "does not claim a namespace collision at the root"
        namespaceCollisionTest
    , testCase
        "does not claim lexically invalid root whitespace"
        invalidRootWhitespaceTest
    , testCase
        "does not claim malformed content before the native root"
        invalidRootPrefixTest
    , testCase
        "does not claim an invalid attribute QName before the native binding"
        invalidAttributeQNameTest
    , testCase
        "does not claim attributes without XML separators"
        missingAttributeSeparatorTest
    , testCase
        "does not claim invalid pre-ownership XML lexemes"
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
        "does not claim an unrelated declaration before the native root"
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
    @?= [("amx", "Archi Model XML", "5.0.0-v1", "ArchiMate")]

inventoryTest :: Assertion
inventoryTest = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
  map ruleSnapshot (NonEmpty.toList (adapterContractRules contract))
    @?= expectedRuleInventory

recognitionTest :: Assertion
recognitionTest = do
  selection <- implicitSelection validModel
  foldAdapterSelection
    (const (assertFailure "native AMX was not selected"))
    (const (pure ()))
    selection

noMatchTest :: Assertion
noMatchTest = do
  selection <- implicitSelection wrongRoot
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "format mismatch became recognition failure"))
       (pure ())
       (const (assertFailure "one adapter produced multiple matches")))
    (const (assertFailure "wrong root matched AMX"))
    selection

recognitionFailureTest :: Assertion
recognitionFailureTest = do
  selection <- implicitSelection malformedAMX
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
  selection <- implicitSelection malformedUtf8AMX
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (pure ()))
       (assertFailure "malformed native UTF-8 became a clean no-match")
       (const (assertFailure "malformed native UTF-8 produced matches")))
    (const (assertFailure "malformed native UTF-8 selected AMX"))
    selection

malformedInputOwnershipBoundaryTest :: Assertion
malformedInputOwnershipBoundaryTest = do
  mapM_
    assertNoMatch
    [ "<a:model note=\""
        <> ByteString.singleton 0xFF
        <> "\" "
        <> ownershipBinding
        <> closeRoot
    , "<a:model note=\"\0\" " <> ownershipBinding <> closeRoot
    ]
  mapM_
    assertRecognitionFailure
    [ "<a:model " <> ownershipBinding <> " note=\"" <> ByteString.singleton 0xFF
    , "<a:model " <> ownershipBinding <> " note=\"\0"
    ]
  where
    ownershipBinding = "xmlns:a=\"http://www.archimatetool.com/archimate\""
    closeRoot = " version=\"5.0.0\"/>"
    assertNoMatch input = do
      assertBool
        "malformed pre-ownership input retained a native signal"
        (not (hasNativeAMXSignal input))
      selection <- implicitSelection input
      foldAdapterSelection
        (foldAdapterSelectionError
           (const (assertFailure "unexpected explicit lookup failure"))
           (const (assertFailure "malformed pre-ownership input claimed AMX"))
           (pure ())
           (const (assertFailure "malformed input produced matches")))
        (const (assertFailure "malformed pre-ownership input selected AMX"))
        selection
    assertRecognitionFailure input = do
      assertBool
        "malformed post-ownership input lost its native signal"
        (hasNativeAMXSignal input)
      selection <- implicitSelection input
      foldAdapterSelection
        (foldAdapterSelectionError
           (const (assertFailure "unexpected explicit lookup failure"))
           (const (pure ()))
           (assertFailure "malformed native input became a clean no-match")
           (const (assertFailure "malformed native input produced matches")))
        (const (assertFailure "malformed native input selected AMX"))
        selection

explicitDecodeTest :: Assertion
explicitDecodeTest = do
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
unrelatedRepresentationTest = do
  selection <- implicitSelection "{\"format\":\"another-adapter\"}"
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "unrelated representation became AMX failure"))
       (pure ())
       (const (assertFailure "unrelated representation produced matches")))
    (const (assertFailure "unrelated representation selected AMX"))
    selection

unrelatedMalformedXmlTest :: Assertion
unrelatedMalformedXmlTest = do
  selection <- implicitSelection "<future"
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "another XML format became AMX failure"))
       (pure ())
       (const (assertFailure "another XML format produced matches")))
    (const (assertFailure "another XML format selected AMX"))
    selection

exactRootSignalTest :: Assertion
exactRootSignalTest = do
  selection <-
    implicitSelection
      "<future:model note=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "incidental namespace text claimed AMX"))
       (pure ())
       (const (assertFailure "incidental namespace text produced matches")))
    (const (assertFailure "incidental namespace text selected AMX"))
    selection

namespaceCollisionTest :: Assertion
namespaceCollisionTest = do
  selection <-
    implicitSelection
      "<f:model xmlns:f=\"urn:future\" xmlns:a=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "foreign root namespace claimed AMX"))
       (pure ())
       (const (assertFailure "foreign root namespace produced matches")))
    (const (assertFailure "foreign root namespace selected AMX"))
    selection

invalidRootWhitespaceTest :: Assertion
invalidRootWhitespaceTest = do
  selection <-
    implicitSelection
      "< a:model xmlns:a=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "invalid root whitespace claimed AMX"))
       (pure ())
       (const (assertFailure "invalid root whitespace produced matches")))
    (const (assertFailure "invalid root whitespace selected AMX"))
    selection

invalidRootPrefixTest :: Assertion
invalidRootPrefixTest = do
  selection <-
    implicitSelection
      "broken<a:model xmlns:a=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "malformed root prefix claimed AMX"))
       (pure ())
       (const (assertFailure "malformed root prefix produced matches")))
    (const (assertFailure "malformed root prefix selected AMX"))
    selection

invalidAttributeQNameTest :: Assertion
invalidAttributeQNameTest = do
  selection <-
    implicitSelection
      "<a:model 1broken=\"value\" xmlns:a=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "invalid attribute QName claimed AMX"))
       (pure ())
       (const (assertFailure "invalid attribute QName produced matches")))
    (const (assertFailure "invalid attribute QName selected AMX"))
    selection

missingAttributeSeparatorTest :: Assertion
missingAttributeSeparatorTest = do
  selection <-
    implicitSelection
      "<a:model note=\"x\"xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "missing attribute separator claimed AMX"))
       (pure ())
       (const (assertFailure "missing attribute separator produced matches")))
    (const (assertFailure "missing attribute separator selected AMX"))
    selection

invalidPreOwnershipLexemeTest :: Assertion
invalidPreOwnershipLexemeTest =
  mapM_
    assertNoMatch
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
  where
    assertNoMatch input = do
      assertBool
        ("invalid input retained a native signal: " <> show input)
        (not (hasNativeAMXSignal input))
      selection <- implicitSelection input
      foldAdapterSelection
        (foldAdapterSelectionError
           (const (assertFailure "unexpected explicit lookup failure"))
           (const (assertFailure "invalid input claimed AMX"))
           (pure ())
           (const (assertFailure "invalid input produced matches")))
        (const (assertFailure "invalid input selected AMX"))
        selection

provenOwnershipTest :: Assertion
provenOwnershipTest = do
  mapM_
    assertRecognitionFailure
    [ "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" broken="
    , "<a:model x:value=\"pending\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    ]
  where
    assertRecognitionFailure input = do
      selection <- implicitSelection input
      foldAdapterSelection
        (foldAdapterSelectionError
           (const (assertFailure "unexpected explicit lookup failure"))
           (const (pure ()))
           (assertFailure "proven native ownership became a clean no-match")
           (const (assertFailure "malformed native root produced matches")))
        (const (assertFailure "malformed native root selected AMX"))
        selection

internalSubsetRecognitionTest :: Assertion
internalSubsetRecognitionTest = do
  fixture <-
    ByteString.readFile
      =<< getDataFileName "tst/data/invalid/decode/unsafe-doctype.archimate"
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
unrelatedDeclarationTest = do
  selection <-
    implicitSelection
      "<!future><a:model xmlns:a=\"http://www.archimatetool.com/archimate\""
  foldAdapterSelection
    (foldAdapterSelectionError
       (const (assertFailure "unexpected explicit lookup failure"))
       (const (assertFailure "unrelated declaration claimed AMX"))
       (pure ())
       (const (assertFailure "unrelated declaration produced matches")))
    (const (assertFailure "unrelated declaration selected AMX"))
    selection

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
  let utf16 =
        "\255\254"
          <> TextEncoding.encodeUtf16LE
               "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
  selection <- implicitSelection utf16
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
  assertBool
    "CRLF and LF namespace aliases did not collapse before ownership"
    (not (hasNativeAMXSignal duplicate))
  assertBool
    "CRLF and two-space namespace values did not remain distinct"
    (hasNativeAMXSignal distinct)

largeOpeningTagTest :: Assertion
largeOpeningTagTest = do
  let model =
        "<a:model note=\""
          <> ByteString.replicate (1024 * 1024) 120
          <> "\" xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
  assertBool
    "large native opening tag lost its signal"
    (hasNativeAMXSignal model)
  selection <- implicitSelection model
  foldAdapterSelection
    (const
       (assertFailure "native AMX with a large opening tag was not selected"))
    (const (pure ()))
    selection

implicitSelection :: ByteString -> IO AdapterSelection
implicitSelection bytes = do
  adapter <- requireAdapter
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  pure (selectAdapter collection Nothing bytes)

descriptorSnapshot :: CompiledAdapterContract -> (Text, Text, Text, Text)
descriptorSnapshot contract =
  foldAdapterDescriptor
    (\identifier name version notation ->
       (adapterIdText identifier, name, version, notation))
    (adapterContractDescriptor contract)

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

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

validModel, wrongRoot, wrongVersion, missingVersion, malformedAMX :: ByteString
validModel = TextEncoding.encodeUtf8 validModelText

validModelText :: Text
validModelText =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"

wrongRoot = "<model xmlns=\"urn:not-archi\" version=\"5.0.0\"/>"

wrongVersion =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"4.0.0\"/>"

missingVersion = "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\"/>"

malformedAMX = "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\""

malformedUtf8AMX :: ByteString
malformedUtf8AMX = validModel <> "\255"
