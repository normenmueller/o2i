{-# LANGUAGE OverloadedStrings #-}

-- | Exact selected-View identity binding for supplemental input.
module O2I.Input.Internal.Binding
  ( bindSupplementalInputs
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal
  ( CoreQualifiedEndpointId(..)
  , CoreStructuredPropositionFamilyId(..)
  )
import O2I.Core.Graph.Observation
  ( carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  , contextualizationOccurrenceIdentity
  , relationOccurrenceIdentity
  )
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Core.Identity.Internal
  ( IdentityResolution(..)
  , ScopedOccurrence
  , SelectedIdentityKind(..)
  , resolveIdentity
  , scopedOccurrenceIdentity
  )
import O2I.Input.Internal.Types
import O2I.Structure
  ( structuredIncidenceOccurrence
  , structuredPropositionFamily
  , structuredPropositionIncidences
  , structuredPropositionOccurrence
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )
import O2I.Structure.Internal (WellFormedGraph(..))

-- | Bind every payload identity to its exact selected-View identity kind.
--
-- The resolver applies the normative unknown, ambiguous, out-of-View,
-- wrong-kind precedence. Independent identity sites accumulate in canonical
-- evidence-key order. The bound value retains exact unresolved sites so each
-- dependent semantic rule can suppress only the prerequisites it requires.
bindSupplementalInputs ::
     WellFormedGraph scope
  -> SupplementalInputSet provenance
  -> SupplementalBinding scope provenance
bindSupplementalInputs graph inputs@(SupplementalInputSet payloads) =
  SupplementalBinding
    { supplementalBindingInputs =
        BoundSupplementalInputs
          (forgetSupplementalInputSetProvenance inputs)
          unresolvedSites
    , supplementalBindingDiagnosticDefects = defects
    }
  where
    kinds = identityKinds graph
    defects =
      sortOn
        snd
        (concatMap
           (\input ->
              map
                (\defect -> (supplementalInputProvenance input, defect))
                (bindingDefects graph kinds input))
           payloads)
    unresolvedSites = Set.fromList (map (defectIdentitySite . snd) defects)

forgetSupplementalInputSetProvenance ::
     SupplementalInputSet provenance -> SupplementalInputSet ()
forgetSupplementalInputSetProvenance (SupplementalInputSet inputs) =
  SupplementalInputSet (map forget inputs)
  where
    forget input =
      case input of
        StrategyFormulationSupplement _ ordinal formulation ->
          StrategyFormulationSupplement () ordinal formulation
        CollectiveFitSupplement _ ordinal collective ->
          CollectiveFitSupplement () ordinal collective

defectIdentitySite ::
     SupplementalBindingDiagnosticDefect -> SupplementalIdentitySite
defectIdentitySite defect =
  case defect of
    SupplementalBindingIdentityUnknown (SupplementalIdentityUnknownEvidence ordinal pointer identifier) ->
      SupplementalIdentitySite ordinal pointer identifier
    SupplementalBindingIdentityAmbiguous (SupplementalIdentityAmbiguousEvidence ordinal pointer identifier) ->
      SupplementalIdentitySite ordinal pointer identifier
    SupplementalBindingIdentityWrongType (SupplementalIdentityWrongTypeEvidence ordinal pointer identifier) ->
      SupplementalIdentitySite ordinal pointer identifier
    SupplementalBindingIdentityOutOfSelectedView (SupplementalIdentityOutOfSelectedViewEvidence ordinal pointer identifier) ->
      SupplementalIdentitySite ordinal pointer identifier

bindingDefects ::
     WellFormedGraph scope
  -> Map OccurrenceIdentity SelectedIdentityKind
  -> SupplementalInput provenance
  -> [SupplementalBindingDiagnosticDefect]
bindingDefects graph kinds input =
  case input of
    StrategyFormulationSupplement _ ordinal formulation ->
      concat
        [ resolveSite
            graph
            kinds
            ordinal
            "/strategy"
            strategyKind
            (formulationStrategy formulation)
        , resolveSite
            graph
            kinds
            ordinal
            "/diagnosis"
            strategyDriverKind
            (formulationDiagnosis formulation)
        , resolveSite
            graph
            kinds
            ordinal
            "/intent"
            strategyObjectiveKind
            (formulationIntent formulation)
        , resolveSite
            graph
            kinds
            ordinal
            "/guidingPolicy"
            strategyPrincipleKind
            (formulationGuidingPolicy formulation)
        , resolveSites
            graph
            kinds
            ordinal
            "/actions"
            strategyActionKind
            (formulationActions formulation)
        , resolveSites
            graph
            kinds
            ordinal
            "/keyResults"
            strategyKeyResultKind
            (formulationKeyResults formulation)
        ]
    CollectiveFitSupplement _ ordinal collective ->
      concat
        [ resolveSite
            graph
            kinds
            ordinal
            "/claim"
            collectiveFamilyKind
            (collectiveClaim collective)
        , resolveSites
            graph
            kinds
            ordinal
            "/participants"
            strategyKind
            (collectiveParticipants collective)
        , resolveSite
            graph
            kinds
            ordinal
            "/target"
            strategyKind
            (collectiveTarget collective)
        , resolveSite
            graph
            kinds
            ordinal
            "/targetGuidingPolicy"
            strategyPrincipleKind
            (collectiveTargetGuidingPolicy collective)
        , concat
            [ resolveSite
              graph
              kinds
              ordinal
              (itemPointer index "participantA")
              strategyKind
              (pairwiseParticipantA coherence)
              ++ resolveSite
                   graph
                   kinds
                   ordinal
                   (itemPointer index "participantB")
                   strategyKind
                   (pairwiseParticipantB coherence)
            | (index, coherence) <-
                indexed (collectivePairwiseCoherence collective)
            ]
        , concat
            [ resolveSite
              graph
              kinds
              ordinal
              (compatibilityPointer index)
              strategyKind
              (compatibilityParticipant compatibility)
            | (index, compatibility) <-
                indexed (collectiveParticipantCompatibility collective)
            ]
        ]

resolveSites ::
     WellFormedGraph scope
  -> Map OccurrenceIdentity SelectedIdentityKind
  -> SupplementalInputOrdinal
  -> Text
  -> SelectedIdentityKind
  -> NonEmpty ModelIdentity
  -> [SupplementalBindingDiagnosticDefect]
resolveSites graph kinds ordinal pointer expected identities =
  concat
    [ resolveSite
      graph
      kinds
      ordinal
      (appendIndex pointer index)
      expected
      identifier
    | (index, identifier) <- indexed identities
    ]

resolveSite ::
     WellFormedGraph scope
  -> Map OccurrenceIdentity SelectedIdentityKind
  -> SupplementalInputOrdinal
  -> Text
  -> SelectedIdentityKind
  -> ModelIdentity
  -> [SupplementalBindingDiagnosticDefect]
resolveSite graph kinds ordinal pointer expected identifier =
  case resolveIdentity
         (wellFormedSelectedViewScope graph)
         (classify kinds)
         expected
         identifier of
    UnknownModelIdentity _ ->
      [ SupplementalBindingIdentityUnknown
          (SupplementalIdentityUnknownEvidence ordinal pointer identifier)
      ]
    AmbiguousModelIdentity _ _ ->
      [ SupplementalBindingIdentityAmbiguous
          (SupplementalIdentityAmbiguousEvidence ordinal pointer identifier)
      ]
    ModelIdentityOutOfSelectedView _ _ ->
      [ SupplementalBindingIdentityOutOfSelectedView
          (SupplementalIdentityOutOfSelectedViewEvidence
             ordinal
             pointer
             identifier)
      ]
    WrongSelectedIdentityKind _ _ _ ->
      [ SupplementalBindingIdentityWrongType
          (SupplementalIdentityWrongTypeEvidence ordinal pointer identifier)
      ]
    ResolvedIdentity _ _ -> []

classify ::
     Map OccurrenceIdentity SelectedIdentityKind
  -> ScopedOccurrence scope
  -> SelectedIdentityKind
classify kinds occurrence =
  Map.findWithDefault
    SelectedUnclassifiedOccurrence
    (scopedOccurrenceIdentity occurrence)
    kinds

identityKinds ::
     WellFormedGraph scope -> Map OccurrenceIdentity SelectedIdentityKind
identityKinds graph =
  Map.fromList
    (carrierKinds
       ++ relationKinds
       ++ contextualizationKinds
       ++ propositionKinds
       ++ incidenceKinds)
  where
    propositions = wellFormedStructuredPropositions graph
    carrierKinds =
      [ ( carrierOccurrenceIdentity carrier
        , SelectedCarrier (carrierQualifiedEndpoint carrier))
      | carrier <- wellFormedCarriers graph
      ]
    relationKinds =
      [ (relationOccurrenceIdentity relation, SelectedRelation)
      | relation <- wellFormedRelations graph
      ]
    contextualizationKinds =
      [ ( contextualizationOccurrenceIdentity contextualization
        , SelectedContextualization)
      | contextualization <- wellFormedContextualizations graph
      ]
    propositionKinds =
      [ ( structuredPropositionOccurrence proposition
        , SelectedStructuredProposition
            (structuredPropositionFamily proposition))
      | proposition <- propositions
      ]
    incidenceKinds =
      [ (structuredIncidenceOccurrence incidence, SelectedStructuredIncidence)
      | proposition <- propositions
      , incidence <- structuredPropositionIncidences proposition
      ]

strategyKind :: SelectedIdentityKind
strategyKind =
  SelectedCarrier
    (CoreQualifiedEndpointId Generated.GeneratedEndpointContextStrategy)

strategyDriverKind :: SelectedIdentityKind
strategyDriverKind =
  SelectedCarrier
    (CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyDriver)

strategyObjectiveKind :: SelectedIdentityKind
strategyObjectiveKind =
  SelectedCarrier
    (CoreQualifiedEndpointId
       Generated.GeneratedEndpointPrimitiveStrategyObjective)

strategyPrincipleKind :: SelectedIdentityKind
strategyPrincipleKind =
  SelectedCarrier
    (CoreQualifiedEndpointId
       Generated.GeneratedEndpointPrimitiveStrategyPrinciple)

strategyActionKind :: SelectedIdentityKind
strategyActionKind =
  SelectedCarrier
    (CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyAction)

strategyKeyResultKind :: SelectedIdentityKind
strategyKeyResultKind =
  SelectedCarrier
    (CoreQualifiedEndpointId
       Generated.GeneratedEndpointPrimitiveStrategyKeyResult)

collectiveFamilyKind :: SelectedIdentityKind
collectiveFamilyKind =
  SelectedStructuredProposition
    (CoreStructuredPropositionFamilyId
       Generated.GeneratedFamilyCollectiveStrategyRealization)

indexed :: NonEmpty value -> [(Int, value)]
indexed = zip [0 ..] . foldr (:) []

itemPointer :: Int -> Text -> Text
itemPointer index member =
  appendIndex "/pairwiseCoherence" index <> "/" <> member

compatibilityPointer :: Int -> Text
compatibilityPointer index =
  appendIndex "/participantCompatibility" index <> "/participant"

appendIndex :: Text -> Int -> Text
appendIndex pointer index = pointer <> "/" <> Text.pack (show index)
