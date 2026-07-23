{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I
import qualified O2I.Language as Language
import O2I.Test.Collective (collectiveTests)
import O2I.Test.Qualification (needQualificationTests)
import O2I.Test.Support
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "O2I"
    [ claimStateTests
    , collectiveTests
    , structureTests
    , performanceDimensionRoleTests
    , semanticTests
    , needQualificationTests
    , macroRuleTests
    , traceTests
    , kpiDefinitionTests
    , readinessTests
    , effectEvidenceTests
    , registryTests
    ]

claimStateTests :: TestTree
claimStateTests =
  testGroup
    "claim state"
    [ testCase "claim projections preserve explicit commitment" $ do
        claimCommitment (candidateClaim strategyNode) @?= Candidate
        claimCommitment (assertedClaim strategyNode) @?= Asserted
        claimedProposition (claimWithCommitment Candidate strategyNode)
          @?= strategyNode
    , testCase "candidate declarations are retained but excluded"
        $ case validateClaimStructure candidateOnlyGraph of
            StructureAccepted structure -> do
              let graph = structuralGraph structure
              assertBool
                "candidate node entered typed graph"
                (null (graphNodes graph))
              assertBool
                "candidate edge entered typed graph"
                (null (graphEdges graph))
              structuralCandidatePropositions structure
                @?= [CandidateNodeProposition strategyNode]
              let assessment = assessModelSemantics structure []
              contextElaboration assessment strategyId @?= Nothing
              modelMaturity assessment @?= Skeleton
              assertNoSemanticModel assessment
            StructureModelRejected errors ->
              assertFailure ("unexpected structural errors: " ++ show errors)
            StructureInternalFailure internal ->
              assertFailure ("unexpected internal failure: " ++ show internal)
    , testCase "valid candidate relation is retained but excluded"
        $ case validateClaimStructure validCandidateEdgeGraph of
            StructureAccepted structure -> do
              graphEdges (structuralGraph structure) @?= []
              structuralCandidatePropositions structure
                @?= [CandidateEdgeProposition candidateDependencyEdge]
            StructureModelRejected errors ->
              assertFailure ("unexpected structural errors: " ++ show errors)
            StructureInternalFailure internal ->
              assertFailure ("unexpected internal failure: " ++ show internal)
    , testCase "candidate-owned-by-candidate is structurally admissible"
        $ case validateClaimStructure candidateOwnedByCandidateGraph of
            StructureAccepted structure -> do
              assertBool
                "candidate-owned node entered typed graph"
                (null (graphNodes (structuralGraph structure)))
              structuralCandidatePropositions structure
                @?= [ CandidateNodeProposition strategyNode
                    , CandidateNodeProposition strategyActionNode
                    ]
            StructureModelRejected errors ->
              assertFailure ("unexpected structural errors: " ++ show errors)
            StructureInternalFailure internal ->
              assertFailure ("unexpected internal failure: " ++ show internal)
    , testCase "candidate declaration identity is validated"
        $ assertStructuralErrors
            [DuplicateNodeId strategyId]
            (validateClaimStructure candidateDuplicateDeclarationGraph)
    , testCase "candidate ownership possibility is validated"
        $ assertStructuralErrors
            [UnknownOwner strategyActionId missingId]
            (validateClaimStructure candidateUnknownOwnerGraph)
    , testCase "candidate contextual type is validated"
        $ assertStructuralErrors
            [InvalidPrimitiveInterpretation strategyActionId Ethos Action]
            (validateClaimStructure candidateInvalidInterpretationGraph)
    , testCase "asserted ownership cannot depend on a candidate Context"
        $ assertStructuralErrors
            [AssertedNodeDependsOnCandidate strategyActionId strategyId]
            (validateClaimStructure assertedOwnerCandidateGraph)
    , testCase "asserted relation cannot depend on a candidate endpoint"
        $ assertStructuralErrors
            [ AssertedEdgeDependsOnCandidate
                candidateDependencyEdge
                secondStrategyId
            ]
            (validateClaimStructure assertedEdgeCandidateGraph)
    , testCase "candidate unknown relation is rejected precisely"
        $ assertStructuralErrors
            [UnknownRelation (RelationName "unknown")]
            (validateClaimStructure candidateUnknownRelationGraph)
    , testCase "candidate wrong endpoint kinds are rejected precisely"
        $ assertStructuralErrors
            [ InvalidRelationEndpointKinds
                wrongKindCandidateEdge
                (ContextNodeKind Strategy)
                (PrimitiveNodeKind Strategy Action)
            ]
            (validateClaimStructure candidateWrongKindsGraph)
    , testCase "candidate propositions keep an otherwise valid model Draft"
        $ withClaimStructure candidateExtendedSampleGraph
        $ \structure -> do
            let graph = structuralGraph structure
                assessment =
                  assessModelSemantics
                    structure
                    [assertedClaim sampleStrategyFormulation]
            modelMaturity assessment @?= Draft
            assertNoSemanticModel assessment
            assessmentInvariantErrors assessment @?= []
            assessmentCandidatePropositions assessment
              @?= [ CandidateModelNode
                      (RawContextNode secondStrategyId Strategy)
                  , CandidateModelEdge candidateDependencyEdge
                  ]
            mapM_
              (\context ->
                 contextElaboration assessment context @?= Just Elaborated)
              (contextIdentifiersOf graph)
    , testCase "missing asserted content yields a referenced Skeleton"
        $ withStructural (RawGraph [strategyNode] [])
        $ \structure -> do
            let assessment = assessModelSemantics structure []
            modelMaturity assessment @?= Skeleton
            contextElaboration assessment strategyId @?= Just Referenced
            assertNoSemanticModel assessment
    , testCase "candidate Strategy content never elaborates its Context"
        $ withStructural sampleGraph
        $ \structure -> do
            let assessment =
                  assessModelSemantics
                    structure
                    [candidateClaim sampleStrategyFormulation]
            contextElaboration assessment strategyId @?= Just Referenced
            CandidateStrategyFormulation strategyId
              `elem` assessmentCandidatePropositions assessment
                       @? "candidate formulation was not retained"
            assessmentInvariantErrors assessment
              @?= [StrategyWithoutFormulation strategyId]
            modelMaturity assessment @?= Draft
            assertNoSemanticModel assessment
    , testCase "candidate content does not satisfy an asserted minimum"
        $ withClaimStructure candidateEthosContentGraph
        $ \structure -> do
            let assessment = assessModelSemantics structure []
            assessmentInvariantErrors assessment
              @?= [EthosWithoutPrinciple ethosId]
            contextElaboration assessment ethosId @?= Just Referenced
            assessmentCandidatePropositions assessment
              @?= [CandidateModelNode ethosPrincipleNode]
            assertNoSemanticModel assessment
    , testCase "candidate does not hide asserted defects"
        $ withClaimStructure candidateExtendedSampleGraph
        $ \structure -> do
            let assessment = assessModelSemantics structure []
            assessmentInvariantErrors assessment
              @?= [StrategyWithoutFormulation strategyId]
            contextElaboration assessment strategyId @?= Just Referenced
    , testCase "fully asserted semantic model reaches exact maturity"
        $ withStructural sampleGraph
        $ \structure -> do
            let assessment =
                  assessModelSemantics
                    structure
                    [assertedClaim sampleStrategyFormulation]
            modelMaturity assessment @?= SemanticallyValid
            assertBool
              "semantic model was not exposed"
              (case assessedSemanticModel assessment of
                 Just _ -> True
                 Nothing -> False)
    ]

strategyNode :: RawNode
strategyNode = RawContextNode strategyId Strategy

strategyActionNode :: RawNode
strategyActionNode = RawPrimitiveNode strategyActionId strategyId Action

candidateOnlyGraph :: RawClaimGraph
candidateOnlyGraph = RawClaimGraph [candidateClaim strategyNode] []

candidateOwnedByCandidateGraph :: RawClaimGraph
candidateOwnedByCandidateGraph =
  RawClaimGraph
    [candidateClaim strategyNode, candidateClaim strategyActionNode]
    []

candidateDuplicateDeclarationGraph :: RawClaimGraph
candidateDuplicateDeclarationGraph =
  RawClaimGraph
    [ candidateClaim strategyNode
    , candidateClaim (RawContextNode strategyId Need)
    ]
    []

candidateUnknownOwnerGraph :: RawClaimGraph
candidateUnknownOwnerGraph =
  RawClaimGraph
    [candidateClaim (RawPrimitiveNode strategyActionId missingId Action)]
    []

candidateInvalidInterpretationGraph :: RawClaimGraph
candidateInvalidInterpretationGraph =
  RawClaimGraph
    [ candidateClaim (RawContextNode ethosId Ethos)
    , candidateClaim (RawPrimitiveNode strategyActionId ethosId Action)
    ]
    []

assertedOwnerCandidateGraph :: RawClaimGraph
assertedOwnerCandidateGraph =
  RawClaimGraph
    [ candidateClaim strategyNode
    , assertedClaim (RawPrimitiveNode strategyActionId strategyId Action)
    ]
    []

candidateDependencyEdge :: RawEdge
candidateDependencyEdge = edge strategyId contributesToStrategy secondStrategyId

validCandidateEdgeGraph :: RawClaimGraph
validCandidateEdgeGraph =
  RawClaimGraph
    [ assertedClaim strategyNode
    , assertedClaim (RawContextNode secondStrategyId Strategy)
    ]
    [candidateClaim candidateDependencyEdge]

assertedEdgeCandidateGraph :: RawClaimGraph
assertedEdgeCandidateGraph =
  RawClaimGraph
    [ assertedClaim strategyNode
    , candidateClaim (RawContextNode secondStrategyId Strategy)
    ]
    [assertedClaim candidateDependencyEdge]

unknownCandidateEdge :: RawEdge
unknownCandidateEdge =
  RawEdge strategyId (RelationName "unknown") secondStrategyId

candidateUnknownRelationGraph :: RawClaimGraph
candidateUnknownRelationGraph =
  RawClaimGraph
    [ assertedClaim strategyNode
    , assertedClaim (RawContextNode secondStrategyId Strategy)
    ]
    [candidateClaim unknownCandidateEdge]

wrongKindCandidateEdge :: RawEdge
wrongKindCandidateEdge = edge strategyId contributesToStrategy strategyActionId

candidateWrongKindsGraph :: RawClaimGraph
candidateWrongKindsGraph =
  RawClaimGraph
    [assertedClaim strategyNode, assertedClaim strategyActionNode]
    [candidateClaim wrongKindCandidateEdge]

candidateExtendedSampleGraph :: RawClaimGraph
candidateExtendedSampleGraph =
  RawClaimGraph
    (map assertedClaim (rawNodes sampleGraph)
       ++ [candidateClaim (RawContextNode secondStrategyId Strategy)])
    (map assertedClaim (rawEdges sampleGraph)
       ++ [candidateClaim candidateDependencyEdge])

candidateEthosContentGraph :: RawClaimGraph
candidateEthosContentGraph =
  RawClaimGraph
    [ assertedClaim (RawContextNode ethosId Ethos)
    , candidateClaim ethosPrincipleNode
    ]
    []

ethosPrincipleNode :: RawNode
ethosPrincipleNode = RawPrimitiveNode ethosPrincipleId ethosId Principle

withClaimStructure ::
     RawClaimGraph -> (StructuralAssessment -> Assertion) -> Assertion
withClaimStructure raw action =
  case validateClaimStructure raw of
    StructureAccepted assessment -> action assessment
    StructureModelRejected errors ->
      assertFailure ("unexpected structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      assertFailure ("unexpected internal failure: " ++ show internal)

withStructural :: RawGraph -> (StructuralAssessment -> Assertion) -> Assertion
withStructural raw action =
  case validateStructure raw of
    StructureAccepted assessment -> action assessment
    StructureModelRejected errors ->
      assertFailure ("unexpected structural errors: " ++ show errors)
    StructureInternalFailure internal ->
      assertFailure ("unexpected internal failure: " ++ show internal)

contextIdentifiersOf :: WellFormedGraph -> [RawNodeId]
contextIdentifiersOf graph =
  concatMap (contextNodesOf graph) [minBound .. maxBound]

assertNoSemanticModel :: ModelAssessment -> Assertion
assertNoSemanticModel assessment =
  case assessedSemanticModel assessment of
    Nothing -> pure ()
    Just _ -> assertFailure "unresolved assessment exposed semantic model"

macroRuleTests :: TestTree
macroRuleTests =
  testGroup
    "macro evidence rules"
    [ testCase "every registered macrorelation has exactly one rule"
        $ macroRuleConclusions @?= registeredMacroConclusions
    , testCase "kind-mismatched context endpoints do not form a claim"
        $ null (macroClaims kindMismatchedMacroIndex)
            @? "unexpected macro claim"
    , testCase "claim buckets preserve duplicate occurrences and source order" $ do
        let index =
              buildMacroFactIndex
                macroTestNodes
                [(7 :: Int, macroTestClaim), (3, macroTestClaim)]
            claims =
              macroClaimsFor
                index
                macroEthosId
                (FixedRelation GuidesMissionCode)
                macroMissionId
        map fst claims @?= [7, 3]
    , testCase "claim keys resist endpoint and context-kind collisions" $ do
        length (macroClaims collisionMacroIndex) @?= 1
        length
          (macroClaimsFor
             collisionMacroIndex
             macroEthosId
             (FixedRelation GuidesMissionCode)
             macroMissionId)
          @?= 1
    , testCase "conservative discovery returns persisted premise occurrences"
        $ withOnlyMacroClaim baseMacroIndex
        $ \claim ->
            map
              macroDependencyEdge
              (macroScopeDependencies baseMacroIndex claim)
              @?= [2 :: Int]
    , testCase "conservative discovery is monotone under added facts"
        $ withOnlyMacroClaim baseMacroIndex
        $ \claim -> do
            let base =
                  map
                    macroDependencyEdge
                    (macroScopeDependencies baseMacroIndex claim)
                extended =
                  map
                    macroDependencyEdge
                    (macroScopeDependencies extendedMacroIndex claim)
            assertBool
              "an added fact removed a macro dependency"
              (all (`elem` extended) base)
            extended @?= [2, 3 :: Int]
    , testCase "exact-rule fixtures cover every registered macrorelation"
        $ sort
            (nub
               (concatMap
                  (map (macroClaimConclusion . snd)
                     . macroClaims
                     . macroIndexFor)
                  [sampleGraph, orientationMacroGraph, strategyMacroGraph]))
            @?= registeredMacroConclusions
    , testCase "every exact witness premise is conservatively discoverable" $ do
        assertGraphWitnessesAreConservative
          sampleGraph
          [sampleStrategyFormulation]
        assertGraphWitnessesAreConservative orientationMacroGraph []
        assertGraphWitnessesAreConservative
          strategyMacroGraph
          [sampleStrategyFormulation, secondStrategyFormulation]
    ]

macroRuleConclusions :: [RelationCode]
macroRuleConclusions =
  sort (map macroEvidenceRuleConclusion (NonEmpty.toList macroEvidenceRules))

registeredMacroConclusions :: [RelationCode]
registeredMacroConclusions =
  sort
    [ relationCodeOf relation
    | relation <- allRelations
    , MacroRelation _ <- [Language.relationSemanticsOf relation]
    ]

baseMacroIndex :: MacroFactIndex Int Int
baseMacroIndex =
  buildMacroFactIndex
    macroTestNodes
    [(1, macroTestClaim), (2, macroTestPremise)]

extendedMacroIndex :: MacroFactIndex Int Int
extendedMacroIndex =
  buildMacroFactIndex
    macroTestNodes
    [ (1, macroTestClaim)
    , (2, macroTestPremise)
    , (3, macroTestPremise)
    , (4, RawEdge macroEthosId (RelationName "unrelated") macroMissionId)
    ]

kindMismatchedMacroIndex :: MacroFactIndex Int Int
kindMismatchedMacroIndex =
  buildMacroFactIndex
    [ (1, RawContextNode macroEthosId Ethos)
    , (2, RawContextNode macroMissionId Vision)
    ]
    [(1, macroTestClaim)]

collisionMacroIndex :: MacroFactIndex Int Int
collisionMacroIndex =
  buildMacroFactIndex
    [ (1, RawContextNode macroEthosId Ethos)
    , (2, RawContextNode macroEthosId Vision)
    , (3, RawContextNode macroMissionId Mission)
    , (4, RawContextNode macroMissionId Need)
    ]
    [(1, macroTestClaim)]

macroTestNodes :: [(Int, RawNode)]
macroTestNodes =
  [ (1, RawContextNode macroEthosId Ethos)
  , (2, RawContextNode macroMissionId Mission)
  , (3, RawPrimitiveNode macroPrincipleId macroEthosId Principle)
  , (4, RawPrimitiveNode macroDriverId macroMissionId Driver)
  ]

macroTestClaim :: RawEdge
macroTestClaim = edge macroEthosId guidesMission macroMissionId

macroTestPremise :: RawEdge
macroTestPremise =
  edge macroPrincipleId guidesEthosPrincipleToMissionDriver macroDriverId

macroEthosId, macroMissionId, macroPrincipleId, macroDriverId :: RawNodeId
macroEthosId = RawNodeId "macro-ethos"

macroMissionId = RawNodeId "macro-mission"

macroPrincipleId = RawNodeId "macro-principle"

macroDriverId = RawNodeId "macro-driver"

withOnlyMacroClaim ::
     MacroFactIndex node edge -> (MacroClaim node -> Assertion) -> Assertion
withOnlyMacroClaim index action =
  case macroClaims index of
    [(_, claim)] -> action claim
    claims ->
      assertFailure ("expected one macro claim, got " ++ show (length claims))

macroIndexFor :: RawGraph -> MacroFactIndex RawNodeId RawEdge
macroIndexFor raw =
  buildMacroFactIndex
    [(rawNodeIdentifier node, node) | node <- rawNodes raw]
    [(candidate, candidate) | candidate <- rawEdges raw]

orientationMacroGraph :: RawGraph
orientationMacroGraph =
  RawGraph
    [ RawContextNode macroEthosId Ethos
    , RawContextNode macroMissionId Mission
    , RawContextNode orientationVisionId Vision
    , RawPrimitiveNode macroPrincipleId macroEthosId Principle
    , RawPrimitiveNode macroDriverId macroMissionId Driver
    , RawPrimitiveNode orientationObjectiveId orientationVisionId Objective
    ]
    [ edge macroEthosId guidesMission macroMissionId
    , edge macroMissionId groundsVision orientationVisionId
    , edge macroEthosId guidesVision orientationVisionId
    , macroTestPremise
    , edge
        macroDriverId
        groundsMissionDriverToVisionObjective
        orientationObjectiveId
    , edge
        macroPrincipleId
        guidesEthosPrincipleToVisionObjective
        orientationObjectiveId
    ]

orientationVisionId, orientationObjectiveId :: RawNodeId
orientationVisionId = RawNodeId "macro-vision"

orientationObjectiveId = RawNodeId "macro-vision-objective"

strategyMacroGraph :: RawGraph
strategyMacroGraph =
  twoStrategyGraph
    (edge strategyId directsStrategy secondStrategyId)
    []
    [ edge strategyId contributesToStrategy secondStrategyId
    , edge
        strategyPrincipleId
        guidesStrategyPrincipleToPrinciple
        secondStrategyPrincipleId
    , edge
        strategyKeyResultId
        contributesStrategyKeyResultToKeyResult
        secondStrategyKeyResultId
    , edge
        strategyActionId
        contributesStrategyActionToAction
        secondStrategyActionId
    ]

assertGraphWitnessesAreConservative ::
     RawGraph -> [RawStrategyFormulation] -> Assertion
assertGraphWitnessesAreConservative raw formulations =
  withSemanticallyValid raw formulations $ \semantic ->
    let index = macroIndexFor raw
     in mapM_
          (assertExactWitnessIsConservative semantic index)
          (macroClaims index)

assertExactWitnessIsConservative ::
     SemanticallyValidModel
  -> MacroFactIndex RawNodeId RawEdge
  -> (RawEdge, MacroClaim RawNodeId)
  -> Assertion
assertExactWitnessIsConservative semantic index (_, claim) =
  case macroEvidenceWitnesses semantic claim of
    [] -> assertFailure "reference macro claim has no exact evidence witness"
    witnesses ->
      let dependencies =
            map macroDependencyEdge (macroScopeDependencies index claim)
       in mapM_
            (mapM_
               (\premise ->
                  assertBool
                    "exact premise is absent from conservative discovery"
                    (premise `elem` dependencies))
               . NonEmpty.toList
               . witnessPremises)
            witnesses

performanceDimensionRoleTests :: TestTree
performanceDimensionRoleTests =
  testGroup
    "closed performance-dimension roles"
    [ testCase "StrategySuccessDimension admits Strategy Key Results"
        $ withWellFormed strategySuccessPerformanceDimensionGraph
        $ \graph ->
            withContextRef graph SStrategy strategyId $ \strategy ->
              map
                unNodeId
                (performanceDimensionNodesIn
                   graph
                   strategy
                   StrategySuccessDimension)
                @?= [strategyPerformanceDimensionId]
    , testCase "MeasureMeasurementDimension admits Measure KPIs"
        $ withWellFormed measureMeasurementPerformanceDimensionGraph
        $ \graph ->
            withContextRef graph SMeasure measureId $ \measure ->
              map
                unNodeId
                (performanceDimensionNodesIn
                   graph
                   measure
                   MeasureMeasurementDimension)
                @?= [measurePerformanceDimensionId]
    , testCase "the registry contains exactly both admissible roles"
        $ map performanceDimensionRoleIdentity allPerformanceDimensionRoles
            @?= [ ( StrategySuccessDimensionCode
                  , PerformanceDimensionRoleName "strategy-success-dimension"
                  , Strategy
                  , KeyResult)
                , ( MeasureMeasurementDimensionCode
                  , PerformanceDimensionRoleName "measure-measurement-dimension"
                  , Measure
                  , KPI)
                ]
    , testCase "performance-dimension relation names are stable" $ do
        let strategicName =
              relationNameFor
                (containsPerformanceDimension StrategySuccessDimension)
            measurementName =
              relationNameFor
                (containsPerformanceDimension MeasureMeasurementDimension)
        strategicName
          @?= RelationName
                "strategy-performance-dimension-contains-strategy-key-result"
        measurementName
          @?= RelationName "measure-performance-dimension-contains-measure-kpi"
        map relationCodeOf (lookupRelations strategicName)
          @?= [PerformanceDimensionMembership StrategySuccessDimensionCode]
        map relationCodeOf (lookupRelations measurementName)
          @?= [PerformanceDimensionMembership MeasureMeasurementDimensionCode]
        relationNameFor indicatesMeasurePerformanceDimension
          @?= RelationName
                "strategy-driver-indicates-measure-performance-dimension"
        relationNameFor determinesMeasurePerformanceDimension
          @?= RelationName
                "strategy-key-result-determines-measure-performance-dimension"
    , QC.testProperty
        "raw performance-dimension ownership derives from the role registry"
        $ QC.forAll (QC.elements [minBound .. maxBound])
        $ \context -> rawPerformanceDimensionOwnershipMatchesRegistry context
    , testCase "StrategySuccessDimension rejects non-KeyResult membership"
        $ let invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension StrategySuccessDimension))
                  strategyActionId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (StructuringNodeKind Strategy PerformanceDimension)
                    (PrimitiveNodeKind Strategy Action)
                ]
                (validateStructure strategySuccessDimensionWithActionGraph)
    , testCase "MeasureMeasurementDimension cannot type a Strategy dimension"
        $ let invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension MeasureMeasurementDimension))
                  strategyKeyResultId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (StructuringNodeKind Strategy PerformanceDimension)
                    (PrimitiveNodeKind Strategy KeyResult)
                ]
                (validateStructure
                   strategySuccessPerformanceDimensionGraph
                     {rawEdges = [invalidEdge]})
    , testCase "Strategy dimension rejects a cross-Strategy Key Result"
        $ let foreignKeyResultId = RawNodeId "foreign-strategy-key-result"
              invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension StrategySuccessDimension))
                  foreignKeyResultId
           in assertStructuralErrors
                [ PerformanceDimensionMembershipOwnerMismatch
                    invalidEdge
                    strategyId
                    secondStrategyId
                ]
                (validateStructure
                   (RawGraph
                      [ RawContextNode strategyId Strategy
                      , RawContextNode secondStrategyId Strategy
                      , RawStructuringNode
                          strategyPerformanceDimensionId
                          strategyId
                          PerformanceDimension
                      , RawPrimitiveNode
                          foreignKeyResultId
                          secondStrategyId
                          KeyResult
                      ]
                      [invalidEdge]))
    , testCase "Measure dimension rejects a cross-Measure KPI"
        $ let secondMeasureId = RawNodeId "second-measure"
              foreignKpiId = RawNodeId "foreign-measure-kpi"
              invalidEdge =
                RawEdge
                  measurePerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension MeasureMeasurementDimension))
                  foreignKpiId
           in assertStructuralErrors
                [ PerformanceDimensionMembershipOwnerMismatch
                    invalidEdge
                    measureId
                    secondMeasureId
                ]
                (validateStructure
                   (RawGraph
                      [ RawContextNode measureId Measure
                      , RawContextNode secondMeasureId Measure
                      , RawStructuringNode
                          measurePerformanceDimensionId
                          measureId
                          PerformanceDimension
                      , RawPrimitiveNode foreignKpiId secondMeasureId KPI
                      ]
                      [invalidEdge]))
    , testCase "membership does not interpret an inadmissible Primitive"
        $ let invalidPrimitiveId = RawNodeId "strategy-kpi"
              invalidEdge =
                RawEdge
                  strategyPerformanceDimensionId
                  (relationNameFor
                     (containsPerformanceDimension StrategySuccessDimension))
                  invalidPrimitiveId
           in assertStructuralErrors
                [ InvalidPrimitiveInterpretation invalidPrimitiveId Strategy KPI
                , InvalidRelationEndpointKinds
                    invalidEdge
                    (StructuringNodeKind Strategy PerformanceDimension)
                    (PrimitiveNodeKind Strategy KPI)
                ]
                (validateStructure
                   (RawGraph
                      [ RawContextNode strategyId Strategy
                      , RawStructuringNode
                          strategyPerformanceDimensionId
                          strategyId
                          PerformanceDimension
                      , RawPrimitiveNode invalidPrimitiveId strategyId KPI
                      ]
                      [invalidEdge]))
    ]

