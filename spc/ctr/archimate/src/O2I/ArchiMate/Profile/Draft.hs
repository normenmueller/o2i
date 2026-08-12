{-# LANGUAGE RankNTypes #-}

-- | Observation-complete, profile-neutral ArchiMate input.
--
-- Draft values retain exact scalar, reference, ordering, path, span, and opaque
-- evidence. Construction canonicalizes only unobservable attribute order.
module O2I.ArchiMate.Profile.Draft
  ( -- | Observation-complete Draft rooted in one native model record.
    ProfileDraft
  , profileDraft
  , profileDraftRoot
  , -- | Opaque native record indexed by its admissible role.
    DraftRecord
  , -- | Closed runtime witness for a native record family.
    DraftRecordFamilyValue
  , foldDraftRecordFamilyValue
  , draftRecordFamily
  , draftRecordIdentity
  , draftRecordLocation
  , draftRecordMembers
  , foldDraftRecord
  , -- | Phantom role of the native model root.
    ModelRootRole
  , -- | Phantom role of a native property definition.
    PropertyDefinitionRole
  , -- | Phantom role of a native element.
    ElementRole
  , -- | Phantom role of a native relationship.
    RelationshipRole
  , -- | Phantom role of a native View.
    ViewRole
  , -- | Phantom role of a native View node.
    ViewNodeRole
  , -- | Phantom role of a native View connection.
    ViewConnectionRole
  , -- | Role-safe model-root Draft record.
    ModelRootDraft
  , modelRootDraft
  , -- | Role-safe property-definition Draft record.
    PropertyDefinitionDraft
  , propertyDefinitionDraft
  , -- | Role-safe element Draft record.
    ElementDraft
  , elementDraft
  , -- | Role-safe relationship Draft record.
    RelationshipDraft
  , relationshipDraft
  , -- | Role-safe View Draft record.
    ViewDraft
  , viewDraft
  , -- | Role-safe View-node Draft record.
    ViewNodeDraft
  , viewNodeDraft
  , -- | Role-safe View-connection Draft record.
    ViewConnectionDraft
  , viewConnectionDraft
  , -- | Opaque exact identity observations for one record role.
    DraftIdentity
  , draftIdentity
  , foldDraftIdentity
  , -- | Closed or explicitly retained scalar-value kind.
    DraftValueKind
  , draftTextKind
  , draftBooleanKind
  , draftNumberKind
  , draftNativeNameKind
  , draftOtherKind
  , foldDraftValueKind
  , -- | Opaque scalar value paired with exact source provenance.
    DraftScalar
  , draftTextScalar
  , draftBooleanScalar
  , draftNumberScalar
  , draftNativeNameScalar
  , draftOtherScalar
  , foldDraftScalarValue
  , draftScalarKind
  , draftScalarText
  , draftScalarLocation
  , -- | Closed recognized native field kind.
    DraftFieldValue
  , foldDraftFieldValue
  , -- | Opaque role-safe member of one native Draft record.
    DraftMember
  , typeFieldMember
  , nameFieldMember
  , elementDocumentationFieldMember
  , relationshipDocumentationFieldMember
  , directedFieldMember
  , influenceStrengthFieldMember
  , propertyMember
  , referenceMember
  , childRecordMember
  , opaqueMember
  , foldDraftMember
  , -- | Opaque native reference indexed by owner and target roles.
    DraftReference
  , -- | Closed runtime witness for a native reference field.
    DraftReferenceFieldValue
  , foldDraftReferenceFieldValue
  , propertyDefinitionReference
  , relationshipSourceReference
  , relationshipTargetReference
  , viewNodeElementReference
  , viewConnectionRelationshipReference
  , viewConnectionSourceReference
  , viewConnectionTargetReference
  , draftReferenceField
  , draftReferenceIdentity
  , draftReferenceLocation
  , draftReferenceExpectedFamily
  , foldDraftReference
  , -- | Direct or property-definition-backed key evidence.
    DraftPropertyKey
  , directPropertyKey
  , propertyDefinitionKey
  , foldDraftPropertyKey
  , -- | Opaque property observation owned by one record role.
    DraftProperty
  , draftProperty
  , draftPropertyKey
  , draftPropertyValues
  , draftPropertyLocation
  , draftPropertyOpaqueEvidence
  , -- | Native local name with an optional namespace.
    DraftNativeName
  , draftNativeName
  , draftNativeNamespace
  , draftNativeLocalName
  , -- | Closed position of unrecognized native evidence.
    DraftOpaquePosition
  , opaqueAttribute
  , opaqueChild
  , foldDraftOpaquePosition
  , -- | Unrecognized observation retained without interpretation.
    DraftOpaqueEvidence
  , draftOpaqueEvidence
  , draftOpaquePosition
  , draftOpaqueName
  , draftOpaqueScalars
  , draftOpaqueLocation
  , -- | One named and ordinal source-path step.
    DraftPathStep
  , draftPathStep
  , draftPathStepName
  , draftPathStepOrdinal
  , -- | Non-empty exact path to a source observation.
    DraftSourcePath
  , draftSourcePath
  , foldDraftSourcePath
  , -- | Source path and optional source span of an observation.
    DraftLocation
  , draftLocation
  , draftLocationPath
  , draftLocationSpan
  , -- | One line, column, and optional offset in the source.
    DraftSourcePosition
  , draftSourcePosition
  , draftSourceLine
  , draftSourceColumn
  , draftSourceOffset
  , -- | Exact start and end positions of a source observation.
    DraftSourceSpan
  , draftSourceSpan
  , draftSpanStart
  , draftSpanEnd
  ) where

import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Internal.Draft

-- | Wrap one canonical-order model-root observation as a complete Draft.
profileDraft :: ModelRootDraft -> ProfileDraft
profileDraft = ProfileDraft

-- | Model-root observation retained by the Draft.
profileDraftRoot :: ProfileDraft -> ModelRootDraft
profileDraftRoot = profileDraftRootValue

-- | Consume every closed native record-family witness.
foldDraftRecordFamilyValue ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> DraftRecordFamilyValue
  -> result
foldDraftRecordFamilyValue root definition element relationship view node connection family =
  case family of
    ModelRootFamily -> root
    PropertyDefinitionFamily -> definition
    ElementFamily -> element
    RelationshipFamily -> relationship
    ViewFamily -> view
    ViewNodeFamily -> node
    ViewConnectionFamily -> connection

-- | Runtime native family of a role-typed Draft record.
draftRecordFamily :: DraftRecord recordRole -> DraftRecordFamilyValue
draftRecordFamily = recordFamilyValue . draftRecordFamilyValue

-- | Exact identity observations retained for the Draft record.
draftRecordIdentity :: DraftRecord recordRole -> DraftIdentity recordRole
draftRecordIdentity = draftRecordIdentityValue

-- | Exact source location of the Draft record.
draftRecordLocation :: DraftRecord recordRole -> DraftLocation
draftRecordLocation = draftRecordLocationValue

-- | Ordered, role-safe members retained by the Draft record.
draftRecordMembers :: DraftRecord recordRole -> [DraftMember recordRole]
draftRecordMembers = draftRecordMembersValue

-- | Consume a role-typed record without exposing its constructor.
foldDraftRecord ::
     (DraftRecordFamilyValue -> DraftIdentity recordRole -> DraftLocation -> [DraftMember
                                                                                recordRole] -> result)
  -> DraftRecord recordRole
  -> result
foldDraftRecord consume record =
  consume
    (draftRecordFamily record)
    (draftRecordIdentityValue record)
    (draftRecordLocationValue record)
    (draftRecordMembersValue record)

-- | Construct a model-root record without interpreting its observations.
modelRootDraft ::
     DraftIdentity ModelRootRole
  -> DraftLocation
  -> [DraftMember ModelRootRole]
  -> ModelRootDraft
modelRootDraft = mkDraftRecord DraftModelRoot

-- | Construct a property-definition record from exact observations.
propertyDefinitionDraft ::
     DraftIdentity PropertyDefinitionRole
  -> DraftLocation
  -> [DraftMember PropertyDefinitionRole]
  -> PropertyDefinitionDraft
propertyDefinitionDraft = mkDraftRecord DraftPropertyDefinition

-- | Construct an element record from exact observations.
elementDraft ::
     DraftIdentity ElementRole
  -> DraftLocation
  -> [DraftMember ElementRole]
  -> ElementDraft
elementDraft = mkDraftRecord DraftElement

-- | Construct a relationship record from exact observations.
relationshipDraft ::
     DraftIdentity RelationshipRole
  -> DraftLocation
  -> [DraftMember RelationshipRole]
  -> RelationshipDraft
relationshipDraft = mkDraftRecord DraftRelationship

-- | Construct a View record from exact observations.
viewDraft ::
     DraftIdentity ViewRole
  -> DraftLocation
  -> [DraftMember ViewRole]
  -> ViewDraft
viewDraft = mkDraftRecord DraftView

-- | Construct a View-node record from exact observations.
viewNodeDraft ::
     DraftIdentity ViewNodeRole
  -> DraftLocation
  -> [DraftMember ViewNodeRole]
  -> ViewNodeDraft
viewNodeDraft = mkDraftRecord DraftViewNode

-- | Construct a View-connection record from exact observations.
viewConnectionDraft ::
     DraftIdentity ViewConnectionRole
  -> DraftLocation
  -> [DraftMember ViewConnectionRole]
  -> ViewConnectionDraft
viewConnectionDraft = mkDraftRecord DraftViewConnection

-- | Retain zero, one, or many exact recognized identity observations.
draftIdentity :: [DraftScalar] -> DraftIdentity recordRole
draftIdentity = DraftIdentity

-- | Consume all retained identity observations without exposing constructors.
foldDraftIdentity ::
     ([DraftScalar] -> result) -> DraftIdentity recordRole -> result
foldDraftIdentity consume = consume . draftIdentityValuesValue

-- | Canonical witnesses for the four recognized scalar kinds.
draftTextKind, draftBooleanKind, draftNumberKind, draftNativeNameKind ::
     DraftValueKind
draftTextKind = DraftText

draftBooleanKind = DraftBoolean

draftNumberKind = DraftNumber

draftNativeNameKind = DraftNativeNameValue

-- | Retain an unrecognized scalar kind by its native token.
draftOtherKind :: Text -> DraftValueKind
draftOtherKind = DraftOtherKind

-- | Consume every recognized or explicitly retained scalar kind.
foldDraftValueKind ::
     result
  -> result
  -> result
  -> result
  -> (Text -> result)
  -> DraftValueKind
  -> result
foldDraftValueKind text boolean number nativeName other kind =
  case kind of
    DraftText -> text
    DraftBoolean -> boolean
    DraftNumber -> number
    DraftNativeNameValue -> nativeName
    DraftOtherKind value -> other value

-- | Construct one text scalar with exact source provenance.
draftTextScalar :: Text -> DraftLocation -> DraftScalar
draftTextScalar value = DraftScalar (DraftTextScalar value)

-- | Construct one Boolean scalar with exact source provenance.
draftBooleanScalar :: Bool -> DraftLocation -> DraftScalar
draftBooleanScalar value = DraftScalar (DraftBooleanScalar value)

-- | Retain one native number lexeme with exact source provenance.
draftNumberScalar :: Text -> DraftLocation -> DraftScalar
draftNumberScalar value = DraftScalar (DraftNumberScalar value)

-- | Construct one native-name scalar with exact source provenance.
draftNativeNameScalar :: DraftNativeName -> DraftLocation -> DraftScalar
draftNativeNameScalar value = DraftScalar (DraftNativeNameScalar value)

-- | Retain one unrecognized scalar kind and lexeme with provenance.
draftOtherScalar :: Text -> Text -> DraftLocation -> DraftScalar
draftOtherScalar kind value = DraftScalar (DraftOtherScalar kind value)

-- | Consume the exact typed scalar value.
foldDraftScalarValue ::
     (Text -> result)
  -> (Bool -> result)
  -> (Text -> result)
  -> (DraftNativeName -> result)
  -> (Text -> Text -> result)
  -> DraftScalar
  -> result
foldDraftScalarValue text boolean number nativeName other scalar =
  case draftScalarValueValue scalar of
    DraftTextScalar value -> text value
    DraftBooleanScalar value -> boolean value
    DraftNumberScalar value -> number value
    DraftNativeNameScalar value -> nativeName value
    DraftOtherScalar kind value -> other kind value

-- | Runtime kind of the retained scalar value.
draftScalarKind :: DraftScalar -> DraftValueKind
draftScalarKind = draftScalarKindValue

-- | Lossless textual rendering of the retained scalar value.
draftScalarText :: DraftScalar -> Text
draftScalarText = draftScalarTextValue

-- | Exact source location of the scalar observation.
draftScalarLocation :: DraftScalar -> DraftLocation
draftScalarLocation = draftScalarLocationValue

-- | Consume every closed recognized native field kind.
foldDraftFieldValue ::
     result -> result -> result -> result -> result -> DraftFieldValue -> result
foldDraftFieldValue typeValue name documentation directed strength field =
  case field of
    TypeField -> typeValue
    NameField -> name
    DocumentationField -> documentation
    DirectedField -> directed
    InfluenceStrengthField -> strength

-- | Construct a recognized native type-field member.
typeFieldMember :: [DraftScalar] -> DraftLocation -> DraftMember recordRole
typeFieldMember = DraftFieldMember DraftTypeField

-- | Construct a recognized native name-field member.
nameFieldMember :: [DraftScalar] -> DraftLocation -> DraftMember recordRole
nameFieldMember = DraftFieldMember DraftNameField

-- | Construct an element documentation-field member.
elementDocumentationFieldMember ::
     [DraftScalar] -> DraftLocation -> DraftMember ElementRole
elementDocumentationFieldMember =
  DraftFieldMember DraftElementDocumentationField

-- | Construct a relationship documentation-field member.
relationshipDocumentationFieldMember ::
     [DraftScalar] -> DraftLocation -> DraftMember RelationshipRole
relationshipDocumentationFieldMember =
  DraftFieldMember DraftRelationshipDocumentationField

-- | Construct a relationship directedness-field member.
directedFieldMember ::
     [DraftScalar] -> DraftLocation -> DraftMember RelationshipRole
directedFieldMember = DraftFieldMember DraftDirectedField

-- | Construct a relationship influence-strength-field member.
influenceStrengthFieldMember ::
     [DraftScalar] -> DraftLocation -> DraftMember RelationshipRole
influenceStrengthFieldMember = DraftFieldMember DraftInfluenceStrengthField

-- | Embed one role-safe property observation as a record member.
propertyMember :: DraftProperty recordRole -> DraftMember recordRole
propertyMember = DraftPropertyMember

-- | Embed one role-safe native reference as a record member.
referenceMember :: DraftReference ownerRole targetRole -> DraftMember ownerRole
referenceMember = DraftReferenceMember . SomeDraftReference

-- | Embed one nested native record without imposing Profile semantics.
childRecordMember :: DraftRecord childRole -> DraftMember ownerRole
childRecordMember = DraftChildRecord . SomeDraftRecord

-- | Embed one unrecognized observation as retained evidence.
opaqueMember :: DraftOpaqueEvidence -> DraftMember recordRole
opaqueMember = DraftOpaqueMember

-- | Consume every closed member alternative without exposing constructors.
foldDraftMember ::
     (DraftFieldValue -> [DraftScalar] -> DraftLocation -> result)
  -> (DraftProperty recordRole -> result)
  -> (forall targetRole. DraftReference recordRole targetRole -> result)
  -> (forall childRole. DraftRecord childRole -> result)
  -> (DraftOpaqueEvidence -> result)
  -> DraftMember recordRole
  -> result
foldDraftMember field property reference child opaque member =
  case member of
    DraftFieldMember observedField values location ->
      field
        (O2I.ArchiMate.Profile.Internal.Draft.fieldValue observedField)
        values
        location
    DraftPropertyMember propertyValue -> property propertyValue
    DraftReferenceMember (SomeDraftReference referenceValue) ->
      reference referenceValue
    DraftChildRecord (SomeDraftRecord record) -> child record
    DraftOpaqueMember evidence -> opaque evidence

-- | Consume every closed native reference-field witness.
foldDraftReferenceFieldValue ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> DraftReferenceFieldValue
  -> result
foldDraftReferenceFieldValue definition source target nodeElement connection sourceNode targetNode field =
  case field of
    PropertyDefinitionReferenceField -> definition
    RelationshipSourceReferenceField -> source
    RelationshipTargetReferenceField -> target
    ViewNodeElementReferenceField -> nodeElement
    ViewConnectionRelationshipReferenceField -> connection
    ViewConnectionSourceReferenceField -> sourceNode
    ViewConnectionTargetReferenceField -> targetNode

-- | Construct a property-definition reference with exact provenance.
propertyDefinitionReference ::
     DraftIdentity PropertyDefinitionRole
  -> DraftLocation
  -> DraftReference ownerRole PropertyDefinitionRole
propertyDefinitionReference = DraftReference DraftPropertyDefinitionReference

-- | Construct a relationship source reference to an element.
relationshipSourceReference ::
     DraftIdentity ElementRole
  -> DraftLocation
  -> DraftReference RelationshipRole ElementRole
relationshipSourceReference = DraftReference DraftRelationshipSourceReference

-- | Construct a relationship target reference to an element.
relationshipTargetReference ::
     DraftIdentity ElementRole
  -> DraftLocation
  -> DraftReference RelationshipRole ElementRole
relationshipTargetReference = DraftReference DraftRelationshipTargetReference

-- | Construct a View-node reference to its displayed element.
viewNodeElementReference ::
     DraftIdentity ElementRole
  -> DraftLocation
  -> DraftReference ViewNodeRole ElementRole
viewNodeElementReference = DraftReference DraftViewNodeElementReference

-- | Construct a View-connection reference to its relationship.
viewConnectionRelationshipReference ::
     DraftIdentity RelationshipRole
  -> DraftLocation
  -> DraftReference ViewConnectionRole RelationshipRole
viewConnectionRelationshipReference =
  DraftReference DraftViewConnectionRelationshipReference

-- | Construct a View-connection reference to its source node.
viewConnectionSourceReference ::
     DraftIdentity ViewNodeRole
  -> DraftLocation
  -> DraftReference ViewConnectionRole ViewNodeRole
viewConnectionSourceReference =
  DraftReference DraftViewConnectionSourceReference

-- | Construct a View-connection reference to its target node.
viewConnectionTargetReference ::
     DraftIdentity ViewNodeRole
  -> DraftLocation
  -> DraftReference ViewConnectionRole ViewNodeRole
viewConnectionTargetReference =
  DraftReference DraftViewConnectionTargetReference

-- | Runtime native field represented by the role-safe reference.
draftReferenceField ::
     DraftReference ownerRole targetRole -> DraftReferenceFieldValue
draftReferenceField = referenceFieldValue . draftReferenceFieldValue

-- | Exact target identity observations retained by the reference.
draftReferenceIdentity ::
     DraftReference ownerRole targetRole -> DraftIdentity targetRole
draftReferenceIdentity = draftReferenceIdentityValue

-- | Exact source location of the reference observation.
draftReferenceLocation :: DraftReference ownerRole targetRole -> DraftLocation
draftReferenceLocation = draftReferenceLocationValue

-- | Native record family required by the role-safe reference.
draftReferenceExpectedFamily ::
     DraftReference ownerRole targetRole -> DraftRecordFamilyValue
draftReferenceExpectedFamily =
  recordFamilyValue . referenceExpectedFamily . draftReferenceFieldValue

-- | Consume one role-safe reference without exposing its constructor.
foldDraftReference ::
     (DraftReferenceFieldValue -> DraftIdentity targetRole -> DraftLocation -> result)
  -> DraftReference ownerRole targetRole
  -> result
foldDraftReference consume reference =
  consume
    (draftReferenceField reference)
    (draftReferenceIdentityValue reference)
    (draftReferenceLocationValue reference)

-- | Retain direct scalar observations as a property key.
directPropertyKey :: [DraftScalar] -> DraftPropertyKey ownerRole
directPropertyKey = DraftDirectPropertyKey

-- | Use one role-safe property-definition reference as key evidence.
propertyDefinitionKey ::
     DraftReference ownerRole PropertyDefinitionRole
  -> DraftPropertyKey ownerRole
propertyDefinitionKey = DraftPropertyDefinitionKey

-- | Consume direct or definition-backed property-key evidence.
foldDraftPropertyKey ::
     ([DraftScalar] -> result)
  -> (DraftReference ownerRole PropertyDefinitionRole -> result)
  -> DraftPropertyKey ownerRole
  -> result
foldDraftPropertyKey direct referenced key =
  case key of
    DraftDirectPropertyKey values -> direct values
    DraftPropertyDefinitionKey reference -> referenced reference

-- | Construct one property observation without interpreting its key or values.
draftProperty ::
     DraftPropertyKey ownerRole
  -> [DraftScalar]
  -> DraftLocation
  -> [DraftOpaqueEvidence]
  -> DraftProperty ownerRole
draftProperty = mkDraftProperty

-- | Exact direct or definition-backed key evidence.
draftPropertyKey :: DraftProperty ownerRole -> DraftPropertyKey ownerRole
draftPropertyKey = draftPropertyKeyValue

-- | All scalar values retained for the property observation.
draftPropertyValues :: DraftProperty ownerRole -> [DraftScalar]
draftPropertyValues = draftPropertyValuesValue

-- | Exact source location of the property observation.
draftPropertyLocation :: DraftProperty ownerRole -> DraftLocation
draftPropertyLocation = draftPropertyLocationValue

-- | Unrecognized property content retained for provenance.
draftPropertyOpaqueEvidence :: DraftProperty ownerRole -> [DraftOpaqueEvidence]
draftPropertyOpaqueEvidence = draftPropertyOpaqueEvidenceValue

-- | Construct a native name without assigning O2I meaning.
draftNativeName :: Maybe Text -> Text -> DraftNativeName
draftNativeName = DraftNativeName

-- | Optional native namespace of the name.
draftNativeNamespace :: DraftNativeName -> Maybe Text
draftNativeNamespace = draftNativeNamespaceValue

-- | Native local component of the name.
draftNativeLocalName :: DraftNativeName -> Text
draftNativeLocalName = draftNativeLocalNameValue

-- | Canonical witnesses for opaque attribute and child positions.
opaqueAttribute, opaqueChild :: DraftOpaquePosition
opaqueAttribute = DraftOpaqueAttribute

opaqueChild = DraftOpaqueChild

-- | Consume both closed opaque-evidence positions.
foldDraftOpaquePosition :: result -> result -> DraftOpaquePosition -> result
foldDraftOpaquePosition attribute child position =
  case position of
    DraftOpaqueAttribute -> attribute
    DraftOpaqueChild -> child

-- | Retain one unrecognized native observation and exact provenance.
draftOpaqueEvidence ::
     DraftOpaquePosition
  -> DraftNativeName
  -> [DraftScalar]
  -> DraftLocation
  -> DraftOpaqueEvidence
draftOpaqueEvidence = DraftOpaqueEvidence

-- | Native position of the unrecognized observation.
draftOpaquePosition :: DraftOpaqueEvidence -> DraftOpaquePosition
draftOpaquePosition = draftOpaquePositionValue

-- | Native name of the unrecognized observation.
draftOpaqueName :: DraftOpaqueEvidence -> DraftNativeName
draftOpaqueName = draftOpaqueNameValue

-- | Scalar content retained for the unrecognized observation.
draftOpaqueScalars :: DraftOpaqueEvidence -> [DraftScalar]
draftOpaqueScalars = draftOpaqueScalarsValue

-- | Exact source location of the unrecognized observation.
draftOpaqueLocation :: DraftOpaqueEvidence -> DraftLocation
draftOpaqueLocation = draftOpaqueLocationValue

-- | Construct a path step from a zero-based equal-name sibling index.
draftPathStep :: DraftNativeName -> Natural -> DraftPathStep
draftPathStep name zeroBasedOrdinal = DraftPathStep name (zeroBasedOrdinal + 1)

-- | Native name identifying the path step.
draftPathStepName :: DraftPathStep -> DraftNativeName
draftPathStepName = draftPathStepNameValue

-- | One-based equal-name sibling ordinal retained in the path.
draftPathStepOrdinal :: DraftPathStep -> Natural
draftPathStepOrdinal = draftPathStepOrdinalValue

-- | Construct a non-empty source path.
draftSourcePath :: DraftPathStep -> [DraftPathStep] -> DraftSourcePath
draftSourcePath = DraftSourcePath

-- | Consume the non-empty path as its first step and remaining steps.
foldDraftSourcePath ::
     (DraftPathStep -> [DraftPathStep] -> result) -> DraftSourcePath -> result
foldDraftSourcePath consume (DraftSourcePath first rest) = consume first rest

-- | Construct an exact source location with an optional span.
draftLocation :: DraftSourcePath -> Maybe DraftSourceSpan -> DraftLocation
draftLocation = DraftLocation

-- | Non-empty source path of the observation.
draftLocationPath :: DraftLocation -> DraftSourcePath
draftLocationPath = draftLocationPathValue

-- | Optional source span of the observation.
draftLocationSpan :: DraftLocation -> Maybe DraftSourceSpan
draftLocationSpan = draftLocationSpanValue

-- | Construct one source position without normalizing coordinates.
draftSourcePosition ::
     Natural -> Natural -> Maybe Natural -> DraftSourcePosition
draftSourcePosition = DraftSourcePosition

-- | Source line retained for the position.
draftSourceLine :: DraftSourcePosition -> Natural
draftSourceLine = draftSourceLineValue

-- | Source column retained for the position.
draftSourceColumn :: DraftSourcePosition -> Natural
draftSourceColumn = draftSourceColumnValue

-- | Optional absolute source offset retained for the position.
draftSourceOffset :: DraftSourcePosition -> Maybe Natural
draftSourceOffset = draftSourceOffsetValue

-- | Construct a source span from exact start and end positions.
draftSourceSpan :: DraftSourcePosition -> DraftSourcePosition -> DraftSourceSpan
draftSourceSpan = DraftSourceSpan

-- | Exact start position of the source span.
draftSpanStart :: DraftSourceSpan -> DraftSourcePosition
draftSpanStart = draftSpanStartValue

-- | Exact end position of the source span.
draftSpanEnd :: DraftSourceSpan -> DraftSourcePosition
draftSpanEnd = draftSpanEndValue
