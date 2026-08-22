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
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
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
    ]

profileOwnerEvidence :: Assertion
profileOwnerEvidence = do
  source <- modelSource
  diagnostics <-
    requireProfileResult
      (ProfileConformance.foldProfileCorpusOwnerEvidence
         (\selected universe assessment ->
            let activation =
                  profileActivationDiagnostics source selected universe
             in case assessment of
                  Nothing -> Right activation
                  Just value ->
                    foldProfileAssessmentDiagnostics
                      (const (Left "Profile contract failure"))
                      (Right . (activation <>))
                      source
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
         (structureEvidenceDiagnostic source))
  expected <- requireCoreResult CoreConformance.structureCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 12
  assertCanonicalDiagnostics diagnostics

bindingOwnerEvidence :: Assertion
bindingOwnerEvidence = do
  source <- supplementalSource
  diagnostics <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         (bindingEvidenceDiagnostic source))
  expected <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  map diagnosticRuleIdentity diagnostics @?= map coreRuleIdText expected
  length (nub (map diagnosticRuleIdentity diagnostics)) @?= 4
  assertCanonicalDiagnostics diagnostics

semanticsOwnerEvidence :: Assertion
semanticsOwnerEvidence = do
  source <- supplementalSource
  conversions <-
    requireCoreResult
      (CoreConformance.foldSemanticsCorpusOwnerEvidence
         (semanticsEvidenceDiagnostic source))
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
  source <- supplementalSource
  diagnostics <-
    requireRight
      (fmap
         concat
         (traverse
            (uncurry (integratedDiagnostics source))
            ProfileConformance.profileIntegratedBindingSources))
  generic <-
    requireCoreResult
      (CoreConformance.foldBindingCorpusOwnerEvidence
         (bindingEvidenceDiagnostic source))
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

integratedDiagnostics ::
     SourceIdentity -> Draft.ProfileDraft -> Text -> Either String [Diagnostic]
integratedDiagnostics source draft identityValue =
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
                     (bindProjection source identityValue)
                     (Profile.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

bindProjection ::
     SourceIdentity
  -> Text
  -> Profile.ProfileProjection profile document
  -> Either String [Diagnostic]
bindProjection source identityValue projection =
  Profile.withProfileStructureAssessment
    projection
    (const (Left "integrated identity-index failure"))
    (const (Left "integrated selected-scope failure"))
    (const (Left "integrated Structure-input failure"))
    (Structure.foldStructureAssessment
       (const (Left "integrated Structure rejection"))
       (\graph -> do
          decoded <-
            mapLeft
              (const "integrated supplemental decode failure")
              (Binding.decodeSupplementalInput
                 (Binding.supplementalInputOrdinal 0)
                 (strategyPayload identityValue))
          inputSet <-
            mapLeft
              (const "integrated supplemental set failure")
              (Binding.assessSupplementalInputSet [decoded])
          let binding = Binding.bindSupplementalInputs graph inputSet
          pure
            (Binding.foldSupplementalBinding
               (\_ evidence ->
                  map (bindingEvidenceDiagnostic source binding) evidence)
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

supplementalSource :: IO SourceIdentity
supplementalSource = sourceIdentityFor SupplementalRole "supplemental"

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
