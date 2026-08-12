{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE StandaloneDeriving #-}

module O2I.ArchiMate.Profile.Internal.Draft where

import Data.List (partition, sortBy)
import Data.Ord (comparing)
import Data.Text (Text)
import Numeric.Natural (Natural)

-- | Type-level role of the one native model-root record.
data ModelRootRole

-- | Type-level role of native property-definition records.
data PropertyDefinitionRole

-- | Type-level role of native element records.
data ElementRole

-- | Type-level role of native relationship records.
data RelationshipRole

-- | Type-level role of native View records.
data ViewRole

-- | Type-level role of native View-node records.
data ViewNodeRole

-- | Type-level role of native View-connection records.
data ViewConnectionRole

-- | Closed profile-neutral record families admitted at the Draft boundary.
data DraftRecordFamily recordRole where
  DraftModelRoot :: DraftRecordFamily ModelRootRole
  DraftPropertyDefinition :: DraftRecordFamily PropertyDefinitionRole
  DraftElement :: DraftRecordFamily ElementRole
  DraftRelationship :: DraftRecordFamily RelationshipRole
  DraftView :: DraftRecordFamily ViewRole
  DraftViewNode :: DraftRecordFamily ViewNodeRole
  DraftViewConnection :: DraftRecordFamily ViewConnectionRole

deriving instance Eq (DraftRecordFamily recordRole)

deriving instance Show (DraftRecordFamily recordRole)

-- | Value-level representation of a Draft record family.
data DraftRecordFamilyValue
  = ModelRootFamily
  | PropertyDefinitionFamily
  | ElementFamily
  | RelationshipFamily
  | ViewFamily
  | ViewNodeFamily
  | ViewConnectionFamily
  deriving (Bounded, Enum, Eq, Ord, Show)

recordFamilyValue :: DraftRecordFamily recordRole -> DraftRecordFamilyValue
recordFamilyValue family =
  case family of
    DraftModelRoot -> ModelRootFamily
    DraftPropertyDefinition -> PropertyDefinitionFamily
    DraftElement -> ElementFamily
    DraftRelationship -> RelationshipFamily
    DraftView -> ViewFamily
    DraftViewNode -> ViewNodeFamily
    DraftViewConnection -> ViewConnectionFamily

-- | Closed classification of scalar values retained at the Draft boundary.
data DraftValueKind
  = DraftText
  | DraftBoolean
  | DraftNumber
  | DraftNativeNameValue
  | DraftOtherKind !Text
  deriving (Eq, Ord, Show)

-- | One exact source position when supplied by the notation decoder.
data DraftSourcePosition = DraftSourcePosition
  { draftSourceLineValue :: !Natural
  , draftSourceColumnValue :: !Natural
  , draftSourceOffsetValue :: !(Maybe Natural)
  } deriving (Eq, Ord, Show)

-- | Optional source span from its inclusive start to exclusive end.
data DraftSourceSpan = DraftSourceSpan
  { draftSpanStartValue :: !DraftSourcePosition
  , draftSpanEndValue :: !DraftSourcePosition
  } deriving (Eq, Ord, Show)

-- | One native name with an optional namespace and mandatory local name.
data DraftNativeName = DraftNativeName
  { draftNativeNamespaceValue :: !(Maybe Text)
  , draftNativeLocalNameValue :: !Text
  } deriving (Eq, Ord, Show)

-- | One expanded-QName path step and its one-based equal-name ordinal.
data DraftPathStep = DraftPathStep
  { draftPathStepNameValue :: !DraftNativeName
  , draftPathStepOrdinalValue :: !Natural
  } deriving (Eq, Ord, Show)

-- | Non-empty expanded-QName source path.
data DraftSourcePath =
  DraftSourcePath !DraftPathStep ![DraftPathStep]
  deriving (Eq, Ord, Show)

-- | Mandatory source path plus an optional exact source span.
data DraftLocation = DraftLocation
  { draftLocationPathValue :: !DraftSourcePath
  , draftLocationSpanValue :: !(Maybe DraftSourceSpan)
  } deriving (Show)

-- Source spans are diagnostic evidence. Draft observation equality and order
-- are stable across serialization-only span changes.
instance Eq DraftLocation where
  left == right = draftLocationPathValue left == draftLocationPathValue right

instance Ord DraftLocation where
  compare = comparing draftLocationPathValue

data DraftScalarValue
  = DraftTextScalar !Text
  | DraftBooleanScalar !Bool
  | DraftNumberScalar !Text
  | DraftNativeNameScalar !DraftNativeName
  | DraftOtherScalar !Text !Text
  deriving (Eq, Ord, Show)

-- | One raw scalar value paired with its exact source location.
data DraftScalar = DraftScalar
  { draftScalarValueValue :: !DraftScalarValue
  , draftScalarLocationValue :: !DraftLocation
  } deriving (Eq, Ord, Show)

draftScalarKindValue :: DraftScalar -> DraftValueKind
draftScalarKindValue scalar =
  case draftScalarValueValue scalar of
    DraftTextScalar _ -> DraftText
    DraftBooleanScalar _ -> DraftBoolean
    DraftNumberScalar _ -> DraftNumber
    DraftNativeNameScalar _ -> DraftNativeNameValue
    DraftOtherScalar kind _ -> DraftOtherKind kind

draftScalarTextValue :: DraftScalar -> Text
draftScalarTextValue scalar =
  case draftScalarValueValue scalar of
    DraftTextScalar value -> value
    DraftBooleanScalar True -> "true"
    DraftBooleanScalar False -> "false"
    DraftNumberScalar value -> value
    DraftNativeNameScalar value -> draftNativeLocalNameValue value
    DraftOtherScalar _ value -> value

-- | Raw identity observations whose phantom role prevents cross-family use.
newtype DraftIdentity recordRole = DraftIdentity
  { draftIdentityValuesValue :: [DraftScalar]
  } deriving (Eq, Ord, Show)

type role DraftIdentity nominal

-- | Closed, owner- and target-typed native reference fields.
data DraftReferenceField ownerRole targetRole where
  DraftPropertyDefinitionReference
    :: DraftReferenceField owner PropertyDefinitionRole
  DraftRelationshipSourceReference
    :: DraftReferenceField RelationshipRole ElementRole
  DraftRelationshipTargetReference
    :: DraftReferenceField RelationshipRole ElementRole
  DraftViewNodeElementReference :: DraftReferenceField ViewNodeRole ElementRole
  DraftViewConnectionRelationshipReference
    :: DraftReferenceField ViewConnectionRole RelationshipRole
  DraftViewConnectionSourceReference
    :: DraftReferenceField ViewConnectionRole ViewNodeRole
  DraftViewConnectionTargetReference
    :: DraftReferenceField ViewConnectionRole ViewNodeRole

deriving instance Eq (DraftReferenceField ownerRole targetRole)

deriving instance Show (DraftReferenceField ownerRole targetRole)

-- | Value-level representation of a typed native reference field.
data DraftReferenceFieldValue
  = PropertyDefinitionReferenceField
  | RelationshipSourceReferenceField
  | RelationshipTargetReferenceField
  | ViewNodeElementReferenceField
  | ViewConnectionRelationshipReferenceField
  | ViewConnectionSourceReferenceField
  | ViewConnectionTargetReferenceField
  deriving (Bounded, Enum, Eq, Ord, Show)

referenceFieldValue ::
     DraftReferenceField ownerRole targetRole -> DraftReferenceFieldValue
referenceFieldValue field =
  case field of
    DraftPropertyDefinitionReference -> PropertyDefinitionReferenceField
    DraftRelationshipSourceReference -> RelationshipSourceReferenceField
    DraftRelationshipTargetReference -> RelationshipTargetReferenceField
    DraftViewNodeElementReference -> ViewNodeElementReferenceField
    DraftViewConnectionRelationshipReference ->
      ViewConnectionRelationshipReferenceField
    DraftViewConnectionSourceReference -> ViewConnectionSourceReferenceField
    DraftViewConnectionTargetReference -> ViewConnectionTargetReferenceField

referenceExpectedFamily ::
     DraftReferenceField ownerRole targetRole -> DraftRecordFamily targetRole
referenceExpectedFamily field =
  case field of
    DraftPropertyDefinitionReference -> DraftPropertyDefinition
    DraftRelationshipSourceReference -> DraftElement
    DraftRelationshipTargetReference -> DraftElement
    DraftViewNodeElementReference -> DraftElement
    DraftViewConnectionRelationshipReference -> DraftRelationship
    DraftViewConnectionSourceReference -> DraftViewNode
    DraftViewConnectionTargetReference -> DraftViewNode

-- | One raw native reference with statically fixed owner and target roles.
data DraftReference ownerRole targetRole = DraftReference
  { draftReferenceFieldValue :: !(DraftReferenceField ownerRole targetRole)
  , draftReferenceIdentityValue :: !(DraftIdentity targetRole)
  , draftReferenceLocationValue :: !DraftLocation
  } deriving (Eq, Show)

type role DraftReference nominal nominal

data SomeDraftReference ownerRole where
  SomeDraftReference
    :: DraftReference ownerRole targetRole -> SomeDraftReference ownerRole

instance Eq (SomeDraftReference ownerRole) where
  SomeDraftReference left == SomeDraftReference right =
    referenceFieldValue (draftReferenceFieldValue left)
      == referenceFieldValue (draftReferenceFieldValue right)
      && draftIdentityValuesValue (draftReferenceIdentityValue left)
           == draftIdentityValuesValue (draftReferenceIdentityValue right)
      && draftReferenceLocationValue left == draftReferenceLocationValue right

instance Show (SomeDraftReference ownerRole) where
  show (SomeDraftReference reference) = show reference

-- | A direct or property-definition-backed key retaining its owner role.
data DraftPropertyKey ownerRole
  = DraftDirectPropertyKey ![DraftScalar]
  | DraftPropertyDefinitionKey
      !(DraftReference ownerRole PropertyDefinitionRole)
  deriving (Eq, Show)

-- | Native position of evidence not recognized by the Draft vocabulary.
data DraftOpaquePosition
  = DraftOpaqueAttribute
  | DraftOpaqueChild
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Losslessly retained native evidence outside the recognized vocabulary.
data DraftOpaqueEvidence = DraftOpaqueEvidence
  { draftOpaquePositionValue :: !DraftOpaquePosition
  , draftOpaqueNameValue :: !DraftNativeName
  , draftOpaqueScalarsValue :: ![DraftScalar]
  , draftOpaqueLocationValue :: !DraftLocation
  } deriving (Eq, Ord, Show)

-- | One raw property whose phantom role identifies its owning record family.
data DraftProperty ownerRole = DraftProperty
  { draftPropertyKeyValue :: !(DraftPropertyKey ownerRole)
  , draftPropertyValuesValue :: ![DraftScalar]
  , draftPropertyLocationValue :: !DraftLocation
  , draftPropertyOpaqueEvidenceValue :: ![DraftOpaqueEvidence]
  } deriving (Eq, Show)

mkDraftProperty ::
     DraftPropertyKey ownerRole
  -> [DraftScalar]
  -> DraftLocation
  -> [DraftOpaqueEvidence]
  -> DraftProperty ownerRole
mkDraftProperty key values location opaque =
  DraftProperty key values location (canonicalOpaqueOrder opaque)

canonicalOpaqueOrder :: [DraftOpaqueEvidence] -> [DraftOpaqueEvidence]
canonicalOpaqueOrder evidence =
  sortBy (comparing draftOpaqueNameValue) attributes ++ children
  where
    (attributes, children) =
      partition ((== DraftOpaqueAttribute) . draftOpaquePositionValue) evidence

-- | Closed recognized scalar fields. Identity is retained separately.
data DraftField recordRole where
  DraftTypeField :: DraftField recordRole
  DraftNameField :: DraftField recordRole
  DraftElementDocumentationField :: DraftField ElementRole
  DraftRelationshipDocumentationField :: DraftField RelationshipRole
  DraftDirectedField :: DraftField RelationshipRole
  DraftInfluenceStrengthField :: DraftField RelationshipRole

deriving instance Eq (DraftField recordRole)

deriving instance Show (DraftField recordRole)

-- | Value-level representation of a recognized Draft scalar field.
data DraftFieldValue
  = TypeField
  | NameField
  | DocumentationField
  | DirectedField
  | InfluenceStrengthField
  deriving (Bounded, Enum, Eq, Ord, Show)

fieldValue :: DraftField recordRole -> DraftFieldValue
fieldValue field =
  case field of
    DraftTypeField -> TypeField
    DraftNameField -> NameField
    DraftElementDocumentationField -> DocumentationField
    DraftRelationshipDocumentationField -> DocumentationField
    DraftDirectedField -> DirectedField
    DraftInfluenceStrengthField -> InfluenceStrengthField

-- | One ordered member retained within a raw Draft record.
data DraftMember recordRole
  = DraftFieldMember !(DraftField recordRole) ![DraftScalar] !DraftLocation
  | DraftPropertyMember !(DraftProperty recordRole)
  | DraftReferenceMember !(SomeDraftReference recordRole)
  | DraftChildRecord !SomeDraftRecord
  | DraftOpaqueMember !DraftOpaqueEvidence

type role DraftMember nominal

instance Eq (DraftMember recordRole) where
  left == right = eraseMember left == eraseMember right

instance Show (DraftMember recordRole) where
  show member =
    case member of
      DraftFieldMember field values location ->
        "DraftFieldMember "
          <> show field
          <> " "
          <> show values
          <> " "
          <> show location
      DraftPropertyMember property -> "DraftPropertyMember " <> show property
      DraftReferenceMember reference ->
        "DraftReferenceMember " <> show reference
      DraftChildRecord record -> "DraftChildRecord " <> show record
      DraftOpaqueMember evidence -> "DraftOpaqueMember " <> show evidence

-- | One lossless raw record whose phantom role fixes its record family.
data DraftRecord recordRole = DraftRecord
  { draftRecordFamilyValue :: !(DraftRecordFamily recordRole)
  , draftRecordIdentityValue :: !(DraftIdentity recordRole)
  , draftRecordLocationValue :: !DraftLocation
  , draftRecordMembersValue :: ![DraftMember recordRole]
  } deriving (Eq, Show)

type role DraftRecord nominal

data SomeDraftRecord where
  SomeDraftRecord :: DraftRecord recordRole -> SomeDraftRecord

instance Eq SomeDraftRecord where
  SomeDraftRecord left == SomeDraftRecord right =
    eraseRecord left == eraseRecord right

instance Show SomeDraftRecord where
  show (SomeDraftRecord record) = show record

-- | Draft record specialized to the model-root family.
type ModelRootDraft = DraftRecord ModelRootRole

-- | Draft record specialized to the property-definition family.
type PropertyDefinitionDraft = DraftRecord PropertyDefinitionRole

-- | Draft record specialized to the element family.
type ElementDraft = DraftRecord ElementRole

-- | Draft record specialized to the relationship family.
type RelationshipDraft = DraftRecord RelationshipRole

-- | Draft record specialized to the View family.
type ViewDraft = DraftRecord ViewRole

-- | Draft record specialized to the View-node family.
type ViewNodeDraft = DraftRecord ViewNodeRole

-- | Draft record specialized to the View-connection family.
type ViewConnectionDraft = DraftRecord ViewConnectionRole

-- | Complete lossless native document at the Profile Draft boundary.
newtype ProfileDraft = ProfileDraft
  { profileDraftRootValue :: ModelRootDraft
  } deriving (Eq, Show)

data ErasedDraftReference =
  ErasedDraftReference !DraftReferenceFieldValue ![DraftScalar] !DraftLocation
  deriving (Eq)

data ErasedDraftPropertyKey
  = ErasedDirectPropertyKey ![DraftScalar]
  | ErasedPropertyDefinitionKey !ErasedDraftReference
  deriving (Eq)

data ErasedDraftProperty =
  ErasedDraftProperty
    !ErasedDraftPropertyKey
    ![DraftScalar]
    !DraftLocation
    ![DraftOpaqueEvidence]
  deriving (Eq)

data ErasedDraftMember
  = ErasedFieldMember !DraftFieldValue ![DraftScalar] !DraftLocation
  | ErasedPropertyMember !ErasedDraftProperty
  | ErasedReferenceMember !ErasedDraftReference
  | ErasedChildRecord !ErasedDraftRecord
  | ErasedOpaqueMember !DraftOpaqueEvidence
  deriving (Eq)

data ErasedDraftRecord =
  ErasedDraftRecord
    !DraftRecordFamilyValue
    ![DraftScalar]
    !DraftLocation
    ![ErasedDraftMember]
  deriving (Eq)

eraseReference :: DraftReference ownerRole targetRole -> ErasedDraftReference
eraseReference reference =
  ErasedDraftReference
    (referenceFieldValue (draftReferenceFieldValue reference))
    (draftIdentityValuesValue (draftReferenceIdentityValue reference))
    (draftReferenceLocationValue reference)

erasePropertyKey :: DraftPropertyKey ownerRole -> ErasedDraftPropertyKey
erasePropertyKey key =
  case key of
    DraftDirectPropertyKey values -> ErasedDirectPropertyKey values
    DraftPropertyDefinitionKey reference ->
      ErasedPropertyDefinitionKey (eraseReference reference)

eraseProperty :: DraftProperty ownerRole -> ErasedDraftProperty
eraseProperty property =
  ErasedDraftProperty
    (erasePropertyKey (draftPropertyKeyValue property))
    (draftPropertyValuesValue property)
    (draftPropertyLocationValue property)
    (draftPropertyOpaqueEvidenceValue property)

eraseMember :: DraftMember recordRole -> ErasedDraftMember
eraseMember member =
  case member of
    DraftFieldMember field values location ->
      ErasedFieldMember (fieldValue field) values location
    DraftPropertyMember property ->
      ErasedPropertyMember (eraseProperty property)
    DraftReferenceMember (SomeDraftReference reference) ->
      ErasedReferenceMember (eraseReference reference)
    DraftChildRecord (SomeDraftRecord record) ->
      ErasedChildRecord (eraseRecord record)
    DraftOpaqueMember evidence -> ErasedOpaqueMember evidence

eraseRecord :: DraftRecord recordRole -> ErasedDraftRecord
eraseRecord record =
  ErasedDraftRecord
    (recordFamilyValue (draftRecordFamilyValue record))
    (draftIdentityValuesValue (draftRecordIdentityValue record))
    (draftRecordLocationValue record)
    (map eraseMember (draftRecordMembersValue record))

mkDraftRecord ::
     DraftRecordFamily recordRole
  -> DraftIdentity recordRole
  -> DraftLocation
  -> [DraftMember recordRole]
  -> DraftRecord recordRole
mkDraftRecord family identityValue location members =
  DraftRecord family identityValue location (canonicalMemberOrder members)

-- | Normalize unobservable attribute order while retaining child source order.
canonicalMemberOrder :: [DraftMember recordRole] -> [DraftMember recordRole]
canonicalMemberOrder members =
  sortBy (comparing attributeOrder) attributes ++ children
  where
    (attributes, children) = partition isAttribute members

isAttribute :: DraftMember recordRole -> Bool
isAttribute member =
  case member of
    DraftFieldMember field _ _ -> fieldValue field /= DocumentationField
    DraftReferenceMember _ -> True
    DraftOpaqueMember evidence ->
      draftOpaquePositionValue evidence == DraftOpaqueAttribute
    DraftPropertyMember _ -> False
    DraftChildRecord _ -> False

attributeOrder :: DraftMember recordRole -> (Int, DraftNativeName)
attributeOrder member =
  case member of
    DraftFieldMember field _ _ -> (fieldRank (fieldValue field), emptyName)
    DraftReferenceMember (SomeDraftReference reference) ->
      ( referenceRank (referenceFieldValue (draftReferenceFieldValue reference))
      , emptyName)
    DraftOpaqueMember evidence -> (100, draftOpaqueNameValue evidence)
    _ -> (200, emptyName)
  where
    emptyName = DraftNativeName Nothing ""

fieldRank :: DraftFieldValue -> Int
fieldRank value =
  case value of
    TypeField -> 10
    NameField -> 20
    DirectedField -> 30
    InfluenceStrengthField -> 40
    DocumentationField -> 90

referenceRank :: DraftReferenceFieldValue -> Int
referenceRank value =
  case value of
    PropertyDefinitionReferenceField -> 50
    RelationshipSourceReferenceField -> 50
    RelationshipTargetReferenceField -> 60
    ViewNodeElementReferenceField -> 50
    ViewConnectionRelationshipReferenceField -> 50
    ViewConnectionSourceReferenceField -> 60
    ViewConnectionTargetReferenceField -> 70
