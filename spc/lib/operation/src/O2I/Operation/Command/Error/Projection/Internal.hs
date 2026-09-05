{-# LANGUAGE OverloadedStrings #-}

-- | Private construction of the purpose-built command-error projections.
module O2I.Operation.Command.Error.Projection.Internal
  ( supplementalCommandInputDiagnostic
  , readinessCommandInputDiagnostic
  , assessmentCommandInputDiagnostic
  , validateCommandOwnerDiagnostic
  , qualifyCommandOwnerDiagnostic
  , readinessCommandOwnerDiagnostic
  , assessCommandOwnerDiagnostic
  , qualificationSubjectsCommandOwnerDiagnostic
  , traceCommandOwnerDiagnostic
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract (coreQualifiedEndpointIdText, coreRuleIdText)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , ModelIdentity
  , OccurrenceIdentity
  , OccurrenceIdentityDefect(..)
  , SelectedViewScopeDefect
  , SelectedViewScopeDefectKind(..)
  , identityIndexDefectModelIdentities
  , identityIndexDefectOccurrence
  , modelIdentityText
  , occurrenceIdentityText
  , selectedViewScopeDefectCardinality
  , selectedViewScopeDefectKind
  , selectedViewScopeDefectOccurrence
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorNotation
  , adapterDescriptorVersion
  , adapterIdText
  )
import O2I.Operation.Assess.Result
  ( AssessInternalFailure
  , foldAssessInternalFailure
  )
import O2I.Operation.Command.Error.Branch.Generated
  ( assessOwnerBranch
  , assessOwnerBranchToken
  , qualificationSubjectsOwnerBranch
  , qualificationSubjectsOwnerBranchToken
  , qualifyOwnerBranch
  , qualifyOwnerBranchToken
  , readinessOwnerBranch
  , readinessOwnerBranchToken
  , traceOwnerBranch
  , traceOwnerBranchToken
  , validateOwnerBranch
  , validateOwnerBranchToken
  )
import O2I.Operation.Diagnostic.Owner
  ( AdapterNotationResolutionFailure
  , foldAdapterNotationResolutionFailure
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , arrayFragment
  , closedObjectFragment
  , naturalFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceKey
  , SourceRole(..)
  , SupplementalProvenanceDefect
  , foldSourceIdentity
  , foldSourceKey
  , foldSupplementalProvenanceDefect
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import O2I.Operation.Qualification.Subjects.Result
  ( QualificationSubjectsInternalFailure
  , foldQualificationSubjectsInternalFailure
  )
import O2I.Operation.Qualify.Result
  ( QualifyInternalFailure
  , foldQualifyInternalFailure
  )
import O2I.Operation.Readiness.Result
  ( ReadinessInternalFailure
  , foldReadinessInternalFailure
  )
import O2I.Operation.Trace.Result
  ( TraceInternalFailure
  , foldTraceInternalFailure
  )
import O2I.Operation.Validate.Result
  ( ValidateInternalFailure
  , foldValidateInternalFailure
  )
import qualified O2I.Qualification as Qualification
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental
import qualified O2I.Structure as Structure

-- | Project all rule-specific supplemental evidence into the closed command
-- diagnostic boundary.
supplementalCommandInputDiagnostic ::
     Supplemental.SupplementalInputDefect -> CanonicalFragment
supplementalCommandInputDiagnostic =
  supplementalInputDiagnosticWith inputDiagnosticFragment

supplementalInputDiagnosticWith ::
     (Text -> NonEmpty Natural -> Text -> [CanonicalFragment] -> result)
  -> Supplemental.SupplementalInputDefect
  -> result
supplementalInputDiagnosticWith project defect =
  Supplemental.foldSupplementalInputDefect eliminator defect
  where
    rule = coreRuleIdText (Supplemental.supplementalInputDefectRule defect)
    exact reason ordinal fields =
      project
        rule
        (Supplemental.supplementalInputOrdinalValue ordinal :| [])
        reason
        fields
    schema reason ordinal pointer expected =
      exact
        reason
        ordinal
        [textField "jsonPointer" pointer, textField "expectedSchema" expected]
    identity reason ordinal pointer identifier =
      exact
        reason
        ordinal
        [ textField "jsonPointer" pointer
        , modelIdentityField "identity" identifier
        ]
    eliminator =
      Supplemental.SupplementalInputDefectEliminator
        { Supplemental.eliminateSupplementalInvalidUtf8 =
            \value ->
              exact
                "invalid-utf8"
                (Supplemental.supplementalInvalidUtf8InputOrdinal value)
                []
        , Supplemental.eliminateSupplementalInvalidJsonSyntax =
            \value ->
              exact
                "invalid-json-syntax"
                (Supplemental.supplementalInvalidJsonSyntaxInputOrdinal value)
                []
        , Supplemental.eliminateSupplementalDuplicateObjectMember =
            \value ->
              exact
                "duplicate-object-member"
                (Supplemental.supplementalDuplicateObjectMemberInputOrdinal
                   value)
                [ textField
                    "jsonPointer"
                    (Supplemental.supplementalDuplicateObjectMemberPointer value)
                ]
        , Supplemental.eliminateSupplementalTopLevelObjectRequired =
            \value ->
              schema
                "top-level-object-required"
                (Supplemental.supplementalTopLevelObjectInputOrdinal value)
                (Supplemental.supplementalTopLevelObjectInstancePointer value)
                (Supplemental.supplementalTopLevelObjectExpectedSchema value)
        , Supplemental.eliminateSupplementalTypeMemberInvalid =
            \value ->
              schema
                "type-member-invalid"
                (Supplemental.supplementalTypeMemberInputOrdinal value)
                (Supplemental.supplementalTypeMemberInstancePointer value)
                (Supplemental.supplementalTypeMemberExpectedSchema value)
        , Supplemental.eliminateSupplementalPayloadTypeNotAdmitted =
            \value ->
              schema
                "payload-type-not-admitted"
                (Supplemental.supplementalPayloadTypeNotAdmittedInputOrdinal
                   value)
                (Supplemental.supplementalPayloadTypeNotAdmittedInstancePointer
                   value)
                (Supplemental.supplementalPayloadTypeNotAdmittedExpectedSchema
                   value)
        , Supplemental.eliminateSupplementalRequiredMemberMissing =
            \value ->
              schema
                "required-member-missing"
                (Supplemental.supplementalRequiredMemberMissingInputOrdinal
                   value)
                (Supplemental.supplementalRequiredMemberMissingInstancePointer
                   value)
                (Supplemental.supplementalRequiredMemberMissingExpectedSchema
                   value)
        , Supplemental.eliminateSupplementalUnknownMember =
            \value ->
              schema
                "unknown-member"
                (Supplemental.supplementalUnknownMemberInputOrdinal value)
                (Supplemental.supplementalUnknownMemberInstancePointer value)
                (Supplemental.supplementalUnknownMemberExpectedSchema value)
        , Supplemental.eliminateSupplementalValueKindInvalid =
            \value ->
              schema
                "value-kind-invalid"
                (Supplemental.supplementalValueKindInputOrdinal value)
                (Supplemental.supplementalValueKindInstancePointer value)
                (Supplemental.supplementalValueKindExpectedSchema value)
        , Supplemental.eliminateSupplementalScalarGrammarInvalid =
            \value ->
              schema
                "scalar-grammar-invalid"
                (Supplemental.supplementalScalarGrammarInputOrdinal value)
                (Supplemental.supplementalScalarGrammarInstancePointer value)
                (Supplemental.supplementalScalarGrammarExpectedSchema value)
        , Supplemental.eliminateSupplementalArrayCardinalityInvalid =
            \value ->
              schema
                "array-cardinality-invalid"
                (Supplemental.supplementalArrayCardinalityInputOrdinal value)
                (Supplemental.supplementalArrayCardinalityInstancePointer value)
                (Supplemental.supplementalArrayCardinalityExpectedSchema value)
        , Supplemental.eliminateSupplementalArrayDistinctnessInvalid =
            \value ->
              schema
                "array-distinctness-invalid"
                (Supplemental.supplementalArrayDistinctnessInputOrdinal value)
                (Supplemental.supplementalArrayDistinctnessInstancePointer value)
                (Supplemental.supplementalArrayDistinctnessExpectedSchema value)
        , Supplemental.eliminateSupplementalSubjectCardinalityInvalid =
            \value ->
              project
                rule
                (fmap
                   Supplemental.supplementalInputOrdinalValue
                   (Supplemental.supplementalSubjectCardinalityFirstInputOrdinal
                      value
                      :| NonEmpty.toList
                           (Supplemental.supplementalSubjectCardinalityRemainingInputOrdinals
                              value)))
                "subject-cardinality-invalid"
                [ textField
                    "payloadType"
                    (supplementalPayloadTypeText
                       (Supplemental.supplementalSubjectCardinalityPayloadType
                          value))
                , modelIdentityField
                    "subject"
                    (Supplemental.supplementalSubjectCardinalitySubject value)
                ]
        , Supplemental.eliminateSupplementalIdentityUnknown =
            \value ->
              identity
                "identity-unknown"
                (Supplemental.supplementalIdentityUnknownInputOrdinal value)
                (Supplemental.supplementalIdentityUnknownInstancePointer value)
                (Supplemental.supplementalIdentityUnknownModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityAmbiguous =
            \value ->
              identity
                "identity-ambiguous"
                (Supplemental.supplementalIdentityAmbiguousInputOrdinal value)
                (Supplemental.supplementalIdentityAmbiguousInstancePointer value)
                (Supplemental.supplementalIdentityAmbiguousModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityWrongType =
            \value ->
              identity
                "identity-wrong-type"
                (Supplemental.supplementalIdentityWrongTypeInputOrdinal value)
                (Supplemental.supplementalIdentityWrongTypeInstancePointer value)
                (Supplemental.supplementalIdentityWrongTypeModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityOutOfSelectedView =
            \value ->
              identity
                "identity-out-of-selected-view"
                (Supplemental.supplementalIdentityOutOfViewInputOrdinal value)
                (Supplemental.supplementalIdentityOutOfViewInstancePointer value)
                (Supplemental.supplementalIdentityOutOfViewModelIdentity value)
        , Supplemental.eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            \value ->
              exact
                "model-identity-unicode-scalar-invalid"
                (Supplemental.supplementalUnicodeScalarInputOrdinal value)
                [ textField
                    "jsonPointer"
                    (Supplemental.supplementalUnicodeScalarInstancePointer value)
                , textField
                    "expectedSchema"
                    (Supplemental.supplementalUnicodeScalarExpectedSchema value)
                , fieldFragment
                    "unicodeScalars"
                    (map
                       unicodeScalarValueFragment
                       (NonEmpty.toList
                          (Supplemental.supplementalUnicodeScalarOccurrences
                             value)))
                ]
        , Supplemental.eliminateSupplementalModelIdentityContainsNul =
            \value ->
              exact
                "model-identity-contains-nul"
                (Supplemental.supplementalModelIdentityNulInputOrdinal value)
                [ textField
                    "jsonPointer"
                    (Supplemental.supplementalModelIdentityNulInstancePointer
                       value)
                , textField
                    "expectedSchema"
                    (Supplemental.supplementalModelIdentityNulExpectedSchema
                       value)
                , fieldFragment
                    "nulIndexes"
                    (map
                       (scalarValueFragment "natural" naturalFragment)
                       (NonEmpty.toList
                          (Supplemental.supplementalModelIdentityNulIndexes
                             value)))
                ]
        }

-- | Project one complete Readiness-input diagnostic.
readinessCommandInputDiagnostic ::
     Readiness.EvidenceInputDefect -> CanonicalFragment
readinessCommandInputDiagnostic defect =
  evidenceCommandInputDiagnostic
    (coreRuleIdText (Readiness.evidenceInputDefectRule defect))
    (Readiness.readinessInputOrdinalValue
       (Readiness.evidenceInputDefectOrdinal defect))
    (Readiness.evidenceInputDefectKind defect)
    (Readiness.evidenceInputDefectPointer defect)
    (Readiness.evidenceInputDefectSubjects defect)

-- | Project one complete Assessment-input diagnostic.
assessmentCommandInputDiagnostic ::
     Assessment.AssessmentInputDefect -> CanonicalFragment
assessmentCommandInputDiagnostic defect =
  evidenceCommandInputDiagnostic
    (coreRuleIdText (Assessment.assessmentInputDefectRule defect))
    (Assessment.assessmentInputOrdinalValue
       (Assessment.assessmentInputDefectOrdinal defect))
    (Assessment.assessmentInputDefectKind defect)
    (Assessment.assessmentInputDefectPointer defect)
    (Assessment.assessmentInputDefectSubjects defect)

-- | Project every Validate owner-contract branch with retained evidence.
validateCommandOwnerDiagnostic :: ValidateInternalFailure -> CanonicalFragment
validateCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (validateOwnerBranchToken (validateOwnerBranch failure))
    (foldValidateInternalFailure
       sourceOwnerEvidence
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       semanticOwnerEvidence
       failure)

-- | Project every Qualify owner-contract branch with retained evidence.
qualifyCommandOwnerDiagnostic :: QualifyInternalFailure -> CanonicalFragment
qualifyCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (qualifyOwnerBranchToken (qualifyOwnerBranch failure))
    (foldQualifyInternalFailure
       sourceOwnerEvidence
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       (\_ -> oneOwnerEvidence "semantic-graph-mismatch" [])
       failure)

-- | Project every Readiness owner-contract branch with retained evidence.
readinessCommandOwnerDiagnostic :: ReadinessInternalFailure -> CanonicalFragment
readinessCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (readinessOwnerBranchToken (readinessOwnerBranch failure))
    (foldReadinessInternalFailure
       sourceOwnerEvidence
       sourceOwnerEvidence
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       semanticOwnerEvidence
       failure)

-- | Project every Assess owner-contract branch with retained evidence.
assessCommandOwnerDiagnostic :: AssessInternalFailure -> CanonicalFragment
assessCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (assessOwnerBranchToken (assessOwnerBranch failure))
    (foldAssessInternalFailure
       sourceOwnerEvidence
       sourceOwnerEvidence
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       semanticOwnerEvidence
       failure)

-- | Project every QualificationSubjects owner-contract branch with retained
-- evidence.
qualificationSubjectsCommandOwnerDiagnostic ::
     QualificationSubjectsInternalFailure -> CanonicalFragment
qualificationSubjectsCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (qualificationSubjectsOwnerBranchToken
       (qualificationSubjectsOwnerBranch failure))
    (foldQualificationSubjectsInternalFailure
       sourceOwnerEvidence
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       qualificationContextOwnerEvidence
       occurrenceProjectionOwnerEvidence
       occurrenceJoinOwnerEvidence
       failure)

-- | Project every Trace owner-contract branch with retained evidence.
traceCommandOwnerDiagnostic :: TraceInternalFailure -> CanonicalFragment
traceCommandOwnerDiagnostic failure =
  ownerFailureFragment
    (traceOwnerBranchToken (traceOwnerBranch failure))
    (foldTraceInternalFailure
       sourceOwnerEvidence
       adapterOwnerEvidence
       notationOwnerEvidence
       profileOwnerEvidenceOccurrences
       identityOwnerEvidenceOccurrences
       scopeOwnerEvidenceOccurrences
       structureOwnerEvidenceOccurrences
       provenanceOwnerEvidenceOccurrences
       supplementalInputOwnerEvidenceOccurrences
       semanticOwnerEvidence
       failure)

qualificationContextOwnerEvidence ::
     Qualification.QualificationContextError -> NonEmpty CanonicalFragment
qualificationContextOwnerEvidence context =
  case context of
    Qualification.QualificationSemanticGraphMismatch ->
      oneOwnerEvidence "semantic-graph-mismatch" []

occurrenceProjectionOwnerEvidence ::
     Notation.CanonicalOccurrence
  -> OccurrenceIdentityDefect
  -> NonEmpty CanonicalFragment
occurrenceProjectionOwnerEvidence occurrence defect =
  oneOwnerEvidence
    "impossible-occurrence-identity"
    [ fieldFragment "occurrence" [canonicalOccurrenceValue occurrence]
    , textField "details" (occurrenceIdentityDefectText defect)
    ]

occurrenceJoinOwnerEvidence ::
     OccurrenceIdentity
  -> [Notation.CanonicalOccurrence]
  -> NonEmpty CanonicalFragment
occurrenceJoinOwnerEvidence occurrence candidates =
  oneOwnerEvidence
    "occurrence-join-mismatch"
    [ occurrenceIdentityField "occurrence" occurrence
    , fieldFragment "candidates" (map canonicalOccurrenceValue candidates)
    ]

occurrenceIdentityDefectText :: OccurrenceIdentityDefect -> Text
occurrenceIdentityDefectText defect =
  case defect of
    EmptyOccurrenceIdentity -> "empty"
    OccurrenceIdentityContainsU0000 -> "contains-u0000"
    OccurrenceIdentityContainsSurrogate -> "contains-surrogate"

sourceOwnerEvidence :: SourceIdentity -> NonEmpty CanonicalFragment
sourceOwnerEvidence identity =
  oneOwnerEvidence
    "source-identity"
    [fieldFragment "source" [sourceIdentityValue identity]]

adapterOwnerEvidence :: AdapterDescriptor -> NonEmpty CanonicalFragment
adapterOwnerEvidence descriptor =
  oneOwnerEvidence
    "adapter-descriptor"
    [fieldFragment "adapter" [adapterDescriptorValue descriptor]]

notationOwnerEvidence ::
     AdapterNotationResolutionFailure -> NonEmpty CanonicalFragment
notationOwnerEvidence =
  foldAdapterNotationResolutionFailure
    (\authority contract ->
       oneOwnerEvidence
         "adapter-authority-mismatch"
         [ fieldFragment "authorityAdapter" [adapterDescriptorValue authority]
         , fieldFragment "contractAdapter" [adapterDescriptorValue contract]
         ])
    (\descriptor kind ->
       oneOwnerEvidence
         "adapter-notation-rule-missing"
         [ fieldFragment "adapter" [adapterDescriptorValue descriptor]
         , textField
             "notationIssueKind"
             (Notation.archiMateNotationIssueKindToken kind)
         ])

profileOwnerEvidenceOccurrences ::
     NonEmpty (Profile.ProfileContractEvidence profile document)
  -> NonEmpty CanonicalFragment
profileOwnerEvidenceOccurrences = fmap profileOwnerEvidence

profileOwnerEvidence ::
     Profile.ProfileContractEvidence profile document -> CanonicalFragment
profileOwnerEvidence =
  Profile.foldProfileContractEvidence
    (\rule kind ->
       ownerEvidenceFragment
         "unknown-generated-profile-rule"
         [ textField "ruleId" rule
         , textField "evidenceKind" (profileEvidenceKindText kind)
         ])
    (\rule kind ->
       ownerEvidenceFragment
         "generated-profile-evidence-mismatch"
         [ textField "ruleId" rule
         , textField "evidenceKind" (profileEvidenceKindText kind)
         ])
    (\binding occurrence ->
       ownerEvidenceFragment
         "missing-core-contract-binding"
         [ textField "binding" binding
         , fieldFragment "occurrence" [canonicalOccurrenceValue occurrence]
         ])
    (\occurrence details ->
       ownerEvidenceFragment
         "impossible-occurrence-identity"
         [ fieldFragment "occurrence" [canonicalOccurrenceValue occurrence]
         , textField "details" details
         ])

identityOwnerEvidenceOccurrences ::
     NonEmpty IdentityIndexDefect -> NonEmpty CanonicalFragment
identityOwnerEvidenceOccurrences = fmap identityOwnerEvidence

identityOwnerEvidence :: IdentityIndexDefect -> CanonicalFragment
identityOwnerEvidence defect =
  ownerEvidenceFragment
    "duplicate-model-identity"
    [ occurrenceIdentityField
        "occurrence"
        (identityIndexDefectOccurrence defect)
    , fieldFragment
        "modelIdentities"
        (map
           (scalarValueFragment "model-identity" textFragment
              . modelIdentityText)
           (NonEmpty.toList (identityIndexDefectModelIdentities defect)))
    ]

scopeOwnerEvidenceOccurrences ::
     NonEmpty SelectedViewScopeDefect -> NonEmpty CanonicalFragment
scopeOwnerEvidenceOccurrences = fmap scopeOwnerEvidence

scopeOwnerEvidence :: SelectedViewScopeDefect -> CanonicalFragment
scopeOwnerEvidence defect =
  ownerEvidenceFragment
    (selectedViewScopeDefectKindText (selectedViewScopeDefectKind defect))
    [ occurrenceIdentityField
        "occurrence"
        (selectedViewScopeDefectOccurrence defect)
    , fieldFragment
        "cardinality"
        [ scalarValueFragment
            "natural"
            naturalFragment
            (fromIntegral (selectedViewScopeDefectCardinality defect))
        ]
    ]

structureOwnerEvidenceOccurrences ::
     NonEmpty Structure.StructureInputDefect -> NonEmpty CanonicalFragment
structureOwnerEvidenceOccurrences = fmap structureOwnerEvidence

structureOwnerEvidence :: Structure.StructureInputDefect -> CanonicalFragment
structureOwnerEvidence defect =
  case defect of
    Structure.ProjectionOutsideSelectedView occurrence ->
      ownerEvidenceFragment
        "projection-outside-selected-view"
        [occurrenceIdentityField "occurrence" occurrence]
    Structure.DuplicateStructureProjection occurrence kinds ->
      ownerEvidenceFragment
        "duplicate-structure-projection"
        [ occurrenceIdentityField "occurrence" occurrence
        , fieldFragment
            "projectionKinds"
            (map
               (scalarValueFragment "text" textFragment
                  . structureProjectionKindText)
               (NonEmpty.toList kinds))
        ]
    Structure.MissingCarrierProjection owner role endpoint ->
      ownerEvidenceFragment
        "missing-carrier-projection"
        [ occurrenceIdentityField "owner" owner
        , textField "endpointRole" (structureEndpointRoleText role)
        , occurrenceIdentityField "endpoint" endpoint
        ]
    Structure.MissingStructuredPropositionProjection proposition occurrence ->
      ownerEvidenceFragment
        "missing-structured-proposition-projection"
        [ occurrenceIdentityField "proposition" proposition
        , occurrenceIdentityField "occurrence" occurrence
        ]

provenanceOwnerEvidenceOccurrences ::
     NonEmpty SupplementalProvenanceDefect -> NonEmpty CanonicalFragment
provenanceOwnerEvidenceOccurrences = fmap provenanceOwnerEvidence

provenanceOwnerEvidence :: SupplementalProvenanceDefect -> CanonicalFragment
provenanceOwnerEvidence =
  foldSupplementalProvenanceDefect
    (\identity ->
       ownerEvidenceFragment
         "model-source-is-not-supplemental"
         [fieldFragment "source" [sourceIdentityValue identity]])
    (\key identities ->
       ownerEvidenceFragment
         "duplicate-supplemental-source"
         [ fieldFragment "sourceKey" [sourceKeyValue key]
         , fieldFragment
             "sources"
             (map sourceIdentityValue (NonEmpty.toList identities))
         ])

supplementalInputOwnerEvidenceOccurrences ::
     NonEmpty Supplemental.SupplementalInputDefect -> NonEmpty CanonicalFragment
supplementalInputOwnerEvidenceOccurrences = fmap supplementalInputOwnerEvidence

supplementalInputOwnerEvidence ::
     Supplemental.SupplementalInputDefect -> CanonicalFragment
supplementalInputOwnerEvidence =
  supplementalInputDiagnosticWith $ \rule ordinals reason fields ->
    ownerEvidenceFragment
      reason
      (textField "ruleId" rule
         : fieldFragment
             "inputOrdinals"
             (map
                (scalarValueFragment "natural" naturalFragment)
                (NonEmpty.toList ordinals))
         : fields)

semanticOwnerEvidence :: [OccurrenceIdentity] -> NonEmpty CanonicalFragment
semanticOwnerEvidence occurrences =
  oneOwnerEvidence
    "semantic-occurrences"
    [ fieldFragment
        "occurrences"
        (map
           (scalarValueFragment "occurrence-identity" textFragment
              . occurrenceIdentityText)
           occurrences)
    ]

evidenceCommandInputDiagnostic ::
     Text
  -> Natural
  -> Readiness.EvidenceInputDefectKind
  -> Text
  -> NonEmpty Readiness.EvidenceInputDiagnosticSubject
  -> CanonicalFragment
evidenceCommandInputDiagnostic rule ordinal kind pointer subjects =
  inputDiagnosticFragment
    rule
    (ordinal :| [])
    (evidenceInputDefectKindText kind)
    (textField "jsonPointer" pointer
       : map evidenceInputSubjectField (NonEmpty.toList subjects))

evidenceInputSubjectField ::
     Readiness.EvidenceInputDiagnosticSubject -> CanonicalFragment
evidenceInputSubjectField =
  Readiness.foldEvidenceInputDiagnosticSubject
    (\label value ->
       fieldFragment label [scalarValueFragment "text" textFragment value])
    (\label value ->
       fieldFragment label [scalarValueFragment "natural" naturalFragment value])
    modelIdentityField
    occurrenceIdentityField
    (\label value ->
       fieldFragment
         label
         [ scalarValueFragment
             "qualified-type"
             textFragment
             (coreQualifiedEndpointIdText value)
         ])

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
    Readiness.EvidenceInputIdentityUnknown -> "identity-unknown"
    Readiness.EvidenceInputIdentityAmbiguous -> "identity-ambiguous"
    Readiness.EvidenceInputIdentityOutOfSelectedView ->
      "identity-out-of-selected-view"
    Readiness.EvidenceInputIdentityWrongType -> "identity-wrong-type"

inputDiagnosticFragment ::
     Text
  -> NonEmpty Natural
  -> Text
  -> [CanonicalFragment]
  -> CanonicalFragment
inputDiagnosticFragment rule ordinals reason fields =
  closedObjectFragment
    [ requiredMember "ruleId" (textFragment rule)
    , requiredMember
        "inputOrdinals"
        (arrayFragment (map naturalFragment (NonEmpty.toList ordinals)))
    , requiredMember "reason" (textFragment reason)
    , requiredMember "fields" (arrayFragment fields)
    ]

ownerFailureFragment :: Text -> NonEmpty CanonicalFragment -> CanonicalFragment
ownerFailureFragment branch evidence =
  closedObjectFragment
    [ requiredMember "category" (textFragment "owner-contract")
    , requiredMember "branch" (textFragment branch)
    , requiredMember "evidence" (arrayFragment (NonEmpty.toList evidence))
    ]

ownerEvidenceFragment :: Text -> [CanonicalFragment] -> CanonicalFragment
ownerEvidenceFragment kind fields =
  closedObjectFragment
    [ requiredMember "kind" (textFragment kind)
    , requiredMember "fields" (arrayFragment fields)
    ]

fieldFragment :: Text -> [CanonicalFragment] -> CanonicalFragment
fieldFragment name values =
  closedObjectFragment
    [ requiredMember "name" (textFragment name)
    , requiredMember "values" (arrayFragment values)
    ]

scalarValueFragment ::
     Text -> (value -> CanonicalFragment) -> value -> CanonicalFragment
scalarValueFragment kind project value =
  closedObjectFragment
    [ requiredMember "kind" (textFragment kind)
    , requiredMember "value" (project value)
    ]

unicodeScalarValueFragment ::
     Supplemental.SupplementalUnicodeScalarOccurrence -> CanonicalFragment
unicodeScalarValueFragment occurrence =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "unicode-scalar")
    , requiredMember
        "index"
        (naturalFragment
           (Supplemental.supplementalUnicodeScalarIndex occurrence))
    , requiredMember
        "codePoint"
        (naturalFragment
           (Supplemental.supplementalUnicodeScalarCodePoint occurrence))
    ]

oneOwnerEvidence :: Text -> [CanonicalFragment] -> NonEmpty CanonicalFragment
oneOwnerEvidence kind fields = ownerEvidenceFragment kind fields :| []

textField :: Text -> Text -> CanonicalFragment
textField name value =
  fieldFragment name [scalarValueFragment "text" textFragment value]

modelIdentityField :: Text -> ModelIdentity -> CanonicalFragment
modelIdentityField name identity =
  fieldFragment
    name
    [ scalarValueFragment
        "model-identity"
        textFragment
        (modelIdentityText identity)
    ]

occurrenceIdentityField :: Text -> OccurrenceIdentity -> CanonicalFragment
occurrenceIdentityField name identity =
  fieldFragment
    name
    [ scalarValueFragment
        "occurrence-identity"
        textFragment
        (occurrenceIdentityText identity)
    ]

supplementalPayloadTypeText :: Supplemental.SupplementalPayloadType -> Text
supplementalPayloadTypeText payloadType =
  case payloadType of
    Supplemental.StrategyFormulationPayload -> "strategy-formulation"
    Supplemental.CollectiveFitPayload -> "collective-fit"

sourceKeyValue :: SourceKey -> CanonicalFragment
sourceKeyValue =
  foldSourceKey $ \role ordinal ->
    closedObjectFragment
      [ requiredMember "kind" (textFragment "source-key")
      , requiredMember "role" (textFragment (sourceRoleText role))
      , requiredMember "ordinal" (naturalFragment (sourceOrdinalValue ordinal))
      ]

sourceIdentityValue :: SourceIdentity -> CanonicalFragment
sourceIdentityValue =
  foldSourceIdentity $ \role ordinal reference digest ->
    closedObjectFragment
      [ requiredMember "kind" (textFragment "source-identity")
      , requiredMember "role" (textFragment (sourceRoleText role))
      , requiredMember "ordinal" (naturalFragment (sourceOrdinalValue ordinal))
      , requiredMember
          "reference"
          (textFragment (sourceReferenceText reference))
      , requiredMember "sha256" (textFragment (sourceSha256Text digest))
      ]

sourceRoleText :: SourceRole -> Text
sourceRoleText role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

adapterDescriptorValue :: AdapterDescriptor -> CanonicalFragment
adapterDescriptorValue descriptor =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "adapter-descriptor")
    , requiredMember
        "id"
        (textFragment (adapterIdText (adapterDescriptorId descriptor)))
    , requiredMember "name" (textFragment (adapterDescriptorName descriptor))
    , requiredMember
        "version"
        (textFragment (adapterDescriptorVersion descriptor))
    , requiredMember
        "notation"
        (textFragment (adapterDescriptorNotation descriptor))
    ]

canonicalOccurrenceValue :: Notation.CanonicalOccurrence -> CanonicalFragment
canonicalOccurrenceValue occurrence =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "canonical-occurrence")
    , requiredMember
        "occurrenceKind"
        (textFragment
           (Notation.foldCanonicalOccurrenceKind
              "record"
              "property"
              "reference"
              (Notation.canonicalOccurrenceKind occurrence)))
    , requiredMember
        "ordinal"
        (naturalFragment (Notation.canonicalOccurrenceOrdinal occurrence))
    ]

