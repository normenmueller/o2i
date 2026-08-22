module StructureCrossGenerationEvidence where

import O2I.Core.Identity (SelectedViewScope)
import O2I.Structure (StructureEvidence)

consume :: SelectedViewScope scope -> StructureEvidence scope -> ()
consume selected evidence = selected `seq` evidence `seq` ()

crossGeneration ::
     SelectedViewScope firstScope -> StructureEvidence secondScope -> ()
crossGeneration = consume
