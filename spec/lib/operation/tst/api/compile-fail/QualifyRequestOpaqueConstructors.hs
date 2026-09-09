module QualifyRequestOpaqueConstructors where

import O2I.Operation.Qualify.Request

invalidCategory :: QualifySelectorCategory
invalidCategory = QualifyNeedSelectorCategory

invalidDefect :: QualifyRequestDefect
invalidDefect = DuplicateQualifySelector undefined undefined

invalidRequest :: QualifyRequest
invalidRequest =
  QualifyRequest undefined undefined undefined undefined undefined undefined
