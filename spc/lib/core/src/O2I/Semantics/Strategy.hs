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
          { eligibleStrategyIdentity = strategyIdentity
          , eligibleStrategyOccurrence = strategyOccurrence
          , eligibleStrategyInput = formulation
          , eligibleStrategyWitnesses = Set.toAscList (Set.fromList witnesses)
          }
  where
    strategyIdentity = carrierModelIdentity strategy
    strategyOccurrence = carrierOccurrenceIdentity strategy
    diagnosis =
      resolvedOccurrence "/diagnosis" (formulationDiagnosis formulation)
    intent = resolvedOccurrence "/intent" (formulationIntent formulation)
    guidingPolicy =
      resolvedOccurrence "/guidingPolicy" (formulationGuidingPolicy formulation)
    actionSites =
      resolvedOccurrences
        "/actions"
        (NonEmpty.toList (formulationActions formulation))
    keyResultSites =
      resolvedOccurrences
        "/keyResults"
        (NonEmpty.toList (formulationKeyResults formulation))
    actions = map snd actionSites
    keyResults = map snd keyResultSites
    allActionsResolved =
      length actionSites == NonEmpty.length (formulationActions formulation)
    allKeyResultsResolved =
      length keyResultSites
        == NonEmpty.length (formulationKeyResults formulation)
    allIdentitySitesResolved =
      allActionsResolved
        && allKeyResultsResolved
        && all
             identityResolved
             [ ("/diagnosis", formulationDiagnosis formulation)
             , ("/intent", formulationIntent formulation)
             , ("/guidingPolicy", formulationGuidingPolicy formulation)
             ]
    ownedDiagnosis =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        strategyOccurrence
        endpointStrategyDriver
    ownedIntent =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        strategyOccurrence
        endpointStrategyObjective
    ownedGuidingPolicy =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        strategyOccurrence
        endpointStrategyPrinciple
    ownedActions =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        strategyOccurrence
        endpointStrategyAction
    ownedKeyResults =
      assertedOwnedMembersAtEndpoint
        semanticIndex
        strategyOccurrence
        endpointStrategyKeyResult
    visionOrientations =
      case intent of
        Just target ->
          filter
            (isAssertedEndpoint semanticIndex endpointVisionObjective)
            (assertedIncomingSources semanticIndex target tokenOrients)
        Nothing -> []
    actionWithoutContribution =
      [ action
      | action <- actions
      , null
          (filter
             (`Set.member` keyResultSet)
             (assertedOutgoingTargets semanticIndex action tokenContributesTo))
      ]
    defects =
      whenResolved
        "/diagnosis"
        (formulationDiagnosis formulation)
        (exactOwnedDefect
           Generated.StrategyFormulationDiagnosisRule
           Generated.StrategyFormulationDiagnosisOccurrences
           strategyIdentity
           diagnosis
           ownedDiagnosis)
        ++ whenResolved
             "/intent"
             (formulationIntent formulation)
             (exactOwnedDefect
                Generated.StrategyFormulationIntentRule
                Generated.StrategyFormulationIntentOccurrences
                strategyIdentity
                intent
                ownedIntent)
        ++ whenResolved
             "/guidingPolicy"
             (formulationGuidingPolicy formulation)
             (exactOwnedDefect
                Generated.StrategyFormulationGuidingPolicyRule
                Generated.StrategyFormulationGuidingPolicyOccurrences
                strategyIdentity
                guidingPolicy
                ownedGuidingPolicy)
        ++ [ defect
           | allActionsResolved
           , defect <-
               listedOwnedDefect
                 Generated.StrategyFormulationActionsRule
                 Generated.StrategyFormulationActionsOccurrences
                 strategyIdentity
                 actions
                 ownedActions
           ]
        ++ [ defect
           | allKeyResultsResolved
           , defect <-
               listedOwnedDefect
                 Generated.StrategyFormulationKeyResultsRule
                 Generated.StrategyFormulationKeyResultsOccurrences
                 strategyIdentity
                 keyResults
                 ownedKeyResults
           ]
        ++ whenResolved
             "/intent"
             (formulationIntent formulation)
             (requiredRelationDefect
                Generated.StrategyFormulationVisionOrientationRule
                Generated.StrategyFormulationVisionOrientationOccurrences
                (SemanticStrategyEvidenceKey strategyIdentity)
                visionOrientations)
        ++ [ defect
           | identityResolved ("/diagnosis", formulationDiagnosis formulation)
           , identityResolved ("/intent", formulationIntent formulation)
           , defect <-
               relationBetweenMaybeDefect
                 semanticIndex
                 Generated.StrategyFormulationDiagnosisGroundingRule
                 (SemanticStrategyEvidenceKey strategyIdentity)
                 diagnosis
                 tokenGrounds
                 intent
           ]
        ++ [ defect
           | identityResolved
               ("/guidingPolicy", formulationGuidingPolicy formulation)
           , action <- actions
           , defect <-
               sourceToMemberRelationDefect
                 semanticIndex
                 Generated.StrategyFormulationGuidingPolicyActionsRule
                 strategyIdentity
                 guidingPolicy
                 tokenGuides
                 action
           ]
        ++ [ mkSemanticDefect
             Generated.StrategyFormulationActionContributionsRule
             (SemanticStrategyMemberEvidenceKey strategyIdentity actionIdentity)
             (Generated.StrategyFormulationActionContributionsOccurrences action)
           | allKeyResultsResolved
           , action <- actionWithoutContribution
           , Just actionIdentity <- [modelIdentityAt semanticIndex action]
           ]
        ++ [ defect
           | identityResolved ("/intent", formulationIntent formulation)
           , keyResult <- keyResults
           , defect <-
               memberToTargetRelationDefect
                 semanticIndex
                 Generated.StrategyFormulationKeyResultSubstantiationRule
                 strategyIdentity
                 tokenSubstantiates
                 intent
                 keyResult
           ]
    witnesses =
      strategyOccurrence
        : maybeToList diagnosis
        ++ maybeToList intent
        ++ maybeToList guidingPolicy
        ++ actions
        ++ keyResults
        ++ visionOrientations
        ++ contextualizationWitnesses
             semanticIndex
             (maybeToList diagnosis
                ++ maybeToList intent
                ++ maybeToList guidingPolicy
                ++ actions
                ++ keyResults)
        ++ relationWitnesses
    relationWitnesses =
      case intent of
        Nothing -> []
        Just objective ->
          concat
            [ relationOccurrences
              (assertedMatchingRelations
                 semanticIndex
                 visionObjective
                 tokenOrients
                 objective)
            | visionObjective <- visionOrientations
            ]
            ++ maybeRelationOccurrences
                 semanticIndex
                 diagnosis
                 tokenGrounds
                 (Just objective)
            ++ concat
                 [ maybeRelationOccurrences
                   semanticIndex
                   guidingPolicy
                   tokenGuides
                   (Just action)
                 | action <- actions
                 ]
            ++ concat
                 [ relationOccurrencesToTargets
                   semanticIndex
                   action
                   tokenContributesTo
                   keyResultSet
                 | action <- actions
                 ]
            ++ concat
                 [ relationOccurrences
                   (assertedMatchingRelations
                      semanticIndex
                      keyResult
                      tokenSubstantiates
                      objective)
                 | keyResult <- keyResults
                 ]
    identityResolved (pointer, identifier) =
      strategyIdentitySiteResolved
        semanticIndex
        strategyIdentity
        pointer
        identifier
    resolvedOccurrence pointer identifier
      | identityResolved (pointer, identifier) =
        occurrenceForIdentity semanticIndex identifier
      | otherwise = Nothing
    resolvedOccurrences base identifiers =
      [ (identifier, occurrence)
      | (index, identifier) <- zip [0 :: Int ..] identifiers
      , let pointer = base <> "/" <> Text.pack (show index)
      , identityResolved (pointer, identifier)
      , Just occurrence <- [occurrenceForIdentity semanticIndex identifier]
      ]
    whenResolved pointer identifier values
      | identityResolved (pointer, identifier) = values
      | otherwise = []
    keyResultSet = Set.fromList keyResults

