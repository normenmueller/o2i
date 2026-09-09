{-# LANGUAGE OverloadedStrings #-}

-- | Canonical projections of opaque Core Readiness results.
module O2I.Operation.Readiness.Machine.Internal
  ( readinessUnavailableFragment
  , readinessAssessmentFragment
  , reconstructionReasonFragment
  , readinessEvidenceKeyFragment
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Contract (coreQualifiedEndpointIdText, coreRuleIdText)
import O2I.Core.Identity (modelIdentityText, occurrenceIdentityText)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , arrayFragment
  , closedObjectFragment
  , naturalFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Readiness.Result
  ( ReadinessUnavailable
  , foldReadinessUnavailable
  )
import O2I.Operation.Trace.Machine.Internal
  ( boundEndpointsFragment
  , gapDispositionFragment
  , slotFragment
  , traceIdentityFragment
  )
import qualified O2I.Readiness as Readiness
import qualified O2I.Trace as Trace

readinessUnavailableFragment :: ReadinessUnavailable -> CanonicalFragment
readinessUnavailableFragment =
  foldReadinessUnavailable
    (\trace defects ->
       closedObjectFragment
         [ requiredMember "suppliedTraceIdentity" (traceIdentityFragment trace)
         , requiredMember "disposition" (textFragment "subject-unavailable")
         , requiredMember
             "reasons"
             (arrayFragment
                (map bindingDefectFragment (NonEmpty.toList defects)))
         ])
    (\graph trace reasons ->
       closedObjectFragment
         [ requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         , requiredMember "disposition" (textFragment "subject-unavailable")
         , requiredMember
             "reasons"
             (arrayFragment
                (map reconstructionReasonFragment (NonEmpty.toList reasons)))
         ])

readinessAssessmentFragment ::
     Readiness.ReadinessAssessment scope -> CanonicalFragment
readinessAssessmentFragment =
  Readiness.foldReadinessAssessment
    (\graph trace diagnostics ->
       closedObjectFragment
         [ requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         , requiredMember "disposition" (textFragment "not-ready")
         , requiredMember
             "diagnostics"
             (arrayFragment
                (map readinessDiagnosticFragment (NonEmpty.toList diagnostics)))
         ])
    (\proof ->
       closedObjectFragment
         [ requiredMember
             "graphIdentity"
             (textFragment
                (modelIdentityText (Readiness.evidenceReadyGraphIdentity proof)))
         , requiredMember
             "traceIdentity"
             (traceIdentityFragment (Readiness.evidenceReadyTraceIdentity proof))
         , requiredMember "disposition" (textFragment "ready")
         , requiredMember "diagnostics" (arrayFragment [])
         ])

bindingDefectFragment :: Readiness.EvidenceInputDefect -> CanonicalFragment
bindingDefectFragment defect =
  closedObjectFragment
    [ requiredMember "phase" (textFragment "binding")
    , requiredMember
        "ruleId"
        (textFragment
           (coreRuleIdText (Readiness.evidenceInputDefectRule defect)))
    , requiredMember
        "reason"
        (textFragment
           (evidenceInputDefectKindText
              (Readiness.evidenceInputDefectKind defect)))
    , requiredMember
        "jsonPointer"
        (textFragment (Readiness.evidenceInputDefectPointer defect))
    , requiredMember
        "subjects"
        (arrayFragment
           (map
              evidenceInputSubjectFragment
              (NonEmpty.toList (Readiness.evidenceInputDefectSubjects defect))))
    ]

evidenceInputDefectKindText :: Readiness.EvidenceInputDefectKind -> Text
evidenceInputDefectKindText kind =
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
    Readiness.EvidenceInputIdentityUnknown -> "unknown"
    Readiness.EvidenceInputIdentityAmbiguous -> "ambiguous"
    Readiness.EvidenceInputIdentityOutOfSelectedView -> "out-of-selected-view"
    Readiness.EvidenceInputIdentityWrongType -> "wrong-type"

evidenceInputSubjectFragment ::
     Readiness.EvidenceInputDiagnosticSubject -> CanonicalFragment
evidenceInputSubjectFragment =
  Readiness.foldEvidenceInputDiagnosticSubject
    (subject "text" textFragment)
    (subject "natural" naturalFragment)
    (subject "model-identity" (textFragment . modelIdentityText))
    (subject "occurrence-identity" (textFragment . occurrenceIdentityText))
    (subject "qualified-type" (textFragment . coreQualifiedEndpointIdText))
  where
    subject kind encode label value =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "label" (textFragment label)
        , requiredMember "value" (encode value)
        ]

reconstructionReasonFragment ::
     Readiness.ReadinessSubjectUnavailableReason -> CanonicalFragment
reconstructionReasonFragment =
  Readiness.foldReadinessSubjectUnavailableReason
    suppliedTraceReasonFragment
    promotionReasonFragment

suppliedTraceReasonFragment ::
     Trace.SuppliedTraceUnavailableReason -> CanonicalFragment
suppliedTraceReasonFragment reason =
  case reason of
    Trace.TraceGraphIdentityMismatch expected supplied ->
      closedObjectFragment
        [ requiredMember "phase" (textFragment "supplied-trace")
        , requiredMember "reason" (textFragment "graph-identity-mismatch")
        , requiredMember
            "expectedGraphIdentity"
            (textFragment (modelIdentityText expected))
        , requiredMember
            "suppliedGraphIdentity"
            (textFragment (modelIdentityText supplied))
        ]
    Trace.ExactSlotUnsupported slot endpoints disposition ->
      closedObjectFragment
        [ requiredMember "phase" (textFragment "supplied-trace")
        , requiredMember "reason" (textFragment "exact-slot-unsupported")
        , requiredMember "slot" (slotFragment slot)
        , requiredMember "endpoints" (boundEndpointsFragment endpoints)
        , requiredMember "disposition" (gapDispositionFragment disposition)
        ]

promotionReasonFragment ::
     Trace.TracePromotionUnavailableReason -> CanonicalFragment
promotionReasonFragment reason =
  closedObjectFragment
    [ requiredMember "phase" (textFragment "promotion")
    , requiredMember "reason" (textFragment (promotionReasonText reason))
    ]

promotionReasonText :: Trace.TracePromotionUnavailableReason -> Text
promotionReasonText reason =
  case reason of
    Trace.StrategyAssessmentUnavailable -> "strategy-assessment-unavailable"
    Trace.StrategyAssessmentInvalid -> "strategy-assessment-invalid"
    Trace.StrategyProofModelMismatch -> "strategy-proof-model-mismatch"
    Trace.StrategyIdentityMismatch -> "strategy-identity-mismatch"
    Trace.StrategyDiagnosisMismatch -> "strategy-diagnosis-mismatch"
    Trace.StrategyIntentMismatch -> "strategy-intent-mismatch"
    Trace.StrategyActionNotInFormulation -> "strategy-action-not-in-formulation"
    Trace.StrategyKeyResultNotInFormulation ->
      "strategy-key-result-not-in-formulation"

readinessDiagnosticFragment ::
     Readiness.ReadinessDiagnosticEvidence scope -> CanonicalFragment
readinessDiagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "ruleId"
        (textFragment
           (coreRuleIdText (Readiness.readinessDiagnosticRule diagnostic)))
    , requiredMember
        "evidenceKey"
        (readinessEvidenceKeyFragment
           (Readiness.readinessDiagnosticKey diagnostic))
    ]

readinessEvidenceKeyFragment ::
     Readiness.ReadinessEvidenceKey -> CanonicalFragment
readinessEvidenceKeyFragment =
  Readiness.foldReadinessEvidenceKey
    (\graph trace ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "readiness-subject")
         , requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         ])
    (\kpi ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "kpi-definition")
         , requiredMember "kpi" (textFragment (modelIdentityText kpi))
         ])
    (\intervention ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "planned-start")
         , requiredMember
             "intervention"
             (textFragment (modelIdentityText intervention))
         ])
    (\trace ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "evidence-plan")
         , requiredMember "trace" (traceIdentityFragment trace)
         ])
