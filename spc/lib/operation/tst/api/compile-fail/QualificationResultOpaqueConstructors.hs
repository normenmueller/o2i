module QualificationResultOpaqueConstructors where

import O2I.Operation.Qualification.Subjects.Result
import O2I.Operation.Qualify.Result

invalidSubjects :: QualificationSubjectsResult
invalidSubjects = QualificationSubjectsFailed undefined

invalidQualify :: QualifyResult
invalidQualify = QualifyFailed undefined
