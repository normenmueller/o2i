{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Public Core Semantics boundary.
--
-- Assessments and proofs are opaque. Consumers can inspect deterministic
-- dispositions, subjects, defects, blockers, and witness occurrences without
-- constructing semantic authority or traversing the graph generically.
module O2I.Semantics
  ( SemanticAssessment
  , SemanticDisposition(..)
  , assessSemantics
  , semanticAssessmentMatchesGraph
  , semanticDisposition
  , foldSemanticAssessment
  , semanticCandidateOccurrences
  , semanticallyValidModel
  , SemanticDiagnosticEvidence
  , SemanticDiagnosticEliminator(..)
  , foldSemanticDiagnosticEvidence
  , semanticDiagnosticRule
  , SituatedNeedAssessment
  , StrategyFormulationAssessment
  , CollectiveStrategyRealizationAssessment
  , SubjectDisposition(..)
  , situatedNeedAssessments
  , strategyFormulationAssessments
  , collectiveStrategyRealizationAssessments
  , situatedNeedDisposition
  , strategyFormulationDisposition
  , collectiveStrategyRealizationDisposition
  , situatedNeedSubject
  , strategyFormulationSubject
  , collectiveStrategyRealizationSubject
  , StrategyFormulationUnavailableReason(..)
  , strategyFormulationUnavailableReason
  , SemanticallyValidModel
  , GloballySituatedNeed
  , QualificationEligibleStrategy
  , ValidatedCollectiveStrategyRealization
  , semanticallyValidSituatedNeeds
  , semanticallyValidStrategies
  , semanticallyValidCollectiveRealizations
  , globallySituatedNeedIdentity
  , globallySituatedNeedWitnesses
  , qualificationEligibleStrategyIdentity
  , qualificationEligibleStrategyWitnesses
  , validatedCollectiveStrategyRealizationIdentity
  , validatedCollectiveStrategyRealizationWitnesses
  , CollectiveStrategyRealizationComponents
  , CollectiveFitUnavailableReason(..)
  , MacroSupportAssessment
  , ParticipantPrimitiveSupportAssessment
  , ComponentDisposition(..)
  , collectiveStrategyRealizationComponents
  , collectiveCompletenessDisposition
  , collectiveFitDisposition
  , collectiveFitUnavailableReasons
  , collectiveFitBlockingStrategies
  , collectiveCoverageDisposition
  , collectiveCoverageBlockingStrategies
  , collectiveMacroSupportAssessments
  , macroSupportParticipant
  , macroSupportDisposition
  , macroSupportWitnesses
  , collectivePrimitiveSupportAssessments
  , primitiveSupportParticipant
  , primitiveSupportDisposition
  , primitiveSupportUnavailableReasons
  , primitiveSupportBlockingStrategies
  , primitiveSupportWitnesses
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Contract (CoreRuleId)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import qualified O2I.Semantics.Eval as Eval
import O2I.Semantics.Input (BoundSupplementalInputs)
import O2I.Semantics.Internal
  ( CollectiveFitUnavailableReason(..)
  , CollectiveStrategyRealizationAssessment
  , CollectiveStrategyRealizationComponents
  , GloballySituatedNeed
  , MacroSupportAssessment
  , ParticipantPrimitiveSupportAssessment
  , QualificationEligibleStrategy
  , SemanticallyValidModel
  , SituatedNeedAssessment
  , StrategyFormulationAssessment
  , StrategyFormulationUnavailableReason(..)
  , ValidatedCollectiveStrategyRealization
  )
import qualified O2I.Semantics.Internal as Internal
import O2I.Structure (WellFormedGraph)

-- | Opaque aggregate result nominal in its producing selected-View scope.
newtype SemanticAssessment scope =
  SemanticAssessment (Internal.SemanticAssessment scope)

type role SemanticAssessment nominal

-- | Opaque semantic diagnostic nominal in its producing scope.
newtype SemanticDiagnosticEvidence scope =
  SemanticDiagnosticEvidence Internal.SemanticDefect

type role SemanticDiagnosticEvidence nominal

-- | Evaluate Semantics without erasing the selected-View scope.
assessSemantics ::
     WellFormedGraph scope
  -> BoundSupplementalInputs scope
  -> SemanticAssessment scope
assessSemantics graph = SemanticAssessment . Eval.assessSemantics graph

-- | Decide whether this assessment was produced from the exact graph value.
semanticAssessmentMatchesGraph ::
     WellFormedGraph scope -> SemanticAssessment scope -> Bool
semanticAssessmentMatchesGraph graph (SemanticAssessment assessment) =
  Internal.semanticAssessmentMatchesGraph graph assessment

-- | Aggregate Core Semantics disposition.
data SemanticDisposition
  = SemanticRejected
  | SemanticUnavailable
  | SemanticAccepted
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Subject-local disposition shared by fixed semantic families.
data SubjectDisposition
  = SubjectCandidate
  | SubjectUnavailable
  | SubjectInvalid
  | SubjectValid
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Disposition of one separately inspectable collective component.
data ComponentDisposition
  = ComponentUnavailable
  | ComponentInvalid
  | ComponentSatisfied
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify the aggregate semantic outcome without exposing its proof data.
semanticDisposition :: SemanticAssessment scope -> SemanticDisposition
semanticDisposition (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsRejected _ _ _ -> SemanticRejected
    Internal.SemanticsUnavailable _ _ -> SemanticUnavailable
    Internal.SemanticsAccepted _ _ -> SemanticAccepted

-- | Eliminate only the exact aggregate result produced in one scope.
foldSemanticAssessment ::
     (NonEmpty (SemanticDiagnosticEvidence scope) -> result)
  -> result
  -> (SemanticallyValidModel scope -> result)
  -> SemanticAssessment scope
  -> result
foldSemanticAssessment rejected unavailable accepted (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsRejected _ _ failures ->
      rejected (SemanticDiagnosticEvidence <$> failures)
    Internal.SemanticsUnavailable _ _ -> unavailable
    Internal.SemanticsAccepted _ model -> accepted model

-- | Return every Candidate occurrence retained during semantic assessment.
semanticCandidateOccurrences :: SemanticAssessment scope -> [OccurrenceIdentity]
semanticCandidateOccurrences =
  Internal.storedCandidateOccurrences . semanticResults

-- | Project the model-internal proof from every non-rejected outcome.
semanticallyValidModel ::
     SemanticAssessment scope -> Maybe (SemanticallyValidModel scope)
semanticallyValidModel (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsRejected _ _ _ -> Nothing
    Internal.SemanticsUnavailable _ model -> Just model
    Internal.SemanticsAccepted _ model -> Just model

-- | Identify the compiled Core rule carried by scoped semantic evidence.
semanticDiagnosticRule :: SemanticDiagnosticEvidence scope -> CoreRuleId
semanticDiagnosticRule (SemanticDiagnosticEvidence defect) =
  Internal.semanticRuleId (Internal.semanticDefectRule defect)

-- | Total consumer algebra for every produced semantic diagnostic shape.
--
-- Each handler receives evidence-key fields first and occurrence evidence
-- second. 'NonEmpty' and list cardinalities are retained exactly from the
-- compiled Core contract.
data SemanticDiagnosticEliminator result = SemanticDiagnosticEliminator
  { eliminateCollectiveAssertedCollectiveCoverage :: ModelIdentity -> NonEmpty
                                                                        OccurrenceIdentity -> result
  , eliminateCollectiveAssertedCompleteness :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveAssertedMacroSupport :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveAssertedParticipantPrimitiveSupport :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitPairwiseCoherence :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitParticipantBinding :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitParticipantCompatibility :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitTargetBinding :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitTargetGuidingPolicy :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateCollectiveFitTargetTradeOffs :: ModelIdentity -> OccurrenceIdentity -> result
  , eliminateContextualizationAssertedDependency :: OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateSituatedNeedDriverAnchoring :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> result
  , eliminateSituatedNeedDriverCardinality :: ModelIdentity -> result
  , eliminateSituatedNeedObjectiveCardinality :: ModelIdentity -> result
  , eliminateSituatedNeedObjectiveGrounding :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> result
  , eliminateSituatedNeedSurfacingSituationAnchoring :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> result
  , eliminateSituatedNeedSurfacingSituationCardinality :: ModelIdentity -> result
  , eliminateStrategyFormulationActionContributions :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> result
  , eliminateStrategyFormulationActions :: ModelIdentity -> NonEmpty
                                                              OccurrenceIdentity -> result
  , eliminateStrategyFormulationDiagnosis :: ModelIdentity -> [OccurrenceIdentity] -> result
  , eliminateStrategyFormulationDiagnosisGrounding :: ModelIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateStrategyFormulationGuidingPolicy :: ModelIdentity -> [OccurrenceIdentity] -> result
  , eliminateStrategyFormulationGuidingPolicyActions :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateStrategyFormulationIntent :: ModelIdentity -> [OccurrenceIdentity] -> result
  , eliminateStrategyFormulationKeyResultSubstantiation :: ModelIdentity -> ModelIdentity -> OccurrenceIdentity -> OccurrenceIdentity -> result
  , eliminateStrategyFormulationKeyResults :: ModelIdentity -> NonEmpty
                                                                 OccurrenceIdentity -> result
  , eliminateStrategyFormulationVisionOrientation :: ModelIdentity -> result
  }

-- | Eliminate opaque evidence through its one exact typed producer branch.
foldSemanticDiagnosticEvidence ::
     forall result scope.
     SemanticDiagnosticEliminator result
  -> SemanticDiagnosticEvidence scope
  -> result
foldSemanticDiagnosticEvidence eliminator (SemanticDiagnosticEvidence defect) =
  Internal.foldSemanticDefect eliminate defect
  where
    eliminate ::
         forall evidenceSchema occurrenceSchema.
         Generated.GeneratedSemanticRule evidenceSchema occurrenceSchema
      -> Internal.SemanticEvidenceKey evidenceSchema
      -> Internal.SemanticOccurrenceEvidence occurrenceSchema
      -> result
    eliminate Generated.CollectiveAssertedCollectiveCoverageRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveAssertedCollectiveCoverageOccurrences values) =
      eliminateCollectiveAssertedCollectiveCoverage eliminator claim values
    eliminate Generated.CollectiveAssertedCompletenessRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveAssertedCompletenessOccurrences occurrence) =
      eliminateCollectiveAssertedCompleteness eliminator claim occurrence
    eliminate Generated.CollectiveAssertedMacroSupportRule (Internal.SemanticParticipantClaimEvidenceKey claim participant) (Generated.CollectiveAssertedMacroSupportOccurrences claimOccurrence participantOccurrence targetOccurrence) =
      eliminateCollectiveAssertedMacroSupport
        eliminator
        claim
        participant
        claimOccurrence
        participantOccurrence
        targetOccurrence
    eliminate Generated.CollectiveAssertedParticipantPrimitiveSupportRule (Internal.SemanticParticipantClaimEvidenceKey claim participant) (Generated.CollectiveAssertedParticipantPrimitiveSupportOccurrences claimOccurrence participantOccurrence targetOccurrence) =
      eliminateCollectiveAssertedParticipantPrimitiveSupport
        eliminator
        claim
        participant
        claimOccurrence
        participantOccurrence
        targetOccurrence
    eliminate Generated.CollectiveFitPairwiseCoherenceRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitPairwiseCoherenceOccurrences occurrence) =
      eliminateCollectiveFitPairwiseCoherence eliminator claim occurrence
    eliminate Generated.CollectiveFitParticipantBindingRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitParticipantBindingOccurrences occurrence) =
      eliminateCollectiveFitParticipantBinding eliminator claim occurrence
    eliminate Generated.CollectiveFitParticipantCompatibilityRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitParticipantCompatibilityOccurrences occurrence) =
      eliminateCollectiveFitParticipantCompatibility eliminator claim occurrence
    eliminate Generated.CollectiveFitTargetBindingRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitTargetBindingOccurrences occurrence) =
      eliminateCollectiveFitTargetBinding eliminator claim occurrence
    eliminate Generated.CollectiveFitTargetGuidingPolicyRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitTargetGuidingPolicyOccurrences occurrence) =
      eliminateCollectiveFitTargetGuidingPolicy eliminator claim occurrence
    eliminate Generated.CollectiveFitTargetTradeOffsRule (Internal.SemanticFitClaimEvidenceKey claim) (Generated.CollectiveFitTargetTradeOffsOccurrences occurrence) =
      eliminateCollectiveFitTargetTradeOffs eliminator claim occurrence
    eliminate Generated.ContextualizationAssertedDependencyRule (Internal.SemanticAssertedDependencyEvidenceKey dependent endpoint context) (Generated.ContextualizationAssertedDependencyOccurrences dependentOccurrence endpointOccurrence contextOccurrence) =
      eliminateContextualizationAssertedDependency
        eliminator
        dependent
        endpoint
        context
        dependentOccurrence
        endpointOccurrence
        contextOccurrence
    eliminate Generated.SituatedNeedDriverAnchoringRule (Internal.SemanticNeedMemberEvidenceKey need member) (Generated.SituatedNeedDriverAnchoringOccurrences occurrence) =
      eliminateSituatedNeedDriverAnchoring eliminator need member occurrence
    eliminate Generated.SituatedNeedDriverCardinalityRule (Internal.SemanticNeedEvidenceKey need) Generated.SituatedNeedDriverCardinalityOccurrences =
      eliminateSituatedNeedDriverCardinality eliminator need
    eliminate Generated.SituatedNeedObjectiveCardinalityRule (Internal.SemanticNeedEvidenceKey need) Generated.SituatedNeedObjectiveCardinalityOccurrences =
      eliminateSituatedNeedObjectiveCardinality eliminator need
    eliminate Generated.SituatedNeedObjectiveGroundingRule (Internal.SemanticNeedMemberEvidenceKey need member) (Generated.SituatedNeedObjectiveGroundingOccurrences occurrence) =
      eliminateSituatedNeedObjectiveGrounding eliminator need member occurrence
    eliminate Generated.SituatedNeedSurfacingSituationAnchoringRule (Internal.SemanticNeedMemberEvidenceKey need member) (Generated.SituatedNeedSurfacingSituationAnchoringOccurrences occurrence) =
      eliminateSituatedNeedSurfacingSituationAnchoring
        eliminator
        need
        member
        occurrence
    eliminate Generated.SituatedNeedSurfacingSituationCardinalityRule (Internal.SemanticNeedEvidenceKey need) Generated.SituatedNeedSurfacingSituationCardinalityOccurrences =
      eliminateSituatedNeedSurfacingSituationCardinality eliminator need
    eliminate Generated.StrategyFormulationActionContributionsRule (Internal.SemanticStrategyMemberEvidenceKey strategy member) (Generated.StrategyFormulationActionContributionsOccurrences occurrence) =
      eliminateStrategyFormulationActionContributions
        eliminator
        strategy
        member
        occurrence
    eliminate Generated.StrategyFormulationActionsRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationActionsOccurrences occurrences) =
      eliminateStrategyFormulationActions eliminator strategy occurrences
    eliminate Generated.StrategyFormulationDiagnosisRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationDiagnosisOccurrences occurrences) =
      eliminateStrategyFormulationDiagnosis eliminator strategy occurrences
    eliminate Generated.StrategyFormulationDiagnosisGroundingRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationDiagnosisGroundingOccurrences diagnosis grounding) =
      eliminateStrategyFormulationDiagnosisGrounding
        eliminator
        strategy
        diagnosis
        grounding
    eliminate Generated.StrategyFormulationGuidingPolicyRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationGuidingPolicyOccurrences occurrences) =
      eliminateStrategyFormulationGuidingPolicy eliminator strategy occurrences
    eliminate Generated.StrategyFormulationGuidingPolicyActionsRule (Internal.SemanticStrategyMemberEvidenceKey strategy member) (Generated.StrategyFormulationGuidingPolicyActionsOccurrences policy action) =
      eliminateStrategyFormulationGuidingPolicyActions
        eliminator
        strategy
        member
        policy
        action
    eliminate Generated.StrategyFormulationIntentRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationIntentOccurrences occurrences) =
      eliminateStrategyFormulationIntent eliminator strategy occurrences
    eliminate Generated.StrategyFormulationKeyResultSubstantiationRule (Internal.SemanticStrategyMemberEvidenceKey strategy member) (Generated.StrategyFormulationKeyResultSubstantiationOccurrences keyResult substantiation) =
      eliminateStrategyFormulationKeyResultSubstantiation
        eliminator
        strategy
        member
        keyResult
        substantiation
    eliminate Generated.StrategyFormulationKeyResultsRule (Internal.SemanticStrategyEvidenceKey strategy) (Generated.StrategyFormulationKeyResultsOccurrences occurrences) =
      eliminateStrategyFormulationKeyResults eliminator strategy occurrences
    eliminate Generated.StrategyFormulationVisionOrientationRule (Internal.SemanticStrategyEvidenceKey strategy) Generated.StrategyFormulationVisionOrientationOccurrences =
      eliminateStrategyFormulationVisionOrientation eliminator strategy

