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
  , SupplementalIdentitySite(..)
  , supplementalIdentitySiteResolved
  , SupplementalInputDefectKind(..)
  , SupplementalInputDefect(..)
  , SupplementalUnicodeScalarOccurrence(..)
  , SupplementalInvalidUtf8Evidence(..)
  , SupplementalInvalidJsonSyntaxEvidence(..)
  , SupplementalDuplicateObjectMemberEvidence(..)
  , SupplementalTopLevelObjectRequiredEvidence(..)
  , SupplementalTypeMemberInvalidEvidence(..)
  , SupplementalPayloadTypeNotAdmittedEvidence(..)
  , SupplementalRequiredMemberMissingEvidence(..)
  , SupplementalUnknownMemberEvidence(..)
  , SupplementalValueKindInvalidEvidence(..)
  , SupplementalScalarGrammarInvalidEvidence(..)
  , SupplementalArrayCardinalityInvalidEvidence(..)
  , SupplementalArrayDistinctnessInvalidEvidence(..)
  , SupplementalSubjectCardinalityInvalidEvidence(..)
  , SupplementalIdentityUnknownEvidence(..)
  , SupplementalIdentityAmbiguousEvidence(..)
  , SupplementalIdentityWrongTypeEvidence(..)
  , SupplementalIdentityOutOfSelectedViewEvidence(..)
  , SupplementalModelIdentityUnicodeScalarInvalidEvidence(..)
  , SupplementalModelIdentityContainsNulEvidence(..)
  , supplementalInputDefectRule
  , SupplementalInputDefectEliminator(..)
  , foldSupplementalInputDefect
  , supplementalInputDefectKind
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreRuleId)
import qualified O2I.Core.Contract.Generated as Generated
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
    -- | Inputs retained with identity-resolution state.
  { supplementalBindingInputs :: !(BoundSupplementalInputs scope)
    -- | Deterministically ordered identity-binding defects.
  , supplementalBindingDefects :: ![SupplementalInputDefect]
  } deriving (Eq, Show)

-- | Opaque payload set with exact resolution state for every identity site.
data BoundSupplementalInputs scope = BoundSupplementalInputs
  { boundSupplementalInputSet :: !SupplementalInputSet
  , unresolvedSupplementalIdentitySites :: !(Set SupplementalIdentitySite)
  } deriving (Eq, Show)

-- | One exact unresolved identity site retained only inside Core.
data SupplementalIdentitySite =
  SupplementalIdentitySite !SupplementalInputOrdinal !Text !ModelIdentity
  deriving (Eq, Ord, Show)

-- | Report whether one exact identity site resolved in the selected View.
supplementalIdentitySiteResolved ::
     BoundSupplementalInputs scope
  -> SupplementalInputOrdinal
  -> Text
  -> ModelIdentity
  -> Bool
supplementalIdentitySiteResolved inputs ordinal pointer identifier =
  Set.notMember
    (SupplementalIdentitySite ordinal pointer identifier)
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

-- | Exact invalid Unicode code point retained at its decoded scalar index.
data SupplementalUnicodeScalarOccurrence = SupplementalUnicodeScalarOccurrence
  { supplementalUnicodeScalarIndex :: !Natural
  , supplementalUnicodeScalarCodePoint :: !Natural
  } deriving (Eq, Ord, Show)

-- | Evidence that exact input bytes are not UTF-8.
newtype SupplementalInvalidUtf8Evidence =
  SupplementalInvalidUtf8Evidence SupplementalInputOrdinal
  deriving (Eq, Ord, Show)

-- | Evidence that one UTF-8 input is not exactly one JSON value.
newtype SupplementalInvalidJsonSyntaxEvidence =
  SupplementalInvalidJsonSyntaxEvidence SupplementalInputOrdinal
  deriving (Eq, Ord, Show)

-- | Evidence that an object member repeats at one instance location.
data SupplementalDuplicateObjectMemberEvidence =
  SupplementalDuplicateObjectMemberEvidence !SupplementalInputOrdinal !Text
  deriving (Eq, Ord, Show)

-- | Evidence that the input root is not an object.
data SupplementalTopLevelObjectRequiredEvidence =
  SupplementalTopLevelObjectRequiredEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
  deriving (Eq, Ord, Show)

-- | Evidence that the payload discriminator member is invalid.
data SupplementalTypeMemberInvalidEvidence =
  SupplementalTypeMemberInvalidEvidence !SupplementalInputOrdinal !Text !Text
  deriving (Eq, Ord, Show)

