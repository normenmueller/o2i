{-# LANGUAGE RankNTypes #-}

-- | Total profile-neutral ArchiMate canonicalization and assessment.
--
-- Canonical construction retains every Draft observation. Assessment reports
-- identity and native-reference outcomes without interpreting O2I Profile rules.
module O2I.ArchiMate.Profile.Notation
  ( -- | Observation-complete canonical notation document.
    CanonicalDocument
  , withCanonicalDocument
  , canonicalDocumentDraft
  , canonicalDocumentRecords
  , canonicalDocumentProperties
  , canonicalDocumentReferences
  , -- | Stable address of one canonical notation observation.
    CanonicalOccurrence
  , -- | Closed category of canonical occurrence addresses.
    CanonicalOccurrenceKind
  , foldCanonicalOccurrenceKind
  , canonicalOccurrenceKind
  , canonicalOccurrenceOrdinal
  , -- | Opaque canonical native record with retained identity evidence.
    CanonicalRecord
  , foldCanonicalRecord
  , -- | Opaque canonical property observation and provenance.
    CanonicalProperty
  , canonicalPropertyOccurrence
  , canonicalPropertyOwner
  , canonicalPropertyOwnerFamily
  , canonicalPropertyLocation
  , canonicalPropertyValues
  , canonicalPropertyOpaqueEvidence
  , foldCanonicalPropertyKey
  , -- | Opaque canonical native field observation.
    CanonicalField
  , canonicalFieldKind
  , canonicalFieldScalars
  , canonicalFieldLocation
  , -- | Closed reason why one observed native identity is invalid.
    IdentityInvalidReason
  , foldIdentityInvalidReason
  , -- | Total outcome of assessing one native identity.
    IdentityOutcome
  , foldIdentityOutcome
  , -- | Opaque resolved native-reference target.
    CanonicalTarget
  , canonicalTargetOccurrence
  , canonicalTargetFamily
  , canonicalTargetIdentity
  , canonicalTargetLocation
  , canonicalTargetFields
  , -- | Total outcome of resolving one native reference.
    ReferenceOutcome
  , foldReferenceOutcome
  , -- | Opaque canonical native reference and its resolution evidence.
    CanonicalReference
  , canonicalReferenceOccurrence
  , canonicalReferenceOwner
  , canonicalReferenceField
  , canonicalReferenceExpectedFamily
  , canonicalReferenceLocation
  , canonicalReferenceOutcome
  , -- | Opaque inventory descriptor for one native View.
    CanonicalView
  , canonicalViews
  , canonicalViewOccurrence
  , canonicalViewIdentity
  , canonicalViewNameFields
  , canonicalViewLocation
  , -- | Total outcome of recognizing one Profile-marker key candidate.
    MarkerKeyOutcome
  , foldMarkerKeyOutcome
  , -- | Opaque model-root property considered as marker evidence.
    MarkerCandidate
  , markerCandidateProperty
  , markerCandidateDefinitionFields
  , markerCandidateKeyOutcome
  , -- | Opaque aggregate assessment of model-root Profile marker evidence.
    MarkerEvidenceAssessment
  , assessMarkerEvidence
  , foldMarkerEvidenceAssessment
  , -- | Closed complete Notation issue-kind algebra.
    ArchiMateNotationIssueKind
  , ViewInventoryIssueKind
  , ProfileMarkerIssueKind
  , SelectedUniverseIssueKind
  , allArchiMateNotationIssueKinds
  , allViewInventoryIssueKinds
  , allProfileMarkerIssueKinds
  , allSelectedUniverseIssueKinds
  , foldArchiMateNotationIssueKind
  , archiMateNotationIssueKindToken
  , viewInventoryIssueKindToken
  , profileMarkerIssueKindToken
  , selectedUniverseIssueKindToken
  , -- | Opaque Notation issue with non-empty exact native evidence.
    ArchiMateNotationIssue
  , ArchiMateNotationEvidence
  , foldArchiMateNotationEvidence
  , archiMateNotationIssueKind
  , archiMateNotationIssueSubject
  , archiMateNotationIssueEvidence
  , assessCanonicalViewInventory
  , profileMarkerNotationIssues
  , -- | Opaque selected-universe assessment and conformance proof.
    StageResult
  , foldStageResult
  , NotationResult
  , NotationConformantUniverse
  , assessArchiMateNotation
  , notationIssues
  , notationConformance
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft
  ( DraftFieldValue
  , DraftLocation
  , DraftOpaqueEvidence
  , DraftRecordFamilyValue
  , DraftReferenceFieldValue
  , DraftScalar
  , DraftValueKind
  , ProfileDraft
  )
import O2I.ArchiMate.Profile.Internal.Closure.Witness
  ( ProfileAssessmentUniverse
  )
import O2I.ArchiMate.Profile.Internal.Notation hiding
  ( CanonicalDocument
  , ViewDescriptor
  , buildCanonicalDocument
  )
import O2I.ArchiMate.Profile.Internal.Notation.Conformance
  ( ArchiMateNotationEvidence
  , ArchiMateNotationIssue
  , ArchiMateNotationIssueKind
  , NotationConformantUniverse
  , NotationResult
  , ProfileMarkerIssueKind
  , SelectedUniverseIssueKind
  , StageResult
  , ViewInventoryIssueKind
  )
import qualified O2I.ArchiMate.Profile.Internal.Notation.Conformance as Conformance
import O2I.ArchiMate.Profile.Internal.Notation.Witness
import O2I.Core.Identity (ModelIdentity)

-- | Build one canonical document under a fresh source witness.
withCanonicalDocument ::
     ProfileDraft
  -> (forall document. CanonicalDocument document -> result)
  -> result
withCanonicalDocument = withCanonicalDocumentValue

-- | Original observation-complete Draft retained by the document.
canonicalDocumentDraft :: CanonicalDocument document -> ProfileDraft
canonicalDocumentDraft = canonicalDocumentDraftValue . canonicalDocumentValue

-- | Canonical record occurrences in deterministic source order.
canonicalDocumentRecords :: CanonicalDocument document -> [CanonicalRecord]
canonicalDocumentRecords =
  canonicalDocumentRecordsValue . canonicalDocumentValue

-- | Canonical property occurrences in deterministic source order.
canonicalDocumentProperties :: CanonicalDocument document -> [CanonicalProperty]
canonicalDocumentProperties =
  canonicalDocumentPropertiesValue . canonicalDocumentValue

-- | Canonical reference occurrences in deterministic source order.
canonicalDocumentReferences ::
     CanonicalDocument document -> [CanonicalReference]
canonicalDocumentReferences =
  canonicalDocumentReferencesValue . canonicalDocumentValue

-- | Consume every closed canonical occurrence kind.
foldCanonicalOccurrenceKind ::
     result -> result -> result -> CanonicalOccurrenceKind -> result
foldCanonicalOccurrenceKind record property reference kind =
  case kind of
    CanonicalRecordOccurrence -> record
    CanonicalPropertyOccurrence -> property
    CanonicalReferenceOccurrence -> reference

-- | Closed category of the addressed canonical observation.
canonicalOccurrenceKind :: CanonicalOccurrence -> CanonicalOccurrenceKind
canonicalOccurrenceKind = canonicalOccurrenceKindValue

-- | Stable occurrence ordinal within the canonical document.
canonicalOccurrenceOrdinal :: CanonicalOccurrence -> Natural
canonicalOccurrenceOrdinal = canonicalOccurrenceOrdinalValue

-- | Consume one canonical record while retaining malformed identity evidence.
foldCanonicalRecord ::
     (CanonicalOccurrence -> DraftRecordFamilyValue -> IdentityOutcome -> DraftLocation -> [CanonicalField] -> result)
  -> CanonicalRecord
  -> result
foldCanonicalRecord consume record =
  consume
    (canonicalRecordOccurrenceValue record)
    (canonicalRecordFamilyValue record)
    (canonicalRecordIdentityValue record)
    (canonicalRecordLocationValue record)
    (canonicalRecordFieldsValue record)

-- | Stable occurrence assigned to the property observation.
canonicalPropertyOccurrence :: CanonicalProperty -> CanonicalOccurrence
canonicalPropertyOccurrence = canonicalPropertyOccurrenceValue

-- | Canonical occurrence of the record that owns the property.
canonicalPropertyOwner :: CanonicalProperty -> CanonicalOccurrence
canonicalPropertyOwner = canonicalPropertyOwnerValue

-- | Native record family of the property owner.
canonicalPropertyOwnerFamily :: CanonicalProperty -> DraftRecordFamilyValue
canonicalPropertyOwnerFamily = canonicalPropertyOwnerFamilyValue

-- | Exact source location of the property observation.
canonicalPropertyLocation :: CanonicalProperty -> DraftLocation
canonicalPropertyLocation = canonicalPropertyLocationValue

-- | All observed property values without semantic interpretation.
canonicalPropertyValues :: CanonicalProperty -> [DraftScalar]
canonicalPropertyValues = canonicalPropertyValuesValue

-- | Unrecognized property evidence retained for provenance.
canonicalPropertyOpaqueEvidence :: CanonicalProperty -> [DraftOpaqueEvidence]
canonicalPropertyOpaqueEvidence = canonicalPropertyOpaqueEvidenceValue

-- | Consume direct key occurrences or the one retained definition reference.
foldCanonicalPropertyKey ::
     ([DraftScalar] -> result)
  -> (CanonicalReference -> result)
  -> CanonicalProperty
  -> result
foldCanonicalPropertyKey direct referenced property =
  case canonicalPropertyKeyEvidenceValue property of
    CanonicalDirectPropertyKey scalars -> direct scalars
    CanonicalReferencedPropertyKey reference -> referenced reference

-- | Native field kind represented by the canonical field.
canonicalFieldKind :: CanonicalField -> DraftFieldValue
canonicalFieldKind = canonicalFieldValue

-- | All scalar observations retained for the canonical field.
canonicalFieldScalars :: CanonicalField -> [DraftScalar]
canonicalFieldScalars = canonicalFieldScalarsValue

-- | Exact source location of the canonical field.
canonicalFieldLocation :: CanonicalField -> DraftLocation
canonicalFieldLocation = canonicalFieldLocationValue

-- | Consume every closed reason for an invalid native identity.
foldIdentityInvalidReason ::
     (DraftValueKind -> result)
  -> result
  -> result
  -> result
  -> IdentityInvalidReason
  -> result
foldIdentityInvalidReason nonText empty u0000 surrogate reason =
  case reason of
    IdentityValueIsNotText kind -> nonText kind
    IdentityValueIsEmpty -> empty
    IdentityValueContainsU0000 -> u0000
    IdentityValueContainsSurrogate -> surrogate

-- | Consume missing, multiple, invalid, or resolved identity evidence.
foldIdentityOutcome ::
     result
  -> ([DraftScalar] -> result)
  -> (DraftScalar -> IdentityInvalidReason -> result)
  -> (DraftScalar -> ModelIdentity -> result)
  -> IdentityOutcome
  -> result
foldIdentityOutcome missing multiple invalid resolved outcome =
  case outcome of
    IdentityMissing -> missing
    IdentityMultiple scalars -> multiple scalars
    IdentityInvalid scalar reason -> invalid scalar reason
    IdentityResolved scalar identifier -> resolved scalar identifier

-- | Stable occurrence of the resolved target record.
canonicalTargetOccurrence :: CanonicalTarget -> CanonicalOccurrence
canonicalTargetOccurrence = canonicalTargetOccurrenceValue

-- | Native record family of the resolved target.
canonicalTargetFamily :: CanonicalTarget -> DraftRecordFamilyValue
canonicalTargetFamily = canonicalTargetFamilyValue

-- | Resolved model identity of the target.
canonicalTargetIdentity :: CanonicalTarget -> ModelIdentity
canonicalTargetIdentity = canonicalTargetIdentityValue

-- | Exact source location of the target record.
canonicalTargetLocation :: CanonicalTarget -> DraftLocation
canonicalTargetLocation = canonicalTargetLocationValue

-- | Canonical native fields retained for the target record.
canonicalTargetFields :: CanonicalTarget -> [CanonicalField]
canonicalTargetFields = canonicalTargetFieldsValue

-- | Consume every closed native-reference resolution outcome.
foldReferenceOutcome ::
     (IdentityOutcome -> result)
  -> (DraftScalar -> ModelIdentity -> result)
  -> (DraftScalar -> ModelIdentity -> DraftRecordFamilyValue -> [CanonicalTarget] -> result)
  -> (DraftScalar -> ModelIdentity -> DraftRecordFamilyValue -> [CanonicalTarget] -> result)
  -> (DraftScalar -> ModelIdentity -> CanonicalTarget -> result)
  -> ReferenceOutcome
  -> result
foldReferenceOutcome invalid missing wrongFamily ambiguous resolved outcome =
  case outcome of
    ReferenceIdentityInvalid identityValue -> invalid identityValue
    ReferenceTargetMissing scalar identifier -> missing scalar identifier
    ReferenceTargetWrongFamily scalar identifier expected targets ->
      wrongFamily scalar identifier expected targets
    ReferenceExpectedFamilyAmbiguous scalar identifier expected targets ->
      ambiguous scalar identifier expected targets
    ReferenceResolved scalar identifier target ->
      resolved scalar identifier target

-- | Stable occurrence assigned to the native reference.
canonicalReferenceOccurrence :: CanonicalReference -> CanonicalOccurrence
canonicalReferenceOccurrence = canonicalReferenceOccurrenceValue

-- | Canonical occurrence of the record that owns the reference.
canonicalReferenceOwner :: CanonicalReference -> CanonicalOccurrence
canonicalReferenceOwner = canonicalReferenceOwnerValue

-- | Native reference field represented by the occurrence.
canonicalReferenceField :: CanonicalReference -> DraftReferenceFieldValue
canonicalReferenceField = canonicalReferenceFieldValue

-- | Native record family required for a valid target.
canonicalReferenceExpectedFamily :: CanonicalReference -> DraftRecordFamilyValue
canonicalReferenceExpectedFamily = canonicalReferenceExpectedFamilyValue

-- | Exact source location of the reference observation.
canonicalReferenceLocation :: CanonicalReference -> DraftLocation
canonicalReferenceLocation = canonicalReferenceLocationValue

-- | Total native-reference resolution outcome, including retained defects.
canonicalReferenceOutcome :: CanonicalReference -> ReferenceOutcome
canonicalReferenceOutcome = canonicalReferenceOutcomeValue

-- | Inventory every native View under its source-document witness.
canonicalViews :: CanonicalDocument document -> [CanonicalView document]
canonicalViews = canonicalViewsValue

-- | Canonical occurrence of the represented native View.
canonicalViewOccurrence :: CanonicalView document -> CanonicalOccurrence
canonicalViewOccurrence = viewDescriptorOccurrenceValue . canonicalViewValue

-- | Native identity outcome of the represented View.
canonicalViewIdentity :: CanonicalView document -> IdentityOutcome
canonicalViewIdentity = viewDescriptorIdentityValue . canonicalViewValue

-- | All native name fields observed for the View.
canonicalViewNameFields :: CanonicalView document -> [CanonicalField]
canonicalViewNameFields = viewDescriptorNameFieldsValue . canonicalViewValue

-- | Exact source location of the View record.
canonicalViewLocation :: CanonicalView document -> DraftLocation
canonicalViewLocation = viewDescriptorLocationValue . canonicalViewValue

-- | Consume every closed marker-key recognition outcome.
foldMarkerKeyOutcome ::
     result
  -> ([DraftScalar] -> result)
  -> (DraftScalar -> result)
  -> (DraftScalar -> result)
  -> (DraftScalar -> result)
  -> (CanonicalReference -> result)
  -> MarkerKeyOutcome
  -> result
foldMarkerKeyOutcome missing multiple nonText exact other rejected outcome =
  case outcome of
    MarkerKeyMissing -> missing
    MarkerKeyMultiple scalars -> multiple scalars
    MarkerKeyNonText scalar -> nonText scalar
    MarkerKeyExact scalar -> exact scalar
    MarkerKeyOther scalar -> other scalar
    MarkerKeyReferenceRejected reference -> rejected reference

-- | Property occurrence considered as model-root Profile marker evidence.
markerCandidateProperty :: MarkerCandidate -> CanonicalProperty
markerCandidateProperty = markerCandidatePropertyValue

-- | Native fields of a referenced property definition, when present.
markerCandidateDefinitionFields :: MarkerCandidate -> [CanonicalField]
markerCandidateDefinitionFields = markerCandidateDefinitionFieldsValue

-- | Total recognition outcome for the candidate marker key.
markerCandidateKeyOutcome :: MarkerCandidate -> MarkerKeyOutcome
markerCandidateKeyOutcome = markerCandidateKeyOutcomeValue

-- | Assess all model-root key candidates in exact source order.
assessMarkerEvidence :: CanonicalDocument document -> MarkerEvidenceAssessment
assessMarkerEvidence = assessMarkerEvidenceValue . canonicalDocumentValue

-- | Consume rejected or accepted marker evidence without exposing constructors.
foldMarkerEvidenceAssessment ::
     ([MarkerCandidate] -> result)
  -> ([MarkerCandidate] -> [CanonicalProperty] -> result)
  -> MarkerEvidenceAssessment
  -> result
foldMarkerEvidenceAssessment rejected accepted assessment =
  case assessment of
    MarkerEvidenceRejected candidates -> rejected candidates
    MarkerEvidenceAccepted candidates properties ->
      accepted candidates properties

-- | Canonical complete inventory of every externally reportable issue kind.
allArchiMateNotationIssueKinds :: NonEmpty ArchiMateNotationIssueKind
allArchiMateNotationIssueKinds = Conformance.allArchiMateNotationIssueKindsValue

-- | Canonical closed View-inventory subset.
allViewInventoryIssueKinds :: NonEmpty ViewInventoryIssueKind
allViewInventoryIssueKinds = Conformance.allViewInventoryIssueKindsValue

-- | Canonical closed Profile-marker subset.
allProfileMarkerIssueKinds :: NonEmpty ProfileMarkerIssueKind
allProfileMarkerIssueKinds = Conformance.allProfileMarkerIssueKindsValue

-- | Canonical closed selected-universe subset.
allSelectedUniverseIssueKinds :: NonEmpty SelectedUniverseIssueKind
allSelectedUniverseIssueKinds = Conformance.allSelectedUniverseIssueKindsValue

-- | Consume one of the three independently closed issue-kind families.
foldArchiMateNotationIssueKind ::
     (ViewInventoryIssueKind -> result)
  -> (ProfileMarkerIssueKind -> result)
  -> (SelectedUniverseIssueKind -> result)
  -> ArchiMateNotationIssueKind
  -> result
foldArchiMateNotationIssueKind inventory marker universe kind =
  case kind of
    Conformance.ViewInventoryNotationKind value -> inventory value
    Conformance.ProfileMarkerNotationKind value -> marker value
    Conformance.SelectedUniverseNotationKind value -> universe value

-- | Stable adapter-binding discriminator for one complete issue kind.
archiMateNotationIssueKindToken :: ArchiMateNotationIssueKind -> Text
archiMateNotationIssueKindToken =
  Conformance.archiMateNotationIssueKindTokenValue

-- | Stable discriminator for one View-inventory issue kind.
viewInventoryIssueKindToken :: ViewInventoryIssueKind -> Text
viewInventoryIssueKindToken = Conformance.viewInventoryIssueKindTokenValue

-- | Stable discriminator for one Profile-marker issue kind.
profileMarkerIssueKindToken :: ProfileMarkerIssueKind -> Text
profileMarkerIssueKindToken = Conformance.profileMarkerIssueKindTokenValue

-- | Stable discriminator for one selected-universe issue kind.
selectedUniverseIssueKindToken :: SelectedUniverseIssueKind -> Text
selectedUniverseIssueKindToken = Conformance.selectedUniverseIssueKindTokenValue

-- | Consume exact occurrence, scalar-value, or reference evidence.
foldArchiMateNotationEvidence ::
     (DraftLocation -> result)
  -> (DraftLocation -> DraftValueKind -> Text -> result)
  -> (DraftLocation -> Text -> [DraftLocation] -> result)
  -> ArchiMateNotationEvidence
  -> result
foldArchiMateNotationEvidence occurrence value reference evidence =
  case evidence of
    Conformance.NotationOccurrenceEvidence location -> occurrence location
    Conformance.NotationValueEvidence location kind text ->
      value location kind text
    Conformance.NotationReferenceEvidence location text targets ->
      reference location text targets

-- | Closed kind of one Profile-classified Notation issue.
archiMateNotationIssueKind ::
     ArchiMateNotationIssue -> ArchiMateNotationIssueKind
archiMateNotationIssueKind = Conformance.archiMateNotationIssueKindValue

-- | Exact native subject location of one Notation issue.
archiMateNotationIssueSubject :: ArchiMateNotationIssue -> DraftLocation
archiMateNotationIssueSubject = Conformance.archiMateNotationIssueSubjectValue

-- | Non-empty exact native evidence for one Notation issue.
archiMateNotationIssueEvidence ::
     ArchiMateNotationIssue -> NonEmpty ArchiMateNotationEvidence
archiMateNotationIssueEvidence = Conformance.archiMateNotationIssueEvidenceValue

-- | Assess only the model-global identity and View discovery boundary.
assessCanonicalViewInventory ::
     CanonicalDocument document -> [ArchiMateNotationIssue]
assessCanonicalViewInventory = Conformance.assessCanonicalViewInventoryValue

-- | Assess only profile-neutral model-root marker-key integrity.
profileMarkerNotationIssues ::
     CanonicalDocument document -> [ArchiMateNotationIssue]
profileMarkerNotationIssues = Conformance.assessProfileMarkerIssuesValue

-- | Consume rejection with non-empty issues or the accepted stage witness.
foldStageResult ::
     (NonEmpty issue -> result)
  -> (accepted -> result)
  -> StageResult issue accepted
  -> result
foldStageResult rejected accepted result =
  case result of
    Conformance.StageRejected issues -> rejected issues
    Conformance.StageAccepted value -> accepted value

-- | Assess profile-neutral identity and reference integrity once.
assessArchiMateNotation ::
     ProfileAssessmentUniverse profile document
  -> NotationResult profile document
assessArchiMateNotation = Conformance.assessArchiMateNotationValue

-- | Canonically ordered complete issues for the exact selected universe.
notationIssues :: NotationResult profile document -> [ArchiMateNotationIssue]
notationIssues = Conformance.notationIssuesValue

-- | Construct the opaque projection proof only for an issue-free universe.
notationConformance ::
     NotationResult profile document
  -> StageResult
       ArchiMateNotationIssue
       (NotationConformantUniverse profile document)
notationConformance = Conformance.notationConformanceValue
