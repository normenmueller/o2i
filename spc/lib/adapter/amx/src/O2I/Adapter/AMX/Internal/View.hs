{-# LANGUAGE OverloadedStrings #-}

-- | Exact AMX View selection and presentation validation.
module O2I.Adapter.AMX.Internal.View
  ( resolveAMXView
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML (archiNamespace)
import O2I.Inspection.Cardinality
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Resolve exactly one View by name or stable identifier and validate every
-- persisted object, relationship, and connection-endpoint reference in it.
resolveAMXView ::
     AMXDocument -> ViewSelector -> ViewAttempt AMXViewDefect AMXSelectedView
resolveAMXView document selector =
  case matchingViews of
    [] ->
      ViewFailed
        NoViewMatch
        (Located rootLocation (ViewNotFound selector) :| [])
    [view] -> validateSelectedView document view
    first:second:rest ->
      let duplicateViews = first :| (second : rest)
          candidates =
            atLeastTwo
              (viewCandidate first)
              (viewCandidate second)
              (map viewCandidate rest)
          defect =
            case selector of
              ViewByName name ->
                AmbiguousViewName
                  name
                  (fmap (viewCandidateId . viewCandidate) duplicateViews)
              ViewById identifier ->
                DuplicateViewId
                  identifier
                  (fmap (viewCandidateName . viewCandidate) duplicateViews)
       in ViewFailed
            (MultipleViewMatches candidates)
            (Located (amxElementLocation first) defect :| [])
  where
    views = filter isViewElement (amxDocumentElements document)
    matchingViews = filter (matches selector) views
    rootLocation = amxElementLocation (amxDocumentRoot document)

matches :: ViewSelector -> AMXElement -> Bool
matches selector view =
  case selector of
    ViewByName name -> elementName view == name
    ViewById identifier -> elementId view == Just identifier

viewCandidate :: AMXElement -> ViewCandidate
viewCandidate view =
  ViewCandidate
    { viewCandidateId = maybe "" id (elementId view)
    , viewCandidateName = elementName view
    , viewCandidateLocation = amxElementLocation view
    }

validateSelectedView ::
     AMXDocument -> AMXElement -> ViewAttempt AMXViewDefect AMXSelectedView
validateSelectedView document view =
  case defects of
    [] ->
      ViewPassed
        resolved
        AMXSelectedView
          { selectedViewElement = view
          , selectedPresentations = presentations
          , selectedConnections = connections
          }
    first:rest -> ViewFailed (OneViewMatch (viewCandidate view)) (first :| rest)
  where
    resolved =
      ResolvedView
        { resolvedViewId = maybe "" id (elementId view)
        , resolvedViewName = elementName view
        , resolvedViewLocation = amxElementLocation view
        }
    modelNodes =
      filter
        (\element ->
           not (isRelationshipElement element || isViewElement element))
        (amxDocumentElements document)
    relationships = filter isRelationshipElement (amxDocumentElements document)
    modelNodeIndex = elementsById modelNodes
    relationshipIndex = elementsById relationships
    diagramObjects = filter isDiagramObject (elementDescendants view)
    objectIndex = elementsById diagramObjects
    objectResults = map (resolveObject modelNodeIndex) diagramObjects
    presentations = mapMaybe resultValue objectResults
    presentationIndex =
      Map.fromList
        [ ( elementOccurrence "view-object" (presentationElement presentation)
          , presentation)
        | presentation <- presentations
        ]
    connectionElements = filter isConnection (elementDescendants view)
    connectionResults =
      map
        (resolveConnection relationshipIndex objectIndex presentationIndex)
        connectionElements
    connections = mapMaybe resultValue connectionResults
    defects =
      concatMap resultDefects objectResults
        ++ concatMap resultDefects connectionResults

data Resolution a = Resolution
  { resultValue :: Maybe a
  , resultDefects :: [Located AMXViewDefect]
  }

resolveObject ::
     Map Text [AMXElement] -> AMXElement -> Resolution AMXPresentation
resolveObject modelIndex object =
  case reference >>= (`Map.lookup` modelIndex) of
    Nothing ->
      Resolution
        Nothing
        [Located location (UnresolvedViewObjectReference reference)]
    Just [target] -> Resolution (Just (AMXPresentation object target)) []
    Just matchedElements ->
      case nonEmpty matchedElements of
        Nothing ->
          Resolution
            Nothing
            [Located location (UnresolvedViewObjectReference reference)]
        Just occurrences ->
          Resolution
            Nothing
            [ Located
                location
                (AmbiguousViewObjectReference
                   (maybe "" id reference)
                   (fmap amxElementLocation occurrences))
            ]
  where
    referenceName = expandedQName Nothing 'a' "rchimateElement"
    reference = elementAttribute referenceName object
    location = attributeReferenceLocation referenceName object reference

resolveConnection ::
     Map Text [AMXElement]
  -> Map Text [AMXElement]
  -> Map OccurrenceId AMXPresentation
  -> AMXElement
  -> Resolution AMXConnectionPresentation
resolveConnection relationshipIndex objectIndex presentationIndex connection =
  case (relationship, sourceObject, targetObject) of
    (Just relation, Just source, Just target) ->
      case ( presentationFor source
           , presentationFor target
           , endpointDefects relation source target) of
        (Just sourcePresentation, Just targetPresentation, []) ->
          Resolution
            (Just
               AMXConnectionPresentation
                 { connectionElement = connection
                 , connectionRelationship = relation
                 , connectionSourcePresentation = sourcePresentation
                 , connectionTargetPresentation = targetPresentation
                 })
            defects
        _ -> Resolution Nothing defects
    _ -> Resolution Nothing defects
  where
    relationshipName = expandedQName Nothing 'a' "rchimateRelationship"
    sourceName = expandedQName Nothing 's' "ource"
    targetName = expandedQName Nothing 't' "arget"
    relationshipReference = elementAttribute relationshipName connection
    sourceReference = elementAttribute sourceName connection
    targetReference = elementAttribute targetName connection
    relationshipResult =
      resolveRelationship
        relationshipIndex
        relationshipReference
        (attributeReferenceLocation
           relationshipName
           connection
           relationshipReference)
    sourceResult =
      resolveEndpoint
        "source"
        objectIndex
        sourceReference
        (attributeReferenceLocation sourceName connection sourceReference)
    targetResult =
      resolveEndpoint
        "target"
        objectIndex
        targetReference
        (attributeReferenceLocation targetName connection targetReference)
    relationship = resultValue relationshipResult
    sourceObject = resultValue sourceResult
    targetObject = resultValue targetResult
    defects =
      resultDefects relationshipResult
        ++ resultDefects sourceResult
        ++ resultDefects targetResult
        ++ case (relationship, sourceObject, targetObject) of
             (Just relation, Just source, Just target) ->
               endpointDefects relation source target
             _ -> []
    presentationFor object =
      Map.lookup (elementOccurrence "view-object" object) presentationIndex
    endpointDefects relation source target =
      mismatch SourceEndpoint relation source
        ++ mismatch TargetEndpoint relation target
    mismatch role relation object =
      let expected = elementAttribute (endpointQName role) relation
          actual = do
            presentation <- presentationFor object
            elementId (presentationTarget presentation)
       in [ Located
            (amxElementLocation connection)
            (ViewConnectionEndpointMismatch
               (displayId connection)
               (maybe "<missing>" id expected)
               (maybe "<missing>" id actual))
          | expected /= actual
          ]

resolveRelationship ::
     Map Text [AMXElement]
  -> Maybe Text
  -> SourceLocation
  -> Resolution AMXElement
resolveRelationship index reference location =
  case reference >>= (`Map.lookup` index) of
    Nothing ->
      Resolution
        Nothing
        [Located location (UnresolvedViewRelationshipReference reference)]
    Just [relationship] -> Resolution (Just relationship) []
    Just matchedRelationships ->
      case nonEmpty matchedRelationships of
        Nothing ->
          Resolution
            Nothing
            [Located location (UnresolvedViewRelationshipReference reference)]
        Just occurrences ->
          Resolution
            Nothing
            [ Located
                location
                (AmbiguousViewRelationshipReference
                   (maybe "" id reference)
                   (fmap amxElementLocation occurrences))
            ]

resolveEndpoint ::
     Text
  -> Map Text [AMXElement]
  -> Maybe Text
  -> SourceLocation
  -> Resolution AMXElement
resolveEndpoint role index reference location =
  case reference >>= (`Map.lookup` index) of
    Nothing ->
      Resolution
        Nothing
        [Located location (UnresolvedViewConnectionEndpoint role reference)]
    Just [object] -> Resolution (Just object) []
    Just matchedObjects ->
      case nonEmpty matchedObjects of
        Nothing ->
          Resolution
            Nothing
            [Located location (UnresolvedViewConnectionEndpoint role reference)]
        Just occurrences ->
          Resolution
            Nothing
            [ Located
                location
                (AmbiguousViewConnectionEndpoint
                   role
                   (maybe "" id reference)
                   (fmap amxElementLocation occurrences))
            ]

elementsById :: [AMXElement] -> Map Text [AMXElement]
elementsById =
  Map.fromListWith (flip (++))
    . mapMaybe
        (\element ->
           fmap (\identifier -> (identifier, [element])) (elementId element))

isDiagramObject :: AMXElement -> Bool
isDiagramObject element =
  elementType element
    == Just (expandedQName (Just archiNamespace) 'D' "iagramObject")

isConnection :: AMXElement -> Bool
isConnection element =
  elementType element
    == Just (expandedQName (Just archiNamespace) 'C' "onnection")

attributeReferenceLocation ::
     ExpandedQName -> AMXElement -> Maybe Text -> SourceLocation
attributeReferenceLocation name element reference =
  case reference of
    Nothing -> amxElementLocation element
    Just _ -> elementAttributeLocation name element

displayId :: AMXElement -> Text
displayId element =
  maybe
    (occurrenceIdText (elementOccurrence "xml" element))
    id
    (elementId element)

nonEmpty :: [value] -> Maybe (NonEmpty value)
nonEmpty values =
  case values of
    [] -> Nothing
    first:rest -> Just (first :| rest)
