{-# LANGUAGE OverloadedStrings #-}

-- | Canonical fragments shared by Qualification machine documents.
module O2I.Operation.Qualify.Machine.Internal
  ( qualificationAssessmentFragment
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , arrayFragment
  , closedObjectFragment
  , nullFragment
  , requiredMember
  , textFragment
  )
import qualified O2I.Qualification as Qualification

qualificationAssessmentFragment ::
     Qualification.QualificationAssessment scope -> CanonicalFragment
qualificationAssessmentFragment assessment =
  closedObjectFragment
    [ requiredMember
        "graphIdentity"
        (modelIdentityFragment
           (Qualification.qualificationAssessmentGraphIdentity assessment))
    , requiredMember
        "disposition"
        (textFragment
           (assessmentDispositionText
              (Qualification.qualificationAssessmentDisposition assessment)))
    , requiredMember
        "selectedNeeds"
        (modelIdentityArray
           (Qualification.qualificationSelectedNeeds assessment))
    , requiredMember
        "selectedStrategies"
        (modelIdentityArray
           (Qualification.qualificationSelectedStrategies assessment))
    , requiredMember
        "subjectUnavailable"
        (arrayFragment
           (map
              qualificationUnavailableFragment
              (Qualification.qualificationSubjectUnavailable assessment)))
    , requiredMember
        "unroutedProposals"
        (arrayFragment
           (map
              qualificationProposalFragment
              (Qualification.qualificationUnroutedProposals assessment)))
    , requiredMember
        "pairs"
        (arrayFragment
           (map
              qualificationPairFragment
              (Qualification.qualificationPairAssessments assessment)))
    ]

assessmentDispositionText ::
     Qualification.QualificationAssessmentDisposition -> Text
assessmentDispositionText disposition =
  case disposition of
    Qualification.QualificationSubjectsUnavailable -> "subjects-unavailable"
    Qualification.QualificationPairOutcomesAvailable ->
      "pair-outcomes-available"

qualificationUnavailableFragment ::
     Qualification.QualificationSubjectUnavailable scope -> CanonicalFragment
qualificationUnavailableFragment unavailable =
  closedObjectFragment
    [ requiredMember
        "category"
        (textFragment
           (unavailableCategoryText
              (Qualification.qualificationUnavailableCategory unavailable)))
    , requiredMember
        "identity"
        (modelIdentityFragment
           (Qualification.qualificationUnavailableIdentity unavailable))
    , requiredMember
        "reason"
        (textFragment
           (unavailableReasonText
              (Qualification.qualificationUnavailableReason unavailable)))
    , requiredMember
        "occurrences"
        (occurrenceIdentityArray
           (Qualification.qualificationUnavailableOccurrences unavailable))
    ]

unavailableCategoryText :: Qualification.QualificationSubjectCategory -> Text
unavailableCategoryText category =
  case category of
    Qualification.QualificationNeedCategory -> "need"
    Qualification.QualificationStrategyCategory -> "strategy"

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

qualificationPairFragment ::
     Qualification.QualificationPairAssessment scope -> CanonicalFragment
qualificationPairFragment pair =
  closedObjectFragment
    [ requiredMember
        "need"
        (modelIdentityFragment (Qualification.qualificationPairNeed pair))
    , requiredMember
        "strategy"
        (modelIdentityFragment (Qualification.qualificationPairStrategy pair))
    , requiredMember
        "disposition"
        (textFragment
           (pairDispositionText
              (Qualification.qualificationPairDisposition pair)))
    , requiredMember
        "diagnostics"
        (arrayFragment
           (map
              qualificationDiagnosticFragment
              (Qualification.qualificationPairDiagnostics pair)))
    , requiredMember
        "proposals"
        (arrayFragment
           (map
              qualificationProposalFragment
              (Qualification.qualificationPairProposals pair)))
    ]

pairDispositionText :: Qualification.QualificationPairDisposition -> Text
pairDispositionText disposition =
  case disposition of
    Qualification.QualificationPairInvalidSelectedSubjects ->
      "invalid-selected-subjects"
    Qualification.QualificationPairProposalMissing -> "proposal-missing"
    Qualification.QualificationPairProposalsAssessed -> "proposals-assessed"

qualificationProposalFragment ::
     Qualification.QualificationProposalAssessment scope -> CanonicalFragment
qualificationProposalFragment proposal =
  closedObjectFragment
    [ requiredMember
        "identity"
        (modelIdentityFragment
           (Qualification.qualificationProposalIdentity proposal))
    , requiredMember
        "occurrence"
        (occurrenceIdentityFragment
           (Qualification.qualificationProposalOccurrence proposal))
    , requiredMember
        "disposition"
        (textFragment
           (proposalDispositionText
              (Qualification.qualificationProposalDisposition proposal)))
    , requiredMember
        "diagnostics"
        (arrayFragment
           (map
              qualificationDiagnosticFragment
              (Qualification.qualificationProposalDiagnostics proposal)))
    , requiredMember
        "admissible"
        (maybe
           nullFragment
           admissibleProposalFragment
           (Qualification.admissibleQualificationProposal proposal))
    ]

proposalDispositionText ::
     Qualification.QualificationProposalDisposition -> Text
proposalDispositionText disposition =
  case disposition of
    Qualification.QualificationProposalRouteInvalid -> "route-invalid"
    Qualification.QualificationProposalFormallyInvalid -> "formally-invalid"
    Qualification.QualificationProposalFormallyAdmissible ->
      "formally-admissible"

admissibleProposalFragment ::
     Qualification.AdmissibleQualificationProposal scope -> CanonicalFragment
admissibleProposalFragment proposal =
  closedObjectFragment
    [ requiredMember
        "proposal"
        (modelIdentityFragment
           (Qualification.admissibleProposalIdentity proposal))
    , requiredMember
        "occurrence"
        (occurrenceIdentityFragment
           (Qualification.admissibleProposalOccurrence proposal))
    , requiredMember
        "need"
        (modelIdentityFragment (Qualification.admissibleNeedIdentity proposal))
    , requiredMember
        "strategy"
        (modelIdentityFragment
           (Qualification.admissibleStrategyIdentity proposal))
    , requiredMember
        "keyResult"
        (modelIdentityFragment
           (Qualification.admissibleKeyResultIdentity proposal))
    , requiredMember
        "objective"
        (modelIdentityFragment
           (Qualification.admissibleObjectiveIdentity proposal))
    , requiredMember
        "rationale"
        (textFragment (Qualification.admissibleRationale proposal))
    , requiredMember
        "sources"
        (arrayFragment
           (map
              textFragment
              (NonEmpty.toList (Qualification.admissibleSources proposal))))
    , requiredMember
        "witnesses"
        (occurrenceIdentityArray (Qualification.admissibleWitnesses proposal))
    ]

qualificationDiagnosticFragment ::
     Qualification.QualificationDiagnosticEvidence scope -> CanonicalFragment
qualificationDiagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "ruleId"
        (textFragment
           (coreRuleIdText
              (Qualification.qualificationDiagnosticRule diagnostic)))
    , requiredMember
        "evidenceKind"
        (textFragment
           (qualificationEvidenceKindText
              (Qualification.qualificationDiagnosticKind diagnostic)))
    , requiredMember
        "subjects"
        (arrayFragment
           (map
              qualificationDiagnosticSubjectFragment
              (NonEmpty.toList
                 (Qualification.qualificationDiagnosticSubjects diagnostic))))
    , requiredMember
        "occurrenceGroups"
        (arrayFragment
           (map
              qualificationOccurrenceGroupFragment
              (NonEmpty.toList
                 (Qualification.qualificationDiagnosticOccurrenceGroups
                    diagnostic))))
    ]

