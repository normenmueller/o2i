{-# LANGUAGE OverloadedStrings #-}

-- | Minimal process facade for the private O2I CLI library.
module O2I.Cli
  ( runCli
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (showVersion)
import O2I.Cli.Command (ExecutionError(..), executeCommand)
import O2I.Cli.Options
import O2I.Cli.Output
import O2I.Cli.Scanner (scanOutputMode)
import O2I.Cli.Static (staticComposition)
import O2I.Operation.Machine (ToolDescriptor, mkToolDescriptor)
import qualified Paths_o2i_cli as Package
import System.Environment (getArgs)
import System.Exit (ExitCode(..), exitWith)

-- | Parse process arguments, run one command, and terminate with its status.
runCli :: IO ()
runCli = do
  arguments <- getArgs
  code <- runArguments arguments
  exitWith (toExitCode code)

runArguments :: [String] -> IO Int
runArguments arguments = do
  let requestedMode = scanOutputMode arguments
  case parseCliOptions arguments of
    Left failure -> finishInvocationError requestedMode failure
    Right options ->
      case options of
        HelpCommand path -> finishParserText (commandHelp path)
        VersionCommand ->
          finishParserText ("o2i " <> Text.pack (showVersion Package.version))
        _ -> runReport requestedMode options

runReport :: OutputMode -> CliOptions -> IO Int
runReport mode options =
  case (staticComposition, toolDescriptor) of
    (Left failure, _) -> finishInvocationError mode failure
    (_, Left failure) -> finishInvocationError mode failure
    (Right static, Right tool) -> do
      outcome <- executeCommand static tool options
      case outcome of
        Left failure -> finishExecutionError mode tool failure
        Right primary -> do
          emitted <- emitPrimaryReport mode primary
          finishOutput emitted (primaryExitCode primary)

toolDescriptor :: Either CliError ToolDescriptor
toolDescriptor =
  mapLeft
    (const
       (CliError
          "cli.internal.tool-descriptor"
          "The executable descriptor is invalid."))
    (mkToolDescriptor "o2i" (Text.pack (showVersion Package.version)))

finishParserText :: Text -> IO Int
finishParserText message = do
  emitted <- emitParserText message
  finishOutput emitted 0

finishInvocationError :: OutputMode -> CliError -> IO Int
finishInvocationError mode failure =
  case mode of
    HumanOutput -> emitHumanError failure >>= (`finishOutput` 2)
    JsonOutput ->
      case toolDescriptor of
        Left _ -> failClosedCommandError
        Right tool ->
          case prepareArgumentCommandError tool failure of
            Left _ -> failClosedCommandError
            Right encoded -> emitMachineError encoded >>= (`finishOutput` 2)

finishExecutionError :: OutputMode -> ToolDescriptor -> ExecutionError -> IO Int
finishExecutionError mode tool failure =
  case failure of
    ExecutionArgumentError argumentFailure ->
      finishInvocationError mode argumentFailure
    ExecutionCommandError commandFailure ->
      case mode of
        HumanOutput ->
          emitHumanCommandError commandFailure >>= (`finishOutput` 2)
        JsonOutput ->
          case prepareCommandError tool commandFailure of
            Left _ -> failClosedCommandError
            Right encoded -> emitMachineError encoded >>= (`finishOutput` 2)

failClosedCommandError :: IO Int
failClosedCommandError = do
  emitted <-
    emitHumanError
      (CliError
         "cli.internal.command-error-preflight"
         "A canonical command-error document could not be validated.")
  finishOutput emitted 2

finishOutput :: Either OutputFailure () -> Int -> IO Int
finishOutput result successCode =
  case result of
    Right () -> pure successCode
    Left failure -> reportOutputFailure failure >> pure 2

toExitCode :: Int -> ExitCode
toExitCode 0 = ExitSuccess
toExitCode code = ExitFailure code

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
