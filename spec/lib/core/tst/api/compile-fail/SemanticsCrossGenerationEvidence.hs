module SemanticsCrossGenerationEvidence where

import O2I.Semantics
import O2I.Structure (WellFormedGraph)

consume ::
     SemanticallyValidModel scope -> SemanticDiagnosticEvidence scope -> ()
consume model evidence = model `seq` evidence `seq` ()

crossGeneration ::
     SemanticallyValidModel firstScope
  -> SemanticDiagnosticEvidence secondScope
  -> ()
crossGeneration = consume

consumeAssessment :: WellFormedGraph scope -> SemanticAssessment scope -> ()
consumeAssessment graph assessment = graph `seq` assessment `seq` ()

crossGenerationAssessment ::
     WellFormedGraph firstScope -> SemanticAssessment secondScope -> ()
crossGenerationAssessment = consumeAssessment
