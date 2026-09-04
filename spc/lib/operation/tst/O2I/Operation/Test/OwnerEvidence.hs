{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Operation.Test.OwnerEvidence
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.Aeson.Types as AesonTypes
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (nub, sort, sortOn)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Conformance as ProfileConformance
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.ArchiMate.Profile.Resolution as Profile
import qualified O2I.Core.Conformance as CoreConformance
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , acquireSource
  , acquiredSourceIdentity
  , acquiredSupplementalSource
  , fileInput
  , foldAcquiredSupplementalSource
  )
import O2I.Operation.Acquisition.Internal (AcquiredSource(..))
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , CompiledAdapterContract
  , adapterCollectionContracts
  , notationRuleStage
  )
import O2I.Operation.Adapter.Authoring
  ( adapterBehavior
  , archiMateNotationRule
  , compileAdapter
  , compileAdapterCollection
  , decodedDraft
  , mkAdapterDescriptor
  , mkAdapterId
  , mkAdapterRuleSpec
  , noRecognitionMatch
  )
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
  ( withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  )
import O2I.Operation.Diagnostic.Owner.Source.Internal
import O2I.Operation.Encoding.Internal (canonicalFragmentBytes)
import qualified O2I.Operation.Human.Diagnostic as Human
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Machine.Fragment.Internal
  ( preparedDiagnosticDocumentFragment
  )
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import O2I.Operation.Test.AdapterSupport (compileCompleteAdapter)
import qualified O2I.Semantics.Input as SemanticsInput
import qualified O2I.Structure as Structure
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "owner evidence"
    [ testCase
        "keeps exact 38-kind Notation schema closure"
        notationSchemaClosure
    , testCase
        "retains and encodes real Adapter-owned Notation evidence"
        notationOwnerEvidence
    , testCase
        "retains and encodes real Profile owner evidence"
        profileOwnerEvidence
    , testCase
        "retains and encodes real Structure evidence 12/12"
        structureOwnerEvidence
    , testCase
        "retains and encodes real generic Binding evidence 4/4"
        bindingOwnerEvidence
    , testCase
        "publicly consumes every supplemental Binding branch with its source"
        publicSupplementalConsumption
    , testCase
        "retains and encodes real Semantics evidence 27/27"
        semanticsOwnerEvidence
    , testCase
        "nests real acquired Binding evidence under its exact source"
        acquiredBindingEvidence
    , testCase
        "accumulates every decode failure and stops before later stages"
        supplementalAdmissionFailureBoundaries
    , testCase
        "accumulates high-fanout decode failures completely and canonically"
        supplementalAdmissionFailureHighFanout
    , testCase
        "binds exactly once after Structure and never after rejection"
        supplementalBindingLifecycle
    ]

notationSchemaClosure :: Assertion
notationSchemaClosure = do
  actual <- schemaNotationEvidenceKinds
  let expected =
        map
          (("archimate-notation-" <>) . Notation.archiMateNotationIssueKindToken)
          (NonEmpty.toList Notation.allArchiMateNotationIssueKinds)
  length actual @?= 38
  sort actual @?= sort expected

notationOwnerEvidence :: Assertion
notationOwnerEvidence = do
  descriptor <- testAdapterDescriptor
  otherIdentifier <- requireRight (mkAdapterId "other")
  otherDescriptor <-
    requireRight
      (mkAdapterDescriptor
         otherIdentifier
         "Other Adapter"
         "1.0.0"
         "archimate-3.2")
  contract <- compileTestContract descriptor
  model <- modelSource
  otherContract <- compileTestContract otherDescriptor
  swappedContract <- compileSwappedNotationContract descriptor
  Notation.withCanonicalDocument notationOwnerDraft $ \document ->
    case Notation.canonicalViews document of
      [] -> assertFailure "Notation owner source has no View"
      view:_ ->
        Profile.withSelectedArchiMateProfile
          Profile.compiledProfileDescriptor
          (\selected -> do
             let result =
                   Notation.assessArchiMateNotation
                     (Closure.deriveProfileAssessmentUniverse
                        selected
                        document
                        view)
                 issues = Notation.notationIssues result
                 authority =
                   PreparedAuthority
                     contract
                     Profile.compiledProfileDescriptor
                     model
                 mismatchedAuthority =
                   PreparedAuthority
                     otherContract
                     Profile.compiledProfileDescriptor
                     model
             assertBool
               "Notation owner source emitted no issues"
               (not (null issues))
             assertBool
               "real empty View name fields emitted no occurrence-backed multiplicity"
               (any isOccurrenceBackedViewNameMultiplicity issues)
             foldNotationAssessmentDiagnostics
               (foldAdapterNotationResolutionFailure
                  (\actual expected -> do
                     actual @?= otherDescriptor
                     expected @?= descriptor)
                  (\_ _ -> assertFailure "unexpected Notation rule failure"))
               (const (assertFailure "mismatched Notation authority accepted"))
               mismatchedAuthority
               contract
               result
             foldNotationAssessmentDiagnostics
               (foldAdapterNotationResolutionFailure
                  (\actual expected -> do
                     actual @?= descriptor
                     expected @?= descriptor)
                  (\_ _ -> assertFailure "unexpected Notation rule failure"))
               (const (assertFailure "swapped Notation authority accepted"))
               authority
               swappedContract
               result
             foldNotationAssessmentDiagnostics
               (foldAdapterNotationResolutionFailure
                  (\_ _ -> assertFailure "Notation authority mismatch")
                  (\_ _ -> assertFailure "Notation rule missing"))
               (assertNotationDiagnostics authority issues)
               authority
               contract
               result)
  where
    isOccurrenceBackedViewNameMultiplicity issue =
      Notation.archiMateNotationIssueKindToken
        (Notation.archiMateNotationIssueKind issue)
        == "view-name-multiplicity"
        && any
             (Notation.foldArchiMateNotationEvidence
                (const True)
                (\_ _ _ -> False)
                (\_ _ _ -> False))
             (NonEmpty.toList (Notation.archiMateNotationIssueEvidence issue))

assertNotationDiagnostics ::
     PreparedAuthority authority profile document
  -> [Notation.ArchiMateNotationIssue]
  -> [PreparedDiagnostic authority profile document]
  -> Assertion
assertNotationDiagnostics authority issues diagnostics = do
  length diagnostics @?= length issues
  map preparedDiagnosticRuleIdentity diagnostics
    @?= map
          (("test.notation." <>)
             . Notation.archiMateNotationIssueKindToken
             . Notation.archiMateNotationIssueKind)
          issues
  assertBool
    "a Notation diagnostic escaped the Adapter-owned branch"
    (all isNotationDiagnostic diagnostics)
  let document =
        preparedDiagnosticDocument
          authority
          diagnostics
          noSupplementalDiagnosticGroups
      encodedDocument = encodeDocument document
  humanDiagnosticFamilies document @?= replicate (length diagnostics) "notation"
  assertDocumentSchema encodedDocument
  value <- decodeDocument encodedDocument
  rows <- parseModelClassifications value
  rows
    @?= replicate
          (length diagnostics)
          ( "notation-assessment"
          , "adapter"
          , "notation"
          , "error"
          , "model-finding")
  encodedEvidence <- parseNotationEvidence value
  encodedEvidence @?= map notationIssueEvidenceValue issues
  notationRules <- parseNotationRuleInventory value
  notationRules
    @?= [ ( "archimate-notation-"
              <> Notation.archiMateNotationIssueKindToken kind
          , "test.notation." <> Notation.archiMateNotationIssueKindToken kind)
        | kind <- NonEmpty.toList Notation.allArchiMateNotationIssueKinds
        ]
  assertDocumentValueRejected (addDiagnosticRule value)
  assertDocumentValueRejected (mutateNotationDisposition value)
  assertDocumentValueRejected (mutateNotationEvidenceKind value)
  where
    isNotationDiagnostic =
      foldPreparedDiagnostic
        (const True)
        (const False)
        (const False)
        (const False)
        (const False)
        (const False)
        (const False)
        (const False)

