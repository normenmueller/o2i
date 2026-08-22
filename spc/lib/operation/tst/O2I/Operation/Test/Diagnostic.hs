{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module O2I.Operation.Test.Diagnostic
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Language.Haskell.TH (lookupTypeName, lookupValueName)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.ArchiMate.Profile.Rule.Catalog
import O2I.ArchiMate.Profile.Rule.Explanation (ProfileRuleExplanation)
import O2I.Core.Identity
import O2I.Core.Rule.Catalog
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.AdapterOwner.Internal
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Encoding.Internal (canonicalFragmentBytes)
import O2I.Operation.Machine.Fragment.Internal (diagnosticFragment)
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import O2I.Operation.Rule.Catalog
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

$(do
    witnessType <- lookupTypeName "AdapterRuleWitness"
    witnessConstructor <- lookupValueName "AdapterRuleWitness"
    resolver <- lookupValueName "resolveAdapterContractRule"
    consumer <- lookupValueName "foldAdapterRuleWitness"
    case (witnessType, witnessConstructor, resolver, consumer) of
      (Just _, Nothing, Just _, Just _) -> pure []
      _ ->
        fail
          "AdapterRuleWitness must be abstract while its resolver and fold remain visible")

tests :: TestTree
tests =
  testGroup
    "diagnostic"
    [ testCase "enumerates severity and disposition" closedClassifications
    , testCase "keeps code and owning rule identity distinct" codeOwnership
    , testCase "preserves every authority" authorityCases
    , testCase "preserves every typed occurrence" occurrenceCases
    , testCase
        "resolves Adapter provenance through its compiled contract"
        adapterWitnessResolution
    , testCase
        "rejects unknown and foreign Adapter rules"
        adapterWitnessRejection
    , testCase
        "resolves and encodes every provenance owner exactly"
        provenanceEncoding
    , testCase "encodes every severity exactly" severityEncoding
    , testCase "encodes every disposition exactly" dispositionEncoding
    , testCase "encodes every typed occurrence exactly" occurrenceEncoding
    , testCase "encodes every source role exactly" sourceRoleEncoding
    , testCase "encodes every Adapter location exactly" adapterLocationEncoding
    , testCase
        "encodes every canonical occurrence kind exactly"
        canonicalKindEncoding
    , testCase
        "encodes every Draft locator alternative exactly"
        draftLocationEncoding
    , testCase "rejects impossible provenance cross-forms" provenanceRejection
    ]

closedClassifications :: Assertion
closedClassifications = do
  fmap diagnosticSeverityText severities
    @?= ["debug", "info", "warning", "error"]
  fmap (foldDiagnosticSeverity 0 1 2 3) severities @?= ([0, 1, 2, 3] :: [Int])
  fmap diagnosticDispositionText dispositions
    @?= ["model-finding", "process-failure"]
  fmap (foldDiagnosticDisposition 0 1) dispositions @?= ([0, 1] :: [Int])
  where
    severities = [debugSeverity, infoSeverity, warningSeverity, errorSeverity]
    dispositions = [modelFinding, processFailure]

codeOwnership :: Assertion
codeOwnership = do
  value <- operationDiagnostic
  diagnosticRuleIdentity value @?= "bootstrap.profile-adapter.adapter-id"
  diagnosticCodeText (diagnosticCode value)
    @?= "o2i.operation.bootstrap.profile-adapter.adapter-id"
  diagnosticSeverity value @?= errorSeverity
  diagnosticDisposition value @?= modelFinding

authorityCases :: Assertion
authorityCases = do
  (_, _, adapterWitness) <- adapterWitnessFixture "test" "native.invalid"
  let provenances =
        [ OperationDiagnosticProvenance operationRule
        , AdapterDiagnosticProvenance adapterWitness
        , ProfileDiagnosticProvenance profileRule
        , CoreDiagnosticProvenance coreRule
        ]
  fmap diagnosticProvenanceAuthority provenances
    @?= [ "Operation"
        , "Adapter:test"
        , "Profile:o2i.archimate-profile@0.3"
        , "Core"
        ]
  fmap provenanceTag provenances @?= ([0, 1, 2, 3] :: [Int])
  where
    provenanceTag =
      foldDiagnosticProvenance
        (const 0)
        (\_ _ -> 1)
        (const 2)
        (const 3)
        (const 4)

occurrenceCases :: Assertion
occurrenceCases = do
  occurrences <- typedOccurrences
  value <- operationDiagnostic
  fmap occurrenceTag (NonEmpty.toList occurrences)
    @?= ([0, 1, 2, 3, 4, 5] :: [Int])
  NonEmpty.length (diagnosticOccurrences value) @?= 1
  foldDiagnostic
    (\severity disposition provenance retained -> do
       severity @?= errorSeverity
       disposition @?= modelFinding
       diagnosticProvenanceAuthority provenance @?= "Operation"
       NonEmpty.length retained @?= 1)
    value
  where
    occurrenceTag =
      foldDiagnosticOccurrence
        (const 0)
        (\_ _ -> 1)
        (\_ _ -> 2)
        (\_ _ -> 3)
        (\_ _ -> 4)
        (\_ _ -> 5)

adapterWitnessResolution :: Assertion
adapterWitnessResolution = do
  (contract, identifier, witness) <-
    adapterWitnessFixture "test" "native.invalid"
  resolved <- requireRight (resolveAdapterContractRule identifier contract)
  resolved @?= witness
  let provenance = AdapterDiagnosticProvenance resolved
  occurrence <- sourceOccurrence
  let value = diagnostic errorSeverity processFailure provenance occurrence
  diagnosticRuleIdentity value @?= "native.invalid"
  diagnosticCodeText (diagnosticCode value)
    @?= "o2i.adapter.test.native.invalid"
  diagnosticProvenanceAuthority provenance @?= "Adapter:test"
  diagnosticProvenanceStage provenance @?= "preparation"
  foldAdapterRuleWitness
    (\descriptor rule -> do
       adapterIdText (adapterDescriptorId descriptor) @?= "test"
       adapterRuleId rule @?= identifier
       adapterRuleStage rule @?= preparationRuleStage)
    resolved

adapterWitnessRejection :: Assertion
adapterWitnessRejection = do
  (firstContract, _, _) <- adapterWitnessFixture "first" "first.native"
  (_, foreignIdentifier, _) <- adapterWitnessFixture "second" "second.native"
  (sameFirstContract, sameIdentifier, _) <-
    adapterWitnessFixtureWithExpectation
      "same-first"
      "shared.native"
      "first expectation"
  (sameSecondContract, _, _) <-
    adapterWitnessFixtureWithExpectation
      "same-second"
      "shared.native"
      "second expectation"
  unknownSpec <-
    requireRight
      (mkAdapterRuleSpec
         "unknown.native"
         preparationRuleStage
         "expectation"
         "meaning"
         "action")
  assertResolutionFailure firstContract foreignIdentifier "second.native"
  assertResolutionFailure
    firstContract
    (adapterRuleSpecId unknownSpec)
    "unknown.native"
  sameFirst <-
    requireRight (resolveAdapterContractRule sameIdentifier sameFirstContract)
  sameSecond <-
    requireRight (resolveAdapterContractRule sameIdentifier sameSecondContract)
  assertWitnessOwnerAndExpectation sameFirst "same-first" "first expectation"
  assertWitnessOwnerAndExpectation sameSecond "same-second" "second expectation"

provenanceEncoding :: Assertion
provenanceEncoding = do
  (adapterContract, adapterIdentifier, _) <-
    adapterWitnessFixture "test" "native.invalid"
  adapterWitness <-
    requireRight (resolveAdapterContractRule adapterIdentifier adapterContract)
  resolvedOperation <-
    requireJust
      "Operation rule was absent from its exact catalog"
      (lookupOperationRule
         operationRuleCatalog
         "bootstrap.profile-adapter.adapter-id")
  resolvedProfile <-
    requireJust
      "Profile rule was absent from its exact catalog"
      (lookupSelectedProfileRule selectedProfileRuleCatalog "carrier:context")
  resolvedCore <-
    requireJust
      "Core rule was absent from its exact catalog"
      (lookupCoreRule coreRuleCatalog "core.assessment.actual-start.cardinality")
  (occurrence, occurrenceBytes) <- sourceOccurrenceFixture
  let cases =
        [ ( OperationDiagnosticProvenance resolvedOperation
          , object
              [ field "owner" "\"operation\""
              , field "ruleId" "\"bootstrap.profile-adapter.adapter-id\""
              ]
          , "bootstrap.profile-adapter.adapter-id"
          , "o2i.operation.bootstrap.profile-adapter.adapter-id"
          , "Operation"
          , "preparation")
        , ( AdapterDiagnosticProvenance adapterWitness
          , object
              [ field "owner" "\"adapter\""
              , field "adapterId" "\"test\""
              , field "ruleId" "\"native.invalid\""
              ]
          , "native.invalid"
          , "o2i.adapter.test.native.invalid"
          , "Adapter:test"
          , "preparation")
        , ( ProfileDiagnosticProvenance resolvedProfile
          , object
              [ field "owner" "\"profile\""
              , field "profileReference" "\"o2i.archimate-profile@0.3\""
              , field "ruleId" "\"carrier:context\""
              ]
          , "carrier:context"
          , "o2i.profile.carrier:context"
          , "Profile:o2i.archimate-profile@0.3"
          , "profile")
        , ( CoreDiagnosticProvenance resolvedCore
          , object
              [ field "owner" "\"core\""
              , field "ruleId" "\"core.assessment.actual-start.cardinality\""
              ]
          , "core.assessment.actual-start.cardinality"
          , "o2i.core.core.assessment.actual-start.cardinality"
          , "Core"
          , "readiness-and-assessment")
        ]
  mapM_
    (\(provenance, expected, ruleIdentity, code, authority, stage) -> do
       let value = diagnostic errorSeverity modelFinding provenance occurrence
       assertDiagnosticEncoding
         value
         (diagnosticBytes "error" "model-finding" expected occurrenceBytes)
       diagnosticRuleIdentity value @?= ruleIdentity
       diagnosticCodeText (diagnosticCode value) @?= code
       diagnosticProvenanceAuthority provenance @?= authority
       diagnosticProvenanceStage provenance @?= stage)
    cases

severityEncoding :: Assertion
severityEncoding = do
  (occurrence, occurrenceBytes) <- sourceOccurrenceFixture
  let cases =
        [ (debugSeverity, "debug")
        , (infoSeverity, "info")
        , (warningSeverity, "warning")
        , (errorSeverity, "error")
        ]
  mapM_
    (\(severity, expected) ->
       assertDiagnosticEncoding
         (diagnostic severity modelFinding operationProvenance occurrence)
         (diagnosticBytes
            expected
            "model-finding"
            operationProvenanceBytes
            occurrenceBytes))
    cases

dispositionEncoding :: Assertion
dispositionEncoding = do
  (occurrence, occurrenceBytes) <- sourceOccurrenceFixture
  let cases =
        [(modelFinding, "model-finding"), (processFailure, "process-failure")]
  mapM_
    (\(disposition, expected) ->
       assertDiagnosticEncoding
         (diagnostic errorSeverity disposition operationProvenance occurrence)
         (diagnosticBytes
            "error"
            expected
            operationProvenanceBytes
            occurrenceBytes))
    cases

occurrenceEncoding :: Assertion
occurrenceEncoding = do
  occurrences <- NonEmpty.toList <$> typedOccurrences
  identity <- sourceIdentity
  let source = sourceBytes identity
      expectedOccurrences =
        [ object [field "kind" "\"source\"", field "source" source]
        , object
            [ field "kind" "\"native\""
            , field "source" source
            , field "location" "null"
            ]
        , object
            [ field "kind" "\"draft\""
            , field "source" source
            , field "location" testLocationBytes
            ]
        , object
            [ field "kind" "\"canonical\""
            , field "source" source
            , field
                "occurrence"
                (object [field "kind" "\"record\"", field "ordinal" "0"])
            ]
        , object
            [ field "kind" "\"subject\""
            , field "source" source
            , field "identity" "\"subject\""
            ]
        , object
            [ field "kind" "\"occurrence\""
            , field "source" source
            , field "identity" "\"record:0\""
            ]
        ]
  assertOccurrenceEncodings occurrences expectedOccurrences

sourceRoleEncoding :: Assertion
sourceRoleEncoding =
  mapM_
    (\(role, encodedRole) -> do
       identity <- sourceIdentityFor role "source"
       let encodedSource = sourceBytesAs encodedRole identity
       assertOccurrenceEncodings
         [SourceDiagnosticOccurrence identity]
         [object [field "kind" "\"source\"", field "source" encodedSource]])
    [ (ModelRole, "model")
    , (SupplementalRole, "supplemental")
    , (ReadinessRole, "readiness")
    , (AssessmentRole, "assessment")
    ]

adapterLocationEncoding :: Assertion
adapterLocationEncoding = do
  identity <- sourceIdentity
  lineColumn <- requireRight (nativeLineColumn 2 3)
  path <- requireRight (nativePath ("root" :| ["child"]))
  let source = sourceBytes identity
      cases =
        [ (unlocatedOccurrence, "null")
        , ( locatedOccurrence (nativeByteOffset 7)
          , object [field "kind" "\"byte-offset\"", field "offset" "7"])
        , ( locatedOccurrence lineColumn
          , object
              [ field "kind" "\"line-column\""
              , field "line" "2"
              , field "column" "3"
              ])
        , ( locatedOccurrence path
          , object
              [ field "kind" "\"path\""
              , field "steps" (array ["\"root\"", "\"child\""])
              ])
        ]
      occurrenceBytes location =
        object
          [ field "kind" "\"native\""
          , field "source" source
          , field "location" location
          ]
  assertOccurrenceEncodings
    (fmap (AdapterDiagnosticOccurrence identity . fst) cases)
    (fmap (occurrenceBytes . snd) cases)

canonicalKindEncoding :: Assertion
canonicalKindEncoding = do
  identity <- sourceIdentity
  occurrences <- canonicalOccurrenceAlternatives
  let source = sourceBytes identity
      occurrenceBytes kind =
        object
          [ field "kind" "\"canonical\""
          , field "source" source
          , field
              "occurrence"
              (object [field "kind" (quoted kind), field "ordinal" "0"])
          ]
  assertOccurrenceEncodings
    (fmap (CanonicalDiagnosticOccurrence identity) occurrences)
    (fmap occurrenceBytes ["record", "property", "reference"])

draftLocationEncoding :: Assertion
draftLocationEncoding = do
  identity <- sourceIdentity
  let cases =
        [ (testLocation, testLocationBytes)
        , (spannedTestLocation, spannedTestLocationBytes)
        ]
      source = sourceBytes identity
      occurrenceBytes location =
        object
          [ field "kind" "\"draft\""
          , field "source" source
          , field "location" location
          ]
  assertOccurrenceEncodings
    (fmap (DraftDiagnosticOccurrence identity . fst) cases)
    (fmap (occurrenceBytes . snd) cases)

provenanceRejection :: Assertion
provenanceRejection = do
  occurrence <- sourceOccurrence
  let bytes =
        canonicalFragmentBytes
          (diagnosticFragment
             (diagnostic
                errorSeverity
                modelFinding
                operationProvenance
                occurrence))
      rejected =
        [ replaceOnce "\"owner\":\"operation\"" "\"owner\":\"unknown\"" bytes
        , replaceOnce "\"owner\":\"operation\"" "\"owner\":\"adapter\"" bytes
        , replaceOnce
            "\"owner\":\"operation\""
            "\"owner\":\"operation\",\"authority\":\"Core\""
            bytes
        , replaceOnce
            "\"owner\":\"operation\""
            "\"owner\":\"operation\",\"stage\":\"profile\""
            bytes
        , replaceOnce
            "\"severity\":\"error\""
            "\"code\":\"o2i.core.impossible\",\"severity\":\"error\""
            bytes
        , replaceOnce
            "\"owner\":\"operation\""
            "\"owner\":\"operation\",\"profileReference\":\"cross-owner\""
            bytes
        , replaceOnce "\"severity\":\"error\"" "\"severity\":\"fatal\"" bytes
        , replaceOnce
            "\"disposition\":\"model-finding\""
            "\"disposition\":\"unknown\""
            bytes
        ]
  mapM_ (assertDiagnosticSchema False) rejected
  assertDiagnosticSchema
    False
    (replaceOnce "\"kind\":\"source\"" "\"kind\":\"unknown\"" bytes)
  assertDiagnosticSchema
    False
    (replaceOnce "\"occurrences\":[" "\"extra\":true,\"occurrences\":[" bytes)

assertOccurrenceEncodings :: [DiagnosticOccurrence] -> [ByteString] -> Assertion
assertOccurrenceEncodings occurrences expectedOccurrences =
  case (occurrences, expectedOccurrences) of
    ([], []) -> pure ()
    (occurrence:rest, expected:expectedRest) -> do
      assertDiagnosticEncoding
        (diagnostic errorSeverity modelFinding operationProvenance occurrence)
        (diagnosticBytes
           "error"
           "model-finding"
           operationProvenanceBytes
           expected)
      assertOccurrenceEncodings rest expectedRest
    _ -> assertFailure "Occurrence fixture and expected encodings differ"

assertDiagnosticEncoding :: Diagnostic -> ByteString -> Assertion
assertDiagnosticEncoding value expected = do
  let actual = canonicalFragmentBytes (diagnosticFragment value)
  actual @?= expected
  assertDiagnosticSchema True actual

diagnostic ::
     DiagnosticSeverity
  -> DiagnosticDisposition
  -> DiagnosticProvenance
  -> DiagnosticOccurrence
  -> Diagnostic
diagnostic severity disposition provenance occurrence =
  Diagnostic severity disposition provenance (occurrence :| [])

diagnosticBytes ::
     ByteString -> ByteString -> ByteString -> ByteString -> ByteString
diagnosticBytes severity disposition provenance occurrence =
  object
    [ field "severity" (quoted severity)
    , field "disposition" (quoted disposition)
    , field "provenance" provenance
    , field "occurrences" (array [occurrence])
    ]

operationProvenance :: DiagnosticProvenance
operationProvenance = OperationDiagnosticProvenance operationRule

operationProvenanceBytes :: ByteString
operationProvenanceBytes =
  object
    [ field "owner" "\"operation\""
    , field "ruleId" "\"bootstrap.profile-adapter.adapter-id\""
    ]

sourceOccurrence :: IO DiagnosticOccurrence
sourceOccurrence = fst <$> sourceOccurrenceFixture

sourceOccurrenceFixture :: IO (DiagnosticOccurrence, ByteString)
sourceOccurrenceFixture = do
  identity <- sourceIdentity
  pure
    ( SourceDiagnosticOccurrence identity
    , object [field "kind" "\"source\"", field "source" (sourceBytes identity)])

typedOccurrences :: IO (NonEmpty DiagnosticOccurrence)
typedOccurrences = do
  identifier <- requireRight (modelIdentity "subject")
  occurrenceIdentifier <- requireRight (occurrenceIdentity "record:0")
  identity <- sourceIdentity
  canonical <- canonicalOccurrence
  pure
    (SourceDiagnosticOccurrence identity
       :| [ AdapterDiagnosticOccurrence identity unlocatedOccurrence
          , DraftDiagnosticOccurrence identity testLocation
          , CanonicalDiagnosticOccurrence identity canonical
          , SubjectDiagnosticOccurrence identity identifier
          , CoreDiagnosticOccurrence identity occurrenceIdentifier
          ])

operationDiagnostic :: IO Diagnostic
operationDiagnostic = do
  identity <- sourceIdentity
  pure
    (Diagnostic
       ErrorSeverity
       ModelFinding
       (OperationDiagnosticProvenance operationRule)
       (SourceDiagnosticOccurrence identity :| []))

operationRule :: OperationRule
operationRule = NonEmpty.head (operationRuleCatalogEntries operationRuleCatalog)

profileRule :: ProfileRuleExplanation
profileRule =
  NonEmpty.head (selectedProfileRuleCatalogEntries selectedProfileRuleCatalog)

coreRule :: CoreRule
coreRule = NonEmpty.head (coreRuleCatalogEntries coreRuleCatalog)

sourceIdentity :: IO SourceIdentity
sourceIdentity = sourceIdentityFor ModelRole "model"

sourceIdentityFor :: SourceRole -> Text -> IO SourceIdentity
sourceIdentityFor role referenceText =
  requireRight (mkSourceReference referenceText) >>= \reference ->
    pure (sourceIdentityFromBytes role (sourceOrdinal 0) reference modelBytes)

canonicalOccurrence :: IO Notation.CanonicalOccurrence
canonicalOccurrence = do
  occurrences <- canonicalOccurrenceAlternatives
  case occurrences of
    record:_ -> pure record
    [] ->
      assertFailure "canonical occurrence matrix did not produce a record"
        >> fail "unreachable"

canonicalOccurrenceAlternatives :: IO [Notation.CanonicalOccurrence]
canonicalOccurrenceAlternatives =
  Notation.withCanonicalDocument canonicalMatrixDraft $ \document ->
    case ( Notation.canonicalDocumentRecords document
         , Notation.canonicalDocumentProperties document
         , Notation.canonicalDocumentReferences document) of
      ([record], [property], [reference]) ->
        pure
          [ Notation.foldCanonicalRecord
              (\occurrence _ _ _ _ -> occurrence)
              record
          , Notation.canonicalPropertyOccurrence property
          , Notation.canonicalReferenceOccurrence reference
          ]
      _ ->
        assertFailure "canonical occurrence matrix is not one-of-each"
          >> fail "unreachable"

canonicalMatrixDraft :: Draft.ProfileDraft
canonicalMatrixDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [Draft.draftTextScalar "model" testLocation])
       testLocation
       [ Draft.propertyMember
           (Draft.draftProperty
              (Draft.directPropertyKey
                 [Draft.draftTextScalar "key" testLocation])
              [Draft.draftTextScalar "value" testLocation]
              testLocation
              [])
       , Draft.referenceMember
           (Draft.propertyDefinitionReference
              (Draft.draftIdentity
                 [Draft.draftTextScalar "definition" testLocation])
              testLocation)
       ])

