{-# LANGUAGE RankNTypes #-}

-- | Opaque source witnesses for constructively attributed owner evidence.
--
-- Model witnesses are issued only by the real preparation runtime.
-- Supplemental binding retains identity and bytes from the same acquired
-- artifacts without exposing a detachable source token.
module O2I.Operation.Diagnostic.Owner.Source
  ( PreparedAuthority
  , PreparedScope
  , SupplementalOwnerBinding
  , SupplementalOwnerBindingEvidence
  , BoundOwnerSupplementalInputs
  , withSupplementalOwnerBinding
  , foldSupplementalOwnerBinding
  , assessOwnerSemantics
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
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
  ( SupplementalBindingDiagnosticEvidence
  , SupplementalInputDefect
  , assessSupplementalInputSet
  , bindSupplementalInputs
  , decodeSupplementalInput
  , foldSupplementalBindingDiagnosticEvidence
  , foldSupplementalBindingDiagnostics
  , supplementalInputOrdinal
  )
import O2I.Structure (WellFormedGraph)

-- | Acquire no new bytes: validate, decode, and bind the supplied exact
-- acquired artifacts in one fresh input generation.
withSupplementalOwnerBinding ::
     PreparedScope authority profile document scope
  -> [AcquiredSupplementalSource]
  -> WellFormedGraph scope
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (forall inputs. SupplementalOwnerBinding
                       authority
                       profile
                       document
                       scope
                       inputs -> result)
  -> result
withSupplementalOwnerBinding _ acquired graph provenanceFailure inputFailure accepted =
  case mkSupplementalProvenance (map acquiredIdentity acquired) of
    Left defects -> provenanceFailure defects
    Right _ ->
      case traverse decodeOwnerSource ordered of
        Left defects -> inputFailure defects
        Right decoded ->
          case assessSupplementalInputSet decoded of
            Left defects -> inputFailure defects
            Right inputSet ->
              accepted
                (SupplementalOwnerBinding
                   ordered
                   (bindSupplementalInputs graph inputSet))
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

-- | Eliminate the exact binding without exposing its private source tokens.
foldSupplementalOwnerBinding ::
     ([AcquiredSupplementalSource] -> BoundOwnerSupplementalInputs
                                        authority
                                        profile
                                        document
                                        scope
                                        inputs -> [SupplementalOwnerBindingEvidence
                                                     scope
                                                     inputs] -> result)
  -> SupplementalOwnerBinding authority profile document scope inputs
  -> result
foldSupplementalOwnerBinding consume (SupplementalOwnerBinding sources binding) =
  foldSupplementalBindingDiagnostics
    (\bound evidence ->
       consume
         sources
         (BoundOwnerSupplementalInputs bound)
         (map retainSource evidence))
    binding
  where
    retainSource evidence =
      SupplementalOwnerBindingEvidence (bindingEvidenceSource evidence) evidence

bindingEvidenceSource ::
     SupplementalBindingDiagnosticEvidence
       scope
       (SupplementalOwnerOccurrence inputs)
  -> AcquiredSupplementalSource
bindingEvidenceSource =
  foldSupplementalBindingDiagnosticEvidence source source source source
  where
    source (SupplementalOwnerOccurrence value) _ = value

-- | Evaluate Core Semantics from one accepted owner-bound input generation.
assessOwnerSemantics ::
     WellFormedGraph scope
  -> BoundOwnerSupplementalInputs authority profile document scope inputs
  -> SemanticAssessment scope
assessOwnerSemantics graph (BoundOwnerSupplementalInputs bound) =
  assessSemantics graph bound
