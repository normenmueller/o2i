module ReadinessPublicApi where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity (ModelIdentity)
import O2I.Readiness
import O2I.Trace
  ( SuppliedTraceUnavailableReason
  , TraceIdentity
  , TracePromotionUnavailableReason
  )

bindingOutcome ::
     ReadinessInputBinding scope
  -> Either
       (ReadinessInput, NonEmpty EvidenceInputDefect)
       (BoundReadinessInput scope)
bindingOutcome =
  foldReadinessInputBinding (\input defects -> Left (input, defects)) Right

subjectOutcome ::
     ReadinessSubjectAssessment scope
  -> Either
       ( ModelIdentity
       , TraceIdentity
       , NonEmpty ReadinessSubjectUnavailableReason)
       (ReadinessSubject scope)
subjectOutcome =
  foldReadinessSubjectAssessment
    (\graph trace reasons -> Left (graph, trace, reasons))
    Right

unavailableReason ::
     ReadinessSubjectUnavailableReason
  -> Either SuppliedTraceUnavailableReason TracePromotionUnavailableReason
unavailableReason = foldReadinessSubjectUnavailableReason Left Right

assessmentOutcome ::
     ReadinessAssessment scope
  -> Either
       ( ModelIdentity
       , TraceIdentity
       , NonEmpty (ReadinessDiagnosticEvidence scope))
       (EvidenceReadyProof scope)
assessmentOutcome =
  foldReadinessAssessment
    (\graph trace diagnostics -> Left (graph, trace, diagnostics))
    Right
