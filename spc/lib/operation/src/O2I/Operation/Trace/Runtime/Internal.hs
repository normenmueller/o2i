{-# LANGUAGE RankNTypes #-}

-- | Sole concrete IO composition for Trace execution.
module O2I.Operation.Trace.Runtime.Internal
  ( runTrace
  , runTraceWith
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Operation.Acquisition
  ( AcquiredSource
  , AcquisitionFailure
  , InputSource
  , acquireSource
  , acquiredModelSource
  , acquiredSourceIdentity
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , adapterDescriptorId
  , lookupAdapterContract
  , selectedAdapterDescriptor
  )
import O2I.Operation.Diagnostic
  ( noSupplementalDiagnosticGroups
  , preparedDiagnosticDocument
  )
import O2I.Operation.Diagnostic.Owner
  ( foldNotationAssessmentDiagnostics
  , foldProfileAssessmentDiagnostics
  , profileActivationDiagnostics
  , semanticsEvidenceDiagnostic
  , structureEvidenceDiagnostic
  , withModelStructureAssessment
  )
import O2I.Operation.Diagnostic.Owner.Source
  ( assessOwnerSemantics
  , foldSupplementalOwnerBinding
  , withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  )
import O2I.Operation.Failure
  ( commandFailure
  , inputAcquisitionFailure
  , preparationFailure
  )
import O2I.Operation.Preparation (withPreparedSelectedView)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Provenance (SourceOrdinal, SourceRole(..), sourceOrdinal)
import qualified O2I.Operation.Request as Request
import O2I.Operation.Trace.Request
  ( TraceRequest
  , traceAdapterId
  , traceModelInput
  , traceViewSelector
  )
import O2I.Operation.Trace.Result.Internal
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure
import qualified O2I.Trace as Trace

-- | Execute one immutable Trace request through the shared prepared prefix.
runTrace ::
     AdapterCollection -> ProfileInventory -> TraceRequest -> IO TraceResult
runTrace = runTraceWith acquireSource

-- | Test seam for the sole physical IO boundary.
runTraceWith ::
     (SourceRole -> SourceOrdinal -> InputSource -> IO
                                                      (Either
                                                         AcquisitionFailure
                                                         AcquiredSource))
  -> AdapterCollection
  -> ProfileInventory
  -> TraceRequest
  -> IO TraceResult
runTraceWith acquire adapters profiles request = do
  acquired <- acquire ModelRole (sourceOrdinal 0) (traceModelInput request)
  case acquired of
    Left failure ->
      pure
        (TraceFailed
           (TraceCommonFailure
              (commandFailure (inputAcquisitionFailure failure))))
    Right source ->
      case acquiredModelSource source of
        Nothing ->
          pure
            (internalFailure
               (TraceAcquiredModelRoleFailure (acquiredSourceIdentity source)))
        Just model -> preparedPrefix model
  where
    preparedPrefix model =
      withPreparedSelectedView
        adapters
        profiles
        (traceAdapterId request)
        (Request.traceRequest (traceViewSelector request))
        model
        (pure . TraceFailed . TraceCommonFailure . preparationFailure)
        preparedStages
    preparedStages authority selected _ _ _ selectedView universe _ =
      case lookupAdapterContract
             (adapterDescriptorId (selectedAdapterDescriptor selected))
             adapters of
        Nothing ->
          pure
            (internalFailure
               (TraceSelectedAdapterContractFailure
                  (selectedAdapterDescriptor selected)))
        Just contract ->
          let notation = Notation.assessArchiMateNotation universe
           in foldNotationAssessmentDiagnostics
                (pure . internalFailure . TraceNotationContractFailure)
                (afterNotation authority selectedView universe notation)
                authority
                contract
                notation
    afterNotation authority selectedView universe notation diagnostics =
      Notation.foldStageResult
        (const
           (finishPrerequisite
              authority
              TraceNotationPrerequisite
              selectedView
              diagnostics))
        (afterProfile authority selectedView universe diagnostics)
        (Notation.notationConformance notation)
    afterProfile authority selectedView universe diagnostics conformant =
      let assessment = Profile.assessSelectedView conformant
          activation = profileActivationDiagnostics authority universe
       in Profile.foldProfileProjectionAssessment
            (pure . internalFailure . TraceProfileContractFailure)
            (\_ ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . TraceProfileContractFailure)
                 (\profileDiagnostics ->
                    finishPrerequisite
                      authority
                      TraceProfilePrerequisite
                      selectedView
                      (diagnostics <> activation <> profileDiagnostics))
                 authority
                 assessment)
            (\projection ->
               foldProfileAssessmentDiagnostics
                 (pure . internalFailure . TraceProfileContractFailure)
                 (\profileDiagnostics ->
                    assessStructure
                      authority
                      selectedView
                      (diagnostics <> activation <> profileDiagnostics)
                      projection)
                 authority
                 assessment)
            assessment
    assessStructure authority selectedView diagnostics projection =
      withModelStructureAssessment
        authority
        projection
        (pure . internalFailure . TraceIdentityIndexFailure)
        (pure . internalFailure . TraceSelectedViewScopeFailure)
        (pure . internalFailure . TraceStructureInputFailure)
        (\scope assessment ->
           Structure.foldStructureAssessment
             (\evidence ->
                finishPrerequisite
                  authority
                  TraceStructurePrerequisite
                  selectedView
                  (diagnostics
                     <> map
                          (structureEvidenceDiagnostic scope)
                          (NonEmpty.toList evidence)))
             (assessSemantics authority scope selectedView diagnostics)
             assessment)
    assessSemantics authority scope selectedView diagnostics graph =
      withAdmittedOwnerSupplementalInputs
        authority
        []
        (pure . internalFailure . TraceEmptyInputProvenanceFailure)
        (pure . internalFailure . TraceEmptyInputContractFailure)
        (\admitted ->
           withBoundAdmittedOwnerSupplementalInputs
             scope
             graph
             admitted
             (\binding ->
                foldSupplementalOwnerBinding
                  (\bound _ ->
                     completeSemantics
                       authority
                       scope
                       selectedView
                       diagnostics
                       (assessOwnerSemantics graph bound))
                  binding))
    completeSemantics authority scope selectedView diagnostics assessment =
      Semantics.foldSemanticAssessment
        (\evidence ->
           finishPrerequisite
             authority
             TraceSemanticsPrerequisite
             selectedView
             (diagnostics
                <> map
                     (semanticsEvidenceDiagnostic scope)
                     (NonEmpty.toList evidence)))
        (case Semantics.semanticallyValidModel assessment of
           Nothing ->
             pure
               (internalFailure
                  (TraceSemanticModelContractFailure
                     (Semantics.semanticCandidateOccurrences assessment)))
           Just model -> finishTrace authority selectedView diagnostics model)
        (finishTrace authority selectedView diagnostics)
        assessment
    finishTrace authority selectedView diagnostics model =
      let assessment = Trace.assessTraceability model
          prepared =
            PreparedTrace
              request
              selectedView
              (preparedDiagnosticDocument
                 authority
                 diagnostics
                 noSupplementalDiagnosticGroups)
       in pure
            (case Trace.traceRootTraces assessment of
               [] -> TraceRejectedResult assessment prepared
               roots
                 | all
                     ((== Trace.RootTraceComplete) . Trace.rootTraceDisposition)
                     roots -> TraceAcceptedResult assessment prepared
                 | otherwise -> TraceRejectedResult assessment prepared)
    finishPrerequisite authority stage selectedView diagnostics =
      pure
        (TracePrerequisiteRejectedResult
           stage
           (PreparedTrace
              request
              selectedView
              (preparedDiagnosticDocument
                 authority
                 diagnostics
                 noSupplementalDiagnosticGroups)))

internalFailure :: TraceInternalFailure -> TraceResult
internalFailure = TraceFailed . TraceOwnerContractFailure
