-- | Execution of the thin AMX inspection composition root.
module O2I.Cli.Command.Inspect
  ( runInspectCommand
  ) where

import O2I.Adapter.AMX (amxAdapter)
import O2I.Cli.Input (inspectionRequestFor)
import O2I.Cli.Options
import O2I.Cli.Output
import O2I.Inspection

-- | Delegate validation to Inspection, route output, and return its exit code.
runInspectCommand :: InspectOptions -> IO Int
runInspectCommand options = do
  outcome <- inspect amxAdapter (inspectionRequestFor options)
  case outcome of
    InspectionCompleted report -> do
      emitted <-
        emitInspectionReport
          (inspectOutputMode options)
          (inspectVerbosity options)
          report
      finish emitted (reportExitCode report)
    InspectionCommandFailed commandError -> do
      emitted <- emitCommandError (inspectOutputMode options) commandError
      finish emitted (commandErrorExitCode commandError)
  where
    finish (Right ()) code = pure code
    finish (Left failure) _ = reportOutputFailure failure >> pure 2
