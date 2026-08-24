{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import O2I.Adapter.AMX.Repository (checkRepositoryModel)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (stderr)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [modelPath] -> do
      result <- checkRepositoryModel modelPath
      case result of
        Left failure -> do
          Text.hPutStrLn stderr ("[o2i|error] " <> failure)
          exitFailure
        Right () ->
          putStrLn
            "[o2i|success] Repository Candidate Views passed AMX/Profile/Core verification."
    _ -> do
      Text.hPutStrLn
        stderr
        (Text.pack "Usage: o2i-amx-repository-view-check MODEL.archimate")
      exitFailure