exactOwnedDefect ::
     Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyKeySchema
       occurrenceSchema
  -> ([OccurrenceIdentity] -> SemanticOccurrenceEvidence occurrenceSchema)
  -> ModelIdentity
  -> Maybe OccurrenceIdentity
  -> [OccurrenceIdentity]
  -> [SemanticDefect]
exactOwnedDefect rule occurrenceEvidence strategy expected owned =
  case expected of
    Just member
      | owned == [member] -> []
    _ ->
      [ mkSemanticDefect
          rule
          (SemanticStrategyEvidenceKey strategy)
          (occurrenceEvidence owned)
      ]

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
listedOwnedDefect rule occurrenceEvidence strategy listed owned
  | not (null listed) && all (`elem` owned) listed = []
  | otherwise =
    case NonEmpty.nonEmpty listed of
      Nothing -> []
      Just occurrences ->
        [ mkSemanticDefect
            rule
            (SemanticStrategyEvidenceKey strategy)
            (occurrenceEvidence occurrences)
        ]

requiredRelationDefect ::
     Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyKeySchema
       occurrenceSchema
  -> SemanticOccurrenceEvidence occurrenceSchema
  -> SemanticEvidenceKey 'Generated.GeneratedStrategyKeySchema
  -> [OccurrenceIdentity]
  -> [SemanticDefect]
