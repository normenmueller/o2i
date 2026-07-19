{-# LANGUAGE OverloadedStrings #-}

-- | Opaque projection of a closed semantic scope into the O2I raw graph.
module O2I.Inspection.Import
  ( ImportedGraph
  , buildImportedGraph
  , importedRawGraph
  , importedClosedScopeProvenance
  , importedSourceIdentity
  , importedView
  , importedLocationsForSubjects
  ) where

import Data.List (nub)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import O2I
import O2I.Inspection.Diagnostic
  ( DiagnosticSubject(..)
  , rawEdgeSubjectIdentifier
  )
import O2I.Inspection.Profile.Internal
import O2I.Inspection.Provenance
import O2I.Inspection.Scope.Internal
import O2I.Inspection.View

-- | Raw graph bound to complete occurrence provenance for one closed View.
data ImportedGraph = ImportedGraph
  { importedGraphRaw :: RawGraph
  , importedGraphClosedScopeProvenance :: ClosedScopeProvenance
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
    , importedGraphClosedScopeProvenance = closedScopeProvenance scope
    , importedGraphSource =
        locationSource (resolvedViewLocation (closedScopeView scope))
    , importedGraphView = closedScopeView scope
    , importedGraphSubjectLocations = subjectLocations
    }
  where
    facts = closedScopeFacts scope
    included occurrence = Set.member occurrence (closedScopeOccurrences scope)
    subjectLocations =
      Map.fromListWith (flip (++)) (concatMap (factSubjects included) facts)

-- | Read the exact unchecked graph sent to structural validation.
importedRawGraph :: ImportedGraph -> RawGraph
importedRawGraph = importedGraphRaw

-- | Read the canonical provenance artifact of the imported closed scope.
importedClosedScopeProvenance :: ImportedGraph -> ClosedScopeProvenance
importedClosedScopeProvenance = importedGraphClosedScopeProvenance

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
    rawEdgeText = rawEdgeSubjectIdentifier

rawNodeIdentifier :: RawNode -> RawNodeId
rawNodeIdentifier node =
  case node of
    RawContextNode identifier _ -> identifier
    RawPrimitiveNode identifier _ _ -> identifier
    RawStructuringNode identifier _ _ -> identifier
    RawAnchorNode identifier _ -> identifier
