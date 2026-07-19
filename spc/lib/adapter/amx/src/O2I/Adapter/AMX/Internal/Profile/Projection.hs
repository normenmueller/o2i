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
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Closure
import O2I.Adapter.AMX.Internal.Profile.Metadata
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Project the sole adapter observation into a total profile result.
projectAMXProfile ::
     ProfileSnapshot AMXProfileFact -> ProfileProjection AMXProfileDefect
projectAMXProfile snapshot =
  case locatedValue (snapshotFact snapshot) of
    AMXProfileFact document selected -> projectSnapshot document selected

projectSnapshot ::
     AMXDocument -> AMXSelectedView -> ProfileProjection AMXProfileDefect
projectSnapshot document selected =
  ProfileProjection
    { projectedRoot = rootProjection
    , projectedFacts = profileFacts environment closure
    , projectedDefects = rootDeferred ++ nodeDeferred ++ relationDeferred
    }
  where
    environment = buildEnvironment document selected
    closure = candidateClosure environment
    (rootProjection, rootDeferred) = projectRootProfile document
    nodeDeferred =
      concatMap
        (candidateDefects environment)
        [ element
        | element <- environmentNodes environment
        , Set.member (nodeOccurrence element) (closureCandidates closure)
        ]
    relationDeferred =
      concatMap
        (relationshipDefects environment)
        (semanticRelationshipElements environment closure)

profileFacts :: Environment -> CandidateClosure -> [IndexedProfileFact]
profileFacts environment closure =
  nodeFacts
    ++ relationshipFacts
    ++ presentationFacts
    ++ ownershipDependencies
    ++ hiddenDependencies
  where
    nodeFacts =
      map
        (projectNodeOccurrence environment closure)
        (environmentNodes environment)
    semanticRelationships = semanticRelationshipElements environment closure
    retainedRelationships =
      stableUniqueElements
        (environmentOwnerships environment ++ semanticRelationships)
    relationshipFacts =
      concatMap
        (projectRelationshipOccurrence environment closure)
        retainedRelationships
    presentationFacts = projectPresentations environment closure
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
     Environment -> CandidateClosure -> AMXElement -> IndexedProfileFact
projectNodeOccurrence environment closure element
  | Set.member occurrence (closureCandidates closure) =
    case rawNode environment element of
      Just node
        | representationCompatible element (nodeKind environment element) ->
          indexNode occurrence node (amxElementLocation element)
      _ -> indexOccurrence occurrence (amxElementLocation element)
  | otherwise = indexOccurrence occurrence (amxElementLocation element)
  where
    occurrence = nodeOccurrence element

projectRelationshipOccurrence ::
     Environment -> CandidateClosure -> AMXElement -> [IndexedProfileFact]
projectRelationshipOccurrence environment closure relationship =
  declarationFact : endpointReferences
  where
    occurrence = relationshipOccurrence relationship
    declarationFact =
      case if isOwnershipRelationship relationship
             then Nothing
             else projectedRawEdge environment closure relationship of
        Just edge -> indexEdge occurrence edge (amxElementLocation relationship)
        Nothing -> indexOccurrence occurrence (amxElementLocation relationship)
    endpointReferences =
      [ relationshipReference environment relationship role reason
      | role <- ["source", "target"]
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
  -> Text.Text
  -> PersistedDependencyReason
  -> IndexedProfileFact
relationshipReference environment relationship role reason =
  indexReference occurrence reference matches reason
  where
    occurrence = relationshipOccurrence relationship
    attributeName = ExpandedQName Nothing role
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
            OccurrenceId (occurrenceIdText occurrence <> ":reference:" <> role)
        , referenceFromOccurrence = occurrence
        , referenceRole =
            if isOwnershipRelationship relationship
              then if role == "source"
                     then OwnershipSourceReference
                     else OwnershipTargetReference
              else if role == "source"
                     then RelationSourceReference
                     else RelationTargetReference
        , referenceToken = token
        , referenceLocation =
            case token of
              Nothing -> amxElementLocation relationship
              Just _ -> elementAttributeLocation attributeName relationship
        }

projectPresentations :: Environment -> CandidateClosure -> [IndexedProfileFact]
projectPresentations environment closure =
  concatMap objectPresentation objects
    ++ concatMap connectionPresentation connections
  where
    selected = environmentSelectedView environment
    objects = selectedPresentations selected
    connections = selectedConnections selected
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
               || connectionRelationship connection
                    `elem` semanticRelationshipElements environment closure
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
  -> [IndexedProfileFact]
relationshipBackDependencies environment closure reason relationship =
  [ indexDependency (nodeOccurrence endpoint) relationOccurrence reason
  | endpoint <- uniqueEndpointElements environment relationship
  , Set.member (nodeOccurrence endpoint) (closureCandidates closure)
  ]
  where
    relationOccurrence = relationshipOccurrence relationship

hiddenRelationshipDependencies ::
     Environment -> CandidateClosure -> AMXElement -> [IndexedProfileFact]
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
     Environment -> AMXElement -> [DeferredProfileDefect AMXProfileDefect]
relationshipDefects environment relationship =
  case resolvedSignatures environment relationship of
    [] -> []
    signatures ->
      case actualRelationshipRepresentation relationship of
        Just actual
          | any ((== actual) . signatureRepresentation) signatures -> []
        actual ->
          [ deferRelationship
              (relationshipOccurrence relationship)
              (Located
                 (amxElementLocation relationship)
                 (IncompatibleRelationshipRepresentation
                    (displayId relationship)
                    (Text.intercalate
                       "|"
                       (nub
                          (map
                             (representationText . signatureRepresentation)
                             signatures)))
                    (maybe "<unresolved>" representationText actual)))
          ]

deferRelationship ::
     OccurrenceId
  -> Located AMXProfileDefect
  -> DeferredProfileDefect AMXProfileDefect
deferRelationship occurrence defect =
  DeferredProfileDefect
    { defectApplicability = ReachedProfileDefect (occurrence :| [])
    , deferredDefect = defect
    }
