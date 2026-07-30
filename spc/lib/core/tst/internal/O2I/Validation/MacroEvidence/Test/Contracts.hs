{-# LANGUAGE OverloadedStrings #-}

-- | Private macro-evidence semantic, ordering, and work contracts.
module O2I.Validation.MacroEvidence.Test.Contracts
  ( macroEvidenceTests
  ) where

import Control.Exception (SomeException, evaluate, try)
import Data.List (isInfixOf, nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Monoid (Sum(..))
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Macro (buildMacroFactIndex)
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.MacroEvidence
import O2I.Validation.MacroEvidence.Eval (canonicalizeMacroOccurrences)
import qualified O2I.Validation.MacroEvidence.Prepare as Prepare
import O2I.Validation.MacroEvidence.Test.Fixture
import O2I.Validation.MacroEvidence.Test.Oracle
import qualified O2I.Validation.MacroEvidence.Types as Internal
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Types (Domain, domainToAscList)
import O2I.Validation.Semantics.Context
import Test.Tasty
import Test.Tasty.HUnit

macroEvidenceTests :: TestTree
macroEvidenceTests =
  testGroup
    "private endpoint-typed macro evidence"
    [ registryContracts
    , domainCacheContracts
    , occurrenceIdentityContracts
    , preparationWorkContracts
    , resolverStrictnessContract
    , completeRegistryOracleContract
    , multiRoleRegistryContracts
    , scenarioMatrix
    , affineWorkContracts
    , permutationContracts
    , existsContracts
    ]

resolverStrictnessContract :: TestTree
resolverStrictnessContract =
  testCase "forces resolved domains before exposing resolver work" $ do
    result <-
      try (evaluate (snd (instantiateAlternative alternative unresolvedDomain)))
    case result :: Either SomeException (Sum Int) of
      Left _ -> pure ()
      Right _ -> assertFailure "resolver work escaped an unevaluated Domain"
  where
    alternative =
      Single
        (SourcePrimitiveSelector SEthos SPrinciple)
        guidesEthosPrincipleToMissionDriver
        (TargetPrimitiveSelector SMission SDriver)

unresolvedDomain :: TypedMacroSelector from to kind -> (Domain kind, Sum Int)
unresolvedDomain _ = (error "controlled unresolved Domain", Sum 1)

occurrenceIdentityContracts :: TestTree
occurrenceIdentityContracts =
  testGroup
    "persisted occurrence identity"
    [ testCase "separates public equality from occurrence identity" $ do
        let edge =
              RawEdge
                { rawEdgeFrom = strategyId
                , rawEdgeRelation = relationNameFor framesMeasure
                , rawEdgeTo = measureId
                }
            first =
              Internal.MacroEvidenceWitness
                (Internal.MacroPremiseOccurrence 987654321 edge NonEmpty.:| [])
            second =
              Internal.MacroEvidenceWitness
                (Internal.MacroPremiseOccurrence 7 edge NonEmpty.:| [])
            rendered = show first
        first @?= second
        assertBool
          "exact occurrence identity collapsed"
          (not (Internal.sameWitnessOccurrences first second))
        witnessPremises first @?= witnessPremises second
        witnessPremises first @?= edge NonEmpty.:| []
        rendered @?= "MacroEvidenceWitness {validatedWitnessPremises = "
          ++ show (edge NonEmpty.:| [])
          ++ "}"
        assertBool
          "Show exposed the private occurrence representation"
          (not ("MacroPremiseOccurrence" `isInfixOf` rendered))
        assertBool
          "Show exposed the private witness field"
          (not ("validatedWitnessOccurrences" `isInfixOf` rendered))
        assertBool
          "Show exposed the private occurrence ordinal"
          (not ("987654321" `isInfixOf` rendered))
    , testCase "preserves rows sharing one occurrence vector" $ do
        let firstEdge =
              RawEdge
                { rawEdgeFrom = strategyId
                , rawEdgeRelation = relationNameFor framesMeasure
                , rawEdgeTo = measureId
                }
            secondEdge =
              firstEdge {rawEdgeTo = RawNodeId (Text.pack "second-measure")}
            firstRow =
              Internal.MacroPremiseOccurrence 3 firstEdge NonEmpty.:| []
            secondRow =
              Internal.MacroPremiseOccurrence 3 secondEdge NonEmpty.:| []
            (witnesses, insertions, emitted) =
              canonicalizeMacroOccurrences [firstRow, secondRow]
        map witnessPremises witnesses
          @?= [firstEdge NonEmpty.:| [], secondEdge NonEmpty.:| []]
        insertions @?= 2
        emitted @?= 2
    ]

preparationWorkContracts :: TestTree
preparationWorkContracts =
  testGroup
    "truthful preparation work"
    [ testCase
        "reports exact operations for the small baseline"
        exactPreparationBaseline
    , testCase
        "counts one additional indexed domain member"
        additionalDomainMemberDelta
    , testCase
        "counts one additional two-alternative macro claim"
        additionalCollectiveClaimDelta
    , testGroup
        "reads every scenario input exactly once"
        [ testGroup
          (show size)
          [ testCase (show shape) (assertPreparationReads shape size)
          | shape <- [minBound .. maxBound]
          ]
        | size <- declaredSizes
        ]
    ]

exactPreparationBaseline :: Assertion
exactPreparationBaseline =
  withPreparationWork (scenarioSemantic Sparse 0) $ \work ->
    work
      @?= MacroPreparationWork
            { preparationFactNodesRead = 15
            , preparationFactEdgesRead = 12
            , preparationRelationalIndexWork =
                IndexBuildWork
                  { buildNodesRead = 15
                  , buildNodeDomainInsertions = 15
                  , buildEdgesRead = 12
                  , buildCanonicalOccurrencesAssigned = 12
                  , buildProjectionInsertions = 12
                  , buildExactOccurrenceInsertions = 12
                  , buildRelationProjectionsCreated = 12
                  }
            , preparationDomainNodesRead = 15
            , preparationDomainEdgesRead = 12
            , preparationStrategyFormulationsRead = 1
            , preparationDomainLookups = 19
            , preparationDomainInsertions = 15
            , preparationClaimsRead = 1
            , preparationRegistryInsertions = 1
            , preparationPlansInstantiated = 1
            }

additionalDomainMemberDelta :: Assertion
additionalDomainMemberDelta =
  withPreparationWork (scenarioSemantic Sparse 0) $ \baseline ->
    withPreparationWork
      (validateScenario
         additionalDomainMemberGraph
         (scenarioFormulation Sparse 0)) $ \expanded -> do
      preparationFactNodesRead expanded @?= preparationFactNodesRead baseline
        + 1
      preparationDomainNodesRead expanded
        @?= preparationDomainNodesRead baseline
        + 1
      preparationDomainLookups expanded @?= preparationDomainLookups baseline
        + 1
      preparationDomainInsertions expanded
        @?= preparationDomainInsertions baseline
        + 1
      preparationClaimsRead expanded @?= preparationClaimsRead baseline
      preparationRegistryInsertions expanded
        @?= preparationRegistryInsertions baseline
      preparationPlansInstantiated expanded
        @?= preparationPlansInstantiated baseline

additionalCollectiveClaimDelta :: Assertion
additionalCollectiveClaimDelta =
  withPreparationWork
    (validateRegistryGraph registryGraphWithoutCollectiveClaim) $ \withoutClaim ->
    withPreparationWork validateRegistryScenario $ \withClaim -> do
      preparationFactEdgesRead withClaim
        @?= preparationFactEdgesRead withoutClaim
        + 1
      preparationDomainEdgesRead withClaim
        @?= preparationDomainEdgesRead withoutClaim
        + 1
      preparationDomainLookups withClaim
        @?= preparationDomainLookups withoutClaim
        + 4
      preparationDomainInsertions withClaim
        @?= preparationDomainInsertions withoutClaim
      preparationClaimsRead withClaim @?= preparationClaimsRead withoutClaim + 1
      preparationRegistryInsertions withClaim
        @?= preparationRegistryInsertions withoutClaim
        + 1
      preparationPlansInstantiated withClaim
        @?= preparationPlansInstantiated withoutClaim
        + 2

assertPreparationReads :: ScenarioShape -> Int -> Assertion
assertPreparationReads shape size =
  withPreparationWork (scenarioSemantic shape size) $ \work -> do
    let graph = scenarioGraph shape size
    preparationFactNodesRead work @?= length (rawNodes graph)
    preparationFactEdgesRead work @?= length (rawEdges graph)
    preparationDomainNodesRead work @?= length (rawNodes graph)
    preparationDomainEdgesRead work @?= length (rawEdges graph)
    preparationStrategyFormulationsRead work @?= 1

withPreparationWork ::
     Either String ContextSemantics
  -> (MacroPreparationWork -> Assertion)
  -> Assertion
withPreparationWork validation assertion =
  case validation of
    Left message -> assertFailure message
    Right semantic ->
      assertion (macroEvidencePreparationWork (prepareMacroEvidence semantic))

registryContracts :: TestTree
registryContracts =
  testGroup
    "endpoint-typed registry"
    [ testCase "matches the general macrorelation registry exactly once" $ do
        let actual =
              sort
                (map
                   macroEvidenceRuleConclusion
                   (NonEmpty.toList macroEvidenceRules))
            expected =
              sort
                [ relationCodeOf relation
                | relation <- allRelations
                , MacroRelation _ <- [relationSemanticsOf relation]
                ]
        actual @?= expected
        length actual @?= length (nub actual)
    , testCase "expands every anchor family to four exact alternatives"
        $ mapM_ assertAnchorExpansion anchorMacroRules
    ]
  where
    anchorMacroRules =
      [ (SurfacesNeedCode, ConstitutedByAnchorFamily, AnchorsNeedDriverFamily)
      , (ChangesSituationCode, ConstitutedByAnchorFamily, ChangesAnchorFamily)
      , (MeasuresSituationCode, ConstitutedByAnchorFamily, MeasuresAnchorFamily)
      ]

assertAnchorExpansion ::
     (FixedRelationCode, AnchorRelationFamily, AnchorRelationFamily)
  -> Assertion
assertAnchorExpansion (conclusion, firstFamily, secondFamily) =
  case lookupMacroEvidenceRule (FixedRelation conclusion) of
    Nothing -> assertFailure ("missing macro rule: " ++ show conclusion)
    Just rule' ->
      map alternativeCodes (NonEmpty.toList (ruleAlternatives rule'))
        @?= [ [ AnchorRelation firstFamily anchor
              , AnchorRelation secondFamily anchor
              ]
            | anchor <- [minBound .. maxBound]
            ]
  where
    alternativeCodes alternative =
      [ code
      | premise <- NonEmpty.toList (alternativePremises alternative)
      , ExactRelation code <- [premiseRelation premise]
      ]

domainCacheContracts :: TestTree
domainCacheContracts =
  testGroup
    "kind-indexed domain cache"
    [ testCase
        "returns exact domains for every prepared address family"
        exactPreparedDomains
    , testCase
        "isolates owner identity and indexed kind"
        preparedDomainIsolation
    , testCase "serves every addressable kind family"
        $ case validateRegistryScenario of
            Left message -> assertFailure message
            Right semantic -> do
              let prepared = prepareMacroEvidence semantic
              mapM_
                (assertHasEvidence prepared)
                [ FixedRelation GuidesMissionCode
                , FixedRelation OrientsStrategyCode
                , FixedRelation FramesMeasureCode
                , FixedRelation SurfacesNeedCode
                ]
    , testCase "treats missing anchor addresses as empty domains"
        $ case validateRegistryScenario of
            Left message -> assertFailure message
            Right semantic -> do
              let prepared = prepareMacroEvidence semantic
              case [ claim
                   | (_, claim) <- macroEvidenceClaims prepared
                   , macroClaimConclusion claim
                       == FixedRelation SurfacesNeedCode
                   ] of
                [claim] ->
                  length (macroEvidenceWitnessesIn prepared claim) @?= 1
                claims ->
                  assertFailure
                    ("expected one surfaces-need claim, got "
                       ++ show (length claims))
    , testCase "builds shared domains once for all compiled claims"
        $ case validateRegistryScenario of
            Left message -> assertFailure message
            Right semantic -> do
              let prepared = prepareMacroEvidence semantic
                  work = macroEvidencePreparationWork prepared
                  claimCount = length (macroEvidenceClaims prepared)
              assertBool "fixture must contain multiple claims" (claimCount > 1)
              preparationDomainNodesRead work
                @?= length (rawNodes registryGraph)
              preparationDomainEdgesRead work
                @?= length (rawEdges registryGraph)
              preparationStrategyFormulationsRead work
                @?= length registryFormulations
    ]

exactPreparedDomains :: Assertion
exactPreparedDomains =
  withAllDomainEvidence $ \prepared -> do
    assertDomain
      [ethosPrincipleId]
      (Prepare.preparedOwnedPrimitiveDomain
         prepared
         (mkNodeId ethosId)
         SEthos
         SPrinciple)
    assertDomain
      [strategyDriverId]
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId strategyId)
         StrategyDiagnosisRole)
    assertDomain
      [strategyObjectiveId]
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId strategyId)
         StrategyIntentRole)
    assertDomain
      [strategyPrincipleId]
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId strategyId)
         StrategyGuidingPolicyRole)
    assertDomain
      [strategyActionId, strategyActionAdditionalId]
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId strategyId)
         StrategyCoherentActionRole)
    assertDomain
      [strategyKeyResultId, strategyKeyResultAdditionalId]
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId strategyId)
         StrategyKeyResultRole)
    assertDomain
      [strategyDimensionId]
      (Prepare.preparedPerformanceDimensionDomain
         prepared
         (mkNodeId strategyId)
         StrategySuccessDimension)
    assertDomain
      [measureDimensionId]
      (Prepare.preparedPerformanceDimensionDomain
         prepared
         (mkNodeId measureId)
         MeasureMeasurementDimension)
    assertDomain
      [situationAnchorId]
      (Prepare.preparedSituationAnchorDomain
         prepared
         (mkNodeId situationId)
         SBusinessCapability)

