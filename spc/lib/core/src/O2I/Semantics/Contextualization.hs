-- | Assertion-sensitive contextualization semantics.
module O2I.Semantics.Contextualization
  ( assessAssertedContextualizationDependencies
  ) where

import qualified Data.Set as Set
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Graph.Observation
  ( Commitment(..)
  , RelationObservation
  , contextualizationCommitment
  , contextualizationOccurrenceIdentity
  , relationCommitment
  , relationOccurrenceIdentity
  , relationSourceOccurrence
  , relationTargetOccurrence
  )
import O2I.Core.Identity (OccurrenceIdentity)
import O2I.Semantics.Index (SemanticIndex, contextualizationForMember)
import O2I.Semantics.Internal
  ( SemanticDefect
  , SemanticEvidenceKey(..)
  , mkSemanticDefect
  , sortSemanticDefects
  )
import O2I.Structure
  ( StructuredIncidenceObservation
  , StructuredPropositionObservation
  , WellFormedGraph
  , structuredIncidenceEndpoint
  , structuredIncidenceOccurrence
  , structuredPropositionCommitment
  , structuredPropositionIncidences
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )

-- | Reject asserted dependents that rely on Candidate contextualization.
assessAssertedContextualizationDependencies ::
     SemanticIndex scope -> WellFormedGraph scope -> [SemanticDefect]
assessAssertedContextualizationDependencies semanticIndex graph =
  sortSemanticDefects . Set.toAscList . Set.fromList
    $ relationDefects ++ incidenceDefects
  where
    relationDefects =
      concatMap
        (assertedRelationDefects semanticIndex)
        (wellFormedRelations graph)
    incidenceDefects =
      concatMap
        (assertedPropositionDefects semanticIndex)
        (wellFormedStructuredPropositions graph)

assertedRelationDefects ::
     SemanticIndex scope -> RelationObservation scope -> [SemanticDefect]
assertedRelationDefects semanticIndex relation
  | relationCommitment relation == Candidate = []
  | otherwise =
    concatMap
      (dependencyDefect semanticIndex dependent)
      [relationSourceOccurrence relation, relationTargetOccurrence relation]
  where
    dependent = relationOccurrenceIdentity relation

assertedPropositionDefects ::
     SemanticIndex scope
  -> StructuredPropositionObservation scope
  -> [SemanticDefect]
assertedPropositionDefects semanticIndex proposition
  | structuredPropositionCommitment proposition == Candidate = []
  | otherwise =
    concatMap
      (assertedIncidenceDefects semanticIndex)
      (structuredPropositionIncidences proposition)

assertedIncidenceDefects ::
     SemanticIndex scope
  -> StructuredIncidenceObservation scope
  -> [SemanticDefect]
assertedIncidenceDefects semanticIndex incidence =
  dependencyDefect
    semanticIndex
    (structuredIncidenceOccurrence incidence)
    (structuredIncidenceEndpoint incidence)

dependencyDefect ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> OccurrenceIdentity
  -> [SemanticDefect]
dependencyDefect semanticIndex dependent endpoint =
  case contextualizationForMember semanticIndex endpoint of
    Just contextualization
      | contextualizationCommitment contextualization == Candidate ->
        [ mkSemanticDefect
            Generated.ContextualizationAssertedDependencyRule
            (SemanticAssertedDependencyEvidenceKey dependent endpoint context)
            (Generated.ContextualizationAssertedDependencyOccurrences
               dependent
               endpoint
               context)
        ]
      where context = contextualizationOccurrenceIdentity contextualization
    _ -> []
