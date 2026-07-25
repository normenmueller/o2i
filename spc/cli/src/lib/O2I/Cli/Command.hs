-- | Closed dispatch for supported O2I commands.
module O2I.Cli.Command
  ( runCommand
  ) where

import O2I.Cli.Command.BuildRevision (runBuildRevisionCommand)
import O2I.Cli.Command.Inspect (runInspectCommand)
import O2I.Cli.Options

-- | Dispatch one successfully parsed invocation.
runCommand :: CliOptions -> IO Int
runCommand options =
  case options of
    InspectCommand inspectOptions -> runInspectCommand inspectOptions
    BuildRevisionCommand -> runBuildRevisionCommand
