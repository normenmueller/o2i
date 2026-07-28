{-# LANGUAGE OverloadedStrings #-}

-- | Deterministic, ANSI-free process output and human report rendering.
module O2I.Cli.Output
  ( OutputStream(..)
  , OutputFailure(..)
  , emitInspectionReport
  , emitCommandError
  , emitParserText
  , reportOutputFailure
  , renderHumanReport
  , renderHumanDiagnostics
  , renderHumanCommandError
  , renderHumanSourceLocation
  , writeHandleBytes
  ) where

import Control.Exception (IOException, try)
import Control.Monad (void)
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Lazy.Builder as Builder
import qualified Data.Text.Lazy.Encoding as LazyTextEncoding
import O2I.Cli.Options
import O2I.Cli.TerminalText (terminalSafeText)
import O2I.Inspection
import System.IO (Handle, hFlush, stderr, stdout)

-- | Intended process stream for one write.
data OutputStream
  = StandardOutput
  | StandardError
  deriving (Eq, Show)

-- | Failed write or flush on one non-recursive process stream.
newtype OutputFailure = OutputFailure
  { failedOutputStream :: OutputStream
  } deriving (Eq, Show)

-- | Write one completed report and its human diagnostics on separate streams.
emitInspectionReport ::
     OutputMode -> Verbosity -> InspectionReport -> IO (Either OutputFailure ())
emitInspectionReport mode verbosity report = do
  stdoutResult <- writeStream StandardOutput stdout reportBytes
  case stdoutResult of
    Left failure -> pure (Left failure)
    Right () ->
      let diagnostics = renderHumanDiagnostics verbosity report
       in if LazyByteString.null diagnostics
            then pure (Right ())
            else writeStream StandardError stderr diagnostics
  where
    reportBytes =
      case mode of
        HumanOutput -> renderHumanReport report
        JsonOutput -> renderInspectionReportJSON report <> "\n"

-- | Write one pre-report command error according to the selected output mode.
emitCommandError :: OutputMode -> CommandError -> IO (Either OutputFailure ())
emitCommandError mode commandError =
  case mode of
    HumanOutput ->
      writeStream StandardError stderr (renderHumanCommandError commandError)
    JsonOutput ->
      writeStream
        StandardOutput
        stdout
        (renderCommandErrorJSON commandError <> "\n")

-- | Write optparse help, version, or completion text to standard output.
emitParserText :: String -> IO (Either OutputFailure ())
emitParserText =
  writeStream StandardOutput stdout . encodeText . ensureLineEnding . Text.pack

-- | Best-effort output-failure reporting without recursive fallback.
reportOutputFailure :: OutputFailure -> IO ()
reportOutputFailure failure =
  case failedOutputStream failure of
    StandardOutput ->
      void
        (writeStream
           StandardError
           stderr
           "[o2i|error] Unable to write standard output.\n")
    StandardError -> pure ()

-- | Render the stable human report written only to standard output.
renderHumanReport :: InspectionReport -> LazyByteString.ByteString
renderHumanReport report =
  encodeBuilder
    (line ("O2I inspection: " <> resultText (reportResult report))
       <> line ("Source: " <> sourceText source)
       <> line
            ("SHA-256: "
               <> terminalSafeText (sourceHashText (sourceSha256 source)))
       <> supplementalSourceLines (reportSupplementalSources report)
       <> maybe mempty (line . ("Maturity: " <>)) (reportMaturityText report)
       <> line ("Adapter: " <> adapterText (requestAdapter request))
       <> line ("View: " <> selectorText (requestedViewSelector request))
       <> closedScopeProvenanceLines (reportClosedScopeProvenance report)
       <> line "Stages:"
       <> foldMap stageLine stages)
  where
    request = reportRequestInfo report
    source = requestSourceIdentity request
    stages = stageReportsList (reportStageReports report)

-- | Render diagnostics and verbosity-only context written only to stderr.
renderHumanDiagnostics ::
     Verbosity -> InspectionReport -> LazyByteString.ByteString
renderHumanDiagnostics verbosity report =
  encodeBuilder
    (verboseContext <> debugContext <> foldMap renderDiagnostic diagnostics)
  where
    request = reportRequestInfo report
    source = requestSourceIdentity request
    diagnostics = diagnosticsList (reportDiagnostics report)
    verboseContext
      | verbosity >= VerboseVerbosity =
        prefixedLine
          "info"
          ("Inspected "
             <> terminalSafeText (sourceDisplayLabel source)
             <> " with result "
             <> resultText (reportResult report)
             <> ".")
      | otherwise = mempty
    debugContext
      | verbosity >= DebugVerbosity =
        foldMap
          (\stage ->
             prefixedLine
               "debug"
               (stageText (reportedStage stage)
                  <> "="
                  <> stateText (reportedState stage)))
          (stageReportsList (reportStageReports report))
      | otherwise = mempty
    renderDiagnostic diagnostic =
      prefixedLine
        (severityText (diagnosticSeverity diagnostic))
        (terminalSafeText (diagnosticCodeText (diagnosticCode diagnostic))
           <> ": "
           <> terminalSafeText (diagnosticMessage diagnostic)
           <> verboseSubjects diagnostic
           <> debugLocations diagnostic
           <> debugSupplementalSources diagnostic)
    verboseSubjects diagnostic
      | verbosity >= VerboseVerbosity
          && not (null (diagnosticSubjects diagnostic)) =
        " ["
          <> Text.intercalate
               ", "
               (map subjectText (diagnosticSubjects diagnostic))
          <> "]"
      | otherwise = ""
    debugLocations diagnostic
      | verbosity >= DebugVerbosity
          && not (null (diagnosticLocations diagnostic)) =
        " {"
          <> Text.intercalate
               ", "
               (map locationText (diagnosticLocations diagnostic))
          <> "}"
      | otherwise = ""
    debugSupplementalSources diagnostic
      | verbosity >= DebugVerbosity
          && not (null (diagnosticSupplementalSources diagnostic)) =
        " <"
          <> Text.intercalate
               ", "
               (map
                  supplementalSourceText
                  (diagnosticSupplementalSources diagnostic))
          <> ">"
      | otherwise = ""

-- | Render one command failure as a prefixed human process error.
renderHumanCommandError :: CommandError -> LazyByteString.ByteString
renderHumanCommandError commandError =
  encodeBuilder (prefixedLine "error" message)
  where
    message =
      case commandError of
        InvocationCommandError _ detail -> terminalSafeText detail
        InputCommandError source detail ->
          "Cannot read "
            <> terminalSafeText source
            <> ": "
            <> terminalSafeText detail
        StructureInternalCommandError _ ->
          "Structural elaboration failed after model checks passed."

-- | Total, exception-normalizing write used by process code and handle tests.
writeHandleBytes :: Handle -> LazyByteString.ByteString -> IO Bool
writeHandleBytes handle bytes = do
  result <-
    try (LazyByteString.hPut handle bytes >> hFlush handle) :: IO
      (Either IOException ())
  pure
    (case result of
       Left _ -> False
       Right () -> True)

writeStream ::
     OutputStream
  -> Handle
  -> LazyByteString.ByteString
  -> IO (Either OutputFailure ())
writeStream stream handle bytes = do
  written <- writeHandleBytes handle bytes
  pure
    (if written
       then Right ()
       else Left (OutputFailure stream))

encodeBuilder :: Builder.Builder -> LazyByteString.ByteString
encodeBuilder = LazyTextEncoding.encodeUtf8 . Builder.toLazyText

encodeText :: Text -> LazyByteString.ByteString
encodeText = LazyByteString.fromStrict . TextEncoding.encodeUtf8

line :: Text -> Builder.Builder
line value = Builder.fromText value <> Builder.singleton '\n'

prefixedLine :: Text -> Text -> Builder.Builder
prefixedLine level message = line ("[o2i|" <> level <> "] " <> message)

ensureLineEnding :: Text -> Text
ensureLineEnding value = Text.stripEnd value <> "\n"

resultText :: InspectionResult -> Text
resultText result =
  case result of
    InspectionPassed -> "passed"
    InspectionPartial -> "partial"
    InspectionFailed -> "failed"

sourceText :: SourceIdentity -> Text
sourceText source =
  terminalSafeText (sourceDisplayLabel source)
    <> " ("
    <> inputKindText (sourceInputKind source)
    <> ")"

inputKindText :: SourceInputKind -> Text
inputKindText kind =
  case kind of
    FileSource -> "file"
    StandardInputSource -> "stdin"

supplementalSourceLines :: [SupplementalSource] -> Builder.Builder
supplementalSourceLines sources
  | null sources = mempty
  | otherwise =
    line "Supplemental sources:"
      <> foldMap (line . ("  " <>) . supplementalSourceText) sources

supplementalSourceText :: SupplementalSource -> Text
supplementalSourceText supplemental =
  supplementalKindText (supplementalInputKind supplemental)
    <> ": "
    <> sourceText source
    <> " sha256="
    <> terminalSafeText (sourceHashText (sourceSha256 source))
  where
    source = supplementalSourceIdentity supplemental

supplementalKindText :: SupplementalInputKind -> Text
supplementalKindText kind =
  case kind of
    StrategySupplement -> "strategy"
    CollectiveFitSupplement -> "collective-fit"
    ReadinessSupplement -> "readiness"
    EvidenceSupplement -> "evidence"

closedScopeProvenanceLines :: Maybe ClosedScopeProvenance -> Builder.Builder
closedScopeProvenanceLines maybeProvenance =
  case maybeProvenance of
    Nothing -> mempty
    Just provenance ->
      line "Closed scope provenance:"
        <> foldMap
             (line . ("  " <>) . occurrenceProvenanceText)
             (NonEmpty.toList (closedScopeProvenanceOccurrences provenance))

occurrenceProvenanceText :: OccurrenceProvenance -> Text
occurrenceProvenanceText provenance =
  terminalSafeText (occurrenceIdText (provenanceOccurrenceId provenance))
    <> " | "
    <> renderHumanSourceLocation (provenanceLocation provenance)
    <> " | reasons="
    <> Text.intercalate
         ","
         (map
            inclusionReasonText
            (NonEmpty.toList (provenanceReasons provenance)))

-- | Render one complete location with every source-derived scalar encoded.
renderHumanSourceLocation :: SourceLocation -> Text
renderHumanSourceLocation location =
  sourceText source
    <> " sha256="
    <> terminalSafeText (sourceHashText (sourceSha256 source))
    <> " path="
    <> Text.intercalate "/" (map pathStepText path)
    <> " target="
    <> locationTargetText (locationTarget location)
    <> maybe "" fullSpanText (locationSpan location)
  where
    source = locationSource location
    path = NonEmpty.toList (locationPath location)

pathStepText :: PathStep -> Text
pathStepText step =
  "{"
    <> maybe "" terminalSafeText (qNameNamespace name)
    <> "}"
    <> terminalSafeText (qNameLocalName name)
    <> "["
    <> naturalText (pathStepOrdinal step)
    <> "]"
  where
    name = pathStepName step

locationTargetText :: LocationTarget -> Text
locationTargetText target =
  case target of
    ElementTarget -> "element"
    AttributeTarget name -> "attribute:" <> qNameText name
    PropertyTarget key -> "property:" <> terminalSafeText key
    TextFieldTarget name -> "text-field:" <> qNameText name

qNameText :: ExpandedQName -> Text
qNameText name =
  "{"
    <> maybe "" terminalSafeText (qNameNamespace name)
    <> "}"
    <> terminalSafeText (qNameLocalName name)

fullSpanText :: SourceSpan -> Text
fullSpanText sourceSpan =
  " span="
    <> naturalText (spanStartLine sourceSpan)
    <> ":"
    <> naturalText (spanStartColumn sourceSpan)
    <> "-"
    <> naturalText (spanEndLine sourceSpan)
    <> ":"
    <> naturalText (spanEndColumn sourceSpan)

inclusionReasonText :: InclusionReason -> Text
inclusionReasonText reason =
  case reason of
    DirectPresentation -> "direct-presentation"
    RelationshipEndpoint -> "relationship-endpoint"
    ContextOwnership -> "context-ownership"
    PerformanceDimensionMembership -> "performance-dimension-membership"
    SituationDependency -> "situation-dependency"
    NeedDependency -> "need-dependency"
    MacroPremise -> "macro-premise"
    CollectiveRealizationSegment -> "collective-realization-segment"
    CollectiveRealizationParticipant -> "collective-realization-participant"
    CollectiveRealizationContribution -> "collective-realization-contribution"

adapterText :: AdapterDescriptor -> Text
adapterText adapter =
  terminalSafeText (adapterName adapter)
    <> " ("
    <> terminalSafeText (adapterIdentifier adapter)
    <> " "
    <> terminalSafeText (adapterVersion adapter)
    <> ")"

selectorText :: ViewSelector -> Text
selectorText selector =
  case selector of
    ViewByName name -> "name " <> quoted (terminalSafeText name)
    ViewById identifier -> "id " <> quoted (terminalSafeText identifier)

quoted :: Text -> Text
quoted value = "\"" <> value <> "\""

stageLine :: StageReport -> Builder.Builder
stageLine stage =
  line
    ("  "
       <> Text.justifyLeft 13 ' ' (stageText (reportedStage stage))
       <> stateText (reportedState stage))

stageText :: InspectionStage -> Text
stageText stage =
  case stage of
    DecodeStage -> "decode"
    ViewScopeStage -> "view-scope"
    ProfileStage -> "profile"
    StructureStage -> "structure"
    SemanticsStage -> "semantics"
    TraceabilityStage -> "traceability"
    ReadinessStage -> "readiness"
    EvidenceStage -> "evidence"

stateText :: StageState -> Text
stateText state =
  case state of
    StagePassed -> "passed"
    StageFailed -> "failed"
    StageUnavailable -> "unavailable"
    StageNotRun reason -> "not-run (" <> blockReasonText reason <> ")"

blockReasonText :: BlockReason -> Text
blockReasonText reason =
  case reason of
    BlockedByFailure stage -> "failed " <> stageText stage
    BlockedByUnavailable stage -> "unavailable " <> stageText stage

severityText :: DiagnosticSeverity -> Text
severityText severity =
  case severity of
    DebugSeverity -> "debug"
    InfoSeverity -> "info"
    WarningSeverity -> "warn"
    ErrorSeverity -> "error"

subjectText :: DiagnosticSubject -> Text
subjectText subject =
  terminalSafeText (subjectKind subject)
    <> "="
    <> terminalSafeText (subjectIdentifier subject)

locationText :: SourceLocation -> Text
locationText location =
  terminalSafeText (sourceDisplayLabel (locationSource location))
    <> maybe "" spanText (locationSpan location)

spanText :: SourceSpan -> Text
spanText sourceSpan =
  ":"
    <> naturalText (spanStartLine sourceSpan)
    <> ":"
    <> naturalText (spanStartColumn sourceSpan)

naturalText :: Show value => value -> Text
naturalText = Text.pack . show
