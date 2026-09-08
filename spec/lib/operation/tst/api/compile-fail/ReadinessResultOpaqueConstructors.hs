module ReadinessResultOpaqueConstructors where

import O2I.Operation.Readiness.Request
import O2I.Operation.Readiness.Result

invalidRequest :: ReadinessRequest
invalidRequest = ReadinessRequest undefined undefined Nothing undefined []

invalidResult :: ReadinessResult
invalidResult = ReadinessFailed undefined
