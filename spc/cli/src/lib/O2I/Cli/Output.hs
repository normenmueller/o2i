{-# LANGUAGE OverloadedStrings #-}

-- | Strict, exception-normalizing process stream boundary.
module O2I.Cli.Output
  ( OutputStream(..)
  , OutputFailure(..)
  , CommandErrorPreflightFailure(..)
  , PrimaryReport(..)
  , emitPrimaryReport
  , emitMachineError
  , emitHumanCommandError
  , emitHumanError
  , emitParserText
  , prepareArgumentCommandError
  , prepareCommandError
  , reportOutputFailure
  , writeHandleBytes
  , textBytes
  , lineBytes
  ) where

import Control.Exception (IOException, try)
import Control.Monad (void)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Cli.Options (CliError(..), OutputMode(..))
import O2I.Cli.TerminalText (terminalLiteral)
import O2I.Operation.Command.Error
  ( CommandError
  , argumentCommandError
  , argumentFailure
  , argumentFailureMessage
  , commandErrorCode
  , foldCommandError
  )
import O2I.Operation.Command.Error.Machine
  ( commandErrorDocument
  , encodeCommandErrorDocument
  )
import O2I.Operation.Failure (preparationFailureStage)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Preparation (preparationStageText)
import System.IO (Handle, hFlush, stderr, stdout)

-- | Intended process stream for one write.
data OutputStream
  = StandardOutput
  | StandardError
  deriving (Eq, Show)

-- | Failed strict write or flush on one non-recursive process stream.
newtype OutputFailure = OutputFailure
  { failedOutputStream :: OutputStream
  } deriving (Eq, Show)

-- | Why CLI-owned input could not become a typed Operation command error.
data CommandErrorPreflightFailure =
  InvalidArgumentCommandError
  deriving (Eq, Show)

-- | Both complete renderings and the already classified process exit.
-- Construction happens before this value reaches a process handle.
data PrimaryReport = PrimaryReport
  { primaryHumanBytes :: ByteString
  , primaryJsonBytes :: ByteString
  , primaryExitCode :: Int
  } deriving (Eq, Show)

-- | Emit exactly one completed primary report to standard output.
emitPrimaryReport :: OutputMode -> PrimaryReport -> IO (Either OutputFailure ())
emitPrimaryReport mode report = writeStream StandardOutput stdout selected
  where
    selected =
      case mode of
        HumanOutput -> primaryHumanBytes report
        JsonOutput -> primaryJsonBytes report

-- | Emit one already Schema-validated canonical command-error document.
emitMachineError :: ByteString -> IO (Either OutputFailure ())
emitMachineError = writeStream StandardOutput stdout . (<> "\n")

-- | Validate a CLI-authored argument error and seal it through Operation.
prepareArgumentCommandError ::
     ToolDescriptor
  -> CliError
  -> Either CommandErrorPreflightFailure ByteString
prepareArgumentCommandError tool failure = do
  authored <-
    mapLeft
      (const InvalidArgumentCommandError)
      (argumentFailure (cliErrorCode failure) (cliErrorMessage failure))
  pure (prepareCommandError tool (argumentCommandError authored))

-- | Encode the closed Operation command-error algebra directly to its
-- canonical machine bytes. Schema conformance is established at the Operation
-- contract boundary and exercised in tests, not reconstructed at runtime.
prepareCommandError :: ToolDescriptor -> CommandError -> ByteString
prepareCommandError tool =
  encodeCommandErrorDocument . commandErrorDocument tool

-- | Render one closed Operation command error on stderr without losing its
-- stable branch code or exposing terminal controls.
emitHumanCommandError :: CommandError -> Text -> IO (Either OutputFailure ())
emitHumanCommandError failure details =
  writeStream
    StandardError
    stderr
    (lineBytes (render failure) <> lineBytes ("  " <> details))
  where
    render commandError =
      prefixed
        (commandErrorCode commandError)
        (foldCommandError
           argumentFailureMessage
           (const "The input source could not be acquired.")
           (\preparationFailureValue ->
              "Command preparation failed at "
                <> preparationStageText
                     (preparationFailureStage preparationFailureValue)
                <> ".")
           (const "Validate could not start.")
           (const "Qualify could not start.")
           (const "Readiness could not start.")
           (const "Assess could not start.")
           (const "Qualification-subject discovery could not start.")
           (const "Trace could not start.")
           commandError)
    prefixed code message =
      "[o2i|error] " <> terminalLiteral code <> ": " <> terminalLiteral message

-- | Emit one terminal-safe human command error and no stdout bytes.
emitHumanError :: CliError -> IO (Either OutputFailure ())
emitHumanError failure =
  writeStream
    StandardError
    stderr
    (lineBytes
       ("[o2i|error] "
          <> terminalLiteral (cliErrorCode failure)
          <> ": "
          <> terminalLiteral (cliErrorMessage failure)))

-- | Emit exact help or version text to standard output.
emitParserText :: Text -> IO (Either OutputFailure ())
emitParserText = writeStream StandardOutput stdout . lineBytes

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

-- | One strict handle write followed by a flush, with exceptions normalized.
writeHandleBytes :: Handle -> ByteString -> IO Bool
writeHandleBytes handle bytes = do
  result <-
    try (ByteString.hPut handle bytes >> hFlush handle) :: IO
      (Either IOException ())
  pure
    (case result of
       Left _ -> False
       Right () -> True)

writeStream ::
     OutputStream -> Handle -> ByteString -> IO (Either OutputFailure ())
writeStream stream handle bytes = do
  written <- writeHandleBytes handle bytes
  pure
    (if written
       then Right ()
       else Left (OutputFailure stream))

-- | Encode complete Unicode text as strict UTF-8.
textBytes :: Text -> ByteString
textBytes = TextEncoding.encodeUtf8

-- | Normalize to exactly one terminal line ending.
lineBytes :: Text -> ByteString
lineBytes = textBytes . (<> "\n") . Text.stripEnd

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
