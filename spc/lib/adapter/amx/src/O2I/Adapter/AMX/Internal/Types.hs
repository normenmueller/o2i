{-# LANGUAGE OverloadedStrings #-}

-- | Internal source-preserving AMX representation.
module O2I.Adapter.AMX.Internal.Types
  ( AMXDocument(..)
  , AMXElement(..)
  , AMXSelectedView(..)
  , AMXPresentation(..)
  , AMXConnectionPresentation(..)
  , AMXProfileFact(..)
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

elementAttribute :: ExpandedQName -> AMXElement -> Maybe Text
elementAttribute name = Map.lookup name . amxElementAttributes

elementAttributeLocation :: ExpandedQName -> AMXElement -> SourceLocation
elementAttributeLocation name element =
  (amxElementLocation element) {locationTarget = AttributeTarget name}

elementChildrenNamed :: Text -> AMXElement -> [AMXElement]
elementChildrenNamed local =
  filter ((== ExpandedQName Nothing local) . amxElementQName)
    . amxElementChildren

elementDescendants :: AMXElement -> [AMXElement]
elementDescendants element =
  concatMap
    (\child -> child : elementDescendants child)
    (amxElementChildren element)

elementDirectProperties :: AMXElement -> [AMXElement]
elementDirectProperties = elementChildrenNamed "property"

elementId :: AMXElement -> Maybe Text
elementId = elementAttribute (ExpandedQName Nothing "id")

elementName :: AMXElement -> Text
elementName = maybe "" id . elementAttribute (ExpandedQName Nothing "name")

elementOccurrence :: Text -> AMXElement -> OccurrenceId
elementOccurrence prefix element =
  OccurrenceId (prefix <> ":" <> locationPathText (amxElementLocation element))

elementType :: AMXElement -> Maybe ExpandedQName
elementType element = do
  value <-
    elementAttribute
      (ExpandedQName (Just "http://www.w3.org/2001/XMLSchema-instance") "type")
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
         (ExpandedQName
            (Just "http://www.archimatetool.com/archimate")
            "ArchimateDiagramModel")

resolveQNameValue :: AMXElement -> Text -> Maybe ExpandedQName
resolveQNameValue element value =
  case Text.breakOn ":" value of
    (prefix, suffix)
      | Text.null suffix ->
        Just
          (ExpandedQName (Map.lookup "" (amxElementNamespaces element)) prefix)
      | otherwise -> do
        namespace <- Map.lookup prefix (amxElementNamespaces element)
        Just (ExpandedQName (Just namespace) (Text.drop 1 suffix))

locationPathText :: SourceLocation -> Text
locationPathText =
  Text.intercalate "/" . map pathStepText . toList . locationPath
  where
    toList (first :| rest) = first : rest
    pathStepText step =
      let name = pathStepName step
       in "{"
            <> maybe "" id (qNameNamespace name)
            <> "}"
            <> qNameLocalName name
            <> "["
            <> Text.pack (show (pathStepOrdinal step))
            <> "]"
