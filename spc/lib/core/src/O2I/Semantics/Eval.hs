-- | Fixed Core semantic evaluation pipeline.
module O2I.Semantics.Eval
  ( assessSemantics
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import O2I.Core.Graph.Observation
  ( Commitment(..)
  , carrierCommitment
  , carrierOccurrenceIdentity
  , contextualizationCommitment
  , contextualizationOccurrenceIdentity
  , relationCommitment
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity (OccurrenceIdentity)
import O2I.Input.Internal.Types (BoundSupplementalInputs)
import O2I.Semantics.Contextualization
  ( assessAssertedContextualizationDependencies
  )
import O2I.Semantics.Family.CollectiveStrategyRealization
  ( assessCollectiveStrategyRealizations
  )
import O2I.Semantics.Index (buildSemanticIndex)
import O2I.Semantics.Internal
import O2I.Semantics.SituatedNeed (assessSituatedNeeds)
import O2I.Semantics.Strategy (assessStrategyFormulations)
import O2I.Structure
  ( WellFormedGraph
  , structuredPropositionCommitment
  , structuredPropositionOccurrence
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )

-- | Evaluate every fixed Core semantic family over one selected View.
assessSemantics ::
     WellFormedGraph scope
  -> BoundSupplementalInputs scope
  -> SemanticAssessment scope
assessSemantics graph inputs =
  case NonEmpty.nonEmpty defects of
    Just failures -> SemanticsRejected results failures
    Nothing
      | unavailable -> SemanticsUnavailable results
      | otherwise ->
        SemanticsAccepted
          results
          SemanticallyValidModel
            { semanticModelGraph = graph
            , semanticModelSituatedNeeds = validNeeds
            , semanticModelEligibleStrategies = validStrategies
            , semanticModelCollectiveRealizations = validCollectives
            }
  where
    semanticIndex = buildSemanticIndex graph inputs
    needs = assessSituatedNeeds semanticIndex
    strategies = assessStrategyFormulations semanticIndex
    collectives = assessCollectiveStrategyRealizations semanticIndex strategies
    contextualizationDefects =
      assessAssertedContextualizationDependencies semanticIndex graph
    defects =
      sortSemanticDefects
        (contextualizationDefects
           ++ concatMap situatedNeedDefects needs
           ++ concatMap strategyDefects strategies
           ++ concatMap collectiveDefects collectives)
    unavailable =
      any strategyUnavailable strategies
        || any collectiveUnavailable collectives
    results =
      SemanticResults
        { storedSituatedNeedAssessments = needs
        , storedStrategyAssessments = strategies
        , storedCollectiveAssessments = collectives
        , storedCandidateOccurrences = candidateOccurrences graph
        }
    validNeeds = [proof | SituatedNeedValid proof <- needs]
    validStrategies = [proof | StrategyFormulationValid proof <- strategies]
    validCollectives =
      [proof | CollectiveStrategyRealizationValid proof _ <- collectives]

situatedNeedDefects :: SituatedNeedAssessment scope -> [SemanticDefect]
situatedNeedDefects assessment =
  case assessment of
    SituatedNeedInvalid _ failures -> NonEmpty.toList failures
    _ -> []

strategyDefects :: StrategyFormulationAssessment scope -> [SemanticDefect]
strategyDefects assessment =
  case assessment of
    StrategyFormulationInvalid _ failures -> NonEmpty.toList failures
    _ -> []

collectiveDefects ::
     CollectiveStrategyRealizationAssessment scope -> [SemanticDefect]
collectiveDefects assessment =
  case assessment of
    CollectiveStrategyRealizationInvalid _ _ failures ->
      NonEmpty.toList failures
    _ -> []

strategyUnavailable :: StrategyFormulationAssessment scope -> Bool
strategyUnavailable assessment =
  case assessment of
    StrategyFormulationUnavailable _ _ -> True
    _ -> False

collectiveUnavailable :: CollectiveStrategyRealizationAssessment scope -> Bool
collectiveUnavailable assessment =
  case assessment of
    CollectiveStrategyRealizationUnavailable _ _ -> True
    _ -> False

candidateOccurrences :: WellFormedGraph scope -> [OccurrenceIdentity]
candidateOccurrences graph =
  Set.toAscList . Set.fromList
    $ [ carrierOccurrenceIdentity carrier
      | carrier <- wellFormedCarriers graph
      , carrierCommitment carrier == Candidate
      ]
        ++ [ relationOccurrenceIdentity relation
           | relation <- wellFormedRelations graph
           , relationCommitment relation == Candidate
           ]
        ++ [ contextualizationOccurrenceIdentity contextualization
           | contextualization <- wellFormedContextualizations graph
           , contextualizationCommitment contextualization == Candidate
           ]
        ++ [ structuredPropositionOccurrence proposition
           | proposition <- wellFormedStructuredPropositions graph
           , structuredPropositionCommitment proposition == Candidate
           ]