preparedDomainIsolation :: Assertion
preparedDomainIsolation =
  withRegistryEvidence $ \prepared -> do
    assertDomain
      [strategyDriverId]
      (Prepare.preparedOwnedPrimitiveDomain
         prepared
         (mkNodeId strategyId)
         SStrategy
         SDriver)
    assertDomain
      [strategyObjectiveId]
      (Prepare.preparedOwnedPrimitiveDomain
         prepared
         (mkNodeId strategyId)
         SStrategy
         SObjective)
    assertDomain
      [secondStrategyDriverId]
      (Prepare.preparedOwnedPrimitiveDomain
         prepared
         (mkNodeId secondStrategyId)
         SStrategy
         SDriver)
    assertDomain
      []
      (Prepare.preparedOwnedPrimitiveDomain
         prepared
         (mkNodeId (RawNodeId "missing-strategy"))
         SStrategy
         SDriver)
    assertDomain
      []
      (Prepare.preparedStrategyRoleDomain
         prepared
         (mkNodeId (RawNodeId "missing-strategy"))
         StrategyDiagnosisRole)
    assertDomain
      []
      (Prepare.preparedPerformanceDimensionDomain
         prepared
         (mkNodeId (RawNodeId "missing-measure"))
         MeasureMeasurementDimension)
    assertDomain
      []
      (Prepare.preparedSituationAnchorDomain
         prepared
         (mkNodeId situationId)
         SBusinessProcess)
    assertDomain
      []
      (Prepare.preparedSituationAnchorDomain
         prepared
         (mkNodeId situationId)
         SBusinessObject)
    assertDomain
      []
      (Prepare.preparedSituationAnchorDomain
         prepared
         (mkNodeId situationId)
         SValueStream)
    assertDomain
      []
      (Prepare.preparedSituationAnchorDomain
         prepared
         (mkNodeId (RawNodeId "missing-situation"))
         SBusinessCapability)

