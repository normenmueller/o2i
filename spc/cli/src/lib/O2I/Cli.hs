{-# LANGUAGE OverloadedStrings #-}

-- | Minimal process facade for the private O2I CLI library.
module O2I.Cli
  ( runCli
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Cli.Command (runCommand)
import O2I.Cli.Options
import O2I.Cli.Output
import O2I.Inspection
import Options.Applicative
import System.Environment (getArgs)
import System.Exit (ExitCode(..), exitWith)

-- | Parse process arguments, run one command, and terminate with its status.
runCli :: IO ()
runCli = do
  arguments <- getArgs
  code <- runArguments arguments
  exitWith (toExitCode code)

runArguments :: [String] -> IO Int
runArguments arguments =
  case parseCliOptions arguments of
    Success options -> runCommand options
    Failure failure ->
      let (message, parserExit) = renderFailure failure "o2i"
       in case parserExit of
            ExitSuccess -> finishParserText message
            ExitFailure _ ->
              finishInvocationError
                (requestedOutputMode arguments)
                (Text.strip (Text.pack message))
    CompletionInvoked completion -> do
      message <- execCompletion completion "o2i"
      finishParserText message

finishParserText :: String -> IO Int
finishParserText message = do
  emitted <- emitParserText message
  finishOutput emitted 0

finishInvocationError :: OutputMode -> Text -> IO Int
finishInvocationError mode message = do
  let commandError = InvocationCommandError InvalidInvocation message
  emitted <- emitCommandError mode commandError
  finishOutput emitted (commandErrorExitCode commandError)

finishOutput :: Either OutputFailure () -> Int -> IO Int
finishOutput result successCode =
  case result of
    Right () -> pure successCode
    Left failure -> reportOutputFailure failure >> pure 2

requestedOutputMode :: [String] -> OutputMode
requestedOutputMode = select HumanOutput
  where
    select mode [] = mode
    select mode ("--":_) = mode
    select _ ("--json":arguments) = select JsonOutput arguments
    select mode (_:arguments) = select mode arguments

toExitCode :: Int -> ExitCode
toExitCode 0 = ExitSuccess
toExitCode code = ExitFailure code
