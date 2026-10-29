{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Checked, shared Strategy-to-Strategy primitive evidence and macro support.
-- Preparation visits observed edges and role memberships only. In particular,
-- the Objective join never enumerates lower/upper Key Result combinations.
module O2I.Semantics.StrategyRelations
  ( PreparedStrategyRelations
  , StrategyRelationWork(..)
  , prepareStrategyRelations
  , preparedStrategyRelationWork
  , assessStrategyRelations
  , assessStrategyRelationsWithWork
  , contributionForPair
  , contributionSummary
  , contributionSummaryWithWork
  , requiredStrategyTargets
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Graph.Observation
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types (StrategyFormulationInput(..))
import O2I.Semantics.Index
import O2I.Semantics.Internal
import O2I.Semantics.StrategyRelations.Evidence
import O2I.Semantics.Vocabulary

-- | Account for all preparation and requested result materialization work.
-- Bucket visits include rejected edges; emitted memberships count every
-- original admission before canonical deduplication. Consumers count lookups.
data StrategyRelationWork = StrategyRelationWork
  { strategySourceOccurrenceVisits :: !Int
  , strategyRoleMembershipLookups :: !Int
  , strategyTargetMembershipVisits :: !Int
  , strategyRelationBucketVisits :: !Int
  , strategyRelationOccurrenceVisits :: !Int
  , strategyJoinObjectiveVisits :: !Int
  , strategyOwnerPairLookups :: !Int
  , strategyEmittedEvidenceMemberships :: !Int
  } deriving (Eq, Show)

type role PreparedStrategyRelations nominal

-- | One graph's opaque role-checked evidence, shared by every consumer.
data PreparedStrategyRelations scope = PreparedStrategyRelations
  { preparedStrategies :: !(Map OccurrenceIdentity (PreparedStrategy scope))
  , preparedDirections :: !(Map
                              (OccurrenceIdentity, OccurrenceIdentity)
                              (NonEmpty (DirectionSupport scope)))
  , preparedContributions :: !(Map
                                 (OccurrenceIdentity, OccurrenceIdentity)
                                 (NonEmpty (ContributionSupport scope)))
  , preparedStrategyRelationWork :: !StrategyRelationWork
  }

data MemberRole
  = PolicyRole
  | IntentRole
  | ActionRole
  | KeyResultRole
  deriving (Eq)

type MemberIndex scope
  = Map
      OccurrenceIdentity
      (PreparedStrategy scope, MemberRole, StrategyRoleMember scope)

-- | Build all role maps and original edge buckets once for the selected graph.
prepareStrategyRelations ::
     SemanticIndex scope
  -> [StrategyFormulationAssessment scope]
  -> PreparedStrategyRelations scope
prepareStrategyRelations index assessments =
  PreparedStrategyRelations strategies directions contributions work
  where
    proofs = [proof | StrategyFormulationValid proof <- assessments]
    strategies =
      Map.fromList
        [ ( carrierOccurrenceIdentity (preparedStrategyCarrier strategy)
          , strategy)
        | proof <- proofs
        , Just strategy <- [prepareStrategy index proof]
        ]
    memberships = Map.unions (map roleIndex (Map.elems strategies))
    edges = indexedRelations index
    observed = foldl' (observeEdge memberships) emptyObserved edges
    actionPairs = observedActions observed
    principlePairs = observedPrinciples observed
    translations = observedTranslations observed
    objectiveKeys =
      Map.keysSet translations
        `Set.union` Map.keysSet (observedSubstantiations observed)
    objectives =
      [ ObjectiveContributionSupport lower intent substantiations byUpper
      | objective <- Set.toAscList objectiveKeys
      , Just substantiations <-
          [Map.lookup objective (observedSubstantiations observed)]
      , Just byUpper <- [Map.lookup objective translations]
      , Just (lower, IntentRole, intent) <- [Map.lookup objective memberships]
      ]
    objectivePairs =
      Map.fromListWith
        (<>)
        [ ( (lowerOccurrence, upper)
          , MediatedObjectiveContribution
              (ObjectiveContributionProjection objective buckets)
              :| [])
        | objective <- objectives
        , let lowerOccurrence =
                carrierOccurrenceIdentity
                  (preparedStrategyCarrier (objectiveSupportLower objective))
        , (upper, buckets) <-
            Map.toAscList (objectiveSupportTranslations objective)
        ]
    actionAlternatives =
      Map.map (\edges' -> ActionContribution edges' :| []) actionPairs
    contributions = Map.unionWith (<>) actionAlternatives objectivePairs
    translationPairs =
      Map.fromListWith
        (<>)
        [ ( ( upper
            , carrierOccurrenceIdentity
                (preparedStrategyCarrier
                   (translationLower (NonEmpty.head bucket))))
          , ObjectiveTranslationDirection bucket :| [])
        | byUpper <- Map.elems translations
        , (upper, byKeyResult) <- Map.toAscList byUpper
        , Just bucket <-
            [ NonEmpty.nonEmpty
                (concatMap NonEmpty.toList (Map.elems byKeyResult))
            ]
        ]
    directions =
      Map.unionWith
        (<>)
        (Map.map (\edges' -> GuidingPolicyDirection edges' :| []) principlePairs)
        translationPairs
    membershipCount =
      sum
        [ NonEmpty.length (formulationGuidingPolicy input)
          + NonEmpty.length (formulationIntent input)
          + NonEmpty.length (formulationActions input)
          + NonEmpty.length (formulationKeyResults input)
        | proof <- proofs
        , let input = eligibleStrategyInput proof
        ]
    work =
      StrategyRelationWork
        { strategySourceOccurrenceVisits =
            length (indexedCarriers index) + length edges
        , strategyRoleMembershipLookups = membershipCount + 2 * length edges
        , strategyTargetMembershipVisits =
            sum
              [ Map.size (preparedStrategyActions strategy)
                + Map.size (preparedStrategyKeyResults strategy)
              | strategy <- Map.elems strategies
              ]
        , strategyRelationBucketVisits = observedBucketVisits observed
        , strategyRelationOccurrenceVisits = length edges
        , strategyJoinObjectiveVisits = Set.size objectiveKeys
        , strategyOwnerPairLookups = 0
        , strategyEmittedEvidenceMemberships = 0
        }

prepareStrategy ::
     SemanticIndex scope
  -> QualificationEligibleStrategy scope
  -> Maybe (PreparedStrategy scope)
prepareStrategy index proof = do
  owner <- carrierAt index (eligibleStrategyOccurrence proof)
  if carrierCommitment owner /= Asserted
       || eligibleStrategyGraphIdentity proof
            /= semanticIndexGraphIdentity index
    then Nothing
    else Just
           PreparedStrategy
             { preparedStrategyGraph = semanticIndexGraphIdentity index
             , preparedStrategyCarrier = owner
             , preparedStrategyPrinciples =
                 members
                   endpointStrategyPrinciple
                   (formulationGuidingPolicy input)
             , preparedStrategyIntents =
                 members endpointStrategyObjective (formulationIntent input)
             , preparedStrategyActions = actionMembers
             , preparedStrategyKeyResults = keyResultMembers
             , preparedStrategyTargetActions = Map.keysSet actionMembers
             , preparedStrategyTargetKeyResults = Map.keysSet keyResultMembers
             }
  where
    input = eligibleStrategyInput proof
    actionMembers = members endpointStrategyAction (formulationActions input)
    keyResultMembers =
      members endpointStrategyKeyResult (formulationKeyResults input)
    members endpoint identifiers =
      Map.fromList
        [ (occurrence, StrategyRoleMember carrier ownership)
        | identifier <- NonEmpty.toList identifiers
        , occurrence <- occurrencesForModelIdentity index identifier
        , Just carrier <- [carrierAt index occurrence]
        , carrierQualifiedEndpoint carrier == endpoint
        , carrierCommitment carrier == Asserted
        , Just ownership <- [contextualizationForMember index occurrence]
        , contextualizationOwnerOccurrence ownership
            == eligibleStrategyOccurrence proof
        , contextualizationCommitment ownership == Asserted
        ]

roleIndex :: PreparedStrategy scope -> MemberIndex scope
roleIndex strategy =
  Map.unions
    [ Map.map (\member -> (strategy, role, member)) members
    | (role, members) <-
        [ (PolicyRole, preparedStrategyPrinciples strategy)
        , (IntentRole, preparedStrategyIntents strategy)
        , (ActionRole, preparedStrategyActions strategy)
        , (KeyResultRole, preparedStrategyKeyResults strategy)
        ]
    ]

data ObservedSupport scope = ObservedSupport
  { observedActions :: !(Map
                           (OccurrenceIdentity, OccurrenceIdentity)
                           (NonEmpty (DirectStrategySupport scope)))
  , observedPrinciples :: !(Map
                              (OccurrenceIdentity, OccurrenceIdentity)
                              (NonEmpty (DirectStrategySupport scope)))
  , observedTranslations :: !(Map
                                OccurrenceIdentity
                                (Map
                                   OccurrenceIdentity
                                   (Map
                                      OccurrenceIdentity
                                      (NonEmpty (StrategyTranslation scope)))))
  , observedSubstantiations :: !(Map
                                   OccurrenceIdentity
                                   (NonEmpty (DirectStrategySupport scope)))
  , observedBucketVisits :: !Int
  }

emptyObserved :: ObservedSupport scope
emptyObserved = ObservedSupport Map.empty Map.empty Map.empty Map.empty 0

observeEdge ::
     MemberIndex scope
  -> ObservedSupport scope
  -> RelationObservation scope
  -> ObservedSupport scope
observeEdge members observed relation =
  let !sourceBinding = Map.lookup source members
      !targetBinding = Map.lookup target members
   in case (sourceBinding, targetBinding) of
        (Just (sourceOwner, sourceRole, sourceMember), Just (targetOwner, targetRole, targetMember))
          | relationCommitment relation == Asserted ->
            let direct =
                  DirectStrategySupport sourceMember targetMember relation :| []
                sourceStrategy =
                  carrierOccurrenceIdentity
                    (preparedStrategyCarrier sourceOwner)
                targetStrategy =
                  carrierOccurrenceIdentity
                    (preparedStrategyCarrier targetOwner)
                pair = (sourceStrategy, targetStrategy)
                distinct = sourceStrategy /= targetStrategy
             in case (sourceRole, targetRole) of
                  (ActionRole, ActionRole)
                    | token == tokenContributesTo && distinct ->
                      visited
                        { observedActions =
                            Map.insertWith
                              (<>)
                              pair
                              direct
                              (observedActions observed)
                        }
                  (PolicyRole, PolicyRole)
                    | token == tokenGuides && distinct ->
                      visited
                        { observedPrinciples =
                            Map.insertWith
                              (<>)
                              pair
                              direct
                              (observedPrinciples observed)
                        }
                  (KeyResultRole, IntentRole)
                    | token == tokenTranslatesInto && distinct ->
                      let translation =
                            StrategyTranslation
                              sourceOwner
                              targetOwner
                              sourceMember
                              targetMember
                              relation
                              :| []
                          bucket =
                            Map.singleton
                              sourceStrategy
                              (Map.singleton source translation)
                       in visited
                            { observedTranslations =
                                Map.insertWith
                                  (Map.unionWith (Map.unionWith (<>)))
                                  target
                                  bucket
                                  (observedTranslations observed)
                            }
                  (KeyResultRole, IntentRole)
                    | token == tokenSubstantiates && not distinct ->
                      visited
                        { observedSubstantiations =
                            Map.insertWith
                              (<>)
                              target
                              direct
                              (observedSubstantiations observed)
                        }
                  _ -> visited
        _ -> visited
  where
    source = relationSourceOccurrence relation
    target = relationTargetOccurrence relation
    token = relationToken relation
    visited =
      observed {observedBucketVisits = observedBucketVisits observed + 1}

-- | Select primitive contribution for one actual lower/upper Strategy pair.
contributionForPair ::
     PreparedStrategyRelations scope
  -> OccurrenceIdentity
  -> OccurrenceIdentity
  -> Maybe (NonEmpty (ContributionSupport scope))
contributionForPair prepared lower upper =
  Map.lookup (lower, upper) (preparedContributions prepared)

-- | Canonical summary derived only from checked alternatives.
contributionSummary ::
     NonEmpty (ContributionSupport scope)
  -> (Set.Set OccurrenceIdentity, Set.Set OccurrenceIdentity)
contributionSummary alternatives =
  ( Set.unions (map contributionCoveredTargets values)
  , Set.unions (map contributionWitnesses values))
  where
    values = NonEmpty.toList alternatives

-- | Result projections plus the raw admissions traversed to construct them.
contributionSummaryWithWork ::
     NonEmpty (ContributionSupport scope)
  -> ((Set.Set OccurrenceIdentity, Set.Set OccurrenceIdentity), (Int, Int))
contributionSummaryWithWork alternatives =
  ( contributionSummary alternatives
  , (sum (map fst counts), sum (map snd counts)))
  where
    counts = map contributionMembershipWork (NonEmpty.toList alternatives)

-- | Exact target obligations from one prepared valid Strategy formulation.
requiredStrategyTargets ::
     PreparedStrategyRelations scope
  -> OccurrenceIdentity
  -> Maybe (Set.Set OccurrenceIdentity, Set.Set OccurrenceIdentity)
requiredStrategyTargets prepared occurrence = do
  strategy <- Map.lookup occurrence (preparedStrategies prepared)
  pure
    ( preparedStrategyTargetActions strategy
    , preparedStrategyTargetKeyResults strategy)

-- | Assess explicit macros; primitive support never synthesizes a declaration.
assessStrategyRelations ::
     SemanticIndex scope
  -> [StrategyFormulationAssessment scope]
  -> PreparedStrategyRelations scope
  -> [StrategyRelationAssessment scope]
assessStrategyRelations index assessments prepared =
  fst (assessStrategyRelationsWithWork index assessments prepared)

-- | Exact standalone request work in addition to shared preparation.
assessStrategyRelationsWithWork ::
     SemanticIndex scope
  -> [StrategyFormulationAssessment scope]
  -> PreparedStrategyRelations scope
  -> ([StrategyRelationAssessment scope], StrategyRelationWork)
assessStrategyRelationsWithWork index strategies prepared =
  ( assessments
  , (preparedStrategyRelationWork prepared)
      { strategySourceOccurrenceVisits =
          strategySourceOccurrenceVisits (preparedStrategyRelationWork prepared)
            + length (indexedRelations index)
      , strategyRelationOccurrenceVisits =
          strategyRelationOccurrenceVisits
            (preparedStrategyRelationWork prepared)
            + length (indexedRelations index)
      , strategyOwnerPairLookups =
          length
            [ ()
            | (_, relation, source, target) <- macros
            , relationCommitment relation == Asserted
            , carrierCommitment source == Asserted
            , carrierCommitment target == Asserted
            , null
                (concatMap
                   (prerequisite results . carrierModelIdentity)
                   [source, target])
            ]
      , strategyEmittedEvidenceMemberships =
          sum
            [ relationProofMembershipWork proof
            | StrategyRelationValid _ _ proof <- assessments
            ]
      })
  where
    results =
      Map.fromList
        [(assessmentIdentity assessment, assessment) | assessment <- strategies]
    macros =
      [ (kind, relation, source, target)
      | relation <- indexedRelations index
      , Just (kind, source, target) <- [macroEndpoints index relation]
      ]
    assessments =
      [ assessMacro index results prepared kind relation source target
      | (kind, relation, source, target) <- macros
      ]

macroEndpoints ::
     SemanticIndex scope
  -> RelationObservation scope
  -> Maybe
       ( StrategyRelationKind
       , CarrierObservation scope
       , CarrierObservation scope)
macroEndpoints index relation = do
  source <- carrierAt index (relationSourceOccurrence relation)
  target <- carrierAt index (relationTargetOccurrence relation)
  if carrierQualifiedEndpoint source /= endpointContextStrategy
       || carrierQualifiedEndpoint target /= endpointContextStrategy
    then Nothing
    else if relationToken relation == tokenDirects
           then Just (StrategyDirection, source, target)
           else if relationToken relation == tokenContributesTo
                  then Just (StrategyContribution, source, target)
                  else Nothing

assessMacro ::
     SemanticIndex scope
  -> Map ModelIdentity (StrategyFormulationAssessment scope)
  -> PreparedStrategyRelations scope
  -> StrategyRelationKind
  -> RelationObservation scope
  -> CarrierObservation scope
  -> CarrierObservation scope
  -> StrategyRelationAssessment scope
assessMacro _ results prepared kind relation source target
  | relationCommitment relation == Candidate =
    StrategyRelationCandidate kind relation
  | carrierCommitment source == Candidate
      || carrierCommitment target == Candidate = invalid endpointDefect
  | Just unavailable <- NonEmpty.nonEmpty prerequisites =
    StrategyRelationUnavailable kind relation unavailable
  | otherwise =
    case kind of
      StrategyDirection ->
        case Map.lookup pair (preparedDirections prepared) of
          Just alternatives ->
            StrategyRelationValid
              kind
              relation
              (StrategyDirectionProof relation alternatives)
          Nothing -> invalid directionDefect
      StrategyContribution ->
        case contributionForPair prepared sourceOccurrence targetOccurrence of
          Just alternatives ->
            StrategyRelationValid
              kind
              relation
              (StrategyContributionProof relation alternatives)
          Nothing -> invalid contributionDefect
  where
    sourceOccurrence = carrierOccurrenceIdentity source
    targetOccurrence = carrierOccurrenceIdentity target
    pair = (sourceOccurrence, targetOccurrence)
    relationOccurrence = relationOccurrenceIdentity relation
    key =
      SemanticStrategyRelationEvidenceKey
        relationOccurrence
        sourceOccurrence
        targetOccurrence
    endpointDefect =
      mkSemanticDefect
        Generated.StrategyRelationAssertedEndpointDependencyRule
        key
        (Generated.StrategyRelationAssertedEndpointDependencyOccurrences
           relationOccurrence
           sourceOccurrence
           targetOccurrence)
    directionDefect =
      mkSemanticDefect
        Generated.StrategyRelationDirectionSupportRule
        key
        (Generated.StrategyRelationDirectionSupportOccurrences
           relationOccurrence
           sourceOccurrence
           targetOccurrence)
    contributionDefect =
      mkSemanticDefect
        Generated.StrategyRelationContributionSupportRule
        key
        (Generated.StrategyRelationContributionSupportOccurrences
           relationOccurrence
           sourceOccurrence
           targetOccurrence)
    invalid defect = StrategyRelationInvalid kind relation (defect :| [])
    prerequisites =
      concatMap (prerequisite results . carrierModelIdentity) [source, target]

prerequisite ::
     Map ModelIdentity (StrategyFormulationAssessment scope)
  -> ModelIdentity
  -> [(ModelIdentity, StrategyRelationUnavailableReason)]
prerequisite results identifier =
  case Map.lookup identifier results of
    Just (StrategyFormulationValid _) -> []
    Just (StrategyFormulationInvalid _ _) ->
      [(identifier, StrategyRelationFormulationInvalid)]
    Just (StrategyFormulationCandidate _ _) ->
      [(identifier, StrategyRelationFormulationCandidate)]
    Just (StrategyFormulationUnavailable _ StrategyFormulationIdentityUnresolved) ->
      [(identifier, StrategyRelationFormulationIdentityUnresolved)]
    _ -> [(identifier, StrategyRelationFormulationMissing)]

assessmentIdentity :: StrategyFormulationAssessment scope -> ModelIdentity
assessmentIdentity assessment =
  case assessment of
    StrategyFormulationUnavailable identifier _ -> identifier
    StrategyFormulationCandidate identifier _ -> identifier
    StrategyFormulationInvalid identifier _ -> identifier
    StrategyFormulationValid proof -> eligibleStrategyIdentity proof
