{-# LANGUAGE OverloadedStrings #-}

-- | Canonical projections of opaque Core Assessment results.
module O2I.Operation.Assess.Machine.Internal
  ( assessUnavailableFragment
  , assessmentResultFragment
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Assessment
  ( AssessmentInputDefect
  , AssessmentLimitationKind(..)
  , AssessmentResult
  , AssessmentSubjectUnavailableReason
  , EffectResult
  , EvidenceAssessedProof
  , Observation
  , ObservationAssessment
  , TargetAttainment
  )
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract (coreQualifiedEndpointIdText, coreRuleIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Assess.Result (AssessUnavailable, foldAssessUnavailable)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , CanonicalMember
  , arrayFragment
  , closedObjectFragment
  , naturalFragment
  , nullFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Readiness.Machine.Internal
  ( readinessEvidenceKeyFragment
  , reconstructionReasonFragment
  )
import O2I.Operation.Trace.Machine.Internal (traceIdentityFragment)
import qualified O2I.Readiness as Readiness
import O2I.Trace (TraceIdentity)

assessUnavailableFragment :: AssessUnavailable -> CanonicalFragment
assessUnavailableFragment =
  foldAssessUnavailable
    (\trace defects ->
       closedObjectFragment
         [ requiredMember "suppliedTraceIdentity" (traceIdentityFragment trace)
         , requiredMember "disposition" (textFragment "subject-unavailable")
         , requiredMember
             "reasons"
             (arrayFragment
                (map assessmentInputDefectFragment (NonEmpty.toList defects)))
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
                (map
                   assessmentUnavailableReasonFragment
                   (NonEmpty.toList reasons)))
         ])

assessmentResultFragment :: AssessmentResult scope -> CanonicalFragment
assessmentResultFragment result =
  Assessment.foldAssessmentResult
    (\graph trace diagnostics ->
       closedObjectFragment
         [ requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         , requiredMember "disposition" (textFragment "collection-invalid")
         , requiredMember
             "diagnostics"
             (arrayFragment
                (map assessmentDiagnosticFragment (NonEmpty.toList diagnostics)))
         , requiredMember "observations" (arrayFragment [])
         , requiredMember "proof" nullFragment
         ])
    (completedFragment
       (Assessment.assessmentResultGraphIdentity result)
       (Assessment.assessmentResultTraceIdentity result))
    result

completedFragment ::
     ModelIdentity
  -> TraceIdentity
  -> [ObservationAssessment scope]
  -> Maybe (EvidenceAssessedProof scope)
  -> CanonicalFragment
completedFragment graph trace observations proof =
  closedObjectFragment
    [ requiredMember "graphIdentity" (textFragment (modelIdentityText graph))
    , requiredMember "traceIdentity" (traceIdentityFragment trace)
    , requiredMember
        "disposition"
        (textFragment
           (case proof of
              Nothing -> "observations-invalid"
              Just _ -> "completed"))
    , requiredMember "diagnostics" (arrayFragment [])
    , requiredMember
        "observations"
        (arrayFragment (map observationAssessmentFragment observations))
    , requiredMember "proof" (maybe nullFragment proofFragment proof)
    ]

proofFragment :: EvidenceAssessedProof scope -> CanonicalFragment
proofFragment proof =
  closedObjectFragment
    [ requiredMember
        "graphIdentity"
        (textFragment
           (modelIdentityText (Assessment.evidenceAssessedGraphIdentity proof)))
    , requiredMember
        "traceIdentity"
        (traceIdentityFragment (Assessment.evidenceAssessedTraceIdentity proof))
    , requiredMember
        "observationCount"
        (naturalFragment (Assessment.evidenceAssessedObservationCount proof))
    ]

observationAssessmentFragment ::
     ObservationAssessment scope -> CanonicalFragment
observationAssessmentFragment =
  Assessment.foldObservationAssessment
    (\observation diagnostics ->
       closedObjectFragment
         (observationMembers observation
            <> [ requiredMember
                   "disposition"
                   (textFragment "invalid-observation")
               , requiredMember
                   "diagnostics"
                   (arrayFragment
                      (map
                         assessmentDiagnosticFragment
                         (NonEmpty.toList diagnostics)))
               ]))
    (\observation effect target limitations ->
       closedObjectFragment
         (observationMembers observation
            <> [ requiredMember
                   "disposition"
                   (textFragment "assessed-observation")
               , requiredMember "effect" (effectFragment effect)
               , requiredMember "target" (targetFragment target)
               , requiredMember
                   "limitations"
                   (arrayFragment
                      (map limitationFragment (NonEmpty.toList limitations)))
               ]))

observationMembers :: Observation -> [CanonicalMember]
observationMembers observation =
  [ requiredMember
      "sourceOrdinal"
      (naturalFragment
         (Assessment.observationOrdinalValue
            (Assessment.observationOrdinal observation)))
  , requiredMember
      "traceIdentity"
      (traceIdentityFragment (Assessment.observationTraceIdentity observation))
  , requiredMember
      "observedAt"
      (textFragment
         (Readiness.utcTimestampText
            (Assessment.observationObservedAt observation)))
  , requiredMember
      "source"
      (textFragment
         (Readiness.canonicalTextValue
            (Assessment.observationSource observation)))
  , requiredMember
      "value"
      (domainValueFragment (Assessment.observationValue observation))
  ]

domainValueFragment :: Readiness.DomainValue -> CanonicalFragment
domainValueFragment =
  Readiness.foldDomainValue
    (\value unit ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "quantitative")
         , requiredMember
             "value"
             (textFragment (Readiness.canonicalDecimalText value))
         , requiredMember "unit" (textFragment (Readiness.unitText unit))
         ])
    (\scale level ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "ordinal")
         , requiredMember
             "scaleId"
             (textFragment (Readiness.canonicalTextValue scale))
         , requiredMember
             "level"
             (textFragment (Readiness.canonicalTextValue level))
         ])
    (\value ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "categorical")
         , requiredMember
             "value"
             (textFragment (Readiness.canonicalTextValue value))
         ])

