{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.Index
  ( ProfileIndex
  , RecordInfo
  , recordInfoOccurrence
  , recordInfoParent
  , recordInfoFamily
  , recordInfoIdentity
  , recordInfoLocation
  , recordInfoFields
  , recordInfoTypeValues
  , recordInfoNameValues
  , recordInfoDirectedValues
  , PropertyInfo
  , propertyInfoOccurrence
  , propertyInfoOwner
  , propertyInfoOwnerFamily
  , propertyInfoLocation
  , propertyInfoRawValues
  , propertyInfoOpaqueEvidence
  , propertyInfoKeys
  , propertyInfoValues
  , propertyInfoDefinition
  , RelationshipInfo
  , relationshipInfoRecord
  , relationshipInfoOccurrence
  , relationshipInfoKind
  , relationshipInfoDirected
  , relationshipInfoLabel
  , relationshipInfoSource
  , relationshipInfoTarget
  , buildProfileIndex
  , indexRecords
  , indexChildrenByParent
  , indexReferencesByOwnerAndField
  , indexPropertiesByOwner
  , indexPropertiesByOwnerAndKey
  , indexPropertyByOccurrence
  , indexRelationships
  , indexRelationshipsBySource
  , indexRelationshipsByTarget
  , indexModelRoots
  , lookupRecord
  , resolvedReferenceOccurrence
  , isRelationship
  , isConcept
  , isJunction
  , isAndJunction
  , archiMateElement
  , propertiesFor
  , propertiesForKey
  , hasProperty
  , propertyValues
  , roleValues
  , incidentRelationships
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Draft
import O2I.ArchiMate.Profile.Internal.Notation

data RecordInfo = RecordInfo
  { recordInfoOccurrence :: !CanonicalOccurrence
  , recordInfoParent :: !(Maybe CanonicalOccurrence)
  , recordInfoFamily :: !DraftRecordFamilyValue
  , recordInfoIdentity :: !IdentityOutcome
  , recordInfoLocation :: !DraftLocation
  , recordInfoFields :: ![CanonicalField]
  , recordInfoTypeValues :: ![Text]
  , recordInfoNameValues :: ![Text]
  , recordInfoDirectedValues :: ![Bool]
  }

data PropertyInfo = PropertyInfo
  { propertyInfoOccurrence :: !CanonicalOccurrence
  , propertyInfoOwner :: !CanonicalOccurrence
  , propertyInfoOwnerFamily :: !DraftRecordFamilyValue
  , propertyInfoLocation :: !DraftLocation
  , propertyInfoRawValues :: ![DraftScalar]
  , propertyInfoOpaqueEvidence :: ![DraftOpaqueEvidence]
  , propertyInfoKeys :: ![Text]
  , propertyInfoValues :: ![Text]
  , propertyInfoDefinition :: !(Maybe CanonicalOccurrence)
  }

data RelationshipInfo = RelationshipInfo
  { relationshipInfoRecord :: !RecordInfo
  , relationshipInfoOccurrence :: !CanonicalOccurrence
  , relationshipInfoKind :: !Text
  , relationshipInfoDirected :: !Bool
  , relationshipInfoLabel :: !Text
  , relationshipInfoSource :: !(Maybe CanonicalOccurrence)
  , relationshipInfoTarget :: !(Maybe CanonicalOccurrence)
  }

data ProfileIndex = ProfileIndex
  { indexRecords :: !(Map CanonicalOccurrence RecordInfo)
  , indexChildrenByParent :: !(Map CanonicalOccurrence [RecordInfo])
  , indexReferencesByOwnerAndField :: !(Map
                                          ( CanonicalOccurrence
                                          , DraftReferenceFieldValue)
                                          [CanonicalReference])
  , indexPropertiesByOwner :: !(Map CanonicalOccurrence [PropertyInfo])
  , indexPropertiesByOwnerAndKey :: !(Map
                                        (CanonicalOccurrence, Text)
                                        [PropertyInfo])
  , indexPropertyByOccurrence :: !(Map CanonicalOccurrence PropertyInfo)
  , indexRelationships :: !(Map CanonicalOccurrence RelationshipInfo)
  , indexRelationshipsBySource :: !(Map CanonicalOccurrence [RelationshipInfo])
  , indexRelationshipsByTarget :: !(Map CanonicalOccurrence [RelationshipInfo])
  , indexModelRoots :: !(Set CanonicalOccurrence)
  }

buildProfileIndex :: CanonicalDocument -> ProfileIndex
buildProfileIndex document =
  ProfileIndex
    { indexRecords = records
    , indexChildrenByParent =
        groupedBy recordInfoParentValue recordInfoOccurrence recordInfos
    , indexReferencesByOwnerAndField =
        groupedBy
          (Just . referenceOwnerAndField)
          canonicalReferenceOccurrenceValue
          references
    , indexPropertiesByOwner =
        groupedBy (Just . propertyInfoOwner) propertyInfoOccurrence properties
    , indexPropertiesByOwnerAndKey = propertiesByOwnerAndKey properties
    , indexPropertyByOccurrence =
        Map.fromList
          [(propertyInfoOccurrence property, property) | property <- properties]
    , indexRelationships = relationships
    , indexRelationshipsBySource =
        relationshipIncidence relationshipInfoSource relationships
    , indexRelationshipsByTarget =
        relationshipIncidence relationshipInfoTarget relationships
    , indexModelRoots =
        Set.fromList
          [ recordInfoOccurrence record
          | record <- Map.elems records
          , recordInfoFamily record == ModelRootFamily
          ]
    }
  where
    recordInfos = map recordInformation (canonicalDocumentRecordsValue document)
    records =
      Map.fromList [(recordInfoOccurrence info, info) | info <- recordInfos]
    references = canonicalDocumentReferencesValue document
    properties =
      map propertyInformation (canonicalDocumentPropertiesValue document)
    relationships =
      Map.fromList
        [ (occurrence, relationshipInformation referenceIndex record)
        | record <- Map.elems records
        , recordInfoFamily record == RelationshipFamily
        , let occurrence = recordInfoOccurrence record
        ]
    referenceIndex =
      groupedBy
        (Just . referenceOwnerAndField)
        canonicalReferenceOccurrenceValue
        references

recordInformation :: CanonicalRecord -> RecordInfo
recordInformation record =
  RecordInfo
    { recordInfoOccurrence = canonicalRecordOccurrenceValue record
    , recordInfoParent = canonicalRecordParentValue record
    , recordInfoFamily = canonicalRecordFamilyValue record
    , recordInfoIdentity = canonicalRecordIdentityValue record
    , recordInfoLocation = canonicalRecordLocationValue record
    , recordInfoFields = canonicalRecordFieldsValue record
    , recordInfoTypeValues = fieldTypeValues record
    , recordInfoNameValues = fieldTextValues NameField record
    , recordInfoDirectedValues = fieldBooleanValues DirectedField record
    }

propertyInformation :: CanonicalProperty -> PropertyInfo
propertyInformation property =
  PropertyInfo
    { propertyInfoOccurrence = canonicalPropertyOccurrenceValue property
    , propertyInfoOwner = canonicalPropertyOwnerValue property
    , propertyInfoOwnerFamily = canonicalPropertyOwnerFamilyValue property
    , propertyInfoLocation = canonicalPropertyLocationValue property
    , propertyInfoRawValues = canonicalPropertyValuesValue property
    , propertyInfoOpaqueEvidence = canonicalPropertyOpaqueEvidenceValue property
    , propertyInfoKeys = propertyKeys property
    , propertyInfoValues = textScalars (canonicalPropertyValuesValue property)
    , propertyInfoDefinition = definition
    }
  where
    definition =
      case canonicalPropertyKeyEvidenceValue property of
        CanonicalDirectPropertyKey _ -> Nothing
        CanonicalReferencedPropertyKey reference ->
          resolvedReferenceOccurrence reference
    propertyKeys canonical =
      case canonicalPropertyKeyEvidenceValue canonical of
        CanonicalDirectPropertyKey scalars -> textScalars scalars
        CanonicalReferencedPropertyKey reference ->
          case canonicalReferenceOutcomeValue reference of
            ReferenceResolved _ _ target ->
              [ draftScalarTextValue scalar
              | field <- canonicalTargetFieldsValue target
              , canonicalFieldValue field == NameField
              , scalar <- canonicalFieldScalarsValue field
              , draftScalarKindValue scalar == DraftText
              ]
            _ -> []

relationshipInformation ::
     Map (CanonicalOccurrence, DraftReferenceFieldValue) [CanonicalReference]
  -> RecordInfo
  -> RelationshipInfo
relationshipInformation references record =
  RelationshipInfo
    { relationshipInfoRecord = record
    , relationshipInfoOccurrence = occurrence
    , relationshipInfoKind = firstOrEmpty (recordInfoTypeValues record)
    , relationshipInfoDirected = or (recordInfoDirectedValues record)
    , relationshipInfoLabel = firstOrEmpty (recordInfoNameValues record)
    , relationshipInfoSource = resolved RelationshipSourceReferenceField
    , relationshipInfoTarget = resolved RelationshipTargetReferenceField
    }
  where
    occurrence = recordInfoOccurrence record
    resolved field =
      case Map.findWithDefault [] (occurrence, field) references of
        [reference] -> resolvedReferenceOccurrence reference
        _ -> Nothing

groupedBy ::
     Ord key
  => (value -> Maybe key)
  -> (value -> CanonicalOccurrence)
  -> [value]
  -> Map key [value]
groupedBy keyOf occurrenceOf = fmap Map.elems . foldl' insertValue Map.empty
  where
    insertValue groups value =
      case keyOf value of
        Nothing -> groups
        Just key ->
          Map.insertWith
            Map.union
            key
            (Map.singleton (occurrenceOf value) value)
            groups

propertiesByOwnerAndKey ::
     [PropertyInfo] -> Map (CanonicalOccurrence, Text) [PropertyInfo]
propertiesByOwnerAndKey properties =
  fmap Map.elems (foldl' insertProperty Map.empty properties)
  where
    insertProperty groups property =
      foldl'
        (insertForKey property)
        groups
        (Set.toAscList (Set.fromList (propertyInfoKeys property)))
    insertForKey property groups key =
      Map.insertWith
        Map.union
        (propertyInfoOwner property, key)
        (Map.singleton (propertyInfoOccurrence property) property)
        groups

relationshipIncidence ::
     (RelationshipInfo -> Maybe CanonicalOccurrence)
  -> Map CanonicalOccurrence RelationshipInfo
  -> Map CanonicalOccurrence [RelationshipInfo]
relationshipIncidence endpoint =
  groupedBy endpoint relationshipInfoOccurrence . Map.elems

referenceOwnerAndField ::
     CanonicalReference -> (CanonicalOccurrence, DraftReferenceFieldValue)
referenceOwnerAndField reference =
  ( canonicalReferenceOwnerValue reference
  , canonicalReferenceFieldValue reference)

recordInfoParentValue :: RecordInfo -> Maybe CanonicalOccurrence
recordInfoParentValue = recordInfoParent

resolvedReferenceOccurrence :: CanonicalReference -> Maybe CanonicalOccurrence
resolvedReferenceOccurrence reference =
  case canonicalReferenceOutcomeValue reference of
    ReferenceResolved _ _ target -> Just (canonicalTargetOccurrenceValue target)
    _ -> Nothing

lookupRecord :: ProfileIndex -> CanonicalOccurrence -> Maybe RecordInfo
lookupRecord profileIndex occurrence =
  Map.lookup occurrence (indexRecords profileIndex)

fieldTextValues :: DraftFieldValue -> CanonicalRecord -> [Text]
fieldTextValues field record =
  [ draftScalarTextValue scalar
  | canonicalField <- canonicalRecordFieldsValue record
  , canonicalFieldValue canonicalField == field
  , scalar <- canonicalFieldScalarsValue canonicalField
  , draftScalarKindValue scalar == DraftText
  ]

fieldTypeValues :: CanonicalRecord -> [Text]
fieldTypeValues record =
  [ draftScalarTextValue scalar
  | canonicalField <- canonicalRecordFieldsValue record
  , canonicalFieldValue canonicalField == TypeField
  , scalar <- canonicalFieldScalarsValue canonicalField
  , draftScalarKindValue scalar == DraftText
  ]

fieldBooleanValues :: DraftFieldValue -> CanonicalRecord -> [Bool]
fieldBooleanValues field record =
  [ value
  | canonicalField <- canonicalRecordFieldsValue record
  , canonicalFieldValue canonicalField == field
  , scalar <- canonicalFieldScalarsValue canonicalField
  , DraftBooleanScalar value <- [draftScalarValueValue scalar]
  ]

textScalars :: [DraftScalar] -> [Text]
textScalars scalars =
  [ draftScalarTextValue scalar
  | scalar <- scalars
  , draftScalarKindValue scalar == DraftText
  ]

firstOrEmpty :: [Text] -> Text
firstOrEmpty values =
  case values of
    value:_ -> value
    [] -> ""

isRelationship, isConcept, isJunction :: RecordInfo -> Bool
isRelationship record = recordInfoFamily record == RelationshipFamily

isConcept record =
  recordInfoFamily record == ElementFamily && not (isJunction record)

isJunction record =
  recordInfoFamily record == ElementFamily
    && any
         (`elem` ["Junction", "AndJunction", "OrJunction"])
         (recordInfoTypeValues record)

isAndJunction :: RecordInfo -> Bool
isAndJunction record = "AndJunction" `elem` recordInfoTypeValues record

archiMateElement :: RecordInfo -> Text
archiMateElement record
  | isJunction record = "Junction"
  | otherwise = firstOrEmpty (recordInfoTypeValues record)

propertiesFor :: ProfileIndex -> CanonicalOccurrence -> [PropertyInfo]
propertiesFor profileIndex occurrence =
  Map.findWithDefault [] occurrence (indexPropertiesByOwner profileIndex)

propertiesForKey ::
     ProfileIndex -> CanonicalOccurrence -> Text -> [PropertyInfo]
propertiesForKey profileIndex occurrence key =
  Map.findWithDefault
    []
    (occurrence, key)
    (indexPropertiesByOwnerAndKey profileIndex)

hasProperty :: ProfileIndex -> Text -> CanonicalOccurrence -> Bool
hasProperty profileIndex key occurrence =
  not (null (propertiesForKey profileIndex occurrence key))

propertyValues :: ProfileIndex -> Text -> CanonicalOccurrence -> [Text]
propertyValues profileIndex key occurrence =
  [ value
  | property <- propertiesForKey profileIndex occurrence key
  , value <- propertyInfoValues property
  ]

roleValues :: ProfileIndex -> CanonicalOccurrence -> [Text]
roleValues profileIndex occurrence =
  case propertyValues profileIndex "o2i.role" occurrence of
    [] -> [""]
    values -> values

incidentRelationships ::
     ProfileIndex -> CanonicalOccurrence -> [RelationshipInfo]
incidentRelationships profileIndex occurrence =
  Map.elems
    (foldl'
       addRelationship
       Map.empty
       (Map.findWithDefault
          []
          occurrence
          (indexRelationshipsBySource profileIndex)
          ++ Map.findWithDefault
               []
               occurrence
               (indexRelationshipsByTarget profileIndex)))
  where
    addRelationship relationships relationship =
      Map.insert
        (relationshipInfoOccurrence relationship)
        relationship
        relationships
