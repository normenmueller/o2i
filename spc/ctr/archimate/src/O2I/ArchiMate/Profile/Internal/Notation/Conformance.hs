{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Closed profile-neutral Notation classification and conformance proof.
module O2I.ArchiMate.Profile.Internal.Notation.Conformance where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Closure
import O2I.ArchiMate.Profile.Internal.Closure.Witness
import O2I.ArchiMate.Profile.Internal.Draft
import qualified O2I.ArchiMate.Profile.Internal.Notation as Raw
import O2I.ArchiMate.Profile.Internal.Notation.Witness
import O2I.Core.Identity (ModelIdentity, modelIdentityText)

-- | Closed View-inventory subset in canonical contract order.
data ViewInventoryIssueKind
  = ModelIdentityMissing
  | ModelIdentityMultiplicity
  | ModelIdentityValueKindInvalid
  | ModelIdentityGrammarInvalid
  | ModelIdentityDuplicate
  | ViewIdentityMissing
  | ViewIdentityMultiplicity
  | ViewIdentityValueKindInvalid
  | ViewIdentityGrammarInvalid
  | ViewIdentityDuplicate
  | ViewNameMissing
  | ViewNameMultiplicity
  | ViewNameValueKindInvalid
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed Profile-marker key-integrity subset.
data ProfileMarkerIssueKind
  = MarkerKeyMissing
  | MarkerKeyMultiplicity
  | MarkerKeyValueKindInvalid
  | MarkerReferenceIdentityMissing
  | MarkerReferenceIdentityMultiplicity
  | MarkerReferenceIdentityValueKindInvalid
  | MarkerReferenceIdentityGrammarInvalid
  | MarkerReferenceTargetMissing
  | MarkerReferenceTargetWrongFamily
  | MarkerReferenceTargetAmbiguous
  | MarkerDefinitionNameMissing
  | MarkerDefinitionNameMultiplicity
  | MarkerDefinitionNameValueKindInvalid
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed identity and reference integrity subset for the final universe.
data SelectedUniverseIssueKind
  = RecordIdentityMissing
  | RecordIdentityMultiplicity
  | RecordIdentityValueKindInvalid
  | RecordIdentityGrammarInvalid
  | RecordIdentityDuplicate
  | ReferenceIdentityMissing
  | ReferenceIdentityMultiplicity
  | ReferenceIdentityValueKindInvalid
  | ReferenceIdentityGrammarInvalid
  | ReferenceTargetMissing
  | ReferenceTargetWrongFamily
  | ReferenceTargetAmbiguous
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Complete closed Notation issue discriminator owned by the Profile.
data ArchiMateNotationIssueKind
  = ViewInventoryNotationKind !ViewInventoryIssueKind
  | ProfileMarkerNotationKind !ProfileMarkerIssueKind
  | SelectedUniverseNotationKind !SelectedUniverseIssueKind
  deriving (Eq, Ord, Show)

-- | Exact native evidence retained for one Notation issue.
data ArchiMateNotationEvidence
  = NotationOccurrenceEvidence !DraftLocation
  | NotationValueEvidence !DraftLocation !DraftValueKind !Text
  | NotationReferenceEvidence !DraftLocation !Text ![DraftLocation]
  deriving (Eq, Ord, Show)

-- | Opaque issue with non-empty evidence.
data ArchiMateNotationIssue = ArchiMateNotationIssue
  { archiMateNotationIssueKindValue :: !ArchiMateNotationIssueKind
  , archiMateNotationIssueSubjectValue :: !DraftLocation
  , archiMateNotationIssueEvidenceValue :: !(NonEmpty ArchiMateNotationEvidence)
  } deriving (Eq, Ord, Show)

-- | Total result of one stage with non-empty rejection evidence.
data StageResult issue accepted
  = StageRejected !(NonEmpty issue)
  | StageAccepted !accepted

-- | Exact universe paired with its canonically ordered Notation issues.
data NotationResult profile document = NotationResult
  { notationResultUniverseValue :: !(ProfileAssessmentUniverse profile document)
  , notationIssuesValue :: ![ArchiMateNotationIssue]
  }

type role NotationResult nominal nominal

-- | Opaque proof that the exact selected universe has no Notation issue.
newtype NotationConformantUniverse profile document =
  NotationConformantUniverse (ProfileAssessmentUniverse profile document)

type role NotationConformantUniverse nominal nominal

allViewInventoryIssueKindsValue :: NonEmpty ViewInventoryIssueKind
allViewInventoryIssueKindsValue =
  ModelIdentityMissing :| [ModelIdentityMultiplicity .. maxBound]

allProfileMarkerIssueKindsValue :: NonEmpty ProfileMarkerIssueKind
allProfileMarkerIssueKindsValue =
  MarkerKeyMissing :| [MarkerKeyMultiplicity .. maxBound]

allSelectedUniverseIssueKindsValue :: NonEmpty SelectedUniverseIssueKind
allSelectedUniverseIssueKindsValue =
  RecordIdentityMissing :| [RecordIdentityMultiplicity .. maxBound]

allArchiMateNotationIssueKindsValue :: NonEmpty ArchiMateNotationIssueKind
allArchiMateNotationIssueKindsValue =
  fmap ViewInventoryNotationKind allViewInventoryIssueKindsValue
    <> fmap ProfileMarkerNotationKind allProfileMarkerIssueKindsValue
    <> fmap SelectedUniverseNotationKind allSelectedUniverseIssueKindsValue

viewInventoryIssueKindTokenValue :: ViewInventoryIssueKind -> Text
viewInventoryIssueKindTokenValue kind =
  case kind of
    ModelIdentityMissing -> "model-identity-missing"
    ModelIdentityMultiplicity -> "model-identity-multiplicity"
    ModelIdentityValueKindInvalid -> "model-identity-value-kind-invalid"
    ModelIdentityGrammarInvalid -> "model-identity-grammar-invalid"
    ModelIdentityDuplicate -> "model-identity-duplicate"
    ViewIdentityMissing -> "view-identity-missing"
    ViewIdentityMultiplicity -> "view-identity-multiplicity"
    ViewIdentityValueKindInvalid -> "view-identity-value-kind-invalid"
    ViewIdentityGrammarInvalid -> "view-identity-grammar-invalid"
    ViewIdentityDuplicate -> "view-identity-duplicate"
    ViewNameMissing -> "view-name-missing"
    ViewNameMultiplicity -> "view-name-multiplicity"
    ViewNameValueKindInvalid -> "view-name-value-kind-invalid"

profileMarkerIssueKindTokenValue :: ProfileMarkerIssueKind -> Text
profileMarkerIssueKindTokenValue kind =
  case kind of
    MarkerKeyMissing -> "marker-key-missing"
    MarkerKeyMultiplicity -> "marker-key-multiplicity"
    MarkerKeyValueKindInvalid -> "marker-key-value-kind-invalid"
    MarkerReferenceIdentityMissing -> "marker-reference-identity-missing"
    MarkerReferenceIdentityMultiplicity ->
      "marker-reference-identity-multiplicity"
    MarkerReferenceIdentityValueKindInvalid ->
      "marker-reference-identity-value-kind-invalid"
    MarkerReferenceIdentityGrammarInvalid ->
      "marker-reference-identity-grammar-invalid"
    MarkerReferenceTargetMissing -> "marker-reference-target-missing"
    MarkerReferenceTargetWrongFamily -> "marker-reference-target-wrong-family"
    MarkerReferenceTargetAmbiguous -> "marker-reference-target-ambiguous"
    MarkerDefinitionNameMissing -> "marker-definition-name-missing"
    MarkerDefinitionNameMultiplicity -> "marker-definition-name-multiplicity"
    MarkerDefinitionNameValueKindInvalid ->
      "marker-definition-name-value-kind-invalid"

selectedUniverseIssueKindTokenValue :: SelectedUniverseIssueKind -> Text
selectedUniverseIssueKindTokenValue kind =
  case kind of
    RecordIdentityMissing -> "record-identity-missing"
    RecordIdentityMultiplicity -> "record-identity-multiplicity"
    RecordIdentityValueKindInvalid -> "record-identity-value-kind-invalid"
    RecordIdentityGrammarInvalid -> "record-identity-grammar-invalid"
    RecordIdentityDuplicate -> "record-identity-duplicate"
    ReferenceIdentityMissing -> "reference-identity-missing"
    ReferenceIdentityMultiplicity -> "reference-identity-multiplicity"
    ReferenceIdentityValueKindInvalid -> "reference-identity-value-kind-invalid"
    ReferenceIdentityGrammarInvalid -> "reference-identity-grammar-invalid"
    ReferenceTargetMissing -> "reference-target-missing"
    ReferenceTargetWrongFamily -> "reference-target-wrong-family"
    ReferenceTargetAmbiguous -> "reference-target-ambiguous"

archiMateNotationIssueKindTokenValue :: ArchiMateNotationIssueKind -> Text
archiMateNotationIssueKindTokenValue kind =
  case kind of
    ViewInventoryNotationKind value -> viewInventoryIssueKindTokenValue value
    ProfileMarkerNotationKind value -> profileMarkerIssueKindTokenValue value
    SelectedUniverseNotationKind value ->
      selectedUniverseIssueKindTokenValue value

assessCanonicalViewInventoryValue ::
     CanonicalDocument document -> [ArchiMateNotationIssue]
assessCanonicalViewInventoryValue document =
  canonicalOrder (identityIssues <> nameIssues)
  where
    raw = canonicalDocumentValue document
    records = Raw.canonicalDocumentRecordsValue raw
    modelRecords =
      filter ((== ModelRootFamily) . Raw.canonicalRecordFamilyValue) records
    viewRecords =
      filter ((== ViewFamily) . Raw.canonicalRecordFamilyValue) records
    modelDuplicates = duplicateIdentityLocations modelRecords
    viewDuplicates = duplicateIdentityLocations viewRecords
    identityIssues =
      concatMap
        (inventoryIdentityIssues
           ModelIdentityMissing
           ModelIdentityMultiplicity
           ModelIdentityValueKindInvalid
           ModelIdentityGrammarInvalid
           ModelIdentityDuplicate
           modelDuplicates)
        modelRecords
        <> concatMap
             (inventoryIdentityIssues
                ViewIdentityMissing
                ViewIdentityMultiplicity
                ViewIdentityValueKindInvalid
                ViewIdentityGrammarInvalid
                ViewIdentityDuplicate
                viewDuplicates)
             viewRecords
    nameIssues = concatMap viewNameIssues viewRecords

assessProfileMarkerIssuesValue ::
     CanonicalDocument document -> [ArchiMateNotationIssue]
assessProfileMarkerIssuesValue document =
  canonicalOrder (concatMap markerCandidateIssues candidates)
  where
    raw = canonicalDocumentValue document
    candidates =
      case Raw.assessMarkerEvidenceValue raw of
        Raw.MarkerEvidenceRejected values -> values
        Raw.MarkerEvidenceAccepted values _ -> values

assessArchiMateNotationValue ::
     ProfileAssessmentUniverse profile document
  -> NotationResult profile document
assessArchiMateNotationValue universe =
  NotationResult universe (canonicalOrder issues)
  where
    closed = profileAssessmentUniverseValue universe
    rawDocument = closedViewDocumentValue closed
    witnessedDocument = CanonicalDocument rawDocument
    document = Raw.canonicalDocumentRecordsValue rawDocument
    scope = closedViewUniverseValue closed
    records =
      filter
        ((`Set.member` scope) . Raw.canonicalRecordOccurrenceValue)
        document
    duplicateLocations = duplicateIdentityLocations records
    identityIssues =
      concatMap (selectedIdentityIssues duplicateLocations) records
    referenceIssues =
      concatMap
        selectedReferenceIssues
        (filter
           ((`Set.member` scope) . Raw.canonicalReferenceOwnerValue)
           (Raw.canonicalDocumentReferencesValue
              (closedViewDocumentValue closed)))
    issues =
      assessCanonicalViewInventoryValue witnessedDocument
        <> assessProfileMarkerIssuesValue witnessedDocument
        <> identityIssues
        <> referenceIssues

notationConformanceValue ::
     NotationResult profile document
  -> StageResult
       ArchiMateNotationIssue
       (NotationConformantUniverse profile document)
notationConformanceValue result =
  case NonEmpty.nonEmpty (notationIssuesValue result) of
    Just issues -> StageRejected issues
    Nothing ->
      StageAccepted
        (NotationConformantUniverse (notationResultUniverseValue result))

notationConformantUniverseValue ::
     NotationConformantUniverse profile document
  -> ProfileAssessmentUniverse profile document
notationConformantUniverseValue (NotationConformantUniverse universe) = universe

inventoryIdentityIssues ::
     ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> Map ModelIdentity [DraftLocation]
  -> Raw.CanonicalRecord
  -> [ArchiMateNotationIssue]
inventoryIdentityIssues missing multiple invalid grammar duplicate duplicates record =
  identityOutcomeIssues
    (ViewInventoryNotationKind missing)
    (ViewInventoryNotationKind multiple)
    (ViewInventoryNotationKind invalid)
    (ViewInventoryNotationKind grammar)
    (ViewInventoryNotationKind duplicate)
    duplicates
    (Raw.canonicalRecordLocationValue record)
    (Raw.canonicalRecordIdentityValue record)

selectedIdentityIssues ::
     Map ModelIdentity [DraftLocation]
  -> Raw.CanonicalRecord
  -> [ArchiMateNotationIssue]
selectedIdentityIssues duplicates record =
  identityOutcomeIssues
    (SelectedUniverseNotationKind RecordIdentityMissing)
    (SelectedUniverseNotationKind RecordIdentityMultiplicity)
    (SelectedUniverseNotationKind RecordIdentityValueKindInvalid)
    (SelectedUniverseNotationKind RecordIdentityGrammarInvalid)
    (SelectedUniverseNotationKind RecordIdentityDuplicate)
    duplicates
    (Raw.canonicalRecordLocationValue record)
    (Raw.canonicalRecordIdentityValue record)

identityOutcomeIssues ::
     ArchiMateNotationIssueKind
  -> ArchiMateNotationIssueKind
  -> ArchiMateNotationIssueKind
  -> ArchiMateNotationIssueKind
  -> ArchiMateNotationIssueKind
  -> Map ModelIdentity [DraftLocation]
  -> DraftLocation
  -> Raw.IdentityOutcome
  -> [ArchiMateNotationIssue]
identityOutcomeIssues missing multiple invalid grammar duplicate duplicates subject outcome =
  case outcome of
    Raw.IdentityMissing -> [occurrenceIssue missing subject]
    Raw.IdentityMultiple values -> [scalarIssue multiple subject values]
    Raw.IdentityInvalid scalar reason ->
      [ scalarIssue
          (case reason of
             Raw.IdentityValueIsNotText _ -> invalid
             Raw.IdentityValueIsEmpty -> grammar
             Raw.IdentityValueContainsU0000 -> grammar
             Raw.IdentityValueContainsSurrogate -> grammar)
          subject
          [scalar]
      ]
    Raw.IdentityResolved _ identifier ->
      case Map.findWithDefault [] identifier duplicates of
        _:_:_ ->
          [ referenceIssue
              duplicate
              subject
              (modelIdentityText identifier)
              (Map.findWithDefault [] identifier duplicates)
          ]
        _ -> []

viewNameIssues :: Raw.CanonicalRecord -> [ArchiMateNotationIssue]
viewNameIssues record =
  case nameFields of
    [] -> [occurrenceIssue kindMissing subject]
    [_first, _second] -> [scalarIssue kindMultiple subject scalars]
    _:_:_ -> [scalarIssue kindMultiple subject scalars]
    [field] ->
      case Raw.canonicalFieldScalarsValue field of
        [] -> [occurrenceIssue kindMissing subject]
        [_first, _second] -> [scalarIssue kindMultiple subject scalars]
        _:_:_ -> [scalarIssue kindMultiple subject scalars]
        [scalar]
          | draftScalarKindValue scalar /= DraftText ->
            [scalarIssue kindInvalid subject [scalar]]
          | otherwise -> []
  where
    subject = Raw.canonicalRecordLocationValue record
    nameFields =
      filter
        ((== NameField) . Raw.canonicalFieldValue)
        (Raw.canonicalRecordFieldsValue record)
    scalars = concatMap Raw.canonicalFieldScalarsValue nameFields
    kindMissing = ViewInventoryNotationKind ViewNameMissing
    kindMultiple = ViewInventoryNotationKind ViewNameMultiplicity
    kindInvalid = ViewInventoryNotationKind ViewNameValueKindInvalid

selectedReferenceIssues :: Raw.CanonicalReference -> [ArchiMateNotationIssue]
selectedReferenceIssues reference =
  case Raw.canonicalReferenceOutcomeValue reference of
    Raw.ReferenceIdentityInvalid outcome ->
      referenceIdentityIssues
        ReferenceIdentityMissing
        ReferenceIdentityMultiplicity
        ReferenceIdentityValueKindInvalid
        ReferenceIdentityGrammarInvalid
        subject
        outcome
    Raw.ReferenceTargetMissing scalar _ ->
      [referenceScalarIssue ReferenceTargetMissing scalar []]
    Raw.ReferenceTargetWrongFamily scalar _ _ targets ->
      [ referenceScalarIssue
          ReferenceTargetWrongFamily
          scalar
          (map Raw.canonicalTargetLocationValue targets)
      ]
    Raw.ReferenceExpectedFamilyAmbiguous scalar _ _ targets ->
      [ referenceScalarIssue
          ReferenceTargetAmbiguous
          scalar
          (map Raw.canonicalTargetLocationValue targets)
      ]
    Raw.ReferenceResolved {} -> []
  where
    subject = Raw.canonicalReferenceLocationValue reference
    referenceScalarIssue kind scalar targets =
      referenceIssue
        (SelectedUniverseNotationKind kind)
        subject
        (draftScalarTextValue scalar)
        targets

referenceIdentityIssues ::
     SelectedUniverseIssueKind
  -> SelectedUniverseIssueKind
  -> SelectedUniverseIssueKind
  -> SelectedUniverseIssueKind
  -> DraftLocation
  -> Raw.IdentityOutcome
  -> [ArchiMateNotationIssue]
referenceIdentityIssues missing multiple invalid grammar subject outcome =
  case outcome of
    Raw.IdentityMissing -> [issue missing (occurrenceEvidence subject)]
    Raw.IdentityMultiple values ->
      [issue multiple (scalarEvidenceOrSubject subject values)]
    Raw.IdentityInvalid scalar reason ->
      [ issue
          (case reason of
             Raw.IdentityValueIsNotText _ -> invalid
             Raw.IdentityValueIsEmpty -> grammar
             Raw.IdentityValueContainsU0000 -> grammar
             Raw.IdentityValueContainsSurrogate -> grammar)
          (scalarEvidenceOrSubject subject [scalar])
      ]
    Raw.IdentityResolved {} -> []
  where
    issue kind evidence =
      ArchiMateNotationIssue
        (SelectedUniverseNotationKind kind)
        subject
        evidence

markerCandidateIssues :: Raw.MarkerCandidate -> [ArchiMateNotationIssue]
markerCandidateIssues candidate =
  case Raw.canonicalPropertyKeyEvidenceValue property of
    Raw.CanonicalDirectPropertyKey _ ->
      markerKeyIssues
        MarkerKeyMissing
        MarkerKeyMultiplicity
        MarkerKeyValueKindInvalid
        subject
        (Raw.markerCandidateKeyOutcomeValue candidate)
    Raw.CanonicalReferencedPropertyKey reference ->
      case Raw.canonicalReferenceOutcomeValue reference of
        Raw.ReferenceIdentityInvalid outcome ->
          markerReferenceIdentityIssues subject outcome
        Raw.ReferenceTargetMissing scalar _ ->
          [markerReferenceIssue MarkerReferenceTargetMissing scalar []]
        Raw.ReferenceTargetWrongFamily scalar _ _ targets ->
          [ markerReferenceIssue
              MarkerReferenceTargetWrongFamily
              scalar
              (map Raw.canonicalTargetLocationValue targets)
          ]
        Raw.ReferenceExpectedFamilyAmbiguous scalar _ _ targets ->
          [ markerReferenceIssue
              MarkerReferenceTargetAmbiguous
              scalar
              (map Raw.canonicalTargetLocationValue targets)
          ]
        Raw.ReferenceResolved {} ->
          markerKeyIssues
            MarkerDefinitionNameMissing
            MarkerDefinitionNameMultiplicity
            MarkerDefinitionNameValueKindInvalid
            subject
            (Raw.markerCandidateKeyOutcomeValue candidate)
  where
    property = Raw.markerCandidatePropertyValue candidate
    subject = Raw.canonicalPropertyLocationValue property
    markerReferenceIssue kind scalar targets =
      referenceIssue
        (ProfileMarkerNotationKind kind)
        subject
        (draftScalarTextValue scalar)
        targets

markerKeyIssues ::
     ProfileMarkerIssueKind
  -> ProfileMarkerIssueKind
  -> ProfileMarkerIssueKind
  -> DraftLocation
  -> Raw.MarkerKeyOutcome
  -> [ArchiMateNotationIssue]
markerKeyIssues missing multiple invalid subject outcome =
  case outcome of
    Raw.MarkerKeyMissing -> [markerOccurrenceIssue missing]
    Raw.MarkerKeyMultiple values -> [markerScalarIssue multiple values]
    Raw.MarkerKeyNonText scalar -> [markerScalarIssue invalid [scalar]]
    Raw.MarkerKeyExact {} -> []
    Raw.MarkerKeyOther {} -> []
    Raw.MarkerKeyReferenceRejected {} -> []
  where
    markerOccurrenceIssue kind =
      occurrenceIssue (ProfileMarkerNotationKind kind) subject
    markerScalarIssue kind =
      scalarIssue (ProfileMarkerNotationKind kind) subject

markerReferenceIdentityIssues ::
     DraftLocation -> Raw.IdentityOutcome -> [ArchiMateNotationIssue]
markerReferenceIdentityIssues subject outcome =
  case outcome of
    Raw.IdentityMissing ->
      [markerOccurrenceIssue MarkerReferenceIdentityMissing]
    Raw.IdentityMultiple values ->
      [markerScalarIssue MarkerReferenceIdentityMultiplicity values]
    Raw.IdentityInvalid scalar reason ->
      [ markerScalarIssue
          (case reason of
             Raw.IdentityValueIsNotText _ ->
               MarkerReferenceIdentityValueKindInvalid
             Raw.IdentityValueIsEmpty -> MarkerReferenceIdentityGrammarInvalid
             Raw.IdentityValueContainsU0000 ->
               MarkerReferenceIdentityGrammarInvalid
             Raw.IdentityValueContainsSurrogate ->
               MarkerReferenceIdentityGrammarInvalid)
          [scalar]
      ]
    Raw.IdentityResolved {} -> []
  where
    markerOccurrenceIssue kind =
      occurrenceIssue (ProfileMarkerNotationKind kind) subject
    markerScalarIssue kind =
      scalarIssue (ProfileMarkerNotationKind kind) subject

duplicateIdentityLocations ::
     [Raw.CanonicalRecord] -> Map ModelIdentity [DraftLocation]
duplicateIdentityLocations = Map.fromListWith (flip (<>)) . foldr collect []
  where
    collect record values =
      case Raw.canonicalRecordIdentityValue record of
        Raw.IdentityResolved _ identifier ->
          (identifier, [Raw.canonicalRecordLocationValue record]) : values
        _ -> values

occurrenceIssue ::
     ArchiMateNotationIssueKind -> DraftLocation -> ArchiMateNotationIssue
occurrenceIssue kind subject =
  ArchiMateNotationIssue kind subject (occurrenceEvidence subject)

scalarIssue ::
     ArchiMateNotationIssueKind
  -> DraftLocation
  -> [DraftScalar]
  -> ArchiMateNotationIssue
scalarIssue kind subject scalars =
  ArchiMateNotationIssue kind subject (scalarEvidenceOrSubject subject scalars)

referenceIssue ::
     ArchiMateNotationIssueKind
  -> DraftLocation
  -> Text
  -> [DraftLocation]
  -> ArchiMateNotationIssue
referenceIssue kind subject value targets =
  ArchiMateNotationIssue
    kind
    subject
    (NotationReferenceEvidence subject value targets :| [])

occurrenceEvidence :: DraftLocation -> NonEmpty ArchiMateNotationEvidence
occurrenceEvidence subject = NotationOccurrenceEvidence subject :| []

scalarEvidenceOrSubject ::
     DraftLocation -> [DraftScalar] -> NonEmpty ArchiMateNotationEvidence
scalarEvidenceOrSubject subject values =
  case NonEmpty.nonEmpty (map scalarNotationEvidence values) of
    Just evidence -> evidence
    Nothing -> occurrenceEvidence subject

scalarNotationEvidence :: DraftScalar -> ArchiMateNotationEvidence
scalarNotationEvidence scalar =
  NotationValueEvidence
    (draftScalarLocationValue scalar)
    (draftScalarKindValue scalar)
    (draftScalarTextValue scalar)

canonicalOrder :: [ArchiMateNotationIssue] -> [ArchiMateNotationIssue]
canonicalOrder = sortOn issueOrder

issueOrder ::
     ArchiMateNotationIssue
  -> (ArchiMateNotationIssueKind, DraftLocation, [ArchiMateNotationEvidence])
issueOrder issue =
  ( archiMateNotationIssueKindValue issue
  , archiMateNotationIssueSubjectValue issue
  , NonEmpty.toList (archiMateNotationIssueEvidenceValue issue))