profileOwnerEvidence :: Assertion
profileOwnerEvidence = do
  contract <- testAdapterContract
  source <- modelSource
  observed <-
    requireProfileResult
      (ProfileConformance.foldProfileCorpusOwnerEvidence $ \_ universe assessment ->
         let authority =
               PreparedAuthority
                 contract
                 Profile.compiledProfileDescriptor
                 source
             activation = profileActivationDiagnostics authority universe
             assessed =
               case assessment of
                 Nothing -> Right []
                 Just value ->
                   foldProfileAssessmentDiagnostics
                     (const (Left "Profile owner contract failure"))
                     Right
                     authority
                     value
          in do
               retained <- assessed
               let diagnostics = activation <> retained
                   document =
                     preparedDiagnosticDocument
                       authority
                       diagnostics
                       noSupplementalDiagnosticGroups
               pure
                 ( map preparedDiagnosticRuleIdentity diagnostics
                 , map preparedDiagnosticSeverity diagnostics
                 , encodeDocument document
                 , humanDiagnosticFamilies document))
  rows <- traverse requireProfileObservation observed
  let rules = concatMap (\(values, _, _, _) -> values) rows
      severities = concatMap (\(_, values, _, _) -> values) rows
      documents = map (\(_, _, value, _) -> value) rows
      humanFamilies = concatMap (\(_, _, _, values) -> values) rows
  assertBool
    "a Profile diagnostic rule escaped the owner corpus"
    (all (`elem` ProfileConformance.profileCorpusOwnerRuleIds) (nub rules))
  sort
    [rule | (rule, severity) <- zip rules severities, severity == errorSeverity]
    @?= sort ProfileConformance.profileCorpusDiagnosticRuleIds
  assertBool
    "positive Profile evidence was absent"
    (infoSeverity `elem` severities)
  length
    (nub
       (map profileEvidenceKindTag ProfileConformance.profileCorpusEvidenceKinds))
    @?= 12
  sort (nub humanFamilies)
    @?= [ "activation"
        , "profile"
        , "profile-classification"
        , "profile-invariant"
        , "profile-mapping"
        ]
  mapM_ assertDocumentSchema documents

structureOwnerEvidence :: Assertion
structureOwnerEvidence = do
  contract <- testAdapterContract
  source <- modelSource
  rows <-
    requireCoreResult
      (CoreConformance.foldStructureCorpusEvidence $ \_ evidence ->
         let authority =
               PreparedAuthority
                 contract
                 Profile.compiledProfileDescriptor
                 source
             scope = PreparedScope source
             diagnostic = structureEvidenceDiagnostic scope evidence
             document =
               preparedDiagnosticDocument
                 authority
                 [diagnostic]
                 noSupplementalDiagnosticGroups
          in ( preparedDiagnosticRuleIdentity diagnostic
             , encodeDocument document
             , humanDiagnosticFamilies document))
  expected <- requireCoreResult CoreConformance.structureCorpusRuleIds
  map firstOf3 rows @?= map coreRuleIdText expected
  length (nub (map firstOf3 rows)) @?= 12
  mapM_ (assertDocumentSchema . secondOf3) rows
  assertBool
    "a Structure diagnostic escaped its typed evidence family"
    (all (== "structure") (concatMap thirdOf3 rows))

bindingOwnerEvidence :: Assertion
bindingOwnerEvidence = do
  contract <- testAdapterContract
  model <- modelSource
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
      authority =
        PreparedAuthority contract Profile.compiledProfileDescriptor model
  rows <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         occurrence
         (\_ evidence ->
            let rule =
                  coreRuleIdText
                    (SemanticsInput.supplementalBindingDiagnosticEvidenceRule
                       evidence)
                group =
                  SupplementalDiagnosticGroups
                    [ SupplementalDiagnosticGroup
                        source
                        [SupplementalOwnerBindingEvidence evidence]
                    ]
                document = preparedDiagnosticDocument authority [] group
             in ( rule
                , encodeDocument document
                , humanDiagnosticFamilies document)))
  expected <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  map firstOf3 rows @?= map coreRuleIdText expected
  length (nub (map firstOf3 rows)) @?= 4
  mapM_
    (\document -> do
       assertDocumentSchema document
       value <- decodeDocument document
       dispositions <- parseSupplementalDispositions value
       dispositions @?= ["process-failure"])
    (map secondOf3 rows)
  sort (nub (concatMap thirdOf3 rows))
    @?= sort
          [ "supplemental-identity-ambiguous"
          , "supplemental-identity-out-of-view"
          , "supplemental-identity-unknown"
          , "supplemental-identity-wrong-type"
          ]

publicSupplementalConsumption :: Assertion
publicSupplementalConsumption = do
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
  rows <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         occurrence
         (\_ evidence ->
            let groups =
                  SupplementalDiagnosticGroups
                    [ SupplementalDiagnosticGroup
                        source
                        [SupplementalOwnerBindingEvidence evidence]
                    ]
             in foldSupplementalDiagnosticGroups consumeGroup concat groups))
  expectedRules <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  let findings = concat rows
  fmap findingRule findings @?= fmap coreRuleIdText expectedRules
  sort (nub (fmap findingBranch findings))
    @?= sort ["unknown", "ambiguous", "wrong-type", "out-of-view"]
  fmap findingSource findings @?= replicate (length findings) "supplemental"
  assertBool
    "diagnostic-retained source differs from its enclosing group source"
    (all findingSourceMatchesGroup findings)
  assertBool
    "public supplemental fold lost an instance pointer"
    (all (not . Text.null . findingPointer) findings)
  assertBool
    "public supplemental fold lost a lexical model identity"
    (all (not . Text.null . findingIdentity) findings)
  where
    consumeGroup acquired diagnostics =
      let reference =
            foldAcquiredSupplementalSource
              (sourceReferenceText
                 . sourceIdentityReference
                 . acquiredSourceIdentity)
              acquired
       in fmap (consumeDiagnostic acquired reference) diagnostics
    consumeDiagnostic groupSource reference diagnostic =
      foldSupplementalDiagnostic
        (finding groupSource reference diagnostic "unknown")
        (finding groupSource reference diagnostic "ambiguous")
        (finding groupSource reference diagnostic "wrong-type")
        (finding groupSource reference diagnostic "out-of-view")
        diagnostic
    finding groupSource reference diagnostic branch retainedSource pointer identity =
      SupplementalFinding
        reference
        (supplementalDiagnosticRuleIdentity diagnostic)
        branch
        pointer
        (modelIdentityText identity)
        (retainedSource == groupSource)

data SupplementalFinding = SupplementalFinding
  { findingSource :: !Text
  , findingRule :: !Text
  , findingBranch :: !Text
  , findingPointer :: !Text
  , findingIdentity :: !Text
  , findingSourceMatchesGroup :: !Bool
  }

semanticsOwnerEvidence :: Assertion
semanticsOwnerEvidence = do
  rows <- semanticsOwnerRows
  checkedIn <-
    LazyByteString.readFile
      ("tst" </> "fixtures" </> "semantic-diagnostic-machine-v2.jsonl")
  expected <- requireCoreResult CoreConformance.semanticsCorpusRuleIds
  map firstOf3 rows @?= map coreRuleIdText expected
  length (nub (map firstOf3 rows)) @?= 27
  mapM_ (assertDocumentSchema . secondOf3) rows
  semanticsMachineBaseline rows @?= checkedIn
  assertBool
    "a Semantics diagnostic escaped its typed evidence family"
    (all (== "semantics") (concatMap thirdOf3 rows))

semanticsOwnerRows :: IO [(Text, LazyByteString.ByteString, [Text])]
semanticsOwnerRows = do
  contract <- testAdapterContract
  source <- modelSource
  requireCoreResult
    (CoreConformance.foldSemanticsCorpusOwnerEvidence $ \_ evidence ->
       let authority =
             PreparedAuthority contract Profile.compiledProfileDescriptor source
           scope = PreparedScope source
           diagnostic = semanticsEvidenceDiagnostic scope evidence
           document =
             preparedDiagnosticDocument
               authority
               [diagnostic]
               noSupplementalDiagnosticGroups
        in ( preparedDiagnosticRuleIdentity diagnostic
           , encodeDocument document
           , humanDiagnosticFamilies document))

semanticsMachineBaseline ::
     [(Text, LazyByteString.ByteString, [Text])] -> LazyByteString.ByteString
semanticsMachineBaseline rows =
  LazyByteString.intercalate "\n" (map secondOf3 rows) <> "\n"

