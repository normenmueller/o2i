{-# LANGUAGE OverloadedStrings #-}

module OpaqueConstructors where

import O2I.Operation.Adapter
import O2I.Operation.Failure

invalidAdapterId :: AdapterId
invalidAdapterId = AdapterId "amx"

resolutionFailure :: ProfileResolutionFailure
resolutionFailure = ProfileReferenceMissingFailure undefined undefined

compatibilityFailure :: ProfileCompatibilityFailure
compatibilityFailure =
  ProfileAdapterIdNotAdmittedFailure undefined undefined undefined undefined
