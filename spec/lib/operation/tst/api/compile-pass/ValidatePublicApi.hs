module ValidatePublicApi where

import Data.ByteString (ByteString)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Validate (runValidate)
import O2I.Operation.Validate.Machine
  ( encodeValidateResultDocument
  , validateResultDocument
  )
import O2I.Operation.Validate.Request (notationValidateRequest)
import O2I.Operation.Validate.Result (ValidateFailure)
import O2I.Operation.View (ViewSelector)

validateNotationDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> InputSource
  -> ViewSelector
  -> IO (Either ValidateFailure ByteString)
validateNotationDocument tool adapters profiles model view =
  fmap
    (fmap encodeValidateResultDocument . validateResultDocument tool)
    (runValidate adapters profiles (notationValidateRequest model view Nothing))
