{-# LANGUAGE OverloadedStrings #-}

module O2I.Adapter.AMX.Test.XML
  ( xmlTests
  ) where

import qualified Data.ByteString as ByteString
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Internal.XML.DTD (skipDoctypeDeclaration)
import O2I.Adapter.AMX.Internal.XML.Scan
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

xmlTests :: TestTree
xmlTests =
  testGroup
    "native XML"
    [ testCase "accepts UTF-8 with an optional BOM" bomTest
    , testCase "rejects unsupported encodings" encodingTest
    , testCase "rejects malformed UTF-8 and forbidden scalars" scalarTest
    , testCase "rejects malformed XML 1.0 lexical forms" lexicalTest
    , testCase "accepts legal XML 1.0 comments and instructions" lexicalPassTest
    , testCase "recognizes the supported DTD grammar exactly" dtdGrammarTest
    , testCase "rejects DTDs before parser expansion" dtdTest
    , testCase "rejects unsupported entity facilities" entityTest
    , testCase "requires XML separators before attributes" separatorTest
    , testCase "enforces namespace well-formedness" namespaceTest
    , testCase "tracks nested namespace scopes" namespaceScopeTest
    , testCase
        "normalizes namespace end-of-line sequences exactly once"
        namespaceEndOfLineTest
    , testCase
        "preserves expanded attributes through XML normalization"
        attributeNormalizationTest
    , testCase
        "accepts XML whitespace before tag terminators"
        terminatorSpaceTest
    , testCase "enforces exact resource boundaries" limitsTest
    , testCase "projects flat documents within the element limit" flatTest
    , testCase "uses expanded names and equal-name ordinals" pathTest
    , testCase "requires one exact native root version" versionTest
    ]

bomTest :: Assertion
bomTest =
  case decodeNative (ByteString.pack [239, 187, 191] <> validModel) of
    Right (NativeFormatMatch _) -> pure ()
    result -> assertFailure ("unexpected BOM result: " <> show result)

encodingTest :: Assertion
encodingTest = do
  decodeNative (ByteString.pack [255, 254, 0, 0])
    @?= Left (UnsupportedEncoding "UTF-32LE")
  decodeNative
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    @?= Left (UnsupportedEncoding "ISO-8859-1")
  decodeNative
    "<?xml version=\"1.0\"encoding=\"ISO-8859-1\"?><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    @?= Left MalformedXml

scalarTest :: Assertion
scalarTest = do
  decodeNative (ByteString.pack [0xC3, 0x28]) @?= Left InvalidUtf8
  decodeNative
    "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">&#0;</a:model>"
    @?= Left (ForbiddenXmlScalar 0)

lexicalTest :: Assertion
lexicalTest =
  mapM_
    (\input -> decodeNative input @?= Left MalformedXml)
    [ nativeWith "<!--a--b-->"
    , nativeWith "<?XML foo?>"
    , nativeWith "<1/>"
    , "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">]]></a:model>"
    ]
  where
    nativeWith content =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">"
        <> content
        <> "</a:model>"

lexicalPassTest :: Assertion
lexicalPassTest =
  mapM_
    (\input ->
       case decodeNative input of
         Right (NativeFormatMatch _) -> pure ()
         result -> assertFailure ("unexpected lexical result: " <> show result))
    [nativeWith "<!--legal comment-->", nativeWith "<?probe data?>"]
  where
    nativeWith content =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">"
        <> content
        <> "</a:model>"

dtdTest :: Assertion
dtdTest =
  decodeNative
    "<!DOCTYPE model><a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"
    @?= Left UnsupportedXmlFacility