structureTests :: TestTree
structureTests =
  testGroup
    "structural elaboration"
    [ testCase "empty graph is structurally well-formed"
        $ assertStructureAccepted (validateStructure emptyGraph)
    , testCase "complete reference graph is structurally well-formed"
        $ assertStructureAccepted (validateStructure sampleGraph)
    , testCase "typed edges expose safe total observations"
        $ withWellFormed sampleGraph
        $ \graph ->
            case graphEdges graph of
              candidate:_ -> do
                someEdgeFrom candidate @?= visionId
                someEdgeRelation candidate @?= relationNameFor orientsStrategy
                someEdgeTo candidate @?= strategyId
              [] -> assertFailure "reference graph has no edges"
    , testCase "validated context lookup returns a typed reference"
        $ withWellFormed sampleGraph
        $ \graph ->
            withContextRef graph SNeed needId $ \need ->
              contextRefId need @?= needId
    , testCase "validated context lookup rejects a false type index"
        $ withWellFormed sampleGraph
        $ \graph -> lookupContextRef graph SStrategy needId @?= Nothing
    , testCase "validated context lookup rejects non-context nodes"
        $ withWellFormed sampleGraph
        $ \graph -> lookupContextRef graph SNeed needObjectiveId @?= Nothing
    , testCase "structural errors accumulate"
        $ let invalidEdge =
                RawEdge missingId (RelationName "unknown") strategyId
           in assertStructuralErrors
                [ DuplicateNodeId strategyId
                , UnknownOwner needObjectiveId missingId
                , UnknownEdgeEndpoint invalidEdge missingId
                , UnknownRelation (RelationName "unknown")
                ]
                (validateStructure multiplyInvalidGraph)
    , testCase "duplicate edges are rejected"
        $ let duplicate = edge visionId orientsStrategy strategyId
           in assertStructuralErrors
                [DuplicateEdge duplicate]
                (validateStructure
                   sampleGraph {rawEdges = duplicate : rawEdges sampleGraph})
    , testCase "wrong relation endpoint kinds are rejected"
        $ let invalidEdge = edge needId qualifiesNeed strategyId
           in assertStructuralErrors
                [ InvalidRelationEndpointKinds
                    invalidEdge
                    (ContextNodeKind Need)
                    (ContextNodeKind Strategy)
                ]
                (validateStructure invalidRelationEndpointsGraph)
    , testCase "unknown primitive owners are rejected exactly"
        $ assertStructuralErrors
            [UnknownOwner needObjectiveId missingId]
            (validateStructure
               (RawGraph
                  [RawPrimitiveNode needObjectiveId missingId Objective]
                  []))
    , testCase "invalid primitive interpretations are rejected exactly"
        $ assertStructuralErrors
            [InvalidPrimitiveInterpretation measureKpiId Strategy KPI]
            (validateStructure
               (RawGraph
                  [ RawContextNode strategyId Strategy
                  , RawPrimitiveNode measureKpiId strategyId KPI
                  ]
                  []))
    , testCase "invalid structuring contexts are rejected exactly"
        $ assertStructuralErrors
            [ InvalidStructuringContext
                measurePerformanceDimensionId
                Need
                PerformanceDimension
            ]
            (validateStructure
               (RawGraph
                  [ RawContextNode needId Need
                  , RawStructuringNode
                      measurePerformanceDimensionId
                      needId
                      PerformanceDimension
                  ]
                  []))
    , testCase "unknown structuring owners are rejected exactly"
        $ assertStructuralErrors
            [UnknownOwner measurePerformanceDimensionId missingId]
            (validateStructure
               (RawGraph
                  [ RawStructuringNode
                      measurePerformanceDimensionId
                      missingId
                      PerformanceDimension
                  ]
                  []))
    , testCase "primitive owner conflicts are duplicate node declarations"
        $ assertStructuralErrors
            [DuplicateNodeId needObjectiveId]
            (validateStructure
               (RawGraph
                  [ RawContextNode needId Need
                  , RawContextNode visionId Vision
                  , RawPrimitiveNode needObjectiveId needId Objective
                  , RawPrimitiveNode needObjectiveId visionId Objective
                  ]
                  []))
    , testCase "structuring owner conflicts are duplicate node declarations"
        $ assertStructuralErrors
            [DuplicateNodeId measurePerformanceDimensionId]
            (validateStructure
               (RawGraph
                  [ RawContextNode strategyId Strategy
                  , RawContextNode measureId Measure
                  , RawStructuringNode
                      measurePerformanceDimensionId
                      strategyId
                      PerformanceDimension
                  , RawStructuringNode
                      measurePerformanceDimensionId
                      measureId
                      PerformanceDimension
                  ]
                  []))
    , testCase "performance dimension exposes exactly its declared owner"
        $ withWellFormed measureMeasurementPerformanceDimensionGraph
        $ \graph ->
            case lookupNode graph measurePerformanceDimensionId of
              Just node -> someNodeOwner node @?= Just measureId
              Nothing -> assertFailure "performance dimension was not found"
    , testCase "anchor has no owner and Situation assignment is relational"
        $ let secondSituationId = RawNodeId "second-situation"
           in withWellFormed
                (RawGraph
                   [ RawContextNode situationId Situation
                   , RawContextNode secondSituationId Situation
                   , RawAnchorNode situationAnchorId BusinessCapability
                   ]
                   [ anchorEdge
                       situationId
                       constitutedByAnchor
                       situationAnchorId
                   , anchorEdge
                       secondSituationId
                       constitutedByAnchor
                       situationAnchorId
                   ]) $ \graph -> do
                case lookupNode graph situationAnchorId of
                  Just node -> someNodeOwner node @?= Nothing
                  Nothing -> assertFailure "Situation anchor was not found"
                constitutingAnchorNodes graph situationId
                  @?= [situationAnchorId]
                constitutingAnchorNodes graph secondSituationId
                  @?= [situationAnchorId]
    , testCase "edge errors accumulate independently"
        $ let from = RawNodeId "unknown-from"
              to = RawNodeId "unknown-to"
              relation = RelationName "unknown"
              invalidEdge = RawEdge from relation to
           in assertStructuralErrors
                [ UnknownEdgeEndpoint invalidEdge from
                , UnknownEdgeEndpoint invalidEdge to
                , UnknownRelation relation
                ]
                (validateStructure independentlyInvalidEdgeGraph)
    , QC.testProperty "unknown endpoints accumulate"
        $ QC.forAll unknownEndpointGraph
        $ \raw ->
            case validateStructure raw of
              StructureModelRejected errors ->
                case rawEdges raw of
                  [candidate] ->
                    NonEmpty.toList errors
                      == [ UnknownEdgeEndpoint candidate (rawEdgeFrom candidate)
                         , UnknownEdgeEndpoint candidate (rawEdgeTo candidate)
                         , UnknownRelation (rawEdgeRelation candidate)
                         ]
                  _ -> False
              StructureAccepted _ -> False
              StructureInternalFailure _ -> False
    ]

