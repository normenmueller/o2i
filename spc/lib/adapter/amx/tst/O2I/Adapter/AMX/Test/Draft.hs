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
import O2I.Adapter.AMX.Test.Fixture (fixtureBytes)
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
    , testCase
        "classifies referenced non-Group View children as nodes"
        referencedViewNodeTest
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
  draft <- fixtureDraft "native-complete-draft"
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
  draft <- fixtureDraft "native-complete-draft"
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
  draft <- fixtureDraft "native-group-archimate-element-overlap"
  let records = recordInventory draft
  length (filter ((== "view-node") . recordFamily) records) @?= 1
  opaqueNames records @?= ["version", "folder", "child"]
  assertBool
    "Group archimateElement overlap was not retained as opaque evidence"
    ("unexpected" `elem` opaqueScalarTexts records)

namespaceTest :: Assertion
namespaceTest = do
  draft <- fixtureDraft "native-extension-lookalike"
  let records = recordInventory draft
  map recordFamily records @?= ["model-root"]
  opaqueNames records @?= ["version", "folder", "element"]

scalarTest :: Assertion
scalarTest = do
  draft <- fixtureDraft "native-complete-draft"
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
  draft <- fixtureDraft "native-malformed-occurrences"
  scalarKinds (recordInventory draft) @?= ["text", "text", "text"]

whitespaceTest :: Assertion
whitespaceTest = do
  draft <- fixtureDraft "native-formatting-whitespace"
  scalarKinds (recordInventory draft) @?= []
  significant <- fixtureDraft "native-significant-whitespace"
  assertBool
    "non-XML whitespace was discarded"
    ("\xA0" `elem` opaqueScalarTexts (recordInventory significant))

canonicalizationTest :: Assertion
canonicalizationTest = do
  left <- fixtureDraft "native-prefix-order-a"
  right <- fixtureDraft "native-prefix-order-b"
  left @?= right

attributeNormalizationTest :: Assertion
attributeNormalizationTest = do
  draft <- fixtureDraft "native-attribute-normalization"
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
  draft <- fixtureDraft "native-unknown-content"
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
  draft <- fixtureDraft "native-mixed-content"
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
  draft <- fixtureDraft "native-fragmented-documentation"
  let documentation =
        [ map Draft.draftScalarText values
        | record <- recordInventory draft
        , FieldMember field values <- recordMembers record
        , fieldName field == "documentation"
        ]
  documentation @?= [["prefix" <> Text.replicate 256 "x" <> "suffix"]]

referencedViewNodeTest :: Assertion
referencedViewNodeTest = do
  draft <- fixtureDraft "native-unknown-typed-view-child"
  let records = recordInventory draft
  length (filter ((== "view-node") . recordFamily) records) @?= 1
  referenceFields records @?= ["node-element"]
  opaqueNames records @?= ["version", "folder"]

pathProvenanceTest :: Assertion
pathProvenanceTest = do
  draft <- fixtureDraft "native-order-duplicates"
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
  draft <- fixtureDraft "native-order-duplicates"
  let properties =
        [ (key, map Draft.draftScalarText values)
        | record <- recordInventory draft
        , PropertyMember key values <- recordMembers record
        ]
  properties @?= [(["same"], ["one"]), (["same"], ["two"]), ([], [])]

influenceStrengthTest :: Assertion
influenceStrengthTest = do
  influence <- fixtureDraft "native-influence-strength"
  association <- fixtureDraft "native-association-strength"
  recognizedFieldNames influence @?= ["type", "strength"]
  recognizedFieldNames association @?= ["type"]
  opaqueNames (recordInventory association)
    @?= ["version", "folder", "strength"]

fixtureDraft :: Text -> IO Draft.ProfileDraft
fixtureDraft identifier = fixtureBytes identifier >>= decodedDraft

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

expectedOpaqueContent :: [(Text, [(Text, Text)])]
expectedOpaqueContent =
  [ ("version", [("text", "5.0.0")])
  , ("folder", [("other:id", "folder"), ("other:type", "motivation")])
  , ("extension", [("other:mode", "alpha")])
  , ("nested", [])
  , ("nested", [("text", "beta")])
  ]