-- | Enumerate deterministic assessments for all recognized Need subjects.
situatedNeedAssessments ::
     SemanticAssessment scope -> [SituatedNeedAssessment scope]
situatedNeedAssessments =
  Internal.storedSituatedNeedAssessments . semanticResults

-- | Enumerate deterministic assessments for all recognized Strategy subjects.
strategyFormulationAssessments ::
     SemanticAssessment scope -> [StrategyFormulationAssessment scope]
strategyFormulationAssessments =
  Internal.storedStrategyAssessments . semanticResults

-- | Enumerate deterministic assessments for all recognized collective claims.
collectiveStrategyRealizationAssessments ::
     SemanticAssessment scope -> [CollectiveStrategyRealizationAssessment scope]
collectiveStrategyRealizationAssessments =
  Internal.storedCollectiveAssessments . semanticResults

-- | Classify one situated-Need assessment.
situatedNeedDisposition :: SituatedNeedAssessment scope -> SubjectDisposition
situatedNeedDisposition assessment =
  case assessment of
    Internal.SituatedNeedCandidate _ _ -> SubjectCandidate
    Internal.SituatedNeedInvalid _ _ -> SubjectInvalid
    Internal.SituatedNeedValid _ -> SubjectValid

-- | Classify one Strategy-formulation assessment.
strategyFormulationDisposition ::
     StrategyFormulationAssessment scope -> SubjectDisposition
