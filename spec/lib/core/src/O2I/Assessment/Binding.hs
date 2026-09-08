{-# LANGUAGE OverloadedStrings #-}

-- | Selected-View binding for one decoded Assessment bundle.
module O2I.Assessment.Binding
  ( bindAssessmentBundleInputInternal
  ) where

import O2I.Assessment.Internal
import O2I.Readiness.Binding (bindReadinessInputInternal)
import O2I.Readiness.Internal
import O2I.Structure (WellFormedGraph)

bindAssessmentBundleInputInternal ::
     WellFormedGraph scope
  -> AssessmentBundleInput
  -> AssessmentInputBinding scope
bindAssessmentBundleInputInternal graph bundle =
  case bindReadinessInputInternal graph (storedAssessmentReadiness bundle) of
    ReadinessInputSubjectUnavailable _ defects ->
      AssessmentInputSubjectUnavailable bundle (fmap toAssessmentDefect defects)
    ReadinessInputBound bound ->
      AssessmentInputBound (BoundAssessmentBundleInput bundle bound)
  where
    ordinal = storedAssessmentOrdinal bundle
    toAssessmentDefect defect =
      AssessmentInputDefect
        (storedEvidenceInputDefectRule defect)
        (storedEvidenceInputDefectKind defect)
        ordinal
        ("/readiness" <> storedEvidenceInputDefectPointer defect)
        (storedEvidenceInputDefectSubjects defect)
