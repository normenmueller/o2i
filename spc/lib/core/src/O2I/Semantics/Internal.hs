{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Internal result algebra of Core semantic assessment.
module O2I.Semantics.Internal
  ( SemanticRule
  , semanticRule
  , semanticRuleIdentity
  , semanticRules
  , semanticRuleId
  , semanticRuleRank
  , SemanticEvidence(..)
  , SemanticEvidenceKey(..)
  , SemanticOccurrenceEvidence
  , SemanticDefect
  , mkSemanticDefect
  , semanticDefectRule
  , semanticDefectEvidence
  , semanticDefectOccurrenceGroups
  , sortSemanticDefects
  , StrategyFormulationUnavailableReason(..)
  , StrategyFormulationAssessment(..)
  , GloballySituatedNeed(..)
  , SituatedNeedAssessment(..)
  , CollectiveFitUnavailableReason(..)
  , CollectiveFitAssessment(..)
  , CollectiveCompletenessAssessment(..)
  , CollectiveCoverageAssessment(..)
  , MacroSupportAssessment(..)
  , ParticipantPrimitiveSupportAssessment(..)
  , CollectiveStrategyRealizationComponents(..)
  , CollectiveStrategyRealizationAssessment(..)
  , QualificationEligibleStrategy(..)
  , ValidatedCollectiveStrategyRealization(..)
  , SemanticallyValidModel(..)
  , semanticallyValidModelGraphIdentity
  , SemanticResults(..)
  , SemanticAssessment(..)
  , semanticAssessmentMatchesGraph
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract (CoreRuleId)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types (CollectiveFitInput, StrategyFormulationInput)
import O2I.Structure (WellFormedGraph)
import O2I.Structure.Internal (sameWellFormedGraph, wellFormedGraphIdentity)

-- | Existential projection of one generated schema-indexed semantic rule.
newtype SemanticRule =
  SemanticRule Generated.GeneratedSemanticRuleIdentity

-- | Existentially project one generated semantic rule.
semanticRule ::
     Generated.GeneratedSemanticRule schema occurrenceSchema -> SemanticRule
semanticRule = SemanticRule . Generated.generatedSemanticRuleIdentity

-- | Project one generated semantic rule identity.
semanticRuleIdentity :: Generated.GeneratedSemanticRuleIdentity -> SemanticRule
semanticRuleIdentity = SemanticRule

instance Eq SemanticRule where
  left == right = semanticRuleRank left == semanticRuleRank right

instance Ord SemanticRule where
  compare left right = compare (semanticRuleRank left) (semanticRuleRank right)

instance Show SemanticRule where
  showsPrec precedence rule = showsPrec precedence (semanticRuleId rule)

-- | Complete canonical semantic rule inventory.
semanticRules :: NonEmpty SemanticRule
semanticRules = SemanticRule <$> Generated.generatedSemanticRuleIdentities

-- | Project the exact compiled-contract provenance of one semantic rule.
semanticRuleId :: SemanticRule -> CoreRuleId
semanticRuleId (SemanticRule rule) =
  CoreRuleId (Generated.generatedSemanticRuleIdentityText rule)

-- | Rank one semantic rule by the exact compiled companion inventory.
semanticRuleRank :: SemanticRule -> Int
semanticRuleRank (SemanticRule rule) =
  Generated.generatedSemanticRuleIdentityRank rule

-- | Exact rule-bound semantic evidence key.
data SemanticEvidence
  = SemanticNeedKey !ModelIdentity
  | SemanticNeedMemberKey !ModelIdentity !ModelIdentity
  | SemanticStrategyKey !ModelIdentity
  | SemanticStrategyMemberKey !ModelIdentity !ModelIdentity
  | SemanticFitClaimKey !ModelIdentity
  | SemanticParticipantClaimKey !ModelIdentity !ModelIdentity
  | SemanticAssertedDependencyKey
      !OccurrenceIdentity
      !OccurrenceIdentity
      !OccurrenceIdentity
  deriving (Eq, Ord, Show)

-- | Private evidence key indexed by its generated schema.
data SemanticEvidenceKey schema where
  SemanticNeedEvidenceKey
    :: !ModelIdentity -> SemanticEvidenceKey 'Generated.GeneratedNeedKeySchema
  SemanticNeedMemberEvidenceKey
    :: !ModelIdentity
    -> !ModelIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedNeedMemberKeySchema
  SemanticStrategyEvidenceKey
    :: !ModelIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedStrategyKeySchema
  SemanticStrategyMemberEvidenceKey
    :: !ModelIdentity
    -> !ModelIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedStrategyMemberKeySchema
  SemanticFitClaimEvidenceKey
    :: !ModelIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedFitClaimKeySchema
  SemanticParticipantClaimEvidenceKey
    :: !ModelIdentity
    -> !ModelIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedParticipantClaimKeySchema
  SemanticAssertedDependencyEvidenceKey
    :: !OccurrenceIdentity
    -> !OccurrenceIdentity
    -> !OccurrenceIdentity
    -> SemanticEvidenceKey 'Generated.GeneratedAssertedDependencyKeySchema

-- | Sole production instantiation of generated occurrence evidence.
type SemanticOccurrenceEvidence schema
  = Generated.GeneratedSemanticOccurrenceEvidence schema OccurrenceIdentity

-- | One deterministic defect whose rule and evidence schemas coincide.
data SemanticDefect where
  SemanticDefectInternal
    :: !(Generated.GeneratedSemanticRule schema occurrenceSchema)
    -> !(SemanticEvidenceKey schema)
    -> !(SemanticOccurrenceEvidence occurrenceSchema)
    -> SemanticDefect

-- | Construct a defect only from a rule and evidence key of the same schema.
mkSemanticDefect ::
     Generated.GeneratedSemanticRule schema occurrenceSchema
  -> SemanticEvidenceKey schema
  -> SemanticOccurrenceEvidence occurrenceSchema
  -> SemanticDefect
mkSemanticDefect = SemanticDefectInternal

-- | Project the closed semantic rule carried by a defect.
semanticDefectRule :: SemanticDefect -> SemanticRule
semanticDefectRule (SemanticDefectInternal rule _ _) = semanticRule rule

-- | Erase the private schema index for the stable public evidence projection.
semanticDefectEvidence :: SemanticDefect -> SemanticEvidence
semanticDefectEvidence (SemanticDefectInternal _ evidence _) =
  eraseSemanticEvidenceKey evidence

-- | Project every named occurrence group without positional reconstruction.
semanticDefectOccurrenceGroups ::
     SemanticDefect -> NonEmpty (Text, [OccurrenceIdentity])
semanticDefectOccurrenceGroups (SemanticDefectInternal _ _ occurrences) =
  Generated.generatedSemanticOccurrenceEvidenceGroups occurrences

eraseSemanticEvidenceKey :: SemanticEvidenceKey schema -> SemanticEvidence
eraseSemanticEvidenceKey evidence =
  case evidence of
    SemanticNeedEvidenceKey need -> SemanticNeedKey need
    SemanticNeedMemberEvidenceKey need member ->
      SemanticNeedMemberKey need member
    SemanticStrategyEvidenceKey strategy -> SemanticStrategyKey strategy
    SemanticStrategyMemberEvidenceKey strategy member ->
      SemanticStrategyMemberKey strategy member
    SemanticFitClaimEvidenceKey claim -> SemanticFitClaimKey claim
    SemanticParticipantClaimEvidenceKey claim participant ->
      SemanticParticipantClaimKey claim participant
    SemanticAssertedDependencyEvidenceKey dependent endpoint context ->
      SemanticAssertedDependencyKey dependent endpoint context

instance Eq SemanticDefect where
  left == right = semanticDefectOrderKey left == semanticDefectOrderKey right

instance Ord SemanticDefect where
  compare left right =
    compare (semanticDefectOrderKey left) (semanticDefectOrderKey right)

instance Show SemanticDefect where
  showsPrec precedence defect =
    showsPrec
      precedence
      ( semanticDefectRule defect
      , semanticDefectEvidence defect
      , semanticDefectOccurrenceGroups defect)

-- | Sort defects by compiled rule order and exact canonical evidence.
sortSemanticDefects :: [SemanticDefect] -> [SemanticDefect]
sortSemanticDefects = sortOn semanticDefectOrderKey

semanticDefectOrderKey ::
     SemanticDefect
  -> (Int, SemanticEvidence, NonEmpty (Text, [OccurrenceIdentity]))
semanticDefectOrderKey defect =
  ( semanticRuleRank (semanticDefectRule defect)
  , semanticDefectEvidence defect
  , semanticDefectOccurrenceGroups defect)

-- | Closed reason why one Strategy formulation cannot be assessed.
data StrategyFormulationUnavailableReason
  = StrategyFormulationInputMissing
  | StrategyFormulationIdentityUnresolved
  deriving (Bounded, Enum, Eq, Ord, Show)

type role QualificationEligibleStrategy nominal

-- | Opaque proof that one Strategy has a complete valid formulation.
data QualificationEligibleStrategy scope = QualificationEligibleStrategy
  { eligibleStrategyGraphIdentity :: !ModelIdentity
  , eligibleStrategyIdentity :: !ModelIdentity
  , eligibleStrategyOccurrence :: !OccurrenceIdentity
  , eligibleStrategyInput :: !StrategyFormulationInput
  , eligibleStrategyWitnesses :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Complete outcome for one asserted Strategy.
data StrategyFormulationAssessment scope
  = StrategyFormulationUnavailable
      !ModelIdentity
      !StrategyFormulationUnavailableReason
  | StrategyFormulationCandidate !ModelIdentity !OccurrenceIdentity
  | StrategyFormulationInvalid !ModelIdentity !(NonEmpty SemanticDefect)
  | StrategyFormulationValid !(QualificationEligibleStrategy scope)
  deriving (Eq, Show)

type role GloballySituatedNeed nominal

-- | Opaque proof that one asserted Need is globally situated.
data GloballySituatedNeed scope = GloballySituatedNeed
  { situatedNeedIdentity :: !ModelIdentity
  , situatedNeedOccurrence :: !OccurrenceIdentity
  , situatedNeedWitnesses :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Complete outcome for one asserted Need.
data SituatedNeedAssessment scope
  = SituatedNeedCandidate !ModelIdentity !OccurrenceIdentity
  | SituatedNeedInvalid !ModelIdentity !(NonEmpty SemanticDefect)
  | SituatedNeedValid !(GloballySituatedNeed scope)
  deriving (Eq, Show)

-- | Closed prerequisite failure of collective Fit or support assessment.
data CollectiveFitUnavailableReason
  = CollectiveFitInputMissing
  | CollectiveFitIdentityUnresolved
  | ParticipantStrategyFormulationUnavailable
  | ParticipantStrategyFormulationInvalid
  | TargetStrategyFormulationUnavailable
  | TargetStrategyFormulationInvalid
  deriving (Bounded, Enum, Eq, Ord, Show)

type role ValidatedCollectiveStrategyRealization nominal

-- | Opaque proof of one asserted, complete, supported collective realization.
data ValidatedCollectiveStrategyRealization scope = ValidatedCollectiveStrategyRealization
  { validatedCollectiveClaim :: !ModelIdentity
  , validatedCollectiveInput :: !CollectiveFitInput
  , validatedCollectiveWitnesses :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Complete semantic outcome for one structured proposition.
data CollectiveFitAssessment
  = CollectiveFitUnavailable
      !(NonEmpty CollectiveFitUnavailableReason)
      ![ModelIdentity]
  | CollectiveFitInvalid !(NonEmpty SemanticDefect)
  | CollectiveFitSatisfied !CollectiveFitInput ![OccurrenceIdentity]
  deriving (Eq, Show)

-- | Asserted participant-completeness result of one collective proposition.
data CollectiveCompletenessAssessment
  = CollectiveCompletenessViolated !SemanticDefect
  | CollectiveCompletenessSatisfied
  deriving (Eq, Show)

-- | Target-formulation coverage result of one collective proposition.
data CollectiveCoverageAssessment
  = CollectiveCoverageUnavailable ![ModelIdentity]
  | CollectiveCoverageViolated !SemanticDefect
  | CollectiveCoverageSatisfied ![OccurrenceIdentity]
  deriving (Eq, Show)

-- | Macro-support result for exactly one participant.
data MacroSupportAssessment
  = MacroSupportViolated !ModelIdentity !ModelIdentity !SemanticDefect
  | MacroSupportSatisfied !ModelIdentity !ModelIdentity ![OccurrenceIdentity]
  deriving (Eq, Show)

-- | Primitive-support result for exactly one participant.
data ParticipantPrimitiveSupportAssessment
  = ParticipantPrimitiveSupportUnavailable
      !ModelIdentity
      !ModelIdentity
      !(NonEmpty CollectiveFitUnavailableReason)
      ![ModelIdentity]
  | ParticipantPrimitiveSupportViolated
      !ModelIdentity
      !ModelIdentity
      !SemanticDefect
  | ParticipantPrimitiveSupportSatisfied
      !ModelIdentity
      !ModelIdentity
      ![OccurrenceIdentity]
  deriving (Eq, Show)

-- | Separately inspectable results required by one asserted collective claim.
data CollectiveStrategyRealizationComponents scope = CollectiveStrategyRealizationComponents
  { collectiveCompletenessResult :: !CollectiveCompletenessAssessment
  , collectiveFitResult :: !CollectiveFitAssessment
  , collectiveCoverageResult :: !CollectiveCoverageAssessment
  , collectiveMacroSupportResults :: ![MacroSupportAssessment]
  , collectivePrimitiveSupportResults :: ![ParticipantPrimitiveSupportAssessment]
  } deriving (Eq, Show)

-- | Complete semantic outcome for one structured proposition.
data CollectiveStrategyRealizationAssessment scope
  = CollectiveStrategyRealizationCandidate !ModelIdentity !OccurrenceIdentity
  | CollectiveStrategyRealizationUnavailable
      !ModelIdentity
      !(CollectiveStrategyRealizationComponents scope)
  | CollectiveStrategyRealizationInvalid
      !ModelIdentity
      !(CollectiveStrategyRealizationComponents scope)
      !(NonEmpty SemanticDefect)
  | CollectiveStrategyRealizationValid
      !(ValidatedCollectiveStrategyRealization scope)
      !(CollectiveStrategyRealizationComponents scope)
  deriving (Eq, Show)

type role SemanticallyValidModel nominal

-- | Opaque selected-View model whose model-internal Core Semantics is valid.
data SemanticallyValidModel scope = SemanticallyValidModel
  { semanticModelGraph :: !(WellFormedGraph scope)
  , semanticModelSituatedNeeds :: ![GloballySituatedNeed scope]
  }

-- | Project the exact selected View identity from the retained proof spine.
semanticallyValidModelGraphIdentity ::
     SemanticallyValidModel scope -> ModelIdentity
semanticallyValidModelGraphIdentity =
  wellFormedGraphIdentity . semanticModelGraph

instance Eq (SemanticallyValidModel scope) where
  left == right =
    semanticModelGraph left == semanticModelGraph right
      && semanticModelSituatedNeeds left == semanticModelSituatedNeeds right

instance Show (SemanticallyValidModel scope) where
  showsPrec precedence model =
    showParen (precedence > 10)
      $ showString "SemanticallyValidModel "
          . showsPrec 11 (semanticModelGraph model)
          . showChar ' '
          . showsPrec 11 (semanticModelSituatedNeeds model)

-- | Complete subject-local results retained by every aggregate outcome.
data SemanticResults scope = SemanticResults
  { storedSituatedNeedAssessments :: ![SituatedNeedAssessment scope]
  , storedStrategyAssessments :: ![StrategyFormulationAssessment scope]
  , storedCollectiveAssessments :: ![CollectiveStrategyRealizationAssessment
                                       scope]
  , storedCandidateOccurrences :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Complete semantic assessment with deterministic rejection precedence.
data SemanticAssessment scope
  = SemanticsRejected
      !(WellFormedGraph scope)
      !(SemanticResults scope)
      !(NonEmpty SemanticDefect)
  | SemanticsUnavailable
      !(SemanticResults scope)
      !(SemanticallyValidModel scope)
  | SemanticsAccepted !(SemanticResults scope) !(SemanticallyValidModel scope)
  deriving (Eq, Show)

-- | Decide whether an assessment came from this exact selected-View graph.
semanticAssessmentMatchesGraph ::
     WellFormedGraph scope -> SemanticAssessment scope -> Bool
semanticAssessmentMatchesGraph graph assessment =
  sameWellFormedGraph graph producingGraph
  where
    producingGraph =
      case assessment of
        SemanticsRejected rejectedGraph _ _ -> rejectedGraph
        SemanticsUnavailable _ model -> semanticModelGraph model
        SemanticsAccepted _ model -> semanticModelGraph model
