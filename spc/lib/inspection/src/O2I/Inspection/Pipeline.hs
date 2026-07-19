{-# LANGUAGE OverloadedStrings #-}

-- | Complete format-neutral, staged O2I inspection flow.
module O2I.Inspection.Pipeline
  ( Availability(..)
  , Sourced
  , sourcedFromDocument
  , sourcedFrom
  , sourcedValue
  , StrategyFormulationBundle(..)
  , ReadinessBundle(..)
  , EvidenceBundle(..)
  , InspectionInputs(..)
  , InspectionRequest(..)
  , InspectionOutcome(..)
  , InputRequirement(..)
  , StructurallyClosedModel
  , SemanticsWitness
  , ReadinessWitness
  , EvidenceWitness
  , prepareSemantics
  , validateScopedSemantics
  , prepareReadiness
  , validateScopedReadiness
  , prepareEvidence
  , validateScopedEvidence
  , inspect
  , inspectSourceDocument
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import O2I
import O2I.Inspection.Adapter
import O2I.Inspection.Diagnostic.Internal
import O2I.Inspection.Import
import O2I.Inspection.Input
import O2I.Inspection.Profile
import O2I.Inspection.Profile.Internal
  ( IndexedProfileFact(..)
  , ResolvedProfileProjection(..)
  )
import O2I.Inspection.Provenance
import O2I.Inspection.Provenance.Internal
  ( SupplementalSource(..)
  , bindSourcePosition
  )
import O2I.Inspection.Report.Internal
import O2I.Inspection.Scope.Internal

-- | Availability of one complete, explicitly sourced supplemental input.
data Availability a
  = Absent
  | Supplied !(Sourced a)
  deriving (Eq, Show)

-- | Supplemental value tied to its immutable source identity.
data Sourced a = Sourced
  { sourcedFrom :: SourceIdentity -- ^ Identity of the complete source input.
  , sourcedValue :: a -- ^ Value decoded from that exact source.
  } deriving (Eq, Show)

-- | Bind one supplemental value to the exact document from which it came.
sourcedFromDocument :: SourceDocument -> a -> Sourced a
sourcedFromDocument document = Sourced (sourceDocumentIdentity document)

-- | Complete, source-ordered Strategy formulation submission.
newtype StrategyFormulationBundle = StrategyFormulationBundle
  { strategyFormulationsInput :: [RawStrategyFormulation]
  } deriving (Eq, Show)

-- | Complete ex-ante evidence-readiness submission.
data ReadinessBundle = ReadinessBundle
  { readinessCheckedAtInput :: UTCTime
  , kpiDefinitionsInput :: [RawKPIDefinition]
  , plannedStartsInput :: [PlannedInterventionStart]
  , evidencePlansInput :: [EvidencePlan]
  } deriving (Eq, Show)

-- | Complete ex-post evidence-assessment submission.
data EvidenceBundle = EvidenceBundle
  { evidenceAssessedAtInput :: UTCTime
  , actualStartsInput :: [ActualInterventionStart]
  , followUpsInput :: [FollowUpObservation]
  } deriving (Eq, Show)

-- | Inputs independently required by later normative stages.
data InspectionInputs = InspectionInputs
  { strategyInput :: Availability StrategyFormulationBundle
  , readinessInput :: Availability ReadinessBundle
  , evidenceInput :: Availability EvidenceBundle
  } deriving (Eq, Show)

-- | One complete format-neutral inspection request.
data InspectionRequest = InspectionRequest
  { modelInput :: InputSource
  , viewSelector :: ViewSelector
  , inspectionInputs :: InspectionInputs
  } deriving (Eq, Show)

-- | Inspection either yields a model report or a process-level command error.
data InspectionOutcome
  = InspectionCompleted InspectionReport
  | InspectionCommandFailed CommandError
  deriving (Eq, Show)

-- | Missing information that prevents semantic validation from starting.
data InputRequirement =
  StrategyFormulationsRequired (NonEmpty RawNodeId)
  deriving (Eq, Show)

-- | Opaque binding of one exact graph to its closed scope and provenance.
data StructurallyClosedModel = StructurallyClosedModel
  { structurallyClosedGraph :: WellFormedGraph
  , structurallyClosedScope :: SemanticallyClosedScope
  , structurallyClosedImport :: ImportedGraph
  }

-- | Opaque, graph-bound input to global semantic validation.
data SemanticsWitness = SemanticsWitness
  { witnessClosedModel :: StructurallyClosedModel
  , witnessStrategyInput :: Maybe (Sourced StrategyFormulationBundle)
  }

-- | Opaque binding of one traceable model to its exact readiness source.
data ReadinessWitness = ReadinessWitness
  { witnessTraceableModel :: TraceableEffectModel
  , witnessReadinessInput :: Sourced ReadinessBundle
  }

-- | Opaque binding of one ready model to its exact evidence source.
data EvidenceWitness = EvidenceWitness
  { witnessReadyModel :: EvidenceReadyModel
  , witnessEvidenceInput :: Sourced EvidenceBundle
  }

-- | Prepare semantics only from one exact structurally closed model.
prepareSemantics ::
     StructurallyClosedModel
  -> Availability StrategyFormulationBundle
  -> Either (NonEmpty InputRequirement) SemanticsWitness
prepareSemantics closed availability =
  case availability of
    Supplied sourced ->
      Right
        SemanticsWitness
          {witnessClosedModel = closed, witnessStrategyInput = Just sourced}
    Absent ->
      case NonEmpty.nonEmpty strategies of
        Nothing ->
          Right
            SemanticsWitness
              {witnessClosedModel = closed, witnessStrategyInput = Nothing}
        Just required ->
          Left (NonEmpty.singleton (StrategyFormulationsRequired required))
  where
    strategies = contextNodesOf (structurallyClosedGraph closed) Strategy

-- | Validate the exact graph and formulations carried by the witness.
validateScopedSemantics ::
     SemanticsWitness -> Check ModelInvariantError SemanticallyValidModel
validateScopedSemantics witness =
  validateModelSemantics
    (structurallyClosedGraph (witnessClosedModel witness))
    (maybe
       []
       (strategyFormulationsInput . sourcedValue)
       (witnessStrategyInput witness))

-- | Prepare readiness only when one complete sourced bundle is supplied.
prepareReadiness ::
     TraceableEffectModel
  -> Availability ReadinessBundle
  -> Maybe ReadinessWitness
prepareReadiness traceable availability =
  case availability of
    Absent -> Nothing
    Supplied sourced ->
      Just
        ReadinessWitness
          {witnessTraceableModel = traceable, witnessReadinessInput = sourced}

-- | Validate readiness from the exact model and source carried by the witness.
validateScopedReadiness ::
     ReadinessWitness -> Check EvidenceReadinessError EvidenceReadyModel
validateScopedReadiness witness =
  validateEvidenceReadinessAt
    (readinessCheckedAtInput bundle)
    (witnessTraceableModel witness)
    (kpiDefinitionsInput bundle)
    (plannedStartsInput bundle)
    (evidencePlansInput bundle)
  where
    bundle = sourcedValue (witnessReadinessInput witness)

-- | Prepare evidence only when one complete sourced bundle is supplied.
prepareEvidence ::
     EvidenceReadyModel -> Availability EvidenceBundle -> Maybe EvidenceWitness
prepareEvidence ready availability =
  case availability of
    Absent -> Nothing
    Supplied sourced ->
      Just
        EvidenceWitness
          {witnessReadyModel = ready, witnessEvidenceInput = sourced}

-- | Assess evidence from the exact ready model and source in the witness.
validateScopedEvidence ::
     EvidenceWitness -> Check EvidenceError EvidenceAssessedModel
validateScopedEvidence witness =
  assessEffectEvidenceAt
    (evidenceAssessedAtInput bundle)
    (witnessReadyModel witness)
    (actualStartsInput bundle)
    (followUpsInput bundle)
  where
    bundle = sourcedValue (witnessEvidenceInput witness)

-- | Acquire complete bytes and run the identical inspection path for files
-- and non-seekable standard input.
inspect :: Adapter -> InspectionRequest -> IO InspectionOutcome
inspect adapter request = do
  acquired <- acquireInput (modelInput request)
  pure
    (case acquired of
       Left failure ->
         InspectionCommandFailed
           (InputCommandError
              (inputSourceLabel (inputFailureSource failure))
              (inputFailureMessage failure))
       Right document ->
         inspectSourceDocument
           adapter
           (viewSelector request)
           (inspectionInputs request)
           document)

-- | Run inspection over already acquired exact bytes. Every source-relative
-- adapter position is bound here to this document's immutable identity.
inspectSourceDocument ::
     Adapter
  -> ViewSelector
  -> InspectionInputs
  -> SourceDocument
  -> InspectionOutcome
inspectSourceDocument (Adapter descriptor decode decodeSpec resolveView viewSpec contract observe) selector inputs source =
  case decode source of
    DecodeUnavailable observation defects ->
      let diagnostics =
            locatedDiagnostics
              DecodeStage
              decodeSpec
              (fmap (bindLocated sourceIdentity) defects)
       in InspectionCompleted
            (decodeFailureReport
               requestInfo
               (NativeBindingUnavailable
                  (bindDecodeUnavailableObservation sourceIdentity observation))
               diagnostics)
    DecodeRejected rejected defects ->
      let diagnostics =
            locatedDiagnostics
              DecodeStage
              decodeSpec
              (fmap (bindLocated sourceIdentity) defects)
       in InspectionCompleted
            (decodeFailureReport
               requestInfo
               (NativeBindingRejected
                  (bindRejectedNativeBinding sourceIdentity rejected))
               diagnostics)
    DecodePassed binding document ->
      case resolveView document selector of
        ViewFailed observation defects ->
          let diagnostics =
                locatedDiagnostics
                  ViewScopeStage
                  viewSpec
                  (fmap (bindLocated sourceIdentity) defects)
           in InspectionCompleted
                (viewFailureReport
                   requestInfo
                   binding
                   (bindObservedViewResolution sourceIdentity observation)
                   diagnostics)
        ViewPassed view selectedView ->
          inspectProfile
            requestInfo
            binding
            (ResolvedViewResolution (bindResolvedView sourceIdentity view))
            inputs
            contract
            (observe document selectedView)
  where
    requestInfo =
      InspectionRequestInfo
        { requestSourceIdentity = sourceDocumentIdentity source
        , requestAdapter = descriptor
        , requestedViewSelector = selector
        }
    sourceIdentity = sourceDocumentIdentity source

inspectProfile ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> InspectionInputs
  -> O2IProfileContract SourcePosition fact defect
  -> ProfileSnapshot SourcePosition fact
  -> InspectionOutcome
inspectProfile request binding viewResolution inputs contract observations =
  case resolveRootProfile contract observations of
    ProfileRejected observed defects ->
      let diagnostics =
            locatedDiagnostics
              ProfileStage
              (profileDefectSpec contract)
              (fmap (bindLocated sourceIdentity) defects)
       in InspectionCompleted
            (profileFailureReport
               request
               binding
               viewResolution
               observed
               diagnostics)
    ProfileResolved resolved projection ->
      inspectScope
        request
        binding
        viewResolution
        resolved
        inputs
        (buildProfileIndex
           (resolvedView viewResolution)
           contract
           (bindResolvedProfileProjection sourceIdentity projection))
  where
    sourceIdentity = requestSourceIdentity request

inspectScope ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> InspectionInputs
  -> ProfileIndex
  -> InspectionOutcome
inspectScope request binding viewResolution profile inputs index =
  case closeScope index of
    ScopeRejected summary issues ->
      let diagnostics = scopeDiagnostics issues
       in InspectionCompleted
            (scopeFailureReport
               request
               binding
               viewResolution
               profile
               summary
               diagnostics)
    ScopeClosed scope ->
      let imported = buildImportedGraph scope
       in case validateStructure (importedRawGraph imported) of
            StructureModelRejected defects ->
              InspectionCompleted
                (structureFailureReport
                   request
                   binding
                   viewResolution
                   profile
                   scope
                   imported
                   defects)
            StructureAccepted graph ->
              inspectSemantics
                request
                binding
                viewResolution
                profile
                inputs
                (StructurallyClosedModel
                   { structurallyClosedGraph = graph
                   , structurallyClosedScope = scope
                   , structurallyClosedImport = imported
                   })
            StructureInternalFailure internal ->
              InspectionCommandFailed
                (StructureInternalCommandError
                   (structureInternalDetail internal))

inspectSemantics ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> InspectionInputs
  -> StructurallyClosedModel
  -> InspectionOutcome
inspectSemantics request binding viewResolution profile inputs closed =
  case prepareSemantics closed (strategyInput inputs) of
    Left _ ->
      InspectionCompleted
        (pipelineReport
           request
           binding
           viewResolution
           profile
           (resolvedScopeFor closed)
           []
           StagePassed
           StageUnavailable
           (StageNotRun (BlockedByUnavailable SemanticsStage))
           (StageNotRun (BlockedByUnavailable SemanticsStage))
           (StageNotRun (BlockedByUnavailable SemanticsStage))
           [])
    Right witness ->
      let sources = semanticsWitnessSources witness
       in case validateScopedSemantics witness of
            Failure defects ->
              let diagnostics =
                    coreDiagnosticsWithSources
                      SemanticsStage
                      sources
                      closed
                      semanticDefectSpec
                      defects
               in InspectionCompleted
                    (pipelineReport
                       request
                       binding
                       viewResolution
                       profile
                       (resolvedScopeFor closed)
                       sources
                       StagePassed
                       StageFailed
                       (StageNotRun (BlockedByFailure SemanticsStage))
                       (StageNotRun (BlockedByFailure SemanticsStage))
                       (StageNotRun (BlockedByFailure SemanticsStage))
                       diagnostics)
            Success semantic ->
              inspectTraceability
                request
                binding
                viewResolution
                profile
                inputs
                closed
                sources
                semantic

inspectTraceability ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> InspectionInputs
  -> StructurallyClosedModel
  -> [SupplementalSource]
  -> SemanticallyValidModel
  -> InspectionOutcome
inspectTraceability request binding viewResolution profile inputs closed sources semantic =
  case validateTraceability semantic of
    Failure defects ->
      let diagnostics =
            coreDiagnostics
              TraceabilityStage
              closed
              traceabilityDefectSpec
              defects
       in InspectionCompleted
            (pipelineReport
               request
               binding
               viewResolution
               profile
               resolvedScope
               sources
               StagePassed
               StagePassed
               StageFailed
               (StageNotRun (BlockedByFailure TraceabilityStage))
               (StageNotRun (BlockedByFailure TraceabilityStage))
               diagnostics)
    Success traceable ->
      inspectReadiness
        request
        binding
        viewResolution
        profile
        inputs
        closed
        sources
        traceable
  where
    resolvedScope = resolvedScopeFor closed

inspectReadiness ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> InspectionInputs
  -> StructurallyClosedModel
  -> [SupplementalSource]
  -> TraceableEffectModel
  -> InspectionOutcome
inspectReadiness request binding viewResolution profile inputs closed sources traceable =
  case prepareReadiness traceable (readinessInput inputs) of
    Nothing ->
      InspectionCompleted
        (pipelineReport
           request
           binding
           viewResolution
           profile
           resolvedScope
           sources
           StagePassed
           StagePassed
           StagePassed
           StageUnavailable
           (StageNotRun (BlockedByUnavailable ReadinessStage))
           [])
    Just witness ->
      let readinessSource = readinessWitnessSource witness
          usedSources = sources ++ [readinessSource]
       in case validateScopedReadiness witness of
            Failure defects ->
              let diagnostics =
                    coreDiagnosticsWithSources
                      ReadinessStage
                      [readinessSource]
                      closed
                      readinessDefectSpec
                      defects
               in InspectionCompleted
                    (pipelineReport
                       request
                       binding
                       viewResolution
                       profile
                       resolvedScope
                       usedSources
                       StagePassed
                       StagePassed
                       StagePassed
                       StageFailed
                       (StageNotRun (BlockedByFailure ReadinessStage))
                       diagnostics)
            Success ready ->
              inspectEvidence
                request
                binding
                viewResolution
                profile
                inputs
                closed
                usedSources
                ready
  where
    resolvedScope = resolvedScopeFor closed

inspectEvidence ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> InspectionInputs
  -> StructurallyClosedModel
  -> [SupplementalSource]
  -> EvidenceReadyModel
  -> InspectionOutcome
inspectEvidence request binding viewResolution profile inputs closed sources ready =
  case prepareEvidence ready (evidenceInput inputs) of
    Nothing ->
      InspectionCompleted
        (pipelineReport
           request
           binding
           viewResolution
           profile
           resolvedScope
           sources
           StagePassed
           StagePassed
           StagePassed
           StagePassed
           StageUnavailable
           [])
    Just witness ->
      let evidenceSource = evidenceWitnessSource witness
          usedSources = sources ++ [evidenceSource]
       in case validateScopedEvidence witness of
            Failure defects ->
              let diagnostics =
                    coreDiagnosticsWithSources
                      EvidenceStage
                      [evidenceSource]
                      closed
                      evidenceDefectSpec
                      defects
               in InspectionCompleted
                    (pipelineReport
                       request
                       binding
                       viewResolution
                       profile
                       resolvedScope
                       usedSources
                       StagePassed
                       StagePassed
                       StagePassed
                       StagePassed
                       StageFailed
                       diagnostics)
            Success _ ->
              InspectionCompleted
                (pipelineReport
                   request
                   binding
                   viewResolution
                   profile
                   resolvedScope
                   usedSources
                   StagePassed
                   StagePassed
                   StagePassed
                   StagePassed
                   StagePassed
                   [])
  where
    resolvedScope = resolvedScopeFor closed

decodeFailureReport ::
     InspectionRequestInfo
  -> (NonEmpty DiagnosticId -> NativeBindingFailure)
  -> NonEmpty Diagnostic
  -> InspectionReport
decodeFailureReport request failure diagnostics =
  let normalized = normalizeNonEmptyDiagnostics diagnostics
      artifact = forgetNonEmptyDiagnostics normalized
   in DecodeRejectedReport
        request
        (failure (nonEmptyDiagnosticIds normalized))
        (earlyStageReports DecodeStage artifact)
        artifact

viewFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ObservedViewResolution SourceLocation
  -> NonEmpty Diagnostic
  -> InspectionReport
viewFailureReport request binding observation diagnostics =
  let normalized = normalizeNonEmptyDiagnostics diagnostics
      artifact = forgetNonEmptyDiagnostics normalized
   in ViewRejectedReport
        request
        binding
        (FailedViewResolution observation (nonEmptyDiagnosticIds normalized))
        (earlyStageReports ViewScopeStage artifact)
        artifact

profileFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ObservedO2IProfile
  -> NonEmpty Diagnostic
  -> InspectionReport
profileFailureReport request binding viewResolution observed diagnostics =
  let normalized = normalizeNonEmptyDiagnostics diagnostics
      artifact = forgetNonEmptyDiagnostics normalized
   in ProfileRejectedReport
        request
        binding
        viewResolution
        (RejectedO2IProfile observed (nonEmptyDiagnosticIds normalized))
        (earlyStageReports ProfileStage artifact)
        artifact

scopeFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> ClosedScopeSummary
  -> NonEmpty Diagnostic
  -> InspectionReport
scopeFailureReport request binding viewResolution profile summary diagnostics =
  let normalized = normalizeNonEmptyDiagnostics diagnostics
      artifact = forgetNonEmptyDiagnostics normalized
   in ScopeRejectedReport
        request
        binding
        viewResolution
        profile
        (ScopeFailure summary (nonEmptyDiagnosticIds normalized))
        (earlyStageReports ProfileStage artifact)
        artifact

structureFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> SemanticallyClosedScope
  -> ImportedGraph
  -> NonEmpty StructuralError
  -> InspectionReport
structureFailureReport request binding viewResolution profile scope imported defects =
  let normalized =
        normalizeNonEmptyDiagnostics
          (fmap
             (coreDiagnostic StructureStage imported structuralDefectSpec)
             defects)
      diagnostics = forgetNonEmptyDiagnostics normalized
   in PipelineReport
        request
        binding
        viewResolution
        profile
        (resolvedScopeForScope scope)
        []
        (pipelineStageReports
           StageFailed
           (StageNotRun (BlockedByFailure StructureStage))
           (StageNotRun (BlockedByFailure StructureStage))
           (StageNotRun (BlockedByFailure StructureStage))
           (StageNotRun (BlockedByFailure StructureStage))
           diagnostics)
        diagnostics

pipelineReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> ResolvedScope
  -> [SupplementalSource]
  -> StageState
  -> StageState
  -> StageState
  -> StageState
  -> StageState
  -> [Diagnostic]
  -> InspectionReport
pipelineReport request binding viewResolution profile scope sources structure semantics trace readiness evidence diagnostics =
  let artifact = normalizeDiagnostics diagnostics
   in PipelineReport
        request
        binding
        viewResolution
        profile
        scope
        sources
        (pipelineStageReports
           structure
           semantics
           trace
           readiness
           evidence
           artifact)
        artifact

resolvedScopeFor :: StructurallyClosedModel -> ResolvedScope
resolvedScopeFor = resolvedScopeForScope . structurallyClosedScope

resolvedScopeForScope :: SemanticallyClosedScope -> ResolvedScope
resolvedScopeForScope scope =
  ResolvedScope
    { resolvedScopeSummary = closedScopeSummary scope
    , resolvedScopeProvenance = closedScopeProvenance scope
    }

earlyStageReports :: InspectionStage -> Diagnostics -> StageReports
earlyStageReports failedStage diagnostics =
  StageReports
    { decodeStageReport = beforeOrAt DecodeStage
    , viewScopeStageReport = beforeOrAt ViewScopeStage
    , profileStageReport = beforeOrAt ProfileStage
    , structureStageReport = after StructureStage
    , semanticsStageReport = after SemanticsStage
    , traceabilityStageReport = after TraceabilityStage
    , readinessStageReport = after ReadinessStage
    , evidenceStageReport = after EvidenceStage
    }
  where
    beforeOrAt stage
      | stage < failedStage = stageReport stage StagePassed diagnostics
      | stage == failedStage = stageReport stage StageFailed diagnostics
      | otherwise = after stage
    after stage =
      stageReport stage (StageNotRun (BlockedByFailure failedStage)) diagnostics

pipelineStageReports ::
     StageState
  -> StageState
  -> StageState
  -> StageState
  -> StageState
  -> Diagnostics
  -> StageReports
pipelineStageReports structure semantics trace readiness evidence diagnostics =
  StageReports
    { decodeStageReport = stageReport DecodeStage StagePassed diagnostics
    , viewScopeStageReport = stageReport ViewScopeStage StagePassed diagnostics
    , profileStageReport = stageReport ProfileStage StagePassed diagnostics
    , structureStageReport = stageReport StructureStage structure diagnostics
    , semanticsStageReport = stageReport SemanticsStage semantics diagnostics
    , traceabilityStageReport = stageReport TraceabilityStage trace diagnostics
    , readinessStageReport = stageReport ReadinessStage readiness diagnostics
    , evidenceStageReport = stageReport EvidenceStage evidence diagnostics
    }

stageReport :: InspectionStage -> StageState -> Diagnostics -> StageReport
stageReport stage state diagnostics =
  StageReport
    { reportedStage = stage
    , reportedState = state
    , reportedDiagnosticIds =
        [ diagnosticId diagnostic
        | diagnostic <- diagnosticsList diagnostics
        , diagnosticStage diagnostic == stage
        ]
    }

locatedDiagnostics ::
     InspectionStage
  -> (defect -> DiagnosticSpec)
  -> NonEmpty (Located SourceLocation defect)
  -> NonEmpty Diagnostic
locatedDiagnostics stage specification =
  fmap (diagnosticFromLocated stage specification)

scopeDiagnostics :: NonEmpty ScopeIssue -> NonEmpty Diagnostic
scopeDiagnostics = fmap normalizeIssue
  where
    normalizeIssue issue =
      case issue of
        ProfileIssue diagnostic -> diagnostic
        InspectionScopeIssue defect ->
          diagnosticFromLocated ProfileStage scopeDefectSpec defect

coreDiagnostics ::
     InspectionStage
  -> StructurallyClosedModel
  -> (defect -> DiagnosticSpec)
  -> NonEmpty defect
  -> [Diagnostic]
coreDiagnostics stage closed specification =
  map (coreDiagnostic stage (structurallyClosedImport closed) specification)
    . NonEmpty.toList

coreDiagnosticsWithSources ::
     InspectionStage
  -> [SupplementalSource]
  -> StructurallyClosedModel
  -> (defect -> DiagnosticSpec)
  -> NonEmpty defect
  -> [Diagnostic]
coreDiagnosticsWithSources stage sources closed specification =
  map (diagnosticWithSupplementalSources sources)
    . coreDiagnostics stage closed specification

semanticsWitnessSources :: SemanticsWitness -> [SupplementalSource]
semanticsWitnessSources witness =
  case witnessStrategyInput witness of
    Nothing -> []
    Just sourced ->
      [SupplementalSource StrategySupplement (sourcedFrom sourced)]

readinessWitnessSource :: ReadinessWitness -> SupplementalSource
readinessWitnessSource witness =
  SupplementalSource
    ReadinessSupplement
    (sourcedFrom (witnessReadinessInput witness))

evidenceWitnessSource :: EvidenceWitness -> SupplementalSource
evidenceWitnessSource witness =
  SupplementalSource
    EvidenceSupplement
    (sourcedFrom (witnessEvidenceInput witness))

coreDiagnostic ::
     InspectionStage
  -> ImportedGraph
  -> (defect -> DiagnosticSpec)
  -> defect
  -> Diagnostic
coreDiagnostic stage imported specification defect =
  diagnosticFromSpec
    stage
    (importedLocationsForSubjects imported (specSubjects spec))
    spec
  where
    spec = specification defect

bindLocated ::
     SourceIdentity
  -> Located SourcePosition value
  -> Located SourceLocation value
bindLocated source (Located position value) =
  Located (bindSourcePosition source position) value

bindEncodingObservation ::
     SourceIdentity
  -> EncodingObservation SourcePosition
  -> EncodingObservation SourceLocation
bindEncodingObservation source observation =
  case observation of
    EncodingNotObserved -> EncodingNotObserved
    EncodingDefaultedToUtf8 -> EncodingDefaultedToUtf8
    EncodingDeclared declaration ->
      EncodingDeclared (bindLocated source declaration)

bindDecodeUnavailableObservation ::
     SourceIdentity
  -> DecodeUnavailableObservation SourcePosition
  -> DecodeUnavailableObservation SourceLocation
bindDecodeUnavailableObservation source observation =
  DecodeUnavailableObservation
    (bindEncodingObservation source (unavailableEncoding observation))

bindRejectedNativeBinding ::
     SourceIdentity
  -> RejectedNativeBinding SourcePosition
  -> RejectedNativeBinding SourceLocation
bindRejectedNativeBinding source rejected =
  RejectedNativeBinding
    { rejectedEncoding = rejectedEncoding rejected
    , rejectedRootQName = bindLocated source (rejectedRootQName rejected)
    , rejectedNativeVersion =
        fmap (bindLocated source) (rejectedNativeVersion rejected)
    }

bindViewCandidate ::
     SourceIdentity
  -> ViewCandidate SourcePosition
  -> ViewCandidate SourceLocation
bindViewCandidate source candidate =
  ViewCandidate
    { viewCandidateId = viewCandidateId candidate
    , viewCandidateName = viewCandidateName candidate
    , viewCandidateLocation =
        bindSourcePosition source (viewCandidateLocation candidate)
    }

bindResolvedView ::
     SourceIdentity
  -> ResolvedView SourcePosition
  -> ResolvedView SourceLocation
bindResolvedView source view =
  ResolvedView
    { resolvedViewId = resolvedViewId view
    , resolvedViewName = resolvedViewName view
    , resolvedViewLocation =
        bindSourcePosition source (resolvedViewLocation view)
    }

bindObservedViewResolution ::
     SourceIdentity
  -> ObservedViewResolution SourcePosition
  -> ObservedViewResolution SourceLocation
bindObservedViewResolution source observation =
  case observation of
    NoViewMatch -> NoViewMatch
    OneViewMatch candidate -> OneViewMatch (bindViewCandidate source candidate)
    MultipleViewMatches candidates ->
      MultipleViewMatches (fmap (bindViewCandidate source) candidates)

bindResolvedProfileProjection ::
     SourceIdentity
  -> ResolvedProfileProjection SourcePosition fact defect
  -> ResolvedProfileProjection SourceLocation fact defect
bindResolvedProfileProjection source projection =
  ResolvedProfileProjection
    { resolvedProfileSnapshot =
        profileSnapshot
          (bindLocated
             source
             (snapshotFact (resolvedProfileSnapshot projection)))
    , resolvedProjectedFacts =
        map (bindIndexedProfileFact source) (resolvedProjectedFacts projection)
    , resolvedDeferredDefects =
        map
          (bindDeferredProfileDefect source)
          (resolvedDeferredDefects projection)
    }

bindDeferredProfileDefect ::
     SourceIdentity
  -> DeferredProfileDefect SourcePosition defect
  -> DeferredProfileDefect SourceLocation defect
bindDeferredProfileDefect source deferred =
  DeferredProfileDefect
    { defectApplicability = defectApplicability deferred
    , deferredDefect = bindLocated source (deferredDefect deferred)
    }

bindIndexedProfileFact ::
     SourceIdentity
  -> IndexedProfileFact SourcePosition
  -> IndexedProfileFact SourceLocation
bindIndexedProfileFact source fact =
  case fact of
    IndexedOccurrence occurrence position ->
      IndexedOccurrence occurrence (bindSourcePosition source position)
    IndexedNode occurrence node position ->
      IndexedNode occurrence node (bindSourcePosition source position)
    IndexedEdge occurrence edge position ->
      IndexedEdge occurrence edge (bindSourcePosition source position)
    IndexedSeed presentation target -> IndexedSeed presentation target
    IndexedDependency from to reason -> IndexedDependency from to reason
    IndexedReference from reference matches reason ->
      IndexedReference
        from
        (bindReferenceOccurrence source reference)
        matches
        reason

bindReferenceOccurrence ::
     SourceIdentity
  -> ReferenceOccurrence SourcePosition
  -> ReferenceOccurrence SourceLocation
bindReferenceOccurrence source reference =
  ReferenceOccurrence
    { referenceOccurrenceId = referenceOccurrenceId reference
    , referenceFromOccurrence = referenceFromOccurrence reference
    , referenceRole = referenceRole reference
    , referenceToken = referenceToken reference
    , referenceLocation =
        bindSourcePosition source (referenceLocation reference)
    }

inputSourceLabel :: InputSource -> Text
inputSourceLabel source =
  case source of
    InputPath path -> Text.pack path
    StandardInput -> "<stdin>"

structureInternalDetail :: StructureInternalError -> Text
structureInternalDetail internal =
  case internal of
    ContextElaborationInvariant identifier ->
      "context-elaboration-invariant:" <> rawNodeIdText identifier
    ChildElaborationInvariant identifier ->
      "child-elaboration-invariant:" <> rawNodeIdText identifier
    EdgeElaborationInvariant edge ->
      "edge-elaboration-invariant:" <> rawEdgeSubjectIdentifier edge
