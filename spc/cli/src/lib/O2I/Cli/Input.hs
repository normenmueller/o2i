-- | Translation from CLI tokens to the existing Inspection input contract.
module O2I.Cli.Input
  ( inputSourceFor
  , inspectionRequestFor
  ) where

import O2I.Cli.Options
import O2I.Inspection

-- | Interpret only the reserved standard-input token specially.
inputSourceFor :: FilePath -> InputSource
inputSourceFor "-" = StandardInput
inputSourceFor path = InputPath path

-- | Build an initial inspection request without manufacturing supplemental
-- validation inputs.
inspectionRequestFor :: InspectOptions -> InspectionRequest
inspectionRequestFor options =
  InspectionRequest
    { modelInput = inputSourceFor (inspectModelToken options)
    , viewSelector =
        case inspectViewSelection options of
          ViewName name -> ViewByName name
          ViewIdentifier identifier -> ViewById identifier
    , inspectionInputs =
        InspectionInputs
          { strategyInput = Absent
          , readinessInput = Absent
          , evidenceInput = Absent
          }
    }
