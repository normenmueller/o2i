module O2I.Cli.Test.Support
  ( ProcessResult(..)
  , goldenBytes
  , runO2I
  ) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Monad (void)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Paths_o2i_cli as Package
import System.Environment (lookupEnv)
import System.Exit (ExitCode)
import System.IO (hClose)
import System.Process

data ProcessResult = ProcessResult
  { processExitCode :: ExitCode
  , processStdout :: ByteString
  , processStderr :: ByteString
  } deriving (Eq, Show)

goldenBytes :: FilePath -> IO ByteString
goldenBytes name =
  Package.getDataFileName ("tst/golden/" <> name) >>= ByteString.readFile

runO2I :: [String] -> ByteString -> IO ProcessResult
runO2I arguments input = do
  executable <- maybe "o2i" id <$> lookupEnv "O2I_CLI_TEST_EXECUTABLE"
  created <-
    createProcess
      (proc executable arguments)
        {std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe}
  case created of
    (Just inputHandle, Just outputHandle, Just errorHandle, processHandle) -> do
      outputResult <- newEmptyMVar
      errorResult <- newEmptyMVar
      void
        (forkIO (ByteString.hGetContents outputHandle >>= putMVar outputResult))
      void
        (forkIO (ByteString.hGetContents errorHandle >>= putMVar errorResult))
      ByteString.hPut inputHandle input
      hClose inputHandle
      output <- takeMVar outputResult
      errors <- takeMVar errorResult
      exitCode <- waitForProcess processHandle
      pure (ProcessResult exitCode output errors)
    _ -> fail "createProcess did not return all requested pipes"
