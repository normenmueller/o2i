{-# LANGUAGE RankNTypes #-}

-- | Capability-neutral execution of the shared prepared selected-View prefix.
module O2I.Operation.Preparation.Runtime.Internal
  ( withPreparedSelectedView
  ) where

import O2I.ArchiMate.Profile.Closure
  ( ProfileAssessmentUniverse
  , deriveProfileAssessmentUniverse
  )
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , assessMarkerEvidence
  , withCanonicalDocument
  )
import O2I.ArchiMate.Profile.Resolution (withSelectedArchiMateProfile)
import O2I.Operation.Acquisition (AcquiredSource, acquiredSourceBytes)
import O2I.Operation.Adapter
  ( AdapterCollection
  , AdapterId
  , SelectedAdapter
  , adapterExecutionOutcome
  , foldAdapterSelection
  , foldDecodeOutcome
  , runSelectedAdapter
  , selectAdapter
  , selectedAdapterDescriptor
  )
import O2I.Operation.Failure.Internal (PreparationFailure(..))
import O2I.Operation.Profile
  ( ProfileInventory
  , ResolvedProfile
  , checkProfileCompatibility
  , foldProfileCompatibility
  , foldProfileMarkerEvidenceOutcome
  , foldProfileResolution
  , prepareProfileMarkerEvidence
  , resolveProfile
  , resolvedProfileDescriptor
  )
import O2I.Operation.Request
  ( CapabilityInputReferences
  , RequestedContract
  , requestedInputs
  , requestedViewSelector
  )
import O2I.Operation.View
  ( SelectedView
  , foldViewSelection
  , selectView
  , selectedViewDescriptor
  )

-- | Execute the sole shared preparation prefix and expose its nominally scoped
-- selected material. Exact capability-owned references become available to
-- the downstream continuation only after this prefix succeeds; their
-- acquisition remains outside this runtime and follows later accepted
-- Notation and Profile assessment.
withPreparedSelectedView ::
     AdapterCollection
  -> ProfileInventory
  -> Maybe AdapterId
  -> RequestedContract
  -> AcquiredSource
  -> (PreparationFailure -> result)
  -> (forall document profile. SelectedAdapter -> ResolvedProfile -> CanonicalDocument
                                                                       document -> SelectedView
                                                                                     document -> ProfileAssessmentUniverse
                                                                                                   profile
                                                                                                   document -> CapabilityInputReferences -> result)
  -> result
withPreparedSelectedView adapters profiles requestedAdapter request model failed prepared =
  foldAdapterSelection
    (failed . AdapterSelectionPreparationFailure)
    decodeSelected
    (selectAdapter adapters requestedAdapter (acquiredSourceBytes model))
  where
    decodeSelected selected =
      let execution = runSelectedAdapter selected (acquiredSourceBytes model)
       in foldDecodeOutcome
            (failed
               . AdapterDecodePreparationFailure
                   (selectedAdapterDescriptor selected))
            (\draft -> withCanonicalDocument draft (prepareDocument selected))
            (adapterExecutionOutcome execution)
    prepareDocument selected document =
      foldProfileMarkerEvidenceOutcome
        (failed . ProfileMarkerPreparationFailure)
        (resolveSelected selected document)
        (prepareProfileMarkerEvidence (assessMarkerEvidence document))
    resolveSelected selected document evidence =
      let resolution = resolveProfile profiles evidence
          rejected = failed (ProfileResolutionPreparationFailure resolution)
       in foldProfileResolution
            (\_ _ -> rejected)
            (\_ _ _ -> rejected)
            (\_ _ _ _ -> rejected)
            (\_ _ _ _ -> rejected)
            (\_ _ _ -> rejected)
            (\_ _ _ -> rejected)
            (compatible selected document)
            resolution
    compatible selected document resolved =
      let compatibility = checkProfileCompatibility resolved selected
          rejected =
            failed (ProfileCompatibilityPreparationFailure compatibility)
       in foldProfileCompatibility
            (\_ _ _ _ -> rejected)
            (\_ _ _ _ _ -> rejected)
            (\_ _ _ -> selectPrepared selected resolved document)
            compatibility
    selectPrepared selected resolved document =
      foldViewSelection
        (failed . ViewSelectionPreparationFailure)
        (complete selected resolved document)
        (selectView document (requestedViewSelector request))
    complete selected resolved document selectedView =
      withSelectedArchiMateProfile (resolvedProfileDescriptor resolved) $ \profile ->
        prepared
          selected
          resolved
          document
          selectedView
          (deriveProfileAssessmentUniverse
             profile
             document
             (selectedViewDescriptor selectedView))
          (requestedInputs request)
