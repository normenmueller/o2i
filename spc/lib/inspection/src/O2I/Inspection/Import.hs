{-# LANGUAGE OverloadedStrings #-}

-- | Opaque projection of a closed semantic scope into the O2I raw graph.
module O2I.Inspection.Import
  ( ImportedGraph
  , buildImportedGraph
  , importedRawGraph
  , importedProvenance
  , importedSourceIdentity
  , importedView
  , importedLocationsForSubjects
  ) where

import Data.List (nub)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Inspection.Diagnostic (DiagnosticSubject(..))
import O2I.Inspection.Profile.Internal
import O2I.Inspection.Provenance
import O2I.Inspection.Scope.Internal
import O2I.Inspection.View

-- | Raw graph bound to complete occurrence provenance for one closed View.
data ImportedGraph = ImportedGraph
  { importedGraphRaw :: RawGraph
  , importedGraphProvenance :: Provenance
  , importedGraphSource :: SourceIdentity
  , importedGraphView :: ResolvedView
  , importedGraphSubjectLocations :: Map (Text, Text) [SourceLocation]
  }

-- | Build the format-neutral graph only from a successful closure witness.
buildImportedGraph :: SemanticallyClosedScope -> ImportedGraph
buildImportedGraph scope =
  ImportedGraph
    { importedGraphRaw =
        RawGraph
          { rawNodes =
              [ node
              | IndexedNode occurrence node _ <- facts
              , included occurrence
              ]
          , rawEdges =
              [ edge
              | IndexedEdge occurrence edge _ <- facts
              , included occurrence
              ]
          }
    , importedGraphProvenance = mkProvenance provenance
    , importedGraphSource =
        locationSource (resolvedViewLocation (closedScopeView scope))
    , importedGraphView = closedScopeView scope
    , importedGraphSubjectLocations = subjectLocations
    }
  where
    facts = closedScopeFacts scope
    included occurrence = Set.member occurrence (closedScopeOccurrences scope)
    provenance = mapMaybe occurrenceProvenance retainedOccurrences
    retainedOccurrences =
      stableUnique
        [ occurrence
        | fact <- facts
        , Just (occurrence, _) <- [factLocation fact]
        , included occurrence
        ]
    locations = Map.fromList (mapMaybe factLocation facts)
    subjectLocations =
      Map.fromListWith (flip (++)) (concatMap (factSubjects included) facts)
    occurrenceProvenance occurrence = do
      location <- Map.lookup occurrence locations
      pure
        OccurrenceProvenance
          { provenanceOccurrenceId = occurrence
          , provenanceLocation = location
          , provenanceReasons =
              Map.findWithDefault [] occurrence (closedScopeReasons scope)
          }

-- | Read the exact unchecked graph sent to structural validation.
importedRawGraph :: ImportedGraph -> RawGraph
importedRawGraph = importedGraphRaw

-- | Read complete ordered occurrence provenance.
importedProvenance :: ImportedGraph -> Provenance
importedProvenance = importedGraphProvenance

-- | Read the immutable acquired-source identity.
importedSourceIdentity :: ImportedGraph -> SourceIdentity
importedSourceIdentity = importedGraphSource

-- | Read the exact selected View.
importedView :: ImportedGraph -> ResolvedView
importedView = importedGraphView

-- | Locate normalized diagnostic subjects in the imported source.
importedLocationsForSubjects ::
     ImportedGraph -> [DiagnosticSubject] -> [SourceLocation]
importedLocationsForSubjects imported subjects =
  nub
    [ location
    | subject <- subjects
    , location <-
        Map.findWithDefault
          []
          (subjectKind subject, subjectIdentifier subject)
          (importedGraphSubjectLocations imported)
    ]

factLocation :: IndexedProfileFact -> Maybe (OccurrenceId, SourceLocation)
factLocation (IndexedOccurrence occurrence location) =
  Just (occurrence, location)
factLocation (IndexedNode occurrence _ location) = Just (occurrence, location)
factLocation (IndexedEdge occurrence _ location) = Just (occurrence, location)
factLocation _ = Nothing

factSubjects ::
     (OccurrenceId -> Bool)
  -> IndexedProfileFact
  -> [((Text, Text), [SourceLocation])]
factSubjects included fact =
  case fact of
    IndexedNode occurrence node location
      | included occurrence -> [(("node", rawNodeText node), [location])]
    IndexedEdge occurrence edge location
      | included occurrence -> [(("edge", rawEdgeText edge), [location])]
    IndexedOccurrence _ _ -> []
    IndexedNode _ _ _ -> []
    IndexedEdge _ _ _ -> []
    IndexedSeed _ _ -> []
    IndexedDependency _ _ _ -> []
    IndexedReference _ _ _ _ -> []
  where
    rawNodeText node = rawNodeIdText (rawNodeIdentifier node)
    rawEdgeText edge =
      Text.intercalate
        ":"
        [ rawNodeIdText (rawEdgeFrom edge)
        , relationNameText (rawEdgeRelation edge)
        , rawNodeIdText (rawEdgeTo edge)
        ]

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier node =
  case node of
    RawContextNode identifier _ -> identifier
    RawPrimitiveNode identifier _ _ -> identifier
    RawStructuringNode identifier _ _ -> identifier
    RawAnchorNode identifier _ -> identifier

stableUnique :: Ord value => [value] -> [value]
stableUnique = go Set.empty
  where
    go _ [] = []
    go seen (value:values)
      | Set.member value seen = go seen values
      | otherwise = value : go (Set.insert value seen) values
