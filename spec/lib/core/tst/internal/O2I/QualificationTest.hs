{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import qualified Data.ByteString.Char8 as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment(..))
import qualified O2I.Core.Graph.Observation.Internal as ObservationInternal
import O2I.Core.Identity
import qualified O2I.Qualification as Public
import qualified O2I.Qualification.Eval as QualificationEval
import qualified O2I.Qualification.Index as QualificationIndex
import O2I.Qualification.Internal
import O2I.Semantics
  ( SemanticAssessment
  , SemanticDisposition(..)
  , assessSemantics
  , semanticDisposition
  )
import O2I.Semantics.Input
import O2I.Structure
import qualified O2I.Structure.Internal as StructureInternal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), assertBool, assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core Qualification"
    [ testCase "maps the complete closed rule vocabulary" closedRuleVocabulary
    , testCase
        "executes the positive and negative behavior of every rule"
        ruleBehaviorClosure
    , testCase "rejects a different exact producing graph" exactGraphBinding
    , testCase "discovers fixed subjects with Core eligibility" subjects
    , testCase "admits one complete formal proposal" admissibleProposal
    , testCase
        "canonicalizes proposal content and ignores input permutation"
        canonicalProposal
    , testCase
        "canonicalizes emitted proposal order after routing"
        canonicalProposalOrder
    , testCase
        "reports selector unavailability before pair outcomes"
        selectorUnavailable
    , testCase
        "uses the exact selector resolution precedence"
        selectorPrecedence
    , testCase
        "keeps eligibility unavailability separate from ineligibility"
        eligibilityUnavailable
    , testCase "uses ineligibility before proposal presence" pairPrecedence
    , testCase "reports Strategy ineligibility" strategyIneligibility
    , testCase "emits one missing-proposal pair outcome" missingProposal
    , testCase "assesses only route roles for an unrouted proposal" unroutedOnly
    , testCase
        "reports a missing Strategy route role"
        unroutedStrategyCardinality
    , testCase
        "canonicalizes malformed role-reference evidence"
        malformedReferencePermutation
    , testCase "reports every invalid route-role target" routeRoleTargets
    , testCase "excludes an out-of-request Need route silently" outOfRequestNeed
    , testCase
        "excludes an out-of-request Strategy route silently"
        outOfRequestStrategy
    , testCase
        "accumulates independent in-scope proposal defects"
        invalidProposal
    , testCase
        "retains every malformed source occurrence canonically"
        malformedSourceProvenance
    , testCase "reports every invalid proposal-role target" proposalRoleTargets
    , testCase
        "detects proposal identity in every effect-graph family"
        effectGraphMembershipFamilies
    , testCase "rejects existing qualification relations" existingRelations
    , testCase
        "rejects unlisted and contextually incoherent endpoints"
        endpointCoherence
    , testCase
        "routes every proposal exactly once under unrelated load"
        exactRoutingWork
    , testCase
        "keeps joint proposal and requested-domain routing linear"
        requestedMembershipWork
    , testCase "counts requested-pair work independently" requestedPairWork
    , testCase "counts actual emitted-entry comparisons" emittedOrderingWork
    , testCase "orders many sources without comparisons" sourceRadixWork
    , testCase "orders many witnesses without comparisons" witnessRadixWork
    , testCase
        "isolates emitted long-value growth from ordering work"
        emittedScalarWork
    , testCase
        "keeps fixed-result source and witness growth linear"
        sourceWitnessCouplingWork
    ]

closedRuleVocabulary :: Assertion
closedRuleVocabulary =
  map
    (coreRuleIdText . qualificationRuleId)
    ([minBound .. maxBound] :: [QualificationRule])
    @?= [ "core.qualification.pair.proposal-presence"
        , "core.qualification.proposal.effect-graph-membership"
        , "core.qualification.proposal.existing-macro-qualification"
        , "core.qualification.proposal.existing-primitive-support"
        , "core.qualification.proposal.key-result-context"
        , "core.qualification.proposal.listed-key-result"
        , "core.qualification.proposal.need-eligibility"
        , "core.qualification.proposal.objective-context"
        , "core.qualification.proposal.rationale"
        , "core.qualification.proposal.role.key-result.cardinality"
        , "core.qualification.proposal.role.key-result.target"
        , "core.qualification.proposal.role.need.cardinality"
        , "core.qualification.proposal.role.need.target"
        , "core.qualification.proposal.role.objective.cardinality"
        , "core.qualification.proposal.role.objective.target"
        , "core.qualification.proposal.role.strategy.cardinality"
        , "core.qualification.proposal.role.strategy.target"
        , "core.qualification.proposal.selected-need"
        , "core.qualification.proposal.selected-strategy"
        , "core.qualification.proposal.sources"
        , "core.qualification.proposal.strategy-eligibility"
        ]

ruleBehaviorClosure :: Assertion
ruleBehaviorClosure = do
  let cases =
        [ (PairProposalPresenceRule, missingProposal)
        , (ProposalEffectGraphMembershipRule, effectGraphMembershipFamilies)
        , (ProposalExistingMacroQualificationRule, existingRelations)
        , (ProposalExistingPrimitiveSupportRule, existingRelations)
        , (ProposalKeyResultContextRule, endpointCoherence)
        , (ProposalListedKeyResultRule, endpointCoherence)
        , (ProposalNeedEligibilityRule, pairPrecedence)
        , (ProposalObjectiveContextRule, endpointCoherence)
        , (ProposalRationaleRule, invalidProposal)
        , (ProposalKeyResultCardinalityRule, invalidProposal)
        , (ProposalKeyResultTargetRule, proposalRoleTargets)
        , (ProposalNeedCardinalityRule, unroutedOnly)
        , (ProposalNeedTargetRule, routeRoleTargets)
        , (ProposalObjectiveCardinalityRule, invalidProposal)
        , (ProposalObjectiveTargetRule, proposalRoleTargets)
        , (ProposalStrategyCardinalityRule, unroutedStrategyCardinality)
        , (ProposalStrategyTargetRule, routeRoleTargets)
        , (ProposalSelectedNeedRule, outOfRequestNeed)
        , (ProposalSelectedStrategyRule, outOfRequestStrategy)
        , (ProposalSourcesRule, malformedSourceProvenance)
        , (ProposalStrategyEligibilityRule, strategyIneligibility)
        ]
  map fst cases @?= ([minBound .. maxBound] :: [QualificationRule])
  mapM_ (\(_, negativeBranch) -> admissibleProposal >> negativeBranch) cases

exactGraphBinding :: Assertion
exactGraphBinding =
  withFixture $ \graph semantics -> do
    let differentGraph =
          graph
            { StructureInternal.storedWellFormedRelations =
                drop 1 (wellFormedRelations graph)
            }
    case Public.prepareQualificationContext differentGraph semantics of
      Left problem -> problem @?= Public.QualificationSemanticGraphMismatch
      Right _ -> assertFailure "different graph unexpectedly bound to Semantics"
    withFixtureSemantics True differentGraph $ \differentSemantics -> do
      semanticDisposition differentSemantics @?= SemanticRejected
      case Public.prepareQualificationContext graph differentSemantics of
        Left problem -> problem @?= Public.QualificationSemanticGraphMismatch
        Right _ ->
          assertFailure "rejected Semantics escaped its exact producing graph"

subjects :: Assertion
subjects =
  withFixture $ \graph semantics -> do
    let discovered = qualificationSubjectsFor graph semantics
    map
      Public.qualificationSubjectIdentity
      (Public.qualificationNeedSubjects discovered)
      @?= [modelId "ineligible-need", modelId "need"]
    map
      Public.qualificationSubjectEligibility
      (Public.qualificationNeedSubjects discovered)
      @?= [ Public.QualificationSubjectIneligible
          , Public.QualificationSubjectEligible
          ]
    map
      Public.qualificationSubjectIdentity
      (Public.qualificationStrategySubjects discovered)
      @?= [modelId "ineligible-strategy", modelId "strategy"]
    map
      Public.qualificationSubjectEligibility
      (Public.qualificationStrategySubjects discovered)
      @?= [ Public.QualificationSubjectIneligible
          , Public.QualificationSubjectEligible
          ]

