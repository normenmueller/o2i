{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed terminal-neutral projections of Operation failures.
--
-- The projections preserve fixed typed fields and source cardinalities while
-- keeping Core- and Profile-owned representations behind the Operation
-- boundary. Constructors remain private; reports are their sole producers.
module O2I.Operation.Human.Failure
  ( type HumanFailureAdapterRuleStage
  , foldHumanFailureAdapterRuleStage
  , type HumanFailureAdapterRule
  , foldHumanFailureAdapterRule
  , type HumanFailureNativeLocation
  , foldHumanFailureNativeLocation
  , type HumanFailureAdapterOccurrence
  , foldHumanFailureAdapterOccurrence
  , type HumanFailureAdapterDiagnostic
  , foldHumanFailureAdapterDiagnostic
  , type HumanAdapterSelectionFailure
  , foldHumanAdapterSelectionFailure
  , type HumanFailureRecordFamily
  , foldHumanFailureRecordFamily
  , type HumanFailureReferenceField
  , foldHumanFailureReferenceField
  , type HumanFailureCanonicalTarget
  , foldHumanFailureCanonicalTarget
  , type HumanFailureReferenceOutcome
  , foldHumanFailureReferenceOutcome
  , type HumanFailureCanonicalReference
  , foldHumanFailureCanonicalReference
  , type HumanFailureOpaquePosition
  , foldHumanFailureOpaquePosition
  , type HumanFailureOpaqueEvidence
  , foldHumanFailureOpaqueEvidence
  , type HumanFailurePropertyKey
  , foldHumanFailurePropertyKey
  , type HumanFailureCanonicalProperty
  , foldHumanFailureCanonicalProperty
  , type HumanFailureMarkerKeyOutcome
  , foldHumanFailureMarkerKeyOutcome
  , type HumanFailureMarkerCandidate
  , foldHumanFailureMarkerCandidate
  , type HumanFailureDraftValueKind
  , foldHumanFailureDraftValueKind
  , type HumanProfileResolutionFailure
  , foldHumanProfileResolutionFailure
  , type HumanProfileCompatibilityFailure
  , foldHumanProfileCompatibilityFailure
  , type HumanFailureViewSelectionCandidate
  , foldHumanFailureViewSelectionCandidate
  , type HumanViewSelectionFailure
  , foldHumanViewSelectionFailure
  , type HumanPreparationFailure
  , foldHumanPreparationFailure
  , type HumanCommonFailure
  , foldHumanCommonFailure
  , type HumanInputDefectSubject
  , foldHumanInputDefectSubject
  , type HumanInputDefectKind
  , foldHumanInputDefectKind
  , type HumanInputDefect
  , foldHumanInputDefect
  , type HumanSupplementalPayloadType
  , foldHumanSupplementalPayloadType
  , type HumanSupplementalInputDefect
  , foldHumanSupplementalInputDefect
  , type HumanNotationContractFailure
  , foldHumanNotationContractFailure
  , type HumanProfileContractEvidence
  , foldHumanProfileContractEvidence
  , type HumanIdentityIndexDefect
  , foldHumanIdentityIndexDefect
  , type HumanSelectedViewScopeDefectKind
  , foldHumanSelectedViewScopeDefectKind
  , type HumanSelectedViewScopeDefect
  , foldHumanSelectedViewScopeDefect
  , type HumanStructureInputDefect
  , foldHumanStructureInputDefect
  , type HumanSupplementalProvenanceDefect
  , foldHumanSupplementalProvenanceDefect
  ) where

import O2I.Operation.Human.Failure.Internal
