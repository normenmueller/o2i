module OpaqueConstructors where

import qualified O2I.Inspection.Adapter as Adapter
import qualified O2I.Inspection.Diagnostic as Diagnostic
import qualified O2I.Inspection.Pipeline as Pipeline
import qualified O2I.Inspection.Profile as Profile
import qualified O2I.Inspection.Provenance as Provenance

forgedDescriptor :: Adapter.AdapterDescriptor
forgedDescriptor = Adapter.AdapterDescriptor undefined undefined undefined

forgedNativeVersion :: Adapter.NativeVersion
forgedNativeVersion = Adapter.NativeVersion undefined

forgedCode :: Diagnostic.DiagnosticCode
forgedCode = Diagnostic.DiagnosticCode undefined

forgedId :: Diagnostic.DiagnosticId
forgedId = Diagnostic.DiagnosticId undefined

forgedSpec :: Diagnostic.DiagnosticSpec
forgedSpec =
  Diagnostic.DiagnosticSpec
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedDiagnostic :: Diagnostic.Diagnostic
forgedDiagnostic =
  Diagnostic.Diagnostic
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedDiagnostics :: Diagnostic.Diagnostics
forgedDiagnostics = Diagnostic.Diagnostics []

rewrittenDiagnosticId :: Diagnostic.Diagnostic -> Diagnostic.Diagnostic
rewrittenDiagnosticId diagnostic =
  diagnostic {Diagnostic.diagnosticId = undefined}

forgedProfileVersion :: Profile.O2IProfileVersion
forgedProfileVersion = Profile.O2IProfileVersion undefined

forgedSourced :: Pipeline.Sourced value
forgedSourced = Pipeline.Sourced undefined undefined

forgedSourceHash :: Provenance.SourceHash
forgedSourceHash = Provenance.SourceHash undefined

forgedSourceIdentity :: Provenance.SourceIdentity
forgedSourceIdentity = Provenance.SourceIdentity undefined undefined undefined

forgedQName :: Provenance.ExpandedQName
forgedQName = Provenance.ExpandedQName undefined undefined

forgedPathStep :: Provenance.PathStep
forgedPathStep = Provenance.PathStep undefined undefined

forgedSourceSpan :: Provenance.SourceSpan
forgedSourceSpan = Provenance.SourceSpan undefined undefined undefined undefined

forgedPosition :: Provenance.SourcePosition
forgedPosition = Provenance.SourcePosition undefined undefined undefined

forgedLocation :: Provenance.SourceLocation
forgedLocation =
  Provenance.SourceLocation undefined undefined undefined undefined

forgedOccurrenceKind :: Provenance.OccurrenceKind
forgedOccurrenceKind = Provenance.OccurrenceKind undefined

forgedOccurrenceId :: Provenance.OccurrenceId
forgedOccurrenceId = Provenance.OccurrenceId undefined

forgedOccurrenceProvenance :: Provenance.OccurrenceProvenance
forgedOccurrenceProvenance =
  Provenance.OccurrenceProvenance undefined undefined undefined

forgedClosedScopeProvenance :: Provenance.ClosedScopeProvenance
forgedClosedScopeProvenance = Provenance.ClosedScopeProvenance undefined

forgedSupplementalSource :: Provenance.SupplementalSource
forgedSupplementalSource = Provenance.SupplementalSource undefined undefined

foreignLocation ::
     Provenance.SourceIdentity
  -> Provenance.SourceLocation
  -> Provenance.SourceLocation
foreignLocation source location = location {Provenance.locationSource = source}

rewrittenSourceHash :: Provenance.SourceHash -> Provenance.SourceHash
rewrittenSourceHash sourceHash =
  sourceHash {Provenance.sourceHashText = undefined}

rewrittenSourceIdentity ::
     Provenance.SourceIdentity -> Provenance.SourceIdentity
rewrittenSourceIdentity identity =
  identity {Provenance.sourceDisplayLabel = undefined}

rewrittenQName :: Provenance.ExpandedQName -> Provenance.ExpandedQName
rewrittenQName name = name {Provenance.qNameNamespace = undefined}

rewrittenPathStep :: Provenance.PathStep -> Provenance.PathStep
rewrittenPathStep step = step {Provenance.pathStepName = undefined}

rewrittenSourceSpan :: Provenance.SourceSpan -> Provenance.SourceSpan
rewrittenSourceSpan sourceSpan =
  sourceSpan {Provenance.spanStartLine = undefined}

rewrittenOccurrenceKind ::
     Provenance.OccurrenceKind -> Provenance.OccurrenceKind
rewrittenOccurrenceKind kind = kind {Provenance.occurrenceKindText = undefined}

rewrittenOccurrenceId :: Provenance.OccurrenceId -> Provenance.OccurrenceId
rewrittenOccurrenceId identifier =
  identifier {Provenance.occurrenceIdText = undefined}

rewrittenOccurrenceProvenance ::
     Provenance.OccurrenceProvenance -> Provenance.OccurrenceProvenance
rewrittenOccurrenceProvenance provenance =
  provenance {Provenance.provenanceOccurrenceId = undefined}

rewrittenClosedScopeProvenance ::
     Provenance.ClosedScopeProvenance -> Provenance.ClosedScopeProvenance
rewrittenClosedScopeProvenance provenance =
  provenance {Provenance.closedScopeProvenanceOccurrences = undefined}

rewrittenSupplementalSource ::
     Provenance.SupplementalSource -> Provenance.SupplementalSource
rewrittenSupplementalSource supplemental =
  supplemental {Provenance.supplementalInputKind = undefined}
