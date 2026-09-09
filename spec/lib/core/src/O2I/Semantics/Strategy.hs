{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Family-specific assessment of complete Strategy formulations.
module O2I.Semantics.Strategy
  ( assessStrategyFormulations
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import qualified Data.Text as Text
import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRelationToken)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , Commitment(..)
  , RelationObservation
  , carrierCommitment
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationOccurrenceIdentity
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Input.Internal.Types (StrategyFormulationInput(..))
import O2I.Semantics.Index
import O2I.Semantics.Internal
import O2I.Semantics.Vocabulary

-- | Assess every Strategy in canonical occurrence order.
assessStrategyFormulations ::
     SemanticIndex scope -> [StrategyFormulationAssessment scope]
assessStrategyFormulations semanticIndex =
  map
    (assessStrategy semanticIndex)
    (carriersAtEndpoint semanticIndex endpointContextStrategy)

assessStrategy ::
     SemanticIndex scope
  -> CarrierObservation scope
  -> StrategyFormulationAssessment scope
assessStrategy semanticIndex strategy =
  case carrierCommitment strategy of
    Candidate ->
      StrategyFormulationCandidate strategyIdentity strategyOccurrence
    Asserted ->
      case strategyFormulationInputFor semanticIndex strategyIdentity of
        Nothing ->
          StrategyFormulationUnavailable
            strategyIdentity
            StrategyFormulationInputMissing
        Just formulation -> assessFormulation semanticIndex strategy formulation
  where
    strategyIdentity = carrierModelIdentity strategy
    strategyOccurrence = carrierOccurrenceIdentity strategy

assessFormulation ::
     SemanticIndex scope
  -> CarrierObservation scope
  -> StrategyFormulationInput
  -> StrategyFormulationAssessment scope
assessFormulation semanticIndex strategy formulation =
  case NonEmpty.nonEmpty (sortSemanticDefects defects) of
    Just failures -> StrategyFormulationInvalid strategyIdentity failures
    Nothing
      | not allIdentitySitesResolved ->
        StrategyFormulationUnavailable
          strategyIdentity
          StrategyFormulationIdentityUnresolved
    Nothing ->
      StrategyFormulationValid
        QualificationEligibleStrategy
          { eligibleStrategyGraphIdentity =
              semanticIndexGraphIdentity semanticIndex
          , eligibleStrategyIdentity = strategyIdentity
          , eligibleStrategyOccurrence = strategyOccurrence
          , eligibleStrategyInput = formulation
          , eligibleStrategyWitnesses = Set.toAscList (Set.fromList witnesses)
          }
  where
    strategyIdentity = carrierModelIdentity strategy
    strategyOccurrence = carrierOccurrenceIdentity strategy
    diagnosis = resolveMembers "/diagnosis" (formulationDiagnosis formulation)
    intents = resolveMembers "/intent" (formulationIntent formulation)
    policies =
      resolveMembers "/guidingPolicy" (formulationGuidingPolicy formulation)
    actions = resolveMembers "/actions" (formulationActions formulation)
    keyResults =
      resolveMembers "/keyResults" (formulationKeyResults formulation)
    diagnosisResolved = complete diagnosis (formulationDiagnosis formulation)
    intentsResolved = complete intents (formulationIntent formulation)
    policiesResolved = complete policies (formulationGuidingPolicy formulation)
    actionsResolved = complete actions (formulationActions formulation)
    keyResultsResolved = complete keyResults (formulationKeyResults formulation)
    allIdentitySitesResolved =
      and
        [ diagnosisResolved
        , intentsResolved
        , policiesResolved
        , actionsResolved
        , keyResultsResolved
        ]
    complete occurrences identifiers =
      length occurrences == NonEmpty.length identifiers
    owned endpoint =
      assertedOwnedMembersAtEndpoint semanticIndex strategyOccurrence endpoint
    visionSources intent =
      filter
        (isAssertedEndpoint semanticIndex endpointVisionObjective)
        (assertedIncomingSources semanticIndex intent tokenOrients)
    defects =
      ownedDefects
        diagnosisResolved
        Generated.StrategyFormulationDiagnosisRule
        Generated.StrategyFormulationDiagnosisOccurrences
        diagnosis
        endpointStrategyDriver
        ++ ownedDefects
             intentsResolved
             Generated.StrategyFormulationIntentRule
             Generated.StrategyFormulationIntentOccurrences
             intents
             endpointStrategyObjective
        ++ ownedDefects
             policiesResolved
             Generated.StrategyFormulationGuidingPolicyRule
             Generated.StrategyFormulationGuidingPolicyOccurrences
             policies
             endpointStrategyPrinciple
        ++ ownedDefects
             actionsResolved
             Generated.StrategyFormulationActionsRule
             Generated.StrategyFormulationActionsOccurrences
             actions
             endpointStrategyAction
        ++ ownedDefects
             keyResultsResolved
             Generated.StrategyFormulationKeyResultsRule
             Generated.StrategyFormulationKeyResultsOccurrences
             keyResults
             endpointStrategyKeyResult
        ++ [ mkSemanticDefect
             Generated.StrategyFormulationVisionOrientationRule
             (SemanticStrategyMemberEvidenceKey strategyIdentity identifier)
             (Generated.StrategyFormulationVisionOrientationOccurrences intent)
           | intent <- intents
           , null (visionSources intent)
           , Just identifier <- [modelIdentityAt semanticIndex intent]
           ]
        ++ coverage
             intentsResolved
             Generated.StrategyFormulationDiagnosisGroundingRule
             Generated.StrategyFormulationDiagnosisGroundingOccurrences
             outgoing
             tokenGrounds
             diagnosis
             intents
        ++ coverage
             diagnosisResolved
             Generated.StrategyFormulationIntentGroundingRule
             Generated.StrategyFormulationIntentGroundingOccurrences
             incoming
             tokenGrounds
             intents
             diagnosis
        ++ coverage
             policiesResolved
             Generated.StrategyFormulationGuidingPolicyActionsRule
             Generated.StrategyFormulationGuidingPolicyActionsOccurrences
             incoming
             tokenGuides
             actions
             policies
        ++ [ mkSemanticDefect
             Generated.StrategyFormulationActionContributionsRule
             (SemanticStrategyMemberEvidenceKey strategyIdentity identifier)
             (Generated.StrategyFormulationActionContributionsOccurrences action)
           | keyResultsResolved
           , action <- actions
           , not (hasNeighbour outgoing tokenContributesTo keyResultSet action)
           , Just identifier <- [modelIdentityAt semanticIndex action]
           ]
        ++ coverage
             intentsResolved
             Generated.StrategyFormulationKeyResultSubstantiationRule
             Generated.StrategyFormulationKeyResultSubstantiationOccurrences
             outgoing
             tokenSubstantiates
             keyResults
             intents
        ++ coverage
             keyResultsResolved
             Generated.StrategyFormulationIntentSubstantiationRule
             Generated.StrategyFormulationIntentSubstantiationOccurrences
             incoming
             tokenSubstantiates
             intents
             keyResults
    ownedDefects resolved rule evidence listed endpoint
      | resolved =
        listedOwnedDefect rule evidence strategyIdentity listed (owned endpoint)
      | otherwise = []
    coverage resolved rule evidence neighbours token members opposite
      | resolved =
        memberCoverageDefects
          semanticIndex
          rule
          evidence
          strategyIdentity
          (hasNeighbour neighbours token oppositeSet)
          members
          opposite
      | otherwise = []
      where
        oppositeSet = Set.fromList opposite
    outgoing member token = assertedOutgoingTargets semanticIndex member token
    incoming member token = assertedIncomingSources semanticIndex member token
    hasNeighbour neighbours token selected member =
      any (`Set.member` selected) (neighbours member token)
    selectedMembers = diagnosis ++ intents ++ policies ++ actions ++ keyResults
    witnesses =
      strategyOccurrence
        : selectedMembers
        ++ concatMap visionSources intents
        ++ contextualizationWitnesses semanticIndex selectedMembers
        ++ relationWitnesses
    relationWitnesses =
      concat
        [ relationOccurrences
          (assertedMatchingRelations semanticIndex vision tokenOrients intent)
        | intent <- intents
        , vision <- visionSources intent
        ]
        ++ concatMap
             (\driver ->
                relationOccurrencesToTargets
                  semanticIndex
                  driver
                  tokenGrounds
                  intentSet)
             diagnosis
        ++ concatMap
             (\policy ->
                relationOccurrencesToTargets
                  semanticIndex
                  policy
                  tokenGuides
                  actionSet)
             policies
        ++ concatMap
             (\action ->
                relationOccurrencesToTargets
                  semanticIndex
                  action
                  tokenContributesTo
                  keyResultSet)
             actions
        ++ concatMap
             (\keyResult ->
                relationOccurrencesToTargets
                  semanticIndex
                  keyResult
                  tokenSubstantiates
                  intentSet)
             keyResults
    intentSet = Set.fromList intents
    actionSet = Set.fromList actions
    keyResultSet = Set.fromList keyResults
    resolveMembers base identifiers =
      [ occurrence
      | (index, identifier) <- zip [0 :: Int ..] (NonEmpty.toList identifiers)
      , let pointer = base <> "/" <> Text.pack (show index)
      , strategyIdentitySiteResolved
          semanticIndex
          strategyIdentity
          pointer
          identifier
      , Just occurrence <- [occurrenceForIdentity semanticIndex identifier]
      ]

-- | Listed membership does not exclude additional unselected Strategy primitives.
listedOwnedDefect ::
     Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyKeySchema
       occurrenceSchema
  -> (NonEmpty.NonEmpty OccurrenceIdentity -> SemanticOccurrenceEvidence
                                                occurrenceSchema)
  -> ModelIdentity
  -> [OccurrenceIdentity]
  -> [OccurrenceIdentity]
  -> [SemanticDefect]
listedOwnedDefect rule evidence strategy listed owned
  | all (`Set.member` ownedSet) listed = []
  | otherwise =
    case NonEmpty.nonEmpty (Set.toAscList (Set.fromList listed)) of
      Nothing -> []
      Just occurrences ->
        [ mkSemanticDefect
            rule
            (SemanticStrategyEvidenceKey strategy)
            (evidence occurrences)
        ]
  where
    ownedSet = Set.fromList owned

-- | One defect per uncovered member, preserving the full selected opposite role.
-- Only addressed neighbours are inspected; no member-pair product is constructed.
memberCoverageDefects ::
     SemanticIndex scope
  -> Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyMemberKeySchema
       occurrenceSchema
  -> (OccurrenceIdentity -> NonEmpty.NonEmpty OccurrenceIdentity -> SemanticOccurrenceEvidence
                                                                      occurrenceSchema)
  -> ModelIdentity
  -> (OccurrenceIdentity -> Bool)
  -> [OccurrenceIdentity]
  -> [OccurrenceIdentity]
  -> [SemanticDefect]
memberCoverageDefects semanticIndex rule evidence strategy covered members opposite =
  case NonEmpty.nonEmpty (Set.toAscList (Set.fromList opposite)) of
    Nothing -> []
    Just selected ->
      [ mkSemanticDefect
        rule
        (SemanticStrategyMemberEvidenceKey strategy identifier)
        (evidence member selected)
      | member <- members
      , not (covered member)
      , Just identifier <- [modelIdentityAt semanticIndex member]
      ]

occurrenceForIdentity ::
     SemanticIndex scope -> ModelIdentity -> Maybe OccurrenceIdentity
occurrenceForIdentity semanticIndex identifier =
  case occurrencesForModelIdentity semanticIndex identifier of
    [occurrence] -> Just occurrence
    _ -> Nothing

modelIdentityAt ::
     SemanticIndex scope -> OccurrenceIdentity -> Maybe ModelIdentity
modelIdentityAt semanticIndex occurrence =
  carrierModelIdentity <$> carrierAt semanticIndex occurrence

isAssertedEndpoint ::
     SemanticIndex scope
  -> CoreQualifiedEndpointId
  -> OccurrenceIdentity
  -> Bool
isAssertedEndpoint semanticIndex endpoint occurrence =
  maybe
    False
    (\carrier ->
       carrierCommitment carrier == Asserted
         && carrierQualifiedEndpoint carrier == endpoint)
    (carrierAt semanticIndex occurrence)

contextualizationWitnesses ::
     SemanticIndex scope -> [OccurrenceIdentity] -> [OccurrenceIdentity]
contextualizationWitnesses semanticIndex members =
  [ contextualizationOccurrenceIdentity contextualization
  | member <- members
  , Just contextualization <- [contextualizationForMember semanticIndex member]
  ]

relationOccurrences :: [RelationObservation scope] -> [OccurrenceIdentity]
relationOccurrences = map relationOccurrenceIdentity

relationOccurrencesToTargets ::
     SemanticIndex scope
  -> OccurrenceIdentity
  -> CoreRelationToken
  -> Set.Set OccurrenceIdentity
  -> [OccurrenceIdentity]
relationOccurrencesToTargets semanticIndex source token targets =
  concat
    [ relationOccurrences
      (assertedMatchingRelations semanticIndex source token target)
    | target <-
        filter
          (`Set.member` targets)
          (assertedOutgoingTargets semanticIndex source token)
    ]
