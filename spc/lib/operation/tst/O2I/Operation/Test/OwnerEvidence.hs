{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Operation.Test.OwnerEvidence
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.Aeson.Types as AesonTypes
import qualified Data.ByteString.Lazy as LazyByteString
import Data.JSON.JSONSchema (validateJSONSchema)
import Data.List (nub, sort)
import Data.Text (Text)
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Conformance as ProfileConformance
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.ArchiMate.Profile.Resolution as Profile
import qualified O2I.Core.Conformance as CoreConformance
import O2I.Core.Contract (coreRuleIdText)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , acquireSource
  , acquiredSupplementalSource
  , fileInput
  )
import O2I.Operation.Acquisition.Internal (AcquiredSource(..))
import O2I.Operation.Adapter (AdapterDescriptor)
import O2I.Operation.Adapter.Authoring (mkAdapterDescriptor, mkAdapterId)
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source (withSupplementalOwnerBinding)
import O2I.Operation.Diagnostic.Owner.Source.Internal
import O2I.Operation.Encoding.Internal (canonicalFragmentBytes)
import O2I.Operation.Machine.Fragment.Internal
  ( preparedDiagnosticDocumentFragment
  )
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
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
        "retains and encodes real Profile owner evidence"
        profileOwnerEvidence
    , testCase
        "retains and encodes real Structure evidence 12/12"
        structureOwnerEvidence
    , testCase
        "retains and encodes real generic Binding evidence 4/4"
        bindingOwnerEvidence
    , testCase
        "retains and encodes real Semantics evidence 27/27"
        semanticsOwnerEvidence
    , testCase
        "nests real acquired Binding evidence under its exact source"
        acquiredBindingEvidence
    ]

profileOwnerEvidence :: Assertion
profileOwnerEvidence = do
  adapter <- testAdapterDescriptor
  source <- modelSource
  observed <-
    requireProfileResult
      (ProfileConformance.foldProfileCorpusOwnerEvidence $ \_ universe assessment ->
         let authority =
               PreparedAuthority
                 adapter
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
                     preparedDiagnosticDocument authority diagnostics []
               pure
                 ( map preparedDiagnosticRuleIdentity diagnostics
                 , map preparedDiagnosticSeverity diagnostics
                 , encodeDocument document))
  rows <- traverse requireProfileObservation observed
  let rules = concatMap firstOf3 rows
      severities = concatMap secondOf3 rows
      documents = map thirdOf3 rows
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
  mapM_ assertDocumentSchema documents

structureOwnerEvidence :: Assertion
structureOwnerEvidence = do
  adapter <- testAdapterDescriptor
  source <- modelSource
  rows <-
    requireCoreResult
      (CoreConformance.foldStructureCorpusEvidence $ \_ evidence ->
         let authority =
               PreparedAuthority
                 adapter
                 Profile.compiledProfileDescriptor
                 source
             scope = PreparedScope source
             diagnostic = structureEvidenceDiagnostic scope evidence
             document = preparedDiagnosticDocument authority [diagnostic] []
          in ( preparedDiagnosticRuleIdentity diagnostic
             , encodeDocument document))
  expected <- requireCoreResult CoreConformance.structureCorpusRuleIds
  map fst rows @?= map coreRuleIdText expected
  length (nub (map fst rows)) @?= 12
  mapM_ (assertDocumentSchema . snd) rows

bindingOwnerEvidence :: Assertion
bindingOwnerEvidence = do
  adapter <- testAdapterDescriptor
  model <- modelSource
  source <- supplementalAcquiredSource
  let occurrence = SupplementalOwnerOccurrence source
      authority =
        PreparedAuthority adapter Profile.compiledProfileDescriptor model
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
                  SupplementalDiagnosticGroup
                    source
                    [SupplementalOwnerBindingEvidence source evidence]
                document = preparedDiagnosticDocument authority [] [group]
             in (rule, encodeDocument document)))
  expected <- requireCoreResult CoreConformance.bindingCorpusRuleIds
  map fst rows @?= map coreRuleIdText expected
  length (nub (map fst rows)) @?= 4
  mapM_ (assertDocumentSchema . snd) rows

