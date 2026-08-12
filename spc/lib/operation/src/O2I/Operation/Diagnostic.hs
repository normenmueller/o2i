{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Common typed diagnostics without caller-extensible detail maps.
--
-- Stable codes, authorities, and stages are projected from their compiled
-- rule owners. Exact source, native, Draft, canonical, and subject
-- occurrences remain distinct typed alternatives.
module O2I.Operation.Diagnostic
  ( type DiagnosticCode
  , diagnosticCodeText
  , type DiagnosticSeverity
  , debugSeverity
  , infoSeverity
  , warningSeverity
  , errorSeverity
  , diagnosticSeverityText
  , foldDiagnosticSeverity
  , type DiagnosticDisposition
  , modelFinding
  , processFailure
  , diagnosticDispositionText
  , foldDiagnosticDisposition
  , type DiagnosticProvenance
  , diagnosticProvenanceIdentity
  , diagnosticProvenanceAuthority
  , diagnosticProvenanceStage
  , foldDiagnosticProvenance
  , type DiagnosticOccurrence
  , foldDiagnosticOccurrence
  , type Diagnostic
  , diagnosticCode
  , diagnosticRuleIdentity
  , diagnosticSeverity
  , diagnosticDisposition
  , diagnosticProvenance
  , diagnosticOccurrences
  , foldDiagnostic
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftLocation)
import O2I.ArchiMate.Profile.Notation (CanonicalOccurrence)
import O2I.ArchiMate.Profile.Rule.Explanation
  ( ProfileRuleExplanation
  , profileRuleId
  , profileRuleIdText
  , profileRuleProfileReference
  , profileRuleStage
  , profileRuleStageText
  )
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (ModelIdentity)
import O2I.Core.Rule.Catalog
  ( CoreRule
  , coreRuleIdentity
  , coreRuleStage
  , coreRuleStageText
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterOccurrence
  , AdapterRule
  , adapterDescriptorId
  , adapterIdText
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleStage
  , adapterRuleStageText
  )
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Provenance (SourceIdentity)
import O2I.Operation.Rule.Catalog
  ( OperationRule
  , operationRuleIdText
  , operationRuleIdentity
  , operationRuleStage
  , operationRuleStageText
  )

-- | Project the stable namespaced diagnostic code.
diagnosticCodeText :: DiagnosticCode -> Text
diagnosticCodeText (DiagnosticCode value) = value

-- | Severity for diagnostic execution detail.
debugSeverity :: DiagnosticSeverity
debugSeverity = DebugSeverity

-- | Severity for non-failing operational information.
infoSeverity :: DiagnosticSeverity
infoSeverity = InfoSeverity

-- | Severity for a non-fatal concern requiring attention.
warningSeverity :: DiagnosticSeverity
warningSeverity = WarningSeverity

-- | Severity for a failed operation or invalid result.
errorSeverity :: DiagnosticSeverity
errorSeverity = ErrorSeverity

-- | Render one severity as its stable machine value.
diagnosticSeverityText :: DiagnosticSeverity -> Text
diagnosticSeverityText severity =
  case severity of
    DebugSeverity -> "debug"
    InfoSeverity -> "info"
    WarningSeverity -> "warning"
    ErrorSeverity -> "error"

-- | Consume every closed diagnostic severity.
foldDiagnosticSeverity ::
     result -> result -> result -> result -> DiagnosticSeverity -> result
foldDiagnosticSeverity debug info warning failure severity =
  case severity of
    DebugSeverity -> debug
    InfoSeverity -> info
    WarningSeverity -> warning
    ErrorSeverity -> failure

-- | Disposition for a finding attributable to model content.
modelFinding :: DiagnosticDisposition
modelFinding = ModelFinding

-- | Disposition for a failure of acquisition or processing.
processFailure :: DiagnosticDisposition
processFailure = ProcessFailure

-- | Render one disposition as its stable machine value.
diagnosticDispositionText :: DiagnosticDisposition -> Text
diagnosticDispositionText disposition =
  case disposition of
    ModelFinding -> "model-finding"
    ProcessFailure -> "process-failure"

-- | Consume either closed diagnostic disposition.
foldDiagnosticDisposition :: result -> result -> DiagnosticDisposition -> result
foldDiagnosticDisposition finding failure disposition =
  case disposition of
    ModelFinding -> finding
    ProcessFailure -> failure

-- | Exact compiled rule identity and therefore the stable diagnostic code.
diagnosticProvenanceIdentity :: DiagnosticProvenance -> Text
diagnosticProvenanceIdentity provenance =
  case provenance of
    OperationDiagnosticProvenance rule ->
      operationRuleIdText (operationRuleIdentity rule)
    AdapterDiagnosticProvenance _ rule -> adapterRuleIdText (adapterRuleId rule)
    ProfileDiagnosticProvenance rule -> profileRuleIdText (profileRuleId rule)
    CoreDiagnosticProvenance rule -> coreRuleIdText (coreRuleIdentity rule)

-- | Stable closed authority, including exact adapter or Profile identity.
diagnosticProvenanceAuthority :: DiagnosticProvenance -> Text
diagnosticProvenanceAuthority provenance =
  case provenance of
    OperationDiagnosticProvenance _ -> "Operation"
    AdapterDiagnosticProvenance descriptor _ ->
      "Adapter:" <> adapterIdText (adapterDescriptorId descriptor)
    ProfileDiagnosticProvenance rule ->
      "Profile:" <> profileRuleProfileReference rule
    CoreDiagnosticProvenance _ -> "Core"

-- | Exact owner-defined stage without a second stage taxonomy.
diagnosticProvenanceStage :: DiagnosticProvenance -> Text
diagnosticProvenanceStage provenance =
  case provenance of
    OperationDiagnosticProvenance rule ->
      operationRuleStageText (operationRuleStage rule)
    AdapterDiagnosticProvenance _ rule ->
      adapterRuleStageText (adapterRuleStage rule)
    ProfileDiagnosticProvenance rule ->
      profileRuleStageText (profileRuleStage rule)
    CoreDiagnosticProvenance rule -> coreRuleStageText (coreRuleStage rule)

-- | Consume every exact rule-owner alternative.
foldDiagnosticProvenance ::
     (OperationRule -> result)
  -> (AdapterDescriptor -> AdapterRule -> result)
  -> (ProfileRuleExplanation -> result)
  -> (CoreRule -> result)
  -> DiagnosticProvenance
  -> result
foldDiagnosticProvenance operation adapter profile core provenance =
  case provenance of
    OperationDiagnosticProvenance rule -> operation rule
    AdapterDiagnosticProvenance descriptor rule -> adapter descriptor rule
    ProfileDiagnosticProvenance rule -> profile rule
    CoreDiagnosticProvenance rule -> core rule

-- | Consume every closed occurrence shape while preserving source identity.
foldDiagnosticOccurrence ::
     (SourceIdentity -> result)
  -> (SourceIdentity -> AdapterOccurrence -> result)
  -> (SourceIdentity -> DraftLocation -> result)
  -> (SourceIdentity -> CanonicalOccurrence -> result)
  -> (SourceIdentity -> ModelIdentity -> result)
  -> DiagnosticOccurrence
  -> result
foldDiagnosticOccurrence source native draft canonical subject occurrence =
  case occurrence of
    SourceDiagnosticOccurrence identity -> source identity
    AdapterDiagnosticOccurrence identity location -> native identity location
    DraftDiagnosticOccurrence identity location -> draft identity location
    CanonicalDiagnosticOccurrence identity location ->
      canonical identity location
    SubjectDiagnosticOccurrence identity modelIdentity ->
      subject identity modelIdentity

-- | Derive the stable namespaced code from the exact owning rule.
diagnosticCode :: Diagnostic -> DiagnosticCode
diagnosticCode (Diagnostic _ _ provenance _) =
  DiagnosticCode
    (case provenance of
       OperationDiagnosticProvenance rule ->
         "o2i.operation." <> operationRuleIdText (operationRuleIdentity rule)
       AdapterDiagnosticProvenance descriptor rule ->
         "o2i.adapter."
           <> adapterIdText (adapterDescriptorId descriptor)
           <> "."
           <> adapterRuleIdText (adapterRuleId rule)
       ProfileDiagnosticProvenance rule ->
         "o2i.profile." <> profileRuleIdText (profileRuleId rule)
       CoreDiagnosticProvenance rule ->
         "o2i.core." <> coreRuleIdText (coreRuleIdentity rule))

-- | Stable owning rule identity, distinct from the namespaced diagnostic code.
diagnosticRuleIdentity :: Diagnostic -> Text
diagnosticRuleIdentity = diagnosticProvenanceIdentity . diagnosticProvenance

-- | Impact level assigned to the diagnostic.
diagnosticSeverity :: Diagnostic -> DiagnosticSeverity
diagnosticSeverity (Diagnostic severity _ _ _) = severity

-- | Model-finding or process-failure interpretation of the diagnostic.
diagnosticDisposition :: Diagnostic -> DiagnosticDisposition
diagnosticDisposition (Diagnostic _ disposition _ _) = disposition

-- | Exact compiled rule provenance owning the diagnostic.
diagnosticProvenance :: Diagnostic -> DiagnosticProvenance
diagnosticProvenance (Diagnostic _ _ provenance _) = provenance

-- | Non-empty exact occurrence set reported by the diagnostic.
diagnosticOccurrences :: Diagnostic -> NonEmpty DiagnosticOccurrence
diagnosticOccurrences (Diagnostic _ _ _ occurrences) = occurrences

-- | Consume every immutable diagnostic field in canonical order.
foldDiagnostic ::
     (DiagnosticSeverity -> DiagnosticDisposition -> DiagnosticProvenance -> NonEmpty
                                                                               DiagnosticOccurrence -> result)
  -> Diagnostic
  -> result
foldDiagnostic consume (Diagnostic severity disposition provenance occurrences) =
  consume severity disposition provenance occurrences
