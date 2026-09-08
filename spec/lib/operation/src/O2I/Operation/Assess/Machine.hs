{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for selected-View evidence assessment.
module O2I.Operation.Assess.Machine
  ( type AssessResultDocument
  , assessResultDocument
  , assessResultSchema
  , assessResultDocumentVariant
  , encodeAssessResultDocument
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Acquisition
  ( AcquiredAssessmentSource
  , AcquiredSupplementalSource
  , InputSource
  , acquiredSourceIdentity
  , foldAcquiredAssessmentSource
  , foldInputSource
  )
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Assess.Machine.Internal
  ( assessUnavailableFragment
  , assessmentResultFragment
  )
import O2I.Operation.Assess.Request (AssessRequest, foldAssessRequest)
import O2I.Operation.Assess.Result
  ( AssessExitClass
  , AssessFailure
  , AssessPrerequisite
  , AssessResult
  , PreparedAssess
  , assessExitClassText
  , assessExitCode
  , assessPrerequisiteText
  , assessPrimaryNegativeExit
  , assessSubjectUnavailableExit
  , assessSuccessExit
  , foldAssessPrerequisite
  , foldPreparedAssess
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , MachineResult(..)
  , arrayFragment
  , closedObjectFragment
  , closedOperationMachineResult
  , naturalFragment
  , nullFragment
  , reportAuthorityMember
  , requiredMember
  , textFragment
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( emptySupplementalDiagnosticGroupFragments
  , foldPreparedDiagnosticDocumentFragments
  , sourceIdentityFragment
  , viewDescriptorFragment
  )
import O2I.Operation.Report.Internal (ReportEnvelope, foldAssessReport)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.View
  ( SelectedView
  , ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )

-- | Validated canonical machine envelope for one completed result.
newtype AssessResultDocument =
  AssessResultDocument MachineResult

-- | Build the exact machine envelope for any non-operational result.
assessResultDocument ::
     ToolDescriptor -> AssessResult -> Either AssessFailure AssessResultDocument
assessResultDocument tool =
  foldAssessReport
    tool
    Left
    (\envelope stage prepared ->
       Right
         (preparedDocument
            envelope
            "prerequisite-rejected"
            assessSubjectUnavailableExit
            (Just stage)
            nullFragment
            prepared))
    (\envelope unavailable prepared ->
       Right
         (preparedDocument
            envelope
            "subject-unavailable"
            assessSubjectUnavailableExit
            Nothing
            (assessUnavailableFragment unavailable)
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "collection-invalid"
            assessPrimaryNegativeExit
            Nothing
            (assessmentResultFragment assessment)
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "observations-invalid"
            assessPrimaryNegativeExit
            Nothing
            (assessmentResultFragment assessment)
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "completed"
            assessSuccessExit
            Nothing
            (assessmentResultFragment assessment)
            prepared))

-- | Generated Schema authority for every assessment result variant.
assessResultSchema :: MachineSchema
assessResultSchema = Generated.assessResultMachineSchema

-- | Project the exact variant encoded by one validated document.
assessResultDocumentVariant :: AssessResultDocument -> SchemaVariant
assessResultDocumentVariant (AssessResultDocument result) =
  machineResultVariantValue result

-- | Encode one validated document to deterministic canonical JSON bytes.
encodeAssessResultDocument :: AssessResultDocument -> ByteString
encodeAssessResultDocument (AssessResultDocument result) =
  machineResultBytesValue result

preparedDocument ::
     ReportEnvelope
  -> Text
  -> AssessExitClass
  -> Maybe AssessPrerequisite
  -> CanonicalFragment
  -> PreparedAssess
  -> AssessResultDocument
preparedDocument envelope status classification prerequisite assessment prepared =
  foldPreparedAssess
    (\request view bundle supplements diagnostics ->
       foldPreparedDiagnosticDocumentFragments
         (\authority modelDiagnostics supplementalGroups ->
            AssessResultDocument
              (closedOperationMachineResult
                 envelope
                 [ requiredMember
                     "context"
                     (contextFragment
                        prerequisite
                        view
                        bundle
                        supplements
                        supplementalGroups
                        authority)
                 , requiredMember "request" (requestFragment request)
                 , requiredMember
                     "execution"
                     (executionFragment status classification prerequisite)
                 , requiredMember "assessment" assessment
                 , requiredMember
                     "diagnostics"
                     (diagnosticsFragment modelDiagnostics)
                 , reportAuthorityMember envelope
                 ]))
         diagnostics)
    prepared

contextFragment ::
     Maybe AssessPrerequisite
  -> SelectedView document
  -> Maybe AcquiredAssessmentSource
  -> [AcquiredSupplementalSource]
  -> [CanonicalFragment]
  -> CanonicalFragment
  -> CanonicalFragment
contextFragment prerequisite view bundle supplements supplementalGroups authority =
  closedObjectFragment
    [ requiredMember "authority" authority
    , requiredMember
        "view"
        (viewDescriptorFragment (selectedViewDescriptor view))
    , requiredMember
        "assessment"
        (maybe nullFragment acquiredAssessmentFragment bundle)
    , requiredMember "supplements" (arrayFragment selectedSupplementalGroups)
    ]
  where
    selectedSupplementalGroups =
      case prerequisite of
        Just stage ->
          foldAssessPrerequisite
            []
            []
            (emptySupplementalDiagnosticGroupFragments supplements)
            supplementalGroups
            stage
        Nothing -> supplementalGroups

acquiredAssessmentFragment :: AcquiredAssessmentSource -> CanonicalFragment
acquiredAssessmentFragment =
  foldAcquiredAssessmentSource (sourceIdentityFragment . acquiredSourceIdentity)

requestFragment :: AssessRequest -> CanonicalFragment
requestFragment =
  foldAssessRequest $ \_ selector adapter bundle supplements ->
    closedObjectFragment
      [ requiredMember "view" (viewSelectorFragment selector)
      , requiredMember
          "adapterId"
          (maybe nullFragment (textFragment . adapterIdText) adapter)
      , requiredMember "assessment" (inputSourceFragment bundle)
      , requiredMember
          "supplements"
          (arrayFragment (map inputSourceFragment supplements))
      ]

viewSelectorFragment :: ViewSelector -> CanonicalFragment
viewSelectorFragment =
  foldViewSelector (selector "name") (selector "identity" . modelIdentityText)
  where
    selector kind value =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "value" (textFragment value)
        ]

inputSourceFragment :: InputSource -> CanonicalFragment
inputSourceFragment =
  foldInputSource
    (\_ path ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "file")
         , requiredMember "path" (textFragment (Text.pack path))
         ])
    (const (closedObjectFragment [requiredMember "kind" (textFragment "stdin")]))

executionFragment ::
     Text -> AssessExitClass -> Maybe AssessPrerequisite -> CanonicalFragment
executionFragment status classification prerequisite =
  closedObjectFragment
    ([ requiredMember "status" (textFragment status)
     , requiredMember
         "exitClass"
         (textFragment (assessExitClassText classification))
     , requiredMember
         "exitCode"
         (naturalFragment (assessExitCode classification))
     ]
       <> maybe
            []
            (pure
               . requiredMember "prerequisite"
               . textFragment
               . assessPrerequisiteText)
            prerequisite)

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]
