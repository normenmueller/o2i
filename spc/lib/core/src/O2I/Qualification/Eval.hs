{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Deterministic addressed evaluation of Need qualification proposals.
module O2I.Qualification.Eval
  ( QualificationContext
  , QualificationContextError(..)
  , prepareQualificationContextInternal
  , qualificationSubjectsInternal
  , assessQualificationInternal
  , assessQualificationWithWorkInternal
  , qualificationSourceOrderingWorkInternal
  , qualificationWitnessOrderingWorkInternal
  , qualificationRequestedMembershipWorkInternal
  , qualificationCarrierAddressWorkInternal
  ) where

import Data.Char (ord)
import qualified Data.IntMap.Strict as IntMap
import Data.IntMap.Strict (IntMap)
import qualified Data.IntSet as IntSet
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreRelationToken
  , coreRuleIdText
  )
import O2I.Core.Graph.Observation
  ( ContextualizationObservation
  , RelationObservation
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationOccurrenceIdentity
  , contextualizationOwnerOccurrence
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Core.Identity.Internal
  ( IdentityResolution(..)
  , SelectedIdentityKind(..)
  , scopedOccurrenceIdentity
  )
import O2I.Input.Internal.Text
  ( canonicalFachlicheText
  , canonicalizeFachlicheText
  )
import O2I.Input.Internal.Types (StrategyFormulationInput(..))
import O2I.Qualification.Index
import O2I.Qualification.Internal
import O2I.Semantics
  ( SemanticAssessment
  , semanticAssessmentMatchesGraph
  , situatedNeedAssessments
  , strategyFormulationAssessments
  )
import qualified O2I.Semantics.Internal as Semantics
import O2I.Structure (WellFormedGraph)

data RoutedProposal = RoutedProposal
  { routedProposalInput :: !QualificationProposalInput
  , routedNeedReference :: !QualificationReferenceInput
  , routedNeedCarrier :: !UntypedCarrier
  , routedStrategyReference :: !QualificationReferenceInput
  , routedStrategyCarrier :: !UntypedCarrier
  }

-- The existential scope is irrelevant after the exact carrier facts have been
-- copied; retaining a local record avoids weakening the public scope boundary.
data UntypedCarrier = UntypedCarrier
  { untypedCarrierOccurrence :: !OccurrenceIdentity
  , untypedCarrierIdentity :: !ModelIdentity
  , untypedCarrierNeedRank :: !(Maybe Int)
  , untypedCarrierStrategyRank :: !(Maybe Int)
  }

data SelectedQualificationSubject = SelectedQualificationSubject
  { selectedQualificationIdentity :: !ModelIdentity
  , selectedQualificationRank :: !Int
  }

data RequestedSubjectRanks =
  RequestedSubjectRanks !(IntSet.IntSet) !(IntSet.IntSet)

data RoutingState scope = RoutingState
  { routingUnrouted :: ![QualificationProposalAssessment scope]
  , routingBuckets :: !(IntMap (IntMap [RoutedProposal]))
  , routingWork :: !QualificationWork
  }

data Radix value =
  Radix ![value] !(IntMap (Radix value))

emptyRadix :: Radix value
emptyRadix = Radix [] IntMap.empty

insertRadix :: [Int] -> value -> Radix value -> Radix value
insertRadix key value (Radix values children) =
  case key of
    [] -> Radix (value : values) children
    scalar:remaining ->
      Radix
        values
        (IntMap.alter
           (Just . insertRadix remaining value . maybe emptyRadix id)
           scalar
           children)

flattenRadix :: Radix value -> [value]
flattenRadix (Radix values children) =
  reverse values ++ concatMap flattenRadix (IntMap.elems children)

flattenUniqueRadix :: Radix value -> [value]
flattenUniqueRadix (Radix values children) =
  take 1 (reverse values)
    ++ concatMap flattenUniqueRadix (IntMap.elems children)

radixSortOn ::
     Bool -> (value -> [Int]) -> [value] -> ([value], QualificationWork)
radixSortOn addressed key values =
  ( flattenRadix tree
  , emptyQualificationWork
      { qualificationAddressedSupportVisits =
          if addressed
            then length values
            else 0
      , qualificationOrderingScalarVisits = scalarVisits
      })
  where
    decorated = [(key value, value) | value <- values]
    tree =
      foldl'
        (\radix (orderingKey, value) -> insertRadix orderingKey value radix)
        emptyRadix
        decorated
    scalarVisits = sum (map (length . fst) decorated)

radixSortUniqueOn ::
     Bool -> (value -> [Int]) -> [value] -> ([value], QualificationWork)
radixSortUniqueOn addressed key values =
  ( flattenUniqueRadix tree
  , emptyQualificationWork
      { qualificationAddressedSupportVisits =
          if addressed
            then length values
            else 0
      , qualificationOrderingScalarVisits = scalarVisits
      })
  where
    decorated = [(key value, value) | value <- values]
    tree =
      foldl'
        (\radix (orderingKey, value) -> insertRadix orderingKey value radix)
        emptyRadix
        decorated
    scalarVisits = sum (map (length . fst) decorated)

countedSortOn ::
     Ord key
  => (value -> key)
  -> (key -> Int)
  -> [value]
  -> ([value], QualificationWork)
countedSortOn key scalarSize values = (map snd sorted, work)
  where
    decorated = [(key value, value) | value <- values]
    (sorted, comparisons) = mergeSortCounted decorated
    work =
      emptyQualificationWork
        { qualificationOrderingScalarVisits =
            sum (map (scalarSize . fst) decorated)
        , qualificationOrderingComparisons = comparisons
        }

mergeSortCounted :: Ord key => [(key, value)] -> ([(key, value)], Int)
mergeSortCounted values =
  case values of
    [] -> ([], 0)
    [_] -> (values, 0)
    _ ->
      let (leftValues, rightValues) = splitAt (length values `div` 2) values
          (sortedLeft, leftComparisons) = mergeSortCounted leftValues
          (sortedRight, rightComparisons) = mergeSortCounted rightValues
          (merged, mergeComparisons) = mergeCounted sortedLeft sortedRight
       in (merged, leftComparisons + rightComparisons + mergeComparisons)

mergeCounted ::
     Ord key => [(key, value)] -> [(key, value)] -> ([(key, value)], Int)
mergeCounted left right =
  case (left, right) of
    ([], _) -> (right, 0)
    (_, []) -> (left, 0)
    (leftHead@(leftKey, _):leftTail, rightHead@(rightKey, _):rightTail)
      | leftKey <= rightKey ->
        let (remaining, comparisons) = mergeCounted leftTail right
         in (leftHead : remaining, comparisons + 1)
      | otherwise ->
        let (remaining, comparisons) = mergeCounted left rightTail
         in (rightHead : remaining, comparisons + 1)

textRadixKey :: Text -> [Int]
textRadixKey = map ord . Text.unpack

identityRadixKey :: ModelIdentity -> [Int]
identityRadixKey = textRadixKey . modelIdentityText

occurrenceRadixKey :: OccurrenceIdentity -> [Int]
occurrenceRadixKey = textRadixKey . occurrenceIdentityText

qualificationSourceOrderingWorkInternal :: [Text] -> QualificationWork
qualificationSourceOrderingWorkInternal = snd . radixSortOn True textRadixKey

qualificationWitnessOrderingWorkInternal ::
     [OccurrenceIdentity] -> QualificationWork
qualificationWitnessOrderingWorkInternal =
  snd . radixSortUniqueOn True occurrenceRadixKey

qualificationRequestedMembershipWorkInternal ::
     [Int] -> [Int] -> [(Int, Int)] -> QualificationWork
qualificationRequestedMembershipWorkInternal needs strategies pairs =
  foldl measure emptyQualificationWork pairs
  where
    requested = requestedSubjectRanks needs strategies
    measure accumulated (need, strategy) =
      let (isRequested, work) = requestedPairMembership requested need strategy
       in isRequested `seq` addQualificationWork accumulated work

qualificationCarrierAddressWorkInternal ::
     [OccurrenceIdentity] -> [OccurrenceIdentity] -> QualificationWork
qualificationCarrierAddressWorkInternal members probes =
  emptyQualificationWork
    { qualificationCarrierAddressVisits = visits
    , qualificationCarrierAddressScalarVisits = scalarVisits
    }
  where
    (visits, scalarVisits) = qualificationCarrierAddressProbeWork members probes

requestedSubjectRanks :: [Int] -> [Int] -> RequestedSubjectRanks
requestedSubjectRanks needs strategies =
  RequestedSubjectRanks (IntSet.fromList needs) (IntSet.fromList strategies)

requestedPairMembership ::
     RequestedSubjectRanks -> Int -> Int -> (Bool, QualificationWork)
requestedPairMembership (RequestedSubjectRanks needs strategies) need strategy =
  (needRequested && strategyRequested, work)
  where
    !needRequested = IntSet.member need needs
    !strategyRequested = IntSet.member strategy strategies
    work = emptyQualificationWork {qualificationRequestedMembershipVisits = 2}

type role QualificationContext nominal

-- | Exact graph-bound inputs and addresses prepared once for qualification.
data QualificationContext scope =
  QualificationContext !(QualificationIndex scope) !(SemanticAssessment scope)

-- | Closed failure to bind Semantics to its exact producing graph.
data QualificationContextError =
  QualificationSemanticGraphMismatch
  deriving (Bounded, Enum, Eq, Ord, Show)

prepareQualificationContextInternal ::
     WellFormedGraph scope
  -> SemanticAssessment scope
  -> Either QualificationContextError (QualificationContext scope)
prepareQualificationContextInternal graph semantics
  | semanticAssessmentMatchesGraph graph semantics =
    Right (QualificationContext (buildQualificationIndex graph) semantics)
  | otherwise = Left QualificationSemanticGraphMismatch

qualificationSubjectsInternal ::
     QualificationContext scope -> QualificationSubjects scope
qualificationSubjectsInternal (QualificationContext index semantics) =
  QualificationSubjects
    (map (assessNeedSubject needAssessments) rawNeeds)
    (map (assessStrategySubject strategyAssessments) rawStrategies)
  where
    QualificationSubjects rawNeeds rawStrategies =
      qualificationIndexSubjects index
    needAssessments = indexedNeedAssessments semantics
    strategyAssessments = indexedStrategyAssessments semantics

assessQualificationInternal ::
     QualificationContext scope
  -> [QualificationNeedSelector]
  -> NonEmpty QualificationStrategySelector
  -> [QualificationProposalInput]
  -> QualificationAssessment scope
assessQualificationInternal context needs strategies proposals =
  fst (assessQualificationWithWorkInternal context needs strategies proposals)

assessQualificationWithWorkInternal ::
     QualificationContext scope
  -> [QualificationNeedSelector]
  -> NonEmpty QualificationStrategySelector
  -> [QualificationProposalInput]
  -> (QualificationAssessment scope, QualificationWork)
assessQualificationWithWorkInternal (QualificationContext index semantics) rawNeeds rawStrategies rawProposals =
  (assessment, finalWork)
  where
    assessment =
      QualificationAssessment
        { storedQualificationGraphIdentity =
            qualificationIndexGraphIdentity index
        , storedQualificationSelectedNeeds = selectedNeeds
        , storedQualificationSelectedStrategies = selectedStrategies
        , storedQualificationSubjectUnavailable = unavailable
        , storedQualificationUnroutedProposals =
            [proposal | null unavailable, proposal <- orderedUnrouted]
        , storedQualificationPairs = [pair | null unavailable, pair <- pairs]
        }
    evaluatedWork
      | null unavailable = addQualificationWork (routingWork routed) resultWork
      | otherwise = selectorWork
    finalWork =
      (addQualificationWork (qualificationIndexWork index) evaluatedWork)
        { qualificationEmittedStructuralSize =
            qualificationAssessmentStructuralSize assessment
        , qualificationEmittedScalarSize =
            qualificationAssessmentScalarSize assessment
        }
    (needSelectors, needSelectorOrderingWork) =
      radixSortUniqueOn
        False
        (identityRadixKey . storedQualificationNeedSelectorIdentity)
        rawNeeds
    (strategySelectors, strategySelectorOrderingWork) =
      radixSortUniqueOn
        False
        (identityRadixKey . storedQualificationStrategySelectorIdentity)
        (NonEmpty.toList rawStrategies)
    needAssessments = indexedNeedAssessments semantics
    strategyAssessments = indexedStrategyAssessments semantics
    needSelections =
      map (resolveNeedSelector index needAssessments) needSelectors
    strategySelections =
      map (resolveStrategySelector index strategyAssessments) strategySelectors
    unavailable =
      [failure | Left failure <- needSelections]
        ++ [failure | Left failure <- strategySelections]
    selectedNeedSubjects = [subject | Right subject <- needSelections]
    selectedStrategySubjects = [subject | Right subject <- strategySelections]
    selectedNeeds = map selectedQualificationIdentity selectedNeedSubjects
    selectedStrategies =
      map selectedQualificationIdentity selectedStrategySubjects
    selectorWork =
      addQualificationWork
        needSelectorOrderingWork
        (addQualificationWork
           strategySelectorOrderingWork
           (emptyQualificationWork
              { qualificationSelectorResolutionVisits =
                  length needSelectors + length strategySelectors
              , qualificationAddressedSupportVisits =
                  length needSelectors + length strategySelectors
              }))
    requestedRanks =
      requestedSubjectRanks
        (map selectedQualificationRank selectedNeedSubjects)
        (map selectedQualificationRank selectedStrategySubjects)
    routed =
      foldl
        (routeProposal index requestedRanks)
        (RoutingState [] IntMap.empty emptyQualificationWork)
        rawProposals
    (orderedUnrouted, unroutedOrderingWork) =
      countedSortOn
        qualificationProposalAssessmentSortKey
        qualificationProposalSortKeyScalarSize
        (routingUnrouted routed)
    (bucketOrderingWork, orderedBuckets) =
      IntMap.mapAccum
        (\outerWork strategyBuckets ->
           let (innerWork, orderedStrategyBuckets) =
                 IntMap.mapAccum
                   (\work proposals ->
                      let (ordered, orderingWork) =
                            countedSortOn
                              qualificationRoutedProposalSortKey
                              qualificationProposalSortKeyScalarSize
                              proposals
                       in (addQualificationWork work orderingWork, ordered))
                   outerWork
                   strategyBuckets
            in (innerWork, orderedStrategyBuckets))
        emptyQualificationWork
        (routingBuckets routed)
    pairResults =
      [ assessPair
        index
        needAssessments
        strategyAssessments
        orderedBuckets
        (selectedQualificationIdentity needSubject)
        (selectedQualificationRank needSubject)
        (selectedQualificationIdentity selectedStrategySubject)
        (selectedQualificationRank selectedStrategySubject)
      | needSubject <- selectedNeedSubjects
      , selectedStrategySubject <- selectedStrategySubjects
      ]
    pairs = map fst pairResults
    resultWork =
      (addQualificationWork
         (foldl addQualificationWork selectorWork (map snd pairResults))
         (addQualificationWork unroutedOrderingWork bucketOrderingWork))
        {qualificationRequestedPairVisits = length pairs}

qualificationRoutedProposalSortKey ::
     RoutedProposal -> (ModelIdentity, OccurrenceIdentity)
qualificationRoutedProposalSortKey proposal =
  ( storedQualificationProposalIdentity (routedProposalInput proposal)
  , storedQualificationProposalOccurrence (routedProposalInput proposal))

qualificationProposalSortKeyScalarSize ::
     (ModelIdentity, OccurrenceIdentity) -> Int
qualificationProposalSortKeyScalarSize (identifier, occurrence) =
  Text.length (modelIdentityText identifier)
    + Text.length (occurrenceIdentityText occurrence)

qualificationDefectSortKeyScalarSize ::
     (Int, QualificationEvidence, NonEmpty QualificationOccurrenceGroup) -> Int
qualificationDefectSortKeyScalarSize (_, evidence, groups) =
  qualificationEvidenceScalarSize evidence
    + sum (map qualificationOccurrenceGroupScalarSize (NonEmpty.toList groups))

qualificationEvidenceScalarSize :: QualificationEvidence -> Int
qualificationEvidenceScalarSize evidence =
  case evidence of
    QualificationProposalKey proposal -> modelScalarSize proposal
    QualificationProposalRoleKey proposal _ -> modelScalarSize proposal
    QualificationProposalRoleTargetKey proposal _ target ->
      modelScalarSize proposal + occurrenceScalarSize target
    QualificationSelectedNeedKey need -> modelScalarSize need
    QualificationSelectedStrategyKey strategy -> modelScalarSize strategy
    QualificationPairKey need strategy ->
      modelScalarSize need + modelScalarSize strategy
    QualificationProposalRelationKey proposal relation ->
      modelScalarSize proposal + Text.length relation

qualificationOccurrenceGroupScalarSize :: QualificationOccurrenceGroup -> Int
qualificationOccurrenceGroupScalarSize group =
  Text.length (storedQualificationOccurrenceRole group)
    + sum (map occurrenceScalarSize (storedQualificationOccurrenceValues group))

modelScalarSize :: ModelIdentity -> Int
modelScalarSize = Text.length . modelIdentityText

occurrenceScalarSize :: OccurrenceIdentity -> Int
occurrenceScalarSize = Text.length . occurrenceIdentityText

sortQualificationDefectsWithWork ::
     [QualificationDefect] -> ([QualificationDefect], QualificationWork)
sortQualificationDefectsWithWork =
  countedSortOn qualificationDefectOrderKey qualificationDefectSortKeyScalarSize

qualificationProposalAssessmentSortKey ::
     QualificationProposalAssessment scope
  -> (ModelIdentity, OccurrenceIdentity)
qualificationProposalAssessmentSortKey assessment =
  case assessment of
    QualificationProposalUnrouted identifier occurrence _ ->
      (identifier, occurrence)
    QualificationProposalInvalid identifier occurrence _ ->
      (identifier, occurrence)
    QualificationProposalAdmissible proof ->
      ( storedAdmissibleProposalIdentity proof
      , storedAdmissibleProposalOccurrence proof)

indexedNeedAssessments ::
     SemanticAssessment scope
  -> Map ModelIdentity (Semantics.SituatedNeedAssessment scope)
indexedNeedAssessments semantics =
  Map.fromList
    [ (situatedNeedSubject assessment, assessment)
    | assessment <- situatedNeedAssessments semantics
    ]

indexedStrategyAssessments ::
     SemanticAssessment scope
  -> Map ModelIdentity (Semantics.StrategyFormulationAssessment scope)
indexedStrategyAssessments semantics =
  Map.fromList
    [ (strategySubject assessment, assessment)
    | assessment <- strategyFormulationAssessments semantics
    ]

assessNeedSubject ::
     Map ModelIdentity (Semantics.SituatedNeedAssessment scope)
  -> QualificationSubject
  -> QualificationSubject
assessNeedSubject assessments subject =
  subject
    { storedQualificationSubjectEligibility =
        case Map.lookup identifier assessments of
          Just (Semantics.SituatedNeedValid _) -> QualificationSubjectEligible
          Just _ -> QualificationSubjectIneligible
          Nothing -> QualificationSubjectEligibilityUnavailable
    }
  where
    identifier = storedQualificationSubjectIdentity subject

assessStrategySubject ::
     Map ModelIdentity (Semantics.StrategyFormulationAssessment scope)
  -> QualificationSubject
  -> QualificationSubject
assessStrategySubject assessments subject =
  subject
    { storedQualificationSubjectEligibility =
        case Map.lookup identifier assessments of
          Just (Semantics.StrategyFormulationValid _) ->
            QualificationSubjectEligible
          Just (Semantics.StrategyFormulationUnavailable _ _) ->
            QualificationSubjectEligibilityUnavailable
          Just _ -> QualificationSubjectIneligible
          Nothing -> QualificationSubjectEligibilityUnavailable
    }
  where
    identifier = storedQualificationSubjectIdentity subject

resolveNeedSelector ::
     QualificationIndex scope
  -> Map ModelIdentity (Semantics.SituatedNeedAssessment scope)
  -> QualificationNeedSelector
  -> Either (QualificationSubjectUnavailable scope) SelectedQualificationSubject
resolveNeedSelector index assessments selector =
  resolveQualificationSelector
    index
    QualificationNeedCategory
    endpointContextNeed
    qualificationCarrierNeedRank
    identifier
    (Map.notMember identifier assessments)
  where
    identifier = storedQualificationNeedSelectorIdentity selector

resolveStrategySelector ::
     QualificationIndex scope
  -> Map ModelIdentity (Semantics.StrategyFormulationAssessment scope)
  -> QualificationStrategySelector
  -> Either (QualificationSubjectUnavailable scope) SelectedQualificationSubject
resolveStrategySelector index assessments selector =
  resolveQualificationSelector
    index
    QualificationStrategyCategory
    endpointContextStrategy
    qualificationCarrierStrategyRank
    identifier
    eligibilityUnavailable
  where
    identifier = storedQualificationStrategySelectorIdentity selector
    eligibilityUnavailable =
      case Map.lookup identifier assessments of
        Just (Semantics.StrategyFormulationUnavailable _ _) -> True
        Nothing -> True
        _ -> False

resolveQualificationSelector ::
     QualificationIndex scope
  -> QualificationSubjectCategory
  -> CoreQualifiedEndpointId
  -> (IndexedQualificationCarrier scope -> Maybe Int)
  -> ModelIdentity
  -> Bool
  -> Either (QualificationSubjectUnavailable scope) SelectedQualificationSubject
resolveQualificationSelector index category endpoint compactRank identifier eligibilityUnavailable =
  case qualificationResolveIdentity index (SelectedCarrier endpoint) identifier of
    UnknownModelIdentity _ -> unavailable QualificationSelectorUnknown []
    AmbiguousModelIdentity _ occurrences ->
      unavailable QualificationSelectorAmbiguous (NonEmpty.toList occurrences)
    ModelIdentityOutOfSelectedView _ occurrence ->
      unavailable QualificationSelectorOutOfSelectedView [occurrence]
    WrongSelectedIdentityKind occurrence _ _ ->
      unavailable
        QualificationSelectorWrongTypeOrFamily
        [scopedOccurrenceIdentity occurrence]
    ResolvedIdentity occurrence _
      | eligibilityUnavailable ->
        unavailable
          QualificationEligibilityPrerequisiteUnavailable
          (qualificationOccurrencesForIdentity index identifier)
      | otherwise ->
        case qualificationCarrierAt index (scopedOccurrenceIdentity occurrence)
               >>= compactRank of
          Just rank -> Right (SelectedQualificationSubject identifier rank)
          Nothing ->
            error
              "Qualification subject invariant violated: resolved carrier has no compact rank"
  where
    unavailable reason occurrences =
      Left
        QualificationSubjectUnavailable
          { storedQualificationUnavailableCategory = category
          , storedQualificationUnavailableIdentity = identifier
          , storedQualificationUnavailableReason = reason
          , storedQualificationUnavailableOccurrences = occurrences
          }

situatedNeedSubject :: Semantics.SituatedNeedAssessment scope -> ModelIdentity
situatedNeedSubject assessment =
  case assessment of
    Semantics.SituatedNeedCandidate subject _ -> subject
    Semantics.SituatedNeedInvalid subject _ -> subject
    Semantics.SituatedNeedValid proof -> Semantics.situatedNeedIdentity proof

strategySubject ::
     Semantics.StrategyFormulationAssessment scope -> ModelIdentity
strategySubject assessment =
  case assessment of
    Semantics.StrategyFormulationUnavailable subject _ -> subject
    Semantics.StrategyFormulationCandidate subject _ -> subject
    Semantics.StrategyFormulationInvalid subject _ -> subject
    Semantics.StrategyFormulationValid proof ->
      Semantics.eligibleStrategyIdentity proof

routeProposal ::
     QualificationIndex scope
  -> RequestedSubjectRanks
  -> RoutingState scope
  -> QualificationProposalInput
  -> RoutingState scope
routeProposal index requested state proposal =
  case NonEmpty.nonEmpty orderedRouteDefects of
    Just defects ->
      state
        { routingUnrouted =
            QualificationProposalUnrouted
              proposalIdentity
              proposalOccurrence
              defects
              : routingUnrouted state
        , routingWork = visitedWork
        }
    Nothing ->
      case (needRoute, strategyRoute) of
        (Just (needReference, needCarrier), Just (strategyReference, strategyCarrier)) ->
          case ( untypedCarrierNeedRank needCarrier
               , untypedCarrierStrategyRank strategyCarrier) of
            (Just needRank, Just strategyRank) ->
              let (isRequested, membershipWork) =
                    requestedPairMembership requested needRank strategyRank
                  completedWork =
                    addQualificationWork visitedWork membershipWork
               in if isRequested
                    then state
                           { routingBuckets =
                               IntMap.alter
                                 (Just
                                    . IntMap.insertWith
                                        (++)
                                        strategyRank
                                        [ RoutedProposal
                                            proposal
                                            needReference
                                            needCarrier
                                            strategyReference
                                            strategyCarrier
                                        ]
                                    . maybe IntMap.empty id)
                                 needRank
                                 (routingBuckets state)
                           , routingWork = completedWork
                           }
                    else state {routingWork = completedWork}
            _ ->
              error
                "Qualification route invariant violated: typed route has no compact rank"
        _ -> error "Qualification route derivation lost its route defects"
  where
    proposalIdentity = storedQualificationProposalIdentity proposal
    proposalOccurrence = storedQualificationProposalOccurrence proposal
    references = storedQualificationProposalReferences proposal
    needReferences = referencesFor QualificationNeedRole references
    strategyReferences = referencesFor QualificationStrategyRole references
    (needRoute, needDefects, needWork) =
      assessRouteRole
        index
        proposal
        QualificationNeedRole
        endpointContextNeed
        ProposalNeedCardinalityRule
        ProposalNeedTargetRule
        needReferences
    (strategyRoute, strategyDefects, strategyWork) =
      assessRouteRole
        index
        proposal
        QualificationStrategyRole
        endpointContextStrategy
        ProposalStrategyCardinalityRule
        ProposalStrategyTargetRule
        strategyReferences
    routeDefects = needDefects ++ strategyDefects
    (orderedRouteDefects, routeDefectOrderingWork) =
      sortQualificationDefectsWithWork routeDefects
    visitedWork =
      addQualificationWork
        (routingWork state)
        (addQualificationWork
           needWork
           (addQualificationWork
              strategyWork
              (addQualificationWork
                 routeDefectOrderingWork
                 (emptyQualificationWork {qualificationProposalVisits = 1}))))

assessRouteRole ::
     QualificationIndex scope
  -> QualificationProposalInput
  -> QualificationRole
  -> CoreQualifiedEndpointId
  -> QualificationRule
  -> QualificationRule
  -> [QualificationReferenceInput]
  -> ( Maybe (QualificationReferenceInput, UntypedCarrier)
     , [QualificationDefect]
     , QualificationWork)
assessRouteRole index proposal role expected cardinalityRule targetRule references =
  (route, cardinalityDefects ++ targetDefects, work)
  where
    (canonicalReferenceOccurrences, referenceOrderingWork) =
      radixSortOn
        False
        occurrenceRadixKey
        (map storedQualificationReferenceOccurrence references)
    resolved =
      [ (reference, carrier, scalarVisits)
      | reference <- references
      , let target = storedQualificationReferenceTarget reference
      , let (carrier, scalarVisits) = qualificationCarrierAtAddress index target
      ]
    valid =
      [ (reference, untype carrier)
      | (reference, Just carrier, _) <- resolved
      , carrierQualifiedEndpoint (qualificationCarrierObservation carrier)
          == expected
      ]
    route =
      case (references, valid) of
        ([_], [single]) -> Just single
        _ -> Nothing
    cardinalityDefects =
      [ roleCardinalityDefect
        proposal
        role
        cardinalityRule
        canonicalReferenceOccurrences
      | length references /= 1
      ]
    targetDefects =
      [ roleTargetDefect proposal role targetRule reference
      | (reference, carrier, _) <- resolved
      , maybe
          True
          ((/= expected)
             . carrierQualifiedEndpoint
             . qualificationCarrierObservation)
          carrier
      ]
    work =
      addQualificationWork
        (if length references /= 1
           then referenceOrderingWork
           else emptyQualificationWork)
        (emptyQualificationWork
           { qualificationCarrierAddressVisits = length references
           , qualificationCarrierAddressScalarVisits =
               sum [scalarVisits | (_, _, scalarVisits) <- resolved]
           , qualificationAddressedSupportVisits = length references
           })

untype :: IndexedQualificationCarrier scope -> UntypedCarrier
untype indexedCarrier =
  UntypedCarrier
    (carrierOccurrenceIdentity carrier)
    (carrierModelIdentity carrier)
    (qualificationCarrierNeedRank indexedCarrier)
    (qualificationCarrierStrategyRank indexedCarrier)
  where
    carrier = qualificationCarrierObservation indexedCarrier

referencesFor ::
     QualificationRole
  -> [QualificationReferenceInput]
  -> [QualificationReferenceInput]
referencesFor role =
  filter
    ((== Just role)
       . qualificationRoleIdValue
       . storedQualificationReferenceRole)

assessPair ::
     QualificationIndex scope
  -> Map ModelIdentity (Semantics.SituatedNeedAssessment scope)
  -> Map ModelIdentity (Semantics.StrategyFormulationAssessment scope)
  -> IntMap (IntMap [RoutedProposal])
  -> ModelIdentity
  -> Int
  -> ModelIdentity
  -> Int
  -> (QualificationPairAssessment scope, QualificationWork)
assessPair index needs strategies buckets need needRank strategy strategyRank =
  case NonEmpty.nonEmpty orderedSubjectDefects of
    Just defects ->
      ( QualificationPairInvalidSubjects need strategy defects
      , subjectDefectOrderingWork)
    Nothing ->
      case maybe
             []
             (IntMap.findWithDefault [] strategyRank)
             (IntMap.lookup needRank buckets) of
        [] ->
          ( QualificationPairMissingProposal
              need
              strategy
              (pairPresenceDefect need strategy)
          , emptyQualificationWork)
        first:remaining ->
          ( QualificationPairProposals
              need
              strategy
              (fst firstResult :| map fst remainingResults)
          , foldl
              addQualificationWork
              emptyQualificationWork
              (map snd (firstResult : remainingResults)))
          where firstResult =
                  assessRoutedProposal index needProof strategyProof first
                remainingResults =
                  map
                    (assessRoutedProposal index needProof strategyProof)
                    remaining
  where
    needAssessment = Map.lookup need needs
    strategyAssessment = Map.lookup strategy strategies
    needProof =
      case needAssessment of
        Just (Semantics.SituatedNeedValid proof) -> Just proof
        _ -> Nothing
    strategyProof =
      case strategyAssessment of
        Just (Semantics.StrategyFormulationValid proof) -> Just proof
        _ -> Nothing
    (orderedSubjectDefects, subjectDefectOrderingWork) =
      sortQualificationDefectsWithWork
        ([needEligibilityDefect index need | needProof == Nothing]
           ++ [ strategyEligibilityDefect index strategy
              | strategyProof == Nothing
              ])

assessRoutedProposal ::
     QualificationIndex scope
  -> Maybe (Semantics.GloballySituatedNeed scope)
  -> Maybe (Semantics.QualificationEligibleStrategy scope)
  -> RoutedProposal
  -> (QualificationProposalAssessment scope, QualificationWork)
assessRoutedProposal index (Just needProof) (Just strategyProof) routed =
  case NonEmpty.nonEmpty orderedDefects of
    Just failures ->
      ( QualificationProposalInvalid
          proposalIdentity
          proposalOccurrence
          failures
      , work)
    Nothing ->
      case ( canonicalRationale
           , NonEmpty.nonEmpty canonicalSources
           , keyResultRoute
           , objectiveRoute) of
        (Just rationale, Just sources, Just (_, keyResultCarrier), Just (_, objectiveCarrier)) ->
          ( QualificationProposalAdmissible
              AdmissibleQualificationProposal
                { storedAdmissibleProposalIdentity = proposalIdentity
                , storedAdmissibleProposalOccurrence = proposalOccurrence
                , storedAdmissibleNeedIdentity = needIdentity
                , storedAdmissibleStrategyIdentity = strategyIdentity
                , storedAdmissibleKeyResultIdentity =
                    untypedCarrierIdentity keyResultCarrier
                , storedAdmissibleObjectiveIdentity =
                    untypedCarrierIdentity objectiveCarrier
                , storedAdmissibleRationale = rationale
                , storedAdmissibleSources = sources
                , storedAdmissibleWitnesses = witnesses
                }
          , work)
        _ -> error "Qualification admissibility lost a required defect"
  where
    proposal = routedProposalInput routed
    proposalIdentity = storedQualificationProposalIdentity proposal
    proposalOccurrence = storedQualificationProposalOccurrence proposal
    needReference = routedNeedReference routed
    strategyReference = routedStrategyReference routed
    needCarrier = routedNeedCarrier routed
    strategyCarrier = routedStrategyCarrier routed
    needIdentity = untypedCarrierIdentity needCarrier
    strategyIdentity = untypedCarrierIdentity strategyCarrier
    keyResultReferences =
      referencesFor
        QualificationKeyResultRole
        (storedQualificationProposalReferences proposal)
    objectiveReferences =
      referencesFor
        QualificationObjectiveRole
        (storedQualificationProposalReferences proposal)
    (keyResultRoute, keyResultDefects, keyResultWork) =
      assessRouteRole
        index
        proposal
        QualificationKeyResultRole
        endpointStrategyKeyResult
        ProposalKeyResultCardinalityRule
        ProposalKeyResultTargetRule
        keyResultReferences
    (objectiveRoute, objectiveDefects, objectiveWork) =
      assessRouteRole
        index
        proposal
        QualificationObjectiveRole
        endpointNeedObjective
        ProposalObjectiveCardinalityRule
        ProposalObjectiveTargetRule
        objectiveReferences
    canonicalRationale =
      storedQualificationProposalRationale proposal
        >>= either (const Nothing) (Just . canonicalFachlicheText)
              . canonicalizeFachlicheText
    assessedSources =
      [ ( source
        , canonicalizeFachlicheText (storedQualificationSourceText source))
      | source <- storedQualificationProposalSources proposal
      ]
    (canonicalSources, sourceOrderingWork) =
      radixSortOn
        True
        textRadixKey
        [canonicalFachlicheText value | (_, Right value) <- assessedSources]
    (invalidSourceOccurrences, invalidSourceOrderingWork) =
      radixSortOn
        False
        occurrenceRadixKey
        [ storedQualificationSourceOccurrence source
        | (source, Left _) <- assessedSources
        ]
    sourceValid =
      not (null (storedQualificationProposalSources proposal))
        && length canonicalSources
             == length (storedQualificationProposalSources proposal)
    (effectOccurrences, effectAddressScalarVisits) =
      qualificationOccurrencesForIdentityAtAddress index proposalIdentity
    rationaleDefects =
      [ proposalDefect ProposalRationaleRule proposal
      | canonicalRationale == Nothing
      ]
    sourceDefects =
      [ proposalDefectWith
        ProposalSourcesRule
        proposal
        [occurrenceGroup "sources" invalidSourceOccurrences]
      | not sourceValid
      ]
    membershipDefects =
      [ proposalDefectWith
        ProposalEffectGraphMembershipRule
        proposal
        [occurrenceGroup "effect-graph" effectOccurrences]
      | not (null effectOccurrences)
      ]
    listedDefects =
      case keyResultRoute of
        Just (reference, carrier)
          | untypedCarrierIdentity carrier
              `notElem` NonEmpty.toList
                          (formulationKeyResults
                             (Semantics.eligibleStrategyInput strategyProof)) ->
            [ roleTargetDefect
                proposal
                QualificationKeyResultRole
                ProposalListedKeyResultRule
                reference
            ]
        _ -> []
    (keyResultContext, keyResultContextAddressVisits, keyResultContextAddressScalarVisits) =
      contextualizationForRoute index keyResultRoute
    (objectiveContext, objectiveContextAddressVisits, objectiveContextAddressScalarVisits) =
      contextualizationForRoute index objectiveRoute
    keyResultContextDefects =
      contextDefects
        proposal
        QualificationKeyResultRole
        ProposalKeyResultContextRule
        keyResultRoute
        keyResultContext
        (Semantics.eligibleStrategyOccurrence strategyProof)
    objectiveContextDefects =
      contextDefects
        proposal
        QualificationObjectiveRole
        ProposalObjectiveContextRule
        objectiveRoute
        objectiveContext
        (Semantics.situatedNeedOccurrence needProof)
    (primitiveRelations, primitiveRelationAddressVisits, primitiveRelationAddressScalarVisits) =
      relationsForRoutes index keyResultRoute tokenTranslatesInto objectiveRoute
    (macroRelations, macroRelationAddressScalarVisits) =
      qualificationRelationsBetweenAtAddress
        index
        (untypedCarrierOccurrence strategyCarrier)
        tokenQualifies
        (untypedCarrierOccurrence needCarrier)
    primitiveExistingDefects =
      [ relationDefect
        ProposalExistingPrimitiveSupportRule
        proposal
        "strategy-key-result-translates-into-need-objective"
        primitiveRelations
      | not (null primitiveRelations)
      ]
    macroExistingDefects =
      [ relationDefect
        ProposalExistingMacroQualificationRule
        proposal
        "strategy-qualifies-need"
        macroRelations
      | not (null macroRelations)
      ]
    defects =
      membershipDefects
        ++ keyResultDefects
        ++ objectiveDefects
        ++ rationaleDefects
        ++ sourceDefects
        ++ listedDefects
        ++ keyResultContextDefects
        ++ objectiveContextDefects
        ++ primitiveExistingDefects
        ++ macroExistingDefects
    (orderedDefects, defectOrderingWork) =
      sortQualificationDefectsWithWork defects
    work =
      foldl
        addQualificationWork
        (emptyQualificationWork
           { qualificationSupportAddressVisits =
               2
                 + keyResultContextAddressVisits
                 + objectiveContextAddressVisits
                 + primitiveRelationAddressVisits
           , qualificationSupportAddressScalarVisits =
               effectAddressScalarVisits
                 + keyResultContextAddressScalarVisits
                 + objectiveContextAddressScalarVisits
                 + primitiveRelationAddressScalarVisits
                 + macroRelationAddressScalarVisits
           , qualificationAddressedSupportVisits =
               length effectOccurrences
                 + maybe 0 (const 1) keyResultContext
                 + maybe 0 (const 1) objectiveContext
                 + length primitiveRelations
                 + length macroRelations
           })
        [ keyResultWork
        , objectiveWork
        , sourceOrderingWork
        , invalidSourceOrderingWork
        , defectOrderingWork
        , witnessOrderingWork
        ]
    (witnesses, witnessOrderingWork) =
      radixSortUniqueOn True occurrenceRadixKey rawWitnesses
    rawWitnesses =
      [ proposalOccurrence
      , storedQualificationReferenceOccurrence needReference
      , storedQualificationReferenceTarget needReference
      , storedQualificationReferenceOccurrence strategyReference
      , storedQualificationReferenceTarget strategyReference
      ]
        ++ map
             storedQualificationSourceOccurrence
             (storedQualificationProposalSources proposal)
        ++ routeWitnesses keyResultRoute
        ++ routeWitnesses objectiveRoute
        ++ maybe
             []
             (pure . contextualizationOccurrenceIdentity)
             keyResultContext
        ++ maybe
             []
             (pure . contextualizationOccurrenceIdentity)
             objectiveContext
        ++ Semantics.situatedNeedWitnesses needProof
        ++ Semantics.eligibleStrategyWitnesses strategyProof
assessRoutedProposal _ _ _ _ =
  error "Qualification proposal evaluated without valid pair subjects"

contextualizationForRoute ::
     QualificationIndex scope
  -> Maybe (QualificationReferenceInput, UntypedCarrier)
  -> (Maybe (ContextualizationObservation scope), Int, Int)
contextualizationForRoute index route =
  case route of
    Nothing -> (Nothing, 0, 0)
    Just (_, carrier) ->
      let (owner, scalarVisits) =
            qualificationOwnerForMemberAtAddress
              index
              (untypedCarrierOccurrence carrier)
       in (owner, 1, scalarVisits)

contextDefects ::
     QualificationProposalInput
  -> QualificationRole
  -> QualificationRule
  -> Maybe (QualificationReferenceInput, UntypedCarrier)
  -> Maybe (ContextualizationObservation scope)
  -> OccurrenceIdentity
  -> [QualificationDefect]
contextDefects proposal role rule route contextualization expectedOwner =
  case route of
    Nothing -> []
    Just (reference, _) ->
      [ QualificationDefect
        rule
        (QualificationProposalRoleTargetKey
           (storedQualificationProposalIdentity proposal)
           role
           (storedQualificationReferenceTarget reference))
        (occurrenceGroup
           "proposal"
           [storedQualificationProposalOccurrence proposal]
           :| [ occurrenceGroup
                  "reference"
                  [storedQualificationReferenceOccurrence reference]
              , occurrenceGroup
                  "target"
                  [storedQualificationReferenceTarget reference]
              , occurrenceGroup
                  "contextualization"
                  (maybe
                     []
                     (pure . contextualizationOccurrenceIdentity)
                     contextualization)
              ])
      | maybe
          True
          ((/= expectedOwner) . contextualizationOwnerOccurrence)
          contextualization
      ]

relationsForRoutes ::
     QualificationIndex scope
  -> Maybe (QualificationReferenceInput, UntypedCarrier)
  -> CoreRelationToken
  -> Maybe (QualificationReferenceInput, UntypedCarrier)
  -> ([RelationObservation scope], Int, Int)
relationsForRoutes index source token target =
  case (source, target) of
    (Just (_, sourceCarrier), Just (_, targetCarrier)) ->
      let (relations, scalarVisits) =
            qualificationRelationsBetweenAtAddress
              index
              (untypedCarrierOccurrence sourceCarrier)
              token
              (untypedCarrierOccurrence targetCarrier)
       in (relations, 1, scalarVisits)
    _ -> ([], 0, 0)

routeWitnesses ::
     Maybe (QualificationReferenceInput, UntypedCarrier) -> [OccurrenceIdentity]
routeWitnesses route =
  case route of
    Nothing -> []
    Just (reference, carrier) ->
      [ storedQualificationReferenceOccurrence reference
      , untypedCarrierOccurrence carrier
      ]

roleCardinalityDefect ::
     QualificationProposalInput
  -> QualificationRole
  -> QualificationRule
  -> [OccurrenceIdentity]
  -> QualificationDefect
roleCardinalityDefect proposal role rule references =
  QualificationDefect
    rule
    (QualificationProposalRoleKey
       (storedQualificationProposalIdentity proposal)
       role)
    (occurrenceGroup "proposal" [storedQualificationProposalOccurrence proposal]
       :| [occurrenceGroup "references" references])

roleTargetDefect ::
     QualificationProposalInput
  -> QualificationRole
  -> QualificationRule
  -> QualificationReferenceInput
  -> QualificationDefect
roleTargetDefect proposal role rule reference =
  QualificationDefect
    rule
    (QualificationProposalRoleTargetKey
       (storedQualificationProposalIdentity proposal)
       role
       (storedQualificationReferenceTarget reference))
    (occurrenceGroup "proposal" [storedQualificationProposalOccurrence proposal]
       :| [ occurrenceGroup
              "reference"
              [storedQualificationReferenceOccurrence reference]
          , occurrenceGroup
              "target"
              [storedQualificationReferenceTarget reference]
          ])

proposalDefect ::
     QualificationRule -> QualificationProposalInput -> QualificationDefect
proposalDefect rule proposal = proposalDefectWith rule proposal []

proposalDefectWith ::
     QualificationRule
  -> QualificationProposalInput
  -> [QualificationOccurrenceGroup]
  -> QualificationDefect
proposalDefectWith rule proposal extra =
  QualificationDefect
    rule
    (QualificationProposalKey (storedQualificationProposalIdentity proposal))
    (occurrenceGroup "proposal" [storedQualificationProposalOccurrence proposal]
       :| extra)

relationDefect ::
     QualificationRule
  -> QualificationProposalInput
  -> Text
  -> [RelationObservation scope]
  -> QualificationDefect
relationDefect rule proposal semanticRelation relations =
  QualificationDefect
    rule
    (QualificationProposalRelationKey
       (storedQualificationProposalIdentity proposal)
       semanticRelation)
    (occurrenceGroup "proposal" [storedQualificationProposalOccurrence proposal]
       :| [ occurrenceGroup
              "relations"
              (map relationOccurrenceIdentity relations)
          ])

needEligibilityDefect ::
     QualificationIndex scope -> ModelIdentity -> QualificationDefect
needEligibilityDefect index need =
  QualificationDefect
    ProposalNeedEligibilityRule
    (QualificationSelectedNeedKey need)
    (occurrenceGroup "need" (qualificationOccurrencesForIdentity index need)
       :| [])

strategyEligibilityDefect ::
     QualificationIndex scope -> ModelIdentity -> QualificationDefect
strategyEligibilityDefect index strategy =
  QualificationDefect
    ProposalStrategyEligibilityRule
    (QualificationSelectedStrategyKey strategy)
    (occurrenceGroup
       "strategy"
       (qualificationOccurrencesForIdentity index strategy)
       :| [])

pairPresenceDefect :: ModelIdentity -> ModelIdentity -> QualificationDefect
pairPresenceDefect need strategy =
  QualificationDefect
    PairProposalPresenceRule
    (QualificationPairKey need strategy)
    (occurrenceGroup "proposal" [] :| [])

occurrenceGroup :: Text -> [OccurrenceIdentity] -> QualificationOccurrenceGroup
occurrenceGroup = QualificationOccurrenceGroup

qualificationAssessmentStructuralSize :: QualificationAssessment scope -> Int
qualificationAssessmentStructuralSize assessment =
  1
    + length (storedQualificationSelectedNeeds assessment)
    + length (storedQualificationSelectedStrategies assessment)
    + sum
        [ 1 + length (storedQualificationUnavailableOccurrences unavailable)
        | unavailable <- storedQualificationSubjectUnavailable assessment
        ]
    + sum
        (map
           qualificationProposalStructuralSize
           (storedQualificationUnroutedProposals assessment))
    + sum
        (map
           qualificationPairStructuralSize
           (storedQualificationPairs assessment))

qualificationPairStructuralSize :: QualificationPairAssessment scope -> Int
qualificationPairStructuralSize pair =
  case pair of
    QualificationPairInvalidSubjects _ _ defects ->
      1 + sum (map qualificationDefectStructuralSize (NonEmpty.toList defects))
    QualificationPairMissingProposal _ _ defect ->
      1 + qualificationDefectStructuralSize defect
    QualificationPairProposals _ _ proposals ->
      1
        + sum
            (map qualificationProposalStructuralSize (NonEmpty.toList proposals))

qualificationProposalStructuralSize ::
     QualificationProposalAssessment scope -> Int
qualificationProposalStructuralSize proposal =
  case proposal of
    QualificationProposalUnrouted _ _ defects ->
      1 + sum (map qualificationDefectStructuralSize (NonEmpty.toList defects))
    QualificationProposalInvalid _ _ defects ->
      1 + sum (map qualificationDefectStructuralSize (NonEmpty.toList defects))
    QualificationProposalAdmissible proof ->
      1
        + NonEmpty.length (storedAdmissibleSources proof)
        + length (storedAdmissibleWitnesses proof)

qualificationDefectStructuralSize :: QualificationDefect -> Int
qualificationDefectStructuralSize defect =
  2
    + sum
        [ 1 + length (storedQualificationOccurrenceValues group)
        | group <- NonEmpty.toList (storedQualificationDefectOccurrences defect)
        ]

qualificationAssessmentScalarSize :: QualificationAssessment scope -> Int
qualificationAssessmentScalarSize assessment =
  modelScalarSize (storedQualificationGraphIdentity assessment)
    + sum (map modelScalarSize (storedQualificationSelectedNeeds assessment))
    + sum
        (map modelScalarSize (storedQualificationSelectedStrategies assessment))
    + sum
        [ modelScalarSize (storedQualificationUnavailableIdentity unavailable)
          + sum
              (map
                 occurrenceScalarSize
                 (storedQualificationUnavailableOccurrences unavailable))
        | unavailable <- storedQualificationSubjectUnavailable assessment
        ]
    + sum
        (map
           qualificationProposalScalarSize
           (storedQualificationUnroutedProposals assessment))
    + sum
        (map qualificationPairScalarSize (storedQualificationPairs assessment))

qualificationPairScalarSize :: QualificationPairAssessment scope -> Int
qualificationPairScalarSize pair =
  case pair of
    QualificationPairInvalidSubjects need strategy defects ->
      modelScalarSize need
        + modelScalarSize strategy
        + sum (map qualificationDefectScalarSize (NonEmpty.toList defects))
    QualificationPairMissingProposal need strategy defect ->
      modelScalarSize need
        + modelScalarSize strategy
        + qualificationDefectScalarSize defect
    QualificationPairProposals need strategy proposals ->
      modelScalarSize need
        + modelScalarSize strategy
        + sum (map qualificationProposalScalarSize (NonEmpty.toList proposals))

qualificationProposalScalarSize :: QualificationProposalAssessment scope -> Int
qualificationProposalScalarSize proposal =
  case proposal of
    QualificationProposalUnrouted identifier occurrence defects ->
      modelScalarSize identifier
        + occurrenceScalarSize occurrence
        + sum (map qualificationDefectScalarSize (NonEmpty.toList defects))
    QualificationProposalInvalid identifier occurrence defects ->
      modelScalarSize identifier
        + occurrenceScalarSize occurrence
        + sum (map qualificationDefectScalarSize (NonEmpty.toList defects))
    QualificationProposalAdmissible proof ->
      sum
        [ modelScalarSize (storedAdmissibleProposalIdentity proof)
        , occurrenceScalarSize (storedAdmissibleProposalOccurrence proof)
        , modelScalarSize (storedAdmissibleNeedIdentity proof)
        , modelScalarSize (storedAdmissibleStrategyIdentity proof)
        , modelScalarSize (storedAdmissibleKeyResultIdentity proof)
        , modelScalarSize (storedAdmissibleObjectiveIdentity proof)
        , Text.length (storedAdmissibleRationale proof)
        , sum
            (map Text.length (NonEmpty.toList (storedAdmissibleSources proof)))
        , sum (map occurrenceScalarSize (storedAdmissibleWitnesses proof))
        ]

qualificationDefectScalarSize :: QualificationDefect -> Int
qualificationDefectScalarSize defect =
  Text.length (coreRuleIdText (qualificationRuleId rule))
    + qualificationEvidenceScalarSize (storedQualificationDefectEvidence defect)
    + sum
        (map
           qualificationOccurrenceGroupScalarSize
           (NonEmpty.toList (storedQualificationDefectOccurrences defect)))
  where
    rule = storedQualificationDefectRule defect
