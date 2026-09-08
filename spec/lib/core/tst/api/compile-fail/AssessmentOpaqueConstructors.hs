module AssessmentOpaqueConstructors where

import O2I.Assessment

forgeBundle :: AssessmentBundleInput
forgeBundle =
  AssessmentBundleInput undefined undefined undefined undefined undefined

forgeBound :: BoundAssessmentBundleInput scope
forgeBound = BoundAssessmentBundleInput undefined undefined

forgeSubject :: AssessmentSubject scope
forgeSubject = AssessmentSubject undefined undefined undefined undefined

forgeProof :: EvidenceAssessedProof scope
forgeProof = EvidenceAssessedProof undefined undefined undefined