humanDiagnosticFamilies :: PreparedDiagnosticDocument -> [Text]
humanDiagnosticFamilies document =
  Human.foldHumanDiagnosticDocument
    (\_ diagnostics groups ->
       map diagnosticFamily diagnostics <> concatMap groupFamilies groups)
    (Human.humanDiagnosticDocument document)
  where
    groupFamilies =
      Human.foldHumanSupplementalDiagnosticGroup $ \_ diagnostics ->
        map diagnosticFamily diagnostics
    diagnosticFamily =
      Human.foldHumanDiagnostic $ \_ _ _ _ _ _ _ evidence ->
        Human.foldHumanDiagnosticEvidence
          humanNotationFamily
          humanActivationFamily
          humanProfileFamily
          humanProfileClassificationFamily
          humanProfileMappingFamily
          humanProfileInvariantFamily
          humanStructureFamily
          humanSemanticFamily
          (\_ _ _ -> "supplemental-identity-unknown")
          (\_ _ _ -> "supplemental-identity-ambiguous")
          (\_ _ _ -> "supplemental-identity-wrong-type")
          (\_ _ _ -> "supplemental-identity-out-of-view")
          evidence

humanNotationFamily :: Human.HumanNotationDiagnosticEvidence -> Text
humanNotationFamily =
  Human.foldHumanNotationDiagnosticEvidence $ \adapter rule kind subject observations ->
    consumeTag
      "notation"
      [ humanAdapter adapter
      , humanAdapterRule rule
      , humanNotationKind kind
      , humanLocation subject
      , foldMap humanNotationObservation observations
      ]

humanAdapter :: HumanValue.HumanAdapterDescriptor -> ()
humanAdapter =
  HumanValue.foldHumanAdapterDescriptor $ \identifier name version notation ->
    consumeUnit
      [identifier `seq` (), name `seq` (), version `seq` (), notation `seq` ()]

humanAdapterRule :: Human.HumanAdapterRule -> ()
humanAdapterRule =
  Human.foldHumanAdapterRule $ \identity stage expectation meaning action ->
    consumeUnit
      [ identity `seq` ()
      , Human.foldHumanAdapterRuleStage () () stage
      , expectation `seq` ()
      , meaning `seq` ()
      , action `seq` ()
      ]

humanNotationKind :: Human.HumanNotationIssueKind -> ()
humanNotationKind =
  Human.foldHumanNotationIssueKind
    (Human.foldHumanViewInventoryIssueKind (\token -> token `seq` ()))
    (Human.foldHumanProfileMarkerIssueKind (\token -> token `seq` ()))
    (Human.foldHumanSelectedUniverseIssueKind (\token -> token `seq` ()))

humanNotationObservation :: Human.HumanNotationObservation -> ()
humanNotationObservation =
  Human.foldHumanNotationObservation
    humanLocation
    (\location kind value ->
       consumeUnit
         [ humanLocation location
         , Human.foldHumanDraftValueKind
             ()
             ()
             ()
             ()
             (\token -> token `seq` ())
             kind
         , value `seq` ()
         ])
    (\location value targets ->
       consumeUnit
         [ humanLocation location
         , value `seq` ()
         , consumeUnit (map humanLocation targets)
         ])

humanLocation :: HumanValue.HumanSourceLocation -> ()
humanLocation =
  HumanValue.foldHumanSourceLocation $ \path sourceSpan ->
    consumeUnit
      [ foldMap
          (HumanValue.foldHumanSourcePathStep $ \name ordinal ->
             HumanValue.foldHumanNativeName
               (\kind value -> kind `seq` value `seq` ())
               name
               `seq` ordinal
               `seq` ())
          path
      , foldMap
          (HumanValue.foldHumanSourceSpan $ \start end ->
             humanPosition start `seq` humanPosition end)
          sourceSpan
      ]
  where
    humanPosition =
      HumanValue.foldHumanSourcePosition $ \offset line column ->
        offset `seq` line `seq` column `seq` ()

humanActivationFamily :: Human.HumanActivationDiagnosticEvidence -> Text
humanActivationFamily =
  Human.foldHumanActivationDiagnosticEvidence $ \profile digest branch rule owner trigger sources ->
    consumeTag
      "activation"
      [ profile `seq` ()
      , digest `seq` ()
      , Human.foldHumanClosureBranch () () branch
      , rule `seq` ()
      , humanCanonical owner
      , humanCanonical trigger
      , consumeUnit (map (\source -> source `seq` ()) sources)
      ]

humanProfileFamily :: Human.HumanProfileDiagnosticEvidence -> Text
humanProfileFamily =
  Human.foldHumanProfileDiagnosticEvidence
    Human.HumanProfileDiagnosticEliminator
      { Human.eliminateHumanProfileCarrierOccurrence = one
      , Human.eliminateHumanProfileClassificationOccurrence = one
      , Human.eliminateHumanProfileMetadataOwnerAndO2iPropertyOccurrences = many
      , Human.eliminateHumanProfilePropertyOccurrence = two
      , Human.eliminateHumanProfilePropertySlot =
          \rule owner slot values ->
            consumeTag
              "profile"
              [ rule `seq` ()
              , humanCanonical owner
              , slot `seq` ()
              , consumeUnit (map humanCanonical values)
              ]
      , Human.eliminateHumanProfilePropertyValue =
          \rule property value drafts ->
            consumeTag
              "profile"
              [ rule `seq` ()
              , humanCanonical property
              , humanCanonical value
              , consumeUnit (map humanDraftScalar drafts)
              ]
      , Human.eliminateHumanProfileProposalCarrierOccurrence = one
      , Human.eliminateHumanProfileProposalReferenceIncidence = three
      , Human.eliminateHumanProfileRelationshipOccurrence = one
      , Human.eliminateHumanProfileReservedPropertyOccurrence =
          \rule property owner reserved ->
            consumeTag
              "profile"
              [ rule `seq` ()
              , humanCanonical property
              , humanCanonical owner
              , reserved `seq` ()
              ]
      , Human.eliminateHumanProfileStructuredCarrierOccurrence = one
      , Human.eliminateHumanProfileStructuredIncidence = many
      }
  where
    one rule occurrence =
      consumeTag "profile" [rule `seq` (), humanCanonical occurrence]
    two rule first second =
      consumeTag
        "profile"
        [rule `seq` (), humanCanonical first, humanCanonical second]
    three rule first second remaining =
      consumeTag
        "profile"
        [ rule `seq` ()
        , humanCanonical first
        , humanCanonical second
        , consumeUnit (map humanCanonical remaining)
        ]
    many rule owner values =
      consumeTag
        "profile"
        [ rule `seq` ()
        , humanCanonical owner
        , consumeUnit (map humanCanonical values)
        ]

humanProfileClassificationFamily ::
     Human.HumanProfileClassificationDiagnosticEvidence -> Text
humanProfileClassificationFamily =
  Human.foldHumanProfileClassificationDiagnosticEvidence $ \graph qualification rule occurrence ->
    consumeTag
      "profile-classification"
      [ graph `seq` ()
      , qualification `seq` ()
      , rule `seq` ()
      , humanCanonical occurrence
      ]

humanProfileMappingFamily :: Human.HumanProfileMappingDiagnosticEvidence -> Text
humanProfileMappingFamily =
  Human.foldHumanProfileMappingDiagnosticEvidence
    (\rule occurrence mapping ->
       consumeTag
         "profile-mapping"
         [rule `seq` (), humanOccurrence occurrence, mapping `seq` ()])
    (\rule occurrence mapping source target ->
       consumeTag
         "profile-mapping"
         [ rule `seq` ()
         , humanOccurrence occurrence
         , mapping `seq` ()
         , humanOccurrence source
         , humanOccurrence target
         ])
    (\rule occurrence mapping kind ->
       consumeTag
         "profile-mapping"
         [ rule `seq` ()
         , humanOccurrence occurrence
         , mapping `seq` ()
         , humanProfileKind kind
         ])

humanProfileInvariantFamily ::
     Human.HumanProfileInvariantDiagnosticEvidence -> Text
humanProfileInvariantFamily =
  Human.foldHumanProfileInvariantDiagnosticEvidence $ \rule occurrence ->
    consumeTag "profile-invariant" [rule `seq` (), humanCanonical occurrence]

