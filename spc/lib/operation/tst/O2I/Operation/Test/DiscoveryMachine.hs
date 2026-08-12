{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.DiscoveryMachine
  ( tests
  ) where

import Control.Exception (IOException)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.Operation.Acquisition.Internal
import O2I.Operation.Adapter.Internal
import O2I.Operation.Discovery.Adapter (discoverAdapters)
import O2I.Operation.Discovery.Adapter.Machine
import O2I.Operation.Discovery.Profile.Internal
import O2I.Operation.Discovery.Profile.Machine
import O2I.Operation.Discovery.Rule.Explanation.Machine
import O2I.Operation.Discovery.Rule.Internal
import O2I.Operation.Discovery.Rule.Inventory.Machine
import O2I.Operation.Discovery.View.Internal
import O2I.Operation.Discovery.View.Machine
import O2I.Operation.Provenance.Internal
import O2I.Operation.Schema
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "discovery machine documents"
    [ testCase "close exact generated variant inventories" variantInventories
    , testCase "encode Adapter inventory exactly" adapterInventory
    , testCase "encode both Profile inventory branches exactly" profileInventory
    , testCase "encode both Rule inventory branches exactly" ruleInventory
    , testCase "encode both Rule explanation branches exactly" ruleExplanation
    , testCase
        "encode every View discovery and selection branch exactly"
        viewDiscovery
    , testCase
        "retain View source identity after acquisition"
        viewSourceProvenance
    , testCase
        "reject wrong-stage View adapter diagnostics"
        wrongStageViewDiagnostics
    , testCase "encode every nested View identity outcome" nestedViewIdentities
    , testCase "preserve empty native View lexemes" emptyNativeViewLexemes
    , testCase "escape unrestricted domain text canonically" canonicalEscaping
    ]

variantInventories :: Assertion
variantInventories = do
  variants adapterInventorySchema @?= ["adapter-inventory"]
  variants profileInventorySchema
    @?= ["profile-inventory", "profile-static-definition-invalid"]
  variants ruleInventorySchema
    @?= ["rule-inventory", "rule-static-definition-invalid"]
  variants ruleExplanationSchema
    @?= ["rule-explanation-found", "rule-explanation-not-found"]
  variants viewDiscoverySchema
    @?= [ "views-discovered"
        , "view-acquisition-failed"
        , "view-adapter-selection-failed"
        , "view-adapter-decode-failed"
        ]

adapterInventory :: Assertion
adapterInventory = do
  let document = adapterInventoryDocument (discoverAdapters adapterCollection)
      encoded = encodeAdapterInventoryDocument document
  variant adapterInventoryDocumentVariant document @?= "adapter-inventory"
  encoded
    @?= object
          [ schema "o2i.discovery.adapter-inventory/v1"
          , field "kind" "\"adapter-inventory\""
          , field "authority" "\"Operation\""
          , field "adapters" (array [adapterDescriptorBytes adapterDescriptor])
          ]
  assertSchema "o2i.discovery.adapter-inventory-v1.schema.json" encoded

profileInventory :: Assertion
profileInventory = do
  let success =
        profileInventoryDocument
          (ProfileDiscoveryCompiled
             (ProfileDiscovery
                (profileRow :| [])
                (Map.singleton "profile@0.3" profileRow)))
      failure =
        profileInventoryDocument
          (ProfileDiscoveryCompilationFailed
             (MissingProfileAdapterId "profile@0.3"
                :| [DuplicateProfileAdapterId "profile@0.3" "amx"]))
      successEncoded = encodeProfileInventoryDocument success
      failureEncoded = encodeProfileInventoryDocument failure
  variant profileInventoryDocumentVariant success @?= "profile-inventory"
  successEncoded
    @?= object
          [ schema "o2i.discovery.profile-inventory/v1"
          , field "kind" "\"profile-inventory\""
          , field "authority" "\"Operation\""
          , field "profiles" (array [profileRowBytes])
          ]
  assertSchema "o2i.discovery.profile-inventory-v1.schema.json" successEncoded
  variant profileInventoryDocumentVariant failure
    @?= "profile-static-definition-invalid"
  failureEncoded
    @?= object
          [ schema "o2i.discovery.profile-inventory/v1"
          , field "kind" "\"profile-static-definition-invalid\""
          , field "authority" "\"Operation\""
          , field
              "diagnostics"
              (array
                 [ object
                     [ field "code" "\"missing-adapter-id\""
                     , field "profileReference" "\"profile@0.3\""
                     ]
                 , object
                     [ field "code" "\"duplicate-adapter-id\""
                     , field "profileReference" "\"profile@0.3\""
                     , field "adapterId" "\"amx\""
                     ]
                 ])
          ]
  assertSchema "o2i.discovery.profile-inventory-v1.schema.json" failureEncoded

ruleInventory :: Assertion
ruleInventory = do
  let success =
        ruleInventoryDocument
          (RuleDiscoveryCompiled
             (RuleDiscovery
                coreAuthority
                (coreRule :| [])
                (Map.singleton "core.rule" coreRule)))
      failure =
        ruleInventoryDocument
          (RuleDiscoveryCompilationFailed
             (ProfileRuleCatalogMismatch "p@1" "p@2" digestA digestB
                :| [DuplicateRuleIdentity "Core" "core.rule"]))
      successEncoded = encodeRuleInventoryDocument success
      failureEncoded = encodeRuleInventoryDocument failure
  variant ruleInventoryDocumentVariant success @?= "rule-inventory"
  successEncoded
    @?= object
          [ schema "o2i.discovery.rule-inventory/v1"
          , field "kind" "\"rule-inventory\""
          , field "authority" coreAuthorityBytes
          , field "rules" (array [coreRuleBytes])
          ]
  assertSchema "o2i.discovery.rule-inventory-v1.schema.json" successEncoded
  variant ruleInventoryDocumentVariant failure
    @?= "rule-static-definition-invalid"
  failureEncoded
    @?= object
          [ schema "o2i.discovery.rule-inventory/v1"
          , field "kind" "\"rule-static-definition-invalid\""
          , field
              "diagnostics"
              (array
                 [ object
                     [ field "code" "\"profile-catalog-mismatch\""
                     , field "expectedReference" "\"p@1\""
                     , field "actualReference" "\"p@2\""
                     , field "expectedDigest" (quoted digestABytes)
                     , field "actualDigest" (quoted digestBBytes)
                     ]
                 , object
                     [ field "code" "\"duplicate-rule-id\""
                     , field "authority" "\"Core\""
                     , field "ruleId" "\"core.rule\""
                     ]
                 ])
          ]
  assertSchema "o2i.discovery.rule-inventory-v1.schema.json" failureEncoded

ruleExplanation :: Assertion
ruleExplanation = do
  let found =
        ruleExplanationDocument
          (RuleExplanationFound coreAuthority "core.rule" coreRule)
      missing =
        ruleExplanationDocument
          (RuleExplanationNotFound coreAuthority " core.rule")
      foundEncoded = encodeRuleExplanationDocument found
      missingEncoded = encodeRuleExplanationDocument missing
  variant ruleExplanationDocumentVariant found @?= "rule-explanation-found"
  foundEncoded
    @?= object
          [ schema "o2i.discovery.rule-explanation/v1"
          , field "kind" "\"rule-explanation-found\""
          , field "authority" coreAuthorityBytes
          , field "requestedRuleId" "\"core.rule\""
          , field "rule" coreRuleBytes
          ]
  assertSchema "o2i.discovery.rule-explanation-v1.schema.json" foundEncoded
  variant ruleExplanationDocumentVariant missing
    @?= "rule-explanation-not-found"
  missingEncoded
    @?= object
          [ schema "o2i.discovery.rule-explanation/v1"
          , field "kind" "\"rule-explanation-not-found\""
          , field "authority" coreAuthorityBytes
          , field "requestedRuleId" "\" core.rule\""
          ]
  assertSchema "o2i.discovery.rule-explanation-v1.schema.json" missingEncoded

viewDiscovery :: Assertion
viewDiscovery = do
  let acquisition =
        ViewDiscoveryFailed
          (ViewAcquisitionFailed
             (AcquisitionFailure
                (FileInput sourceReference "model.amx")
                acquisitionError))
      unknown =
        ViewDiscoveryFailed
          (ViewAdapterSelectionFailed
             sourceIdentity
             (UnknownAdapter (AdapterId "missing")))
      recognition =
        ViewDiscoveryFailed
          (ViewAdapterSelectionFailed
             sourceIdentity
             (AdapterRecognitionFailed
                ((adapterDescriptor, recognitionAdapterDiagnostic :| []) :| [])))
      noMatch =
        ViewDiscoveryFailed
          (ViewAdapterSelectionFailed sourceIdentity NoAdapterMatched)
      multiple =
        ViewDiscoveryFailed
          (ViewAdapterSelectionFailed
             sourceIdentity
             (MultipleAdaptersMatched
                (adapterDescriptor :| [secondAdapterDescriptor])))
      decode =
        ViewDiscoveryFailed
          (ViewAdapterDecodeFailed
             sourceIdentity
             adapterDescriptor
             (adapterDiagnostic :| []))
      succeeded =
        ViewsDiscovered
          (ViewDiscoveryResult
             sourceIdentity
             adapterDescriptor
             emptyCanonicalDocument
             [])
  assertView
    "view-acquisition-failed"
    [ field
        "failure"
        (object
           [ field "sourceKind" "\"file\""
           , field "sourceReference" "\"model\""
           , field "message" "\"user error (read failed)\""
           ])
    ]
    acquisition
  assertView
    "view-adapter-selection-failed"
    [ field "source" sourceIdentityBytes
    , field
        "failure"
        (object
           [field "kind" "\"unknown-adapter\"", field "adapterId" "\"missing\""])
    ]
    unknown
  assertView
    "view-adapter-selection-failed"
    [ field "source" sourceIdentityBytes
    , field
        "failure"
        (object
           [ field "kind" "\"recognition-failed\""
           , field
               "failures"
               (array
                  [ object
                      [ field
                          "adapter"
                          (adapterDescriptorBytes adapterDescriptor)
                      , field
                          "diagnostics"
                          (array [recognitionAdapterDiagnosticBytes])
                      ]
                  ])
           ])
    ]
    recognition
  assertView
    "view-adapter-selection-failed"
    [ field "source" sourceIdentityBytes
    , field "failure" (object [field "kind" "\"no-match\""])
    ]
    noMatch
  assertView
    "view-adapter-selection-failed"
    [ field "source" sourceIdentityBytes
    , field
        "failure"
        (object
           [ field "kind" "\"multiple-matches\""
           , field
               "adapters"
               (array
                  [ adapterDescriptorBytes adapterDescriptor
                  , adapterDescriptorBytes secondAdapterDescriptor
                  ])
           ])
    ]
    multiple
  assertView
    "view-adapter-decode-failed"
    [ field "source" sourceIdentityBytes
    , field "adapter" (adapterDescriptorBytes adapterDescriptor)
    , field "diagnostics" (array [adapterDiagnosticBytes])
    ]
    decode
  assertView
    "views-discovered"
    [ field "source" sourceIdentityBytes
    , field "adapter" (adapterDescriptorBytes adapterDescriptor)
    , field
        "authorities"
        (array
           [ object [field "kind" "\"operation\""]
           , object [field "kind" "\"adapter\"", field "adapterId" "\"amx\""]
           ])
    , field "views" "[]"
    ]
    succeeded

viewSourceProvenance :: Assertion
viewSourceProvenance = do
  let selection =
        viewDiscoveryDocument
          (ViewDiscoveryFailed
             (ViewAdapterSelectionFailed sourceIdentity NoAdapterMatched))
      decode =
        viewDiscoveryDocument
          (ViewDiscoveryFailed
             (ViewAdapterDecodeFailed
                sourceIdentity
                adapterDescriptor
                (adapterDiagnostic :| [])))
  ByteString.isInfixOf
    sourceIdentityBytes
    (encodeViewDiscoveryDocument selection)
    @? "selection failure lost acquired source identity"
  ByteString.isInfixOf sourceIdentityBytes (encodeViewDiscoveryDocument decode)
    @? "decode failure lost acquired source identity"

wrongStageViewDiagnostics :: Assertion
wrongStageViewDiagnostics = do
  let recognition =
        viewDiscoveryDocument
          (ViewDiscoveryFailed
             (ViewAdapterSelectionFailed
                sourceIdentity
                (AdapterRecognitionFailed
                   ((adapterDescriptor, adapterDiagnostic :| []) :| []))))
      decode =
        viewDiscoveryDocument
          (ViewDiscoveryFailed
             (ViewAdapterDecodeFailed
                sourceIdentity
                adapterDescriptor
                (recognitionAdapterDiagnostic :| [])))
  assertSchemaRejected
    "o2i.discovery.view-v1.schema.json"
    (encodeViewDiscoveryDocument recognition)
  assertSchemaRejected
    "o2i.discovery.view-v1.schema.json"
    (encodeViewDiscoveryDocument decode)

nestedViewIdentities :: Assertion
nestedViewIdentities = do
  let canonical = Notation.buildCanonicalDocument identityDraft
      document =
        viewDiscoveryDocument
          (ViewsDiscovered
             (ViewDiscoveryResult
                sourceIdentity
                adapterDescriptor
                canonical
                (Notation.viewInventory canonical)))
      encoded = encodeViewDiscoveryDocument document
  assertSchema "o2i.discovery.view-v1.schema.json" encoded
  mapM_
    (assertContained encoded)
    [ "\"identity\":{\"kind\":\"missing\"}"
    , "\"identity\":{\"kind\":\"multiple\",\"values\":["
    , "\"reason\":{\"kind\":\"non-text\",\"observedKind\":\"boolean\"}"
    , "\"reason\":{\"kind\":\"empty\"}"
    , "\"reason\":{\"kind\":\"u0000\"}"
    , "\"identity\":{\"kind\":\"resolved\""
    , "\"identity\":\"resolved\""
    ]
  length (Notation.viewInventory canonical) @?= 6

emptyNativeViewLexemes :: Assertion
emptyNativeViewLexemes = do
  let canonical = Notation.buildCanonicalDocument emptyNativeLexemeDraft
      document =
        viewDiscoveryDocument
          (ViewsDiscovered
             (ViewDiscoveryResult
                sourceIdentity
                adapterDescriptor
                canonical
                (Notation.viewInventory canonical)))
      encoded = encodeViewDiscoveryDocument document
  assertSchema "o2i.discovery.view-v1.schema.json" encoded
  mapM_
    (assertContained encoded)
    [ "\"localName\":\"\""
    , "\"kind\":\"number\",\"value\":\"\""
    , "\"nativeKind\":\"\""
    , "\"observedKind\":\"\""
    , "\"ordinal\":1"
    ]
  assertSchemaRejected
    "o2i.discovery.view-v1.schema.json"
    (replaceOnce
       "\"name\":{\"namespace\":null,\"localName\":\"\"},\"ordinal\":1"
       "\"name\":{\"namespace\":null,\"localName\":\"\"},\"ordinal\":0"
       encoded)

replaceOnce :: ByteString -> ByteString -> ByteString -> ByteString
replaceOnce expected replacement source =
  case ByteString.breakSubstring expected source of
    (prefix, suffix)
      | ByteString.null suffix -> source
      | otherwise ->
        prefix
          <> replacement
          <> ByteString.drop (ByteString.length expected) suffix

assertContained :: ByteString -> ByteString -> Assertion
assertContained document fragment =
  ByteString.isInfixOf fragment document
    @? ("machine document omitted fragment: " <> show fragment)

canonicalEscaping :: Assertion
canonicalEscaping = do
  let requested = "quote\" slash\\ line\n tab\t " <> Text.singleton '\x1F'
      document =
        ruleExplanationDocument
          (RuleExplanationNotFound coreAuthority requested)
      encoded = encodeRuleExplanationDocument document
  encoded
    @?= object
          [ schema "o2i.discovery.rule-explanation/v1"
          , field "kind" "\"rule-explanation-not-found\""
          , field "authority" coreAuthorityBytes
          , field
              "requestedRuleId"
              "\"quote\\\" slash\\\\ line\\n tab\\t \\u001F\""
          ]
  assertSchema "o2i.discovery.rule-explanation-v1.schema.json" encoded

assertView :: ByteString -> [ByteString] -> ViewDiscovery -> Assertion
assertView expectedVariant members outcome = do
  let document = viewDiscoveryDocument outcome
      encoded = encodeViewDiscoveryDocument document
  variant viewDiscoveryDocumentVariant document @?= expectedVariant
  encoded
    @?= object
          (schema "o2i.discovery.view/v1"
             : field "kind" (quoted expectedVariant)
             : members)
  assertSchema "o2i.discovery.view-v1.schema.json" encoded

assertSchema :: FilePath -> ByteString -> Assertion
assertSchema name encoded = do
  valid <- validateAgainstSchema name encoded
  valid @? (name <> ": encoded document violates its machine schema")

assertSchemaRejected :: FilePath -> ByteString -> Assertion
assertSchemaRejected name encoded = do
  valid <- validateAgainstSchema name encoded
  not valid @? (name <> ": invalid document satisfies its machine schema")

validateAgainstSchema :: FilePath -> ByteString -> IO Bool
validateAgainstSchema name encoded = do
  schemaBytes <- LazyByteString.readFile ("contract" </> "schema" </> name)
  schemaValue <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure (name <> ": " <> message)
      Right value -> pure value
  documentValue <-
    case Aeson.eitherDecodeStrict encoded of
      Left message -> assertFailure (name <> " document: " <> message)
      Right value -> pure value
  pure (validateJSONSchema schemaValue documentValue)

variants :: MachineSchema -> [ByteString]
variants =
  fmap (utf8 . schemaVariantText) . NonEmpty.toList . machineSchemaVariants

variant :: (document -> SchemaVariant) -> document -> ByteString
variant project = utf8 . schemaVariantText . project

schema :: ByteString -> ByteString
schema = field "schema" . quoted

field :: ByteString -> ByteString -> ByteString
field name value = quoted name <> ":" <> value

object :: [ByteString] -> ByteString
object members = "{" <> separated members <> "}"

array :: [ByteString] -> ByteString
array entries = "[" <> separated entries <> "]"

separated :: [ByteString] -> ByteString
separated = ByteString.intercalate ","

quoted :: ByteString -> ByteString
quoted value = "\"" <> value <> "\""

utf8 :: Text.Text -> ByteString
utf8 = ByteString.pack . fmap (fromIntegral . fromEnum) . Text.unpack

profileRow :: ProfileDiscoveryRow
profileRow =
  ProfileDiscoveryRow
    "profile"
    "0.3"
    "0.3"
    "archimate-3.2"
    ("amx" :| ["zeta"])
    digestA

profileRowBytes :: ByteString
profileRowBytes =
  object
    [ field "identity" "\"profile\""
    , field "token" "\"0.3\""
    , field "reference" "\"profile@0.3\""
    , field "version" "\"0.3\""
    , field "notation" "\"archimate-3.2\""
    , field "adapterIds" (array ["\"amx\"", "\"zeta\""])
    , field "contractDigest" (quoted digestABytes)
    ]

coreAuthority :: RuleAuthority
coreAuthority =
  CoreAuthority (RuleContractBinding "o2i-core" "0.2" (Just digestB))

coreRule :: DiscoveredRule
coreRule =
  DiscoveredRule
    coreAuthority
    "core.rule"
    "validation"
    "expectation"
    "meaning"
    "action"

coreAuthorityBytes :: ByteString
coreAuthorityBytes =
  object
    [ field "kind" "\"core\""
    , field "label" "\"Core\""
    , field "subject" "null"
    , field
        "contract"
        (object
           [ field "identity" "\"o2i-core\""
           , field "version" "\"0.2\""
           , field "digest" (quoted digestBBytes)
           ])
    ]

digestA :: Text.Text
digestA = Text.replicate 64 "a"

digestABytes :: ByteString
digestABytes = utf8 digestA

digestB :: Text.Text
digestB = Text.replicate 64 "b"

digestBBytes :: ByteString
digestBBytes = utf8 digestB

coreRuleBytes :: ByteString
coreRuleBytes =
  object
    [ field "id" "\"core.rule\""
    , field "stage" "\"validation\""
    , field "expectation" "\"expectation\""
    , field "meaning" "\"meaning\""
    , field "action" "\"action\""
    ]

adapterIdentifier :: AdapterId
adapterIdentifier = AdapterId "amx"

adapterDescriptor :: AdapterDescriptor
adapterDescriptor =
  AdapterDescriptor adapterIdentifier "AMX" "1.0" "archimate-3.2"

secondAdapterDescriptor :: AdapterDescriptor
secondAdapterDescriptor =
  AdapterDescriptor (AdapterId "zeta") "Zeta" "2.0" "archimate-3.2"

adapterRule :: AdapterRule
adapterRule =
  AdapterRule
    (AdapterRuleId "amx.decode")
    AdapterDecodeStage
    "decode"
    "retain evidence"
    "fix source"

recognitionAdapterRule :: AdapterRule
recognitionAdapterRule =
  AdapterRule
    (AdapterRuleId "amx.recognition")
    AdapterRecognitionStage
    "recognize"
    "select adapter"
    "fix signature"

adapterDiagnostic :: AdapterDiagnostic
adapterDiagnostic =
  AdapterDiagnostic
    adapterRule
    (AdapterOccurrence Nothing
       :| [AdapterOccurrence (Just (NativeLineColumn 2 3))])

recognitionAdapterDiagnostic :: AdapterDiagnostic
recognitionAdapterDiagnostic =
  AdapterDiagnostic recognitionAdapterRule (AdapterOccurrence Nothing :| [])

adapterCollection :: AdapterCollection
adapterCollection =
  AdapterCollection
    (adapterValue :| [])
    (Map.singleton adapterIdentifier adapterValue)
  where
    adapterValue =
      Adapter
        adapterDescriptor
        (adapterRule :| [])
        (const RecognitionMatch)
        (const (DecodePassed emptyDraft))

adapterDescriptorBytes :: AdapterDescriptor -> ByteString
adapterDescriptorBytes descriptor =
  case descriptor of
    AdapterDescriptor identifier name version notation ->
      object
        [ field "id" (quoted (adapterIdBytes identifier))
        , field "name" (quoted (utf8 name))
        , field "version" (quoted (utf8 version))
        , field "notation" (quoted (utf8 notation))
        ]

adapterIdBytes :: AdapterId -> ByteString
adapterIdBytes (AdapterId value) = utf8 value

adapterDiagnosticBytes :: ByteString
adapterDiagnosticBytes =
  object
    [ field
        "rule"
        (object
           [ field "id" "\"amx.decode\""
           , field "stage" "\"decode\""
           , field "expectation" "\"decode\""
           , field "meaning" "\"retain evidence\""
           , field "action" "\"fix source\""
           ])
    , field
        "occurrences"
        (array
           [ "null"
           , object
               [ field "kind" "\"line-column\""
               , field "line" "2"
               , field "column" "3"
               ]
           ])
    ]

recognitionAdapterDiagnosticBytes :: ByteString
recognitionAdapterDiagnosticBytes =
  object
    [ field
        "rule"
        (object
           [ field "id" "\"amx.recognition\""
           , field "stage" "\"recognition\""
           , field "expectation" "\"recognize\""
           , field "meaning" "\"select adapter\""
           , field "action" "\"fix signature\""
           ])
    , field "occurrences" (array ["null"])
    ]

sourceReference :: SourceReference
sourceReference = SourceReference "model"

sourceIdentity :: SourceIdentity
sourceIdentity =
  sourceIdentityFromBytes ModelRole (SourceOrdinal 0) sourceReference "model"

sourceIdentityBytes :: ByteString
sourceIdentityBytes =
  object
    [ field "role" "\"model\""
    , field "ordinal" "0"
    , field "reference" "\"model\""
    , field
        "sha256"
        "\"9372c470eeadd5ecd9c3c74c2b3cb633f8e2f2fad799250a0f70d652b6b825e4\""
    ]

acquisitionError :: IOException
acquisitionError = userError "read failed"

emptyDraft :: Draft.ProfileDraft
emptyDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [Draft.draftTextScalar "model" rootLocation])
       rootLocation
       [])

