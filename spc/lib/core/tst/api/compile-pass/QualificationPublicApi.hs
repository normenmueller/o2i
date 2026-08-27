module QualificationPublicApi where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreQualificationProposalRoleId
  , CoreQualifiedEndpointId
  , CoreRuleId
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Qualification
import O2I.Semantics (SemanticAssessment)
import O2I.Structure (WellFormedGraph)

constructProposal ::
     OccurrenceIdentity
  -> ModelIdentity
  -> Maybe Text
  -> [(OccurrenceIdentity, Text)]
  -> [(OccurrenceIdentity, CoreQualificationProposalRoleId, OccurrenceIdentity)]
  -> QualificationProposalInput
constructProposal = qualificationProposalInput

constructNeedSelector :: ModelIdentity -> QualificationNeedSelector
constructNeedSelector = qualificationNeedSelector

constructStrategySelector :: ModelIdentity -> QualificationStrategySelector
constructStrategySelector = qualificationStrategySelector

prepare ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> Either QualificationContextError (QualificationContext scope)
prepare = prepareQualificationContext

discover ::
     QualificationContext scope
  -> ( [( ModelIdentity
        , OccurrenceIdentity
        , CoreQualifiedEndpointId
        , QualificationSubjectEligibility)]
     , [( ModelIdentity
        , OccurrenceIdentity
        , CoreQualifiedEndpointId
        , QualificationSubjectEligibility)])
discover context =
  ( map project (qualificationNeedSubjects subjects)
  , map project (qualificationStrategySubjects subjects))
  where
    subjects = qualificationSubjects context
    project subject =
      ( qualificationSubjectIdentity subject
      , qualificationSubjectOccurrence subject
      , qualificationSubjectQualifiedEndpoint subject
      , qualificationSubjectEligibility subject)

assess ::
     QualificationContext scope
  -> [QualificationNeedSelector]
  -> NonEmpty QualificationStrategySelector
  -> [QualificationProposalInput]
  -> QualificationAssessment scope
assess = assessQualification

summarizeAssessment ::
     QualificationAssessment scope
  -> ( ModelIdentity
     , QualificationAssessmentDisposition
     , [ModelIdentity]
     , [ModelIdentity]
     , [QualificationSubjectUnavailable scope]
     , [QualificationProposalAssessment scope]
     , [QualificationPairAssessment scope])
summarizeAssessment assessment =
  ( qualificationAssessmentGraphIdentity assessment
  , qualificationAssessmentDisposition assessment
  , qualificationSelectedNeeds assessment
  , qualificationSelectedStrategies assessment
  , qualificationSubjectUnavailable assessment
  , qualificationUnroutedProposals assessment
  , qualificationPairAssessments assessment)

summarizeUnavailable ::
     QualificationSubjectUnavailable scope
  -> ( QualificationSubjectCategory
     , ModelIdentity
     , QualificationSubjectUnavailableReason
     , [OccurrenceIdentity])
summarizeUnavailable unavailable =
  ( qualificationUnavailableCategory unavailable
  , qualificationUnavailableIdentity unavailable
  , qualificationUnavailableReason unavailable
  , qualificationUnavailableOccurrences unavailable)

summarizePair ::
     QualificationPairAssessment scope
  -> ( QualificationPairDisposition
     , ModelIdentity
     , ModelIdentity
     , [QualificationDiagnosticEvidence scope]
     , [QualificationProposalAssessment scope])
summarizePair pair =
  ( qualificationPairDisposition pair
  , qualificationPairNeed pair
  , qualificationPairStrategy pair
  , qualificationPairDiagnostics pair
  , qualificationPairProposals pair)

summarizeProposal ::
     QualificationProposalAssessment scope
  -> ( QualificationProposalDisposition
     , ModelIdentity
     , OccurrenceIdentity
     , [QualificationDiagnosticEvidence scope]
     , Maybe (AdmissibleQualificationProposal scope))
summarizeProposal proposal =
  ( qualificationProposalDisposition proposal
  , qualificationProposalIdentity proposal
  , qualificationProposalOccurrence proposal
  , qualificationProposalDiagnostics proposal
  , admissibleQualificationProposal proposal)

summarizeProof ::
     AdmissibleQualificationProposal scope
  -> ( ModelIdentity
     , OccurrenceIdentity
     , ModelIdentity
     , ModelIdentity
     , ModelIdentity
     , ModelIdentity
     , Text
     , NonEmpty Text
     , [OccurrenceIdentity])
summarizeProof proof =
  ( admissibleProposalIdentity proof
  , admissibleProposalOccurrence proof
  , admissibleNeedIdentity proof
  , admissibleStrategyIdentity proof
  , admissibleKeyResultIdentity proof
  , admissibleObjectiveIdentity proof
  , admissibleRationale proof
  , admissibleSources proof
  , admissibleWitnesses proof)

summarizeDiagnostic ::
     QualificationDiagnosticEvidence scope
  -> ( CoreRuleId
     , QualificationEvidenceKind
     , NonEmpty QualificationDiagnosticSubject
     , NonEmpty QualificationOccurrenceGroup)
summarizeDiagnostic diagnostic =
  ( qualificationDiagnosticRule diagnostic
  , qualificationDiagnosticKind diagnostic
  , qualificationDiagnosticSubjects diagnostic
  , qualificationDiagnosticOccurrenceGroups diagnostic)