admissibleProposal :: Assertion
admissibleProposal =
  withFixture $ \graph semantics -> do
    let assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [validProposal "proposal"]
    Public.qualificationSelectedNeeds assessment @?= [modelId "need"]
    Public.qualificationSelectedStrategies assessment @?= [modelId "strategy"]
    Public.qualificationUnroutedProposals assessment @?= []
    case Public.qualificationPairAssessments assessment of
      [pair] -> do
        Public.qualificationPairDisposition pair
          @?= Public.QualificationPairProposalsAssessed
        case Public.qualificationPairProposals pair of
          [result] -> do
            Public.qualificationProposalDisposition result
              @?= Public.QualificationProposalFormallyAdmissible
            case Public.admissibleQualificationProposal result of
              Nothing -> assertFailure "admissible result lost its opaque proof"
              Just proof -> do
                Public.admissibleNeedIdentity proof @?= modelId "need"
                Public.admissibleStrategyIdentity proof @?= modelId "strategy"
                Public.admissibleKeyResultIdentity proof
                  @?= modelId "strategy-key-result"
                Public.admissibleObjectiveIdentity proof
                  @?= modelId "need-objective"
                Public.admissibleRationale proof @?= "rationale"
                NonEmpty.toList (Public.admissibleSources proof)
                  @?= ["source-document"]
          other ->
            assertFailure
              ("unexpected proposal outcomes: " ++ show (length other))
      other ->
        assertFailure ("unexpected pair outcomes: " ++ show (length other))

canonicalProposal :: Assertion
canonicalProposal =
  withFixture $ \graph semantics -> do
    let sources =
          [ (occurrenceId "source-z", "  source z  ")
          , (occurrenceId "source-a", "source a")
          ]
        first =
          qualificationProposal
            "canonical"
            (Just "  rationale  ")
            sources
            validReferences
        second =
          qualificationProposal
            "canonical"
            (Just "rationale")
            (reverse sources)
            (reverse validReferences)
        assess proposal =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [proposal]
        firstAssessment = assess first
        secondAssessment = assess second
    firstAssessment @?= secondAssessment
    case Public.admissibleQualificationProposal
           (onlyProposal (onlyPair firstAssessment)) of
      Nothing -> assertFailure "canonical proposal lost its opaque proof"
      Just proof -> do
        Public.admissibleRationale proof @?= "rationale"
        NonEmpty.toList (Public.admissibleSources proof)
          @?= ["source a", "source z"]

canonicalProposalOrder :: Assertion
canonicalProposalOrder =
  withFixture $ \graph semantics -> do
    let first = validProposal "proposal-a"
        second = validProposal "proposal-b"
        assess proposals =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            proposals
    assess [second, first] @?= assess [first, second]

selectorUnavailable :: Assertion
selectorUnavailable =
  withFixture $ \graph semantics -> do
    let assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "unknown-need"]
            (strategySelectors "strategy")
            []
    Public.qualificationAssessmentDisposition assessment
      @?= Public.QualificationSubjectsUnavailable
    Public.qualificationPairAssessments assessment @?= []
    case Public.qualificationSubjectUnavailable assessment of
      [failure] -> do
        Public.qualificationUnavailableCategory failure
          @?= Public.QualificationNeedCategory
        Public.qualificationUnavailableIdentity failure
          @?= modelId "unknown-need"
        Public.qualificationUnavailableReason failure
          @?= Public.QualificationSelectorUnknown
        Public.qualificationUnavailableOccurrences failure @?= []
      failures ->
        assertFailure
          ("unexpected selector failures: " ++ show (length failures))

selectorPrecedence :: Assertion
selectorPrecedence =
  withFixture $ \graph semantics -> do
    let (assessment, work) =
          assessQualificationWithWorkInternal
            graph
            semantics
            (map
               needSelector
               ["unknown-need", "out-of-view", "ambiguous", "strategy", "need"])
            (strategySelectorList
               [ "unknown-strategy"
               , "out-of-view"
               , "ambiguous"
               , "need"
               , "strategy"
               ])
            []
        failures =
          [ ( Public.qualificationUnavailableCategory failure
            , Public.qualificationUnavailableIdentity failure
            , Public.qualificationUnavailableReason failure
            , Public.qualificationUnavailableOccurrences failure)
          | failure <- Public.qualificationSubjectUnavailable assessment
          ]
    Public.qualificationSelectedNeeds assessment @?= [modelId "need"]
    Public.qualificationSelectedStrategies assessment @?= [modelId "strategy"]
    qualificationSelectorResolutionVisits work @?= 10
    failures
      @?= [ ( Public.QualificationNeedCategory
            , modelId "ambiguous"
            , Public.QualificationSelectorAmbiguous
            , [occurrenceId "ambiguous-a", occurrenceId "ambiguous-b"])
          , ( Public.QualificationNeedCategory
            , modelId "out-of-view"
            , Public.QualificationSelectorOutOfSelectedView
            , [occurrenceId "out-of-view"])
          , ( Public.QualificationNeedCategory
            , modelId "strategy"
            , Public.QualificationSelectorWrongTypeOrFamily
            , [occurrenceId "strategy"])
          , ( Public.QualificationNeedCategory
            , modelId "unknown-need"
            , Public.QualificationSelectorUnknown
            , [])
          , ( Public.QualificationStrategyCategory
            , modelId "ambiguous"
            , Public.QualificationSelectorAmbiguous
            , [occurrenceId "ambiguous-a", occurrenceId "ambiguous-b"])
          , ( Public.QualificationStrategyCategory
            , modelId "need"
            , Public.QualificationSelectorWrongTypeOrFamily
            , [occurrenceId "need"])
          , ( Public.QualificationStrategyCategory
            , modelId "out-of-view"
            , Public.QualificationSelectorOutOfSelectedView
            , [occurrenceId "out-of-view"])
          , ( Public.QualificationStrategyCategory
            , modelId "unknown-strategy"
            , Public.QualificationSelectorUnknown
            , [])
          ]
    Public.qualificationPairAssessments assessment @?= []

eligibilityUnavailable :: Assertion
eligibilityUnavailable =
  withUnavailableFixture $ \graph semantics -> do
    let discovered = qualificationSubjectsFor graph semantics
        assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            []
    map
      Public.qualificationSubjectEligibility
      (Public.qualificationStrategySubjects discovered)
      @?= [ Public.QualificationSubjectEligibilityUnavailable
          , Public.QualificationSubjectEligibilityUnavailable
          ]
    case Public.qualificationSubjectUnavailable assessment of
      [failure] -> do
        Public.qualificationUnavailableCategory failure
          @?= Public.QualificationStrategyCategory
        Public.qualificationUnavailableReason failure
          @?= Public.QualificationEligibilityPrerequisiteUnavailable
      failures ->
        assertFailure
          ("unexpected eligibility failures: " ++ show (length failures))
    Public.qualificationPairAssessments assessment @?= []

pairPrecedence :: Assertion
pairPrecedence =
  withFixture $ \graph semantics -> do
    let pair =
          onlyPair
            (assessQualificationFor
               graph
               semantics
               [needSelector "ineligible-need"]
               (strategySelectors "strategy")
               [])
    Public.qualificationPairDisposition pair
      @?= Public.QualificationPairInvalidSelectedSubjects
    diagnosticRuleTexts (Public.qualificationPairDiagnostics pair)
      @?= ["core.qualification.proposal.need-eligibility"]
    diagnosticKinds (Public.qualificationPairDiagnostics pair)
      @?= [Public.QualificationSelectedNeedEvidence]
    let diagnostic = onlyDiagnostic (Public.qualificationPairDiagnostics pair)
    diagnosticSubjectRows diagnostic @?= [("model", "need", "ineligible-need")]
    diagnosticOccurrenceRows diagnostic
      @?= [("need", [occurrenceId "ineligible-need"])]

