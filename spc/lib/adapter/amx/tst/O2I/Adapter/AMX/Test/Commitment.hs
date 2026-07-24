{-# LANGUAGE OverloadedStrings #-}

-- | Explicit commitment contract across every native proposition carrier.
module O2I.Adapter.AMX.Test.Commitment
  ( commitmentTests
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Test.Collective.Fixture
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

data Carrier
  = ContextCarrier
  | SituationAnchorCarrier
  | PrimitiveCarrier
  | PerformanceDimensionCarrier
  | RelationshipCarrier
  | StructuredPropositionCarrier
  deriving (Bounded, Enum, Eq, Show)

commitmentTests :: TestTree
commitmentTests =
  testGroup
    "commitment"
    [ testCase
        "accepts asserted on every proposition carrier"
        assertedCarrierTest
    , testCase
        "accepts candidate on every proposition carrier"
        candidateCarrierTest
    , testCase
        "requires commitment on every proposition carrier"
        missingCarrierTest
    , testCase
        "requires one commitment on every proposition carrier"
        duplicateCarrierTest
    , testCase
        "accepts only the closed commitment vocabulary"
        invalidCarrierTest
    , testCase
        "forbids commitment on contextualization syntax"
        contextualizationCommitmentTest
    , testCase
        "forbids commitment on collective realizes syntax"
        collectiveSegmentCommitmentTest
    , testCase
        "retains candidates and excludes them from semantics"
        candidateExclusionTest
    , testCase
        "rejects an asserted child of a candidate Context"
        assertedChildDependencyTest
    , testCase
        "rejects an asserted relation with a candidate endpoint"
        assertedRelationDependencyTest
    , testCase
        "allows a candidate relation with a candidate endpoint"
        candidateRelationDependencyTest
    , testCase
        "commitment diagnostics retain exact property provenance"
        commitmentProvenanceTest
    ]

assertedCarrierTest :: Assertion
assertedCarrierTest =
  mapM_ (assertProfileAccepted . carrierModel assertedProperties) carriers

candidateCarrierTest :: Assertion
candidateCarrierTest =
  mapM_ (assertProfileAccepted . carrierModel candidateProperties) carriers

missingCarrierTest :: Assertion
missingCarrierTest =
  mapM_
    (assertCommitmentCodes ["o2i.amx.profile.commitment-missing"]
       . carrierModel [])
    carriers

duplicateCarrierTest :: Assertion
duplicateCarrierTest =
  mapM_
    (assertCommitmentCodes ["o2i.amx.profile.commitment-duplicate"]
       . carrierModel (candidateProperties <> assertedProperties))
    carriers

invalidCarrierTest :: Assertion
invalidCarrierTest =
  mapM_
    (assertCommitmentCodes ["o2i.amx.profile.commitment-invalid"]
       . carrierModel [property "o2i.commitment" "tentative"])
    carriers

contextualizationCommitmentTest :: Assertion
contextualizationCommitmentTest =
  assertCommitmentCodes
    ["o2i.amx.profile.commitment-forbidden"]
    (model
       (grouping "ethos" "Ethos" (Text.concat ethosMetadata)
          <> principle "principle" principleMetadata
          <> relationshipWithProperties
               (Text.concat assertedProperties)
               "ownership"
               "CompositionRelationship"
               "contextualizes"
               "ethos"
               "principle"
               False
          <> view "view" "Scope" (diagramObject "object" "principle"))
       [profileProperty])

collectiveSegmentCommitmentTest :: Assertion
collectiveSegmentCommitmentTest =
  assertCommitmentCodes
    ["o2i.amx.profile.commitment-forbidden"]
    (model
       (Text.concat standardParticipants
          <> junctionElement "claim" "AndJunction" collectiveClaimMetadata
          <> segmentElementWithMetadata
               incomingA
               (Text.concat assertedProperties)
          <> segmentElement incomingB
          <> segmentElement outgoing
          <> scopeView)
       [profileProperty])

candidateExclusionTest :: Assertion
candidateExclusionTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (carrierModel candidateProperties PrimitiveCarrier)
  assertBool
    "candidate Primitive must remain diagnostically visible"
    ("o2i.claim.candidate-excluded" `elem` diagnosticCodes report)
  assertBool
    "candidate Primitive must not satisfy asserted Ethos completeness"
    ("o2i.semantics.ethos-principle-missing" `elem` diagnosticCodes report)

assertedChildDependencyTest :: Assertion
assertedChildDependencyTest = do
  report <- inspectText (ViewByName "Scope") assertedChildOfCandidateModel
  assertBool
    "asserted child must not depend on a candidate Context"
    ("o2i.structure.asserted-node-depends-on-candidate"
       `elem` diagnosticCodes report)

assertedRelationDependencyTest :: Assertion
assertedRelationDependencyTest = do
  report <-
    inspectText (ViewByName "Scope") (relationDependencyModel "asserted")
  assertBool
    "asserted relation must not depend on a candidate endpoint"
    ("o2i.structure.asserted-edge-depends-on-candidate"
       `elem` diagnosticCodes report)

candidateRelationDependencyTest :: Assertion
candidateRelationDependencyTest = do
  report <-
    inspectText (ViewByName "Scope") (relationDependencyModel "candidate")
  let observedCodes = diagnosticCodes report
  assertBool
    ("candidate relation must remain visible outside validated semantics: "
       <> show observedCodes)
    ("o2i.claim.candidate-excluded" `elem` observedCodes)
  assertBool
    "candidate relation may depend on a candidate endpoint"
    ("o2i.structure.asserted-edge-depends-on-candidate" `notElem` observedCodes)

commitmentProvenanceTest :: Assertion
commitmentProvenanceTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (carrierModel [property "o2i.commitment" "tentative"] ContextCarrier)
  case commitmentDiagnostics report of
    [diagnostic] ->
      case diagnosticLocations diagnostic of
        [location] ->
          locationTarget location @?= PropertyTarget "o2i.commitment"
        _ -> assertFailure "expected one commitment source location"
    _ -> assertFailure "expected one commitment diagnostic"

assertProfileAccepted :: Text -> Assertion
assertProfileAccepted sourceModel = do
  report <- inspectText (ViewByName "Scope") sourceModel
  stageState ProfileStage report @?= StagePassed
  commitmentDiagnostics report @?= []

assertCommitmentCodes :: [Text] -> Text -> Assertion
assertCommitmentCodes expected sourceModel = do
  report <- inspectText (ViewByName "Scope") sourceModel
  map (diagnosticCodeText . diagnosticCode) (commitmentDiagnostics report)
    @?= expected

commitmentDiagnostics :: InspectionReport -> [Diagnostic]
commitmentDiagnostics =
  filter
    (Text.isPrefixOf "o2i.amx.profile.commitment"
       . diagnosticCodeText
       . diagnosticCode)
    . diagnosticsList
    . reportDiagnostics

carrierModel :: [Text] -> Carrier -> Text
carrierModel commitment carrier =
  case carrier of
    ContextCarrier ->
      simpleModel
        (grouping
           "mission"
           "Mission"
           (carrierMetadata "Context" "Mission" commitment))
        "mission"
    SituationAnchorCarrier ->
      simpleModel
        (element
           "Capability"
           "anchor"
           "Anchor"
           (carrierMetadata "SituationAnchor" "BusinessCapability" commitment))
        "anchor"
    PrimitiveCarrier ->
      model
        (grouping "ethos" "Ethos" (Text.concat ethosMetadata)
           <> principle
                "principle"
                (carrierMetadata "Primitive" "Principle" commitment)
           <> contextualization "ownership" "ethos" "principle"
           <> view "view" "Scope" (diagramObject "object" "principle"))
        [profileProperty]
    PerformanceDimensionCarrier ->
      model
        (grouping
           "measure"
           "Measure"
           (Text.concat (metadata "Context" "Measure"))
           <> grouping
                "dimension"
                "Dimension"
                (carrierMetadata "Structuring" "PerformanceDimension" commitment)
           <> contextualization "ownership" "measure" "dimension"
           <> view "view" "Scope" (diagramObject "object" "dimension"))
        [profileProperty]
    RelationshipCarrier -> relationshipCarrierModel commitment
    StructuredPropositionCarrier ->
      scopedCollectiveWithMetadata
        (Text.concat
           ([ property "o2i.kind" "StructuredProposition"
            , property "o2i.type" "CollectiveStrategyRealization"
            , property "o2i.collective-fit-evidence" "fit-claim"
            ]
              <> commitment))

simpleModel :: Text -> Text -> Text
simpleModel declaration identifier =
  model
    (declaration <> view "view" "Scope" (diagramObject "object" identifier))
    [profileProperty]

relationshipCarrierModel :: [Text] -> Text
relationshipCarrierModel commitment =
  model
    (grouping "ethos" "Ethos" (Text.concat ethosMetadata)
       <> grouping "mission" "Mission" (Text.concat contextMetadata)
       <> relationshipWithProperties
            (Text.concat commitment)
            "guides"
            "InfluenceRelationship"
            "guides"
            "ethos"
            "mission"
            False
       <> connectedView "guides" "ethos" "mission")
    [profileProperty]

assertedChildOfCandidateModel :: Text
assertedChildOfCandidateModel =
  model
    (grouping
       "ethos"
       "Ethos"
       (carrierMetadata "Context" "Ethos" candidateProperties)
       <> principle "principle" principleMetadata
       <> contextualization "ownership" "ethos" "principle"
       <> view "view" "Scope" (diagramObject "object" "principle"))
    [profileProperty]

relationDependencyModel :: Text -> Text
relationDependencyModel relationCommitment =
  model
    (grouping
       "ethos"
       "Ethos"
       (carrierMetadata "Context" "Ethos" candidateProperties)
       <> grouping "mission" "Mission" (Text.concat contextMetadata)
       <> relationshipWithCommitment
            relationCommitment
            "guides"
            "InfluenceRelationship"
            "guides"
            "ethos"
            "mission"
            False
       <> connectedView "guides" "ethos" "mission")
    [profileProperty]

carrierMetadata :: Text -> Text -> [Text] -> Text
carrierMetadata kind carrierType commitment =
  Text.concat
    ([property "o2i.kind" kind, property "o2i.type" carrierType] <> commitment)

assertedProperties :: [Text]
assertedProperties = [property "o2i.commitment" "asserted"]

candidateProperties :: [Text]
candidateProperties = [property "o2i.commitment" "candidate"]

carriers :: [Carrier]
carriers = [minBound .. maxBound]

stageState :: InspectionStage -> InspectionReport -> StageState
stageState stage report =
  case filter
         ((== stage) . reportedStage)
         (stageReportsList (reportStageReports report)) of
    [stageReport] -> reportedState stageReport
    _ -> error "expected one report for each Inspection stage"
