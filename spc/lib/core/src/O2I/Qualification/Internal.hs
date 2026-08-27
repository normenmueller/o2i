{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private algebra for Core Need qualification.
module O2I.Qualification.Internal
  ( QualificationRole(..)
  , qualificationRoleIdValue
  , qualificationRoleRank
  , QualificationReferenceInput(..)
  , QualificationSourceInput(..)
  , QualificationProposalInput(..)
  , QualificationNeedSelector(..)
  , QualificationStrategySelector(..)
  , QualificationSubjectCategory(..)
  , QualificationSubjectEligibility(..)
  , QualificationSubject(..)
  , QualificationSubjects(..)
  , QualificationSubjectUnavailableReason(..)
  , QualificationSubjectUnavailable(..)
  , QualificationRule(..)
  , qualificationRuleId
  , qualificationRuleRank
  , QualificationEvidence(..)
  , QualificationOccurrenceGroup(..)
  , QualificationDefect(..)
  , qualificationDefectOrderKey
  , AdmissibleQualificationProposal(..)
  , QualificationProposalAssessment(..)
  , QualificationPairAssessment(..)
  , QualificationAssessment(..)
  , QualificationWork(..)
  , emptyQualificationWork
  , addQualificationWork
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreQualificationProposalRoleId
  , CoreQualifiedEndpointId
  , CoreRuleId
  , coreQualificationProposalRoleIdText
  )
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)

-- | Closed semantic role order of a Need qualification proposal.
data QualificationRole
  = QualificationNeedRole
  | QualificationStrategyRole
  | QualificationKeyResultRole
  | QualificationObjectiveRole
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Recover the exact compiled role identifier retained at the input edge.
qualificationRoleIdValue ::
     CoreQualificationProposalRoleId -> Maybe QualificationRole
qualificationRoleIdValue role =
  case coreQualificationProposalRoleIdText role of
    "need-qualification-proposal.role.need" -> Just QualificationNeedRole
    "need-qualification-proposal.role.strategy" ->
      Just QualificationStrategyRole
    "need-qualification-proposal.role.key-result" ->
      Just QualificationKeyResultRole
    "need-qualification-proposal.role.objective" ->
      Just QualificationObjectiveRole
    _ -> Nothing

qualificationRoleRank :: QualificationRole -> Int
qualificationRoleRank = fromEnum

-- | One Profile-resolved role reference at the notation-neutral Core edge.
data QualificationReferenceInput = QualificationReferenceInput
  { storedQualificationReferenceOccurrence :: !OccurrenceIdentity
  , storedQualificationReferenceRole :: !CoreQualificationProposalRoleId
  , storedQualificationReferenceTarget :: !OccurrenceIdentity
  } deriving (Eq, Ord, Show)

-- | One normalized source identity and its exact source occurrence.
data QualificationSourceInput = QualificationSourceInput
  { storedQualificationSourceOccurrence :: !OccurrenceIdentity
  , storedQualificationSourceText :: !Text
  } deriving (Eq, Ord, Show)

-- | One projected proposal retained outside the effect graph.
data QualificationProposalInput = QualificationProposalInput
  { storedQualificationProposalOccurrence :: !OccurrenceIdentity
  , storedQualificationProposalIdentity :: !ModelIdentity
  , storedQualificationProposalRationale :: !(Maybe Text)
  , storedQualificationProposalSources :: ![QualificationSourceInput]
  , storedQualificationProposalReferences :: ![QualificationReferenceInput]
  } deriving (Eq, Show)

-- | Closed Need selector; its expected kind is fixed by the constructor type.
newtype QualificationNeedSelector = QualificationNeedSelector
  { storedQualificationNeedSelectorIdentity :: ModelIdentity
  } deriving (Eq, Ord, Show)

-- | Closed Strategy selector; its expected kind is fixed by the constructor type.
newtype QualificationStrategySelector = QualificationStrategySelector
  { storedQualificationStrategySelectorIdentity :: ModelIdentity
  } deriving (Eq, Ord, Show)