dtdGrammarTest :: Assertion
dtdGrammarTest = do
  mapM_
    (\declaration ->
       skipDoctypeDeclaration (declaration <> suffix) @?= Just suffix)
    [ " model>"
    , " model SYSTEM 'model.dtd'>"
    , " model PUBLIC '-//O2I//DTD Model//EN' 'model.dtd'>"
    , " model [<!ELEMENT model EMPTY>]>"
    , " model [<!ELEMENT model ANY>]>"
    , " model [<!ELEMENT model (#PCDATA)>]>"
    , " model [<!ELEMENT model (#PCDATA|item)*>]>"
    , " model [<!ELEMENT model (item,(left|right)*)>]>"
    , " model [<!ATTLIST model id ID #REQUIRED note CDATA #IMPLIED>] >"
    , " model [<!ATTLIST model mode (one|two) 'one'>]>"
    , " model [<!ATTLIST model kind NOTATION (one|two) #IMPLIED>]>"
    , " model [<!ENTITY value 'text &amp;'>]>"
    , " model [<!ENTITY value SYSTEM 'value.ent'>]>"
    , " model [<!ENTITY image SYSTEM 'image.bin' NDATA png>]>"
    , " model [<!ENTITY % value 'text'>%value;]>"
    , " model [<!NOTATION png SYSTEM 'image/png'>]>"
    , " model [<!NOTATION png PUBLIC 'image/png'>]>"
    , " model [<!-- legal --><?probe data?>]>"
    ]
  mapM_
    (\declaration -> skipDoctypeDeclaration (declaration <> suffix) @?= Nothing)
    [ "model>"
    , " ???>"
    , " model [garbage]>"
    , " model [<!UNKNOWN value>]>"
    , " model [<!ELEMENT model (left|right,third)>]>"
    , " model [<!ELEMENT model (#PCDATA|item)>]>"
    , " model [<!ATTLIST model id UNKNOWN #IMPLIED>]>"
    , " model [<!ENTITY %value 'text'>]>"
    , " model [<![IGNORE[anything]]>] >"
    , " model [<!-- broken -- comment -->]>"
    , " model [<?xml data?>]>"
    , " model [<!ENTITY value '&missing'>]>"
    ]
  where
    suffix = "<model/>"

entityTest :: Assertion
entityTest =
  decodeNative
    "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">&custom;</a:model>"
    @?= Left UnsupportedXmlFacility

separatorTest :: Assertion
separatorTest = do
  decodeNative
    "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\"version=\"5.0.0\"/>"
    @?= Left MalformedXml
  decodeNative
    "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"><item note=\"x\"other=\"y\"/></a:model>"
    @?= Left MalformedXml

namespaceTest :: Assertion
namespaceTest =
  mapM_
    (\input -> decodeNative input @?= Left MalformedXml)
    [ nativeWith
        "xmlns:x=\"urn:same\" xmlns:y=\"urn:same\" x:value=\"one\" y:value=\"two\""
    , nativeWith "x:value=\"unbound\""
    , nativeWith "xmlns:xmlns=\"urn:forbidden\""
    , nativeWith "xmlns:xml=\"urn:wrong\""
    ]
  where
    nativeWith attributes =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" "
        <> attributes
        <> "/>"

namespaceScopeTest :: Assertion
namespaceScopeTest = do
  mapM_
    (\input -> decodeNative input @?= Left MalformedXml)
    [ nativeWith "<child x:value=\"unbound\"/>"
    , nativeWith
        "<child xmlns:x=\"urn:same\" xmlns:y=\"urn:same\" x:value=\"one\" y:value=\"two\"/>"
    , nativeWith "<x:child xmlns:x=\"urn:one\"></y:child>"
    ]
  case decodeNative validRebinding of
    Right (NativeFormatMatch _) -> pure ()
    result ->
      assertFailure ("valid namespace rebinding failed: " <> show result)
  where
    nativeWith content =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">"
        <> content
        <> "</a:model>"
    validRebinding =
      nativeWith
        "<x:child xmlns:x=\"urn:one\"><x:item xmlns:x=\"urn:two\"/></x:child>"

namespaceEndOfLineTest :: Assertion
namespaceEndOfLineTest = do
  decodeNative (rootWith duplicateAliases) @?= Left MalformedXml
  decodeNative (nestedWith duplicateAliases) @?= Left MalformedXml
  mapM_
    assertNativeMatch
    [ rootWith distinctAliases
    , nestedWith distinctAliases
    , rootWith referenceDistinctAliases
    ]
  where
    duplicateAliases =
      "x:value=\"one\" y:value=\"two\" xmlns:x=\"urn:\r\nsame\" xmlns:y=\"urn:\nsame\""
    distinctAliases =
      "x:value=\"one\" y:value=\"two\" xmlns:x=\"urn:\r\nsame\" xmlns:y=\"urn:  same\""
    referenceDistinctAliases =
      "x:value=\"one\" y:value=\"two\" xmlns:x=\"urn:&#10;same\" xmlns:y=\"urn:\nsame\""
    rootWith attributes =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" "
        <> attributes
        <> "/>"
    nestedWith attributes =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" xmlns:x=\"urn:outer\"><child "
        <> attributes
        <> "/></a:model>"
    assertNativeMatch input =
      case decodeNative input of
        Right (NativeFormatMatch _) -> pure ()
        result ->
          assertFailure ("valid EOL normalization failed: " <> show result)