testDraft :: Draft.ProfileDraft
testDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [Draft.draftTextScalar "model" testLocation])
       testLocation
       [])

testLocation :: Draft.DraftLocation
testLocation =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing "model") 0)
       [])
    Nothing

spannedTestLocation :: Draft.DraftLocation
spannedTestLocation =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep
          (Draft.draftNativeName (Just "urn:test") "element")
          2)
       [])
    (Just
       (Draft.draftSourceSpan
          (Draft.draftSourcePosition 1 2 Nothing)
          (Draft.draftSourcePosition 3 4 (Just 12))))

adapterWitnessFixture ::
     Text
  -> Text
  -> IO (CompiledAdapterContract, AdapterRuleId, AdapterRuleWitness)
adapterWitnessFixture adapterIdentity ruleIdentity =
  adapterWitnessFixtureWithExpectation
    adapterIdentity
    ruleIdentity
    "expectation"

adapterWitnessFixtureWithExpectation ::
     Text
  -> Text
  -> Text
  -> IO (CompiledAdapterContract, AdapterRuleId, AdapterRuleWitness)
adapterWitnessFixtureWithExpectation adapterIdentity ruleIdentity expectation = do
  identifier <- requireRight (mkAdapterId adapterIdentity)
  descriptor <-
    requireRight (mkAdapterDescriptor identifier adapterIdentity "1" "test")
  nativeSpec <-
    requireRight
      (mkAdapterRuleSpec
         ruleIdentity
         preparationRuleStage
         expectation
         "meaning"
         "action")
  notationBindings <-
    traverse
      notationBinding
      (NonEmpty.toList Notation.allArchiMateNotationIssueKinds)
  adapter <-
    requireRight
      (compileAdapter
         descriptor
         (nativeAdapterRule nativeSpec :| notationBindings)
         (const (pure testAdapterBehavior)))
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  let contract = NonEmpty.head (adapterCollectionContracts collection)
      ruleIdentifier = adapterRuleSpecId nativeSpec
  witness <- requireRight (resolveAdapterContractRule ruleIdentifier contract)
  pure (contract, ruleIdentifier, witness)
  where
    notationBinding kind =
      archiMateNotationRule kind
        <$> requireRight
              (mkAdapterRuleSpec
                 ("notation." <> Notation.archiMateNotationIssueKindToken kind)
                 notationRuleStage
                 "expectation"
                 "meaning"
                 "action")

