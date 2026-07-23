{-# LANGUAGE OverloadedStrings #-}

-- | Native collective Strategy-realization syntax recognition.
module O2I.Adapter.AMX.Internal.Profile.Collective.Syntax
  ( CollectiveObservation(..)
  , observeCollective
  , isCollectiveClaimCandidate
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Internal.Defect hiding
  ( CollectiveContributorIsTarget
  , DuplicateCollectiveContributor
  , EmptyCollectiveFitEvidenceReference
  )
import qualified O2I.Adapter.AMX.Internal.Defect as Defect
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.Inspection.Provenance

-- | Stable metadata key linking a Junction claim to supplemental Fit evidence.
collectiveFitEvidenceKey :: Text
collectiveFitEvidenceKey = "o2i.collective-fit-evidence"

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

-- | A Junction or explicit Claim declaration enters collective candidacy only
-- through direct O2I metadata. Unannotated visual Junctions remain nonsemantic.
isCollectiveClaimCandidate :: AMXElement -> Bool
isCollectiveClaimCandidate element =
  hasO2IMetadata element
    && (isJunction element
          || singlePropertyValue "o2i.kind" element == Just "Claim"
          || singlePropertyValue "o2i.type" element
               == Just "CollectiveStrategyRealization")

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
           | length (stableUnique contributorIds) < 2
           ]
        ++ [ Located
             (amxElementLocation junction)
             (CollectiveTargetCardinality claimName (length outgoing))
           | length outgoing /= 1
           ]
        ++ duplicateContributorDefects claimName contributorResults
        ++ [ Located
             (amxElementLocation junction)
             (Defect.CollectiveContributorIsTarget claimName participant)
           | participant <- stableUnique contributorIds
           , participant `elem` targetIds
           ]

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
  commitment <- collectiveCommitment junction
  fitReference <- singlePropertyValue collectiveFitEvidenceKey junction
  pure
    (claimWithCommitment
       commitment
       RawCollectiveStrategyRealization
         { rawRealizationId = ClaimId claimIdentifier
         , rawContributors = contributorIds
         , rawTarget = targetId
         , rawCollectiveFitEvidence = CollectiveFitEvidenceRef fitReference
         })

metadataDefects ::
     Environment -> AMXElement -> [Located SourcePosition AMXProfileDefect]
metadataDefects environment junction =
  unsupported
    ++ identifierDefects
    ++ representationDefects
    ++ exactValueDefects
         "o2i.kind"
         "Claim"
         MissingO2IKind
         DuplicateO2IKind
         (\claimId actual -> UnknownO2IKind claimId actual)
         junction
    ++ exactValueDefects
         "o2i.type"
         "CollectiveStrategyRealization"
         MissingO2IType
         DuplicateO2IType
         (\claimId actual -> InvalidO2ITypeForKind claimId "Claim" actual)
         junction
    ++ commitmentDefects junction
    ++ fitReferenceDefects junction
  where
    identifier = displayId junction
    properties = o2iProperties junction
    allowedKeys =
      ["o2i.kind", "o2i.type", "o2i.commitment", collectiveFitEvidenceKey]
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
      | not (isAndJunction junction)
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

commitmentDefects :: AMXElement -> [Located SourcePosition AMXProfileDefect]
commitmentDefects element =
  case directProperties "o2i.commitment" element of
    [] ->
      [ Located
          (amxElementLocation element)
          (MissingCollectiveCommitment identifier)
      ]
    [(property, value)]
      | value `elem` ["candidate", "asserted"] -> []
      | otherwise ->
        [ Located
            (propertyLocation "o2i.commitment" property)
            (InvalidCollectiveCommitment identifier value)
        ]
    first:rest ->
      [ Located
          (propertyLocation "o2i.commitment" (fst first))
          (DuplicateCollectiveCommitment identifier (snd first :| map snd rest))
      ]
  where
    identifier = displayId element

fitReferenceDefects :: AMXElement -> [Located SourcePosition AMXProfileDefect]
fitReferenceDefects element =
  case directProperties collectiveFitEvidenceKey element of
    [] ->
      [ Located
          (amxElementLocation element)
          (MissingCollectiveFitEvidenceReference identifier)
      ]
    [(property, value)]
      | Text.null (Text.strip value) ->
        [ Located
            (propertyLocation collectiveFitEvidenceKey property)
            (Defect.EmptyCollectiveFitEvidenceReference identifier)
        ]
      | otherwise -> []
    first:rest ->
      [ Located
          (propertyLocation collectiveFitEvidenceKey (fst first))
          (DuplicateCollectiveFitEvidenceReference
             identifier
             (snd first :| map snd rest))
      ]
  where
    identifier = displayId element

segmentDefects ::
     Environment
  -> Text
  -> AMXElement
  -> AMXElement
  -> [Located SourcePosition AMXProfileDefect]
segmentDefects environment claim junction segment =
  representationDefects ++ nameDefects ++ segmentMetadataDefects ++ chainDefects
  where
    segmentId = displayId segment
    expected = ArchiRelationshipRepresentation "RealizationRelationship" False
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
      | elementName segment /= "realizes"
      ]
    segmentMetadataDefects =
      [ Located
        (propertyLocation key property)
        (CollectiveSegmentMetadata claim segmentId key)
      | (property, key, _) <- o2iProperties segment
      ]
    chainDefects =
      [ Located
        (amxElementLocation segment)
        (CollectiveJunctionChain claim segmentId)
      | any
          (\endpoint -> endpoint /= junction && isJunction endpoint)
          (endpointCandidates segment)
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

collectiveCommitment :: AMXElement -> Maybe Commitment
collectiveCommitment element =
  case singlePropertyValue "o2i.commitment" element of
    Just "candidate" -> Just Candidate
    Just "asserted" -> Just Asserted
    _ -> Nothing

isJunction :: AMXElement -> Bool
isJunction = hasArchiType "Junction"

isAndJunction :: AMXElement -> Bool
isAndJunction element =
  isJunction element
    && elementAttribute (expandedQName Nothing 't' "ype") element == Nothing

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

hasO2IMetadata :: AMXElement -> Bool
hasO2IMetadata =
  any (Text.isPrefixOf "o2i." . propertyKey) . elementDirectProperties

o2iProperties :: AMXElement -> [(AMXElement, Text, Text)]
o2iProperties element =
  [ (property, key, propertyValue property)
  | property <- elementDirectProperties element
  , let key = propertyKey property
  , "o2i." `Text.isPrefixOf` key
  ]

directProperties :: Text -> AMXElement -> [(AMXElement, Text)]
directProperties key element =
  [ (property, value)
  | (property, observedKey, value) <- o2iProperties element
  , observedKey == key
  ]

singlePropertyValue :: Text -> AMXElement -> Maybe Text
singlePropertyValue key element =
  case directProperties key element of
    [(_, value)] -> Just value
    _ -> Nothing

propertyKey :: AMXElement -> Text
propertyKey = maybe "" id . elementAttribute (expandedQName Nothing 'k' "ey")

propertyValue :: AMXElement -> Text
propertyValue =
  maybe "" id . elementAttribute (expandedQName Nothing 'v' "alue")

propertyLocation :: Text -> AMXElement -> SourcePosition
propertyLocation key property =
  sourcePosition
    (positionPath location)
    (PropertyTarget key)
    (positionSpan location)
  where
    location = amxElementLocation property

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