withRegistryEvidence :: (PreparedMacroEvidence -> Assertion) -> Assertion
withRegistryEvidence assertion =
  case validateRegistryScenario of
    Left message -> assertFailure message
    Right semantic -> assertion (prepareMacroEvidence semantic)

withAllDomainEvidence :: (PreparedMacroEvidence -> Assertion) -> Assertion
withAllDomainEvidence assertion =
  case validateRegistryGraph graph of
    Left message -> assertFailure message
    Right semantic -> assertion (prepareMacroEvidence semantic)
  where
    graph =
      registryGraph
        { rawNodes =
            RawStructuringNode
              strategyDimensionId
              strategyId
              PerformanceDimension
              : rawNodes registryGraph
        }

strategyDimensionId :: RawNodeId
strategyDimensionId = RawNodeId "strategy-dimension"

assertDomain :: [RawNodeId] -> Domain kind -> Assertion
assertDomain expected = (@?= expected) . map unNodeId . domainToAscList

assertHasEvidence :: PreparedMacroEvidence -> RelationCode -> Assertion
assertHasEvidence prepared expected =
  case [ claim
       | (_, claim) <- macroEvidenceClaims prepared
       , macroClaimConclusion claim == expected
       ] of
    [] -> assertFailure ("missing claim for " ++ show expected)
    claims ->
      assertBool
        ("missing evidence for " ++ show expected)
        (any (not . null . macroEvidenceWitnessesIn prepared) claims)