semanticTests :: TestTree
semanticTests =
  testGroup
    "model semantics"
    [ testCase "complete reference model is semantically valid"
        $ withWellFormed sampleGraph
        $ \graph ->
            assertSuccess
              (validateModelSemantics graph [sampleStrategyFormulation])
    , testCase "an Ethos with one owned Principle is complete"
        $ withWellFormed minimalEthosGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "an empty Ethos is rejected at Semantics"
        $ assertSemanticErrorsWith
            (RawGraph [RawContextNode ethosId Ethos] [])
            []
            [EthosWithoutPrinciple ethosId]
    , testCase "primitive evidence completes Orientation without macro edges"
        $ withWellFormed completeOrientationGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "an empty Mission is rejected without an evidence cascade"
        $ assertSemanticErrorsWith
            minimalEthosGraph
              { rawNodes =
                  RawContextNode missionId Mission : rawNodes minimalEthosGraph
              }
            []
            [MissionWithoutDriver missionId]
    , testCase "a Mission Driver requires guidance from an Ethos Principle"
        $ assertSemanticErrorsWith
            missionContentGraph {rawEdges = []}
            []
            [MissionWithoutEthosGuidance missionId]
    , testCase "an empty Vision is rejected without an evidence cascade"
        $ assertSemanticErrorsWith
            missionContentGraph
              { rawNodes =
                  RawContextNode visionId Vision : rawNodes missionContentGraph
              }
            []
            [VisionWithoutObjective visionId]
    , testCase "a Vision Objective requires Mission grounding"
        $ assertSemanticErrorsWith
            (withoutEdge visionGroundingEdge completeOrientationGraph)
            []
            [VisionWithoutMissionGrounding visionId]
    , testCase "a Vision Objective requires Ethos guidance"
        $ assertSemanticErrorsWith
            (withoutEdge visionGuidanceEdge completeOrientationGraph)
            []
            [VisionWithoutEthosGuidance visionId]
    , testCase "explicit Orientation macro edges do not replace evidence"
        $ assertSemanticErrorsWith
            orientationMacroOnlyGraph
            []
            [ VisionWithoutMissionGrounding visionId
            , VisionWithoutEthosGuidance visionId
            ]
    , testCase "Vision evidence may use different representative Objectives"
        $ withWellFormed splitVisionEvidenceGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , QC.testProperty
        "additional owned orientation Primitives need no all-to-all evidence"
        $ QC.forAll (QC.chooseInt (0, 20))
        $ semanticsAccepts . orientationGraphWithExtras
    , QC.testProperty "removing required Orientation evidence is rejected"
        $ QC.forAll (QC.elements orientationEvidenceEdges)
        $ \required ->
            not
              (semanticsAccepts (withoutEdge required completeOrientationGraph))
    , testCase "constituted Situation without surfaced Need is valid"
        $ withWellFormed
            (RawGraph
               [ RawContextNode situationId Situation
               , RawAnchorNode situationAnchorId BusinessCapability
               ]
               [anchorEdge situationId constitutedByAnchor situationAnchorId])
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "Situation without constituting anchor is rejected"
        $ assertSemanticErrorsWith
            (RawGraph [RawContextNode situationId Situation] [])
            []
            [SituationWithoutConstitutingAnchor situationId]
    , testCase "model without Strategy requires no formulation"
        $ withWellFormed emptyGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "every Strategy requires exactly one formulation"
        $ assertSemanticErrorsWith
            sampleGraph
            []
            [StrategyWithoutFormulation strategyId]
    , testCase "duplicate Strategy formulations are rejected exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [sampleStrategyFormulation, sampleStrategyFormulation]
            [DuplicateStrategyFormulation strategyId]
    , testCase "Strategy intent requires primitive Vision orientation"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  visionObjectiveId
                  orientsVisionObjectiveToStrategyObjective
                  strategyObjectiveId)
               sampleGraph)
            [ StrategyIntentWithoutVisionOrientation
                strategyId
                strategyObjectiveId
            ]
    , testCase "Strategy orientation needs no explicit Context macro edge"
        $ withWellFormed
            (withoutEdge (edge visionId orientsStrategy strategyId) sampleGraph)
        $ \graph ->
            assertSuccess
              (validateModelSemantics graph [sampleStrategyFormulation])
    , QC.testProperty
        "additional Vision Objectives need no Strategy orientation edge"
        $ QC.forAll (QC.chooseInt (0, 20))
        $ \extraCount ->
            semanticsAcceptsWith
              (strategyGraphWithExtraVisionObjectives extraCount)
              [sampleStrategyFormulation]
    , testCase "unknown formulation Strategy is rejected exactly"
        $ assertSemanticErrorsWith
            emptyGraph
            [sampleStrategyFormulation {rawFormulationStrategy = missingId}]
            [UnknownFormulationStrategy missingId]
    , testCase "non-Strategy formulation owner is rejected exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [ sampleStrategyFormulation
            , sampleStrategyFormulation {rawFormulationStrategy = needId}
            ]
            [FormulationForNonStrategy needId (ContextNodeKind Need)]
    , testCase "all Strategy text fields require nonblank content"
        $ assertSemanticErrorsWith
            sampleGraph
            [blankStrategyFormulation]
            [ EmptyStrategyText strategyId ScopeField
            , EmptyStrategyText strategyId PeriodField
            , EmptyStrategyText strategyId ResponsibilityScopeField
            , EmptyStrategyText strategyId DecisionLevelField
            , EmptyStrategyText strategyId ResponsibilitiesField
            , EmptyStrategyText strategyId DecisionPathsField
            , EmptyStrategyText strategyId ImplementationLogicField
            , EmptyStrategyText strategyId GuardrailsField
            , EmptyStrategyText strategyId PositioningField
            , EmptyStrategyText strategyId TradeOffsField
            , EmptyStrategyText strategyId FitRationaleField
            ]
    , testCase "independent role errors accumulate without coherence cascades"
        $ assertSemanticErrorsWith
            sampleGraph
            [invalidRoleStrategyFormulation]
            [ InvalidStrategyPrimitiveReference
                strategyId
                DiagnosisRole
                needDriverId
                Driver
            , InvalidStrategyPrimitiveReference
                strategyId
                IntentRole
                strategyDriverId
                Objective
            , InvalidStrategyPrimitiveReference
                strategyId
                GuidingPolicyRole
                strategyObjectiveId
                Principle
            , InvalidStrategyPrimitiveReference
                strategyId
                CoherentActionRole
                interventionActionId
                Action
            , InvalidStrategyPrimitiveReference
                strategyId
                StrategicKeyResultRole
                interventionKeyResultId
                KeyResult
            ]
    , testCase "duplicate Action and Key Result references accumulate exactly"
        $ assertSemanticErrorsWith
            sampleGraph
            [duplicateReferenceStrategyFormulation]
            [ DuplicateStrategyPrimitiveReference
                strategyId
                CoherentActionRole
                strategyActionId
            , DuplicateStrategyPrimitiveReference
                strategyId
                StrategicKeyResultRole
                strategyKeyResultId
            ]
    , testCase "diagnosis must ground strategic intention"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyDriverId
                  groundsStrategyDriverToObjective
                  strategyObjectiveId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyDriverId
                (relationNameFor groundsStrategyDriverToObjective)
                strategyObjectiveId
            ]
    , testCase "guiding policy must guide every coherent Action"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyPrincipleId
                  guidesStrategyPrincipleToAction
                  strategyActionId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyPrincipleId
                (relationNameFor guidesStrategyPrincipleToAction)
                strategyActionId
            ]
    , testCase "every coherent Action must contribute to a Key Result"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyActionId
                  contributesStrategyActionToKeyResult
                  strategyKeyResultId)
               sampleGraph)
            [StrategyActionWithoutKeyResult strategyId strategyActionId]
    , testCase "every strategic Key Result must substantiate intention"
        $ assertSemanticErrors
            (withoutEdge
               (edge
                  strategyKeyResultId
                  substantiatesStrategyKeyResultObjective
                  strategyObjectiveId)
               sampleGraph)
            [ MissingStrategyCoherence
                strategyId
                strategyKeyResultId
                (relationNameFor substantiatesStrategyKeyResultObjective)
                strategyObjectiveId
            ]
    , testCase "Strategy coherence covers every listed Action and Key Result"
        $ assertSemanticErrorsWith
            (withoutEdge
               (edge
                  semanticExtraStrategyKeyResultId
                  substantiatesStrategyKeyResultObjective
                  strategyObjectiveId)
               (withoutEdge
                  (edge
                     semanticExtraStrategyActionId
                     contributesStrategyActionToKeyResult
                     strategyKeyResultId)
                  (withoutEdge
                     (edge
                        strategyPrincipleId
                        guidesStrategyPrincipleToAction
                        semanticExtraStrategyActionId)
                     multiRoleStrategyGraph)))
            [multiRoleStrategyFormulation]
            [ MissingStrategyCoherence
                strategyId
                strategyPrincipleId
                (relationNameFor guidesStrategyPrincipleToAction)
                semanticExtraStrategyActionId
            , StrategyActionWithoutKeyResult
                strategyId
                semanticExtraStrategyActionId
            , MissingStrategyCoherence
                strategyId
                semanticExtraStrategyKeyResultId
                (relationNameFor substantiatesStrategyKeyResultObjective)
                strategyObjectiveId
            ]
    , testCase "an internally complete Intervention is semantically valid"
        $ withWellFormed minimalInterventionGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "an empty Intervention reports both missing constituents"
        $ assertSemanticErrorsWith
            (RawGraph [RawContextNode interventionId Intervention] [])
            []
            [ InterventionWithoutAction interventionId
            , InterventionWithoutKeyResult interventionId
            ]
    , testCase "an Intervention Action does not imply a Key Result"
        $ assertSemanticErrorsWith
            (RawGraph
               [ RawContextNode interventionId Intervention
               , RawPrimitiveNode interventionActionId interventionId Action
               ]
               [])
            []
            [InterventionWithoutKeyResult interventionId]
    , testCase "an Intervention Key Result does not imply an Action"
        $ assertSemanticErrorsWith
            (RawGraph
               [ RawContextNode interventionId Intervention
               , RawPrimitiveNode
                   interventionKeyResultId
                   interventionId
                   KeyResult
               ]
               [])
            []
            [InterventionWithoutAction interventionId]
    , testCase "Intervention Action must contribute to its Key Result"
        $ assertSemanticErrorsWith
            minimalInterventionGraph {rawEdges = []}
            []
            [InterventionWithoutActionContribution interventionId]
    , QC.testProperty
        "additional Intervention content needs no all-to-all contribution"
        $ QC.forAll (QC.chooseInt (0, 20))
        $ semanticsAccepts . interventionGraphWithExtras
    , testCase "an internally complete Measure is semantically valid"
        $ withWellFormed measureMeasurementPerformanceDimensionGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "an empty Measure reports both missing constituents"
        $ assertSemanticErrorsWith
            (RawGraph [RawContextNode measureId Measure] [])
            []
            [ MeasureWithoutPerformanceDimension measureId
            , MeasureWithoutKPI measureId
            ]
    , testCase "a measurement dimension does not imply a KPI"
        $ assertSemanticErrorsWith
            (RawGraph
               [ RawContextNode measureId Measure
               , RawStructuringNode
                   measurePerformanceDimensionId
                   measureId
                   PerformanceDimension
               ]
               [])
            []
            [MeasureWithoutKPI measureId]
    , testCase "a Measure KPI does not imply a measurement dimension"
        $ assertSemanticErrorsWith
            (RawGraph
               [ RawContextNode measureId Measure
               , RawPrimitiveNode measureKpiId measureId KPI
               ]
               [])
            []
            [MeasureWithoutPerformanceDimension measureId]
    , testCase "Measure KPI must belong to its measurement dimension"
        $ assertSemanticErrorsWith
            measureMeasurementPerformanceDimensionGraph {rawEdges = []}
            []
            [MeasureWithoutKPIDimensionMembership measureId]
    , QC.testProperty
        "additional Measure content needs no all-to-all membership"
        $ QC.forAll (QC.chooseInt (0, 20))
        $ semanticsAccepts . measureGraphWithExtras
    , testCase "a minimally situated Need is semantically valid"
        $ withWellFormed minimalNeedGraph
        $ \graph -> assertSuccess (validateModelSemantics graph [])
    , testCase "every Need Driver requires a constituting anchor"
        $ assertSemanticErrorsWith
            minimalNeedGraph
              { rawNodes =
                  RawPrimitiveNode semanticExtraNeedDriverId needId Driver
                    : rawNodes minimalNeedGraph
              }
            []
            [UnanchoredNeedDriver needId semanticExtraNeedDriverId]
    , testCase "every Need Objective requires an owned grounding Driver"
        $ assertSemanticErrorsWith
            minimalNeedGraph
              { rawNodes =
                  RawPrimitiveNode semanticExtraNeedObjectiveId needId Objective
                    : rawNodes minimalNeedGraph
              }
            []
            [UngroundedNeedObjective needId semanticExtraNeedObjectiveId]
    , testCase "need requires a driver"
        $ assertSemanticErrors
            (removeNode needDriverId sampleGraph)
            [ NeedWithoutDriver needId
            , UngroundedNeedObjective needId needObjectiveId
            ]
    , testCase "need requires an objective"
        $ assertSemanticErrors
            (removeNode needObjectiveId sampleGraph)
            [NeedWithoutObjective needId]
    , testCase "need requires a surfacing situation"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= edge situationId surfacesNeed needId)
                    (rawEdges sampleGraph)
              }
            [ NeedWithoutSurfacingSituation needId
            , UnanchoredNeedDriver needId needDriverId
            ]
    , testCase "need driver requires a situation anchor"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= anchorEdge
                          situationAnchorId
                          anchorsNeedDriver
                          needDriverId)
                    (rawEdges sampleGraph)
              }
            [UnanchoredNeedDriver needId needDriverId]
    , testCase "need objective requires grounding"
        $ assertSemanticErrors
            sampleGraph
              { rawEdges =
                  filter
                    (/= edge
                          needDriverId
                          groundsNeedDriverToObjective
                          needObjectiveId)
                    (rawEdges sampleGraph)
              }
            [UngroundedNeedObjective needId needObjectiveId]
    , testCase "situated unqualified need is semantically valid"
        $ withWellFormed unqualifiedNeedGraph
        $ \graph ->
            assertSuccess
              (validateModelSemantics graph [sampleStrategyFormulation])
    ]

