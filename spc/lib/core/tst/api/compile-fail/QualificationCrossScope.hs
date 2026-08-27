module QualificationCrossScope where

import O2I.Qualification (QualificationAssessment, QualificationContext)

crossScopeContext ::
     QualificationContext firstScope -> QualificationContext secondScope
crossScopeContext = id

crossScope ::
     QualificationAssessment firstScope -> QualificationAssessment secondScope
crossScope = id