completeRegistryOracleContract :: TestTree
completeRegistryOracleContract =
  testCase "complete registry agrees with the independent naive oracle"
    $ case validateRegistryScenario of
        Left message -> assertFailure message
        Right semantic -> do
          let prepared = prepareMacroEvidence semantic
              index =
                buildMacroFactIndex
                  [ (rawNodeIdentifier node, node)
                  | node <- rawNodes registryGraph
                  ]
                  [(candidate, candidate) | candidate <- rawEdges registryGraph]
              claims = map snd (macroEvidenceClaims prepared)
          sort (nub (map macroClaimConclusion claims))
            @?= sort
                  (map
                     macroEvidenceRuleConclusion
                     (NonEmpty.toList macroEvidenceRules))
          mapM_ (assertClaimAgrees prepared index) claims
  where
    assertClaimAgrees prepared index claim =
      sort
        (map
           (NonEmpty.toList . witnessPremises)
           (macroEvidenceWitnessesIn prepared claim))
        @?= sort (naiveMacroWitnesses index registryFormulations claim)

multiRoleRegistryContracts :: TestTree
multiRoleRegistryContracts =
  testGroup
    "complete multi-member Strategy roles"
    [ testCase "enumerates every affected macro witness"
        $ withRegistryEvidence assertMultiRoleWitnesses
    , testCase "canonicalizes graph, formulation, and member order"
        $ case ( validateRegistryScenario
               , validateRegistryInput reversedGraph reversedFormulations) of
            (Left message, _) -> assertFailure message
            (_, Left message) -> assertFailure message
            (Right baseline, Right reordered) ->
              sort (registryWitnessProjection (prepareMacroEvidence reordered))
                @?= sort
                      (registryWitnessProjection (prepareMacroEvidence baseline))
    , testCase "canonicalizes validation errors across input order"
        $ case ( validateRegistryInput invalidGraph registryFormulations
               , validateRegistryInput reversedInvalidGraph reversedFormulations) of
            (Left message, _) -> assertFailure message
            (_, Left message) -> assertFailure message
            (Right baseline, Right reordered) -> do
              macroErrors baseline @?= expectedErrors
              macroErrors reordered @?= expectedErrors
    ]
  where
    reversedGraph =
      registryGraph
        { rawNodes = reverse (rawNodes registryGraph)
        , rawEdges = reverse (rawEdges registryGraph)
        }
    reversedFormulations =
      reverse
        [ formulation
          { rawFormulationActions =
              NonEmpty.reverse (rawFormulationActions formulation)
          , rawFormulationKeyResults =
              NonEmpty.reverse (rawFormulationKeyResults formulation)
          }
        | formulation <- registryFormulations
        ]
    invalidGraph =
      registryGraph
        { rawEdges =
            filter
              (`notElem` invalidatedRegistryEvidence)
              (rawEdges registryGraph)
        }
    reversedInvalidGraph =
      RawGraph
        { rawNodes = reverse (rawNodes invalidGraph)
        , rawEdges = reverse (rawEdges invalidGraph)
        }
    expectedErrors =
      map
        MissingMacroEvidence
        (sort
           [ fixtureEdge strategyId contributesToStrategy secondStrategyId
           , fixtureEdge strategyId directsIntervention interventionId
           , fixtureEdge strategyId framesMeasure measureId
           , fixtureEdge strategyId qualifiesNeed needId
           ])
    macroErrors semantic =
      case validatePreparedMacroEvidence (prepareMacroEvidence semantic) of
        Failure errors -> NonEmpty.toList errors
        Success _ -> error "invalid registry evidence was accepted"