minimalEthosGraph :: RawGraph
minimalEthosGraph =
  RawGraph
    [ RawContextNode ethosId Ethos
    , RawPrimitiveNode ethosPrincipleId ethosId Principle
    ]
    []

missionContentGraph :: RawGraph
missionContentGraph =
  RawGraph
    (RawContextNode missionId Mission
       : RawPrimitiveNode missionDriverId missionId Driver
       : rawNodes minimalEthosGraph)
    [missionGuidanceEdge]

completeOrientationGraph :: RawGraph
completeOrientationGraph =
  RawGraph
    (RawContextNode visionId Vision
       : RawPrimitiveNode visionObjectiveId visionId Objective
       : rawNodes missionContentGraph)
    orientationEvidenceEdges

orientationMacroOnlyGraph :: RawGraph
orientationMacroOnlyGraph =
  completeOrientationGraph
    { rawEdges =
        [ missionGuidanceEdge
        , edge ethosId guidesMission missionId
        , edge missionId groundsVision visionId
        , edge ethosId guidesVision visionId
        ]
    }

splitVisionEvidenceGraph :: RawGraph
splitVisionEvidenceGraph =
  completeOrientationGraph
    { rawNodes =
        RawPrimitiveNode secondVisionObjectiveId visionId Objective
          : rawNodes completeOrientationGraph
    , rawEdges =
        edge
          ethosPrincipleId
          guidesEthosPrincipleToVisionObjective
          secondVisionObjectiveId
          : filter (/= visionGuidanceEdge) orientationEvidenceEdges
    }

orientationGraphWithExtras :: Int -> RawGraph
orientationGraphWithExtras extraCount =
  completeOrientationGraph
    { rawNodes =
        extraDrivers ++ extraObjectives ++ rawNodes completeOrientationGraph
    }
  where
    suffixes = [1 .. extraCount]
    extraDrivers =
      [ RawPrimitiveNode
        (RawNodeId ("extra-mission-driver-" <> Text.pack (show suffix)))
        missionId
        Driver
      | suffix <- suffixes
      ]
    extraObjectives =
      [ RawPrimitiveNode
        (RawNodeId ("extra-vision-objective-" <> Text.pack (show suffix)))
        visionId
        Objective
      | suffix <- suffixes
      ]

