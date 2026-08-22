{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RankNTypes #-}

-- | Convert scoped owner evidence into canonical Operation diagnostics.
--
-- Every conversion retains the producing artifact at the same nominal index.
-- Rule identity, provenance, and occurrences come only from that evidence;
-- this module performs no catalog lookup or runtime correlation.
module O2I.Operation.Diagnostic.Owner
  ( profileActivationDiagnostics
  , foldProfileAssessmentDiagnostics
  , withModelStructureAssessment
  , structureEvidenceDiagnostic
  , bindingEvidenceDiagnostic
  , SemanticEvidenceConversion
  , foldSemanticEvidenceConversion
  , semanticsEvidenceDiagnostic
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (maybeToList)
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Notation (CanonicalOccurrence)
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.ArchiMate.Profile.Resolution as Profile
import O2I.Core.Identity
  ( IdentityIndexDefect
  , OccurrenceIdentity
  , SelectedViewScopeDefect
  )
import O2I.Operation.Acquisition (acquiredSourceIdentity)
import qualified O2I.Operation.Diagnostic.Internal as Internal
import O2I.Operation.Diagnostic.Owner.Source.Internal
  ( ModelOwnerSource(..)
  , ScopedModelOwnerSource(..)
  , SupplementalOwnerBinding(..)
  , SupplementalOwnerBindingEvidence(..)
  , SupplementalOwnerOccurrence(..)
  )
import O2I.Operation.Provenance (SourceIdentity)
import qualified O2I.Semantics as Semantics
import qualified O2I.Semantics.Input as Binding
import qualified O2I.Structure as Structure

-- | Convert every positive activation fact in one exact Profile universe.
profileActivationDiagnostics ::
     ModelOwnerSource document
  -> Profile.SelectedArchiMateProfile profile
  -> Closure.ProfileAssessmentUniverse profile document
  -> [Internal.Diagnostic]
profileActivationDiagnostics (ModelOwnerSource source) selected universe =
  concatMap
    activationDiagnostics
    (Closure.assessmentActivationProvenance universe)
  where
    reference =
      Profile.profileDescriptorReference
        (Profile.selectedArchiMateProfileDescriptor selected)
    activationDiagnostics =
      Closure.foldActivationProvenance
        (\_ _ _ rule owner trigger sourceRules ->
           map
             (\ruleIdentity ->
                profileDiagnostic
                  Internal.InfoSeverity
                  source
                  reference
                  ruleIdentity
                  (canonical source owner :| [canonical source trigger]))
             (rule : sourceRules))

-- | Eliminate contract failure or convert every negative or positive result.
foldProfileAssessmentDiagnostics ::
     (NonEmpty (Profile.ProfileContractEvidence profile document) -> result)
  -> ([Internal.Diagnostic] -> result)
  -> ModelOwnerSource document
  -> Profile.SelectedArchiMateProfile profile
  -> Closure.ProfileAssessmentUniverse profile document
  -> Profile.ProfileProjectionAssessment profile document
  -> result
foldProfileAssessmentDiagnostics contractFailure consume (ModelOwnerSource source) selected _ assessment =
  Profile.foldProfileProjectionAssessment
    contractFailure
    (consume . map (profileDefectDiagnostic source reference) . NonEmpty.toList)
    (consume . positiveDiagnostics source reference)
    assessment
  where
    reference =
      Profile.profileDescriptorReference
        (Profile.selectedArchiMateProfileDescriptor selected)

profileDefectDiagnostic ::
     SourceIdentity
  -> Text
  -> Profile.ProfileDiagnosticEvidence profile document
  -> Internal.Diagnostic
profileDefectDiagnostic source reference =
  Profile.foldProfileDiagnosticEvidence $ \rule evidence ->
    profileDiagnostic
      Internal.ErrorSeverity
      source
      reference
      rule
      (profileEvidenceOccurrences source evidence)

positiveDiagnostics ::
     SourceIdentity
  -> Text
  -> Profile.ProfileProjection profile document
  -> [Internal.Diagnostic]
positiveDiagnostics source reference projection =
  map
    classificationDiagnostic
    (Profile.profileClassificationEvidence projection)
    <> map mappingDiagnostic (Profile.profileMappingProvenance projection)
    <> map
         invariantDiagnostic
         (Profile.profileQualificationInvariantEvidence projection)
  where
    classificationDiagnostic =
      Profile.foldProfileClassificationEvidence $ \_ _ rule occurrence ->
        profileDiagnostic
          Internal.InfoSeverity
          source
          reference
          rule
          (canonical source occurrence :| [])
    mappingDiagnostic =
      Profile.foldProfileMappingProvenance
        (\rule occurrence _ ->
           profileDiagnostic
             Internal.InfoSeverity
             source
             reference
             rule
             (coreOccurrence source occurrence :| []))
        (\rule occurrence _ sourceOccurrence targetOccurrence ->
           profileDiagnostic
             Internal.InfoSeverity
             source
             reference
             rule
             (coreOccurrence source occurrence
                :| [ coreOccurrence source sourceOccurrence
                   , coreOccurrence source targetOccurrence
                   ]))
        (\rule occurrence _ ->
           profileDiagnostic
             Internal.InfoSeverity
             source
             reference
             rule
             (coreOccurrence source occurrence :| []))
    invariantDiagnostic =
      Profile.foldProfileInvariantEvidence $ \rule evidence ->
        profileDiagnostic
          Internal.InfoSeverity
          source
          reference
          rule
          (profileEvidenceOccurrences source evidence)

profileEvidenceOccurrences ::
     SourceIdentity
  -> Profile.ProfileEvidence profile document kind
  -> NonEmpty Internal.DiagnosticOccurrence
profileEvidenceOccurrences source =
  Profile.foldProfileEvidence
    (\occurrence -> canonical source occurrence :| [])
    (\occurrence -> canonical source occurrence :| [])
    (\owner properties ->
       canonical source owner :| map (canonical source) properties)
    (\property owner -> canonical source property :| [canonical source owner])
    (\owner _ properties ->
       canonical source owner :| map (canonical source) properties)
    (\property owner scalars ->
       canonical source property
         :| (canonical source owner
               : map
                   (Internal.DraftDiagnosticOccurrence source
                      . Draft.draftScalarLocation)
                   scalars))
    (\occurrence -> canonical source occurrence :| [])
    (\occurrence proposal related ->
       canonical source occurrence
         :| (canonical source proposal : map (canonical source) related))
    (\occurrence -> canonical source occurrence :| [])
    (\property owner _ -> canonical source property :| [canonical source owner])
    (\occurrence -> canonical source occurrence :| [])
    (\occurrence related ->
       canonical source occurrence :| map (canonical source) related)

-- | Derive the model-source witness for the fresh Structure scope.
withModelStructureAssessment ::
     ModelOwnerSource document
  -> Profile.ProfileProjection profile document
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty Structure.StructureInputDefect -> result)
  -> (forall scope. ScopedModelOwnerSource scope -> Structure.StructureAssessment
                                                      scope -> result)
  -> result
withModelStructureAssessment (ModelOwnerSource source) projection identityFailure scopeFailure structureFailure consume =
  Profile.withProfileStructureAssessment
    projection
    identityFailure
    scopeFailure
    structureFailure
    (\assessment -> consume (ScopedModelOwnerSource source) assessment)

-- | Convert one scoped Structure defect while retaining its model source.
structureEvidenceDiagnostic ::
     ScopedModelOwnerSource scope
  -> Structure.StructureEvidence scope
  -> Internal.Diagnostic
structureEvidenceDiagnostic (ScopedModelOwnerSource source) evidence =
  coreDiagnostic
    Internal.ErrorSeverity
    (Internal.StructureOwnerEvidenceProvenance
       (Structure.structureEvidenceRule evidence))
    (Structure.foldStructureEvidence structureOccurrences evidence)
  where
    occurrence = coreOccurrence source
    zeroOrMultiple =
      Structure.foldStructureZeroOrMultipleOccurrences
        []
        (\first second remaining -> first : second : remaining)
    structureOccurrences =
      Structure.StructureDefectEliminator
        { Structure.eliminateQualifiedEndpointCatalogMembership =
            \value ->
              occurrence
                (Structure.qualifiedEndpointCatalogMembershipSubject value)
                :| []
        , Structure.eliminateContextualizationSourceCategory =
            \value ->
              occurrence
                (Structure.contextualizationSourceCategorySegment value)
                :| [ occurrence
                       (Structure.contextualizationSourceCategoryOwner value)
                   ]
        , Structure.eliminateContextualizationTargetCategory =
            \value ->
              occurrence
                (Structure.contextualizationTargetCategorySegment value)
                :| [ occurrence
                       (Structure.contextualizationTargetCategoryMember value)
                   ]
        , Structure.eliminateContextualizationTargetOwnerCardinality =
            \value ->
              occurrence
                (Structure.contextualizationTargetOwnerCardinalityMember value)
                :| map
                     occurrence
                     (zeroOrMultiple
                        (Structure.contextualizationTargetOwnerCardinalityOwners
                           value))
        , Structure.eliminateSemanticRelationCompatibility =
            \value ->
              occurrence (Structure.semanticRelationCompatibilityRelation value)
                :| [ occurrence
                       (Structure.semanticRelationCompatibilitySource value)
                   , occurrence
                       (Structure.semanticRelationCompatibilityTarget value)
                   ]
        , Structure.eliminateStructuredPropositionIdentity =
            \value ->
              occurrence (Structure.structuredPropositionIdentitySubject value)
                :| map
                     occurrence
                     (Structure.structuredPropositionIdentityFirstOccurrence
                        value
                        : Structure.structuredPropositionIdentitySecondOccurrence
                            value
                        : Structure.structuredPropositionIdentityRemainingOccurrences
                            value)
        , Structure.eliminateCollectiveParticipantType =
            \value ->
              occurrence (Structure.collectiveParticipantTypeClaim value)
                :| [ occurrence
                       (Structure.collectiveParticipantTypeSegment value)
                   , occurrence
                       (Structure.collectiveParticipantTypeEndpoint value)
                   ]
        , Structure.eliminateCollectiveParticipantCardinality =
            \value ->
              occurrence (Structure.collectiveParticipantCardinalityClaim value)
                :| map
                     occurrence
                     (maybeToList
                        (Structure.collectiveParticipantCardinalitySoleEndpoint
                           value))
        , Structure.eliminateCollectiveParticipantUniqueness =
            \value ->
              occurrence (Structure.collectiveParticipantUniquenessClaim value)
                :| map
                     occurrence
                     (NonEmpty.toList
                        (Structure.collectiveParticipantUniquenessDuplicateEndpoints
                           value))
        , Structure.eliminateCollectiveTargetType =
            \value ->
              occurrence (Structure.collectiveTargetTypeClaim value)
                :| [ occurrence (Structure.collectiveTargetTypeSegment value)
                   , occurrence (Structure.collectiveTargetTypeEndpoint value)
                   ]
        , Structure.eliminateCollectiveTargetCardinality =
            \value ->
              occurrence (Structure.collectiveTargetCardinalityClaim value)
                :| map
                     occurrence
                     (zeroOrMultiple
                        (Structure.collectiveTargetCardinalityEndpoints value))
        , Structure.eliminateCollectiveTargetDistinctness =
            \value ->
              occurrence (Structure.collectiveTargetDistinctnessClaim value)
                :| map
                     occurrence
                     (NonEmpty.toList
                        (Structure.collectiveTargetDistinctnessOverlappingEndpoints
                           value))
        }

-- | Convert one graph-bound supplemental diagnostic at the same scope.
bindingEvidenceDiagnostic ::
     SupplementalOwnerBinding scope inputs
  -> SupplementalOwnerBindingEvidence scope inputs
  -> Internal.Diagnostic
bindingEvidenceDiagnostic (SupplementalOwnerBinding _) (SupplementalOwnerBindingEvidence evidence) =
  coreDiagnostic
    Internal.ErrorSeverity
    (Internal.BindingOwnerEvidenceProvenance
       (Binding.supplementalBindingEvidenceRule evidence))
    (Binding.foldSupplementalBindingEvidence
       (bindingOccurrences . supplementalSourceIdentity)
       evidence)
  where
    supplementalSourceIdentity (SupplementalOwnerOccurrence acquired) =
      acquiredSourceIdentity acquired
    bindingOccurrences source =
      Binding.SupplementalInputDefectEliminator
        { Binding.eliminateSupplementalInvalidUtf8 = const sourceOnly
        , Binding.eliminateSupplementalInvalidJsonSyntax = const sourceOnly
        , Binding.eliminateSupplementalDuplicateObjectMember = const sourceOnly
        , Binding.eliminateSupplementalTopLevelObjectRequired = const sourceOnly
        , Binding.eliminateSupplementalTypeMemberInvalid = const sourceOnly
        , Binding.eliminateSupplementalPayloadTypeNotAdmitted = const sourceOnly
        , Binding.eliminateSupplementalRequiredMemberMissing = const sourceOnly
        , Binding.eliminateSupplementalUnknownMember = const sourceOnly
        , Binding.eliminateSupplementalValueKindInvalid = const sourceOnly
        , Binding.eliminateSupplementalScalarGrammarInvalid = const sourceOnly
        , Binding.eliminateSupplementalArrayCardinalityInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalArrayDistinctnessInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalSubjectCardinalityInvalid =
            subject . Binding.supplementalSubjectCardinalitySubject
        , Binding.eliminateSupplementalIdentityUnknown =
            subject . Binding.supplementalIdentityUnknownModelIdentity
        , Binding.eliminateSupplementalIdentityAmbiguous =
            subject . Binding.supplementalIdentityAmbiguousModelIdentity
        , Binding.eliminateSupplementalIdentityWrongType =
            subject . Binding.supplementalIdentityWrongTypeModelIdentity
        , Binding.eliminateSupplementalIdentityOutOfSelectedView =
            subject . Binding.supplementalIdentityOutOfViewModelIdentity
        , Binding.eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            const sourceOnly
        , Binding.eliminateSupplementalModelIdentityContainsNul =
            const sourceOnly
        }
      where
        sourceOnly = Internal.SourceDiagnosticOccurrence source :| []
        subject identity =
          Internal.SubjectDiagnosticOccurrence source identity :| []

-- | Closed result of converting one scoped semantic evidence value.
data SemanticEvidenceConversion
  = SemanticEvidenceOccurrenceMissing
  | SemanticEvidenceConverted !Internal.Diagnostic

-- | Eliminate the impossible empty-occurrence branch or its diagnostic.
foldSemanticEvidenceConversion ::
     result
  -> (Internal.Diagnostic -> result)
  -> SemanticEvidenceConversion
  -> result
foldSemanticEvidenceConversion missing converted result =
  case result of
    SemanticEvidenceOccurrenceMissing -> missing
    SemanticEvidenceConverted diagnostic -> converted diagnostic

-- | Convert one semantic diagnostic retained by the same assessment scope.
semanticsEvidenceDiagnostic ::
     ScopedModelOwnerSource scope
  -> Semantics.SemanticAssessment scope
  -> Semantics.SemanticDiagnosticEvidence scope
  -> SemanticEvidenceConversion
semanticsEvidenceDiagnostic (ScopedModelOwnerSource source) _ evidence =
  case values of
    first:remaining ->
      SemanticEvidenceConverted
        (coreDiagnostic
           Internal.ErrorSeverity
           (Internal.SemanticsOwnerEvidenceProvenance
              (Semantics.semanticDiagnosticRule evidence))
           (first :| remaining))
    [] -> SemanticEvidenceOccurrenceMissing
  where
    values =
      map
        (Internal.SubjectDiagnosticOccurrence source)
        (Semantics.semanticDiagnosticModelIdentities evidence)
        <> map
             (Internal.CoreDiagnosticOccurrence source)
             (Semantics.semanticDiagnosticOccurrenceIdentities evidence)

profileDiagnostic ::
     Internal.DiagnosticSeverity
  -> SourceIdentity
  -> Text
  -> Text
  -> NonEmpty Internal.DiagnosticOccurrence
  -> Internal.Diagnostic
profileDiagnostic severity _ reference rule occurrences =
  Internal.Diagnostic
    severity
    Internal.ModelFinding
    (Internal.OwnerEvidenceDiagnosticProvenance
       (Internal.ProfileOwnerEvidenceProvenance reference rule))
    occurrences

coreDiagnostic ::
     Internal.DiagnosticSeverity
  -> Internal.OwnerEvidenceProvenance
  -> NonEmpty Internal.DiagnosticOccurrence
  -> Internal.Diagnostic
coreDiagnostic severity provenance occurrences =
  Internal.Diagnostic
    severity
    Internal.ModelFinding
    (Internal.OwnerEvidenceDiagnosticProvenance provenance)
    occurrences

canonical ::
     SourceIdentity -> CanonicalOccurrence -> Internal.DiagnosticOccurrence
canonical = Internal.CanonicalDiagnosticOccurrence

coreOccurrence ::
     SourceIdentity -> OccurrenceIdentity -> Internal.DiagnosticOccurrence
coreOccurrence = Internal.CoreDiagnosticOccurrence
