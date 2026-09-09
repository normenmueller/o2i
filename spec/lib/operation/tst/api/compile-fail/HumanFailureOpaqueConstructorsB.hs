module HumanFailureOpaqueConstructorsB where

import qualified O2I.Operation.Assess.Human as Assess
import qualified O2I.Operation.Human.Failure as Failure
import qualified O2I.Operation.Qualification.Subjects.Human as Subjects
import qualified O2I.Operation.Qualify.Human as Qualify
import qualified O2I.Operation.Readiness.Human as Readiness
import qualified O2I.Operation.Trace.Human as Trace
import qualified O2I.Operation.Validate.Human as Validate

viewCandidate :: Failure.HumanFailureViewSelectionCandidate
viewCandidate =
  Failure.HumanFailureViewSelectionCandidate
    undefined
    undefined
    undefined
    undefined

viewFailure :: Failure.HumanViewSelectionFailure
viewFailure = Failure.HumanViewSelectionUnknown undefined

preparation :: Failure.HumanPreparationFailure
preparation =
  Failure.HumanAdapterSelectionPreparationFailure undefined undefined

common :: Failure.HumanCommonFailure
common = Failure.HumanOperationPreparationFailure undefined

inputSubject :: Failure.HumanInputDefectSubject
inputSubject = Failure.HumanInputTextSubject undefined undefined

inputKind :: Failure.HumanInputDefectKind
inputKind = Failure.HumanInputInvalidUtf8

inputDefect :: Failure.HumanInputDefect
inputDefect =
  Failure.HumanInputDefect undefined undefined undefined undefined undefined

payload :: Failure.HumanSupplementalPayloadType
payload = Failure.HumanStrategyFormulationPayload

supplemental :: Failure.HumanSupplementalInputDefect
supplemental = Failure.HumanSupplementalInvalidUtf8 undefined undefined

notation :: Failure.HumanNotationContractFailure
notation = Failure.HumanNotationRuleMissing undefined undefined

profile :: Failure.HumanProfileContractEvidence
profile = Failure.HumanUnknownGeneratedProfileRule undefined undefined

identity :: Failure.HumanIdentityIndexDefect
identity = Failure.HumanIdentityIndexDefect undefined undefined

scopeKind :: Failure.HumanSelectedViewScopeDefectKind
scopeKind = Failure.HumanUnknownSelectedViewSubjectOccurrence

scope :: Failure.HumanSelectedViewScopeDefect
scope = Failure.HumanSelectedViewScopeDefect undefined undefined undefined

structure :: Failure.HumanStructureInputDefect
structure = Failure.HumanProjectionOutsideSelectedView undefined

provenance :: Failure.HumanSupplementalProvenanceDefect
provenance = Failure.HumanModelSourceIsNotSupplemental undefined

subjects :: Subjects.HumanQualificationSubjectsFailure
subjects = Subjects.HumanQualificationSubjectsContextFailure

validate :: Validate.HumanValidateFailure
validate = Validate.HumanValidateCommonFailure undefined

trace :: Trace.HumanTraceFailure
trace = Trace.HumanTraceCommonFailure undefined

qualify :: Qualify.HumanQualifyFailure
qualify = Qualify.HumanQualifyContextFailure

readiness :: Readiness.HumanReadinessFailure
readiness = Readiness.HumanReadinessCommonFailure undefined

assess :: Assess.HumanAssessFailure
assess = Assess.HumanAssessCommonFailure undefined
