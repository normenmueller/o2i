{-# LANGUAGE OverloadedStrings #-}

-- | Native collective Strategy-realization syntax recognition.
module O2I.Adapter.AMX.Internal.Profile.Collective.Syntax
  ( CollectiveObservation(..)
  , observeCollective
  , isCollectiveStrategyRealizationDeclaration
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I hiding (collectiveContributors, collectiveTarget)
import O2I.Adapter.AMX.Internal.Defect hiding
  ( CollectiveContributorIsTarget
  , DuplicateCollectiveContributor
  , EmptyCollectiveFitEvidenceReference
  )
import qualified O2I.Adapter.AMX.Internal.Defect as Defect
import O2I.Adapter.AMX.Internal.Profile.Commitment
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Profile.Property
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.ArchiMate.Profile
import O2I.Inspection.Provenance

data CollectiveObservation = CollectiveObservation
  { observedJunction :: AMXElement
  , observedSegments :: [AMXElement]
  , observedIncoming :: [AMXElement]
  , observedOutgoing :: [AMXElement]
  , observedContributors :: [AMXElement]
  , observedTargets :: [AMXElement]
  , observedRawClaim :: Maybe (Claim RawCollectiveStrategyRealization)
  , observedDefects :: [Located SourcePosition AMXProfileDefect]
  }

-- | Dispatch exactly one directly declared collective proposition type.
--
-- Missing, duplicate, and unknown type metadata remains visible to the
-- generic profile contract. Representation and remaining collective metadata
-- are validated only after this unambiguous dispatch decision.
isCollectiveStrategyRealizationDeclaration :: AMXElement -> Bool
isCollectiveStrategyRealizationDeclaration element =
  case directProperties typeKey element of
    [(_, value)] -> value == collectiveCarrierType carrier
    _ -> False
  where
    typeKey = carrierTypeKey (contractMetadata profileContract)
    carrier = collectiveCarrier (contractCollectiveRealization profileContract)

observeCollective ::
     Environment
  -> Map.Map Text [AMXElement]
  -> AMXElement
  -> CollectiveObservation
observeCollective environment relationshipAdjacency junction =
  CollectiveObservation
    { observedJunction = junction
    , observedSegments = segments
    , observedIncoming = incoming
    , observedOutgoing = outgoing
    , observedContributors = contributors
    , observedTargets = targets
    , observedRawClaim =
        if null defects
          then rawClaim identifier contributors targets junction
          else Nothing
    , observedDefects = defects
    }
  where
    identifier = elementId junction
    segments =
      maybe
        []
        (\stableId -> Map.findWithDefault [] stableId relationshipAdjacency)
        identifier
    incoming =
      filter
        ((== identifier) . elementAttribute (endpointQName TargetEndpoint))
        segments
    outgoing =
      filter
        ((== identifier) . elementAttribute (endpointQName SourceEndpoint))
        segments
    contributorResults =
      map (resolveParticipant environment SourceEndpoint "contributor") incoming
    targetResults =
      map (resolveParticipant environment TargetEndpoint "target") outgoing
    contributors = mapMaybeResult contributorResults
    targets = mapMaybeResult targetResults
    claimName = maybe "<missing>" id identifier
    contributorIds = mapMaybeId contributors
    targetIds = mapMaybeId targets
    defects =
      metadataDefects environment junction
        ++ concatMap (segmentDefects environment claimName junction) segments
        ++ concatMap (participantDefects claimName) contributorResults
        ++ concatMap (participantDefects claimName) targetResults
        ++ [ Located
             (amxElementLocation junction)
             (CollectiveContributorCardinality
                claimName
                (length (stableUnique contributorIds)))
           | not
               (cardinalityAccepts
                  (collectiveContributorCardinality contributorsContract)
                  (length (stableUnique contributorIds)))
           ]
        ++ [ Located
             (amxElementLocation junction)
             (CollectiveTargetCardinality claimName (length outgoing))
           | not
               (cardinalityAccepts
                  (collectiveTargetCardinality targetContract)
                  (length outgoing))
           ]
        ++ (if requirementIsRequired
                 (collectiveContributorsDistinct contributorsContract)
              then duplicateContributorDefects claimName contributorResults
              else [])
        ++ [ Located
             (amxElementLocation junction)
             (Defect.CollectiveContributorIsTarget claimName participant)
           | participant <- stableUnique contributorIds
           , participant `elem` targetIds
           , requirementIsRequired
               (collectiveTargetDistinctFromContributors targetContract)
           ]
    collective = contractCollectiveRealization profileContract
    contributorsContract = collectiveContributors collective
    targetContract = collectiveTarget collective

rawClaim ::
     Maybe Text
  -> [AMXElement]
  -> [AMXElement]
  -> AMXElement
  -> Maybe (Claim RawCollectiveStrategyRealization)
rawClaim identifier contributors targets junction = do
  claimIdentifier <- identifier
  contributorIds <- traverse (fmap RawNodeId . elementId) contributors
  [target] <- pure targets
  targetId <- RawNodeId <$> elementId target
  commitment <- resolvedCommitment (decodeCommitment junction)
  fitReference <- singlePropertyValue fitEvidenceKey junction
  pure
    (claimWithCommitment
       commitment
       RawCollectiveStrategyRealization
         { rawRealizationId = ClaimId claimIdentifier
         , rawContributors = contributorIds
         , rawTarget = targetId
         , rawCollectiveFitEvidence = CollectiveFitEvidenceRef fitReference
         })
  where
    fitEvidenceKey =
      collectiveFitEvidenceKey
        (collectiveCarrier (contractCollectiveRealization profileContract))

metadataDefects ::
     Environment -> AMXElement -> [Located SourcePosition AMXProfileDefect]
metadataDefects environment junction =
  unsupported
    ++ identifierDefects
    ++ representationDefects
    ++ exactValueDefects
         kindKey
         (metadataKindText (collectiveCarrierKind carrier))
         MissingO2IKind
         DuplicateO2IKind
         (\claimId actual -> UnknownO2IKind claimId actual)
         junction
    ++ exactValueDefects
         typeKey
         (collectiveCarrierType carrier)
         MissingO2IType
         DuplicateO2IType
         (\claimId actual ->
            InvalidO2ITypeForKind
              claimId
              (metadataKindText (collectiveCarrierKind carrier))
              actual)
         junction
    ++ commitmentResolutionDefects (decodeCommitment junction)
    ++ fitReferenceDefects junction
  where
    metadata = contractMetadata profileContract
    collective = contractCollectiveRealization profileContract
    carrier = collectiveCarrier collective
    kindKey = carrierKindKey metadata
    typeKey = carrierTypeKey metadata
    commitmentKey = collectiveCommitmentKey carrier
    fitEvidenceKey = collectiveFitEvidenceKey carrier
    identifier = displayId junction
    properties = o2iProperties junction
    allowedKeys = [kindKey, typeKey, commitmentKey, fitEvidenceKey]
    unsupported =
      [ Located
        (propertyLocation key property)
        (UnsupportedO2IMetadataKey identifier key)
      | (property, key, _) <- properties
      , key `notElem` allowedKeys
      ]
    identifierDefects =
      case elementId junction of
        Nothing ->
          [Located (amxElementLocation junction) MissingCollectiveClaimId]
        Just stableId
          | Text.null (Text.strip stableId) ->
            [Located (amxElementLocation junction) MissingCollectiveClaimId]
        Just stableId ->
          let count =
                length
                  (Map.findWithDefault
                     []
                     stableId
                     (environmentNodeIndex environment))
           in [ Located
                (amxElementLocation junction)
                (AmbiguousCollectiveClaimId stableId count)
              | count /= 1
              ]
    representationDefects =
      [ Located
        (amxElementLocation junction)
        (InvalidCollectiveJunctionRepresentation
           identifier
           (elementRepresentationText junction))
      | not (isCollectiveCarrier carrier junction)
      ]

exactValueDefects ::
     Text
  -> Text
  -> (Text -> AMXProfileDefect)
  -> (Text -> NonEmpty Text -> AMXProfileDefect)
  -> (Text -> Text -> AMXProfileDefect)
  -> AMXElement
  -> [Located SourcePosition AMXProfileDefect]
exactValueDefects key expected missing duplicate invalid element =
  case directProperties key element of
    [] -> [Located (amxElementLocation element) (missing identifier)]
    [(property, value)]
      | value == expected -> []
      | otherwise ->
        [Located (propertyLocation key property) (invalid identifier value)]
    first:rest ->
      [ Located
          (propertyLocation key (fst first))
          (duplicate identifier (snd first :| map snd rest))
      ]
  where
    identifier = displayId element

fitReferenceDefects :: AMXElement -> [Located SourcePosition AMXProfileDefect]
fitReferenceDefects element =
  case directProperties fitEvidenceKey element of
    [] ->
      [ Located
          (amxElementLocation element)
          (MissingCollectiveFitEvidenceReference identifier)
      ]
    [(property, value)]
      | Text.null (Text.strip value) ->
        [ Located
            (propertyLocation fitEvidenceKey property)
            (Defect.EmptyCollectiveFitEvidenceReference identifier)
        ]
      | otherwise -> []
    first:rest ->
      [ Located
          (propertyLocation fitEvidenceKey (fst first))
          (DuplicateCollectiveFitEvidenceReference
             identifier
             (snd first :| map snd rest))
      ]
  where
    identifier = displayId element
    fitEvidenceKey =
      collectiveFitEvidenceKey
        (collectiveCarrier (contractCollectiveRealization profileContract))

segmentDefects ::
     Environment
  -> Text
  -> AMXElement
  -> AMXElement
  -> [Located SourcePosition AMXProfileDefect]
segmentDefects environment claim junction segment =
  representationDefects
    ++ nameDefects
    ++ forbiddenCommitmentDefects "collective-realization-segment" segment
    ++ segmentMetadataDefects
    ++ chainDefects
  where
    segmentId = displayId segment
    collective = contractCollectiveRealization profileContract
    segmentContract = collectiveSegments collective
    expected = collectiveSegmentRepresentation segmentContract
    actual = actualRelationshipRepresentation segment
    representationDefects =
      [ Located
        (amxElementLocation segment)
        (InvalidCollectiveSegmentRepresentation
           claim
           segmentId
           (maybe "<unresolved>" representationText actual))
      | actual /= Just expected
      ]
    nameDefects =
      [ Located
        (amxElementLocation segment)
        (InvalidCollectiveSegmentName claim segmentId (elementName segment))
      | elementName segment /= collectiveSegmentLabel segmentContract
      ]
    segmentMetadataDefects =
      [ Located
        (propertyLocation key property)
        (CollectiveSegmentMetadata claim segmentId key)
      | (property, key, _) <- o2iProperties segment
      , key /= relationCommitmentKey (contractMetadata profileContract)
      , requirementIsForbidden (collectiveSegmentMetadata segmentContract)
      ]
    chainDefects =
      [ Located
        (amxElementLocation segment)
        (CollectiveJunctionChain claim segmentId)
      | any
          (\endpoint -> endpoint /= junction && isJunction endpoint)
          (endpointCandidates segment)
      , requirementIsForbidden (collectiveJunctionChains collective)
      ]
    endpointCandidates relationship =
      stableUniqueElements
        (concatMap
           (\role ->
              case elementAttribute (endpointQName role) relationship of
                Nothing -> []
                Just endpointId ->
                  Map.findWithDefault
                    []
                    endpointId
                    (environmentNodeIndex environment))
           [SourceEndpoint, TargetEndpoint])

data ParticipantResolution = ParticipantResolution
  { participantRelationship :: AMXElement
  , participantEndpointRole :: EndpointRole
  , participantEndpoint :: Maybe AMXElement
  , participantResolutionProblems :: [ParticipantProblem]
  }

data ParticipantProblem
  = EndpointUnresolved Text Text (Maybe Text)
  | EndpointAmbiguous Text Text Int

resolveParticipant ::
     Environment -> EndpointRole -> Text -> AMXElement -> ParticipantResolution
resolveParticipant environment endpointRole role relationship =
  case endpointElements environment endpointRole relationship of
    [] ->
      ParticipantResolution
        relationship
        endpointRole
        Nothing
        [ EndpointUnresolved
            (displayId relationship)
            role
            (elementAttribute (endpointQName endpointRole) relationship)
        ]
    [endpoint] ->
      ParticipantResolution relationship endpointRole (Just endpoint) []
    endpoints ->
      ParticipantResolution
        relationship
        endpointRole
        Nothing
        [EndpointAmbiguous (displayId relationship) role (length endpoints)]

participantDefects ::
     Text -> ParticipantResolution -> [Located SourcePosition AMXProfileDefect]
participantDefects claim resolution =
  [ Located
    (elementAttributeLocation
       (endpointQName (participantEndpointRole resolution))
       (participantRelationship resolution))
    (withClaim problem)
  | problem <- participantResolutionProblems resolution
  ]
  where
    withClaim problem =
      case problem of
        EndpointUnresolved segment role reference ->
          CollectiveEndpointUnresolved claim segment role reference
        EndpointAmbiguous segment role count ->
          CollectiveEndpointAmbiguous claim segment role count

duplicateContributorDefects ::
     Text
  -> [ParticipantResolution]
  -> [Located SourcePosition AMXProfileDefect]
duplicateContributorDefects claim = go Set.empty
  where
    go _ [] = []
    go seen (resolution:rest) =
      case participantEndpoint resolution >>= elementId of
        Nothing -> go seen rest
        Just contributor
          | Set.member contributor seen ->
            Located
              (elementAttributeLocation
                 (endpointQName (participantEndpointRole resolution))
                 (participantRelationship resolution))
              (Defect.DuplicateCollectiveContributor claim contributor)
              : go seen rest
          | otherwise -> go (Set.insert contributor seen) rest

isJunction :: AMXElement -> Bool
isJunction =
  hasArchiType
    (collectiveCarrierElement
       (collectiveCarrier (contractCollectiveRealization profileContract)))

isCollectiveCarrier :: CollectiveCarrierContract -> AMXElement -> Bool
isCollectiveCarrier carrier element =
  hasArchiType (collectiveCarrierElement carrier) element
    && junctionTypeMatches
         (collectiveJunctionType carrier)
         (elementAttribute (expandedQName Nothing 't' "ype") element)

junctionTypeMatches :: Text -> Maybe Text -> Bool
junctionTypeMatches expected actual =
  case expected of
    "and" -> actual == Nothing
    _ -> actual == Just expected

hasArchiType :: Text -> AMXElement -> Bool
hasArchiType localName element =
  case elementType element of
    Just name ->
      qNameNamespace name == Just archiNamespace
        && qNameLocalName name == localName
    Nothing -> False

elementRepresentationText :: AMXElement -> Text
elementRepresentationText element =
  case elementType element of
    Nothing -> "<unresolved>"
    Just name ->
      "{"
        <> maybe "" id (qNameNamespace name)
        <> "}"
        <> qNameLocalName name
        <> maybe
             ""
             (":" <>)
             (elementAttribute (expandedQName Nothing 't' "ype") element)

mapMaybeResult :: [ParticipantResolution] -> [AMXElement]
mapMaybeResult =
  foldr
    (\resolution rest ->
       case participantEndpoint resolution of
         Nothing -> rest
         Just endpoint -> endpoint : rest)
    []

mapMaybeId :: [AMXElement] -> [Text]
mapMaybeId =
  foldr
    (\element rest ->
       case elementId element of
         Nothing -> rest
         Just identifier -> identifier : rest)
    []

stableUnique :: Ord value => [value] -> [value]
stableUnique = go Set.empty
  where
    go _ [] = []
    go seen (value:rest)
      | Set.member value seen = go seen rest
      | otherwise = value : go (Set.insert value seen) rest