strategyGraphWithExtraVisionObjectives :: Int -> RawGraph
strategyGraphWithExtraVisionObjectives extraCount =
  sampleGraph {rawNodes = extraObjectives ++ rawNodes sampleGraph}
  where
    extraObjectives =
      [ RawPrimitiveNode
        (RawNodeId
           ("extra-strategy-vision-objective-" <> Text.pack (show suffix)))
        visionId
        Objective
      | suffix <- [1 .. extraCount]
      ]

multiRoleStrategyGraph :: RawGraph
multiRoleStrategyGraph =
  sampleGraph
    { rawNodes =
        [ RawPrimitiveNode semanticExtraStrategyActionId strategyId Action
        , RawPrimitiveNode semanticExtraStrategyKeyResultId strategyId KeyResult
        ]
          ++ rawNodes sampleGraph
    , rawEdges =
        [ edge
            strategyPrincipleId
            guidesStrategyPrincipleToAction
            semanticExtraStrategyActionId
        , edge
            semanticExtraStrategyActionId
            contributesStrategyActionToKeyResult
            strategyKeyResultId
        , edge
            semanticExtraStrategyKeyResultId
            substantiatesStrategyKeyResultObjective
            strategyObjectiveId
        ]
          ++ rawEdges sampleGraph
    }

multiRoleStrategyFormulation :: RawStrategyFormulation
multiRoleStrategyFormulation =
  sampleStrategyFormulation
    { rawFormulationActions =
        strategyActionId NonEmpty.:| [semanticExtraStrategyActionId]
    , rawFormulationKeyResults =
        strategyKeyResultId NonEmpty.:| [semanticExtraStrategyKeyResultId]
    }

minimalNeedGraph :: RawGraph
minimalNeedGraph =
  RawGraph
    [ RawContextNode situationId Situation
    , RawAnchorNode situationAnchorId BusinessCapability
    , RawContextNode needId Need
    , RawPrimitiveNode needDriverId needId Driver
    , RawPrimitiveNode needObjectiveId needId Objective
    ]
    [ anchorEdge situationId constitutedByAnchor situationAnchorId
    , edge situationId surfacesNeed needId
    , anchorEdge situationAnchorId anchorsNeedDriver needDriverId
    , edge needDriverId groundsNeedDriverToObjective needObjectiveId
    ]

minimalInterventionGraph :: RawGraph
minimalInterventionGraph =
  RawGraph
    [ RawContextNode interventionId Intervention
    , RawPrimitiveNode interventionActionId interventionId Action
    , RawPrimitiveNode interventionKeyResultId interventionId KeyResult
    ]
    [ edge
        interventionActionId
        contributesInterventionActionToKeyResult
        interventionKeyResultId
    ]

interventionGraphWithExtras :: Int -> RawGraph
interventionGraphWithExtras extraCount =
  minimalInterventionGraph
    {rawNodes = extraNodes ++ rawNodes minimalInterventionGraph}
  where
    extraNodes = concatMap extraPair [1 .. extraCount]
    extraPair suffix =
      [ RawPrimitiveNode (identifier "action" suffix) interventionId Action
      , RawPrimitiveNode
          (identifier "key-result" suffix)
          interventionId
          KeyResult
      ]
    identifier kind suffix =
      RawNodeId
        ("extra-intervention-" <> kind <> "-" <> Text.pack (show suffix))

measureGraphWithExtras :: Int -> RawGraph
measureGraphWithExtras extraCount =
  measureMeasurementPerformanceDimensionGraph
    { rawNodes =
        extraNodes ++ rawNodes measureMeasurementPerformanceDimensionGraph
    }
  where
    extraNodes = concatMap extraPair [1 .. extraCount]
    extraPair suffix =
      [ RawStructuringNode
          (identifier "dimension" suffix)
          measureId
          PerformanceDimension
      , RawPrimitiveNode (identifier "kpi" suffix) measureId KPI
      ]
    identifier kind suffix =
      RawNodeId ("extra-measure-" <> kind <> "-" <> Text.pack (show suffix))

orientationEvidenceEdges :: [RawEdge]
orientationEvidenceEdges =
  [missionGuidanceEdge, visionGroundingEdge, visionGuidanceEdge]

missionGuidanceEdge :: RawEdge
missionGuidanceEdge =
  edge ethosPrincipleId guidesEthosPrincipleToMissionDriver missionDriverId

visionGroundingEdge :: RawEdge
visionGroundingEdge =
  edge missionDriverId groundsMissionDriverToVisionObjective visionObjectiveId

visionGuidanceEdge :: RawEdge
visionGuidanceEdge =
  edge ethosPrincipleId guidesEthosPrincipleToVisionObjective visionObjectiveId

secondVisionObjectiveId :: RawNodeId
secondVisionObjectiveId = RawNodeId "second-vision-objective"

semanticExtraStrategyActionId, semanticExtraStrategyKeyResultId :: RawNodeId
semanticExtraStrategyActionId = RawNodeId "semantic-extra-strategy-action"

semanticExtraStrategyKeyResultId =
  RawNodeId "semantic-extra-strategy-key-result"

semanticExtraNeedDriverId, semanticExtraNeedObjectiveId :: RawNodeId
semanticExtraNeedDriverId = RawNodeId "semantic-extra-need-driver"

semanticExtraNeedObjectiveId = RawNodeId "semantic-extra-need-objective"

semanticsAccepts :: RawGraph -> Bool
semanticsAccepts raw = semanticsAcceptsWith raw []

semanticsAcceptsWith :: RawGraph -> [RawStrategyFormulation] -> Bool
semanticsAcceptsWith raw formulations =
  case validateStructure raw of
    StructureAccepted assessment ->
      case validateModelSemantics (structuralGraph assessment) formulations of
        Success _ -> True
        Failure _ -> False
    StructureModelRejected _ -> False
    StructureInternalFailure _ -> False

