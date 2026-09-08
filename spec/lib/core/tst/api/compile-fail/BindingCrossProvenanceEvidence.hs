module BindingCrossProvenanceEvidence where

import O2I.Semantics.Input

consumeEvidence ::
     SupplementalBinding scope provenance
  -> SupplementalBindingEvidence scope provenance
  -> ()
consumeEvidence binding evidence = binding `seq` evidence `seq` ()

crossEvidence ::
     SupplementalBinding scope firstProvenance
  -> SupplementalBindingEvidence scope secondProvenance
  -> ()
crossEvidence = consumeEvidence

consumeBinding ::
     SupplementalInputSet provenance
  -> SupplementalBinding scope provenance
  -> ()
consumeBinding inputs binding = inputs `seq` binding `seq` ()

crossBinding ::
     SupplementalInputSet firstProvenance
  -> SupplementalBinding scope secondProvenance
  -> ()
crossBinding = consumeBinding