-- | Evidence that a discriminator names no admitted payload type.
data SupplementalPayloadTypeNotAdmittedEvidence =
  SupplementalPayloadTypeNotAdmittedEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
  deriving (Eq, Ord, Show)

-- | Evidence that one schema-required member is absent.
data SupplementalRequiredMemberMissingEvidence =
  SupplementalRequiredMemberMissingEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
  deriving (Eq, Ord, Show)

-- | Evidence that one object member is outside the closed schema.
data SupplementalUnknownMemberEvidence =
  SupplementalUnknownMemberEvidence !SupplementalInputOrdinal !Text !Text
  deriving (Eq, Ord, Show)

-- | Evidence that a value has the wrong JSON kind.
data SupplementalValueKindInvalidEvidence =
  SupplementalValueKindInvalidEvidence !SupplementalInputOrdinal !Text !Text
  deriving (Eq, Ord, Show)

-- | Evidence that a scalar violates its closed grammar.
data SupplementalScalarGrammarInvalidEvidence =
  SupplementalScalarGrammarInvalidEvidence !SupplementalInputOrdinal !Text !Text
  deriving (Eq, Ord, Show)

-- | Evidence that an array violates its required cardinality.
data SupplementalArrayCardinalityInvalidEvidence =
  SupplementalArrayCardinalityInvalidEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
  deriving (Eq, Ord, Show)

-- | Evidence that canonical array members are not distinct.
data SupplementalArrayDistinctnessInvalidEvidence =
  SupplementalArrayDistinctnessInvalidEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
  deriving (Eq, Ord, Show)

-- | Constructive evidence of at least two inputs for one payload subject.
data SupplementalSubjectCardinalityInvalidEvidence =
  SupplementalSubjectCardinalityInvalidEvidence
    !SupplementalPayloadType
    !ModelIdentity
    !SupplementalInputOrdinal
    !(NonEmpty SupplementalInputOrdinal)
  deriving (Eq, Ord, Show)

-- | Evidence that one identity site has no model-wide occurrence.
data SupplementalIdentityUnknownEvidence =
  SupplementalIdentityUnknownEvidence
    !SupplementalInputOrdinal
    !Text
    !ModelIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that one identity site has multiple model-wide occurrences.
data SupplementalIdentityAmbiguousEvidence =
  SupplementalIdentityAmbiguousEvidence
    !SupplementalInputOrdinal
    !Text
    !ModelIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that one resolved site has the wrong qualified type.
data SupplementalIdentityWrongTypeEvidence =
  SupplementalIdentityWrongTypeEvidence
    !SupplementalInputOrdinal
    !Text
    !ModelIdentity
  deriving (Eq, Ord, Show)

-- | Evidence that one unique identity lies outside the selected View.
data SupplementalIdentityOutOfSelectedViewEvidence =
  SupplementalIdentityOutOfSelectedViewEvidence
    !SupplementalInputOrdinal
    !Text
    !ModelIdentity
  deriving (Eq, Ord, Show)

-- | Evidence of malformed surrogate code points in a ModelIdentity string.
data SupplementalModelIdentityUnicodeScalarInvalidEvidence =
  SupplementalModelIdentityUnicodeScalarInvalidEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
    !(NonEmpty SupplementalUnicodeScalarOccurrence)
  deriving (Eq, Ord, Show)

-- | Evidence of one or more NUL scalars in a ModelIdentity string.
data SupplementalModelIdentityContainsNulEvidence =
  SupplementalModelIdentityContainsNulEvidence
    !SupplementalInputOrdinal
    !Text
    !Text
    !(NonEmpty Natural)
  deriving (Eq, Ord, Show)

