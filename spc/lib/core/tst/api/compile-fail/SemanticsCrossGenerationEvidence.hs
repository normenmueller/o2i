module SemanticsCrossGenerationEvidence where

import O2I.Semantics

consume ::
     SemanticallyValidModel scope -> SemanticDiagnosticEvidence scope -> ()
consume model evidence = model `seq` evidence `seq` ()

crossGeneration ::
     SemanticallyValidModel firstScope
  -> SemanticDiagnosticEvidence secondScope
  -> ()
crossGeneration = consume