traceTests :: TestTree
traceTests =
  testGroup
    "relational effect trace"
    ([ testCase "empty model is not traceable"
         $ withSemanticallyValid emptyGraph []
         $ \model ->
             assertTraceabilityErrors
               [NoIntervention]
               (validateTraceability model)
     , testCase "complete reference model is traceable"
         $ withTraceable sampleGraph (const (pure ()))
     , testCase "effect-trace identity representation is stable"
         $ withTraceable sampleGraph
         $ \model ->
             effectTraceIdText
               (traceIdentifier (NonEmpty.head (effectTraces model)))
               @?= "19;19:o2i-effect-trace-v16:vision16:vision-objective8:strategy15:strategy-driver18:strategy-objective19:strategy-key-result15:strategy-action4:need11:need-driver14:need-objective12:intervention19:intervention-action23:intervention-key-result7:measure29:measure-performance-dimension11:measure-kpi9:situation16:situation-anchor"
     , testCase "effect traces expose every typed proof-path constituent"
         $ withTraceable sampleGraph
         $ \model ->
             let trace = NonEmpty.head (effectTraces model)
              in do
                   contextRefId (traceVision trace) @?= visionId
                   unNodeId (traceVisionObjective trace) @?= visionObjectiveId
                   contextRefId (traceStrategy trace) @?= strategyId
                   unNodeId (traceStrategyDriver trace) @?= strategyDriverId
                   unNodeId (traceStrategyObjective trace)
                     @?= strategyObjectiveId
                   unNodeId (traceStrategyKeyResult trace)
                     @?= strategyKeyResultId
                   unNodeId (traceStrategyAction trace) @?= strategyActionId
                   contextRefId (traceNeed trace) @?= needId
                   unNodeId (traceNeedDriver trace) @?= needDriverId
                   unNodeId (traceNeedObjective trace) @?= needObjectiveId
                   contextRefId (traceIntervention trace) @?= interventionId
                   unNodeId (traceInterventionAction trace)
                     @?= interventionActionId
                   unNodeId (traceInterventionKeyResult trace)
                     @?= interventionKeyResultId
                   contextRefId (traceMeasure trace) @?= measureId
                   unNodeId (traceMeasurePerformanceDimension trace)
                     @?= measurePerformanceDimensionId
                   unNodeId (traceKPI trace) @?= measureKpiId
                   contextRefId (traceSituation trace) @?= situationId
                   situationAnchorRefId (traceSituationAnchor trace)
                     @?= situationAnchorId
                   situationAnchorRefKind (traceSituationAnchor trace)
                     @?= BusinessCapability
     , testCase "every Intervention must address a Need"
         $ withSemanticallyValid
             (withoutEdge (edge interventionId addressesNeed needId) sampleGraph)
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [InterventionWithoutNeed interventionId]
               (validateTraceability model)
     , testCase "every addressed need requires a complete trace"
         $ withSemanticallyValid
             additionalUntracedNeedGraph
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [MissingEffectTrace interventionId additionalNeedId]
               (validateTraceability model)
     , testCase "every macrorelation requires primitive evidence"
         $ withSemanticallyValid
             macroWithoutEvidenceGraph
             [sampleStrategyFormulation]
         $ \model ->
             assertTraceabilityErrors
               [ MissingMacroEvidence
                   secondMissionId
                   (relationNameFor groundsVision)
                   visionId
               ]
               (validateTraceability model)
     , testCase "parallel primitive paths produce distinct traces"
         $ withTraceable twoPathGraph
         $ \model -> do
             let identifiers =
                   map traceIdentifier (NonEmpty.toList (effectTraces model))
             length identifiers @?= 2
             length (nub identifiers) @?= 2
     , testCase "unlisted Strategy primitives cannot substantiate a trace"
         $ withTraceable unlistedStrategyPathGraph
         $ \model ->
             map
               (unNodeId . traceInterventionKeyResult)
               (NonEmpty.toList (effectTraces model))
               @?= [interventionKeyResultId]
     , unlistedStrategyMacroTest
         "unlisted Key Result cannot substantiate qualifies"
         unlistedQualifiesGraph
         (edge strategyId qualifiesNeed needId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted Action cannot substantiate directs Intervention"
         unlistedDirectsInterventionGraph
         (edge strategyId directsIntervention interventionId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted diagnosis and Key Result cannot substantiate frames"
         unlistedFramesGraph
         (edge strategyId framesMeasure measureId)
         [sampleStrategyFormulation]
         [MissingEffectTrace interventionId needId]
     , unlistedStrategyMacroTest
         "unlisted policies cannot substantiate directs Strategy"
         unlistedDirectsStrategyGraph
         (edge strategyId directsStrategy secondStrategyId)
         [sampleStrategyFormulation, secondStrategyFormulation]
         []
     , unlistedStrategyMacroTest
         "unlisted Actions and Key Results cannot substantiate contributes"
         unlistedContributesStrategyGraph
         (edge strategyId contributesToStrategy secondStrategyId)
         [sampleStrategyFormulation, secondStrategyFormulation]
         []
     ]
       ++ map missingEdgeTest (rawEdges sampleGraph)
       ++ [ QC.testProperty "removing any effect-path edge is rejected"
              $ QC.forAll (QC.elements (rawEdges sampleGraph))
              $ \missingEdge ->
                  traceabilityFails
                    sampleGraph
                      { rawEdges =
                          filter (/= missingEdge) (rawEdges sampleGraph)
                      }
          , QC.testProperty "all situation anchor types are traceable"
              $ QC.forAll (QC.elements [minBound .. maxBound])
              $ \anchor -> traceabilitySucceeds (graphWithAnchor anchor)
          ])

data MissingEdgeExpectation
  = SemanticExpectation [ModelInvariantError]
  | TraceExpectation [TraceabilityError]

missingEdgeTest :: RawEdge -> TestTree
missingEdgeTest missingEdge =
  testCase ("trace rejects missing edge " ++ show missingEdge) $ do
    let raw = withoutEdge missingEdge sampleGraph
    case missingEdgeExpectation missingEdge of
      Just (SemanticExpectation expected) -> assertSemanticErrors raw expected
      Just (TraceExpectation expected) ->
        withSemanticallyValid raw [sampleStrategyFormulation] $ \model ->
          assertTraceabilityErrors expected (validateTraceability model)
      Nothing -> assertFailure "missing exact edge-error expectation"

unlistedStrategyMacroTest ::
     TestName
  -> RawGraph
  -> RawEdge
  -> [RawStrategyFormulation]
  -> [TraceabilityError]
  -> TestTree
unlistedStrategyMacroTest name raw macro formulations additionalErrors =
  testCase name
    $ withSemanticallyValid raw formulations
    $ \model ->
        assertTraceabilityErrors
          (MissingMacroEvidence
             (rawEdgeFrom macro)
             (rawEdgeRelation macro)
             (rawEdgeTo macro)
             : additionalErrors)
          (validateTraceability model)

missingEdgeExpectation :: RawEdge -> Maybe MissingEdgeExpectation
missingEdgeExpectation candidate
  | candidate
      == edge
           ethosPrincipleId
           guidesEthosPrincipleToMissionDriver
           missionDriverId =
    Just (SemanticExpectation [MissionWithoutEthosGuidance missionId])
  | candidate
      == edge
           missionDriverId
           groundsMissionDriverToVisionObjective
           visionObjectiveId =
    Just (SemanticExpectation [VisionWithoutMissionGrounding visionId])
  | candidate
      == edge
           ethosPrincipleId
           guidesEthosPrincipleToVisionObjective
           visionObjectiveId =
    Just (SemanticExpectation [VisionWithoutEthosGuidance visionId])
  | candidate
      == edge
           visionObjectiveId
           orientsVisionObjectiveToStrategyObjective
           strategyObjectiveId =
    Just
      (SemanticExpectation
         [StrategyIntentWithoutVisionOrientation strategyId strategyObjectiveId])
  | candidate == edge situationId surfacesNeed needId =
    Just
      (SemanticExpectation
         [ NeedWithoutSurfacingSituation needId
         , UnanchoredNeedDriver needId needDriverId
         ])
  | candidate
      == edge
           strategyDriverId
           groundsStrategyDriverToObjective
           strategyObjectiveId =
    semanticCoherence
      strategyDriverId
      groundsStrategyDriverToObjective
      strategyObjectiveId
  | candidate
      == edge
           strategyPrincipleId
           guidesStrategyPrincipleToAction
           strategyActionId =
    semanticCoherence
      strategyPrincipleId
      guidesStrategyPrincipleToAction
      strategyActionId
  | candidate
      == edge
           strategyKeyResultId
           substantiatesStrategyKeyResultObjective
           strategyObjectiveId =
    semanticCoherence
      strategyKeyResultId
      substantiatesStrategyKeyResultObjective
      strategyObjectiveId
  | candidate
      == edge
           strategyActionId
           contributesStrategyActionToKeyResult
           strategyKeyResultId =
    Just
      (SemanticExpectation
         [StrategyActionWithoutKeyResult strategyId strategyActionId])
  | candidate == edge needDriverId groundsNeedDriverToObjective needObjectiveId =
    Just (SemanticExpectation [UngroundedNeedObjective needId needObjectiveId])
  | candidate == anchorEdge situationId constitutedByAnchor situationAnchorId =
    Just
      (SemanticExpectation
         [ SituationWithoutConstitutingAnchor situationId
         , UnanchoredNeedDriver needId needDriverId
         ])
  | candidate == anchorEdge situationAnchorId anchorsNeedDriver needDriverId =
    unanchoredNeedDriver
  | candidate
      == edge
           interventionActionId
           contributesInterventionActionToKeyResult
           interventionKeyResultId =
    Just
      (SemanticExpectation
         [InterventionWithoutActionContribution interventionId])
  | candidate
      == edge
           measurePerformanceDimensionId
           (containsPerformanceDimension MeasureMeasurementDimension)
           measureKpiId =
    Just (SemanticExpectation [MeasureWithoutKPIDimensionMembership measureId])
  | candidate == edge interventionId addressesNeed needId =
    Just (TraceExpectation [InterventionWithoutNeed interventionId])
  | Just (from, relation, to) <- missingMacroEvidence candidate =
    Just
      (TraceExpectation
         [ MissingMacroEvidence from relation to
         , MissingEffectTrace interventionId needId
         ])
  | candidate `elem` traceOnlyEdges =
    Just (TraceExpectation [MissingEffectTrace interventionId needId])
  | otherwise = Nothing
  where
    semanticCoherence ::
         RawNodeId
      -> Relation from to
      -> RawNodeId
      -> Maybe MissingEdgeExpectation
    semanticCoherence from relation to =
      Just
        (SemanticExpectation
           [ MissingStrategyCoherence
               strategyId
               from
               (relationNameFor relation)
               to
           ])
    unanchoredNeedDriver =
      Just (SemanticExpectation [UnanchoredNeedDriver needId needDriverId])

missingMacroEvidence :: RawEdge -> Maybe (RawNodeId, RelationName, RawNodeId)
missingMacroEvidence candidate
  | candidate
      == edge
           visionObjectiveId
           orientsVisionObjectiveToStrategyObjective
           strategyObjectiveId = macro visionId orientsStrategy strategyId
  | candidate
      == edge
           strategyKeyResultId
           translatesStrategyKeyResultToNeedObjective
           needObjectiveId = macro strategyId qualifiesNeed needId
  | candidate
      == edge
           strategyActionId
           guidesStrategyActionToInterventionAction
           interventionActionId =
    macro strategyId directsIntervention interventionId
  | candidate
      == edge
           interventionKeyResultId
           substantiatesInterventionKeyResultNeedObjective
           needObjectiveId = macro interventionId addressesNeed needId
  | candidate `elem` measureFramingEdges =
    macro strategyId framesMeasure measureId
  | candidate
      == edge interventionKeyResultId setsTargetForMeasureKPI measureKpiId =
    macro interventionId setsTargetForMeasure measureId
  | candidate == anchorEdge interventionActionId changesAnchor situationAnchorId =
    macro interventionId changesSituation situationId
  | candidate == anchorEdge measureKpiId measuresAnchor situationAnchorId =
    macro measureId measuresSituation situationId
  | otherwise = Nothing
  where
    macro ::
         RawNodeId
      -> Relation from to
      -> RawNodeId
      -> Maybe (RawNodeId, RelationName, RawNodeId)
    macro from relation to = Just (from, relationNameFor relation, to)

measureFramingEdges :: [RawEdge]
measureFramingEdges =
  [ edge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measurePerformanceDimensionId
  , edge
      measurePerformanceDimensionId
      (containsPerformanceDimension MeasureMeasurementDimension)
      measureKpiId
  ]

traceOnlyEdges :: [RawEdge]
traceOnlyEdges =
  [ edge visionId orientsStrategy strategyId
  , edge strategyId qualifiesNeed needId
  , edge strategyId directsIntervention interventionId
  , edge interventionId changesSituation situationId
  , edge strategyId framesMeasure measureId
  , edge interventionId setsTargetForMeasure measureId
  , edge measureId measuresSituation situationId
  , edge
      interventionActionId
      contributesInterventionActionToKeyResult
      interventionKeyResultId
  , edge
      interventionKeyResultId
      contributesInterventionKeyResultToStrategyKeyResult
      strategyKeyResultId
  ]

kpiDefinitionTests :: TestTree
kpiDefinitionTests =
  testGroup
    "KPI definitions"
    [ testCase "readiness exposes one validated definition per typed KPI"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            case ( kpiDefinitions ready
                 , NonEmpty.toList (readyEffectTraces ready)) of
              ([definition], trace:_) -> do
                unNodeId (kpiDefinitionKPI definition) @?= measureKpiId
                kpiDefinitionUnit definition @?= percent
                kpiDefinitionDomain definition @?= percentageDomain
                kpiDefinitionMeasurementMethod definition
                  @?= "monthly controlled measurement"
                kpiDefinitionInterpretation definition
                  @?= "higher levels indicate better outcomes"
                lookupKPIDefinition ready (traceKPI trace) @?= Just definition
              _ -> assertFailure "expected one trace and one KPI definition"
    , testCase "every traced KPI requires a definition"
        $ withTraceable sampleGraph
        $ \model ->
            let kpi = traceKPI (NonEmpty.head (effectTraces model))
             in assertReadinessErrors
                  [MissingKPIDefinition kpi]
                  (validateReadyWithDefinitions model [])
    , testCase "identical KPI definitions are rejected as duplicates"
        $ withTraceable sampleGraph
        $ \model ->
            assertReadinessErrors
              [DuplicateKPIDefinition measureKpiId 2]
              (validateReadyWithDefinitions
                 model
                 [sampleKPIDefinition, sampleKPIDefinition])
    , testCase "incompatible units conflict for one KPI"
        $ withTraceable sampleGraph
        $ \model ->
            let conflicting = sampleKPIDefinition {rawDefinitionUnit = count}
             in assertReadinessErrors
                  [ConflictingKPIDefinition measureKpiId 2]
                  (validateReadyWithDefinitions
                     model
                     [sampleKPIDefinition, conflicting])
    , testCase "incompatible domains conflict for one KPI"
        $ withTraceable sampleGraph
        $ \model ->
            let conflicting =
                  sampleKPIDefinition {rawDefinitionDomain = UnboundedDomain}
             in assertReadinessErrors
                  [ConflictingKPIDefinition measureKpiId 2]
                  (validateReadyWithDefinitions
                     model
                     [sampleKPIDefinition, conflicting])
    , testCase "definitions for untraced KPIs are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let unknown = sampleKPIDefinition {rawDefinitionKPI = missingId}
             in assertReadinessErrors
                  [UnknownKPIDefinition missingId]
                  (validateReadyWithDefinitions
                     model
                     [sampleKPIDefinition, unknown])
    , testCase "inverted bounded domains are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let domain = BoundedDomain (Level 100) (Level 0)
                invalid = sampleKPIDefinition {rawDefinitionDomain = domain}
             in assertReadinessErrors
                  [InvalidKPIValueDomain measureKpiId domain]
                  (validateReadyWithDefinitions model [invalid])
    , testCase "named KPI units must be nonblank"
        $ withTraceable sampleGraph
        $ \model ->
            let invalid =
                  sampleKPIDefinition {rawDefinitionUnit = NamedUnit " "}
             in assertReadinessErrors
                  [EmptyKPIUnit measureKpiId]
                  (validateReadyWithDefinitions model [invalid])
    , testCase "measurement methods must be nonblank"
        $ withTraceable sampleGraph
        $ \model ->
            let invalid =
                  sampleKPIDefinition {rawDefinitionMeasurementMethod = " "}
             in assertReadinessErrors
                  [EmptyKPIMeasurementMethod measureKpiId]
                  (validateReadyWithDefinitions model [invalid])
    , testCase "KPI interpretations must be nonblank"
        $ withTraceable sampleGraph
        $ \model ->
            let invalid =
                  sampleKPIDefinition {rawDefinitionInterpretation = " "}
             in assertReadinessErrors
                  [EmptyKPIInterpretation measureKpiId]
                  (validateReadyWithDefinitions model [invalid])
    , testCase "bounded percentage domain accepts both level boundaries"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan =
                  (planForTrace trace)
                    { baseline = observation 0 baselineDate
                    , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 100)
                    , targetCriterion = AtLeast (Level 100)
                    }
             in assertSuccess
                  (validateReadyWithPlans model (definitionsFor model) [plan])
    , testCase "delta endpoint at a lower domain boundary is valid"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan =
                  (planForTrace trace)
                    { baseline = observation 5 baselineDate
                    , effectCriterion = AbsoluteDecreaseByAtLeast (Delta 5)
                    , targetCriterion = AtMost (Level 0)
                    }
             in assertSuccess
                  (validateReadyWithPlans model (definitionsFor model) [plan])
    , testCase "one KPI definition governs every trace using that KPI"
        $ withTraceable sharedKpiTwoPathGraph
        $ \model ->
            case validateReadyWithDefinitions model (definitionsFor model) of
              Failure errors ->
                assertFailure ("readiness errors: " ++ show errors)
              Success ready -> do
                length (kpiDefinitions ready) @?= 1
                NonEmpty.length (evidencePlans ready) @?= 2
    , testCase "distinct multi-trace KPIs each receive one definition"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            sort (map (unNodeId . kpiDefinitionKPI) (kpiDefinitions ready))
              @?= sort [measureKpiId, duplicateId measureKpiId]
    , testCase "multi-trace KPI definitions cannot disagree"
        $ withTraceable sharedKpiTwoPathGraph
        $ \model ->
            let conflicting = sampleKPIDefinition {rawDefinitionUnit = count}
             in assertReadinessErrors
                  [ConflictingKPIDefinition measureKpiId 2]
                  (validateReadyWithDefinitions
                     model
                     [sampleKPIDefinition, conflicting])
    , testCase "all trace plans use the shared KPI domain"
        $ withTraceable sharedKpiTwoPathGraph
        $ \model ->
            case NonEmpty.toList (effectTraces model) of
              first:second:_ ->
                let invalid =
                      (planForTrace second)
                        {targetCriterion = AtLeast (Level 101)}
                 in assertReadinessErrors
                      [ TargetCriterionOutsideDomain
                          (traceIdentifier second)
                          (Level 101)
                          percentageDomain
                      ]
                      (validateReadyWithPlans
                         model
                         (definitionsFor model)
                         [planForTrace first, invalid])
              traces ->
                assertFailure
                  ("expected two traces, got " ++ show (length traces))
    ]

validateReadyWithDefinitions ::
     TraceableEffectModel
  -> [RawKPIDefinition]
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
validateReadyWithDefinitions model definitions =
  validateReadyWithPlans
    model
    definitions
    (map planForTrace (NonEmpty.toList (effectTraces model)))

validateReadyWithPlans ::
     TraceableEffectModel
  -> [RawKPIDefinition]
  -> [EvidencePlan]
  -> Validation (NonEmpty.NonEmpty EvidenceReadinessError) EvidenceReadyModel
validateReadyWithPlans model definitions plans =
  validateEvidenceReadinessAt
    readinessDate
    model
    definitions
    (plannedStartsFor model)
    plans

readinessTests :: TestTree
readinessTests =
  testGroup
    "evidence readiness"
    [ testCase "complete ex-ante plans establish readiness"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready -> do
            NonEmpty.length (evidencePlans ready) @?= 1
            NonEmpty.length (readyEffectTraces ready) @?= 1
            readinessCheckedAt ready @?= readinessDate
            plannedInterventionStarts ready @?= [samplePlannedStart]
    , testCase "empty plans accumulate independent readiness defects"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
             in assertReadinessErrors
                  [ MissingKPIDefinition (traceKPI trace)
                  , MissingPlannedInterventionStart (traceIntervention trace)
                  , MissingEvidencePlan (traceIdentifier trace)
                  ]
                  (validateEvidenceReadinessAt readinessDate model [] [] [])
    , testCase "known Intervention has one evidence-ready trace"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              length (readyTracesForIntervention ready intervention) @?= 1
    , testCase "trace-free Intervention has no evidence-ready trace"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withWellFormed
              (RawGraph [RawContextNode missingId Intervention] [])
              (\graph ->
                 withContextRef graph SIntervention missingId $ \intervention ->
                   readyTracesForIntervention ready intervention @?= [])
    , testCase "Intervention may have multiple evidence-ready traces"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention -> do
              length (readyTracesForIntervention ready intervention) @?= 2
              plannedInterventionStarts ready @?= [samplePlannedStart]
    , testCase "contradictory starts for multi-trace Intervention are rejected"
        $ withTraceable twoPathGraph
        $ \model ->
            let contradictory =
                  samplePlannedStart {plannedStartAt = afterInterventionDate}
             in assertReadinessErrors
                  [DuplicatePlannedInterventionStart interventionId 2]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     [samplePlannedStart, contradictory]
                     (map planForTrace (NonEmpty.toList (effectTraces model))))
    , testCase "unknown planned Intervention timing is rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let unknown = PlannedInterventionStart missingId interventionDate
             in assertReadinessErrors
                  [UnknownPlannedInterventionStart missingId]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     [samplePlannedStart, unknown]
                     (map planForTrace (NonEmpty.toList (effectTraces model))))
    , testCase "every traced Intervention requires planned timing"
        $ withTraceable sampleGraph
        $ \model ->
            let intervention =
                  traceIntervention (NonEmpty.head (effectTraces model))
             in assertReadinessErrors
                  [MissingPlannedInterventionStart intervention]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     []
                     (map planForTrace (NonEmpty.toList (effectTraces model))))
    , testCase "plan and baseline may be fixed at the check time"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan =
                  (planForTrace trace)
                    { establishedAt = readinessDate
                    , baseline =
                        (baseline (planForTrace trace))
                          {observedAt = readinessDate}
                    }
             in assertSuccess
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     (plannedStartsFor model)
                     [plan])
    , testCase "duplicate plans for one trace are rejected"
        $ withTraceable sampleGraph
        $ \model ->
            let trace = NonEmpty.head (effectTraces model)
                plan = planForTrace trace
                identifier = traceIdentifier trace
             in assertReadinessErrors
                  [DuplicateEvidencePlan identifier 2]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     (plannedStartsFor model)
                     [plan, plan])
    , testCase "unknown planned traces are rejected exactly"
        $ withTraceable twoPathGraph
        $ \twoPath ->
            case filter
                   ((/= interventionKeyResultId)
                      . unNodeId
                      . traceInterventionKeyResult)
                   (NonEmpty.toList (effectTraces twoPath)) of
              unknownTrace:_ ->
                withTraceable sampleGraph $ \singlePath ->
                  let knownTrace = NonEmpty.head (effectTraces singlePath)
                      knownPlan = planForTrace knownTrace
                      unknownPlan = planForTrace unknownTrace
                   in assertReadinessErrors
                        [ UnknownEvidencePlanTrace
                            (traceIdentifier unknownTrace)
                        ]
                        (validateEvidenceReadinessAt
                           readinessDate
                           singlePath
                           (definitionsFor singlePath)
                           (plannedStartsFor singlePath)
                           [knownPlan, unknownPlan])
              [] -> assertFailure "two-path fixture lacks an unknown trace"
    , testCase "every trace requires one plan"
        $ withTraceable twoPathGraph
        $ \model ->
            case NonEmpty.toList (effectTraces model) of
              planned:omitted:_ ->
                assertReadinessErrors
                  [MissingEvidencePlan (traceIdentifier omitted)]
                  (validateEvidenceReadinessAt
                     readinessDate
                     model
                     (definitionsFor model)
                     (plannedStartsFor model)
                     [planForTrace planned])
              traces ->
                assertFailure
                  ("expected two traces, got " ++ show (length traces))
    , readinessFailureTest
        "plan must be established by the check time"
        readinessDate
        (\plan -> plan {establishedAt = afterReadinessDate})
        (\identifier -> [PlanEstablishedAfterCheck identifier])
    , testCase "readiness must be checked before planned start"
        $ withTraceable sampleGraph
        $ \model ->
            let intervention =
                  traceIntervention (NonEmpty.head (effectTraces model))
             in assertReadinessErrors
                  [ReadinessCheckedAtOrAfterPlannedStart intervention]
                  (validateEvidenceReadinessAt
                     interventionDate
                     model
                     (definitionsFor model)
                     (plannedStartsFor model)
                     (map planForTrace (NonEmpty.toList (effectTraces model))))
    , readinessFailureTest
        "baseline must be observed by the check time"
        readinessDate
        (mapBaseline (\item -> item {observedAt = afterReadinessDate}))
        (\identifier -> [BaselineObservedAfterCheck identifier])
    , readinessFailureTest
        "baseline cannot be later than the readiness check"
        readinessDate
        (mapBaseline (\item -> item {observedAt = interventionDate}))
        (\identifier -> [BaselineObservedAfterCheck identifier])
    , readinessFailureTest
        "target due date must follow intervention"
        readinessDate
        (\plan -> plan {targetDueAt = interventionDate})
        (\identifier -> [InvalidTargetDueDate identifier])
    , readinessFailureTest
        "baseline KPI must match the trace"
        readinessDate
        (mapBaseline (\item -> item {observationKPI = missingId}))
        (\identifier -> [BaselineKPIMismatch identifier measureKpiId missingId])
    , readinessFailureTest
        "baseline anchor must match the trace"
        readinessDate
        (mapBaseline (\item -> item {observationAnchor = missingId}))
        (\identifier ->
           [BaselineAnchorMismatch identifier situationAnchorId missingId])
    , readinessFailureTest
        "absolute delta endpoint must remain inside the KPI domain"
        readinessDate
        (\plan ->
           plan
             { baseline = observation 95 baselineDate
             , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 6)
             })
        (\identifier ->
           [ EffectCriterionOutsideDomain
               identifier
               (Level 101)
               percentageDomain
           ])
    , readinessFailureTest
        "effect criterion magnitude must be positive"
        readinessDate
        (\plan -> plan {effectCriterion = AbsoluteIncreaseByAtLeast (Delta 0)})
        (\identifier -> [InvalidEffectCriterion identifier])
    , readinessFailureTest
        "relative effect criterion ratio must be positive"
        readinessDate
        (\plan ->
           plan {effectCriterion = RelativeIncreaseByAtLeast (RelativeChange 0)})
        (\identifier -> [InvalidEffectCriterion identifier])
    , readinessFailureTest
        "relative effect criterion requires nonzero baseline"
        readinessDate
        (\plan ->
           plan
             { baseline = observation 0 baselineDate
             , effectCriterion =
                 RelativeIncreaseByAtLeast (RelativeChange (1 / 10))
             })
        (\identifier -> [RelativeEffectCriterionWithZeroBaseline identifier])
    , readinessFailureTest
        "target criterion bounds must be valid"
        readinessDate
        (\plan -> plan {targetCriterion = Within (Level 80) (Level 70)})
        (\identifier -> [InvalidTargetCriterion identifier])
    , readinessFailureTest
        "target levels must remain inside the KPI domain"
        readinessDate
        (\plan -> plan {targetCriterion = AtLeast (Level 101)})
        (\identifier ->
           [ TargetCriterionOutsideDomain
               identifier
               (Level 101)
               percentageDomain
           ])
    , readinessFailureTest
        "baseline levels must remain inside the KPI domain"
        readinessDate
        (mapBaseline (\item -> item {observedLevel = Level (-1)}))
        (\identifier ->
           [BaselineLevelOutsideDomain identifier (Level (-1)) percentageDomain])
    , readinessFailureTest
        "baseline levels cannot exceed the KPI domain"
        readinessDate
        (mapBaseline (\item -> item {observedLevel = Level 101}))
        (\identifier ->
           [BaselineLevelOutsideDomain identifier (Level 101) percentageDomain])
    , readinessFailureTest
        "plan provenance must be nonblank"
        readinessDate
        (\plan -> plan {planSource = EvidenceSource " "})
        (\identifier -> [EmptyPlanSource identifier])
    , readinessFailureTest
        "baseline provenance must be nonblank"
        readinessDate
        (mapBaseline (\item -> item {observationSource = EvidenceSource " "}))
        (\identifier -> [EmptyBaselineSource identifier])
    ]

