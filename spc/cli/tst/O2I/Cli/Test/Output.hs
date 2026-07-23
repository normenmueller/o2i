{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Output
  ( tests
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as ByteStringChar8
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Char (chr, ord)
import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Adapter.AMX (amxAdapter)
import O2I.Cli.Options (Verbosity(DebugVerbosity))
import O2I.Cli.Output
import O2I.Cli.TerminalText (terminalSafeText)
import O2I.Inspection
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openBinaryTempFile)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "output"
    [ testCase "terminal encoding covers C0, DEL, and C1" controlEncoding
    , testCase "terminal encoding preserves readable text" readableEncoding
    , testCase "invocation errors retain one intact prefix" prefixedInvocation
    , testCase "input errors do not enter stdout report syntax" inputError
    , testCase
        "adapter and diagnostic scalars are terminal-safe"
        hostileInspection
    , testCase
        "collective partial-View human output is deterministic"
        collectivePartialViewOutput
    , testCase "SourceLocation scalars are terminal-safe" hostileLocation
    , testCase "human output contains no ANSI escape" ansiFree
    , testCase "closed output handle is normalized" closedHandle
    ]

controlEncoding :: Assertion
controlEncoding = do
  terminalSafeText "\r\n\ESC\DEL\x0085\&\x009f"
    @?= "\\u{000D}\\u{000A}\\u{001B}\\u{007F}\\u{0085}\\u{009F}"
  let controls =
        Text.pack (map chr ([0x00 .. 0x1f] <> [0x7f] <> [0x80 .. 0x9f]))
      encoded = terminalSafeText controls
  assertBool "encoded controls remain in output" (terminalSafe encoded)
  countText "\\u{" encoded @?= 65

readableEncoding :: Assertion
readableEncoding = do
  terminalSafeText "Visible ASCII and Unicode: \x00c4\& \x03a9\& \x2192"
    @?= "Visible ASCII and Unicode: \x00c4\& \x03a9\& \x2192"
  terminalSafeText "literal \\u{000A}" @?= "literal \\\\u{000A}"

prefixedInvocation :: Assertion
prefixedInvocation =
  renderHumanCommandError
    (InvocationCommandError InvalidInvocation "first line\nsecond line")
    @?= "[o2i|error] first line\\u{000A}second line\n"

inputError :: Assertion
inputError =
  renderHumanCommandError (InputCommandError "missing" "not found")
    @?= "[o2i|error] Cannot read missing: not found\n"

hostileInspection :: Assertion
hostileInspection = do
  report <- adversarialReport
  let human = LazyByteString.toStrict (renderHumanReport report)
      diagnostics =
        LazyByteString.toStrict (renderHumanDiagnostics DebugVerbosity report)
      escaped = TextEncoding.encodeUtf8 (terminalSafeText adversarialText)
  assertContains human ("Adapter: a" <> escaped)
  assertContains human ("View: id \"" <> escaped <> "\"")
  assertContains diagnostics ("[o2i|warn] o2i.test." <> escaped)
  assertContains diagnostics ("[" <> escaped <> "=" <> escaped <> "]")
  assertTerminalSafe human
  assertTerminalSafe diagnostics
  assertPrefixed diagnostics

collectivePartialViewOutput :: Assertion
collectivePartialViewOutput = do
  report <- collectivePartialViewReport
  let firstReport = renderHumanReport report
      secondReport = renderHumanReport report
      firstDiagnostics = renderHumanDiagnostics DebugVerbosity report
      secondDiagnostics = renderHumanDiagnostics DebugVerbosity report
  firstReport @?= secondReport
  firstDiagnostics @?= secondDiagnostics
  assertContains
    (LazyByteString.toStrict firstReport)
    "collective-realization-segment"
  assertContains
    (LazyByteString.toStrict firstDiagnostics)
    "shown-contributors=0"
  assertContains
    (LazyByteString.toStrict firstDiagnostics)
    "total-contributors=2"

collectivePartialViewReport :: IO InspectionReport
collectivePartialViewReport =
  case inspectSourceDocument
         amxAdapter
         (ViewByName "Partial")
         emptyInputs
         (sourceDocumentFromBytes
            "collective.archimate"
            FileSource
            (TextEncoding.encodeUtf8 collectivePartialViewModel)) of
    InspectionCompleted report -> pure report
    InspectionCommandFailed failure ->
      fail ("unexpected command failure: " <> show failure)

collectivePartialViewModel :: Text
collectivePartialViewModel =
  Text.concat
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    , "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" "
    , "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
    , "version=\"5.0.0\"><folder>"
    , strategy "contributor-a"
    , strategy "contributor-b"
    , strategy "target"
    , "<element xsi:type=\"a:Junction\" id=\"claim\" name=\"claim\">"
    , propertyText "o2i.kind" "Claim"
    , propertyText "o2i.type" "CollectiveStrategyRealization"
    , propertyText "o2i.commitment" "asserted"
    , propertyText "o2i.collective-fit-evidence" "fit-claim"
    , "</element>"
    , realization "incoming-a" "contributor-a" "claim"
    , realization "incoming-b" "contributor-b" "claim"
    , realization "outgoing" "claim" "target"
    , "<element xsi:type=\"a:ArchimateDiagramModel\" id=\"partial\" "
    , "name=\"Partial\"><child xsi:type=\"a:DiagramObject\" "
    , "id=\"claim-object\" archimateElement=\"claim\"/></element>"
    , "</folder>"
    , propertyText "o2i.profile" "0.2"
    , "</a:model>"
    ]
  where
    strategy identifier =
      Text.concat
        [ "<element xsi:type=\"a:Grouping\" id=\""
        , identifier
        , "\" name=\""
        , identifier
        , "\">"
        , propertyText "o2i.kind" "Context"
        , propertyText "o2i.type" "Strategy"
        , "</element>"
        ]
    realization identifier source target =
      Text.concat
        [ "<element xsi:type=\"a:RealizationRelationship\" id=\""
        , identifier
        , "\" name=\"realizes\" source=\""
        , source
        , "\" target=\""
        , target
        , "\"/>"
        ]
    propertyText key value =
      "<property key=\"" <> key <> "\" value=\"" <> value <> "\"/>"

