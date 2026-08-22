{-# LANGUAGE RankNTypes #-}

-- | Opaque source witnesses for constructively attributed owner evidence.
--
-- Model witnesses are issued only by the real preparation runtime.
-- Supplemental binding retains identity and bytes from the same acquired
-- artifacts without exposing a detachable source token.
module O2I.Operation.Diagnostic.Owner.Source
  ( ModelOwnerSource
  , ScopedModelOwnerSource
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
  ( AcquiredSource
  , acquiredSourceBytes
  , acquiredSourceIdentity
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
  , foldSupplementalBinding
  , supplementalInputOrdinal
  )
import O2I.Structure (WellFormedGraph)

-- | Acquire no new bytes: validate, decode, and bind the supplied exact
-- acquired artifacts in one fresh input generation.
withSupplementalOwnerBinding ::
     [AcquiredSource]
  -> WellFormedGraph scope
  -> (NonEmpty SupplementalProvenanceDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> (forall inputs. SupplementalOwnerBinding scope inputs -> result)
  -> result
withSupplementalOwnerBinding acquired graph provenanceFailure inputFailure accepted =
  case mkSupplementalProvenance (map acquiredSourceIdentity acquired) of
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
                   (bindSupplementalInputs graph inputSet))
  where
    ordered = sortOn acquiredOrdinal acquired
    acquiredOrdinal =
      sourceOrdinalValue . sourceIdentityOrdinal . acquiredSourceIdentity
    decodeOwnerSource source =
      decodeSupplementalInput
        (SupplementalOwnerOccurrence source)
        (supplementalInputOrdinal (acquiredOrdinal source))
        (acquiredSourceBytes source)

-- | Eliminate the exact binding without exposing its private source tokens.
foldSupplementalOwnerBinding ::
     (BoundOwnerSupplementalInputs scope inputs -> [SupplementalOwnerBindingEvidence
                                                      scope
                                                      inputs] -> result)
  -> SupplementalOwnerBinding scope inputs
  -> result
foldSupplementalOwnerBinding consume (SupplementalOwnerBinding binding) =
  foldSupplementalBinding
    (\bound evidence ->
       consume
         (BoundOwnerSupplementalInputs bound)
         (map SupplementalOwnerBindingEvidence evidence))
    binding

-- | Evaluate Core Semantics from one accepted owner-bound input generation.
assessOwnerSemantics ::
     WellFormedGraph scope
  -> BoundOwnerSupplementalInputs scope inputs
  -> SemanticAssessment scope
assessOwnerSemantics graph (BoundOwnerSupplementalInputs bound) =
  assessSemantics graph bound
