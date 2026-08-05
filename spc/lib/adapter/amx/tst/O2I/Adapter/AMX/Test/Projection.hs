{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed catalogs, graph identity, determinism, and provenance tests.
module O2I.Adapter.AMX.Test.Projection
  ( projectionTests
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Internal.Defect
import qualified O2I.Adapter.AMX.Internal.Defect as Defect
import O2I.Adapter.AMX.Test.Support
import O2I.ArchiMate.Profile
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

projectionTests :: TestTree
projectionTests =
  testGroup
    "projection"
    [ testCase "defect catalog is complete and code-unique" defectCatalogTest
    , testCase
        "every concrete defect constructor maps to its catalog tag"
        defectConstructorMappingTest
    , testCase
        "resource defects retain their stable diagnostic contract"
        resourceDefectContractTest
    , testCase
        "relation projection covers the Core registry"
        registryCoverageTest
    , testCase "projected relation crosses Structure" projectionBoundaryTest
    , testCase "projection and report bytes are deterministic" determinismTest
    , testCase "diagnostics retain exact source provenance" provenanceTest
    , testCase
        "a minimal Context crosses Structure and Semantics"
        semanticAcceptanceBoundaryTest
    , testCase
        "semantic invariants reject an unconstituted Situation"
        semanticRejectionBoundaryTest
    ]

defectCatalogTest :: Assertion
defectCatalogTest = do
  let tags = [minBound .. maxBound]
      specs = map amxDefectTagSpec tags
      codes = map (diagnosticCodeText . specCode) specs
  length tags @?= 59
  length codes @?= length (stableUnique codes)
  assertBool
    "Decode catalog codes must retain their namespace"
    (all ("o2i.amx.decode." `Text.isPrefixOf`) (take 12 codes))
  assertBool
    "View catalog codes must retain their namespace"
    (all ("o2i.amx.view." `Text.isPrefixOf`) (take 10 (drop 12 codes)))
  assertBool
    "Profile catalog codes must retain their namespace"
    (all ("o2i.amx.profile." `Text.isPrefixOf`) (drop 22 codes))

defectConstructorMappingTest :: Assertion
defectConstructorMappingTest = do
  concreteTags @?= [minBound .. maxBound]
  map specCode concreteSpecs @?= map (specCode . amxDefectTagSpec) concreteTags
  where
    concreteTags =
      map amxDecodeDefectTag decodeDefects
        ++ map amxViewDefectTag viewDefects
        ++ map amxProfileDefectTag profileDefects
    concreteSpecs =
      map amxDecodeDefectSpec decodeDefects
        ++ map amxViewDefectSpec viewDefects
        ++ map amxProfileDefectSpec profileDefects

decodeDefects :: [AMXDecodeDefect]
decodeDefects =
  [ MalformedXml
  , UnsafeXml
  , InputBytesLimitExceeded 10 11
  , XmlDepthLimitExceeded 10 11
  , XmlElementsLimitExceeded 10 11
  , XmlAttributesLimitExceeded 10 11
  , XmlTextLimitExceeded 10 11
  , InvalidUtf8
  , UnsupportedXmlEncoding "UTF-16"
  , UnexpectedRootQName (expandedQName (Just "urn:test") 'm' "odel")
  , MissingNativeVersion
  , UnsupportedNativeVersion "4.0.0"
  ]

resourceDefectContractTest :: Assertion
resourceDefectContractTest = mapM_ assertContract resourceDefectContracts
  where
    assertContract (defect, expectedCode) = do
      let specification = amxDecodeDefectSpec defect
      diagnosticCodeText (specCode specification) @?= expectedCode
      specSeverity specification @?= ErrorSeverity
      specDisposition specification @?= ProcessFailure
      specSubjects specification
        @?= [DiagnosticSubject "limit" "10", DiagnosticSubject "observed" "11"]

resourceDefectContracts :: [(AMXDecodeDefect, Text.Text)]
resourceDefectContracts =
  [ (InputBytesLimitExceeded 10 11, "o2i.amx.decode.resource.input-bytes")
  , (XmlDepthLimitExceeded 10 11, "o2i.amx.decode.resource.xml-depth")
  , (XmlElementsLimitExceeded 10 11, "o2i.amx.decode.resource.xml-elements")
  , (XmlAttributesLimitExceeded 10 11, "o2i.amx.decode.resource.xml-attributes")
  , (XmlTextLimitExceeded 10 11, "o2i.amx.decode.resource.xml-text")
  ]

viewDefects :: [AMXViewDefect]
viewDefects =
  [ ViewNotFound (ViewByName "missing")
  , AmbiguousViewName "view" ("a" :| ["b"])
  , DuplicateViewId "id" ("a" :| ["b"])
  , UnresolvedViewObjectReference Nothing
  , AmbiguousViewObjectReference "node" (sampleLocation :| [])
  , UnresolvedViewRelationshipReference Nothing
  , AmbiguousViewRelationshipReference "edge" (sampleLocation :| [])
  , UnresolvedViewConnectionEndpoint "connection" Nothing
  , AmbiguousViewConnectionEndpoint
      "connection"
      "endpoint"
      (sampleLocation :| [])
  , ViewConnectionEndpointMismatch "connection" "expected" "actual"
  ]

profileDefects :: [AMXProfileDefect]
profileDefects =
  [ MissingO2IProfile
  , DuplicateO2IProfile ("0.3" :| ["0.3"])
  , UnsupportedO2IProfile "0.2"
  , UnsupportedO2IRootProperty "o2i.extra"
  , UnsupportedO2IMetadataKey "node" "o2i.extra"
  , MissingO2IKind "node"
  , DuplicateO2IKind "node" ("Context" :| ["Context"])
  , UnknownO2IKind "node" "Unknown"
  , MissingO2IType "node"
  , DuplicateO2IType "node" ("Mission" :| ["Mission"])
  , InvalidO2ITypeForKind "node" "Context" "Driver"
  , IncompatibleElementRepresentation "node" "Grouping" "Driver"
  , IncompatibleRelationshipRepresentation
      "edge"
      "InfluenceRelationship"
      "AssociationRelationship"
  , MissingOwnership "node"
  , DuplicateOwnership "node" ("a" :| ["b"])
  , OwnershipOnOwnerlessKind "node"
  , MissingCommitment "claim"
  , DuplicateCommitment "claim" ("candidate" :| ["asserted"])
  , InvalidCommitment "claim" "tentative"
  , ForbiddenCommitment "ownership" "contextualization"
  , MissingCollectiveClaimId
  , AmbiguousCollectiveClaimId "claim" 2
  , InvalidCollectiveJunctionRepresentation "claim" "OrJunction"
  , MissingCollectiveFitEvidenceReference "claim"
  , DuplicateCollectiveFitEvidenceReference "claim" ("fit-a" :| ["fit-b"])
  , Defect.EmptyCollectiveFitEvidenceReference "claim"
  , InvalidCollectiveSegmentRepresentation
      "claim"
      "segment"
      "InfluenceRelationship"
  , InvalidCollectiveSegmentName "claim" "segment" "jointly-realizes"
  , CollectiveSegmentMetadata "claim" "segment" "o2i.role"
  , CollectiveJunctionChain "claim" "segment"
  , CollectiveEndpointUnresolved "claim" "segment" "contributor" Nothing
  , CollectiveEndpointAmbiguous "claim" "segment" "target" 2
  , CollectiveContributorCardinality "claim" 1
  , CollectiveTargetCardinality "claim" 0
  , Defect.DuplicateCollectiveContributor "claim" "strategy"
  , Defect.CollectiveContributorIsTarget "claim" "strategy"
  , PartialCollectiveView "claim" 1 2
  ]

sampleLocation :: SourcePosition
sampleLocation =
  sourcePosition
    (firstPathStep (expandedQName (Just "urn:test") 'm' "odel") :| [])
    ElementTarget
    Nothing

registryCoverageTest :: Assertion
registryCoverageTest = do
  map relationMappingCode relationMappings @?= map relationCodeOf allRelations
  assertBool
    "every signature must retain the Core semantic name"
    (all
       (not . Text.null . relationNameText . relationMappingName)
       relationMappings)

projectionBoundaryTest :: Assertion
projectionBoundaryTest = do
  report <-
    inspectText (ViewByName "Scope") (connectionModel "relation" "a" "b")
  take 4 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 4 StagePassed

determinismTest :: Assertion
determinismTest = do
  first <- inspectText (ViewByName "Scope") validEthosModel
  second <- inspectText (ViewByName "Scope") validEthosModel
  renderInspectionReportJSON first @?= renderInspectionReportJSON second

provenanceTest :: Assertion
provenanceTest = do
  report <- inspectText (ViewByName "Scope") obligatedModel
  case diagnosticsList (reportDiagnostics report) of
    diagnostic:_ -> do
      let locations = diagnosticLocations diagnostic
      assertBool
        "diagnostic must retain a source location"
        (not (null locations))
      map (sourceDisplayLabel . locationSource) locations
        @?= replicate (length locations) "test.archimate"
      map (sourceSha256 . locationSource) locations
        @?= replicate
              (length locations)
              (sourceSha256 (sourceDocumentIdentity (source obligatedModel)))
    [] -> assertFailure "expected located profile diagnostics"

semanticAcceptanceBoundaryTest :: Assertion
semanticAcceptanceBoundaryTest = do
  report <- inspectText (ViewByName "Scope") validEthosModel
  take 5 (map reportedState (stageReportsList (reportStageReports report)))
    @?= replicate 5 StagePassed

semanticRejectionBoundaryTest :: Assertion
semanticRejectionBoundaryTest = do
  report <-
    inspectText
      (ViewByName "Scope")
      (model
         (grouping
            "situation"
            "Situation"
            (Text.concat (metadata "Context" "Situation"))
            <> view "view" "Scope" (diagramObject "object" "situation"))
         [profileProperty])
  diagnosticCodes report @?= ["o2i.semantics.situation-unconstituted"]