emptyCanonicalDocument :: Notation.CanonicalDocument
emptyCanonicalDocument = Notation.buildCanonicalDocument emptyDraft

identityDraft :: Draft.ProfileDraft
identityDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [textScalar "model"])
       rootLocation
       [ viewMember "missing" []
       , viewMember "multiple" [textScalar "one", textScalar "two"]
       , viewMember "non-text" [Draft.draftBooleanScalar True rootLocation]
       , viewMember "empty" [textScalar ""]
       , viewMember "nul" [textScalar "nul\NULvalue"]
       , viewMember "resolved" [textScalar "resolved"]
       ])

emptyNativeLexemeDraft :: Draft.ProfileDraft
emptyNativeLexemeDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [Draft.draftTextScalar "model" rawLocation])
       rawLocation
       [ Draft.childRecordMember
           (Draft.viewDraft
              (Draft.draftIdentity [Draft.draftOtherScalar "" "raw" rawLocation])
              rawLocation
              [ Draft.nameFieldMember
                  [Draft.draftNumberScalar "" rawLocation]
                  rawLocation
              ])
       ])

rawLocation :: Draft.DraftLocation
rawLocation =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing "") 0)
       [])
    Nothing

viewMember ::
     Text.Text -> [Draft.DraftScalar] -> Draft.DraftMember Draft.ModelRootRole
viewMember name identity =
  Draft.childRecordMember
    (Draft.viewDraft
       (Draft.draftIdentity identity)
       (location name)
       [Draft.nameFieldMember [textScalar name] (location (name <> "-name"))])

textScalar :: Text.Text -> Draft.DraftScalar
textScalar value = Draft.draftTextScalar value rootLocation

location :: Text.Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing

rootLocation :: Draft.DraftLocation
rootLocation = location "model"
