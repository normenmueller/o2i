module HumanClosedProjectionOpaqueConstructors where

import O2I.Operation.Human.Diagnostic
import O2I.Operation.Report

adapterRuleStage :: HumanAdapterRuleStage
adapterRuleStage = HumanAdapterNotationRuleStage

adapterRule :: HumanAdapterRule
adapterRule = HumanAdapterRule undefined undefined undefined undefined undefined

viewInventoryKind :: HumanViewInventoryIssueKind
viewInventoryKind = HumanViewInventoryIssueKind undefined

profileMarkerKind :: HumanProfileMarkerIssueKind
profileMarkerKind = HumanProfileMarkerIssueKind undefined

selectedUniverseKind :: HumanSelectedUniverseIssueKind
selectedUniverseKind = HumanSelectedUniverseIssueKind undefined

notationKind :: HumanNotationIssueKind
notationKind = HumanViewInventoryIssue undefined

draftValueKind :: HumanDraftValueKind
draftValueKind = HumanDraftTextValue

notationObservation :: HumanNotationObservation
notationObservation = HumanNotationOccurrence undefined

notationEvidence :: HumanNotationDiagnosticEvidence
notationEvidence =
  HumanNotationDiagnosticEvidence
    undefined
    undefined
    undefined
    undefined
    undefined

closureBranch :: HumanClosureBranch
closureBranch = HumanGraphClosureBranch

activationEvidence :: HumanActivationDiagnosticEvidence
activationEvidence =
  HumanActivationDiagnosticEvidence
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

profileEvidenceKind :: HumanProfileEvidenceKind
profileEvidenceKind = HumanCarrierOccurrenceEvidence

profileEvidence :: HumanProfileDiagnosticEvidence
profileEvidence = HumanProfileDiagnosticEvidence undefined

profileClassificationEvidence :: HumanProfileClassificationDiagnosticEvidence
profileClassificationEvidence =
  HumanProfileClassificationDiagnosticEvidence
    undefined
    undefined
    undefined
    undefined

profileMappingEvidence :: HumanProfileMappingDiagnosticEvidence
profileMappingEvidence =
  HumanProfileCarrierMapping undefined undefined undefined

profileInvariantEvidence :: HumanProfileInvariantDiagnosticEvidence
profileInvariantEvidence =
  HumanProfileInvariantDiagnosticEvidence undefined undefined

structureMultiplicity :: HumanStructureZeroOrMultipleOccurrences
structureMultiplicity = HumanNoStructureOccurrence

structureEvidence :: HumanStructureDiagnosticEvidence
structureEvidence = HumanStructureDiagnosticEvidence undefined

reportOperation :: ReportOperation
reportOperation = ViewsReportOperation

reportContract :: ReportContract
reportContract = AdapterReportContract

reportAuthority :: ReportAuthority
reportAuthority = PreparedReportAuthority undefined

reportEnvelope :: ReportEnvelope
reportEnvelope =
  ReportEnvelope undefined undefined undefined undefined undefined
