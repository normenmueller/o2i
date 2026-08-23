{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import Data.List (intercalate, sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Core.Contract
import qualified O2I.Core.Contract.Generated as Generated
import qualified O2I.Core.Contract.Internal as Contract
import O2I.Core.Graph.Observation
  ( Commitment(..)
  , carrierCommitment
  , carrierModelIdentity
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity
import qualified O2I.Semantics as Public
import O2I.Semantics.Contextualization
  ( assessAssertedContextualizationDependencies
  )
import qualified O2I.Semantics.Eval as Eval
import O2I.Semantics.Family.CollectiveStrategyRealization
  ( CollectiveWork(..)
  , assessCollectiveStrategyRealizations
  , assessCollectiveStrategyRealizationsWithWork
  )
import O2I.Semantics.Index
import O2I.Semantics.Input
import O2I.Semantics.Internal
import O2I.Semantics.SituatedNeed (assessSituatedNeeds)
import O2I.Semantics.Strategy (assessStrategyFormulations)
import O2I.Structure
import qualified O2I.Structure.Index as StructureIndex
import O2I.Structure.Internal (StructureAssessment(..))
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertBool, assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core Semantics"
    [ testGroup
        "aggregate"
        [ testCase "accepts a complete semantic model" aggregateAccepted
        , testCase
            "reports unavailable without model defects"
            aggregateUnavailable
        , testCase
            "rejection takes precedence over unavailable"
            aggregatePrecedence
        , testCase "retains Candidate subject-local outcomes" candidateOutcomes
        ]
    , testGroup
        "families"
        [ testCase
            "rejects asserted use of Candidate contextualization"
            assertedContextualizationDependency
        , testCase "accepts a globally situated Need" situatedNeedAccepted
        , testCase
            "rejects Candidate carriers as situated-Need support"
            situatedNeedCandidateSupportRejected
        , testCase
            "rejects Candidate anchors as situated-Need support"
            situatedNeedCandidateAnchorRejected
        , testCase
            "reports deterministic situated-Need defects"
            situatedNeedRejected
        , testCase
            "reports missing Strategy input as unavailable"
            strategyUnavailable
        , testCase "rejects an incomplete Strategy graph" strategyInvalid
        , testCase "accepts a complete Strategy formulation" strategyValid
        , testCase
            "rejects Candidate carriers as Strategy support"
            strategyCandidateSupportRejected
        , testCase
            "keeps missing collective Fit separate from support"
            collectiveInputUnavailable
        , testCase "accepts a complete collective realization" collectiveValid
        , testCase
            "rejects Candidate Strategy carriers as collective support"
            collectiveCandidateSupportRejected
        , testCase
            "keeps collective component failures separate"
            collectiveComponentDefect
        , testCase
            "retains unrelated subjects across binding defects"
            supplementalBindingIsolation
        , testCase
            "suppresses only collective predicates with unresolved sites"
            collectiveSiteLocalSuppression
        , testCase
            "keeps target-independent Fit diagnostics"
            collectiveUnresolvedTargetIsolation
        , testCase
            "keeps participant-list-independent Fit diagnostics"
            collectiveUnresolvedParticipantsIsolation
        ]
    , testGroup
        "determinism"
        [ testCase "builds exact addressed semantic indexes" addressedIndex
        , testCase
            "closes the compiled semantic rule catalog"
            compiledRuleCatalog
        , testCase
            "projects exact generated semantic evidence schemas"
            compiledEvidenceSchemas
        , testCase "sorts defects by compiled rule order" compiledRuleOrder
        , testCase
            "retains accepted global order in flat Binding diagnostics"
            flatBindingDiagnosticOrder
        , testCase
            "is independent of projection and input permutation"
            permutationIndependence
        ]
    , testGroup
        "runtime occurrence evidence"
        [ testCase
            "retains direct macro-support occurrence roles"
            directMacroSupportOccurrenceRoles
        , testCase
            "retains direct primitive-support occurrence roles"
            directPrimitiveSupportOccurrenceRoles
        , testCase
            "executes the exact 27/27 real-producer matrix"
            realProducerOccurrenceMatrix
        , testCase
            "preserves every cardinality and multi-role order"
            runtimeOccurrenceCardinalityOracle
        ]
    , testGroup
        "work"
        [ testCase
            "scales only pairwise coherence quadratically"
            collectiveWorkScalesByParticipant
        , testCase
            "scales primitive support linearly by participant primitives"
            collectiveWorkScalesByParticipantPrimitive
        , testCase
            "prepares target primitive occurrences once"
            collectiveWorkScalesByTargetPrimitive
        ]
    ]

aggregateAccepted :: Assertion
aggregateAccepted =
  assertScenario
    completeModelOccurrences
    (completeProjection Forward True)
    completeInputs $ \graph inputs -> do
    let assessment = Public.assessSemantics graph inputs
    Public.semanticDisposition assessment @?= Public.SemanticAccepted
    length (publicSemanticEvidence assessment) @?= 0
    Public.semanticCandidateOccurrences assessment @?= []
    case Public.acceptedSemanticModel assessment of
      Nothing -> assertFailure "accepted assessment did not retain its proof"
      Just model -> do
        Public.semanticallyValidSituatedNeeds model @?= []
        map
          Public.qualificationEligibleStrategyIdentity
          (Public.semanticallyValidStrategies model)
          @?= map modelId ["strategy-a", "strategy-b", "strategy-target"]
        map
          Public.validatedCollectiveStrategyRealizationIdentity
          (Public.semanticallyValidCollectiveRealizations model)
          @?= [modelId "collective-claim"]

aggregateUnavailable :: Assertion
aggregateUnavailable =
  assertScenario
    (carrierModels ["strategy-a"])
    (structureProjection [strategyCarrier "a" Asserted] [] [] [] [])
    [] $ \graph inputs -> do
    let assessment = Public.assessSemantics graph inputs
    Public.semanticDisposition assessment @?= Public.SemanticUnavailable
    length (publicSemanticEvidence assessment) @?= 0
    map
      Public.strategyFormulationDisposition
      (Public.strategyFormulationAssessments assessment)
      @?= [Public.SubjectUnavailable]

aggregatePrecedence :: Assertion
aggregatePrecedence =
  assertScenario
    (carrierModels ["need", "strategy-a"])
    (structureProjection
       [contextCarrier "need" "Need" Asserted, strategyCarrier "a" Asserted]
       []
       []
       []
       [])
    [] $ \graph inputs -> do
    let assessment = Public.assessSemantics graph inputs
    Public.semanticDisposition assessment @?= Public.SemanticRejected
    map
      Public.strategyFormulationDisposition
      (Public.strategyFormulationAssessments assessment)
      @?= [Public.SubjectUnavailable]
    map Public.semanticDiagnosticRule (publicSemanticEvidence assessment)
      @?= map
            semanticRuleId
            [ semanticRule Generated.SituatedNeedDriverCardinalityRule
            , semanticRule Generated.SituatedNeedObjectiveCardinalityRule
            , semanticRule
                Generated.SituatedNeedSurfacingSituationCardinalityRule
            ]

publicSemanticEvidence ::
     Public.SemanticAssessment scope
  -> [Public.SemanticDiagnosticEvidence scope]
publicSemanticEvidence =
  Public.foldSemanticAssessment NonEmpty.toList [] (const [])

candidateOutcomes :: Assertion
candidateOutcomes =
  assertScenario candidateModelOccurrences candidateProjection [] $ \graph inputs -> do
    let assessment = Public.assessSemantics graph inputs
    Public.semanticDisposition assessment @?= Public.SemanticAccepted
    map
      Public.situatedNeedDisposition
      (Public.situatedNeedAssessments assessment)
      @?= [Public.SubjectCandidate]
    map
      Public.strategyFormulationDisposition
      (Public.strategyFormulationAssessments assessment)
      @?= replicate 3 Public.SubjectCandidate
    map
      Public.collectiveStrategyRealizationDisposition
      (Public.collectiveStrategyRealizationAssessments assessment)
      @?= [Public.SubjectCandidate]
    map occurrenceIdentityText (Public.semanticCandidateOccurrences assessment)
      @?= sort
            [ "collective-claim"
            , "need"
            , "strategy-a"
            , "strategy-b"
            , "strategy-target"
            ]

assertedContextualizationDependency :: Assertion
assertedContextualizationDependency =
  assertScenario
    contextualizationDependencyModels
    contextualizationDependencyProjection
    [] $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
        defects =
          assessAssertedContextualizationDependencies semanticIndex graph
        assessment = Public.assessSemantics graph inputs
    length defects @?= 1
    map (semanticRuleId . semanticDefectRule) defects
      @?= [ semanticRuleId
              (semanticRuleIdentity
                 Generated.ContextualizationAssertedDependencyRuleIdentity)
          ]
    map flattenDefectOccurrences defects
      @?= [ map
              occurrenceId
              [ "relation-principle-guides-action"
              , "strategy-a-principle"
              , "owns-strategy-a-principle"
              ]
          ]
    Public.semanticDisposition assessment @?= Public.SemanticRejected

situatedNeedAccepted :: Assertion
situatedNeedAccepted =
  assertScenario needModelOccurrences validNeedProjection [] $ \graph inputs ->
    let semanticIndex = buildSemanticIndex graph inputs
     in case assessSituatedNeeds semanticIndex of
          [SituatedNeedValid proof] -> do
            situatedNeedIdentity proof @?= modelId "need"
            assertCarrierWitnessesAsserted
              semanticIndex
              (situatedNeedWitnesses proof)
            assertBool
              "situated Need proof must retain complete witnesses"
              (length (situatedNeedWitnesses proof) >= 11)
          result ->
            assertFailure ("unexpected situated Need result: " ++ show result)

situatedNeedRejected :: Assertion
situatedNeedRejected =
  assertScenario
    (carrierModels ["need"])
    (structureProjection [contextCarrier "need" "Need" Asserted] [] [] [] [])
    [] $ \graph inputs ->
    case assessSituatedNeeds (buildSemanticIndex graph inputs) of
      [SituatedNeedInvalid subject defects] -> do
        subject @?= modelId "need"
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [ semanticRule Generated.SituatedNeedDriverCardinalityRule
              , semanticRule Generated.SituatedNeedObjectiveCardinalityRule
              , semanticRule
                  Generated.SituatedNeedSurfacingSituationCardinalityRule
              ]
      result ->
        assertFailure ("unexpected situated Need result: " ++ show result)

situatedNeedCandidateSupportRejected :: Assertion
situatedNeedCandidateSupportRejected =
  assertScenario needModelOccurrences needProjectionWithCandidateSituation [] $ \graph inputs ->
    case assessSituatedNeeds (buildSemanticIndex graph inputs) of
      [SituatedNeedInvalid subject defects] -> do
        subject @?= modelId "need"
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [ semanticRule Generated.SituatedNeedDriverAnchoringRule
              , semanticRule
                  Generated.SituatedNeedSurfacingSituationCardinalityRule
              ]
      result ->
        assertFailure
          ("Candidate Situation became Need proof support: " ++ show result)

situatedNeedCandidateAnchorRejected :: Assertion
situatedNeedCandidateAnchorRejected =
  assertScenario needModelOccurrences needProjectionWithCandidateAnchor [] $ \graph inputs ->
    case assessSituatedNeeds (buildSemanticIndex graph inputs) of
      [SituatedNeedInvalid subject defects] -> do
        subject @?= modelId "need"
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [ semanticRule Generated.SituatedNeedDriverAnchoringRule
              , semanticRule
                  Generated.SituatedNeedSurfacingSituationAnchoringRule
              ]
      result ->
        assertFailure
          ("Candidate Situation Anchor became Need proof support: "
             ++ show result)

strategyUnavailable :: Assertion
strategyUnavailable =
  assertScenario
    (carrierModels ["strategy-a"])
    (structureProjection [strategyCarrier "a" Asserted] [] [] [] [])
    [] $ \graph inputs ->
    assessStrategyFormulations (buildSemanticIndex graph inputs)
      @?= [ StrategyFormulationUnavailable
              (modelId "strategy-a")
              StrategyFormulationInputMissing
          ]

strategyInvalid :: Assertion
strategyInvalid =
  assertScenario
    (strategyModelOccurrences "a")
    (strategyProjectionWithoutVisionOrientation "a")
    [(0, strategyInput "a")] $ \graph inputs ->
    case assessStrategyFormulations (buildSemanticIndex graph inputs) of
      [StrategyFormulationInvalid subject defects] -> do
        subject @?= modelId "strategy-a"
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [semanticRule Generated.StrategyFormulationVisionOrientationRule]
      result -> assertFailure ("unexpected Strategy result: " ++ show result)

strategyValid :: Assertion
strategyValid =
  assertScenario
    (strategyModelOccurrences "a")
    (strategyProjection "a")
    [(0, strategyInput "a")] $ \graph inputs ->
    let semanticIndex = buildSemanticIndex graph inputs
     in case assessStrategyFormulations semanticIndex of
          [StrategyFormulationValid proof] -> do
            eligibleStrategyIdentity proof @?= modelId "strategy-a"
            assertCarrierWitnessesAsserted
              semanticIndex
              (eligibleStrategyWitnesses proof)
            assertBool
              "Strategy proof must retain complete witnesses"
              (length (eligibleStrategyWitnesses proof) >= 17)
          result ->
            assertFailure ("unexpected Strategy result: " ++ show result)

strategyCandidateSupportRejected :: Assertion
strategyCandidateSupportRejected =
  assertScenario
    (strategyModelOccurrences "a")
    (strategyProjectionWithCandidateVisionObjective "a")
    [(0, strategyInput "a")] $ \graph inputs ->
    case assessStrategyFormulations (buildSemanticIndex graph inputs) of
      [StrategyFormulationInvalid subject defects] -> do
        subject @?= modelId "strategy-a"
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [semanticRule Generated.StrategyFormulationVisionOrientationRule]
      result ->
        assertFailure
          ("Candidate Vision Objective became Strategy proof support: "
             ++ show result)

collectiveInputUnavailable :: Assertion
collectiveInputUnavailable =
  assertScenario
    completeModelOccurrences
    (completeProjection Forward True)
    strategyInputs $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
        strategies = assessStrategyFormulations semanticIndex
    case assessCollectiveStrategyRealizations semanticIndex strategies of
      [CollectiveStrategyRealizationUnavailable subject components] -> do
        subject @?= modelId "collective-claim"
        componentSummary components
          @?= ( Public.ComponentSatisfied
              , Public.ComponentUnavailable
              , Public.ComponentSatisfied
              , replicate 2 Public.ComponentSatisfied
              , replicate 2 Public.ComponentSatisfied)
      result -> assertFailure ("unexpected collective result: " ++ show result)

collectiveValid :: Assertion
collectiveValid =
  assertScenario
    completeModelOccurrences
    (completeProjection Forward True)
    completeInputs $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
        strategies = assessStrategyFormulations semanticIndex
    case assessCollectiveStrategyRealizations semanticIndex strategies of
      [CollectiveStrategyRealizationValid proof components] -> do
        validatedCollectiveClaim proof @?= modelId "collective-claim"
        assertCarrierWitnessesAsserted
          semanticIndex
          (validatedCollectiveWitnesses proof)
        assertBool
          "collective proof must retain family and prerequisite witnesses"
          (length (validatedCollectiveWitnesses proof) >= 40)
        componentSummary components
          @?= ( Public.ComponentSatisfied
              , Public.ComponentSatisfied
              , Public.ComponentSatisfied
              , replicate 2 Public.ComponentSatisfied
              , replicate 2 Public.ComponentSatisfied)
      result -> assertFailure ("unexpected collective result: " ++ show result)

collectiveCandidateSupportRejected :: Assertion
collectiveCandidateSupportRejected =
  assertScenario
    completeModelOccurrences
    completeProjectionWithCandidateParticipant
    completeInputs $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
        strategies = assessStrategyFormulations semanticIndex
    case assessCollectiveStrategyRealizations semanticIndex strategies of
      [CollectiveStrategyRealizationInvalid _ components _] ->
        map
          Public.macroSupportDisposition
          (Public.collectiveMacroSupportAssessments components)
          @?= [Public.ComponentInvalid, Public.ComponentSatisfied]
      result ->
        assertFailure
          ("Candidate Strategy became collective proof support: " ++ show result)

collectiveComponentDefect :: Assertion
collectiveComponentDefect =
  assertScenario
    completeModelOccurrences
    (completeProjection Forward False)
    completeInputs $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
        strategies = assessStrategyFormulations semanticIndex
    case assessCollectiveStrategyRealizations semanticIndex strategies of
      [CollectiveStrategyRealizationInvalid subject components defects] -> do
        subject @?= modelId "collective-claim"
        componentSummary components
          @?= ( Public.ComponentSatisfied
              , Public.ComponentSatisfied
              , Public.ComponentSatisfied
              , [Public.ComponentSatisfied, Public.ComponentInvalid]
              , replicate 2 Public.ComponentSatisfied)
        map semanticDefectRule (NonEmpty.toList defects)
          @?= [semanticRule Generated.CollectiveAssertedMacroSupportRule]
        map flattenDefectOccurrences (NonEmpty.toList defects)
          @?= [ map
                  occurrenceId
                  ["collective-claim", "strategy-b", "strategy-target"]
              ]
      result -> assertFailure ("unexpected collective result: " ++ show result)

directMacroSupportOccurrenceRoles :: Assertion
directMacroSupportOccurrenceRoles =
  assertProducerGroups
    "core.collective-strategy-realization.asserted-macro-support"
    [ ("claim", ["collective-claim"])
    , ("participant", ["strategy-b"])
    , ("target", ["strategy-target"])
    ]

directPrimitiveSupportOccurrenceRoles :: Assertion
directPrimitiveSupportOccurrenceRoles =
  assertProducerGroups
    "core.collective-strategy-realization.asserted-participant-primitive-support"
    [ ("claim", ["collective-claim"])
    , ("participant", ["strategy-a"])
    , ("target", ["strategy-target"])
    ]

assertProducerGroups :: Text -> [(Text, [Text])] -> Assertion
assertProducerGroups rule expected =
  case realProducerDefects of
    Left problem -> assertFailure problem
    Right defects ->
      case filter ((== (rule, expected)) . runtimeOccurrenceSummary) defects of
        [defect] -> snd (runtimeOccurrenceSummary defect) @?= expected
        found ->
          assertFailure
            ("expected one real producer for "
               ++ Text.unpack rule
               ++ ", found "
               ++ show (length found))

realProducerOccurrenceMatrix :: Assertion
realProducerOccurrenceMatrix =
  case realProducerDefects of
    Left problem -> assertFailure problem
    Right defects ->
      let byRule =
            Map.fromListWith
              min
              [ (fst summary, summary)
              | defect <- defects
              , let summary = runtimeOccurrenceSummary defect
              ]
          actual = map (byRule Map.!) (map fst runtimeProducerOccurrenceOracle)
       in do
            length runtimeProducerOccurrenceOracle @?= 27
            Map.keysSet byRule
              @?= Map.keysSet (Map.fromList runtimeProducerOccurrenceOracle)
            actual @?= runtimeProducerOccurrenceOracle

runtimeOccurrenceCardinalityOracle :: Assertion
runtimeOccurrenceCardinalityOracle = do
  groups Generated.SituatedNeedDriverCardinalityOccurrences
    @?= [("observed-driver", [])]
  groups (Generated.StrategyFormulationDiagnosisOccurrences [])
    @?= [("owned-diagnosis", [])]
  groups (Generated.StrategyFormulationDiagnosisOccurrences ["one"])
    @?= [("owned-diagnosis", ["one"])]
  groups (Generated.StrategyFormulationDiagnosisOccurrences ["one", "many"])
    @?= [("owned-diagnosis", ["one", "many"])]
  groups
    (Generated.StrategyFormulationActionsOccurrences ("one" NonEmpty.:| []))
    @?= [("listed-action", ["one"])]
  groups
    (Generated.StrategyFormulationActionsOccurrences
       ("one" NonEmpty.:| ["many"]))
    @?= [("listed-action", ["one", "many"])]
  groups
    (Generated.CollectiveAssertedCollectiveCoverageOccurrences
       ("one" NonEmpty.:| []))
    @?= [("uncovered-target-member", ["one"])]
  groups
    (Generated.CollectiveAssertedCollectiveCoverageOccurrences
       ("one" NonEmpty.:| ["many"]))
    @?= [("uncovered-target-member", ["one", "many"])]
  groups
    (Generated.StrategyFormulationDiagnosisGroundingOccurrences
       "diagnosis"
       "intent")
    @?= [("diagnosis", ["diagnosis"]), ("intent", ["intent"])]
  assertBool
    "binary role reassociation was observationally invisible"
    (groups
       (Generated.StrategyFormulationDiagnosisGroundingOccurrences
          "intent"
          "diagnosis")
       /= [("diagnosis", ["diagnosis"]), ("intent", ["intent"])])
  groups
    (Generated.CollectiveAssertedMacroSupportOccurrences
       "claim"
       "participant"
       "target")
    @?= [ ("claim", ["claim"])
        , ("participant", ["participant"])
        , ("target", ["target"])
        ]
  assertBool
    "three-role reassociation was observationally invisible"
    (groups
       (Generated.CollectiveAssertedMacroSupportOccurrences
          "target"
          "participant"
          "claim")
       /= [ ("claim", ["claim"])
          , ("participant", ["participant"])
          , ("target", ["target"])
          ])
  where
    groups ::
         Generated.GeneratedSemanticOccurrenceEvidence schema Text
      -> [(Text, [Text])]
    groups =
      NonEmpty.toList . Generated.generatedSemanticOccurrenceEvidenceGroups

runtimeOccurrenceSummary :: SemanticDefect -> (Text, [(Text, [Text])])
runtimeOccurrenceSummary defect =
  ( coreRuleIdText (semanticRuleId (semanticDefectRule defect))
  , [ (role, map occurrenceIdentityText occurrences)
    | (role, occurrences) <-
        NonEmpty.toList (semanticDefectOccurrenceGroups defect)
    ])

runtimeProducerOccurrenceOracle :: [(Text, [(Text, [Text])])]
runtimeProducerOccurrenceOracle =
  [ ( "core.collective-strategy-realization.asserted-collective-coverage"
    , [ ( "uncovered-target-member"
        , ["strategy-target-action", "strategy-target-key-result"])
      ])
  , ( "core.collective-strategy-realization.asserted-completeness"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.asserted-macro-support"
    , [ ("claim", ["collective-claim"])
      , ("participant", ["strategy-b"])
      , ("target", ["strategy-target"])
      ])
  , ( "core.collective-strategy-realization.asserted-participant-primitive-support"
    , [ ("claim", ["collective-claim"])
      , ("participant", ["strategy-a"])
      , ("target", ["strategy-target"])
      ])
  , ( "core.collective-strategy-realization.fit-pairwise-coherence"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.fit-participant-binding"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.fit-participant-compatibility"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.fit-target-binding"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.fit-target-guiding-policy"
    , [("claim", ["collective-claim"])])
  , ( "core.collective-strategy-realization.fit-target-trade-offs"
    , [("claim", ["collective-claim"])])
  , ( "core.contextualization.asserted-dependency"
    , [ ("dependent", ["relation-principle-guides-action"])
      , ("contextualized-endpoint", ["strategy-a-principle"])
      , ("candidate-contextualization", ["owns-strategy-a-principle"])
      ])
  , ( "core.situated-need.driver-anchoring"
    , [("unanchored-driver", ["need-driver"])])
  , ("core.situated-need.driver-cardinality", [("observed-driver", [])])
  , ("core.situated-need.objective-cardinality", [("observed-objective", [])])
  , ( "core.situated-need.objective-grounding"
    , [("ungrounded-objective", ["need-objective"])])
  , ( "core.situated-need.surfacing-situation-anchoring"
    , [("unanchored-surfacing-situation", ["situation"])])
  , ( "core.situated-need.surfacing-situation-cardinality"
    , [("observed-surfacing-situation", [])])
  , ( "core.strategy-formulation.action-contributions"
    , [("uncontributing-action", ["strategy-a-action"])])
  , ( "core.strategy-formulation.actions"
    , [("listed-action", ["strategy-b-action"])])
  , ( "core.strategy-formulation.diagnosis"
    , [("owned-diagnosis", ["strategy-a-driver"])])
  , ( "core.strategy-formulation.diagnosis-grounding"
    , [ ("diagnosis", ["strategy-a-driver"])
      , ("intent", ["strategy-a-objective"])
      ])
  , ( "core.strategy-formulation.guiding-policy"
    , [("owned-guiding-policy", ["strategy-a-principle"])])
  , ( "core.strategy-formulation.guiding-policy-actions"
    , [ ("guiding-policy", ["strategy-a-principle"])
      , ("action", ["strategy-a-action"])
      ])
  , ( "core.strategy-formulation.intent"
    , [("owned-intent", ["strategy-a-objective"])])
  , ( "core.strategy-formulation.key-result-substantiation"
    , [ ("key-result", ["strategy-a-key-result"])
      , ("intent", ["strategy-a-objective"])
      ])
  , ( "core.strategy-formulation.key-results"
    , [("listed-key-result", ["strategy-b-key-result"])])
  , ( "core.strategy-formulation.vision-orientation"
    , [("observed-vision-orientation", [])])
  ]

realProducerDefects :: Either String [SemanticDefect]
realProducerDefects =
  concat
    <$> sequence
          [ scenarioDefects
              contextualizationDependencyModels
              contextualizationDependencyProjection
              []
          , scenarioDefects
              (carrierModels ["need"])
              (structureProjection
                 [contextCarrier "need" "Need" Asserted]
                 []
                 []
                 []
                 [])
              []
          , scenarioDefects
              needModelOccurrences
              needProjectionWithCandidateAnchor
              []
          , scenarioDefects
              needModelOccurrences
              needProjectionWithoutGrounding
              []
          , scenarioDefects
              strategyMismatchModelOccurrences
              strategyMismatchProjection
              [(0, strategyMismatchInput)]
          , scenarioDefects
              (strategyModelOccurrences "a")
              (strategyProjectionMissingRelation "a" 0)
              [(0, strategyInput "a")]
          , scenarioDefects
              (strategyModelOccurrences "a")
              (strategyProjectionMissingRelation "a" 1)
              [(0, strategyInput "a")]
          , scenarioDefects
              (strategyModelOccurrences "a")
              (strategyProjectionMissingRelation "a" 2)
              [(0, strategyInput "a")]
          , scenarioDefects
              (strategyModelOccurrences "a")
              (strategyProjectionMissingRelation "a" 3)
              [(0, strategyInput "a")]
          , scenarioDefects
              (strategyModelOccurrences "a")
              (strategyProjectionWithoutVisionOrientation "a")
              [(0, strategyInput "a")]
          , scenarioDefects
              completeModelOccurrences
              (completeProjection Forward True)
              (strategyInputs ++ [(3, collectiveInputAllFitDefects)])
          , scenarioDefects
              completeModelOccurrences
              completeProjectionOpen
              completeInputs
          , scenarioDefects
              completeModelOccurrences
              completeProjectionWithoutPrimitives
              completeInputs
          , scenarioDefects
              completeModelOccurrences
              (completeProjection Forward False)
              completeInputs
          ]

scenarioDefects ::
     [ModelOccurrence]
  -> StructureProjection
  -> [(Natural, ByteString)]
  -> Either String [SemanticDefect]
scenarioDefects occurrences projection inputs =
  runScenario
    occurrences
    projection
    inputs
    (\graph bound ->
       case Eval.assessSemantics graph bound of
         SemanticsRejected _ defects -> NonEmpty.toList defects
         _ -> [])

supplementalBindingIsolation :: Assertion
supplementalBindingIsolation =
  assertBindingScenario
    completeModelOccurrences
    (completeProjection Forward True)
    [ (0, strategyInputWithDiagnosis "a" "unknown-diagnosis")
    , (1, strategyInput "b")
    , (2, strategyInput "target")
    ] $ \graph binding -> foldSupplementalBinding (inspect graph) binding
  where
    inspect graph bound evidence = do
      map supplementalBindingEvidenceIsUnknown evidence @?= [True]
      let semanticIndex = buildSemanticIndex graph bound
      case assessStrategyFormulations semanticIndex of
        [StrategyFormulationUnavailable subject reason, StrategyFormulationValid strategyB, StrategyFormulationValid strategyTarget] -> do
          subject @?= modelId "strategy-a"
          reason @?= StrategyFormulationIdentityUnresolved
          eligibleStrategyIdentity strategyB @?= modelId "strategy-b"
          eligibleStrategyIdentity strategyTarget @?= modelId "strategy-target"
        result ->
          assertFailure
            ("binding defect suppressed unrelated Strategy results: "
               ++ show result)

flatBindingDiagnosticOrder :: Assertion
flatBindingDiagnosticOrder =
  assertBindingScenario
    completeModelOccurrences
    (completeProjection Forward True)
    [ (0, strategyInputWithDiagnosis "a" "strategy-a")
    , (1, strategyInputWithDiagnosis "b" "unknown-diagnosis")
    ] $ \_ binding ->
    foldSupplementalBindingDiagnostics
      (\_ evidence ->
         map
           (coreRuleIdText . supplementalBindingDiagnosticEvidenceRule)
           evidence
           @?= [ "core.supplemental.identity.unknown"
               , "core.supplemental.identity.wrong-type"
               ])
      binding

collectiveSiteLocalSuppression :: Assertion
collectiveSiteLocalSuppression =
  assertBindingScenario
    completeModelOccurrences
    (completeProjection Forward True)
    (strategyInputs ++ [(3, collectiveInputWithUnresolvedPolicy)]) $ \graph binding ->
    foldSupplementalBinding (inspect graph) binding
  where
    inspect graph bound evidence = do
      map supplementalBindingEvidenceIsUnknown evidence @?= [True]
      let semanticIndex = buildSemanticIndex graph bound
          strategies = assessStrategyFormulations semanticIndex
      case assessCollectiveStrategyRealizations semanticIndex strategies of
        [CollectiveStrategyRealizationInvalid _ components defects] -> do
          map semanticDefectRule (NonEmpty.toList defects)
            @?= [semanticRule Generated.CollectiveFitTargetTradeOffsRule]
          Public.collectiveFitDisposition components @?= Public.ComponentInvalid
        result ->
          assertFailure
            ("unresolved collective site suppressed an independent predicate: "
               ++ show result)

collectiveUnresolvedTargetIsolation :: Assertion
collectiveUnresolvedTargetIsolation =
  assertCollectiveBindingDefects
    collectiveInputWithUnresolvedTarget
    [ semanticRule Generated.CollectiveFitTargetGuidingPolicyRule
    , semanticRule Generated.CollectiveFitTargetTradeOffsRule
    ]

collectiveUnresolvedParticipantsIsolation :: Assertion
collectiveUnresolvedParticipantsIsolation =
  assertCollectiveBindingDefects
    collectiveInputWithUnresolvedParticipants
    [ semanticRule Generated.CollectiveFitPairwiseCoherenceRule
    , semanticRule Generated.CollectiveFitParticipantCompatibilityRule
    ]

assertCollectiveBindingDefects :: ByteString -> [SemanticRule] -> Assertion
assertCollectiveBindingDefects input expectedRules =
  assertBindingScenario
    completeModelOccurrences
    (completeProjection Forward True)
    (strategyInputs ++ [(3, input)]) $ \graph binding ->
    foldSupplementalBinding (inspect graph) binding
  where
    inspect graph bound evidence = do
      map supplementalBindingEvidenceIsUnknown evidence @?= [True]
      let semanticIndex = buildSemanticIndex graph bound
          strategies = assessStrategyFormulations semanticIndex
      case assessCollectiveStrategyRealizations semanticIndex strategies of
        [CollectiveStrategyRealizationInvalid _ components defects] -> do
          map semanticDefectRule (NonEmpty.toList defects) @?= expectedRules
          Public.collectiveFitDisposition components @?= Public.ComponentInvalid
        result ->
          assertFailure
            ("unexpected site-local collective result: " ++ show result)

supplementalBindingEvidenceIsUnknown ::
     SupplementalBindingEvidence scope () -> Bool
supplementalBindingEvidenceIsUnknown =
  foldSupplementalBindingEvidence (const eliminator)
  where
    eliminator =
      SupplementalInputDefectEliminator
        { eliminateSupplementalInvalidUtf8 = const False
        , eliminateSupplementalInvalidJsonSyntax = const False
        , eliminateSupplementalDuplicateObjectMember = const False
        , eliminateSupplementalTopLevelObjectRequired = const False
        , eliminateSupplementalTypeMemberInvalid = const False
        , eliminateSupplementalPayloadTypeNotAdmitted = const False
        , eliminateSupplementalRequiredMemberMissing = const False
        , eliminateSupplementalUnknownMember = const False
        , eliminateSupplementalValueKindInvalid = const False
        , eliminateSupplementalScalarGrammarInvalid = const False
        , eliminateSupplementalArrayCardinalityInvalid = const False
        , eliminateSupplementalArrayDistinctnessInvalid = const False
        , eliminateSupplementalSubjectCardinalityInvalid = const False
        , eliminateSupplementalIdentityUnknown = const True
        , eliminateSupplementalIdentityAmbiguous = const False
        , eliminateSupplementalIdentityWrongType = const False
        , eliminateSupplementalIdentityOutOfSelectedView = const False
        , eliminateSupplementalModelIdentityUnicodeScalarInvalid = const False
        , eliminateSupplementalModelIdentityContainsNul = const False
        }

collectiveWorkScalesByParticipant :: Assertion
collectiveWorkScalesByParticipant = do
  workTwo <- requireCollectiveWork 2 1 1
  workFour <- requireCollectiveWork 4 1 1
  workTwo @?= expectedCollectiveWork 2 1 1
  workFour @?= expectedCollectiveWork 4 1 1
  collectivePairwiseComparisons workFour @?= 6
    * collectivePairwiseComparisons workTwo

collectiveWorkScalesByParticipantPrimitive :: Assertion
collectiveWorkScalesByParticipantPrimitive = do
  workOne <- requireCollectiveWork 2 1 1
  workThree <- requireCollectiveWork 2 3 1
  workThree @?= expectedCollectiveWork 2 3 1
  collectiveContributionSourceProbes workThree @?= 3
    * collectiveContributionSourceProbes workOne
  collectivePairwiseComparisons workThree
    @?= collectivePairwiseComparisons workOne

collectiveWorkScalesByTargetPrimitive :: Assertion
collectiveWorkScalesByTargetPrimitive = do
  workOne <- requireCollectiveWork 2 1 1
  workFour <- requireCollectiveWork 2 1 4
  workFour @?= expectedCollectiveWork 2 1 4
  collectiveTargetPrimitiveLookups workFour @?= 4
    * collectiveTargetPrimitiveLookups workOne
  collectiveContributionSourceProbes workFour
    @?= collectiveContributionSourceProbes workOne
  collectivePairwiseComparisons workFour
    @?= collectivePairwiseComparisons workOne

requireCollectiveWork :: Int -> Int -> Int -> IO CollectiveWork
requireCollectiveWork participantCount participantWidth targetWidth =
  case collectiveWorkFor participantCount participantWidth targetWidth of
    Left problem -> assertFailure problem >> pure (expectedCollectiveWork 0 0 0)
    Right work -> pure work

collectiveWorkFor :: Int -> Int -> Int -> Either String CollectiveWork
collectiveWorkFor participantCount participantWidth targetWidth = do
  result <-
    runScenario
      (workModelOccurrences participantCount participantWidth targetWidth)
      (workProjection participantCount participantWidth targetWidth)
      (workInputs participantCount participantWidth targetWidth)
      (\graph inputs ->
         let semanticIndex = buildSemanticIndex graph inputs
             strategies = assessStrategyFormulations semanticIndex
          in case assessCollectiveStrategyRealizationsWithWork
                    semanticIndex
                    strategies of
               [(_, work)] -> Right work
               outcomes ->
                 Left ("unexpected collective work outcomes: " ++ show outcomes))
  result

expectedCollectiveWork :: Int -> Int -> Int -> CollectiveWork
expectedCollectiveWork participantCount participantWidth targetWidth =
  CollectiveWork
    { collectiveParticipantIndexEntries = participantCount
    , collectiveParticipantPrimitiveLookups =
        2 * participantCount * participantWidth
    , collectiveTargetPrimitiveLookups = 2 * targetWidth
    , collectiveContributionSourceProbes =
        2 * participantCount * participantWidth
    , collectiveContributionTargetProbes =
        3 * participantCount * participantWidth
    , collectiveContributionRelationLookups =
        2 * participantCount * participantWidth
    , collectivePairwiseComparisons =
        participantCount * (participantCount - 1) `div` 2
    }

addressedIndex :: Assertion
addressedIndex =
  assertScenario
    completeModelOccurrences
    (completeProjection Forward True)
    completeInputs $ \graph inputs -> do
    let semanticIndex = buildSemanticIndex graph inputs
    map
      carrierModelIdentity
      (carriersAtEndpoint semanticIndex endpointContextStrategy)
      @?= map modelId ["strategy-a", "strategy-b", "strategy-target"]
    occurrencesForModelIdentity semanticIndex (modelId "strategy-b")
      @?= [occurrenceId "strategy-b"]
    assertedOwnedMembersAtEndpoint
      semanticIndex
      (occurrenceId "strategy-a")
      endpointStrategyAction
      @?= [occurrenceId "strategy-a-action"]
    assertedOutgoingTargets
      semanticIndex
      (occurrenceId "strategy-a-action")
      tokenContributesTo
      @?= map occurrenceId ["strategy-a-key-result", "strategy-target-action"]
    assertedIncomingSources
      semanticIndex
      (occurrenceId "strategy-target-action")
      tokenContributesTo
      @?= [occurrenceId "strategy-a-action"]
    map
      relationOccurrenceIdentity
      (assertedMatchingRelations
         semanticIndex
         (occurrenceId "strategy-a")
         tokenContributesTo
         (occurrenceId "strategy-target"))
      @?= [occurrenceId "macro-a-contributes-target"]
    assertBool
      "Strategy input must be indexed by exact model identity"
      (case strategyFormulationInputFor semanticIndex (modelId "strategy-a") of
         Just _ -> True
         Nothing -> False)
    assertBool
      "collective input must be indexed by exact claim identity"
      (case collectiveFitInputFor semanticIndex (modelId "collective-claim") of
         Just _ -> True
         Nothing -> False)

compiledRuleOrder :: Assertion
compiledRuleOrder = do
  let strategyDefect =
        mkSemanticDefect
          Generated.StrategyFormulationVisionOrientationRule
          (SemanticStrategyEvidenceKey (modelId "strategy-a"))
          Generated.StrategyFormulationVisionOrientationOccurrences
      needObjectiveDefect =
        mkSemanticDefect
          Generated.SituatedNeedObjectiveCardinalityRule
          (SemanticNeedEvidenceKey (modelId "need"))
          Generated.SituatedNeedObjectiveCardinalityOccurrences
      needDriverDefect =
        mkSemanticDefect
          Generated.SituatedNeedDriverCardinalityRule
          (SemanticNeedEvidenceKey (modelId "need"))
          Generated.SituatedNeedDriverCardinalityOccurrences
  sortSemanticDefects [strategyDefect, needObjectiveDefect, needDriverDefect]
    @?= [needDriverDefect, needObjectiveDefect, strategyDefect]
  map
    semanticRuleId
    [ semanticRule Generated.SituatedNeedDriverCardinalityRule
    , semanticRule Generated.SituatedNeedObjectiveCardinalityRule
    , semanticRule Generated.StrategyFormulationVisionOrientationRule
    ]
    @?= map
          (semanticRuleId . semanticDefectRule)
          [needDriverDefect, needObjectiveDefect, strategyDefect]

flattenDefectOccurrences :: SemanticDefect -> [OccurrenceIdentity]
flattenDefectOccurrences =
  concatMap snd . NonEmpty.toList . semanticDefectOccurrenceGroups

compiledRuleCatalog :: Assertion
compiledRuleCatalog = do
  let rules = NonEmpty.toList semanticRules
      compiledIds = NonEmpty.toList Contract.semanticsRuleIds
  sort (map semanticRuleId rules) @?= sort compiledIds
  sort (map semanticRuleRank rules) @?= [0 .. length compiledIds - 1]

compiledEvidenceSchemas :: Assertion
compiledEvidenceSchemas = do
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedFitClaimKeyWitness
    @?= ("claim" NonEmpty.:| [])
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedNeedKeyWitness
    @?= ("need" NonEmpty.:| [])
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedNeedMemberKeyWitness
    @?= ("need" NonEmpty.:| ["member"])
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedParticipantClaimKeyWitness
    @?= ("claim" NonEmpty.:| ["participant"])
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedStrategyKeyWitness
    @?= ("strategy" NonEmpty.:| [])
  Generated.generatedSemanticEvidenceSchemaFields
    Generated.GeneratedStrategyMemberKeyWitness
    @?= ("strategy" NonEmpty.:| ["member"])

permutationIndependence :: Assertion
permutationIndependence =
  case ( canonicalSemanticSummary Forward completeInputs
       , canonicalSemanticSummary Reverse (reverse completeInputs)) of
    (Right canonical, Right permuted) -> canonical @?= permuted
    (Left problem, _) -> assertFailure problem
    (_, Left problem) -> assertFailure problem

canonicalSemanticSummary ::
     ProjectionOrder -> [(Natural, ByteString)] -> Either String SemanticSummary
canonicalSemanticSummary order inputs =
  runScenario
    (ordered order completeModelOccurrences)
    (completeProjection order True)
    inputs
    (\graph bound -> summarizeAssessment (Public.assessSemantics graph bound))

data SemanticSummary = SemanticSummary
  { summaryDisposition :: !Public.SemanticDisposition
  , summaryDefects :: ![(Text, [Text])]
  , summaryCandidates :: ![Text]
  , summaryNeeds :: ![(Text, Public.SubjectDisposition)]
  , summaryStrategies :: ![(Text, Public.SubjectDisposition)]
  , summaryCollectives :: ![(Text, Public.SubjectDisposition)]
  , summaryComponents :: ![Maybe
                             ( Public.ComponentDisposition
                             , Public.ComponentDisposition
                             , Public.ComponentDisposition
                             , [Public.ComponentDisposition]
                             , [Public.ComponentDisposition])]
  } deriving (Eq, Show)

summarizeAssessment :: Public.SemanticAssessment scope -> SemanticSummary
summarizeAssessment assessment =
  SemanticSummary
    { summaryDisposition = Public.semanticDisposition assessment
    , summaryDefects =
        [ ( coreRuleIdText (Public.semanticDiagnosticRule defect)
          , map
              occurrenceIdentityText
              (concatMap
                 Public.semanticOccurrenceGroupOccurrences
                 (NonEmpty.toList
                    (Public.semanticDiagnosticOccurrenceGroups defect))))
        | defect <- publicSemanticEvidence assessment
        ]
    , summaryCandidates =
        map
          occurrenceIdentityText
          (Public.semanticCandidateOccurrences assessment)
    , summaryNeeds =
        [ ( modelIdentityText (Public.situatedNeedSubject result)
          , Public.situatedNeedDisposition result)
        | result <- Public.situatedNeedAssessments assessment
        ]
    , summaryStrategies =
        [ ( modelIdentityText (Public.strategyFormulationSubject result)
          , Public.strategyFormulationDisposition result)
        | result <- Public.strategyFormulationAssessments assessment
        ]
    , summaryCollectives =
        [ ( modelIdentityText
              (Public.collectiveStrategyRealizationSubject result)
          , Public.collectiveStrategyRealizationDisposition result)
        | result <- Public.collectiveStrategyRealizationAssessments assessment
        ]
    , summaryComponents =
        [ componentSummary
          <$> Public.collectiveStrategyRealizationComponents result
        | result <- Public.collectiveStrategyRealizationAssessments assessment
        ]
    }

componentSummary ::
     CollectiveStrategyRealizationComponents scope
  -> ( Public.ComponentDisposition
     , Public.ComponentDisposition
     , Public.ComponentDisposition
     , [Public.ComponentDisposition]
     , [Public.ComponentDisposition])
componentSummary components =
  ( Public.collectiveCompletenessDisposition components
  , Public.collectiveFitDisposition components
  , Public.collectiveCoverageDisposition components
  , map
      Public.macroSupportDisposition
      (Public.collectiveMacroSupportAssessments components)
  , map
      Public.primitiveSupportDisposition
      (Public.collectivePrimitiveSupportAssessments components))

data ProjectionOrder
  = Forward
  | Reverse

ordered :: ProjectionOrder -> [value] -> [value]
ordered order values =
  case order of
    Forward -> values
    Reverse -> reverse values

assertScenario ::
     [ModelOccurrence]
  -> StructureProjection
  -> [(Natural, ByteString)]
  -> (forall scope. WellFormedGraph scope -> BoundSupplementalInputs scope -> Assertion)
  -> Assertion
assertScenario occurrences projection inputs inspect =
  case runScenario occurrences projection inputs inspect of
    Left problem -> assertFailure problem
    Right assertion -> assertion

runScenario ::
     [ModelOccurrence]
  -> StructureProjection
  -> [(Natural, ByteString)]
  -> (forall scope. WellFormedGraph scope -> BoundSupplementalInputs scope -> result)
  -> Either String result
runScenario occurrences projection payloads inspect = do
  result <-
    runBindingScenario occurrences projection payloads $ \graph binding ->
      foldSupplementalBinding
        (\bound evidence ->
           case evidence of
             [] -> Right (inspect graph bound)
             _ ->
               Left
                 ("supplemental binding failed: "
                    ++ show (length evidence)
                    ++ " scoped diagnostics"))
        binding
  result

assertBindingScenario ::
     [ModelOccurrence]
  -> StructureProjection
  -> [(Natural, ByteString)]
  -> (forall scope. WellFormedGraph scope -> SupplementalBinding scope () -> Assertion)
  -> Assertion
assertBindingScenario occurrences projection inputs inspect =
  case runBindingScenario occurrences projection inputs inspect of
    Left problem -> assertFailure problem
    Right assertion -> assertion

runBindingScenario ::
     [ModelOccurrence]
  -> StructureProjection
  -> [(Natural, ByteString)]
  -> (forall scope. WellFormedGraph scope -> SupplementalBinding scope () -> result)
  -> Either String result
runBindingScenario occurrences projection payloads inspect = do
  identityIndex <- mapLeft "identity" (buildModelIdentityIndex occurrences)
  selected <-
    mapLeft
      "selected View"
      (withSelectedViewScope
         identityIndex
         (map modelOccurrenceIdentity occurrences)
         (\scope -> assessScoped scope))
  selected
  where
    assessScoped scope = do
      structure <-
        mapLeft
          "Structure input"
          (StructureIndex.assessStructure scope projection)
      graph <-
        case structure of
          StructureRejected defects ->
            Left ("Structure rejected fixture: " ++ show defects)
          StructureAccepted accepted -> Right accepted
      decoded <-
        traverse
          (\(ordinal, bytes) ->
             mapLeft
               "supplemental decode"
               (decodeSupplementalInput
                  ()
                  (supplementalInputOrdinal ordinal)
                  bytes))
          payloads
      inputSet <-
        mapLeft "supplemental set" (assessSupplementalInputSet decoded)
      let binding = bindSupplementalInputs graph inputSet
      Right (inspect graph binding)

mapLeft :: Show problem => String -> Either problem value -> Either String value
mapLeft label result =
  case result of
    Left problem -> Left (label ++ " failed: " ++ show problem)
    Right value -> Right value

candidateProjection :: StructureProjection
candidateProjection =
  structureProjection
    [ contextCarrier "need" "Need" Candidate
    , strategyCarrier "a" Candidate
    , strategyCarrier "b" Candidate
    , strategyCarrier "target" Candidate
    ]
    []
    []
    [ structuredPropositionProjection
        (occurrenceId "collective-claim")
        collectiveFamily
        completenessOpen
        Candidate
    ]
    [ incidence "claim-participant-a" participantRole "strategy-a"
    , incidence "claim-participant-b" participantRole "strategy-b"
    , incidence "claim-target" targetRole "strategy-target"
    ]

candidateModelOccurrences :: [ModelOccurrence]
candidateModelOccurrences =
  carrierModels
    ["need", "strategy-a", "strategy-b", "strategy-target", "collective-claim"]
    ++ segmentModels
         ["claim-participant-a", "claim-participant-b", "claim-target"]

contextualizationDependencyProjection :: StructureProjection
contextualizationDependencyProjection =
  structureProjection
    [ strategyCarrier "a" Candidate
    , primitiveCarrier "strategy-a-principle" "Principle" Asserted
    , primitiveCarrier "strategy-a-action" "Action" Asserted
    ]
    [ ownership
        "owns-strategy-a-principle"
        "strategy-a"
        "strategy-a-principle"
        Candidate
    , ownership
        "owns-strategy-a-action"
        "strategy-a"
        "strategy-a-action"
        Asserted
    ]
    [ relation
        "relation-principle-guides-action"
        "strategy-a-principle"
        "guides"
        "strategy-a-action"
        Asserted
    ]
    []
    []

contextualizationDependencyModels :: [ModelOccurrence]
contextualizationDependencyModels =
  carrierModels ["strategy-a", "strategy-a-principle", "strategy-a-action"]
    ++ segmentModels
         [ "owns-strategy-a-principle"
         , "owns-strategy-a-action"
         , "relation-principle-guides-action"
         ]

validNeedProjection :: StructureProjection
validNeedProjection =
  structureProjection needCarriers needContextualizations needRelations [] []

needProjectionWithCandidateSituation :: StructureProjection
needProjectionWithCandidateSituation =
  structureProjection
    [ contextCarrier "need" "Need" Asserted
    , contextCarrier "situation" "Situation" Candidate
    , anchorCarrier "anchor" "BusinessCapability" Asserted
    , primitiveCarrier "need-driver" "Driver" Asserted
    , primitiveCarrier "need-objective" "Objective" Asserted
    ]
    needContextualizations
    needRelations
    []
    []

needProjectionWithCandidateAnchor :: StructureProjection
needProjectionWithCandidateAnchor =
  structureProjection
    [ contextCarrier "need" "Need" Asserted
    , contextCarrier "situation" "Situation" Asserted
    , anchorCarrier "anchor" "BusinessCapability" Candidate
    , primitiveCarrier "need-driver" "Driver" Asserted
    , primitiveCarrier "need-objective" "Objective" Asserted
    ]
    needContextualizations
    needRelations
    []
    []

needProjectionWithoutGrounding :: StructureProjection
needProjectionWithoutGrounding =
  structureProjection
    needCarriers
    needContextualizations
    (init needRelations)
    []
    []

needCarriers :: [CarrierProjection]
needCarriers =
  [ contextCarrier "need" "Need" Asserted
  , contextCarrier "situation" "Situation" Asserted
  , anchorCarrier "anchor" "BusinessCapability" Asserted
  , primitiveCarrier "need-driver" "Driver" Asserted
  , primitiveCarrier "need-objective" "Objective" Asserted
  ]

needContextualizations :: [ContextualizationProjection]
needContextualizations =
  [ ownership "owns-need-driver" "need" "need-driver" Asserted
  , ownership "owns-need-objective" "need" "need-objective" Asserted
  ]

needRelations :: [RelationProjection]
needRelations =
  [ relation "situation-surfaces-need" "situation" "surfaces" "need" Asserted
  , relation
      "situation-constituted-by-anchor"
      "situation"
      "is-constituted-by"
      "anchor"
      Asserted
  , relation "anchor-anchors-driver" "anchor" "anchors" "need-driver" Asserted
  , relation
      "need-driver-grounds-objective"
      "need-driver"
      "grounds"
      "need-objective"
      Asserted
  ]

needModelOccurrences :: [ModelOccurrence]
needModelOccurrences =
  carrierModels ["need", "situation", "anchor", "need-driver", "need-objective"]
    ++ segmentModels
         [ "owns-need-driver"
         , "owns-need-objective"
         , "situation-surfaces-need"
         , "situation-constituted-by-anchor"
         , "anchor-anchors-driver"
         , "need-driver-grounds-objective"
         ]

strategyProjection :: String -> StructureProjection
strategyProjection label =
  structureProjection
    (visionCarriers ++ strategyCarriers label)
    (visionContextualizations ++ strategyContextualizations label)
    (visionOrientation label : strategyInternalRelations label)
    []
    []

strategyProjectionWithoutVisionOrientation :: String -> StructureProjection
strategyProjectionWithoutVisionOrientation label =
  structureProjection
    (visionCarriers ++ strategyCarriers label)
    (visionContextualizations ++ strategyContextualizations label)
    (strategyInternalRelations label)
    []
    []

strategyProjectionMissingRelation :: String -> Int -> StructureProjection
strategyProjectionMissingRelation label omitted =
  structureProjection
    (visionCarriers ++ strategyCarriers label)
    (visionContextualizations ++ strategyContextualizations label)
    (visionOrientation label
       : [ relationRow
         | (index, relationRow) <-
             zip [0 :: Int ..] (strategyInternalRelations label)
         , index /= omitted
         ])
    []
    []

strategyMismatchProjection :: StructureProjection
strategyMismatchProjection =
  structureProjection
    (visionCarriers ++ strategyCarriers "a" ++ strategyCarriers "b")
    (visionContextualizations
       ++ strategyContextualizations "a"
       ++ strategyContextualizations "b")
    (concatMap
       (\label -> visionOrientation label : strategyInternalRelations label)
       ["a", "b"])
    []
    []

strategyMismatchModelOccurrences :: [ModelOccurrence]
strategyMismatchModelOccurrences =
  carrierModels
    (visionCarrierNames ++ strategyCarrierNames "a" ++ strategyCarrierNames "b")
    ++ segmentModels
         (visionContextualizationNames
            ++ strategyContextualizationNames "a"
            ++ strategyContextualizationNames "b"
            ++ concatMap
                 (\label ->
                    visionOrientationName label
                      : strategyInternalRelationNames label)
                 ["a", "b"])

strategyProjectionWithCandidateVisionObjective :: String -> StructureProjection
strategyProjectionWithCandidateVisionObjective label =
  structureProjection
    (contextCarrier "vision" "Vision" Asserted
       : primitiveCarrier "vision-objective" "Objective" Candidate
       : strategyCarriers label)
    (visionContextualizations ++ strategyContextualizations label)
    (visionOrientation label : strategyInternalRelations label)
    []
    []

strategyModelOccurrences :: String -> [ModelOccurrence]
strategyModelOccurrences label =
  carrierModels (visionCarrierNames ++ strategyCarrierNames label)
    ++ segmentModels
         (visionContextualizationNames
            ++ strategyContextualizationNames label
            ++ (visionOrientationName label
                  : strategyInternalRelationNames label))

completeProjection :: ProjectionOrder -> Bool -> StructureProjection
completeProjection order includeSecondMacro =
  structureProjection
    (ordered order completeCarriers)
    (ordered order completeContextualizations)
    (ordered order relations)
    (ordered order [collectiveProposition])
    (ordered order collectiveIncidences)
  where
    relations =
      completeStrategyRelations
        ++ [macroRelation "a"]
        ++ [macroRelation "b" | includeSecondMacro]
        ++ collectivePrimitiveRelations

completeProjectionWithCandidateParticipant :: StructureProjection
completeProjectionWithCandidateParticipant =
  structureProjection
    (visionCarriers
       ++ strategyCarriersWithCommitment "a" Candidate
       ++ strategyCarriers "b"
       ++ strategyCarriers "target")
    completeContextualizations
    (completeStrategyRelations
       ++ [macroRelation "a", macroRelation "b"]
       ++ collectivePrimitiveRelations)
    [collectiveProposition]
    collectiveIncidences

completeProjectionOpen :: StructureProjection
completeProjectionOpen =
  structureProjection
    completeCarriers
    completeContextualizations
    (completeStrategyRelations
       ++ [macroRelation "a", macroRelation "b"]
       ++ collectivePrimitiveRelations)
    [ structuredPropositionProjection
        (occurrenceId "collective-claim")
        collectiveFamily
        completenessOpen
        Asserted
    ]
    collectiveIncidences

completeProjectionWithoutPrimitives :: StructureProjection
completeProjectionWithoutPrimitives =
  structureProjection
    completeCarriers
    completeContextualizations
    (completeStrategyRelations ++ [macroRelation "a", macroRelation "b"])
    [collectiveProposition]
    collectiveIncidences

completeCarriers :: [CarrierProjection]
completeCarriers =
  visionCarriers ++ concatMap strategyCarriers ["a", "b", "target"]

completeContextualizations :: [ContextualizationProjection]
completeContextualizations =
  visionContextualizations
    ++ concatMap strategyContextualizations ["a", "b", "target"]

completeStrategyRelations :: [RelationProjection]
completeStrategyRelations =
  concatMap
    (\label -> visionOrientation label : strategyInternalRelations label)
    ["a", "b", "target"]

collectivePrimitiveRelations :: [RelationProjection]
collectivePrimitiveRelations =
  [ relation
      "primitive-a-contributes-target-action"
      "strategy-a-action"
      "contributes-to"
      "strategy-target-action"
      Asserted
  , relation
      "primitive-b-contributes-target-key-result"
      "strategy-b-key-result"
      "contributes-to"
      "strategy-target-key-result"
      Asserted
  ]

macroRelation :: String -> RelationProjection
macroRelation label =
  relation
    ("macro-" ++ label ++ "-contributes-target")
    ("strategy-" ++ label)
    "contributes-to"
    "strategy-target"
    Asserted

collectiveProposition :: StructuredPropositionProjection
collectiveProposition =
  structuredPropositionProjection
    (occurrenceId "collective-claim")
    collectiveFamily
    completenessClosed
    Asserted

collectiveIncidences :: [StructuredIncidenceProjection]
collectiveIncidences =
  [ incidence "claim-participant-a" participantRole "strategy-a"
  , incidence "claim-participant-b" participantRole "strategy-b"
  , incidence "claim-target" targetRole "strategy-target"
  ]

completeModelOccurrences :: [ModelOccurrence]
completeModelOccurrences =
  carrierModels
    (visionCarrierNames
       ++ concatMap strategyCarrierNames ["a", "b", "target"]
       ++ ["collective-claim"])
    ++ segmentModels
         (visionContextualizationNames
            ++ concatMap strategyContextualizationNames ["a", "b", "target"]
            ++ concatMap
                 (\label ->
                    visionOrientationName label
                      : strategyInternalRelationNames label)
                 ["a", "b", "target"]
            ++ [ "macro-a-contributes-target"
               , "macro-b-contributes-target"
               , "primitive-a-contributes-target-action"
               , "primitive-b-contributes-target-key-result"
               , "claim-participant-a"
               , "claim-participant-b"
               , "claim-target"
               ])

visionCarriers :: [CarrierProjection]
visionCarriers =
  [ contextCarrier "vision" "Vision" Asserted
  , primitiveCarrier "vision-objective" "Objective" Asserted
  ]

visionContextualizations :: [ContextualizationProjection]
visionContextualizations =
  [ownership "owns-vision-objective" "vision" "vision-objective" Asserted]

visionCarrierNames :: [String]
visionCarrierNames = ["vision", "vision-objective"]

visionContextualizationNames :: [String]
visionContextualizationNames = ["owns-vision-objective"]

strategyCarriers :: String -> [CarrierProjection]
strategyCarriers label = strategyCarriersWithCommitment label Asserted

strategyCarriersWithCommitment :: String -> Commitment -> [CarrierProjection]
strategyCarriersWithCommitment label strategyCommitment =
  strategyCarrier label strategyCommitment
    : [ primitiveCarrier (strategyMember label member) o2iType Asserted
      | (member, o2iType) <-
          [ ("driver", "Driver")
          , ("objective", "Objective")
          , ("principle", "Principle")
          , ("action", "Action")
          , ("key-result", "KeyResult")
          ]
      ]

strategyContextualizations :: String -> [ContextualizationProjection]
strategyContextualizations label =
  [ ownership
    ("owns-" ++ strategyMember label member)
    ("strategy-" ++ label)
    (strategyMember label member)
    Asserted
  | member <- ["driver", "objective", "principle", "action", "key-result"]
  ]

strategyInternalRelations :: String -> [RelationProjection]
strategyInternalRelations label =
  [ relation
      (strategyRelation label "driver-grounds-objective")
      (strategyMember label "driver")
      "grounds"
      (strategyMember label "objective")
      Asserted
  , relation
      (strategyRelation label "principle-guides-action")
      (strategyMember label "principle")
      "guides"
      (strategyMember label "action")
      Asserted
  , relation
      (strategyRelation label "action-contributes-key-result")
      (strategyMember label "action")
      "contributes-to"
      (strategyMember label "key-result")
      Asserted
  , relation
      (strategyRelation label "key-result-substantiates-objective")
      (strategyMember label "key-result")
      "substantiates"
      (strategyMember label "objective")
      Asserted
  ]

visionOrientation :: String -> RelationProjection
visionOrientation label =
  relation
    (visionOrientationName label)
    "vision-objective"
    "orients"
    (strategyMember label "objective")
    Asserted

strategyCarrierNames :: String -> [String]
strategyCarrierNames label =
  ("strategy-" ++ label)
    : map
        (strategyMember label)
        ["driver", "objective", "principle", "action", "key-result"]

strategyContextualizationNames :: String -> [String]
strategyContextualizationNames label =
  map
    (("owns-" ++) . strategyMember label)
    ["driver", "objective", "principle", "action", "key-result"]

strategyInternalRelationNames :: String -> [String]
strategyInternalRelationNames label =
  map
    (strategyRelation label)
    [ "driver-grounds-objective"
    , "principle-guides-action"
    , "action-contributes-key-result"
    , "key-result-substantiates-objective"
    ]

strategyRelation :: String -> String -> String
strategyRelation label suffix = "strategy-" ++ label ++ "-" ++ suffix

visionOrientationName :: String -> String
visionOrientationName label = "vision-orients-strategy-" ++ label

strategyMember :: String -> String -> String
strategyMember label member = "strategy-" ++ label ++ "-" ++ member

strategyInputs :: [(Natural, ByteString)]
strategyInputs =
  [(0, strategyInput "a"), (1, strategyInput "b"), (2, strategyInput "target")]

completeInputs :: [(Natural, ByteString)]
completeInputs = strategyInputs ++ [(3, collectiveInput)]

strategyInput :: String -> ByteString
strategyInput label =
  strategyInputWithDiagnosis label ("strategy-" ++ label ++ "-driver")

strategyInputWithDiagnosis :: String -> String -> ByteString
strategyInputWithDiagnosis label diagnosis =
  strategyInputWithMembers
    label
    diagnosis
    (strategyMember label "objective")
    (strategyMember label "principle")
    (strategyMember label "action")
    (strategyMember label "key-result")

strategyMismatchInput :: ByteString
strategyMismatchInput =
  strategyInputWithMembers
    "a"
    (strategyMember "b" "driver")
    (strategyMember "b" "objective")
    (strategyMember "b" "principle")
    (strategyMember "b" "action")
    (strategyMember "b" "key-result")

strategyInputWithMembers ::
     String -> String -> String -> String -> String -> String -> ByteString
strategyInputWithMembers label diagnosis intent guidingPolicy action keyResult =
  ByteString.pack
    (concat
       [ "{\"type\":\"StrategyFormulationInput\""
       , ",\"strategy\":\"strategy-"
       , label
       , "\""
       , ",\"scope\":[\"scope\"]"
       , ",\"anchoring\":{"
       , "\"period\":\"period\""
       , ",\"responsibilityScope\":\"responsibility scope\""
       , ",\"decisionLevel\":\"decision level\""
       , ",\"responsibilities\":[\"responsibility\"]"
       , ",\"decisionPaths\":[\"decision path\"]"
       , ",\"implementationLogic\":\"implementation logic\"}"
       , ",\"derivedGuardrails\":[\"guardrail\"]"
       , ",\"diagnosis\":\""
       , diagnosis
       , "\""
       , ",\"intent\":\""
       , intent
       , "\""
       , ",\"guidingPolicy\":\""
       , guidingPolicy
       , "\""
       , ",\"positioning\":[\"positioning\"]"
       , ",\"tradeOffs\":[\"trade-off\"]"
       , ",\"actions\":[\""
       , action
       , "\"]"
       , ",\"keyResults\":[\""
       , keyResult
       , "\"]"
       , ",\"fitRationale\":[\"fit rationale\"]}"
       ])

collectiveInput :: ByteString
collectiveInput =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-b\"]"
       , ",\"target\":\"strategy-target\""
       , ",\"targetGuidingPolicy\":\"strategy-target-principle\""
       , ",\"targetTradeOffs\":[\"trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-b\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-b\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

collectiveInputAllFitDefects :: ByteString
collectiveInputAllFitDefects =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-target\"]"
       , ",\"target\":\"strategy-b\""
       , ",\"targetGuidingPolicy\":\"strategy-a-principle\""
       , ",\"targetTradeOffs\":[\"different-trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-target\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-target\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

collectiveInputWithUnresolvedPolicy :: ByteString
collectiveInputWithUnresolvedPolicy =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-b\"]"
       , ",\"target\":\"strategy-target\""
       , ",\"targetGuidingPolicy\":\"unknown-policy\""
       , ",\"targetTradeOffs\":[\"different-trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-b\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-b\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

collectiveInputWithUnresolvedTarget :: ByteString
collectiveInputWithUnresolvedTarget =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-b\"]"
       , ",\"target\":\"unknown-target\""
       , ",\"targetGuidingPolicy\":\"strategy-a-principle\""
       , ",\"targetTradeOffs\":[\"different-trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-b\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-b\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

collectiveInputWithUnresolvedParticipants :: ByteString
collectiveInputWithUnresolvedParticipants =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"unknown-participant\",\"strategy-b\"]"
       , ",\"target\":\"strategy-target\""
       , ",\"targetGuidingPolicy\":\"strategy-target-principle\""
       , ",\"targetTradeOffs\":[\"trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-a\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

workProjection :: Int -> Int -> Int -> StructureProjection
workProjection participantCount participantWidth targetWidth =
  structureProjection
    (visionCarriers ++ concatMap workStrategyCarriers strategies)
    (visionContextualizations
       ++ concatMap workStrategyContextualizations strategies)
    (concatMap workStrategyRelations strategies
       ++ map workMacroRelation participants
       ++ workContributionRelations participants participantWidth targetWidth)
    [collectiveProposition]
    (workCollectiveIncidences participants)
  where
    participants = workParticipantLabels participantCount
    strategies =
      map (\label -> (label, participantWidth)) participants
        ++ [("target", targetWidth)]

workModelOccurrences :: Int -> Int -> Int -> [ModelOccurrence]
workModelOccurrences participantCount participantWidth targetWidth =
  carrierModels
    (visionCarrierNames
       ++ concatMap workStrategyCarrierNames strategies
       ++ ["collective-claim"])
    ++ segmentModels
         (visionContextualizationNames
            ++ concatMap workStrategyContextualizationNames strategies
            ++ concatMap workStrategyRelationNames strategies
            ++ map workMacroRelationName participants
            ++ workContributionRelationNames
                 participants
                 participantWidth
                 targetWidth
            ++ map workIncidenceName participants
            ++ ["claim-target"])
  where
    participants = workParticipantLabels participantCount
    strategies =
      map (\label -> (label, participantWidth)) participants
        ++ [("target", targetWidth)]

workInputs :: Int -> Int -> Int -> [(Natural, ByteString)]
workInputs participantCount participantWidth targetWidth =
  zipWith
    (\ordinal (label, width) ->
       (fromIntegral ordinal, workStrategyInput label width))
    [0 :: Int ..]
    strategies
    ++ [(fromIntegral (length strategies), workCollectiveInput participants)]
  where
    participants = workParticipantLabels participantCount
    strategies =
      map (\label -> (label, participantWidth)) participants
        ++ [("target", targetWidth)]

workParticipantLabels :: Int -> [String]
workParticipantLabels count = ["p" ++ show index | index <- [1 .. count]]

workStrategyCarriers :: (String, Int) -> [CarrierProjection]
workStrategyCarriers (label, width) =
  strategyCarrier label Asserted
    : primitiveCarrier (strategyMember label "driver") "Driver" Asserted
    : primitiveCarrier (strategyMember label "objective") "Objective" Asserted
    : primitiveCarrier (strategyMember label "principle") "Principle" Asserted
    : [ primitiveCarrier (workAction label index) "Action" Asserted
      | index <- [1 .. width]
      ]
    ++ [ primitiveCarrier (workKeyResult label index) "KeyResult" Asserted
       | index <- [1 .. width]
       ]

workStrategyContextualizations :: (String, Int) -> [ContextualizationProjection]
workStrategyContextualizations (label, width) =
  [ ownership ("owns-" ++ member) ("strategy-" ++ label) member Asserted
  | member <- workStrategyMemberNames label width
  ]

workStrategyRelations :: (String, Int) -> [RelationProjection]
workStrategyRelations (label, width) =
  visionOrientation label
    : relation
        (strategyRelation label "driver-grounds-objective")
        (strategyMember label "driver")
        "grounds"
        (strategyMember label "objective")
        Asserted
    : concat
        [ [ relation
              (workRelationName label "principle-guides-action" index)
              (strategyMember label "principle")
              "guides"
              (workAction label index)
              Asserted
          , relation
              (workRelationName label "action-contributes-key-result" index)
              (workAction label index)
              "contributes-to"
              (workKeyResult label index)
              Asserted
          , relation
              (workRelationName label "key-result-substantiates-objective" index)
              (workKeyResult label index)
              "substantiates"
              (strategyMember label "objective")
              Asserted
          ]
        | index <- [1 .. width]
        ]

workMacroRelation :: String -> RelationProjection
workMacroRelation label =
  relation
    (workMacroRelationName label)
    ("strategy-" ++ label)
    "contributes-to"
    "strategy-target"
    Asserted

workContributionRelations :: [String] -> Int -> Int -> [RelationProjection]
workContributionRelations participants participantWidth targetWidth =
  concat
    [ [ relation
          (workContributionName label "action" index)
          (workAction label index)
          "contributes-to"
          (workAction "target" (targetIndex index))
          Asserted
      , relation
          (workContributionName label "key-result" index)
          (workKeyResult label index)
          "contributes-to"
          (workKeyResult "target" (targetIndex index))
          Asserted
      ]
    | label <- participants
    , index <- [1 .. participantWidth]
    ]
  where
    targetIndex index = ((index - 1) `mod` targetWidth) + 1

workCollectiveIncidences :: [String] -> [StructuredIncidenceProjection]
workCollectiveIncidences participants =
  [ incidence
    (workIncidenceName participant)
    participantRole
    ("strategy-" ++ participant)
  | participant <- participants
  ]
    ++ [incidence "claim-target" targetRole "strategy-target"]

workStrategyCarrierNames :: (String, Int) -> [String]
workStrategyCarrierNames (label, width) =
  ("strategy-" ++ label) : workStrategyMemberNames label width

workStrategyMemberNames :: String -> Int -> [String]
workStrategyMemberNames label width =
  map (strategyMember label) ["driver", "objective", "principle"]
    ++ [workAction label index | index <- [1 .. width]]
    ++ [workKeyResult label index | index <- [1 .. width]]

workStrategyContextualizationNames :: (String, Int) -> [String]
workStrategyContextualizationNames =
  map ("owns-" ++) . uncurry workStrategyMemberNames

workStrategyRelationNames :: (String, Int) -> [String]
workStrategyRelationNames (label, width) =
  visionOrientationName label
    : strategyRelation label "driver-grounds-objective"
    : concat
        [ [ workRelationName label "principle-guides-action" index
          , workRelationName label "action-contributes-key-result" index
          , workRelationName label "key-result-substantiates-objective" index
          ]
        | index <- [1 .. width]
        ]

workContributionRelationNames :: [String] -> Int -> Int -> [String]
workContributionRelationNames participants participantWidth _ =
  [ workContributionName label member index
  | label <- participants
  , index <- [1 .. participantWidth]
  , member <- ["action", "key-result"]
  ]

workAction :: String -> Int -> String
workAction label index = strategyMember label ("action-" ++ show index)

workKeyResult :: String -> Int -> String
workKeyResult label index = strategyMember label ("key-result-" ++ show index)

workRelationName :: String -> String -> Int -> String
workRelationName label relationName index =
  strategyRelation label (relationName ++ "-" ++ show index)

workMacroRelationName :: String -> String
workMacroRelationName label = "macro-" ++ label ++ "-contributes-target"

workContributionName :: String -> String -> Int -> String
workContributionName label member index =
  "primitive-"
    ++ label
    ++ "-"
    ++ member
    ++ "-"
    ++ show index
    ++ "-contributes-target"

workIncidenceName :: String -> String
workIncidenceName participant = "claim-participant-" ++ participant

workStrategyInput :: String -> Int -> ByteString
workStrategyInput label width =
  ByteString.pack
    (concat
       [ "{\"type\":\"StrategyFormulationInput\""
       , ",\"strategy\":\"strategy-"
       , label
       , "\""
       , ",\"scope\":[\"scope\"]"
       , ",\"anchoring\":{"
       , "\"period\":\"period\""
       , ",\"responsibilityScope\":\"responsibility scope\""
       , ",\"decisionLevel\":\"decision level\""
       , ",\"responsibilities\":[\"responsibility\"]"
       , ",\"decisionPaths\":[\"decision path\"]"
       , ",\"implementationLogic\":\"implementation logic\"}"
       , ",\"derivedGuardrails\":[\"guardrail\"]"
       , ",\"diagnosis\":\""
       , strategyMember label "driver"
       , "\""
       , ",\"intent\":\""
       , strategyMember label "objective"
       , "\""
       , ",\"guidingPolicy\":\""
       , strategyMember label "principle"
       , "\""
       , ",\"positioning\":[\"positioning\"]"
       , ",\"tradeOffs\":[\"trade-off\"]"
       , ",\"actions\":"
       , jsonStringArray [workAction label index | index <- [1 .. width]]
       , ",\"keyResults\":"
       , jsonStringArray [workKeyResult label index | index <- [1 .. width]]
       , ",\"fitRationale\":[\"fit rationale\"]}"
       ])

workCollectiveInput :: [String] -> ByteString
workCollectiveInput participants =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":"
       , jsonStringArray (map ("strategy-" ++) participants)
       , ",\"target\":\"strategy-target\""
       , ",\"targetGuidingPolicy\":\"strategy-target-principle\""
       , ",\"targetTradeOffs\":[\"trade-off\"]"
       , ",\"pairwiseCoherence\":["
       , intercalate "," (map pairwiseJson (stringPairs participants))
       , "]"
       , ",\"participantCompatibility\":["
       , intercalate "," (map compatibilityJson participants)
       , "]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

pairwiseJson :: (String, String) -> String
pairwiseJson (left, right) =
  concat
    [ "{\"participantA\":\"strategy-"
    , left
    , "\",\"participantB\":\"strategy-"
    , right
    , "\",\"rationale\":\"coherent\"}"
    ]

compatibilityJson :: String -> String
compatibilityJson participant =
  concat
    [ "{\"participant\":\"strategy-"
    , participant
    , "\",\"guidingPolicyRationale\":\"compatible\""
    , ",\"tradeOffRationale\":\"compatible\"}"
    ]

stringPairs :: [String] -> [(String, String)]
stringPairs [] = []
stringPairs (value:rest) =
  map (\other -> (value, other)) rest ++ stringPairs rest

jsonStringArray :: [String] -> String
jsonStringArray values =
  "[" ++ intercalate "," (map (\value -> "\"" ++ value ++ "\"") values) ++ "]"

contextCarrier :: String -> Text -> Commitment -> CarrierProjection
contextCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    contextCategory
    (exactType o2iType)
    commitment

strategyCarrier :: String -> Commitment -> CarrierProjection
strategyCarrier label = contextCarrier ("strategy-" ++ label) "Strategy"

primitiveCarrier :: String -> Text -> Commitment -> CarrierProjection
primitiveCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    primitiveCategory
    (exactType o2iType)
    commitment

anchorCarrier :: String -> Text -> Commitment -> CarrierProjection
anchorCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    situationAnchorCategory
    (exactType o2iType)
    commitment

ownership ::
     String -> String -> String -> Commitment -> ContextualizationProjection
ownership identifier owner member commitment =
  contextualizationProjection
    (occurrenceId identifier)
    (occurrenceId owner)
    (occurrenceId member)
    commitment

relation ::
     String -> String -> Text -> String -> Commitment -> RelationProjection
relation identifier source token target commitment =
  relationProjection
    (occurrenceId identifier)
    (occurrenceId source)
    (exactRelationToken token)
    (occurrenceId target)
    commitment

incidence ::
     String
  -> CoreStructuredPropositionRoleId
  -> String
  -> StructuredIncidenceProjection
incidence identifier role endpoint =
  structuredIncidenceProjection
    (occurrenceId identifier)
    (occurrenceId "collective-claim")
    role
    (occurrenceId endpoint)

carrierModels :: [String] -> [ModelOccurrence]
carrierModels =
  map
    (\identifier ->
       modelOccurrence (occurrenceId identifier) (modelId identifier))

segmentModels :: [String] -> [ModelOccurrence]
segmentModels =
  map
    (\identifier ->
       modelOccurrence
         (occurrenceId identifier)
         (modelId ("segment-" ++ identifier)))

contextCategory, primitiveCategory, situationAnchorCategory ::
     CoreCarrierCategory
contextCategory = exactCategory "Context"

primitiveCategory = exactCategory "Primitive"

situationAnchorCategory = exactCategory "SituationAnchor"

endpointContextStrategy, endpointStrategyAction :: CoreQualifiedEndpointId
endpointContextStrategy = exactEndpoint "context.strategy"

endpointStrategyAction = exactEndpoint "primitive.strategy.action"

tokenContributesTo :: CoreRelationToken
tokenContributesTo = exactRelationToken "contributes-to"

collectiveFamily :: CoreStructuredPropositionFamilyId
collectiveFamily = exactFamily "collective-strategy-realization"

participantRole, targetRole :: CoreStructuredPropositionRoleId
participantRole = exactRole "collective-strategy-realization.role.participant"

targetRole = exactRole "collective-strategy-realization.role.target"

completenessOpen, completenessClosed :: CoreParticipantCompleteness
completenessOpen = exactCompleteness "open"

completenessClosed = exactCompleteness "closed"

modelId :: String -> ModelIdentity
modelId identifier =
  case modelIdentity (Text.pack identifier) of
    Left problem ->
      failureValue ("invalid model identity in test: " ++ show problem)
    Right value -> value

occurrenceId :: String -> OccurrenceIdentity
occurrenceId identifier =
  case occurrenceIdentity (Text.pack identifier) of
    Left problem ->
      failureValue ("invalid occurrence identity in test: " ++ show problem)
    Right value -> value

exactCategory :: Text -> CoreCarrierCategory
exactCategory token =
  exactValue "carrier category" token (lookupCoreCarrierCategory token)

exactType :: Text -> CoreO2IType
exactType token = exactValue "O2I type" token (lookupCoreO2IType token)

exactRelationToken :: Text -> CoreRelationToken
exactRelationToken token =
  exactValue "relation token" token (lookupCoreRelationToken token)

exactEndpoint :: Text -> CoreQualifiedEndpointId
exactEndpoint token =
  exactValue "qualified endpoint" token (lookupCoreQualifiedEndpointId token)

exactFamily :: Text -> CoreStructuredPropositionFamilyId
exactFamily token =
  exactValue
    "structured proposition family"
    token
    (lookupCoreStructuredPropositionFamilyId token)

exactRole :: Text -> CoreStructuredPropositionRoleId
exactRole token =
  exactValue
    "structured proposition role"
    token
    (lookupCoreStructuredPropositionRoleId token)

exactCompleteness :: Text -> CoreParticipantCompleteness
exactCompleteness token =
  exactValue
    "participant completeness"
    token
    (lookupCoreParticipantCompletenessToken token)

exactValue :: String -> Text -> Maybe value -> value
exactValue label token value =
  case value of
    Nothing ->
      failureValue
        ("compiled contract lacks " ++ label ++ ": " ++ Text.unpack token)
    Just result -> result

failureValue :: String -> value
failureValue = error

assertCarrierWitnessesAsserted ::
     SemanticIndex scope -> [OccurrenceIdentity] -> Assertion
assertCarrierWitnessesAsserted semanticIndex witnesses =
  [ occurrence
  | occurrence <- witnesses
  , Just carrier <- [carrierAt semanticIndex occurrence]
  , carrierCommitment carrier /= Asserted
  ]
    @?= []
