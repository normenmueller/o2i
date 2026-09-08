{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for qualification-subject discovery.
module O2I.Operation.Qualification.Subjects.Machine
  ( type QualificationSubjectsDocument
  , qualificationSubjectsDocument
  , qualificationSubjectsSchema
  , qualificationSubjectsDocumentVariant
  , encodeQualificationSubjectsDocument
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract (coreQualifiedEndpointIdText)
import O2I.Core.Identity (modelIdentityText, occurrenceIdentityText)
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
import O2I.Operation.Qualification.Subjects.Request
  ( QualificationSubjectsRequest
  , foldQualificationSubjectsRequest
  )
import O2I.Operation.Qualification.Subjects.Result
  ( DiscoveredQualificationSubject
  , PreparedQualificationSubjects
  , QualificationSubjectsFailure
  , QualificationSubjectsInventory
  , QualificationSubjectsPrerequisite
  , QualificationSubjectsResult
  , discoveredQualificationSubjectCategory
  , discoveredQualificationSubjectDisplayName
  , discoveredQualificationSubjectEligibility
  , discoveredQualificationSubjectIdentity
  , discoveredQualificationSubjectOccurrence
  , discoveredQualificationSubjectQualifiedEndpoint
  , foldPreparedQualificationSubjects
  , qualificationInventoryNeedSubjects
  , qualificationInventoryStrategySubjects
  , qualificationSubjectCategoryText
  , qualificationSubjectEligibilityText
  , qualificationSubjectsPrerequisiteText
  )
import O2I.Operation.Report.Internal
  ( ReportEnvelope
  , foldQualificationSubjectsReport
  )
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.View
  ( ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )

-- | One immutable prepared qualification-subject document.
newtype QualificationSubjectsDocument =
  QualificationSubjectsDocument MachineResult

-- | Preserve command failures or close one prepared terminal document.
qualificationSubjectsDocument ::
     ToolDescriptor
  -> QualificationSubjectsResult
  -> Either QualificationSubjectsFailure QualificationSubjectsDocument
qualificationSubjectsDocument tool =
  foldQualificationSubjectsReport
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
    (\envelope subjects prepared ->
       Right
         (preparedDocument
            envelope
            "discovered"
            Nothing
            (qualificationSubjectsFragment subjects)
            prepared))

-- | Exact generated Schema authority.
qualificationSubjectsSchema :: MachineSchema
qualificationSubjectsSchema = Generated.qualificationSubjectsMachineSchema

-- | Exact terminal constructor discriminator.
qualificationSubjectsDocumentVariant ::
     QualificationSubjectsDocument -> SchemaVariant
qualificationSubjectsDocumentVariant (QualificationSubjectsDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeQualificationSubjectsDocument ::
     QualificationSubjectsDocument -> ByteString
encodeQualificationSubjectsDocument (QualificationSubjectsDocument result) =
  machineResultBytesValue result

preparedDocument ::
     ReportEnvelope
  -> Text
  -> Maybe QualificationSubjectsPrerequisite
  -> CanonicalFragment
  -> PreparedQualificationSubjects
  -> QualificationSubjectsDocument
preparedDocument envelope status prerequisite subjectsFragment prepared =
  foldPreparedQualificationSubjects
    (\request view acquired diagnostics ->
       foldPreparedDiagnosticDocumentFragments
         (\authority modelDiagnostics supplementalGroups ->
            QualificationSubjectsDocument
              (closedOperationMachineResult
                 envelope
                 [ requiredMember
                     "context"
                     (closedObjectFragment
                        [ requiredMember "authority" authority
                        , requiredMember
                            "view"
                            (viewDescriptorFragment
                               (selectedViewDescriptor view))
                        , requiredMember
                            "supplements"
                            (arrayFragment
                               (selectedSupplementalGroups
                                  prerequisite
                                  acquired
                                  supplementalGroups))
                        ])
                 , requiredMember "request" (requestFragment request)
                 , requiredMember
                     "execution"
                     (executionFragment status prerequisite)
                 , requiredMember "subjects" subjectsFragment
                 , requiredMember
                     "diagnostics"
                     (diagnosticsFragment modelDiagnostics)
                 , reportAuthorityMember envelope
                 ]))
         diagnostics)
    prepared

requestFragment :: QualificationSubjectsRequest -> CanonicalFragment
requestFragment =
  foldQualificationSubjectsRequest $ \_ selector adapter supplements ->
    closedObjectFragment
      [ requiredMember "view" (viewSelectorFragment selector)
      , requiredMember
          "adapterId"
          (maybe nullFragment (textFragment . adapterIdText) adapter)
      , requiredMember
          "supplements"
          (arrayFragment (map inputSourceFragment supplements))
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

selectedSupplementalGroups ::
     Maybe QualificationSubjectsPrerequisite
  -> [AcquiredSupplementalSource]
  -> [CanonicalFragment]
  -> [CanonicalFragment]
selectedSupplementalGroups prerequisite acquired groups =
  case prerequisite of
    Nothing -> groups
    Just _ -> emptySupplementalDiagnosticGroupFragments acquired

qualificationSubjectsFragment ::
     QualificationSubjectsInventory -> CanonicalFragment
qualificationSubjectsFragment inventory =
  closedObjectFragment
    [ requiredMember
        "needs"
        (arrayFragment
           (map
              qualificationSubjectFragment
              (qualificationInventoryNeedSubjects inventory)))
    , requiredMember
        "strategies"
        (arrayFragment
           (map
              qualificationSubjectFragment
              (qualificationInventoryStrategySubjects inventory)))
    ]

qualificationSubjectFragment ::
     DiscoveredQualificationSubject -> CanonicalFragment
qualificationSubjectFragment subject =
  closedObjectFragment
    [ requiredMember
        "category"
        (textFragment
           (qualificationSubjectCategoryText
              (discoveredQualificationSubjectCategory subject)))
    , requiredMember
        "identity"
        (textFragment
           (modelIdentityText (discoveredQualificationSubjectIdentity subject)))
    , requiredMember
        "occurrence"
        (textFragment
           (occurrenceIdentityText
              (discoveredQualificationSubjectOccurrence subject)))
    , requiredMember
        "qualifiedType"
        (textFragment
           (coreQualifiedEndpointIdText
              (discoveredQualificationSubjectQualifiedEndpoint subject)))
    , requiredMember
        "displayName"
        (maybe
           nullFragment
           textFragment
           (discoveredQualificationSubjectDisplayName subject))
    , requiredMember
        "eligibility"
        (textFragment
           (qualificationSubjectEligibilityText
              (discoveredQualificationSubjectEligibility subject)))
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

executionFragment ::
     Text -> Maybe QualificationSubjectsPrerequisite -> CanonicalFragment
executionFragment status prerequisite =
  closedObjectFragment
    ([requiredMember "status" (textFragment status)]
       <> maybe
            []
            (pure
               . requiredMember "prerequisite"
               . textFragment
               . qualificationSubjectsPrerequisiteText)
            prerequisite)

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]
