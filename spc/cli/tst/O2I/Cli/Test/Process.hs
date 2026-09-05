{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Process
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import Data.Char (ord)
import Data.JSON.JSONSchema (validateJSONSchema)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric (showHex)
import O2I.Cli.Test.Support
import O2I.Operation.Command.Error.Machine (commandErrorSchemaBytes)
import System.Exit (ExitCode(..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "process"
    [ testCase "root help golden" rootHelp
    , testCase "every admitted command path has exact help" allCommandHelp
    , testCase "root version" version
    , testCase "adapter human golden" (golden "adapters-human.txt" ["adapters"])
    , testCase
        "adapter machine golden"
        (golden "adapters-json.json" ["adapters", "--json"])
    , testCase "Profile human golden" (golden "profiles-human.txt" ["profiles"])
    , testCase
        "Profile machine golden"
        (golden "profiles-json.json" ["profiles", "--json"])
    , testCase
        "rules and explanations retain complete Human authority"
        ruleHumanReports
    , testCase
        "rules and explanations retain complete Machine authority"
        ruleMachineReports
    , testCase "human command error uses stderr only" humanCommandError
    , testCase "machine command error uses stdout only" machineCommandError
    , testCase
        "option-looking fixed operand selects human mode"
        optionLookingOperand
    , testCase "stdin cardinality error is machine-safe" stdinCardinality
    , testCase "marker placement error retains JSON intent" markerPlacement
    , testCase "human error scalars are terminal-safe" terminalSafeError
    , testCase
        "all model reports render complete terminal-safe Human projections"
        realHumanReports
    , testCase
        "all machine-capable model reports preserve canonical documents"
        realMachineReports
    , testCase
        "qualification-subject supplemental failure is canonical machine output"
        qualificationSubjectsMachineFailure
    , testCase
        "qualification-subject supplemental failure is complete Human output"
        qualificationSubjectsHumanFailure
    , testCase
        "debug Human output strictly extends verbose with exact machine bytes"
        verbosityExtension
    ]

rootHelp :: Assertion
rootHelp = do
  result <- runO2I ["--help"] ByteString.empty
  expected <- goldenBytes "help.txt"
  result @?= ProcessResult ExitSuccess expected ByteString.empty

allCommandHelp :: Assertion
allCommandHelp = mapM_ assertHelp commandPaths
  where
    assertHelp path = do
      result <- runO2I (path <> ["--help"]) ByteString.empty
      processExitCode result @?= ExitSuccess
      assertContains (processStdout result) "Usage: o2i "
      processStderr result @?= ByteString.empty

version :: Assertion
version = do
  result <- runO2I ["--version"] ByteString.empty
  result @?= ProcessResult ExitSuccess "o2i 0.3.0.0\n" ByteString.empty

golden :: FilePath -> [String] -> Assertion
golden name arguments = do
  result <- runO2I arguments ByteString.empty
  expected <- goldenBytes name
  result @?= ProcessResult ExitSuccess expected ByteString.empty

ruleHumanReports :: Assertion
ruleHumanReports = mapM_ assertAuthority ruleAuthorities
  where
    assertAuthority (authority, rule, authorityLine, ruleLine) = do
      inventory <- runO2I (["rules"] <> authority) ByteString.empty
      processExitCode inventory @?= ExitSuccess
      processStderr inventory @?= ByteString.empty
      assertContains (processStdout inventory) "O2I rules: discovered\n"
      assertContains (processStdout inventory) authorityLine
      assertContains (processStdout inventory) ruleLine
      found <- runO2I (["explain"] <> authority <> [rule]) ByteString.empty
      processExitCode found @?= ExitSuccess
      processStderr found @?= ByteString.empty
      assertContains (processStdout found) "O2I rule explanation: found\n"
      assertContains (processStdout found) authorityLine
      assertContains
        (processStdout found)
        ("  requested=\"" <> TextEncoding.encodeUtf8 (Text.pack rule) <> "\"\n")
      assertContains (processStdout found) ruleLine
      missing <-
        runO2I
          (["explain"] <> authority <> ["hostile-\"missing\""])
          ByteString.empty
      processExitCode missing @?= ExitFailure 1
      processStderr missing @?= ByteString.empty
      assertContains (processStdout missing) "O2I rule explanation: not-found\n"
      assertContains (processStdout missing) authorityLine
      assertContains
        (processStdout missing)
        "  requested=\"hostile-\\\"missing\\\"\"\n"
      mapM_ (assertTerminalSafe . processStdout) [inventory, found, missing]

ruleMachineReports :: Assertion
ruleMachineReports = mapM_ assertAuthority ruleAuthorities
  where
    assertAuthority (authority, rule, _, _) = do
      inventory <-
        runO2I (["rules"] <> authority <> ["--json"]) ByteString.empty
      processExitCode inventory @?= ExitSuccess
      processStderr inventory @?= ByteString.empty
      assertJsonObject (processStdout inventory)
      assertContains
        (processStdout inventory)
        "\"schema\":\"o2i.discovery.rule-inventory/v1\""
      assertContains (processStdout inventory) "\"kind\":\"rule-inventory\""
      ByteString.count 10 (processStdout inventory) @?= 1
      found <-
        runO2I (["explain"] <> authority <> [rule, "--json"]) ByteString.empty
      processExitCode found @?= ExitSuccess
      processStderr found @?= ByteString.empty
      assertJsonObject (processStdout found)
      assertContains
        (processStdout found)
        "\"schema\":\"o2i.discovery.rule-explanation/v1\""
      assertContains (processStdout found) "\"kind\":\"rule-explanation-found\""
      assertContains
        (processStdout found)
        ("\"requestedRuleId\":\""
           <> TextEncoding.encodeUtf8 (Text.pack rule)
           <> "\"")
      missing <-
        runO2I
          (["explain"] <> authority <> ["hostile-\"missing\"", "--json"])
          ByteString.empty
      processExitCode missing @?= ExitFailure 1
      processStderr missing @?= ByteString.empty
      assertJsonObject (processStdout missing)
      assertContains
        (processStdout missing)
        "\"kind\":\"rule-explanation-not-found\""
      assertContains
        (processStdout missing)
        "\"requestedRuleId\":\"hostile-\\\"missing\\\"\""

ruleAuthorities ::
     [([String], String, ByteString.ByteString, ByteString.ByteString)]
ruleAuthorities =
  [ ( ["operation"]
    , "bootstrap.profile-adapter.adapter-id"
    , "  authority=operation | subject=unavailable | contract=\"o2i.operation\" | version=\"0.3.0\" | sha256=\"3566684fcc278d3359f7c4620f9f058c39fd9a8dd9fd12b5616da5b860bfe347\"\n"
    , "  \"bootstrap.profile-adapter.adapter-id\" | \"preparation\" | expectation=\"The selected adapter identifier is admitted by the resolved compiled Profile.\" | meaning=\"A Profile explicitly declares which compiled adapters may project its notation.\" | action=\"Select an admitted adapter or update the compiled Profile contract.\"\n")
  , ( ["core"]
    , "core.assessment.actual-start.cardinality"
    , "  authority=core | subject=unavailable | contract=\"o2i.core-semantics\" | version=\"0.3.0\" | sha256=\"fa431df65d5a5fdd64d91d5ad4089a3e8e31421027f4e0258370e742c8b1a333\"\n"
    , "  \"core.assessment.actual-start.cardinality\" | \"readiness-and-assessment\" | expectation=\"An assessment has exactly one actual start for the traced Intervention.\" | meaning=\"Assessment chronology begins from one unambiguous Intervention start.\" | action=\"Provide one actual start bound to the traced Intervention.\"\n")
  , ( ["adapter", "amx"]
    , "o2i.amx.decode.encoding"
    , "  authority=adapter | subject=\"amx\" | contract=\"amx\" | version=\"5.0.0-v1\" | sha256=unavailable\n"
    , "  \"o2i.amx.decode.encoding\" | \"preparation\" | expectation=\"The XML encoding is UTF-8.\" | meaning=\"Draft projection requires one complete, safely decoded native XML observation.\" | action=\"Save the AMX document with UTF-8 encoding.\"\n")
  , ( ["profile", "o2i.archimate-profile@0.3"]
    , "carrier:context"
    , "  authority=profile | subject=\"o2i.archimate-profile@0.3\" | contract=\"o2i.archimate-profile\" | version=\"0.3.0\" | sha256=\"3254127ed6029c6df26fb30578956429fe9d3f82de8ee2f9bbe8d363b676d081\"\n"
    , "  \"carrier:context\" | \"profile\" | expectation=\"A displayed concept carrying an O2I type in [Ethos, Mission, Vision, Strategy, Situation, Need, Intervention, Measure] must use ArchiMate element 'Grouping' in carrier category 'Context'.\" | meaning=\"The carrier tuple is the compiled notation representation of those O2I types.\" | action=\"Use ArchiMate element 'Grouping' and an admitted o2i.type value.\"\n")
  ]

humanCommandError :: Assertion
humanCommandError = do
  result <- runO2I ["frobnicate"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  assertContains (processStderr result) "[o2i|error] \"cli.argument.command\":"

machineCommandError :: Assertion
machineCommandError = do
  result <- runO2I ["adapters", "--json=true"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertMachineError (processStdout result)

optionLookingOperand :: Assertion
optionLookingOperand = do
  result <- runO2I ["views", "--json=true"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  assertContains (processStdout result) "O2I views: failed\n  acquisition|"
  assertContains (processStdout result) "--json=true"
  processStderr result @?= ByteString.empty

stdinCardinality :: Assertion
stdinCardinality = do
  result <-
    runO2I
      ["readiness", "-", "--view", "Scope", "--input", "-", "--json"]
      ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertMachineError (processStdout result)

markerPlacement :: Assertion
markerPlacement = do
  result <- runO2I ["adapters", "--", "--json"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertMachineError (processStdout result)

terminalSafeError :: Assertion
terminalSafeError = do
  result <- runO2I ["bad\n\ESC\DEL\x0085"] ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  case TextEncoding.decodeUtf8' (processStderr result) of
    Left failure -> assertFailure (show failure)
    Right rendered ->
      assertBool
        "stderr contains an unsafe terminal control"
        (Text.all safeCharacter rendered)
  assertContains
    (processStderr result)
    "bad\\u{000A}\\u{001B}\\u{007F}\\u{0085}"

realHumanReports :: Assertion
realHumanReports = do
  model <- fixturePath "profiled-minimal.archimate"
  readiness <- fixturePath "readiness-input.json"
  assessment <- fixturePath "assessment-input.json"
  mapM_
    assertHumanReport
    [ ( ["views", model]
      , ExitSuccess
      , "O2I views: discovered\n"
      , "|views|o2i|0.3.0.0|")
    , ( ["qualification-subjects", model, "--view", "KPI", "--verbose"]
      , ExitSuccess
      , "O2I qualification-subjects: discovered\n"
      , "|qualification-subjects|o2i|0.3.0.0|")
    , ( ["validate", model, "--view", "KPI", "--level", "semantics", "--debug"]
      , ExitSuccess
      , "O2I validate: accepted\n"
      , "|validate|o2i|0.3.0.0|")
    , ( ["trace", model, "--view", "KPI"]
      , ExitFailure 1
      , "O2I trace: partial\n"
      , "|trace|o2i|0.3.0.0|")
    , ( ["qualify", model, "--view", "KPI", "--strategy-id", "strategy"]
      , ExitSuccess
      , "O2I qualify: completed\n"
      , "|qualify|o2i|0.3.0.0|")
    , ( ["readiness", model, "--view", "KPI", "--input", readiness]
      , ExitFailure 3
      , "O2I readiness: unavailable\n"
      , "|readiness|o2i|0.3.0.0|")
    , ( ["assess", model, "--view", "KPI", "--input", assessment]
      , ExitFailure 3
      , "O2I assess: subject-unavailable\n"
      , "|assess|o2i|0.3.0.0|")
    ]
  where
    assertHumanReport (arguments, expectedExit, status, envelope) = do
      result <- runO2I arguments ByteString.empty
      processExitCode result @?= expectedExit
      processStderr result @?= ByteString.empty
      assertContains (processStdout result) status
      assertContains (processStdout result) envelope
      assertTerminalSafe (processStdout result)

realMachineReports :: Assertion
realMachineReports = do
  model <- fixturePath "profiled-minimal.archimate"
  readiness <- fixturePath "readiness-input.json"
  assessment <- fixturePath "assessment-input.json"
  mapM_
    assertMachineReport
    [ ( ["views", model, "--json"]
      , ExitSuccess
      , "o2i.discovery.view/v2"
      , "views")
    , ( ["qualification-subjects", model, "--view", "KPI", "--json"]
      , ExitSuccess
      , "o2i.discovery.qualification-subjects/v1"
      , "qualification-subjects")
    , ( ["validate", model, "--view", "KPI", "--level", "semantics", "--json"]
      , ExitSuccess
      , "o2i.operation.validate/v1"
      , "validate")
    , ( ["trace", model, "--view", "KPI", "--json"]
      , ExitFailure 1
      , "o2i.operation.trace/v1"
      , "trace")
    , ( [ "qualify"
        , model
        , "--view"
        , "KPI"
        , "--strategy-id"
        , "strategy"
        , "--json"
        ]
      , ExitSuccess
      , "o2i.operation.qualify/v1"
      , "qualify")
    , ( ["readiness", model, "--view", "KPI", "--input", readiness, "--json"]
      , ExitFailure 3
      , "o2i.operation.readiness/v1"
      , "readiness")
    , ( ["assess", model, "--view", "KPI", "--input", assessment, "--json"]
      , ExitFailure 3
      , "o2i.operation.assess/v1"
      , "assess")
    ]
  where
    assertMachineReport (arguments, expectedExit, schema, operation) = do
      result <- runO2I arguments ByteString.empty
      processExitCode result @?= expectedExit
      processStderr result @?= ByteString.empty
      assertJsonObject (processStdout result)
      assertContains (processStdout result) ("\"schema\":\"" <> schema <> "\"")
      assertContains
        (processStdout result)
        ("\"operation\":\"" <> operation <> "\"")
      assertContains
        (processStdout result)
        "\"tool\":{\"identity\":\"o2i\",\"version\":\"0.3.0.0\"}"
      ByteString.count 10 (processStdout result) @?= 1

qualificationSubjectsMachineFailure :: Assertion
qualificationSubjectsMachineFailure = do
  model <- fixturePath "profiled-minimal.archimate"
  result <-
    runO2I
      [ "qualification-subjects"
      , model
      , "--view"
      , "KPI"
      , "--supplement"
      , "-"
      , "--json"
      ]
      ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStderr result @?= ByteString.empty
  assertMachineError (processStdout result)
  assertContains
    (processStdout result)
    "\"kind\":\"qualification-subjects-failed\""
  assertContains
    (processStdout result)
    "\"code\":\"qualification-subjects.supplemental-input\""
  assertContains
    (processStdout result)
    "\"ruleId\":\"core.supplemental.decode.json-syntax\""

qualificationSubjectsHumanFailure :: Assertion
qualificationSubjectsHumanFailure = do
  model <- fixturePath "profiled-minimal.archimate"
  result <-
    runO2I
      ["qualification-subjects", model, "--view", "KPI", "--supplement", "-"]
      ByteString.empty
  processExitCode result @?= ExitFailure 2
  processStdout result @?= ByteString.empty
  assertContains
    (processStderr result)
    "[o2i|error] \"qualification-subjects.supplemental-input\":"
  assertContains
    (processStderr result)
    "invalid-json-syntax|core.supplemental.decode.json-syntax|0"
  assertTerminalSafe (processStderr result)

verbosityExtension :: Assertion
verbosityExtension = do
  normal <- runO2I ["adapters"] ByteString.empty
  verbose <- runO2I ["adapters", "--verbose"] ByteString.empty
  debug <- runO2I ["adapters", "--debug"] ByteString.empty
  machine <- runO2I ["adapters", "--json"] ByteString.empty
  mapM_ ((@?= ExitSuccess) . processExitCode) [normal, verbose, debug, machine]
  assertBool
    "verbose output does not preserve the complete normal report prefix"
    (processStdout normal `ByteString.isPrefixOf` processStdout verbose)
  assertBool
    "debug output does not preserve the complete verbose report prefix"
    (processStdout verbose `ByteString.isPrefixOf` processStdout debug)
  assertContains (processStdout verbose) "  exit=0\n"
  assertContains
    (processStdout debug)
    ("  machine-utf8-hex=" <> hexBytes (processStdout machine) <> "\n")
  mapM_ (assertTerminalSafe . processStdout) [normal, verbose, debug]

hexBytes :: ByteString.ByteString -> ByteString.ByteString
hexBytes =
  TextEncoding.encodeUtf8
    . Text.concat
    . map (Text.justifyRight 2 '0' . Text.pack . (`showHex` ""))
    . ByteString.unpack

assertMachineError :: ByteString.ByteString -> Assertion
assertMachineError bytes = do
  schema <- decodeJsonObject commandErrorSchemaBytes
  document <- decodeJsonObject bytes
  assertBool
    "command error document does not conform to its embedded Schema"
    (validateJSONSchema schema document)
  case document of
    Aeson.Object object -> do
      assertContains bytes "\"schema\":\"o2i.command-error/v1\""
      assertBool "command error document is empty" (not (null object))
    _ -> assertFailure "command-error output is not a JSON object"

assertJsonObject :: ByteString.ByteString -> Assertion
assertJsonObject bytes = do
  document <- decodeJsonObject bytes
  case document of
    Aeson.Object object ->
      assertBool "machine report document is empty" (not (null object))
    _ -> assertFailure "machine report output is not a JSON object"

decodeJsonObject :: ByteString.ByteString -> IO Aeson.Value
decodeJsonObject bytes =
  case Aeson.eitherDecodeStrict bytes of
    Left message -> assertFailure message >> fail "unreachable"
    Right value -> pure value

assertTerminalSafe :: ByteString.ByteString -> Assertion
assertTerminalSafe bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left failure -> assertFailure (show failure)
    Right rendered ->
      assertBool
        "human report contains an unsafe terminal control"
        (Text.all safeCharacter rendered)

assertContains :: ByteString.ByteString -> ByteString.ByteString -> Assertion
assertContains actual expected =
  assertBool
    ("missing expected bytes: " <> show expected)
    (ByteString.isInfixOf expected actual)

safeCharacter :: Char -> Bool
safeCharacter character =
  let code = ord character
   in character == '\n'
        || (code > 0x1f && code /= 0x7f && not (code >= 0x80 && code <= 0x9f))

commandPaths :: [[String]]
commandPaths =
  [ ["adapters"]
  , ["profiles"]
  , ["rules", "adapter"]
  , ["rules", "operation"]
  , ["rules", "core"]
  , ["rules", "profile"]
  , ["explain", "adapter"]
  , ["explain", "operation"]
  , ["explain", "core"]
  , ["explain", "profile"]
  , ["views"]
  , ["qualification-subjects"]
  , ["validate"]
  , ["trace"]
  , ["qualify"]
  , ["readiness"]
  , ["assess"]
  ]
