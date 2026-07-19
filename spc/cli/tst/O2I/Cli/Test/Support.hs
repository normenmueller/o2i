module O2I.Cli.Test.Support
  ( ProcessResult(..)
  , fixtureBytes
  , fixturePath
  , goldenBytes
  , runO2I
  , runO2IChunks
  ) where

import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import qualified Paths_o2i_cli as Package
import System.Exit (ExitCode)
import System.IO (hClose)
import System.Process

data ProcessResult = ProcessResult
  { processExitCode :: ExitCode
  , processStdout :: ByteString
  , processStderr :: ByteString
  } deriving (Eq, Show)

fixturePath :: FilePath -> IO FilePath
fixturePath name = Package.getDataFileName ("tst/data/" <> name)

fixtureBytes :: FilePath -> IO ByteString
fixtureBytes name = fixturePath name >>= ByteString.readFile

goldenBytes :: FilePath -> IO ByteString
goldenBytes name =
  Package.getDataFileName ("tst/golden/" <> name) >>= ByteString.readFile

runO2I :: [String] -> ByteString -> IO ProcessResult
runO2I arguments input = runO2IChunks arguments [input]

runO2IChunks :: [String] -> [ByteString] -> IO ProcessResult
runO2IChunks arguments chunks = do
  created <-
    createProcess
      (proc "o2i" arguments)
        {std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe}
  case created of
    (Just inputHandle, Just outputHandle, Just errorHandle, processHandle) -> do
      outputResult <- newEmptyMVar
      errorResult <- newEmptyMVar
      void
        (forkIO (ByteString.hGetContents outputHandle >>= putMVar outputResult))
      void
        (forkIO (ByteString.hGetContents errorHandle >>= putMVar errorResult))
      mapM_ (ByteString.hPut inputHandle) chunks
      hClose inputHandle
      output <- takeMVar outputResult
      errors <- takeMVar errorResult
      exitCode <- waitForProcess processHandle
      pure (ProcessResult exitCode output errors)
    _ -> fail "createProcess did not return all requested pipes"
