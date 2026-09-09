module AssessmentCrossScope where

import O2I.Assessment

crossBound ::
     BoundAssessmentBundleInput firstScope
  -> BoundAssessmentBundleInput secondScope
crossBound = id

crossSubject :: AssessmentSubject firstScope -> AssessmentSubject secondScope
crossSubject = id

crossProof ::
     EvidenceAssessedProof firstScope -> EvidenceAssessedProof secondScope
crossProof = id
