module QualificationOpaqueConstructors where

import O2I.Qualification

forgeContext :: QualificationContext scope
forgeContext = QualificationContext undefined undefined

forgeAssessment :: QualificationAssessment scope
forgeAssessment =
  QualificationAssessment
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgeNeedSelector :: QualificationNeedSelector
forgeNeedSelector = QualificationNeedSelector undefined

forgeStrategySelector :: QualificationStrategySelector
forgeStrategySelector = QualificationStrategySelector undefined

forgeUnavailable :: QualificationSubjectUnavailable scope
forgeUnavailable =
  QualificationSubjectUnavailable undefined undefined undefined undefined

forgePair :: QualificationPairAssessment scope
forgePair = QualificationPairProposals undefined undefined undefined

forgeProposal :: QualificationProposalAssessment scope
forgeProposal = QualificationProposalAdmissible undefined

forgeProof :: AdmissibleQualificationProposal scope
forgeProof =
  AdmissibleQualificationProposal
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