testAdapterBehavior :: AdapterBehavior scope
testAdapterBehavior =
  adapterBehavior (const noRecognitionMatch) (const (decodedDraft testDraft))

assertWitnessOwnerAndExpectation ::
     AdapterRuleWitness -> Text -> Text -> Assertion
assertWitnessOwnerAndExpectation witness expectedOwner expectedExpectation =
  foldAdapterRuleWitness
    (\descriptor rule -> do
       adapterIdText (adapterDescriptorId descriptor) @?= expectedOwner
       adapterRuleIdText (adapterRuleId rule) @?= "shared.native"
       adapterRuleExpectation rule @?= expectedExpectation)
    witness

assertResolutionFailure ::
     CompiledAdapterContract -> AdapterRuleId -> Text -> Assertion
assertResolutionFailure contract identifier expected =
  case resolveAdapterContractRule identifier contract of
    Left failure ->
      foldAdapterRuleResolutionFailure
        (\descriptor missing -> do
           adapterIdText (adapterDescriptorId descriptor) @?= "first"
           adapterRuleIdText missing @?= expected)
        failure
    Right _ -> assertFailure "non-member Adapter rule produced a witness"

modelBytes :: ByteString
modelBytes = "model"

sourceBytes :: SourceIdentity -> ByteString
sourceBytes = sourceBytesAs "model"

