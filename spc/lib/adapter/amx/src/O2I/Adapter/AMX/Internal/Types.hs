{-# LANGUAGE OverloadedStrings #-}

-- | Internal source-preserving AMX representation.
module O2I.Adapter.AMX.Internal.Types
  ( AMXDocument(..)
  , AMXElement(..)
  , AMXSelectedView(..)
  , AMXPresentation(..)
  , AMXConnectionPresentation(..)
  , AMXProfileFact(..)
  , AMXOccurrenceKind(..)
  , EndpointRole(..)
  , endpointQName
  , elementAttribute
  , elementAttributeLocation
  , elementChildrenNamed
  , elementDescendants
  , elementDirectProperties
  , elementId
  , elementName
  , elementOccurrence
  , elementType
  , isRelationshipElement
  , isViewElement
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Inspection.Provenance

-- | XML element annotated with a stable expanded-QName path.
data AMXElement = AMXElement
  { amxElementQName :: ExpandedQName
  , amxElementAttributes :: Map ExpandedQName Text
  , amxElementChildren :: [AMXElement]
  , amxElementLocator :: SourceLocator
  , amxElementLocation :: SourceLocation
  , amxElementNamespaces :: Map Text Text
  } deriving (Eq, Show)

-- | Successfully decoded native AMX document.
data AMXDocument = AMXDocument
  { amxDocumentRoot :: AMXElement
  , amxDocumentElements :: [AMXElement]
  } deriving (Eq, Show)

-- | One validated object presentation in the selected View.
data AMXPresentation = AMXPresentation
  { presentationElement :: AMXElement
  , presentationTarget :: AMXElement
  } deriving (Eq, Show)

-- | One validated relationship presentation in the selected View.
data AMXConnectionPresentation = AMXConnectionPresentation
  { connectionElement :: AMXElement
  , connectionRelationship :: AMXElement
  , connectionSourcePresentation :: AMXPresentation
  , connectionTargetPresentation :: AMXPresentation
  } deriving (Eq, Show)

-- | Selected View after exact reference and endpoint validation.
data AMXSelectedView = AMXSelectedView
  { selectedViewElement :: AMXElement
  , selectedPresentations :: [AMXPresentation]
  , selectedConnections :: [AMXConnectionPresentation]
  } deriving (Eq, Show)

-- | Complete adapter-owned observation supplied to profile projection.
data AMXProfileFact =
  AMXProfileFact AMXDocument AMXSelectedView
  deriving (Eq, Show)

-- | Closed AMX occurrence vocabulary, distinct from persisted model IDs and
-- human presentation labels.
data AMXOccurrenceKind
  = XmlOccurrence
  | NodeOccurrence
  | RelationshipOccurrence
  | PresentationOccurrence
  | ConnectionOccurrence
  | ViewObjectOccurrence
  | RelationshipSourceReferenceOccurrence
  | RelationshipTargetReferenceOccurrence
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed native relationship endpoint vocabulary.
data EndpointRole
  = SourceEndpoint
  | TargetEndpoint
  deriving (Bounded, Enum, Eq, Ord, Show)

endpointQName :: EndpointRole -> ExpandedQName
endpointQName role =
  case role of
    SourceEndpoint -> expandedQName Nothing 's' "ource"
    TargetEndpoint -> expandedQName Nothing 't' "arget"

elementAttribute :: ExpandedQName -> AMXElement -> Maybe Text
elementAttribute name = Map.lookup name . amxElementAttributes

elementAttributeLocation :: ExpandedQName -> AMXElement -> SourceLocation
elementAttributeLocation name element =
  locateSource
    (amxElementLocator element)
    (locationPath (amxElementLocation element))
    (AttributeTarget name)
    (locationSpan (amxElementLocation element))

elementChildrenNamed :: ExpandedQName -> AMXElement -> [AMXElement]
elementChildrenNamed name =
  filter ((== name) . amxElementQName) . amxElementChildren

elementDescendants :: AMXElement -> [AMXElement]
elementDescendants element =
  concatMap
    (\child -> child : elementDescendants child)
    (amxElementChildren element)

elementDirectProperties :: AMXElement -> [AMXElement]
elementDirectProperties =
  elementChildrenNamed (expandedQName Nothing 'p' "roperty")

elementId :: AMXElement -> Maybe Text
elementId = elementAttribute (expandedQName Nothing 'i' "d")

elementName :: AMXElement -> Text
elementName = maybe "" id . elementAttribute (expandedQName Nothing 'n' "ame")

elementOccurrence :: AMXOccurrenceKind -> AMXElement -> OccurrenceId
elementOccurrence kind element =
  occurrenceId
    (occurrenceKindLiteral (kindLiteral kind))
    (locationPath (amxElementLocation element))

elementType :: AMXElement -> Maybe ExpandedQName
elementType element = do
  value <-
    elementAttribute
      (expandedQName
         (Just "http://www.w3.org/2001/XMLSchema-instance")
         't'
         "ype")
      element
  resolveQNameValue element value

isRelationshipElement :: AMXElement -> Bool
isRelationshipElement element =
  maybe
    False
    (Text.isSuffixOf "Relationship" . qNameLocalName)
    (elementType element)

isViewElement :: AMXElement -> Bool
isViewElement element =
  elementType element
    == Just
         (expandedQName
            (Just "http://www.archimatetool.com/archimate")
            'A'
            "rchimateDiagramModel")

resolveQNameValue :: AMXElement -> Text -> Maybe ExpandedQName
resolveQNameValue element value =
  case Text.breakOn ":" value of
    (prefix, suffix)
      | Text.null suffix ->
        either
          (const Nothing)
          Just
          (mkExpandedQName (Map.lookup "" (amxElementNamespaces element)) prefix)
      | otherwise -> do
        namespace <- Map.lookup prefix (amxElementNamespaces element)
        either
          (const Nothing)
          Just
          (mkExpandedQName (Just namespace) (Text.drop 1 suffix))

kindLiteral :: AMXOccurrenceKind -> NonEmpty Char
kindLiteral kind =
  case kind of
    XmlOccurrence -> 'x' :| "ml"
    NodeOccurrence -> 'n' :| "ode"
    RelationshipOccurrence -> 'r' :| "elationship"
    PresentationOccurrence -> 'p' :| "resentation"
    ConnectionOccurrence -> 'c' :| "onnection"
    ViewObjectOccurrence -> 'v' :| "iew-object"
    RelationshipSourceReferenceOccurrence ->
      'r' :| "elationship-source-reference"
    RelationshipTargetReferenceOccurrence ->
      'r' :| "elationship-target-reference"
