{-# LANGUAGE OverloadedStrings #-}

-- | Concrete canonical projections shared only by Discovery machine documents.
module O2I.Operation.Discovery.Machine.Internal
  ( adapterDescriptorFragment
  , adapterDiagnosticFragment
  , adapterSelectionErrorFragment
  , acquisitionFailureFragment
  , profileDiscoveryRowFragment
  , profileDiscoveryDefectFragment
  , ruleAuthorityFragment
  , discoveredRuleFragment
  , ruleDiscoveryDefectFragment
  , sourceIdentityFragment
  , viewDiscoveryAuthorityFragment
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
  , IdentityInvalidReason
  , IdentityOutcome
  , ViewDescriptor
  , canonicalFieldKind
  , canonicalFieldLocation
  , canonicalFieldScalars
  , canonicalOccurrenceKind
  , canonicalOccurrenceOrdinal
  , foldCanonicalOccurrenceKind
  , foldIdentityInvalidReason
  , foldIdentityOutcome
  , viewDescriptorIdentity
  , viewDescriptorLocation
  , viewDescriptorNameFields
  , viewDescriptorOccurrence
  )
import O2I.Core.Identity (modelIdentityText)
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
import O2I.Operation.Discovery.Profile
  ( ProfileDiscoveryDefect
  , ProfileDiscoveryRow
  , foldProfileDiscoveryDefect
  , foldProfileDiscoveryRow
  )
import O2I.Operation.Discovery.Rule
  ( DiscoveredRule
  , RuleAuthority
  , RuleContractBinding
  , RuleDiscoveryDefect
  , foldDiscoveredRule
  , foldRuleAuthority
  , foldRuleContractBinding
  , foldRuleDiscoveryDefect
  , ruleAuthorityText
  )
import O2I.Operation.Discovery.View
  ( ViewDiscoveryAuthority
  , foldViewDiscoveryAuthority
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

profileDiscoveryRowFragment :: ProfileDiscoveryRow -> CanonicalFragment
profileDiscoveryRowFragment =
  foldProfileDiscoveryRow $ \identity token version notation adapters digest ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "token" (textFragment token)
      , requiredMember "reference" (textFragment (identity <> "@" <> token))
      , requiredMember "version" (textFragment version)
      , requiredMember "notation" (textFragment notation)
      , requiredMember
          "adapterIds"
          (arrayFragment (fmap textFragment (NonEmpty.toList adapters)))
      , requiredMember "contractDigest" (textFragment digest)
      ]

profileDiscoveryDefectFragment :: ProfileDiscoveryDefect -> CanonicalFragment
profileDiscoveryDefectFragment =
  foldProfileDiscoveryDefect
    (\reference ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "missing-adapter-id")
         , requiredMember "profileReference" (textFragment reference)
         ])
    (\reference identifier ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "duplicate-adapter-id")
         , requiredMember "profileReference" (textFragment reference)
         , requiredMember "adapterId" (textFragment identifier)
         ])

ruleAuthorityFragment :: RuleAuthority -> CanonicalFragment
ruleAuthorityFragment authority =
  foldRuleAuthority
    (authorityFragment "operation" Nothing)
    (authorityFragment "core" Nothing)
    (\reference -> authorityFragment "profile" (Just reference))
    (\identifier ->
       authorityFragment "adapter" (Just (adapterIdText identifier)))
    authority
  where
    authorityFragment kind subject binding =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "label" (textFragment (ruleAuthorityText authority))
        , requiredMember "subject" (maybe nullFragment textFragment subject)
        , requiredMember "contract" (ruleContractBindingFragment binding)
        ]

discoveredRuleFragment :: DiscoveredRule -> CanonicalFragment
discoveredRuleFragment =
  foldDiscoveredRule $ \_ identity stage expectation meaning action ->
    closedObjectFragment
      [ requiredMember "id" (textFragment identity)
      , requiredMember "stage" (textFragment stage)
      , requiredMember "expectation" (textFragment expectation)
      , requiredMember "meaning" (textFragment meaning)
      , requiredMember "action" (textFragment action)
      ]

ruleDiscoveryDefectFragment :: RuleDiscoveryDefect -> CanonicalFragment
ruleDiscoveryDefectFragment =
  foldRuleDiscoveryDefect
    (\expectedReference actualReference expectedDigest actualDigest ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "profile-catalog-mismatch")
         , requiredMember "expectedReference" (textFragment expectedReference)
         , requiredMember "actualReference" (textFragment actualReference)
         , requiredMember "expectedDigest" (textFragment expectedDigest)
         , requiredMember "actualDigest" (textFragment actualDigest)
         ])
    (\authority identity ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "duplicate-rule-id")
         , requiredMember "authority" (textFragment authority)
         , requiredMember "ruleId" (textFragment identity)
         ])

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

viewDiscoveryAuthorityFragment :: ViewDiscoveryAuthority -> CanonicalFragment
viewDiscoveryAuthorityFragment =
  foldViewDiscoveryAuthority
    (closedObjectFragment [requiredMember "kind" (textFragment "operation")])
    (\identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "adapter")
         , requiredMember "adapterId" (textFragment (adapterIdText identifier))
         ])

viewDescriptorFragment :: ViewDescriptor -> CanonicalFragment
viewDescriptorFragment descriptor =
  closedObjectFragment
    [ requiredMember
        "occurrence"
        (canonicalOccurrenceFragment (viewDescriptorOccurrence descriptor))
    , requiredMember
        "identity"
        (identityOutcomeFragment (viewDescriptorIdentity descriptor))
    , requiredMember
        "nameFields"
        (arrayFragment
           (fmap canonicalFieldFragment (viewDescriptorNameFields descriptor)))
    , requiredMember
        "location"
        (draftLocationFragment (viewDescriptorLocation descriptor))
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
        (textFragment (fromStringText (displayException exception)))
    ]

ruleContractBindingFragment :: RuleContractBinding -> CanonicalFragment
ruleContractBindingFragment =
  foldRuleContractBinding $ \identity version digest ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "version" (textFragment version)
      , requiredMember "digest" (maybe nullFragment textFragment digest)
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

fromStringText :: String -> Text
fromStringText = Text.pack
