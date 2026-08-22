{-# LANGUAGE OverloadedStrings #-}

-- | Capability-neutral canonical fragments shared by Operation reports.
module O2I.Operation.Machine.Fragment.Internal
  ( acquisitionFailureFragment
  , adapterDescriptorFragment
  , adapterDiagnosticFragment
  , adapterSelectionErrorFragment
  , sourceIdentityFragment
  , draftLocationFragment
  , draftValueKindFragment
  , draftScalarFragment
  , canonicalOccurrenceFragment
  , diagnosticFragment
  , viewDescriptorFragment
  ) where

import Control.Exception (IOException, displayException)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Draft
  ( DraftFieldValue
  , DraftLocation
  , DraftNativeName
  , DraftPathStep
  , DraftScalar
  , DraftSourcePosition
  , DraftSourceSpan
  , DraftValueKind
  , draftLocationPath
  , draftLocationSpan
  , draftNativeLocalName
  , draftNativeNamespace
  , draftPathStepName
  , draftPathStepOrdinal
  , draftScalarLocation
  , draftSourceColumn
  , draftSourceLine
  , draftSourceOffset
  , draftSpanEnd
  , draftSpanStart
  , foldDraftFieldValue
  , foldDraftScalarValue
  , foldDraftSourcePath
  , foldDraftValueKind
  )
import O2I.ArchiMate.Profile.Notation
  ( CanonicalField
  , CanonicalOccurrence
  , CanonicalView
  , IdentityInvalidReason
  , IdentityOutcome
  , canonicalFieldKind
  , canonicalFieldLocation
  , canonicalFieldScalars
  , canonicalOccurrenceKind
  , canonicalOccurrenceOrdinal
  , canonicalViewIdentity
  , canonicalViewLocation
  , canonicalViewNameFields
  , canonicalViewOccurrence
  , foldCanonicalOccurrenceKind
  , foldIdentityInvalidReason
  , foldIdentityOutcome
  )
import O2I.ArchiMate.Profile.Rule.Explanation
  ( profileRuleId
  , profileRuleIdText
  , profileRuleProfileReference
  )
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity (modelIdentityText, occurrenceIdentityText)
import O2I.Core.Rule.Catalog (coreRuleIdentity)
import O2I.Operation.Acquisition
  ( AcquisitionFailure
  , foldAcquisitionFailure
  , foldInputSource
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterOccurrence
  , AdapterRule
  , AdapterSelectionError
  , NativeLocation
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorNotation
  , adapterDescriptorVersion
  , adapterDiagnosticOccurrences
  , adapterDiagnosticRule
  , adapterIdText
  , adapterRuleAction
  , adapterRuleExpectation
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleMeaning
  , adapterRuleStage
  , adapterRuleStageText
  , foldAdapterOccurrence
  , foldAdapterSelectionError
  , foldNativeLocation
  )
import O2I.Operation.Diagnostic
  ( Diagnostic
  , DiagnosticOccurrence
  , DiagnosticProvenance
  , diagnosticDisposition
  , diagnosticDispositionText
  , diagnosticOccurrences
  , diagnosticProvenance
  , diagnosticSeverity
  , diagnosticSeverityText
  , foldDiagnosticOccurrence
  , foldDiagnosticProvenance
  , foldOwnerEvidenceProvenance
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , arrayFragment
  , booleanFragment
  , closedObjectFragment
  , naturalFragment
  , nullFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(..)
  , foldSourceIdentity
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import O2I.Operation.Rule.Catalog (operationRuleIdText, operationRuleIdentity)

adapterDescriptorFragment :: AdapterDescriptor -> CanonicalFragment
adapterDescriptorFragment descriptor =
  closedObjectFragment
    [ requiredMember
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

adapterDiagnosticFragment :: AdapterDiagnostic -> CanonicalFragment
adapterDiagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "rule"
        (adapterRuleFragment (adapterDiagnosticRule diagnostic))
    , requiredMember
        "occurrences"
        (arrayFragment
           (fmap
              adapterOccurrenceFragment
              (NonEmpty.toList (adapterDiagnosticOccurrences diagnostic))))
    ]

adapterSelectionErrorFragment :: AdapterSelectionError -> CanonicalFragment
adapterSelectionErrorFragment =
  foldAdapterSelectionError
    (\identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "unknown-adapter")
         , requiredMember "adapterId" (textFragment (adapterIdText identifier))
         ])
    (\failures ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "recognition-failed")
         , requiredMember
             "failures"
             (arrayFragment
                [ closedObjectFragment
                  [ requiredMember "adapter" (adapterDescriptorFragment adapter)
                  , requiredMember
                      "diagnostics"
                      (arrayFragment
                         (fmap
                            adapterDiagnosticFragment
                            (NonEmpty.toList diagnostics)))
                  ]
                | (adapter, diagnostics) <- NonEmpty.toList failures
                ])
         ])
    (closedObjectFragment [requiredMember "kind" (textFragment "no-match")])
    (\descriptors ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "multiple-matches")
         , requiredMember
             "adapters"
             (arrayFragment
                (fmap adapterDescriptorFragment (NonEmpty.toList descriptors)))
         ])

