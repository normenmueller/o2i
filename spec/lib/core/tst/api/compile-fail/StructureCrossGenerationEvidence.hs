module StructureCrossGenerationEvidence where

import O2I.Core.Identity (SelectedViewScope)
import O2I.Structure (StructureAssessment, StructureEvidence)

consume :: SelectedViewScope scope -> StructureEvidence scope -> ()
consume selected evidence = selected `seq` evidence `seq` ()

crossGeneration ::
     SelectedViewScope firstScope -> StructureEvidence secondScope -> ()
crossGeneration = consume

consumeAssessment :: SelectedViewScope scope -> StructureAssessment scope -> ()
consumeAssessment selected assessment = selected `seq` assessment `seq` ()

crossGenerationAssessment ::
     SelectedViewScope firstScope -> StructureAssessment secondScope -> ()
crossGenerationAssessment = consumeAssessment
