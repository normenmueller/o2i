module SupplementalInputPublicApi where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Core.Contract (CoreRuleId)
import O2I.Core.Identity (ModelIdentity)
import O2I.Semantics.Input
import O2I.Structure (WellFormedGraph)

data SupplementalEvidenceView
  = InvalidUtf8View SupplementalInputOrdinal
  | InvalidJsonSyntaxView SupplementalInputOrdinal
  | DuplicateObjectMemberView SupplementalInputOrdinal Text
  | TopLevelObjectView SupplementalInputOrdinal Text Text
  | TypeMemberView SupplementalInputOrdinal Text Text
  | PayloadTypeView SupplementalInputOrdinal Text Text
  | RequiredMemberView SupplementalInputOrdinal Text Text
  | UnknownMemberView SupplementalInputOrdinal Text Text
  | ValueKindView SupplementalInputOrdinal Text Text
  | ScalarGrammarView SupplementalInputOrdinal Text Text
  | ArrayCardinalityView SupplementalInputOrdinal Text Text
  | ArrayDistinctnessView SupplementalInputOrdinal Text Text
  | SubjectCardinalityView
      SupplementalPayloadType
      ModelIdentity
      SupplementalInputOrdinal
      (NonEmpty SupplementalInputOrdinal)
  | IdentityUnknownView SupplementalInputOrdinal Text ModelIdentity
  | IdentityAmbiguousView SupplementalInputOrdinal Text ModelIdentity
  | IdentityWrongTypeView SupplementalInputOrdinal Text ModelIdentity
  | IdentityOutOfViewView SupplementalInputOrdinal Text ModelIdentity
  | UnicodeScalarView
      SupplementalInputOrdinal
      Text
      Text
      (NonEmpty (Natural, Natural))
  | ModelIdentityNulView SupplementalInputOrdinal Text Text (NonEmpty Natural)

projectRule :: SupplementalInputDefect -> CoreRuleId
projectRule = supplementalInputDefectRule

