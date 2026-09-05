{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed terminal-neutral values shared by human report projections.
--
-- The values retain semantic categories and source positions. They contain no
-- rendering, escaping, extensible label map, or construction surface.
module O2I.Operation.Human.Value
  ( type HumanModelIdentity
  , foldHumanModelIdentity
  , type HumanOccurrenceIdentity
  , foldHumanOccurrenceIdentity
  , type HumanQualifiedType
  , foldHumanQualifiedType
  , type HumanSourceRole
  , foldHumanSourceRole
  , type HumanSourceIdentity
  , foldHumanSourceIdentity
  , type HumanInputSource
  , foldHumanInputSource
  , type HumanViewSelector
  , foldHumanViewSelector
  , type HumanAdapterSelection
  , foldHumanAdapterSelection
  , type HumanAdapterDescriptor
  , foldHumanAdapterDescriptor
  , type HumanProfileDescriptor
  , foldHumanProfileDescriptor
  , type HumanCanonicalOccurrenceKind
  , foldHumanCanonicalOccurrenceKind
  , type HumanCanonicalOccurrence
  , foldHumanCanonicalOccurrence
  , type HumanNativeName
  , foldHumanNativeName
  , type HumanSourcePosition
  , foldHumanSourcePosition
  , type HumanSourceSpan
  , foldHumanSourceSpan
  , type HumanSourcePathStep
  , foldHumanSourcePathStep
  , type HumanSourceLocation
  , foldHumanSourceLocation
  , type HumanScalarValue
  , foldHumanScalarValue
  , type HumanDraftScalar
  , foldHumanDraftScalar
  , type HumanIdentityInvalidReason
  , foldHumanIdentityInvalidReason
  , type HumanIdentityOutcome
  , foldHumanIdentityOutcome
  , type HumanCanonicalField
  , foldHumanCanonicalField
  , type HumanViewDescriptor
  , foldHumanViewDescriptor
  , type HumanTraceBinding
  , foldHumanTraceBinding
  , type HumanTraceIdentity
  , foldHumanTraceIdentity
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Human.Value.Internal

-- | Consume the exact model-identity text.
foldHumanModelIdentity :: (Text -> result) -> HumanModelIdentity -> result
foldHumanModelIdentity consume (HumanModelIdentity value) = consume value

-- | Consume the exact occurrence-identity text.
foldHumanOccurrenceIdentity ::
     (Text -> result) -> HumanOccurrenceIdentity -> result
foldHumanOccurrenceIdentity consume (HumanOccurrenceIdentity value) =
  consume value

-- | Consume the exact qualified-type text.
foldHumanQualifiedType :: (Text -> result) -> HumanQualifiedType -> result
foldHumanQualifiedType consume (HumanQualifiedType value) = consume value

-- | Eliminate every closed source role.
foldHumanSourceRole ::
     result -> result -> result -> result -> HumanSourceRole -> result
foldHumanSourceRole model supplemental readiness assessment role =
  case role of
    HumanModelSource -> model
    HumanSupplementalSource -> supplemental
    HumanReadinessSource -> readiness
    HumanAssessmentSource -> assessment

-- | Consume every retained source-identity field.
foldHumanSourceIdentity ::
     (HumanSourceRole -> Natural -> Text -> Text -> result)
  -> HumanSourceIdentity
  -> result
foldHumanSourceIdentity consume (HumanSourceIdentity role ordinal reference digest) =
  consume role ordinal reference digest

-- | Eliminate the exact requested file or standard-input source.
foldHumanInputSource ::
     (Text -> FilePath -> result)
  -> (Text -> result)
  -> HumanInputSource
  -> result
foldHumanInputSource file standard input =
  case input of
    HumanFileInput reference path -> file reference path
    HumanStandardInput reference -> standard reference

-- | Eliminate both exact View selector shapes.
foldHumanViewSelector ::
     (Text -> result)
  -> (HumanModelIdentity -> result)
  -> HumanViewSelector
  -> result
foldHumanViewSelector name identity selector =
  case selector of
    HumanViewNameSelector value -> name value
    HumanViewIdentitySelector value -> identity value

-- | Eliminate automatic or exact requested Adapter selection.
foldHumanAdapterSelection ::
     result -> (Text -> result) -> HumanAdapterSelection -> result
foldHumanAdapterSelection automatic requested selection =
  case selection of
    HumanAutomaticAdapterSelection -> automatic
    HumanRequestedAdapterSelection identifier -> requested identifier

-- | Consume every retained adapter-descriptor field.
foldHumanAdapterDescriptor ::
     (Text -> Text -> Text -> Text -> result)
  -> HumanAdapterDescriptor
  -> result
foldHumanAdapterDescriptor consume (HumanAdapterDescriptor identifier name version notation) =
  consume identifier name version notation

-- | Consume every retained Profile-descriptor field.
foldHumanProfileDescriptor ::
     (Text -> Text -> Text -> Text -> [Text] -> Text -> result)
  -> HumanProfileDescriptor
  -> result
foldHumanProfileDescriptor consume (HumanProfileDescriptor identity token version notation adapters digest) =
  consume identity token version notation adapters digest

-- | Eliminate every closed canonical occurrence kind.
foldHumanCanonicalOccurrenceKind ::
     result -> result -> result -> HumanCanonicalOccurrenceKind -> result
foldHumanCanonicalOccurrenceKind record property reference kind =
  case kind of
    HumanRecordOccurrence -> record
    HumanPropertyOccurrence -> property
    HumanReferenceOccurrence -> reference

-- | Consume the occurrence kind and ordinal.
foldHumanCanonicalOccurrence ::
     (HumanCanonicalOccurrenceKind -> Natural -> result)
  -> HumanCanonicalOccurrence
  -> result
foldHumanCanonicalOccurrence consume (HumanCanonicalOccurrence kind ordinal) =
  consume kind ordinal

-- | Consume the optional namespace and local name.
foldHumanNativeName ::
     (Maybe Text -> Text -> result) -> HumanNativeName -> result
foldHumanNativeName consume (HumanNativeName namespace localName) =
  consume namespace localName

-- | Consume line, column, and optional byte offset.
foldHumanSourcePosition ::
     (Natural -> Natural -> Maybe Natural -> result)
  -> HumanSourcePosition
  -> result
foldHumanSourcePosition consume (HumanSourcePosition line column offset) =
  consume line column offset

-- | Consume the start and end source positions.
foldHumanSourceSpan ::
     (HumanSourcePosition -> HumanSourcePosition -> result)
  -> HumanSourceSpan
  -> result
foldHumanSourceSpan consume (HumanSourceSpan start end) = consume start end

-- | Consume the native name and ordinal of one path step.
foldHumanSourcePathStep ::
     (HumanNativeName -> Natural -> result) -> HumanSourcePathStep -> result
foldHumanSourcePathStep consume (HumanSourcePathStep name ordinal) =
  consume name ordinal

-- | Consume the exact path and optional source span.
foldHumanSourceLocation ::
     (NonEmpty HumanSourcePathStep -> Maybe HumanSourceSpan -> result)
  -> HumanSourceLocation
  -> result
foldHumanSourceLocation consume (HumanSourceLocation path sourceSpan) =
  consume path sourceSpan

-- | Eliminate every closed scalar-value branch.
foldHumanScalarValue ::
     (Text -> result)
  -> (Bool -> result)
  -> (Text -> result)
  -> (HumanNativeName -> result)
  -> (Text -> Text -> result)
  -> HumanScalarValue
  -> result
foldHumanScalarValue text boolean number nativeName other value =
  case value of
    HumanTextScalar retained -> text retained
    HumanBooleanScalar retained -> boolean retained
    HumanNumberScalar retained -> number retained
    HumanNativeNameScalar retained -> nativeName retained
    HumanOtherScalar kind retained -> other kind retained

-- | Consume the scalar value and exact source location.
foldHumanDraftScalar ::
     (HumanScalarValue -> HumanSourceLocation -> result)
  -> HumanDraftScalar
  -> result
foldHumanDraftScalar consume (HumanDraftScalar value location) =
  consume value location

-- | Eliminate every closed invalid-identity reason.
foldHumanIdentityInvalidReason ::
     (Text -> result)
  -> result
  -> result
  -> result
  -> HumanIdentityInvalidReason
  -> result
foldHumanIdentityInvalidReason nonText empty nul surrogate reason =
  case reason of
    HumanIdentityNonText kind -> nonText kind
    HumanIdentityEmpty -> empty
    HumanIdentityContainsNul -> nul
    HumanIdentityContainsSurrogate -> surrogate

-- | Eliminate every complete identity-extraction outcome.
foldHumanIdentityOutcome ::
     result
  -> ([HumanDraftScalar] -> result)
  -> (HumanDraftScalar -> HumanIdentityInvalidReason -> result)
  -> (HumanDraftScalar -> HumanModelIdentity -> result)
  -> HumanIdentityOutcome
  -> result
foldHumanIdentityOutcome missing multiple invalid resolved outcome =
  case outcome of
    HumanIdentityMissing -> missing
    HumanIdentityMultiple values -> multiple values
    HumanIdentityInvalid value reason -> invalid value reason
    HumanIdentityResolved value identity -> resolved value identity

-- | Consume the canonical field kind, scalars, and location.
foldHumanCanonicalField ::
     (Text -> [HumanDraftScalar] -> HumanSourceLocation -> result)
  -> HumanCanonicalField
  -> result
foldHumanCanonicalField consume (HumanCanonicalField kind values location) =
  consume kind values location

-- | Consume every retained View-descriptor field.
foldHumanViewDescriptor ::
     (HumanCanonicalOccurrence -> HumanIdentityOutcome -> [HumanCanonicalField] -> HumanSourceLocation -> result)
  -> HumanViewDescriptor
  -> result
foldHumanViewDescriptor consume (HumanViewDescriptor occurrence identity nameFields location) =
  consume occurrence identity nameFields location

-- | Consume the trace variable and bound model identity.
foldHumanTraceBinding ::
     (Text -> HumanModelIdentity -> result) -> HumanTraceBinding -> result
foldHumanTraceBinding consume (HumanTraceBinding variable identity) =
  consume variable identity

-- | Consume the graph identity and ordered trace bindings.
foldHumanTraceIdentity ::
     (HumanModelIdentity -> [HumanTraceBinding] -> result)
  -> HumanTraceIdentity
  -> result
foldHumanTraceIdentity consume (HumanTraceIdentity graph bindings) =
  consume graph bindings