sourceBytesAs :: ByteString -> SourceIdentity -> ByteString
sourceBytesAs role identity =
  object
    [ field "role" (quoted role)
    , field "ordinal" "0"
    , field
        "reference"
        (quoted (utf8 (sourceReferenceText (sourceIdentityReference identity))))
    , field
        "sha256"
        (quoted (utf8 (sourceSha256Text (sourceIdentitySha256 identity))))
    ]

testLocationBytes :: ByteString
testLocationBytes =
  object
    [ field
        "path"
        (array
           [ object
               [ field
                   "name"
                   (object
                      [field "namespace" "null", field "localName" "\"model\""])
               , field "ordinal" "1"
               ]
           ])
    , field "span" "null"
    ]

spannedTestLocationBytes :: ByteString
spannedTestLocationBytes =
  object
    [ field
        "path"
        (array
           [ object
               [ field
                   "name"
                   (object
                      [ field "namespace" "\"urn:test\""
                      , field "localName" "\"element\""
                      ])
               , field "ordinal" "3"
               ]
           ])
    , field
        "span"
        (object
           [ field
               "start"
               (object
                  [field "line" "1", field "column" "2", field "offset" "null"])
           , field
               "end"
               (object
                  [field "line" "3", field "column" "4", field "offset" "12"])
           ])
    ]

assertDiagnosticSchema :: Bool -> ByteString -> Assertion
assertDiagnosticSchema expected bytes = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v1.schema.json")
  schema <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  document <-
    case Aeson.eitherDecodeStrict bytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  validateJSONSchema schema document @?= expected

replaceOnce :: ByteString -> ByteString -> ByteString -> ByteString
replaceOnce needle replacement value =
  case ByteString.breakSubstring needle value of
    (before, suffix)
      | ByteString.null suffix -> value
      | otherwise ->
        before
          <> replacement
          <> ByteString.drop (ByteString.length needle) suffix

field :: ByteString -> ByteString -> ByteString
field name value = quoted name <> ":" <> value

object :: [ByteString] -> ByteString
object members = "{" <> ByteString.intercalate "," members <> "}"

array :: [ByteString] -> ByteString
array entries = "[" <> ByteString.intercalate "," entries <> "]"

quoted :: ByteString -> ByteString
quoted value = "\"" <> value <> "\""

utf8 :: Text -> ByteString
utf8 = ByteString.pack . showText

showText :: Text -> String
showText = Text.unpack

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

requireJust :: String -> Maybe value -> IO value
requireJust message value =
  case value of
    Nothing -> assertFailure message >> fail "unreachable"
    Just present -> pure present
