{-# LANGUAGE RoleAnnotations #-}

-- | Private result algebra of Core effect tracing.
module O2I.Trace.Internal
  ( TraceIdentity(..)
  , traceIdentityValue
  , traceIdentityBinding
  , TraceIdentityBindingDefect(..)
  , BoundTraceIdentity(..)
  , TraceRootBinding(..)
  , TraceSlotSupport(..)
  , TraceVariableProjection(..)
  , TraceBoundEndpoints(..)
  , TraceGapDisposition(..)
  , TraceGap(..)
  , CompleteWitness(..)
  , PartialTrace(..)
  , RootTraceResult(..)
  , RootTrace(..)
  , TraceAssessment(..)
  , SuppliedTraceUnavailableReason(..)
  , SuppliedCompleteTrace(..)
  , SuppliedTraceAssessment(..)
  , TracePromotionUnavailableReason(..)
  , PromotedTraceableEffectModel(..)
  , TracePromotionAssessment(..)
  , TraceWork(..)
  , emptyTraceWork
  , addTraceWork
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Trace.Grammar (TraceSlot, TraceVariable)

-- | Exact graph identity and complete fixed variable binding.
data TraceIdentity = TraceIdentity
  { storedTraceGraphIdentity :: !ModelIdentity
  , storedTraceBindings :: !(Map TraceVariable ModelIdentity)
  } deriving (Eq, Ord, Show)

traceIdentityValue ::
     ModelIdentity -> [(TraceVariable, ModelIdentity)] -> TraceIdentity
traceIdentityValue graph = TraceIdentity graph . Map.fromList

traceIdentityBinding :: TraceIdentity -> TraceVariable -> ModelIdentity
traceIdentityBinding identity variable =
  storedTraceBindings identity Map.! variable

-- | One fixed variable identity that does not resolve at its required endpoint.
data TraceIdentityBindingDefect = TraceIdentityVariableUnresolved
  { unresolvedTraceVariable :: !TraceVariable
  , unresolvedTraceIdentity :: !ModelIdentity
  } deriving (Eq, Ord, Show)

type role BoundTraceIdentity nominal

-- | Opaque proof that every variable identity resolves at its required
-- qualified endpoint in one selected View.
newtype BoundTraceIdentity scope = BoundTraceIdentity
  { storedBoundTraceIdentity :: TraceIdentity
  } deriving (Eq, Show)

data TraceRootBinding = TraceRootBinding
  { storedRootIntervention :: !ModelIdentity
  , storedRootNeed :: !ModelIdentity
  , storedRootSupport :: !(NonEmpty OccurrenceIdentity)
  , storedRootInterventionRank :: !Int
  , storedRootNeedRank :: !Int
  } deriving (Eq, Show)

-- | Canonically ordered asserted occurrences supporting one fixed slot.
data TraceSlotSupport = TraceSlotSupport
  { storedSupportSlot :: !TraceSlot
  , storedSupportOccurrences :: ![OccurrenceIdentity]
  } deriving (Eq, Show)

-- | Exact surviving identities for one variable of a partial Trace.
data TraceVariableProjection = TraceVariableProjection
  { storedProjectionVariable :: !TraceVariable
  , storedProjectionValues :: ![ModelIdentity]
  } deriving (Eq, Show)

-- | Both established endpoint bindings of one fixed slot.
data TraceBoundEndpoints = TraceBoundEndpoints
  { storedSourceVariable :: !TraceVariable
  , storedSourceIdentity :: !ModelIdentity
  , storedTargetVariable :: !TraceVariable
  , storedTargetIdentity :: !ModelIdentity
  } deriving (Eq, Ord, Show)

-- | Support condition that explains one Trace gap.
data TraceGapDisposition
  = MissingSupport
  | CandidateOnlySupport
  | GloballyInconsistentSupport
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One local or global obstruction to a complete Trace witness.
data TraceGap
  = BoundSlotGap !TraceSlot !TraceBoundEndpoints !TraceGapDisposition
  | UnboundSlotGap
      !TraceSlot
      ![(TraceVariable, ModelIdentity)]
      !(NonEmpty TraceVariable)
      !TraceGapDisposition
  | GlobalConsistencyObstruction !(NonEmpty TraceSlot) !TraceGapDisposition
  deriving (Eq, Show)

type role CompleteWitness nominal

-- | Opaque complete witness and its exact occurrence support.
data CompleteWitness scope = CompleteWitness
  { storedCompleteTraceIdentity :: !TraceIdentity
  , storedCompleteRelationSupport :: ![TraceSlotSupport]
  , storedCompleteOwnershipSupport :: ![TraceSlotSupport]
  } deriving (Eq, Show)

type role PartialTrace nominal

-- | Opaque maximal projections, support, and gaps for an incomplete root.
data PartialTrace scope = PartialTrace
  { storedPartialVariableProjections :: ![TraceVariableProjection]
  , storedPartialRelationSupport :: ![TraceSlotSupport]
  , storedPartialOwnershipSupport :: ![TraceSlotSupport]
  , storedPartialGaps :: !(NonEmpty TraceGap)
  } deriving (Eq, Show)

type role RootTraceResult nominal

data RootTraceResult scope
  = CompleteTraceResult !(CompleteWitness scope)
  | PartialTraceResult !(PartialTrace scope)
  deriving (Eq, Show)

type role RootTrace nominal

-- | Opaque assessment of one distinct asserted root binding.
data RootTrace scope = RootTrace
  { storedRootGraphIdentity :: !ModelIdentity
  , storedRootBinding :: !TraceRootBinding
  , storedRootResult :: !(RootTraceResult scope)
  } deriving (Eq, Show)

type role TraceAssessment nominal

-- | Opaque selected-View assessment of every asserted Trace root.
data TraceAssessment scope
  = NoAssertedRoot !ModelIdentity
  | AssessedRootTraces !ModelIdentity !(NonEmpty (RootTrace scope))
  deriving (Eq, Show)

-- | Exact reason why a supplied complete identity cannot be validated.
data SuppliedTraceUnavailableReason
  = TraceGraphIdentityMismatch !ModelIdentity !ModelIdentity
  | ExactSlotUnsupported !TraceSlot !TraceBoundEndpoints !TraceGapDisposition
  deriving (Eq, Show)

type role SuppliedCompleteTrace nominal

-- | Opaque proof that every slot of a supplied identity has asserted support.
data SuppliedCompleteTrace scope = SuppliedCompleteTrace
  { storedSuppliedTraceIdentity :: !TraceIdentity
  , storedSuppliedRelationSupport :: ![TraceSlotSupport]
  , storedSuppliedOwnershipSupport :: ![TraceSlotSupport]
  } deriving (Eq, Show)

type role SuppliedTraceAssessment nominal

-- | Closed validation result for a directly supplied complete identity.
data SuppliedTraceAssessment scope
  = SuppliedTraceUnavailable
      !TraceIdentity
      !(NonEmpty SuppliedTraceUnavailableReason)
  | SuppliedTraceComplete !(SuppliedCompleteTrace scope)
  deriving (Eq, Show)

-- | Exact failed premise of Trace-to-strategy proof promotion.
data TracePromotionUnavailableReason
  = StrategyAssessmentUnavailable
  | StrategyAssessmentInvalid
  | StrategyProofModelMismatch
  | StrategyIdentityMismatch
  | StrategyDiagnosisMismatch
  | StrategyIntentMismatch
  | StrategyActionNotInFormulation
  | StrategyKeyResultNotInFormulation
  deriving (Bounded, Enum, Eq, Ord, Show)

type role PromotedTraceableEffectModel nominal

-- | Opaque proof joining a supplied complete Trace with strategy validity.
data PromotedTraceableEffectModel scope = PromotedTraceableEffectModel
  { storedPromotedGraphIdentity :: !ModelIdentity
  , storedPromotedTraceIdentity :: !TraceIdentity
  , storedPromotedStrategyProofIdentity :: !ModelIdentity
  } deriving (Eq, Show)

type role TracePromotionAssessment nominal

-- | Closed result of Trace-to-strategy proof promotion.
data TracePromotionAssessment scope
  = TracePromotionUnavailable
      !ModelIdentity
      !TraceIdentity
      !(NonEmpty TracePromotionUnavailableReason)
  | TracePromotionSucceeded !(PromotedTraceableEffectModel scope)
  deriving (Eq, Show)

-- | Exact private counter evidence for focused asymptotic tests.
--
-- Each consistency run traverses the 38 fixed slots. Bindings visited
-- count @sum |F_(k-1)|@, bucket occurrences count the complete occurrence
-- multiplicity @sum |H(k,b)|@, and peak pair is
-- @max (|F_(k-1)| + |F_k|)@. Totals cover the constant family of the primary,
-- distinguished-variable, and Candidate-only passes; peak pair takes their
-- maximum. Preparation scalar steps count Unicode scalars actually visited by
-- ordered identity comparisons in @W_p@. Preparation fixed-word steps and the
-- two trie counters charge bounded-depth @IntMap@ addressing, frontier
-- traversal, and compaction; their depth is the machine-word width and
-- therefore constant.
-- Input visits and direct supplied-Trace lookups remain separate.
data TraceWork = TraceWork
  { traceCarrierVisits :: !Int
  , traceRelationVisits :: !Int
  , traceOwnershipVisits :: !Int
  , traceRootCount :: !Int
  , traceConsistencyRuns :: !Int
  , traceFrontierStageVisits :: !Int
  , traceFrontierBindingsVisited :: !Int
  , traceSupportBucketOccurrences :: !Int
  , traceFrontierBindingsEmitted :: !Int
  , traceFrontierPeakPair :: !Int
  , tracePreparationIdentityScalarSteps :: !Int
  , tracePreparationFixedWordSteps :: !Int
  , traceAddressTrieSteps :: !Int
  , traceFrontierKeyTrieSteps :: !Int
  , traceFrontierHistoryCellComparisons :: !Int
  , traceDirectSupportLookups :: !Int
  } deriving (Eq, Show)

emptyTraceWork :: TraceWork
emptyTraceWork = TraceWork 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

addTraceWork :: TraceWork -> TraceWork -> TraceWork
addTraceWork left right =
  TraceWork
    { traceCarrierVisits = traceCarrierVisits left + traceCarrierVisits right
    , traceRelationVisits = traceRelationVisits left + traceRelationVisits right
    , traceOwnershipVisits =
        traceOwnershipVisits left + traceOwnershipVisits right
    , traceRootCount = traceRootCount left + traceRootCount right
    , traceConsistencyRuns =
        traceConsistencyRuns left + traceConsistencyRuns right
    , traceFrontierStageVisits =
        traceFrontierStageVisits left + traceFrontierStageVisits right
    , traceFrontierBindingsVisited =
        traceFrontierBindingsVisited left + traceFrontierBindingsVisited right
    , traceSupportBucketOccurrences =
        traceSupportBucketOccurrences left + traceSupportBucketOccurrences right
    , traceFrontierBindingsEmitted =
        traceFrontierBindingsEmitted left + traceFrontierBindingsEmitted right
    , traceFrontierPeakPair =
        max (traceFrontierPeakPair left) (traceFrontierPeakPair right)
    , tracePreparationIdentityScalarSteps =
        tracePreparationIdentityScalarSteps left
          + tracePreparationIdentityScalarSteps right
    , tracePreparationFixedWordSteps =
        tracePreparationFixedWordSteps left
          + tracePreparationFixedWordSteps right
    , traceAddressTrieSteps =
        traceAddressTrieSteps left + traceAddressTrieSteps right
    , traceFrontierKeyTrieSteps =
        traceFrontierKeyTrieSteps left + traceFrontierKeyTrieSteps right
    , traceFrontierHistoryCellComparisons =
        traceFrontierHistoryCellComparisons left
          + traceFrontierHistoryCellComparisons right
    , traceDirectSupportLookups =
        traceDirectSupportLookups left + traceDirectSupportLookups right
    }
