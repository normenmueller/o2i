{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.OwnerEvidence
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Conformance as ProfileConformance
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.ArchiMate.Profile.Resolution as Profile
import qualified O2I.Core.Conformance as CoreConformance
import O2I.Core.Contract (coreRuleIdText)
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

profileOwnerEvidence :: Assertion
profileOwnerEvidence = do
  source <- modelSource
  diagnostics <-
    requireProfileResult
      (ProfileConformance.foldProfileCorpusOwnerEvidence
         (\selected universe assessment ->
            let activation =
                  profileActivationDiagnostics
                    (ModelOwnerSource source)
                    selected
                    universe
             in case assessment of
                  Nothing -> Right activation
                  Just value ->
                    foldProfileAssessmentDiagnostics
                      (const (Left "Profile contract failure"))
                      (Right . (activation <>))
                      (ModelOwnerSource source)
                      selected
                      universe
                      value))
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
  length (nub (map profileEvidenceKindTag evidenceKinds)) @?= 12
  assertCanonicalDiagnostics diagnostics

structureOwnerEvidence :: Assertion
structureOwnerEvidence = do
  source <- modelSource
  diagnostics <-
    requireCoreResult
      (CoreConformance.foldStructureCorpusEvidence
         (\_ evidence ->
            structureEvidenceDiagnostic (ScopedModelOwnerSource source) evidence))
  expected <- requireCoreResult CoreConformance.structureCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 12
  assertCanonicalDiagnostics diagnostics

bindingOwnerEvidence :: Assertion
bindingOwnerEvidence = do
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
  diagnostics <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         occurrence
         (\binding evidence ->
            bindingEvidenceDiagnostic
              (SupplementalOwnerBinding binding)
              (SupplementalOwnerBindingEvidence evidence)))
  expected <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 4
  assertCanonicalDiagnostics diagnostics

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
            semanticsEvidenceDiagnostic
              (ScopedModelOwnerSource source)
              assessment
              evidence))
  diagnostics <-
    requireRight
      (traverse
         (foldSemanticEvidenceConversion
            (Left "semantic evidence carried no occurrence")
            Right)
         conversions)
  expected <- requireCoreResult CoreConformance.semanticsCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 27
  assertCanonicalDiagnostics diagnostics

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

requireProfileResult ::
     ProfileConformance.ProfileConformanceResult (Either String [Diagnostic])
  -> IO [Diagnostic]
requireProfileResult =
  ProfileConformance.foldProfileConformanceResult
    (const (assertFailure "Profile conformance fixture failed" >> pure []))
    (requireRight . fmap concat . sequence)

requireCoreResult :: CoreConformance.CoreConformanceResult value -> IO [value]
requireCoreResult =
  CoreConformance.foldCoreConformanceResult
    (const (assertFailure "Core conformance fixture failed" >> pure []))
    pure

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