humanProfileKind :: Human.HumanProfileEvidenceKind -> ()
humanProfileKind =
  Human.foldHumanProfileEvidenceKind () () () () () () () () () () () ()

humanStructureFamily :: Human.HumanStructureDiagnosticEvidence -> Text
humanStructureFamily =
  Human.foldHumanStructureDiagnosticEvidence
    Human.HumanStructureDiagnosticEliminator
      { Human.eliminateHumanQualifiedEndpointCatalogMembership = one
      , Human.eliminateHumanContextualizationSourceCategory = two
      , Human.eliminateHumanContextualizationTargetCategory = two
      , Human.eliminateHumanContextualizationTargetOwnerCardinality = zeroMany
      , Human.eliminateHumanSemanticRelationCompatibility = three
      , Human.eliminateHumanStructuredPropositionIdentity =
          \owner source target values ->
            consumeTag
              "structure"
              [ humanOccurrence owner
              , humanOccurrence source
              , humanOccurrence target
              , consumeUnit (map humanOccurrence values)
              ]
      , Human.eliminateHumanCollectiveParticipantType = three
      , Human.eliminateHumanCollectiveParticipantCardinality =
          \owner participant ->
            consumeTag
              "structure"
              [humanOccurrence owner, foldMap humanOccurrence participant]
      , Human.eliminateHumanCollectiveParticipantUniqueness =
          \owner participants ->
            consumeTag
              "structure"
              [humanOccurrence owner, foldMap humanOccurrence participants]
      , Human.eliminateHumanCollectiveTargetType = three
      , Human.eliminateHumanCollectiveTargetCardinality = zeroMany
      , Human.eliminateHumanCollectiveTargetDistinctness =
          \owner targets ->
            consumeTag
              "structure"
              [humanOccurrence owner, foldMap humanOccurrence targets]
      }
  where
    one value = consumeTag "structure" [humanOccurrence value]
    two first second =
      consumeTag "structure" [humanOccurrence first, humanOccurrence second]
    three first second third =
      consumeTag
        "structure"
        [humanOccurrence first, humanOccurrence second, humanOccurrence third]
    zeroMany owner values =
      consumeTag
        "structure"
        [ humanOccurrence owner
        , Human.foldHumanStructureZeroOrMultipleOccurrences
            ()
            (\first second remaining ->
               consumeUnit (map humanOccurrence (first : second : remaining)))
            values
        ]

humanCanonical :: HumanValue.HumanCanonicalOccurrence -> ()
humanCanonical =
  HumanValue.foldHumanCanonicalOccurrence $ \kind ordinal ->
    HumanValue.foldHumanCanonicalOccurrenceKind () () () kind
      `seq` ordinal
      `seq` ()

humanOccurrence :: HumanValue.HumanOccurrenceIdentity -> ()
humanOccurrence =
  HumanValue.foldHumanOccurrenceIdentity (\identity -> identity `seq` ())

humanDraftScalar :: HumanValue.HumanDraftScalar -> ()
humanDraftScalar =
  HumanValue.foldHumanDraftScalar $ \value location ->
    humanScalar value `seq` humanLocation location
  where
    humanScalar =
      HumanValue.foldHumanScalarValue
        (\text -> text `seq` ())
        (\boolean -> boolean `seq` ())
        (\number -> number `seq` ())
        (HumanValue.foldHumanNativeName $ \kind name -> kind `seq` name `seq` ())
        (\kind retained -> kind `seq` retained `seq` ())

consumeTag :: Text -> [()] -> Text
consumeTag tag values = consumeUnit values `seq` tag

consumeUnit :: [()] -> ()
consumeUnit = foldr seq ()

humanSemanticFamily :: Human.HumanSemanticDiagnosticEvidence -> Text
humanSemanticFamily =
  Human.foldHumanSemanticDiagnosticEvidence
    Human.HumanSemanticDiagnosticEliminator
      { Human.eliminateHumanCollectiveAssertedCollectiveCoverage =
          \claim values -> consume [model claim, occurrences values]
      , Human.eliminateHumanCollectiveAssertedCompleteness = field
      , Human.eliminateHumanCollectiveAssertedMacroSupport =
          \claim participant first second third ->
            consume
              [ model claim
              , model participant
              , occurrences [first, second, third]
              ]
      , Human.eliminateHumanCollectiveAssertedParticipantPrimitiveSupport =
          \claim participant first second third ->
            consume
              [ model claim
              , model participant
              , occurrences [first, second, third]
              ]
      , Human.eliminateHumanCollectiveFitPairwiseCoherence = field
      , Human.eliminateHumanCollectiveFitParticipantBinding = field
      , Human.eliminateHumanCollectiveFitParticipantCompatibility = field
      , Human.eliminateHumanCollectiveFitTargetBinding = field
      , Human.eliminateHumanCollectiveFitTargetGuidingPolicy = field
      , Human.eliminateHumanCollectiveFitTargetTradeOffs = field
      , Human.eliminateHumanContextualizationAssertedDependency =
          \dependent endpoint context first second third ->
            consume
              [occurrences [dependent, endpoint, context, first, second, third]]
      , Human.eliminateHumanSituatedNeedDriverAnchoring = member
      , Human.eliminateHumanSituatedNeedDriverCardinality = one
      , Human.eliminateHumanSituatedNeedObjectiveCardinality = one
      , Human.eliminateHumanSituatedNeedObjectiveGrounding = member
      , Human.eliminateHumanSituatedNeedSurfacingSituationAnchoring = member
      , Human.eliminateHumanSituatedNeedSurfacingSituationCardinality = one
      , Human.eliminateHumanStrategyFormulationActionContributions = member
      , Human.eliminateHumanStrategyFormulationActions = fields
      , Human.eliminateHumanStrategyFormulationDiagnosis = fields
      , Human.eliminateHumanStrategyFormulationDiagnosisGrounding = pair
      , Human.eliminateHumanStrategyFormulationGuidingPolicy = fields
      , Human.eliminateHumanStrategyFormulationGuidingPolicyActions = memberPair
      , Human.eliminateHumanStrategyFormulationIntent = fields
      , Human.eliminateHumanStrategyFormulationKeyResultSubstantiation =
          memberPair
      , Human.eliminateHumanStrategyFormulationKeyResults = fields
      , Human.eliminateHumanStrategyFormulationVisionOrientation = one
      }
  where
    consume values =
      foldr (\value result -> value `seq` result) "semantics" values
    model = HumanValue.foldHumanModelIdentity (\value -> value `seq` ())
    occurrence =
      HumanValue.foldHumanOccurrenceIdentity (\value -> value `seq` ())
    occurrences values =
      foldr (\value result -> occurrence value `seq` result) () values
    one identity = consume [model identity]
    field identity value = consume [model identity, occurrence value]
    fields identity values = consume [model identity, occurrences values]
    pair identity first second =
      consume [model identity, occurrence first, occurrence second]
    member owner owned value =
      consume [model owner, model owned, occurrence value]
    memberPair owner owned first second =
      consume [model owner, model owned, occurrence first, occurrence second]

acquiredBindingEvidence :: Assertion
acquiredBindingEvidence = do
  contract <- testAdapterContract
  model <- modelSource
  first <- acquiredStrategySource
  second <- acquiredStrategySource2
  valid <- acquiredValidStrategySource
  let draft = bindingOwnerDraft
  forward <-
    requireRight
      (integratedBindingDocument contract model [first, second, valid] draft)
  reversed <-
    requireRight
      (integratedBindingDocument contract model [valid, second, first] draft)
  forward @?= reversed
  assertDocumentSchema forward
  value <- decodeDocument forward
  actual <- parseSupplementalAssociations value
  actual
    @?= [ expectedSupplementalAssociation first "unknown"
        , expectedSupplementalAssociation second "unknown-2"
        , expectedEmptySupplementalAssociation valid
        ]