strategyIneligibility :: Assertion
strategyIneligibility =
  withFixture $ \graph semantics -> do
    let pair =
          onlyPair
            (assessQualificationFor
               graph
               semantics
               [needSelector "need"]
               (strategySelectors "ineligible-strategy")
               [])
    Public.qualificationPairDisposition pair
      @?= Public.QualificationPairInvalidSelectedSubjects
    diagnosticRuleTexts (Public.qualificationPairDiagnostics pair)
      @?= ["core.qualification.proposal.strategy-eligibility"]
    diagnosticKinds (Public.qualificationPairDiagnostics pair)
      @?= [Public.QualificationSelectedStrategyEvidence]
    let diagnostic = onlyDiagnostic (Public.qualificationPairDiagnostics pair)
    diagnosticSubjectRows diagnostic
      @?= [("model", "strategy", "ineligible-strategy")]
    diagnosticOccurrenceRows diagnostic
      @?= [("strategy", [occurrenceId "ineligible-strategy"])]

missingProposal :: Assertion
missingProposal =
  withFixture $ \graph semantics -> do
    let pair =
          onlyPair
            (assessQualificationFor
               graph
               semantics
               [needSelector "need"]
               (strategySelectors "strategy")
               [])
    Public.qualificationPairDisposition pair
      @?= Public.QualificationPairProposalMissing
    diagnosticRuleTexts (Public.qualificationPairDiagnostics pair)
      @?= ["core.qualification.pair.proposal-presence"]
    diagnosticKinds (Public.qualificationPairDiagnostics pair)
      @?= [Public.QualificationPairEvidence]
    let diagnostic = onlyDiagnostic (Public.qualificationPairDiagnostics pair)
    diagnosticSubjectRows diagnostic
      @?= [("model", "need", "need"), ("model", "strategy", "strategy")]
    diagnosticOccurrenceRows diagnostic @?= [("proposal", [])]

unroutedOnly :: Assertion
unroutedOnly =
  withFixture $ \graph semantics -> do
    let proposal =
          qualificationProposal
            "unrouted"
            Nothing
            []
            [ roleReference "unrouted-strategy" roleStrategy "strategy"
            , roleReference "unrouted-key-result" roleKeyResult "need"
            ]
        assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [proposal]
    case Public.qualificationUnroutedProposals assessment of
      [result] -> do
        diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
          @?= ["core.qualification.proposal.role.need.cardinality"]
        diagnosticKinds (Public.qualificationProposalDiagnostics result)
          @?= [Public.QualificationProposalRoleEvidence]
        let diagnostic =
              onlyDiagnostic (Public.qualificationProposalDiagnostics result)
        diagnosticSubjectRows diagnostic
          @?= [("model", "proposal", "unrouted"), ("role", "role", "need")]
        diagnosticOccurrenceRows diagnostic
          @?= [("proposal", [occurrenceId "unrouted"]), ("references", [])]
      other ->
        assertFailure ("unexpected unrouted results: " ++ show (length other))
    Public.qualificationPairDisposition (onlyPair assessment)
      @?= Public.QualificationPairProposalMissing

unroutedStrategyCardinality :: Assertion
unroutedStrategyCardinality =
  withFixture $ \graph semantics -> do
    let proposal =
          qualificationProposal
            "unrouted-strategy-cardinality"
            Nothing
            []
            [roleReference "routed-need" roleNeed "need"]
        assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [proposal]
    case Public.qualificationUnroutedProposals assessment of
      [result] -> do
        let diagnostic =
              onlyDiagnostic (Public.qualificationProposalDiagnostics result)
        coreRuleIdText (Public.qualificationDiagnosticRule diagnostic)
          @?= "core.qualification.proposal.role.strategy.cardinality"
        Public.qualificationDiagnosticKind diagnostic
          @?= Public.QualificationProposalRoleEvidence
        diagnosticSubjectRows diagnostic
          @?= [ ("model", "proposal", "unrouted-strategy-cardinality")
              , ("role", "role", "strategy")
              ]
        diagnosticOccurrenceRows diagnostic
          @?= [ ("proposal", [occurrenceId "unrouted-strategy-cardinality"])
              , ("references", [])
              ]
      other ->
        assertFailure ("unexpected unrouted results: " ++ show (length other))
    Public.qualificationPairDisposition (onlyPair assessment)
      @?= Public.QualificationPairProposalMissing

malformedReferencePermutation :: Assertion
malformedReferencePermutation =
  withFixture $ \graph semantics -> do
    let references =
          [ roleReference "need-z" roleNeed "need"
          , roleReference "need-a" roleNeed "need"
          , roleReference "strategy" roleStrategy "strategy"
          ]
        assess orderedReferences =
          Public.qualificationUnroutedProposals
            (assessQualificationFor
               graph
               semantics
               [needSelector "need"]
               (strategySelectors "strategy")
               [ qualificationProposal
                   "reference-permutation"
                   Nothing
                   []
                   orderedReferences
               ])
        result = assess references
    result @?= assess (reverse references)
    case result of
      [proposal] -> do
        let diagnostic =
              onlyDiagnostic (Public.qualificationProposalDiagnostics proposal)
        coreRuleIdText (Public.qualificationDiagnosticRule diagnostic)
          @?= "core.qualification.proposal.role.need.cardinality"
        diagnosticOccurrenceRows diagnostic
          @?= [ ("proposal", [occurrenceId "reference-permutation"])
              , ("references", [occurrenceId "need-a", occurrenceId "need-z"])
              ]
      other ->
        assertFailure ("unexpected unrouted results: " ++ show (length other))

routeRoleTargets :: Assertion
routeRoleTargets =
  withFixture $ \graph semantics -> do
    let proposal =
          qualificationProposal
            "invalid-route-targets"
            (Just "rationale")
            [(occurrenceId "invalid-route-targets-source", "source")]
            [ roleReference "wrong-need" roleNeed "strategy"
            , roleReference "wrong-strategy" roleStrategy "need"
            ]
        assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [proposal]
    case Public.qualificationUnroutedProposals assessment of
      [result] -> do
        diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
          @?= [ "core.qualification.proposal.role.need.target"
              , "core.qualification.proposal.role.strategy.target"
              ]
        diagnosticKinds (Public.qualificationProposalDiagnostics result)
          @?= replicate 2 Public.QualificationProposalRoleTargetEvidence
        map
          diagnosticSubjectRows
          (Public.qualificationProposalDiagnostics result)
          @?= [ [ ("model", "proposal", "invalid-route-targets")
                , ("role", "role", "need")
                , ("occurrence", "target", "strategy")
                ]
              , [ ("model", "proposal", "invalid-route-targets")
                , ("role", "role", "strategy")
                , ("occurrence", "target", "need")
                ]
              ]
        map
          diagnosticOccurrenceRows
          (Public.qualificationProposalDiagnostics result)
          @?= [ [ ("proposal", [occurrenceId "invalid-route-targets"])
                , ("reference", [occurrenceId "wrong-need"])
                , ("target", [occurrenceId "strategy"])
                ]
              , [ ("proposal", [occurrenceId "invalid-route-targets"])
                , ("reference", [occurrenceId "wrong-strategy"])
                , ("target", [occurrenceId "need"])
                ]
              ]
      other ->
        assertFailure ("unexpected unrouted results: " ++ show (length other))

outOfRequestNeed :: Assertion
outOfRequestNeed =
  withFixture $ \graph semantics -> do
    let assessment =
          assessQualificationFor
            graph
            semantics
            []
            (strategySelectors "strategy")
            [qualificationProposal "outside" Nothing [] validReferences]
    Public.qualificationUnroutedProposals assessment @?= []
    Public.qualificationPairAssessments assessment @?= []

