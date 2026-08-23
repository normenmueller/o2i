{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

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
  , foldSemanticAssessment
  , semanticCandidateOccurrences
  , acceptedSemanticModel
  , SemanticDiagnosticEvidence
  , SemanticEvidenceKind(..)
  , semanticDiagnosticRule
  , SemanticSubject
  , semanticDiagnosticSubjects
  , foldSemanticSubject
  , SemanticOccurrenceRole
  , SemanticOccurrenceGroup
  , semanticDiagnosticOccurrenceGroups
  , semanticOccurrenceGroupRole
  , semanticOccurrenceGroupOccurrences
  , semanticOccurrenceRoleId
  , semanticDiagnosticKind
  , semanticDiagnosticModelIdentities
  , semanticDiagnosticOccurrenceIdentities
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
import Data.Text (Text)
import O2I.Core.Contract (CoreRuleId)
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
semanticDisposition (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsRejected _ _ -> SemanticRejected
    Internal.SemanticsUnavailable _ -> SemanticUnavailable
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
    Internal.SemanticsRejected _ failures ->
      rejected (SemanticDiagnosticEvidence <$> failures)
    Internal.SemanticsUnavailable _ -> unavailable
    Internal.SemanticsAccepted _ model -> accepted model

-- | Return every Candidate occurrence retained during semantic assessment.
semanticCandidateOccurrences :: SemanticAssessment scope -> [OccurrenceIdentity]
semanticCandidateOccurrences =
  Internal.storedCandidateOccurrences . semanticResults

-- | Project the validated model only from an accepted semantic outcome.
acceptedSemanticModel ::
     SemanticAssessment scope -> Maybe (SemanticallyValidModel scope)
acceptedSemanticModel (SemanticAssessment assessment) =
  case assessment of
    Internal.SemanticsAccepted _ model -> Just model
    _ -> Nothing

-- | Identify the compiled Core rule carried by scoped semantic evidence.
semanticDiagnosticRule :: SemanticDiagnosticEvidence scope -> CoreRuleId
semanticDiagnosticRule (SemanticDiagnosticEvidence defect) =
  Internal.semanticRuleId (Internal.semanticDefectRule defect)

-- | One exact named subject retained by the semantic evidence key.
data SemanticSubject
  = SemanticModelSubject !Text !ModelIdentity
  | SemanticOccurrenceSubject !Text !OccurrenceIdentity

-- | Return every subject with its owner-defined role in admitted order.
semanticDiagnosticSubjects ::
     SemanticDiagnosticEvidence scope -> NonEmpty SemanticSubject
semanticDiagnosticSubjects (SemanticDiagnosticEvidence defect) =
  case Internal.semanticDefectEvidence defect of
    Internal.SemanticNeedKey need ->
      SemanticModelSubject "need" need NonEmpty.:| []
    Internal.SemanticNeedMemberKey need member ->
      SemanticModelSubject "need" need
        NonEmpty.:| [SemanticModelSubject "member" member]
    Internal.SemanticStrategyKey strategy ->
      SemanticModelSubject "strategy" strategy NonEmpty.:| []
    Internal.SemanticStrategyMemberKey strategy member ->
      SemanticModelSubject "strategy" strategy
        NonEmpty.:| [SemanticModelSubject "member" member]
    Internal.SemanticFitClaimKey claim ->
      SemanticModelSubject "claim" claim NonEmpty.:| []
    Internal.SemanticParticipantClaimKey claim participant ->
      SemanticModelSubject "claim" claim
        NonEmpty.:| [SemanticModelSubject "participant" participant]
    Internal.SemanticAssertedDependencyKey dependent endpoint context ->
      SemanticOccurrenceSubject "dependent" dependent
        NonEmpty.:| [ SemanticOccurrenceSubject "endpoint" endpoint
                    , SemanticOccurrenceSubject "context" context
                    ]

-- | Eliminate either exact semantic subject value without exposing constructors.
foldSemanticSubject ::
     (Text -> ModelIdentity -> result)
  -> (Text -> OccurrenceIdentity -> result)
  -> SemanticSubject
  -> result
foldSemanticSubject model occurrence subject =
  case subject of
    SemanticModelSubject role identity -> model role identity
    SemanticOccurrenceSubject role identity -> occurrence role identity

-- | Opaque, rule-local role of one semantic occurrence group.
newtype SemanticOccurrenceRole =
  SemanticOccurrenceRole Text

-- | Opaque named group of occurrences retained by its Core producer.
data SemanticOccurrenceGroup =
  SemanticOccurrenceGroup !SemanticOccurrenceRole ![OccurrenceIdentity]

-- | Return every named group in its admitted order, including empty groups.
--
-- Structural cardinality is fixed by the compiled Core companion. Concrete
-- graph membership and semantic relations remain guarantees of the opaque
-- producer path.
semanticDiagnosticOccurrenceGroups ::
     SemanticDiagnosticEvidence scope -> NonEmpty SemanticOccurrenceGroup
semanticDiagnosticOccurrenceGroups (SemanticDiagnosticEvidence defect) =
  projectGroup <$> Internal.semanticDefectOccurrenceGroups defect
  where
    projectGroup (role, occurrences) =
      SemanticOccurrenceGroup (SemanticOccurrenceRole role) occurrences

-- | Project the opaque role of one occurrence group.
semanticOccurrenceGroupRole :: SemanticOccurrenceGroup -> SemanticOccurrenceRole
semanticOccurrenceGroupRole (SemanticOccurrenceGroup role _) = role

-- | Project the exact canonical occurrences retained in one named group.
semanticOccurrenceGroupOccurrences ::
     SemanticOccurrenceGroup -> [OccurrenceIdentity]
semanticOccurrenceGroupOccurrences (SemanticOccurrenceGroup _ values) = values

-- | Return the admitted rule-local role identifier for serialization.
semanticOccurrenceRoleId :: SemanticOccurrenceRole -> Text
semanticOccurrenceRoleId (SemanticOccurrenceRole role) = role

-- | Classify the closed evidence-key shape without exposing its representation.
semanticDiagnosticKind ::
     SemanticDiagnosticEvidence scope -> SemanticEvidenceKind
semanticDiagnosticKind (SemanticDiagnosticEvidence defect) =
  semanticEvidenceKindValue (Internal.semanticDefectEvidence defect)

semanticEvidenceKindValue :: Internal.SemanticEvidence -> SemanticEvidenceKind
semanticEvidenceKindValue evidence =
  case evidence of
    Internal.SemanticNeedKey _ -> NeedEvidence
    Internal.SemanticNeedMemberKey _ _ -> NeedMemberEvidence
    Internal.SemanticStrategyKey _ -> StrategyEvidence
    Internal.SemanticStrategyMemberKey _ _ -> StrategyMemberEvidence
    Internal.SemanticFitClaimKey _ -> CollectiveEvidence
    Internal.SemanticParticipantClaimKey _ _ -> CollectiveParticipantEvidence
    Internal.SemanticAssertedDependencyKey _ _ _ -> AssertedDependencyEvidence

-- | Return model identities carried by one semantic evidence key.
semanticDiagnosticModelIdentities ::
     SemanticDiagnosticEvidence scope -> [ModelIdentity]
semanticDiagnosticModelIdentities (SemanticDiagnosticEvidence defect) =
  semanticEvidenceModelIdentitiesValue (Internal.semanticDefectEvidence defect)

semanticEvidenceModelIdentitiesValue ::
     Internal.SemanticEvidence -> [ModelIdentity]
semanticEvidenceModelIdentitiesValue evidence =
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
semanticDiagnosticOccurrenceIdentities ::
     SemanticDiagnosticEvidence scope -> [OccurrenceIdentity]
semanticDiagnosticOccurrenceIdentities (SemanticDiagnosticEvidence defect) =
  semanticEvidenceOccurrenceIdentitiesValue
    (Internal.semanticDefectEvidence defect)

semanticEvidenceOccurrenceIdentitiesValue ::
     Internal.SemanticEvidence -> [OccurrenceIdentity]
semanticEvidenceOccurrenceIdentitiesValue evidence =
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
    Internal.SemanticsRejected results _ -> results
    Internal.SemanticsUnavailable results -> results
    Internal.SemanticsAccepted results _ -> results