supplementalAdmissionFailureBoundaries :: Assertion
supplementalAdmissionFailureBoundaries = do
  contract <- testAdapterContract
  model <- modelSource
  invalidFirst <- acquiredSupplementalBytes 0 "invalid-first" "{"
  invalidSecond <- acquiredSupplementalBytes 1 "invalid-second" "["
  let authority =
        PreparedAuthority contract Profile.compiledProfileDescriptor model
  withAdmittedOwnerSupplementalInputs
    authority
    [invalidSecond, invalidFirst]
    (const (assertFailure "valid supplemental provenance was rejected"))
    (\defects -> NonEmpty.length defects @?= 2)
    (const (assertFailure "decode failure reached set admission or Structure"))
  valid <- acquiredStrategySource
  withAdmittedOwnerSupplementalInputs
    authority
    [valid, valid]
    (\defects -> NonEmpty.length defects @?= 1)
    (const (assertFailure "provenance failure reached decode or set assessment"))
    (const (assertFailure "provenance failure reached Structure"))
  duplicateSubject <-
    acquireStrategySource
      1
      "supplemental-owner-source-duplicate-subject"
      "owner-source-strategy.json"
  withAdmittedOwnerSupplementalInputs
    authority
    [valid, duplicateSubject]
    (const (assertFailure "valid supplemental provenance was rejected"))
    (\defects -> NonEmpty.length defects @?= 1)
    (const (assertFailure "set-assessment failure reached Structure"))

supplementalAdmissionFailureHighFanout :: Assertion
supplementalAdmissionFailureHighFanout = do
  contract <- testAdapterContract
  model <- modelSource
  let fanout = 4096
      authority =
        PreparedAuthority contract Profile.compiledProfileDescriptor model
      observe ::
           [AcquiredSupplementalSource]
        -> Either Text (NonEmpty SemanticsInput.SupplementalInputDefect)
      observe candidates =
        withAdmittedOwnerSupplementalInputs
          authority
          candidates
          (const (Left "valid high-fanout provenance was rejected"))
          Right
          (const (Left "invalid high-fanout input reached set admission"))
      invalidSource ordinal =
        acquiredSupplementalBytes
          (fromIntegral ordinal)
          ("invalid-high-fanout-" <> Text.pack (show ordinal))
          "{"
  sources <- traverse invalidSource [0 .. fanout - 1]
  expectedGroups <- traverse (requireRight . observe . pure) sources
  actual <- requireRight (observe (reverse sources))
  NonEmpty.length actual @?= fanout
  NonEmpty.toList actual @?= concatMap NonEmpty.toList expectedGroups

supplementalBindingLifecycle :: Assertion
supplementalBindingLifecycle = do
  contract <- testAdapterContract
  model <- modelSource
  valid <- acquiredValidStrategySource
  counter <- newIORef 0
  let rejected =
        withIntegratedProjection
          bindingStructureRejectedDraft
          (bindProjectionOnce counter contract model [valid])
  case rejected of
    Left _ -> pure ()
    Right action ->
      action >> assertFailure "Structure rejection reached Binding"
  countAfterRejection <- readIORef counter
  countAfterRejection @?= 0
  accepted <-
    requireRight
      (withIntegratedProjection
         bindingOwnerDraft
         (bindProjectionOnce counter contract model [valid]))
  accepted
  countAfterAcceptance <- readIORef counter
  countAfterAcceptance @?= 1

integratedBindingDocument ::
     CompiledAdapterContract
  -> SourceIdentity
  -> [AcquiredSupplementalSource]
  -> Draft.ProfileDraft
  -> Either String LazyByteString.ByteString
integratedBindingDocument contract model sources draft =
  withIntegratedProjection draft (bindProjection contract model sources)

withIntegratedProjection ::
     Draft.ProfileDraft
  -> (forall profile document. Profile.ProfileProjection profile document -> Either
                                                                               String
                                                                               result)
  -> Either String result
