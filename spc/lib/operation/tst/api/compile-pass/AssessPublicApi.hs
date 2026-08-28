module AssessPublicApi where

import Data.ByteString (ByteString)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Assess (runAssess)
import O2I.Operation.Assess.Machine
  ( assessResultDocument
  , encodeAssessResultDocument
  )
import O2I.Operation.Assess.Request (assessRequest)
import O2I.Operation.Assess.Result (AssessFailure)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.View (ViewSelector)

assessDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> InputSource
  -> ViewSelector
  -> InputSource
  -> [InputSource]
  -> IO (Either AssessFailure ByteString)
assessDocument tool adapters profiles model view bundle supplements =
  fmap
    (fmap encodeAssessResultDocument . assessResultDocument tool)
    (runAssess
       adapters
       profiles
       (assessRequest model view Nothing bundle supplements))