outOfRequestStrategy :: Assertion
outOfRequestStrategy =
  withFixture $ \graph semantics -> do
    let references =
          [ roleReference "proposal-need" roleNeed "need"
          , roleReference "proposal-strategy" roleStrategy "ineligible-strategy"
          ]
        assessment =
          assessQualificationFor
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            [qualificationProposal "outside-strategy" Nothing [] references]
    Public.qualificationUnroutedProposals assessment @?= []
    Public.qualificationPairDisposition (onlyPair assessment)
      @?= Public.QualificationPairProposalMissing

invalidProposal :: Assertion
invalidProposal =
  withFixture $ \graph semantics -> do
    let proposal =
          qualificationProposal
            "invalid"
            Nothing
            []
            [ roleReference "invalid-need" roleNeed "need"
            , roleReference "invalid-strategy" roleStrategy "strategy"
            ]
        result =
          onlyProposal
            (onlyPair
               (assessQualificationFor
                  graph
                  semantics
                  [needSelector "need"]
                  (strategySelectors "strategy")
                  [proposal]))
    Public.qualificationProposalDisposition result
      @?= Public.QualificationProposalFormallyInvalid
    diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
      @?= [ "core.qualification.proposal.rationale"
          , "core.qualification.proposal.role.key-result.cardinality"
          , "core.qualification.proposal.role.objective.cardinality"
          , "core.qualification.proposal.sources"
          ]
    diagnosticKinds (Public.qualificationProposalDiagnostics result)
      @?= [ Public.QualificationProposalEvidence
          , Public.QualificationProposalRoleEvidence
          , Public.QualificationProposalRoleEvidence
          , Public.QualificationProposalEvidence
          ]
    map diagnosticSubjectRows (Public.qualificationProposalDiagnostics result)
      @?= [ [("model", "proposal", "invalid")]
          , [("model", "proposal", "invalid"), ("role", "role", "key-result")]
          , [("model", "proposal", "invalid"), ("role", "role", "objective")]
          , [("model", "proposal", "invalid")]
          ]
    map
      diagnosticOccurrenceRows
      (Public.qualificationProposalDiagnostics result)
      @?= [ [("proposal", [occurrenceId "invalid"])]
          , [("proposal", [occurrenceId "invalid"]), ("references", [])]
          , [("proposal", [occurrenceId "invalid"]), ("references", [])]
          , [("proposal", [occurrenceId "invalid"]), ("sources", [])]
          ]

malformedSourceProvenance :: Assertion
malformedSourceProvenance =
  withFixture $ \graph semantics -> do
    let sources =
          [ (occurrenceId "valid-source", "source")
          , (occurrenceId "invalid-source-z", " ")
          , (occurrenceId "invalid-source-a", "")
          ]
        assess orderedSources =
          onlyProposal
            (onlyPair
               (assessQualificationFor
                  graph
                  semantics
                  [needSelector "need"]
                  (strategySelectors "strategy")
                  [ qualificationProposal
                      "malformed-sources"
                      (Just "rationale")
                      orderedSources
                      validReferences
                  ]))
        result = assess sources
    result @?= assess (reverse sources)
    case Public.qualificationProposalDiagnostics result of
      [diagnostic] -> do
        Public.qualificationDiagnosticKind diagnostic
          @?= Public.QualificationProposalEvidence
        diagnosticSubjectRows diagnostic
          @?= [("model", "proposal", "malformed-sources")]
        diagnosticOccurrenceRows diagnostic
          @?= [ ("proposal", [occurrenceId "malformed-sources"])
              , ( "sources"
                , [ occurrenceId "invalid-source-a"
                  , occurrenceId "invalid-source-z"
                  ])
              ]
      diagnostics ->
        assertFailure
          ("unexpected source diagnostics: " ++ show (length diagnostics))

proposalRoleTargets :: Assertion
proposalRoleTargets =
  withFixture $ \graph semantics -> do
    let proposal =
          qualificationProposal
            "invalid-proposal-targets"
            (Just "rationale")
            [(occurrenceId "invalid-proposal-targets-source", "source")]
            [ roleReference "valid-need" roleNeed "need"
            , roleReference "valid-strategy" roleStrategy "strategy"
            , roleReference "wrong-key-result" roleKeyResult "need-objective"
            , roleReference
                "wrong-objective"
                roleObjective
                "strategy-key-result"
            ]
        result =
          onlyProposal
            (onlyPair
               (assessQualificationFor
                  graph
                  semantics
                  [needSelector "need"]
                  (strategySelectors "strategy")
                  [proposal]))
    diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
      @?= [ "core.qualification.proposal.role.key-result.target"
          , "core.qualification.proposal.role.objective.target"
          ]
    diagnosticKinds (Public.qualificationProposalDiagnostics result)
      @?= replicate 2 Public.QualificationProposalRoleTargetEvidence
    map diagnosticSubjectRows (Public.qualificationProposalDiagnostics result)
      @?= [ [ ("model", "proposal", "invalid-proposal-targets")
            , ("role", "role", "key-result")
            , ("occurrence", "target", "need-objective")
            ]
          , [ ("model", "proposal", "invalid-proposal-targets")
            , ("role", "role", "objective")
            , ("occurrence", "target", "strategy-key-result")
            ]
          ]

effectGraphMembershipFamilies :: Assertion
effectGraphMembershipFamilies =
  withFixture $ \graph _ -> do
    let proposition =
          StructureInternal.StructuredPropositionObservation
            (occurrenceId "effect-proposition")
            (modelId "effect-structured-proposition")
            collectiveFamily
            completenessOpen
            Candidate
            [ StructureInternal.StructuredIncidenceObservation
                (occurrenceId "effect-incidence")
                participantRole
                (occurrenceId "strategy")
            ]
        effectGraph =
          graph
            { StructureInternal.storedWellFormedStructuredPropositions =
                [proposition]
            }
        cases =
          [ ("segment-owns-need-driver", "owns-need-driver")
          , ("segment-situation-surfaces-need", "situation-surfaces-need")
          , ("effect-structured-proposition", "effect-proposition")
          , ("effect-structured-incidence", "effect-incidence")
          ]
    withFixtureSemantics True effectGraph $ \semantics ->
      mapM_ (assertEffectMembership effectGraph semantics) cases

assertEffectMembership ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> (String, String)
  -> Assertion
assertEffectMembership graph semantics (identifier, expectedOccurrence) = do
  let proposal = validProposal identifier
      result =
        onlyProposal
          (onlyPair
             (assessQualificationFor
                graph
                semantics
                [needSelector "need"]
                (strategySelectors "strategy")
                [proposal]))
  case Public.qualificationProposalDiagnostics result of
    [diagnostic] -> do
      coreRuleIdText (Public.qualificationDiagnosticRule diagnostic)
        @?= "core.qualification.proposal.effect-graph-membership"
      Public.qualificationDiagnosticKind diagnostic
        @?= Public.QualificationProposalEvidence
      diagnosticSubjectRows diagnostic
        @?= [("model", "proposal", Text.pack identifier)]
      diagnosticOccurrenceRows diagnostic
        @?= [ ("proposal", [occurrenceId identifier])
            , ("effect-graph", [occurrenceId expectedOccurrence])
            ]
    diagnostics ->
      assertFailure
        ("unexpected effect membership diagnostics: "
           ++ show (length diagnostics))