withIntegratedProjection draft consume =
  Profile.withSelectedArchiMateProfile Profile.compiledProfileDescriptor $ \selected ->
    Notation.withCanonicalDocument draft $ \document ->
      case Notation.canonicalViews document of
        [] -> Left "integrated Profile source has no View"
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse selected document view
           in Notation.foldStageResult
                (const (Left "integrated Profile source failed Notation"))
                (\conformant ->
                   Profile.foldProfileProjectionAssessment
                     (const (Left "integrated Profile contract failure"))
                     (\evidence ->
                        Left
                          ("integrated Profile source was rejected: "
                             <> show
                                  (map
                                     Profile.profileDiagnosticRuleId
                                     (NonEmpty.toList evidence))))
                     consume
                     (Profile.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

bindProjectionOnce ::
     IORef Int
  -> CompiledAdapterContract
  -> SourceIdentity
  -> [AcquiredSupplementalSource]
  -> Profile.ProfileProjection profile document
  -> Either String (IO ())
bindProjectionOnce counter contract model sources projection =
  let authority =
        PreparedAuthority contract Profile.compiledProfileDescriptor model
   in withAdmittedOwnerSupplementalInputs
        authority
        sources
        (const (Left "supplemental provenance failure"))
        (const (Left "supplemental input failure"))
        (\admitted ->
           Profile.withProfileStructureAssessment
             projection
             (const (Left "identity-index failure"))
             (const (Left "selected-scope failure"))
             (const (Left "Structure-input failure"))
             (Structure.foldStructureAssessment
                (const (Left "Structure rejection"))
                (\graph ->
                   let scope = PreparedScope model
                    in withBoundAdmittedOwnerSupplementalInputs
                         scope
                         graph
                         admitted
                         (\binding ->
                            Right $ do
                              modifyIORef' counter (+ 1)
                              case bindingDiagnosticGroups binding of
                                SupplementalDiagnosticGroups groups ->
                                  length groups @?= length sources))))

bindProjection ::
     CompiledAdapterContract
  -> SourceIdentity
  -> [AcquiredSupplementalSource]
  -> Profile.ProfileProjection profile document
  -> Either String LazyByteString.ByteString
bindProjection contract model sources projection =
  let authority =
        PreparedAuthority contract Profile.compiledProfileDescriptor model
   in withAdmittedOwnerSupplementalInputs
        authority
        sources
        (const (Left "integrated supplemental provenance failure"))
        (const (Left "integrated supplemental input failure"))
        (\admitted ->
           Profile.withProfileStructureAssessment
             projection
             (const (Left "integrated identity-index failure"))
             (const (Left "integrated selected-scope failure"))
             (const (Left "integrated Structure-input failure"))
             (Structure.foldStructureAssessment
                (\evidence ->
                   Left
                     ("integrated Structure rejection: "
                        <> show
                             (map
                                (coreRuleIdText
                                   . Structure.structureEvidenceRule)
                                (NonEmpty.toList evidence))))
                (\graph ->
                   let scope = PreparedScope model
                    in withBoundAdmittedOwnerSupplementalInputs
                         scope
                         graph
                         admitted
                         (\binding ->
                            Right
                              (encodeDocument
                                 (preparedDiagnosticDocument
                                    authority
                                    []
                                    (bindingDiagnosticGroups binding)))))))

encodeDocument :: PreparedDiagnosticDocument -> LazyByteString.ByteString
encodeDocument =
  LazyByteString.fromStrict
    . canonicalFragmentBytes
    . preparedDiagnosticDocumentFragment

assertDocumentSchema :: LazyByteString.ByteString -> Assertion
assertDocumentSchema bytes = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v2.schema.json")
  schema <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  document <- decodeDocument bytes
  assertBool
    ("v2 schema rejected exact owner document: " <> show bytes)
    (validateJSONSchema schema document)

assertDocumentValueRejected :: Aeson.Value -> Assertion
assertDocumentValueRejected document = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v2.schema.json")
  schema <- decodeDocument schemaBytes
  assertBool
    "v2 schema accepted a forbidden Notation association"
    (not (validateJSONSchema schema document))

notationIssueEvidenceValue :: Notation.ArchiMateNotationIssue -> Aeson.Value
notationIssueEvidenceValue issue =
  Aeson.object
    [ "fields"
        Aeson..= [ Aeson.object
                     [ "role" Aeson..= ("subject" :: Text)
                     , "values"
                         Aeson..= [ draftLocationValue
                                      (Notation.archiMateNotationIssueSubject
                                         issue)
                                  ]
                     ]
                 , Aeson.object
                     [ "role" Aeson..= ("observations" :: Text)
                     , "values"
                         Aeson..= map
                                    notationObservationValue
                                    (NonEmpty.toList
                                       (Notation.archiMateNotationIssueEvidence
                                          issue))
                     ]
                 ]
    ]

notationObservationValue :: Notation.ArchiMateNotationEvidence -> Aeson.Value
notationObservationValue =
  Notation.foldArchiMateNotationEvidence
    (\location ->
       Aeson.object
         [ "kind" Aeson..= ("occurrence" :: Text)
         , "location" Aeson..= draftLocationValue location
         ])
    (\location valueKind value ->
       Aeson.object
         [ "kind" Aeson..= ("value" :: Text)
         , "location" Aeson..= draftLocationValue location
         , "valueKind" Aeson..= draftValueKindText valueKind
         , "value" Aeson..= value
         ])
    (\location value targets ->
       Aeson.object
         [ "kind" Aeson..= ("reference" :: Text)
         , "location" Aeson..= draftLocationValue location
         , "value" Aeson..= value
         , "targets" Aeson..= map draftLocationValue targets
         ])

draftValueKindText :: Draft.DraftValueKind -> Text
draftValueKindText =
  Draft.foldDraftValueKind "text" "boolean" "number" "native-name" id

draftLocationValue :: Draft.DraftLocation -> Aeson.Value
draftLocationValue location =
  Aeson.object
    [ "path"
        Aeson..= Draft.foldDraftSourcePath
                   (\first rest -> map draftPathStepValue (first : rest))
                   (Draft.draftLocationPath location)
    , "span"
        Aeson..= maybe
                   Aeson.Null
                   draftSourceSpanValue
                   (Draft.draftLocationSpan location)
    ]

draftPathStepValue :: Draft.DraftPathStep -> Aeson.Value
draftPathStepValue step =
  Aeson.object
    [ "name" Aeson..= draftNativeNameValue (Draft.draftPathStepName step)
    , "ordinal" Aeson..= Draft.draftPathStepOrdinal step
    ]

draftNativeNameValue :: Draft.DraftNativeName -> Aeson.Value
draftNativeNameValue name =
  Aeson.object
    [ "namespace" Aeson..= Draft.draftNativeNamespace name
    , "localName" Aeson..= Draft.draftNativeLocalName name
    ]

draftSourceSpanValue :: Draft.DraftSourceSpan -> Aeson.Value
draftSourceSpanValue sourceSpan =
  Aeson.object
    [ "start"
        Aeson..= draftSourcePositionValue (Draft.draftSpanStart sourceSpan)
    , "end" Aeson..= draftSourcePositionValue (Draft.draftSpanEnd sourceSpan)
    ]

draftSourcePositionValue :: Draft.DraftSourcePosition -> Aeson.Value
draftSourcePositionValue position =
  Aeson.object
    [ "line" Aeson..= Draft.draftSourceLine position
    , "column" Aeson..= Draft.draftSourceColumn position
    , "offset" Aeson..= Draft.draftSourceOffset position
    ]

addDiagnosticRule :: Aeson.Value -> Aeson.Value
addDiagnosticRule =
  mutateFirstModelDiagnostic
    (AesonKeyMap.insert "ruleId" (Aeson.String "totally.wrong.rule"))

mutateNotationDisposition :: Aeson.Value -> Aeson.Value
mutateNotationDisposition =
  mutateFirstModelDiagnostic
    (AesonKeyMap.insert "disposition" (Aeson.String "process-failure"))

mutateNotationEvidenceKind :: Aeson.Value -> Aeson.Value
mutateNotationEvidenceKind =
  mutateModelDiagnostics $ \diagnostic ->
    case AesonKeyMap.lookup "evidenceKind" diagnostic of
      Just (Aeson.String "archimate-notation-view-name-multiplicity") ->
        AesonKeyMap.insert
          "evidenceKind"
          (Aeson.String "archimate-notation-view-name-missing")
          diagnostic
      _ -> diagnostic

mutateFirstModelDiagnostic ::
     (Aeson.Object -> Aeson.Object) -> Aeson.Value -> Aeson.Value
mutateFirstModelDiagnostic mutate =
  mutateModelDiagnosticsOnce $ \diagnostics ->
    case diagnostics of
      Aeson.Object first:rest -> Aeson.Object (mutate first) : rest
      _ -> diagnostics

mutateModelDiagnostics ::
     (Aeson.Object -> Aeson.Object) -> Aeson.Value -> Aeson.Value
mutateModelDiagnostics mutate =
  mutateModelDiagnosticsOnce
    (map $ \diagnostic ->
       case diagnostic of
         Aeson.Object value -> Aeson.Object (mutate value)
         _ -> diagnostic)

mutateModelDiagnosticsOnce ::
     ([Aeson.Value] -> [Aeson.Value]) -> Aeson.Value -> Aeson.Value
mutateModelDiagnosticsOnce mutate documentValue =
  case documentValue of
    Aeson.Object document ->
      case AesonKeyMap.lookup "modelDiagnostics" document of
        Just diagnostics ->
          case Aeson.fromJSON diagnostics of
            Aeson.Success values ->
              Aeson.Object
                (AesonKeyMap.insert
                   "modelDiagnostics"
                   (Aeson.toJSON (mutate values))
                   document)
            Aeson.Error _ -> documentValue
        _ -> documentValue
    _ -> documentValue

decodeDocument :: LazyByteString.ByteString -> IO Aeson.Value
decodeDocument bytes =
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

parseModelClassifications :: Aeson.Value -> IO [(Text, Text, Text, Text, Text)]
parseModelClassifications documentValue =
  case AesonTypes.parseEither parser documentValue of
    Left message -> assertParseFailure message
    Right rows -> pure rows
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        diagnostics <- document Aeson..: "modelDiagnostics"
        traverse classification diagnostics
    classification =
      Aeson.withObject "model diagnostic" $ \diagnostic ->
        (,,,,)
          <$> diagnostic Aeson..: "producer"
          <*> diagnostic Aeson..: "owner"
          <*> diagnostic Aeson..: "stage"
          <*> diagnostic Aeson..: "severity"
          <*> diagnostic Aeson..: "disposition"

parseNotationEvidence :: Aeson.Value -> IO [Aeson.Value]
parseNotationEvidence documentValue =
  case AesonTypes.parseEither parser documentValue of
    Left message -> assertParseFailure message
    Right evidence -> pure evidence
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        diagnostics <- document Aeson..: "modelDiagnostics"
        traverse
          (Aeson.withObject "Notation diagnostic" (Aeson..: "evidence"))
          diagnostics

parseNotationRuleInventory :: Aeson.Value -> IO [(Text, Text)]
parseNotationRuleInventory documentValue =
  case AesonTypes.parseEither parser documentValue of
    Left message -> assertParseFailure message
    Right rules -> pure rules
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        authority <- document Aeson..: "authority"
        Aeson.withObject "prepared authority" parseRules authority
    parseRules authority = do
      rules <- authority Aeson..: "notationRules"
      traverse
        (Aeson.withObject "Notation rule binding" $ \binding ->
           (,) <$> binding Aeson..: "evidenceKind" <*> binding Aeson..: "ruleId")
        rules

parseSupplementalDispositions :: Aeson.Value -> IO [Text]
parseSupplementalDispositions documentValue =
  case AesonTypes.parseEither parser documentValue of
    Left message -> assertParseFailure message
    Right dispositions -> pure dispositions
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        sources <- document Aeson..: "supplementalSources"
        concat
          <$> traverse sourceDispositions (map snd (AesonKeyMap.toList sources))
    sourceDispositions =
      Aeson.withObject "supplemental source" $ \source -> do
        diagnostics <- source Aeson..: "diagnostics"
        traverse
          (Aeson.withObject "binding diagnostic" (Aeson..: "disposition"))
          diagnostics

schemaNotationEvidenceKinds :: IO [Text]
schemaNotationEvidenceKinds = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v2.schema.json")
  schema <- decodeDocument schemaBytes
  case AesonTypes.parseEither parser schema of
    Left message -> assertParseFailure message
    Right values -> pure values
  where
    parser =
      Aeson.withObject "diagnostic schema" $ \schema -> do
        definitions <- schema Aeson..: "$defs"
        Aeson.withObject "diagnostic definitions" modelDiagnostics definitions
    modelDiagnostics definitions = do
      diagnostic <- definitions Aeson..: "modelDiagnostic"
      Aeson.withObject "model diagnostic union" alternatives diagnostic
    alternatives diagnostic = do
      rows <- diagnostic Aeson..: "oneOf"
      catMaybes <$> traverse notationKind rows
    notationKind =
      Aeson.withObject "model diagnostic" $ \diagnostic -> do
        properties <- diagnostic Aeson..: "properties"
        Aeson.withObject "model diagnostic properties" inspect properties
    inspect properties = do
      producerSchema <- properties Aeson..: "producer"
      producer <- Aeson.withObject "producer" (Aeson..: "const") producerSchema
      if producer == ("notation-assessment" :: Text)
        then do
          evidenceSchema <- properties Aeson..: "evidenceKind"
          Just
            <$> Aeson.withObject
                  "evidence kind"
                  (Aeson..: "const")
                  evidenceSchema
        else pure Nothing

parseSupplementalAssociations :: Aeson.Value -> IO [(Text, Text, Text, [Text])]
parseSupplementalAssociations documentValue =
  case AesonTypes.parseEither parser documentValue of
    Left message -> assertParseFailure message
    Right associations -> pure associations
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        sources <- document Aeson..: "supplementalSources"
        Aeson.withObject
          "supplemental sources"
          (traverse sourceAssociation
             . sortOn (AesonKey.toText . fst)
             . AesonKeyMap.toList)
          sources
    sourceAssociation (ordinal, sourceValue) =
      Aeson.withObject "supplemental source" (sourceFields ordinal) sourceValue
    sourceFields ordinal source = do
      reference <- source Aeson..: "reference"
      digest <- source Aeson..: "sha256"
      diagnostics <- source Aeson..: "diagnostics"
      identities <- traverse diagnosticIdentity diagnostics
      pure (AesonKey.toText ordinal, reference, digest, identities)
    diagnosticIdentity =
      Aeson.withObject "binding diagnostic" $ \diagnostic -> do
        evidence <- diagnostic Aeson..: "evidence"
        Aeson.withObject "binding evidence" identityField evidence
    identityField evidence = do
      evidenceFields <-
        evidence Aeson..: "fields" :: AesonTypes.Parser [Aeson.Value]
      values <- concat <$> traverse fieldIdentities evidenceFields
      case values of
        [identity] -> pure identity
        _ -> fail "expected one Binding identity value"
    fieldIdentities =
      Aeson.withObject "binding evidence field" $ \field -> do
        role <- field Aeson..: "role"
        if role == ("identity" :: Text)
          then field Aeson..: "values"
          else pure []

expectedSupplementalAssociation ::
     AcquiredSupplementalSource -> Text -> (Text, Text, Text, [Text])
expectedSupplementalAssociation source identityText =
  foldAcquiredSupplementalSource
    (\acquired ->
       foldSourceIdentity
         (\_ ordinal reference digest ->
            ( Text.pack (show (sourceOrdinalValue ordinal))
            , sourceReferenceText reference
            , sourceSha256Text digest
            , replicate 6 identityText))
         (acquiredSourceIdentity acquired))
    source

expectedEmptySupplementalAssociation ::
     AcquiredSupplementalSource -> (Text, Text, Text, [Text])
expectedEmptySupplementalAssociation source =
  foldAcquiredSupplementalSource
    (\acquired ->
       foldSourceIdentity
         (\_ ordinal reference digest ->
            ( Text.pack (show (sourceOrdinalValue ordinal))
            , sourceReferenceText reference
            , sourceSha256Text digest
            , []))
         (acquiredSourceIdentity acquired))
    source

assertParseFailure :: String -> IO value
assertParseFailure message = assertFailure message >> fail "unreachable"

profileEvidenceKindTag :: Profile.ProfileEvidenceKind -> Int
profileEvidenceKindTag =
  Profile.foldProfileEvidenceKind 0 1 2 3 4 5 6 7 8 9 10 11

testAdapterDescriptor :: IO AdapterDescriptor
testAdapterDescriptor = do
  identifier <- requireRight (mkAdapterId "test")
  requireRight
    (mkAdapterDescriptor identifier "Test Adapter" "1.0.0" "archimate-3.2")

testAdapterContract :: IO CompiledAdapterContract
testAdapterContract = testAdapterDescriptor >>= compileTestContract

compileTestContract :: AdapterDescriptor -> IO CompiledAdapterContract
compileTestContract descriptor = do
  adapter <-
    compileCompleteAdapter descriptor [] $ \_ ->
      pure
        (adapterBehavior
           (const noRecognitionMatch)
           (const (decodedDraft notationOwnerDraft)))
  collection <- requireRight (compileAdapterCollection (adapter :| []))
  pure (NonEmpty.head (adapterCollectionContracts collection))

compileSwappedNotationContract ::
     AdapterDescriptor -> IO CompiledAdapterContract
compileSwappedNotationContract descriptor = do
  bindings <-
    traverse
      (\kind -> do
         spec <-
           requireRight
             (mkAdapterRuleSpec
                (swappedRuleIdentifier kind)
                notationRuleStage
                "expectation"
                "meaning"
                "action")
         pure (archiMateNotationRule kind spec))
      (NonEmpty.toList Notation.allArchiMateNotationIssueKinds)
  case bindings of
    firstBinding:remainingBindings -> do
      adapter <-
        requireRight
          (compileAdapter
             descriptor
             (firstBinding :| remainingBindings)
             (\_ ->
                Right
                  (adapterBehavior
                     (const noRecognitionMatch)
                     (const (decodedDraft notationOwnerDraft)))))
      collection <- requireRight (compileAdapterCollection (adapter :| []))
      pure (NonEmpty.head (adapterCollectionContracts collection))
    [] ->
      assertFailure "closed Notation inventory is empty" >> fail "unreachable"
  where
    swappedRuleIdentifier kind = "test.notation." <> swappedToken
      where
        token = Notation.archiMateNotationIssueKindToken kind
        swappedToken
          | token == "model-identity-missing" = "view-identity-missing"
          | token == "view-identity-missing" = "model-identity-missing"
          | otherwise = token

notationOwnerDraft :: Draft.ProfileDraft
notationOwnerDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (draftIdentity "model")
       (draftLocation "model")
       [ Draft.childRecordMember
           (Draft.elementDraft
              (draftIdentity "model")
              (draftLocation "duplicate-model")
              [ Draft.typeFieldMember
                  [ Draft.draftTextScalar
                      "Grouping"
                      (draftLocation "duplicate-model-type")
                  ]
                  (draftLocation "duplicate-model-type-field")
              ])
       , Draft.childRecordMember
           (Draft.viewDraft
              (draftIdentity "empty-name-view")
              (draftLocation "empty-name-view")
              [ Draft.nameFieldMember [] (draftLocation "empty-name-field-a")
              , Draft.nameFieldMember [] (draftLocation "empty-name-field-b")
              ])
       , Draft.childRecordMember
           (Draft.viewDraft
              (draftIdentity "main-view")
              (draftLocation "main-view")
              [ Draft.nameFieldMember
                  [ Draft.draftTextScalar
                      "Main"
                      (draftLocation "main-view-name")
                  , Draft.draftTextScalar
                      "Alternate"
                      (draftLocation "main-view-name-alternate")
                  ]
                  (draftLocation "main-view-name-field")
              ])
       ])

bindingOwnerDraft :: Draft.ProfileDraft
bindingOwnerDraft = bindingOwnerDraftWithOwnership True

bindingStructureRejectedDraft :: Draft.ProfileDraft
bindingStructureRejectedDraft = bindingOwnerDraftWithOwnership False

bindingOwnerDraftWithOwnership :: Bool -> Draft.ProfileDraft
bindingOwnerDraftWithOwnership includeOwnership =
  Draft.profileDraft
    (Draft.modelRootDraft
       (draftIdentity "model")
       (draftLocation "model")
       (draftPropertyMember
          "model-profile"
          "o2i.profile"
          "o2i.archimate-profile@0.3"
          : map
              (Draft.childRecordMember . uncurry3 bindingElement)
              [ ("strategy", "Grouping", "Strategy")
              , ("driver", "Driver", "Driver")
              , ("objective", "Goal", "Objective")
              , ("principle", "Principle", "Principle")
              , ("action", "CourseOfAction", "Action")
              , ("key-result", "Outcome", "KeyResult")
              ]
              <> (if includeOwnership
                    then map
                           (Draft.childRecordMember . bindingOwnership)
                           bindingPrimitiveTargets
                    else [])
              <> [ Draft.childRecordMember
                     (Draft.viewDraft
                        (draftIdentity "binding-view")
                        (draftLocation "binding-view")
                        (Draft.nameFieldMember
                           [ Draft.draftTextScalar
                               "Binding"
                               (draftLocation "binding-view-name")
                           ]
                           (draftLocation "binding-view-name-field")
                           : map
                               (Draft.childRecordMember . bindingViewNode)
                               [ "strategy"
                               , "driver"
                               , "objective"
                               , "principle"
                               , "action"
                               , "key-result"
                               ]
                               <> (if includeOwnership
                                     then map
                                            (Draft.childRecordMember
                                               . bindingViewConnection)
                                            bindingPrimitiveTargets
                                     else [])))
                 ]))

bindingPrimitiveTargets :: [Text]
bindingPrimitiveTargets =
  ["driver", "objective", "principle", "action", "key-result"]

bindingElement :: Text -> Text -> Text -> Draft.ElementDraft
bindingElement identifier archiMateType o2iType =
  Draft.elementDraft
    (draftIdentity identifier)
    (draftLocation identifier)
    [ Draft.typeFieldMember
        [ Draft.draftTextScalar
            archiMateType
            (draftLocation (identifier <> "-archimate-type"))
        ]
        (draftLocation (identifier <> "-archimate-type-field"))
    , draftPropertyMember (identifier <> "-type") "o2i.type" o2iType
    , draftPropertyMember
        (identifier <> "-commitment")
        "o2i.commitment"
        "asserted"
    ]

bindingViewNode :: Text -> Draft.ViewNodeDraft
bindingViewNode target =
  Draft.viewNodeDraft
    (draftIdentity (target <> "-node"))
    (draftLocation (target <> "-node"))
    [ Draft.referenceMember
        (Draft.viewNodeElementReference
           (draftIdentity target)
           (draftLocation (target <> "-node-element")))
    ]

bindingOwnership :: Text -> Draft.RelationshipDraft
bindingOwnership target =
  Draft.relationshipDraft
    (draftIdentity ("owns-" <> target))
    (draftLocation ("owns-" <> target))
    [ Draft.typeFieldMember
        [ Draft.draftTextScalar
            "CompositionRelationship"
            (draftLocation ("owns-" <> target <> "-type"))
        ]
        (draftLocation ("owns-" <> target <> "-type-field"))
    , Draft.directedFieldMember
        [ Draft.draftBooleanScalar
            False
            (draftLocation ("owns-" <> target <> "-directed"))
        ]
        (draftLocation ("owns-" <> target <> "-directed-field"))
    , Draft.nameFieldMember
        [ Draft.draftTextScalar
            "contextualizes"
            (draftLocation ("owns-" <> target <> "-name"))
        ]
        (draftLocation ("owns-" <> target <> "-name-field"))
    , Draft.referenceMember
        (Draft.relationshipSourceReference
           (draftIdentity "strategy")
           (draftLocation ("owns-" <> target <> "-source")))
    , Draft.referenceMember
        (Draft.relationshipTargetReference
           (draftIdentity target)
           (draftLocation ("owns-" <> target <> "-target")))
    , draftPropertyMember
        ("owns-" <> target <> "-commitment")
        "o2i.commitment"
        "asserted"
    ]

bindingViewConnection :: Text -> Draft.ViewConnectionDraft
bindingViewConnection target =
  Draft.viewConnectionDraft
    (draftIdentity ("owns-" <> target <> "-connection"))
    (draftLocation ("owns-" <> target <> "-connection"))
    [ Draft.referenceMember
        (Draft.viewConnectionRelationshipReference
           (draftIdentity ("owns-" <> target))
           (draftLocation ("owns-" <> target <> "-connection-relationship")))
    , Draft.referenceMember
        (Draft.viewConnectionSourceReference
           (draftIdentity "strategy-node")
           (draftLocation ("owns-" <> target <> "-connection-source")))
    , Draft.referenceMember
        (Draft.viewConnectionTargetReference
           (draftIdentity (target <> "-node"))
           (draftLocation ("owns-" <> target <> "-connection-target")))
    ]

draftPropertyMember :: Text -> Text -> Text -> Draft.DraftMember recordRole
draftPropertyMember identifier key value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey
          [Draft.draftTextScalar key (draftLocation (identifier <> "-key"))])
       [Draft.draftTextScalar value (draftLocation (identifier <> "-value"))]
       (draftLocation identifier)
       [])

