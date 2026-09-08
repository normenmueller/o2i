{-# LANGUAGE OverloadedStrings #-}

-- | Selected-View binding for decoded Readiness identity sites.
module O2I.Readiness.Binding
  ( bindReadinessInputInternal
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal (CoreQualifiedEndpointId(..), CoreRuleId(..))
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
  , selectedViewScopeGraphIdentity
  )
import O2I.Readiness.Internal
import O2I.Structure
  ( WellFormedGraph
  , wellFormedCarriers
  , wellFormedContextualizations
  , wellFormedRelations
  )
import O2I.Structure.Internal (WellFormedGraph(..))
import O2I.Trace
  ( TraceVariable(..)
  , traceIdentityBinding
  , traceIdentityGraphIdentity
  )
import O2I.Trace.Internal (BoundTraceIdentity(..))

bindReadinessInputInternal ::
     WellFormedGraph scope -> ReadinessInput -> ReadinessInputBinding scope
bindReadinessInputInternal graph input =
  case sortEvidenceInputDefects (bindingDefects graph input) of
    [] ->
      ReadinessInputBound
        (BoundReadinessInput
           input
           (BoundTraceIdentity (storedEvidenceTrace (storedEvidencePlan input))))
    first:remaining ->
      ReadinessInputSubjectUnavailable input (first :| remaining)

bindingDefects ::
     WellFormedGraph scope -> ReadinessInput -> [EvidenceInputDefect]
bindingDefects graph input =
  graphDefects
    <> concat
         [ resolveSite
           graph
           kinds
           ordinal
           ("/evidencePlan/trace/bindings/" <> name)
           (variableKinds variable)
           (traceIdentityBinding trace variable)
         | (name, variable) <- bindingFields
         ]
    <> resolveSite
         graph
         kinds
         ordinal
         "/kpiDefinition/kpi"
         (endpoint Generated.GeneratedEndpointPrimitiveMeasureKpi :| [])
         (storedKpiIdentity (storedKpiDefinition input))
    <> resolveSite
         graph
         kinds
         ordinal
         "/plannedStart/intervention"
         (endpoint Generated.GeneratedEndpointContextIntervention :| [])
         (storedPlannedIntervention (storedPlannedStart input))
  where
    ordinal = storedReadinessOrdinal input
    trace = storedEvidenceTrace (storedEvidencePlan input)
    kinds = identityKinds graph
    graphDefects =
      bindGraphIdentity graph kinds ordinal (traceIdentityGraphIdentity trace)

bindGraphIdentity ::
     WellFormedGraph scope
  -> Map OccurrenceIdentity SelectedIdentityKind
  -> ReadinessInputOrdinal
  -> ModelIdentity
  -> [EvidenceInputDefect]
bindGraphIdentity graph kinds ordinal identity
  | identity == expected = []
  | otherwise =
    case resolveIdentity
           scope
           (classify kinds)
           SelectedUnclassifiedOccurrence
           identity of
      UnknownModelIdentity _ -> [bindingDefect EvidenceInputIdentityUnknown]
      AmbiguousModelIdentity _ _ ->
        [bindingDefect EvidenceInputIdentityAmbiguous]
      ModelIdentityOutOfSelectedView _ _ ->
        [bindingDefect EvidenceInputIdentityOutOfSelectedView]
      WrongSelectedIdentityKind _ _ _ ->
        [bindingDefect EvidenceInputIdentityWrongType]
      ResolvedIdentity _ _ -> [bindingDefect EvidenceInputIdentityWrongType]
  where
    scope = wellFormedSelectedViewScope graph
    expected = selectedViewScopeGraphIdentity scope
    bindingDefect kind =
      EvidenceInputDefect
        (bindingRule kind)
        kind
        ordinal
        "/evidencePlan/trace/graphIdentity"
        (EvidenceInputModelSubject "modelIdentity" identity
           :| [EvidenceInputModelSubject "expectedGraphIdentity" expected])

resolveSite ::
     WellFormedGraph scope
  -> Map OccurrenceIdentity SelectedIdentityKind
  -> ReadinessInputOrdinal
  -> Text
  -> NonEmpty SelectedIdentityKind
  -> ModelIdentity
  -> [EvidenceInputDefect]
resolveSite graph kinds ordinal pointer expectedKinds identity =
  case resolveIdentity
         (wellFormedSelectedViewScope graph)
         (classify kinds)
         (NonEmpty.head expectedKinds)
         identity of
    UnknownModelIdentity _ -> [bindingDefect EvidenceInputIdentityUnknown []]
    AmbiguousModelIdentity _ occurrences ->
      [ bindingDefect
          EvidenceInputIdentityAmbiguous
          (map
             (EvidenceInputOccurrenceSubject "occurrence")
             (NonEmpty.toList occurrences))
      ]
    ModelIdentityOutOfSelectedView _ occurrence ->
      [ bindingDefect
          EvidenceInputIdentityOutOfSelectedView
          [EvidenceInputOccurrenceSubject "occurrence" occurrence]
      ]
    WrongSelectedIdentityKind occurrence _ actual
      | actual `elem` NonEmpty.toList expectedKinds -> []
      | otherwise ->
        [ bindingDefect
            EvidenceInputIdentityWrongType
            [ EvidenceInputOccurrenceSubject
                "occurrence"
                (scopedOccurrenceIdentity occurrence)
            ]
        ]
    ResolvedIdentity _ _ -> []
  where
    bindingDefect kind extra =
      EvidenceInputDefect
        (bindingRule kind)
        kind
        ordinal
        pointer
        (EvidenceInputModelSubject "modelIdentity" identity
           :| (map
                 (EvidenceInputQualifiedTypeSubject "expectedQualifiedType"
                    . selectedEndpoint)
                 (NonEmpty.toList expectedKinds)
                 <> extra))

selectedEndpoint :: SelectedIdentityKind -> CoreQualifiedEndpointId
selectedEndpoint kind =
  case kind of
    SelectedCarrier value -> value
    _ -> error "Readiness identity site requires a carrier endpoint"

bindingRule :: EvidenceInputDefectKind -> CoreRuleId
bindingRule kind =
  CoreRuleId
    $ case kind of
        EvidenceInputIdentityUnknown -> "core.evidence-input.identity.unknown"
        EvidenceInputIdentityAmbiguous ->
          "core.evidence-input.identity.ambiguous"
        EvidenceInputIdentityOutOfSelectedView ->
          "core.evidence-input.identity.out-of-selected-view"
        EvidenceInputIdentityWrongType ->
          "core.evidence-input.identity.wrong-type"
        _ -> error "Readiness binding received a non-binding defect"

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
    ([ ( carrierOccurrenceIdentity carrier
       , SelectedCarrier (carrierQualifiedEndpoint carrier))
     | carrier <- wellFormedCarriers graph
     ]
       <> [ (relationOccurrenceIdentity relation, SelectedRelation)
          | relation <- wellFormedRelations graph
          ]
       <> [ ( contextualizationOccurrenceIdentity contextualization
            , SelectedContextualization)
          | contextualization <- wellFormedContextualizations graph
          ])

endpoint :: Generated.GeneratedQualifiedEndpoint -> SelectedIdentityKind
endpoint = SelectedCarrier . CoreQualifiedEndpointId

variableKinds :: TraceVariable -> NonEmpty SelectedIdentityKind
variableKinds variable =
  case variable of
    VisionVariable -> one Generated.GeneratedEndpointContextVision
    StrategyVariable -> one Generated.GeneratedEndpointContextStrategy
    NeedVariable -> one Generated.GeneratedEndpointContextNeed
    InterventionVariable -> one Generated.GeneratedEndpointContextIntervention
    MeasureVariable -> one Generated.GeneratedEndpointContextMeasure
    SituationVariable -> one Generated.GeneratedEndpointContextSituation
    VisionObjectiveVariable ->
      one Generated.GeneratedEndpointPrimitiveVisionObjective
    StrategyDriverVariable ->
      one Generated.GeneratedEndpointPrimitiveStrategyDriver
    StrategyObjectiveVariable ->
      one Generated.GeneratedEndpointPrimitiveStrategyObjective
    StrategyActionVariable ->
      one Generated.GeneratedEndpointPrimitiveStrategyAction
    StrategyKeyResultVariable ->
      one Generated.GeneratedEndpointPrimitiveStrategyKeyResult
    NeedDriverVariable -> one Generated.GeneratedEndpointPrimitiveNeedDriver
    NeedObjectiveVariable ->
      one Generated.GeneratedEndpointPrimitiveNeedObjective
    InterventionActionVariable ->
      one Generated.GeneratedEndpointPrimitiveInterventionAction
    InterventionKeyResultVariable ->
      one Generated.GeneratedEndpointPrimitiveInterventionKeyResult
    MeasurePerformanceDimensionVariable ->
      one Generated.GeneratedEndpointStructuringMeasurePerformanceDimension
    MeasureKpiVariable -> one Generated.GeneratedEndpointPrimitiveMeasureKpi
    SituationAnchorVariable ->
      endpoint Generated.GeneratedEndpointSituationAnchorBusinessCapability
        :| [ endpoint Generated.GeneratedEndpointSituationAnchorBusinessProcess
           , endpoint Generated.GeneratedEndpointSituationAnchorBusinessObject
           , endpoint Generated.GeneratedEndpointSituationAnchorValueStream
           ]
  where
    one value = endpoint value :| []

bindingFields :: [(Text, TraceVariable)]
bindingFields =
  [ ("vision", VisionVariable)
  , ("strategy", StrategyVariable)
  , ("need", NeedVariable)
  , ("intervention", InterventionVariable)
  , ("measure", MeasureVariable)
  , ("situation", SituationVariable)
  , ("visionObjective", VisionObjectiveVariable)
  , ("strategyDriver", StrategyDriverVariable)
  , ("strategyObjective", StrategyObjectiveVariable)
  , ("strategyAction", StrategyActionVariable)
  , ("strategyKeyResult", StrategyKeyResultVariable)
  , ("needDriver", NeedDriverVariable)
  , ("needObjective", NeedObjectiveVariable)
  , ("interventionAction", InterventionActionVariable)
  , ("interventionKeyResult", InterventionKeyResultVariable)
  , ("measurePerformanceDimension", MeasurePerformanceDimensionVariable)
  , ("measureKpi", MeasureKpiVariable)
  , ("situationAnchor", SituationAnchorVariable)
  ]
