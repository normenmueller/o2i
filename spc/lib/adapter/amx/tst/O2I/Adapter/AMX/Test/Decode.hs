{-# LANGUAGE OverloadedStrings #-}

-- | Decode trust-boundary tests.
module O2I.Adapter.AMX.Test.Decode
  ( decodeTests
  ) where

import qualified Data.ByteString as ByteString
import O2I.Adapter.AMX.Internal.XML
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
