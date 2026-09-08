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
import O2I.ArchiMate.Profile.Resolution
  ( SelectedArchiMateProfile
  , withSelectedArchiMateProfile
  )
import O2I.Operation.Acquisition
  ( AcquiredModelSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
  )
import O2I.Operation.Acquisition.Internal (AcquiredModelSource(..))
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
import O2I.Operation.Adapter.Internal
  ( CompiledAdapterContract(..)
  , SelectedAdapter(..)
  )
import O2I.Operation.Diagnostic.Owner.Source (PreparedAuthority)
import O2I.Operation.Diagnostic.Owner.Source.Internal (PreparedAuthority(..))
import O2I.Operation.Failure.Internal
  ( PreparationFailure(..)
  , ProfileCompatibilityFailure(..)
  , ProfileResolutionFailure(..)
  )
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
  -> AcquiredModelSource
  -> (PreparationFailure -> result)
  -> (forall authority document profile. PreparedAuthority
                                           authority
                                           profile
                                           document -> SelectedAdapter -> ResolvedProfile -> CanonicalDocument
                                                                                               document -> SelectedArchiMateProfile
                                                                                                             profile -> SelectedView
                                                                                                                          document -> ProfileAssessmentUniverse
                                                                                                                                        profile
                                                                                                                                        document -> CapabilityInputReferences -> result)
  -> result
withPreparedSelectedView adapters profiles requestedAdapter request (AcquiredModelSource model) failed prepared =
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
       in foldProfileResolution
            (\rule key ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferenceMissingFailure rule key)))
            (\rule key occurrences ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferencePropertyMultiplicityFailure
                       rule
                       key
                       occurrences)))
            (\rule key occurrence occurrences ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferenceValueMultiplicityFailure
                       rule
                       key
                       occurrence
                       occurrences)))
            (\rule key occurrence kind ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferenceValueKindInvalidFailure
                       rule
                       key
                       occurrence
                       kind)))
            (\rule key occurrence ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferenceGrammarInvalidFailure rule key occurrence)))
            (\rule key reference ->
               failed
                 (ProfileResolutionPreparationFailure
                    (ProfileReferenceUnknownFailure rule key reference)))
            (compatible selected document)
            resolution
    compatible selected document resolved =
      let compatibility = checkProfileCompatibility resolved selected
       in foldProfileCompatibility
            (\rule profile adapter admitted ->
               failed
                 (ProfileCompatibilityPreparationFailure
                    (ProfileAdapterIdNotAdmittedFailure
                       rule
                       profile
                       adapter
                       admitted)))
            (\rule profile adapter profileNotation adapterNotation ->
               failed
                 (ProfileCompatibilityPreparationFailure
                    (ProfileAdapterNotationMismatchFailure
                       rule
                       profile
                       adapter
                       profileNotation
                       adapterNotation)))
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
          (PreparedAuthority
             (selectedAdapterContract selected)
             (resolvedProfileDescriptor resolved)
             (acquiredSourceIdentity model))
          selected
          resolved
          document
          profile
          selectedView
          (deriveProfileAssessmentUniverse
             profile
             document
             (selectedViewDescriptor selectedView))
          (requestedInputs request)
    selectedAdapterContract (SelectedAdapter adapter) =
      CompiledAdapterContract adapter
