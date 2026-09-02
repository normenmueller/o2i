{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Process
  ( tests
  ) where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import Data.Char (ord)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Cli.Test.Support
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
    , testCase "human command error uses stderr only" humanCommandError
    , testCase "machine command error uses stdout only" machineCommandError
    , testCase
        "option-looking fixed operand selects human mode"
        optionLookingOperand
    , testCase "stdin cardinality error is machine-safe" stdinCardinality
    , testCase "marker placement error retains JSON intent" markerPlacement
    , testCase "human error scalars are terminal-safe" terminalSafeError
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
  processStdout result @?= "O2I views: failed\n"
  processStderr result @?= ByteString.empty

stdinCardinality :: Assertion
stdinCardinality = do
  result <-
    runO2I
      [ "readiness"
      , "-"
      , "--view"
      , "Scope"
      , "--input"
      , "-"
      , "--json"
      ]
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

assertMachineError :: ByteString.ByteString -> Assertion
assertMachineError bytes =
  case Aeson.eitherDecodeStrict bytes of
    Left message -> assertFailure message
    Right (Aeson.Object object) -> do
      assertContains bytes "\"schema\":\"o2i.command-error/v1\""
      assertBool "command error document is empty" (not (null object))
    Right _ -> assertFailure "command-error output is not a JSON object"

assertContains :: ByteString.ByteString -> ByteString.ByteString -> Assertion
assertContains actual expected =
  assertBool
    ("missing expected bytes: " <> show expected)
    (ByteString.isInfixOf expected actual)

safeCharacter :: Char -> Bool
safeCharacter character =
  let code = ord character
   in character == '\n'
        || (code > 0x1f
              && code /= 0x7f
              && not (code >= 0x80 && code <= 0x9f))

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
