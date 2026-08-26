module TracePublicApi where

import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Semantics (SemanticallyValidModel)
import O2I.Trace

constructIdentity ::
     ModelIdentity -> [(TraceVariable, ModelIdentity)] -> Maybe TraceIdentity
constructIdentity = mkTraceIdentity

bindIdentity ::
     SemanticallyValidModel scope
  -> TraceIdentity
  -> Either (NonEmpty TraceIdentityBindingDefect) (BoundTraceIdentity scope)
bindIdentity = bindTraceIdentity

assess ::
     SemanticallyValidModel scope
  -> (TraceDisposition, ModelIdentity, [RootTrace scope])
assess model =
  ( traceDisposition assessment
  , traceAssessmentGraphIdentity assessment
  , traceRootTraces assessment)
  where
    assessment = assessTraceability model

summarizeRoot ::
     RootTrace scope
  -> ( ModelIdentity
     , ModelIdentity
     , ModelIdentity
     , NonEmpty OccurrenceIdentity
     , RootTraceDisposition
     , Either (CompleteWitness scope) (PartialTrace scope))
summarizeRoot root =
  ( rootTraceGraphIdentity root
  , rootTraceIntervention root
  , rootTraceNeed root
  , rootTraceSupport root
  , rootTraceDisposition root
  , foldRootTrace Left Right root)

summarizeGap ::
     TraceGap
  -> Either
       (TraceSlot, TraceBoundEndpoints, TraceGapDisposition)
       (Either
          ( TraceSlot
          , [(TraceVariable, ModelIdentity)]
          , NonEmpty TraceVariable
          , TraceGapDisposition)
          (NonEmpty TraceSlot, TraceGapDisposition))
summarizeGap =
  foldTraceGap
    (\slot endpoints disposition -> Left (slot, endpoints, disposition))
    (\slot established unresolved disposition ->
       Right (Left (slot, established, unresolved, disposition)))
    (\slots disposition -> Right (Right (slots, disposition)))

slotProjection :: TraceSlotSupport -> (TraceSlot, [OccurrenceIdentity])
slotProjection support =
  (traceSupportSlot support, traceSupportOccurrences support)

variableProjection ::
     TraceVariableProjection -> (TraceVariable, [ModelIdentity])
variableProjection projection =
  (traceProjectionVariable projection, traceProjectionValues projection)

validate ::
     SemanticallyValidModel scope
  -> BoundTraceIdentity scope
  -> SuppliedTraceAssessment scope
validate = validateSuppliedTrace