existingRelations :: Assertion
existingRelations =
  withFixture $ \graph _ -> do
    let scoped = ObservationInternal.ScopedGraphOccurrence . occurrenceId
        macro =
          ObservationInternal.RelationObservation
            (scoped "existing-macro")
            (scoped "strategy")
            QualificationIndex.tokenQualifies
            (scoped "need")
            Asserted
        primitive =
          ObservationInternal.RelationObservation
            (scoped "existing-primitive")
            (scoped "strategy-key-result")
            QualificationIndex.tokenTranslatesInto
            (scoped "need-objective")
            Candidate
        effectGraph =
          graph
            { StructureInternal.storedWellFormedRelations =
                macro : primitive : wellFormedRelations graph
            }
    withFixtureSemantics True effectGraph $ \semantics -> do
      let result =
            onlyProposal
              (onlyPair
                 (assessQualificationFor
                    effectGraph
                    semantics
                    [needSelector "need"]
                    (strategySelectors "strategy")
                    [validProposal "new-proposal"]))
      diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
        @?= [ "core.qualification.proposal.existing-macro-qualification"
            , "core.qualification.proposal.existing-primitive-support"
            ]
      diagnosticKinds (Public.qualificationProposalDiagnostics result)
        @?= [ Public.QualificationProposalRelationEvidence
            , Public.QualificationProposalRelationEvidence
            ]
      map diagnosticSubjectRows (Public.qualificationProposalDiagnostics result)
        @?= [ [ ("model", "proposal", "new-proposal")
              , ("text", "semantic-relation", "strategy-qualifies-need")
              ]
            , [ ("model", "proposal", "new-proposal")
              , ( "text"
                , "semantic-relation"
                , "strategy-key-result-translates-into-need-objective")
              ]
            ]
      map
        diagnosticOccurrenceRows
        (Public.qualificationProposalDiagnostics result)
        @?= [ [ ("proposal", [occurrenceId "new-proposal"])
              , ("relations", [occurrenceId "existing-macro"])
              ]
            , [ ("proposal", [occurrenceId "new-proposal"])
              , ("relations", [occurrenceId "existing-primitive"])
              ]
            ]

endpointCoherence :: Assertion
endpointCoherence =
  withFixture $ \graph _ -> do
    let scoped = ObservationInternal.ScopedGraphOccurrence . occurrenceId
        keyResult =
          ObservationInternal.CarrierObservation
            (scoped "unlisted-key-result")
            (modelId "unlisted-key-result")
            QualificationIndex.endpointStrategyKeyResult
            Asserted
        objective =
          ObservationInternal.CarrierObservation
            (scoped "wrong-objective")
            (modelId "wrong-objective")
            QualificationIndex.endpointNeedObjective
            Asserted
        keyResultContext =
          ObservationInternal.ContextualizationObservation
            (scoped "owns-unlisted-key-result")
            (scoped "ineligible-strategy")
            (scoped "unlisted-key-result")
            Asserted
        objectiveContext =
          ObservationInternal.ContextualizationObservation
            (scoped "owns-wrong-objective")
            (scoped "ineligible-need")
            (scoped "wrong-objective")
            Asserted
        effectGraph =
          graph
            { StructureInternal.storedWellFormedCarriers =
                keyResult : objective : wellFormedCarriers graph
            , StructureInternal.storedWellFormedContextualizations =
                keyResultContext
                  : objectiveContext
                  : wellFormedContextualizations graph
            }
        references =
          [ roleReference "coherent-need" roleNeed "need"
          , roleReference "coherent-strategy" roleStrategy "strategy"
          , roleReference
              "incoherent-key-result"
              roleKeyResult
              "unlisted-key-result"
          , roleReference "incoherent-objective" roleObjective "wrong-objective"
          ]
    withFixtureSemantics True effectGraph $ \semantics -> do
      let result =
            onlyProposal
              (onlyPair
                 (assessQualificationFor
                    effectGraph
                    semantics
                    [needSelector "need"]
                    (strategySelectors "strategy")
                    [ qualificationProposal
                        "endpoint-coherence"
                        (Just "rationale")
                        [(occurrenceId "endpoint-coherence-source", "source")]
                        references
                    ]))
      diagnosticRuleTexts (Public.qualificationProposalDiagnostics result)
        @?= [ "core.qualification.proposal.key-result-context"
            , "core.qualification.proposal.listed-key-result"
            , "core.qualification.proposal.objective-context"
            ]
      diagnosticKinds (Public.qualificationProposalDiagnostics result)
        @?= replicate 3 Public.QualificationProposalRoleTargetEvidence
      map diagnosticSubjectRows (Public.qualificationProposalDiagnostics result)
        @?= [ [ ("model", "proposal", "endpoint-coherence")
              , ("role", "role", "key-result")
              , ("occurrence", "target", "unlisted-key-result")
              ]
            , [ ("model", "proposal", "endpoint-coherence")
              , ("role", "role", "key-result")
              , ("occurrence", "target", "unlisted-key-result")
              ]
            , [ ("model", "proposal", "endpoint-coherence")
              , ("role", "role", "objective")
              , ("occurrence", "target", "wrong-objective")
              ]
            ]
      map
        diagnosticOccurrenceRows
        (Public.qualificationProposalDiagnostics result)
        @?= [ [ ("proposal", [occurrenceId "endpoint-coherence"])
              , ("reference", [occurrenceId "incoherent-key-result"])
              , ("target", [occurrenceId "unlisted-key-result"])
              , ("contextualization", [occurrenceId "owns-unlisted-key-result"])
              ]
            , [ ("proposal", [occurrenceId "endpoint-coherence"])
              , ("reference", [occurrenceId "incoherent-key-result"])
              , ("target", [occurrenceId "unlisted-key-result"])
              ]
            , [ ("proposal", [occurrenceId "endpoint-coherence"])
              , ("reference", [occurrenceId "incoherent-objective"])
              , ("target", [occurrenceId "wrong-objective"])
              , ("contextualization", [occurrenceId "owns-wrong-objective"])
              ]
            ]

exactRoutingWork :: Assertion
exactRoutingWork =
  withFixture $ \graph semantics -> do
    let outside =
          [ qualificationProposal
            ("outside-" ++ show number)
            Nothing
            []
            validReferences
          | number <- [1 .. 128 :: Int]
          ]
        (_, baselineWork) =
          assessQualificationWithWorkInternal
            graph
            semantics
            []
            (strategySelectors "strategy")
            []
        (_, work) =
          assessQualificationWithWorkInternal
            graph
            semantics
            []
            (strategySelectors "strategy")
            outside
    qualificationProposalVisits work @?= 128
    qualificationRequestedPairVisits work @?= 0
    qualificationRequestedMembershipVisits work @?= 2 * 128
    qualificationCarrierAddressVisits work @?= 2 * 128
    assertBool
      "routing recorded no actual carrier-address scalar visits"
      (qualificationCarrierAddressScalarVisits work > 0)
    qualificationOrderingComparisons work @?= 0
    qualificationEmittedStructuralSize work
      @?= qualificationEmittedStructuralSize baselineWork
    qualificationEmittedScalarSize work
      @?= qualificationEmittedScalarSize baselineWork
    assertBool
      "routing work grew beyond the proposal-owned role references"
      (qualificationAddressedSupportVisits work <= 4 * 128)

requestedMembershipWork :: Assertion
requestedMembershipWork = do
  let proposalRanks =
        [(2048 + number, 4096 + number) | number <- [1 .. 4096 :: Int]]
      membershipSmall =
        QualificationEval.qualificationRequestedMembershipWorkInternal
          [0]
          [0]
          proposalRanks
      membershipLarge =
        QualificationEval.qualificationRequestedMembershipWorkInternal
          [0 .. 1023]
          [0 .. 1023]
          proposalRanks
      baseCarriers =
        [occurrenceId ("carrier-" ++ show number) | number <- [1 .. 128 :: Int]]
      proposalTargets = concat (replicate 32 baseCarriers)
      unrelatedCarriers =
        [ occurrenceId ("unrelated-" ++ show number)
        | number <- [1 .. 8192 :: Int]
        ]
      addressSmall =
        QualificationEval.qualificationCarrierAddressWorkInternal
          baseCarriers
          proposalTargets
      addressLarge =
        QualificationEval.qualificationCarrierAddressWorkInternal
          (baseCarriers ++ unrelatedCarriers)
          proposalTargets
      expectedMembershipVisits = 2 * length proposalRanks
      expectedAddressScalarVisits =
        sum (map (Text.length . occurrenceIdentityText) proposalTargets)
  qualificationRequestedMembershipVisits membershipSmall
    @?= expectedMembershipVisits
  qualificationRequestedMembershipVisits membershipLarge
    @?= expectedMembershipVisits
  qualificationOrderingComparisons membershipSmall @?= 0
  qualificationOrderingComparisons membershipLarge @?= 0
  qualificationRequestedPairVisits membershipSmall @?= 0
  qualificationRequestedPairVisits membershipLarge @?= 0
  qualificationCarrierAddressVisits addressSmall @?= length proposalTargets
  qualificationCarrierAddressVisits addressLarge @?= length proposalTargets
  qualificationCarrierAddressScalarVisits addressSmall
    @?= expectedAddressScalarVisits
  qualificationCarrierAddressScalarVisits addressLarge
    @?= expectedAddressScalarVisits