profileEvidenceKindText :: Profile.ProfileEvidenceKind -> Text
profileEvidenceKindText =
  Profile.foldProfileEvidenceKind
    "carrier-occurrence"
    "classification-occurrence"
    "metadata-owner-and-o2i-property-occurrences"
    "property-occurrence-evidence"
    "property-slot-evidence"
    "property-value-evidence"
    "proposal-carrier-occurrence"
    "proposal-reference-incidence"
    "relationship-occurrence"
    "reserved-property-occurrence"
    "structured-carrier-occurrence"
    "structured-incidence"

selectedViewScopeDefectKindText :: SelectedViewScopeDefectKind -> Text
selectedViewScopeDefectKindText kind =
  case kind of
    UnknownSelectedViewSubjectOccurrence ->
      "unknown-selected-view-subject-occurrence"
    SelectedViewSubjectIdentityMismatch ->
      "selected-view-subject-identity-mismatch"
    UnknownSelectedViewOccurrence -> "unknown-selected-view-occurrence"
    DuplicateSelectedViewOccurrence -> "duplicate-selected-view-occurrence"

structureProjectionKindText :: Structure.StructureProjectionKind -> Text
structureProjectionKindText kind =
  case kind of
    Structure.CarrierProjectionKind -> "carrier"
    Structure.ContextualizationProjectionKind -> "contextualization"
    Structure.RelationProjectionKind -> "relation"
    Structure.StructuredPropositionProjectionKind -> "structured-proposition"
    Structure.StructuredIncidenceProjectionKind -> "structured-incidence"

structureEndpointRoleText :: Structure.StructureEndpointRole -> Text
structureEndpointRoleText role =
  case role of
    Structure.RelationSourceRole -> "relation-source"
    Structure.RelationTargetRole -> "relation-target"
    Structure.ContextualizationOwnerRole -> "contextualization-owner"
    Structure.ContextualizationMemberRole -> "contextualization-member"
    Structure.StructuredIncidenceEndpointRole -> "structured-incidence-endpoint"