-- | Canonical selector and subject category order.
data QualificationSubjectCategory
  = QualificationNeedCategory
  | QualificationStrategyCategory
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed semantic eligibility disposition for discovery.
data QualificationSubjectEligibility
  = QualificationSubjectEligible
  | QualificationSubjectIneligible
  | QualificationSubjectEligibilityUnavailable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One fixed discovery subject with Core-owned type and eligibility.
data QualificationSubject = QualificationSubject
  { storedQualificationSubjectIdentity :: !ModelIdentity
  , storedQualificationSubjectOccurrence :: !OccurrenceIdentity
  , storedQualificationSubjectQualifiedEndpoint :: !CoreQualifiedEndpointId
  , storedQualificationSubjectEligibility :: !QualificationSubjectEligibility
  } deriving (Eq, Ord, Show)

type role QualificationSubjects nominal

-- | Canonical fixed Need and Strategy discovery result for one selected View.
data QualificationSubjects scope = QualificationSubjects
  { storedQualificationNeedSubjects :: ![QualificationSubject]
  , storedQualificationStrategySubjects :: ![QualificationSubject]
  } deriving (Eq, Show)

-- | Closed reason why qualification cannot materialize requested pairs.
data QualificationSubjectUnavailableReason
  = QualificationSelectorUnknown
  | QualificationSelectorAmbiguous
  | QualificationSelectorOutOfSelectedView
  | QualificationSelectorWrongTypeOrFamily
  | QualificationEligibilityPrerequisiteUnavailable
  deriving (Bounded, Enum, Eq, Ord, Show)

type role QualificationSubjectUnavailable nominal

