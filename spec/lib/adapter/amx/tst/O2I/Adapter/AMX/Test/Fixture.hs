{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module O2I.Adapter.AMX.Test.Fixture
  ( fixtureBytes
  , fixtureTests
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import Data.Aeson (FromJSON, eitherDecodeStrict')
import qualified Data.ByteString as ByteString
import Data.List (find, nub, sort)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import GHC.Generics (Generic)
import Numeric (showHex)
import O2I.Adapter.AMX.Internal.Draft (projectNativeDocument)
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (decodeNative)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import Paths_o2i_amx (getDataFileName)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>), takeExtension)
import Test.Tasty (TestTree)
import Test.Tasty.HUnit

fixtureTests :: TestTree
fixtureTests =
  testCase
    "binds every native fixture and expected classification"
    fixtureManifestTest

data FixtureManifest = FixtureManifest
  { schema :: !Text
  , nativeContract :: !Text
  , adapterId :: !Text
  , producerOracle :: !ProducerOracle
  , valid :: ![Fixture]
  , invalid :: ![Fixture]
  } deriving (Generic, Show)

instance FromJSON FixtureManifest

data ProducerOracle = ProducerOracle
  { name :: !Text
  , version :: !Text
  , nativeVersion :: !Text
  } deriving (Generic, Show)

instance FromJSON ProducerOracle

data Fixture = Fixture
  { fixtureId :: !Text
  , path :: !FilePath
  , origin :: !Text
  , sha256 :: !Text
  , expected :: !Text
  , draftSha256 :: !(Maybe Text)
  } deriving (Generic, Show)

instance FromJSON Fixture

fixtureManifestTest :: Assertion
fixtureManifestTest = do
  manifest <- loadManifest
  schema manifest @?= "o2i.amx.fixtures/v2"
  nativeContract manifest @?= "amx-native-xml/5.0.0-v1"
  adapterId manifest @?= "amx"
  let oracle = producerOracle manifest
  (name oracle, version oracle, nativeVersion oracle)
    @?= ("Archi", "5.9.0", "5.0.0")
  let fixtures = valid manifest <> invalid manifest
      identifiers = map fixtureId fixtures
  sort identifiers @?= sort (nub identifiers)
  fixturePaths <- discoverFixtures "tst/data"
  sort (map path fixtures) @?= fixturePaths
  mapM_ verifyFixture fixtures

fixtureBytes :: Text -> IO ByteString.ByteString
fixtureBytes identifier = do
  manifest <- loadManifest
  case find ((== identifier) . fixtureId) (valid manifest <> invalid manifest) of
    Nothing ->
      assertFailure ("unknown manifest fixture: " <> Text.unpack identifier)
        >> fail "unreachable"
    Just fixture -> readFixtureBytes fixture

loadManifest :: IO FixtureManifest
loadManifest = do
  manifestBytes <- readDataFile "tst/data/manifest.json"
  either
    (\failure -> assertFailure failure >> fail "unreachable")
    pure
    (eitherDecodeStrict' manifestBytes)

verifyFixture :: Fixture -> Assertion
verifyFixture fixture = do
  bytes <- readFixtureBytes fixture
  assertBool "fixture ID must be explicit" (not (Text.null (fixtureId fixture)))
  assertBool
    "fixture origin must be explicit"
    (not (Text.null (origin fixture)))
  case (decodeNative bytes, expected fixture, draftSha256 fixture) of
    (Right (NativeFormatMatch document), "match", Just expectedDraftDigest) ->
      draftDigest (projectNativeDocument document) @?= expectedDraftDigest
    (Right (NativeFormatMismatch mismatch _), expectedMismatch, Nothing)
      | expectedMismatch == mismatchName mismatch -> pure ()
    (Left failure, expectedFailure, Nothing)
      | expectedFailure == failureName failure -> pure ()
    (outcome, expectedClassification, expectedDraftDigest) ->
      assertFailure
        ("fixture contract mismatch: expected "
           <> Text.unpack expectedClassification
           <> " with Draft digest "
           <> show expectedDraftDigest
           <> ", received "
           <> classification outcome)

readFixtureBytes :: Fixture -> IO ByteString.ByteString
readFixtureBytes fixture = do
  bytes <- readDataFile (path fixture)
  digest bytes @?= sha256 fixture
  pure bytes

failureName :: NativeFailure -> Text
failureName failure =
  case failure of
    InputLimitExceeded _ _ -> "input-limit-exceeded"
    XmlDepthLimitExceeded _ _ -> "xml-depth-limit-exceeded"
    XmlElementLimitExceeded _ _ -> "xml-element-limit-exceeded"
    XmlAttributeLimitExceeded _ _ -> "xml-attribute-limit-exceeded"
    XmlTextLimitExceeded _ _ -> "xml-text-limit-exceeded"
    InvalidUtf8 -> "invalid-utf8"
    UnsupportedEncoding _ -> "unsupported-encoding"
    UnsupportedXmlFacility -> "unsupported-xml-facility"
    ForbiddenXmlScalar _ -> "forbidden-xml-scalar"
    MalformedXml -> "malformed-xml"

mismatchName :: NativeMismatch -> Text
mismatchName mismatch =
  case mismatch of
    NativeRootMismatch nativeName ->
      "root-qname-mismatch:"
        <> maybe
             ""
             (\namespace -> "{" <> namespace <> "}")
             (nativeNameNamespace nativeName)
        <> nativeNameLocal nativeName
    NativeVersionMissing -> "native-version-missing"
    NativeVersionUnsupported value -> "native-version-unsupported:" <> value

readDataFile :: FilePath -> IO ByteString.ByteString
readDataFile relative = getDataFileName relative >>= ByteString.readFile

digest :: ByteString.ByteString -> Text
digest = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
  where
    byteHex byte =
      case showHex byte "" of
        [digit] -> ['0', digit]
        digits -> digits

classification :: Either failure NativeClassification -> String
classification outcome =
  case outcome of
    Left _ -> "native-failure"
    Right (NativeFormatMatch _) -> "match"
    Right (NativeFormatMismatch mismatch _) ->
      Text.unpack (mismatchName mismatch)

discoverFixtures :: FilePath -> IO [FilePath]
discoverFixtures root = sort <$> visit root
  where
    visit relative = do
      absolute <- getDataFileName relative
      entries <- sort <$> listDirectory absolute
      concat <$> mapM (entry relative) entries
    entry parent entryName = do
      let relative = parent </> entryName
      absolute <- getDataFileName relative
      directory <- doesDirectoryExist absolute
      if directory
        then visit relative
        else pure [relative | takeExtension relative == ".archimate"]

draftDigest :: Draft.ProfileDraft -> Text
draftDigest = digest . Text.encodeUtf8 . renderSnapshot . profileSnapshot

data Snapshot
  = Atom !Text
  | Sequence ![Snapshot]

renderSnapshot :: Snapshot -> Text
renderSnapshot snapshot =
  case snapshot of
    Atom value -> "a" <> decimal (Text.length value) <> ":" <> value
    Sequence values ->
      "s" <> decimal (length values) <> ":" <> foldMap renderSnapshot values

profileSnapshot :: Draft.ProfileDraft -> Snapshot
profileSnapshot profile =
  Sequence
    [Atom "profile-draft-v1", recordSnapshot (Draft.profileDraftRoot profile)]

recordSnapshot :: Draft.DraftRecord recordRole -> Snapshot
recordSnapshot record =
  Sequence
    [ Atom "record"
    , Atom (recordFamilyName (Draft.draftRecordFamily record))
    , identitySnapshot (Draft.draftRecordIdentity record)
    , locationSnapshot (Draft.draftRecordLocation record)
    , Sequence (map memberSnapshot (Draft.draftRecordMembers record))
    ]

identitySnapshot :: Draft.DraftIdentity recordRole -> Snapshot
identitySnapshot = Draft.foldDraftIdentity (Sequence . map scalarSnapshot)

memberSnapshot :: Draft.DraftMember recordRole -> Snapshot
memberSnapshot =
  Draft.foldDraftMember
    fieldSnapshot
    propertySnapshot
    referenceSnapshot
    recordSnapshot
    opaqueSnapshot

fieldSnapshot ::
     Draft.DraftFieldValue
  -> [Draft.DraftScalar]
  -> Draft.DraftLocation
  -> Snapshot
fieldSnapshot field values location =
  Sequence
    [ Atom "field"
    , Atom (fieldName field)
    , Sequence (map scalarSnapshot values)
    , locationSnapshot location
    ]

propertySnapshot :: Draft.DraftProperty recordRole -> Snapshot
propertySnapshot property =
  Sequence
    [ Atom "property"
    , propertyKeySnapshot (Draft.draftPropertyKey property)
    , Sequence (map scalarSnapshot (Draft.draftPropertyValues property))
    , locationSnapshot (Draft.draftPropertyLocation property)
    , Sequence (map opaqueSnapshot (Draft.draftPropertyOpaqueEvidence property))
    ]

propertyKeySnapshot :: Draft.DraftPropertyKey recordRole -> Snapshot
propertyKeySnapshot =
  Draft.foldDraftPropertyKey
    (\values -> Sequence [Atom "direct", Sequence (map scalarSnapshot values)])
    (\reference -> Sequence [Atom "definition", referenceSnapshot reference])

referenceSnapshot :: Draft.DraftReference ownerRole targetRole -> Snapshot
referenceSnapshot reference =
  Sequence
    [ Atom "reference"
    , Atom (referenceFieldName (Draft.draftReferenceField reference))
    , Atom (recordFamilyName (Draft.draftReferenceExpectedFamily reference))
    , identitySnapshot (Draft.draftReferenceIdentity reference)
    , locationSnapshot (Draft.draftReferenceLocation reference)
    ]

opaqueSnapshot :: Draft.DraftOpaqueEvidence -> Snapshot
opaqueSnapshot evidence =
  Sequence
    [ Atom "opaque"
    , Atom
        (Draft.foldDraftOpaquePosition
           "attribute"
           "child"
           (Draft.draftOpaquePosition evidence))
    , nativeNameSnapshot (Draft.draftOpaqueName evidence)
    , Sequence (map scalarSnapshot (Draft.draftOpaqueScalars evidence))
    , locationSnapshot (Draft.draftOpaqueLocation evidence)
    ]

scalarSnapshot :: Draft.DraftScalar -> Snapshot
scalarSnapshot scalar =
  Sequence
    [ Draft.foldDraftScalarValue
        (\value -> Sequence [Atom "text", Atom value])
        (\value -> Sequence [Atom "boolean", Atom (boolean value)])
        (\value -> Sequence [Atom "number", Atom value])
        (\value -> Sequence [Atom "native-name", nativeNameSnapshot value])
        (\kind value -> Sequence [Atom "other", Atom kind, Atom value])
        scalar
    , locationSnapshot (Draft.draftScalarLocation scalar)
    ]

nativeNameSnapshot :: Draft.DraftNativeName -> Snapshot
nativeNameSnapshot nativeName =
  Sequence
    [ maybe
        (Sequence [])
        (Sequence . pure . Atom)
        (Draft.draftNativeNamespace nativeName)
    , Atom (Draft.draftNativeLocalName nativeName)
    ]

locationSnapshot :: Draft.DraftLocation -> Snapshot
locationSnapshot location =
  Sequence
    [ sourcePathSnapshot (Draft.draftLocationPath location)
    , maybe (Sequence []) sourceSpanSnapshot (Draft.draftLocationSpan location)
    ]

sourcePathSnapshot :: Draft.DraftSourcePath -> Snapshot
sourcePathSnapshot =
  Draft.foldDraftSourcePath
    (\first rest -> Sequence (map pathStepSnapshot (first : rest)))

pathStepSnapshot :: Draft.DraftPathStep -> Snapshot
pathStepSnapshot step =
  Sequence
    [ nativeNameSnapshot (Draft.draftPathStepName step)
    , Atom (decimal (Draft.draftPathStepOrdinal step))
    ]

sourceSpanSnapshot :: Draft.DraftSourceSpan -> Snapshot
sourceSpanSnapshot spanValue =
  Sequence
    [ sourcePositionSnapshot (Draft.draftSpanStart spanValue)
    , sourcePositionSnapshot (Draft.draftSpanEnd spanValue)
    ]

sourcePositionSnapshot :: Draft.DraftSourcePosition -> Snapshot
sourcePositionSnapshot position =
  Sequence
    [ Atom (decimal (Draft.draftSourceLine position))
    , Atom (decimal (Draft.draftSourceColumn position))
    , maybe
        (Sequence [])
        (Sequence . pure . Atom . decimal)
        (Draft.draftSourceOffset position)
    ]

recordFamilyName :: Draft.DraftRecordFamilyValue -> Text
recordFamilyName =
  Draft.foldDraftRecordFamilyValue
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

fieldName :: Draft.DraftFieldValue -> Text
fieldName =
  Draft.foldDraftFieldValue
    "type"
    "name"
    "documentation"
    "directed"
    "influence-strength"

referenceFieldName :: Draft.DraftReferenceFieldValue -> Text
referenceFieldName =
  Draft.foldDraftReferenceFieldValue
    "property-definition"
    "relationship-source"
    "relationship-target"
    "view-node-element"
    "view-connection-relationship"
    "view-connection-source"
    "view-connection-target"

boolean :: Bool -> Text
boolean value =
  if value
    then "true"
    else "false"

decimal :: Show value => value -> Text
decimal = Text.pack . show