strategyFormulationDisposition assessment =
  case assessment of
    Internal.StrategyFormulationUnavailable _ _ -> SubjectUnavailable
    Internal.StrategyFormulationCandidate _ _ -> SubjectCandidate
    Internal.StrategyFormulationInvalid _ _ -> SubjectInvalid
    Internal.StrategyFormulationValid _ -> SubjectValid

-- | Classify one collective-Strategy-realization assessment.
collectiveStrategyRealizationDisposition ::
     CollectiveStrategyRealizationAssessment scope -> SubjectDisposition
collectiveStrategyRealizationDisposition assessment =
  case assessment of
    Internal.CollectiveStrategyRealizationCandidate _ _ -> SubjectCandidate
    Internal.CollectiveStrategyRealizationUnavailable _ _ -> SubjectUnavailable
    Internal.CollectiveStrategyRealizationInvalid _ _ _ -> SubjectInvalid
    Internal.CollectiveStrategyRealizationValid _ _ -> SubjectValid

-- | Identify the Need subject of one situated-Need assessment.
situatedNeedSubject :: SituatedNeedAssessment scope -> ModelIdentity
situatedNeedSubject assessment =
  case assessment of
    Internal.SituatedNeedCandidate subject _ -> subject
    Internal.SituatedNeedInvalid subject _ -> subject
    Internal.SituatedNeedValid proof -> Internal.situatedNeedIdentity proof

