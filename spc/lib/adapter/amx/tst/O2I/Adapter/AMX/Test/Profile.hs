{-# LANGUAGE OverloadedStrings #-}

-- | Concrete O2I profile, contextualization, and notation tests.
module O2I.Adapter.AMX.Test.Profile
  ( profileTests
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

profileTests :: TestTree
profileTests =
  testGroup
    "profile"
    [ testCase "accepts the exact direct root profile" exactRootProfileTest
    , testCase "requires one direct root profile" missingProfileTest
    , testCase "ignores nested profile properties" nestedProfileTest
    , testCase
        "ignores foreign-namespaced profile properties"
        foreignProfilePropertyTest
    , testCase "rejects duplicate root profiles" duplicateProfileTest
    , testCase
        "rejects conflicting duplicate root profiles"
        conflictingDuplicateProfileTest
    , testCase "rejects unsupported root profile" unsupportedProfileTest
    , testCase
        "rejects every additional direct root O2I property"
        additionalRootPropertyTest
    , testCase "rejects legacy root version independently" legacyProfileTest
    , testCase "names and layout never establish candidacy" noCandidateTest
    , testCase
        "contextualization obligates an endpoint without metadata"
        obligatedMetadataTest
    , testCase "rejects unsupported candidate metadata" metadataKeyTest
    , testCase "rejects missing o2i.kind" missingKindTest
    , testCase "rejects malformed o2i.kind value" malformedKindPropertyTest
    , testCase "rejects unknown o2i.kind" unknownKindTest
    , testCase "rejects missing o2i.type" missingTypeTest
    , testCase "rejects invalid o2i.type for kind" invalidTypeTest
    , testCase "rejects duplicate kind and type metadata" duplicateMetadataTest
    , testCase "rejects the wrong ArchiMate element notation" wrongNotationTest
    , testCase "requires contextualization for a Primitive" missingOwnershipTest
    , testCase
        "visual containment never supplies contextualization"
        visualNestingTest
    , testCase
        "rejects composition[contains] as Context Ownership"
        legacyOwnershipLabelTest
    , testCase "rejects duplicate ownership" duplicateOwnershipTest
    , testCase "rejects ownership on an ownerless kind" ownerlessOwnershipTest
    , testCase "rejects unresolved ownership references" invalidOwnershipTest
    , testCase
        "projects invalid membership to Structure"
        membershipOwnerMismatchTest
    , testCase "accepts aggregation[contains] membership" validMembershipTest
    , testCase
        "rejects an incompatible relation representation"
        relationshipRepresentationTest
    , testCase "projects unknown relations to Structure" unknownRelationTest
    , testCase
        "projects uniquely identified invalid endpoints to Structure"
        invalidRelationEndpointTest
    , testCase
        "passes notation-independent interpretation defects to Structure"
        structureOwnershipTest
    , testCase
        "unreached profile defects outside the selected scope do not leak"
        unreachedProfileDefectTest
    ]

exactRootProfileTest :: Assertion
exactRootProfileTest = do
  report <- inspectText (ViewByName "Scope") validContextModel
  case reportProfileResolution report of
    ProfileResolvedResolution _ -> pure ()
    resolution ->
      assertFailure ("expected resolved profile: " <> show resolution)

missingProfileTest :: Assertion
missingProfileTest = do
  bytes <-
    ByteString.readFile (fixture "invalid/profile/missing-profile.archimate")
  report <- inspectBytes (ViewByName "Scope") bytes
  diagnosticCodes report @?= ["o2i.amx.profile.missing"]

nestedProfileTest :: Assertion
nestedProfileTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (profileProperty
            <> grouping "mission" "Mission" (Text.concat contextMetadata)
            <> view "view" "Scope" (diagramObject "object" "mission"))
         [])
  diagnosticCodes report @?= ["o2i.amx.profile.missing"]

foreignProfilePropertyTest :: Assertion
foreignProfilePropertyTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith
         [ "<x:property xmlns:x=\"urn:foreign\" "
             <> "key=\"o2i.profile\" value=\"0.2\"/>"
         ])
  diagnosticCodes report @?= ["o2i.amx.profile.missing"]