effectEvidenceTests :: TestTree
effectEvidenceTests =
  testGroup
    "effect evidence"
    [ testCase "complete evidence is assessed"
        $ withAssessed id 75 followUpDate
        $ \assessed assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
            evidenceAssessedAt assessed @?= assessmentDate
            actualInterventionStarts assessed @?= [sampleActualStart]
    , testCase "empty follow-ups accumulate independent evidence defects"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let trace = NonEmpty.head (readyEffectTraces ready)
             in assertEvidenceErrors
                  [ MissingActualInterventionStart (traceIntervention trace)
                  , MissingFollowUpObservation (traceIdentifier trace)
                  ]
                  (assessEffectEvidenceAt assessmentDate ready [] [])
    , testCase "effect can be supported before target achievement"
        $ withAssessed id 60 followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetNotSatisfiedInObservation
    , testCase "target achievement does not imply positive effect"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 72 baselineDate
                 , effectCriterion = AbsoluteIncreaseByAtLeast (Delta 10)
                 })
            75
            followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= NotSatisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "satisfied observation after due is distinguished"
        $ withAssessed
            (\plan -> plan {targetDueAt = earlyTargetDate})
            75
            followUpDate
        $ \_ assessment ->
            targetResult assessment @?= TargetSatisfiedInObservationAfterDue
    , testCase "late actual start does not move the absolute target due time"
        $ withReadyPlan id
        $ \ready trace ->
            let lateStart = sampleActualStart {actualStartAt = assessmentDate}
                followUp = followUpForTrace trace 75 lateObservationDate
             in case assessEffectEvidenceAt
                       lateAssessmentDate
                       ready
                       [lateStart]
                       [followUp] of
                  Failure errors ->
                    assertFailure ("evidence errors: " ++ show errors)
                  Success assessed ->
                    targetResult (NonEmpty.head (effectAssessments assessed))
                      @?= TargetSatisfiedInObservationAfterDue
    , testCase "AtMost targets are assessed"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 60 baselineDate
                 , effectCriterion = AbsoluteDecreaseByAtLeast (Delta 10)
                 , targetCriterion = AtMost (Level 50)
                 })
            45
            followUpDate
        $ \_ assessment -> do
            effectResult assessment @?= Satisfied
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "Within targets are assessed"
        $ withAssessed
            (\plan -> plan {targetCriterion = Within (Level 70) (Level 80)})
            75
            followUpDate
        $ \_ assessment ->
            targetResult assessment @?= TargetSatisfiedInObservationByDue
    , testCase "absolute percentage delta is measured in percentage points"
        $ withAssessed id 50 followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "nine percentage points do not satisfy a ten-point delta"
        $ withAssessed id 49 followUpDate
        $ \_ assessment -> effectResult assessment @?= NotSatisfied
    , testCase "relative increase is distinct from absolute delta"
        $ withAssessed
            (\plan ->
               plan
                 { effectCriterion =
                     RelativeIncreaseByAtLeast (RelativeChange (1 / 10))
                 })
            44
            followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "relative decrease is assessed against baseline magnitude"
        $ withAssessed
            (\plan ->
               plan
                 { baseline = observation 100 baselineDate
                 , effectCriterion =
                     RelativeDecreaseByAtLeast (RelativeChange (1 / 10))
                 , targetCriterion = AtMost (Level 100)
                 })
            90
            followUpDate
        $ \_ assessment -> effectResult assessment @?= Satisfied
    , testCase "one actual start governs all traces of an Intervention"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            assertSuccess
              (assessEffectEvidenceAt
                 assessmentDate
                 ready
                 [sampleActualStart]
                 (followUpsForReady ready 75 followUpDate))
    , testCase "actual start must be after the readiness check"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              let startAtReadiness =
                    sampleActualStart {actualStartAt = readinessDate}
               in assertEvidenceErrors
                    [ActualInterventionStartAtOrBeforeReadiness intervention]
                    (assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [startAtReadiness]
                       (followUpsForReady ready 75 followUpDate))
    , testCase "actual start before readiness is rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              let earlyStart =
                    sampleActualStart {actualStartAt = beforeReadinessDate}
               in assertEvidenceErrors
                    [ActualInterventionStartAtOrBeforeReadiness intervention]
                    (assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [earlyStart]
                       (followUpsForReady ready 75 followUpDate))
    , testCase "contradictory actual starts are rejected canonically"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            let contradictory =
                  sampleActualStart {actualStartAt = afterInterventionDate}
             in assertEvidenceErrors
                  [DuplicateActualInterventionStart interventionId 2]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart, contradictory]
                     (followUpsForReady ready 75 followUpDate))
    , testCase "unknown actual Intervention timing is rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let unknown = ActualInterventionStart missingId interventionDate
             in assertEvidenceErrors
                  [UnknownActualInterventionStart missingId]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart, unknown]
                     (followUpsForReady ready 75 followUpDate))
    , testCase "every ready Intervention requires actual timing"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            withOnlyReadyIntervention ready $ \intervention ->
              assertEvidenceErrors
                [MissingActualInterventionStart intervention]
                (assessEffectEvidenceAt
                   assessmentDate
                   ready
                   []
                   (followUpsForReady ready 75 followUpDate))
    , testCase "multiple follow-ups per trace are assessed independently"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let trace = NonEmpty.head (readyEffectTraces ready)
                first = followUpForTrace trace 60 followUpDate
                second = followUpForTrace trace 75 laterFollowUpDate
             in case assessEffectEvidenceAt
                       assessmentDate
                       ready
                       [sampleActualStart]
                       [first, second] of
                  Failure errors ->
                    assertFailure ("evidence errors: " ++ show errors)
                  Success assessed ->
                    NonEmpty.length (effectAssessments assessed) @?= 2
    , testCase "duplicate trace and timestamp pairs are rejected"
        $ withReady sampleGraph [sampleStrategyFormulation]
        $ \ready ->
            let trace = NonEmpty.head (readyEffectTraces ready)
                followUp = followUpForTrace trace 75 followUpDate
                identifier = traceIdentifier trace
             in assertEvidenceErrors
                  [DuplicateFollowUpObservation identifier followUpDate 2]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart]
                     [followUp, followUp])
    , testCase "every ready trace requires a follow-up"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \ready ->
            case NonEmpty.toList (readyEffectTraces ready) of
              observed:omitted:_ ->
                assertEvidenceErrors
                  [MissingFollowUpObservation (traceIdentifier omitted)]
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart]
                     [followUpForTrace observed 75 followUpDate])
              traces ->
                assertFailure
                  ("expected two traces, got " ++ show (length traces))
    , testCase "unknown follow-up traces are rejected exactly"
        $ withReady twoPathGraph [sampleStrategyFormulation]
        $ \twoPath ->
            case filter
                   ((/= interventionKeyResultId)
                      . unNodeId
                      . traceInterventionKeyResult)
                   (NonEmpty.toList (readyEffectTraces twoPath)) of
              unknownTrace:_ ->
                withReady sampleGraph [sampleStrategyFormulation] $ \single ->
                  let knownTrace = NonEmpty.head (readyEffectTraces single)
                      known = followUpForTrace knownTrace 75 followUpDate
                      unknown = followUpForTrace unknownTrace 75 followUpDate
                   in assertEvidenceErrors
                        [UnknownFollowUpTrace (traceIdentifier unknownTrace)]
                        (assessEffectEvidenceAt
                           assessmentDate
                           single
                           [sampleActualStart]
                           [known, unknown])
              [] -> assertFailure "two-path fixture lacks an unknown trace"
    , evidenceFailureTest
        "follow-up KPI must match the trace"
        (\item -> item {observationKPI = missingId})
        (\identifier _ ->
           [FollowUpKPIMismatch identifier measureKpiId missingId])
    , evidenceFailureTest
        "follow-up anchor must match the trace"
        (\item -> item {observationAnchor = missingId})
        (\identifier _ ->
           [FollowUpAnchorMismatch identifier situationAnchorId missingId])
    , evidenceFailureTest
        "follow-up level must satisfy the KPI domain"
        (\item -> item {observedLevel = Level 101})
        (\identifier _ ->
           [FollowUpLevelOutsideDomain identifier (Level 101) percentageDomain])
    , evidenceFailureTest
        "follow-up level cannot fall below the KPI domain"
        (\item -> item {observedLevel = Level (-1)})
        (\identifier _ ->
           [FollowUpLevelOutsideDomain identifier (Level (-1)) percentageDomain])
    , testCase "follow-up levels may equal both domain boundaries"
        $ withReadyPlan id
        $ \ready trace ->
            let lower = followUpForTrace trace 0 followUpDate
                upper = followUpForTrace trace 100 laterFollowUpDate
             in assertSuccess
                  (assessEffectEvidenceAt
                     assessmentDate
                     ready
                     [sampleActualStart]
                     [lower, upper])
    , evidenceFailureTest
        "follow-up must be observed after actual start"
        (\item -> item {observedAt = interventionDate})
        (\identifier _ -> [FollowUpObservedAtOrBeforeActualStart identifier])
    , evidenceFailureAtTest
        "future-dated follow-up is rejected"
        followUpDate
        (\item -> item {observedAt = laterFollowUpDate})
        (\identifier _ -> [FollowUpObservedAfterAssessment identifier])
    , evidenceFailureAtTest
        "actual start must precede assessment"
        interventionDate
        (\item -> item {observedAt = interventionDate})
        (\identifier intervention ->
           [ ActualInterventionStartAtOrAfterAssessment intervention
           , FollowUpObservedAtOrBeforeActualStart identifier
           ])
    , testCase "follow-up may be observed exactly at assessedAt"
        $ withReadyPlan id
        $ \ready trace ->
            assertSuccess
              (assessEffectEvidenceAt
                 followUpDate
                 ready
                 [sampleActualStart]
                 [followUpForTrace trace 75 followUpDate])
    , evidenceFailureTest
        "follow-up provenance must be nonblank"
        (\item -> item {observationSource = EvidenceSource " "})
        (\identifier _ -> [EmptyFollowUpSource identifier])
    , testCase "positive effect makes the traced Need effective"
        $ assertEffectiveNeed id 75 True
    , testCase "missing positive effect leaves the traced Need ineffective"
        $ assertEffectiveNeed
            (\plan -> plan {baseline = observation 72 baselineDate})
            75
            False
    , QC.testProperty "positive effect thresholds are accepted"
        $ QC.forAll (QC.chooseInteger (1, 60))
        $ \threshold ->
            evidenceSucceeds
              (\plan ->
                 plan
                   { effectCriterion =
                       AbsoluteIncreaseByAtLeast (Delta (fromInteger threshold))
                   })
              (fromInteger threshold + 40)
    , QC.testProperty "both effect directions are assessed"
        $ QC.forAll ((,) <$> QC.arbitrary <*> QC.chooseInteger (1, 60))
        $ \(increases, threshold) ->
            directionalEvidenceSucceeds increases threshold
    ]

