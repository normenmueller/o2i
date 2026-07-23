{-# LANGUAGE OverloadedStrings #-}

-- | Opaque projection of a closed semantic scope into the O2I raw graph.
module O2I.Inspection.Import
  ( ImportedGraph
  , ImportedCollectiveClaim
  , buildImportedGraph
  , importedClaimGraph
  , importedCollectiveClaims
  , importedCollectiveOccurrence
  , importedCollectiveClaim
  , importedCollectiveLocation
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
  { importedGraphClaims :: RawClaimGraph
  , importedGraphCollectiveClaims :: [ImportedCollectiveClaim]
  , importedGraphClosedScopeProvenance :: ClosedScopeProvenance
  , importedGraphSource :: SourceIdentity
  , importedGraphView :: ResolvedView SourceLocation
  , importedGraphSubjectLocations :: Map (Text, Text) [SourceLocation]
  }

-- | One imported collective claim with exact occurrence provenance.
data ImportedCollectiveClaim =
  ImportedCollectiveClaim
    OccurrenceId
    (Claim RawCollectiveStrategyRealization)
    SourceLocation

-- | Build the format-neutral graph only from a successful closure witness.
buildImportedGraph :: SemanticallyClosedScope -> ImportedGraph
buildImportedGraph scope =
  ImportedGraph
    { importedGraphClaims =
        RawClaimGraph
          { rawNodeClaims =
              [ claim
              | IndexedNode occurrence node _ <- facts
              , included occurrence
              , let claim = node
              ]
          , rawEdgeClaims =
              [ claim
              | IndexedEdge occurrence edge _ <- facts
              , included occurrence
              , let claim = edge
              ]
          }
    , importedGraphCollectiveClaims =
        [ ImportedCollectiveClaim occurrence claim location
        | IndexedCollectiveStrategyRealization occurrence claim _ _ location <-
            facts
        , included occurrence
        ]
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

-- | Read the exact unchecked graph claims sent to structural validation.
importedClaimGraph :: ImportedGraph -> RawClaimGraph
importedClaimGraph = importedGraphClaims

-- | Enumerate imported collective claims in source order.
importedCollectiveClaims :: ImportedGraph -> [ImportedCollectiveClaim]
importedCollectiveClaims = importedGraphCollectiveClaims

-- | Read the exact persisted occurrence of an imported collective claim.
importedCollectiveOccurrence :: ImportedCollectiveClaim -> OccurrenceId
importedCollectiveOccurrence (ImportedCollectiveClaim occurrence _ _) =
  occurrence

-- | Read the commitment-bearing collective claim imported from one occurrence.
importedCollectiveClaim ::
     ImportedCollectiveClaim -> Claim RawCollectiveStrategyRealization
importedCollectiveClaim (ImportedCollectiveClaim _ claim _) = claim

-- | Read the source location of an imported collective claim.
importedCollectiveLocation :: ImportedCollectiveClaim -> SourceLocation
importedCollectiveLocation (ImportedCollectiveClaim _ _ location) = location

-- | Read the canonical provenance artifact of the imported closed scope.
importedClosedScopeProvenance :: ImportedGraph -> ClosedScopeProvenance
importedClosedScopeProvenance = importedGraphClosedScopeProvenance

-- | Read the immutable acquired-source identity.
importedSourceIdentity :: ImportedGraph -> SourceIdentity
importedSourceIdentity = importedGraphSource

-- | Read the exact selected View.
importedView :: ImportedGraph -> ResolvedView SourceLocation
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
  -> IndexedProfileFact SourceLocation
  -> [((Text, Text), [SourceLocation])]
factSubjects included fact =
  case fact of
    IndexedNode occurrence claim location
      | included occurrence ->
        [(("node", rawNodeText (claimedProposition claim)), [location])]
    IndexedEdge occurrence claim location
      | included occurrence ->
        [(("edge", rawEdgeText (claimedProposition claim)), [location])]
    IndexedCollectiveStrategyRealization occurrence claim _ _ location
      | included occurrence ->
        [ ( ( "collective-claim"
            , claimIdText (rawRealizationId (claimedProposition claim)))
          , [location])
        ]
    IndexedOccurrence _ _ -> []
    IndexedNode _ _ _ -> []
    IndexedEdge _ _ _ -> []
    IndexedCollectiveStrategyRealization _ _ _ _ _ -> []
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
