{-# LANGUAGE OverloadedStrings #-}

-- | Fixture ownership, reference contracts, license, and repository integration.
module O2I.Adapter.AMX.Test.Fixture
  ( fixtureTests
  ) where

import qualified Data.Aeson as Aeson
import Data.Aeson ((.:), (.:?))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import System.Directory (doesFileExist)
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

fixtureTests :: TestTree
fixtureTests =
  testGroup
    "fixtures and integration"
    [ testCase
        "repository O2I Syntax - Primitives is structurally inspectable"
        integrationTest
    , testCase
        "invalid fixtures retain declared stage ownership"
        fixtureContractTest
    , testCase "fixture manifest is valid JSON" manifestTest
    , testCase
        "valid references have truthful admission state"
        validReferenceContractTest
    , testCase
        "the Archi-saved minimal reference is decode-only"
        nativeReferenceTest
    , testCase
        "the Archi-saved Ethos reference projects and passes Semantics"
        ethosReferenceTest
    , testCase "package license equals canonical license" licenseTest
    ]

integrationTest :: Assertion
integrationTest = do
  bytes <-
    ByteString.readFile
      (".." </> ".." </> ".." </> ".." </> "mdl" </> "o2i.archimate")
  report <- inspectBytes (ViewByName "O2I Syntax - Primitives") bytes
  take 5 (map reportedState (stageReportsList (reportStageReports report)))
    @?= [StagePassed, StagePassed, StagePassed, StagePassed, StageUnavailable]
  reportResult report @?= InspectionPartial
  reportExitCode report @?= 3

fixtureContractTest :: Assertion
fixtureContractTest = do
  mapM_ assertDecodeFixture decodeFixtures
  mapM_ assertInspectionFixture inspectionFixtures
  where
    assertDecodeFixture (path, expected) = do
      bytes <- ByteString.readFile (fixture path)
      assertBool path (expected `elem` decodeCodes (sourceBytes bytes))
    assertInspectionFixture (path, selector, expected) = do
      bytes <- ByteString.readFile (fixture path)
      report <- inspectBytes selector bytes
      assertBool path (expected `elem` diagnosticCodes report)
    decodeFixtures =
      [ ("invalid/decode/empty.archimate", "o2i.amx.decode.xml-malformed")
      , ("invalid/decode/malformed.archimate", "o2i.amx.decode.xml-malformed")
      , ("invalid/decode/unsafe-doctype.archimate", "o2i.amx.decode.xml-unsafe")
      , ("invalid/decode/wrong-root.archimate", "o2i.amx.decode.root-qname")
      , ( "invalid/decode/missing-native-version.archimate"
        , "o2i.amx.decode.native-version-missing")
      , ( "invalid/decode/unsupported-native-version.archimate"
        , "o2i.amx.decode.native-version-unsupported")
      ]
    inspectionFixtures =
      [ ( "invalid/view/duplicate-view-name.archimate"
        , ViewByName "Scope"
        , "o2i.amx.view.name-ambiguous")
      , ( "invalid/view/duplicate-view-id.archimate"
        , ViewById "view"
        , "o2i.amx.view.id-ambiguous")
      , ( "invalid/view/unresolved-object.archimate"
        , ViewByName "Scope"
        , "o2i.amx.view.object-unresolved")
      , ( "invalid/view/empty-view.archimate"
        , ViewByName "Scope"
        , "o2i.inspection.scope.empty")
      , ( "invalid/profile/missing-profile.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.missing")
      , ( "invalid/profile/unsupported-profile.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.unsupported")
      , ( "invalid/profile/duplicate-profile.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.duplicate")
      , ( "invalid/profile/legacy-version-property.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.legacy-version-property")
      , ( "invalid/profile/missing-kind.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.kind-missing")
      , ( "invalid/profile/wrong-element-representation.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.element-representation")
      , ( "invalid/profile/missing-ownership.archimate"
        , ViewByName "Scope"
        , "o2i.amx.profile.ownership-missing")
      ]

manifestTest :: Assertion
manifestTest = do
  bytes <- LazyByteString.readFile (fixture "manifest.json")
  case Aeson.eitherDecode bytes :: Either String Aeson.Value of
    Left message -> assertFailure message
    Right _ -> pure ()

data ReferenceEntry = ReferenceEntry
  { referencePath :: FilePath
  , referenceClass :: Text
  , referenceStatus :: Text
  , referenceSha256 :: Maybe Text
  } deriving (Eq, Show)

instance Aeson.FromJSON ReferenceEntry where
  parseJSON =
    Aeson.withObject "valid reference" $ \value ->
      ReferenceEntry
        <$> value .: "path"
        <*> value .: "class"
        <*> value .: "status"
        <*> value .:? "sha256"

newtype ValidReferenceCatalog =
  ValidReferenceCatalog [ReferenceEntry]
  deriving (Eq, Show)

instance Aeson.FromJSON ValidReferenceCatalog where
  parseJSON =
    Aeson.withObject "valid reference catalog" $ \value ->
      ValidReferenceCatalog <$> value .: "references"

validReferenceContractTest :: Assertion
validReferenceContractTest = do
  bytes <- LazyByteString.readFile (fixture "valid/catalog.json")
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message
    Right (ValidReferenceCatalog entries) -> do
      map referencePath entries @?= expectedReferencePaths
      map referenceClass entries @?= "focused-adapter"
        : replicate 8 "semantic-reference"
      map referenceStatus entries @?= replicate 2 "admitted-archi-saved"
        ++ replicate 7 "pending-external-archi-save"
      map referenceSha256 entries
        @?= [Just nativeReferenceSha256, Just ethosReferenceSha256]
        ++ replicate 7 Nothing
      assertReferencePresence entries

assertReferencePresence :: [ReferenceEntry] -> Assertion
assertReferencePresence = mapM_ assertEntry
  where
    assertEntry entry = do
      present <- doesFileExist (fixture (referencePath entry))
      case referenceStatus entry of
        "admitted-archi-saved" ->
          assertBool "an admitted reference must exist" present
        "pending-external-archi-save" ->
          assertBool
            "a pending reference must carry no unverified integrity claim"
            (referenceSha256 entry == Nothing)
        status -> assertFailure ("unexpected reference status: " <> show status)

nativeReferenceSha256 :: Text
nativeReferenceSha256 =
  "359b5309a7c66ab3e090ec29f0c5ef135c361825ae0cc7797b5560ae80acff01"

ethosReferenceSha256 :: Text
ethosReferenceSha256 =
  "0d891904a1855ba37d40ce2ad9d88e4a5b1ff5cb04a71f10f045a512f23afee7"

nativeReferenceTest :: Assertion
nativeReferenceTest = do
  bytes <- ByteString.readFile (fixture "valid/native/minimal.archimate")
  let document =
        sourceDocumentFromBytes
          "valid/native/minimal.archimate"
          FileSource
          bytes
  sourceHashText (sourceSha256 (sourceDocumentIdentity document))
    @?= nativeReferenceSha256
  case decodeSource document of
    DecodePassed binding decoded -> do
      nativeRootQName binding @?= expectedRootQName
      nativeVersionText (nativeVersion binding) @?= "5.0.0"
      elementAttribute (expandedQName Nothing 'i' "d") (amxDocumentRoot decoded)
        @?= Just "id-38b61e2f53db4787b817eebd3632eb7f"
    DecodeRejected _ _ -> assertFailure "native reference was rejected"
    DecodeUnavailable _ _ -> assertFailure "native reference was unavailable"
  report <- inspectBytes (ViewByName "Default View") bytes
  viewResolutionId report @?= Just "id-e88788554b2449deb90b0f5676c4ce01"
  diagnosticCodes report @?= ["o2i.amx.profile.missing"]

ethosReferenceTest :: Assertion
ethosReferenceTest = do
  bytes <- ByteString.readFile (fixture "valid/orientation/ethos.archimate")
  let document = sourceBytes bytes
      selector = ViewByName "O2I Reference - Ethos"
  sourceHashText (sourceSha256 (sourceDocumentIdentity document))
    @?= ethosReferenceSha256
  report <- inspectBytes selector bytes
  requestSourceIdentity (reportRequestInfo report)
    @?= sourceDocumentIdentity document
  viewResolutionId report @?= Just "id-fad6c1265c8c4623ab29335326eb23f2"
  take 5 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 5 StagePassed
  diagnosticCodes report @?= ["o2i.traceability.intervention-missing"]

expectedReferencePaths :: [FilePath]
expectedReferencePaths =
  [ "valid/native/minimal.archimate"
  , "valid/orientation/ethos.archimate"
  , "valid/orientation/mission.archimate"
  , "valid/orientation/vision.archimate"
  , "valid/formation/strategy.archimate"
  , "valid/situation/need.archimate"
  , "valid/operationalization/intervention.archimate"
  , "valid/evidence/measure.archimate"
  , "valid/full/effect-trace.archimate"
  ]

licenseTest :: Assertion
licenseTest = do
  canonical <- ByteString.readFile (".." </> ".." </> ".." </> "LICENSE")
  local <- ByteString.readFile "LICENSE"
  local @?= canonical