registryTests :: TestTree
registryTests =
  testGroup
    "typed registries"
    [ QC.testProperty
        "performance-dimension role lookup and reification round-trip"
        $ QC.forAll
            (QC.elements allPerformanceDimensionRoles)
            performanceDimensionRoleRoundTrips
    , testCase "every performance-dimension role code is represented"
        $ performanceDimensionRoleCodes @?= [minBound .. maxBound]
    , testCase
        "every performance-dimension role member has its own interpretation"
        $ mapM_ assertRoleMemberInterpretation allPerformanceDimensionRoles
    , QC.testProperty "relation lookup round-trips"
        $ QC.forAll (QC.elements allRelations) relationRoundTrips
    , testCase "relation registry identities are unique"
        $ assertBool "duplicate relation identity" relationRegistryIsUnique
    , testCase "every relation code is represented"
        $ relationCodes @?= allRelationCodes
    , QC.testProperty "interpretation lookup round-trips"
        $ QC.forAll (QC.elements allInterpretations) interpretationRoundTrips
    , testCase "every interpretation code is represented"
        $ interpretationCodes @?= [minBound .. maxBound]
    , testCase
        "Context x Primitive validation matches the registry exhaustively"
        $ mapM_
            (\context ->
               mapM_
                 (assertInterpretationValidationContract context)
                 [minBound .. maxBound])
            [minBound .. maxBound]
    ]

performanceDimensionRoleRoundTrips :: SomePerformanceDimensionRole -> Bool
performanceDimensionRoleRoundTrips role =
  reifyPerformanceDimensionRole (performanceDimensionRoleCodeOf role) == role
    && lookupPerformanceDimensionRole context == Just role
  where
    (_, _, context, _) = performanceDimensionRoleIdentity role

performanceDimensionRoleCodes :: [PerformanceDimensionRoleCode]
performanceDimensionRoleCodes =
  map performanceDimensionRoleCodeOf allPerformanceDimensionRoles

assertRoleMemberInterpretation :: SomePerformanceDimensionRole -> Assertion
assertRoleMemberInterpretation role =
  case lookupInterpretation context member of
    Just _ -> pure ()
    Nothing ->
      assertFailure
        ("missing independent interpretation for role member "
           ++ show (context, member))
  where
    (_, _, context, member) = performanceDimensionRoleIdentity role

relationRoundTrips :: SomeRelation -> Bool
relationRoundTrips relation =
  relation `elem` lookupRelations (relationNameOf relation)

relationRegistryIsUnique :: Bool
relationRegistryIsUnique = identities == nub identities
  where
    identities = map relationIdentity allRelations

relationCodes :: [RelationCode]
relationCodes = nub (map relationCodeOf allRelations)

interpretationRoundTrips :: SomeInterpretation -> Bool
interpretationRoundTrips interpretation =
  case lookupInterpretation context primitive of
    Just _ -> True
    Nothing -> False
  where
    (context, primitive) = interpretationIdentity interpretation

interpretationCodes :: [InterpretationCode]
interpretationCodes = map interpretationCodeOf allInterpretations

assertInterpretationValidationContract :: Context -> Primitive -> Assertion
assertInterpretationValidationContract context primitive =
  case (lookupInterpretation context primitive, validateStructure raw) of
    (Just _, StructureAccepted assessment) ->
      case lookupNode (structuralGraph assessment) primitiveId of
        Just node -> someNodeOwner node @?= Just contextId
        Nothing ->
          assertFailure (message ++ ": validated Primitive was not found")
    (Nothing, StructureModelRejected errors) ->
      NonEmpty.toList errors
        @?= [InvalidPrimitiveInterpretation primitiveId context primitive]
    (Just _, StructureModelRejected errors) ->
      assertFailure (message ++ ": admissible pair failed: " ++ show errors)
    (Nothing, StructureAccepted _) ->
      assertFailure (message ++ ": inadmissible pair was accepted")
    (_, StructureInternalFailure internal) ->
      assertFailure (message ++ ": internal failure: " ++ show internal)
  where
    contextId = RawNodeId "registry-context"
    primitiveId = RawNodeId "registry-primitive"
    raw =
      RawGraph
        [ RawContextNode contextId context
        , RawPrimitiveNode primitiveId contextId primitive
        ]
        []
    message = "Context x Primitive contract " ++ show (context, primitive)