-- | Identify the Strategy subject of one formulation assessment.
strategyFormulationSubject ::
     StrategyFormulationAssessment scope -> ModelIdentity
strategyFormulationSubject assessment =
  case assessment of
    Internal.StrategyFormulationUnavailable subject _ -> subject
    Internal.StrategyFormulationCandidate subject _ -> subject
    Internal.StrategyFormulationInvalid subject _ -> subject
    Internal.StrategyFormulationValid proof ->
      Internal.eligibleStrategyIdentity proof

-- | Return why Strategy assessment was unavailable, when applicable.
strategyFormulationUnavailableReason ::
     StrategyFormulationAssessment scope
  -> Maybe StrategyFormulationUnavailableReason
strategyFormulationUnavailableReason assessment =
  case assessment of
    Internal.StrategyFormulationUnavailable _ reason -> Just reason
    _ -> Nothing

-- | Identify the claim subject of one collective-realization assessment.
collectiveStrategyRealizationSubject ::
     CollectiveStrategyRealizationAssessment scope -> ModelIdentity
collectiveStrategyRealizationSubject assessment =
  case assessment of
    Internal.CollectiveStrategyRealizationCandidate subject _ -> subject
    Internal.CollectiveStrategyRealizationUnavailable subject _ -> subject
    Internal.CollectiveStrategyRealizationInvalid subject _ _ -> subject
    Internal.CollectiveStrategyRealizationValid proof _ ->
      Internal.validatedCollectiveClaim proof