duplicateProfileTest :: Assertion
duplicateProfileTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith [profileProperty, profileProperty])
  diagnosticCodes report @?= ["o2i.amx.profile.duplicate"]
  case reportProfileResolution report of
    ProfileRejectedResolution rejected ->
      case rejectedProfileObservation rejected of
        MultipleO2IProfiles versions ->
          atLeastTwoToList versions @?= ["0.2", "0.2"]
        observation ->
          assertFailure
            ("expected multiple profile values: " <> show observation)
    resolution ->
      assertFailure
        ("expected rejected profile resolution: " <> show resolution)

conflictingDuplicateProfileTest :: Assertion
conflictingDuplicateProfileTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith [profileProperty, property "o2i.profile" "0.3"])
  diagnosticCodes report
    @?= ["o2i.amx.profile.duplicate", "o2i.amx.profile.unsupported"]

unsupportedProfileTest :: Assertion
unsupportedProfileTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith [property "o2i.profile" "0.3"])
  diagnosticCodes report @?= ["o2i.amx.profile.unsupported"]

additionalRootPropertyTest :: Assertion
additionalRootPropertyTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith
         [ profileProperty
         , property "o2i.owner" "invented"
         , property "o2i.version" "0.2"
         ])
  diagnosticCodes report
    @?= ["o2i.amx.profile.root-property", "o2i.amx.profile.root-property"]
  map diagnosticSubjects (diagnosticsList (reportDiagnostics report))
    @?= [ [DiagnosticSubject "metadata-key" "o2i.owner"]
        , [DiagnosticSubject "metadata-key" "o2i.version"]
        ]

legacyProfileTest :: Assertion
legacyProfileTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWith [property "version" "0.2"])
  diagnosticCodes report
    @?= ["o2i.amx.profile.legacy-version-property", "o2i.amx.profile.missing"]

noCandidateTest :: Assertion
noCandidateTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping "ordinary" "O2I Mission" ""
            <> view "view" "Scope" (diagramObject "object" "ordinary"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.inspection.scope.empty"]

obligatedMetadataTest :: Assertion
obligatedMetadataTest = do
  report <- inspectText (ViewByName "Scope") obligatedModel
  diagnosticCodes report
    @?= [ "o2i.amx.profile.commitment-missing"
        , "o2i.amx.profile.kind-missing"
        , "o2i.amx.profile.type-missing"
        ]

metadataKeyTest :: Assertion
metadataKeyTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [ property "o2i.kind" "Context"
         , property "o2i.type" "Mission"
         , property "o2i.commitment" "asserted"
         , property "o2i.owner" "invented"
         ])
  diagnosticCodes report @?= ["o2i.amx.profile.metadata-key"]

missingKindTest :: Assertion
missingKindTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [property "o2i.type" "Mission", property "o2i.commitment" "asserted"])
  diagnosticCodes report @?= ["o2i.amx.profile.kind-missing"]

malformedKindPropertyTest :: Assertion
malformedKindPropertyTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [ "<property key=\"o2i.kind\"/>"
         , property "o2i.type" "Mission"
         , property "o2i.commitment" "asserted"
         ])
  diagnosticCodes report @?= ["o2i.amx.profile.kind-unknown"]

unknownKindTest :: Assertion
unknownKindTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [ property "o2i.kind" "Unknown"
         , property "o2i.type" "Mission"
         , property "o2i.commitment" "asserted"
         ])
  diagnosticCodes report @?= ["o2i.amx.profile.kind-unknown"]

missingTypeTest :: Assertion
missingTypeTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [property "o2i.kind" "Context", property "o2i.commitment" "asserted"])
  diagnosticCodes report @?= ["o2i.amx.profile.type-missing"]

invalidTypeTest :: Assertion
invalidTypeTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [ property "o2i.kind" "Context"
         , property "o2i.type" "Driver"
         , property "o2i.commitment" "asserted"
         ])
  diagnosticCodes report @?= ["o2i.amx.profile.type-invalid"]

