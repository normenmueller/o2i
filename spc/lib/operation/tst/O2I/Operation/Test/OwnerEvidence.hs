{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.OwnerEvidence
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Types as AesonTypes
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (maybeToList)
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
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Acquisition
  ( acquireSource
  , acquiredSourceIdentity
  , fileInput
  )
import O2I.Operation.Acquisition.Internal (AcquiredSource(..))
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source
  ( foldSupplementalOwnerBinding
  , withSupplementalOwnerBinding
  )
import O2I.Operation.Diagnostic.Owner.Source.Internal
  ( ModelOwnerSource(..)
  , ScopedModelOwnerSource(..)
  , SupplementalOwnerBinding(..)
  , SupplementalOwnerBindingEvidence(..)
  , SupplementalOwnerOccurrence(..)
  )
import O2I.Operation.Encoding.Internal (canonicalFragmentBytes)
import O2I.Operation.Machine.Fragment.Internal (diagnosticFragment)
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import qualified O2I.Semantics as Semantics
import qualified O2I.Semantics.Input as Binding
import qualified O2I.Structure as Structure
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "owner evidence"
    [ testCase
        "encodes real mixed-polar Profile evidence 126/126 and 12/12"
        profileOwnerEvidence
    , testCase "encodes real Structure evidence 12/12" structureOwnerEvidence
    , testCase "encodes real generic Binding evidence 4/4" bindingOwnerEvidence
    , testCase "encodes real Semantics evidence 27/27" semanticsOwnerEvidence
    , testCase
        "integrates reachable ArchiMate Binding 3/4 and masks ambiguity"
        integratedBindingEvidence
    , testCase
        "derives a Binding diagnostic from one exact public acquired source"
        acquiredSourceVerticalEvidence
    ]

data OwnerEncodingObservation = OwnerEncodingObservation
  { ownerEncodingSeverity :: !Text
  , ownerEncodingDisposition :: !Text
  , ownerEncodingOwner :: !Text
  , ownerEncodingProfileReference :: !(Maybe Text)
  , ownerEncodingRule :: !Text
  , ownerEncodingOccurrences :: ![OwnerOccurrenceEncoding]
  } deriving (Eq, Show)

data OwnerOccurrenceEncoding = OwnerOccurrenceEncoding
  { ownerOccurrenceKind :: !Text
  , ownerOccurrenceSource :: !SourceEncodingObservation
  , ownerOccurrenceIdentity :: !(Maybe Text)
  , ownerOccurrenceCanonical :: !(Maybe Aeson.Value)
  , ownerOccurrenceLocation :: !(Maybe Aeson.Value)
  } deriving (Eq, Show)

data SourceEncodingObservation =
  SourceEncodingObservation !Text !Natural !Text !Text
  deriving (Eq, Show)

profileOwnerEvidence :: Assertion
profileOwnerEvidence = do
  source <- modelSource
  pairs <-
    requireProfileResult
      (ProfileConformance.foldProfileCorpusOwnerEvidence
         (\selected universe assessment ->
            profileOwnerPairs source selected universe assessment))
  let expectedEncodings = map fst pairs
      diagnostics = map snd pairs
  let expected = ProfileConformance.profileCorpusOwnerRuleIds
      actual = map diagnosticRuleIdentity diagnostics
      negative =
        [ diagnosticRuleIdentity diagnostic
        | diagnostic <- diagnostics
        , diagnosticSeverity diagnostic == errorSeverity
        ]
      positive =
        [ diagnostic
        | diagnostic <- diagnostics
        , diagnosticSeverity diagnostic == infoSeverity
        ]
      evidenceKinds = ProfileConformance.profileCorpusEvidenceKinds
  sort actual @?= sort expected
  length (nub actual) @?= 126
  sort negative @?= sort ProfileConformance.profileCorpusDiagnosticRuleIds
  assertBool "positive Profile evidence was not encoded" (not (null positive))
  length positive @?= length expected
    - length ProfileConformance.profileCorpusDiagnosticRuleIds
  assertBool
    "Profile owner evidence changed disposition"
    (all ((== modelFinding) . diagnosticDisposition) diagnostics)
  length (nub (map profileEvidenceKindTag evidenceKinds)) @?= 12
  assertCanonicalDiagnostics diagnostics
  assertExactOwnerEncodings "Profile" expectedEncodings diagnostics

structureOwnerEvidence :: Assertion
structureOwnerEvidence = do
  source <- modelSource
  pairs <-
    requireCoreResult
      (CoreConformance.foldStructureCorpusEvidence
         (\_ evidence ->
            ( structureOwnerExpectation source evidence
            , structureEvidenceDiagnostic
                (ScopedModelOwnerSource source)
                evidence)))
  let expectedEncodings = map fst pairs
      diagnostics = map snd pairs
  expected <- requireCoreResult CoreConformance.structureCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 12
  assertErrorModelFindings diagnostics
  assertCanonicalDiagnostics diagnostics
  assertExactOwnerEncodings "Structure" expectedEncodings diagnostics

bindingOwnerEvidence :: Assertion
bindingOwnerEvidence = do
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
  pairs <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         occurrence
         (\binding evidence ->
            ( bindingOwnerExpectation (acquiredSourceIdentity source) evidence
            , bindingEvidenceDiagnostic
                (SupplementalOwnerBinding binding)
                (SupplementalOwnerBindingEvidence evidence))))
  let expectedEncodings = map fst pairs
      diagnostics = map snd pairs
  expected <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 4
  assertErrorModelFindings diagnostics
  assertCanonicalDiagnostics diagnostics
  assertExactOwnerEncodings "Binding" expectedEncodings diagnostics

acquiredSourceVerticalEvidence :: Assertion
acquiredSourceVerticalEvidence = do
  reference <-
    case mkSourceReference "supplemental-owner-source" of
      Left _ -> assertFailure "invalid source reference" >> fail "unreachable"
      Right value -> pure value
  input <-
    case fileInput
           reference
           ("tst" </> "fixtures" </> "owner-source-strategy.json") of
      Left _ -> assertFailure "invalid fixture path" >> fail "unreachable"
      Right value -> pure value
  acquiredResult <- acquireSource SupplementalRole (sourceOrdinal 0) input
  acquired <-
    case acquiredResult of
      Left _ -> assertFailure "fixture acquisition failed" >> fail "unreachable"
      Right value -> pure value
  case ProfileConformance.profileIntegratedBindingSources of
    [] -> assertFailure "missing integrated Profile source"
    (draft, _):_ -> do
      diagnostics <- requireRight (integratedAcquired [acquired] draft)
      length diagnostics @?= 6
      assertBool
        "unexpected owner rule escaped the vertical path"
        (all
           ((== "core.supplemental.identity.unknown") . diagnosticRuleIdentity)
           diagnostics)
      assertBool
        "diagnostic source differs from the acquired artifact"
        (all
           (== acquiredSourceIdentity acquired)
           (concatMap diagnosticOccurrenceSources diagnostics))
      assertCanonicalDiagnostics diagnostics

diagnosticOccurrenceSources :: Diagnostic -> [SourceIdentity]
diagnosticOccurrenceSources diagnostic =
  map
    (foldDiagnosticOccurrence
       id
       (\source _ -> source)
       (\source _ -> source)
       (\source _ -> source)
       (\source _ -> source)
       (\source _ -> source))
    (NonEmpty.toList (diagnosticOccurrences diagnostic))

semanticsOwnerEvidence :: Assertion
semanticsOwnerEvidence = do
  source <- modelSource
  conversions <-
    requireCoreResult
      (CoreConformance.foldSemanticsCorpusOwnerEvidence
         (\assessment evidence ->
            ( semanticsOwnerExpectation source evidence
            , semanticsEvidenceDiagnostic
                (ScopedModelOwnerSource source)
                assessment
                evidence)))
  pairs <-
    requireRight
      (traverse
         (\(expectedEncoding, conversion) ->
            foldSemanticEvidenceConversion
              (Left "semantic evidence carried no occurrence")
              (\diagnostic -> Right (expectedEncoding, diagnostic))
              conversion)
         conversions)
  let expectedEncodings = map fst pairs
      diagnostics = map snd pairs
  expected <- requireCoreResult CoreConformance.semanticsCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 27
  assertErrorModelFindings diagnostics
  assertCanonicalDiagnostics diagnostics
  assertExactOwnerEncodings "Semantics" expectedEncodings diagnostics

integratedBindingEvidence :: Assertion
integratedBindingEvidence = do
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
  diagnostics <-
    requireRight
      (fmap
         concat
         (traverse
            (uncurry (integratedDiagnostics occurrence))
            ProfileConformance.profileIntegratedBindingSources))
  generic <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         occurrence
         (\binding evidence ->
            bindingEvidenceDiagnostic
              (SupplementalOwnerBinding binding)
              (SupplementalOwnerBindingEvidence evidence)))
  let integratedRules = nub (map diagnosticRuleIdentity diagnostics)
      genericRules = nub (map diagnosticRuleIdentity generic)
      maskedRules = filter (`notElem` integratedRules) genericRules
      duplicateCases = ProfileConformance.duplicateIdentityCases
  sort integratedRules
    @?= sort
          [ "core.supplemental.identity.unknown"
          , "core.supplemental.identity.out-of-selected-view"
          , "core.supplemental.identity.wrong-type"
          ]
  maskedRules @?= ["core.supplemental.identity.ambiguous"]
  length duplicateCases @?= 56
  assertBool
    "a duplicate family pair escaped Notation masking"
    (all duplicateCaseMasksBinding duplicateCases)
  assertCanonicalDiagnostics diagnostics

integratedAcquired ::
     [AcquiredSource] -> Draft.ProfileDraft -> Either String [Diagnostic]
