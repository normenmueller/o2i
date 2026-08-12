{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Family-owned semantics of collective Strategy realization.
module O2I.Semantics.Family.CollectiveStrategyRealization
  ( CollectiveWork(..)
  , assessCollectiveStrategyRealizations
  , assessCollectiveStrategyRealizationsWithWork
  ) where

import Data.List (sort, sortOn)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import qualified Data.Text as Text
import O2I.Core.Contract (CoreStructuredPropositionRoleId)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Graph.Observation
  ( Commitment(..)
  , carrierCommitment
  , carrierModelIdentity
  , relationOccurrenceIdentity
  , relationTargetOccurrence
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types
  ( CollectiveFitInput(..)
  , PairwiseCoherence(..)
  , ParticipantCompatibility(..)
  , StrategyFormulationInput(..)
  )
import O2I.Semantics.Index
import O2I.Semantics.Internal
import O2I.Semantics.Vocabulary
import O2I.Structure
  ( StructuredIncidenceObservation
  , StructuredPropositionObservation
  , structuredIncidenceEndpoint
  , structuredIncidenceOccurrence
  , structuredIncidenceRole
  , structuredPropositionCommitment
  , structuredPropositionCompleteness
  , structuredPropositionFamily
  , structuredPropositionIncidences
  , structuredPropositionModelIdentity
  , structuredPropositionOccurrence
  )

-- | Assess the one compiled structured-proposition family.
assessCollectiveStrategyRealizations ::
     SemanticIndex scope
  -> [StrategyFormulationAssessment scope]
  -> [CollectiveStrategyRealizationAssessment scope]
assessCollectiveStrategyRealizations semanticIndex strategyAssessments =
  map
    fst
    (assessCollectiveStrategyRealizationsWithWork
       semanticIndex
       strategyAssessments)

-- | Assess collective realizations with a private, exact work account.
assessCollectiveStrategyRealizationsWithWork ::
     SemanticIndex scope
  -> [StrategyFormulationAssessment scope]
  -> [(CollectiveStrategyRealizationAssessment scope, CollectiveWork)]
assessCollectiveStrategyRealizationsWithWork semanticIndex strategyAssessments =
  map assessCollective collectives
  where
    collectives =
      filter
        ((== familyCollectiveStrategyRealization) . structuredPropositionFamily)
        (indexedStructuredPropositions semanticIndex)
    strategyResults = strategyAssessmentIndex strategyAssessments
    assessCollective = assessOneCollective semanticIndex strategyResults

assessOneCollective ::
     SemanticIndex scope
  -> Map ModelIdentity (StrategyFormulationAssessment scope)
  -> StructuredPropositionObservation scope
  -> (CollectiveStrategyRealizationAssessment scope, CollectiveWork)
assessOneCollective semanticIndex strategyResults proposition =
  (assessment, work)
  where
    assessment =
      case structuredPropositionCommitment proposition of
        Candidate ->
          CollectiveStrategyRealizationCandidate claim claimOccurrence
        Asserted ->
          case NonEmpty.nonEmpty (sortSemanticDefects defects) of
            Just failures ->
              CollectiveStrategyRealizationInvalid claim components failures
            Nothing
              | componentsUnavailable components ->
                CollectiveStrategyRealizationUnavailable claim components
              | otherwise ->
                case collectiveFitResult components of
                  CollectiveFitSatisfied input fitWitnesses ->
                    CollectiveStrategyRealizationValid
                      ValidatedCollectiveStrategyRealization
                        { validatedCollectiveClaim = claim
                        , validatedCollectiveInput = input
                        , validatedCollectiveWitnesses =
                            Set.toAscList
                              (Set.fromList
                                 (claimOccurrence
                                    : incidenceOccurrences
                                    ++ prerequisiteWitnesses
                                    ++ fitWitnesses
                                    ++ componentWitnesses components))
                        }
                      components
                  _ -> CollectiveStrategyRealizationUnavailable claim components
    claim = structuredPropositionModelIdentity proposition
    claimOccurrence = structuredPropositionOccurrence proposition
    incidences = structuredPropositionIncidences proposition
    incidenceOccurrences = map structuredIncidenceOccurrence incidences
    participantOccurrences =
      incidenceEndpointsFor roleCollectiveParticipant incidences
    targetOccurrences = incidenceEndpointsFor roleCollectiveTarget incidences
    participantBindings =
      sortOn fst (identitiesAt semanticIndex participantOccurrences)
    participantOccurrenceIndex = Map.fromList participantBindings
    participants = map fst participantBindings
    target = onlyIdentityAt semanticIndex targetOccurrences
    expectedParticipantPairs = allPairs participants
    participantResults = map (strategyResult strategyResults) participants
    targetResult = strategyResult strategyResults <$> target
    completeness = assessCompleteness proposition
    fit =
      assessFit
        semanticIndex
        strategyResults
        claim
        claimOccurrence
        participants
        target
        expectedParticipantPairs
    preparedSupport =
      prepareCollectiveSupport semanticIndex strategyResults participants target
    coverage =
      assessCoverage strategyResults claim participants target preparedSupport
    macroSupport =
      case targetOccurrences of
        [targetOccurrence] ->
          zipWith
            (assessMacroSupport semanticIndex claim targetOccurrence)
            participants
            (map snd participantBindings)
        _ -> []
    primitiveSupport =
      map
        (assessPrimitiveSupport strategyResults claim target preparedSupport)
        participants
    components =
      CollectiveStrategyRealizationComponents
        { collectiveCompletenessResult = completeness
        , collectiveFitResult = fit
        , collectiveCoverageResult = coverage
        , collectiveMacroSupportResults = macroSupport
        , collectivePrimitiveSupportResults = primitiveSupport
        }
    defects =
      componentDefects
        claimOccurrence
        participantOccurrenceIndex
        targetOccurrences
        components
    prerequisiteWitnesses =
      concatMap
        strategyWitnesses
        (participantResults ++ maybeToList targetResult)
    work =
      (preparedCollectiveWork preparedSupport)
        {collectivePairwiseComparisons = length expectedParticipantPairs}

assessCompleteness ::
     StructuredPropositionObservation scope -> CollectiveCompletenessAssessment
assessCompleteness proposition
  | structuredPropositionCompleteness proposition == completenessClosed =
    CollectiveCompletenessSatisfied
  | otherwise =
    CollectiveCompletenessViolated
      (mkCollectiveCompletenessDefect
         (structuredPropositionModelIdentity proposition)
         (structuredPropositionOccurrence proposition))

assessFit ::
     SemanticIndex scope
  -> Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> OccurrenceIdentity
  -> [ModelIdentity]
  -> Maybe ModelIdentity
  -> [(ModelIdentity, ModelIdentity)]
  -> CollectiveFitAssessment
assessFit semanticIndex strategyResults claim claimOccurrence participants target expectedPairs =
  case collectiveFitInputFor semanticIndex claim of
    Nothing ->
      CollectiveFitUnavailable (CollectiveFitInputMissing NonEmpty.:| []) []
    Just input ->
      case NonEmpty.nonEmpty prerequisiteReasons of
        Just reasons -> CollectiveFitUnavailable reasons blockers
        Nothing ->
          case NonEmpty.nonEmpty (sortSemanticDefects fitDefects) of
            Just defects -> CollectiveFitInvalid defects
            Nothing
              | allIdentitySitesResolved ->
                CollectiveFitSatisfied input [claimOccurrence]
              | otherwise ->
                CollectiveFitUnavailable
                  (CollectiveFitIdentityUnresolved NonEmpty.:| [])
                  []
      where prerequisiteStates =
              participantPrerequisites strategyResults participants
                ++ targetPrerequisites strategyResults target
            prerequisiteReasons =
              Set.toAscList (Set.fromList (map fst prerequisiteStates))
            blockers = Set.toAscList (Set.fromList (map snd prerequisiteStates))
            targetFormulation = target >>= validStrategyInput strategyResults
            participantsResolved =
              all
                (uncurry (identitySiteResolved . indexedPointer "/participants"))
                (zip
                   [0 :: Int ..]
                   (NonEmpty.toList (collectiveParticipants input)))
            targetResolved =
              identitySiteResolved "/target" (collectiveTarget input)
            targetGuidingPolicyResolved =
              identitySiteResolved
                "/targetGuidingPolicy"
                (collectiveTargetGuidingPolicy input)
            pairwiseCoherenceResolved =
              and
                [ identitySiteResolved
                  (nestedPointer "/pairwiseCoherence" index "participantA")
                  (pairwiseParticipantA row)
                  && identitySiteResolved
                       (nestedPointer "/pairwiseCoherence" index "participantB")
                       (pairwiseParticipantB row)
                | (index, row) <-
                    zip
                      [0 :: Int ..]
                      (NonEmpty.toList (collectivePairwiseCoherence input))
                ]
            participantCompatibilityResolved =
              and
                [ identitySiteResolved
                  (nestedPointer "/participantCompatibility" index "participant")
                  (compatibilityParticipant row)
                | (index, row) <-
                    zip
                      [0 :: Int ..]
                      (NonEmpty.toList
                         (collectiveParticipantCompatibility input))
                ]
            allIdentitySitesResolved =
              participantsResolved
                && targetResolved
                && targetGuidingPolicyResolved
                && pairwiseCoherenceResolved
                && participantCompatibilityResolved
            identitySiteResolved pointer identifier =
              collectiveIdentitySiteResolved
                semanticIndex
                claim
                pointer
                identifier
            suppliedPairs =
              sort
                [ canonicalPair
                  (pairwiseParticipantA row)
                  (pairwiseParticipantB row)
                | row <- NonEmpty.toList (collectivePairwiseCoherence input)
                ]
            compatibilityParticipants =
              sort
                (map
                   compatibilityParticipant
                   (NonEmpty.toList (collectiveParticipantCompatibility input)))
            fitDefects =
              [ defect
              | participantsResolved
              , defect <-
                  predicateDefect
                    Generated.CollectiveFitParticipantBindingRule
                    claim
                    claimOccurrence
                    (sort participants
                       == sort (NonEmpty.toList (collectiveParticipants input)))
              ]
                ++ [ defect
                   | targetResolved
                   , defect <-
                       predicateDefect
                         Generated.CollectiveFitTargetBindingRule
                         claim
                         claimOccurrence
                         (Just (collectiveTarget input) == target)
                   ]
                ++ [ defect
                   | targetGuidingPolicyResolved
                   , defect <-
                       predicateDefect
                         Generated.CollectiveFitTargetGuidingPolicyRule
                         claim
                         claimOccurrence
                         (maybe
                            False
                            ((== collectiveTargetGuidingPolicy input)
                               . formulationGuidingPolicy)
                            targetFormulation)
                   ]
                ++ predicateDefect
                     Generated.CollectiveFitTargetTradeOffsRule
                     claim
                     claimOccurrence
                     (maybe
                        False
                        ((== Set.fromList
                               (NonEmpty.toList
                                  (collectiveTargetTradeOffs input)))
                           . Set.fromList
                           . NonEmpty.toList
                           . formulationTradeOffs)
                        targetFormulation)
                ++ [ defect
                   | pairwiseCoherenceResolved
                   , defect <-
                       predicateDefect
                         Generated.CollectiveFitPairwiseCoherenceRule
                         claim
                         claimOccurrence
                         (suppliedPairs == expectedPairs)
                   ]
                ++ [ defect
                   | participantCompatibilityResolved
                   , defect <-
                       predicateDefect
                         Generated.CollectiveFitParticipantCompatibilityRule
                         claim
                         claimOccurrence
                         (compatibilityParticipants == sort participants)
                   ]

indexedPointer :: Text.Text -> Int -> Text.Text
indexedPointer parent index = parent <> "/" <> Text.pack (show index)

nestedPointer :: Text.Text -> Int -> Text.Text -> Text.Text
nestedPointer parent index member = indexedPointer parent index <> "/" <> member

assessCoverage ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> [ModelIdentity]
  -> Maybe ModelIdentity
  -> PreparedCollectiveSupport
  -> CollectiveCoverageAssessment
assessCoverage strategyResults claim participants target prepared =
  case NonEmpty.nonEmpty unavailable of
    Just _ -> CollectiveCoverageUnavailable blockers
    Nothing ->
      case target >>= validStrategyInput strategyResults of
        Nothing -> CollectiveCoverageUnavailable blockers
        Just _
          | requiredTargets `Set.isSubsetOf` preparedCoveredTargets prepared ->
            CollectiveCoverageSatisfied relationWitnesses
          | otherwise ->
            CollectiveCoverageViolated
              (mkSemanticDefect
                 Generated.CollectiveAssertedCollectiveCoverageRule
                 (SemanticFitClaimEvidenceKey claim)
                 (Set.toAscList
                    (requiredTargets Set.\\ preparedCoveredTargets prepared)))
  where
    prerequisiteStates =
      participantPrerequisites strategyResults participants
        ++ targetPrerequisites strategyResults target
    unavailable = map fst prerequisiteStates
    blockers = Set.toAscList (Set.fromList (map snd prerequisiteStates))
    requiredTargets =
      preparedTargetActions prepared
        `Set.union` preparedTargetKeyResults prepared
    relationWitnesses = Set.toAscList (preparedRelationWitnesses prepared)

assessMacroSupport ::
     SemanticIndex scope
  -> ModelIdentity
  -> OccurrenceIdentity
  -> ModelIdentity
  -> OccurrenceIdentity
  -> MacroSupportAssessment
assessMacroSupport semanticIndex claim target participant source =
  if isAssertedCarrierAt semanticIndex source
       && isAssertedCarrierAt semanticIndex target
    then case relationWitnesses of
           [] -> MacroSupportViolated claim participant
           _ -> MacroSupportSatisfied claim participant relationWitnesses
    else MacroSupportViolated claim participant
  where
    relationWitnesses =
      map
        relationOccurrenceIdentity
        (assertedMatchingRelations
           semanticIndex
           source
           tokenContributesTo
           target)

assessPrimitiveSupport ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> Maybe ModelIdentity
  -> PreparedCollectiveSupport
  -> ModelIdentity
  -> ParticipantPrimitiveSupportAssessment
assessPrimitiveSupport strategyResults claim target prepared participant =
  case NonEmpty.nonEmpty unavailableReasons of
    Just reasons ->
      ParticipantPrimitiveSupportUnavailable claim participant reasons blockers
    Nothing ->
      case relationWitnesses of
        [] -> ParticipantPrimitiveSupportViolated claim participant
        _ ->
          ParticipantPrimitiveSupportSatisfied
            claim
            participant
            relationWitnesses
  where
    prerequisiteStates =
      participantPrerequisites strategyResults [participant]
        ++ targetPrerequisites strategyResults target
    unavailableReasons =
      Set.toAscList (Set.fromList (map fst prerequisiteStates))
    blockers = Set.toAscList (Set.fromList (map snd prerequisiteStates))
    relationWitnesses =
      maybe
        []
        (Set.toAscList . participantContributionWitnesses)
        (Map.lookup participant (preparedParticipantSupport prepared))

-- | Exact work performed by collective support preparation.
data CollectiveWork = CollectiveWork
  { collectiveParticipantIndexEntries :: !Int
  , collectiveParticipantPrimitiveLookups :: !Int
  , collectiveTargetPrimitiveLookups :: !Int
  , collectiveContributionSourceProbes :: !Int
  , collectiveContributionTargetProbes :: !Int
  , collectiveContributionRelationLookups :: !Int
  , collectivePairwiseComparisons :: !Int
  } deriving (Eq, Show)

data PreparedCollectiveSupport = PreparedCollectiveSupport
  { preparedParticipantSupport :: !(Map ModelIdentity ParticipantSupport)
  , preparedTargetActions :: !(Set.Set OccurrenceIdentity)
  , preparedTargetKeyResults :: !(Set.Set OccurrenceIdentity)
  , preparedCoveredTargets :: !(Set.Set OccurrenceIdentity)
  , preparedRelationWitnesses :: !(Set.Set OccurrenceIdentity)
  , preparedCollectiveWork :: !CollectiveWork
  }

data ParticipantSupport = ParticipantSupport
  { participantContributionWitnesses :: !(Set.Set OccurrenceIdentity)
  , participantCoveredTargets :: !(Set.Set OccurrenceIdentity)
  , participantContributionWork :: !ContributionWork
  }

data ContributionWork = ContributionWork
  { contributionSourceProbes :: !Int
  , contributionTargetProbes :: !Int
  , contributionRelationLookups :: !Int
  }

prepareCollectiveSupport ::
     SemanticIndex scope
  -> Map ModelIdentity (StrategyFormulationAssessment scope)
  -> [ModelIdentity]
  -> Maybe ModelIdentity
  -> PreparedCollectiveSupport
prepareCollectiveSupport semanticIndex strategyResults participants target =
  PreparedCollectiveSupport
    { preparedParticipantSupport = participantSupport
    , preparedTargetActions = targetActions
    , preparedTargetKeyResults = targetKeyResults
    , preparedCoveredTargets =
        Set.unions (map participantCoveredTargets supportValues)
    , preparedRelationWitnesses =
        Set.unions (map participantContributionWitnesses supportValues)
    , preparedCollectiveWork =
        CollectiveWork
          { collectiveParticipantIndexEntries = Map.size participantSupport
          , collectiveParticipantPrimitiveLookups =
              sum (map participantPrimitiveLookups participantInputs)
          , collectiveTargetPrimitiveLookups = targetPrimitiveLookups
          , collectiveContributionSourceProbes =
              sum (map contributionSourceProbes contributionWorks)
          , collectiveContributionTargetProbes =
              sum (map contributionTargetProbes contributionWorks)
          , collectiveContributionRelationLookups =
              sum (map contributionRelationLookups contributionWorks)
          , collectivePairwiseComparisons = 0
          }
    }
  where
    targetInput = target >>= validStrategyInput strategyResults
    targetActionIdentities =
      maybe [] (NonEmpty.toList . formulationActions) targetInput
    targetKeyResultIdentities =
      maybe [] (NonEmpty.toList . formulationKeyResults) targetInput
    targetActions =
      Set.fromList
        (occurrencesForInputIdentities semanticIndex targetActionIdentities)
    targetKeyResults =
      Set.fromList
        (occurrencesForInputIdentities semanticIndex targetKeyResultIdentities)
    targetPrimitiveLookups =
      length targetActionIdentities + length targetKeyResultIdentities
    participantInputs =
      [ (participant, formulation)
      | participant <- participants
      , Just formulation <- [validStrategyInput strategyResults participant]
      ]
    participantSupport =
      Map.fromList
        [ ( participant
          , participantSupportFor
              semanticIndex
              targetActions
              targetKeyResults
              formulation)
        | (participant, formulation) <- participantInputs
        ]
    supportValues = Map.elems participantSupport
    contributionWorks = map participantContributionWork supportValues

participantPrimitiveLookups :: (ModelIdentity, StrategyFormulationInput) -> Int
participantPrimitiveLookups (_, formulation) =
  NonEmpty.length (formulationActions formulation)
    + NonEmpty.length (formulationKeyResults formulation)

participantSupportFor ::
     SemanticIndex scope
  -> Set.Set OccurrenceIdentity
  -> Set.Set OccurrenceIdentity
  -> StrategyFormulationInput
  -> ParticipantSupport
participantSupportFor semanticIndex targetActions targetKeyResults formulation =
  ParticipantSupport
    { participantContributionWitnesses =
        contributionWitnesses actionEvidence
          `Set.union` contributionWitnesses keyResultEvidence
    , participantCoveredTargets =
        contributionTargets actionEvidence
          `Set.union` contributionTargets keyResultEvidence
    , participantContributionWork =
        combineContributionWork
          (contributionWork actionEvidence)
          (contributionWork keyResultEvidence)
    }
  where
    actionEvidence =
      collectContributionEvidence
        semanticIndex
        (occurrencesForInputIdentities
           semanticIndex
           (NonEmpty.toList (formulationActions formulation)))
        targetActions
    keyResultEvidence =
      collectContributionEvidence
        semanticIndex
        (occurrencesForInputIdentities
           semanticIndex
           (NonEmpty.toList (formulationKeyResults formulation)))
        targetKeyResults

data ContributionEvidence = ContributionEvidence
  { contributionWitnesses :: !(Set.Set OccurrenceIdentity)
  , contributionTargets :: !(Set.Set OccurrenceIdentity)
  , contributionWork :: !ContributionWork
  }

collectContributionEvidence ::
     SemanticIndex scope
  -> [OccurrenceIdentity]
  -> Set.Set OccurrenceIdentity
  -> ContributionEvidence
collectContributionEvidence semanticIndex sources targets =
  foldl' collect emptyContributionEvidence sources
  where
    collect evidence source =
      mergeContributionEvidence evidence (evidenceForSource source)
    evidenceForSource source =
      ContributionEvidence
        { contributionWitnesses =
            Set.fromList (map relationOccurrenceIdentity relations)
        , contributionTargets =
            Set.fromList (map relationTargetOccurrence relations)
        , contributionWork =
            ContributionWork
              { contributionSourceProbes = 1
              , contributionTargetProbes = length outgoing
              , contributionRelationLookups = length matchedTargets
              }
        }
      where
        outgoing =
          assertedOutgoingTargets semanticIndex source tokenContributesTo
        matchedTargets = filter (`Set.member` targets) outgoing
        relations =
          concatMap
            (assertedMatchingRelations semanticIndex source tokenContributesTo)
            matchedTargets

emptyContributionEvidence :: ContributionEvidence
emptyContributionEvidence =
  ContributionEvidence Set.empty Set.empty (ContributionWork 0 0 0)

mergeContributionEvidence ::
     ContributionEvidence -> ContributionEvidence -> ContributionEvidence
mergeContributionEvidence left right =
  ContributionEvidence
    { contributionWitnesses =
        contributionWitnesses left `Set.union` contributionWitnesses right
    , contributionTargets =
        contributionTargets left `Set.union` contributionTargets right
    , contributionWork =
        combineContributionWork (contributionWork left) (contributionWork right)
    }

combineContributionWork ::
     ContributionWork -> ContributionWork -> ContributionWork
combineContributionWork left right =
  ContributionWork
    { contributionSourceProbes =
        contributionSourceProbes left + contributionSourceProbes right
    , contributionTargetProbes =
        contributionTargetProbes left + contributionTargetProbes right
    , contributionRelationLookups =
        contributionRelationLookups left + contributionRelationLookups right
    }

componentDefects ::
     OccurrenceIdentity
  -> Map ModelIdentity OccurrenceIdentity
  -> [OccurrenceIdentity]
  -> CollectiveStrategyRealizationComponents scope
  -> [SemanticDefect]
componentDefects claimOccurrence participantBindings targetOccurrences components =
  completenessDefects
    ++ fitDefects
    ++ coverageDefects
    ++ macroDefects
    ++ primitiveDefects
  where
    completenessDefects =
      case collectiveCompletenessResult components of
        CollectiveCompletenessViolated defect -> [defect]
        CollectiveCompletenessSatisfied -> []
    fitDefects =
      case collectiveFitResult components of
        CollectiveFitInvalid defects -> NonEmpty.toList defects
        _ -> []
    coverageDefects =
      case collectiveCoverageResult components of
        CollectiveCoverageViolated defect -> [defect]
        _ -> []
    macroDefects =
      [ mkSemanticDefect
        Generated.CollectiveAssertedMacroSupportRule
        (SemanticParticipantClaimEvidenceKey claim participant)
        (supportFailureWitnesses participant)
      | MacroSupportViolated claim participant <-
          collectiveMacroSupportResults components
      ]
    primitiveDefects =
      [ mkSemanticDefect
        Generated.CollectiveAssertedParticipantPrimitiveSupportRule
        (SemanticParticipantClaimEvidenceKey claim participant)
        (supportFailureWitnesses participant)
      | ParticipantPrimitiveSupportViolated claim participant <-
          collectivePrimitiveSupportResults components
      ]
    supportFailureWitnesses participant =
      Set.toAscList . Set.fromList
        $ claimOccurrence
            : maybeToList (Map.lookup participant participantBindings)
            ++ targetOccurrences

componentsUnavailable :: CollectiveStrategyRealizationComponents scope -> Bool
componentsUnavailable components =
  fitUnavailable
    || coverageUnavailable
    || any primitiveUnavailable (collectivePrimitiveSupportResults components)
  where
    fitUnavailable =
      case collectiveFitResult components of
        CollectiveFitUnavailable _ _ -> True
        _ -> False
    coverageUnavailable =
      case collectiveCoverageResult components of
        CollectiveCoverageUnavailable _ -> True
        _ -> False
    primitiveUnavailable assessment =
      case assessment of
        ParticipantPrimitiveSupportUnavailable _ _ _ _ -> True
        _ -> False

componentWitnesses ::
     CollectiveStrategyRealizationComponents scope -> [OccurrenceIdentity]
componentWitnesses components =
  coverageWitnesses ++ macroWitnesses ++ primitiveWitnesses
  where
    coverageWitnesses =
      case collectiveCoverageResult components of
        CollectiveCoverageSatisfied witnesses -> witnesses
        _ -> []
    macroWitnesses =
      concat
        [ witnesses
        | MacroSupportSatisfied _ _ witnesses <-
            collectiveMacroSupportResults components
        ]
    primitiveWitnesses =
      concat
        [ witnesses
        | ParticipantPrimitiveSupportSatisfied _ _ witnesses <-
            collectivePrimitiveSupportResults components
        ]

strategyAssessmentIndex ::
     [StrategyFormulationAssessment scope]
  -> Map ModelIdentity (StrategyFormulationAssessment scope)
strategyAssessmentIndex = Map.fromList . map keyed
  where
    keyed assessment = (strategyAssessmentIdentity assessment, assessment)

strategyAssessmentIdentity ::
     StrategyFormulationAssessment scope -> ModelIdentity
strategyAssessmentIdentity assessment =
  case assessment of
    StrategyFormulationUnavailable identifier _ -> identifier
    StrategyFormulationCandidate identifier _ -> identifier
    StrategyFormulationInvalid identifier _ -> identifier
    StrategyFormulationValid proof -> eligibleStrategyIdentity proof

strategyResult ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> StrategyFormulationAssessment scope
strategyResult strategyResults identifier =
  Map.findWithDefault
    (StrategyFormulationUnavailable identifier StrategyFormulationInputMissing)
    identifier
    strategyResults

validStrategyInput ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> Maybe StrategyFormulationInput
validStrategyInput strategyResults identifier =
  case Map.lookup identifier strategyResults of
    Just (StrategyFormulationValid proof) -> Just (eligibleStrategyInput proof)
    _ -> Nothing

strategyWitnesses :: StrategyFormulationAssessment scope -> [OccurrenceIdentity]
strategyWitnesses assessment =
  case assessment of
    StrategyFormulationValid proof -> eligibleStrategyWitnesses proof
    _ -> []

participantPrerequisites ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> [ModelIdentity]
  -> [(CollectiveFitUnavailableReason, ModelIdentity)]
participantPrerequisites strategyResults = concatMap prerequisite
  where
    prerequisite identifier =
      case Map.lookup identifier strategyResults of
        Just (StrategyFormulationValid _) -> []
        Just (StrategyFormulationInvalid _ _) ->
          [(ParticipantStrategyFormulationInvalid, identifier)]
        _ -> [(ParticipantStrategyFormulationUnavailable, identifier)]

targetPrerequisites ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> Maybe ModelIdentity
  -> [(CollectiveFitUnavailableReason, ModelIdentity)]
targetPrerequisites strategyResults target =
  case target of
    Nothing -> []
    Just identifier ->
      case Map.lookup identifier strategyResults of
        Just (StrategyFormulationValid _) -> []
        Just (StrategyFormulationInvalid _ _) ->
          [(TargetStrategyFormulationInvalid, identifier)]
        _ -> [(TargetStrategyFormulationUnavailable, identifier)]

incidenceEndpointsFor ::
     CoreStructuredPropositionRoleId
  -> [StructuredIncidenceObservation scope]
  -> [OccurrenceIdentity]
incidenceEndpointsFor role =
  map structuredIncidenceEndpoint . filter ((== role) . structuredIncidenceRole)

identitiesAt ::
     SemanticIndex scope
  -> [OccurrenceIdentity]
  -> [(ModelIdentity, OccurrenceIdentity)]
identitiesAt semanticIndex = foldr collect []
  where
    collect occurrence bindings =
      case carrierAt semanticIndex occurrence of
        Just carrier -> (carrierModelIdentity carrier, occurrence) : bindings
        Nothing -> bindings

onlyIdentityAt ::
     SemanticIndex scope -> [OccurrenceIdentity] -> Maybe ModelIdentity
onlyIdentityAt semanticIndex occurrences =
  case map fst (identitiesAt semanticIndex occurrences) of
    [identifier] -> Just identifier
    _ -> Nothing

occurrencesForInputIdentities ::
     SemanticIndex scope -> [ModelIdentity] -> [OccurrenceIdentity]
occurrencesForInputIdentities semanticIndex identifiers =
  [ occurrence
  | identifier <- identifiers
  , occurrence <- occurrencesForModelIdentity semanticIndex identifier
  , Just carrier <- [carrierAt semanticIndex occurrence]
  , carrierCommitment carrier == Asserted
  ]

isAssertedCarrierAt :: SemanticIndex scope -> OccurrenceIdentity -> Bool
isAssertedCarrierAt semanticIndex occurrence =
  maybe
    False
    ((== Asserted) . carrierCommitment)
    (carrierAt semanticIndex occurrence)

predicateDefect ::
     Generated.GeneratedSemanticRule 'Generated.GeneratedFitClaimKeySchema
  -> ModelIdentity
  -> OccurrenceIdentity
  -> Bool
  -> [SemanticDefect]
predicateDefect rule claim occurrence satisfied =
  [ mkSemanticDefect rule (SemanticFitClaimEvidenceKey claim) [occurrence]
  | not satisfied
  ]

allPairs :: Ord value => [value] -> [(value, value)]
allPairs values =
  [ (left, right)
  | (index, left) <- zip [0 :: Int ..] ordered
  , right <- drop (index + 1) ordered
  ]
  where
    ordered = sort values

canonicalPair :: Ord value => value -> value -> (value, value)
canonicalPair left right
  | left <= right = (left, right)
  | otherwise = (right, left)

maybeToList :: Maybe value -> [value]
maybeToList maybeValue =
  case maybeValue of
    Just value -> [value]
    Nothing -> []