acquisitionFailureFragment :: AcquisitionFailure -> CanonicalFragment
acquisitionFailureFragment =
  foldAcquisitionFailure $ \source exception ->
    foldInputSource
      (\reference _ ->
         sourceFailureFragment "file" (sourceReferenceText reference) exception)
      (\reference ->
         sourceFailureFragment "stdin" (sourceReferenceText reference) exception)
      source

sourceIdentityFragment :: SourceIdentity -> CanonicalFragment
sourceIdentityFragment =
  foldSourceIdentity $ \role ordinal reference digest ->
    closedObjectFragment
      [ requiredMember "role" (textFragment (sourceRoleText role))
      , requiredMember "ordinal" (naturalFragment (sourceOrdinalValue ordinal))
      , requiredMember
          "reference"
          (textFragment (sourceReferenceText reference))
      , requiredMember "sha256" (textFragment (sourceSha256Text digest))
      ]

-- | Encode the common rule-owned diagnostic contract in canonical order.
diagnosticFragment :: Diagnostic -> CanonicalFragment
diagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "severity"
        (textFragment (diagnosticSeverityText (diagnosticSeverity diagnostic)))
    , requiredMember
        "disposition"
        (textFragment
           (diagnosticDispositionText (diagnosticDisposition diagnostic)))
    , requiredMember
        "provenance"
        (diagnosticProvenanceFragment (diagnosticProvenance diagnostic))
    , requiredMember
        "occurrences"
        (arrayFragment
           (fmap
              diagnosticOccurrenceFragment
              (NonEmpty.toList (diagnosticOccurrences diagnostic))))
    ]

-- | Encode the exact locator of the compiled owning rule. Stable code,
-- authority, and stage are derived from this closed owner branch and its
-- catalog rule rather than repeated as independently variable fields.
diagnosticProvenanceFragment :: DiagnosticProvenance -> CanonicalFragment
diagnosticProvenanceFragment =
  foldDiagnosticProvenance
    (ownedRule "operation" [] . operationRuleIdText . operationRuleIdentity)
    (\descriptor rule ->
       ownedRule
         "adapter"
         [ requiredMember
             "adapterId"
             (textFragment (adapterIdText (adapterDescriptorId descriptor)))
         ]
         (adapterRuleIdText (adapterRuleId rule)))
    (\rule ->
       ownedRule
         "profile"
         [ requiredMember
             "profileReference"
             (textFragment (profileRuleProfileReference rule))
         ]
         (profileRuleIdText (profileRuleId rule)))
    (ownedRule "core" [] . coreRuleIdText . coreRuleIdentity)
    ownerEvidenceRule
  where
    ownedRule owner members ruleIdentity =
      closedObjectFragment
        ([requiredMember "owner" (textFragment owner)]
           <> members
           <> [requiredMember "ruleId" (textFragment ruleIdentity)])
    ownerEvidenceRule ownerEvidence =
      foldOwnerEvidenceProvenance
        (\reference ruleIdentity ->
           ownedRule
             "profile"
             [requiredMember "profileReference" (textFragment reference)]
             ruleIdentity)
        (ownedRule "core" [] . coreRuleIdText)
        (ownedRule "core" [] . coreRuleIdText)
        (ownedRule "core" [] . coreRuleIdText)
        ownerEvidence

