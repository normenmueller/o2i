{-# LANGUAGE RoleAnnotations #-}

-- | Public Core Trace boundary.
--
-- Trace results and proof values are opaque and nominal in the selected-View
-- scope that produced them. The fixed grammar is public so Operation can emit
-- stable machine projections without reconstructing Core semantics.
module O2I.Trace
  ( TraceVariable(..)
  , traceVariables
  , traceVariableId
  , TraceRelationSlot(..)
  , traceRelationSlots
  , traceRelationSlotId
  , TraceOwnershipSlot(..)
  , traceOwnershipSlots
  , traceOwnershipSlotId
  , TraceSlot(..)
  , traceSlots
  , traceSlotId
  , traceSlotRuleId
  , TraceIdentity
  , mkTraceIdentity
  , traceIdentityGraphIdentity
  , traceIdentityBindings
  , traceIdentityBinding
  , TraceIdentityBindingDefect
  , traceIdentityBindingDefectVariable
  , traceIdentityBindingDefectIdentity
  , BoundTraceIdentity
  , bindTraceIdentity
  , boundTraceIdentity
  , TraceDisposition(..)
  , TraceAssessment
  , assessTraceability
  , traceDisposition
  , traceAssessmentGraphIdentity
  , traceRootTraces
  , RootTrace
  , rootTraceGraphIdentity
  , rootTraceIntervention
  , rootTraceNeed
  , rootTraceSupport
  , RootTraceDisposition(..)
  , rootTraceDisposition
  , foldRootTrace
  , CompleteWitness
  , completeTraceIdentity
  , completeRelationSupport
  , completeOwnershipSupport
  , PartialTrace
  , partialVariableProjections
  , partialRelationSupport
  , partialOwnershipSupport
  , partialGaps
  , TraceSlotSupport
  , traceSupportSlot
  , traceSupportOccurrences
  , TraceVariableProjection
  , traceProjectionVariable
  , traceProjectionValues
  , TraceGapDisposition(..)
  , TraceGap
  , TraceGapKind(..)
  , traceGapKind
  , foldTraceGap
  , traceGapSlot
  , traceGapDisposition
  , traceGapBoundEndpoints
  , traceGapEstablishedBindings
  , traceGapUnresolvedVariables
  , traceGapObstructingSlots
  , TraceBoundEndpoints
  , traceBoundSourceVariable
  , traceBoundSourceIdentity
  , traceBoundTargetVariable
  , traceBoundTargetIdentity
  , SuppliedTraceUnavailableReason(..)
  , SuppliedTraceDisposition(..)
  , SuppliedTraceAssessment
  , SuppliedCompleteTrace
  , validateSuppliedTrace
  , suppliedTraceDisposition
  , suppliedTraceIdentity
  , suppliedTraceUnavailableReasons
  , suppliedCompleteTrace
  , suppliedCompleteIdentity
  , suppliedCompleteRelationSupport
  , suppliedCompleteOwnershipSupport
  , TracePromotionUnavailableReason(..)
  , TracePromotionDisposition(..)
  , TracePromotionAssessment
  , PromotedTraceableEffectModel
  , promoteTraceableEffectModel
  , tracePromotionDisposition
  , tracePromotionUnavailableReasons
  , promotedTraceableEffectModel
  , promotedTraceGraphIdentity
  , promotedTraceIdentity
  , promotedStrategyProofIdentity
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Semantics (SemanticallyValidModel, StrategyFormulationAssessment)
import qualified O2I.Trace.Eval as Eval
import O2I.Trace.Grammar
  ( TraceOwnershipSlot(..)
  , TraceRelationSlot(..)
  , TraceSlot(..)
  , TraceVariable(..)
  , traceOwnershipSlotId
  , traceOwnershipSlots
  , traceRelationSlotId
  , traceRelationSlots
  , traceSlotId
  , traceSlotRuleId
  , traceSlots
  , traceVariableId
  , traceVariables
  )
import O2I.Trace.Internal
  ( BoundTraceIdentity
  , CompleteWitness
  , PartialTrace
  , PromotedTraceableEffectModel
  , RootTrace
  , SuppliedCompleteTrace
  , SuppliedTraceAssessment
  , SuppliedTraceUnavailableReason(..)
  , TraceAssessment
  , TraceBoundEndpoints
  , TraceGap
  , TraceGapDisposition(..)
  , TraceIdentity
  , TraceIdentityBindingDefect
  , TracePromotionAssessment
  , TracePromotionUnavailableReason(..)
  , TraceSlotSupport
  , TraceVariableProjection
  )
import qualified O2I.Trace.Internal as Internal

-- | Construct a complete fixed Trace identity.
--
-- Returns 'Nothing' for a duplicate variable or an incomplete binding set.
mkTraceIdentity ::
     ModelIdentity -> [(TraceVariable, ModelIdentity)] -> Maybe TraceIdentity
mkTraceIdentity graph bindings
  | length bindings /= length traceVariables = Nothing
  | Map.keysSet bindingMap /= Map.keysSet completeShape = Nothing
  | otherwise = Just (Internal.TraceIdentity graph bindingMap)
  where
    bindingMap = Map.fromList bindings
    completeShape = Map.fromList [(variable, ()) | variable <- traceVariables]

-- | Project the exact selected-View identity carried by a Trace identity.
traceIdentityGraphIdentity :: TraceIdentity -> ModelIdentity
traceIdentityGraphIdentity = Internal.storedTraceGraphIdentity

-- | Project every fixed binding in companion order.
traceIdentityBindings :: TraceIdentity -> [(TraceVariable, ModelIdentity)]
traceIdentityBindings identity =
  [ (variable, Internal.traceIdentityBinding identity variable)
  | variable <- traceVariables
  ]

-- | Project one fixed variable binding.
traceIdentityBinding :: TraceIdentity -> TraceVariable -> ModelIdentity
traceIdentityBinding = Internal.traceIdentityBinding

-- | Project the unresolved fixed variable from one binding defect.
traceIdentityBindingDefectVariable ::
     TraceIdentityBindingDefect -> TraceVariable
traceIdentityBindingDefectVariable = Internal.unresolvedTraceVariable

-- | Project the unresolved model identity from one binding defect.
traceIdentityBindingDefectIdentity ::
     TraceIdentityBindingDefect -> ModelIdentity
traceIdentityBindingDefectIdentity = Internal.unresolvedTraceIdentity

-- | Resolve and qualify every fixed variable binding in this selected View.
-- The Trace graph identity remains a direct-validation concern.
bindTraceIdentity ::
     SemanticallyValidModel scope
  -> TraceIdentity
  -> Either (NonEmpty TraceIdentityBindingDefect) (BoundTraceIdentity scope)
bindTraceIdentity = Eval.bindTraceIdentityInternal

-- | Project the complete identity carried by a bound identity proof.
boundTraceIdentity :: BoundTraceIdentity scope -> TraceIdentity
boundTraceIdentity = Internal.storedBoundTraceIdentity

-- | Top-level presence of asserted Trace roots.
data TraceDisposition
  = TraceHasNoAssertedRoot
  | TraceRootsAssessed
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Evaluate every asserted root using the fixed factorized schedule.
assessTraceability :: SemanticallyValidModel scope -> TraceAssessment scope
assessTraceability = fst . Eval.assessTraceabilityInternal

-- | Classify whether an assessment contains asserted roots.
traceDisposition :: TraceAssessment scope -> TraceDisposition
traceDisposition assessment =
  case assessment of
    Internal.NoAssertedRoot _ -> TraceHasNoAssertedRoot
    Internal.AssessedRootTraces _ _ -> TraceRootsAssessed

-- | Project the exact selected-View identity of an assessment.
traceAssessmentGraphIdentity :: TraceAssessment scope -> ModelIdentity
traceAssessmentGraphIdentity assessment =
  case assessment of
    Internal.NoAssertedRoot graph -> graph
    Internal.AssessedRootTraces graph _ -> graph

-- | Project assessed roots in canonical root-binding order.
traceRootTraces :: TraceAssessment scope -> [RootTrace scope]
traceRootTraces assessment =
  case assessment of
    Internal.NoAssertedRoot _ -> []
    Internal.AssessedRootTraces _ roots -> NonEmpty.toList roots

-- | Project the selected-View identity of one root assessment.
rootTraceGraphIdentity :: RootTrace scope -> ModelIdentity
rootTraceGraphIdentity = Internal.storedRootGraphIdentity

-- | Project the asserted root's intervention identity.
rootTraceIntervention :: RootTrace scope -> ModelIdentity
rootTraceIntervention =
  Internal.storedRootIntervention . Internal.storedRootBinding

-- | Project the asserted root's need identity.
rootTraceNeed :: RootTrace scope -> ModelIdentity
rootTraceNeed = Internal.storedRootNeed . Internal.storedRootBinding

-- | Project all asserted occurrences supporting the distinct root binding.
rootTraceSupport :: RootTrace scope -> NonEmpty OccurrenceIdentity
rootTraceSupport = Internal.storedRootSupport . Internal.storedRootBinding

-- | Completeness classification of one asserted root.
data RootTraceDisposition
  = RootTraceComplete
  | RootTracePartial
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify one root as complete or partial.
rootTraceDisposition :: RootTrace scope -> RootTraceDisposition
rootTraceDisposition trace =
  case Internal.storedRootResult trace of
    Internal.CompleteTraceResult _ -> RootTraceComplete
    Internal.PartialTraceResult _ -> RootTracePartial

-- | Consume either closed result of one root assessment.
foldRootTrace ::
     (CompleteWitness scope -> result)
  -> (PartialTrace scope -> result)
  -> RootTrace scope
  -> result
foldRootTrace complete partial trace =
  case Internal.storedRootResult trace of
    Internal.CompleteTraceResult witness -> complete witness
    Internal.PartialTraceResult value -> partial value

-- | Project the canonical complete Trace identity.
completeTraceIdentity :: CompleteWitness scope -> TraceIdentity
completeTraceIdentity = Internal.storedCompleteTraceIdentity

-- | Project all 27 relation supports in fixed slot order.
completeRelationSupport :: CompleteWitness scope -> [TraceSlotSupport]
completeRelationSupport = Internal.storedCompleteRelationSupport

-- | Project all 11 ownership supports in fixed slot order.
completeOwnershipSupport :: CompleteWitness scope -> [TraceSlotSupport]
completeOwnershipSupport = Internal.storedCompleteOwnershipSupport

-- | Project exact surviving identities for every fixed variable.
partialVariableProjections :: PartialTrace scope -> [TraceVariableProjection]
partialVariableProjections = Internal.storedPartialVariableProjections

-- | Project all 27 partial relation supports in fixed slot order.
partialRelationSupport :: PartialTrace scope -> [TraceSlotSupport]
partialRelationSupport = Internal.storedPartialRelationSupport

-- | Project all 11 partial ownership supports in fixed slot order.
partialOwnershipSupport :: PartialTrace scope -> [TraceSlotSupport]
partialOwnershipSupport = Internal.storedPartialOwnershipSupport

-- | Project ordered local gaps or the global consistency obstruction.
partialGaps :: PartialTrace scope -> NonEmpty TraceGap
partialGaps = Internal.storedPartialGaps

-- | Project the fixed slot described by one support value.
traceSupportSlot :: TraceSlotSupport -> TraceSlot
traceSupportSlot = Internal.storedSupportSlot

-- | Project canonical asserted occurrence support; empty means unsupported.
traceSupportOccurrences :: TraceSlotSupport -> [OccurrenceIdentity]
traceSupportOccurrences = Internal.storedSupportOccurrences

-- | Project the fixed variable described by one partial projection.
traceProjectionVariable :: TraceVariableProjection -> TraceVariable
traceProjectionVariable = Internal.storedProjectionVariable

-- | Project canonical surviving identities for one fixed variable.
traceProjectionValues :: TraceVariableProjection -> [ModelIdentity]
traceProjectionValues = Internal.storedProjectionValues

-- | Structural shape of one gap without exposing its representation.
data TraceGapKind
  = BoundTraceSlotGap
  | UnboundTraceSlotGap
  | TraceGlobalConsistencyObstruction
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify one gap by structural shape.
traceGapKind :: TraceGap -> TraceGapKind
traceGapKind gap =
  case gap of
    Internal.BoundSlotGap _ _ _ -> BoundTraceSlotGap
    Internal.UnboundSlotGap _ _ _ _ -> UnboundTraceSlotGap
    Internal.GlobalConsistencyObstruction _ _ ->
      TraceGlobalConsistencyObstruction

-- | Consume every closed Trace gap shape.
foldTraceGap ::
     (TraceSlot -> TraceBoundEndpoints -> TraceGapDisposition -> result)
  -> (TraceSlot -> [(TraceVariable, ModelIdentity)] -> NonEmpty TraceVariable -> TraceGapDisposition -> result)
  -> (NonEmpty TraceSlot -> TraceGapDisposition -> result)
  -> TraceGap
  -> result
foldTraceGap bound unbound obstruction gap =
  case gap of
    Internal.BoundSlotGap slot endpoints disposition ->
      bound slot endpoints disposition
    Internal.UnboundSlotGap slot established unresolved disposition ->
      unbound slot established unresolved disposition
    Internal.GlobalConsistencyObstruction slots disposition ->
      obstruction slots disposition

-- | Project the affected slot when the gap is local.
traceGapSlot :: TraceGap -> Maybe TraceSlot
traceGapSlot gap =
  case gap of
    Internal.BoundSlotGap slot _ _ -> Just slot
    Internal.UnboundSlotGap slot _ _ _ -> Just slot
    Internal.GlobalConsistencyObstruction _ _ -> Nothing

-- | Project the support condition explaining one gap.
traceGapDisposition :: TraceGap -> TraceGapDisposition
traceGapDisposition gap =
  case gap of
    Internal.BoundSlotGap _ _ disposition -> disposition
    Internal.UnboundSlotGap _ _ _ disposition -> disposition
    Internal.GlobalConsistencyObstruction _ disposition -> disposition

-- | Project both endpoint bindings when the local slot is fully bound.
traceGapBoundEndpoints :: TraceGap -> Maybe TraceBoundEndpoints
traceGapBoundEndpoints gap =
  case gap of
    Internal.BoundSlotGap _ endpoints _ -> Just endpoints
    _ -> Nothing

-- | Project established bindings when a local slot remains unbound.
traceGapEstablishedBindings :: TraceGap -> [(TraceVariable, ModelIdentity)]
traceGapEstablishedBindings gap =
  case gap of
    Internal.UnboundSlotGap _ established _ _ -> established
    _ -> []

-- | Project unresolved variables when a local slot remains unbound.
traceGapUnresolvedVariables :: TraceGap -> [TraceVariable]
traceGapUnresolvedVariables gap =
  case gap of
    Internal.UnboundSlotGap _ _ unresolved _ -> NonEmpty.toList unresolved
    _ -> []

-- | Project all slots participating in a global consistency obstruction.
traceGapObstructingSlots :: TraceGap -> [TraceSlot]
traceGapObstructingSlots gap =
  case gap of
    Internal.GlobalConsistencyObstruction slots _ -> NonEmpty.toList slots
    _ -> []

-- | Project the fixed source variable of bound endpoints.
traceBoundSourceVariable :: TraceBoundEndpoints -> TraceVariable
traceBoundSourceVariable = Internal.storedSourceVariable

-- | Project the established source identity of bound endpoints.
traceBoundSourceIdentity :: TraceBoundEndpoints -> ModelIdentity
traceBoundSourceIdentity = Internal.storedSourceIdentity

-- | Project the fixed target variable of bound endpoints.
traceBoundTargetVariable :: TraceBoundEndpoints -> TraceVariable
traceBoundTargetVariable = Internal.storedTargetVariable

-- | Project the established target identity of bound endpoints.
traceBoundTargetIdentity :: TraceBoundEndpoints -> ModelIdentity
traceBoundTargetIdentity = Internal.storedTargetIdentity

-- | Completeness classification of supplied-identity validation.
data SuppliedTraceDisposition
  = SuppliedTraceRejected
  | SuppliedTraceValidated
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Validate all 38 exact asserted supports of one bound identity.
validateSuppliedTrace ::
     SemanticallyValidModel scope
  -> BoundTraceIdentity scope
  -> SuppliedTraceAssessment scope
validateSuppliedTrace = Eval.validateSuppliedTraceInternal

-- | Classify supplied-identity validation as rejected or complete.
suppliedTraceDisposition ::
     SuppliedTraceAssessment scope -> SuppliedTraceDisposition
suppliedTraceDisposition assessment =
  case assessment of
    Internal.SuppliedTraceUnavailable _ _ -> SuppliedTraceRejected
    Internal.SuppliedTraceComplete _ -> SuppliedTraceValidated

-- | Project the supplied identity from either validation result.
suppliedTraceIdentity :: SuppliedTraceAssessment scope -> TraceIdentity
suppliedTraceIdentity assessment =
  case assessment of
    Internal.SuppliedTraceUnavailable identity _ -> identity
    Internal.SuppliedTraceComplete complete ->
      Internal.storedSuppliedTraceIdentity complete

-- | Project every ordered validation failure, or the empty list on success.
suppliedTraceUnavailableReasons ::
     SuppliedTraceAssessment scope -> [SuppliedTraceUnavailableReason]
suppliedTraceUnavailableReasons assessment =
  case assessment of
    Internal.SuppliedTraceUnavailable _ reasons -> NonEmpty.toList reasons
    Internal.SuppliedTraceComplete _ -> []

-- | Project the complete proof when validation succeeded.
suppliedCompleteTrace ::
     SuppliedTraceAssessment scope -> Maybe (SuppliedCompleteTrace scope)
suppliedCompleteTrace assessment =
  case assessment of
    Internal.SuppliedTraceUnavailable _ _ -> Nothing
    Internal.SuppliedTraceComplete complete -> Just complete

-- | Project the validated complete identity.
suppliedCompleteIdentity :: SuppliedCompleteTrace scope -> TraceIdentity
suppliedCompleteIdentity = Internal.storedSuppliedTraceIdentity

-- | Project all validated relation supports in fixed slot order.
suppliedCompleteRelationSupport ::
     SuppliedCompleteTrace scope -> [TraceSlotSupport]
suppliedCompleteRelationSupport = Internal.storedSuppliedRelationSupport

-- | Project all validated ownership supports in fixed slot order.
suppliedCompleteOwnershipSupport ::
     SuppliedCompleteTrace scope -> [TraceSlotSupport]
suppliedCompleteOwnershipSupport = Internal.storedSuppliedOwnershipSupport

-- | Success classification of Trace-to-strategy proof promotion.
data TracePromotionDisposition
  = TracePromotionRejected
  | TracePromotionAccepted
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Join a supplied complete Trace with a matching valid strategy proof.
promoteTraceableEffectModel ::
     SemanticallyValidModel scope
  -> StrategyFormulationAssessment scope
  -> SuppliedCompleteTrace scope
  -> TracePromotionAssessment scope
promoteTraceableEffectModel = Eval.promoteTraceInternal

-- | Classify promotion as rejected or accepted.
tracePromotionDisposition ::
     TracePromotionAssessment scope -> TracePromotionDisposition
tracePromotionDisposition assessment =
  case assessment of
    Internal.TracePromotionUnavailable _ _ _ -> TracePromotionRejected
    Internal.TracePromotionSucceeded _ -> TracePromotionAccepted

-- | Project every failed promotion premise, or the empty list on success.
tracePromotionUnavailableReasons ::
     TracePromotionAssessment scope -> [TracePromotionUnavailableReason]
tracePromotionUnavailableReasons assessment =
  case assessment of
    Internal.TracePromotionUnavailable _ _ reasons -> NonEmpty.toList reasons
    Internal.TracePromotionSucceeded _ -> []

-- | Project the promoted proof when every premise holds.
promotedTraceableEffectModel ::
     TracePromotionAssessment scope
  -> Maybe (PromotedTraceableEffectModel scope)
promotedTraceableEffectModel assessment =
  case assessment of
    Internal.TracePromotionUnavailable _ _ _ -> Nothing
    Internal.TracePromotionSucceeded proof -> Just proof

-- | Project the selected-View identity carried by a promoted proof.
promotedTraceGraphIdentity ::
     PromotedTraceableEffectModel scope -> ModelIdentity
promotedTraceGraphIdentity = Internal.storedPromotedGraphIdentity

-- | Project the complete Trace identity carried by a promoted proof.
promotedTraceIdentity :: PromotedTraceableEffectModel scope -> TraceIdentity
promotedTraceIdentity = Internal.storedPromotedTraceIdentity

-- | Project the strategy formulation proof identity joined by promotion.
promotedStrategyProofIdentity ::
     PromotedTraceableEffectModel scope -> ModelIdentity
promotedStrategyProofIdentity = Internal.storedPromotedStrategyProofIdentity
