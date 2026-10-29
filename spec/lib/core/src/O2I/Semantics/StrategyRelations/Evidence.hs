{-# LANGUAGE RoleAnnotations #-}

-- | Private proof spine constructed by checked Strategy-relation preparation.
--
-- This module depends only on foundational observations. It keeps the shared
-- Objective join intact when assessments retain a proof, without coupling the
-- relation evaluator to collective realization or public result rendering.
module O2I.Semantics.StrategyRelations.Evidence
  ( StrategyRelationKind(..)
  , StrategyRoleMember(..)
  , PreparedStrategy(..)
  , StrategyTranslation(..)
  , ObjectiveContributionSupport(..)
  , ObjectiveContributionProjection(..)
  , DirectStrategySupport(..)
  , DirectionSupport(..)
  , ContributionSupport(..)
  , StrategyRelationProof(..)
  , contributionCoveredTargets
  , contributionWitnesses
  , directionWitnesses
  , relationProofWitnesses
  , contributionMembershipWork
  , relationProofMembershipWork
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , ContextualizationObservation
  , RelationObservation
  , carrierOccurrenceIdentity
  , contextualizationOccurrenceIdentity
  , relationOccurrenceIdentity
  , relationTargetOccurrence
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)

-- | The two explicit Strategy macro meanings assessed by this domain.
data StrategyRelationKind
  = StrategyDirection
  | StrategyContribution
  deriving (Bounded, Enum, Eq, Ord, Show)

type role StrategyRoleMember nominal

-- | Exact asserted carrier and its asserted ownership in one checked role.
data StrategyRoleMember scope = StrategyRoleMember
  { roleMemberCarrier :: !(CarrierObservation scope)
  , roleMemberContextualization :: !(ContextualizationObservation scope)
  } deriving (Eq, Show)

type role PreparedStrategy nominal

-- | A valid formulation's distinct role membership maps, prepared once.
data PreparedStrategy scope = PreparedStrategy
  { preparedStrategyGraph :: !ModelIdentity
  , preparedStrategyCarrier :: !(CarrierObservation scope)
  , preparedStrategyPrinciples :: !(Map
                                      OccurrenceIdentity
                                      (StrategyRoleMember scope))
  , preparedStrategyIntents :: !(Map
                                   OccurrenceIdentity
                                   (StrategyRoleMember scope))
  , preparedStrategyActions :: !(Map
                                   OccurrenceIdentity
                                   (StrategyRoleMember scope))
  , preparedStrategyKeyResults :: !(Map
                                      OccurrenceIdentity
                                      (StrategyRoleMember scope))
  , preparedStrategyTargetActions :: !(Set.Set OccurrenceIdentity)
  , preparedStrategyTargetKeyResults :: !(Set.Set OccurrenceIdentity)
  } deriving (Eq, Show)

type role StrategyTranslation nominal

-- | One original translation with exact upper/lower owner and role binding.
data StrategyTranslation scope = StrategyTranslation
  { translationUpper :: !(PreparedStrategy scope)
  , translationLower :: !(PreparedStrategy scope)
  , translationUpperKeyResult :: !(StrategyRoleMember scope)
  , translationLowerIntent :: !(StrategyRoleMember scope)
  , translationRelation :: !(RelationObservation scope)
  } deriving (Eq, Show)

type role ObjectiveContributionSupport nominal

-- | Nonempty sides of one exact lower-Objective join. Lower substantiations
-- are retained once, rather than multiplied by upper Key Results.
data ObjectiveContributionSupport scope = ObjectiveContributionSupport
  { objectiveSupportLower :: !(PreparedStrategy scope)
  , objectiveSupportIntent :: !(StrategyRoleMember scope)
  , objectiveSupportSubstantiations :: !(NonEmpty (DirectStrategySupport scope))
  , objectiveSupportTranslations :: !(Map
                                        OccurrenceIdentity
                                        (Map
                                           OccurrenceIdentity
                                           (NonEmpty (StrategyTranslation scope))))
  } deriving (Eq, Show)

type role ObjectiveContributionProjection nominal

-- | Selection of the upper Strategy's translation buckets from shared support.
data ObjectiveContributionProjection scope = ObjectiveContributionProjection
  { objectiveProjectionSupport :: !(ObjectiveContributionSupport scope)
  , objectiveProjectionTranslations :: !(Map
                                           OccurrenceIdentity
                                           (NonEmpty (StrategyTranslation scope)))
  } deriving (Eq, Show)

type role DirectStrategySupport nominal

-- | One original role-bound primitive relation, including both ownerships.
data DirectStrategySupport scope = DirectStrategySupport
  { directSupportSource :: !(StrategyRoleMember scope)
  , directSupportTarget :: !(StrategyRoleMember scope)
  , directSupportRelation :: !(RelationObservation scope)
  } deriving (Eq, Show)

type role DirectionSupport nominal

-- | Closed alternatives supporting an explicit direction claim.
data DirectionSupport scope
  = GuidingPolicyDirection !(NonEmpty (DirectStrategySupport scope))
  | ObjectiveTranslationDirection !(NonEmpty (StrategyTranslation scope))
  deriving (Eq, Show)

type role ContributionSupport nominal

-- | Closed alternatives supporting contribution and collective coverage.
data ContributionSupport scope
  = ActionContribution !(NonEmpty (DirectStrategySupport scope))
  | MediatedObjectiveContribution !(ObjectiveContributionProjection scope)
  deriving (Eq, Show)

type role StrategyRelationProof nominal

-- | Explicit macro occurrence with nonempty checked primitive alternatives.
data StrategyRelationProof scope
  = StrategyDirectionProof
      !(RelationObservation scope)
      !(NonEmpty (DirectionSupport scope))
  | StrategyContributionProof
      !(RelationObservation scope)
      !(NonEmpty (ContributionSupport scope))
  deriving (Eq, Show)

-- | Exact upper members covered by one contribution alternative.
contributionCoveredTargets ::
     ContributionSupport scope -> Set.Set OccurrenceIdentity
contributionCoveredTargets = Set.fromList . contributionCoverageEntries

-- | Canonical original evidence, preserving each side of the shared join.
contributionWitnesses :: ContributionSupport scope -> Set.Set OccurrenceIdentity
contributionWitnesses = Set.fromList . contributionWitnessEntries

-- | Raw admissions visited before canonical deduplication. The same lists
-- feed the evidence projections, including repeated endpoint/ownership entries.
contributionMembershipWork :: ContributionSupport scope -> (Int, Int)
contributionMembershipWork support =
  ( length (contributionCoverageEntries support)
  , length (contributionWitnessEntries support))

contributionCoverageEntries :: ContributionSupport scope -> [OccurrenceIdentity]
contributionCoverageEntries support =
  case support of
    ActionContribution edges ->
      map
        (relationTargetOccurrence . directSupportRelation)
        (NonEmpty.toList edges)
    MediatedObjectiveContribution projection ->
      Map.keys (objectiveProjectionTranslations projection)

contributionWitnessEntries :: ContributionSupport scope -> [OccurrenceIdentity]
contributionWitnessEntries support =
  case support of
    ActionContribution edges ->
      concatMap directWitnessEntries (NonEmpty.toList edges)
    MediatedObjectiveContribution projection ->
      concatMap
        directWitnessEntries
        (NonEmpty.toList
           (objectiveSupportSubstantiations
              (objectiveProjectionSupport projection)))
        ++ concatMap
             translationWitnessEntries
             (concatMap
                NonEmpty.toList
                (Map.elems (objectiveProjectionTranslations projection)))

-- | Canonical original support for one direction alternative.
directionWitnesses :: DirectionSupport scope -> Set.Set OccurrenceIdentity
directionWitnesses = Set.fromList . directionWitnessEntries

directionWitnessEntries :: DirectionSupport scope -> [OccurrenceIdentity]
directionWitnessEntries support =
  case support of
    GuidingPolicyDirection edges ->
      concatMap directWitnessEntries (NonEmpty.toList edges)
    ObjectiveTranslationDirection edges ->
      concatMap translationWitnessEntries (NonEmpty.toList edges)

-- | Public summaries derive from the retained closed proof spine.
relationProofWitnesses :: StrategyRelationProof scope -> [OccurrenceIdentity]
relationProofWitnesses = Set.toAscList . Set.fromList . relationProofEntries

-- | Every original admission visited while materializing a macro result.
relationProofMembershipWork :: StrategyRelationProof scope -> Int
relationProofMembershipWork = length . relationProofEntries

relationProofEntries :: StrategyRelationProof scope -> [OccurrenceIdentity]
relationProofEntries proof =
  case proof of
    StrategyDirectionProof relation alternatives ->
      relationOccurrenceIdentity relation
        : concatMap directionWitnessEntries (NonEmpty.toList alternatives)
    StrategyContributionProof relation alternatives ->
      relationOccurrenceIdentity relation
        : concatMap contributionWitnessEntries (NonEmpty.toList alternatives)

directWitnessEntries :: DirectStrategySupport scope -> [OccurrenceIdentity]
directWitnessEntries support =
  relationOccurrenceIdentity (directSupportRelation support)
    : memberWitnessEntries (directSupportSource support)
    ++ memberWitnessEntries (directSupportTarget support)

translationWitnessEntries :: StrategyTranslation scope -> [OccurrenceIdentity]
translationWitnessEntries translation =
  [ relationOccurrenceIdentity (translationRelation translation)
  , carrierOccurrenceIdentity
      (preparedStrategyCarrier (translationUpper translation))
  , carrierOccurrenceIdentity
      (preparedStrategyCarrier (translationLower translation))
  ]
    ++ memberWitnessEntries (translationUpperKeyResult translation)
    ++ memberWitnessEntries (translationLowerIntent translation)

memberWitnessEntries :: StrategyRoleMember scope -> [OccurrenceIdentity]
memberWitnessEntries member =
  [ carrierOccurrenceIdentity (roleMemberCarrier member)
  , contextualizationOccurrenceIdentity (roleMemberContextualization member)
  ]