invalidatedRegistryEvidence :: [RawEdge]
invalidatedRegistryEvidence =
  [ fixtureEdge
      strategyKeyResultId
      contributesStrategyKeyResultToKeyResult
      secondStrategyKeyResultId
  , fixtureEdge
      strategyKeyResultAdditionalId
      contributesStrategyKeyResultToKeyResult
      secondStrategyKeyResultAdditionalId
  , fixtureEdge
      strategyActionId
      contributesStrategyActionToAction
      secondStrategyActionId
  , fixtureEdge
      strategyActionAdditionalId
      contributesStrategyActionToAction
      secondStrategyActionAdditionalId
  , fixtureEdge
      strategyKeyResultId
      translatesStrategyKeyResultToNeedObjective
      needObjectiveId
  , fixtureEdge
      strategyKeyResultAdditionalId
      translatesStrategyKeyResultToNeedObjective
      needObjectiveId
  , fixtureEdge
      strategyActionId
      guidesStrategyActionToInterventionAction
      interventionActionId
  , fixtureEdge
      strategyActionAdditionalId
      guidesStrategyActionToInterventionAction
      interventionActionId
  , fixtureEdge
      strategyDriverId
      indicatesMeasurePerformanceDimension
      measureDimensionId
  , fixtureEdge
      strategyKeyResultId
      determinesMeasurePerformanceDimension
      measureDimensionId
  , fixtureEdge
      strategyKeyResultAdditionalId
      determinesMeasurePerformanceDimension
      measureDimensionId
  ]

