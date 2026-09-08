{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for selected-View formal qualification.
module O2I.Operation.Qualify.Machine
  ( type QualifyResultDocument
  , qualifyResultDocument
  , qualifyResultSchema
  , qualifyResultDocumentVariant
  , encodeQualifyResultDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , InputSource
  , foldInputSource
  )
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , MachineResult(..)
  , arrayFragment
  , closedObjectFragment
  , closedOperationMachineResult
  , nullFragment
  , reportAuthorityMember
  , requiredMember
  , textFragment
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( emptySupplementalDiagnosticGroupFragments
  , foldPreparedDiagnosticDocumentFragments
  , viewDescriptorFragment
  )
import O2I.Operation.Qualify.Machine.Internal (qualificationAssessmentFragment)
import O2I.Operation.Qualify.Request (QualifyRequest, foldQualifyRequest)
import O2I.Operation.Qualify.Result
  ( PreparedQualify
  , QualifyFailure
  , QualifyPrerequisite
  , QualifyResult
  , foldPreparedQualify
  , foldQualifyPrerequisite
  , qualifyPrerequisiteText
  )
import O2I.Operation.Report.Internal (ReportEnvelope, foldQualifyReport)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.View
  ( SelectedView
  , ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )

-- | One immutable prepared Qualify result document.
newtype QualifyResultDocument =
  QualifyResultDocument MachineResult

-- | Preserve command failures or close one prepared terminal document.
qualifyResultDocument ::
     ToolDescriptor
  -> QualifyResult
  -> Either QualifyFailure QualifyResultDocument
qualifyResultDocument tool =
  foldQualifyReport
    tool
    Left
    (\envelope stage prepared ->
       Right
         (preparedDocument
            envelope
            "prerequisite-rejected"
            (Just stage)
            nullFragment
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "completed"
            Nothing
            (qualificationAssessmentFragment assessment)
            prepared))

-- | Exact generated Schema authority.
qualifyResultSchema :: MachineSchema
qualifyResultSchema = Generated.qualifyResultMachineSchema

-- | Exact terminal constructor discriminator.
qualifyResultDocumentVariant :: QualifyResultDocument -> SchemaVariant
qualifyResultDocumentVariant (QualifyResultDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeQualifyResultDocument :: QualifyResultDocument -> ByteString
encodeQualifyResultDocument (QualifyResultDocument result) =
  machineResultBytesValue result

preparedDocument ::
     ReportEnvelope
  -> Text
  -> Maybe QualifyPrerequisite
  -> CanonicalFragment
  -> PreparedQualify
  -> QualifyResultDocument
preparedDocument envelope status prerequisite qualificationFragment prepared =
  foldPreparedQualify
    (\request view acquired diagnostics ->
       foldPreparedDiagnosticDocumentFragments
         (\authority modelDiagnostics supplementalGroups ->
            QualifyResultDocument
              (closedOperationMachineResult
                 envelope
                 [ requiredMember
                     "context"
                     (contextFragment
                        prerequisite
                        view
                        acquired
                        supplementalGroups
                        authority)
                 , requiredMember "request" (requestFragment request)
                 , requiredMember
                     "execution"
                     (executionFragment status prerequisite)
                 , requiredMember "qualification" qualificationFragment
                 , requiredMember
                     "diagnostics"
                     (diagnosticsFragment modelDiagnostics)
                 , reportAuthorityMember envelope
                 ]))
         diagnostics)
    prepared

contextFragment ::
     Maybe QualifyPrerequisite
  -> SelectedView document
  -> [AcquiredSupplementalSource]
  -> [CanonicalFragment]
  -> CanonicalFragment
  -> CanonicalFragment
contextFragment prerequisite view acquired supplementalGroups authority =
  closedObjectFragment
    [ requiredMember "authority" authority
    , requiredMember
        "view"
        (viewDescriptorFragment (selectedViewDescriptor view))
    , requiredMember "supplements" (arrayFragment selectedSupplementalGroups)
    ]
  where
    selectedSupplementalGroups =
      case prerequisite of
        Just stage ->
          foldQualifyPrerequisite
            []
            []
            (emptySupplementalDiagnosticGroupFragments acquired)
            stage
        Nothing -> supplementalGroups

requestFragment :: QualifyRequest -> CanonicalFragment
requestFragment =
  foldQualifyRequest $ \_ selector adapter strategies needs supplements ->
    closedObjectFragment
      [ requiredMember "view" (viewSelectorFragment selector)
      , requiredMember
          "adapterId"
          (maybe nullFragment (textFragment . adapterIdText) adapter)
      , requiredMember
          "strategies"
          (arrayFragment
             (map
                (textFragment . modelIdentityText)
                (NonEmpty.toList strategies)))
      , requiredMember
          "needs"
          (arrayFragment (map (textFragment . modelIdentityText) needs))
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

executionFragment :: Text -> Maybe QualifyPrerequisite -> CanonicalFragment
executionFragment status prerequisite =
  closedObjectFragment
    ([requiredMember "status" (textFragment status)]
       <> maybe
            []
            (pure
               . requiredMember "prerequisite"
               . textFragment
               . qualifyPrerequisiteText)
            prerequisite)

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]
