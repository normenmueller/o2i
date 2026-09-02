{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Lossless diagnostics bound to one successful preparation authority.
--
-- Severity, disposition, owner, stage and rule identity are total projections
-- of the retained owner evidence. Callers cannot combine those fields or
-- attach evidence to a separately supplied source.
module O2I.Operation.Diagnostic
  ( type DiagnosticSeverity
  , infoSeverity
  , errorSeverity
  , diagnosticSeverityText
  , type DiagnosticDisposition
  , modelFinding
  , processFailure
  , diagnosticDispositionText
  , type AdapterNotationDiagnostic
  , foldAdapterNotationDiagnostic
  , type PreparedDiagnostic
  , preparedDiagnosticSeverity
  , preparedDiagnosticDisposition
  , preparedDiagnosticProducer
  , preparedDiagnosticOwner
  , preparedDiagnosticStage
  , preparedDiagnosticRuleIdentity
  , foldPreparedDiagnostic
  , type SupplementalDiagnostic
  , supplementalDiagnosticRuleIdentity
  , foldSupplementalDiagnostic
  , type SupplementalDiagnosticGroups
  , noSupplementalDiagnosticGroups
  , foldSupplementalDiagnosticGroups
  , type PreparedDiagnosticDocument
  , preparedDiagnosticDocument
  , foldPreparedDiagnosticDocument
  ) where

import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Adapter (adapterRuleId, adapterRuleIdText)
import O2I.Operation.Diagnostic.AdapterOwner.Internal
  ( AdapterNotationDiagnostic
  , foldAdapterNotationDiagnostic
  )
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Diagnostic.Owner.Source.Internal
  ( PreparedAuthority
  , SupplementalOwnerBindingEvidence(..)
  , SupplementalOwnerOccurrence(..)
  )
import qualified O2I.Semantics as Semantics
import qualified O2I.Semantics.Input as Binding
import qualified O2I.Structure as Structure

-- | Severity for an accepted positive owner fact.
infoSeverity :: DiagnosticSeverity
infoSeverity = InfoSeverity

-- | Severity for an owner rejection.
errorSeverity :: DiagnosticSeverity
errorSeverity = ErrorSeverity

-- | Stable machine token of a derived severity.
diagnosticSeverityText :: DiagnosticSeverity -> Text
diagnosticSeverityText severity =
  case severity of
    InfoSeverity -> "info"
    ErrorSeverity -> "error"

-- | A prepared finding attributable to model content.
modelFinding :: DiagnosticDisposition
modelFinding = ModelFinding

-- | A prepared failure attributable to capability-input processing.
processFailure :: DiagnosticDisposition
processFailure = ProcessFailure

-- | Stable machine token of the derived disposition.
diagnosticDispositionText :: DiagnosticDisposition -> Text
diagnosticDispositionText disposition =
  case disposition of
    ModelFinding -> "model-finding"
    ProcessFailure -> "process-failure"

-- | Derive impact directly from the closed producer branch.
preparedDiagnosticSeverity ::
     PreparedDiagnostic authority profile document -> DiagnosticSeverity
preparedDiagnosticSeverity diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic _ -> ErrorSeverity
    ProfileActivationDiagnostic _ -> InfoSeverity
    ProfileRejectionDiagnostic _ -> ErrorSeverity
    ProfileClassificationDiagnostic _ -> InfoSeverity
    ProfileMappingDiagnostic _ -> InfoSeverity
    ProfileInvariantDiagnostic _ -> InfoSeverity
    StructureRejectionDiagnostic _ -> ErrorSeverity
    SemanticsRejectionDiagnostic _ -> ErrorSeverity

-- | Every retained owner result is attributable to model content.
preparedDiagnosticDisposition ::
     PreparedDiagnostic authority profile document -> DiagnosticDisposition
preparedDiagnosticDisposition _ = ModelFinding

-- | Stable closed producer token.
preparedDiagnosticProducer ::
     PreparedDiagnostic authority profile document -> Text
preparedDiagnosticProducer diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic _ -> "notation-assessment"
    ProfileActivationDiagnostic _ -> "profile-activation"
    ProfileRejectionDiagnostic _ -> "profile-assessment"
    ProfileClassificationDiagnostic _ -> "profile-classification"
    ProfileMappingDiagnostic _ -> "profile-mapping"
    ProfileInvariantDiagnostic _ -> "profile-invariant"
    StructureRejectionDiagnostic _ -> "structure-assessment"
    SemanticsRejectionDiagnostic _ -> "semantics-assessment"

-- | Stable closed owner token.
preparedDiagnosticOwner :: PreparedDiagnostic authority profile document -> Text
preparedDiagnosticOwner diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic _ -> "adapter"
    ProfileActivationDiagnostic _ -> "profile"
    ProfileRejectionDiagnostic _ -> "profile"
    ProfileClassificationDiagnostic _ -> "profile"
    ProfileMappingDiagnostic _ -> "profile"
    ProfileInvariantDiagnostic _ -> "profile"
    StructureRejectionDiagnostic _ -> "core"
    SemanticsRejectionDiagnostic _ -> "core"

-- | Stable closed stage token.
preparedDiagnosticStage :: PreparedDiagnostic authority profile document -> Text
preparedDiagnosticStage diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic _ -> "notation"
    ProfileActivationDiagnostic _ -> "profile"
    ProfileRejectionDiagnostic _ -> "profile"
    ProfileClassificationDiagnostic _ -> "profile"
    ProfileMappingDiagnostic _ -> "profile"
    ProfileInvariantDiagnostic _ -> "profile"
    StructureRejectionDiagnostic _ -> "structure"
    SemanticsRejectionDiagnostic _ -> "semantics"

-- | Exact rule identity projected from the retained owner value.
preparedDiagnosticRuleIdentity ::
     PreparedDiagnostic authority profile document -> Text
preparedDiagnosticRuleIdentity diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic evidence ->
      foldAdapterNotationDiagnostic
        (\_ rule _ -> adapterRuleIdText (adapterRuleId rule))
        evidence
    ProfileActivationDiagnostic evidence ->
      Closure.foldActivationProvenance (\_ _ _ rule _ _ _ -> rule) evidence
    ProfileRejectionDiagnostic evidence ->
      Profile.profileDiagnosticRuleId evidence
    ProfileClassificationDiagnostic evidence ->
      Profile.foldProfileClassificationEvidence (\_ _ rule _ -> rule) evidence
    ProfileMappingDiagnostic evidence ->
      Profile.foldProfileMappingProvenance
        (\rule _ _ -> rule)
        (\rule _ _ _ _ -> rule)
        (\rule _ _ -> rule)
        evidence
    ProfileInvariantDiagnostic evidence ->
      Profile.foldProfileInvariantEvidence (\rule _ -> rule) evidence
    StructureRejectionDiagnostic evidence ->
      coreRuleIdText (Structure.structureEvidenceRule evidence)
    SemanticsRejectionDiagnostic evidence ->
      coreRuleIdText (Semantics.semanticDiagnosticRule evidence)

-- | Eliminate every lossless owner branch.
foldPreparedDiagnostic ::
     (AdapterNotationDiagnostic -> result)
  -> (Closure.ActivationProvenance profile document -> result)
  -> (Profile.ProfileDiagnosticEvidence profile document -> result)
  -> (Profile.ProfileClassificationEvidence profile document -> result)
  -> (Profile.ProfileMappingProvenance profile document -> result)
  -> (Profile.ProfileInvariantEvidence profile document -> result)
  -> (forall scope. Structure.StructureEvidence scope -> result)
  -> (forall scope. Semantics.SemanticDiagnosticEvidence scope -> result)
  -> PreparedDiagnostic authority profile document
  -> result
foldPreparedDiagnostic notation activation rejection classification mapping invariant structure semantics diagnostic =
  case diagnostic of
    NotationRejectionDiagnostic evidence -> notation evidence
    ProfileActivationDiagnostic evidence -> activation evidence
    ProfileRejectionDiagnostic evidence -> rejection evidence
    ProfileClassificationDiagnostic evidence -> classification evidence
    ProfileMappingDiagnostic evidence -> mapping evidence
    ProfileInvariantDiagnostic evidence -> invariant evidence
    StructureRejectionDiagnostic evidence -> structure evidence
    SemanticsRejectionDiagnostic evidence -> semantics evidence

-- | Exact Core rule identity retained by one supplemental Binding finding.
supplementalDiagnosticRuleIdentity :: SupplementalDiagnostic -> Text
supplementalDiagnosticRuleIdentity (SupplementalDiagnostic (SupplementalOwnerBindingEvidence evidence)) =
  coreRuleIdText (Binding.supplementalBindingDiagnosticEvidenceRule evidence)

-- | Consume every closed graph-dependent supplemental Binding outcome.
--
-- Each callback receives the exact acquired source retained by the evidence,
-- RFC 6901 instance pointer, and validated model identity. No caller-supplied
-- source, Core constructor, or detachable provenance token is admitted.
foldSupplementalDiagnostic ::
     (AcquiredSupplementalSource -> Text -> Text -> result)
  -> (AcquiredSupplementalSource -> Text -> Text -> result)
  -> (AcquiredSupplementalSource -> Text -> Text -> result)
  -> (AcquiredSupplementalSource -> Text -> Text -> result)
  -> SupplementalDiagnostic
  -> result
foldSupplementalDiagnostic unknown ambiguous wrongType outOfView diagnostic =
  case diagnostic of
    SupplementalDiagnostic (SupplementalOwnerBindingEvidence evidence) ->
      Binding.foldSupplementalBindingDiagnosticEvidence
        (\occurrence value ->
           withOccurrence
             occurrence
             unknown
             (Binding.supplementalIdentityUnknownInstancePointer value)
             (modelIdentityText
                (Binding.supplementalIdentityUnknownModelIdentity value)))
        (\occurrence value ->
           withOccurrence
             occurrence
             ambiguous
             (Binding.supplementalIdentityAmbiguousInstancePointer value)
             (modelIdentityText
                (Binding.supplementalIdentityAmbiguousModelIdentity value)))
        (\occurrence value ->
           withOccurrence
             occurrence
             wrongType
             (Binding.supplementalIdentityWrongTypeInstancePointer value)
             (modelIdentityText
                (Binding.supplementalIdentityWrongTypeModelIdentity value)))
        (\occurrence value ->
           withOccurrence
             occurrence
             outOfView
             (Binding.supplementalIdentityOutOfViewInstancePointer value)
             (modelIdentityText
                (Binding.supplementalIdentityOutOfViewModelIdentity value)))
        evidence
  where
    withOccurrence occurrence consume pointer identity =
      case occurrence of
        SupplementalOwnerOccurrence source -> consume source pointer identity

-- | Canonical empty collection for a document produced before any
-- supplemental binding exists.
noSupplementalDiagnosticGroups ::
     SupplementalDiagnosticGroups authority profile document
noSupplementalDiagnosticGroups = SupplementalDiagnosticGroups []

-- | Consume every source group in canonical order, including empty groups.
--
-- The source and all of its sealed child findings are delivered together, so
-- callers cannot flatten and reassociate diagnostics across source authority.
foldSupplementalDiagnosticGroups ::
     (AcquiredSupplementalSource -> [SupplementalDiagnostic] -> group)
  -> ([group] -> result)
  -> SupplementalDiagnosticGroups authority profile document
  -> result
foldSupplementalDiagnosticGroups group consume groups =
  case groups of
    SupplementalDiagnosticGroups values -> consume (map foldGroup values)
  where
    foldGroup diagnosticGroup =
      case diagnosticGroup of
        SupplementalDiagnosticGroup source evidence ->
          group source (map SupplementalDiagnostic evidence)

-- | Seal one authority with all model and supplemental diagnostics.
preparedDiagnosticDocument ::
     PreparedAuthority authority profile document
  -> [PreparedDiagnostic authority profile document]
  -> SupplementalDiagnosticGroups authority profile document
  -> PreparedDiagnosticDocument
preparedDiagnosticDocument = PreparedDiagnosticDocument

-- | Eliminate the existential document without detaching its authority.
foldPreparedDiagnosticDocument ::
     (forall authority profile document. PreparedAuthority
                                           authority
                                           profile
                                           document -> [PreparedDiagnostic
                                                          authority
                                                          profile
                                                          document] -> SupplementalDiagnosticGroups
                                                                         authority
                                                                         profile
                                                                         document -> result)
  -> PreparedDiagnosticDocument
  -> result
foldPreparedDiagnosticDocument consume document =
  case document of
    PreparedDiagnosticDocument authority modelDiagnostics supplementalGroups ->
      consume authority modelDiagnostics supplementalGroups
