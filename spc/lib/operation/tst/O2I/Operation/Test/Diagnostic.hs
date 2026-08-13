{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Diagnostic
  ( tests
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.ArchiMate.Profile.Rule.Catalog
import O2I.ArchiMate.Profile.Rule.Explanation (ProfileRuleExplanation)
import O2I.Core.Identity
import O2I.Core.Rule.Catalog
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Adapter.Internal
  ( AdapterRule(..)
  , AdapterRuleId(..)
  , AdapterRuleStage(..)
  )
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import O2I.Operation.Rule.Catalog
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "diagnostic"
    [ testCase "enumerates severity and disposition" closedClassifications
    , testCase "keeps code and owning rule identity distinct" codeOwnership
    , testCase "preserves every authority" authorityCases
    , testCase "preserves every typed occurrence" occurrenceCases
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
  descriptor <- testDescriptor
  adapterRule <- testAdapterRule
  let provenances =
        [ OperationDiagnosticProvenance operationRule
        , AdapterDiagnosticProvenance descriptor adapterRule
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
      foldDiagnosticProvenance (const 0) (\_ _ -> 1) (const 2) (const 3)

occurrenceCases :: Assertion
occurrenceCases = do
  identifier <- requireRight (modelIdentity "subject")
  identity <- sourceIdentity
  canonical <- canonicalOccurrence
  value <- operationDiagnostic
  let occurrences =
        [ SourceDiagnosticOccurrence identity
        , AdapterDiagnosticOccurrence identity unlocatedOccurrence
        , DraftDiagnosticOccurrence identity testLocation
        , CanonicalDiagnosticOccurrence identity canonical
        , SubjectDiagnosticOccurrence identity identifier
        ]
  fmap occurrenceTag occurrences @?= ([0, 1, 2, 3, 4] :: [Int])
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
sourceIdentity =
  requireRight (mkSourceReference "model") >>= \reference ->
    pure
      (sourceIdentityFromBytes ModelRole (sourceOrdinal 0) reference modelBytes)

canonicalOccurrence :: IO Notation.CanonicalOccurrence
canonicalOccurrence =
  Notation.withCanonicalDocument testDraft $ \document ->
    case Notation.canonicalDocumentRecords document of
      record:_ ->
        pure
          (Notation.foldCanonicalRecord
             (\occurrence _ _ _ _ -> occurrence)
             record)
      [] ->
        assertFailure "test model root did not produce a canonical record"
          >> fail "unreachable"

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

testDescriptor :: IO AdapterDescriptor
testDescriptor = do
  identifier <- requireRight (mkAdapterId "test")
  requireRight (mkAdapterDescriptor identifier "Test" "1" "test")

testAdapterRule :: IO AdapterRule
testAdapterRule =
  pure
    AdapterRule
      { adapterRuleIdValue = AdapterRuleId "native.invalid"
      , adapterRuleStageValue = AdapterPreparationStage
      , adapterRuleExpectationValue = "expectation"
      , adapterRuleMeaningValue = "meaning"
      , adapterRuleActionValue = "action"
      }

modelBytes :: ByteString
modelBytes = "model"

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