-- | Closed rule-specific supplemental-input defect algebra.
--
-- Constructors are private at the public module boundary. Every constructor
-- carries exactly its rule's stable evidence key and separates any diagnostic
-- detail that does not participate in defect identity.
data SupplementalInputDefect
  = SupplementalInvalidUtf8Defect !SupplementalInputOrdinal
  | SupplementalInvalidJsonSyntaxDefect !SupplementalInputOrdinal
  | SupplementalDuplicateObjectMemberDefect !SupplementalInputOrdinal !Text
  | SupplementalTopLevelObjectRequiredDefect
      !SupplementalInputOrdinal
      !Text
      !Text
  | SupplementalTypeMemberInvalidDefect !SupplementalInputOrdinal !Text !Text
  | SupplementalPayloadTypeNotAdmittedDefect
      !SupplementalInputOrdinal
      !Text
      !Text
  | SupplementalRequiredMemberMissingDefect
      !SupplementalInputOrdinal
      !Text
      !Text
  | SupplementalUnknownMemberDefect !SupplementalInputOrdinal !Text !Text
  | SupplementalValueKindInvalidDefect !SupplementalInputOrdinal !Text !Text
  | SupplementalScalarGrammarInvalidDefect !SupplementalInputOrdinal !Text !Text
  | SupplementalArrayCardinalityInvalidDefect
      !SupplementalInputOrdinal
      !Text
      !Text
  | SupplementalArrayDistinctnessInvalidDefect
      !SupplementalInputOrdinal
      !Text
      !Text
  | SupplementalSubjectCardinalityInvalidDefect
      !SupplementalPayloadType
      !ModelIdentity
      !SupplementalInputOrdinal
      !(NonEmpty SupplementalInputOrdinal)
  | SupplementalIdentityUnknownDefect
      !SupplementalInputOrdinal
      !Text
      !ModelIdentity
  | SupplementalIdentityAmbiguousDefect
      !SupplementalInputOrdinal
      !Text
      !ModelIdentity
  | SupplementalIdentityWrongTypeDefect
      !SupplementalInputOrdinal
      !Text
      !ModelIdentity
  | SupplementalIdentityOutOfSelectedViewDefect
      !SupplementalInputOrdinal
      !Text
      !ModelIdentity
  | SupplementalModelIdentityUnicodeScalarInvalidDefect
      !SupplementalInputOrdinal
      !Text
      !Text
      !(NonEmpty SupplementalUnicodeScalarOccurrence)
  | SupplementalModelIdentityContainsNulDefect
      !SupplementalInputOrdinal
      !Text
      !Text
      !(NonEmpty Natural)
  deriving (Show)

-- | Project the exact Core-owned rule identity of one supplemental defect.
supplementalInputDefectRule :: SupplementalInputDefect -> CoreRuleId
supplementalInputDefectRule defect =
  CoreRuleId
    (Generated.generatedSupplementalRuleIdentityText
       (supplementalInputDefectRuleIdentity defect))

supplementalInputDefectRuleIdentity ::
     SupplementalInputDefect -> Generated.GeneratedSupplementalRuleIdentity
supplementalInputDefectRuleIdentity defect =
  case defect of
    SupplementalInvalidUtf8Defect _ ->
      Generated.GeneratedSupplementalUtf8RuleIdentity
    SupplementalInvalidJsonSyntaxDefect _ ->
      Generated.GeneratedSupplementalJsonSyntaxRuleIdentity
    SupplementalDuplicateObjectMemberDefect _ _ ->
      Generated.GeneratedSupplementalDuplicateMemberRuleIdentity
    SupplementalTopLevelObjectRequiredDefect _ _ _ ->
      Generated.GeneratedSupplementalTopLevelObjectRuleIdentity
    SupplementalTypeMemberInvalidDefect _ _ _ ->
      Generated.GeneratedSupplementalTypeMemberRuleIdentity
    SupplementalPayloadTypeNotAdmittedDefect _ _ _ ->
      Generated.GeneratedSupplementalAdmittedTypeRuleIdentity
    SupplementalRequiredMemberMissingDefect _ _ _ ->
      Generated.GeneratedSupplementalRequiredMemberRuleIdentity
    SupplementalUnknownMemberDefect _ _ _ ->
      Generated.GeneratedSupplementalUnknownMemberRuleIdentity
    SupplementalValueKindInvalidDefect _ _ _ ->
      Generated.GeneratedSupplementalValueKindRuleIdentity
    SupplementalScalarGrammarInvalidDefect _ _ _ ->
      Generated.GeneratedSupplementalScalarGrammarRuleIdentity
    SupplementalArrayCardinalityInvalidDefect _ _ _ ->
      Generated.GeneratedSupplementalArrayCardinalityRuleIdentity
    SupplementalArrayDistinctnessInvalidDefect _ _ _ ->
      Generated.GeneratedSupplementalArrayDistinctnessRuleIdentity
    SupplementalSubjectCardinalityInvalidDefect _ _ _ _ ->
      Generated.GeneratedSupplementalSubjectCardinalityRuleIdentity
    SupplementalIdentityUnknownDefect _ _ _ ->
      Generated.GeneratedSupplementalIdentityUnknownRuleIdentity
    SupplementalIdentityAmbiguousDefect _ _ _ ->
      Generated.GeneratedSupplementalIdentityAmbiguousRuleIdentity
    SupplementalIdentityWrongTypeDefect _ _ _ ->
      Generated.GeneratedSupplementalIdentityWrongTypeRuleIdentity
    SupplementalIdentityOutOfSelectedViewDefect _ _ _ ->
      Generated.GeneratedSupplementalIdentityOutOfSelectedViewRuleIdentity
    SupplementalModelIdentityUnicodeScalarInvalidDefect _ _ _ _ ->
      Generated.GeneratedSupplementalModelIdentityUnicodeScalarRuleIdentity
    SupplementalModelIdentityContainsNulDefect _ _ _ _ ->
      Generated.GeneratedSupplementalModelIdentityNulRuleIdentity