-- | Enumerate every proven globally situated Need in canonical result order.
semanticallyValidSituatedNeeds ::
     SemanticallyValidModel scope -> [GloballySituatedNeed scope]
semanticallyValidSituatedNeeds = Internal.semanticModelSituatedNeeds

-- | Enumerate every qualification proof retained by this assessment.
semanticallyValidStrategies ::
     SemanticAssessment scope -> [QualificationEligibleStrategy scope]
semanticallyValidStrategies assessment =
  [ proof
  | Internal.StrategyFormulationValid proof <-
      strategyFormulationAssessments assessment
  ]

-- | Enumerate every collective proof retained by this assessment.
semanticallyValidCollectiveRealizations ::
     SemanticAssessment scope -> [ValidatedCollectiveStrategyRealization scope]
semanticallyValidCollectiveRealizations assessment =
  [ proof
  | Internal.CollectiveStrategyRealizationValid proof _ <-
      collectiveStrategyRealizationAssessments assessment
  ]

-- | Identify the Need proven globally situated.
globallySituatedNeedIdentity :: GloballySituatedNeed scope -> ModelIdentity
globallySituatedNeedIdentity = Internal.situatedNeedIdentity

-- | Return exact occurrences witnessing global situatedness.
globallySituatedNeedWitnesses ::
     GloballySituatedNeed scope -> [OccurrenceIdentity]
