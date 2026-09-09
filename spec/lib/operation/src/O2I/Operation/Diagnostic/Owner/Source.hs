{-# LANGUAGE RankNTypes #-}

-- | Opaque source witnesses for constructively attributed owner evidence.
--
-- Model witnesses are issued only by the real preparation runtime.
-- Supplemental binding retains identity and bytes from the same acquired
-- artifacts without exposing a detachable source token.
module O2I.Operation.Diagnostic.Owner.Source
  ( PreparedAuthority
  , PreparedScope
  , AdmittedOwnerSupplementalInputs
  , SupplementalOwnerBinding
  , SupplementalOwnerBindingGroup
  , SupplementalOwnerBindingEvidence
  , BoundOwnerSupplementalInputs
  , withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  , foldSupplementalOwnerBinding
  , foldSupplementalOwnerBindingGroup
  , assessOwnerSemantics
  ) where

import Data.Either (partitionEithers)
import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Semigroup (sconcat)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
  , foldAcquiredSupplementalSource
  )
import O2I.Operation.Diagnostic.Owner.Source.Internal
import O2I.Operation.Provenance
  ( SupplementalProvenanceDefect
  , mkSupplementalProvenance
  , sourceIdentityOrdinal
  , sourceOrdinalValue
  )
import O2I.Semantics (SemanticAssessment, assessSemantics)
import O2I.Semantics.Input
  ( SupplementalInputDefect
  , assessSupplementalInputSet
  , bindSupplementalInputs
  , decodeSupplementalInput
  , foldSupplementalBindingDiagnosticGroup
  , foldSupplementalBindingDiagnosticGroups
  , supplementalInputOrdinal
  )
import O2I.Structure (WellFormedGraph)

-- | Acquire no new bytes: validate provenance, decode every supplied exact
-- artifact once, and assess the complete set before Structure.
withAdmittedOwnerSupplementalInputs ::
     PreparedAuthority authority profile document
  -> [AcquiredSupplementalSource]
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (forall inputs. AdmittedOwnerSupplementalInputs
                       authority
                       profile
                       document
                       inputs -> result)
  -> result
withAdmittedOwnerSupplementalInputs _ acquired provenanceFailure inputFailure accepted =
  case mkSupplementalProvenance (map acquiredIdentity acquired) of
    Left defects -> provenanceFailure defects
    Right _ ->
      case partitionEithers (map decodeOwnerSource ordered) of
        (firstFailure:laterFailures, _) ->
          inputFailure (sconcat (firstFailure :| laterFailures))
        ([], decoded) ->
          case assessSupplementalInputSet decoded of
            Left defects -> inputFailure defects
            Right inputSet ->
              accepted (AdmittedOwnerSupplementalInputs inputSet)
  where
    ordered = sortOn acquiredOrdinal acquired
    acquiredOrdinal =
      sourceOrdinalValue . sourceIdentityOrdinal . acquiredIdentity
    acquiredIdentity = foldAcquiredSupplementalSource acquiredSourceIdentity
    acquiredBytes = foldAcquiredSupplementalSource acquiredSourceBytes
    decodeOwnerSource source =
      decodeSupplementalInput
        (SupplementalOwnerOccurrence source)
        (supplementalInputOrdinal (acquiredOrdinal source))
        (acquiredBytes source)

-- | Bind only one already admitted pre-Structure input generation against the
-- exact accepted Structure graph.
withBoundAdmittedOwnerSupplementalInputs ::
     PreparedScope authority profile document scope
  -> WellFormedGraph scope
  -> AdmittedOwnerSupplementalInputs authority profile document inputs
  -> (SupplementalOwnerBinding authority profile document scope inputs -> result)
  -> result
withBoundAdmittedOwnerSupplementalInputs _ graph admitted consume =
  case admitted of
    AdmittedOwnerSupplementalInputs inputSet ->
      consume (SupplementalOwnerBinding (bindSupplementalInputs graph inputSet))

-- | Eliminate the exact binding without exposing its private source tokens.
foldSupplementalOwnerBinding ::
     (BoundOwnerSupplementalInputs authority profile document scope inputs -> [SupplementalOwnerBindingGroup
                                                                                 scope
                                                                                 inputs] -> result)
  -> SupplementalOwnerBinding authority profile document scope inputs
  -> result
foldSupplementalOwnerBinding consume (SupplementalOwnerBinding binding) =
  foldSupplementalBindingDiagnosticGroups
    (\bound groups ->
       consume (BoundOwnerSupplementalInputs bound) (map retainGroup groups))
    binding
  where
    retainGroup =
      foldSupplementalBindingDiagnosticGroup $ \occurrence evidence ->
        case occurrence of
          SupplementalOwnerOccurrence source ->
            SupplementalOwnerBindingGroup
              source
              (map SupplementalOwnerBindingEvidence evidence)

-- | Eliminate one exact acquired source group without exposing a detachable
-- source token or permitting child reassociation.
foldSupplementalOwnerBindingGroup ::
     (AcquiredSupplementalSource -> [SupplementalOwnerBindingEvidence
                                       scope
                                       inputs] -> result)
  -> SupplementalOwnerBindingGroup scope inputs
  -> result
foldSupplementalOwnerBindingGroup consume group =
  case group of
    SupplementalOwnerBindingGroup source evidence -> consume source evidence

-- | Evaluate Core Semantics from one accepted owner-bound input generation.
assessOwnerSemantics ::
     WellFormedGraph scope
  -> BoundOwnerSupplementalInputs authority profile document scope inputs
  -> SemanticAssessment scope
assessOwnerSemantics graph (BoundOwnerSupplementalInputs bound) =
  assessSemantics graph bound
