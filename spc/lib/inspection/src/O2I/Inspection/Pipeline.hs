{-# LANGUAGE OverloadedStrings #-}

-- | Complete format-neutral, staged O2I inspection flow.
module O2I.Inspection.Pipeline
  ( Availability(..)
  , Sourced(..)
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
import O2I.Inspection.Provenance
import O2I.Inspection.Report.Internal
import O2I.Inspection.Scope.Internal

-- | Availability of one complete, explicitly sourced supplemental input.
data Availability a
  = Absent
  | Supplied !(Sourced a)
  deriving (Eq, Show)

-- | Supplemental value tied to its immutable source identity.
data Sourced a = Sourced
  { sourcedFrom :: SourceIdentity
  , sourcedValue :: a
  } deriving (Eq, Show)

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
  , structurallyClosedProvenance :: Provenance
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

-- | Run inspection over already acquired exact bytes.
inspectSourceDocument ::
     Adapter
  -> ViewSelector
  -> InspectionInputs
  -> SourceDocument
  -> InspectionOutcome
inspectSourceDocument (Adapter descriptor decode decodeSpec resolveView viewSpec contract observe) selector inputs source =
  case decode source of
    DecodeUnavailable observation defects ->
      let diagnostics = locatedDiagnostics DecodeStage decodeSpec defects
       in InspectionCompleted
            (decodeFailureReport
               requestInfo
               (NativeBindingUnavailable
                  observation
                  (fmap diagnosticId diagnostics))
               (NonEmpty.toList diagnostics))
    DecodeRejected rejected defects ->
      let diagnostics = locatedDiagnostics DecodeStage decodeSpec defects
       in InspectionCompleted
            (decodeFailureReport
               requestInfo
               (NativeBindingRejected rejected (fmap diagnosticId diagnostics))
               (NonEmpty.toList diagnostics))
    DecodePassed binding document ->
      case resolveView document selector of
        ViewFailed observation defects ->
          let diagnostics = locatedDiagnostics ViewScopeStage viewSpec defects
           in InspectionCompleted
                (viewFailureReport requestInfo binding observation diagnostics)
        ViewPassed view selectedView ->
          inspectProfile
            requestInfo
            binding
            (ResolvedViewResolution view)
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

inspectProfile ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> InspectionInputs
  -> O2IProfileContract fact defect
  -> ProfileSnapshot fact
  -> InspectionOutcome
inspectProfile request binding viewResolution inputs contract observations =
  case resolveRootProfile contract observations of
    ProfileRejected observed defects ->
      let diagnostics =
            locatedDiagnostics ProfileStage (profileDefectSpec contract) defects
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
        (buildProfileIndex (resolvedView viewResolution) contract projection)

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
                   , structurallyClosedProvenance = importedProvenance imported
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
           (closedScopeSummary (structurallyClosedScope closed))
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
                       (closedScopeSummary (structurallyClosedScope closed))
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
               summary
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
    summary = closedScopeSummary (structurallyClosedScope closed)

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
           summary
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
                       summary
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
    summary = closedScopeSummary (structurallyClosedScope closed)

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
           summary
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
                       summary
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
                   summary
                   usedSources
                   StagePassed
                   StagePassed
                   StagePassed
                   StagePassed
                   StagePassed
                   [])
  where
    summary = closedScopeSummary (structurallyClosedScope closed)

decodeFailureReport ::
     InspectionRequestInfo
  -> NativeBindingFailure
  -> [Diagnostic]
  -> InspectionReport
decodeFailureReport request failure diagnostics =
  DecodeRejectedReport
    request
    failure
    (earlyStageReports DecodeStage diagnostics)
    (normalizeDiagnostics diagnostics)

viewFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ObservedViewResolution
  -> NonEmpty Diagnostic
  -> InspectionReport
viewFailureReport request binding observation diagnostics =
  ViewRejectedReport
    request
    binding
    (FailedViewResolution observation (fmap diagnosticId diagnostics))
    (earlyStageReports ViewScopeStage (NonEmpty.toList diagnostics))
    (normalizeDiagnostics (NonEmpty.toList diagnostics))

profileFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ObservedO2IProfile
  -> NonEmpty Diagnostic
  -> InspectionReport
profileFailureReport request binding viewResolution observed diagnostics =
  ProfileRejectedReport
    request
    binding
    viewResolution
    (RejectedO2IProfile observed (fmap diagnosticId diagnostics))
    (earlyStageReports ProfileStage (NonEmpty.toList diagnostics))
    (normalizeDiagnostics (NonEmpty.toList diagnostics))

scopeFailureReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> ClosedScopeSummary
  -> NonEmpty Diagnostic
  -> InspectionReport
scopeFailureReport request binding viewResolution profile summary diagnostics =
  ScopeRejectedReport
    request
    binding
    viewResolution
    profile
    (ScopeFailure summary (fmap diagnosticId diagnostics))
    (earlyStageReports ProfileStage (NonEmpty.toList diagnostics))
    (normalizeDiagnostics (NonEmpty.toList diagnostics))

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
  PipelineReport
    request
    binding
    viewResolution
    profile
    (closedScopeSummary scope)
    []
    (pipelineStageReports
       StageFailed
       (StageNotRun (BlockedByFailure StructureStage))
       (StageNotRun (BlockedByFailure StructureStage))
       (StageNotRun (BlockedByFailure StructureStage))
       (StageNotRun (BlockedByFailure StructureStage))
       diagnostics)
    (normalizeDiagnostics diagnostics)
  where
    diagnostics =
      map
        (coreDiagnostic StructureStage imported structuralDefectSpec)
        (NonEmpty.toList defects)

pipelineReport ::
     InspectionRequestInfo
  -> ResolvedNativeBinding
  -> ResolvedViewResolution
  -> ResolvedO2IProfile
  -> ClosedScopeSummary
  -> [SupplementalSource]
  -> StageState
  -> StageState
  -> StageState
  -> StageState
  -> StageState
  -> [Diagnostic]
  -> InspectionReport
pipelineReport request binding viewResolution profile summary sources structure semantics trace readiness evidence diagnostics =
  PipelineReport
    request
    binding
    viewResolution
    profile
    summary
    sources
    (pipelineStageReports
       structure
       semantics
       trace
       readiness
       evidence
       diagnostics)
    (normalizeDiagnostics diagnostics)

earlyStageReports :: InspectionStage -> [Diagnostic] -> StageReports
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
  -> [Diagnostic]
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

stageReport :: InspectionStage -> StageState -> [Diagnostic] -> StageReport
stageReport stage state diagnostics =
  StageReport
    { reportedStage = stage
    , reportedState = state
    , reportedDiagnosticIds =
        [ diagnosticId diagnostic
        | diagnostic <- diagnosticsList (normalizeDiagnostics diagnostics)
        , diagnosticStage diagnostic == stage
        ]
    }

locatedDiagnostics ::
     InspectionStage
  -> (defect -> DiagnosticSpec)
  -> NonEmpty (Located defect)
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
