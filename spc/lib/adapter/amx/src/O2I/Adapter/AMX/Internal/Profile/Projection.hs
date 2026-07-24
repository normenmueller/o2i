{-# LANGUAGE OverloadedStrings #-}

-- | Projection of native profile observations into Inspection facts.
module O2I.Adapter.AMX.Internal.Profile.Projection
  ( projectAMXProfile
  ) where

import Data.List (nub)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import O2I (claimWithCommitment)
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Closure
import O2I.Adapter.AMX.Internal.Profile.Collective
import O2I.Adapter.AMX.Internal.Profile.Collective.Index
import O2I.Adapter.AMX.Internal.Profile.Commitment
import O2I.Adapter.AMX.Internal.Profile.Metadata
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Profile.Property
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Project the sole adapter observation into a total profile result.
projectAMXProfile ::
     ProfileSnapshot SourcePosition AMXProfileFact
  -> ProfileProjection SourcePosition AMXProfileDefect
projectAMXProfile snapshot =
  case locatedValue (snapshotFact snapshot) of
    AMXProfileFact document selected -> projectSnapshot document selected

projectSnapshot ::
     AMXDocument
  -> AMXSelectedView
  -> ProfileProjection SourcePosition AMXProfileDefect
projectSnapshot document selected =
  ProfileProjection
    { projectedRoot = rootProjection
    , projectedFacts =
        profileFacts environment collectiveIndex closure semanticRelationships
    , projectedDefects =
        rootDeferred
          ++ nodeDeferred
          ++ ownershipDeferred
          ++ relationDeferred
          ++ collectiveDefects environment collectiveIndex
    }
  where
    environment = buildEnvironment document selected
    collectiveIndex = buildCollectiveIndex environment
    closure = candidateClosure environment collectiveIndex
    semanticRelationships =
      semanticRelationshipElements environment collectiveIndex closure
    (rootProjection, rootDeferred) = projectRootProfile document
    nodeDeferred =
      concatMap
        (candidateDefects environment)
        [ element
        | element <- environmentNodes environment
        , not (isCollectiveStrategyRealizationDeclaration element)
        , Set.member (nodeOccurrence element) (closureCandidates closure)
        ]
    relationDeferred =
      concatMap (relationshipDefects environment) semanticRelationships
    ownershipDeferred =
      concatMap
        (\relationship ->
           map
             (deferRelationship (relationshipOccurrence relationship))
             (forbiddenCommitmentDefects "contextualization" relationship))
        (environmentOwnerships environment)

profileFacts ::
     Environment
  -> CollectiveIndex
  -> CandidateClosure
  -> [AMXElement]
  -> [IndexedProfileFact SourcePosition]
profileFacts environment collectiveIndex closure semanticRelationships =
  nodeFacts
    ++ relationshipFacts
    ++ collectiveFacts collectiveIndex
    ++ presentationFacts
    ++ ownershipDependencies
    ++ hiddenDependencies
  where
    nodeFacts =
      map
        (projectNodeOccurrence environment closure)
        (filter
           (not . isCollectiveStrategyRealizationDeclaration)
           (environmentNodes environment))
    retainedRelationships =
      stableUniqueElements
        (environmentOwnerships environment ++ semanticRelationships)
    relationshipFacts =
      concatMap
        (projectRelationshipOccurrence environment closure)
        retainedRelationships
    presentationFacts =
      projectPresentations
        environment
        collectiveIndex
        closure
        semanticRelationships
    ownershipDependencies =
      concatMap
        (relationshipBackDependencies
           environment
           closure
           PersistedContextOwnership)
        (environmentOwnerships environment)
    hiddenDependencies =
      concatMap
        (hiddenRelationshipDependencies environment closure)
        semanticRelationships

projectNodeOccurrence ::
     Environment
  -> CandidateClosure
  -> AMXElement
  -> IndexedProfileFact SourcePosition
projectNodeOccurrence environment closure element
  | Set.member occurrence (closureCandidates closure) =
    case (rawNode environment element, resolvedCommitment commitment) of
      (Just node, Just explicitCommitment)
        | representationCompatible element (nodeKind environment element) ->
          indexNode
            occurrence
            (claimWithCommitment explicitCommitment node)
            (amxElementLocation element)
      _ -> indexOccurrence occurrence (amxElementLocation element)
  | otherwise = indexOccurrence occurrence (amxElementLocation element)
  where
    occurrence = nodeOccurrence element
    commitment = decodeCommitment element

projectRelationshipOccurrence ::
     Environment
  -> CandidateClosure
  -> AMXElement
  -> [IndexedProfileFact SourcePosition]
projectRelationshipOccurrence environment closure relationship =
  declarationFact : endpointReferences
  where
    occurrence = relationshipOccurrence relationship
    declarationFact =
      case if isOwnershipRelationship relationship
             then Nothing
             else projectedRawEdge environment closure relationship of
        Just edge
          | Just commitment <-
              resolvedCommitment (decodeCommitment relationship) ->
            indexEdge
              occurrence
              (claimWithCommitment commitment edge)
              (amxElementLocation relationship)
        _ -> indexOccurrence occurrence (amxElementLocation relationship)
    endpointReferences =
      [ relationshipReference environment relationship role reason
      | role <- [SourceEndpoint, TargetEndpoint]
      ]
    reason =
      if isOwnershipRelationship relationship
        then PersistedContextOwnership
        else case resolvedSignatures environment relationship of
               signature:_ -> relationDependencyReason (signatureCode signature)
               [] -> PersistedRelationshipEndpoint

relationshipReference ::
     Environment
  -> AMXElement
  -> EndpointRole
  -> PersistedDependencyReason
  -> IndexedProfileFact SourcePosition
relationshipReference environment relationship role reason =
  indexReference occurrence reference matches reason
  where
    occurrence = relationshipOccurrence relationship
    attributeName = endpointQName role
    token = elementAttribute attributeName relationship
    matches =
      maybe
        []
        (\identifier ->
           map
             nodeOccurrence
             (Map.findWithDefault
                []
                identifier
                (environmentNodeIndex environment)))
        token
    reference =
      ReferenceOccurrence
        { referenceOccurrenceId =
            elementOccurrence (referenceOccurrenceKind role) relationship
        , referenceFromOccurrence = occurrence
        , referenceRole =
            if isOwnershipRelationship relationship
              then if role == SourceEndpoint
                     then OwnershipSourceReference
                     else OwnershipTargetReference
              else if role == SourceEndpoint
                     then RelationSourceReference
                     else RelationTargetReference
        , referenceToken = token
        , referenceLocation =
            case token of
              Nothing -> amxElementLocation relationship
              Just _ -> elementAttributeLocation attributeName relationship
        }

referenceOccurrenceKind :: EndpointRole -> AMXOccurrenceKind
referenceOccurrenceKind role =
  case role of
    SourceEndpoint -> RelationshipSourceReferenceOccurrence
    TargetEndpoint -> RelationshipTargetReferenceOccurrence

projectPresentations ::
     Environment
  -> CollectiveIndex
  -> CandidateClosure
  -> [AMXElement]
  -> [IndexedProfileFact SourcePosition]
projectPresentations environment collectiveIndex closure semanticRelationships =
  concatMap objectPresentation objects
    ++ concatMap connectionPresentation connections
  where
    selected = environmentSelectedView environment
    objects = selectedPresentations selected
    connections = selectedConnections selected
    semanticRelationshipOccurrences =
      Set.fromList (map relationshipOccurrence semanticRelationships)
    segmentOccurrences = collectiveSegmentOccurrences collectiveIndex
    objectPresentation presentation =
      let source = presentationOccurrence (presentationElement presentation)
          target = nodeOccurrence (presentationTarget presentation)
       in if Set.member target (closureCandidates closure)
            then [ indexOccurrence
                     source
                     (amxElementLocation (presentationElement presentation))
                 , indexPresentation source target
                 ]
            else []
    connectionPresentation connection =
      let source = connectionOccurrence (connectionElement connection)
          target = relationshipOccurrence (connectionRelationship connection)
       in if Set.member target (closureRelationships closure)
               || Set.member target semanticRelationshipOccurrences
               || Set.member target segmentOccurrences
            then [ indexOccurrence
                     source
                     (amxElementLocation (connectionElement connection))
                 , indexPresentation source target
                 ]
            else []

relationshipBackDependencies ::
     Environment
  -> CandidateClosure
  -> PersistedDependencyReason
  -> AMXElement
  -> [IndexedProfileFact SourcePosition]
relationshipBackDependencies environment closure reason relationship =
  [ indexDependency (nodeOccurrence endpoint) relationOccurrence reason
  | endpoint <- uniqueEndpointElements environment relationship
  , Set.member (nodeOccurrence endpoint) (closureCandidates closure)
  ]
  where
    relationOccurrence = relationshipOccurrence relationship

hiddenRelationshipDependencies ::
     Environment
  -> CandidateClosure
  -> AMXElement
  -> [IndexedProfileFact SourcePosition]
hiddenRelationshipDependencies environment closure relationship =
  case exactSignatures environment relationship of
    signature:_
      | isHiddenDependencyRelation (signatureCode signature) ->
        relationshipBackDependencies
          environment
          closure
          (relationDependencyReason (signatureCode signature))
          relationship
    _ -> []

relationshipDefects ::
     Environment
  -> AMXElement
  -> [DeferredProfileDefect SourcePosition AMXProfileDefect]
relationshipDefects environment relationship =
  map
    (deferRelationship (relationshipOccurrence relationship))
    (commitmentResolutionDefects (decodeCommitment relationship)
       ++ unsupportedMetadataDefects
       ++ representationDefects)
  where
    unsupportedMetadataDefects =
      [ Located
        (propertyLocation key property)
        (UnsupportedO2IMetadataKey (displayId relationship) key)
      | (property, key, _) <- o2iProperties relationship
      , key /= "o2i.commitment"
      ]
    representationDefects =
      case resolvedSignatures environment relationship of
        [] -> []
        signatures ->
          case actualRelationshipRepresentation relationship of
            Just actual
              | any ((== actual) . signatureRepresentation) signatures -> []
            actual ->
              [ Located
                  (amxElementLocation relationship)
                  (IncompatibleRelationshipRepresentation
                     (displayId relationship)
                     (Text.intercalate
                        "|"
                        (nub
                           (map
                              (representationText . signatureRepresentation)
                              signatures)))
                     (maybe "<unresolved>" representationText actual))
              ]

deferRelationship ::
     OccurrenceId
  -> Located SourcePosition AMXProfileDefect
  -> DeferredProfileDefect SourcePosition AMXProfileDefect
deferRelationship occurrence defect =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = defect
    }