globallySituatedNeedWitnesses = Internal.situatedNeedWitnesses

-- | Identify the Strategy proven eligible for qualification.
qualificationEligibleStrategyIdentity ::
     QualificationEligibleStrategy scope -> ModelIdentity
qualificationEligibleStrategyIdentity = Internal.eligibleStrategyIdentity

-- | Return exact occurrences witnessing qualification eligibility.
qualificationEligibleStrategyWitnesses ::
     QualificationEligibleStrategy scope -> [OccurrenceIdentity]
qualificationEligibleStrategyWitnesses = Internal.eligibleStrategyWitnesses

-- | Identify the validated collective realization claim.
validatedCollectiveStrategyRealizationIdentity ::
     ValidatedCollectiveStrategyRealization scope -> ModelIdentity
validatedCollectiveStrategyRealizationIdentity =
  Internal.validatedCollectiveClaim

-- | Return exact occurrences witnessing a validated collective realization.
validatedCollectiveStrategyRealizationWitnesses ::
     ValidatedCollectiveStrategyRealization scope -> [OccurrenceIdentity]
validatedCollectiveStrategyRealizationWitnesses =
  Internal.validatedCollectiveWitnesses

-- | Project component results once a collective claim reached evaluation.
collectiveStrategyRealizationComponents ::
     CollectiveStrategyRealizationAssessment scope
  -> Maybe (CollectiveStrategyRealizationComponents scope)
