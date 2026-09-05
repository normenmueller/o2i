{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for selected-View evidence readiness.
module O2I.Operation.Readiness.Machine
  ( type ReadinessResultDocument
  , readinessResultDocument
  , readinessResultSchema
  , readinessResultDocumentVariant
  , encodeReadinessResultDocument
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Acquisition
  ( AcquiredReadinessSource
  , AcquiredSupplementalSource
  , InputSource
  , acquiredSourceIdentity
  , foldAcquiredReadinessSource
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
  , sourceIdentityFragment
  , viewDescriptorFragment
  )
import O2I.Operation.Readiness.Machine.Internal
  ( readinessAssessmentFragment
  , readinessUnavailableFragment
  )
import O2I.Operation.Readiness.Request (ReadinessRequest, foldReadinessRequest)
import O2I.Operation.Readiness.Result
  ( PreparedReadiness
  , ReadinessFailure
  , ReadinessPrerequisite
  , ReadinessResult
  , foldPreparedReadiness
  , foldReadinessPrerequisite
  , readinessPrerequisiteText
  )
import O2I.Operation.Report.Internal (ReportEnvelope, foldReadinessReport)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.View
  ( SelectedView
  , ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )

-- | Validated canonical machine envelope for one completed result.
newtype ReadinessResultDocument =
  ReadinessResultDocument MachineResult

-- | Build a document for a prepared terminal result or return its failure.
readinessResultDocument ::
     ToolDescriptor
  -> ReadinessResult
  -> Either ReadinessFailure ReadinessResultDocument
readinessResultDocument tool =
  foldReadinessReport
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
    (\envelope unavailable prepared ->
       Right
         (preparedDocument
            envelope
            "subject-unavailable"
            Nothing
            (readinessUnavailableFragment unavailable)
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "not-ready"
            Nothing
            (readinessAssessmentFragment assessment)
            prepared))
    (\envelope assessment prepared ->
       Right
         (preparedDocument
            envelope
            "ready"
            Nothing
            (readinessAssessmentFragment assessment)
            prepared))

-- | Generated closed Schema authority for Readiness result documents.
readinessResultSchema :: MachineSchema
readinessResultSchema = Generated.readinessResultMachineSchema

-- | Project the exact generated variant selected by the result.
readinessResultDocumentVariant :: ReadinessResultDocument -> SchemaVariant
readinessResultDocumentVariant (ReadinessResultDocument result) =
  machineResultVariantValue result

-- | Encode the already validated document as deterministic UTF-8 JSON bytes.
encodeReadinessResultDocument :: ReadinessResultDocument -> ByteString
encodeReadinessResultDocument (ReadinessResultDocument result) =
  machineResultBytesValue result

preparedDocument ::
     ReportEnvelope
  -> Text
  -> Maybe ReadinessPrerequisite
  -> CanonicalFragment
  -> PreparedReadiness
  -> ReadinessResultDocument
preparedDocument envelope status prerequisite readinessFragment prepared =
  foldPreparedReadiness
    (\request view evidence supplements diagnostics ->
       foldPreparedDiagnosticDocumentFragments
         (\authority modelDiagnostics supplementalGroups ->
            ReadinessResultDocument
              (closedOperationMachineResult
                 envelope
                 [ requiredMember
                     "context"
                     (contextFragment
                        prerequisite
                        view
                        evidence
                        supplements
                        supplementalGroups
                        authority)
                 , requiredMember "request" (requestFragment request)
                 , requiredMember
                     "execution"
                     (executionFragment status prerequisite)
                 , requiredMember "readiness" readinessFragment
                 , requiredMember
                     "diagnostics"
                     (diagnosticsFragment modelDiagnostics)
                 , reportAuthorityMember envelope
                 ]))
         diagnostics)
    prepared

contextFragment ::
     Maybe ReadinessPrerequisite
  -> SelectedView document
  -> Maybe AcquiredReadinessSource
  -> [AcquiredSupplementalSource]
  -> [CanonicalFragment]
  -> CanonicalFragment
  -> CanonicalFragment
contextFragment prerequisite view evidence supplements supplementalGroups authority =
  closedObjectFragment
    [ requiredMember "authority" authority
    , requiredMember
        "view"
        (viewDescriptorFragment (selectedViewDescriptor view))
    , requiredMember
        "readiness"
        (maybe nullFragment acquiredReadinessFragment evidence)
    , requiredMember "supplements" (arrayFragment selectedSupplementalGroups)
    ]
  where
    selectedSupplementalGroups =
      case prerequisite of
        Just stage ->
          foldReadinessPrerequisite
            []
            []
            (emptySupplementalDiagnosticGroupFragments supplements)
            supplementalGroups
            stage
        Nothing -> supplementalGroups

acquiredReadinessFragment :: AcquiredReadinessSource -> CanonicalFragment
acquiredReadinessFragment =
  foldAcquiredReadinessSource (sourceIdentityFragment . acquiredSourceIdentity)

requestFragment :: ReadinessRequest -> CanonicalFragment
requestFragment =
  foldReadinessRequest $ \_ selector adapter evidence supplements ->
    closedObjectFragment
      [ requiredMember "view" (viewSelectorFragment selector)
      , requiredMember
          "adapterId"
          (maybe nullFragment (textFragment . adapterIdText) adapter)
      , requiredMember "readiness" (inputSourceFragment evidence)
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

executionFragment :: Text -> Maybe ReadinessPrerequisite -> CanonicalFragment
executionFragment status prerequisite =
  closedObjectFragment
    ([requiredMember "status" (textFragment status)]
       <> maybe
            []
            (pure
               . requiredMember "prerequisite"
               . textFragment
               . readinessPrerequisiteText)
            prerequisite)

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]