attributeNormalizationTest :: Assertion
attributeNormalizationTest =
  case decodeNative source of
    Right (NativeFormatMatch (NativeDocument root)) -> do
      nativeElementNamespaces root
        @?= Map.fromList
              [("a", archiNamespace), ("x", "urn:\nsame"), ("y", "urn: same")]
      attributeValue (NativeName (Just "urn:\nsame") "value") root @?= ["one"]
      attributeValue (NativeName (Just "urn: same") "value") root @?= ["two"]
      attributeValue (NativeName Nothing "raw") root @?= ["a b c d"]
      attributeValue (NativeName Nothing "referenced") root @?= ["a\tb\nc\rd"]
    result ->
      assertFailure ("normalized attributes did not decode: " <> show result)
  where
    source =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" xmlns:x=\"urn:&#10;same\" xmlns:y=\"urn:\nsame\" x:value=\"one\" y:value=\"two\" raw=\"a\tb\nc\r\nd\" referenced=\"a&#9;b&#10;c&#13;d\"/>"
    attributeValue name = map nativeAttributeValue . lookupAttribute name

terminatorSpaceTest :: Assertion
terminatorSpaceTest =
  mapM_
    (\input ->
       case decodeNative input of
         Right (NativeFormatMatch _) -> pure ()
         result ->
           assertFailure ("unexpected terminator result: " <> show result))
    [ "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" />"
    , "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" ><item /></a:model>"
    ]

limitsTest :: Assertion
limitsTest = do
  let exact = DecodeLimits 512 2 2 4 0
      shallow =
        "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"><x/></a:model>"
  case decodeNativeWithLimits exact shallow of
    Right (NativeFormatMatch _) -> pure ()
    result -> assertFailure ("exact boundary failed: " <> show result)
  decodeNativeWithLimits exact {maximumXmlDepth = 1} shallow
    @?= Left (XmlDepthLimitExceeded 1 2)
  decodeNativeWithLimits exact {maximumInputBytes = 1} shallow
    @?= Left (InputLimitExceeded 1 (ByteString.length shallow))
  decodeNativeWithLimits exact {maximumXmlElements = 1} shallow
    @?= Left (XmlElementLimitExceeded 1 2)
  decodeNativeWithLimits exact {maximumXmlAttributes = 1} shallow
    @?= Left (XmlAttributeLimitExceeded 1 2)
  decodeNativeWithLimits exact {maximumXmlTextCharacters = 0} textModel
    @?= Left (XmlTextLimitExceeded 0 1)

flatTest :: Assertion
flatTest =
  case decodeNativeWithLimits limits source of
    Right (NativeFormatMatch (NativeDocument root)) ->
      length (childElements root) @?= childCount
    result -> assertFailure ("flat document did not decode: " <> show result)
  where
    childCount = 100000
    source =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">"
        <> ByteString.concat (replicate childCount "<item/>")
        <> "</a:model>"
    limits =
      DecodeLimits
        { maximumInputBytes = ByteString.length source
        , maximumXmlDepth = 2
        , maximumXmlElements = childCount + 1
        , maximumXmlAttributes = 2
        , maximumXmlTextCharacters = 0
        }

pathTest :: Assertion
pathTest =
  case decodeNative bytes of
    Right (NativeFormatMatch (NativeDocument root)) -> do
      nativeElementNamespaces root @?= expectedNamespaces
      map nativeElementPath (childElements root)
        @?= [ [NativePathStep expectedRootName 1, NativePathStep childName 1]
            , [NativePathStep expectedRootName 1, NativePathStep childName 2]
            ]
    result -> assertFailure ("path fixture did not decode: " <> show result)
  where
    bytes =
      "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:x=\"urn:x\" version=\"5.0.0\"><x:item/><x:item/></a:model>"
    childName = NativeName (Just "urn:x") "item"
    expectedNamespaces :: Map Text Text
    expectedNamespaces = Map.fromList [("a", archiNamespace), ("x", "urn:x")]

versionTest :: Assertion
versionTest = do
  classify missingVersion @?= "no-match"
  classify duplicateVersion @?= "native-failure"
  classify namespacedVersion @?= "no-match"
  classify wrongVersion @?= "no-match"
  where
    classify :: ByteString.ByteString -> Text
    classify source =
      case decodeNative source of
        Left _ -> "native-failure"
        Right (NativeFormatMatch _) -> "match"
        Right (NativeFormatMismatch _ _) -> "no-match"

validModel :: ByteString.ByteString
validModel =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\"/>"

textModel :: ByteString.ByteString
textModel =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\">x</a:model>"

missingVersion, duplicateVersion, namespacedVersion, wrongVersion ::
     ByteString.ByteString
missingVersion = "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\"/>"

duplicateVersion =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" version=\"5.0.0\"/>"

namespacedVersion =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" a:version=\"5.0.0\"/>"

wrongVersion =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"4.9.0\"/>"
