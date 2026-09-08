module BindingCrossGenerationEvidence where

import O2I.Semantics.Input
import O2I.Structure (WellFormedGraph)

consume ::
     BoundSupplementalInputs scope -> SupplementalBindingEvidence scope () -> ()
consume inputs evidence = inputs `seq` evidence `seq` ()

crossGeneration ::
     BoundSupplementalInputs firstScope
  -> SupplementalBindingEvidence secondScope ()
  -> ()
crossGeneration = consume

consumeBinding :: WellFormedGraph scope -> SupplementalBinding scope () -> ()
consumeBinding graph binding = graph `seq` binding `seq` ()

crossGenerationBinding ::
     WellFormedGraph firstScope -> SupplementalBinding secondScope () -> ()
crossGenerationBinding = consumeBinding