requestedPairWork :: Assertion
requestedPairWork =
  withFixture $ \graph semantics -> do
    let (_, work) =
          assessQualificationWithWorkInternal
            graph
            semantics
            [needSelector "need", needSelector "ineligible-need"]
            (strategySelectors "strategy")
            []
    qualificationRequestedPairVisits work @?= 2
    qualificationProposalVisits work @?= 0

emittedOrderingWork :: Assertion
emittedOrderingWork =
  withFixture $ \graph semantics -> do
    let proposals =
          map
            validProposal
            ["proposal-d", "proposal-c", "proposal-b", "proposal-a"]
        (_, work) =
          assessQualificationWithWorkInternal
            graph
            semantics
            [needSelector "need"]
            (strategySelectors "strategy")
            proposals
    qualificationRequestedPairVisits work @?= 1
    qualificationProposalVisits work @?= 4
    assertBool
      "emitted-entry comparison sort recorded no actual comparison"
      (qualificationOrderingComparisons work > 0)

sourceRadixWork :: Assertion
sourceRadixWork = do
  let values =
        Text.replicate 4096 "x"
          : [Text.pack ("source-" ++ show number) | number <- [1 .. 256 :: Int]]
      work = QualificationEval.qualificationSourceOrderingWorkInternal values
  qualificationAddressedSupportVisits work @?= length values
  qualificationOrderingScalarVisits work @?= sum (map Text.length values)
  qualificationOrderingComparisons work @?= 0

witnessRadixWork :: Assertion
witnessRadixWork = do
  let witnesses =
        occurrenceId (replicate 4096 'w')
          : [ occurrenceId ("witness-" ++ show number)
            | number <- [1 .. 256 :: Int]
            ]
      work =
        QualificationEval.qualificationWitnessOrderingWorkInternal witnesses
  qualificationAddressedSupportVisits work @?= length witnesses
  qualificationOrderingScalarVisits work
    @?= sum (map (Text.length . occurrenceIdentityText) witnesses)
  qualificationOrderingComparisons work @?= 0

emittedScalarWork :: Assertion
emittedScalarWork =
  withFixture $ \graph semantics -> do
    let longRationale = Text.replicate 8192 "z"
        measure rationale =
          snd
            (assessQualificationWithWorkInternal
               graph
               semantics
               [needSelector "need"]
               (strategySelectors "strategy")
               [ qualificationProposal
                   "long-value"
                   (Just rationale)
                   [(occurrenceId "long-value-source", "source")]
                   validReferences
               ])
        short = measure "r"
        long = measure longRationale
    qualificationRequestedPairVisits long
      @?= qualificationRequestedPairVisits short
    qualificationProposalVisits long @?= qualificationProposalVisits short
    qualificationAddressedSupportVisits long
      @?= qualificationAddressedSupportVisits short
    qualificationOrderingScalarVisits long
      @?= qualificationOrderingScalarVisits short
    qualificationOrderingComparisons long
      @?= qualificationOrderingComparisons short
    qualificationEmittedStructuralSize long
      @?= qualificationEmittedStructuralSize short
    qualificationEmittedScalarSize long
      - qualificationEmittedScalarSize short @?= Text.length longRationale
      - 1

sourceWitnessCouplingWork :: Assertion
sourceWitnessCouplingWork =
  withFixture $ \graph semantics -> do
    let sources count =
          [ (occurrenceId ("many-source-" ++ show number), "source")
          | number <- [1 .. count :: Int]
          ]
        proposal count =
          qualificationProposal
            "many-sources"
            (Just "rationale")
            (sources count)
            validReferences
        measure count =
          snd
            (assessQualificationWithWorkInternal
               graph
               semantics
               [needSelector "need"]
               (strategySelectors "strategy")
               [proposal count])
        one = measure 1
        many = measure 256
        additionalOccurrences =
          [ occurrenceId ("many-source-" ++ show number)
          | number <- [2 .. 256 :: Int]
          ]
        expectedScalarGrowth =
          255 * Text.length "source"
            + sum
                (map
                   (Text.length . occurrenceIdentityText)
                   additionalOccurrences)
    qualificationRequestedPairVisits many @?= 1
    qualificationProposalVisits many @?= 1
    qualificationSupportAddressVisits one @?= 5
    qualificationSupportAddressVisits many @?= 5
    qualificationSupportAddressScalarVisits many
      @?= qualificationSupportAddressScalarVisits one
    assertBool
      "proposal support recorded no actual address-scalar visits"
      (qualificationSupportAddressScalarVisits many > 0)
    qualificationOrderingComparisons many
      @?= qualificationOrderingComparisons one
    qualificationAddressedSupportVisits many
      - qualificationAddressedSupportVisits one @?= 2 * 255
    qualificationOrderingScalarVisits many
      - qualificationOrderingScalarVisits one @?= expectedScalarGrowth
    qualificationEmittedScalarSize many
      - qualificationEmittedScalarSize one @?= expectedScalarGrowth

qualificationContextFor ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> Public.QualificationContext scope
qualificationContextFor graph semantics =
  case Public.prepareQualificationContext graph semantics of
    Left problem ->
      error ("qualification context fixture failed: " ++ show problem)
    Right context -> context

qualificationSubjectsFor ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> Public.QualificationSubjects scope
qualificationSubjectsFor graph semantics =
  Public.qualificationSubjects (qualificationContextFor graph semantics)

assessQualificationFor ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> [Public.QualificationNeedSelector]
  -> NonEmpty.NonEmpty Public.QualificationStrategySelector
  -> [Public.QualificationProposalInput]
  -> Public.QualificationAssessment scope
assessQualificationFor graph semantics =
  Public.assessQualification (qualificationContextFor graph semantics)

assessQualificationWithWorkInternal ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> [Public.QualificationNeedSelector]
  -> NonEmpty.NonEmpty Public.QualificationStrategySelector
  -> [Public.QualificationProposalInput]
  -> (Public.QualificationAssessment scope, QualificationWork)
assessQualificationWithWorkInternal graph semantics =
  QualificationEval.assessQualificationWithWorkInternal
    (qualificationContextFor graph semantics)

needSelector :: String -> Public.QualificationNeedSelector
needSelector = Public.qualificationNeedSelector . modelId

strategySelectors ::
     String -> NonEmpty.NonEmpty Public.QualificationStrategySelector
strategySelectors identifier =
  Public.qualificationStrategySelector (modelId identifier) NonEmpty.:| []

strategySelectorList ::
     [String] -> NonEmpty.NonEmpty Public.QualificationStrategySelector
strategySelectorList identifiers =
  case map (Public.qualificationStrategySelector . modelId) identifiers of
    first:remaining -> first NonEmpty.:| remaining
    [] -> error "strategy selector fixture requires a nonempty list"

onlyPair ::
     Public.QualificationAssessment scope
  -> Public.QualificationPairAssessment scope
onlyPair assessment =
  case Public.qualificationPairAssessments assessment of
    [pair] -> pair
    pairs -> error ("expected one pair, got " ++ show (length pairs))

onlyProposal ::
     Public.QualificationPairAssessment scope
  -> Public.QualificationProposalAssessment scope
onlyProposal pair =
  case Public.qualificationPairProposals pair of
    [proposal] -> proposal
    proposals ->
      error ("expected one proposal, got " ++ show (length proposals))

diagnosticRuleTexts :: [Public.QualificationDiagnosticEvidence scope] -> [Text]
diagnosticRuleTexts = map (coreRuleIdText . Public.qualificationDiagnosticRule)

