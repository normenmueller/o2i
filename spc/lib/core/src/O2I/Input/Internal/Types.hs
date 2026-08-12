{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Closed values and defects of Core-owned supplemental input.
module O2I.Input.Internal.Types
  ( SupplementalInputOrdinal(..)
  , supplementalInputOrdinalValue
  , SupplementalPayloadType(..)
  , FachlicheText(..)
  , StrategyAnchoring(..)
  , StrategyFormulationInput(..)
  , PairwiseCoherence(..)
  , ParticipantCompatibility(..)
  , CollectiveFitInput(..)
  , SupplementalInput(..)
  , supplementalInputOrdinalOf
  , supplementalInputType
  , supplementalInputSubject
  , SupplementalInputSet(..)
  , SupplementalBinding(..)
  , BoundSupplementalInputs(..)
  , supplementalIdentitySiteResolved
  , SupplementalInputDefectKind(..)
  , SupplementalInputEvidence(..)
  , SupplementalInputDefect(..)
  , supplementalInputDefectRule
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity (ModelIdentity)
import O2I.Input.Internal.Text (CanonicalFachlicheText)

-- | Stable zero-based ordinal assigned by the Operation boundary.
newtype SupplementalInputOrdinal =
  SupplementalInputOrdinal Natural
  deriving (Eq, Ord, Show)

-- | Project the stable zero-based ordinal.
supplementalInputOrdinalValue :: SupplementalInputOrdinal -> Natural
supplementalInputOrdinalValue (SupplementalInputOrdinal value) = value

-- | Closed supplemental payload discriminator.
data SupplementalPayloadType
  = StrategyFormulationPayload
  | CollectiveFitPayload
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Canonical fachliche text admitted by the supplemental-input contract.
newtype FachlicheText =
  FachlicheText CanonicalFachlicheText
  deriving (Eq, Ord, Show)

-- | Complete organizational anchoring supplied for one Strategy.
data StrategyAnchoring = StrategyAnchoring
  { strategyAnchoringPeriod :: !FachlicheText
  , strategyAnchoringResponsibilityScope :: !FachlicheText
  , strategyAnchoringDecisionLevel :: !FachlicheText
  , strategyAnchoringResponsibilities :: !(NonEmpty FachlicheText)
  , strategyAnchoringDecisionPaths :: !(NonEmpty FachlicheText)
  , strategyAnchoringImplementationLogic :: !FachlicheText
  } deriving (Eq, Ord, Show)

-- | Canonical complete supplemental formulation of one Strategy.
data StrategyFormulationInput = StrategyFormulationInput
  { formulationStrategy :: !ModelIdentity
  , formulationScope :: !(NonEmpty FachlicheText)
  , formulationAnchoring :: !StrategyAnchoring
  , formulationDerivedGuardrails :: !(NonEmpty FachlicheText)
  , formulationDiagnosis :: !ModelIdentity
  , formulationIntent :: !ModelIdentity
  , formulationGuidingPolicy :: !ModelIdentity
  , formulationPositioning :: !(NonEmpty FachlicheText)
  , formulationTradeOffs :: !(NonEmpty FachlicheText)
  , formulationActions :: !(NonEmpty ModelIdentity)
  , formulationKeyResults :: !(NonEmpty ModelIdentity)
  , formulationFitRationale :: !(NonEmpty FachlicheText)
  } deriving (Eq, Ord, Show)

-- | One supplied coherence rationale for an unordered participant pair.
data PairwiseCoherence = PairwiseCoherence
  { pairwiseParticipantA :: !ModelIdentity
  , pairwiseParticipantB :: !ModelIdentity
  , pairwiseRationale :: !FachlicheText
  } deriving (Eq, Ord, Show)

-- | One participant's compatibility with the target formulation.
data ParticipantCompatibility = ParticipantCompatibility
  { compatibilityParticipant :: !ModelIdentity
  , compatibilityGuidingPolicyRationale :: !FachlicheText
  , compatibilityTradeOffRationale :: !FachlicheText
  } deriving (Eq, Ord, Show)

-- | Canonical collective-Fit input for one structured proposition.
data CollectiveFitInput = CollectiveFitInput
  { collectiveClaim :: !ModelIdentity
  , collectiveParticipants :: !(NonEmpty ModelIdentity)
  , collectiveTarget :: !ModelIdentity
  , collectiveTargetGuidingPolicy :: !ModelIdentity
  , collectiveTargetTradeOffs :: !(NonEmpty FachlicheText)
  , collectivePairwiseCoherence :: !(NonEmpty PairwiseCoherence)
  , collectiveParticipantCompatibility :: !(NonEmpty ParticipantCompatibility)
  , collectiveContributionInteraction :: !(NonEmpty FachlicheText)
  } deriving (Eq, Ord, Show)

-- | One individually decoded and canonicalized supplemental payload.
data SupplementalInput
  = StrategyFormulationSupplement
      !SupplementalInputOrdinal
      !StrategyFormulationInput
  | CollectiveFitSupplement !SupplementalInputOrdinal !CollectiveFitInput
  deriving (Eq, Show)

-- | Project the Operation-assigned input ordinal.
supplementalInputOrdinalOf :: SupplementalInput -> SupplementalInputOrdinal
supplementalInputOrdinalOf input =
  case input of
    StrategyFormulationSupplement ordinal _ -> ordinal
    CollectiveFitSupplement ordinal _ -> ordinal

-- | Project the closed payload type.
supplementalInputType :: SupplementalInput -> SupplementalPayloadType
supplementalInputType input =
  case input of
    StrategyFormulationSupplement _ _ -> StrategyFormulationPayload
    CollectiveFitSupplement _ _ -> CollectiveFitPayload

-- | Project the exact subject identity used by set uniqueness and binding.
supplementalInputSubject :: SupplementalInput -> ModelIdentity
supplementalInputSubject input =
  case input of
    StrategyFormulationSupplement _ formulation ->
      formulationStrategy formulation
    CollectiveFitSupplement _ collective -> collectiveClaim collective

-- | Canonically ordered payloads proven unique by type and subject identity.
newtype SupplementalInputSet =
  SupplementalInputSet [SupplementalInput]
  deriving (Eq, Show)

type role BoundSupplementalInputs nominal

type role SupplementalBinding nominal

-- | Complete identity-binding outcome for one selected-View graph.
data SupplementalBinding scope = SupplementalBinding
  { supplementalBindingInputs :: !(BoundSupplementalInputs scope)
  , supplementalBindingDefects :: ![SupplementalInputDefect]
  } deriving (Eq, Show)

-- | Opaque payload set with exact resolution state for every identity site.
data BoundSupplementalInputs scope = BoundSupplementalInputs
  { boundSupplementalInputSet :: !SupplementalInputSet
  , unresolvedSupplementalIdentitySites :: !(Set SupplementalInputEvidence)
  } deriving (Eq, Show)

-- | Report whether one exact identity site resolved in the selected View.
supplementalIdentitySiteResolved ::
     BoundSupplementalInputs scope
  -> SupplementalInputOrdinal
  -> Text
  -> ModelIdentity
  -> Bool
supplementalIdentitySiteResolved inputs ordinal pointer identifier =
  Set.notMember
    (SupplementalIdentityKey ordinal pointer identifier)
    (unresolvedSupplementalIdentitySites inputs)

-- | Closed failure kind of supplemental decoding, schema, and set assessment.
data SupplementalInputDefectKind
  = SupplementalInvalidUtf8
  | SupplementalInvalidJsonSyntax
  | SupplementalDuplicateObjectMember
  | SupplementalTopLevelObjectRequired
  | SupplementalTypeMemberInvalid
  | SupplementalPayloadTypeNotAdmitted
  | SupplementalRequiredMemberMissing
  | SupplementalUnknownMember
  | SupplementalValueKindInvalid
  | SupplementalScalarGrammarInvalid
  | SupplementalArrayCardinalityInvalid
  | SupplementalArrayDistinctnessInvalid
  | SupplementalSubjectCardinalityInvalid
  | SupplementalIdentityUnknown
  | SupplementalIdentityAmbiguous
  | SupplementalIdentityWrongType
  | SupplementalIdentityOutOfSelectedView
  | SupplementalModelIdentityUnicodeScalarInvalid
  | SupplementalModelIdentityContainsNul
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact rule-bound evidence key of one supplemental-input defect.
data SupplementalInputEvidence
  = SupplementalInputKey !SupplementalInputOrdinal
  | SupplementalMemberKey !SupplementalInputOrdinal !Text
  | SupplementalSchemaKey !SupplementalInputOrdinal !Text !Text
  | SupplementalSubjectKey
      !SupplementalPayloadType
      !ModelIdentity
      !(NonEmpty SupplementalInputOrdinal)
  | SupplementalIdentityKey !SupplementalInputOrdinal !Text !ModelIdentity
  deriving (Eq, Ord, Show)

-- | One deterministic supplemental-input defect.
data SupplementalInputDefect = SupplementalInputDefect
  { supplementalInputDefectKind :: !SupplementalInputDefectKind
  , supplementalInputDefectEvidence :: !SupplementalInputEvidence
  } deriving (Eq, Ord, Show)

-- | Project the exact Core rule owned by a closed defect kind.
supplementalInputDefectRule :: SupplementalInputDefect -> CoreRuleId
supplementalInputDefectRule =
  CoreRuleId . defectRuleText . supplementalInputDefectKind

defectRuleText :: SupplementalInputDefectKind -> Text
defectRuleText kind =
  case kind of
    SupplementalInvalidUtf8 -> "core.supplemental.decode.utf8"
    SupplementalInvalidJsonSyntax -> "core.supplemental.decode.json-syntax"
    SupplementalDuplicateObjectMember ->
      "core.supplemental.decode.duplicate-member"
    SupplementalTopLevelObjectRequired ->
      "core.supplemental.schema.top-level-object"
    SupplementalTypeMemberInvalid -> "core.supplemental.schema.type-member"
    SupplementalPayloadTypeNotAdmitted ->
      "core.supplemental.schema.admitted-type"
    SupplementalRequiredMemberMissing ->
      "core.supplemental.schema.required-member"
    SupplementalUnknownMember -> "core.supplemental.schema.unknown-member"
    SupplementalValueKindInvalid -> "core.supplemental.schema.value-kind"
    SupplementalScalarGrammarInvalid ->
      "core.supplemental.schema.scalar-grammar"
    SupplementalArrayCardinalityInvalid ->
      "core.supplemental.schema.array-cardinality"
    SupplementalArrayDistinctnessInvalid ->
      "core.supplemental.schema.array-distinctness"
    SupplementalSubjectCardinalityInvalid ->
      "core.supplemental.subject.cardinality"
    SupplementalIdentityUnknown -> "core.supplemental.identity.unknown"
    SupplementalIdentityAmbiguous -> "core.supplemental.identity.ambiguous"
    SupplementalIdentityWrongType -> "core.supplemental.identity.wrong-type"
    SupplementalIdentityOutOfSelectedView ->
      "core.supplemental.identity.out-of-selected-view"
    SupplementalModelIdentityUnicodeScalarInvalid ->
      "core.supplemental.schema.model-identity.unicode-scalar"
    SupplementalModelIdentityContainsNul ->
      "core.supplemental.schema.model-identity.nul"