uncurry3 ::
     (first -> second -> third -> result) -> (first, second, third) -> result
uncurry3 function (first, second, third) = function first second third

draftIdentity :: Text -> Draft.DraftIdentity recordRole
draftIdentity value =
  Draft.draftIdentity
    [Draft.draftTextScalar value (draftLocation (value <> "-identity"))]

draftLocation :: Text -> Draft.DraftLocation
draftLocation subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing

modelSource :: IO SourceIdentity
modelSource = sourceIdentityFor ModelRole 0 "model"

supplementalAcquiredSource :: IO AcquiredSupplementalSource
supplementalAcquiredSource = do
  identity <- sourceIdentityFor SupplementalRole 0 "supplemental"
  case acquiredSupplementalSource (AcquiredSource identity "{}") of
    Nothing -> assertFailure "supplemental role was lost" >> fail "unreachable"
    Just source -> pure source

acquiredStrategySource :: IO AcquiredSupplementalSource
acquiredStrategySource =
  acquireStrategySource
    0
    "supplemental-owner-source"
    "owner-source-strategy.json"

acquiredStrategySource2 :: IO AcquiredSupplementalSource
acquiredStrategySource2 =
  acquireStrategySource
    1
    "supplemental-owner-source-2"
    "owner-source-strategy-2.json"