effectFragment :: EffectResult -> CanonicalFragment
effectFragment =
  Assessment.foldEffectResult
    (textFragment "satisfied")
    (textFragment "not-satisfied")
    (textFragment "not-assessable-zero-baseline")

targetFragment :: TargetAttainment -> CanonicalFragment
targetFragment =
  Assessment.foldTargetAttainment
    (textFragment "satisfied-in-observation-by-due")
    (textFragment "satisfied-in-observation-after-due")
    (textFragment "not-satisfied-in-observation")

limitationFragment :: AssessmentLimitationKind -> CanonicalFragment
limitationFragment limitation =
  textFragment
    (case limitation of
       CausalityNotEstablishedLimitation -> "causality-not-established"
       FirstTargetAttainmentTimeNotEstablishedLimitation ->
         "first-target-attainment-time-not-established")

assessmentDiagnosticFragment ::
     Assessment.AssessmentDiagnosticEvidence scope -> CanonicalFragment
assessmentDiagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "ruleId"
        (textFragment
           (coreRuleIdText (Assessment.assessmentDiagnosticRule diagnostic)))
    , requiredMember
        "evidenceKey"
        (assessmentEvidenceKeyFragment
           (Assessment.assessmentDiagnosticKey diagnostic))
    ]

assessmentEvidenceKeyFragment ::
     Assessment.AssessmentEvidenceKey -> CanonicalFragment
assessmentEvidenceKeyFragment =
  Assessment.foldAssessmentEvidenceKey
    (\graph trace ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "assessment-subject")
         , requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         ])
    (\intervention ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "actual-start")
         , requiredMember
             "intervention"
             (textFragment (modelIdentityText intervention))
         ])
    (\graph trace ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "observation-set")
         , requiredMember
             "graphIdentity"
             (textFragment (modelIdentityText graph))
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         ])
    (\trace observedAt ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "observation")
         , requiredMember "traceIdentity" (traceIdentityFragment trace)
         , requiredMember
             "observedAt"
             (textFragment (Readiness.utcTimestampText observedAt))
         ])

assessmentUnavailableReasonFragment ::
     AssessmentSubjectUnavailableReason -> CanonicalFragment
assessmentUnavailableReasonFragment =
  Assessment.foldAssessmentSubjectUnavailableReason
    reconstructionReasonFragment
    (\rule key ->
       closedObjectFragment
         [ requiredMember "phase" (textFragment "readiness-criterion")
         , requiredMember
             "diagnostic"
             (closedObjectFragment
                [ requiredMember "ruleId" (textFragment (coreRuleIdText rule))
                , requiredMember
                    "evidenceKey"
                    (readinessEvidenceKeyFragment key)
                ])
         ])

assessmentInputDefectFragment :: AssessmentInputDefect -> CanonicalFragment
assessmentInputDefectFragment defect =
  closedObjectFragment
    [ requiredMember "phase" (textFragment "binding")
    , requiredMember
        "ruleId"
        (textFragment
           (coreRuleIdText (Assessment.assessmentInputDefectRule defect)))
    , requiredMember
        "reason"
        (textFragment
           (evidenceInputDefectKindText
              (Assessment.assessmentInputDefectKind defect)))
    , requiredMember
        "jsonPointer"
        (textFragment (Assessment.assessmentInputDefectPointer defect))
    , requiredMember
        "subjects"
        (arrayFragment
           (map
              evidenceInputSubjectFragment
              (NonEmpty.toList (Assessment.assessmentInputDefectSubjects defect))))
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
