{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Complete terminal-neutral human projection of Qualify results.
module O2I.Operation.Qualify.Human
  ( type HumanQualifyRequest
  , foldHumanQualifyRequest
  , type HumanQualifyContext
  , foldHumanQualifyContext
  , type HumanQualificationSubjectValue
  , foldHumanQualificationSubjectValue
  , type HumanQualificationOccurrenceGroup
  , foldHumanQualificationOccurrenceGroup
  , type HumanQualificationDiagnostic
  , foldHumanQualificationDiagnostic
  , type HumanAdmissibleProposal
  , foldHumanAdmissibleProposal
  , type HumanQualificationProposal
  , foldHumanQualificationProposal
  , type HumanQualificationPair
  , foldHumanQualificationPair
  , type HumanQualificationUnavailable
  , foldHumanQualificationUnavailable
  , type HumanQualificationAssessment
  , foldHumanQualificationAssessment
  , type HumanQualifyFailure
  , foldHumanQualifyFailure
  , type HumanQualifyReport
  , qualifyHumanReport
  , foldHumanQualifyReport
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract (coreRuleIdText)
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanQualifyFailure
  , foldHumanQualifyFailure
  , projectQualifyFailure
  )
import O2I.Operation.Human.Value
  ( HumanAdapterSelection
  , HumanInputSource
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanSourceIdentity
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( projectAcquiredSupplementalSource
  , projectAdapterSelection
  , projectInputSource
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Qualify.Request (QualifyRequest, foldQualifyRequest)
import O2I.Operation.Qualify.Result
  ( PreparedQualify
  , QualifyPrerequisite
  , QualifyResult
  , foldPreparedQualify
  )
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldQualifyReport)
import O2I.Operation.View (selectedViewDescriptor)
import qualified O2I.Qualification as Qualification

-- | Exact retained Qualify request contract.
data HumanQualifyRequest =
  HumanQualifyRequest
    HumanInputSource
    HumanViewSelector
    HumanAdapterSelection
    (NonEmpty HumanModelIdentity)
    [HumanModelIdentity]
    [HumanInputSource]

-- | Complete context shared by every prepared Qualify branch.
data HumanQualifyContext =
  HumanQualifyContext
    ReportEnvelope
    HumanQualifyRequest
    HumanSourceIdentity
    [HumanSourceIdentity]
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Closed typed subject carried by a qualification diagnostic.
data HumanQualificationSubjectValue
  = HumanQualificationModelSubject Text HumanModelIdentity
  | HumanQualificationOccurrenceSubject Text HumanOccurrenceIdentity
  | HumanQualificationRoleSubject Text Text
  | HumanQualificationTextSubject Text Text

-- | Semantic occurrence role and its exact occurrences.
data HumanQualificationOccurrenceGroup =
  HumanQualificationOccurrenceGroup Text [HumanOccurrenceIdentity]

-- | Rule, evidence kind, typed subjects, and occurrence groups.
data HumanQualificationDiagnostic =
  HumanQualificationDiagnostic
    Text
    Text
    (NonEmpty HumanQualificationSubjectValue)
    (NonEmpty HumanQualificationOccurrenceGroup)

-- | Complete formally admissible qualification proposal.
data HumanAdmissibleProposal =
  HumanAdmissibleProposal
    HumanModelIdentity
    HumanOccurrenceIdentity
    HumanModelIdentity
    HumanModelIdentity
    HumanModelIdentity
    HumanModelIdentity
    Text
    (NonEmpty Text)
    [HumanOccurrenceIdentity]

-- | Qualification proposal with diagnostics and optional admissible proof.
data HumanQualificationProposal =
  HumanQualificationProposal
    HumanModelIdentity
    HumanOccurrenceIdentity
    Text
    [HumanQualificationDiagnostic]
    (Maybe HumanAdmissibleProposal)

-- | Assessed Need/Strategy pair and all routed proposals.
data HumanQualificationPair =
  HumanQualificationPair
    HumanModelIdentity
    HumanModelIdentity
    Text
    [HumanQualificationDiagnostic]
    [HumanQualificationProposal]

-- | Selected subject whose eligibility prerequisite was unavailable.
data HumanQualificationUnavailable =
  HumanQualificationUnavailable
    Text
    HumanModelIdentity
    Text
    [HumanOccurrenceIdentity]

-- | Complete qualification assessment for the selected graph.
data HumanQualificationAssessment =
  HumanQualificationAssessment
    HumanModelIdentity
    Text
    [HumanModelIdentity]
    [HumanModelIdentity]
    [HumanQualificationUnavailable]
    [HumanQualificationProposal]
    [HumanQualificationPair]

-- | Complete terminal-neutral Qualify report.
data HumanQualifyReport
  = HumanQualifyFailed HumanQualifyFailure
  | HumanQualifyPrerequisiteRejected QualifyPrerequisite HumanQualifyContext
  | HumanQualifyCompleted HumanQualificationAssessment HumanQualifyContext

-- | Consume every exact requested Qualify field.
foldHumanQualifyRequest ::
     (HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> NonEmpty
                                                                          HumanModelIdentity -> [HumanModelIdentity] -> [HumanInputSource] -> result)
  -> HumanQualifyRequest
  -> result
foldHumanQualifyRequest consume (HumanQualifyRequest model view adapter strategies needs supplements) =
  consume model view adapter strategies needs supplements

-- | Consume every prepared Qualify context field.
foldHumanQualifyContext ::
     (ReportEnvelope -> HumanQualifyRequest -> HumanSourceIdentity -> [HumanSourceIdentity] -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanQualifyContext
  -> result
foldHumanQualifyContext consume (HumanQualifyContext envelope request model supplements view diagnostics) =
  consume envelope request model supplements view diagnostics

-- | Eliminate every closed qualification subject-value branch.
foldHumanQualificationSubjectValue ::
     (Text -> HumanModelIdentity -> result)
  -> (Text -> HumanOccurrenceIdentity -> result)
  -> (Text -> Text -> result)
  -> (Text -> Text -> result)
  -> HumanQualificationSubjectValue
  -> result
foldHumanQualificationSubjectValue model occurrence role text subject =
  case subject of
    HumanQualificationModelSubject label value -> model label value
    HumanQualificationOccurrenceSubject label value -> occurrence label value
    HumanQualificationRoleSubject label value -> role label value
    HumanQualificationTextSubject label value -> text label value

-- | Consume an occurrence role and all exact occurrences.
foldHumanQualificationOccurrenceGroup ::
     (Text -> [HumanOccurrenceIdentity] -> result)
  -> HumanQualificationOccurrenceGroup
  -> result
foldHumanQualificationOccurrenceGroup consume (HumanQualificationOccurrenceGroup role occurrences) =
  consume role occurrences

-- | Consume every retained qualification diagnostic field.
foldHumanQualificationDiagnostic ::
     (Text -> Text -> NonEmpty HumanQualificationSubjectValue -> NonEmpty
                                                                   HumanQualificationOccurrenceGroup -> result)
  -> HumanQualificationDiagnostic
  -> result
foldHumanQualificationDiagnostic consume (HumanQualificationDiagnostic rule kind subjects groups) =
  consume rule kind subjects groups

-- | Consume every retained admissible-proposal field.
foldHumanAdmissibleProposal ::
     (HumanModelIdentity -> HumanOccurrenceIdentity -> HumanModelIdentity -> HumanModelIdentity -> HumanModelIdentity -> HumanModelIdentity -> Text -> NonEmpty
                                                                                                                                                         Text -> [HumanOccurrenceIdentity] -> result)
  -> HumanAdmissibleProposal
  -> result
foldHumanAdmissibleProposal consume (HumanAdmissibleProposal proposal occurrence need strategy keyResult objective rationale sources witnesses) =
  consume
    proposal
    occurrence
    need
    strategy
    keyResult
    objective
    rationale
    sources
    witnesses

-- | Consume every retained qualification-proposal field.
foldHumanQualificationProposal ::
     (HumanModelIdentity -> HumanOccurrenceIdentity -> Text -> [HumanQualificationDiagnostic] -> Maybe
                                                                                                   HumanAdmissibleProposal -> result)
  -> HumanQualificationProposal
  -> result
foldHumanQualificationProposal consume (HumanQualificationProposal identity occurrence disposition diagnostics admissible) =
  consume identity occurrence disposition diagnostics admissible

-- | Consume every retained qualification-pair field.
foldHumanQualificationPair ::
     (HumanModelIdentity -> HumanModelIdentity -> Text -> [HumanQualificationDiagnostic] -> [HumanQualificationProposal] -> result)
  -> HumanQualificationPair
  -> result
foldHumanQualificationPair consume (HumanQualificationPair need strategy disposition diagnostics proposals) =
  consume need strategy disposition diagnostics proposals

-- | Consume every retained unavailable-subject field.
foldHumanQualificationUnavailable ::
     (Text -> HumanModelIdentity -> Text -> [HumanOccurrenceIdentity] -> result)
  -> HumanQualificationUnavailable
  -> result
foldHumanQualificationUnavailable consume (HumanQualificationUnavailable category identity reason occurrences) =
  consume category identity reason occurrences

-- | Consume every retained qualification-assessment field.
foldHumanQualificationAssessment ::
     (HumanModelIdentity -> Text -> [HumanModelIdentity] -> [HumanModelIdentity] -> [HumanQualificationUnavailable] -> [HumanQualificationProposal] -> [HumanQualificationPair] -> result)
  -> HumanQualificationAssessment
  -> result
foldHumanQualificationAssessment consume (HumanQualificationAssessment graph disposition needs strategies unavailable unrouted pairs) =
  consume graph disposition needs strategies unavailable unrouted pairs

-- | Project a Qualify result without rendering it.
qualifyHumanReport :: ToolDescriptor -> QualifyResult -> HumanQualifyReport
qualifyHumanReport tool =
  foldQualifyReport
    tool
    (HumanQualifyFailed . projectQualifyFailure)
    (\envelope stage prepared ->
       preparedContext
         (HumanQualifyPrerequisiteRejected stage)
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanQualifyCompleted (projectAssessment assessment))
         envelope
         prepared)

-- | Eliminate every closed Qualify-report branch.
foldHumanQualifyReport ::
     (HumanQualifyFailure -> result)
  -> (QualifyPrerequisite -> HumanQualifyContext -> result)
  -> (HumanQualificationAssessment -> HumanQualifyContext -> result)
  -> HumanQualifyReport
  -> result
foldHumanQualifyReport failed prerequisite completed report =
  case report of
    HumanQualifyFailed failure -> failed failure
    HumanQualifyPrerequisiteRejected stage context -> prerequisite stage context
    HumanQualifyCompleted assessment context -> completed assessment context

preparedContext ::
     (HumanQualifyContext -> HumanQualifyReport)
  -> ReportEnvelope
  -> PreparedQualify
  -> HumanQualifyReport
preparedContext constructor envelope prepared =
  foldPreparedQualify
    (\request view supplements diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanQualifyContext
                envelope
                (projectQualifyRequest request)
                (humanDiagnosticDocumentModelSource document)
                (map projectAcquiredSupplementalSource supplements)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    prepared

projectQualifyRequest :: QualifyRequest -> HumanQualifyRequest
projectQualifyRequest =
  foldQualifyRequest $ \model view adapter strategies needs supplements ->
    HumanQualifyRequest
      (projectInputSource model)
      (projectViewSelector view)
      (projectAdapterSelection adapter)
      (fmap projectModelIdentity strategies)
      (map projectModelIdentity needs)
      (map projectInputSource supplements)

projectAssessment ::
     Qualification.QualificationAssessment scope -> HumanQualificationAssessment
projectAssessment assessment =
  HumanQualificationAssessment
    (projectModelIdentity
       (Qualification.qualificationAssessmentGraphIdentity assessment))
    (assessmentDispositionText
       (Qualification.qualificationAssessmentDisposition assessment))
    (map
       projectModelIdentity
       (Qualification.qualificationSelectedNeeds assessment))
    (map
       projectModelIdentity
       (Qualification.qualificationSelectedStrategies assessment))
    (map
       projectUnavailable
       (Qualification.qualificationSubjectUnavailable assessment))
    (map
       projectProposal
       (Qualification.qualificationUnroutedProposals assessment))
    (map projectPair (Qualification.qualificationPairAssessments assessment))

projectUnavailable ::
     Qualification.QualificationSubjectUnavailable scope
  -> HumanQualificationUnavailable
projectUnavailable unavailable =
  HumanQualificationUnavailable
    (case Qualification.qualificationUnavailableCategory unavailable of
       Qualification.QualificationNeedCategory -> "need"
       Qualification.QualificationStrategyCategory -> "strategy")
    (projectModelIdentity
       (Qualification.qualificationUnavailableIdentity unavailable))
    (unavailableReasonText
       (Qualification.qualificationUnavailableReason unavailable))
    (map
       projectOccurrenceIdentity
       (Qualification.qualificationUnavailableOccurrences unavailable))

projectPair ::
     Qualification.QualificationPairAssessment scope -> HumanQualificationPair
projectPair pair =
  HumanQualificationPair
    (projectModelIdentity (Qualification.qualificationPairNeed pair))
    (projectModelIdentity (Qualification.qualificationPairStrategy pair))
    (pairDispositionText (Qualification.qualificationPairDisposition pair))
    (map projectDiagnostic (Qualification.qualificationPairDiagnostics pair))
    (map projectProposal (Qualification.qualificationPairProposals pair))

projectProposal ::
     Qualification.QualificationProposalAssessment scope
  -> HumanQualificationProposal
projectProposal proposal =
  HumanQualificationProposal
    (projectModelIdentity (Qualification.qualificationProposalIdentity proposal))
    (projectOccurrenceIdentity
       (Qualification.qualificationProposalOccurrence proposal))
    (proposalDispositionText
       (Qualification.qualificationProposalDisposition proposal))
    (map
       projectDiagnostic
       (Qualification.qualificationProposalDiagnostics proposal))
    (projectAdmissible
       <$> Qualification.admissibleQualificationProposal proposal)

projectAdmissible ::
     Qualification.AdmissibleQualificationProposal scope
  -> HumanAdmissibleProposal
projectAdmissible proposal =
  HumanAdmissibleProposal
    (projectModelIdentity (Qualification.admissibleProposalIdentity proposal))
    (projectOccurrenceIdentity
       (Qualification.admissibleProposalOccurrence proposal))
    (projectModelIdentity (Qualification.admissibleNeedIdentity proposal))
    (projectModelIdentity (Qualification.admissibleStrategyIdentity proposal))
    (projectModelIdentity (Qualification.admissibleKeyResultIdentity proposal))
    (projectModelIdentity (Qualification.admissibleObjectiveIdentity proposal))
    (Qualification.admissibleRationale proposal)
    (Qualification.admissibleSources proposal)
    (map projectOccurrenceIdentity (Qualification.admissibleWitnesses proposal))

projectDiagnostic ::
     Qualification.QualificationDiagnosticEvidence scope
  -> HumanQualificationDiagnostic
projectDiagnostic diagnostic =
  HumanQualificationDiagnostic
    (coreRuleIdText (Qualification.qualificationDiagnosticRule diagnostic))
    (qualificationKindText
       (Qualification.qualificationDiagnosticKind diagnostic))
    (fmap
       projectSubject
       (Qualification.qualificationDiagnosticSubjects diagnostic))
    (fmap
       (\group ->
          HumanQualificationOccurrenceGroup
            (Qualification.qualificationOccurrenceGroupRole group)
            (map
               projectOccurrenceIdentity
               (Qualification.qualificationOccurrenceGroupOccurrences group)))
       (Qualification.qualificationDiagnosticOccurrenceGroups diagnostic))

projectSubject ::
     Qualification.QualificationDiagnosticSubject
  -> HumanQualificationSubjectValue
projectSubject =
  Qualification.foldQualificationDiagnosticSubject
    (\label value ->
       HumanQualificationModelSubject label (projectModelIdentity value))
    (\label value ->
       HumanQualificationOccurrenceSubject
         label
         (projectOccurrenceIdentity value))
    (\label value ->
       HumanQualificationRoleSubject
         label
         (Qualification.qualificationRoleText value))
    HumanQualificationTextSubject

assessmentDispositionText ::
     Qualification.QualificationAssessmentDisposition -> Text
assessmentDispositionText disposition =
  case disposition of
    Qualification.QualificationSubjectsUnavailable -> "subjects-unavailable"
    Qualification.QualificationPairOutcomesAvailable ->
      "pair-outcomes-available"

unavailableReasonText ::
     Qualification.QualificationSubjectUnavailableReason -> Text
unavailableReasonText reason =
  case reason of
    Qualification.QualificationSelectorUnknown -> "unknown"
    Qualification.QualificationSelectorAmbiguous -> "ambiguous"
    Qualification.QualificationSelectorOutOfSelectedView ->
      "out-of-selected-view"
    Qualification.QualificationSelectorWrongTypeOrFamily ->
      "wrong-type-or-family"
    Qualification.QualificationEligibilityPrerequisiteUnavailable ->
      "eligibility-prerequisite-unavailable"

pairDispositionText :: Qualification.QualificationPairDisposition -> Text
pairDispositionText disposition =
  case disposition of
    Qualification.QualificationPairInvalidSelectedSubjects ->
      "invalid-selected-subjects"
    Qualification.QualificationPairProposalMissing -> "proposal-missing"
    Qualification.QualificationPairProposalsAssessed -> "proposals-assessed"

proposalDispositionText ::
     Qualification.QualificationProposalDisposition -> Text
proposalDispositionText disposition =
  case disposition of
    Qualification.QualificationProposalRouteInvalid -> "route-invalid"
    Qualification.QualificationProposalFormallyInvalid -> "formally-invalid"
    Qualification.QualificationProposalFormallyAdmissible ->
      "formally-admissible"

qualificationKindText :: Qualification.QualificationEvidenceKind -> Text
qualificationKindText kind =
  case kind of
    Qualification.QualificationProposalEvidence -> "proposal"
    Qualification.QualificationProposalRoleEvidence -> "proposal-role"
    Qualification.QualificationProposalRoleTargetEvidence ->
      "proposal-role-target"
    Qualification.QualificationSelectedNeedEvidence -> "selected-need"
    Qualification.QualificationSelectedStrategyEvidence -> "selected-strategy"
    Qualification.QualificationPairEvidence -> "pair"
    Qualification.QualificationProposalRelationEvidence -> "proposal-relation"
