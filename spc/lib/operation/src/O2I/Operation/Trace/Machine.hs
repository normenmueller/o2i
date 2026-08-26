{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for selected-View Trace results.
--
-- Expected failures remain typed command outcomes and have no Operation
-- envelope. Every prepared result becomes one immutable Schema-bound document.
module O2I.Operation.Trace.Machine
  ( type TraceResultDocument
  , traceResultDocument
  , traceResultSchema
  , traceResultDocumentVariant
  , encodeTraceResultDocument
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import O2I.Core.Contract
  ( coreContractIdentity
  , coreContractIdentityText
  , coreContractSha256
  , coreContractSha256Text
  , coreContractVersion
  , coreContractVersionText
  )
import O2I.Core.Identity (modelIdentityText)
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , MachineResult(..)
  , arrayFragment
  , closedObjectFragment
  , closedOperationMachineResult
  , nullFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( foldPreparedDiagnosticDocumentFragments
  , viewDescriptorFragment
  )
import O2I.Operation.Machine.Internal (traceOperationIdentity)
import qualified O2I.Operation.Rule.Generated as Rule
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.Trace.Machine.Internal (traceAssessmentFragment)
import O2I.Operation.Trace.Request (TraceRequest, foldTraceRequest)
import O2I.Operation.Trace.Result
  ( PreparedTrace
  , TraceFailure
  , TracePrerequisite
  , TraceResult
  , foldPreparedTrace
  , foldTracePrerequisite
  , foldTraceResult
  , tracePrerequisiteText
  )
import O2I.Operation.View
  ( ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )
import O2I.Trace (TraceAssessment)

-- | One immutable completed Trace machine document.
newtype TraceResultDocument =
  TraceResultDocument MachineResult

-- | Preserve expected failure or close one prepared terminal result.
traceResultDocument ::
     ToolDescriptor -> TraceResult -> Either TraceFailure TraceResultDocument
traceResultDocument tool =
  foldTraceResult
    Left
    (\stage prepared ->
       Right
         (preparedDocument
            tool
            Generated.tracePrerequisiteRejectedVariant
            "prerequisite-rejected"
            (Just stage)
            nullFragment
            prepared))
    (\assessment prepared ->
       Right
         (completedDocument
            tool
            Generated.traceRejectedVariant
            "rejected"
            assessment
            prepared))
    (\assessment prepared ->
       Right
         (completedDocument
            tool
            Generated.traceAcceptedVariant
            "accepted"
            assessment
            prepared))

-- | Exact generated Schema authority for Trace result documents.
traceResultSchema :: MachineSchema
traceResultSchema = Generated.traceResultMachineSchema

-- | Exact terminal constructor discriminator selected by execution.
traceResultDocumentVariant :: TraceResultDocument -> SchemaVariant
traceResultDocumentVariant (TraceResultDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeTraceResultDocument :: TraceResultDocument -> ByteString
encodeTraceResultDocument (TraceResultDocument result) =
  machineResultBytesValue result

completedDocument ::
     ToolDescriptor
  -> SchemaVariant
  -> Text
  -> TraceAssessment scope
  -> PreparedTrace
  -> TraceResultDocument
completedDocument tool variant status assessment =
  preparedDocument
    tool
    variant
    status
    Nothing
    (traceAssessmentFragment assessment)

preparedDocument ::
     ToolDescriptor
  -> SchemaVariant
  -> Text
  -> Maybe TracePrerequisite
  -> CanonicalFragment
  -> PreparedTrace
  -> TraceResultDocument
preparedDocument tool variant status prerequisite traceFragment prepared =
  foldPreparedTrace
    (\request view diagnostics ->
       foldPreparedDiagnosticDocumentFragments
         (\authority modelDiagnostics _ ->
            TraceResultDocument
              (closedOperationMachineResult
                 Generated.traceResultMachineSchema
                 traceOperationIdentity
                 tool
                 variant
                 [ requiredMember
                     "context"
                     (closedObjectFragment
                        [ requiredMember "authority" authority
                        , requiredMember
                            "view"
                            (viewDescriptorFragment
                               (selectedViewDescriptor view))
                        ])
                 , requiredMember "request" (requestFragment request)
                 , requiredMember
                     "execution"
                     (executionFragment status prerequisite)
                 , requiredMember "trace" traceFragment
                 , requiredMember
                     "diagnostics"
                     (diagnosticsFragment modelDiagnostics)
                 , requiredMember "provenance" (provenanceFragment prerequisite)
                 ]))
         diagnostics)
    prepared

requestFragment :: TraceRequest -> CanonicalFragment
requestFragment =
  foldTraceRequest $ \_ selector adapter ->
    closedObjectFragment
      [ requiredMember "view" (viewSelectorFragment selector)
      , requiredMember
          "adapterId"
          (maybe nullFragment (textFragment . adapterIdText) adapter)
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

executionFragment :: Text -> Maybe TracePrerequisite -> CanonicalFragment
executionFragment status prerequisite =
  closedObjectFragment
    ([requiredMember "status" (textFragment status)]
       <> maybe
            []
            (pure
               . requiredMember "prerequisite"
               . textFragment
               . tracePrerequisiteText)
            prerequisite)

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]

provenanceFragment :: Maybe TracePrerequisite -> CanonicalFragment
provenanceFragment prerequisite =
  closedObjectFragment
    [ requiredMember
        "contracts"
        (arrayFragment
           ([ operationContractFragment
            , kindContractFragment "adapter"
            , kindContractFragment "profile"
            ]
              <> if includeCore prerequisite
                   then [coreContractFragment]
                   else []))
    ]

includeCore :: Maybe TracePrerequisite -> Bool
includeCore prerequisite =
  case prerequisite of
    Nothing -> True
    Just stage -> foldTracePrerequisite False False True True stage

operationContractFragment :: CanonicalFragment
operationContractFragment =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "operation")
    , requiredMember "identity" (textFragment Rule.operationContractIdentity)
    , requiredMember "version" (textFragment Rule.operationContractVersion)
    , requiredMember "digest" (textFragment Rule.operationContractSha256)
    ]

kindContractFragment :: Text -> CanonicalFragment
kindContractFragment kind =
  closedObjectFragment [requiredMember "kind" (textFragment kind)]

coreContractFragment :: CanonicalFragment
coreContractFragment =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "core")
    , requiredMember
        "identity"
        (textFragment (coreContractIdentityText coreContractIdentity))
    , requiredMember
        "version"
        (textFragment (coreContractVersionText coreContractVersion))
    , requiredMember
        "digest"
        (textFragment (coreContractSha256Text coreContractSha256))
    ]
