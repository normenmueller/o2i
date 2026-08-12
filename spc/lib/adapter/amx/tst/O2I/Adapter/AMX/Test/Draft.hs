{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Adapter.AMX.Test.Draft
  ( draftTests
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring (compileAdapterCollection)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

draftTests :: TestTree
draftTests =
  testGroup
    "Draft"
    [ testCase "projects only native AMX record families" familyTest
    , testCase
        "promotes children of transparent View groups once"
        transparentGroupTest
    , testCase
        "promotes typed descendants from every Group shell"
        groupShellTest
    , testCase
        "does not interpret extension lookalikes as native records"
        namespaceTest
    , testCase "retains recognized scalar kinds and references" scalarTest
    , testCase
        "retains unresolved xsi:type values as exact text"
        unresolvedTypeTest
    , testCase "ignores formatting whitespace as scalar content" whitespaceTest
    , testCase
        "normalizes prefix spelling and attribute order"
        canonicalizationTest
    , testCase
        "retains normalized expanded attributes in Draft"
        attributeNormalizationTest
    , testCase
        "retains exact documentation and opaque subtree content"
        contentRetentionTest
    , testCase
        "retains recognized-record and opaque mixed content in source order"
        mixedContentTest
    , testCase
        "concatenates fragmented documentation without changing content"
        fragmentedDocumentationTest
    , testCase "keeps unknown typed View children opaque" unknownViewTypeTest
    , testCase "retains one-based expanded-name source paths" pathProvenanceTest
    , testCase
        "retains duplicate and incomplete properties"
        propertyMultiplicityTest
    , testCase
        "recognizes strength only on native InfluenceRelationship"
        influenceStrengthTest
    ]

familyTest :: Assertion
familyTest = do
  draft <- decodedDraft fixture
  map recordFamily (recordInventory draft)
    @?= [ "model-root"
        , "element"
        , "relationship"
        , "view"
        , "view-node"
        , "view-connection"
        ]

transparentGroupTest :: Assertion
transparentGroupTest = do
  draft <- decodedDraft fixture
  let records = recordInventory draft
  length (filter ((== "view-node") . recordFamily) records) @?= 1
  opaqueNames records
    @?= [ "version"
        , "propertyDefinition"
        , "folder"
        , "folder"
        , "folder"
        , "child"
        , "bounds"
        ]

groupShellTest :: Assertion
groupShellTest = do
  draft <- decodedDraft malformedGroup
  let records = recordInventory draft
  length (filter ((== "view-node") . recordFamily) records) @?= 1
  opaqueNames records @?= ["version", "folder", "child"]

namespaceTest :: Assertion
namespaceTest = do
  draft <- decodedDraft extensionLookalike
  let records = recordInventory draft
  map recordFamily records @?= ["model-root"]
  opaqueNames records @?= ["version", "folder", "element"]

scalarTest :: Assertion
scalarTest = do
  draft <- decodedDraft fixture
  scalarKinds (recordInventory draft)
    @?= [ "text"
        , "native-name"
        , "text"
        , "text"
        , "native-name"
        , "text"
        , "boolean"
        , "text"
        , "native-name"
        , "text"
        , "native-name"
        , "native-name"
        ]
  referenceFields (recordInventory draft)
    @?= [ "source"
        , "target"
        , "node-element"
        , "connection"
        , "source-node"
        , "target-node"
        ]

unresolvedTypeTest :: Assertion
unresolvedTypeTest = do
  mapM_
    (\source -> do
       draft <- decodedDraft source
       scalarKinds (recordInventory draft) @?= ["text"])
    [unresolvedType, invalidType, invalidLeadingType]

whitespaceTest :: Assertion
whitespaceTest = do
  draft <- decodedDraft formattingOnly
  scalarKinds (recordInventory draft) @?= []
  significant <- decodedDraft significantWhitespace
  assertBool
    "non-XML whitespace was discarded"
    ("\xA0" `elem` opaqueScalarTexts (recordInventory significant))

canonicalizationTest :: Assertion
canonicalizationTest = do
  left <- decodedDraft canonicalA
  right <- decodedDraft canonicalB
  left @?= right

attributeNormalizationTest :: Assertion
attributeNormalizationTest = do
  draft <- decodedDraft normalizedAttributes
  let root = Draft.profileDraftRoot draft
      attributes =
        [ ( Draft.draftNativeNamespace (Draft.draftOpaqueName evidence)
          , Draft.draftNativeLocalName (Draft.draftOpaqueName evidence)
          , map Draft.draftScalarText (Draft.draftOpaqueScalars evidence))
        | OpaqueMember evidence <- recordMembers (observeRecord root)
        ]
  attributes
    @?= [ (Nothing, "version", ["5.0.0"])
        , (Just "urn:\nsame", "value", ["one"])
        , (Just "urn: same", "value", ["two"])
        ]

contentRetentionTest :: Assertion
contentRetentionTest = do
  draft <- decodedDraft retainedContent
  let records = recordInventory draft
      fields =
        [ (fieldName field, map Draft.draftScalarText values)
        | record <- records
        , FieldMember field values <- recordMembers record
        ]
      opaque =
        [ ( Draft.draftNativeLocalName (Draft.draftOpaqueName evidence)
          , [ ( kindName (Draft.draftScalarKind scalar)
              , Draft.draftScalarText scalar)
            | scalar <- Draft.draftOpaqueScalars evidence
            ])
        | record <- records
        , OpaqueMember evidence <- recordMembers record
        ]
  fields
    @?= [("type", ["Driver"]), ("documentation", ["Before emphasis after."])]
  assertEqual "opaque subtree inventory" expectedOpaqueContent opaque

mixedContentTest :: Assertion
mixedContentTest = do
  draft <- decodedDraft mixedContent
  let records = recordInventory draft
      elementOpaque =
        [ ( Draft.draftNativeLocalName (Draft.draftOpaqueName evidence)
          , map Draft.draftScalarText (Draft.draftOpaqueScalars evidence))
        | record <- records
        , recordFamily record == "element"
        , OpaqueMember evidence <- recordMembers record
        ]
  elementOpaque
    @?= [ ("element", ["before"])
        , ("extension", [])
        , ("extension", ["inner"])
        , ("nested", [])
        , ("extension", ["after-child"])
        , ("element", ["after"])
        ]

fragmentedDocumentationTest :: Assertion
fragmentedDocumentationTest = do
  draft <- decodedDraft fragmentedDocumentation
  let documentation =
        [ map Draft.draftScalarText values
        | record <- recordInventory draft
        , FieldMember field values <- recordMembers record
        , fieldName field == "documentation"
        ]
  documentation @?= [["prefix" <> Text.replicate 256 "x" <> "suffix"]]

unknownViewTypeTest :: Assertion
unknownViewTypeTest = do
  draft <- decodedDraft unknownTypedViewChild
  let records = recordInventory draft
  length (filter ((== "view-node") . recordFamily) records) @?= 0
  opaqueNames records @?= ["version", "folder", "child"]

pathProvenanceTest :: Assertion
pathProvenanceTest = do
  draft <- decodedDraft repeatedChildren
  let elementLocations =
        [ recordPath record
        | record <- recordInventory draft
        , recordFamily record == "element"
        ]
  elementLocations
    @?= [ [ (Just archiNamespace, "model", 1)
          , (Nothing, "folder", 1)
          , (Nothing, "element", 1)
          ]
        , [ (Just archiNamespace, "model", 1)
          , (Nothing, "folder", 1)
          , (Nothing, "element", 2)
          ]
        ]

propertyMultiplicityTest :: Assertion
propertyMultiplicityTest = do
  draft <- decodedDraft repeatedProperties
  let properties =
        [ (key, map Draft.draftScalarText values)
        | record <- recordInventory draft
        , PropertyMember key values <- recordMembers record
        ]
  properties @?= [(["same"], ["one"]), (["same"], ["two"]), ([], [])]

influenceStrengthTest :: Assertion
influenceStrengthTest = do
  influence <- decodedDraft influenceStrength
  association <- decodedDraft associationStrength
  recognizedFieldNames influence @?= ["type", "strength"]
  recognizedFieldNames association @?= ["type"]
  opaqueNames (recordInventory association)
    @?= ["version", "folder", "strength"]

decodedDraft :: ByteString -> IO Draft.ProfileDraft
decodedDraft bytes = do
  adapter <-
    case amxAdapter of
      Left _ ->
        assertFailure "static AMX adapter failed to compile"
          >> fail "unreachable"
      Right value -> pure value
  collection <- requireRight (compileAdapterCollection (adapter NonEmpty.:| []))
  selected <-
    foldAdapterSelection
      (const
         (assertFailure "AMX fixture was not selected" >> fail "unreachable"))
      pure
      (selectAdapter collection Nothing bytes)
  foldDecodeOutcome
    (const (assertFailure "AMX fixture did not decode" >> fail "unreachable"))
    pure
    (adapterExecutionOutcome (runSelectedAdapter selected bytes))

data AnyRecord = AnyRecord
  { recordFamily :: !Text
  , recordLocation :: !Draft.DraftLocation
  , recordMembers :: ![AnyMember]
  }

data AnyMember
  = FieldMember !Draft.DraftFieldValue ![Draft.DraftScalar]
  | PropertyMember ![Text] ![Draft.DraftScalar]
  | ReferenceMember !Text
  | ChildMember !AnyRecord
  | OpaqueMember !Draft.DraftOpaqueEvidence

recordInventory :: Draft.ProfileDraft -> [AnyRecord]
recordInventory = flatten . observeRecord . Draft.profileDraftRoot
  where
    flatten record = record : concatMap child (recordMembers record)
    child member =
      case member of
        ChildMember nested -> flatten nested
        _ -> []

observeRecord :: Draft.DraftRecord recordRole -> AnyRecord
observeRecord record =
  AnyRecord
    { recordFamily = familyName (Draft.draftRecordFamily record)
    , recordLocation = Draft.draftRecordLocation record
    , recordMembers = map observeMember (Draft.draftRecordMembers record)
    }

observeMember :: Draft.DraftMember recordRole -> AnyMember
observeMember =
  Draft.foldDraftMember
    (\field scalars _ -> FieldMember field scalars)
    (\property ->
       PropertyMember
         (propertyKeyTexts property)
         (Draft.draftPropertyValues property))
    (ReferenceMember . referenceName . Draft.draftReferenceField)
    (ChildMember . observeRecord)
    OpaqueMember

familyName :: Draft.DraftRecordFamilyValue -> Text
familyName =
  Draft.foldDraftRecordFamilyValue
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

referenceName :: Draft.DraftReferenceFieldValue -> Text
referenceName =
  Draft.foldDraftReferenceFieldValue
    "definition"
    "source"
    "target"
    "node-element"
    "connection"
    "source-node"
    "target-node"

opaqueNames :: [AnyRecord] -> [Text]
opaqueNames records =
  [ Draft.draftNativeLocalName (Draft.draftOpaqueName evidence)
  | record <- records
  , OpaqueMember evidence <- recordMembers record
  ]

opaqueScalarTexts :: [AnyRecord] -> [Text]
opaqueScalarTexts records =
  [ Draft.draftScalarText scalar
  | record <- records
  , OpaqueMember evidence <- recordMembers record
  , scalar <- Draft.draftOpaqueScalars evidence
  ]

scalarKinds :: [AnyRecord] -> [Text]
scalarKinds records =
  [ scalarKind scalar
  | record <- records
  , member <- recordMembers record
  , scalar <- memberScalars member
  ]
  where
    memberScalars member =
      case member of
        FieldMember _ values -> values
        PropertyMember _ values -> values
        OpaqueMember _ -> []
        _ -> []
    scalarKind = kindName . Draft.draftScalarKind

kindName :: Draft.DraftValueKind -> Text
kindName =
  Draft.foldDraftValueKind "text" "boolean" "number" "native-name" ("other:" <>)

referenceFields :: [AnyRecord] -> [Text]
referenceFields records =
  [field | record <- records, ReferenceMember field <- recordMembers record]

fieldName :: Draft.DraftFieldValue -> Text
fieldName =
  Draft.foldDraftFieldValue "type" "name" "documentation" "directed" "strength"

recognizedFieldNames :: Draft.ProfileDraft -> [Text]
recognizedFieldNames draft =
  [ fieldName field
  | record <- recordInventory draft
  , FieldMember field _ <- recordMembers record
  ]

propertyKeyTexts :: Draft.DraftProperty recordRole -> [Text]
propertyKeyTexts property =
  Draft.foldDraftPropertyKey
    (map Draft.draftScalarText)
    (const [])
    (Draft.draftPropertyKey property)

recordPath :: AnyRecord -> [(Maybe Text, Text, Integer)]
recordPath record =
  Draft.foldDraftSourcePath
    (\first rest -> map observeStep (first : rest))
    (Draft.draftLocationPath (recordLocation record))
  where
    observeStep step =
      let name = Draft.draftPathStepName step
       in ( Draft.draftNativeNamespace name
          , Draft.draftNativeLocalName name
          , fromIntegral (Draft.draftPathStepOrdinal step))

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

fixture :: ByteString
fixture =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" name=\"Model\" version=\"5.0.0\"><propertyDefinition id=\"definition\" name=\"Key\"/><folder id=\"motivation\" name=\"Motivation\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"driver\" name=\"Driver\"><property key=\"o2i.kind\" value=\"Primitive\"/></element></folder><folder id=\"relations\" name=\"Relations\" type=\"relations\"><element xsi:type=\"a:InfluenceRelationship\" id=\"relation\" name=\"directs\" directed=\"true\" strength=\"++\" source=\"driver\" target=\"driver\"/></folder><folder id=\"views\" name=\"Views\" type=\"diagrams\"><element xsi:type=\"a:ArchimateDiagramModel\" id=\"view\" name=\"View\"><child xsi:type=\"a:Group\" id=\"group\"><child xsi:type=\"a:DiagramObject\" id=\"node\" archimateElement=\"driver\"><bounds x=\"1\"/><sourceConnection xsi:type=\"a:Connection\" id=\"connection\" archimateRelationship=\"relation\" source=\"node\" target=\"node\"/></child></child></element></folder></a:model>"

malformedGroup :: ByteString
malformedGroup =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"views\" type=\"diagrams\"><element xsi:type=\"a:ArchimateDiagramModel\" id=\"view\"><child xsi:type=\"a:Group\" id=\"group\" archimateElement=\"unexpected\"><child xsi:type=\"a:DiagramObject\" id=\"node\" archimateElement=\"element\"/></child></element></folder></a:model>"

unresolvedType :: ByteString
unresolvedType =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"motivation\" type=\"motivation\"><element xsi:type=\"missing:Driver\" id=\"driver\"/></folder></a:model>"

invalidType :: ByteString
invalidType =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"motivation\" type=\"motivation\"><element xsi:type=\"Driver!\" id=\"driver\"/></folder></a:model>"

invalidLeadingType :: ByteString
invalidLeadingType =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"motivation\" type=\"motivation\"><element xsi:type=\"1Driver\" id=\"driver\"/></folder></a:model>"

extensionLookalike :: ByteString
extensionLookalike =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:e=\"urn:extension\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><e:folder id=\"extension\"><e:element xsi:type=\"a:Driver\" id=\"driver\"/></e:folder></a:model>"

formattingOnly :: ByteString
formattingOnly =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" id=\"model\" version=\"5.0.0\">\n  <folder id=\"empty\" type=\"other\">\n  </folder>\n</a:model>"

significantWhitespace :: ByteString
significantWhitespace =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" id=\"model\" version=\"5.0.0\">\xC2\xA0</a:model>"

canonicalA, canonicalB :: ByteString
canonicalA =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" version=\"5.0.0\" id=\"model\"><folder type=\"motivation\" id=\"folder\"><element name=\"Driver\" id=\"driver\" xsi:type=\"a:Driver\"/></folder></a:model>"

canonicalB =
  "<arch:model xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:arch=\"http://www.archimatetool.com/archimate\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"arch:Driver\" id=\"driver\" name=\"Driver\"/></folder></arch:model>"

normalizedAttributes :: ByteString
normalizedAttributes =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" version=\"5.0.0\" xmlns:x=\"urn:&#10;same\" xmlns:y=\"urn:\nsame\" x:value=\"one\" y:value=\"two\"/>"

retainedContent :: ByteString
retainedContent =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"driver\"><documentation>Before <emphasis>emphasis</emphasis> after.</documentation><extension xmlns=\"urn:test\" mode=\"alpha\"><nested>beta</nested></extension></element></folder></a:model>"

mixedContent :: ByteString
mixedContent =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"driver\">before<extension>inner<nested/>after-child</extension>after</element></folder></a:model>"

fragmentedDocumentation :: ByteString
fragmentedDocumentation =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"driver\"><documentation>prefix"
    <> foldMap (const "<fragment>x</fragment>") [1 .. (256 :: Int)]
    <> "suffix</documentation></element></folder></a:model>"

unknownTypedViewChild :: ByteString
unknownTypedViewChild =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:e=\"urn:extension\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"views\" type=\"diagrams\"><element xsi:type=\"a:ArchimateDiagramModel\" id=\"view\"><child xsi:type=\"e:ExtensionNode\" id=\"node\" archimateElement=\"element\"/></element></folder></a:model>"

repeatedChildren :: ByteString
repeatedChildren =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"one\"/><element xsi:type=\"a:Driver\" id=\"two\"/></folder></a:model>"

repeatedProperties :: ByteString
repeatedProperties =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"folder\" type=\"motivation\"><element xsi:type=\"a:Driver\" id=\"driver\"><property key=\"same\" value=\"one\"/><property key=\"same\" value=\"two\"/><property/></element></folder></a:model>"

influenceStrength, associationStrength :: ByteString
influenceStrength = relationshipFixture "InfluenceRelationship"

associationStrength = relationshipFixture "AssociationRelationship"

relationshipFixture :: ByteString -> ByteString
relationshipFixture relationshipType =
  "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" id=\"model\" version=\"5.0.0\"><folder id=\"relations\" type=\"relations\"><element xsi:type=\"a:"
    <> relationshipType
    <> "\" id=\"relationship\" strength=\"++\"/></folder></a:model>"

expectedOpaqueContent :: [(Text, [(Text, Text)])]
expectedOpaqueContent =
  [ ("version", [("text", "5.0.0")])
  , ("folder", [("other:id", "folder"), ("other:type", "motivation")])
  , ("extension", [("other:mode", "alpha")])
  , ("nested", [])
  , ("nested", [("text", "beta")])
  ]