-- | Named total consumer for all nineteen supplemental-input rules.
data SupplementalInputDefectEliminator result = SupplementalInputDefectEliminator
  { eliminateSupplementalInvalidUtf8 :: SupplementalInvalidUtf8Evidence -> result
  , eliminateSupplementalInvalidJsonSyntax :: SupplementalInvalidJsonSyntaxEvidence -> result
  , eliminateSupplementalDuplicateObjectMember :: SupplementalDuplicateObjectMemberEvidence -> result
  , eliminateSupplementalTopLevelObjectRequired :: SupplementalTopLevelObjectRequiredEvidence -> result
  , eliminateSupplementalTypeMemberInvalid :: SupplementalTypeMemberInvalidEvidence -> result
  , eliminateSupplementalPayloadTypeNotAdmitted :: SupplementalPayloadTypeNotAdmittedEvidence -> result
  , eliminateSupplementalRequiredMemberMissing :: SupplementalRequiredMemberMissingEvidence -> result
  , eliminateSupplementalUnknownMember :: SupplementalUnknownMemberEvidence -> result
  , eliminateSupplementalValueKindInvalid :: SupplementalValueKindInvalidEvidence -> result
  , eliminateSupplementalScalarGrammarInvalid :: SupplementalScalarGrammarInvalidEvidence -> result
  , eliminateSupplementalArrayCardinalityInvalid :: SupplementalArrayCardinalityInvalidEvidence -> result
  , eliminateSupplementalArrayDistinctnessInvalid :: SupplementalArrayDistinctnessInvalidEvidence -> result
  , eliminateSupplementalSubjectCardinalityInvalid :: SupplementalSubjectCardinalityInvalidEvidence -> result
  , eliminateSupplementalIdentityUnknown :: SupplementalIdentityUnknownEvidence -> result
  , eliminateSupplementalIdentityAmbiguous :: SupplementalIdentityAmbiguousEvidence -> result
  , eliminateSupplementalIdentityWrongType :: SupplementalIdentityWrongTypeEvidence -> result
  , eliminateSupplementalIdentityOutOfSelectedView :: SupplementalIdentityOutOfSelectedViewEvidence -> result
  , eliminateSupplementalModelIdentityUnicodeScalarInvalid :: SupplementalModelIdentityUnicodeScalarInvalidEvidence -> result
  , eliminateSupplementalModelIdentityContainsNul :: SupplementalModelIdentityContainsNulEvidence -> result
  }

-- | Eliminate one opaque defect through its rule-named exact handler.
foldSupplementalInputDefect ::
     SupplementalInputDefectEliminator result
  -> SupplementalInputDefect
  -> result
