{-# LANGUAGE OverloadedStrings #-}

-- | Observation-complete projection from native AMX into the Profile Draft.
module O2I.Adapter.AMX.Internal.Draft
  ( projectNativeDocument
  ) where

import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as Builder
import Numeric.Natural (Natural)
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace, xsiNamespace)
import O2I.Adapter.AMX.Internal.XML.Lexical (isXmlSpace, parseQName)
import qualified O2I.ArchiMate.Profile.Draft as Draft

projectNativeDocument :: NativeDocument -> Draft.ProfileDraft
projectNativeDocument (NativeDocument root) =
  Draft.profileDraft
    (Draft.modelRootDraft
       (identity root)
       (elementLocation root)
       (rootAttributeMembers root
          <> concatMap (rootContentMembers root) (nativeElementContent root)))

rootAttributeMembers :: NativeElement -> [Draft.DraftMember Draft.ModelRootRole]
rootAttributeMembers element =
  mapMaybe (rootAttributeMember element) (nativeElementAttributes element)

rootAttributeMember ::
     NativeElement
  -> NativeAttribute
  -> Maybe (Draft.DraftMember Draft.ModelRootRole)
rootAttributeMember element attribute
  | nativeAttributeName attribute == idName = Nothing
  | nativeAttributeName attribute == nameName =
    Just
      (Draft.nameFieldMember
         [textAttribute attribute]
         (attributeLocation attribute))
  | nativeAttributeName attribute == xsiTypeName =
    Just
      (Draft.typeFieldMember
         [typeAttribute element attribute]
         (attributeLocation attribute))
  | otherwise = Just (opaqueAttributeMember attribute)

rootContentMembers ::
     NativeElement -> NativeContent -> [Draft.DraftMember Draft.ModelRootRole]
rootContentMembers owner content =
  case content of
    NativeText value -> opaqueTextMembers owner value
    NativeElementContent element
      | nativeElementName element == folderName ->
        Draft.opaqueMember (opaqueShell element) : folderMembers Nothing element
      | nativeElementName element == propertyName ->
        [Draft.propertyMember (property element)]
      | otherwise -> opaqueElementMembers element

-- The existential record roles produced by folder traversal are embedded at
-- the call site instead of escaping as a homogeneous list.
folderMembers :: Maybe Text -> NativeElement -> [Draft.DraftMember ownerRole]
folderMembers inherited folder = concatMap child (nativeElementContent folder)
  where
    folderType = attributeText typeName folder <|> inherited
    child content =
      case content of
        NativeText value -> opaqueTextMembers folder value
        NativeElementContent element
          | nativeElementName element == folderName ->
            Draft.opaqueMember (opaqueShell element)
              : folderMembers folderType element
          | nativeElementName element == elementName ->
            case folderType of
              Just "relations" ->
                [Draft.childRecordMember (relationshipRecord element)]
              Just "diagrams" -> [Draft.childRecordMember (viewRecord element)]
              _ -> [Draft.childRecordMember (elementRecord element)]
          | nativeElementName element == propertyName ->
            [Draft.propertyMember (property element)]
          | otherwise -> opaqueElementMembers element

elementRecord :: NativeElement -> Draft.ElementDraft
elementRecord element =
  Draft.elementDraft
    (identity element)
    (elementLocation element)
    (elementAttributeMembers element <> elementChildMembers element)

relationshipRecord :: NativeElement -> Draft.RelationshipDraft
relationshipRecord element =
  Draft.relationshipDraft
    (identity element)
    (elementLocation element)
    (relationshipAttributeMembers element <> relationshipChildMembers element)

viewRecord :: NativeElement -> Draft.ViewDraft
viewRecord element =
  Draft.viewDraft
    (identity element)
    (elementLocation element)
    (commonAttributeMembers element
       <> concatMap (viewContentMembers element) (nativeElementContent element))

viewNodeRecord :: NativeElement -> Draft.ViewNodeDraft
viewNodeRecord element =
  Draft.viewNodeDraft
    (identity element)
    (elementLocation element)
    (viewNodeAttributeMembers element
       <> concatMap
            (viewNodeContentMembers element)
            (nativeElementContent element))

