{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.HumanFailureCorrespondence
  ( observeRawCommonFailure
  , observeHumanCommonFailure
  , observeRawReadinessInputDefect
  , observeRawAssessmentInputDefect
  , observeHumanInputDefect
  , observeRawSupplementalInputDefect
  , observeHumanSupplementalInputDefect
  , observeRawSourceIdentity
  , observeHumanSourceIdentity
  ) where

import Control.Exception (displayException)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract (coreQualifiedEndpointIdText, coreRuleIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Acquisition
  ( InputSource
  , foldAcquisitionFailure
  , foldInputSource
  )
import O2I.Operation.Failure
  ( CommonFailure
  , commandFailureCode
  , foldCommandFailure
  , foldCommonFailure
  , preparationFailureCode
  )
import qualified O2I.Operation.Human.Failure as HumanFailure
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(..)
  , sourceIdentityOrdinal
  , sourceIdentityReference
  , sourceIdentityRole
  , sourceIdentitySha256
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental

observeRawCommonFailure :: CommonFailure -> [Text]
observeRawCommonFailure =
  foldCommonFailure
    (\command ->
       foldCommandFailure
         (foldAcquisitionFailure $ \source exception ->
            ["acquisition", commandFailureCode command]
              <> observeRawInputSource source
              <> [Text.pack (displayException exception)])
         command)
    (\failureValue -> ["preparation", preparationFailureCode failureValue])

observeHumanCommonFailure :: HumanFailure.HumanCommonFailure -> [Text]
observeHumanCommonFailure =
  HumanFailure.foldHumanCommonFailure
    (\code source exception ->
       ["acquisition", code]
         <> observeHumanInputSource source
         <> [Text.pack (displayException exception)])
    (\failureValue ->
       [ "preparation"
       , HumanFailure.foldHumanPreparationFailure
           (\code _ -> code)
           (\code _ _ -> code)
           (\code _ -> code)
           (\code _ -> code)
           (\code _ -> code)
           (\code _ -> code)
           failureValue
       ])

observeRawInputSource :: InputSource -> [Text]
observeRawInputSource =
  foldInputSource
    (\reference path -> ["file", sourceReferenceText reference, Text.pack path])
    (\reference -> ["standard-input", sourceReferenceText reference])

observeHumanInputSource :: HumanValue.HumanInputSource -> [Text]
observeHumanInputSource =
  HumanValue.foldHumanInputSource
    (\reference path -> ["file", reference, Text.pack path])
    (\reference -> ["standard-input", reference])

observeRawReadinessInputDefect :: Readiness.EvidenceInputDefect -> [Text]
observeRawReadinessInputDefect defect =
  observeRawInputDefect
    (coreRuleIdText (Readiness.evidenceInputDefectRule defect))
    (Readiness.readinessInputOrdinalValue
       (Readiness.evidenceInputDefectOrdinal defect))
    (observeRawInputKind (Readiness.evidenceInputDefectKind defect))
    (Readiness.evidenceInputDefectPointer defect)
    (Readiness.evidenceInputDefectSubjects defect)

observeRawAssessmentInputDefect :: Assessment.AssessmentInputDefect -> [Text]
observeRawAssessmentInputDefect defect =
  observeRawInputDefect
    (coreRuleIdText (Assessment.assessmentInputDefectRule defect))
    (Assessment.assessmentInputOrdinalValue
       (Assessment.assessmentInputDefectOrdinal defect))
    (observeRawInputKind (Assessment.assessmentInputDefectKind defect))
    (Assessment.assessmentInputDefectPointer defect)
    (Assessment.assessmentInputDefectSubjects defect)

observeRawInputDefect ::
     Text
  -> Natural
  -> Text
  -> Text
  -> NonEmpty Readiness.EvidenceInputDiagnosticSubject
  -> [Text]
observeRawInputDefect rule ordinal kind pointer subjects =
  [rule, naturalText ordinal, kind, pointer]
    <> observeItems observeRawInputSubject (NonEmpty.toList subjects)

observeHumanInputDefect :: HumanFailure.HumanInputDefect -> [Text]
observeHumanInputDefect =
  HumanFailure.foldHumanInputDefect $ \rule ordinal kind pointer subjects ->
    [rule, naturalText ordinal, observeHumanInputKind kind, pointer]
      <> observeItems observeHumanInputSubject (NonEmpty.toList subjects)

observeRawInputSubject :: Readiness.EvidenceInputDiagnosticSubject -> [Text]
observeRawInputSubject =
  Readiness.foldEvidenceInputDiagnosticSubject
    (\label value -> ["text", label, value])
    (\label value -> ["natural", label, naturalText value])
    (\label value -> ["model", label, modelIdentityText value])
    (\label value -> ["occurrence", label, occurrenceIdentityText value])
    (\label value ->
       ["qualified-type", label, coreQualifiedEndpointIdText value])

observeHumanInputSubject :: HumanFailure.HumanInputDefectSubject -> [Text]
observeHumanInputSubject =
  HumanFailure.foldHumanInputDefectSubject
    (\label value -> ["text", label, value])
    (\label value -> ["natural", label, naturalText value])
    (\label value ->
       ["model", label, HumanValue.foldHumanModelIdentity id value])
    (\label value ->
       ["occurrence", label, HumanValue.foldHumanOccurrenceIdentity id value])
    (\label value ->
       ["qualified-type", label, HumanValue.foldHumanQualifiedType id value])

observeRawInputKind :: Readiness.EvidenceInputDefectKind -> Text
observeRawInputKind kind =
  case kind of
    Readiness.EvidenceInputInvalidUtf8 -> "invalid-utf8"
    Readiness.EvidenceInputInvalidJsonSyntax -> "invalid-json-syntax"
    Readiness.EvidenceInputDuplicateObjectMember -> "duplicate-object-member"
    Readiness.EvidenceInputTopLevelObjectRequired -> "top-level-object-required"
    Readiness.EvidenceInputDiscriminatorInvalid -> "discriminator-invalid"
    Readiness.EvidenceInputRequiredMemberMissing -> "required-member-missing"
    Readiness.EvidenceInputUnknownMember -> "unknown-member"
    Readiness.EvidenceInputValueKindInvalid -> "value-kind-invalid"
    Readiness.EvidenceInputScalarGrammarInvalid -> "scalar-grammar-invalid"
    Readiness.EvidenceInputArrayCardinalityInvalid ->
      "array-cardinality-invalid"
    Readiness.EvidenceInputArrayDistinctnessInvalid ->
      "array-distinctness-invalid"
    Readiness.EvidenceInputNormalizationCollision -> "normalization-collision"
    Readiness.EvidenceInputModelIdentityUnicodeScalarInvalid ->
      "model-identity-unicode-scalar-invalid"
    Readiness.EvidenceInputModelIdentityContainsNul ->
      "model-identity-contains-nul"
    Readiness.EvidenceInputIdentityUnknown -> "identity-unknown"
    Readiness.EvidenceInputIdentityAmbiguous -> "identity-ambiguous"
    Readiness.EvidenceInputIdentityOutOfSelectedView ->
      "identity-out-of-selected-view"
    Readiness.EvidenceInputIdentityWrongType -> "identity-wrong-type"

observeHumanInputKind :: HumanFailure.HumanInputDefectKind -> Text
observeHumanInputKind =
  HumanFailure.foldHumanInputDefectKind
    "invalid-utf8"
    "invalid-json-syntax"
    "duplicate-object-member"
    "top-level-object-required"
    "discriminator-invalid"
    "required-member-missing"
    "unknown-member"
    "value-kind-invalid"
    "scalar-grammar-invalid"
    "array-cardinality-invalid"
    "array-distinctness-invalid"
    "normalization-collision"
    "model-identity-unicode-scalar-invalid"
    "model-identity-contains-nul"
    "identity-unknown"
    "identity-ambiguous"
    "identity-out-of-selected-view"
    "identity-wrong-type"

observeRawSupplementalInputDefect ::
     Supplemental.SupplementalInputDefect -> [Text]
observeRawSupplementalInputDefect defect =
  coreRuleIdText (Supplemental.supplementalInputDefectRule defect)
    : Supplemental.foldSupplementalInputDefect rawSupplementalEliminator defect

rawSupplementalEliminator ::
     Supplemental.SupplementalInputDefectEliminator [Text]
rawSupplementalEliminator =
  Supplemental.SupplementalInputDefectEliminator
    { Supplemental.eliminateSupplementalInvalidUtf8 =
        \evidence ->
          [ "invalid-utf8"
          , supplementalOrdinalText
              (Supplemental.supplementalInvalidUtf8InputOrdinal evidence)
          ]
    , Supplemental.eliminateSupplementalInvalidJsonSyntax =
        \evidence ->
          [ "invalid-json-syntax"
          , supplementalOrdinalText
              (Supplemental.supplementalInvalidJsonSyntaxInputOrdinal evidence)
          ]
    , Supplemental.eliminateSupplementalDuplicateObjectMember =
        \evidence ->
          [ "duplicate-object-member"
          , supplementalOrdinalText
              (Supplemental.supplementalDuplicateObjectMemberInputOrdinal
                 evidence)
          , Supplemental.supplementalDuplicateObjectMemberPointer evidence
          ]
    , Supplemental.eliminateSupplementalTopLevelObjectRequired =
        observeRawSupplementalTriple
          "top-level-object-required"
          Supplemental.supplementalTopLevelObjectInputOrdinal
          Supplemental.supplementalTopLevelObjectInstancePointer
          Supplemental.supplementalTopLevelObjectExpectedSchema
    , Supplemental.eliminateSupplementalTypeMemberInvalid =
        observeRawSupplementalTriple
          "type-member-invalid"
          Supplemental.supplementalTypeMemberInputOrdinal
          Supplemental.supplementalTypeMemberInstancePointer
          Supplemental.supplementalTypeMemberExpectedSchema
    , Supplemental.eliminateSupplementalPayloadTypeNotAdmitted =
        observeRawSupplementalTriple
          "payload-type-not-admitted"
          Supplemental.supplementalPayloadTypeNotAdmittedInputOrdinal
          Supplemental.supplementalPayloadTypeNotAdmittedInstancePointer
          Supplemental.supplementalPayloadTypeNotAdmittedExpectedSchema
    , Supplemental.eliminateSupplementalRequiredMemberMissing =
        observeRawSupplementalTriple
          "required-member-missing"
          Supplemental.supplementalRequiredMemberMissingInputOrdinal
          Supplemental.supplementalRequiredMemberMissingInstancePointer
          Supplemental.supplementalRequiredMemberMissingExpectedSchema
    , Supplemental.eliminateSupplementalUnknownMember =
        observeRawSupplementalTriple
          "unknown-member"
          Supplemental.supplementalUnknownMemberInputOrdinal
          Supplemental.supplementalUnknownMemberInstancePointer
          Supplemental.supplementalUnknownMemberExpectedSchema
    , Supplemental.eliminateSupplementalValueKindInvalid =
        observeRawSupplementalTriple
          "value-kind-invalid"
          Supplemental.supplementalValueKindInputOrdinal
          Supplemental.supplementalValueKindInstancePointer
          Supplemental.supplementalValueKindExpectedSchema
    , Supplemental.eliminateSupplementalScalarGrammarInvalid =
        observeRawSupplementalTriple
          "scalar-grammar-invalid"
          Supplemental.supplementalScalarGrammarInputOrdinal
          Supplemental.supplementalScalarGrammarInstancePointer
          Supplemental.supplementalScalarGrammarExpectedSchema
    , Supplemental.eliminateSupplementalArrayCardinalityInvalid =
        observeRawSupplementalTriple
          "array-cardinality-invalid"
          Supplemental.supplementalArrayCardinalityInputOrdinal
          Supplemental.supplementalArrayCardinalityInstancePointer
          Supplemental.supplementalArrayCardinalityExpectedSchema
    , Supplemental.eliminateSupplementalArrayDistinctnessInvalid =
        observeRawSupplementalTriple
          "array-distinctness-invalid"
          Supplemental.supplementalArrayDistinctnessInputOrdinal
          Supplemental.supplementalArrayDistinctnessInstancePointer
          Supplemental.supplementalArrayDistinctnessExpectedSchema
    , Supplemental.eliminateSupplementalSubjectCardinalityInvalid =
        \evidence ->
          ["subject-cardinality-invalid"]
            <> observeItems
                 (pure . supplementalOrdinalText)
                 (Supplemental.supplementalSubjectCardinalityFirstInputOrdinal
                    evidence
                    : NonEmpty.toList
                        (Supplemental.supplementalSubjectCardinalityRemainingInputOrdinals
                           evidence))
            <> [ observeRawSupplementalPayload
                   (Supplemental.supplementalSubjectCardinalityPayloadType
                      evidence)
               , modelIdentityText
                   (Supplemental.supplementalSubjectCardinalitySubject evidence)
               ]
    , Supplemental.eliminateSupplementalIdentityUnknown =
        observeRawSupplementalIdentity
          "identity-unknown"
          Supplemental.supplementalIdentityUnknownInputOrdinal
          Supplemental.supplementalIdentityUnknownInstancePointer
          Supplemental.supplementalIdentityUnknownModelIdentity
    , Supplemental.eliminateSupplementalIdentityAmbiguous =
        observeRawSupplementalIdentity
          "identity-ambiguous"
          Supplemental.supplementalIdentityAmbiguousInputOrdinal
          Supplemental.supplementalIdentityAmbiguousInstancePointer
          Supplemental.supplementalIdentityAmbiguousModelIdentity
    , Supplemental.eliminateSupplementalIdentityWrongType =
        observeRawSupplementalIdentity
          "identity-wrong-type"
          Supplemental.supplementalIdentityWrongTypeInputOrdinal
          Supplemental.supplementalIdentityWrongTypeInstancePointer
          Supplemental.supplementalIdentityWrongTypeModelIdentity
    , Supplemental.eliminateSupplementalIdentityOutOfSelectedView =
        observeRawSupplementalIdentity
          "identity-out-of-selected-view"
          Supplemental.supplementalIdentityOutOfViewInputOrdinal
          Supplemental.supplementalIdentityOutOfViewInstancePointer
          Supplemental.supplementalIdentityOutOfViewModelIdentity
    , Supplemental.eliminateSupplementalModelIdentityUnicodeScalarInvalid =
        \evidence ->
          [ "model-identity-unicode-scalar-invalid"
          , supplementalOrdinalText
              (Supplemental.supplementalUnicodeScalarInputOrdinal evidence)
          , Supplemental.supplementalUnicodeScalarInstancePointer evidence
          , Supplemental.supplementalUnicodeScalarExpectedSchema evidence
          ]
            <> observeItems
                 (\(Supplemental.SupplementalUnicodeScalarOccurrence index codePoint) ->
                    [naturalText index, naturalText codePoint])
                 (NonEmpty.toList
                    (Supplemental.supplementalUnicodeScalarOccurrences evidence))
    , Supplemental.eliminateSupplementalModelIdentityContainsNul =
        \evidence ->
          [ "model-identity-contains-nul"
          , supplementalOrdinalText
              (Supplemental.supplementalModelIdentityNulInputOrdinal evidence)
          , Supplemental.supplementalModelIdentityNulInstancePointer evidence
          , Supplemental.supplementalModelIdentityNulExpectedSchema evidence
          ]
            <> observeItems
                 (pure . naturalText)
                 (NonEmpty.toList
                    (Supplemental.supplementalModelIdentityNulIndexes evidence))
    }

observeRawSupplementalTriple ::
     Text
  -> (evidence -> Supplemental.SupplementalInputOrdinal)
  -> (evidence -> Text)
  -> (evidence -> Text)
  -> evidence
  -> [Text]
observeRawSupplementalTriple branch ordinal pointer schema evidence =
  [ branch
  , supplementalOrdinalText (ordinal evidence)
  , pointer evidence
  , schema evidence
  ]

observeRawSupplementalIdentity ::
     Text
  -> (evidence -> Supplemental.SupplementalInputOrdinal)
  -> (evidence -> Text)
  -> (evidence -> ModelIdentity)
  -> evidence
  -> [Text]
observeRawSupplementalIdentity branch ordinal pointer identity evidence =
  [ branch
  , supplementalOrdinalText (ordinal evidence)
  , pointer evidence
  , modelIdentityText (identity evidence)
  ]

observeRawSupplementalPayload :: Supplemental.SupplementalPayloadType -> Text
observeRawSupplementalPayload payload =
  case payload of
    Supplemental.StrategyFormulationPayload -> "strategy-formulation"
    Supplemental.CollectiveFitPayload -> "collective-fit"

observeHumanSupplementalInputDefect ::
     HumanFailure.HumanSupplementalInputDefect -> [Text]
observeHumanSupplementalInputDefect =
  HumanFailure.foldHumanSupplementalInputDefect
    (two "invalid-utf8")
    (two "invalid-json-syntax")
    (three "duplicate-object-member")
    (four "top-level-object-required")
    (four "type-member-invalid")
    (four "payload-type-not-admitted")
    (four "required-member-missing")
    (four "unknown-member")
    (four "value-kind-invalid")
    (four "scalar-grammar-invalid")
    (four "array-cardinality-invalid")
    (four "array-distinctness-invalid")
    (\rule ordinals payload subject ->
       [rule, "subject-cardinality-invalid"]
         <> observeItems (pure . naturalText) (NonEmpty.toList ordinals)
         <> [ HumanFailure.foldHumanSupplementalPayloadType
                "strategy-formulation"
                "collective-fit"
                payload
            , HumanValue.foldHumanModelIdentity id subject
            ])
    (identity "identity-unknown")
    (identity "identity-ambiguous")
    (identity "identity-wrong-type")
    (identity "identity-out-of-selected-view")
    (\rule ordinal pointer expected occurrences ->
       [ rule
       , "model-identity-unicode-scalar-invalid"
       , naturalText ordinal
       , pointer
       , expected
       ]
         <> observeItems
              (\(index, codePoint) -> [naturalText index, naturalText codePoint])
              (NonEmpty.toList occurrences))
    (\rule ordinal pointer expected indexes ->
       [ rule
       , "model-identity-contains-nul"
       , naturalText ordinal
       , pointer
       , expected
       ]
         <> observeItems (pure . naturalText) (NonEmpty.toList indexes))
  where
    two branch rule ordinal = [rule, branch, naturalText ordinal]
    three branch rule ordinal pointer =
      [rule, branch, naturalText ordinal, pointer]
    four branch rule ordinal pointer expected =
      [rule, branch, naturalText ordinal, pointer, expected]
    identity branch rule ordinal pointer value =
      [ rule
      , branch
      , naturalText ordinal
      , pointer
      , HumanValue.foldHumanModelIdentity id value
      ]

observeRawSourceIdentity :: SourceIdentity -> [Text]
observeRawSourceIdentity identity =
  [ rawSourceRoleText (sourceIdentityRole identity)
  , naturalText (sourceOrdinalValue (sourceIdentityOrdinal identity))
  , sourceReferenceText (sourceIdentityReference identity)
  , sourceSha256Text (sourceIdentitySha256 identity)
  ]

rawSourceRoleText :: SourceRole -> Text
rawSourceRoleText role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

observeHumanSourceIdentity :: HumanValue.HumanSourceIdentity -> [Text]
observeHumanSourceIdentity =
  HumanValue.foldHumanSourceIdentity $ \role ordinal reference digest ->
    [ HumanValue.foldHumanSourceRole
        "model"
        "supplemental"
        "readiness"
        "assessment"
        role
    , naturalText ordinal
    , reference
    , digest
    ]

supplementalOrdinalText :: Supplemental.SupplementalInputOrdinal -> Text
supplementalOrdinalText =
  naturalText . Supplemental.supplementalInputOrdinalValue

observeItems :: (value -> [Text]) -> [value] -> [Text]
observeItems observe values =
  "items-begin"
    : concatMap (\value -> "item-begin" : observe value <> ["item-end"]) values
        <> ["items-end"]

naturalText :: Natural -> Text
naturalText = Text.pack . show