integratedAcquired sources draft =
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
                     (const (Left "integrated Profile source was rejected"))
                     (bindAcquiredProjection sources)
                     (Profile.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

bindAcquiredProjection ::
     [AcquiredSource]
  -> Profile.ProfileProjection profile document
  -> Either String [Diagnostic]
bindAcquiredProjection sources projection =
  Profile.withProfileStructureAssessment
    projection
    (const (Left "integrated identity-index failure"))
    (const (Left "integrated selected-scope failure"))
    (const (Left "integrated Structure-input failure"))
    (Structure.foldStructureAssessment
       (const (Left "integrated Structure rejection"))
       (\graph ->
          withSupplementalOwnerBinding
            sources
            graph
            (const (Left "integrated supplemental provenance failure"))
            (const (Left "integrated supplemental input failure"))
            (\binding ->
               Right
                 (foldSupplementalOwnerBinding
                    (\_ evidence ->
                       map (bindingEvidenceDiagnostic binding) evidence)
                    binding))))

integratedDiagnostics ::
     SupplementalOwnerOccurrence inputs
  -> Draft.ProfileDraft
  -> Text
  -> Either String [Diagnostic]
integratedDiagnostics source draft identityValue =
  case Binding.decodeSupplementalInput
         source
         (Binding.supplementalInputOrdinal 0)
         (strategyPayload identityValue) of
    Left _ -> Left "integrated supplemental decode failure"
    Right decoded -> integratedDecoded source decoded draft

integratedDecoded ::
     SupplementalOwnerOccurrence inputs
  -> Binding.SupplementalInput (SupplementalOwnerOccurrence inputs)
  -> Draft.ProfileDraft
  -> Either String [Diagnostic]
integratedDecoded source decoded draft =
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
                     (const (Left "integrated Profile source was rejected"))
                     (bindProjection source decoded)
                     (Profile.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

bindProjection ::
     SupplementalOwnerOccurrence inputs
  -> Binding.SupplementalInput (SupplementalOwnerOccurrence inputs)
  -> Profile.ProfileProjection profile document
  -> Either String [Diagnostic]
bindProjection _ decoded projection =
  Profile.withProfileStructureAssessment
    projection
    (const (Left "integrated identity-index failure"))
    (const (Left "integrated selected-scope failure"))
    (const (Left "integrated Structure-input failure"))
    (Structure.foldStructureAssessment
       (const (Left "integrated Structure rejection"))
       (\graph -> do
          inputSet <-
            mapLeft
              (const "integrated supplemental set failure")
              (Binding.assessSupplementalInputSet [decoded])
          let binding = Binding.bindSupplementalInputs graph inputSet
          pure
            (Binding.foldSupplementalBinding
               (\_ evidence ->
                  map
                    (\value ->
                       bindingEvidenceDiagnostic
                         (SupplementalOwnerBinding binding)
                         (SupplementalOwnerBindingEvidence value))
                    evidence)
               binding)))

duplicateCaseMasksBinding :: ProfileConformance.DuplicateCase -> Bool
duplicateCaseMasksBinding value =
  not (null (ProfileConformance.duplicateCaseIssueTokens value))
    && ProfileConformance.duplicateCaseAffectedOccurrences value
         >= ProfileConformance.duplicateCaseMultiplicity value
    && all
         (>= ProfileConformance.duplicateCaseMultiplicity value)
         (ProfileConformance.duplicateCaseTargetCardinalities value)

profileEvidenceKindTag :: Profile.ProfileEvidenceKind -> Int
profileEvidenceKindTag =
  Profile.foldProfileEvidenceKind 0 1 2 3 4 5 6 7 8 9 10 11

profileOwnerPairs ::
     SourceIdentity
  -> Profile.SelectedArchiMateProfile profile
  -> Closure.ProfileAssessmentUniverse profile document
  -> Maybe (Profile.ProfileProjectionAssessment profile document)
  -> Either String [(OwnerEncodingObservation, Diagnostic)]
profileOwnerPairs source selected universe assessment = do
  let ownerSource = ModelOwnerSource source
      referenceValue =
        Profile.profileDescriptorReference
          (Profile.selectedArchiMateProfileDescriptor selected)
      expectedActivation =
        concatMap
          (Closure.foldActivationProvenance
             (\_ _ _ rule owner trigger sourceRules ->
                map
                  (\ruleIdentity ->
                     profileOwnerExpectation
                       "info"
                       referenceValue
                       ruleIdentity
                       [ canonicalOccurrenceEncoding source owner
                       , canonicalOccurrenceEncoding source trigger
                       ])
                  (rule : sourceRules)))
          (Closure.assessmentActivationProvenance universe)
      actualActivation =
        profileActivationDiagnostics ownerSource selected universe
  case assessment of
    Nothing -> zipOwnerPairs expectedActivation actualActivation
    Just value -> do
      expected <-
        Profile.foldProfileProjectionAssessment
          (const (Left "Profile contract failure"))
          (Right
             . map
                 (Profile.foldProfileDiagnosticEvidence $ \rule evidence ->
                    profileOwnerExpectation
                      "error"
                      referenceValue
                      rule
                      (profileEvidenceOccurrenceEncodings source evidence))
             . NonEmpty.toList)
          (Right . positiveProfileOwnerExpectations source referenceValue)
          value
      actual <-
        foldProfileAssessmentDiagnostics
          (const (Left "Profile contract failure"))
          Right
          ownerSource
          selected
          universe
          value
      zipOwnerPairs
        (expectedActivation <> expected)
        (actualActivation <> actual)

positiveProfileOwnerExpectations ::
     SourceIdentity
  -> Text
  -> Profile.ProfileProjection profile document
  -> [OwnerEncodingObservation]
positiveProfileOwnerExpectations source referenceValue projection =
  map
    (Profile.foldProfileClassificationEvidence $ \_ _ rule occurrence ->
       profileOwnerExpectation
         "info"
         referenceValue
         rule
         [canonicalOccurrenceEncoding source occurrence])
    (Profile.profileClassificationEvidence projection)
    <> map
         (Profile.foldProfileMappingProvenance
            (\rule occurrence _ ->
               profileOwnerExpectation
                 "info"
                 referenceValue
                 rule
                 [coreOccurrenceEncoding source occurrence])
            (\rule occurrence _ sourceOccurrence targetOccurrence ->
               profileOwnerExpectation
                 "info"
                 referenceValue
                 rule
                 [ coreOccurrenceEncoding source occurrence
                 , coreOccurrenceEncoding source sourceOccurrence
                 , coreOccurrenceEncoding source targetOccurrence
                 ])
            (\rule occurrence _ ->
               profileOwnerExpectation
                 "info"
                 referenceValue
                 rule
                 [coreOccurrenceEncoding source occurrence]))
         (Profile.profileMappingProvenance projection)
    <> map
         (Profile.foldProfileInvariantEvidence $ \rule evidence ->
            profileOwnerExpectation
              "info"
              referenceValue
              rule
              (profileEvidenceOccurrenceEncodings source evidence))
         (Profile.profileQualificationInvariantEvidence projection)

profileEvidenceOccurrenceEncodings ::
     SourceIdentity
  -> Profile.ProfileEvidence profile document kind
  -> [OwnerOccurrenceEncoding]
profileEvidenceOccurrenceEncodings source =
  Profile.foldProfileEvidence
    (oneCanonical source)
    (oneCanonical source)
    (\owner properties ->
       canonicalOccurrenceEncoding source owner
         : map (canonicalOccurrenceEncoding source) properties)
    (\property owner ->
       [ canonicalOccurrenceEncoding source property
       , canonicalOccurrenceEncoding source owner
       ])
    (\owner _ properties ->
       canonicalOccurrenceEncoding source owner
         : map (canonicalOccurrenceEncoding source) properties)
    (\property owner scalars ->
       canonicalOccurrenceEncoding source property
         : canonicalOccurrenceEncoding source owner
         : map
             (draftOccurrenceEncoding source . Draft.draftScalarLocation)
             scalars)
    (oneCanonical source)
    (\occurrence proposal related ->
       canonicalOccurrenceEncoding source occurrence
         : canonicalOccurrenceEncoding source proposal
         : map (canonicalOccurrenceEncoding source) related)
    (oneCanonical source)
    (\property owner _ ->
       [ canonicalOccurrenceEncoding source property
       , canonicalOccurrenceEncoding source owner
       ])
    (oneCanonical source)
    (\occurrence related ->
       canonicalOccurrenceEncoding source occurrence
         : map (canonicalOccurrenceEncoding source) related)

oneCanonical ::
     SourceIdentity -> Notation.CanonicalOccurrence -> [OwnerOccurrenceEncoding]
oneCanonical source occurrence = [canonicalOccurrenceEncoding source occurrence]

structureOwnerExpectation ::
     SourceIdentity
  -> Structure.StructureEvidence scope
  -> OwnerEncodingObservation
structureOwnerExpectation source evidence =
  coreOwnerExpectation
    (coreRuleIdText (Structure.structureEvidenceRule evidence))
    (Structure.foldStructureEvidence eliminator evidence)
  where
    occurrence = coreOccurrenceEncoding source
    zeroOrMultiple =
      Structure.foldStructureZeroOrMultipleOccurrences
        []
        (\first second remaining -> first : second : remaining)
    eliminator =
      Structure.StructureDefectEliminator
        { Structure.eliminateQualifiedEndpointCatalogMembership =
            \value ->
              [ occurrence
                  (Structure.qualifiedEndpointCatalogMembershipSubject value)
              ]
        , Structure.eliminateContextualizationSourceCategory =
            \value ->
              [ occurrence
                  (Structure.contextualizationSourceCategorySegment value)
              , occurrence
                  (Structure.contextualizationSourceCategoryOwner value)
              ]
        , Structure.eliminateContextualizationTargetCategory =
            \value ->
              [ occurrence
                  (Structure.contextualizationTargetCategorySegment value)
              , occurrence
                  (Structure.contextualizationTargetCategoryMember value)
              ]
        , Structure.eliminateContextualizationTargetOwnerCardinality =
            \value ->
              occurrence
                (Structure.contextualizationTargetOwnerCardinalityMember value)
                : map
                    occurrence
                    (zeroOrMultiple
                       (Structure.contextualizationTargetOwnerCardinalityOwners
                          value))
        , Structure.eliminateSemanticRelationCompatibility =
            \value ->
              [ occurrence
                  (Structure.semanticRelationCompatibilityRelation value)
              , occurrence (Structure.semanticRelationCompatibilitySource value)
              , occurrence (Structure.semanticRelationCompatibilityTarget value)
              ]
        , Structure.eliminateStructuredPropositionIdentity =
            \value ->
              occurrence (Structure.structuredPropositionIdentitySubject value)
                : map
                    occurrence
                    (Structure.structuredPropositionIdentityFirstOccurrence
                       value
                       : Structure.structuredPropositionIdentitySecondOccurrence
                           value
                       : Structure.structuredPropositionIdentityRemainingOccurrences
                           value)
        , Structure.eliminateCollectiveParticipantType =
            \value ->
              [ occurrence (Structure.collectiveParticipantTypeClaim value)
              , occurrence (Structure.collectiveParticipantTypeSegment value)
              , occurrence (Structure.collectiveParticipantTypeEndpoint value)
              ]
        , Structure.eliminateCollectiveParticipantCardinality =
            \value ->
              occurrence (Structure.collectiveParticipantCardinalityClaim value)
                : map
                    occurrence
                    (maybeToList
                       (Structure.collectiveParticipantCardinalitySoleEndpoint
                          value))
        , Structure.eliminateCollectiveParticipantUniqueness =
            \value ->
              occurrence (Structure.collectiveParticipantUniquenessClaim value)
                : map
                    occurrence
                    (NonEmpty.toList
                       (Structure.collectiveParticipantUniquenessDuplicateEndpoints
                          value))
        , Structure.eliminateCollectiveTargetType =
            \value ->
              [ occurrence (Structure.collectiveTargetTypeClaim value)
              , occurrence (Structure.collectiveTargetTypeSegment value)
              , occurrence (Structure.collectiveTargetTypeEndpoint value)
              ]
        , Structure.eliminateCollectiveTargetCardinality =
            \value ->
              occurrence (Structure.collectiveTargetCardinalityClaim value)
                : map
                    occurrence
                    (zeroOrMultiple
                       (Structure.collectiveTargetCardinalityEndpoints value))
        , Structure.eliminateCollectiveTargetDistinctness =
            \value ->
              occurrence (Structure.collectiveTargetDistinctnessClaim value)
                : map
                    occurrence
                    (NonEmpty.toList
                       (Structure.collectiveTargetDistinctnessOverlappingEndpoints
                          value))
        }

bindingOwnerExpectation ::
     SourceIdentity
  -> Binding.SupplementalBindingEvidence scope provenance
  -> OwnerEncodingObservation
bindingOwnerExpectation source evidence =
  coreOwnerExpectation
    (coreRuleIdText (Binding.supplementalBindingEvidenceRule evidence))
    (Binding.foldSupplementalBindingEvidence (const eliminator) evidence)
  where
    sourceOnly = [sourceOccurrenceEncoding source]
    subject identityValue = [subjectOccurrenceEncoding source identityValue]
    eliminator =
      Binding.SupplementalInputDefectEliminator
        { Binding.eliminateSupplementalInvalidUtf8 = const sourceOnly
        , Binding.eliminateSupplementalInvalidJsonSyntax = const sourceOnly
        , Binding.eliminateSupplementalDuplicateObjectMember = const sourceOnly
        , Binding.eliminateSupplementalTopLevelObjectRequired = const sourceOnly
        , Binding.eliminateSupplementalTypeMemberInvalid = const sourceOnly
        , Binding.eliminateSupplementalPayloadTypeNotAdmitted = const sourceOnly
        , Binding.eliminateSupplementalRequiredMemberMissing = const sourceOnly
        , Binding.eliminateSupplementalUnknownMember = const sourceOnly
        , Binding.eliminateSupplementalValueKindInvalid = const sourceOnly
        , Binding.eliminateSupplementalScalarGrammarInvalid = const sourceOnly
        , Binding.eliminateSupplementalArrayCardinalityInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalArrayDistinctnessInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalSubjectCardinalityInvalid =
            subject . Binding.supplementalSubjectCardinalitySubject
        , Binding.eliminateSupplementalIdentityUnknown =
            subject . Binding.supplementalIdentityUnknownModelIdentity
        , Binding.eliminateSupplementalIdentityAmbiguous =
            subject . Binding.supplementalIdentityAmbiguousModelIdentity
        , Binding.eliminateSupplementalIdentityWrongType =
            subject . Binding.supplementalIdentityWrongTypeModelIdentity
        , Binding.eliminateSupplementalIdentityOutOfSelectedView =
            subject . Binding.supplementalIdentityOutOfViewModelIdentity
        , Binding.eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalModelIdentityContainsNul =
            const sourceOnly
        }

semanticsOwnerExpectation ::
     SourceIdentity
  -> Semantics.SemanticDiagnosticEvidence scope
  -> OwnerEncodingObservation
semanticsOwnerExpectation source evidence =
  coreOwnerExpectation
    (coreRuleIdText (Semantics.semanticDiagnosticRule evidence))
    (map
       (subjectOccurrenceEncoding source)
       (Semantics.semanticDiagnosticModelIdentities evidence)
       <> map
            (coreOccurrenceEncoding source)
            (Semantics.semanticDiagnosticOccurrenceIdentities evidence))

profileOwnerExpectation ::
     Text
  -> Text
  -> Text
  -> [OwnerOccurrenceEncoding]
  -> OwnerEncodingObservation
profileOwnerExpectation severity referenceValue rule occurrences =
  OwnerEncodingObservation
    severity
    "model-finding"
    "profile"
    (Just referenceValue)
    rule
    occurrences

coreOwnerExpectation ::
     Text -> [OwnerOccurrenceEncoding] -> OwnerEncodingObservation
coreOwnerExpectation rule occurrences =
  OwnerEncodingObservation
    "error"
    "model-finding"
    "core"
    Nothing
    rule
    occurrences

zipOwnerPairs ::
     [OwnerEncodingObservation]
  -> [Diagnostic]
  -> Either String [(OwnerEncodingObservation, Diagnostic)]
zipOwnerPairs expected actual
  | length expected == length actual = Right (zip expected actual)
  | otherwise = Left "owner expectation and diagnostic cardinality differ"

requireProfileResult ::
     ProfileConformance.ProfileConformanceResult (Either String [value])
  -> IO [value]
requireProfileResult =
  ProfileConformance.foldProfileConformanceResult
    (const (assertFailure "Profile conformance fixture failed" >> pure []))
    (requireRight . fmap concat . sequence)

requireCoreResult :: CoreConformance.CoreConformanceResult value -> IO [value]
requireCoreResult =
  CoreConformance.foldCoreConformanceResult
    (const (assertFailure "Core conformance fixture failed" >> pure []))
    pure

assertErrorModelFindings :: [Diagnostic] -> Assertion
assertErrorModelFindings diagnostics = do
  assertBool
    "owner evidence changed severity"
    (all ((== errorSeverity) . diagnosticSeverity) diagnostics)
  assertBool
    "owner evidence changed disposition"
    (all ((== modelFinding) . diagnosticDisposition) diagnostics)

assertExactOwnerEncodings ::
     Text -> [OwnerEncodingObservation] -> [Diagnostic] -> Assertion
assertExactOwnerEncodings category expected diagnostics = do
  actual <- traverse decodeOwnerEncoding diagnostics
  expected @?= actual
  assertOwnerMutationControls category expected actual

assertOwnerMutationControls ::
     Text
  -> [OwnerEncodingObservation]
  -> [OwnerEncodingObservation]
  -> Assertion
assertOwnerMutationControls category expected actual =
  case (expected, actual) of
    (representative:_, encoded:_) -> do
      let occurrences = ownerEncodingOccurrences representative
          changedOwner =
            representative
              { ownerEncodingOwner =
                  ownerEncodingOwner representative <> ".mutated"
              }
          changedReference =
            representative
              { ownerEncodingProfileReference =
                  case ownerEncodingProfileReference representative of
                    Nothing -> Just "unexpected-profile"
                    Just value -> Just (value <> ".mutated")
              }
          changedSeverity =
            representative
              { ownerEncodingSeverity =
                  if ownerEncodingSeverity representative == "error"
                    then "info"
                    else "error"
              }
          changedDisposition =
            representative {ownerEncodingDisposition = "process-failure"}
          changedRule =
            representative
              { ownerEncodingRule =
                  ownerEncodingRule representative <> ".mutated"
              }
      assertMutation category "owner" encoded changedOwner
      assertMutation category "profile reference" encoded changedReference
      assertMutation category "severity" encoded changedSeverity
      assertMutation category "disposition" encoded changedDisposition
      assertMutation category "rule" encoded changedRule
      case occurrences of
        [] ->
          assertFailure (Text.unpack category <> " owner occurrences are empty")
        first:remaining -> do
          assertMutation
            category
            "widened occurrences"
            encoded
            representative {ownerEncodingOccurrences = occurrences <> [first]}
          assertMutation
            category
            "narrowed occurrences"
            encoded
            representative {ownerEncodingOccurrences = remaining}
          assertMutation
            category
            "source substitution"
            encoded
            representative
              { ownerEncodingOccurrences =
                  mutateFirstOccurrence mutateOccurrenceSource occurrences
              }
          assertMutation
            category
            "identity substitution"
            encoded
            representative
              { ownerEncodingOccurrences =
                  mutateFirstOccurrence mutateOccurrenceIdentity occurrences
              }
      case firstReorderable expected of
        Nothing ->
          assertBool
            (Text.unpack category <> " singleton occurrence law changed")
            (all ((<= 1) . length . ownerEncodingOccurrences) expected)
        Just (reorderExpected, reorderActual) ->
          assertMutation
            category
            "reordered occurrences"
            reorderActual
            reorderExpected
              { ownerEncodingOccurrences =
                  reverse (ownerEncodingOccurrences reorderExpected)
              }
    _ -> assertFailure (Text.unpack category <> " owner corpus is empty")

assertMutation ::
     Text
  -> String
  -> OwnerEncodingObservation
  -> OwnerEncodingObservation
  -> Assertion
assertMutation category mutation actual mutated =
  assertBool
    (Text.unpack category <> " " <> mutation <> " mutation escaped")
    (actual /= mutated)

firstReorderable ::
     [OwnerEncodingObservation]
  -> Maybe (OwnerEncodingObservation, OwnerEncodingObservation)
firstReorderable expected =
  case filter reorderable expected of
    [] -> Nothing
    value:_ -> Just (value, value)
  where
    reorderable value =
      let occurrences = ownerEncodingOccurrences value
       in length occurrences > 1 && reverse occurrences /= occurrences

mutateFirstOccurrence ::
     (OwnerOccurrenceEncoding -> OwnerOccurrenceEncoding)
  -> [OwnerOccurrenceEncoding]
  -> [OwnerOccurrenceEncoding]
mutateFirstOccurrence _ [] = []
mutateFirstOccurrence mutation (first:remaining) = mutation first : remaining

mutateOccurrenceSource :: OwnerOccurrenceEncoding -> OwnerOccurrenceEncoding
mutateOccurrenceSource occurrence =
  occurrence
    { ownerOccurrenceSource =
        case ownerOccurrenceSource occurrence of
          SourceEncodingObservation role ordinal referenceValue digest ->
            SourceEncodingObservation
              role
              ordinal
              (referenceValue <> ".mutated")
              digest
    }

mutateOccurrenceIdentity :: OwnerOccurrenceEncoding -> OwnerOccurrenceEncoding
mutateOccurrenceIdentity occurrence =
  case ownerOccurrenceIdentity occurrence of
    Just identityValue ->
      occurrence {ownerOccurrenceIdentity = Just (identityValue <> ".mutated")}
    Nothing ->
      case ownerOccurrenceCanonical occurrence of
        Just _ -> occurrence {ownerOccurrenceCanonical = Just Aeson.Null}
        Nothing ->
          case ownerOccurrenceLocation occurrence of
            Just _ -> occurrence {ownerOccurrenceLocation = Just Aeson.Null}
            Nothing -> occurrence {ownerOccurrenceIdentity = Just "mutated"}

sourceOccurrenceEncoding :: SourceIdentity -> OwnerOccurrenceEncoding
sourceOccurrenceEncoding =
  ownerOccurrenceEncoding "source" Nothing Nothing Nothing

subjectOccurrenceEncoding ::
     SourceIdentity -> ModelIdentity -> OwnerOccurrenceEncoding
subjectOccurrenceEncoding source identityValue =
  ownerOccurrenceEncoding
    "subject"
    (Just (modelIdentityText identityValue))
    Nothing
    Nothing
    source

coreOccurrenceEncoding ::
     SourceIdentity -> OccurrenceIdentity -> OwnerOccurrenceEncoding
coreOccurrenceEncoding source identityValue =
  ownerOccurrenceEncoding
    "occurrence"
    (Just (occurrenceIdentityText identityValue))
    Nothing
    Nothing
    source

canonicalOccurrenceEncoding ::
     SourceIdentity -> Notation.CanonicalOccurrence -> OwnerOccurrenceEncoding
canonicalOccurrenceEncoding source occurrence =
  ownerOccurrenceEncoding
    "canonical"
    Nothing
    (Just (canonicalOccurrenceValue occurrence))
    Nothing
    source

draftOccurrenceEncoding ::
     SourceIdentity -> Draft.DraftLocation -> OwnerOccurrenceEncoding
draftOccurrenceEncoding source location =
  ownerOccurrenceEncoding
    "draft"
    Nothing
    Nothing
    (Just (draftLocationValue location))
    source

ownerOccurrenceEncoding ::
     Text
  -> Maybe Text
  -> Maybe Aeson.Value
  -> Maybe Aeson.Value
  -> SourceIdentity
  -> OwnerOccurrenceEncoding
ownerOccurrenceEncoding kind identityValue canonicalValue locationValue source =
  OwnerOccurrenceEncoding
    kind
    (expectedSourceEncoding source)
    identityValue
    canonicalValue
    locationValue

canonicalOccurrenceValue :: Notation.CanonicalOccurrence -> Aeson.Value
canonicalOccurrenceValue occurrence =
  Aeson.object
    [ "kind"
        Aeson..= Notation.foldCanonicalOccurrenceKind
                   ("record" :: Text)
                   "property"
                   "reference"
                   (Notation.canonicalOccurrenceKind occurrence)
    , "ordinal" Aeson..= Notation.canonicalOccurrenceOrdinal occurrence
    ]

draftLocationValue :: Draft.DraftLocation -> Aeson.Value
draftLocationValue location =
  Aeson.object
    [ "path"
        Aeson..= Draft.foldDraftSourcePath
                   (\first remaining ->
                      map draftPathStepValue (first : remaining))
                   (Draft.draftLocationPath location)
    , "span"
        Aeson..= fmap draftSourceSpanValue (Draft.draftLocationSpan location)
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

expectedSourceEncoding :: SourceIdentity -> SourceEncodingObservation
expectedSourceEncoding source =
  SourceEncodingObservation
    (sourceRoleEncoding (sourceIdentityRole source))
    (sourceOrdinalValue (sourceIdentityOrdinal source))
    (sourceReferenceText (sourceIdentityReference source))
    (sourceSha256Text (sourceIdentitySha256 source))

sourceRoleEncoding :: SourceRole -> Text
sourceRoleEncoding role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

decodeOwnerEncoding :: Diagnostic -> IO OwnerEncodingObservation
decodeOwnerEncoding diagnostic = do
  value <-
    case Aeson.eitherDecodeStrict
           (canonicalFragmentBytes (diagnosticFragment diagnostic)) of
      Left message -> assertFailure message >> fail "unreachable"
      Right decoded -> pure decoded
  case AesonTypes.parseEither parseOwnerEncoding value of
    Left message -> assertFailure message >> fail "unreachable"
    Right observation -> pure observation

parseOwnerEncoding :: Aeson.Value -> AesonTypes.Parser OwnerEncodingObservation
parseOwnerEncoding =
  Aeson.withObject "owner diagnostic" $ \object -> do
    severity <- object Aeson..: "severity"
    disposition <- object Aeson..: "disposition"
    provenance <- object Aeson..: "provenance"
    (owner, referenceValue, rule) <- parseOwnerProvenance provenance
    occurrences <- object Aeson..: "occurrences"
    OwnerEncodingObservation severity disposition owner referenceValue rule
      <$> traverse parseOwnerOccurrence occurrences

parseOwnerProvenance ::
     Aeson.Value -> AesonTypes.Parser (Text, Maybe Text, Text)
parseOwnerProvenance =
  Aeson.withObject "owner provenance" $ \object -> do
    owner <- object Aeson..: "owner"
    referenceValue <- object Aeson..:? "profileReference"
    rule <- object Aeson..: "ruleId"
    pure (owner, referenceValue, rule)

parseOwnerOccurrence :: Aeson.Value -> AesonTypes.Parser OwnerOccurrenceEncoding
parseOwnerOccurrence =
  Aeson.withObject "owner occurrence" $ \object -> do
    kind <- object Aeson..: "kind"
    source <- object Aeson..: "source" >>= parseSourceEncoding
    identityValue <- object Aeson..:? "identity"
    canonicalValue <- object Aeson..:? "occurrence"
    locationValue <- object Aeson..:? "location"
    pure
      (OwnerOccurrenceEncoding
         kind
         source
         identityValue
         canonicalValue
         locationValue)

parseSourceEncoding ::
     Aeson.Value -> AesonTypes.Parser SourceEncodingObservation
parseSourceEncoding =
  Aeson.withObject "source identity" $ \object ->
    SourceEncodingObservation
      <$> object Aeson..: "role"
      <*> object Aeson..: "ordinal"
      <*> object Aeson..: "reference"
      <*> object Aeson..: "sha256"

assertCanonicalDiagnostics :: [Diagnostic] -> Assertion
assertCanonicalDiagnostics diagnostics = do
  schemaBytes <-
    LazyByteString.readFile
      ("contract" </> "schema" </> "o2i.operation.diagnostic-v1.schema.json")
  schema <-
    case Aeson.eitherDecode schemaBytes of
      Left message -> assertFailure message >> fail "unreachable"
      Right value -> pure value
  mapM_
    (\diagnostic -> do
       let bytes = canonicalFragmentBytes (diagnosticFragment diagnostic)
       document <-
         case Aeson.eitherDecodeStrict bytes of
           Left message -> assertFailure message >> fail "unreachable"
           Right value -> pure value
       validateJSONSchema schema document @?= True)
    diagnostics

modelSource :: IO SourceIdentity
modelSource = sourceIdentityFor ModelRole "model"

supplementalAcquiredSource :: IO AcquiredSource
supplementalAcquiredSource = do
  identity <- sourceIdentityFor SupplementalRole "supplemental"
  pure (AcquiredSource identity sourceBytes)

sourceIdentityFor :: SourceRole -> Text -> IO SourceIdentity
sourceIdentityFor role referenceText = do
  reference <-
    case mkSourceReference referenceText of
      Left _ -> assertFailure "invalid source reference" >> fail "unreachable"
      Right value -> pure value
  pure (sourceIdentityFromBytes role (sourceOrdinal 0) reference sourceBytes)

strategyPayload :: Text -> ByteString
strategyPayload identityValue =
  ByteString.pack
    ("{\"type\":\"StrategyFormulationInput\",\"strategy\":\""
       <> text
       <> "\",\"scope\":[\"scope\"],\"anchoring\":{\"period\":\"period\",\"responsibilityScope\":\"responsibility scope\",\"decisionLevel\":\"decision level\",\"responsibilities\":[\"responsibility\"],\"decisionPaths\":[\"decision path\"],\"implementationLogic\":\"implementation logic\"},\"derivedGuardrails\":[\"guardrail\"],\"diagnosis\":\""
       <> text
       <> "\",\"intent\":\""
       <> text
       <> "\",\"guidingPolicy\":\""
       <> text
       <> "\",\"positioning\":[\"positioning\"],\"tradeOffs\":[\"trade-off\"],\"actions\":[\""
       <> text
       <> "\"],\"keyResults\":[\""
       <> text
       <> "\"],\"fitRationale\":[\"fit rationale\"]}")
  where
    text = showText identityValue

sourceBytes :: ByteString
sourceBytes = "owner-evidence"

showText :: Text -> String
showText = Text.unpack

mapLeft :: (left -> mapped) -> Either left right -> Either mapped right
mapLeft convert value =
  case value of
    Left failure -> Left (convert failure)
    Right result -> Right result

requireRight :: Either String value -> IO value
requireRight value =
  case value of
    Left message -> assertFailure message >> fail "unreachable"
    Right result -> pure result