assertMultiRoleWitnesses :: PreparedMacroEvidence -> Assertion
assertMultiRoleWitnesses prepared = do
  assertRegistryWitnesses
    prepared
    strategyId
    contributesToStrategy
    secondStrategyId
    [ [ fixtureEdge
          strategyKeyResultId
          contributesStrategyKeyResultToKeyResult
          secondStrategyKeyResultId
      ]
    , [ fixtureEdge
          strategyKeyResultAdditionalId
          contributesStrategyKeyResultToKeyResult
          secondStrategyKeyResultAdditionalId
      ]
    , [ fixtureEdge
          strategyActionId
          contributesStrategyActionToAction
          secondStrategyActionId
      ]
    , [ fixtureEdge
          strategyActionAdditionalId
          contributesStrategyActionToAction
          secondStrategyActionAdditionalId
      ]
    ]
  assertRegistryWitnesses
    prepared
    strategyId
    qualifiesNeed
    needId
    [ [ fixtureEdge
          strategyKeyResultId
          translatesStrategyKeyResultToNeedObjective
          needObjectiveId
      ]
    , [ fixtureEdge
          strategyKeyResultAdditionalId
          translatesStrategyKeyResultToNeedObjective
          needObjectiveId
      ]
    ]
  assertRegistryWitnesses
    prepared
    strategyId
    directsIntervention
    interventionId
    [ [ fixtureEdge
          strategyActionId
          guidesStrategyActionToInterventionAction
          interventionActionId
      ]
    , [ fixtureEdge
          strategyActionAdditionalId
          guidesStrategyActionToInterventionAction
          interventionActionId
      ]
    ]
  assertRegistryWitnesses
    prepared
    strategyId
    framesMeasure
    measureId
    [ [ fixtureEdge
          strategyDriverId
          indicatesMeasurePerformanceDimension
          measureDimensionId
      , fixtureEdge
          strategyKeyResultId
          determinesMeasurePerformanceDimension
          measureDimensionId
      , fixtureEdge
          measureDimensionId
          (containsPerformanceDimension MeasureMeasurementDimension)
          measureKPIId
      ]
    , [ fixtureEdge
          strategyDriverId
          indicatesMeasurePerformanceDimension
          measureDimensionId
      , fixtureEdge
          strategyKeyResultAdditionalId
          determinesMeasurePerformanceDimension
          measureDimensionId
      , fixtureEdge
          measureDimensionId
          (containsPerformanceDimension MeasureMeasurementDimension)
          measureKPIId
      ]
    ]