viewConnectionRecord :: NativeElement -> Draft.ViewConnectionDraft
viewConnectionRecord element =
  Draft.viewConnectionDraft
    (identity element)
    (elementLocation element)
    (viewConnectionAttributeMembers element <> genericChildMembers element)

commonAttributeMembers :: NativeElement -> [Draft.DraftMember recordRole]
commonAttributeMembers element =
  mapMaybe (commonAttributeMember element) (nativeElementAttributes element)

commonAttributeMember ::
     NativeElement -> NativeAttribute -> Maybe (Draft.DraftMember recordRole)
commonAttributeMember element attribute
  | nativeAttributeName attribute == idName = Nothing
  | nativeAttributeName attribute == xsiTypeName =
    Just
      (Draft.typeFieldMember
         [typeAttribute element attribute]
         (attributeLocation attribute))
  | nativeAttributeName attribute == nameName =
    Just
      (Draft.nameFieldMember
         [textAttribute attribute]
         (attributeLocation attribute))
  | otherwise = Just (opaqueAttributeMember attribute)

elementAttributeMembers ::
     NativeElement -> [Draft.DraftMember Draft.ElementRole]
elementAttributeMembers = commonAttributeMembers

relationshipAttributeMembers ::
     NativeElement -> [Draft.DraftMember Draft.RelationshipRole]
