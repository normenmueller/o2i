{-# LANGUAGE OverloadedStrings #-}

-- | Closed AMX defect catalog and total diagnostic projections.
module O2I.Adapter.AMX.Internal.Defect
  ( AMXDecodeDefect(..)
  , AMXViewDefect(..)
  , AMXProfileDefect(..)
  , AMXDefectTag(..)
  , amxDecodeDefectTag
  , amxViewDefectTag
  , amxProfileDefectTag
  , amxDefectTagSpec
  , amxDecodeDefectSpec
  , amxViewDefectSpec
  , amxProfileDefectSpec
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.Inspection.Adapter (ViewSelector(..))
import O2I.Inspection.Diagnostic
import O2I.Inspection.Provenance

-- | Native XML and binding defects owned by Decode.
data AMXDecodeDefect
  = MalformedXml
  | UnsafeXml
  | InvalidUtf8
  | UnsupportedXmlEncoding Text
  | UnexpectedRootQName ExpandedQName
  | MissingNativeVersion
  | UnsupportedNativeVersion Text
  deriving (Eq, Show)

-- | Exact selected-View and persisted-presentation defects.
data AMXViewDefect
  = ViewNotFound ViewSelector
  | AmbiguousViewName Text (NonEmpty Text)
  | DuplicateViewId Text (NonEmpty Text)
  | UnresolvedViewObjectReference (Maybe Text)
  | AmbiguousViewObjectReference Text (NonEmpty SourceLocation)
  | UnresolvedViewRelationshipReference (Maybe Text)
  | AmbiguousViewRelationshipReference Text (NonEmpty SourceLocation)
  | UnresolvedViewConnectionEndpoint Text (Maybe Text)
  | AmbiguousViewConnectionEndpoint Text Text (NonEmpty SourceLocation)
  | ViewConnectionEndpointMismatch Text Text Text
  deriving (Eq, Show)

-- | Concrete O2I profile defects retained until their occurrence is reached.
data AMXProfileDefect
  = MissingO2IProfile
  | DuplicateO2IProfile (NonEmpty Text)
  | UnsupportedO2IProfile Text
  | LegacyRootVersionProperty Text
  | UnsupportedO2IMetadataKey Text Text
  | MissingO2IKind Text
  | DuplicateO2IKind Text (NonEmpty Text)
  | UnknownO2IKind Text Text
  | MissingO2IType Text
  | DuplicateO2IType Text (NonEmpty Text)
  | InvalidO2ITypeForKind Text Text Text
  | IncompatibleElementRepresentation Text Text Text
  | IncompatibleRelationshipRepresentation Text Text Text
  | MissingOwnership Text
  | DuplicateOwnership Text (NonEmpty Text)
  | OwnershipOnOwnerlessKind Text
  deriving (Eq, Show)

-- | Stable finite catalog identity across all AMX defects.
data AMXDefectTag
  = MalformedXmlTag
  | UnsafeXmlTag
  | InvalidUtf8Tag
  | UnsupportedXmlEncodingTag
  | UnexpectedRootQNameTag
  | MissingNativeVersionTag
  | UnsupportedNativeVersionTag
  | ViewNotFoundTag
  | AmbiguousViewNameTag
  | DuplicateViewIdTag
  | UnresolvedViewObjectReferenceTag
  | AmbiguousViewObjectReferenceTag
  | UnresolvedViewRelationshipReferenceTag
  | AmbiguousViewRelationshipReferenceTag
  | UnresolvedViewConnectionEndpointTag
  | AmbiguousViewConnectionEndpointTag
  | ViewConnectionEndpointMismatchTag
  | MissingO2IProfileTag
  | DuplicateO2IProfileTag
  | UnsupportedO2IProfileTag
  | LegacyRootVersionPropertyTag
  | UnsupportedO2IMetadataKeyTag
  | MissingO2IKindTag
  | DuplicateO2IKindTag
  | UnknownO2IKindTag
  | MissingO2ITypeTag
  | DuplicateO2ITypeTag
  | InvalidO2ITypeForKindTag
  | IncompatibleElementRepresentationTag
  | IncompatibleRelationshipRepresentationTag
  | MissingOwnershipTag
  | DuplicateOwnershipTag
  | OwnershipOnOwnerlessKindTag
  deriving (Bounded, Enum, Eq, Ord, Show)

amxDecodeDefectTag :: AMXDecodeDefect -> AMXDefectTag
amxDecodeDefectTag defect =
  case defect of
    MalformedXml -> MalformedXmlTag
    UnsafeXml -> UnsafeXmlTag
    InvalidUtf8 -> InvalidUtf8Tag
    UnsupportedXmlEncoding _ -> UnsupportedXmlEncodingTag
    UnexpectedRootQName _ -> UnexpectedRootQNameTag
    MissingNativeVersion -> MissingNativeVersionTag
    UnsupportedNativeVersion _ -> UnsupportedNativeVersionTag

amxViewDefectTag :: AMXViewDefect -> AMXDefectTag
amxViewDefectTag defect =
  case defect of
    ViewNotFound _ -> ViewNotFoundTag
    AmbiguousViewName _ _ -> AmbiguousViewNameTag
    DuplicateViewId _ _ -> DuplicateViewIdTag
    UnresolvedViewObjectReference _ -> UnresolvedViewObjectReferenceTag
    AmbiguousViewObjectReference _ _ -> AmbiguousViewObjectReferenceTag
    UnresolvedViewRelationshipReference _ ->
      UnresolvedViewRelationshipReferenceTag
    AmbiguousViewRelationshipReference _ _ ->
      AmbiguousViewRelationshipReferenceTag
    UnresolvedViewConnectionEndpoint _ _ -> UnresolvedViewConnectionEndpointTag
    AmbiguousViewConnectionEndpoint _ _ _ -> AmbiguousViewConnectionEndpointTag
    ViewConnectionEndpointMismatch _ _ _ -> ViewConnectionEndpointMismatchTag

amxProfileDefectTag :: AMXProfileDefect -> AMXDefectTag
amxProfileDefectTag defect =
  case defect of
    MissingO2IProfile -> MissingO2IProfileTag
    DuplicateO2IProfile _ -> DuplicateO2IProfileTag
    UnsupportedO2IProfile _ -> UnsupportedO2IProfileTag
    LegacyRootVersionProperty _ -> LegacyRootVersionPropertyTag
    UnsupportedO2IMetadataKey _ _ -> UnsupportedO2IMetadataKeyTag
    MissingO2IKind _ -> MissingO2IKindTag
    DuplicateO2IKind _ _ -> DuplicateO2IKindTag
    UnknownO2IKind _ _ -> UnknownO2IKindTag
    MissingO2IType _ -> MissingO2ITypeTag
    DuplicateO2IType _ _ -> DuplicateO2ITypeTag
    InvalidO2ITypeForKind _ _ _ -> InvalidO2ITypeForKindTag
    IncompatibleElementRepresentation _ _ _ ->
      IncompatibleElementRepresentationTag
    IncompatibleRelationshipRepresentation _ _ _ ->
      IncompatibleRelationshipRepresentationTag
    MissingOwnership _ -> MissingOwnershipTag
    DuplicateOwnership _ _ -> DuplicateOwnershipTag
    OwnershipOnOwnerlessKind _ -> OwnershipOnOwnerlessKindTag

-- | Stable code and generic message for every catalog entry.
amxDefectTagSpec :: AMXDefectTag -> DiagnosticSpec
amxDefectTagSpec tag =
  case tag of
    MalformedXmlTag ->
      model "amx.decode.xml-malformed" "The input is not well-formed XML."
    UnsafeXmlTag ->
      model
        "amx.decode.xml-unsafe"
        "The input contains a DTD or a non-predefined entity."
    InvalidUtf8Tag ->
      model "amx.decode.encoding-invalid" "The input is not valid UTF-8."
    UnsupportedXmlEncodingTag ->
      model
        "amx.decode.encoding-unsupported"
        "The declared or byte-order encoding is not UTF-8."
    UnexpectedRootQNameTag ->
      model
        "amx.decode.root-qname"
        "The XML root is not the native Archi model element."
    MissingNativeVersionTag ->
      model
        "amx.decode.native-version-missing"
        "The native Archi model version is missing."
    UnsupportedNativeVersionTag ->
      model
        "amx.decode.native-version-unsupported"
        "The native Archi model version is unsupported."
    ViewNotFoundTag ->
      model "amx.view.not-found" "No View matches the exact selector."
    AmbiguousViewNameTag ->
      model
        "amx.view.name-ambiguous"
        "More than one View has the exact selected name."
    DuplicateViewIdTag ->
      model
        "amx.view.id-ambiguous"
        "More than one View has the selected stable identifier."
    UnresolvedViewObjectReferenceTag ->
      model
        "amx.view.object-unresolved"
        "A selected View object does not resolve to a model element."
    AmbiguousViewObjectReferenceTag ->
      model
        "amx.view.object-ambiguous"
        "A selected View object resolves to multiple model elements."
    UnresolvedViewRelationshipReferenceTag ->
      model
        "amx.view.connection-unresolved"
        "A selected View connection does not resolve to a relationship."
    AmbiguousViewRelationshipReferenceTag ->
      model
        "amx.view.connection-ambiguous"
        "A selected View connection resolves to multiple relationships."
    UnresolvedViewConnectionEndpointTag ->
      model
        "amx.view.endpoint-unresolved"
        "A selected View connection endpoint does not resolve."
    AmbiguousViewConnectionEndpointTag ->
      model
        "amx.view.endpoint-ambiguous"
        "A selected View connection endpoint is ambiguous."
    ViewConnectionEndpointMismatchTag ->
      model
        "amx.view.endpoint-mismatch"
        "A View connection endpoint differs from its relationship endpoint."
    MissingO2IProfileTag ->
      model
        "amx.profile.missing"
        "The direct root property o2i.profile is missing."
    DuplicateO2IProfileTag ->
      model
        "amx.profile.duplicate"
        "The direct root property o2i.profile occurs more than once."
    UnsupportedO2IProfileTag ->
      model "amx.profile.unsupported" "The O2I profile version is unsupported."
    LegacyRootVersionPropertyTag ->
      model
        "amx.profile.legacy-version-property"
        "The direct root property version is not an O2I profile alias."
    UnsupportedO2IMetadataKeyTag ->
      model
        "amx.profile.metadata-key"
        "An O2I candidate declares an unsupported metadata key."
    MissingO2IKindTag ->
      model
        "amx.profile.kind-missing"
        "An O2I candidate has no direct o2i.kind property."
    DuplicateO2IKindTag ->
      model
        "amx.profile.kind-duplicate"
        "An O2I candidate has more than one direct o2i.kind property."
    UnknownO2IKindTag ->
      model
        "amx.profile.kind-unknown"
        "An O2I candidate declares an unknown o2i.kind value."
    MissingO2ITypeTag ->
      model
        "amx.profile.type-missing"
        "An O2I candidate has no direct o2i.type property."
    DuplicateO2ITypeTag ->
      model
        "amx.profile.type-duplicate"
        "An O2I candidate has more than one direct o2i.type property."
    InvalidO2ITypeForKindTag ->
      model
        "amx.profile.type-invalid"
        "The o2i.type value is invalid for the declared o2i.kind."
    IncompatibleElementRepresentationTag ->
      model
        "amx.profile.element-representation"
        "The ArchiMate element does not realize its declared O2I type."
    IncompatibleRelationshipRepresentationTag ->
      model
        "amx.profile.relation-representation"
        "The ArchiMate relationship does not realize the O2I relation."
    MissingOwnershipTag ->
      model
        "amx.profile.ownership-missing"
        "An owned O2I candidate has no persisted ownership composition."
    DuplicateOwnershipTag ->
      model
        "amx.profile.ownership-duplicate"
        "An owned O2I candidate has multiple ownership compositions."
    OwnershipOnOwnerlessKindTag ->
      model
        "amx.profile.ownership-forbidden"
        "An ownerless O2I candidate has an ownership composition."

amxDecodeDefectSpec :: AMXDecodeDefect -> DiagnosticSpec
amxDecodeDefectSpec defect =
  addSubjects
    (decodeSubjects defect)
    (amxDefectTagSpec (amxDecodeDefectTag defect))

amxViewDefectSpec :: AMXViewDefect -> DiagnosticSpec
amxViewDefectSpec defect =
  addSubjects (viewSubjects defect) (amxDefectTagSpec (amxViewDefectTag defect))

amxProfileDefectSpec :: AMXProfileDefect -> DiagnosticSpec
amxProfileDefectSpec defect =
  addSubjects
    (profileSubjects defect)
    (amxDefectTagSpec (amxProfileDefectTag defect))

model :: Text -> Text -> DiagnosticSpec
model code message =
  diagnosticSpec
    (o2iDiagnosticCode code)
    ErrorSeverity
    ModelFinding
    message
    []
    Map.empty

addSubjects :: [DiagnosticSubject] -> DiagnosticSpec -> DiagnosticSpec
addSubjects subjects specification =
  diagnosticSpec
    (specCode specification)
    (specSeverity specification)
    (specDisposition specification)
    (specMessage specification)
    subjects
    (specData specification)

decodeSubjects :: AMXDecodeDefect -> [DiagnosticSubject]
decodeSubjects defect =
  case defect of
    MalformedXml -> []
    UnsafeXml -> []
    InvalidUtf8 -> []
    UnsupportedXmlEncoding encoding -> [subject "encoding" encoding]
    UnexpectedRootQName name -> [subject "root-qname" (qNameText name)]
    MissingNativeVersion -> []
    UnsupportedNativeVersion version -> [subject "native-version" version]

viewSubjects :: AMXViewDefect -> [DiagnosticSubject]
viewSubjects defect =
  case defect of
    ViewNotFound selector -> [subject "view-selector" (selectorText selector)]
    AmbiguousViewName name identifiers ->
      subject "view-name" name
        : map (subject "view-id") (nonEmptyList identifiers)
    DuplicateViewId identifier names ->
      subject "view-id" identifier
        : map (subject "view-name") (nonEmptyList names)
    UnresolvedViewObjectReference reference ->
      [subject "reference" (maybe "<missing>" id reference)]
    AmbiguousViewObjectReference reference _ -> [subject "reference" reference]
    UnresolvedViewRelationshipReference reference ->
      [subject "reference" (maybe "<missing>" id reference)]
    AmbiguousViewRelationshipReference reference _ ->
      [subject "reference" reference]
    UnresolvedViewConnectionEndpoint connection reference ->
      [ subject "connection" connection
      , subject "reference" (maybe "<missing>" id reference)
      ]
    AmbiguousViewConnectionEndpoint connection reference _ ->
      [subject "connection" connection, subject "reference" reference]
    ViewConnectionEndpointMismatch connection expected actual ->
      [ subject "connection" connection
      , subject "expected-endpoint" expected
      , subject "actual-endpoint" actual
      ]

profileSubjects :: AMXProfileDefect -> [DiagnosticSubject]
profileSubjects defect =
  case defect of
    MissingO2IProfile -> []
    DuplicateO2IProfile values -> map (subject "profile") (nonEmptyList values)
    UnsupportedO2IProfile version -> [subject "profile" version]
    LegacyRootVersionProperty version -> [subject "legacy-version" version]
    UnsupportedO2IMetadataKey identifier key ->
      [subject "node" identifier, subject "metadata-key" key]
    MissingO2IKind identifier -> [subject "node" identifier]
    DuplicateO2IKind identifier values ->
      subject "node" identifier : map (subject "kind") (nonEmptyList values)
    UnknownO2IKind identifier kind ->
      [subject "node" identifier, subject "kind" kind]
    MissingO2IType identifier -> [subject "node" identifier]
    DuplicateO2IType identifier values ->
      subject "node" identifier : map (subject "type") (nonEmptyList values)
    InvalidO2ITypeForKind identifier kind nodeType ->
      [subject "node" identifier, subject "kind" kind, subject "type" nodeType]
    IncompatibleElementRepresentation identifier expected actual ->
      [ subject "node" identifier
      , subject "expected-representation" expected
      , subject "actual-representation" actual
      ]
    IncompatibleRelationshipRepresentation identifier expected actual ->
      [ subject "relationship" identifier
      , subject "expected-representation" expected
      , subject "actual-representation" actual
      ]
    MissingOwnership identifier -> [subject "node" identifier]
    DuplicateOwnership identifier owners ->
      subject "node" identifier : map (subject "owner") (nonEmptyList owners)
    OwnershipOnOwnerlessKind identifier -> [subject "node" identifier]

subject :: Text -> Text -> DiagnosticSubject
subject = DiagnosticSubject

selectorText :: ViewSelector -> Text
selectorText selector =
  case selector of
    ViewByName name -> "name:" <> name
    ViewById identifier -> "id:" <> identifier

qNameText :: ExpandedQName -> Text
qNameText name =
  "{" <> maybe "" id (qNameNamespace name) <> "}" <> qNameLocalName name

nonEmptyList :: NonEmpty value -> [value]
nonEmptyList (first :| rest) = first : rest
