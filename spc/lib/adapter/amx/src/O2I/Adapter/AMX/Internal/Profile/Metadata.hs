{-# LANGUAGE OverloadedStrings #-}

-- | Direct O2I metadata, ownership syntax, and node projection.
module O2I.Adapter.AMX.Internal.Profile.Metadata
  ( MetadataKind(..)
  , metadataKind
  , hasDirectO2IMetadata
  , rawNode
  , nodeKind
  , representationCompatible
  , candidateDefects
  , projectRootProfile
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.Inspection.Cardinality
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Concrete O2I metadata category before type refinement.
data MetadataKind
  = ContextMetadata
  | PrimitiveMetadata
  | StructuringMetadata
  | SituationAnchorMetadata
  deriving (Eq, Show)

-- | Resolve one unique direct @o2i.kind@ value.
metadataKind :: AMXElement -> Maybe MetadataKind
metadataKind element =
  singleMetadataValue "o2i.kind" element >>= metadataKindFromText

-- | Project all reached metadata and ownership violations for one candidate.
candidateDefects ::
     Environment -> AMXElement -> [DeferredProfileDefect AMXProfileDefect]
candidateDefects environment element =
  map (deferCandidate occurrence) (metadataDefects element ++ ownershipDefects)
    ++ representationDefects
  where
    occurrence = nodeOccurrence element
    kind = metadataKind element
    ownerships = incomingOwnerships environment element
    ownershipDefects =
      case kind of
        Just PrimitiveMetadata -> ownedDefects element ownerships
        Just StructuringMetadata -> ownedDefects element ownerships
        Just ContextMetadata -> ownerlessDefects element ownerships
        Just SituationAnchorMetadata -> ownerlessDefects element ownerships
        Nothing -> []
    representationDefects =
      case nodeKind environment element of
        Just resolvedKind
          | not (representationCompatible element (Just resolvedKind)) ->
            [ deferCandidate
                occurrence
                (Located
                   (amxElementLocation element)
                   (IncompatibleElementRepresentation
                      (displayId element)
                      (expectedElementRepresentation resolvedKind)
                      (actualElementRepresentation element)))
            ]
        _ -> []

metadataDefects :: AMXElement -> [Located AMXProfileDefect]
metadataDefects element =
  unsupported ++ kindDefects ++ typeDefects ++ compatibilityDefects
  where
    identifier = displayId element
    o2iProperties =
      [ (property, key, propertyValue property)
      | property <- elementDirectProperties element
      , let key = propertyKey property
      , "o2i." `Text.isPrefixOf` key
      ]
    unsupported =
      [ Located
        (propertyLocation key property)
        (UnsupportedO2IMetadataKey identifier key)
      | (property, key, _) <- o2iProperties
      , key `notElem` ["o2i.kind", "o2i.type"]
      ]
    kindProperties = filter (\(_, key, _) -> key == "o2i.kind") o2iProperties
    typeProperties = filter (\(_, key, _) -> key == "o2i.type") o2iProperties
    kindDefects =
      case kindProperties of
        [] -> [Located (amxElementLocation element) (MissingO2IKind identifier)]
        [(property, _, value)]
          | metadataKind element == Nothing ->
            [ Located
                (propertyLocation "o2i.kind" property)
                (UnknownO2IKind identifier value)
            ]
        [_] -> []
        first:second:rest ->
          [ Located
              (propertyLocation "o2i.kind" (firstOfTriple first))
              (DuplicateO2IKind
                 identifier
                 (third first :| map third (second : rest)))
          ]
    typeDefects =
      case typeProperties of
        [] -> [Located (amxElementLocation element) (MissingO2IType identifier)]
        [_] -> []
        first:second:rest ->
          [ Located
              (propertyLocation "o2i.type" (firstOfTriple first))
              (DuplicateO2IType
                 identifier
                 (third first :| map third (second : rest)))
          ]
    compatibilityDefects =
      case (kindProperties, typeProperties) of
        ([(_, _, kindValue)], [(typeProperty, _, typeValue)])
          | metadataKindFromText kindValue /= Nothing
              && declaredType kindValue typeValue == Nothing ->
            [ Located
                (propertyLocation "o2i.type" typeProperty)
                (InvalidO2ITypeForKind identifier kindValue typeValue)
            ]
        _ -> []

ownedDefects :: AMXElement -> [AMXElement] -> [Located AMXProfileDefect]
ownedDefects element ownerships =
  case ownerships of
    [] -> [Located (amxElementLocation element) (MissingOwnership identifier)]
    [_] -> []
    first:rest ->
      [ Located
          (amxElementLocation element)
          (DuplicateOwnership identifier (fmap ownerIdentifier (first :| rest)))
      ]
  where
    identifier = displayId element
    ownerIdentifier relationship =
      maybe
        "<missing>"
        id
        (elementAttribute (ExpandedQName Nothing "source") relationship)

ownerlessDefects :: AMXElement -> [AMXElement] -> [Located AMXProfileDefect]
ownerlessDefects element ownerships =
  [ Located
    (amxElementLocation relationship)
    (OwnershipOnOwnerlessKind (displayId element))
  | relationship <- ownerships
  ]

deferCandidate ::
     OccurrenceId
  -> Located AMXProfileDefect
  -> DeferredProfileDefect AMXProfileDefect
deferCandidate occurrence defect =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = defect
    }

-- | Project one declaration only from persisted, unique profile facts.
rawNode :: Environment -> AMXElement -> Maybe RawNode
rawNode environment element = do
  identifier <- RawNodeId <$> elementId element
  kindValue <- singleMetadataValue "o2i.kind" element
  typeValue <- singleMetadataValue "o2i.type" element
  case declaredType kindValue typeValue of
    Just (ContextType context) -> Just (RawContextNode identifier context)
    Just (PrimitiveType primitive) -> do
      owner <- uniqueOwnership environment element
      ownerId <-
        RawNodeId <$> elementAttribute (ExpandedQName Nothing "source") owner
      Just (RawPrimitiveNode identifier ownerId primitive)
    Just (StructuringType structuring) -> do
      owner <- uniqueOwnership environment element
      ownerId <-
        RawNodeId <$> elementAttribute (ExpandedQName Nothing "source") owner
      Just (RawStructuringNode identifier ownerId structuring)
    Just (AnchorType anchor) -> Just (RawAnchorNode identifier anchor)
    Nothing -> Nothing

-- | Resolve the format-neutral node kind used by relation signatures.
nodeKind :: Environment -> AMXElement -> Maybe NodeKindValue
nodeKind environment element = do
  kindValue <- singleMetadataValue "o2i.kind" element
  typeValue <- singleMetadataValue "o2i.type" element
  case declaredType kindValue typeValue of
    Just (ContextType context) -> Just (ContextNodeKind context)
    Just (PrimitiveType primitive) -> do
      context <- ownerContext environment element
      Just (PrimitiveNodeKind context primitive)
    Just (StructuringType structuring) -> do
      context <- ownerContext environment element
      Just (StructuringNodeKind context structuring)
    Just (AnchorType anchor) -> Just (AnchorNodeKind anchor)
    Nothing -> Nothing

ownerContext :: Environment -> AMXElement -> Maybe Context
ownerContext environment element = do
  ownership <- uniqueOwnership environment element
  source <- elementAttribute (ExpandedQName Nothing "source") ownership
  [owner] <-
    pure (Map.findWithDefault [] source (environmentNodeIndex environment))
  kindValue <- singleMetadataValue "o2i.kind" owner
  typeValue <- singleMetadataValue "o2i.type" owner
  case declaredType kindValue typeValue of
    Just (ContextType context) -> Just context
    _ -> Nothing

data DeclaredType
  = ContextType Context
  | PrimitiveType Primitive
  | StructuringType Structuring
  | AnchorType SituationAnchor
  deriving (Eq, Show)

metadataKindFromText :: Text -> Maybe MetadataKind
metadataKindFromText value =
  case value of
    "Context" -> Just ContextMetadata
    "Primitive" -> Just PrimitiveMetadata
    "Structuring" -> Just StructuringMetadata
    "SituationAnchor" -> Just SituationAnchorMetadata
    _ -> Nothing

declaredType :: Text -> Text -> Maybe DeclaredType
declaredType kind value =
  case (kind, value) of
    ("Context", "Ethos") -> Just (ContextType Ethos)
    ("Context", "Mission") -> Just (ContextType Mission)
    ("Context", "Vision") -> Just (ContextType Vision)
    ("Context", "Strategy") -> Just (ContextType Strategy)
    ("Context", "Situation") -> Just (ContextType Situation)
    ("Context", "Need") -> Just (ContextType Need)
    ("Context", "Intervention") -> Just (ContextType Intervention)
    ("Context", "Measure") -> Just (ContextType Measure)
    ("Primitive", "Principle") -> Just (PrimitiveType Principle)
    ("Primitive", "Driver") -> Just (PrimitiveType Driver)
    ("Primitive", "Objective") -> Just (PrimitiveType Objective)
    ("Primitive", "KeyResult") -> Just (PrimitiveType KeyResult)
    ("Primitive", "KPI") -> Just (PrimitiveType KPI)
    ("Primitive", "Action") -> Just (PrimitiveType Action)
    ("Structuring", "PerformanceDimension") ->
      Just (StructuringType PerformanceDimension)
    ("SituationAnchor", "BusinessCapability") ->
      Just (AnchorType BusinessCapability)
    ("SituationAnchor", "BusinessProcess") -> Just (AnchorType BusinessProcess)
    ("SituationAnchor", "BusinessObject") -> Just (AnchorType BusinessObject)
    ("SituationAnchor", "BusinessRole") -> Just (AnchorType BusinessRole)
    ("SituationAnchor", "ValueStream") -> Just (AnchorType ValueStream)
    ("SituationAnchor", "RegulatoryConstraint") ->
      Just (AnchorType RegulatoryConstraint)
    _ -> Nothing

-- | Check exact ArchiMate element representation for a resolved O2I kind.
representationCompatible :: AMXElement -> Maybe NodeKindValue -> Bool
representationCompatible element kind =
  case (elementType element, kind) of
    (Just actual, Just expected) ->
      qNameNamespace actual == Just archiNamespace
        && qNameLocalName actual == expectedElementRepresentation expected
    _ -> False

actualElementRepresentation :: AMXElement -> Text
actualElementRepresentation element =
  case elementType element of
    Nothing -> "<unresolved>"
    Just name ->
      "{" <> maybe "" id (qNameNamespace name) <> "}" <> qNameLocalName name

-- | Resolve the exact direct root profile and independent legacy defects.
projectRootProfile ::
     AMXDocument
  -> (RootProjection AMXProfileDefect, [DeferredProfileDefect AMXProfileDefect])
projectRootProfile document = (root, legacyDefects)
  where
    model = amxDocumentRoot document
    profileProperties = directProperties "o2i.profile" model
    profileValues = map (propertyValue . fst) profileProperties
    observed =
      case profileValues of
        [] -> NoO2IProfile
        [value] -> OneO2IProfile value
        first:second:rest -> MultipleO2IProfiles (atLeastTwo first second rest)
    rootDefects =
      case profileProperties of
        [] -> [Located (amxElementLocation model) MissingO2IProfile]
        [(property, _)]
          | propertyValue property == "0.2" -> []
          | otherwise ->
            [ Located
                (propertyLocation "o2i.profile" property)
                (UnsupportedO2IProfile (propertyValue property))
            ]
        first:rest ->
          [ Located
              (propertyLocation "o2i.profile" (fst first))
              (DuplicateO2IProfile
                 (propertyValue (fst first) :| map (propertyValue . fst) rest))
          ]
            ++ [ Located
                 (propertyLocation "o2i.profile" property)
                 (UnsupportedO2IProfile (propertyValue property))
               | (property, _) <- first : rest
               , propertyValue property /= "0.2"
               ]
    root =
      case nonEmpty rootDefects of
        Just defects -> RootUnprojectable observed defects
        Nothing ->
          RootProjectable
            observed
            (resolveProfileVersion (O2IProfileVersion "0.2"))
    legacyDefects =
      [ DeferredProfileDefect
        { defectApplicability = GlobalProfileDefect
        , deferredDefect =
            Located
              (propertyLocation "version" property)
              (LegacyRootVersionProperty (propertyValue property))
        }
      | (property, _) <- directProperties "version" model
      ]

-- | Whether a declaration explicitly enters O2I candidacy.
hasDirectO2IMetadata :: AMXElement -> Bool
hasDirectO2IMetadata =
  any (Text.isPrefixOf "o2i." . propertyKey) . elementDirectProperties

singleMetadataValue :: Text -> AMXElement -> Maybe Text
singleMetadataValue key element =
  singleValue (map (propertyValue . fst) (directProperties key element))

directProperties :: Text -> AMXElement -> [(AMXElement, Text)]
directProperties key element =
  [ (property, propertyValue property)
  | property <- elementDirectProperties element
  , propertyKey property == key
  ]

propertyKey :: AMXElement -> Text
propertyKey = maybe "" id . elementAttribute (ExpandedQName Nothing "key")

propertyValue :: AMXElement -> Text
propertyValue = maybe "" id . elementAttribute (ExpandedQName Nothing "value")

propertyLocation :: Text -> AMXElement -> SourceLocation
propertyLocation key property =
  (amxElementLocation property) {locationTarget = PropertyTarget key}

singleValue :: [value] -> Maybe value
singleValue values =
  case values of
    [value] -> Just value
    _ -> Nothing

firstOfTriple :: (first, second, third) -> first
firstOfTriple (value, _, _) = value

third :: (first, second, third) -> third
third (_, _, value) = value

nonEmpty :: [value] -> Maybe (NonEmpty value)
nonEmpty values =
  case values of
    [] -> Nothing
    first:rest -> Just (first :| rest)