assertRegistryWitnesses ::
     PreparedMacroEvidence
  -> RawNodeId
  -> Relation from to
  -> RawNodeId
  -> [[RawEdge]]
  -> Assertion
assertRegistryWitnesses prepared source relation target expected =
  case [ claim
       | (conclusion, claim) <- macroEvidenceClaims prepared
       , conclusion == fixtureEdge source relation target
       ] of
    [claim] ->
      sort
        (map
           (NonEmpty.toList . witnessPremises)
           (macroEvidenceWitnessesIn prepared claim))
        @?= sort expected
    claims ->
      assertFailure
        ("expected one registered macro claim, got " ++ show (length claims))

registryWitnessProjection :: PreparedMacroEvidence -> [(RawEdge, [[RawEdge]])]
registryWitnessProjection prepared =
  [ ( conclusion
    , sort
        (map
           (NonEmpty.toList . witnessPremises)
           (macroEvidenceWitnessesIn prepared claim)))
  | (conclusion, claim) <- macroEvidenceClaims prepared
  ]

fixtureEdge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
fixtureEdge source relation target =
  RawEdge source (relationNameFor relation) target

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier node =
  case node of
    RawContextNode identifier _ -> identifier
    RawPrimitiveNode identifier _ _ -> identifier
    RawStructuringNode identifier _ _ -> identifier
    RawAnchorNode identifier _ -> identifier

scenarioMatrix :: TestTree
scenarioMatrix =
  testGroup
    "0/10/20/40 shape matrix"
    [ testGroup
      (show size)
      [ testCase (show shape) (assertScenario shape size)
      | shape <- [minBound .. maxBound]
      ]
    | size <- declaredSizes
    ]

assertScenario :: ScenarioShape -> Int -> Assertion
assertScenario shape size =
  withScenario shape size $ \graph formulation evidence claim -> do
    let (witnesses, work) = macroEvidenceWitnessesInWithWork evidence claim
        actual = map (NonEmpty.toList . witnessPremises) witnesses
        expected = naiveFrameWitnesses graph formulation
        relational = macroRelationalWork work
        outputCount = length expected
        indexWork = macroEvidenceIndexBuildWork evidence
    actual @?= expected
    macroPreparedClaimLookups work @?= 1
    macroAlternativesVisited work @?= 1
    macroCanonicalInsertions work @?= outputCount
    macroWitnessesEmitted work @?= outputCount
    workCompleteNodeBindings relational @?= outputCount
    workEdgeBucketProbes relational @?= 3 * outputCount
    workExactOccurrenceReads relational @?= 3 * outputCount
    workResultsEmitted relational @?= outputCount
    buildNodesRead indexWork @?= length (rawNodes graph)
    buildNodeDomainInsertions indexWork @?= length (rawNodes graph)
    buildEdgesRead indexWork @?= length (rawEdges graph)
    buildCanonicalOccurrencesAssigned indexWork @?= length (rawEdges graph)
    buildProjectionInsertions indexWork @?= length (rawEdges graph)
    buildExactOccurrenceInsertions indexWork @?= length (rawEdges graph)

affineWorkContracts :: TestTree
affineWorkContracts =
  testGroup
    "non-output fan-out remains affine"
    [ testCase (show shape) (assertAffineShape shape)
    | shape <- [Sparse, Skewed, DeadEnd, Unrelated]
    ]

assertAffineShape :: ScenarioShape -> Assertion
assertAffineShape shape = do
  vectors <- mapM (scenarioWorkVector shape) declaredSizes
  case vectors of
    [zero, ten, twenty, forty] -> do
      let tenStep = vectorDifference ten zero
      vectorDifference twenty ten @?= tenStep
      vectorDifference forty twenty @?= map (* 2) tenStep
    _ -> assertFailure "declared size matrix is incomplete"

scenarioWorkVector :: ScenarioShape -> Int -> IO [Int]
scenarioWorkVector shape size =
  withScenarioResult shape size $ \_ _ evidence claim ->
    let (_, work) = macroEvidenceWitnessesInWithWork evidence claim
     in pure (evaluationVector (macroRelationalWork work))