projectDefect :: SupplementalInputDefect -> SupplementalEvidenceView
projectDefect = foldSupplementalInputDefect eliminator
  where
    eliminator =
      SupplementalInputDefectEliminator
        { eliminateSupplementalInvalidUtf8 =
            InvalidUtf8View . supplementalInvalidUtf8InputOrdinal
        , eliminateSupplementalInvalidJsonSyntax =
            InvalidJsonSyntaxView . supplementalInvalidJsonSyntaxInputOrdinal
        , eliminateSupplementalDuplicateObjectMember =
            \evidence ->
              DuplicateObjectMemberView
                (supplementalDuplicateObjectMemberInputOrdinal evidence)
                (supplementalDuplicateObjectMemberPointer evidence)
        , eliminateSupplementalTopLevelObjectRequired =
            \evidence ->
              TopLevelObjectView
                (supplementalTopLevelObjectInputOrdinal evidence)
                (supplementalTopLevelObjectInstancePointer evidence)
                (supplementalTopLevelObjectExpectedSchema evidence)
        , eliminateSupplementalTypeMemberInvalid =
            \evidence ->
              TypeMemberView
                (supplementalTypeMemberInputOrdinal evidence)
                (supplementalTypeMemberInstancePointer evidence)
                (supplementalTypeMemberExpectedSchema evidence)
        , eliminateSupplementalPayloadTypeNotAdmitted =
            \evidence ->
              PayloadTypeView
                (supplementalPayloadTypeNotAdmittedInputOrdinal evidence)
                (supplementalPayloadTypeNotAdmittedInstancePointer evidence)
                (supplementalPayloadTypeNotAdmittedExpectedSchema evidence)
        , eliminateSupplementalRequiredMemberMissing =
            \evidence ->
              RequiredMemberView
                (supplementalRequiredMemberMissingInputOrdinal evidence)
                (supplementalRequiredMemberMissingInstancePointer evidence)
                (supplementalRequiredMemberMissingExpectedSchema evidence)
        , eliminateSupplementalUnknownMember =
            \evidence ->
              UnknownMemberView
                (supplementalUnknownMemberInputOrdinal evidence)
                (supplementalUnknownMemberInstancePointer evidence)
                (supplementalUnknownMemberExpectedSchema evidence)
        , eliminateSupplementalValueKindInvalid =
            \evidence ->
              ValueKindView
                (supplementalValueKindInputOrdinal evidence)
                (supplementalValueKindInstancePointer evidence)
                (supplementalValueKindExpectedSchema evidence)
        , eliminateSupplementalScalarGrammarInvalid =
            \evidence ->
              ScalarGrammarView
                (supplementalScalarGrammarInputOrdinal evidence)
                (supplementalScalarGrammarInstancePointer evidence)
                (supplementalScalarGrammarExpectedSchema evidence)
        , eliminateSupplementalArrayCardinalityInvalid =
            \evidence ->
              ArrayCardinalityView
                (supplementalArrayCardinalityInputOrdinal evidence)
                (supplementalArrayCardinalityInstancePointer evidence)
                (supplementalArrayCardinalityExpectedSchema evidence)
        , eliminateSupplementalArrayDistinctnessInvalid =
            \evidence ->
              ArrayDistinctnessView
                (supplementalArrayDistinctnessInputOrdinal evidence)
                (supplementalArrayDistinctnessInstancePointer evidence)
                (supplementalArrayDistinctnessExpectedSchema evidence)
        , eliminateSupplementalSubjectCardinalityInvalid =
            \evidence ->
              SubjectCardinalityView
                (supplementalSubjectCardinalityPayloadType evidence)
                (supplementalSubjectCardinalitySubject evidence)
                (supplementalSubjectCardinalityFirstInputOrdinal evidence)
                (supplementalSubjectCardinalityRemainingInputOrdinals evidence)
        , eliminateSupplementalIdentityUnknown =
            \evidence ->
              IdentityUnknownView
                (supplementalIdentityUnknownInputOrdinal evidence)
                (supplementalIdentityUnknownInstancePointer evidence)
                (supplementalIdentityUnknownModelIdentity evidence)
        , eliminateSupplementalIdentityAmbiguous =
            \evidence ->
              IdentityAmbiguousView
                (supplementalIdentityAmbiguousInputOrdinal evidence)
                (supplementalIdentityAmbiguousInstancePointer evidence)
                (supplementalIdentityAmbiguousModelIdentity evidence)
        , eliminateSupplementalIdentityWrongType =
            \evidence ->
              IdentityWrongTypeView
                (supplementalIdentityWrongTypeInputOrdinal evidence)
                (supplementalIdentityWrongTypeInstancePointer evidence)
                (supplementalIdentityWrongTypeModelIdentity evidence)
        , eliminateSupplementalIdentityOutOfSelectedView =
            \evidence ->
              IdentityOutOfViewView
                (supplementalIdentityOutOfViewInputOrdinal evidence)
                (supplementalIdentityOutOfViewInstancePointer evidence)
                (supplementalIdentityOutOfViewModelIdentity evidence)
        , eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            \evidence ->
              UnicodeScalarView
                (supplementalUnicodeScalarInputOrdinal evidence)
                (supplementalUnicodeScalarInstancePointer evidence)
                (supplementalUnicodeScalarExpectedSchema evidence)
                (fmap
                   (\occurrence ->
                      ( supplementalUnicodeScalarIndex occurrence
                      , supplementalUnicodeScalarCodePoint occurrence))
                   (supplementalUnicodeScalarOccurrences evidence))
        , eliminateSupplementalModelIdentityContainsNul =
            \evidence ->
              ModelIdentityNulView
                (supplementalModelIdentityNulInputOrdinal evidence)
                (supplementalModelIdentityNulInstancePointer evidence)
                (supplementalModelIdentityNulExpectedSchema evidence)
                (supplementalModelIdentityNulIndexes evidence)
        }

roundTripOrdinal :: SupplementalInputOrdinal -> SupplementalInputOrdinal
roundTripOrdinal = supplementalInputOrdinal . supplementalInputOrdinalValue

bind ::
     WellFormedGraph scope
  -> SupplementalInputSet ()
  -> SupplementalBinding scope ()
bind = bindSupplementalInputs

consumeBinding ::
     SupplementalBinding scope ()
  -> (BoundSupplementalInputs scope, [SupplementalEvidenceView])
consumeBinding =
  foldSupplementalBinding
    (\bound evidence -> (bound, map projectBindingEvidence evidence))

projectBindingEvidence ::
     SupplementalBindingEvidence scope () -> SupplementalEvidenceView
