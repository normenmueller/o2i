module HumanReportOpaqueConstructor where

import O2I.Operation.Validate.Human (HumanValidateReport)

forged :: HumanValidateReport
forged = HumanValidateAccepted undefined
