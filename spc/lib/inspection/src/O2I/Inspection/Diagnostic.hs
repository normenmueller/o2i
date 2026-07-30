-- | Public diagnostic vocabulary and stage-free adapter defect descriptions.
--
-- Adapters may describe defects, but only Inspection assigns pipeline stages,
-- source provenance, and canonical machine identities. Normalized diagnostics
-- are therefore observable but not constructible through this module.
module O2I.Inspection.Diagnostic
  ( InspectionStage(..)
  , DiagnosticSeverity(..)
  , DiagnosticDisposition(..)
  , DiagnosticCode
  , DiagnosticCodeError(..)
  , mkDiagnosticCode
  , o2iDiagnosticCode
  , diagnosticCodeText
  , DiagnosticId
  , diagnosticIdText
  , DiagnosticAtom(..)
  , DiagnosticSubject(..)
  , DiagnosticSpec
  , diagnosticSpec
  , specCode
  , specSeverity
  , specDisposition
  , specMessage
  , specSubjects
  , specData
  , Diagnostic
  , diagnosticId
  , diagnosticCode
  , diagnosticStage
  , diagnosticSeverity
  , diagnosticDisposition
  , diagnosticMessage
  , diagnosticSubjects
  , diagnosticLocations
  , diagnosticSupplementalSources
  , diagnosticData
  , Diagnostics
  , diagnosticsList
  , rawEdgeSubjectIdentifier
  , structuralDefectSpec
  , candidatePropositionSpec
  , modelSemanticErrorSpec
  , semanticDefectSpec
  , collectiveRealizationErrorSpec
  , candidateCollectiveRealizationIssueSpec
  , candidateCollectiveRealizationSpec
  , traceabilityDefectSpec
  , readinessDefectSpec
  , evidenceDefectSpec
  ) where

import Data.Map.Strict (Map)
import Data.Text (Text)
import O2I.Inspection.Diagnostic.Internal
  ( Diagnostic
  , DiagnosticAtom(..)
  , DiagnosticCode
  , DiagnosticCodeError(..)
  , DiagnosticDisposition(..)
  , DiagnosticId
  , DiagnosticSeverity(..)
  , DiagnosticSpec
  , DiagnosticSubject(..)
  , Diagnostics
  , InspectionStage(..)
  , candidateCollectiveRealizationIssueSpec
  , candidateCollectiveRealizationSpec
  , candidatePropositionSpec
  , collectiveRealizationErrorSpec
  , diagnosticSpec
  , diagnosticsList
  , evidenceDefectSpec
  , mkDiagnosticCode
  , modelSemanticErrorSpec
  , o2iDiagnosticCode
  , rawEdgeSubjectIdentifier
  , readinessDefectSpec
  , semanticDefectSpec
  , structuralDefectSpec
  , traceabilityDefectSpec
  )
import qualified O2I.Inspection.Diagnostic.Internal as Internal
import O2I.Inspection.Provenance (SourceLocation, SupplementalSource)

-- | Read a validated machine-readable code.
diagnosticCodeText :: DiagnosticCode -> Text
diagnosticCodeText = Internal.diagnosticCodeText

-- | Read the canonical identity of a normalized diagnostic occurrence.
diagnosticIdText :: DiagnosticId -> Text
diagnosticIdText = Internal.diagnosticIdText

-- | Read the code from a stage-free defect description.
specCode :: DiagnosticSpec -> DiagnosticCode
specCode = Internal.specCode

-- | Read the severity from a stage-free defect description.
specSeverity :: DiagnosticSpec -> DiagnosticSeverity
specSeverity = Internal.specSeverity

-- | Read the disposition from a stage-free defect description.
specDisposition :: DiagnosticSpec -> DiagnosticDisposition
specDisposition = Internal.specDisposition

-- | Read the human message from a stage-free defect description.
specMessage :: DiagnosticSpec -> Text
specMessage = Internal.specMessage

-- | Read structured subjects from a stage-free defect description.
specSubjects :: DiagnosticSpec -> [DiagnosticSubject]
specSubjects = Internal.specSubjects

-- | Read machine data from a stage-free defect description.
specData :: DiagnosticSpec -> Map Text DiagnosticAtom
specData = Internal.specData

-- | Read the canonical identity assigned by Inspection.
diagnosticId :: Diagnostic -> DiagnosticId
diagnosticId = Internal.diagnosticId

-- | Read the validated diagnostic code.
diagnosticCode :: Diagnostic -> DiagnosticCode
diagnosticCode = Internal.diagnosticCode

-- | Read the Inspection-owned stage.
diagnosticStage :: Diagnostic -> InspectionStage
diagnosticStage = Internal.diagnosticStage

-- | Read the diagnostic severity.
diagnosticSeverity :: Diagnostic -> DiagnosticSeverity
diagnosticSeverity = Internal.diagnosticSeverity

-- | Read whether the diagnostic is a model finding or process failure.
diagnosticDisposition :: Diagnostic -> DiagnosticDisposition
diagnosticDisposition = Internal.diagnosticDisposition

-- | Read the human diagnostic message.
diagnosticMessage :: Diagnostic -> Text
diagnosticMessage = Internal.diagnosticMessage

-- | Read the structured diagnostic subjects.
diagnosticSubjects :: Diagnostic -> [DiagnosticSubject]
diagnosticSubjects = Internal.diagnosticSubjects

-- | Read exact primary-source provenance.
diagnosticLocations :: Diagnostic -> [SourceLocation]
diagnosticLocations = Internal.diagnosticLocations

-- | Read supplemental sources consumed by the owning stage.
diagnosticSupplementalSources :: Diagnostic -> [SupplementalSource]
diagnosticSupplementalSources = Internal.diagnosticSupplementalSources

-- | Read deterministic machine data.
diagnosticData :: Diagnostic -> Map Text DiagnosticAtom
diagnosticData = Internal.diagnosticData