qualificationEvidenceKindText :: Qualification.QualificationEvidenceKind -> Text
qualificationEvidenceKindText kind =
  case kind of
    Qualification.QualificationProposalEvidence -> "proposal"
    Qualification.QualificationProposalRoleEvidence -> "proposal-role"
    Qualification.QualificationProposalRoleTargetEvidence ->
      "proposal-role-target"
    Qualification.QualificationSelectedNeedEvidence -> "selected-need"
    Qualification.QualificationSelectedStrategyEvidence -> "selected-strategy"
    Qualification.QualificationPairEvidence -> "pair"
    Qualification.QualificationProposalRelationEvidence -> "proposal-relation"

qualificationDiagnosticSubjectFragment ::
     Qualification.QualificationDiagnosticSubject -> CanonicalFragment
qualificationDiagnosticSubjectFragment =
  Qualification.foldQualificationDiagnosticSubject
    (\label value -> subjectFragment "model" label (modelIdentityFragment value))
    (\label value ->
       subjectFragment "occurrence" label (occurrenceIdentityFragment value))
    (\label value ->
       subjectFragment
         "role"
         label
         (textFragment (Qualification.qualificationRoleText value)))
    (\label value -> subjectFragment "text" label (textFragment value))

subjectFragment :: Text -> Text -> CanonicalFragment -> CanonicalFragment
subjectFragment kind label value =
  closedObjectFragment
    [ requiredMember "kind" (textFragment kind)
    , requiredMember "label" (textFragment label)
    , requiredMember "value" value
    ]

qualificationOccurrenceGroupFragment ::
     Qualification.QualificationOccurrenceGroup -> CanonicalFragment
qualificationOccurrenceGroupFragment group =
  closedObjectFragment
    [ requiredMember
        "role"
        (textFragment (Qualification.qualificationOccurrenceGroupRole group))
    , requiredMember
        "occurrences"
        (occurrenceIdentityArray
           (Qualification.qualificationOccurrenceGroupOccurrences group))
    ]

modelIdentityArray :: [ModelIdentity] -> CanonicalFragment
modelIdentityArray = arrayFragment . map modelIdentityFragment

modelIdentityFragment :: ModelIdentity -> CanonicalFragment
modelIdentityFragment = textFragment . modelIdentityText

occurrenceIdentityArray :: [OccurrenceIdentity] -> CanonicalFragment
occurrenceIdentityArray = arrayFragment . map occurrenceIdentityFragment

occurrenceIdentityFragment :: OccurrenceIdentity -> CanonicalFragment
occurrenceIdentityFragment = textFragment . occurrenceIdentityText