evaluationVector :: EvaluationWork -> [Int]
evaluationVector work =
  [ workVariableFrames work
  , workConstraintScans work
  , workIndexDomainProbes work
  , workDomainSizeComparisons work
  , workDomainValuesVisited work
  , workIntersectionMembershipProbes work
  , workBindingAttempts work
  , workCompleteNodeBindings work
  , workEdgeBucketProbes work
  , workExactOccurrenceReads work
  , workResultsEmitted work
  ]

vectorDifference :: [Int] -> [Int] -> [Int]
vectorDifference left right = zipWith (-) left right

permutationContracts :: TestTree
permutationContracts =
  testGroup
    "canonical input invariance"
    [ testCase (show shape) (assertPermutationInvariant shape)
    | shape <- [minBound .. maxBound]
    ]

assertPermutationInvariant :: ScenarioShape -> Assertion
assertPermutationInvariant shape = do
  let size = 40
      graph = scenarioGraph shape size
      formulation = scenarioFormulation shape size
      reversed =
        graph
          { rawNodes = reverse (rawNodes graph)
          , rawEdges = reverse (rawEdges graph)
          }
  normal <- evaluatedWitnesses graph formulation
  permuted <- evaluatedWitnesses reversed formulation
  normalIdentities <- evaluatedWitnessIdentities graph formulation
  permutedIdentities <- evaluatedWitnessIdentities reversed formulation
  permuted @?= normal
  permutedIdentities @?= normalIdentities

existsContracts :: TestTree
existsContracts =
  testGroup
    "existence mode"
    [ testCase "agrees with non-empty enumeration and short-circuits"
        $ withScenario OutputHeavy 40
        $ \_ _ evidence claim -> do
            let (found, existsWork) =
                  macroEvidenceExistsInWithWork evidence claim
                (witnesses, enumerateWork) =
                  macroEvidenceWitnessesInWithWork evidence claim
                existsRelational = macroRelationalWork existsWork
                enumerateRelational = macroRelationalWork enumerateWork
            found @?= not (null witnesses)
            macroPreparedClaimLookups existsWork @?= 1
            macroCanonicalInsertions existsWork @?= 0
            macroWitnessesEmitted existsWork @?= 0
            workResultsEmitted existsRelational @?= 0
            assertBool
              "existence mode did not short-circuit occurrence reads"
              (workExactOccurrenceReads existsRelational
                 < workExactOccurrenceReads enumerateRelational)
    ]

evaluatedWitnesses :: RawGraph -> RawStrategyFormulation -> IO [[RawEdge]]
evaluatedWitnesses graph formulation =
  case validateScenario graph formulation of
    Left message -> assertFailure message >> pure []
    Right semantic -> do
      let evidence = prepareMacroEvidence semantic
      case frameClaim evidence of
        Left message -> assertFailure message >> pure []
        Right claim ->
          pure
            (map
               (NonEmpty.toList . witnessPremises)
               (macroEvidenceWitnessesIn evidence claim))

evaluatedWitnessIdentities ::
     RawGraph -> RawStrategyFormulation -> IO [MacroEvidenceWitness]
evaluatedWitnessIdentities graph formulation =
  case validateScenario graph formulation of
    Left message -> assertFailure message >> pure []
    Right semantic -> do
      let evidence = prepareMacroEvidence semantic
      case frameClaim evidence of
        Left message -> assertFailure message >> pure []
        Right claim -> pure (macroEvidenceWitnessesIn evidence claim)

withScenario ::
     ScenarioShape
  -> Int
  -> (RawGraph -> RawStrategyFormulation -> PreparedMacroEvidence -> MacroClaim
                                                                       RawNodeId -> Assertion)
  -> Assertion
withScenario shape size action = withScenarioResult shape size action

withScenarioResult ::
     ScenarioShape
  -> Int
  -> (RawGraph -> RawStrategyFormulation -> PreparedMacroEvidence -> MacroClaim
                                                                       RawNodeId -> IO
                                                                                      result)
  -> IO result
withScenarioResult shape size action =
  case scenarioSemantic shape size of
    Left message -> assertFailure message >> fail message
    Right semantic -> do
      let graph = scenarioGraph shape size
          formulation = scenarioFormulation shape size
          evidence = prepareMacroEvidence semantic
      case frameClaim evidence of
        Left message -> assertFailure message >> fail message
        Right claim -> action graph formulation evidence claim

declaredSizes :: [Int]
declaredSizes = [0, 10, 20, 40]
