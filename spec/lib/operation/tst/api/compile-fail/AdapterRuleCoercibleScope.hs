module AdapterRuleCoercibleScope where

import Data.Coerce (coerce)
import O2I.Operation.Adapter.Authoring

invalidCoercion :: RecognitionRule left -> RecognitionRule right
invalidCoercion = coerce