foldSupplementalInputDefect eliminator defect =
  case defect of
    SupplementalInvalidUtf8Defect ordinal ->
      eliminateSupplementalInvalidUtf8
        eliminator
        (SupplementalInvalidUtf8Evidence ordinal)
    SupplementalInvalidJsonSyntaxDefect ordinal ->
      eliminateSupplementalInvalidJsonSyntax
        eliminator
        (SupplementalInvalidJsonSyntaxEvidence ordinal)
    SupplementalDuplicateObjectMemberDefect ordinal pointer ->
      eliminateSupplementalDuplicateObjectMember
        eliminator
        (SupplementalDuplicateObjectMemberEvidence ordinal pointer)
    SupplementalTopLevelObjectRequiredDefect ordinal pointer schema ->
      eliminateSupplementalTopLevelObjectRequired
        eliminator
        (SupplementalTopLevelObjectRequiredEvidence ordinal pointer schema)
    SupplementalTypeMemberInvalidDefect ordinal pointer schema ->
      eliminateSupplementalTypeMemberInvalid
        eliminator
        (SupplementalTypeMemberInvalidEvidence ordinal pointer schema)
    SupplementalPayloadTypeNotAdmittedDefect ordinal pointer schema ->
      eliminateSupplementalPayloadTypeNotAdmitted
        eliminator
        (SupplementalPayloadTypeNotAdmittedEvidence ordinal pointer schema)
    SupplementalRequiredMemberMissingDefect ordinal pointer schema ->
      eliminateSupplementalRequiredMemberMissing
        eliminator
        (SupplementalRequiredMemberMissingEvidence ordinal pointer schema)
    SupplementalUnknownMemberDefect ordinal pointer schema ->
      eliminateSupplementalUnknownMember
        eliminator
        (SupplementalUnknownMemberEvidence ordinal pointer schema)
    SupplementalValueKindInvalidDefect ordinal pointer schema ->
      eliminateSupplementalValueKindInvalid
        eliminator
        (SupplementalValueKindInvalidEvidence ordinal pointer schema)
    SupplementalScalarGrammarInvalidDefect ordinal pointer schema ->
      eliminateSupplementalScalarGrammarInvalid
        eliminator
        (SupplementalScalarGrammarInvalidEvidence ordinal pointer schema)
    SupplementalArrayCardinalityInvalidDefect ordinal pointer schema ->
      eliminateSupplementalArrayCardinalityInvalid
        eliminator
        (SupplementalArrayCardinalityInvalidEvidence ordinal pointer schema)
    SupplementalArrayDistinctnessInvalidDefect ordinal pointer schema ->
      eliminateSupplementalArrayDistinctnessInvalid
        eliminator
        (SupplementalArrayDistinctnessInvalidEvidence ordinal pointer schema)
    SupplementalSubjectCardinalityInvalidDefect payloadType subject first remaining ->
      eliminateSupplementalSubjectCardinalityInvalid
        eliminator
        (SupplementalSubjectCardinalityInvalidEvidence
           payloadType
           subject
           first
           remaining)
    SupplementalIdentityUnknownDefect ordinal pointer identifier ->
      eliminateSupplementalIdentityUnknown
        eliminator
        (SupplementalIdentityUnknownEvidence ordinal pointer identifier)
    SupplementalIdentityAmbiguousDefect ordinal pointer identifier ->
      eliminateSupplementalIdentityAmbiguous
        eliminator
        (SupplementalIdentityAmbiguousEvidence ordinal pointer identifier)
    SupplementalIdentityWrongTypeDefect ordinal pointer identifier ->
      eliminateSupplementalIdentityWrongType
        eliminator
        (SupplementalIdentityWrongTypeEvidence ordinal pointer identifier)
    SupplementalIdentityOutOfSelectedViewDefect ordinal pointer identifier ->
      eliminateSupplementalIdentityOutOfSelectedView
        eliminator
        (SupplementalIdentityOutOfSelectedViewEvidence
           ordinal
           pointer
           identifier)
    SupplementalModelIdentityUnicodeScalarInvalidDefect ordinal pointer schema details ->
      eliminateSupplementalModelIdentityUnicodeScalarInvalid
        eliminator
        (SupplementalModelIdentityUnicodeScalarInvalidEvidence
           ordinal
           pointer
           schema
           details)
    SupplementalModelIdentityContainsNulDefect ordinal pointer schema indexes ->
      eliminateSupplementalModelIdentityContainsNul
        eliminator
        (SupplementalModelIdentityContainsNulEvidence
           ordinal
           pointer
           schema
           indexes)

-- | Project the closed failure classification.
supplementalInputDefectKind ::
     SupplementalInputDefect -> SupplementalInputDefectKind
