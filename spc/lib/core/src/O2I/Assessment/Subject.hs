-- | Core-owned reconstruction of the complete Assessment prerequisite.
module O2I.Assessment.Subject
  ( prepareAssessmentSubjectInternal
  ) where

import O2I.Assessment.Internal
import O2I.Readiness.Eval
  ( assessReadinessWithWorkInternal
  , prepareReadinessSubjectInternal
  )
import O2I.Readiness.Internal
import O2I.Semantics (SemanticAssessment, SemanticallyValidModel)

prepareAssessmentSubjectInternal ::
     SemanticallyValidModel scope
  -> SemanticAssessment scope
  -> BoundAssessmentBundleInput scope
  -> AssessmentSubjectAssessment scope
prepareAssessmentSubjectInternal model semantics boundBundle =
  case prepareReadinessSubjectInternal model semantics boundReadiness of
    ReadinessSubjectUnavailable graph trace reasons ->
      AssessmentSubjectUnavailable
        graph
        trace
        (fmap AssessmentReadinessSubjectUnavailable reasons)
    ReadinessSubjectAvailable readinessSubject ->
      case assessReadinessWithWorkInternal readinessSubject of
        (ReadinessNotReady graph trace defects, _) ->
          AssessmentSubjectUnavailable
            graph
            trace
            (fmap AssessmentReadinessCriterionNotSatisfied defects)
        (ReadinessReady proof, work) ->
          AssessmentSubjectAvailable
            (AssessmentSubject
               proof
               boundBundle
               (storedReadinessSuppliedSupportCount readinessSubject)
               (readinessCriteriaEvaluated work))
  where
    boundReadiness = storedBoundAssessmentReadiness boundBundle