diagnosticKinds ::
     [Public.QualificationDiagnosticEvidence scope]
  -> [Public.QualificationEvidenceKind]
diagnosticKinds = map Public.qualificationDiagnosticKind

diagnosticSubjectRows ::
     Public.QualificationDiagnosticEvidence scope -> [(Text, Text, Text)]
diagnosticSubjectRows diagnostic =
  map
    (Public.foldQualificationDiagnosticSubject
       (\label identifier -> ("model", label, modelIdentityText identifier))
       (\label identifier ->
          ("occurrence", label, occurrenceIdentityText identifier))
       (\label role -> ("role", label, Public.qualificationRoleText role))
       (\label value -> ("text", label, value)))
    (NonEmpty.toList (Public.qualificationDiagnosticSubjects diagnostic))

diagnosticOccurrenceRows ::
     Public.QualificationDiagnosticEvidence scope
  -> [(Text, [OccurrenceIdentity])]
diagnosticOccurrenceRows diagnostic =
  [ ( Public.qualificationOccurrenceGroupRole group
    , Public.qualificationOccurrenceGroupOccurrences group)
  | group <-
      NonEmpty.toList
        (Public.qualificationDiagnosticOccurrenceGroups diagnostic)
  ]

onlyDiagnostic ::
     [Public.QualificationDiagnosticEvidence scope]
  -> Public.QualificationDiagnosticEvidence scope
onlyDiagnostic diagnostics =
  case diagnostics of
    [diagnostic] -> diagnostic
    _ -> error ("expected one diagnostic, got " ++ show (length diagnostics))

validProposal :: String -> Public.QualificationProposalInput
validProposal identifier =
  qualificationProposal
    identifier
    (Just "rationale")
    [(occurrenceId (identifier ++ "-source"), "source-document")]
    validReferences

qualificationProposal ::
     String
  -> Maybe Text
  -> [(OccurrenceIdentity, Text)]
  -> [(OccurrenceIdentity, CoreQualificationProposalRoleId, OccurrenceIdentity)]
  -> Public.QualificationProposalInput
qualificationProposal identifier rationale sources references =
  Public.qualificationProposalInput
    (occurrenceId identifier)
    (modelId identifier)
    rationale
    sources
    references

validReferences ::
     [(OccurrenceIdentity, CoreQualificationProposalRoleId, OccurrenceIdentity)]
validReferences =
  [ roleReference "proposal-need" roleNeed "need"
  , roleReference "proposal-strategy" roleStrategy "strategy"
  , roleReference "proposal-key-result" roleKeyResult "strategy-key-result"
  , roleReference "proposal-objective" roleObjective "need-objective"
  ]

roleReference ::
     String
  -> CoreQualificationProposalRoleId
  -> String
  -> (OccurrenceIdentity, CoreQualificationProposalRoleId, OccurrenceIdentity)
roleReference identifier role target =
  (occurrenceId identifier, role, occurrenceId target)

withFixture ::
     (forall scope. WellFormedGraph scope -> SemanticAssessment scope -> Assertion)
  -> Assertion
withFixture = withFixtureStrategy True

withUnavailableFixture ::
     (forall scope. WellFormedGraph scope -> SemanticAssessment scope -> Assertion)
  -> Assertion
withUnavailableFixture = withFixtureStrategy False

withFixtureStrategy ::
     Bool
  -> (forall scope. WellFormedGraph scope -> SemanticAssessment scope -> Assertion)
  -> Assertion
withFixtureStrategy includeStrategy inspect =
  case buildModelIdentityIndex
         (selectedView : modelOccurrences ++ selectorOnlyOccurrences) of
    Left problem -> assertFailure ("identity fixture failed: " ++ show problem)
    Right identityIndex ->
      case withSelectedViewScope
             identityIndex
             selectedView
             (map modelOccurrenceIdentity modelOccurrences)
             buildScoped of
        Left problem -> assertFailure ("scope fixture failed: " ++ show problem)
        Right assertion -> assertion
  where
    buildScoped scope =
      case assessStructure scope fixtureProjection of
        Left problem ->
          assertFailure ("Structure input fixture failed: " ++ show problem)
        Right structure ->
          foldStructureAssessment
            (\problem ->
               assertFailure
                 ("Structure fixture rejected: "
                    ++ show (NonEmpty.length problem)))
            bindSemantics
            structure
    bindSemantics graph =
      withFixtureSemantics includeStrategy graph (inspect graph)

withFixtureSemantics ::
     Bool
  -> WellFormedGraph scope
  -> (SemanticAssessment scope -> Assertion)
  -> Assertion
withFixtureSemantics includeStrategy graph inspect =
  case fixtureSupplementalSet includeStrategy of
    Left problem -> assertFailure ("strategy input fixture failed: " ++ problem)
    Right inputSet ->
      foldSupplementalBinding
        (\bound evidence ->
           case evidence of
             [] -> inspect (assessSemantics graph bound)
             _ ->
               assertFailure
                 ("strategy binding fixture failed: " ++ show (length evidence)))
        (bindSupplementalInputs graph inputSet)

fixtureSupplementalSet :: Bool -> Either String (SupplementalInputSet ())
fixtureSupplementalSet includeStrategy
  | includeStrategy =
    case ( decodeSupplementalInput () (supplementalInputOrdinal 0) strategyInput
         , decodeSupplementalInput
             ()
             (supplementalInputOrdinal 1)
             ineligibleStrategyInput) of
      (Left problem, _) -> Left (show problem)
      (_, Left problem) -> Left (show problem)
      (Right strategy, Right ineligibleStrategy) ->
        case assessSupplementalInputSet [strategy, ineligibleStrategy] of
          Left problem -> Left (show problem)
          Right inputSet -> Right inputSet
  | otherwise =
    case assessSupplementalInputSet [] of
      Left problem -> Left (show problem)
      Right inputSet -> Right inputSet

fixtureProjection :: StructureProjection
fixtureProjection =
  structureProjection carriers contextualizations relations [] []
  where
    carriers =
      [ contextCarrier "ineligible-need" "Need"
      , contextCarrier "need" "Need"
      , contextCarrier "situation" "Situation"
      , anchorCarrier "anchor" "BusinessCapability"
      , primitiveCarrier "need-driver" "Driver"
      , primitiveCarrier "need-objective" "Objective"
      , contextCarrier "vision" "Vision"
      , primitiveCarrier "vision-objective" "Objective"
      , contextCarrier "ineligible-strategy" "Strategy"
      , contextCarrier "strategy" "Strategy"
      , primitiveCarrier "strategy-driver" "Driver"
      , primitiveCarrier "strategy-objective" "Objective"
      , primitiveCarrier "strategy-principle" "Principle"
      , primitiveCarrier "strategy-action" "Action"
      , primitiveCarrier "strategy-key-result" "KeyResult"
      ]
    contextualizations =
      [ ownership "owns-need-driver" "need" "need-driver"
      , ownership "owns-need-objective" "need" "need-objective"
      , ownership "owns-vision-objective" "vision" "vision-objective"
      , ownership "owns-strategy-driver" "strategy" "strategy-driver"
      , ownership "owns-strategy-objective" "strategy" "strategy-objective"
      , ownership "owns-strategy-principle" "strategy" "strategy-principle"
      , ownership "owns-strategy-action" "strategy" "strategy-action"
      , ownership "owns-strategy-key-result" "strategy" "strategy-key-result"
      ]
    relations =
      [ relation "situation-surfaces-need" "situation" "surfaces" "need"
      , relation
          "situation-constituted-by-anchor"
          "situation"
          "is-constituted-by"
          "anchor"
      , relation "anchor-anchors-driver" "anchor" "anchors" "need-driver"
      , relation
          "need-driver-grounds-objective"
          "need-driver"
          "grounds"
          "need-objective"
      , relation
          "vision-orients-strategy-objective"
          "vision-objective"
          "orients"
          "strategy-objective"
      , relation
          "strategy-driver-grounds-objective"
          "strategy-driver"
          "grounds"
          "strategy-objective"
      , relation
          "strategy-principle-guides-action"
          "strategy-principle"
          "guides"
          "strategy-action"
      , relation
          "strategy-action-contributes-key-result"
          "strategy-action"
          "contributes-to"
          "strategy-key-result"
      , relation
          "strategy-key-result-substantiates-objective"
          "strategy-key-result"
          "substantiates"
          "strategy-objective"
      ]