diagnosticOccurrenceFragment :: DiagnosticOccurrence -> CanonicalFragment
diagnosticOccurrenceFragment =
  foldDiagnosticOccurrence
    (withSource "source" [])
    (\source occurrence ->
       withSource
         "native"
         [requiredMember "location" (adapterOccurrenceFragment occurrence)]
         source)
    (\source location ->
       withSource
         "draft"
         [requiredMember "location" (draftLocationFragment location)]
         source)
    (\source occurrence ->
       withSource
         "canonical"
         [requiredMember "occurrence" (canonicalOccurrenceFragment occurrence)]
         source)
    (\source subject ->
       withSource
         "subject"
         [requiredMember "identity" (textFragment (modelIdentityText subject))]
         source)
    (\source occurrence ->
       withSource
         "occurrence"
         [ requiredMember
             "identity"
             (textFragment (occurrenceIdentityText occurrence))
         ]
         source)
  where
    withSource kind members source =
      closedObjectFragment
        ([ requiredMember "kind" (textFragment kind)
         , requiredMember "source" (sourceIdentityFragment source)
         ]
           <> members)

viewDescriptorFragment :: CanonicalView document -> CanonicalFragment
viewDescriptorFragment descriptor =
  closedObjectFragment
    [ requiredMember
        "occurrence"
        (canonicalOccurrenceFragment (canonicalViewOccurrence descriptor))
    , requiredMember
        "identity"
        (identityOutcomeFragment (canonicalViewIdentity descriptor))
    , requiredMember
        "nameFields"
        (arrayFragment
           (fmap canonicalFieldFragment (canonicalViewNameFields descriptor)))
    , requiredMember
        "location"
        (draftLocationFragment (canonicalViewLocation descriptor))
    ]

adapterRuleFragment :: AdapterRule -> CanonicalFragment
adapterRuleFragment rule =
  closedObjectFragment
    [ requiredMember
        "id"
        (textFragment (adapterRuleIdText (adapterRuleId rule)))
    , requiredMember
        "stage"
        (textFragment (adapterRuleStageText (adapterRuleStage rule)))
    , requiredMember "expectation" (textFragment (adapterRuleExpectation rule))
    , requiredMember "meaning" (textFragment (adapterRuleMeaning rule))
    , requiredMember "action" (textFragment (adapterRuleAction rule))
    ]

adapterOccurrenceFragment :: AdapterOccurrence -> CanonicalFragment
adapterOccurrenceFragment =
  foldAdapterOccurrence nullFragment nativeLocationFragment

nativeLocationFragment :: NativeLocation -> CanonicalFragment
nativeLocationFragment =
  foldNativeLocation
    (\offset ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "byte-offset")
         , requiredMember "offset" (naturalFragment offset)
         ])
    (\line column ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "line-column")
         , requiredMember "line" (naturalFragment line)
         , requiredMember "column" (naturalFragment column)
         ])
    (\steps ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "path")
         , requiredMember
             "steps"
             (arrayFragment (fmap textFragment (NonEmpty.toList steps)))
         ])

sourceFailureFragment :: Text -> Text -> IOException -> CanonicalFragment
sourceFailureFragment kind reference exception =
  closedObjectFragment
    [ requiredMember "sourceKind" (textFragment kind)
    , requiredMember "sourceReference" (textFragment reference)
    , requiredMember
        "message"
        (textFragment (Text.pack (displayException exception)))
    ]

sourceRoleText :: SourceRole -> Text
sourceRoleText role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

canonicalOccurrenceFragment :: CanonicalOccurrence -> CanonicalFragment
canonicalOccurrenceFragment occurrence =
  closedObjectFragment
    [ requiredMember
        "kind"
        (textFragment
           (foldCanonicalOccurrenceKind
              "record"
              "property"
              "reference"
              (canonicalOccurrenceKind occurrence)))
    , requiredMember
        "ordinal"
        (naturalFragment (canonicalOccurrenceOrdinal occurrence))
    ]

identityOutcomeFragment :: IdentityOutcome -> CanonicalFragment
identityOutcomeFragment =
  foldIdentityOutcome
    (closedObjectFragment [requiredMember "kind" (textFragment "missing")])
    (\scalars ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "multiple")
         , requiredMember
             "values"
             (arrayFragment (fmap draftScalarFragment scalars))
         ])
    (\scalar reason ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "invalid")
         , requiredMember "value" (draftScalarFragment scalar)
         , requiredMember "reason" (identityInvalidReasonFragment reason)
         ])
    (\scalar identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "resolved")
         , requiredMember "value" (draftScalarFragment scalar)
         , requiredMember
             "identity"
             (textFragment (modelIdentityText identifier))
         ])

