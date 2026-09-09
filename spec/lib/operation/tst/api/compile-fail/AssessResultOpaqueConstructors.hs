module AssessResultOpaqueConstructors where

import O2I.Operation.Assess.Request
import O2I.Operation.Assess.Result

invalidRequest :: AssessRequest
invalidRequest = AssessRequest undefined undefined Nothing undefined []

invalidResult :: AssessResult
invalidResult = AssessFailed undefined