collectiveStrategyRealizationComponents assessment =
  case assessment of
    Internal.CollectiveStrategyRealizationCandidate _ _ -> Nothing
    Internal.CollectiveStrategyRealizationUnavailable _ components ->
      Just components
    Internal.CollectiveStrategyRealizationInvalid _ components _ ->
      Just components
    Internal.CollectiveStrategyRealizationValid _ components -> Just components

-- | Classify structural completeness of the collective realization.
collectiveCompletenessDisposition ::
     CollectiveStrategyRealizationComponents scope -> ComponentDisposition
collectiveCompletenessDisposition components =
  case Internal.collectiveCompletenessResult components of
    Internal.CollectiveCompletenessViolated _ -> ComponentInvalid
    Internal.CollectiveCompletenessSatisfied -> ComponentSatisfied

-- | Classify collective Fit evidence independently of coverage.
collectiveFitDisposition ::
     CollectiveStrategyRealizationComponents scope -> ComponentDisposition
collectiveFitDisposition components =
  case Internal.collectiveFitResult components of
    Internal.CollectiveFitUnavailable _ _ -> ComponentUnavailable
    Internal.CollectiveFitInvalid _ -> ComponentInvalid
    Internal.CollectiveFitSatisfied _ _ -> ComponentSatisfied

-- | Return every reason collective Fit evidence was unavailable.
collectiveFitUnavailableReasons ::
     CollectiveStrategyRealizationComponents scope
  -> [CollectiveFitUnavailableReason]
collectiveFitUnavailableReasons components =
  case Internal.collectiveFitResult components of
    Internal.CollectiveFitUnavailable reasons _ -> NonEmpty.toList reasons
    _ -> []

-- | Return Strategies blocking collective Fit evaluation.
collectiveFitBlockingStrategies ::
     CollectiveStrategyRealizationComponents scope -> [ModelIdentity]
collectiveFitBlockingStrategies components =
  case Internal.collectiveFitResult components of
    Internal.CollectiveFitUnavailable _ blockers -> blockers
    _ -> []

-- | Classify contributor coverage independently of collective Fit.
collectiveCoverageDisposition ::
     CollectiveStrategyRealizationComponents scope -> ComponentDisposition
collectiveCoverageDisposition components =
  case Internal.collectiveCoverageResult components of
    Internal.CollectiveCoverageUnavailable _ -> ComponentUnavailable
    Internal.CollectiveCoverageViolated _ -> ComponentInvalid
    Internal.CollectiveCoverageSatisfied _ -> ComponentSatisfied

-- | Return Strategies blocking contributor-coverage evaluation.
collectiveCoverageBlockingStrategies ::
     CollectiveStrategyRealizationComponents scope -> [ModelIdentity]
