{-# LANGUAGE OverloadedStrings #-}

-- | Decode trust-boundary tests.
module O2I.Adapter.AMX.Test.Decode
  ( decodeTests
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile
import O2I.Adapter.AMX.Internal.View
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Internal.XML.Scan
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

decodeTests :: TestTree
decodeTests =
  testGroup
    "decode"
    [ testCase "classifies empty bytes as malformed XML" decodeEmptyTest
    , testCase "accepts exact UTF-8 native binding" decodeValidTest
    , testCase "accepts UTF-8 BOM" decodeBomTest
    , testCase "rejects invalid UTF-8" decodeInvalidUtf8Test
    , testCase "rejects non-UTF-8 declaration" decodeEncodingTest
    , testCase "rejects non-UTF-8 BOM" decodeEncodingBomTest
    , testCase "rejects DTD and entity declarations" decodeUnsafeTest
    , testCase
        "rejects external entity and network attempts"
        decodeExternalEntityTest
    , testCase "rejects undeclared entity references" decodeEntityTest
    , testCase "does not confuse comment text with a DTD" decodeCommentTest
    , testCase "rejects malformed XML" decodeMalformedTest
    , testCase "rejects the wrong expanded root QName" decodeRootTest
    , testCase "rejects missing native version" decodeMissingVersionTest
    , testCase "rejects unsupported native version" decodeVersionTest
    , testCase "accepts and rejects the exact input-byte boundary" byteLimitTest
    , testCase "accepts and rejects the exact XML-depth boundary" depthLimitTest
    , testCase
        "accepts and rejects the exact element-node boundary"
        elementLimitTest
    , testCase
        "counts namespace declarations at the attribute boundary"
        attributeLimitTest
    , testCase
        "accepts and rejects the exact character-data boundary"
        textLimitTest
    , testCase "counts CDATA as character data" cdataLimitTest
    , testCase
        "accepts predefined and numeric entities as one character each"
        entityCountingTest
    , testCase "rejects many ampersands deterministically" repeatedAmpersandTest
    , testCase
        "leaves malformed lexical structure to the native parser"
        malformedLexicalTest
    , testCase "reports resource limits at Decode" resourceStageTest
    ]

decodeEmptyTest :: Assertion
decodeEmptyTest =
  decodeCodes (sourceBytes ByteString.empty)
    @?= ["o2i.amx.decode.xml-malformed"]

decodeValidTest :: Assertion
decodeValidTest =
  case decodeSource (source validEmptyModel) of
    DecodePassed binding _ -> do
      nativeRootQName binding @?= expectedRootQName
      nativeVersionText (nativeVersion binding) @?= "5.0.0"
    _ -> assertFailure "expected a successful native binding"

decodeBomTest :: Assertion
decodeBomTest =
  case decodeSource
         (sourceBytes
            (ByteString.pack [239, 187, 191] <> encode validEmptyModel)) of
    DecodePassed _ _ -> pure ()
    _ -> assertFailure "UTF-8 BOM must be accepted"

decodeInvalidUtf8Test :: Assertion
decodeInvalidUtf8Test =
  decodeCodes (sourceBytes (ByteString.pack [255, 128]))
    @?= ["o2i.amx.decode.encoding-invalid"]

decodeEncodingTest :: Assertion
decodeEncodingTest =
  decodeCodes
    (source
       "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>")
    @?= ["o2i.amx.decode.encoding-unsupported"]

decodeEncodingBomTest :: Assertion
decodeEncodingBomTest =
  decodeCodes (sourceBytes (ByteString.pack [255, 254, 60, 0]))
    @?= ["o2i.amx.decode.encoding-unsupported"]

decodeUnsafeTest :: Assertion
decodeUnsafeTest = do
  bytes <-
    ByteString.readFile (fixture "invalid/decode/unsafe-doctype.archimate")
  decodeCodes (sourceBytes bytes) @?= ["o2i.amx.decode.xml-unsafe"]

decodeExternalEntityTest :: Assertion
decodeExternalEntityTest =
  decodeCodes
    (source
       "<!DOCTYPE model SYSTEM \"https://invalid.example/model.dtd\"><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>")
    @?= ["o2i.amx.decode.xml-unsafe"]

decodeEntityTest :: Assertion
decodeEntityTest =
  decodeCodes
    (source
       "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">&external;</a:model>")
    @?= ["o2i.amx.decode.xml-unsafe"]

decodeCommentTest :: Assertion
decodeCommentTest =
  case decodeSource (source (model "<!-- <!DOCTYPE harmless> -->" [])) of
    DecodePassed _ _ -> pure ()
    _ -> assertFailure "comment content is not a DTD declaration"

decodeMalformedTest :: Assertion
decodeMalformedTest = do
  bytes <- ByteString.readFile (fixture "invalid/decode/malformed.archimate")
  decodeCodes (sourceBytes bytes) @?= ["o2i.amx.decode.xml-malformed"]

decodeRootTest :: Assertion
decodeRootTest =
  decodeCodes (source "<model xmlns=\"urn:not-archi\" version=\"5.0.0\"/>")
    @?= ["o2i.amx.decode.root-qname"]

decodeMissingVersionTest :: Assertion
decodeMissingVersionTest =
  decodeCodes
    (source "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\"/>")
    @?= ["o2i.amx.decode.native-version-missing"]

decodeVersionTest :: Assertion
decodeVersionTest =
  decodeCodes
    (source
       "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"4.0.0\"/>")
    @?= ["o2i.amx.decode.native-version-unsupported"]

byteLimitTest :: Assertion
byteLimitTest = do
  let bytes = encode validEmptyModel
      exact = resourceLimits {maximumInputBytes = ByteString.length bytes}
      exceeded = exact {maximumInputBytes = ByteString.length bytes - 1}
  assertDecodePass exact validEmptyModel
  decodeCodesWith exceeded (sourceBytes bytes)
    @?= ["o2i.amx.decode.resource.input-bytes"]

depthLimitTest :: Assertion
depthLimitTest = do
  let document = nativeModel "<a:first><a:second/></a:first>"
      exact = resourceLimits {maximumXmlDepth = 3}
      exceeded = exact {maximumXmlDepth = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-depth"]

elementLimitTest :: Assertion
elementLimitTest = do
  let document = nativeModel "<a:first/><a:second/>"
      exact = resourceLimits {maximumXmlElements = 3}
      exceeded = exact {maximumXmlElements = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-elements"]

attributeLimitTest :: Assertion
attributeLimitTest = do
  let document =
        "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" "
          <> "xmlns:b=\"urn:test\" version=\"5.0.0\"/>"
      exact = resourceLimits {maximumXmlAttributes = 3}
      exceeded = exact {maximumXmlAttributes = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-attributes"]

textLimitTest :: Assertion
textLimitTest = do
  let document = nativeModel "abc"
      exact = resourceLimits {maximumXmlTextCharacters = 3}
      exceeded = exact {maximumXmlTextCharacters = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-text"]

cdataLimitTest :: Assertion
cdataLimitTest = do
  let document = nativeModel "<![CDATA[abc]]>"
      exact = resourceLimits {maximumXmlTextCharacters = 3}
      exceeded = exact {maximumXmlTextCharacters = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-text"]

entityCountingTest :: Assertion
entityCountingTest = do
  let document = nativeModel "&amp;&#65;&#x41;"
      exact = resourceLimits {maximumXmlTextCharacters = 3}
      exceeded = exact {maximumXmlTextCharacters = 2}
  assertDecodePass exact document
  decodeCodesWith exceeded (source document)
    @?= ["o2i.amx.decode.resource.xml-text"]

repeatedAmpersandTest :: Assertion
repeatedAmpersandTest =
  decodeCodesWith
    resourceLimits
    (source (nativeModel (Text.replicate 50000 "&amp;" <> "&")))
    @?= ["o2i.amx.decode.xml-unsafe"]

malformedLexicalTest :: Assertion
malformedLexicalTest = mapM_ assertMalformed malformedDocuments
  where
    assertMalformed document =
      decodeCodesWith resourceLimits (source document)
        @?= ["o2i.amx.decode.xml-malformed"]
    malformedDocuments =
      [ nativeModel "<!-- unterminated"
      , nativeModel "<![CDATA[unterminated"
      , nativeModel "<?unterminated"
      , "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" "
          <> "version=\"5.0.0\"><a:item value=\"unterminated</a:model>"
      ]

resourceStageTest :: Assertion
resourceStageTest =
  case inspectSourceDocument adapter (ViewByName "unused") noInputs document of
    InspectionCompleted report ->
      case diagnosticsList (reportDiagnostics report) of
        [diagnostic] -> do
          diagnosticStage diagnostic @?= DecodeStage
          diagnosticSeverity diagnostic @?= ErrorSeverity
          diagnosticDisposition diagnostic @?= ProcessFailure
        _ -> assertFailure "expected one Decode resource diagnostic"
    InspectionCommandFailed commandError ->
      assertFailure ("unexpected command error: " <> show commandError)
  where
    bytes = encode validEmptyModel
    document = sourceBytes bytes
    limits = resourceLimits {maximumInputBytes = ByteString.length bytes - 1}
    adapter =
      Adapter
        (adapterDescriptor
           ('a' NonEmpty.:| "mx")
           ('A' NonEmpty.:| "MX")
           ('t' NonEmpty.:| "est"))
        (decodeAMXWithLimits limits)
        amxDecodeDefectSpec
        resolveAMXView
        amxViewDefectSpec
        amxProfileContract
        observeAMXProfile

resourceLimits :: DecodeLimits
resourceLimits =
  DecodeLimits
    { maximumInputBytes = 1000000
    , maximumXmlDepth = 100
    , maximumXmlElements = 100
    , maximumXmlAttributes = 100
    , maximumXmlTextCharacters = 1000000
    }

nativeModel :: Text -> Text
nativeModel content =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" "
    <> "version=\"5.0.0\">"
    <> content
    <> "</a:model>"

assertDecodePass :: DecodeLimits -> Text -> Assertion
assertDecodePass limits document =
  case decodeAMXWithLimits limits (source document) of
    DecodePassed _ _ -> pure ()
    _ -> assertFailure "expected a successful boundary decode"

decodeCodesWith :: DecodeLimits -> SourceDocument -> [Text]
decodeCodesWith limits document =
  case decodeAMXWithLimits limits document of
    DecodeUnavailable _ defects -> codes defects
    DecodeRejected _ defects -> codes defects
    DecodePassed _ _ -> []
  where
    codes =
      map (diagnosticCodeText . specCode . amxDecodeDefectSpec . locatedValue)
        . NonEmpty.toList