identityInvalidReasonFragment :: IdentityInvalidReason -> CanonicalFragment
identityInvalidReasonFragment =
  foldIdentityInvalidReason
    (\kind ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "non-text")
         , requiredMember "observedKind" (draftValueKindFragment kind)
         ])
    (closedObjectFragment [requiredMember "kind" (textFragment "empty")])
    (closedObjectFragment [requiredMember "kind" (textFragment "u0000")])
    (closedObjectFragment [requiredMember "kind" (textFragment "surrogate")])

canonicalFieldFragment :: CanonicalField -> CanonicalFragment
canonicalFieldFragment field =
  closedObjectFragment
    [ requiredMember "kind" (draftFieldValueFragment (canonicalFieldKind field))
    , requiredMember
        "values"
        (arrayFragment (fmap draftScalarFragment (canonicalFieldScalars field)))
    , requiredMember
        "location"
        (draftLocationFragment (canonicalFieldLocation field))
    ]

draftFieldValueFragment :: DraftFieldValue -> CanonicalFragment
draftFieldValueFragment =
  textFragment
    . foldDraftFieldValue
        "type"
        "name"
        "documentation"
        "directed"
        "influence-strength"

draftScalarFragment :: DraftScalar -> CanonicalFragment
draftScalarFragment scalar =
  closedObjectFragment
    [ requiredMember
        "value"
        (foldDraftScalarValue
           (scalarValue "text" . textFragment)
           (scalarValue "boolean" . booleanFragment)
           (scalarValue "number" . textFragment)
           (scalarValue "native-name" . draftNativeNameFragment)
           (\kind value ->
              closedObjectFragment
                [ requiredMember "kind" (textFragment "other")
                , requiredMember "nativeKind" (textFragment kind)
                , requiredMember "value" (textFragment value)
                ])
           scalar)
    , requiredMember
        "location"
        (draftLocationFragment (draftScalarLocation scalar))
    ]
  where
    scalarValue kind value =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "value" value
        ]

draftValueKindFragment :: DraftValueKind -> CanonicalFragment
draftValueKindFragment =
  textFragment . foldDraftValueKind "text" "boolean" "number" "native-name" id

draftNativeNameFragment :: DraftNativeName -> CanonicalFragment
draftNativeNameFragment name =
  closedObjectFragment
    [ requiredMember
        "namespace"
        (maybe nullFragment textFragment (draftNativeNamespace name))
    , requiredMember "localName" (textFragment (draftNativeLocalName name))
    ]

draftLocationFragment :: DraftLocation -> CanonicalFragment
draftLocationFragment location =
  closedObjectFragment
    [ requiredMember
        "path"
        (foldDraftSourcePath
           (\first rest ->
              arrayFragment (fmap draftPathStepFragment (first : rest)))
           (draftLocationPath location))
    , requiredMember
        "span"
        (maybe nullFragment draftSourceSpanFragment (draftLocationSpan location))
    ]

draftPathStepFragment :: DraftPathStep -> CanonicalFragment
draftPathStepFragment step =
  closedObjectFragment
    [ requiredMember "name" (draftNativeNameFragment (draftPathStepName step))
    , requiredMember "ordinal" (naturalFragment (draftPathStepOrdinal step))
    ]

draftSourceSpanFragment :: DraftSourceSpan -> CanonicalFragment
draftSourceSpanFragment sourceSpan =
  closedObjectFragment
    [ requiredMember
        "start"
        (draftSourcePositionFragment (draftSpanStart sourceSpan))
    , requiredMember
        "end"
        (draftSourcePositionFragment (draftSpanEnd sourceSpan))
    ]

draftSourcePositionFragment :: DraftSourcePosition -> CanonicalFragment
draftSourcePositionFragment position =
  closedObjectFragment
    [ requiredMember "line" (naturalFragment (draftSourceLine position))
    , requiredMember "column" (naturalFragment (draftSourceColumn position))
    , requiredMember
        "offset"
        (maybe nullFragment naturalFragment (draftSourceOffset position))
    ]