collectiveCoverageBlockingStrategies components =
  case Internal.collectiveCoverageResult components of
    Internal.CollectiveCoverageUnavailable blockers -> blockers
    _ -> []

-- | Enumerate macro-support assessments for every contributor.
collectiveMacroSupportAssessments ::
     CollectiveStrategyRealizationComponents scope -> [MacroSupportAssessment]
collectiveMacroSupportAssessments = Internal.collectiveMacroSupportResults

-- | Identify the contributor assessed for macro support.
macroSupportParticipant :: MacroSupportAssessment -> ModelIdentity
macroSupportParticipant assessment =
  case assessment of
    Internal.MacroSupportViolated _ participant _ -> participant
    Internal.MacroSupportSatisfied _ participant _ -> participant

-- | Classify one contributor's macro support.
macroSupportDisposition :: MacroSupportAssessment -> ComponentDisposition
macroSupportDisposition assessment =
  case assessment of
    Internal.MacroSupportViolated _ _ _ -> ComponentInvalid
    Internal.MacroSupportSatisfied _ _ _ -> ComponentSatisfied

-- | Return exact occurrences witnessing satisfied macro support.
macroSupportWitnesses :: MacroSupportAssessment -> [OccurrenceIdentity]
macroSupportWitnesses assessment =
  case assessment of
    Internal.MacroSupportViolated _ _ _ -> []
    Internal.MacroSupportSatisfied _ _ witnesses -> witnesses

-- | Enumerate primitive-support assessments for every contributor.
collectivePrimitiveSupportAssessments ::
     CollectiveStrategyRealizationComponents scope
  -> [ParticipantPrimitiveSupportAssessment]
collectivePrimitiveSupportAssessments =
  Internal.collectivePrimitiveSupportResults

-- | Identify the contributor assessed for primitive support.
primitiveSupportParticipant ::
     ParticipantPrimitiveSupportAssessment -> ModelIdentity
primitiveSupportParticipant assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportUnavailable _ participant _ _ ->
      participant
    Internal.ParticipantPrimitiveSupportViolated _ participant _ -> participant
    Internal.ParticipantPrimitiveSupportSatisfied _ participant _ -> participant

-- | Classify one contributor's primitive support.
primitiveSupportDisposition ::
     ParticipantPrimitiveSupportAssessment -> ComponentDisposition
primitiveSupportDisposition assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportUnavailable _ _ _ _ ->
      ComponentUnavailable
    Internal.ParticipantPrimitiveSupportViolated _ _ _ -> ComponentInvalid
    Internal.ParticipantPrimitiveSupportSatisfied _ _ _ -> ComponentSatisfied

-- | Return every reason primitive-support evaluation was unavailable.
primitiveSupportUnavailableReasons ::
     ParticipantPrimitiveSupportAssessment -> [CollectiveFitUnavailableReason]
primitiveSupportUnavailableReasons assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportUnavailable _ _ reasons _ ->
      NonEmpty.toList reasons
    _ -> []

-- | Return Strategies blocking primitive-support evaluation.
primitiveSupportBlockingStrategies ::
     ParticipantPrimitiveSupportAssessment -> [ModelIdentity]
primitiveSupportBlockingStrategies assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportUnavailable _ _ _ blockers -> blockers
    _ -> []

-- | Return exact occurrences witnessing satisfied primitive support.
primitiveSupportWitnesses ::
     ParticipantPrimitiveSupportAssessment -> [OccurrenceIdentity]
primitiveSupportWitnesses assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportSatisfied _ _ witnesses -> witnesses
    _ -> []

semanticResults :: SemanticAssessment scope -> Internal.SemanticResults scope
semanticResults (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsRejected _ results _ -> results
    Internal.SemanticsUnavailable results _ -> results
    Internal.SemanticsAccepted results _ -> results
