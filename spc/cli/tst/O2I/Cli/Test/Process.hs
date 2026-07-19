{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Process
  ( tests
  ) where

import Data.Aeson (Value(..), decodeStrict')
import Data.Aeson.Key (Key)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as ByteString
import O2I.Cli.Test.Support
import System.Exit (ExitCode(..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "process"
    [ testCase "top-level help" topLevelHelp
    , testCase "inspect help" inspectHelp
    , testCase "version" version
    , testCase "exact-name selection" exactNameSelection
    , testCase "stable-ID selection" stableIdentifierSelection
    , testCase "stdin source identity" stdinIdentity
    , testCase "file and stdin preserve model result" fileStdinEquivalence
    , testCase "one-byte stdin chunks are deterministic" chunkDeterminism
    , testCase "model failure exits 1" modelFailure
    , testCase "empty stdin exits 1" emptyInputFailure
    , testCase "missing View exits 1" missingViewFailure
    , testCase "command failure exits 2" commandFailure
    , testCase "partial inspection exits 3" partialFailure
    , testCase "invalid invocation exits 2" invocationFailure
    , testCase "invalid JSON invocation is uncontaminated" jsonInvocation
    , testCase
        "JSON before option termination selects JSON errors"
        jsonBeforeTerminator
    , testCase "JSON after option termination is positional" jsonAfterTerminator
    , testCase "JSON model diagnostics remain on stderr" jsonDiagnostics
    , testCase "unsupported options fail in the executable" forbiddenOptions
    , testCase
        "human stdout and diagnostics stderr are separate"
        streamSeparation
    , testCase "verbose leaves report bytes unchanged" verboseReport
    , testCase "debug includes verbose diagnostics" debugIncludesVerbose
    , testCase "repeated process output is deterministic" repeatedOutput
    , testCase "repeated diagnostics are deterministic" repeatedDiagnostics
    , testCase "human report golden" humanGolden
    , testCase "JSON report golden" jsonGolden
    ]

topLevelHelp :: Assertion
topLevelHelp = do
  result <- runO2I ["--help"] ByteString.empty
  expected <- goldenBytes "help.txt"
  processExitCode result @?= ExitSuccess
  processStdout result @?= expected
  processStderr result @?= ByteString.empty

inspectHelp :: Assertion
inspectHelp = do
  result <- runO2I ["inspect", "--help"] ByteString.empty
  processExitCode result @?= ExitSuccess
  assertContains (processStdout result) "MODEL (--view NAME | --view-id ID)"
  assertContains (processStdout result) "Model path, or - for standard input."
  countOccurrences "-h,--help" (processStdout result) @?= 1
  assertNotContains (processStdout result) "RawGraph"

version :: Assertion
version = do
  result <- runO2I ["--version"] ByteString.empty
  processExitCode result @?= ExitSuccess
  processStdout result @?= "o2i 0.2.0.0\n"
  processStderr result @?= ByteString.empty

exactNameSelection :: Assertion
exactNameSelection = do
  result <- partialStdin ["--view", "CLI Scope", "--json"]
  processExitCode result @?= ExitFailure 3
  assertContains (processStdout result) "\"kind\":\"name\""

stableIdentifierSelection :: Assertion
stableIdentifierSelection = do
  result <- partialStdin ["--view-id", "view", "--json"]
  processExitCode result @?= ExitFailure 3
  assertContains (processStdout result) "\"kind\":\"id\""

stdinIdentity :: Assertion
stdinIdentity = do
  result <- partialStdin ["--view", "CLI Scope", "--json"]
  assertContains (processStdout result) "\"label\":\"<stdin>\""
  assertContains (processStdout result) "\"inputKind\":\"stdin\""

fileStdinEquivalence :: Assertion
fileStdinEquivalence = do
  path <- fixturePath "partial-strategy.archimate"
  fileResult <-
    runO2I ["inspect", path, "--view", "CLI Scope", "--json"] ByteString.empty
  stdinResult <- partialStdin ["--view", "CLI Scope", "--json"]
  processExitCode fileResult @?= processExitCode stdinResult
  jsonField "result" fileResult @?= jsonField "result" stdinResult
  jsonField "stages" fileResult @?= jsonField "stages" stdinResult
  assertContains
    (processStdout fileResult)
    "\"sha256\":\"6adc62d01690e46fc7158df3d200b1064839a1f2a024dacce7a6aba911be8926\""
  assertContains
    (processStdout stdinResult)
    "\"sha256\":\"6adc62d01690e46fc7158df3d200b1064839a1f2a024dacce7a6aba911be8926\""

chunkDeterminism :: Assertion
chunkDeterminism = do
  bytes <- fixtureBytes "partial-strategy.archimate"
  whole <- runO2I ["inspect", "-", "--view", "CLI Scope", "--json"] bytes
  chunked <-
    runO2IChunks
      ["inspect", "-", "--view", "CLI Scope", "--json"]
      (map ByteString.singleton (ByteString.unpack bytes))
  chunked @?= whole

modelFailure :: Assertion
modelFailure = do
  bytes <- fixtureBytes "malformed.archimate"
  result <- runO2I ["inspect", "-", "--view", "Scope"] bytes
  processExitCode result @?= ExitFailure 1
  assertContains (processStdout result) "O2I inspection: failed"
  assertContains (processStderr result) "[o2i|error] o2i.amx.decode."

emptyInputFailure :: Assertion
emptyInputFailure = do
  result <- runO2I ["inspect", "-", "--view", "Scope"] ByteString.empty
  processExitCode result @?= ExitFailure 1
  assertContains (processStdout result) "decode       failed"

missingViewFailure :: Assertion
missingViewFailure = do
  result <- partialStdin ["--view", "Missing"]
  processExitCode result @?= ExitFailure 1
  assertContains (processStdout result) "view-scope   failed"

commandFailure :: Assertion
commandFailure = do
  result <-
    runO2I
      ["inspect", "missing-cli-model.archimate", "--view", "Scope"]
      ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  assertContains (processStderr result) "[o2i|error] Cannot read"

partialFailure :: Assertion
partialFailure = do
  result <- partialStdin ["--view", "CLI Scope"]
  processExitCode result @?= ExitFailure 3
  assertContains (processStdout result) "semantics    unavailable"

invocationFailure :: Assertion
invocationFailure = do
  result <- runO2I ["inspect"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  assertContains (processStderr result) "[o2i|error] Missing: MODEL"

jsonInvocation :: Assertion
jsonInvocation = do
  result <- runO2I ["inspect", "--json"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertContains (processStdout result) "\"schema\":\"o2i.command-error/v1\""
  assertNotContains (processStdout result) "[o2i|error]"

jsonBeforeTerminator :: Assertion
jsonBeforeTerminator = do
  result <- runO2I ["inspect", "--json", "--", "model"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertContains (processStdout result) "\"schema\":\"o2i.command-error/v1\""

jsonAfterTerminator :: Assertion
jsonAfterTerminator = do
  result <- runO2I ["inspect", "--", "--json"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  assertContains
    (processStderr result)
    "[o2i|error] Missing: (--view NAME | --view-id ID)"
  assertNotContains (processStderr result) "\"schema\""

jsonDiagnostics :: Assertion
jsonDiagnostics = do
  bytes <- fixtureBytes "malformed.archimate"
  result <- runO2I ["inspect", "-", "--view", "Scope", "--json"] bytes
  processExitCode result @?= ExitFailure 1
  case decodeStrict' (processStdout result) :: Maybe Value of
    Nothing -> assertFailure "stdout is not an inspection JSON document"
    Just _ -> pure ()
  assertNotContains (processStdout result) "[o2i|"
  assertContains (processStderr result) "[o2i|error] o2i.amx.decode."

forbiddenOptions :: Assertion
forbiddenOptions = mapM_ assertRejected ["--format", "--through", "--no-color"]
  where
    assertRejected option = do
      result <-
        runO2I
          ["inspect", "model.archimate", "--view", "Scope", option]
          ByteString.empty
      processExitCode result @?= ExitFailure 2
      processStdout result @?= ByteString.empty

streamSeparation :: Assertion
streamSeparation = do
  bytes <- fixtureBytes "malformed.archimate"
  result <- runO2I ["inspect", "-", "--view", "Scope"] bytes
  assertNotContains (processStdout result) "[o2i|"
  assertNotContains (processStderr result) "O2I inspection:"

verboseReport :: Assertion
verboseReport = do
  normal <- partialStdin ["--view", "CLI Scope"]
  verbose <- partialStdin ["--view", "CLI Scope", "--verbose"]
  processStdout verbose @?= processStdout normal
  assertContains (processStderr verbose) "[o2i|info] Inspected <stdin>"

debugIncludesVerbose :: Assertion
debugIncludesVerbose = do
  debug <- partialStdin ["--view", "CLI Scope", "--debug"]
  assertContains (processStderr debug) "[o2i|info] Inspected <stdin>"
  assertContains (processStderr debug) "[o2i|debug] decode=passed"

repeatedOutput :: Assertion
repeatedOutput = do
  first <- partialStdin ["--view", "CLI Scope", "--json"]
  second <- partialStdin ["--view", "CLI Scope", "--json"]
  second @?= first

repeatedDiagnostics :: Assertion
repeatedDiagnostics = do
  bytes <- fixtureBytes "malformed.archimate"
  first <- runO2I ["inspect", "-", "--view", "Scope", "--json"] bytes
  second <- runO2I ["inspect", "-", "--view", "Scope", "--json"] bytes
  second @?= first

humanGolden :: Assertion
humanGolden = do
  actual <- partialStdin ["--view", "CLI Scope"]
  expected <- goldenBytes "inspect-human.txt"
  processStdout actual @?= expected

jsonGolden :: Assertion
jsonGolden = do
  actual <- partialStdin ["--view", "CLI Scope", "--json"]
  expected <- goldenBytes "inspect-json.json"
  processStdout actual @?= expected

partialStdin :: [String] -> IO ProcessResult
partialStdin extra = do
  bytes <- fixtureBytes "partial-strategy.archimate"
  runO2I (["inspect", "-"] <> extra) bytes

jsonField :: Key -> ProcessResult -> Maybe Value
jsonField name result = do
  value <- decodeStrict' (processStdout result)
  case value of
    Object object -> KeyMap.lookup name object
    _ -> Nothing

assertContains :: ByteString.ByteString -> ByteString.ByteString -> Assertion
assertContains actual expected =
  assertBool
    ("missing expected bytes: " <> show expected)
    (ByteString.isInfixOf expected actual)

assertNotContains :: ByteString.ByteString -> ByteString.ByteString -> Assertion
assertNotContains actual unexpected =
  assertBool
    ("unexpected bytes: " <> show unexpected)
    (not (ByteString.isInfixOf unexpected actual))

countOccurrences :: ByteString.ByteString -> ByteString.ByteString -> Int
countOccurrences needle haystack
  | ByteString.null needle = 0
  | otherwise =
    case ByteString.breakSubstring needle haystack of
      (_, suffix)
        | ByteString.null suffix -> 0
        | otherwise ->
          1
            + countOccurrences
                needle
                (ByteString.drop (ByteString.length needle) suffix)
