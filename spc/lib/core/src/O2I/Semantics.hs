-- | Public Core Semantics boundary.
--
-- Assessments and proofs are opaque. Consumers can inspect deterministic
-- dispositions, subjects, defects, blockers, and witness occurrences without
-- constructing semantic authority or traversing the graph generically.
module O2I.Semantics
  ( SemanticAssessment
  , SemanticDisposition(..)
  , assessSemantics
  , semanticDisposition
  , semanticDefects
  , semanticCandidateOccurrences
  , acceptedSemanticModel
  , SemanticDefect
  , SemanticEvidence
  , SemanticEvidenceKind(..)
  , semanticDefectRule
  , semanticDefectEvidence
  , semanticDefectWitnesses
  , semanticEvidenceKind
  , semanticEvidenceModelIdentities
  , semanticEvidenceOccurrenceIdentities
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
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Semantics.Eval (assessSemantics)
import O2I.Semantics.Internal
  ( CollectiveFitUnavailableReason(..)
  , CollectiveStrategyRealizationAssessment
  , CollectiveStrategyRealizationComponents
  , GloballySituatedNeed
  , MacroSupportAssessment
  , ParticipantPrimitiveSupportAssessment
  , QualificationEligibleStrategy
  , SemanticAssessment
  , SemanticDefect
  , SemanticEvidence
  , SemanticallyValidModel
  , SituatedNeedAssessment
  , StrategyFormulationAssessment
  , StrategyFormulationUnavailableReason(..)
  , ValidatedCollectiveStrategyRealization
  )
import qualified O2I.Semantics.Internal as Internal

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

-- | Closed public classification of one semantic evidence key.
data SemanticEvidenceKind
  = NeedEvidence
  | NeedMemberEvidence
  | StrategyEvidence
  | StrategyMemberEvidence
  | CollectiveEvidence
  | CollectiveParticipantEvidence
  | AssertedDependencyEvidence
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify the aggregate semantic outcome without exposing its proof data.
semanticDisposition :: SemanticAssessment scope -> SemanticDisposition
semanticDisposition assessment =
  case assessment of
    Internal.SemanticsRejected _ _ -> SemanticRejected
    Internal.SemanticsUnavailable _ -> SemanticUnavailable
    Internal.SemanticsAccepted _ _ -> SemanticAccepted

-- | Return every semantic defect when the aggregate outcome is rejected.
semanticDefects :: SemanticAssessment scope -> [SemanticDefect]
semanticDefects assessment =
  case assessment of
    Internal.SemanticsRejected _ failures -> NonEmpty.toList failures
    _ -> []

-- | Return every Candidate occurrence retained during semantic assessment.
semanticCandidateOccurrences :: SemanticAssessment scope -> [OccurrenceIdentity]
semanticCandidateOccurrences =
  Internal.storedCandidateOccurrences . semanticResults

-- | Project the validated model only from an accepted semantic outcome.
acceptedSemanticModel ::
     SemanticAssessment scope -> Maybe (SemanticallyValidModel scope)
acceptedSemanticModel assessment =
  case assessment of
    Internal.SemanticsAccepted _ model -> Just model
    _ -> Nothing

-- | Identify the compiled Core rule violated by one semantic defect.
semanticDefectRule :: SemanticDefect -> CoreRuleId
semanticDefectRule = Internal.semanticRuleId . Internal.semanticDefectRule

-- | Project the typed evidence key for one semantic defect.
semanticDefectEvidence :: SemanticDefect -> SemanticEvidence
semanticDefectEvidence = Internal.semanticDefectEvidence

-- | Return the exact graph occurrences witnessing one semantic defect.
semanticDefectWitnesses :: SemanticDefect -> [OccurrenceIdentity]
semanticDefectWitnesses = Internal.semanticDefectWitnesses

-- | Classify the closed evidence-key shape without exposing its representation.
semanticEvidenceKind :: SemanticEvidence -> SemanticEvidenceKind
semanticEvidenceKind evidence =
  case evidence of
    Internal.SemanticNeedKey _ -> NeedEvidence
    Internal.SemanticNeedMemberKey _ _ -> NeedMemberEvidence
    Internal.SemanticStrategyKey _ -> StrategyEvidence
    Internal.SemanticStrategyMemberKey _ _ -> StrategyMemberEvidence
    Internal.SemanticFitClaimKey _ -> CollectiveEvidence
    Internal.SemanticParticipantClaimKey _ _ -> CollectiveParticipantEvidence
    Internal.SemanticAssertedDependencyKey _ _ _ -> AssertedDependencyEvidence

-- | Return model identities carried by one semantic evidence key.
semanticEvidenceModelIdentities :: SemanticEvidence -> [ModelIdentity]
semanticEvidenceModelIdentities evidence =
  case evidence of
    Internal.SemanticNeedKey need -> [need]
    Internal.SemanticNeedMemberKey need member -> [need, member]
    Internal.SemanticStrategyKey strategy -> [strategy]
    Internal.SemanticStrategyMemberKey strategy member -> [strategy, member]
    Internal.SemanticFitClaimKey claim -> [claim]
    Internal.SemanticParticipantClaimKey claim participant ->
      [claim, participant]
    Internal.SemanticAssertedDependencyKey _ _ _ -> []

-- | Return occurrence identities carried by asserted-dependency evidence.
semanticEvidenceOccurrenceIdentities :: SemanticEvidence -> [OccurrenceIdentity]
semanticEvidenceOccurrenceIdentities evidence =
  case evidence of
    Internal.SemanticAssertedDependencyKey dependent endpoint context ->
      [dependent, endpoint, context]
    _ -> []

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

-- | Enumerate every proven qualification-eligible Strategy.
semanticallyValidStrategies ::
     SemanticallyValidModel scope -> [QualificationEligibleStrategy scope]
semanticallyValidStrategies = Internal.semanticModelEligibleStrategies

-- | Enumerate every validated collective Strategy realization.
semanticallyValidCollectiveRealizations ::
     SemanticallyValidModel scope
  -> [ValidatedCollectiveStrategyRealization scope]
semanticallyValidCollectiveRealizations =
  Internal.semanticModelCollectiveRealizations

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
    Internal.MacroSupportViolated _ participant -> participant
    Internal.MacroSupportSatisfied _ participant _ -> participant

-- | Classify one contributor's macro support.
macroSupportDisposition :: MacroSupportAssessment -> ComponentDisposition
macroSupportDisposition assessment =
  case assessment of
    Internal.MacroSupportViolated _ _ -> ComponentInvalid
    Internal.MacroSupportSatisfied _ _ _ -> ComponentSatisfied

-- | Return exact occurrences witnessing satisfied macro support.
macroSupportWitnesses :: MacroSupportAssessment -> [OccurrenceIdentity]
macroSupportWitnesses assessment =
  case assessment of
    Internal.MacroSupportViolated _ _ -> []
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
    Internal.ParticipantPrimitiveSupportViolated _ participant -> participant
    Internal.ParticipantPrimitiveSupportSatisfied _ participant _ -> participant

-- | Classify one contributor's primitive support.
primitiveSupportDisposition ::
     ParticipantPrimitiveSupportAssessment -> ComponentDisposition
primitiveSupportDisposition assessment =
  case assessment of
    Internal.ParticipantPrimitiveSupportUnavailable _ _ _ _ ->
      ComponentUnavailable
    Internal.ParticipantPrimitiveSupportViolated _ _ -> ComponentInvalid
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
semanticResults assessment =
  case assessment of
    Internal.SemanticsRejected results _ -> results
    Internal.SemanticsUnavailable results -> results
    Internal.SemanticsAccepted results _ -> results
