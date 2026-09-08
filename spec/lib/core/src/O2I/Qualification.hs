{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Formal admissibility of Need qualification proposals.
--
-- This capability discovers its fixed Need and Strategy subjects and assesses
-- explicit requested pairs. A positive proof authorizes neither fachliche
-- acceptance nor persistence and never changes the supplied effect graph.
module O2I.Qualification
  ( QualificationProposalInput
  , qualificationProposalInput
  , qualificationProposalInputOccurrence
  , qualificationProposalInputIdentity
  , QualificationNeedSelector
  , qualificationNeedSelector
  , qualificationNeedSelectorIdentity
  , QualificationStrategySelector
  , qualificationStrategySelector
  , qualificationStrategySelectorIdentity
  , QualificationContext
  , QualificationContextError(..)
  , prepareQualificationContext
  , QualificationSubjects
  , qualificationSubjects
  , qualificationNeedSubjects
  , qualificationStrategySubjects
  , QualificationSubject
  , qualificationSubjectIdentity
  , qualificationSubjectOccurrence
  , qualificationSubjectQualifiedEndpoint
  , QualificationSubjectEligibility(..)
  , qualificationSubjectEligibility
  , QualificationAssessment
  , assessQualification
  , QualificationAssessmentDisposition(..)
  , qualificationAssessmentDisposition
  , qualificationAssessmentGraphIdentity
  , qualificationSelectedNeeds
  , qualificationSelectedStrategies
  , QualificationSubjectUnavailable
  , QualificationSubjectCategory(..)
  , QualificationSubjectUnavailableReason(..)
  , qualificationSubjectUnavailable
  , qualificationUnavailableCategory
  , qualificationUnavailableIdentity
  , qualificationUnavailableReason
  , qualificationUnavailableOccurrences
  , qualificationUnroutedProposals
  , qualificationPairAssessments
  , QualificationPairAssessment
  , QualificationPairDisposition(..)
  , qualificationPairDisposition
  , qualificationPairNeed
  , qualificationPairStrategy
  , qualificationPairDiagnostics
  , qualificationPairProposals
  , QualificationProposalAssessment
  , QualificationProposalDisposition(..)
  , qualificationProposalDisposition
  , qualificationProposalIdentity
  , qualificationProposalOccurrence
  , qualificationProposalDiagnostics
  , admissibleQualificationProposal
  , AdmissibleQualificationProposal
  , admissibleProposalIdentity
  , admissibleProposalOccurrence
  , admissibleNeedIdentity
  , admissibleStrategyIdentity
  , admissibleKeyResultIdentity
  , admissibleObjectiveIdentity
  , admissibleRationale
  , admissibleSources
  , admissibleWitnesses
  , QualificationDiagnosticEvidence
  , qualificationDiagnosticRule
  , QualificationEvidenceKind(..)
  , qualificationDiagnosticKind
  , QualificationDiagnosticSubject
  , qualificationDiagnosticSubjects
  , foldQualificationDiagnosticSubject
  , QualificationRole
  , qualificationRoleText
  , QualificationOccurrenceGroup
  , qualificationDiagnosticOccurrenceGroups
  , qualificationOccurrenceGroupRole
  , qualificationOccurrenceGroupOccurrences
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreQualificationProposalRoleId
  , CoreQualifiedEndpointId
  , CoreRuleId
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Qualification.Eval
  ( QualificationContext
  , QualificationContextError(..)
  )
import qualified O2I.Qualification.Eval as Eval
import O2I.Qualification.Internal
  ( AdmissibleQualificationProposal
  , QualificationAssessment
  , QualificationDefect
  , QualificationNeedSelector
  , QualificationOccurrenceGroup
  , QualificationPairAssessment
  , QualificationProposalAssessment
  , QualificationProposalInput
  , QualificationReferenceInput(..)
  , QualificationRole
  , QualificationSourceInput(..)
  , QualificationStrategySelector
  , QualificationSubject
  , QualificationSubjectCategory(..)
  , QualificationSubjectEligibility(..)
  , QualificationSubjectUnavailable
  , QualificationSubjectUnavailableReason(..)
  , QualificationSubjects
  )
import qualified O2I.Qualification.Internal as Internal
import O2I.Semantics (SemanticAssessment)
import O2I.Structure (WellFormedGraph)

-- | Construct one notation-neutral proposal projection.
--
-- Missing or malformed rationale, source, role, and target content is retained
-- for deterministic Core diagnostics rather than rejected at construction.
qualificationProposalInput ::
     OccurrenceIdentity
  -> ModelIdentity
  -> Maybe Text
  -> [(OccurrenceIdentity, Text)]
  -> [(OccurrenceIdentity, CoreQualificationProposalRoleId, OccurrenceIdentity)]
  -> QualificationProposalInput
qualificationProposalInput occurrence identifier rationale sources references =
  Internal.QualificationProposalInput
    occurrence
    identifier
    rationale
    [ QualificationSourceInput sourceOccurrence source
    | (sourceOccurrence, source) <- sources
    ]
    [ QualificationReferenceInput referenceOccurrence role target
    | (referenceOccurrence, role, target) <- references
    ]

-- | Recover the proposal occurrence retained at the input boundary.
qualificationProposalInputOccurrence ::
     QualificationProposalInput -> OccurrenceIdentity
qualificationProposalInputOccurrence =
  Internal.storedQualificationProposalOccurrence

-- | Recover the stable proposal identity retained at the input boundary.
qualificationProposalInputIdentity ::
     QualificationProposalInput -> ModelIdentity
qualificationProposalInputIdentity =
  Internal.storedQualificationProposalIdentity

-- | Construct one closed Need selector from an exact model identity.
qualificationNeedSelector :: ModelIdentity -> QualificationNeedSelector
qualificationNeedSelector = Internal.QualificationNeedSelector

-- | Recover the exact identity of a Need selector.
qualificationNeedSelectorIdentity :: QualificationNeedSelector -> ModelIdentity
qualificationNeedSelectorIdentity =
  Internal.storedQualificationNeedSelectorIdentity

-- | Construct one closed Strategy selector from an exact model identity.
qualificationStrategySelector :: ModelIdentity -> QualificationStrategySelector
qualificationStrategySelector = Internal.QualificationStrategySelector

-- | Recover the exact identity of a Strategy selector.
qualificationStrategySelectorIdentity ::
     QualificationStrategySelector -> ModelIdentity
qualificationStrategySelectorIdentity =
  Internal.storedQualificationStrategySelectorIdentity

-- | Bind one semantic assessment to its exact producing graph and index it.
prepareQualificationContext ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> Either QualificationContextError (QualificationContext scope)
prepareQualificationContext = Eval.prepareQualificationContextInternal

-- | Discover every fixed subject with its Core-owned eligibility disposition.
qualificationSubjects ::
     QualificationContext scope -> QualificationSubjects scope
qualificationSubjects = Eval.qualificationSubjectsInternal

-- | Canonically ordered fixed Need subjects in the selected View.
qualificationNeedSubjects ::
     QualificationSubjects scope -> [QualificationSubject]
qualificationNeedSubjects = Internal.storedQualificationNeedSubjects

-- | Canonically ordered fixed Strategy subjects in the selected View.
qualificationStrategySubjects ::
     QualificationSubjects scope -> [QualificationSubject]
qualificationStrategySubjects = Internal.storedQualificationStrategySubjects

-- | Recover the model identity of one discovered subject.
qualificationSubjectIdentity :: QualificationSubject -> ModelIdentity
qualificationSubjectIdentity = Internal.storedQualificationSubjectIdentity

-- | Recover the exact occurrence of one discovered subject.
qualificationSubjectOccurrence :: QualificationSubject -> OccurrenceIdentity
qualificationSubjectOccurrence = Internal.storedQualificationSubjectOccurrence

-- | Recover the exact qualified O2I endpoint of one discovered subject.
qualificationSubjectQualifiedEndpoint ::
     QualificationSubject -> CoreQualifiedEndpointId
qualificationSubjectQualifiedEndpoint =
  Internal.storedQualificationSubjectQualifiedEndpoint

-- | Recover the Core-owned semantic eligibility of one discovered subject.
qualificationSubjectEligibility ::
     QualificationSubject -> QualificationSubjectEligibility
qualificationSubjectEligibility = Internal.storedQualificationSubjectEligibility

-- | Assess every proposal once for routing and emit every requested pair once.
assessQualification ::
     QualificationContext scope
  -> [QualificationNeedSelector]
  -> NonEmpty QualificationStrategySelector
  -> [QualificationProposalInput]
  -> QualificationAssessment scope
assessQualification = Eval.assessQualificationInternal

-- | Closed aggregate availability of qualification pair outcomes.
data QualificationAssessmentDisposition
  = QualificationSubjectsUnavailable
    -- ^ Selector resolution or an eligibility prerequisite is unavailable.
  | QualificationPairOutcomesAvailable
    -- ^ Every selector resolved and every requested pair was materialized.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify aggregate availability before consuming any pair outcome.
qualificationAssessmentDisposition ::
     QualificationAssessment scope -> QualificationAssessmentDisposition
qualificationAssessmentDisposition assessment
  | null (Internal.storedQualificationSubjectUnavailable assessment) =
    QualificationPairOutcomesAvailable
  | otherwise = QualificationSubjectsUnavailable

-- | Recover the identity of the graph that was assessed.
qualificationAssessmentGraphIdentity ::
     QualificationAssessment scope -> ModelIdentity
qualificationAssessmentGraphIdentity = Internal.storedQualificationGraphIdentity

-- | Recover the canonical distinct selected Need identities.
qualificationSelectedNeeds :: QualificationAssessment scope -> [ModelIdentity]
qualificationSelectedNeeds = Internal.storedQualificationSelectedNeeds

-- | Recover the canonical distinct selected Strategy identities.
qualificationSelectedStrategies ::
     QualificationAssessment scope -> [ModelIdentity]
qualificationSelectedStrategies = Internal.storedQualificationSelectedStrategies

-- | Recover canonical selector and prerequisite unavailability evidence.
qualificationSubjectUnavailable ::
     QualificationAssessment scope -> [QualificationSubjectUnavailable scope]
qualificationSubjectUnavailable = Internal.storedQualificationSubjectUnavailable

-- | Recover the closed Need-before-Strategy category of unavailability.
qualificationUnavailableCategory ::
     QualificationSubjectUnavailable scope -> QualificationSubjectCategory
qualificationUnavailableCategory =
  Internal.storedQualificationUnavailableCategory

-- | Recover the exact selector or subject identity.
qualificationUnavailableIdentity ::
     QualificationSubjectUnavailable scope -> ModelIdentity
qualificationUnavailableIdentity =
  Internal.storedQualificationUnavailableIdentity

-- | Recover the closed capability-specific unavailability reason.
qualificationUnavailableReason ::
     QualificationSubjectUnavailable scope
  -> QualificationSubjectUnavailableReason
qualificationUnavailableReason = Internal.storedQualificationUnavailableReason

-- | Recover canonical occurrence evidence without exposing any actual kind.
qualificationUnavailableOccurrences ::
     QualificationSubjectUnavailable scope -> [OccurrenceIdentity]
qualificationUnavailableOccurrences =
  Internal.storedQualificationUnavailableOccurrences

-- | Recover route-invalid proposals in canonical proposal order.
qualificationUnroutedProposals ::
     QualificationAssessment scope -> [QualificationProposalAssessment scope]
qualificationUnroutedProposals = Internal.storedQualificationUnroutedProposals

-- | Recover exactly one outcome for every requested pair.
qualificationPairAssessments ::
     QualificationAssessment scope -> [QualificationPairAssessment scope]
qualificationPairAssessments = Internal.storedQualificationPairs

-- | Closed precedence-selected disposition of one requested pair.
data QualificationPairDisposition
  = QualificationPairInvalidSelectedSubjects
    -- ^ At least one selected subject lacks its required semantic proof.
  | QualificationPairProposalMissing
    -- ^ Both subjects are valid and the requested pair has no proposal.
  | QualificationPairProposalsAssessed
    -- ^ Both subjects are valid and every routed proposal was assessed.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify one requested-pair outcome without exposing constructors.
qualificationPairDisposition ::
     QualificationPairAssessment scope -> QualificationPairDisposition
qualificationPairDisposition pair =
  case pair of
    Internal.QualificationPairInvalidSubjects {} ->
      QualificationPairInvalidSelectedSubjects
    Internal.QualificationPairMissingProposal {} ->
      QualificationPairProposalMissing
    Internal.QualificationPairProposals {} -> QualificationPairProposalsAssessed

-- | Recover the selected Need identity of one requested pair.
qualificationPairNeed :: QualificationPairAssessment scope -> ModelIdentity
qualificationPairNeed pair =
  case pair of
    Internal.QualificationPairInvalidSubjects need _ _ -> need
    Internal.QualificationPairMissingProposal need _ _ -> need
    Internal.QualificationPairProposals need _ _ -> need

-- | Recover the selected Strategy identity of one requested pair.
qualificationPairStrategy :: QualificationPairAssessment scope -> ModelIdentity
qualificationPairStrategy pair =
  case pair of
    Internal.QualificationPairInvalidSubjects _ strategy _ -> strategy
    Internal.QualificationPairMissingProposal _ strategy _ -> strategy
    Internal.QualificationPairProposals _ strategy _ -> strategy

-- | Recover pair-owned diagnostics; proposal diagnostics remain proposal-local.
qualificationPairDiagnostics ::
     QualificationPairAssessment scope
  -> [QualificationDiagnosticEvidence scope]
qualificationPairDiagnostics pair =
  case pair of
    Internal.QualificationPairInvalidSubjects _ _ defects ->
      map QualificationDiagnosticEvidence (NonEmpty.toList defects)
    Internal.QualificationPairMissingProposal _ _ defect ->
      [QualificationDiagnosticEvidence defect]
    Internal.QualificationPairProposals {} -> []

-- | Recover assessed proposals when the pair selected that outcome.
qualificationPairProposals ::
     QualificationPairAssessment scope
  -> [QualificationProposalAssessment scope]
qualificationPairProposals pair =
  case pair of
    Internal.QualificationPairProposals _ _ proposals ->
      NonEmpty.toList proposals
    _ -> []

-- | Closed disposition of one proposal subject.
data QualificationProposalDisposition
  = QualificationProposalRouteInvalid
    -- ^ Need or Strategy route roles prevented one complete route.
  | QualificationProposalFormallyInvalid
    -- ^ A requested routed proposal failed at least one formal rule.
  | QualificationProposalFormallyAdmissible
    -- ^ A requested routed proposal carries an opaque admissibility proof.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify a proposal outcome without exposing its constructors.
qualificationProposalDisposition ::
     QualificationProposalAssessment scope -> QualificationProposalDisposition
qualificationProposalDisposition proposal =
  case proposal of
    Internal.QualificationProposalUnrouted {} ->
      QualificationProposalRouteInvalid
    Internal.QualificationProposalInvalid {} ->
      QualificationProposalFormallyInvalid
    Internal.QualificationProposalAdmissible {} ->
      QualificationProposalFormallyAdmissible

-- | Recover the stable model identity of an assessed proposal.
qualificationProposalIdentity ::
     QualificationProposalAssessment scope -> ModelIdentity
qualificationProposalIdentity proposal =
  case proposal of
    Internal.QualificationProposalUnrouted identifier _ _ -> identifier
    Internal.QualificationProposalInvalid identifier _ _ -> identifier
    Internal.QualificationProposalAdmissible proof ->
      Internal.storedAdmissibleProposalIdentity proof

-- | Recover the exact occurrence of an assessed proposal.
qualificationProposalOccurrence ::
     QualificationProposalAssessment scope -> OccurrenceIdentity
qualificationProposalOccurrence proposal =
  case proposal of
    Internal.QualificationProposalUnrouted _ occurrence _ -> occurrence
    Internal.QualificationProposalInvalid _ occurrence _ -> occurrence
    Internal.QualificationProposalAdmissible proof ->
      Internal.storedAdmissibleProposalOccurrence proof

-- | Recover every canonical proposal-local diagnostic.
qualificationProposalDiagnostics ::
     QualificationProposalAssessment scope
  -> [QualificationDiagnosticEvidence scope]
qualificationProposalDiagnostics proposal =
  case proposal of
    Internal.QualificationProposalUnrouted _ _ defects ->
      map QualificationDiagnosticEvidence (NonEmpty.toList defects)
    Internal.QualificationProposalInvalid _ _ defects ->
      map QualificationDiagnosticEvidence (NonEmpty.toList defects)
    Internal.QualificationProposalAdmissible {} -> []

-- | Recover the opaque proof only from a formally admissible outcome.
admissibleQualificationProposal ::
     QualificationProposalAssessment scope
  -> Maybe (AdmissibleQualificationProposal scope)
admissibleQualificationProposal proposal =
  case proposal of
    Internal.QualificationProposalAdmissible proof -> Just proof
    _ -> Nothing

-- | Recover the proposal identity proven formally admissible.
admissibleProposalIdentity ::
     AdmissibleQualificationProposal scope -> ModelIdentity
admissibleProposalIdentity = Internal.storedAdmissibleProposalIdentity

-- | Recover the proposal occurrence retained by the proof.
admissibleProposalOccurrence ::
     AdmissibleQualificationProposal scope -> OccurrenceIdentity
admissibleProposalOccurrence = Internal.storedAdmissibleProposalOccurrence

-- | Recover the selected Need identity retained by the proof.
admissibleNeedIdentity :: AdmissibleQualificationProposal scope -> ModelIdentity
admissibleNeedIdentity = Internal.storedAdmissibleNeedIdentity

-- | Recover the selected Strategy identity retained by the proof.
admissibleStrategyIdentity ::
     AdmissibleQualificationProposal scope -> ModelIdentity
admissibleStrategyIdentity = Internal.storedAdmissibleStrategyIdentity

-- | Recover the listed Strategy Key Result retained by the proof.
admissibleKeyResultIdentity ::
     AdmissibleQualificationProposal scope -> ModelIdentity
admissibleKeyResultIdentity = Internal.storedAdmissibleKeyResultIdentity

-- | Recover the Need Objective retained by the proof.
admissibleObjectiveIdentity ::
     AdmissibleQualificationProposal scope -> ModelIdentity
admissibleObjectiveIdentity = Internal.storedAdmissibleObjectiveIdentity

-- | Recover the canonical nonempty rationale retained by the proof.
admissibleRationale :: AdmissibleQualificationProposal scope -> Text
admissibleRationale = Internal.storedAdmissibleRationale

-- | Recover the nonempty normalized source identities retained by the proof.
admissibleSources :: AdmissibleQualificationProposal scope -> NonEmpty Text
admissibleSources = Internal.storedAdmissibleSources

-- | Recover canonical supporting occurrences without implying persistence.
admissibleWitnesses ::
     AdmissibleQualificationProposal scope -> [OccurrenceIdentity]
admissibleWitnesses = Internal.storedAdmissibleWitnesses

-- | Opaque schema-bound evidence for one qualification diagnostic.
newtype QualificationDiagnosticEvidence scope =
  QualificationDiagnosticEvidence QualificationDefect

type role QualificationDiagnosticEvidence nominal

-- | Recover the exact compiled Core rule identity.
qualificationDiagnosticRule ::
     QualificationDiagnosticEvidence scope -> CoreRuleId
qualificationDiagnosticRule (QualificationDiagnosticEvidence defect) =
  Internal.qualificationRuleId (Internal.storedQualificationDefectRule defect)

-- | Closed evidence-key schema of a qualification diagnostic.
data QualificationEvidenceKind
  = QualificationProposalEvidence
    -- ^ A proposal identity key.
  | QualificationProposalRoleEvidence
    -- ^ A proposal and closed role key.
  | QualificationProposalRoleTargetEvidence
    -- ^ A proposal, closed role, and target occurrence key.
  | QualificationSelectedNeedEvidence
    -- ^ A selected Need identity key.
  | QualificationSelectedStrategyEvidence
    -- ^ A selected Strategy identity key.
  | QualificationPairEvidence
    -- ^ A selected Need and Strategy pair key.
  | QualificationProposalRelationEvidence
    -- ^ A proposal and semantic-relation identity key.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify the exact evidence-key schema of a diagnostic.
qualificationDiagnosticKind ::
     QualificationDiagnosticEvidence scope -> QualificationEvidenceKind
qualificationDiagnosticKind (QualificationDiagnosticEvidence defect) =
  case Internal.storedQualificationDefectEvidence defect of
    Internal.QualificationProposalKey {} -> QualificationProposalEvidence
    Internal.QualificationProposalRoleKey {} ->
      QualificationProposalRoleEvidence
    Internal.QualificationProposalRoleTargetKey {} ->
      QualificationProposalRoleTargetEvidence
    Internal.QualificationSelectedNeedKey {} ->
      QualificationSelectedNeedEvidence
    Internal.QualificationSelectedStrategyKey {} ->
      QualificationSelectedStrategyEvidence
    Internal.QualificationPairKey {} -> QualificationPairEvidence
    Internal.QualificationProposalRelationKey {} ->
      QualificationProposalRelationEvidence

-- | One typed labeled field of a qualification evidence key.
data QualificationDiagnosticSubject
  = QualificationModelSubject !Text !ModelIdentity
    -- ^ A labeled model identity.
  | QualificationOccurrenceSubject !Text !OccurrenceIdentity
    -- ^ A labeled occurrence identity.
  | QualificationRoleSubject !Text !QualificationRole
    -- ^ A labeled closed proposal role.
  | QualificationTextSubject !Text !Text
    -- ^ A labeled closed semantic text value.

-- | Recover the exact nonempty evidence-key fields of a diagnostic.
qualificationDiagnosticSubjects ::
     QualificationDiagnosticEvidence scope
  -> NonEmpty QualificationDiagnosticSubject
qualificationDiagnosticSubjects (QualificationDiagnosticEvidence defect) =
  case Internal.storedQualificationDefectEvidence defect of
    Internal.QualificationProposalKey proposal ->
      QualificationModelSubject "proposal" proposal NonEmpty.:| []
    Internal.QualificationProposalRoleKey proposal role ->
      QualificationModelSubject "proposal" proposal
        NonEmpty.:| [QualificationRoleSubject "role" role]
    Internal.QualificationProposalRoleTargetKey proposal role target ->
      QualificationModelSubject "proposal" proposal
        NonEmpty.:| [ QualificationRoleSubject "role" role
                    , QualificationOccurrenceSubject "target" target
                    ]
    Internal.QualificationSelectedNeedKey need ->
      QualificationModelSubject "need" need NonEmpty.:| []
    Internal.QualificationSelectedStrategyKey strategy ->
      QualificationModelSubject "strategy" strategy NonEmpty.:| []
    Internal.QualificationPairKey need strategy ->
      QualificationModelSubject "need" need
        NonEmpty.:| [QualificationModelSubject "strategy" strategy]
    Internal.QualificationProposalRelationKey proposal relation ->
      QualificationModelSubject "proposal" proposal
        NonEmpty.:| [QualificationTextSubject "semantic-relation" relation]

-- | Eliminate one diagnostic subject through its closed typed alternatives.
foldQualificationDiagnosticSubject ::
     (Text -> ModelIdentity -> result)
  -> (Text -> OccurrenceIdentity -> result)
  -> (Text -> QualificationRole -> result)
  -> (Text -> Text -> result)
  -> QualificationDiagnosticSubject
  -> result
foldQualificationDiagnosticSubject model occurrence role text subject =
  case subject of
    QualificationModelSubject label identifier -> model label identifier
    QualificationOccurrenceSubject label identifier ->
      occurrence label identifier
    QualificationRoleSubject label value -> role label value
    QualificationTextSubject label value -> text label value

-- | Render the exact closed short name of a proposal role.
qualificationRoleText :: QualificationRole -> Text
qualificationRoleText role =
  case role of
    Internal.QualificationNeedRole -> "need"
    Internal.QualificationStrategyRole -> "strategy"
    Internal.QualificationKeyResultRole -> "key-result"
    Internal.QualificationObjectiveRole -> "objective"

-- | Recover exact named occurrence groups, including required empty groups.
qualificationDiagnosticOccurrenceGroups ::
     QualificationDiagnosticEvidence scope
  -> NonEmpty QualificationOccurrenceGroup
qualificationDiagnosticOccurrenceGroups (QualificationDiagnosticEvidence defect) =
  Internal.storedQualificationDefectOccurrences defect

-- | Recover the exact schema role of one occurrence group.
qualificationOccurrenceGroupRole :: QualificationOccurrenceGroup -> Text
qualificationOccurrenceGroupRole = Internal.storedQualificationOccurrenceRole

-- | Recover the canonical occurrences in one evidence group.
qualificationOccurrenceGroupOccurrences ::
     QualificationOccurrenceGroup -> [OccurrenceIdentity]
qualificationOccurrenceGroupOccurrences =
  Internal.storedQualificationOccurrenceValues
