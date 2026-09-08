module QualificationBoundCoercible where

import Data.Coerce (coerce)
import O2I.Qualification
  ( QualificationAssessment
  , QualificationContext
  , QualificationSubjectUnavailable
  )

coerceContext ::
     QualificationContext firstScope -> QualificationContext secondScope
coerceContext = coerce

coerceAssessment ::
     QualificationAssessment firstScope -> QualificationAssessment secondScope
coerceAssessment = coerce

coerceUnavailable ::
     QualificationSubjectUnavailable firstScope
  -> QualificationSubjectUnavailable secondScope
coerceUnavailable = coerce