-- | Opaque capability-specific selector or eligibility unavailability.
data QualificationSubjectUnavailable scope = QualificationSubjectUnavailable
  { storedQualificationUnavailableCategory :: !QualificationSubjectCategory
  , storedQualificationUnavailableIdentity :: !ModelIdentity
  , storedQualificationUnavailableReason :: !QualificationSubjectUnavailableReason
  , storedQualificationUnavailableOccurrences :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Closed evaluator rule vocabulary in compiled qualification-stage order.
data QualificationRule
  = PairProposalPresenceRule
  | ProposalEffectGraphMembershipRule
  | ProposalExistingMacroQualificationRule
  | ProposalExistingPrimitiveSupportRule
  | ProposalKeyResultContextRule
  | ProposalListedKeyResultRule
  | ProposalNeedEligibilityRule
  | ProposalObjectiveContextRule
  | ProposalRationaleRule
  | ProposalKeyResultCardinalityRule
  | ProposalKeyResultTargetRule
  | ProposalNeedCardinalityRule
  | ProposalNeedTargetRule
  | ProposalObjectiveCardinalityRule
  | ProposalObjectiveTargetRule
  | ProposalStrategyCardinalityRule
  | ProposalStrategyTargetRule
  | ProposalSelectedNeedRule
  | ProposalSelectedStrategyRule
  | ProposalSourcesRule
  | ProposalStrategyEligibilityRule
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact compiled Core rule identity selected by one closed constructor.
qualificationRuleId :: QualificationRule -> CoreRuleId
qualificationRuleId rule =
  CoreRuleId
    $ case rule of
        PairProposalPresenceRule -> "core.qualification.pair.proposal-presence"
        ProposalEffectGraphMembershipRule ->
          "core.qualification.proposal.effect-graph-membership"
        ProposalExistingMacroQualificationRule ->
          "core.qualification.proposal.existing-macro-qualification"
        ProposalExistingPrimitiveSupportRule ->
          "core.qualification.proposal.existing-primitive-support"
        ProposalKeyResultContextRule ->
          "core.qualification.proposal.key-result-context"
        ProposalListedKeyResultRule ->
          "core.qualification.proposal.listed-key-result"
        ProposalNeedEligibilityRule ->
          "core.qualification.proposal.need-eligibility"
        ProposalObjectiveContextRule ->
          "core.qualification.proposal.objective-context"
        ProposalRationaleRule -> "core.qualification.proposal.rationale"
        ProposalKeyResultCardinalityRule ->
          "core.qualification.proposal.role.key-result.cardinality"
        ProposalKeyResultTargetRule ->
          "core.qualification.proposal.role.key-result.target"
        ProposalNeedCardinalityRule ->
          "core.qualification.proposal.role.need.cardinality"
        ProposalNeedTargetRule -> "core.qualification.proposal.role.need.target"
        ProposalObjectiveCardinalityRule ->
          "core.qualification.proposal.role.objective.cardinality"
        ProposalObjectiveTargetRule ->
          "core.qualification.proposal.role.objective.target"
        ProposalStrategyCardinalityRule ->
          "core.qualification.proposal.role.strategy.cardinality"
        ProposalStrategyTargetRule ->
          "core.qualification.proposal.role.strategy.target"
        ProposalSelectedNeedRule -> "core.qualification.proposal.selected-need"
        ProposalSelectedStrategyRule ->
          "core.qualification.proposal.selected-strategy"
        ProposalSourcesRule -> "core.qualification.proposal.sources"
        ProposalStrategyEligibilityRule ->
          "core.qualification.proposal.strategy-eligibility"

qualificationRuleRank :: QualificationRule -> Int
qualificationRuleRank = fromEnum

-- | Exact evidence key schema selected by a qualification rule.
data QualificationEvidence
  = QualificationProposalKey !ModelIdentity
  | QualificationProposalRoleKey !ModelIdentity !QualificationRole
  | QualificationProposalRoleTargetKey
      !ModelIdentity
      !QualificationRole
      !OccurrenceIdentity
  | QualificationSelectedNeedKey !ModelIdentity
  | QualificationSelectedStrategyKey !ModelIdentity
  | QualificationPairKey !ModelIdentity !ModelIdentity
  | QualificationProposalRelationKey !ModelIdentity !Text
  deriving (Eq, Ord, Show)

-- | One exact named occurrence group retained by Core evidence.
data QualificationOccurrenceGroup = QualificationOccurrenceGroup
  { storedQualificationOccurrenceRole :: !Text
  , storedQualificationOccurrenceValues :: ![OccurrenceIdentity]
  } deriving (Eq, Ord, Show)

-- | One schema-bound deterministic qualification defect.
data QualificationDefect = QualificationDefect
  { storedQualificationDefectRule :: !QualificationRule
  , storedQualificationDefectEvidence :: !QualificationEvidence
  , storedQualificationDefectOccurrences :: !(NonEmpty
                                                QualificationOccurrenceGroup)
  } deriving (Eq, Show)

qualificationDefectOrderKey ::
     QualificationDefect
  -> (Int, QualificationEvidence, NonEmpty QualificationOccurrenceGroup)
qualificationDefectOrderKey defect =
  ( qualificationRuleRank (storedQualificationDefectRule defect)
  , storedQualificationDefectEvidence defect
  , storedQualificationDefectOccurrences defect)

-- | Opaque formal-admissibility proof. It is not acceptance or persistence.
type role AdmissibleQualificationProposal nominal

data AdmissibleQualificationProposal scope = AdmissibleQualificationProposal
  { storedAdmissibleProposalIdentity :: !ModelIdentity
  , storedAdmissibleProposalOccurrence :: !OccurrenceIdentity
  , storedAdmissibleNeedIdentity :: !ModelIdentity
  , storedAdmissibleStrategyIdentity :: !ModelIdentity
  , storedAdmissibleKeyResultIdentity :: !ModelIdentity
  , storedAdmissibleObjectiveIdentity :: !ModelIdentity
  , storedAdmissibleRationale :: !Text
  , storedAdmissibleSources :: !(NonEmpty Text)
  , storedAdmissibleWitnesses :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

type role QualificationProposalAssessment nominal

-- | Complete formal result for one routed or unrouted proposal.
data QualificationProposalAssessment scope
  = QualificationProposalUnrouted
      !ModelIdentity
      !OccurrenceIdentity
      !(NonEmpty QualificationDefect)
  | QualificationProposalInvalid
      !ModelIdentity
      !OccurrenceIdentity
      !(NonEmpty QualificationDefect)
  | QualificationProposalAdmissible !(AdmissibleQualificationProposal scope)
  deriving (Eq, Show)

type role QualificationPairAssessment nominal

-- | Exactly one precedence-selected outcome for one requested pair.
data QualificationPairAssessment scope
  = QualificationPairInvalidSubjects
      !ModelIdentity
      !ModelIdentity
      !(NonEmpty QualificationDefect)
  | QualificationPairMissingProposal
      !ModelIdentity
      !ModelIdentity
      !QualificationDefect
  | QualificationPairProposals
      !ModelIdentity
      !ModelIdentity
      !(NonEmpty (QualificationProposalAssessment scope))
  deriving (Eq, Show)

type role QualificationAssessment nominal

-- | Complete deterministic qualification result for one selected View.
data QualificationAssessment scope = QualificationAssessment
  { storedQualificationGraphIdentity :: !ModelIdentity
  , storedQualificationSelectedNeeds :: ![ModelIdentity]
  , storedQualificationSelectedStrategies :: ![ModelIdentity]
  , storedQualificationSubjectUnavailable :: ![QualificationSubjectUnavailable
                                                 scope]
  , storedQualificationUnroutedProposals :: ![QualificationProposalAssessment
                                                scope]
  , storedQualificationPairs :: ![QualificationPairAssessment scope]
  } deriving (Eq, Show)

-- | Private truthful work evidence for the capability-owned schedule.
data QualificationWork = QualificationWork
  { qualificationCarrierVisits :: !Int
  , qualificationRelationVisits :: !Int
  , qualificationContextualizationVisits :: !Int
  , qualificationSelectorResolutionVisits :: !Int
  , qualificationProposalVisits :: !Int
  , qualificationRequestedPairVisits :: !Int
  , qualificationRequestedMembershipVisits :: !Int
  , qualificationCarrierAddressVisits :: !Int
  , qualificationCarrierAddressScalarVisits :: !Int
  , qualificationSupportAddressVisits :: !Int
  , qualificationSupportAddressScalarVisits :: !Int
  , qualificationAddressedSupportVisits :: !Int
  , qualificationOrderingScalarVisits :: !Int
  , qualificationOrderingComparisons :: !Int
  , qualificationEmittedStructuralSize :: !Int
  , qualificationEmittedScalarSize :: !Int
  } deriving (Eq, Show)

emptyQualificationWork :: QualificationWork
emptyQualificationWork = QualificationWork 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

addQualificationWork ::
     QualificationWork -> QualificationWork -> QualificationWork
addQualificationWork left right =
  QualificationWork
    { qualificationCarrierVisits =
        qualificationCarrierVisits left + qualificationCarrierVisits right
    , qualificationRelationVisits =
        qualificationRelationVisits left + qualificationRelationVisits right
    , qualificationContextualizationVisits =
        qualificationContextualizationVisits left
          + qualificationContextualizationVisits right
    , qualificationSelectorResolutionVisits =
        qualificationSelectorResolutionVisits left
          + qualificationSelectorResolutionVisits right
    , qualificationProposalVisits =
        qualificationProposalVisits left + qualificationProposalVisits right
    , qualificationRequestedPairVisits =
        qualificationRequestedPairVisits left
          + qualificationRequestedPairVisits right
    , qualificationRequestedMembershipVisits =
        qualificationRequestedMembershipVisits left
          + qualificationRequestedMembershipVisits right
    , qualificationCarrierAddressVisits =
        qualificationCarrierAddressVisits left
          + qualificationCarrierAddressVisits right
    , qualificationCarrierAddressScalarVisits =
        qualificationCarrierAddressScalarVisits left
          + qualificationCarrierAddressScalarVisits right
    , qualificationSupportAddressVisits =
        qualificationSupportAddressVisits left
          + qualificationSupportAddressVisits right
    , qualificationSupportAddressScalarVisits =
        qualificationSupportAddressScalarVisits left
          + qualificationSupportAddressScalarVisits right
    , qualificationAddressedSupportVisits =
        qualificationAddressedSupportVisits left
          + qualificationAddressedSupportVisits right
    , qualificationOrderingScalarVisits =
        qualificationOrderingScalarVisits left
          + qualificationOrderingScalarVisits right
    , qualificationOrderingComparisons =
        qualificationOrderingComparisons left
          + qualificationOrderingComparisons right
    , qualificationEmittedStructuralSize =
        qualificationEmittedStructuralSize left
          + qualificationEmittedStructuralSize right
    , qualificationEmittedScalarSize =
        qualificationEmittedScalarSize left
          + qualificationEmittedScalarSize right
    }
