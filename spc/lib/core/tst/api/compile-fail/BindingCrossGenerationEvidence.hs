module BindingCrossGenerationEvidence where

import O2I.Semantics.Input

consume ::
     BoundSupplementalInputs scope -> SupplementalBindingEvidence scope -> ()
consume inputs evidence = inputs `seq` evidence `seq` ()

crossGeneration ::
     BoundSupplementalInputs firstScope
  -> SupplementalBindingEvidence secondScope
  -> ()
crossGeneration = consume
