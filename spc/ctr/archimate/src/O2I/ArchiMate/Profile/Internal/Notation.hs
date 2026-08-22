{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.Notation where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Internal.Draft
import O2I.Core.Identity (ModelIdentity, ModelIdentityDefect(..), modelIdentity)

-- | Closed kinds of retained canonical notation occurrences.
data CanonicalOccurrenceKind
  = CanonicalRecordOccurrence
  | CanonicalPropertyOccurrence
  | CanonicalReferenceOccurrence
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Stable occurrence identity within one canonicalized native document.
data CanonicalOccurrence = CanonicalOccurrence
  { canonicalOccurrenceKindValue :: !CanonicalOccurrenceKind
  , canonicalOccurrenceOrdinalValue :: !Natural
  } deriving (Eq, Ord, Show)

-- | Closed reasons why a present native identity cannot be canonicalized.
data IdentityInvalidReason
  = IdentityValueIsNotText !DraftValueKind
  | IdentityValueIsEmpty
  | IdentityValueContainsU0000
  | IdentityValueContainsSurrogate
  deriving (Eq, Ord, Show)

-- | Complete canonicalization outcome for one native identity field.
data IdentityOutcome
  = IdentityMissing
  | IdentityMultiple ![DraftScalar]
  | IdentityInvalid !DraftScalar !IdentityInvalidReason
  | IdentityResolved !DraftScalar !ModelIdentity
  deriving (Eq, Show)

-- | One recognized scalar field retained in canonical notation order.
data CanonicalField = CanonicalField
  { canonicalFieldValue :: !DraftFieldValue
  , canonicalFieldScalarsValue :: ![DraftScalar]
  , canonicalFieldLocationValue :: !DraftLocation
  } deriving (Eq, Show)

-- | One identity-resolved record eligible as a reference target.
data CanonicalTarget = CanonicalTarget
  { canonicalTargetOccurrenceValue :: !CanonicalOccurrence
  , canonicalTargetFamilyValue :: !DraftRecordFamilyValue
  , canonicalTargetIdentityValue :: !ModelIdentity
  , canonicalTargetLocationValue :: !DraftLocation
  , canonicalTargetFieldsValue :: ![CanonicalField]
  } deriving (Eq, Show)

-- | Complete resolution outcome for one native reference.
data ReferenceOutcome
  = ReferenceIdentityInvalid !IdentityOutcome
  | ReferenceTargetMissing !DraftScalar !ModelIdentity
  | ReferenceTargetWrongFamily
      !DraftScalar
      !ModelIdentity
      !DraftRecordFamilyValue
      ![CanonicalTarget]
  | ReferenceExpectedFamilyAmbiguous
      !DraftScalar
      !ModelIdentity
      !DraftRecordFamilyValue
      ![CanonicalTarget]
  | ReferenceResolved !DraftScalar !ModelIdentity !CanonicalTarget
  deriving (Eq, Show)

-- | One canonical native reference and its identity-resolution outcome.
data CanonicalReference = CanonicalReference
  { canonicalReferenceOccurrenceValue :: !CanonicalOccurrence
  , canonicalReferenceOwnerValue :: !CanonicalOccurrence
  , canonicalReferenceFieldValue :: !DraftReferenceFieldValue
  , canonicalReferenceExpectedFamilyValue :: !DraftRecordFamilyValue
  , canonicalReferenceLocationValue :: !DraftLocation
  , canonicalReferenceOutcomeValue :: !ReferenceOutcome
  } deriving (Eq, Show)

-- | One canonical record retaining its existential Draft-family witness.
data CanonicalRecord = forall recordRole. CanonicalRecord
                                            { canonicalRecordOccurrenceValue :: !CanonicalOccurrence
                                            , canonicalRecordParentValue :: !(Maybe
                                                                                CanonicalOccurrence)
                                            , canonicalRecordFamilyValue :: !DraftRecordFamilyValue
                                            , canonicalRecordIdentityValue :: !IdentityOutcome
                                            , canonicalRecordLocationValue :: !DraftLocation
                                            , canonicalRecordFieldsValue :: ![CanonicalField]
                                            , canonicalRecordDraftValue :: !(DraftRecord
                                                                               recordRole)
                                            }

instance Show CanonicalRecord where
  show record =
    "CanonicalRecord "
      <> show (canonicalRecordOccurrenceValue record)
      <> " "
      <> show (canonicalRecordFamilyValue record)
      <> " "
      <> show (canonicalRecordIdentityValue record)

data CanonicalPropertyKeyEvidence
  = CanonicalDirectPropertyKey ![DraftScalar]
  | CanonicalReferencedPropertyKey !CanonicalReference
  deriving (Eq, Show)

-- | One canonical property retaining key, values, and opaque evidence.
data CanonicalProperty = CanonicalProperty
  { canonicalPropertyOccurrenceValue :: !CanonicalOccurrence
  , canonicalPropertyOwnerValue :: !CanonicalOccurrence
  , canonicalPropertyOwnerFamilyValue :: !DraftRecordFamilyValue
  , canonicalPropertyLocationValue :: !DraftLocation
  , canonicalPropertyValuesValue :: ![DraftScalar]
  , canonicalPropertyOpaqueEvidenceValue :: ![DraftOpaqueEvidence]
  , canonicalPropertyKeyEvidenceValue :: !CanonicalPropertyKeyEvidence
  } deriving (Show)

-- | Complete canonical notation document derived losslessly from a Draft.
data CanonicalDocument = CanonicalDocument
  { canonicalDocumentDraftValue :: !ProfileDraft
  , canonicalDocumentRecordsValue :: ![CanonicalRecord]
  , canonicalDocumentPropertiesValue :: ![CanonicalProperty]
  , canonicalDocumentReferencesValue :: ![CanonicalReference]
  }

-- | Sole canonical record domain for global identity uniqueness and indexing.
canonicalIdentityDomainValue :: CanonicalDocument -> [CanonicalRecord]
canonicalIdentityDomainValue = canonicalDocumentRecordsValue

-- | One identity outcome with its record family and source location.
data IdentityObservation = IdentityObservation
  { identityObservationOccurrenceValue :: !CanonicalOccurrence
  , identityObservationFamilyValue :: !DraftRecordFamilyValue
  , identityObservationOutcomeValue :: !IdentityOutcome
  , identityObservationLocationValue :: !DraftLocation
  } deriving (Eq, Show)

-- | Identity and reference observations produced by notation assessment.
data NotationAssessment = NotationAssessment
  { notationIdentityObservationsValue :: ![IdentityObservation]
  , notationReferenceObservationsValue :: ![CanonicalReference]
  }

-- | Canonical identity, name, and location evidence for one View record.
data ViewDescriptor = ViewDescriptor
  { viewDescriptorDocumentValue :: !CanonicalDocument
  , viewDescriptorOccurrenceValue :: !CanonicalOccurrence
  , viewDescriptorIdentityValue :: !IdentityOutcome
  , viewDescriptorNameFieldsValue :: ![CanonicalField]
  , viewDescriptorLocationValue :: !DraftLocation
  }

instance Show ViewDescriptor where
  show descriptor =
    "ViewDescriptor "
      <> show (viewDescriptorOccurrenceValue descriptor)
      <> " "
      <> show (viewDescriptorIdentityValue descriptor)

-- | Complete recognition outcome for one candidate marker-property key.
data MarkerKeyOutcome
  = MarkerKeyMissing
  | MarkerKeyMultiple ![DraftScalar]
  | MarkerKeyNonText !DraftScalar
  | MarkerKeyExact !DraftScalar
  | MarkerKeyOther !DraftScalar
  | MarkerKeyReferenceRejected !CanonicalReference
  deriving (Show)

-- | One property considered while resolving the exact Profile marker.
data MarkerCandidate = MarkerCandidate
  { markerCandidatePropertyValue :: !CanonicalProperty
  , markerCandidateDefinitionFieldsValue :: ![CanonicalField]
  , markerCandidateKeyOutcomeValue :: !MarkerKeyOutcome
  }

instance Show MarkerCandidate where
  show candidate =
    "MarkerCandidate "
      <> show
           (canonicalPropertyOccurrenceValue
              (markerCandidatePropertyValue candidate))
      <> " "
      <> show (markerCandidateKeyOutcomeValue candidate)

-- | Exact acceptance or rejection of the document-level Profile marker.
data MarkerEvidenceAssessment
  = MarkerEvidenceRejected ![MarkerCandidate]
  | MarkerEvidenceAccepted ![MarkerCandidate] ![CanonicalProperty]

data PendingEvidence where
  PendingProperty
    :: CanonicalOccurrence
    -> DraftRecordFamilyValue
    -> CanonicalOccurrence
    -> DraftProperty ownerRole
    -> PendingEvidence
  PendingReference
    :: CanonicalOccurrence
    -> DraftRecordFamilyValue
    -> DraftReference ownerRole targetRole
    -> PendingEvidence

data Traversal = Traversal
  { traversalNextRecord :: !Natural
  , traversalNextProperty :: !Natural
  , traversalRecordsReversed :: ![CanonicalRecord]
  , traversalEvidenceReversed :: ![PendingEvidence]
  }

data EvidenceBuild = EvidenceBuild
  { evidenceNextReference :: !Natural
  , evidencePropertiesReversed :: ![CanonicalProperty]
  , evidenceReferencesReversed :: ![CanonicalReference]
  }

buildCanonicalDocument :: ProfileDraft -> CanonicalDocument
buildCanonicalDocument draft =
  CanonicalDocument
    { canonicalDocumentDraftValue = draft
    , canonicalDocumentRecordsValue = records
    , canonicalDocumentPropertiesValue =
        reverse (evidencePropertiesReversed evidenceBuild)
    , canonicalDocumentReferencesValue =
        reverse (evidenceReferencesReversed evidenceBuild)
    }
  where
    traversed =
      traverseRecord Nothing initialTraversal (profileDraftRootValue draft)
    records = reverse (traversalRecordsReversed traversed)
    pending = reverse (traversalEvidenceReversed traversed)
    targets = targetIndex records
    evidenceBuild = foldl' (buildEvidence targets) initialEvidenceBuild pending
    initialTraversal = Traversal 0 0 [] []
    initialEvidenceBuild = EvidenceBuild 0 [] []

traverseRecord ::
     Maybe CanonicalOccurrence
  -> Traversal
  -> DraftRecord recordRole
  -> Traversal
traverseRecord parent state record =
  foldl' (traverseMember owner family) entered members
  where
    ordinal = traversalNextRecord state
    owner = CanonicalOccurrence CanonicalRecordOccurrence ordinal
    family = recordFamilyValue (draftRecordFamilyValue record)
    members = draftRecordMembersValue record
    canonical =
      CanonicalRecord
        { canonicalRecordOccurrenceValue = owner
        , canonicalRecordParentValue = parent
        , canonicalRecordFamilyValue = family
        , canonicalRecordIdentityValue =
            assessIdentity (draftRecordIdentityValue record)
        , canonicalRecordLocationValue = draftRecordLocationValue record
        , canonicalRecordFieldsValue = fieldsFromMembers members
        , canonicalRecordDraftValue = record
        }
    entered =
      state
        { traversalNextRecord = ordinal + 1
        , traversalRecordsReversed = canonical : traversalRecordsReversed state
        }

traverseMember ::
     CanonicalOccurrence
  -> DraftRecordFamilyValue
  -> Traversal
  -> DraftMember recordRole
  -> Traversal
traverseMember owner family state member =
  case member of
    DraftPropertyMember property ->
      let ordinal = traversalNextProperty state
          occurrence = CanonicalOccurrence CanonicalPropertyOccurrence ordinal
       in state
            { traversalNextProperty = ordinal + 1
            , traversalEvidenceReversed =
                PendingProperty owner family occurrence property
                  : traversalEvidenceReversed state
            }
    DraftReferenceMember (SomeDraftReference reference) ->
      state
        { traversalEvidenceReversed =
            PendingReference owner family reference
              : traversalEvidenceReversed state
        }
    DraftChildRecord (SomeDraftRecord child) ->
      traverseRecord (Just owner) state child
    DraftFieldMember _ _ _ -> state
    DraftOpaqueMember _ -> state

fieldsFromMembers :: [DraftMember recordRole] -> [CanonicalField]
fieldsFromMembers = foldr collect []
  where
    collect member fields =
      case member of
        DraftFieldMember field scalars location ->
          CanonicalField (fieldValue field) scalars location : fields
        _ -> fields

assessIdentity :: DraftIdentity recordRole -> IdentityOutcome
assessIdentity identityValue =
  case draftIdentityValuesValue identityValue of
    [] -> IdentityMissing
    values@(_:_:_) -> IdentityMultiple values
    [scalar]
      | draftScalarKindValue scalar /= DraftText ->
        IdentityInvalid
          scalar
          (IdentityValueIsNotText (draftScalarKindValue scalar))
      | otherwise ->
        case modelIdentity (draftScalarTextValue scalar) of
          Left defect -> IdentityInvalid scalar (identityReason defect)
          Right identifier -> IdentityResolved scalar identifier

identityReason :: ModelIdentityDefect -> IdentityInvalidReason
identityReason defect =
  case defect of
    EmptyModelIdentity -> IdentityValueIsEmpty
    ModelIdentityContainsU0000 -> IdentityValueContainsU0000
    ModelIdentityContainsSurrogate -> IdentityValueContainsSurrogate

data TargetBucket = TargetBucket
  { targetBucketAll :: ![CanonicalTarget]
  , targetBucketByFamily :: !(Map DraftRecordFamilyValue [CanonicalTarget])
  }

targetIndex :: [CanonicalRecord] -> Map ModelIdentity TargetBucket
targetIndex = Map.map restoreOrder . foldl' addTarget Map.empty
  where
    addTarget index record =
      case canonicalRecordIdentityValue record of
        IdentityResolved _ identifier ->
          Map.alter
            (Just . addToBucket (recordTarget identifier record))
            identifier
            index
        _ -> index
    addToBucket target Nothing =
      TargetBucket
        [target]
        (Map.singleton (canonicalTargetFamilyValue target) [target])
    addToBucket target (Just bucket) =
      bucket
        { targetBucketAll = target : targetBucketAll bucket
        , targetBucketByFamily =
            Map.insertWith
              (++)
              (canonicalTargetFamilyValue target)
              [target]
              (targetBucketByFamily bucket)
        }
    restoreOrder bucket =
      bucket
        { targetBucketAll = reverse (targetBucketAll bucket)
        , targetBucketByFamily = Map.map reverse (targetBucketByFamily bucket)
        }

recordTarget :: ModelIdentity -> CanonicalRecord -> CanonicalTarget
recordTarget identifier record =
  CanonicalTarget
    { canonicalTargetOccurrenceValue = canonicalRecordOccurrenceValue record
    , canonicalTargetFamilyValue = canonicalRecordFamilyValue record
    , canonicalTargetIdentityValue = identifier
    , canonicalTargetLocationValue = canonicalRecordLocationValue record
    , canonicalTargetFieldsValue = canonicalRecordFieldsValue record
    }

buildEvidence ::
     Map ModelIdentity TargetBucket
  -> EvidenceBuild
  -> PendingEvidence
  -> EvidenceBuild
buildEvidence targets state pending =
  case pending of
    PendingReference owner _ reference ->
      let (stateValue, canonical) = buildReference targets owner state reference
       in stateValue
            { evidenceReferencesReversed =
                canonical : evidenceReferencesReversed stateValue
            }
    PendingProperty owner family occurrence property ->
      case draftPropertyKeyValue property of
        DraftDirectPropertyKey keyScalars ->
          state
            { evidencePropertiesReversed =
                CanonicalProperty
                  occurrence
                  owner
                  family
                  (draftPropertyLocationValue property)
                  (draftPropertyValuesValue property)
                  (draftPropertyOpaqueEvidenceValue property)
                  (CanonicalDirectPropertyKey keyScalars)
                  : evidencePropertiesReversed state
            }
        DraftPropertyDefinitionKey reference ->
          let (stateValue, canonical) =
                buildReference targets owner state reference
              propertyValue =
                CanonicalProperty
                  occurrence
                  owner
                  family
                  (draftPropertyLocationValue property)
                  (draftPropertyValuesValue property)
                  (draftPropertyOpaqueEvidenceValue property)
                  (CanonicalReferencedPropertyKey canonical)
           in stateValue
                { evidencePropertiesReversed =
                    propertyValue : evidencePropertiesReversed stateValue
                , evidenceReferencesReversed =
                    canonical : evidenceReferencesReversed stateValue
                }

buildReference ::
     Map ModelIdentity TargetBucket
  -> CanonicalOccurrence
  -> EvidenceBuild
  -> DraftReference ownerRole targetRole
  -> (EvidenceBuild, CanonicalReference)
buildReference targets owner state reference =
  ( state {evidenceNextReference = ordinal + 1}
  , CanonicalReference
      { canonicalReferenceOccurrenceValue = occurrence
      , canonicalReferenceOwnerValue = owner
      , canonicalReferenceFieldValue =
          referenceFieldValue (draftReferenceFieldValue reference)
      , canonicalReferenceExpectedFamilyValue = expected
      , canonicalReferenceLocationValue = draftReferenceLocationValue reference
      , canonicalReferenceOutcomeValue =
          resolveReference
            targets
            expected
            (draftReferenceIdentityValue reference)
      })
  where
    ordinal = evidenceNextReference state
    occurrence = CanonicalOccurrence CanonicalReferenceOccurrence ordinal
    expected =
      recordFamilyValue
        (referenceExpectedFamily (draftReferenceFieldValue reference))

resolveReference ::
     Map ModelIdentity TargetBucket
  -> DraftRecordFamilyValue
  -> DraftIdentity targetRole
  -> ReferenceOutcome
resolveReference targets expected identityValue =
  case assessIdentity identityValue of
    IdentityResolved scalar identifier ->
      resolveTarget scalar identifier (Map.lookup identifier targets)
    invalid -> ReferenceIdentityInvalid invalid
  where
    resolveTarget scalar identifier maybeBucket =
      case maybeBucket of
        Nothing -> ReferenceTargetMissing scalar identifier
        Just bucket ->
          resolveExpected
            scalar
            identifier
            bucket
            (Map.findWithDefault [] expected (targetBucketByFamily bucket))
    resolveExpected scalar identifier bucket expectedTargets =
      case expectedTargets of
        [] ->
          ReferenceTargetWrongFamily
            scalar
            identifier
            expected
            (targetBucketAll bucket)
        [target] -> ReferenceResolved scalar identifier target
        targetsForFamily ->
          ReferenceExpectedFamilyAmbiguous
            scalar
            identifier
            expected
            targetsForFamily

assessNotationValue :: CanonicalDocument -> NotationAssessment
assessNotationValue document =
  NotationAssessment
    { notationIdentityObservationsValue =
        map identityObservation (canonicalDocumentRecordsValue document)
    , notationReferenceObservationsValue =
        canonicalDocumentReferencesValue document
    }

identityObservation :: CanonicalRecord -> IdentityObservation
identityObservation record =
  IdentityObservation
    { identityObservationOccurrenceValue = canonicalRecordOccurrenceValue record
    , identityObservationFamilyValue = canonicalRecordFamilyValue record
    , identityObservationOutcomeValue = canonicalRecordIdentityValue record
    , identityObservationLocationValue = canonicalRecordLocationValue record
    }

viewInventoryValue :: CanonicalDocument -> [ViewDescriptor]
viewInventoryValue document =
  foldr collect [] (canonicalDocumentRecordsValue document)
  where
    collect record views
      | canonicalRecordFamilyValue record == ViewFamily =
        ViewDescriptor
          { viewDescriptorDocumentValue = document
          , viewDescriptorOccurrenceValue =
              canonicalRecordOccurrenceValue record
          , viewDescriptorIdentityValue = canonicalRecordIdentityValue record
          , viewDescriptorNameFieldsValue =
              filter
                ((== NameField) . canonicalFieldValue)
                (canonicalRecordFieldsValue record)
          , viewDescriptorLocationValue = canonicalRecordLocationValue record
          }
          : views
      | otherwise = views

assessMarkerEvidenceValue :: CanonicalDocument -> MarkerEvidenceAssessment
assessMarkerEvidenceValue document
  | any markerCandidateRejected candidates = MarkerEvidenceRejected candidates
  | otherwise = MarkerEvidenceAccepted candidates markerProperties
  where
    rootProperties =
      filter
        isDistinguishedRootProperty
        (canonicalDocumentPropertiesValue document)
    candidates = map markerCandidate rootProperties
    markerProperties =
      [ markerCandidatePropertyValue candidate
      | candidate <- candidates
      , markerCandidateIsMarker candidate
      ]
    isDistinguishedRootProperty property =
      canonicalPropertyOwnerFamilyValue property == ModelRootFamily
        && canonicalPropertyOwnerValue property
             == CanonicalOccurrence CanonicalRecordOccurrence 0

markerCandidate :: CanonicalProperty -> MarkerCandidate
markerCandidate property =
  case canonicalPropertyKeyEvidenceValue property of
    CanonicalDirectPropertyKey scalars ->
      MarkerCandidate property [] (assessMarkerKey scalars)
    CanonicalReferencedPropertyKey reference ->
      case canonicalReferenceOutcomeValue reference of
        ReferenceResolved _ _ target ->
          let nameFields =
                filter
                  ((== NameField) . canonicalFieldValue)
                  (canonicalTargetFieldsValue target)
           in MarkerCandidate
                property
                nameFields
                (assessDefinitionMarkerKey nameFields)
        _ -> MarkerCandidate property [] (MarkerKeyReferenceRejected reference)

assessDefinitionMarkerKey :: [CanonicalField] -> MarkerKeyOutcome
assessDefinitionMarkerKey fields =
  case fields of
    [] -> MarkerKeyMissing
    [field] -> assessMarkerKey (canonicalFieldScalarsValue field)
    _ -> MarkerKeyMultiple (concatMap canonicalFieldScalarsValue fields)

assessMarkerKey :: [DraftScalar] -> MarkerKeyOutcome
assessMarkerKey scalars =
  case scalars of
    [] -> MarkerKeyMissing
    values@(_:_:_) -> MarkerKeyMultiple values
    [scalar]
      | draftScalarKindValue scalar /= DraftText -> MarkerKeyNonText scalar
      | draftScalarTextValue scalar == "o2i.profile" -> MarkerKeyExact scalar
      | otherwise -> MarkerKeyOther scalar

markerCandidateRejected :: MarkerCandidate -> Bool
markerCandidateRejected candidate =
  case markerCandidateKeyOutcomeValue candidate of
    MarkerKeyExact _ -> False
    MarkerKeyOther _ -> False
    MarkerKeyMissing -> True
    MarkerKeyMultiple _ -> True
    MarkerKeyNonText _ -> True
    MarkerKeyReferenceRejected _ -> True

markerCandidateIsMarker :: MarkerCandidate -> Bool
markerCandidateIsMarker candidate =
  case markerCandidateKeyOutcomeValue candidate of
    MarkerKeyExact _ -> True
    MarkerKeyMissing -> False
    MarkerKeyMultiple _ -> False
    MarkerKeyNonText _ -> False
    MarkerKeyOther _ -> False
    MarkerKeyReferenceRejected _ -> False
