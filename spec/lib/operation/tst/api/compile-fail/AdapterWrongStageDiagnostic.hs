module AdapterWrongStageDiagnostic where

import Data.List.NonEmpty (NonEmpty)
import O2I.Operation.Adapter (AdapterOccurrence)
import O2I.Operation.Adapter.Authoring

invalidDiagnostic ::
     DecodeRule scope
  -> NonEmpty AdapterOccurrence
  -> RecognitionDiagnostic scope
invalidDiagnostic = recognitionDiagnostic
