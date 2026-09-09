{-# LANGUAGE OverloadedStrings #-}

-- | Private constructors and owner-to-consumer projections for human values.
module O2I.Operation.Human.Value.Internal
  ( HumanModelIdentity(..)
  , HumanOccurrenceIdentity(..)
  , HumanQualifiedType(..)
  , HumanSourceRole(..)
  , HumanSourceIdentity(..)
  , HumanInputSource(..)
  , HumanViewSelector(..)
  , HumanAdapterSelection(..)
  , HumanAdapterDescriptor(..)
  , HumanProfileDescriptor(..)
  , HumanCanonicalOccurrenceKind(..)
  , HumanCanonicalOccurrence(..)
  , HumanNativeName(..)
  , HumanSourcePosition(..)
  , HumanSourceSpan(..)
  , HumanSourcePathStep(..)
  , HumanSourceLocation(..)
  , HumanScalarValue(..)
  , HumanDraftScalar(..)
  , HumanIdentityInvalidReason(..)
  , HumanIdentityOutcome(..)
  , HumanCanonicalField(..)
  , HumanViewDescriptor(..)
  , HumanTraceBinding(..)
  , HumanTraceIdentity(..)
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectQualifiedType
  , projectSourceIdentity
  , projectAcquiredSupplementalSource
  , projectAcquiredReadinessSource
  , projectAcquiredAssessmentSource
  , projectInputSource
  , projectViewSelector
  , projectAdapterSelection
  , projectAdapterDescriptor
  , projectProfileDescriptor
  , projectCanonicalOccurrence
  , projectSourceLocation
  , projectDraftScalar
  , projectIdentityOutcome
  , projectCanonicalField
  , projectViewDescriptor
  , projectTraceIdentity
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import Numeric.Natural (Natural)
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
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , foldProfileDescriptor
  )
import O2I.Core.Contract (CoreQualifiedEndpointId, coreQualifiedEndpointIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Acquisition
  ( AcquiredAssessmentSource
  , AcquiredReadinessSource
  , AcquiredSupplementalSource
  , InputSource
  , acquiredSourceIdentity
  , foldAcquiredAssessmentSource
  , foldAcquiredReadinessSource
  , foldAcquiredSupplementalSource
  , foldInputSource
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterId
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorNotation
  , adapterDescriptorVersion
  , adapterIdText
  )
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(..)
  , foldSourceIdentity
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import O2I.Operation.View (ViewSelector, foldViewSelector)
import qualified O2I.Trace as Trace

-- | Exact model identity prepared by Operation.
newtype HumanModelIdentity =
  HumanModelIdentity Text

-- | Exact canonical occurrence identity.
newtype HumanOccurrenceIdentity =
  HumanOccurrenceIdentity Text

-- | Exact qualified Core endpoint type.
newtype HumanQualifiedType =
  HumanQualifiedType Text

-- | Closed provenance role of an acquired source.
data HumanSourceRole
  = HumanModelSource
  | HumanSupplementalSource
  | HumanReadinessSource
  | HumanAssessmentSource

-- | Role, ordinal, reference, and digest of one acquired source.
data HumanSourceIdentity =
  HumanSourceIdentity HumanSourceRole Natural Text Text

-- | Exact requested file or standard-input source.
data HumanInputSource
  = HumanFileInput Text FilePath
  | HumanStandardInput Text

-- | Closed exact View selector retained by a request.
data HumanViewSelector
  = HumanViewNameSelector Text
  | HumanViewIdentitySelector HumanModelIdentity

-- | Automatic or exact requested Adapter selection.
data HumanAdapterSelection
  = HumanAutomaticAdapterSelection
  | HumanRequestedAdapterSelection Text

-- | Stable identity and descriptive fields of the selected adapter.
data HumanAdapterDescriptor =
  HumanAdapterDescriptor Text Text Text Text

-- | Stable identity, compatibility, and contract fields of the Profile.
data HumanProfileDescriptor =
  HumanProfileDescriptor Text Text Text Text [Text] Text

-- | Closed canonical occurrence category.
data HumanCanonicalOccurrenceKind
  = HumanRecordOccurrence
  | HumanPropertyOccurrence
  | HumanReferenceOccurrence

-- | Canonical occurrence category and source ordinal.
data HumanCanonicalOccurrence =
  HumanCanonicalOccurrence HumanCanonicalOccurrenceKind Natural

-- | Native local name with an optional namespace.
data HumanNativeName =
  HumanNativeName (Maybe Text) Text

-- | One-based source line and column with an optional byte offset.
data HumanSourcePosition =
  HumanSourcePosition Natural Natural (Maybe Natural)

-- | Inclusive source start and end positions.
data HumanSourceSpan =
  HumanSourceSpan HumanSourcePosition HumanSourcePosition

-- | One native-name step and ordinal in a source path.
data HumanSourcePathStep =
  HumanSourcePathStep HumanNativeName Natural

-- | Exact native path and optional source span.
data HumanSourceLocation =
  HumanSourceLocation (NonEmpty HumanSourcePathStep) (Maybe HumanSourceSpan)

-- | Closed scalar algebra retaining exact lexical values.
data HumanScalarValue
  = HumanTextScalar Text
  | HumanBooleanScalar Bool
  | HumanNumberScalar Text
  | HumanNativeNameScalar HumanNativeName
  | HumanOtherScalar Text Text

-- | Scalar value paired with its exact source location.
data HumanDraftScalar =
  HumanDraftScalar HumanScalarValue HumanSourceLocation

-- | Closed reason why a candidate identity was invalid.
data HumanIdentityInvalidReason
  = HumanIdentityNonText Text
  | HumanIdentityEmpty
  | HumanIdentityContainsNul
  | HumanIdentityContainsSurrogate

-- | Complete identity extraction outcome for a canonical View.
data HumanIdentityOutcome
  = HumanIdentityMissing
  | HumanIdentityMultiple [HumanDraftScalar]
  | HumanIdentityInvalid HumanDraftScalar HumanIdentityInvalidReason
  | HumanIdentityResolved HumanDraftScalar HumanModelIdentity

-- | Canonical field kind, retained scalars, and source location.
data HumanCanonicalField =
  HumanCanonicalField Text [HumanDraftScalar] HumanSourceLocation

-- | Complete terminal-neutral descriptor of one discovered View.
data HumanViewDescriptor =
  HumanViewDescriptor
    HumanCanonicalOccurrence
    HumanIdentityOutcome
    [HumanCanonicalField]
    HumanSourceLocation

-- | Trace variable bound to an exact model identity.
data HumanTraceBinding =
  HumanTraceBinding Text HumanModelIdentity

-- | Trace graph identity and its ordered variable bindings.
data HumanTraceIdentity =
  HumanTraceIdentity HumanModelIdentity [HumanTraceBinding]

projectModelIdentity :: ModelIdentity -> HumanModelIdentity
projectModelIdentity = HumanModelIdentity . modelIdentityText

projectOccurrenceIdentity :: OccurrenceIdentity -> HumanOccurrenceIdentity
projectOccurrenceIdentity = HumanOccurrenceIdentity . occurrenceIdentityText

projectQualifiedType :: CoreQualifiedEndpointId -> HumanQualifiedType
projectQualifiedType = HumanQualifiedType . coreQualifiedEndpointIdText

projectSourceIdentity :: SourceIdentity -> HumanSourceIdentity
projectSourceIdentity =
  foldSourceIdentity $ \role ordinal reference digest ->
    HumanSourceIdentity
      (case role of
         ModelRole -> HumanModelSource
         SupplementalRole -> HumanSupplementalSource
         ReadinessRole -> HumanReadinessSource
         AssessmentRole -> HumanAssessmentSource)
      (sourceOrdinalValue ordinal)
      (sourceReferenceText reference)
      (sourceSha256Text digest)

projectAcquiredSupplementalSource ::
     AcquiredSupplementalSource -> HumanSourceIdentity
projectAcquiredSupplementalSource =
  foldAcquiredSupplementalSource
    (projectSourceIdentity . acquiredSourceIdentity)

projectAcquiredReadinessSource :: AcquiredReadinessSource -> HumanSourceIdentity
projectAcquiredReadinessSource =
  foldAcquiredReadinessSource (projectSourceIdentity . acquiredSourceIdentity)

projectAcquiredAssessmentSource ::
     AcquiredAssessmentSource -> HumanSourceIdentity
projectAcquiredAssessmentSource =
  foldAcquiredAssessmentSource (projectSourceIdentity . acquiredSourceIdentity)

projectInputSource :: InputSource -> HumanInputSource
projectInputSource =
  foldInputSource
    (\reference path -> HumanFileInput (sourceReferenceText reference) path)
    (HumanStandardInput . sourceReferenceText)

projectViewSelector :: ViewSelector -> HumanViewSelector
projectViewSelector =
  foldViewSelector
    HumanViewNameSelector
    (HumanViewIdentitySelector . projectModelIdentity)

projectAdapterSelection :: Maybe AdapterId -> HumanAdapterSelection
projectAdapterSelection =
  maybe
    HumanAutomaticAdapterSelection
    (HumanRequestedAdapterSelection . adapterIdText)

projectAdapterDescriptor :: AdapterDescriptor -> HumanAdapterDescriptor
projectAdapterDescriptor descriptor =
  HumanAdapterDescriptor
    (adapterIdText (adapterDescriptorId descriptor))
    (adapterDescriptorName descriptor)
    (adapterDescriptorVersion descriptor)
    (adapterDescriptorNotation descriptor)

projectProfileDescriptor :: ProfileDescriptor -> HumanProfileDescriptor
projectProfileDescriptor = foldProfileDescriptor HumanProfileDescriptor

projectCanonicalOccurrence :: CanonicalOccurrence -> HumanCanonicalOccurrence
projectCanonicalOccurrence occurrence =
  HumanCanonicalOccurrence
    (foldCanonicalOccurrenceKind
       HumanRecordOccurrence
       HumanPropertyOccurrence
       HumanReferenceOccurrence
       (canonicalOccurrenceKind occurrence))
    (canonicalOccurrenceOrdinal occurrence)

projectNativeName :: DraftNativeName -> HumanNativeName
projectNativeName name =
  HumanNativeName (draftNativeNamespace name) (draftNativeLocalName name)

projectSourcePosition :: DraftSourcePosition -> HumanSourcePosition
projectSourcePosition position =
  HumanSourcePosition
    (draftSourceLine position)
    (draftSourceColumn position)
    (draftSourceOffset position)

projectSourceSpan :: DraftSourceSpan -> HumanSourceSpan
projectSourceSpan sourceSpan =
  HumanSourceSpan
    (projectSourcePosition (draftSpanStart sourceSpan))
    (projectSourcePosition (draftSpanEnd sourceSpan))

projectPathStep :: DraftPathStep -> HumanSourcePathStep
projectPathStep step =
  HumanSourcePathStep
    (projectNativeName (draftPathStepName step))
    (draftPathStepOrdinal step)

projectSourceLocation :: DraftLocation -> HumanSourceLocation
projectSourceLocation location =
  HumanSourceLocation
    (foldDraftSourcePath
       (\first rest -> projectPathStep first :| map projectPathStep rest)
       (draftLocationPath location))
    (projectSourceSpan <$> draftLocationSpan location)

projectDraftScalar :: DraftScalar -> HumanDraftScalar
projectDraftScalar scalar =
  HumanDraftScalar
    (foldDraftScalarValue
       HumanTextScalar
       HumanBooleanScalar
       HumanNumberScalar
       (HumanNativeNameScalar . projectNativeName)
       HumanOtherScalar
       scalar)
    (projectSourceLocation (draftScalarLocation scalar))

projectIdentityOutcome :: IdentityOutcome -> HumanIdentityOutcome
projectIdentityOutcome =
  foldIdentityOutcome
    HumanIdentityMissing
    (HumanIdentityMultiple . map projectDraftScalar)
    (\scalar reason ->
       HumanIdentityInvalid
         (projectDraftScalar scalar)
         (foldIdentityInvalidReason
            (HumanIdentityNonText . draftValueKindText)
            HumanIdentityEmpty
            HumanIdentityContainsNul
            HumanIdentityContainsSurrogate
            reason))
    (\scalar identity ->
       HumanIdentityResolved
         (projectDraftScalar scalar)
         (projectModelIdentity identity))

projectCanonicalField :: CanonicalField -> HumanCanonicalField
projectCanonicalField field =
  HumanCanonicalField
    (draftFieldKindText (canonicalFieldKind field))
    (map projectDraftScalar (canonicalFieldScalars field))
    (projectSourceLocation (canonicalFieldLocation field))

projectViewDescriptor :: CanonicalView document -> HumanViewDescriptor
projectViewDescriptor view =
  HumanViewDescriptor
    (projectCanonicalOccurrence (canonicalViewOccurrence view))
    (projectIdentityOutcome (canonicalViewIdentity view))
    (map projectCanonicalField (canonicalViewNameFields view))
    (projectSourceLocation (canonicalViewLocation view))

projectTraceIdentity :: Trace.TraceIdentity -> HumanTraceIdentity
projectTraceIdentity identity =
  HumanTraceIdentity
    (projectModelIdentity (Trace.traceIdentityGraphIdentity identity))
    [ HumanTraceBinding
      (Trace.traceVariableId variable)
      (projectModelIdentity modelIdentity)
    | (variable, modelIdentity) <- Trace.traceIdentityBindings identity
    ]

draftFieldKindText :: DraftFieldValue -> Text
draftFieldKindText =
  foldDraftFieldValue
    "type"
    "name"
    "documentation"
    "directed"
    "influence-strength"

draftValueKindText :: DraftValueKind -> Text
draftValueKindText =
  foldDraftValueKind "text" "boolean" "number" "native-name" id