relationshipAttributeMembers element =
  mapMaybe member (nativeElementAttributes element)
  where
    member attribute
      | nativeAttributeName attribute == idName = Nothing
      | nativeAttributeName attribute == xsiTypeName =
        Just
          (Draft.typeFieldMember
             [typeAttribute element attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == nameName =
        Just
          (Draft.nameFieldMember
             [textAttribute attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == directedName =
        Just
          (Draft.directedFieldMember
             [booleanOrText attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == strengthName
          && typeNameOf element == Just influenceRelationshipType =
        Just
          (Draft.influenceStrengthFieldMember
             [textAttribute attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == sourceName =
        Just
          (Draft.referenceMember
             (Draft.relationshipSourceReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | nativeAttributeName attribute == targetName =
        Just
          (Draft.referenceMember
             (Draft.relationshipTargetReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | otherwise = Just (opaqueAttributeMember attribute)

viewNodeAttributeMembers ::
     NativeElement -> [Draft.DraftMember Draft.ViewNodeRole]
viewNodeAttributeMembers element =
  mapMaybe member (nativeElementAttributes element)
  where
    member attribute
      | nativeAttributeName attribute == idName = Nothing
      | nativeAttributeName attribute == xsiTypeName =
        Just
          (Draft.typeFieldMember
             [typeAttribute element attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == nameName =
        Just
          (Draft.nameFieldMember
             [textAttribute attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == archimateElementName =
        Just
          (Draft.referenceMember
             (Draft.viewNodeElementReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | otherwise = Just (opaqueAttributeMember attribute)

viewConnectionAttributeMembers ::
     NativeElement -> [Draft.DraftMember Draft.ViewConnectionRole]
viewConnectionAttributeMembers element =
  mapMaybe member (nativeElementAttributes element)
  where
    member attribute
      | nativeAttributeName attribute == idName = Nothing
      | nativeAttributeName attribute == xsiTypeName =
        Just
          (Draft.typeFieldMember
             [typeAttribute element attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == nameName =
        Just
          (Draft.nameFieldMember
             [textAttribute attribute]
             (attributeLocation attribute))
      | nativeAttributeName attribute == archimateRelationshipName =
        Just
          (Draft.referenceMember
             (Draft.viewConnectionRelationshipReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | nativeAttributeName attribute == sourceName =
        Just
          (Draft.referenceMember
             (Draft.viewConnectionSourceReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | nativeAttributeName attribute == targetName =
        Just
          (Draft.referenceMember
             (Draft.viewConnectionTargetReference
                (referenceIdentity attribute)
                (attributeLocation attribute)))
      | otherwise = Just (opaqueAttributeMember attribute)

elementChildMembers :: NativeElement -> [Draft.DraftMember Draft.ElementRole]
elementChildMembers owner = concatMap child (nativeElementContent owner)
  where
    child content =
      case content of
        NativeText value -> opaqueTextMembers owner value
        NativeElementContent element
          | nativeElementName element == documentationName ->
            [ Draft.elementDocumentationFieldMember
                (documentationScalars element)
                (elementLocation element)
            ]
          | nativeElementName element == propertyName ->
            [Draft.propertyMember (property element)]
          | otherwise -> opaqueElementMembers element

relationshipChildMembers ::
     NativeElement -> [Draft.DraftMember Draft.RelationshipRole]
relationshipChildMembers owner = concatMap child (nativeElementContent owner)
  where
    child content =
      case content of
        NativeText value -> opaqueTextMembers owner value
        NativeElementContent element
          | nativeElementName element == documentationName ->
            [ Draft.relationshipDocumentationFieldMember
                (documentationScalars element)
                (elementLocation element)
            ]
          | nativeElementName element == propertyName ->
            [Draft.propertyMember (property element)]
          | otherwise -> opaqueElementMembers element

genericChildMembers :: NativeElement -> [Draft.DraftMember ownerRole]
genericChildMembers owner =
  concatMap (opaqueContentMembers owner) (nativeElementContent owner)

viewContentMembers ::
     NativeElement -> NativeContent -> [Draft.DraftMember Draft.ViewRole]
viewContentMembers owner content =
  case content of
    NativeText value -> opaqueTextMembers owner value
    NativeElementContent element
      | nativeElementName element == childName && isGroup element ->
        groupMembers element
      | nativeElementName element == childName && isViewNode element ->
        [Draft.childRecordMember (viewNodeRecord element)]
      | nativeElementName element == sourceConnectionName ->
        [Draft.childRecordMember (viewConnectionRecord element)]
      | otherwise -> opaqueElementMembers element

viewNodeContentMembers ::
     NativeElement -> NativeContent -> [Draft.DraftMember Draft.ViewNodeRole]
viewNodeContentMembers owner content =
  case content of
    NativeText value -> opaqueTextMembers owner value
    NativeElementContent element
      | nativeElementName element == sourceConnectionName ->
        [Draft.childRecordMember (viewConnectionRecord element)]
      | nativeElementName element == childName && isGroup element ->
        groupMembers element
      | nativeElementName element == childName && isViewNode element ->
        [Draft.childRecordMember (viewNodeRecord element)]
      | otherwise -> opaqueElementMembers element

groupMembers :: NativeElement -> [Draft.DraftMember ownerRole]
groupMembers element =
  Draft.opaqueMember (opaqueShell element)
    : concatMap (viewTreeMembers element) (nativeElementContent element)

viewTreeMembers ::
     NativeElement -> NativeContent -> [Draft.DraftMember ownerRole]
viewTreeMembers owner content =
  case content of
    NativeText value -> opaqueTextMembers owner value
    NativeElementContent element
      | nativeElementName element == sourceConnectionName ->
        [Draft.childRecordMember (viewConnectionRecord element)]
      | nativeElementName element == childName && isGroup element ->
        groupMembers element
      | nativeElementName element == childName && isViewNode element ->
        [Draft.childRecordMember (viewNodeRecord element)]
      | otherwise -> opaqueElementMembers element

isViewNode :: NativeElement -> Bool
isViewNode element =
  typeNameOf element == Just diagramObjectType
    || not (null (lookupAttribute archimateElementName element))

isGroup :: NativeElement -> Bool
isGroup element = typeNameOf element == Just groupType

property :: NativeElement -> Draft.DraftProperty ownerRole
property element =
  Draft.draftProperty
    (Draft.directPropertyKey (attributeScalars keyName element))
    (attributeScalars valueName element)
    (elementLocation element)
    (mapMaybe opaquePropertyPart (nativeElementAttributes element)
       <> concatMap
            (opaqueContentEvidence element)
            (nativeElementContent element))
  where
    opaquePropertyPart attribute
      | nativeAttributeName attribute `elem` [keyName, valueName] = Nothing
      | otherwise = Just (opaqueAttributeEvidence attribute)

identity :: NativeElement -> Draft.DraftIdentity recordRole
identity element = Draft.draftIdentity (attributeScalars idName element)

referenceIdentity :: NativeAttribute -> Draft.DraftIdentity targetRole
referenceIdentity attribute = Draft.draftIdentity [textAttribute attribute]

attributeScalars :: NativeName -> NativeElement -> [Draft.DraftScalar]
attributeScalars name = map textAttribute . lookupAttribute name

textAttribute :: NativeAttribute -> Draft.DraftScalar
textAttribute attribute =
  Draft.draftTextScalar
    (nativeAttributeValue attribute)
    (attributeLocation attribute)

booleanOrText :: NativeAttribute -> Draft.DraftScalar
booleanOrText attribute =
  case nativeAttributeValue attribute of
    "true" -> boolean True
    "1" -> boolean True
    "false" -> boolean False
    "0" -> boolean False
    _ -> textAttribute attribute
  where
    boolean value = Draft.draftBooleanScalar value (attributeLocation attribute)

typeAttribute :: NativeElement -> NativeAttribute -> Draft.DraftScalar
typeAttribute element attribute =
  case resolveNativeName element (nativeAttributeValue attribute) of
    Just name ->
      Draft.draftNativeNameScalar (draftName name) (attributeLocation attribute)
    Nothing -> textAttribute attribute

resolveNativeName :: NativeElement -> Text -> Maybe NativeName
resolveNativeName element lexical =
  case parseQName lexical of
    Just (Just prefix, local) -> do
      namespace <- Map.lookup prefix (nativeElementNamespaces element)
      pure (NativeName (Just namespace) local)
    Just (Nothing, local) -> Just (NativeName Nothing local)
    Nothing -> Nothing

typeNameOf :: NativeElement -> Maybe NativeName
typeNameOf element = do
  attribute <-
    find
      ((== xsiTypeName) . nativeAttributeName)
      (nativeElementAttributes element)
  resolveNativeName element (nativeAttributeValue attribute)

attributeText :: NativeName -> NativeElement -> Maybe Text
attributeText name element =
  nativeAttributeValue
    <$> find ((== name) . nativeAttributeName) (nativeElementAttributes element)

opaqueAttributeMember :: NativeAttribute -> Draft.DraftMember recordRole
opaqueAttributeMember = Draft.opaqueMember . opaqueAttributeEvidence

opaqueAttributeEvidence :: NativeAttribute -> Draft.DraftOpaqueEvidence
opaqueAttributeEvidence attribute =
  Draft.draftOpaqueEvidence
    Draft.opaqueAttribute
    (draftName (nativeAttributeName attribute))
    [textAttribute attribute]
    (attributeLocation attribute)

opaqueChildEvidence :: NativeElement -> Draft.DraftOpaqueEvidence
opaqueChildEvidence element =
  Draft.draftOpaqueEvidence
    Draft.opaqueChild
    (draftName (nativeElementName element))
    (map opaqueAttributeScalar (nativeElementAttributes element))
    (elementLocation element)

opaqueElementMembers :: NativeElement -> [Draft.DraftMember ownerRole]
opaqueElementMembers = map Draft.opaqueMember . opaqueElementEvidence

opaqueElementEvidence :: NativeElement -> [Draft.DraftOpaqueEvidence]
opaqueElementEvidence element =
  opaqueChildEvidence element
    : concatMap (opaqueContentEvidence element) (nativeElementContent element)

opaqueTextEvidence :: NativeElement -> Text -> Draft.DraftOpaqueEvidence
opaqueTextEvidence owner value =
  Draft.draftOpaqueEvidence
    Draft.opaqueChild
    (draftName (nativeElementName owner))
    [Draft.draftTextScalar value (elementLocation owner)]
    (elementLocation owner)

opaqueTextMembers :: NativeElement -> Text -> [Draft.DraftMember ownerRole]
opaqueTextMembers owner value
  | Text.all isXmlSpace value = []
  | otherwise = [Draft.opaqueMember (opaqueTextEvidence owner value)]

opaqueContentMembers ::
     NativeElement -> NativeContent -> [Draft.DraftMember ownerRole]
opaqueContentMembers owner content =
  map Draft.opaqueMember (opaqueContentEvidence owner content)

opaqueContentEvidence ::
     NativeElement -> NativeContent -> [Draft.DraftOpaqueEvidence]
opaqueContentEvidence owner content =
  case content of
    NativeText value
      | Text.all isXmlSpace value -> []
      | otherwise -> [opaqueTextEvidence owner value]
    NativeElementContent element -> opaqueElementEvidence element

opaqueShell :: NativeElement -> Draft.DraftOpaqueEvidence
opaqueShell element =
  Draft.draftOpaqueEvidence
    Draft.opaqueChild
    (draftName (nativeElementName element))
    (map opaqueAttributeScalar (nativeElementAttributes element))
    (elementLocation element)

opaqueAttributeScalar :: NativeAttribute -> Draft.DraftScalar
opaqueAttributeScalar attribute =
  Draft.draftOtherScalar
    (renderName (nativeAttributeName attribute))
    (nativeAttributeValue attribute)
    (attributeLocation attribute)

documentationScalars :: NativeElement -> [Draft.DraftScalar]
documentationScalars element =
  [ Draft.draftTextScalar
      (LazyText.toStrict (Builder.toLazyText (documentationBuilder element)))
      (elementLocation element)
  ]

documentationBuilder :: NativeElement -> Builder.Builder
documentationBuilder = foldMap content . nativeElementContent
  where
    content nativeContent =
      case nativeContent of
        NativeText value -> Builder.fromText value
        NativeElementContent child -> documentationBuilder child

elementLocation :: NativeElement -> Draft.DraftLocation
elementLocation = location . nativeElementPath

attributeLocation :: NativeAttribute -> Draft.DraftLocation
attributeLocation = location . nativeAttributePath

location :: NativePath -> Draft.DraftLocation
location path =
  case map pathStep path of
    first:rest -> Draft.draftLocation (Draft.draftSourcePath first rest) Nothing
    [] ->
      Draft.draftLocation
        (Draft.draftSourcePath
           (Draft.draftPathStep (Draft.draftNativeName Nothing "model") 0)
           [])
        Nothing

pathStep :: NativePathStep -> Draft.DraftPathStep
pathStep step =
  Draft.draftPathStep
    (draftName (nativePathStepName step))
    (fromIntegral (max 1 (nativePathStepOrdinal step) - 1) :: Natural)

draftName :: NativeName -> Draft.DraftNativeName
draftName name =
  Draft.draftNativeName (nativeNameNamespace name) (nativeNameLocal name)

renderName :: NativeName -> Text
renderName name =
  maybe "" (\namespace -> "{" <> namespace <> "}") (nativeNameNamespace name)
    <> nativeNameLocal name

idName, nameName, typeName, directedName, strengthName :: NativeName
idName = NativeName Nothing "id"

nameName = NativeName Nothing "name"

typeName = NativeName Nothing "type"

directedName = NativeName Nothing "directed"

strengthName = NativeName Nothing "strength"

keyName, valueName, sourceName, targetName :: NativeName
keyName = NativeName Nothing "key"

valueName = NativeName Nothing "value"

sourceName = NativeName Nothing "source"

targetName = NativeName Nothing "target"

archimateElementName, archimateRelationshipName, xsiTypeName :: NativeName
archimateElementName = NativeName Nothing "archimateElement"

archimateRelationshipName = NativeName Nothing "archimateRelationship"

xsiTypeName = NativeName (Just xsiNamespace) "type"

folderName, elementName, propertyName, documentationName :: NativeName
folderName = NativeName Nothing "folder"

elementName = NativeName Nothing "element"

propertyName = NativeName Nothing "property"

documentationName = NativeName Nothing "documentation"

childName, sourceConnectionName :: NativeName
childName = NativeName Nothing "child"

sourceConnectionName = NativeName Nothing "sourceConnection"

groupType, diagramObjectType, influenceRelationshipType :: NativeName
groupType = NativeName (Just archiNamespace) "Group"

diagramObjectType = NativeName (Just archiNamespace) "DiagramObject"

influenceRelationshipType =
  NativeName (Just archiNamespace) "InfluenceRelationship"

(<|>) :: Maybe value -> Maybe value -> Maybe value
left <|> right =
  case left of
    Just value -> Just value
    Nothing -> right
