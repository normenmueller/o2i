{-# LANGUAGE OverloadedStrings #-}

-- | Indexed native declarations shared by AMX profile phases.
module O2I.Adapter.AMX.Internal.Profile.Model
  ( Environment(..)
  , buildEnvironment
  , incomingOwnerships
  , uniqueOwnership
  , isOwnershipRelationship
  , endpointElements
  , uniqueEndpointElement
  , uniqueEndpointElements
  , uniqueEndpointOccurrences
  , nodeOccurrence
  , relationshipOccurrence
  , presentationOccurrence
  , connectionOccurrence
  , displayId
  , stableUniqueElements
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Registry
import O2I.Adapter.AMX.Internal.Types
import O2I.ArchiMate.Profile
import O2I.Inspection.Provenance

-- | Native declaration indexes for one decoded document and selected View.
data Environment = Environment
  { environmentDocument :: AMXDocument
  , environmentSelectedView :: AMXSelectedView
  , environmentNodes :: [AMXElement]
  , environmentRelationships :: [AMXElement]
  , environmentNodeIndex :: Map Text [AMXElement]
  , environmentOwnerships :: [AMXElement]
  , environmentPresentedRelations :: Set OccurrenceId
  }

-- | Build stable declaration indexes without interpreting layout or nesting.
buildEnvironment :: AMXDocument -> AMXSelectedView -> Environment
buildEnvironment document selected =
  Environment
    { environmentDocument = document
    , environmentSelectedView = selected
    , environmentNodes = nodes
    , environmentRelationships = relationships
    , environmentNodeIndex = elementsById nodes
    , environmentOwnerships = filter isOwnershipRelationship relationships
    , environmentPresentedRelations =
        Set.fromList
          [ relationshipOccurrence (connectionRelationship connection)
          | connection <- selectedConnections selected
          ]
    }
  where
    declarations = amxDocumentElements document
    relationships = filter isRelationshipElement declarations
    nodes =
      filter
        (\element ->
           not (isRelationshipElement element || isViewElement element))
        declarations

-- | Persisted contextualizations implementing technical Context Ownership.
incomingOwnerships :: Environment -> AMXElement -> [AMXElement]
incomingOwnerships environment element =
  case elementId element of
    Nothing -> []
    Just identifier ->
      filter
        ((== Just identifier) . elementAttribute (endpointQName TargetEndpoint))
        (environmentOwnerships environment)

-- | Resolve exactly one persisted contextualization.
uniqueOwnership :: Environment -> AMXElement -> Maybe AMXElement
uniqueOwnership environment element =
  case incomingOwnerships environment element of
    [ownership] -> Just ownership
    _ -> Nothing

-- | Recognize the sole native contextualization notation.
isOwnershipRelationship :: AMXElement -> Bool
isOwnershipRelationship relationship =
  elementName relationship == contextualizationLabel pattern
    && actualRelationshipRepresentation relationship
         == Just (contextualizationRepresentation pattern)
  where
    pattern = contractContextualization profileContract

-- | Resolve all declaration occurrences referenced by one endpoint token.
endpointElements :: Environment -> EndpointRole -> AMXElement -> [AMXElement]
endpointElements environment role relationship =
  maybe
    []
    (\identifier ->
       Map.findWithDefault [] identifier (environmentNodeIndex environment))
    (elementAttribute (endpointQName role) relationship)

-- | Resolve an endpoint only when its persisted identifier is unique.
uniqueEndpointElement ::
     Environment -> EndpointRole -> AMXElement -> Maybe AMXElement
uniqueEndpointElement environment role relationship =
  case endpointElements environment role relationship of
    [element] -> Just element
    _ -> Nothing

-- | Resolve every unique endpoint of one relationship in role order.
uniqueEndpointElements :: Environment -> AMXElement -> [AMXElement]
uniqueEndpointElements environment relationship =
  mapMaybe
    (\role -> uniqueEndpointElement environment role relationship)
    [SourceEndpoint, TargetEndpoint]

-- | Resolve unique endpoint occurrence identities in role order.
uniqueEndpointOccurrences :: Environment -> AMXElement -> [OccurrenceId]
uniqueEndpointOccurrences environment =
  map nodeOccurrence . uniqueEndpointElements environment

elementsById :: [AMXElement] -> Map Text [AMXElement]
elementsById =
  Map.fromListWith (flip (++))
    . mapMaybe
        (\element ->
           fmap (\identifier -> (identifier, [element])) (elementId element))

-- | Stable occurrence identity of a model declaration.
nodeOccurrence :: AMXElement -> OccurrenceId
nodeOccurrence = elementOccurrence NodeOccurrence

-- | Stable occurrence identity of a relationship declaration.
relationshipOccurrence :: AMXElement -> OccurrenceId
relationshipOccurrence = elementOccurrence RelationshipOccurrence

-- | Stable occurrence identity of a diagram object.
presentationOccurrence :: AMXElement -> OccurrenceId
presentationOccurrence = elementOccurrence PresentationOccurrence

-- | Stable occurrence identity of a diagram connection.
connectionOccurrence :: AMXElement -> OccurrenceId
connectionOccurrence = elementOccurrence ConnectionOccurrence

-- | Persisted identifier or deterministic occurrence fallback for diagnostics.
displayId :: AMXElement -> Text
displayId element =
  maybe
    (occurrenceIdText (elementOccurrence XmlOccurrence element))
    id
    (elementId element)

-- | Stable occurrence-level deduplication.
stableUniqueElements :: [AMXElement] -> [AMXElement]
stableUniqueElements = go Set.empty
  where
    go _ [] = []
    go seen (element:rest)
      | Set.member occurrence seen = go seen rest
      | otherwise = element : go (Set.insert occurrence seen) rest
      where
        occurrence = elementOccurrence XmlOccurrence element
