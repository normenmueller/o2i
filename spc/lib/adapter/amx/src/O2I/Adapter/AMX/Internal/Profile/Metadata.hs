{-# LANGUAGE OverloadedStrings #-}

-- | Direct O2I metadata, contextualization syntax, and node projection.
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
import O2I.Adapter.AMX.Internal.Profile.Commitment
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Profile.Property
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.ArchiMate.Profile
import O2I.Inspection.Cardinality
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Resolve one unique direct @o2i.kind@ value.
metadataKind :: AMXElement -> Maybe MetadataKind
metadataKind element =
  singleMetadataValue kindKey element >>= metadataKindFromText
  where
    kindKey = carrierKindKey (contractMetadata profileContract)

-- | Project metadata and Context Ownership violations for one candidate.
candidateDefects ::
     Environment
  -> AMXElement
  -> [DeferredProfileDefect SourcePosition AMXProfileDefect]
candidateDefects environment element =
  map (deferCandidate occurrence) (metadataDefects element ++ ownershipDefects)
    ++ representationDefects
  where
    occurrence = nodeOccurrence element
    ownerships = incomingOwnerships environment element
    ownershipDefects =
      case fmap
             (carrierMappingOwnership . carrierMappingFor)
             (declaredCarrierOf element) of
        Just requirement
          | requirementIsRequired requirement -> ownedDefects element ownerships
          | requirementIsForbidden requirement ->
            ownerlessDefects element ownerships
        Nothing -> []
        Just _ -> []
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

metadataDefects :: AMXElement -> [Located SourcePosition AMXProfileDefect]
metadataDefects element =
  unsupported
    ++ kindDefects
    ++ typeDefects
    ++ compatibilityDefects
    ++ commitmentResolutionDefects (decodeCommitment element)
  where
    metadata = contractMetadata profileContract
    kindKey = carrierKindKey metadata
    typeKey = carrierTypeKey metadata
    commitmentKey = carrierCommitmentKey metadata
    allowedKeys = [kindKey, typeKey, commitmentKey]
    identifier = displayId element
    observedO2IProperties =
      [ (property, key, propertyValue property)
      | property <- elementDirectProperties element
      , let key = propertyKey property
      , "o2i." `Text.isPrefixOf` key
      ]
    unsupported =
      [ Located
        (propertyLocation key property)
        (UnsupportedO2IMetadataKey identifier key)
      | (property, key, _) <- observedO2IProperties
      , key `notElem` allowedKeys
      ]
    kindProperties =
      filter (\(_, key, _) -> key == kindKey) observedO2IProperties
    typeProperties =
      filter (\(_, key, _) -> key == typeKey) observedO2IProperties
    kindDefects =
      case kindProperties of
        [] -> [Located (amxElementLocation element) (MissingO2IKind identifier)]
        [(property, _, value)]
          | metadataKind element == Nothing ->
            [ Located
                (propertyLocation kindKey property)
                (UnknownO2IKind identifier value)
            ]
        [_] -> []
        first:second:rest ->
          [ Located
              (propertyLocation kindKey (firstOfTriple first))
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
              (propertyLocation typeKey (firstOfTriple first))
              (DuplicateO2IType
                 identifier
                 (third first :| map third (second : rest)))
          ]
    compatibilityDefects =
      case (kindProperties, typeProperties) of
        ([(_, _, kindValue)], [(typeProperty, _, typeValue)])
          | metadataKindFromText kindValue /= Nothing
              && declaredCarrier kindValue typeValue == Nothing ->
            [ Located
                (propertyLocation typeKey typeProperty)
                (InvalidO2ITypeForKind identifier kindValue typeValue)
            ]
        _ -> []

ownedDefects ::
     AMXElement -> [AMXElement] -> [Located SourcePosition AMXProfileDefect]
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
        (elementAttribute (expandedQName Nothing 's' "ource") relationship)

ownerlessDefects ::
     AMXElement -> [AMXElement] -> [Located SourcePosition AMXProfileDefect]
ownerlessDefects element ownerships =
  [ Located
    (amxElementLocation relationship)
    (OwnershipOnOwnerlessKind (displayId element))
  | relationship <- ownerships
  ]

deferCandidate ::
     OccurrenceId
  -> Located SourcePosition AMXProfileDefect
  -> DeferredProfileDefect SourcePosition AMXProfileDefect
deferCandidate occurrence defect =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = defect
    }