duplicateMetadataTest :: Assertion
duplicateMetadataTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (validContextModelWithNodeProperties
         [ property "o2i.kind" "Context"
         , property "o2i.kind" "Context"
         , property "o2i.type" "Mission"
         , property "o2i.type" "Mission"
         , property "o2i.commitment" "asserted"
         ])
  diagnosticCodes report
    @?= ["o2i.amx.profile.kind-duplicate", "o2i.amx.profile.type-duplicate"]

wrongNotationTest :: Assertion
wrongNotationTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (driver "mission" (Text.concat contextMetadata)
            <> view "view" "Scope" (diagramObject "object" "mission"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.profile.element-representation"]

missingOwnershipTest :: Assertion
missingOwnershipTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (driver "driver" primitiveMetadata
            <> view "view" "Scope" (diagramObject "object" "driver"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.amx.profile.ownership-missing"]

visualNestingTest :: Assertion
visualNestingTest = do
  report <- inspectText (ViewByName "Scope") visualNestingModel
  diagnosticCodes report @?= ["o2i.amx.profile.ownership-missing"]

legacyOwnershipLabelTest :: Assertion
legacyOwnershipLabelTest = do
  report <- inspectText (ViewByName "Scope") legacyOwnershipLabelModel
  assertBool
    "composition[contains] must not establish Context Ownership"
    ("o2i.amx.profile.ownership-missing" `elem` diagnosticCodes report)

duplicateOwnershipTest :: Assertion
duplicateOwnershipTest = do
  report <- inspectText (ViewByName "Scope") duplicateOwnershipModel
  diagnosticCodes report @?= ["o2i.amx.profile.ownership-duplicate"]

ownerlessOwnershipTest :: Assertion
ownerlessOwnershipTest = do
  report <- inspectText (ViewByName "Scope") ownerlessOwnershipModel
  diagnosticCodes report @?= ["o2i.amx.profile.ownership-forbidden"]

invalidOwnershipTest :: Assertion
invalidOwnershipTest = do
  report <- inspectText (ViewByName "Scope") invalidOwnershipModel
  diagnosticCodes report @?= ["o2i.inspection.scope.reference-unresolved"]

membershipOwnerMismatchTest :: Assertion
membershipOwnerMismatchTest = do
  report <- inspectText (ViewByName "Scope") invalidMembershipModel
  diagnosticCodes report @?= ["o2i.structure.membership-owner-mismatch"]

validMembershipTest :: Assertion
validMembershipTest = do
  report <- inspectText (ViewByName "Scope") validMembershipModel
  take 5 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 5 StagePassed

relationshipRepresentationTest :: Assertion
relationshipRepresentationTest = do
  report <- inspectText (ViewByName "Scope") wrongRelationshipModel
  diagnosticCodes report @?= ["o2i.amx.profile.relation-representation"]

unknownRelationTest :: Assertion
unknownRelationTest = do
  report <- inspectText (ViewByName "Scope") unknownRelationModel
  diagnosticCodes report @?= ["o2i.structure.relation-unknown"]

invalidRelationEndpointTest :: Assertion
invalidRelationEndpointTest = do
  report <- inspectText (ViewByName "Scope") invalidEndpointModel
  diagnosticCodes report @?= ["o2i.structure.relation-endpoint-kinds-invalid"]

structureOwnershipTest :: Assertion
structureOwnershipTest = do
  report <- inspectText (ViewByName "Scope") invalidInterpretationModel
  diagnosticCodes report @?= ["o2i.structure.interpretation-invalid"]

unreachedProfileDefectTest :: Assertion
unreachedProfileDefectTest = do
  report <-
    inspectText
      (ViewByName "Selected")
      (model
         (grouping "mission" "Mission" (Text.concat contextMetadata)
            <> grouping
                 "outside"
                 "Outside"
                 (Text.concat
                    [ property "o2i.kind" "Unknown"
                    , property "o2i.type" "Mission"
                    ])
            <> view
                 "selected"
                 "Selected"
                 (diagramObject "selected-object" "mission")
            <> view
                 "outside-view"
                 "Outside"
                 (diagramObject "outside-object" "outside"))
         [profileProperty])
  assertBool
    "an unreached metadata defect must remain deferred"
    ("o2i.amx.profile.kind-unknown" `notElem` diagnosticCodes report)
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed
