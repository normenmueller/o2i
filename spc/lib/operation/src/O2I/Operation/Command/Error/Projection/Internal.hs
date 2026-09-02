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
  ( CommandOwnerBranch(..)
  , assessOwnerBranch
  , qualifyOwnerBranch
  , readinessOwnerBranch
  , validateOwnerBranch
  )
import O2I.Operation.Command.Error.Internal
import O2I.Operation.Diagnostic.Owner
  ( AdapterNotationResolutionFailure
  , foldAdapterNotationResolutionFailure
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
import O2I.Operation.Qualify.Result
  ( QualifyInternalFailure
  , foldQualifyInternalFailure
  )
import O2I.Operation.Readiness.Result
  ( ReadinessInternalFailure
  , foldReadinessInternalFailure
  )
import O2I.Operation.Validate.Result
  ( ValidateInternalFailure
  , foldValidateInternalFailure
  )
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental
import qualified O2I.Structure as Structure

-- | Project all rule-specific supplemental evidence into the closed command
-- diagnostic boundary.
supplementalCommandInputDiagnostic ::
     Supplemental.SupplementalInputDefect -> CommandInputDiagnostic
supplementalCommandInputDiagnostic defect =
  Supplemental.foldSupplementalInputDefect eliminator defect
  where
    rule = coreRuleIdText (Supplemental.supplementalInputDefectRule defect)
    exact reason ordinal fields =
      CommandInputDiagnostic
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
              CommandInputDiagnostic
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
                , CommandDiagnosticField
                    "unicodeScalars"
                    (map
                       (\occurrence ->
                          CommandDiagnosticUnicodeScalar
                            (Supplemental.supplementalUnicodeScalarIndex
                               occurrence)
                            (Supplemental.supplementalUnicodeScalarCodePoint
                               occurrence))
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
                , CommandDiagnosticField
                    "nulIndexes"
                    (map
                       CommandDiagnosticNatural
                       (NonEmpty.toList
                          (Supplemental.supplementalModelIdentityNulIndexes
                             value)))
                ]
        }

-- | Project one complete Readiness-input diagnostic.
readinessCommandInputDiagnostic ::
     Readiness.EvidenceInputDefect -> CommandInputDiagnostic
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
     Assessment.AssessmentInputDefect -> CommandInputDiagnostic
assessmentCommandInputDiagnostic defect =
  evidenceCommandInputDiagnostic
    (coreRuleIdText (Assessment.assessmentInputDefectRule defect))
    (Assessment.assessmentInputOrdinalValue
       (Assessment.assessmentInputDefectOrdinal defect))
    (Assessment.assessmentInputDefectKind defect)
    (Assessment.assessmentInputDefectPointer defect)
    (Assessment.assessmentInputDefectSubjects defect)

-- | Project every Validate owner-contract branch with retained evidence.
validateCommandOwnerDiagnostic ::
     ValidateInternalFailure -> CommandOwnerDiagnostic
validateCommandOwnerDiagnostic failure =
  CommandOwnerDiagnostic
    (ValidateCommandOwnerBranch (validateOwnerBranch failure))
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
qualifyCommandOwnerDiagnostic ::
     QualifyInternalFailure -> CommandOwnerDiagnostic
qualifyCommandOwnerDiagnostic failure =
  CommandOwnerDiagnostic
    (QualifyCommandOwnerBranch (qualifyOwnerBranch failure))
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
readinessCommandOwnerDiagnostic ::
     ReadinessInternalFailure -> CommandOwnerDiagnostic
readinessCommandOwnerDiagnostic failure =
  CommandOwnerDiagnostic
    (ReadinessCommandOwnerBranch (readinessOwnerBranch failure))
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
assessCommandOwnerDiagnostic :: AssessInternalFailure -> CommandOwnerDiagnostic
assessCommandOwnerDiagnostic failure =
  CommandOwnerDiagnostic
    (AssessCommandOwnerBranch (assessOwnerBranch failure))
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

sourceOwnerEvidence :: SourceIdentity -> NonEmpty CommandOwnerEvidence
sourceOwnerEvidence identity =
  oneOwnerEvidence
    "source-identity"
    [CommandDiagnosticField "source" [sourceIdentityValue identity]]

adapterOwnerEvidence :: AdapterDescriptor -> NonEmpty CommandOwnerEvidence
adapterOwnerEvidence descriptor =
  oneOwnerEvidence
    "adapter-descriptor"
    [CommandDiagnosticField "adapter" [adapterDescriptorValue descriptor]]

notationOwnerEvidence ::
     AdapterNotationResolutionFailure -> NonEmpty CommandOwnerEvidence
notationOwnerEvidence =
  foldAdapterNotationResolutionFailure
    (\authority contract ->
       oneOwnerEvidence
         "adapter-authority-mismatch"
         [ CommandDiagnosticField
             "authorityAdapter"
             [adapterDescriptorValue authority]
         , CommandDiagnosticField
             "contractAdapter"
             [adapterDescriptorValue contract]
         ])
    (\descriptor kind ->
       oneOwnerEvidence
         "adapter-notation-rule-missing"
         [ CommandDiagnosticField "adapter" [adapterDescriptorValue descriptor]
         , textField
             "notationIssueKind"
             (Notation.archiMateNotationIssueKindToken kind)
         ])

profileOwnerEvidenceOccurrences ::
     NonEmpty (Profile.ProfileContractEvidence profile document)
  -> NonEmpty CommandOwnerEvidence
profileOwnerEvidenceOccurrences = fmap profileOwnerEvidence

profileOwnerEvidence ::
     Profile.ProfileContractEvidence profile document -> CommandOwnerEvidence
profileOwnerEvidence =
  Profile.foldProfileContractEvidence
    (\rule kind ->
       CommandOwnerEvidence
         "unknown-generated-profile-rule"
         [ textField "ruleId" rule
         , textField "evidenceKind" (profileEvidenceKindText kind)
         ])
    (\rule kind ->
       CommandOwnerEvidence
         "generated-profile-evidence-mismatch"
         [ textField "ruleId" rule
         , textField "evidenceKind" (profileEvidenceKindText kind)
         ])
    (\binding occurrence ->
       CommandOwnerEvidence
         "missing-core-contract-binding"
         [ textField "binding" binding
         , CommandDiagnosticField
             "occurrence"
             [canonicalOccurrenceValue occurrence]
         ])
    (\occurrence details ->
       CommandOwnerEvidence
         "impossible-occurrence-identity"
         [ CommandDiagnosticField
             "occurrence"
             [canonicalOccurrenceValue occurrence]
         , textField "details" details
         ])

identityOwnerEvidenceOccurrences ::
     NonEmpty IdentityIndexDefect -> NonEmpty CommandOwnerEvidence
identityOwnerEvidenceOccurrences = fmap identityOwnerEvidence

identityOwnerEvidence :: IdentityIndexDefect -> CommandOwnerEvidence
identityOwnerEvidence defect =
  CommandOwnerEvidence
    "duplicate-model-identity"
    [ occurrenceIdentityField
        "occurrence"
        (identityIndexDefectOccurrence defect)
    , CommandDiagnosticField
        "modelIdentities"
        (map
           (CommandDiagnosticModelIdentity . modelIdentityText)
           (NonEmpty.toList (identityIndexDefectModelIdentities defect)))
    ]

scopeOwnerEvidenceOccurrences ::
     NonEmpty SelectedViewScopeDefect -> NonEmpty CommandOwnerEvidence
scopeOwnerEvidenceOccurrences = fmap scopeOwnerEvidence

scopeOwnerEvidence :: SelectedViewScopeDefect -> CommandOwnerEvidence
scopeOwnerEvidence defect =
  CommandOwnerEvidence
    (selectedViewScopeDefectKindText (selectedViewScopeDefectKind defect))
    [ occurrenceIdentityField
        "occurrence"
        (selectedViewScopeDefectOccurrence defect)
    , CommandDiagnosticField
        "cardinality"
        [ CommandDiagnosticNatural
            (fromIntegral (selectedViewScopeDefectCardinality defect))
        ]
    ]

structureOwnerEvidenceOccurrences ::
     NonEmpty Structure.StructureInputDefect -> NonEmpty CommandOwnerEvidence
structureOwnerEvidenceOccurrences = fmap structureOwnerEvidence

structureOwnerEvidence :: Structure.StructureInputDefect -> CommandOwnerEvidence
structureOwnerEvidence defect =
  case defect of
    Structure.ProjectionOutsideSelectedView occurrence ->
      CommandOwnerEvidence
        "projection-outside-selected-view"
        [occurrenceIdentityField "occurrence" occurrence]
    Structure.DuplicateStructureProjection occurrence kinds ->
      CommandOwnerEvidence
        "duplicate-structure-projection"
        [ occurrenceIdentityField "occurrence" occurrence
        , CommandDiagnosticField
            "projectionKinds"
            (map
               (CommandDiagnosticText . structureProjectionKindText)
               (NonEmpty.toList kinds))
        ]
    Structure.MissingCarrierProjection owner role endpoint ->
      CommandOwnerEvidence
        "missing-carrier-projection"
        [ occurrenceIdentityField "owner" owner
        , textField "endpointRole" (structureEndpointRoleText role)
        , occurrenceIdentityField "endpoint" endpoint
        ]
    Structure.MissingStructuredPropositionProjection proposition occurrence ->
      CommandOwnerEvidence
        "missing-structured-proposition-projection"
        [ occurrenceIdentityField "proposition" proposition
        , occurrenceIdentityField "occurrence" occurrence
        ]

provenanceOwnerEvidenceOccurrences ::
     NonEmpty SupplementalProvenanceDefect -> NonEmpty CommandOwnerEvidence
provenanceOwnerEvidenceOccurrences = fmap provenanceOwnerEvidence

provenanceOwnerEvidence :: SupplementalProvenanceDefect -> CommandOwnerEvidence
provenanceOwnerEvidence =
  foldSupplementalProvenanceDefect
    (\identity ->
       CommandOwnerEvidence
         "model-source-is-not-supplemental"
         [CommandDiagnosticField "source" [sourceIdentityValue identity]])
    (\key identities ->
       CommandOwnerEvidence
         "duplicate-supplemental-source"
         [ CommandDiagnosticField "sourceKey" [sourceKeyValue key]
         , CommandDiagnosticField
             "sources"
             (map sourceIdentityValue (NonEmpty.toList identities))
         ])

semanticOwnerEvidence :: [OccurrenceIdentity] -> NonEmpty CommandOwnerEvidence
semanticOwnerEvidence occurrences =
  oneOwnerEvidence
    "semantic-occurrences"
    [ CommandDiagnosticField
        "occurrences"
        (map
           (CommandDiagnosticOccurrenceIdentity . occurrenceIdentityText)
           occurrences)
    ]

evidenceCommandInputDiagnostic ::
     Text
  -> Natural
  -> Readiness.EvidenceInputDefectKind
  -> Text
  -> NonEmpty Readiness.EvidenceInputDiagnosticSubject
  -> CommandInputDiagnostic
evidenceCommandInputDiagnostic rule ordinal kind pointer subjects =
  CommandInputDiagnostic
    rule
    (ordinal :| [])
    (evidenceInputDefectKindText kind)
    (textField "jsonPointer" pointer
       : map evidenceInputSubjectField (NonEmpty.toList subjects))

evidenceInputSubjectField ::
     Readiness.EvidenceInputDiagnosticSubject -> CommandDiagnosticField
evidenceInputSubjectField =
  Readiness.foldEvidenceInputDiagnosticSubject
    (\label value -> CommandDiagnosticField label [CommandDiagnosticText value])
    (\label value ->
       CommandDiagnosticField label [CommandDiagnosticNatural value])
    modelIdentityField
    occurrenceIdentityField
    (\label value ->
       CommandDiagnosticField
         label
         [CommandDiagnosticQualifiedType (coreQualifiedEndpointIdText value)])

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

oneOwnerEvidence ::
     Text -> [CommandDiagnosticField] -> NonEmpty CommandOwnerEvidence
oneOwnerEvidence kind fields = CommandOwnerEvidence kind fields :| []

textField :: Text -> Text -> CommandDiagnosticField
textField name value = CommandDiagnosticField name [CommandDiagnosticText value]

modelIdentityField :: Text -> ModelIdentity -> CommandDiagnosticField
modelIdentityField name identity =
  CommandDiagnosticField
    name
    [CommandDiagnosticModelIdentity (modelIdentityText identity)]

occurrenceIdentityField :: Text -> OccurrenceIdentity -> CommandDiagnosticField
occurrenceIdentityField name identity =
  CommandDiagnosticField
    name
    [CommandDiagnosticOccurrenceIdentity (occurrenceIdentityText identity)]

supplementalPayloadTypeText :: Supplemental.SupplementalPayloadType -> Text
supplementalPayloadTypeText payloadType =
  case payloadType of
    Supplemental.StrategyFormulationPayload -> "strategy-formulation"
    Supplemental.CollectiveFitPayload -> "collective-fit"

sourceKeyValue :: SourceKey -> CommandDiagnosticValue
sourceKeyValue =
  foldSourceKey $ \role ordinal ->
    CommandDiagnosticSourceKey
      (sourceRoleText role)
      (sourceOrdinalValue ordinal)

sourceIdentityValue :: SourceIdentity -> CommandDiagnosticValue
sourceIdentityValue =
  foldSourceIdentity $ \role ordinal reference digest ->
    CommandDiagnosticSourceIdentity
      (sourceRoleText role)
      (sourceOrdinalValue ordinal)
      (sourceReferenceText reference)
      (sourceSha256Text digest)

sourceRoleText :: SourceRole -> Text
sourceRoleText role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

adapterDescriptorValue :: AdapterDescriptor -> CommandDiagnosticValue
adapterDescriptorValue descriptor =
  CommandDiagnosticAdapterDescriptor
    (adapterIdText (adapterDescriptorId descriptor))
    (adapterDescriptorName descriptor)
    (adapterDescriptorVersion descriptor)
    (adapterDescriptorNotation descriptor)

canonicalOccurrenceValue ::
     Notation.CanonicalOccurrence -> CommandDiagnosticValue
canonicalOccurrenceValue occurrence =
  CommandDiagnosticCanonicalOccurrence
    (Notation.foldCanonicalOccurrenceKind
       "record"
       "property"
       "reference"
       (Notation.canonicalOccurrenceKind occurrence))
    (Notation.canonicalOccurrenceOrdinal occurrence)

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
