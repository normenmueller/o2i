{-# LANGUAGE RoleAnnotations #-}

-- | Closed supplemental-input boundary for semantic capabilities.
--
-- Operation supplies exact bytes and a stable ordinal. Core alone decodes,
-- canonicalizes, validates set uniqueness, and binds every model identity to
-- one opaque structurally valid selected-View graph.
module O2I.Semantics.Input
  ( SupplementalInputOrdinal
  , supplementalInputOrdinal
  , supplementalInputOrdinalValue
  , SupplementalPayloadType(..)
  , SupplementalInput
  , decodeSupplementalInput
  , SupplementalInputSet
  , assessSupplementalInputSet
  , SupplementalBinding
  , SupplementalBindingEvidence
  , SupplementalBindingDiagnosticEvidence
  , SupplementalBindingDiagnosticGroup
  , BoundSupplementalInputs
  , bindSupplementalInputs
  , foldSupplementalBinding
  , foldSupplementalBindingDiagnostics
  , foldSupplementalBindingDiagnosticGroups
  , foldSupplementalBindingDiagnosticGroup
  , supplementalBindingEvidenceRule
  , foldSupplementalBindingEvidence
  , supplementalBindingDiagnosticEvidenceRule
  , foldSupplementalBindingDiagnosticEvidence
  , SupplementalUnicodeScalarOccurrence(..)
  , SupplementalInvalidUtf8Evidence
  , supplementalInvalidUtf8InputOrdinal
  , SupplementalInvalidJsonSyntaxEvidence
  , supplementalInvalidJsonSyntaxInputOrdinal
  , SupplementalDuplicateObjectMemberEvidence
  , supplementalDuplicateObjectMemberInputOrdinal
  , supplementalDuplicateObjectMemberPointer
  , SupplementalTopLevelObjectRequiredEvidence
  , supplementalTopLevelObjectInputOrdinal
  , supplementalTopLevelObjectInstancePointer
  , supplementalTopLevelObjectExpectedSchema
  , SupplementalTypeMemberInvalidEvidence
  , supplementalTypeMemberInputOrdinal
  , supplementalTypeMemberInstancePointer
  , supplementalTypeMemberExpectedSchema
  , SupplementalPayloadTypeNotAdmittedEvidence
  , supplementalPayloadTypeNotAdmittedInputOrdinal
  , supplementalPayloadTypeNotAdmittedInstancePointer
  , supplementalPayloadTypeNotAdmittedExpectedSchema
  , SupplementalRequiredMemberMissingEvidence
  , supplementalRequiredMemberMissingInputOrdinal
  , supplementalRequiredMemberMissingInstancePointer
  , supplementalRequiredMemberMissingExpectedSchema
  , SupplementalUnknownMemberEvidence
  , supplementalUnknownMemberInputOrdinal
  , supplementalUnknownMemberInstancePointer
  , supplementalUnknownMemberExpectedSchema
  , SupplementalValueKindInvalidEvidence
  , supplementalValueKindInputOrdinal
  , supplementalValueKindInstancePointer
  , supplementalValueKindExpectedSchema
  , SupplementalScalarGrammarInvalidEvidence
  , supplementalScalarGrammarInputOrdinal
  , supplementalScalarGrammarInstancePointer
  , supplementalScalarGrammarExpectedSchema
  , SupplementalArrayCardinalityInvalidEvidence
  , supplementalArrayCardinalityInputOrdinal
  , supplementalArrayCardinalityInstancePointer
  , supplementalArrayCardinalityExpectedSchema
  , SupplementalArrayDistinctnessInvalidEvidence
  , supplementalArrayDistinctnessInputOrdinal
  , supplementalArrayDistinctnessInstancePointer
  , supplementalArrayDistinctnessExpectedSchema
  , SupplementalSubjectCardinalityInvalidEvidence
  , supplementalSubjectCardinalityPayloadType
  , supplementalSubjectCardinalitySubject
  , supplementalSubjectCardinalityFirstInputOrdinal
  , supplementalSubjectCardinalityRemainingInputOrdinals
  , SupplementalIdentityUnknownEvidence
  , supplementalIdentityUnknownInputOrdinal
  , supplementalIdentityUnknownInstancePointer
  , supplementalIdentityUnknownModelIdentity
  , SupplementalIdentityAmbiguousEvidence
  , supplementalIdentityAmbiguousInputOrdinal
  , supplementalIdentityAmbiguousInstancePointer
  , supplementalIdentityAmbiguousModelIdentity
  , SupplementalIdentityWrongTypeEvidence
  , supplementalIdentityWrongTypeInputOrdinal
  , supplementalIdentityWrongTypeInstancePointer
  , supplementalIdentityWrongTypeModelIdentity
  , SupplementalIdentityOutOfSelectedViewEvidence
  , supplementalIdentityOutOfViewInputOrdinal
  , supplementalIdentityOutOfViewInstancePointer
  , supplementalIdentityOutOfViewModelIdentity
  , SupplementalModelIdentityUnicodeScalarInvalidEvidence
  , supplementalUnicodeScalarInputOrdinal
  , supplementalUnicodeScalarInstancePointer
  , supplementalUnicodeScalarExpectedSchema
  , supplementalUnicodeScalarOccurrences
  , SupplementalModelIdentityContainsNulEvidence
  , supplementalModelIdentityNulInputOrdinal
  , supplementalModelIdentityNulInstancePointer
  , supplementalModelIdentityNulExpectedSchema
  , supplementalModelIdentityNulIndexes
  , SupplementalInputDefect
  , supplementalInputDefectRule
  , SupplementalInputDefectEliminator(..)
  , foldSupplementalInputDefect
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Identity (ModelIdentity)
import qualified O2I.Input.Internal.Binding as Binding
import O2I.Input.Internal.Decode (decodeSupplementalInput)
import O2I.Input.Internal.Set (assessSupplementalInputSet)
import qualified O2I.Input.Internal.Types as Internal
import O2I.Input.Internal.Types hiding
  ( SupplementalBinding
  , supplementalBindingDefects
  , supplementalBindingInputs
  , supplementalInputDefectRule
  )
import O2I.Structure (WellFormedGraph)

-- | Opaque binding result nominal in its producing selected-View scope.
newtype SupplementalBinding scope provenance =
  SupplementalBinding (Internal.SupplementalBinding scope provenance)

type role SupplementalBinding nominal nominal

-- | Opaque graph-dependent binding evidence in the producing scope.
data SupplementalBindingEvidence scope provenance =
  SupplementalBindingEvidence !provenance !SupplementalInputDefect

type role SupplementalBindingEvidence nominal nominal

-- | Opaque post-decode, graph-dependent evidence. Its closed algebra contains
-- exactly the four outcomes that Binding can construct.
data SupplementalBindingDiagnosticEvidence scope provenance =
  SupplementalBindingDiagnosticEvidence
    !provenance
    !Internal.SupplementalBindingDiagnosticDefect

type role SupplementalBindingDiagnosticEvidence nominal nominal

-- | One constructively retained provenance occurrence and all of its locally
-- ordered post-decode Binding diagnostics, including an empty diagnostic set.
data SupplementalBindingDiagnosticGroup scope provenance =
  SupplementalBindingDiagnosticGroup
    !provenance
    ![Internal.SupplementalBindingDiagnosticDefect]

type role SupplementalBindingDiagnosticGroup nominal nominal

-- | Bind every supplemental identity under one exact selected-View scope.
bindSupplementalInputs ::
     WellFormedGraph scope
  -> SupplementalInputSet provenance
  -> SupplementalBinding scope provenance
bindSupplementalInputs graph =
  SupplementalBinding . Binding.bindSupplementalInputs graph

-- | Eliminate only the exact result produced by scoped Binding.
foldSupplementalBinding ::
     (BoundSupplementalInputs scope -> [SupplementalBindingEvidence
                                          scope
                                          provenance] -> result)
  -> SupplementalBinding scope provenance
  -> result
foldSupplementalBinding consume (SupplementalBinding binding) =
  consume
    (Internal.supplementalBindingInputs binding)
    (map
       (uncurry SupplementalBindingEvidence)
       (Internal.supplementalBindingDefects binding))

-- | Eliminate the exact Binding result through its closed graph-dependent
-- evidence algebra, without reintroducing pre-binding failures.
foldSupplementalBindingDiagnostics ::
     (BoundSupplementalInputs scope -> [SupplementalBindingDiagnosticEvidence
                                          scope
                                          provenance] -> result)
  -> SupplementalBinding scope provenance
  -> result
foldSupplementalBindingDiagnostics consume (SupplementalBinding binding) =
  consume
    (Internal.supplementalBindingInputs binding)
    [ SupplementalBindingDiagnosticEvidence provenance defect
    | (provenance, defects) <-
        Internal.supplementalBindingDiagnosticGroups binding
    , defect <- defects
    ]

-- | Eliminate the exact Binding result without flattening its canonical
-- provenance groups.
foldSupplementalBindingDiagnosticGroups ::
     (BoundSupplementalInputs scope -> [SupplementalBindingDiagnosticGroup
                                          scope
                                          provenance] -> result)
  -> SupplementalBinding scope provenance
  -> result
foldSupplementalBindingDiagnosticGroups consume (SupplementalBinding binding) =
  consume
    (Internal.supplementalBindingInputs binding)
    [ SupplementalBindingDiagnosticGroup provenance defects
    | (provenance, defects) <-
        Internal.supplementalBindingDiagnosticGroups binding
    ]

-- | Eliminate one opaque source group. Every returned diagnostic retains the
-- same provenance that owns the group.
foldSupplementalBindingDiagnosticGroup ::
     (provenance -> [SupplementalBindingDiagnosticEvidence scope provenance] -> result)
  -> SupplementalBindingDiagnosticGroup scope provenance
  -> result
foldSupplementalBindingDiagnosticGroup consume group =
  case group of
    SupplementalBindingDiagnosticGroup provenance defects ->
      consume
        provenance
        (map (SupplementalBindingDiagnosticEvidence provenance) defects)

-- | Project the exact Core rule of scoped Binding evidence.
supplementalBindingEvidenceRule ::
     SupplementalBindingEvidence scope provenance -> CoreRuleId
supplementalBindingEvidenceRule (SupplementalBindingEvidence _ defect) =
  Internal.supplementalInputDefectRule defect

-- | Eliminate scoped Binding evidence through its closed exact handlers.
foldSupplementalBindingEvidence ::
     (provenance -> SupplementalInputDefectEliminator result)
  -> SupplementalBindingEvidence scope provenance
  -> result
foldSupplementalBindingEvidence eliminator (SupplementalBindingEvidence provenance defect) =
  Internal.foldSupplementalInputDefect (eliminator provenance) defect

-- | Project the exact Core rule of closed Binding diagnostic evidence.
supplementalBindingDiagnosticEvidenceRule ::
     SupplementalBindingDiagnosticEvidence scope provenance -> CoreRuleId
supplementalBindingDiagnosticEvidenceRule (SupplementalBindingDiagnosticEvidence _ defect) =
  Internal.supplementalInputDefectRule
    (Internal.supplementalBindingDiagnosticDefect defect)

-- | Eliminate closed Binding evidence through exactly its four possible
-- graph-dependent outcomes.
foldSupplementalBindingDiagnosticEvidence ::
     (provenance -> SupplementalIdentityUnknownEvidence -> result)
  -> (provenance -> SupplementalIdentityAmbiguousEvidence -> result)
  -> (provenance -> SupplementalIdentityWrongTypeEvidence -> result)
  -> (provenance -> SupplementalIdentityOutOfSelectedViewEvidence -> result)
  -> SupplementalBindingDiagnosticEvidence scope provenance
  -> result
foldSupplementalBindingDiagnosticEvidence unknown ambiguous wrongType outOfView (SupplementalBindingDiagnosticEvidence provenance defect) =
  case defect of
    Internal.SupplementalBindingIdentityUnknown evidence ->
      unknown provenance evidence
    Internal.SupplementalBindingIdentityAmbiguous evidence ->
      ambiguous provenance evidence
    Internal.SupplementalBindingIdentityWrongType evidence ->
      wrongType provenance evidence
    Internal.SupplementalBindingIdentityOutOfSelectedView evidence ->
      outOfView provenance evidence

-- | Project the exact Core-owned rule identity of one supplemental defect.
supplementalInputDefectRule :: SupplementalInputDefect -> CoreRuleId
supplementalInputDefectRule = Internal.supplementalInputDefectRule

-- | Construct one stable zero-based ordinal assigned by Operation.
supplementalInputOrdinal :: Natural -> SupplementalInputOrdinal
supplementalInputOrdinal = SupplementalInputOrdinal

-- | Project the Operation-assigned ordinal of invalid UTF-8 input.
supplementalInvalidUtf8InputOrdinal ::
     SupplementalInvalidUtf8Evidence -> SupplementalInputOrdinal
supplementalInvalidUtf8InputOrdinal (SupplementalInvalidUtf8Evidence ordinal) =
  ordinal

-- | Project the Operation-assigned ordinal of invalid JSON input.
supplementalInvalidJsonSyntaxInputOrdinal ::
     SupplementalInvalidJsonSyntaxEvidence -> SupplementalInputOrdinal
supplementalInvalidJsonSyntaxInputOrdinal (SupplementalInvalidJsonSyntaxEvidence ordinal) =
  ordinal

-- | Project the input ordinal of a repeated object member.
supplementalDuplicateObjectMemberInputOrdinal ::
     SupplementalDuplicateObjectMemberEvidence -> SupplementalInputOrdinal
supplementalDuplicateObjectMemberInputOrdinal (SupplementalDuplicateObjectMemberEvidence ordinal _) =
  ordinal

-- | Project the RFC 6901 pointer of a repeated object member.
supplementalDuplicateObjectMemberPointer ::
     SupplementalDuplicateObjectMemberEvidence -> Text
supplementalDuplicateObjectMemberPointer (SupplementalDuplicateObjectMemberEvidence _ pointer) =
  pointer

-- | Project the input ordinal whose root is not an object.
supplementalTopLevelObjectInputOrdinal ::
     SupplementalTopLevelObjectRequiredEvidence -> SupplementalInputOrdinal
supplementalTopLevelObjectInputOrdinal (SupplementalTopLevelObjectRequiredEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer whose root kind is invalid.
supplementalTopLevelObjectInstancePointer ::
     SupplementalTopLevelObjectRequiredEvidence -> Text
supplementalTopLevelObjectInstancePointer (SupplementalTopLevelObjectRequiredEvidence _ pointer _) =
  pointer

-- | Project the schema pointer requiring a root object.
supplementalTopLevelObjectExpectedSchema ::
     SupplementalTopLevelObjectRequiredEvidence -> Text
supplementalTopLevelObjectExpectedSchema (SupplementalTopLevelObjectRequiredEvidence _ _ schema) =
  schema

-- | Project the input ordinal whose discriminator member is invalid.
supplementalTypeMemberInputOrdinal ::
     SupplementalTypeMemberInvalidEvidence -> SupplementalInputOrdinal
supplementalTypeMemberInputOrdinal (SupplementalTypeMemberInvalidEvidence ordinal _ _) =
  ordinal

-- | Project the invalid discriminator instance pointer.
supplementalTypeMemberInstancePointer ::
     SupplementalTypeMemberInvalidEvidence -> Text
supplementalTypeMemberInstancePointer (SupplementalTypeMemberInvalidEvidence _ pointer _) =
  pointer

-- | Project the pre-selection union that owns discriminator-member validity.
supplementalTypeMemberExpectedSchema ::
     SupplementalTypeMemberInvalidEvidence -> Text
supplementalTypeMemberExpectedSchema (SupplementalTypeMemberInvalidEvidence _ _ schema) =
  schema

-- | Project the input ordinal with an unadmitted payload type.
supplementalPayloadTypeNotAdmittedInputOrdinal ::
     SupplementalPayloadTypeNotAdmittedEvidence -> SupplementalInputOrdinal
supplementalPayloadTypeNotAdmittedInputOrdinal (SupplementalPayloadTypeNotAdmittedEvidence ordinal _ _) =
  ordinal

-- | Project the unadmitted discriminator instance pointer.
supplementalPayloadTypeNotAdmittedInstancePointer ::
     SupplementalPayloadTypeNotAdmittedEvidence -> Text
supplementalPayloadTypeNotAdmittedInstancePointer (SupplementalPayloadTypeNotAdmittedEvidence _ pointer _) =
  pointer

-- | Project the pre-selection union containing admitted payload alternatives.
supplementalPayloadTypeNotAdmittedExpectedSchema ::
     SupplementalPayloadTypeNotAdmittedEvidence -> Text
supplementalPayloadTypeNotAdmittedExpectedSchema (SupplementalPayloadTypeNotAdmittedEvidence _ _ schema) =
  schema

-- | Project the input ordinal with a missing required member.
supplementalRequiredMemberMissingInputOrdinal ::
     SupplementalRequiredMemberMissingEvidence -> SupplementalInputOrdinal
supplementalRequiredMemberMissingInputOrdinal (SupplementalRequiredMemberMissingEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer requiring an absent member.
supplementalRequiredMemberMissingInstancePointer ::
     SupplementalRequiredMemberMissingEvidence -> Text
supplementalRequiredMemberMissingInstancePointer (SupplementalRequiredMemberMissingEvidence _ pointer _) =
  pointer

-- | Project the schema pointer naming the required member contract.
supplementalRequiredMemberMissingExpectedSchema ::
     SupplementalRequiredMemberMissingEvidence -> Text
supplementalRequiredMemberMissingExpectedSchema (SupplementalRequiredMemberMissingEvidence _ _ schema) =
  schema

-- | Project the input ordinal containing an unknown member.
supplementalUnknownMemberInputOrdinal ::
     SupplementalUnknownMemberEvidence -> SupplementalInputOrdinal
supplementalUnknownMemberInputOrdinal (SupplementalUnknownMemberEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of an unknown member.
supplementalUnknownMemberInstancePointer ::
     SupplementalUnknownMemberEvidence -> Text
supplementalUnknownMemberInstancePointer (SupplementalUnknownMemberEvidence _ pointer _) =
  pointer

-- | Project the schema pointer for the containing closed object.
supplementalUnknownMemberExpectedSchema ::
     SupplementalUnknownMemberEvidence -> Text
supplementalUnknownMemberExpectedSchema (SupplementalUnknownMemberEvidence _ _ schema) =
  schema

-- | Project the input ordinal containing a value of the wrong JSON kind.
supplementalValueKindInputOrdinal ::
     SupplementalValueKindInvalidEvidence -> SupplementalInputOrdinal
supplementalValueKindInputOrdinal (SupplementalValueKindInvalidEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of the wrong-kind value.
supplementalValueKindInstancePointer ::
     SupplementalValueKindInvalidEvidence -> Text
supplementalValueKindInstancePointer (SupplementalValueKindInvalidEvidence _ pointer _) =
  pointer

-- | Project the schema pointer defining the required JSON kind.
supplementalValueKindExpectedSchema ::
     SupplementalValueKindInvalidEvidence -> Text
supplementalValueKindExpectedSchema (SupplementalValueKindInvalidEvidence _ _ schema) =
  schema

-- | Project the input ordinal containing a malformed scalar.
supplementalScalarGrammarInputOrdinal ::
     SupplementalScalarGrammarInvalidEvidence -> SupplementalInputOrdinal
supplementalScalarGrammarInputOrdinal (SupplementalScalarGrammarInvalidEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of the malformed scalar.
supplementalScalarGrammarInstancePointer ::
     SupplementalScalarGrammarInvalidEvidence -> Text
supplementalScalarGrammarInstancePointer (SupplementalScalarGrammarInvalidEvidence _ pointer _) =
  pointer

-- | Project the schema pointer defining the scalar grammar.
supplementalScalarGrammarExpectedSchema ::
     SupplementalScalarGrammarInvalidEvidence -> Text
supplementalScalarGrammarExpectedSchema (SupplementalScalarGrammarInvalidEvidence _ _ schema) =
  schema

-- | Project the input ordinal containing a wrong-cardinality array.
supplementalArrayCardinalityInputOrdinal ::
     SupplementalArrayCardinalityInvalidEvidence -> SupplementalInputOrdinal
supplementalArrayCardinalityInputOrdinal (SupplementalArrayCardinalityInvalidEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of the wrong-cardinality array.
supplementalArrayCardinalityInstancePointer ::
     SupplementalArrayCardinalityInvalidEvidence -> Text
supplementalArrayCardinalityInstancePointer (SupplementalArrayCardinalityInvalidEvidence _ pointer _) =
  pointer

-- | Project the schema pointer defining required array cardinality.
supplementalArrayCardinalityExpectedSchema ::
     SupplementalArrayCardinalityInvalidEvidence -> Text
supplementalArrayCardinalityExpectedSchema (SupplementalArrayCardinalityInvalidEvidence _ _ schema) =
  schema

-- | Project the input ordinal containing non-distinct array members.
supplementalArrayDistinctnessInputOrdinal ::
     SupplementalArrayDistinctnessInvalidEvidence -> SupplementalInputOrdinal
supplementalArrayDistinctnessInputOrdinal (SupplementalArrayDistinctnessInvalidEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of the non-distinct array.
supplementalArrayDistinctnessInstancePointer ::
     SupplementalArrayDistinctnessInvalidEvidence -> Text
supplementalArrayDistinctnessInstancePointer (SupplementalArrayDistinctnessInvalidEvidence _ pointer _) =
  pointer

-- | Project the schema pointer defining array distinctness.
supplementalArrayDistinctnessExpectedSchema ::
     SupplementalArrayDistinctnessInvalidEvidence -> Text
supplementalArrayDistinctnessExpectedSchema (SupplementalArrayDistinctnessInvalidEvidence _ _ schema) =
  schema

-- | Project the closed payload family whose subject repeats.
supplementalSubjectCardinalityPayloadType ::
     SupplementalSubjectCardinalityInvalidEvidence -> SupplementalPayloadType
supplementalSubjectCardinalityPayloadType (SupplementalSubjectCardinalityInvalidEvidence payloadType _ _ _) =
  payloadType

-- | Project the repeated payload subject identity.
supplementalSubjectCardinalitySubject ::
     SupplementalSubjectCardinalityInvalidEvidence -> ModelIdentity
supplementalSubjectCardinalitySubject (SupplementalSubjectCardinalityInvalidEvidence _ subject _ _) =
  subject

-- | Project the first input ordinal for the repeated subject.
supplementalSubjectCardinalityFirstInputOrdinal ::
     SupplementalSubjectCardinalityInvalidEvidence -> SupplementalInputOrdinal
supplementalSubjectCardinalityFirstInputOrdinal (SupplementalSubjectCardinalityInvalidEvidence _ _ first _) =
  first

-- | Project the second and any later input ordinals.
supplementalSubjectCardinalityRemainingInputOrdinals ::
     SupplementalSubjectCardinalityInvalidEvidence
  -> NonEmpty SupplementalInputOrdinal
supplementalSubjectCardinalityRemainingInputOrdinals (SupplementalSubjectCardinalityInvalidEvidence _ _ _ remaining) =
  remaining

-- | Project the input ordinal of an unknown identity site.
supplementalIdentityUnknownInputOrdinal ::
     SupplementalIdentityUnknownEvidence -> SupplementalInputOrdinal
supplementalIdentityUnknownInputOrdinal (SupplementalIdentityUnknownEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of an unknown identity site.
supplementalIdentityUnknownInstancePointer ::
     SupplementalIdentityUnknownEvidence -> Text
supplementalIdentityUnknownInstancePointer (SupplementalIdentityUnknownEvidence _ pointer _) =
  pointer

-- | Project the exact unknown model identity.
supplementalIdentityUnknownModelIdentity ::
     SupplementalIdentityUnknownEvidence -> ModelIdentity
supplementalIdentityUnknownModelIdentity (SupplementalIdentityUnknownEvidence _ _ identity) =
  identity

-- | Project the input ordinal of an ambiguous identity site.
supplementalIdentityAmbiguousInputOrdinal ::
     SupplementalIdentityAmbiguousEvidence -> SupplementalInputOrdinal
supplementalIdentityAmbiguousInputOrdinal (SupplementalIdentityAmbiguousEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of an ambiguous identity site.
supplementalIdentityAmbiguousInstancePointer ::
     SupplementalIdentityAmbiguousEvidence -> Text
supplementalIdentityAmbiguousInstancePointer (SupplementalIdentityAmbiguousEvidence _ pointer _) =
  pointer

-- | Project the exact ambiguous model identity.
supplementalIdentityAmbiguousModelIdentity ::
     SupplementalIdentityAmbiguousEvidence -> ModelIdentity
supplementalIdentityAmbiguousModelIdentity (SupplementalIdentityAmbiguousEvidence _ _ identity) =
  identity

-- | Project the input ordinal of a wrong-type identity site.
supplementalIdentityWrongTypeInputOrdinal ::
     SupplementalIdentityWrongTypeEvidence -> SupplementalInputOrdinal
supplementalIdentityWrongTypeInputOrdinal (SupplementalIdentityWrongTypeEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of a wrong-type identity site.
supplementalIdentityWrongTypeInstancePointer ::
     SupplementalIdentityWrongTypeEvidence -> Text
supplementalIdentityWrongTypeInstancePointer (SupplementalIdentityWrongTypeEvidence _ pointer _) =
  pointer

-- | Project the identity resolved to the wrong qualified type.
supplementalIdentityWrongTypeModelIdentity ::
     SupplementalIdentityWrongTypeEvidence -> ModelIdentity
supplementalIdentityWrongTypeModelIdentity (SupplementalIdentityWrongTypeEvidence _ _ identity) =
  identity

-- | Project the input ordinal of an out-of-View identity site.
supplementalIdentityOutOfViewInputOrdinal ::
     SupplementalIdentityOutOfSelectedViewEvidence -> SupplementalInputOrdinal
supplementalIdentityOutOfViewInputOrdinal (SupplementalIdentityOutOfSelectedViewEvidence ordinal _ _) =
  ordinal

-- | Project the instance pointer of an out-of-View identity site.
supplementalIdentityOutOfViewInstancePointer ::
     SupplementalIdentityOutOfSelectedViewEvidence -> Text
supplementalIdentityOutOfViewInstancePointer (SupplementalIdentityOutOfSelectedViewEvidence _ pointer _) =
  pointer

-- | Project the exact identity outside the selected View.
supplementalIdentityOutOfViewModelIdentity ::
     SupplementalIdentityOutOfSelectedViewEvidence -> ModelIdentity
supplementalIdentityOutOfViewModelIdentity (SupplementalIdentityOutOfSelectedViewEvidence _ _ identity) =
  identity

-- | Project the input ordinal containing malformed surrogate evidence.
supplementalUnicodeScalarInputOrdinal ::
     SupplementalModelIdentityUnicodeScalarInvalidEvidence
  -> SupplementalInputOrdinal
supplementalUnicodeScalarInputOrdinal (SupplementalModelIdentityUnicodeScalarInvalidEvidence ordinal _ _ _) =
  ordinal

-- | Project the malformed ModelIdentity instance pointer.
supplementalUnicodeScalarInstancePointer ::
     SupplementalModelIdentityUnicodeScalarInvalidEvidence -> Text
supplementalUnicodeScalarInstancePointer (SupplementalModelIdentityUnicodeScalarInvalidEvidence _ pointer _ _) =
  pointer

-- | Project the schema pointer defining Unicode scalar admissibility.
supplementalUnicodeScalarExpectedSchema ::
     SupplementalModelIdentityUnicodeScalarInvalidEvidence -> Text
supplementalUnicodeScalarExpectedSchema (SupplementalModelIdentityUnicodeScalarInvalidEvidence _ _ schema _) =
  schema

-- | Project exact indexes and malformed surrogate code points.
supplementalUnicodeScalarOccurrences ::
     SupplementalModelIdentityUnicodeScalarInvalidEvidence
  -> NonEmpty SupplementalUnicodeScalarOccurrence
supplementalUnicodeScalarOccurrences (SupplementalModelIdentityUnicodeScalarInvalidEvidence _ _ _ occurrences) =
  occurrences

-- | Project the input ordinal containing NUL scalars.
supplementalModelIdentityNulInputOrdinal ::
     SupplementalModelIdentityContainsNulEvidence -> SupplementalInputOrdinal
supplementalModelIdentityNulInputOrdinal (SupplementalModelIdentityContainsNulEvidence ordinal _ _ _) =
  ordinal

-- | Project the ModelIdentity instance pointer containing NUL.
supplementalModelIdentityNulInstancePointer ::
     SupplementalModelIdentityContainsNulEvidence -> Text
supplementalModelIdentityNulInstancePointer (SupplementalModelIdentityContainsNulEvidence _ pointer _ _) =
  pointer

-- | Project the schema pointer defining NUL exclusion.
supplementalModelIdentityNulExpectedSchema ::
     SupplementalModelIdentityContainsNulEvidence -> Text
supplementalModelIdentityNulExpectedSchema (SupplementalModelIdentityContainsNulEvidence _ _ schema _) =
  schema

-- | Project zero-based decoded scalar indexes containing NUL.
supplementalModelIdentityNulIndexes ::
     SupplementalModelIdentityContainsNulEvidence -> NonEmpty Natural
supplementalModelIdentityNulIndexes (SupplementalModelIdentityContainsNulEvidence _ _ _ indexes) =
  indexes
