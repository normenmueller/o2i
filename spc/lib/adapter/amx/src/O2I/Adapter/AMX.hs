-- | Native Archi Model XML adapter for the O2I operation pipeline.
module O2I.Adapter.AMX
  ( AMXAdapterDefect
  , foldAMXAdapterDefect
  , amxAdapter
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified O2I.Adapter.AMX.Internal.Contract as Contract
import O2I.Operation.Adapter (Adapter)

-- | Opaque closed failure emitted only while compiling the static AMX
-- adapter contract.
newtype AMXAdapterDefect =
  AMXAdapterDefect Contract.AMXAdapterDefect

-- | Consume the four closed AMX construction-defect categories.
foldAMXAdapterDefect ::
     result -> result -> result -> result -> AMXAdapterDefect -> result
foldAMXAdapterDefect identifier descriptor rule compilation defect =
  case defect of
    AMXAdapterDefect internal ->
      Contract.foldAMXAdapterDefect
        identifier
        descriptor
        rule
        compilation
        internal

-- | Compile the closed native AMX contract independently of model input.
amxAdapter :: Either (NonEmpty AMXAdapterDefect) Adapter
amxAdapter =
  case Contract.compileAMXAdapter of
    Left defects -> Left (NonEmpty.map AMXAdapterDefect defects)
    Right adapter -> Right adapter
