{-# LANGUAGE OverloadedStrings #-}

-- | Process contract for machine-readable executable provenance.
module O2I.Cli.Command.BuildRevision
  ( runBuildRevisionCommand
  ) where

import O2I.BuildProvenance
import O2I.Cli.Output

-- | Write the exact bound commit or fail explicitly when no binding exists.
runBuildRevisionCommand :: IO Int
runBuildRevisionCommand =
  case buildRevisionStatus of
    RevisionBound _ revision -> do
      result <- emitBuildRevision (buildRevisionText revision)
      finish result 0
    RevisionUnbound issue -> do
      result <- emitBuildRevisionError issue
      finish result 2
  where
    finish result successCode =
      case result of
        Right () -> pure successCode
        Left failure -> reportOutputFailure failure >> pure 2
