{-# LANGUAGE OverloadedStrings #-}

-- | End-to-end closure of persisted evidence for collective realization.
module O2I.Adapter.AMX.Test.Collective.Evidence
  ( collectiveEvidenceTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.View
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Test.Collective.Evidence.Scenario
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

collectiveEvidenceTests :: TestTree
collectiveEvidenceTests =
  testGroup
    "collective evidence closure"
    [ testCase
        "Junction scope closes persisted macro and Primitive evidence"
        collectiveEvidenceClosureTest
    , testCase
        "missing persisted contribution evidence still fails Semantics"
        missingCollectiveEvidenceTest
    , testCase
        "unrelated evidence and an unselected Claim remain isolated"
        collectiveEvidenceIsolationTest
    ]

collectiveEvidenceClosureTest :: Assertion
collectiveEvidenceClosureTest = do
  report <- inspectEvidenceModel completeCollectiveModel
  repeatedReport <- inspectEvidenceModel completeCollectiveModel
  environment <- environmentFor completeCollectiveModel
  assertStageState SemanticsStage StagePassed report
  reportMaturity report @?= Just SemanticallyValid
  renderInspectionReportJSON repeatedReport
    @?= renderInspectionReportJSON report
  assertEvidenceReason
    environment
    report
    "macro-a"
    [CollectiveRealizationContribution]
  assertEvidenceReason
    environment
    report
    "macro-b"
    [CollectiveRealizationContribution]
  assertEvidenceReason environment report "premise-a" [MacroPremise]
  assertEvidenceReason environment report "premise-b" [MacroPremise]

missingCollectiveEvidenceTest :: Assertion
missingCollectiveEvidenceTest = do
  report <- inspectEvidenceModel missingCollectiveModel
  assertStageState SemanticsStage StageFailed report
  assertBool
    "missing persisted contribution evidence must remain a semantic failure"
    ("o2i.semantics.collective.contribution-missing"
       `elem` diagnosticCodes report)

collectiveEvidenceIsolationTest :: Assertion
collectiveEvidenceIsolationTest = do
  report <- inspectEvidenceModel isolatedCollectiveModel
  environment <- environmentFor isolatedCollectiveModel
  assertStageState SemanticsStage StagePassed report
  assertOccurrenceAbsent environment report "unrelated-macro"
  assertOccurrenceAbsent environment report "unrelated-premise"
  assertNodeOccurrenceAbsent environment report "unselected-claim"

assertEvidenceReason ::
     Environment -> InspectionReport -> Text -> [InclusionReason] -> Assertion
assertEvidenceReason environment report identifier expected = do
  let occurrence =
        relationshipOccurrence
          (elementById identifier (environmentRelationships environment))
  reasonsFor occurrence (provenanceEntries report) @?= expected
  case filter
         ((== occurrence) . provenanceOccurrenceId)
         (provenanceEntries report) of
    [entry] ->
      sourceDisplayLabel (locationSource (provenanceLocation entry))
        @?= "test.archimate"
    _ -> assertFailure "expected one exact evidence provenance entry"

assertOccurrenceAbsent :: Environment -> InspectionReport -> Text -> Assertion
assertOccurrenceAbsent environment report identifier =
  assertBool
    ("unexpected reached relationship: " <> Text.unpack identifier)
    (null
       (reasonsFor
          (relationshipOccurrence
             (elementById identifier (environmentRelationships environment)))
          (provenanceEntries report)))

assertNodeOccurrenceAbsent ::
     Environment -> InspectionReport -> Text -> Assertion
assertNodeOccurrenceAbsent environment report identifier =
  assertBool
    ("unexpected reached node: " <> Text.unpack identifier)
    (null
       (reasonsFor
          (nodeOccurrence
             (elementById identifier (environmentNodes environment)))
          (provenanceEntries report)))

provenanceEntries :: InspectionReport -> [OccurrenceProvenance]
provenanceEntries report =
  maybe
    []
    (NonEmpty.toList . closedScopeProvenanceOccurrences)
    (reportClosedScopeProvenance report)

reasonsFor :: OccurrenceId -> [OccurrenceProvenance] -> [InclusionReason]
reasonsFor occurrence entries =
  case [ NonEmpty.toList (provenanceReasons entry)
       | entry <- entries
       , provenanceOccurrenceId entry == occurrence
       ] of
    [reasons] -> reasons
    _ -> []

stageState :: InspectionStage -> InspectionReport -> StageState
stageState stage report =
  case filter
         ((== stage) . reportedStage)
         (stageReportsList (reportStageReports report)) of
    [stageReport] -> reportedState stageReport
    _ -> error "expected one report for each Inspection stage"

assertStageState ::
     InspectionStage -> StageState -> InspectionReport -> Assertion
assertStageState stage expected report =
  assertEqual
    ("diagnostics: " <> show (diagnosticCodes report))
    expected
    (stageState stage report)

environmentFor :: Text -> IO Environment
environmentFor input =
  case decodeAMX (source input) of
    DecodePassed _ document ->
      case resolveAMXView document (ViewByName collectiveViewName) of
        ViewPassed _ selected -> pure (buildEnvironment document selected)
        ViewFailed _ defects ->
          assertFailure ("unexpected View defects: " <> show defects)
    DecodeUnavailable _ defects ->
      assertFailure ("unexpected Decode defects: " <> show defects)
    DecodeRejected _ defects ->
      assertFailure ("unexpected Decode rejection: " <> show defects)

elementById :: Text -> [AMXElement] -> AMXElement
elementById identifier elements =
  case filter ((== Just identifier) . elementId) elements of
    [found] -> found
    matches ->
      error
        ("expected one element "
           <> Text.unpack identifier
           <> ", found "
           <> show (length matches))

inspectEvidenceModel :: Text -> IO InspectionReport
inspectEvidenceModel input =
  case inspectSourceDocument
         amxAdapter
         (ViewByName collectiveViewName)
         collectiveInputs
         (source input) of
    InspectionCompleted report -> pure report
    InspectionCommandFailed commandError ->
      assertFailure ("unexpected command error: " <> show commandError)