acquiredValidStrategySource :: IO AcquiredSupplementalSource
acquiredValidStrategySource =
  acquireStrategySource
    2
    "supplemental-owner-source-valid"
    "owner-source-strategy-valid.json"

acquiredSupplementalBytes ::
     Natural -> Text -> ByteString -> IO AcquiredSupplementalSource
acquiredSupplementalBytes ordinal referenceText bytes = do
  reference <- requireRight (mkSourceReference referenceText)
  let identity =
        sourceIdentityFromBytes
          SupplementalRole
          (sourceOrdinal ordinal)
          reference
          bytes
  case acquiredSupplementalSource (AcquiredSource identity bytes) of
    Nothing -> assertFailure "supplemental role was lost" >> fail "unreachable"
    Just source -> pure source

acquireStrategySource ::
     Natural -> Text -> FilePath -> IO AcquiredSupplementalSource
acquireStrategySource ordinal referenceText fixture = do
  reference <- requireRight (mkSourceReference referenceText)
  input <- requireRight (fileInput reference ("tst" </> "fixtures" </> fixture))
  result <- acquireSource SupplementalRole (sourceOrdinal ordinal) input
  acquired <- requireRight result
  case acquiredSupplementalSource acquired of
    Nothing -> assertFailure "supplemental role was lost" >> fail "unreachable"
    Just source -> pure source

sourceIdentityFor :: SourceRole -> Natural -> Text -> IO SourceIdentity
sourceIdentityFor role ordinal referenceText = do
  reference <- requireRight (mkSourceReference referenceText)
  pure (sourceIdentityFromBytes role (sourceOrdinal ordinal) reference "source")

requireProfileResult ::
     ProfileConformance.ProfileConformanceResult value -> IO [value]
requireProfileResult =
  ProfileConformance.foldProfileConformanceResult
    (const (assertFailure "Profile conformance failure" >> fail "unreachable"))
    pure

requireCoreResult :: CoreConformance.CoreConformanceResult value -> IO [value]
requireCoreResult =
  CoreConformance.foldCoreConformanceResult
    (const (assertFailure "Core conformance failure" >> fail "unreachable"))
    pure

requireRight :: Show failure => Either failure value -> IO value
requireRight value =
  case value of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right result -> pure result

requireProfileObservation :: Either String value -> IO value
requireProfileObservation = requireRight

firstOf3 :: (first, second, third) -> first
firstOf3 (first, _, _) = first

secondOf3 :: (first, second, third) -> second
secondOf3 (_, second, _) = second

thirdOf3 :: (first, second, third) -> third
thirdOf3 (_, _, third) = third
