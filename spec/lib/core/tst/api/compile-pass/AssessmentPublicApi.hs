module AssessmentPublicApi where

import Data.List.NonEmpty (NonEmpty)
import O2I.Assessment
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Identity (ModelIdentity)
import O2I.Readiness (ReadinessEvidenceKey, ReadinessSubjectUnavailableReason)
import O2I.Trace (TraceIdentity)

bindingOutcome ::
     AssessmentInputBinding scope
  -> Either
       (AssessmentBundleInput, NonEmpty AssessmentInputDefect)
       (BoundAssessmentBundleInput scope)
bindingOutcome =
  foldAssessmentInputBinding (\input defects -> Left (input, defects)) Right

subjectOutcome ::
     AssessmentSubjectAssessment scope
  -> Either
       ( ModelIdentity
       , TraceIdentity
       , NonEmpty AssessmentSubjectUnavailableReason)
       (AssessmentSubject scope)
subjectOutcome =
  foldAssessmentSubjectAssessment
    (\graph trace reasons -> Left (graph, trace, reasons))
    Right

unavailableReason ::
     AssessmentSubjectUnavailableReason
  -> Either ReadinessSubjectUnavailableReason (CoreRuleId, ReadinessEvidenceKey)
unavailableReason =
  foldAssessmentSubjectUnavailableReason Left (\rule key -> Right (rule, key))

observationOutcome ::
     ObservationAssessment scope
  -> Either
       (Observation, NonEmpty (AssessmentDiagnosticEvidence scope))
       (EffectResult, TargetAttainment, NonEmpty AssessmentLimitationKind)
observationOutcome =
  foldObservationAssessment
    (\observation diagnostics -> Left (observation, diagnostics))
    (\_ effect target limitations -> Right (effect, target, limitations))

resultOutcome ::
     AssessmentResult scope
  -> Either
       ( ModelIdentity
       , TraceIdentity
       , NonEmpty (AssessmentDiagnosticEvidence scope))
       ([ObservationAssessment scope], Maybe (EvidenceAssessedProof scope))
resultOutcome =
  foldAssessmentResult
    (\graph trace diagnostics -> Left (graph, trace, diagnostics))
    (\observations proof -> Right (observations, proof))

limitationOutcome :: AssessmentLimitationKind -> Bool
limitationOutcome = foldAssessmentLimitationKind False True