hostileLocation :: Assertion
hostileLocation = do
  report <- adversarialReport
  case concatMap
         diagnosticLocations
         (diagnosticsList (reportDiagnostics report)) of
    location:_ -> do
      let rendered = renderHumanSourceLocation location
          escaped = terminalSafeText adversarialText
      assertBool
        "property target was not encoded"
        (("target=property:" <> escaped) `Text.isInfixOf` rendered)
      assertBool
        "QName path was not encoded"
        (("{" <> escaped <> "}q" <> escaped) `Text.isInfixOf` rendered)
      assertBool "location contains raw controls" (terminalSafe rendered)
    [] -> assertFailure "adversarial diagnostic has no SourceLocation"

ansiFree :: Assertion
ansiFree =
  assertBool
    "unexpected ANSI control sequence"
    (not
       (ByteString.isInfixOf
          "\ESC["
          (LazyByteString.toStrict
             (renderHumanCommandError
                (InvocationCommandError InvalidInvocation "invalid")))))

closedHandle :: Assertion
closedHandle = do
  temporary <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile temporary "o2i-cli-output"
  hClose handle
  written <- writeHandleBytes handle "report"
  removeFile path
  assertBool "closed handle should reject output" (not written)

adversarialReport :: IO InspectionReport
adversarialReport =
  case inspectSourceDocument
         adversarialAdapter
         (ViewById adversarialText)
         emptyInputs
         (sourceDocumentFromBytes adversarialText FileSource "model") of
    InspectionCompleted report -> pure report
    InspectionCommandFailed failure ->
      fail ("unexpected command failure: " <> show failure)

adversarialAdapter :: Adapter
adversarialAdapter =
  case amxAdapter of
    Adapter _ _ _ resolveView viewDefect contract observe ->
      Adapter
        descriptor
        decode
        diagnostic
        resolveView
        viewDefect
        contract
        observe
  where
    descriptor =
      adapterDescriptor
        ('a' :| Text.unpack adversarialText)
        ('a' :| Text.unpack adversarialText)
        ('a' :| Text.unpack adversarialText)
    decode _ =
      DecodeUnavailable
        (DecodeUnavailableObservation EncodingNotObserved)
        (Located adversarialPosition () :| [])
    diagnostic () =
      diagnosticSpec
        (o2iDiagnosticCode ("test." <> adversarialText))
        WarningSeverity
        ModelFinding
        adversarialText
        [DiagnosticSubject adversarialText adversarialText]
        mempty

adversarialPosition :: SourcePosition
adversarialPosition =
  sourcePosition
    (firstPathStep name :| [])
    (PropertyTarget adversarialText)
    Nothing
  where
    name = expandedQName (Just adversarialText) 'q' adversarialText

emptyInputs :: InspectionInputs
emptyInputs =
  InspectionInputs
    { strategyInput = Absent
    , collectiveFitInput = Absent
    , readinessInput = Absent
    , evidenceInput = Absent
    }

adversarialText :: Text
adversarialText = "ASCII\\literal\r\n\ESC\DEL\x0085\&\x009f\x03a9"

terminalSafe :: Text -> Bool
terminalSafe = Text.all safeCharacter
  where
    safeCharacter character =
      let code = ord character
       in code > 0x1f && code /= 0x7f && not (code >= 0x80 && code <= 0x9f)

assertTerminalSafe :: ByteString.ByteString -> Assertion
assertTerminalSafe bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left failure -> assertFailure (show failure)
    Right rendered ->
      assertBool
        "human output contains raw controls"
        (Text.all
           (\character ->
              character == '\n' || terminalSafe (Text.singleton character))
           rendered)

assertPrefixed :: ByteString.ByteString -> Assertion
assertPrefixed bytes =
  mapM_
    (assertBool "diagnostic prefix was displaced"
       . ByteString.isPrefixOf "[o2i|")
    (ByteStringChar8.lines bytes)

assertContains :: ByteString.ByteString -> ByteString.ByteString -> Assertion
assertContains actual expected =
  assertBool
    ("missing expected bytes: " <> show expected)
    (ByteString.isInfixOf expected actual)

countText :: Text -> Text -> Int
countText needle = length . Text.breakOnAll needle