carrierNames :: [String]
carrierNames =
  [ "ineligible-need"
  , "need"
  , "situation"
  , "anchor"
  , "need-driver"
  , "need-objective"
  , "vision"
  , "vision-objective"
  , "ineligible-strategy"
  , "strategy"
  , "strategy-driver"
  , "strategy-objective"
  , "strategy-principle"
  , "strategy-action"
  , "strategy-key-result"
  ]

segmentNames :: [String]
segmentNames =
  [ "owns-need-driver"
  , "owns-need-objective"
  , "owns-vision-objective"
  , "owns-strategy-driver"
  , "owns-strategy-objective"
  , "owns-strategy-principle"
  , "owns-strategy-action"
  , "owns-strategy-key-result"
  , "situation-surfaces-need"
  , "situation-constituted-by-anchor"
  , "anchor-anchors-driver"
  , "need-driver-grounds-objective"
  , "vision-orients-strategy-objective"
  , "strategy-driver-grounds-objective"
  , "strategy-principle-guides-action"
  , "strategy-action-contributes-key-result"
  , "strategy-key-result-substantiates-objective"
  ]

modelOccurrences :: [ModelOccurrence]
modelOccurrences =
  [modelOccurrence (occurrenceId name) (modelId name) | name <- carrierNames]
    ++ [ modelOccurrence (occurrenceId name) (modelId ("segment-" ++ name))
       | name <- segmentNames
       ]
    ++ [ modelOccurrence
           (occurrenceId "effect-proposition")
           (modelId "effect-structured-proposition")
       , modelOccurrence
           (occurrenceId "effect-incidence")
           (modelId "effect-structured-incidence")
       , modelOccurrence
           (occurrenceId "existing-macro")
           (modelId "segment-existing-macro")
       , modelOccurrence
           (occurrenceId "existing-primitive")
           (modelId "segment-existing-primitive")
       , modelOccurrence
           (occurrenceId "unlisted-key-result")
           (modelId "unlisted-key-result")
       , modelOccurrence
           (occurrenceId "owns-unlisted-key-result")
           (modelId "segment-owns-unlisted-key-result")
       , modelOccurrence
           (occurrenceId "wrong-objective")
           (modelId "wrong-objective")
       , modelOccurrence
           (occurrenceId "owns-wrong-objective")
           (modelId "segment-owns-wrong-objective")
       ]

selectorOnlyOccurrences :: [ModelOccurrence]
selectorOnlyOccurrences =
  [ modelOccurrence (occurrenceId "out-of-view") (modelId "out-of-view")
  , modelOccurrence (occurrenceId "ambiguous-a") (modelId "ambiguous")
  , modelOccurrence (occurrenceId "ambiguous-b") (modelId "ambiguous")
  ]

selectedView :: ModelOccurrence
selectedView =
  modelOccurrence (occurrenceId "selected-view") (modelId "selected-view")

contextCarrier :: String -> Text -> CarrierProjection
contextCarrier identifier o2iType =
  carrierProjection
    (occurrenceId identifier)
    (exactCategory "Context")
    (exactType o2iType)
    Asserted

primitiveCarrier :: String -> Text -> CarrierProjection
primitiveCarrier identifier o2iType =
  carrierProjection
    (occurrenceId identifier)
    (exactCategory "Primitive")
    (exactType o2iType)
    Asserted

anchorCarrier :: String -> Text -> CarrierProjection
anchorCarrier identifier o2iType =
  carrierProjection
    (occurrenceId identifier)
    (exactCategory "SituationAnchor")
    (exactType o2iType)
    Asserted

ownership :: String -> String -> String -> ContextualizationProjection
ownership identifier owner member =
  contextualizationProjection
    (occurrenceId identifier)
    (occurrenceId owner)
    (occurrenceId member)
    Asserted

relation :: String -> String -> Text -> String -> RelationProjection
relation identifier source token target =
  relationProjection
    (occurrenceId identifier)
    (occurrenceId source)
    (exactRelation token)
    (occurrenceId target)
    Asserted

strategyInput :: ByteString.ByteString
strategyInput = strategyInputFor "strategy"

ineligibleStrategyInput :: ByteString.ByteString
ineligibleStrategyInput = strategyInputFor "ineligible-strategy"

strategyInputFor :: String -> ByteString.ByteString
strategyInputFor strategy =
  ByteString.pack
    (concat
       [ "{\"type\":\"StrategyFormulationInput\""
       , ",\"strategy\":\""
       , strategy
       , "\""
       , ",\"scope\":[\"scope\"]"
       , ",\"anchoring\":{\"period\":\"period\""
       , ",\"responsibilityScope\":\"responsibility scope\""
       , ",\"decisionLevel\":\"decision level\""
       , ",\"responsibilities\":[\"responsibility\"]"
       , ",\"decisionPaths\":[\"decision path\"]"
       , ",\"implementationLogic\":\"implementation logic\"}"
       , ",\"derivedGuardrails\":[\"guardrail\"]"
       , ",\"diagnosis\":\"strategy-driver\""
       , ",\"intent\":\"strategy-objective\""
       , ",\"guidingPolicy\":\"strategy-principle\""
       , ",\"positioning\":[\"positioning\"]"
       , ",\"tradeOffs\":[\"trade-off\"]"
       , ",\"actions\":[\"strategy-action\"]"
       , ",\"keyResults\":[\"strategy-key-result\"]"
       , ",\"fitRationale\":[\"fit rationale\"]}"
       ])

roleNeed, roleStrategy, roleKeyResult, roleObjective ::
     CoreQualificationProposalRoleId
roleNeed = exactQualificationRole "need-qualification-proposal.role.need"

roleStrategy =
  exactQualificationRole "need-qualification-proposal.role.strategy"

roleKeyResult =
  exactQualificationRole "need-qualification-proposal.role.key-result"

roleObjective =
  exactQualificationRole "need-qualification-proposal.role.objective"

collectiveFamily :: CoreStructuredPropositionFamilyId
collectiveFamily =
  exact
    "structured proposition family"
    "collective-strategy-realization"
    (lookupCoreStructuredPropositionFamilyId "collective-strategy-realization")

participantRole :: CoreStructuredPropositionRoleId
participantRole =
  exact
    "structured proposition role"
    "collective-strategy-realization.role.participant"
    (lookupCoreStructuredPropositionRoleId
       "collective-strategy-realization.role.participant")

completenessOpen :: CoreParticipantCompleteness
completenessOpen =
  exact
    "participant completeness"
    "open"
    (lookupCoreParticipantCompletenessToken "open")

modelId :: String -> ModelIdentity
modelId value = either (error . show) id (modelIdentity (Text.pack value))

occurrenceId :: String -> OccurrenceIdentity
occurrenceId value =
  either (error . show) id (occurrenceIdentity (Text.pack value))

exactCategory :: Text -> CoreCarrierCategory
exactCategory value = exact "category" value (lookupCoreCarrierCategory value)

exactType :: Text -> CoreO2IType
exactType value = exact "type" value (lookupCoreO2IType value)

exactRelation :: Text -> CoreRelationToken
exactRelation value = exact "relation" value (lookupCoreRelationToken value)

exactQualificationRole :: Text -> CoreQualificationProposalRoleId
exactQualificationRole value =
  exact "qualification role" value (lookupCoreQualificationProposalRoleId value)

exact :: String -> Text -> Maybe value -> value
exact label value result =
  case result of
    Just found -> found
    Nothing -> error ("missing " ++ label ++ ": " ++ Text.unpack value)
