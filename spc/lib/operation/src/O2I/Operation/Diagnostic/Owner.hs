{-# LANGUAGE RankNTypes #-}

-- | Retain exact owner evidence under one prepared authority.
module O2I.Operation.Diagnostic.Owner
  ( profileActivationDiagnostics
  , foldProfileAssessmentDiagnostics
  , withModelStructureAssessment
  , structureEvidenceDiagnostic
  , bindingDiagnosticGroups
  , semanticsEvidenceDiagnostic
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Core.Identity (IdentityIndexDefect, SelectedViewScopeDefect)
import O2I.Operation.Acquisition
  ( acquiredSourceIdentity
  , foldAcquiredSupplementalSource
  )
import O2I.Operation.Diagnostic.Internal
import O2I.Operation.Diagnostic.Owner.Source (foldSupplementalOwnerBinding)
import O2I.Operation.Diagnostic.Owner.Source.Internal
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Retain every positive activation fact from one exact Profile universe.
profileActivationDiagnostics ::
     PreparedAuthority authority profile document
  -> Closure.ProfileAssessmentUniverse profile document
  -> [PreparedDiagnostic authority profile document]
profileActivationDiagnostics _ =
  map ProfileActivationDiagnostic . Closure.assessmentActivationProvenance

-- | Eliminate contract failure or retain every negative or positive result.
foldProfileAssessmentDiagnostics ::
     (NonEmpty (Profile.ProfileContractEvidence profile document) -> result)
  -> ([PreparedDiagnostic authority profile document] -> result)
  -> PreparedAuthority authority profile document
  -> Profile.ProfileProjectionAssessment profile document
  -> result
foldProfileAssessmentDiagnostics contractFailure consume _ assessment =
  Profile.foldProfileProjectionAssessment
    contractFailure
    (consume . map ProfileRejectionDiagnostic . NonEmpty.toList)
    (consume . positiveDiagnostics)
    assessment
  where
    positiveDiagnostics projection =
      map
        ProfileClassificationDiagnostic
        (Profile.profileClassificationEvidence projection)
        <> map
             ProfileMappingDiagnostic
             (Profile.profileMappingProvenance projection)
        <> map
             ProfileInvariantDiagnostic
             (Profile.profileQualificationInvariantEvidence projection)

-- | Introduce a fresh scope tied to the same preparation authority.
withModelStructureAssessment ::
     PreparedAuthority authority profile document
  -> Profile.ProfileProjection profile document
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty Structure.StructureInputDefect -> result)
  -> (forall scope. PreparedScope authority profile document scope -> Structure.StructureAssessment
                                                                        scope -> result)
  -> result
withModelStructureAssessment (PreparedAuthority _ _ source) projection identityFailure scopeFailure structureFailure consume =
  Profile.withProfileStructureAssessment
    projection
    identityFailure
    scopeFailure
    structureFailure
    (\assessment -> consume (PreparedScope source) assessment)

-- | Retain one scoped Structure rejection without flattening its evidence.
structureEvidenceDiagnostic ::
     PreparedScope authority profile document scope
  -> Structure.StructureEvidence scope
  -> PreparedDiagnostic authority profile document
structureEvidenceDiagnostic _ = StructureRejectionDiagnostic

-- | Group all Binding evidence beneath its exact supplemental source.
--
-- Every acquired source receives exactly one group, including an empty group.
-- Role and ordinal therefore belong to the enclosing source, never to a child.
bindingDiagnosticGroups ::
     SupplementalOwnerBinding authority profile document scope inputs
  -> [SupplementalDiagnosticGroup authority profile document]
bindingDiagnosticGroups binding = foldSupplementalOwnerBinding group binding
  where
    group sources _ evidence =
      [ SupplementalDiagnosticGroup source (evidenceFor source evidence)
      | source <- sources
      ]
    evidenceFor source = filter (sameSource source)
    sameSource source (SupplementalOwnerBindingEvidence evidenceSource _) =
      sourceIdentity source == sourceIdentity evidenceSource
    sourceIdentity = foldAcquiredSupplementalSource acquiredSourceIdentity

-- | Retain one Semantics rejection together with its producing assessment.
semanticsEvidenceDiagnostic ::
     PreparedScope authority profile document scope
  -> Semantics.SemanticDiagnosticEvidence scope
  -> PreparedDiagnostic authority profile document
semanticsEvidenceDiagnostic _ = SemanticsRejectionDiagnostic