requiredRelationDefect rule occurrenceEvidence evidence occurrences
  | null occurrences = [mkSemanticDefect rule evidence occurrenceEvidence]
  | otherwise = []

relationBetweenMaybeDefect ::
     SemanticIndex scope
  -> Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyKeySchema
       'Generated.StrategyFormulationDiagnosisGroundingOccurrenceSchema
  -> SemanticEvidenceKey 'Generated.GeneratedStrategyKeySchema
  -> Maybe OccurrenceIdentity
  -> CoreRelationToken
  -> Maybe OccurrenceIdentity
  -> [SemanticDefect]
relationBetweenMaybeDefect semanticIndex rule evidence source token target =
  case (source, target) of
    (Just from, Just to)
      | not (null (assertedMatchingRelations semanticIndex from token to)) -> []
    (Just from, Just to) ->
      [ mkSemanticDefect
          rule
          evidence
          (Generated.StrategyFormulationDiagnosisGroundingOccurrences from to)
      ]
    _ -> []

sourceToMemberRelationDefect ::
     SemanticIndex scope
  -> Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyMemberKeySchema
       'Generated.StrategyFormulationGuidingPolicyActionsOccurrenceSchema
  -> ModelIdentity
  -> Maybe OccurrenceIdentity
  -> CoreRelationToken
  -> OccurrenceIdentity
  -> [SemanticDefect]
sourceToMemberRelationDefect semanticIndex rule strategy maybeSource token member =
  case (maybeSource, modelIdentityAt semanticIndex member) of
    (Just source, Just memberIdentity)
      | not (null (assertedMatchingRelations semanticIndex source token member)) ->
        []
      | otherwise ->
        [ mkSemanticDefect
            rule
            (SemanticStrategyMemberEvidenceKey strategy memberIdentity)
            (Generated.StrategyFormulationGuidingPolicyActionsOccurrences
               source
               member)
        ]
    _ -> []

memberToTargetRelationDefect ::
     SemanticIndex scope
  -> Generated.GeneratedSemanticRule
       'Generated.GeneratedStrategyMemberKeySchema
       'Generated.StrategyFormulationKeyResultSubstantiationOccurrenceSchema
  -> ModelIdentity
  -> CoreRelationToken
  -> Maybe OccurrenceIdentity
  -> OccurrenceIdentity
  -> [SemanticDefect]
memberToTargetRelationDefect semanticIndex rule strategy token maybeTarget member =
  case (modelIdentityAt semanticIndex member, maybeTarget) of
    (Just memberIdentity, Just target)
      | not (null (assertedMatchingRelations semanticIndex member token target)) ->
        []
      | otherwise ->
        [ mkSemanticDefect
            rule
            (SemanticStrategyMemberEvidenceKey strategy memberIdentity)
            (Generated.StrategyFormulationKeyResultSubstantiationOccurrences
               member
               target)
        ]
    _ -> []

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

maybeRelationOccurrences ::
     SemanticIndex scope
  -> Maybe OccurrenceIdentity
  -> CoreRelationToken
  -> Maybe OccurrenceIdentity
  -> [OccurrenceIdentity]
maybeRelationOccurrences semanticIndex source token target =
  case (source, target) of
    (Just from, Just to) ->
      relationOccurrences
        (assertedMatchingRelations semanticIndex from token to)
    _ -> []

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

maybeToList :: Maybe value -> [value]
maybeToList maybeValue =
  case maybeValue of
    Just value -> [value]
    Nothing -> []
