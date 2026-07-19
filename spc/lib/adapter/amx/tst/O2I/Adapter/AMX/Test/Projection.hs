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
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Test.Support
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
        "relation projection covers the Core registry"
        registryCoverageTest
    , testCase "projected node and edge identities are stable" graphIdentityTest
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
  length tags @?= 33
  length codes @?= length (stableUnique codes)
  map specStage (take 7 specs) @?= replicate 7 DecodeStage
  map specStage (take 10 (drop 7 specs)) @?= replicate 10 ViewScopeStage
  map specStage (drop 17 specs) @?= replicate 16 ProfileStage

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
  , InvalidUtf8
  , UnsupportedXmlEncoding "UTF-16"
  , UnexpectedRootQName (ExpandedQName (Just "urn:test") "model")
  , MissingNativeVersion
  , UnsupportedNativeVersion "4.0.0"
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
  , DuplicateO2IProfile ("0.2" :| ["0.2"])
  , UnsupportedO2IProfile "0.3"
  , LegacyRootVersionProperty "0.2"
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
  ]

sampleLocation :: SourceLocation
sampleLocation =
  SourceLocation
    { locationSource =
        SourceIdentity
          { sourceDisplayLabel = "sample.archimate"
          , sourceInputKind = FileSource
          , sourceSha256 = sourceHashFromBytes ""
          }
    , locationPath =
        firstPathStep (ExpandedQName (Just "urn:test") "model") :| []
    , locationTarget = ElementTarget
    , locationSpan = Nothing
    }

registryCoverageTest :: Assertion
registryCoverageTest = do
  map signatureCode relationSignatures @?= map relationCodeOf allRelations
  assertBool
    "every signature must retain the Core semantic name"
    (all (not . Text.null . relationNameText . signatureName) relationSignatures)

graphIdentityTest :: Assertion
graphIdentityTest = do
  imported <- projectImportedGraph (connectionModel "relation" "a" "b")
  let graph = importedRawGraph imported
  rawNodes graph
    @?= [ RawContextNode (RawNodeId "left") Mission
        , RawContextNode (RawNodeId "right") Vision
        ]
  rawEdges graph
    @?= [ RawEdge
            (RawNodeId "left")
            (RelationName "mission-grounds-vision")
            (RawNodeId "right")
        ]

projectImportedGraph :: Text.Text -> IO ImportedGraph
projectImportedGraph = projectImportedBytes (ViewByName "Scope") . encode

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