supplementalInputDefectKind defect =
  foldSupplementalInputDefect kindEliminator defect
  where
    kindEliminator =
      SupplementalInputDefectEliminator
        { eliminateSupplementalInvalidUtf8 = const SupplementalInvalidUtf8
        , eliminateSupplementalInvalidJsonSyntax =
            const SupplementalInvalidJsonSyntax
        , eliminateSupplementalDuplicateObjectMember =
            const SupplementalDuplicateObjectMember
        , eliminateSupplementalTopLevelObjectRequired =
            const SupplementalTopLevelObjectRequired
        , eliminateSupplementalTypeMemberInvalid =
            const SupplementalTypeMemberInvalid
        , eliminateSupplementalPayloadTypeNotAdmitted =
            const SupplementalPayloadTypeNotAdmitted
        , eliminateSupplementalRequiredMemberMissing =
            const SupplementalRequiredMemberMissing
        , eliminateSupplementalUnknownMember = const SupplementalUnknownMember
        , eliminateSupplementalValueKindInvalid =
            const SupplementalValueKindInvalid
        , eliminateSupplementalScalarGrammarInvalid =
            const SupplementalScalarGrammarInvalid
        , eliminateSupplementalArrayCardinalityInvalid =
            const SupplementalArrayCardinalityInvalid
        , eliminateSupplementalArrayDistinctnessInvalid =
            const SupplementalArrayDistinctnessInvalid
        , eliminateSupplementalSubjectCardinalityInvalid =
            const SupplementalSubjectCardinalityInvalid
        , eliminateSupplementalIdentityUnknown =
            const SupplementalIdentityUnknown
        , eliminateSupplementalIdentityAmbiguous =
            const SupplementalIdentityAmbiguous
        , eliminateSupplementalIdentityWrongType =
            const SupplementalIdentityWrongType
        , eliminateSupplementalIdentityOutOfSelectedView =
            const SupplementalIdentityOutOfSelectedView
        , eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            const SupplementalModelIdentityUnicodeScalarInvalid
        , eliminateSupplementalModelIdentityContainsNul =
            const SupplementalModelIdentityContainsNul
        }

data SupplementalInputDefectKey
  = SupplementalInputKey !SupplementalInputOrdinal
  | SupplementalMemberKey !SupplementalInputOrdinal !Text
  | SupplementalSchemaKey !SupplementalInputOrdinal !Text !Text
  | SupplementalSubjectKey !SupplementalPayloadType !ModelIdentity
  | SupplementalIdentityKey !SupplementalInputOrdinal !Text !ModelIdentity
  deriving (Eq, Ord)

supplementalInputDefectKey ::
     SupplementalInputDefect -> SupplementalInputDefectKey
supplementalInputDefectKey defect =
  case defect of
    SupplementalInvalidUtf8Defect ordinal -> SupplementalInputKey ordinal
    SupplementalInvalidJsonSyntaxDefect ordinal -> SupplementalInputKey ordinal
    SupplementalDuplicateObjectMemberDefect ordinal pointer ->
      SupplementalMemberKey ordinal pointer
    SupplementalTopLevelObjectRequiredDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalTypeMemberInvalidDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalPayloadTypeNotAdmittedDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalRequiredMemberMissingDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalUnknownMemberDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalValueKindInvalidDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalScalarGrammarInvalidDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalArrayCardinalityInvalidDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalArrayDistinctnessInvalidDefect ordinal pointer schema ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalSubjectCardinalityInvalidDefect payloadType subject _ _ ->
      SupplementalSubjectKey payloadType subject
    SupplementalIdentityUnknownDefect ordinal pointer identifier ->
      SupplementalIdentityKey ordinal pointer identifier
    SupplementalIdentityAmbiguousDefect ordinal pointer identifier ->
      SupplementalIdentityKey ordinal pointer identifier
    SupplementalIdentityWrongTypeDefect ordinal pointer identifier ->
      SupplementalIdentityKey ordinal pointer identifier
    SupplementalIdentityOutOfSelectedViewDefect ordinal pointer identifier ->
      SupplementalIdentityKey ordinal pointer identifier
    SupplementalModelIdentityUnicodeScalarInvalidDefect ordinal pointer schema _ ->
      SupplementalSchemaKey ordinal pointer schema
    SupplementalModelIdentityContainsNulDefect ordinal pointer schema _ ->
      SupplementalSchemaKey ordinal pointer schema

instance Eq SupplementalInputDefect where
  left == right =
    supplementalInputDefectKind left == supplementalInputDefectKind right
      && supplementalInputDefectKey left == supplementalInputDefectKey right

instance Ord SupplementalInputDefect where
  compare left right =
    compare
      (supplementalInputDefectKind left, supplementalInputDefectKey left)
      (supplementalInputDefectKind right, supplementalInputDefectKey right)
