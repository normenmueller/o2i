module AdapterRuleCrossScope where

import Data.List.NonEmpty (NonEmpty)
import O2I.Operation.Adapter (AdapterOccurrence)
import O2I.Operation.Adapter.Authoring

invalidDiagnostic ::
     RecognitionRule left
  -> NonEmpty AdapterOccurrence
  -> RecognitionDiagnostic right
invalidDiagnostic = recognitionDiagnostic
