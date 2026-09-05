{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Complete terminal-neutral human projection of Trace results.
module O2I.Operation.Trace.Human
  ( type HumanTraceRequest
  , foldHumanTraceRequest
  , type HumanTraceContext
  , foldHumanTraceContext
  , type HumanTraceSlot
  , foldHumanTraceSlot
  , type HumanTraceSupport
  , foldHumanTraceSupport
  , type HumanTraceProjection
  , foldHumanTraceProjection
  , type HumanTraceGap
  , foldHumanTraceGap
  , type HumanRootTraceResult
  , foldHumanRootTraceResult
  , type HumanRootTrace
  , foldHumanRootTrace
  , type HumanTraceAssessment
  , foldHumanTraceAssessment
  , type HumanTraceFailure
  , foldHumanTraceFailure
  , type HumanTraceReport
  , traceHumanReport
  , foldHumanTraceReport
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.Human.Diagnostic
  ( HumanDiagnosticDocument
  , humanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  )
import O2I.Operation.Human.Failure.Internal
  ( HumanTraceFailure
  , foldHumanTraceFailure
  , projectTraceFailure
  )
import O2I.Operation.Human.Value
  ( HumanAdapterSelection
  , HumanInputSource
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanSourceIdentity
  , HumanTraceBinding
  , HumanTraceIdentity
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( HumanTraceBinding(..)
  , projectAdapterSelection
  , projectInputSource
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectTraceIdentity
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Report.Internal (foldTraceReport)
import O2I.Operation.Trace.Request (TraceRequest, foldTraceRequest)
import O2I.Operation.Trace.Result
  ( PreparedTrace
  , TracePrerequisite
  , TraceResult
  , foldPreparedTrace
  )
import O2I.Operation.View (selectedViewDescriptor)
import qualified O2I.Trace as Trace

-- | Exact retained Trace request contract.
data HumanTraceRequest =
  HumanTraceRequest HumanInputSource HumanViewSelector HumanAdapterSelection

-- | Complete context shared by every prepared Trace branch.
data HumanTraceContext =
  HumanTraceContext
    ReportEnvelope
    HumanTraceRequest
    HumanSourceIdentity
    HumanViewDescriptor
    HumanDiagnosticDocument

-- | Trace slot kind, identifier, and authoritative rule.
data HumanTraceSlot =
  HumanTraceSlot Text Text Text

-- | Trace slot and its exact supporting occurrences.
data HumanTraceSupport =
  HumanTraceSupport HumanTraceSlot [HumanOccurrenceIdentity]

-- | Trace variable and its projected model identities.
data HumanTraceProjection =
  HumanTraceProjection Text [HumanModelIdentity]

-- | Closed local or global reason for incomplete trace support.
data HumanTraceGap
  = HumanBoundTraceGap HumanTraceSlot HumanTraceBinding HumanTraceBinding Text
  | HumanUnboundTraceGap HumanTraceSlot [HumanTraceBinding] (NonEmpty Text) Text
  | HumanGlobalTraceGap (NonEmpty HumanTraceSlot) Text

-- | Complete or partial result for one asserted root trace.
data HumanRootTraceResult
  = HumanCompleteTrace
      HumanTraceIdentity
      [HumanTraceSupport]
      [HumanTraceSupport]
  | HumanPartialTrace
      [HumanTraceProjection]
      [HumanTraceSupport]
      [HumanTraceSupport]
      (NonEmpty HumanTraceGap)

-- | Identities, support, and result retained for one root trace.
data HumanRootTrace =
  HumanRootTrace
    HumanModelIdentity
    HumanModelIdentity
    HumanModelIdentity
    (NonEmpty HumanOccurrenceIdentity)
    HumanRootTraceResult

-- | Trace assessment for one graph and all asserted roots.
data HumanTraceAssessment =
  HumanTraceAssessment HumanModelIdentity [HumanRootTrace]

-- | Complete terminal-neutral Trace report.
data HumanTraceReport
  = HumanTraceFailed HumanTraceFailure
  | HumanTracePrerequisiteRejected TracePrerequisite HumanTraceContext
  | HumanTraceRejected HumanTraceAssessment HumanTraceContext
  | HumanTraceAccepted HumanTraceAssessment HumanTraceContext

-- | Consume every exact requested Trace field.
foldHumanTraceRequest ::
     (HumanInputSource -> HumanViewSelector -> HumanAdapterSelection -> result)
  -> HumanTraceRequest
  -> result
foldHumanTraceRequest consume (HumanTraceRequest model view adapter) =
  consume model view adapter

-- | Consume every prepared Trace context field.
foldHumanTraceContext ::
     (ReportEnvelope -> HumanTraceRequest -> HumanSourceIdentity -> HumanViewDescriptor -> HumanDiagnosticDocument -> result)
  -> HumanTraceContext
  -> result
foldHumanTraceContext consume (HumanTraceContext envelope request model view diagnostics) =
  consume envelope request model view diagnostics

-- | Consume every retained trace-slot field.
foldHumanTraceSlot ::
     (Text -> Text -> Text -> result) -> HumanTraceSlot -> result
foldHumanTraceSlot consume (HumanTraceSlot kind identifier rule) =
  consume kind identifier rule

-- | Consume a trace slot and all supporting occurrences.
foldHumanTraceSupport ::
     (HumanTraceSlot -> [HumanOccurrenceIdentity] -> result)
  -> HumanTraceSupport
  -> result
foldHumanTraceSupport consume (HumanTraceSupport slot occurrences) =
  consume slot occurrences

-- | Consume a trace variable and its projected identities.
foldHumanTraceProjection ::
     (Text -> [HumanModelIdentity] -> result) -> HumanTraceProjection -> result
foldHumanTraceProjection consume (HumanTraceProjection variable identities) =
  consume variable identities

-- | Eliminate every closed trace-gap branch.
foldHumanTraceGap ::
     (HumanTraceSlot -> HumanTraceBinding -> HumanTraceBinding -> Text -> result)
  -> (HumanTraceSlot -> [HumanTraceBinding] -> NonEmpty Text -> Text -> result)
  -> (NonEmpty HumanTraceSlot -> Text -> result)
  -> HumanTraceGap
  -> result
foldHumanTraceGap bound unbound global gap =
  case gap of
    HumanBoundTraceGap slot source target disposition ->
      bound slot source target disposition
    HumanUnboundTraceGap slot established unresolved disposition ->
      unbound slot established unresolved disposition
    HumanGlobalTraceGap slots disposition -> global slots disposition

-- | Eliminate complete or partial root-trace results.
foldHumanRootTraceResult ::
     (HumanTraceIdentity -> [HumanTraceSupport] -> [HumanTraceSupport] -> result)
  -> ([HumanTraceProjection] -> [HumanTraceSupport] -> [HumanTraceSupport] -> NonEmpty
                                                                                HumanTraceGap -> result)
  -> HumanRootTraceResult
  -> result
foldHumanRootTraceResult complete partial result =
  case result of
    HumanCompleteTrace identity relations ownership ->
      complete identity relations ownership
    HumanPartialTrace projections relations ownership gaps ->
      partial projections relations ownership gaps

-- | Consume every retained root-trace field.
foldHumanRootTrace ::
     (HumanModelIdentity -> HumanModelIdentity -> HumanModelIdentity -> NonEmpty
                                                                          HumanOccurrenceIdentity -> HumanRootTraceResult -> result)
  -> HumanRootTrace
  -> result
foldHumanRootTrace consume (HumanRootTrace graph intervention need support result) =
  consume graph intervention need support result

-- | Consume the graph identity and all root traces.
foldHumanTraceAssessment ::
     (HumanModelIdentity -> [HumanRootTrace] -> result)
  -> HumanTraceAssessment
  -> result
foldHumanTraceAssessment consume (HumanTraceAssessment graph roots) =
  consume graph roots

-- | Project a Trace result without rendering it.
traceHumanReport :: ToolDescriptor -> TraceResult -> HumanTraceReport
traceHumanReport tool =
  foldTraceReport
    tool
    (HumanTraceFailed . projectTraceFailure)
    (\envelope stage prepared ->
       preparedContext (HumanTracePrerequisiteRejected stage) envelope prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanTraceRejected (projectAssessment assessment))
         envelope
         prepared)
    (\envelope assessment prepared ->
       preparedContext
         (HumanTraceAccepted (projectAssessment assessment))
         envelope
         prepared)

-- | Eliminate every closed Trace-report branch.
foldHumanTraceReport ::
     (HumanTraceFailure -> result)
  -> (TracePrerequisite -> HumanTraceContext -> result)
  -> (HumanTraceAssessment -> HumanTraceContext -> result)
  -> (HumanTraceAssessment -> HumanTraceContext -> result)
  -> HumanTraceReport
  -> result
foldHumanTraceReport failed prerequisite rejected accepted report =
  case report of
    HumanTraceFailed failure -> failed failure
    HumanTracePrerequisiteRejected stage context -> prerequisite stage context
    HumanTraceRejected assessment context -> rejected assessment context
    HumanTraceAccepted assessment context -> accepted assessment context

preparedContext ::
     (HumanTraceContext -> HumanTraceReport)
  -> ReportEnvelope
  -> PreparedTrace
  -> HumanTraceReport
preparedContext constructor envelope prepared =
  foldPreparedTrace
    (\request view diagnostics ->
       let document = humanDiagnosticDocument diagnostics
        in constructor
             (HumanTraceContext
                envelope
                (projectTraceRequest request)
                (humanDiagnosticDocumentModelSource document)
                (projectViewDescriptor (selectedViewDescriptor view))
                document))
    prepared

projectTraceRequest :: TraceRequest -> HumanTraceRequest
projectTraceRequest =
  foldTraceRequest $ \model view adapter ->
    HumanTraceRequest
      (projectInputSource model)
      (projectViewSelector view)
      (projectAdapterSelection adapter)

projectAssessment :: Trace.TraceAssessment scope -> HumanTraceAssessment
projectAssessment assessment =
  HumanTraceAssessment
    (projectModelIdentity (Trace.traceAssessmentGraphIdentity assessment))
    (map projectRoot (Trace.traceRootTraces assessment))

projectRoot :: Trace.RootTrace scope -> HumanRootTrace
projectRoot root =
  HumanRootTrace
    (projectModelIdentity (Trace.rootTraceGraphIdentity root))
    (projectModelIdentity (Trace.rootTraceIntervention root))
    (projectModelIdentity (Trace.rootTraceNeed root))
    (fmap projectOccurrenceIdentity (Trace.rootTraceSupport root))
    (Trace.foldRootTrace projectComplete projectPartial root)

projectComplete :: Trace.CompleteWitness scope -> HumanRootTraceResult
projectComplete witness =
  HumanCompleteTrace
    (projectTraceIdentity (Trace.completeTraceIdentity witness))
    (map projectSupport (Trace.completeRelationSupport witness))
    (map projectSupport (Trace.completeOwnershipSupport witness))

projectPartial :: Trace.PartialTrace scope -> HumanRootTraceResult
projectPartial partial =
  HumanPartialTrace
    (map projectProjection (Trace.partialVariableProjections partial))
    (map projectSupport (Trace.partialRelationSupport partial))
    (map projectSupport (Trace.partialOwnershipSupport partial))
    (fmap projectGap (Trace.partialGaps partial))

projectProjection :: Trace.TraceVariableProjection -> HumanTraceProjection
projectProjection projection =
  HumanTraceProjection
    (Trace.traceVariableId (Trace.traceProjectionVariable projection))
    (map projectModelIdentity (Trace.traceProjectionValues projection))

projectSupport :: Trace.TraceSlotSupport -> HumanTraceSupport
projectSupport support =
  HumanTraceSupport
    (projectSlot (Trace.traceSupportSlot support))
    (map projectOccurrenceIdentity (Trace.traceSupportOccurrences support))

projectGap :: Trace.TraceGap -> HumanTraceGap
projectGap =
  Trace.foldTraceGap
    (\slot endpoints disposition ->
       HumanBoundTraceGap
         (projectSlot slot)
         (HumanTraceBinding
            (Trace.traceVariableId (Trace.traceBoundSourceVariable endpoints))
            (projectModelIdentity (Trace.traceBoundSourceIdentity endpoints)))
         (HumanTraceBinding
            (Trace.traceVariableId (Trace.traceBoundTargetVariable endpoints))
            (projectModelIdentity (Trace.traceBoundTargetIdentity endpoints)))
         (gapDispositionText disposition))
    (\slot established unresolved disposition ->
       HumanUnboundTraceGap
         (projectSlot slot)
         (map projectBinding established)
         (fmap Trace.traceVariableId unresolved)
         (gapDispositionText disposition))
    (\slots disposition ->
       HumanGlobalTraceGap
         (fmap projectSlot slots)
         (gapDispositionText disposition))

projectBinding :: (Trace.TraceVariable, ModelIdentity) -> HumanTraceBinding
projectBinding (variable, identity) =
  HumanTraceBinding
    (Trace.traceVariableId variable)
    (projectModelIdentity identity)

projectSlot :: Trace.TraceSlot -> HumanTraceSlot
projectSlot slot =
  HumanTraceSlot
    (case slot of
       Trace.RelationTraceSlot _ -> "relation"
       Trace.OwnershipTraceSlot _ -> "ownership")
    (Trace.traceSlotId slot)
    (coreRuleIdText (Trace.traceSlotRuleId slot))

gapDispositionText :: Trace.TraceGapDisposition -> Text
gapDispositionText disposition =
  case disposition of
    Trace.MissingSupport -> "missing-support"
    Trace.CandidateOnlySupport -> "candidate-only"
    Trace.GloballyInconsistentSupport -> "globally-inconsistent"
