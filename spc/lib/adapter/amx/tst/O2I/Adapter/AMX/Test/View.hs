{-# LANGUAGE OverloadedStrings #-}

-- | Exact View resolution and persisted reference tests.
module O2I.Adapter.AMX.Test.View
  ( viewTests
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

viewTests :: TestTree
viewTests =
  testGroup
    "view"
    [ testCase "resolves exact View name" exactViewNameTest
    , testCase "resolves exact stable View ID" exactViewIdTest
    , testCase "rejects a missing View" missingViewTest
    , testCase "rejects duplicate View names" ambiguousViewNameTest
    , testCase "rejects duplicate View IDs" duplicateViewIdTest
    , testCase "rejects unresolved object references" unresolvedObjectTest
    , testCase "rejects missing object references" missingObjectReferenceTest
    , testCase "rejects ambiguous object references" ambiguousObjectTest
    , testCase
        "rejects unresolved relationship references"
        unresolvedRelationshipTest
    , testCase
        "rejects ambiguous relationship references"
        ambiguousRelationshipTest
    , testCase "rejects unresolved connection endpoints" unresolvedEndpointTest
    , testCase "rejects ambiguous connection endpoints" ambiguousEndpointTest
    , testCase "rejects connection endpoint mismatches" endpointMismatchTest
    , testCase "an empty selected View fails as empty O2I scope" emptyViewTest
    , testCase
        "defects in an unselected View do not leak"
        unselectedViewDefectTest
    , testCase
        "repeated View presentations retain occurrence identity"
        repeatedPresentationTest
    ]

exactViewNameTest :: Assertion
exactViewNameTest = do
  report <- inspectText (ViewByName "Scope") validContextModel
  viewResolutionId report @?= Just "view"

exactViewIdTest :: Assertion
exactViewIdTest = do
  report <- inspectText (ViewById "view") validContextModel
  viewResolutionId report @?= Just "view"

missingViewTest :: Assertion
missingViewTest = do
  report <- inspectText (ViewByName "Missing") validContextModel
  diagnosticCodes report @?= ["o2i.amx.view.not-found"]

ambiguousViewNameTest :: Assertion
ambiguousViewNameTest = do
  bytes <-
    ByteString.readFile (fixture "invalid/view/duplicate-view-name.archimate")
  report <- inspectBytes (ViewByName "Scope") bytes
  diagnosticCodes report @?= ["o2i.amx.view.name-ambiguous"]
  case reportViewResolution report of
    ViewRejected failure ->
      case failedViewObservation failure of
        MultipleViewMatches candidates ->
          map viewCandidateId (atLeastTwoToList candidates)
            @?= ["view-a", "view-b"]
        observation ->
          assertFailure ("expected multiple View matches: " <> show observation)
    resolution ->
      assertFailure ("expected rejected View resolution: " <> show resolution)

duplicateViewIdTest :: Assertion
duplicateViewIdTest = do
  report <-
    inspectText
      (ViewById "view")
      (model (view "view" "A" "" <> view "view" "B" "") [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.id-ambiguous"]

unresolvedObjectTest :: Assertion
unresolvedObjectTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (view "view" "Scope" (diagramObject "object" "missing"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.object-unresolved"]

missingObjectReferenceTest :: Assertion
missingObjectReferenceTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (view
            "view"
            "Scope"
            "<child xsi:type=\"a:DiagramObject\" id=\"object\"/>")
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.object-unresolved"]

ambiguousObjectTest :: Assertion
ambiguousObjectTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping "duplicate" "First" (Text.concat contextMetadata)
            <> grouping "duplicate" "Second" (Text.concat contextMetadata)
            <> view "view" "Scope" (diagramObject "object" "duplicate"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.object-ambiguous"]

unresolvedRelationshipTest :: Assertion
unresolvedRelationshipTest = do
  report <- inspectText (ViewByName "Scope") (connectionModel "missing" "a" "b")
  assertBool
    "relationship reference defect expected"
    ("o2i.amx.view.connection-unresolved" `elem` diagnosticCodes report)

ambiguousRelationshipTest :: Assertion
ambiguousRelationshipTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping "left" "Left" (Text.concat contextMetadata)
            <> grouping "right" "Right" (Text.concat visionMetadata)
            <> relationship
                 "relation"
                 "InfluenceRelationship"
                 "grounds"
                 "left"
                 "right"
                 False
            <> relationship
                 "relation"
                 "InfluenceRelationship"
                 "grounds"
                 "left"
                 "right"
                 False
            <> connectedView "relation" "left" "right")
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.connection-ambiguous"]

unresolvedEndpointTest :: Assertion
unresolvedEndpointTest = do
  report <-
    inspectText (ViewByName "Scope") (connectionModel "relation" "missing" "b")
  assertBool
    "endpoint defect expected"
    ("o2i.amx.view.endpoint-unresolved" `elem` diagnosticCodes report)

ambiguousEndpointTest :: Assertion
ambiguousEndpointTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping "left" "Left" (Text.concat contextMetadata)
            <> grouping "right" "Right" (Text.concat visionMetadata)
            <> relationship
                 "relation"
                 "InfluenceRelationship"
                 "grounds"
                 "left"
                 "right"
                 False
            <> view
                 "view"
                 "Scope"
                 (diagramObjectWithConnection "a" "left" "relation" "a" "b"
                    <> diagramObject "a" "left"
                    <> diagramObject "b" "right"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.view.endpoint-ambiguous"]

endpointMismatchTest :: Assertion
endpointMismatchTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (connectionModelWithRelationship "relation" "right" "left")
  diagnosticCodes report
    @?= ["o2i.amx.view.endpoint-mismatch", "o2i.amx.view.endpoint-mismatch"]

emptyViewTest :: Assertion
emptyViewTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model (view "view" "Scope" "") [profileProperty])
  diagnosticCodes report @?= ["o2i.inspection.scope.empty"]
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= [ StagePassed
        , StagePassed
        , StageFailed
        , StageNotRun (BlockedByFailure ProfileStage)
        ]

unselectedViewDefectTest :: Assertion
unselectedViewDefectTest = do
  report <-
    inspectText
      (ViewByName "Selected")
      (model
         (grouping "mission" "Mission" (Text.concat contextMetadata)
            <> view
                 "selected"
                 "Selected"
                 (diagramObject "selected-object" "mission")
            <> view
                 "outside"
                 "Outside"
                 (diagramObject "broken-object" "missing"))
         [profileProperty])
  assertBool
    "the unselected unresolved reference must not be reported"
    ("o2i.amx.view.object-unresolved" `notElem` diagnosticCodes report)
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed

repeatedPresentationTest :: Assertion
repeatedPresentationTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping "mission" "Mission" (Text.concat contextMetadata)
            <> view
                 "view"
                 "Scope"
                 (diagramObject "first" "mission"
                    <> diagramObject "second" "mission"))
         [profileProperty])
  reportScopeResolution report
    @?= ScopeResolved
          ClosedScopeSummary
            {directOccurrenceCount = 2, closedOccurrenceCount = 3}