projectBindingEvidence = foldSupplementalBindingEvidence (const eliminator)
  where
    eliminator =
      SupplementalInputDefectEliminator
        { eliminateSupplementalInvalidUtf8 =
            InvalidUtf8View . supplementalInvalidUtf8InputOrdinal
        , eliminateSupplementalInvalidJsonSyntax =
            InvalidJsonSyntaxView . supplementalInvalidJsonSyntaxInputOrdinal
        , eliminateSupplementalDuplicateObjectMember =
            \evidence ->
              DuplicateObjectMemberView
                (supplementalDuplicateObjectMemberInputOrdinal evidence)
                (supplementalDuplicateObjectMemberPointer evidence)
        , eliminateSupplementalTopLevelObjectRequired =
            \evidence ->
              TopLevelObjectView
                (supplementalTopLevelObjectInputOrdinal evidence)
                (supplementalTopLevelObjectInstancePointer evidence)
                (supplementalTopLevelObjectExpectedSchema evidence)
        , eliminateSupplementalTypeMemberInvalid =
            \evidence ->
              TypeMemberView
                (supplementalTypeMemberInputOrdinal evidence)
                (supplementalTypeMemberInstancePointer evidence)
                (supplementalTypeMemberExpectedSchema evidence)
        , eliminateSupplementalPayloadTypeNotAdmitted =
            \evidence ->
              PayloadTypeView
                (supplementalPayloadTypeNotAdmittedInputOrdinal evidence)
                (supplementalPayloadTypeNotAdmittedInstancePointer evidence)
                (supplementalPayloadTypeNotAdmittedExpectedSchema evidence)
        , eliminateSupplementalRequiredMemberMissing =
            \evidence ->
              RequiredMemberView
                (supplementalRequiredMemberMissingInputOrdinal evidence)
                (supplementalRequiredMemberMissingInstancePointer evidence)
                (supplementalRequiredMemberMissingExpectedSchema evidence)
        , eliminateSupplementalUnknownMember =
            \evidence ->
              UnknownMemberView
                (supplementalUnknownMemberInputOrdinal evidence)
                (supplementalUnknownMemberInstancePointer evidence)
                (supplementalUnknownMemberExpectedSchema evidence)
        , eliminateSupplementalValueKindInvalid =
            \evidence ->
              ValueKindView
                (supplementalValueKindInputOrdinal evidence)
                (supplementalValueKindInstancePointer evidence)
                (supplementalValueKindExpectedSchema evidence)
        , eliminateSupplementalScalarGrammarInvalid =
            \evidence ->
              ScalarGrammarView
                (supplementalScalarGrammarInputOrdinal evidence)
                (supplementalScalarGrammarInstancePointer evidence)
                (supplementalScalarGrammarExpectedSchema evidence)
        , eliminateSupplementalArrayCardinalityInvalid =
            \evidence ->
              ArrayCardinalityView
                (supplementalArrayCardinalityInputOrdinal evidence)
                (supplementalArrayCardinalityInstancePointer evidence)
                (supplementalArrayCardinalityExpectedSchema evidence)
        , eliminateSupplementalArrayDistinctnessInvalid =
            \evidence ->
              ArrayDistinctnessView
                (supplementalArrayDistinctnessInputOrdinal evidence)
                (supplementalArrayDistinctnessInstancePointer evidence)
                (supplementalArrayDistinctnessExpectedSchema evidence)
        , eliminateSupplementalSubjectCardinalityInvalid =
            \evidence ->
              SubjectCardinalityView
                (supplementalSubjectCardinalityPayloadType evidence)
                (supplementalSubjectCardinalitySubject evidence)
                (supplementalSubjectCardinalityFirstInputOrdinal evidence)
                (supplementalSubjectCardinalityRemainingInputOrdinals evidence)
        , eliminateSupplementalIdentityUnknown =
            \evidence ->
              IdentityUnknownView
                (supplementalIdentityUnknownInputOrdinal evidence)
                (supplementalIdentityUnknownInstancePointer evidence)
                (supplementalIdentityUnknownModelIdentity evidence)
        , eliminateSupplementalIdentityAmbiguous =
            \evidence ->
              IdentityAmbiguousView
                (supplementalIdentityAmbiguousInputOrdinal evidence)
                (supplementalIdentityAmbiguousInstancePointer evidence)
                (supplementalIdentityAmbiguousModelIdentity evidence)
        , eliminateSupplementalIdentityWrongType =
            \evidence ->
              IdentityWrongTypeView
                (supplementalIdentityWrongTypeInputOrdinal evidence)
                (supplementalIdentityWrongTypeInstancePointer evidence)
                (supplementalIdentityWrongTypeModelIdentity evidence)
        , eliminateSupplementalIdentityOutOfSelectedView =
            \evidence ->
              IdentityOutOfViewView
                (supplementalIdentityOutOfViewInputOrdinal evidence)
                (supplementalIdentityOutOfViewInstancePointer evidence)
                (supplementalIdentityOutOfViewModelIdentity evidence)
        , eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            \evidence ->
              UnicodeScalarView
                (supplementalUnicodeScalarInputOrdinal evidence)
                (supplementalUnicodeScalarInstancePointer evidence)
                (supplementalUnicodeScalarExpectedSchema evidence)
                (fmap
                   (\occurrence ->
                      ( supplementalUnicodeScalarIndex occurrence
                      , supplementalUnicodeScalarCodePoint occurrence))
                   (supplementalUnicodeScalarOccurrences evidence))
        , eliminateSupplementalModelIdentityContainsNul =
            \evidence ->
              ModelIdentityNulView
                (supplementalModelIdentityNulInputOrdinal evidence)
                (supplementalModelIdentityNulInstancePointer evidence)
                (supplementalModelIdentityNulExpectedSchema evidence)
                (supplementalModelIdentityNulIndexes evidence)
        }