semanticsOwnerEvidence :: Assertion
semanticsOwnerEvidence = do
  adapter <- testAdapterDescriptor
  source <- modelSource
  rows <-
    requireCoreResult
      (CoreConformance.foldSemanticsCorpusOwnerEvidence $ \_ evidence ->
         let authority =
               PreparedAuthority
                 adapter
                 Profile.compiledProfileDescriptor
                 source
             scope = PreparedScope source
             diagnostic = semanticsEvidenceDiagnostic scope evidence
             document = preparedDiagnosticDocument authority [diagnostic] []
          in ( preparedDiagnosticRuleIdentity diagnostic
             , encodeDocument document))
  expected <- requireCoreResult CoreConformance.semanticsCorpusRuleIds
  map fst rows @?= map coreRuleIdText expected
  length (nub (map fst rows)) @?= 27
  mapM_ (assertDocumentSchema . snd) rows

acquiredBindingEvidence :: Assertion
acquiredBindingEvidence = do
  adapter <- testAdapterDescriptor
  model <- modelSource
  supplemental <- acquiredStrategySource
  case ProfileConformance.profileIntegratedBindingSources of
    [] -> assertFailure "missing integrated Profile source"
    (draft, _):_ -> do
      bytes <-
        requireRight
          (integratedBindingDocument adapter model [supplemental] draft)
      assertDocumentSchema bytes
      value <- decodeDocument bytes
      count <- parseSupplementalDiagnosticCount value
      count @?= 6

integratedBindingDocument ::
     AdapterDescriptor
  -> SourceIdentity
  -> [AcquiredSupplementalSource]
  -> Draft.ProfileDraft
  -> Either String LazyByteString.ByteString
integratedBindingDocument adapter model sources draft =
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
                     (bindProjection adapter model sources)
                     (Profile.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

bindProjection ::
     AdapterDescriptor
  -> SourceIdentity
  -> [AcquiredSupplementalSource]
  -> Profile.ProfileProjection profile document
  -> Either String LazyByteString.ByteString
bindProjection adapter model sources projection =
  Profile.withProfileStructureAssessment
    projection
    (const (Left "integrated identity-index failure"))
    (const (Left "integrated selected-scope failure"))
    (const (Left "integrated Structure-input failure"))
    (Structure.foldStructureAssessment
       (const (Left "integrated Structure rejection"))
       (\graph ->
          let authority =
                PreparedAuthority
                  adapter
                  Profile.compiledProfileDescriptor
                  model
              scope = PreparedScope model
           in withSupplementalOwnerBinding
                scope
                sources
                graph
                (const (Left "integrated supplemental provenance failure"))
                (const (Left "integrated supplemental input failure"))
                (\binding ->
                   Right
                     (encodeDocument
                        (preparedDiagnosticDocument
                           authority
                           []
                           (bindingDiagnosticGroups binding))))))

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

decodeDocument :: LazyByteString.ByteString -> IO Aeson.Value
decodeDocument bytes =
  case Aeson.eitherDecode bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

parseSupplementalDiagnosticCount :: Aeson.Value -> IO Int
parseSupplementalDiagnosticCount value =
  case AesonTypes.parseEither parser value of
    Left message -> assertParseFailure message
    Right count -> pure count
  where
    parser =
      Aeson.withObject "prepared diagnostic document" $ \document -> do
        sources <- document Aeson..: "supplementalSources"
        Aeson.withObject
          "supplemental sources"
          (fmap sum . traverse sourceCount . AesonKeyMap.elems)
          sources
    sourceCount =
      Aeson.withObject "supplemental source" $ \source ->
        length
          <$> (source Aeson..: "diagnostics" :: AesonTypes.Parser [Aeson.Value])

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

modelSource :: IO SourceIdentity
modelSource = sourceIdentityFor ModelRole 0 "model"

supplementalAcquiredSource :: IO AcquiredSupplementalSource
supplementalAcquiredSource = do
  identity <- sourceIdentityFor SupplementalRole 0 "supplemental"
  case acquiredSupplementalSource (AcquiredSource identity "{}") of
    Nothing -> assertFailure "supplemental role was lost" >> fail "unreachable"
    Just source -> pure source

acquiredStrategySource :: IO AcquiredSupplementalSource
acquiredStrategySource = do
  reference <- requireRight (mkSourceReference "supplemental-owner-source")
  input <-
    requireRight
      (fileInput
         reference
         ("tst" </> "fixtures" </> "owner-source-strategy.json"))
  result <- acquireSource SupplementalRole (sourceOrdinal 0) input
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