-- | Project one declaration only from persisted, unique profile facts.
rawNode :: Environment -> AMXElement -> Maybe RawNode
rawNode environment element = do
  identifier <- RawNodeId <$> elementId element
  case declaredCarrierOf element of
    Just (ContextCarrier context) -> Just (RawContextNode identifier context)
    Just (PrimitiveCarrier primitive) -> do
      owner <- uniqueOwnership environment element
      ownerId <-
        RawNodeId <$> elementAttribute (expandedQName Nothing 's' "ource") owner
      Just (RawPrimitiveNode identifier ownerId primitive)
    Just (StructuringCarrier structuring) -> do
      owner <- uniqueOwnership environment element
      ownerId <-
        RawNodeId <$> elementAttribute (expandedQName Nothing 's' "ource") owner
      Just (RawStructuringNode identifier ownerId structuring)
    Just (SituationAnchorCarrier anchor) ->
      Just (RawAnchorNode identifier anchor)
    Nothing -> Nothing

-- | Resolve the format-neutral node kind used by relation signatures.
nodeKind :: Environment -> AMXElement -> Maybe NodeKindValue
nodeKind environment element = do
  case declaredCarrierOf element of
    Just (ContextCarrier context) -> Just (ContextNodeKind context)
    Just (PrimitiveCarrier primitive) -> do
      context <- ownerContext environment element
      Just (PrimitiveNodeKind context primitive)
    Just (StructuringCarrier structuring) -> do
      context <- ownerContext environment element
      Just (StructuringNodeKind context structuring)
    Just (SituationAnchorCarrier anchor) -> Just (AnchorNodeKind anchor)
    Nothing -> Nothing

ownerContext :: Environment -> AMXElement -> Maybe Context
ownerContext environment element = do
  ownership <- uniqueOwnership environment element
  source <- elementAttribute (expandedQName Nothing 's' "ource") ownership
  [owner] <-
    pure (Map.findWithDefault [] source (environmentNodeIndex environment))
  case declaredCarrierOf owner of
    Just (ContextCarrier context) -> Just context
    _ -> Nothing

declaredCarrierOf :: AMXElement -> Maybe CarrierType
declaredCarrierOf element = do
  kindValue <- singleMetadataValue kindKey element
  typeValue <- singleMetadataValue typeKey element
  declaredCarrier kindValue typeValue
  where
    metadata = contractMetadata profileContract
    kindKey = carrierKindKey metadata
    typeKey = carrierTypeKey metadata

declaredCarrier :: Text -> Text -> Maybe CarrierType
declaredCarrier kindValue typeValue = do
  kind <- metadataKindFromText kindValue
  carrierTypeFromText kind typeValue

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
  -> ( RootProjection SourcePosition AMXProfileDefect
     , [DeferredProfileDefect SourcePosition AMXProfileDefect])
projectRootProfile document = (root, legacyDefects)
  where
    model = amxDocumentRoot document
    metadata = contractMetadata profileContract
    profileKey = modelProfileKey metadata
    expectedVersion =
      profileVersionText (contractProfileVersion profileContract)
    profileProperties = directProperties profileKey model
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
          | propertyValue property == expectedVersion -> []
          | otherwise ->
            [ Located
                (propertyLocation profileKey property)
                (UnsupportedO2IProfile (propertyValue property))
            ]
        first:rest ->
          [ Located
              (propertyLocation profileKey (fst first))
              (DuplicateO2IProfile
                 (propertyValue (fst first) :| map (propertyValue . fst) rest))
          ]
            ++ [ Located
                 (propertyLocation profileKey property)
                 (UnsupportedO2IProfile (propertyValue property))
               | (property, _) <- first : rest
               , propertyValue property /= expectedVersion
               ]
    root =
      case nonEmpty rootDefects of
        Just defects -> RootUnprojectable observed defects
        Nothing ->
          RootProjectable
            observed
            (resolveProfileVersion (contractProfileVersion profileContract))
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
singleMetadataValue key element = singlePropertyValue key element

firstOfTriple :: (first, second, third) -> first
firstOfTriple (value, _, _) = value

third :: (first, second, third) -> third
third (_, _, value) = value

nonEmpty :: [value] -> Maybe (NonEmpty value)
nonEmpty values =
  case values of
    [] -> Nothing
    first:rest -> Just (first :| rest)
