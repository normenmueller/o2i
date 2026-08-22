module ProfileCrossGenerationEvidence where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection

consumeDiagnostic ::
     ProfileProjection profile document
  -> ProfileDiagnosticEvidence profile document
  -> ()
consumeDiagnostic projection evidence = projection `seq` evidence `seq` ()

crossDocumentDiagnostic ::
     ProfileProjection profile firstDocument
  -> ProfileDiagnosticEvidence profile secondDocument
  -> ()
crossDocumentDiagnostic = consumeDiagnostic

crossProfileDiagnostic ::
     ProfileProjection firstProfile document
  -> ProfileDiagnosticEvidence secondProfile document
  -> ()
crossProfileDiagnostic = consumeDiagnostic

consumeClassification ::
     ProfileProjection profile document
  -> ProfileClassificationEvidence profile document
  -> ()
consumeClassification projection evidence = projection `seq` evidence `seq` ()

crossDocumentClassification ::
     ProfileProjection profile firstDocument
  -> ProfileClassificationEvidence profile secondDocument
  -> ()
crossDocumentClassification = consumeClassification

crossProfileClassification ::
     ProfileProjection firstProfile document
  -> ProfileClassificationEvidence secondProfile document
  -> ()
crossProfileClassification = consumeClassification

consumeMapping ::
     ProfileProjection profile document
  -> ProfileMappingProvenance profile document
  -> ()
consumeMapping projection evidence = projection `seq` evidence `seq` ()

crossDocumentMapping ::
     ProfileProjection profile firstDocument
  -> ProfileMappingProvenance profile secondDocument
  -> ()
crossDocumentMapping = consumeMapping

crossProfileMapping ::
     ProfileProjection firstProfile document
  -> ProfileMappingProvenance secondProfile document
  -> ()
crossProfileMapping = consumeMapping

consumeInvariant ::
     ProfileProjection profile document
  -> ProfileInvariantEvidence profile document
  -> ()
consumeInvariant projection evidence = projection `seq` evidence `seq` ()

crossDocumentInvariant ::
     ProfileProjection profile firstDocument
  -> ProfileInvariantEvidence profile secondDocument
  -> ()
crossDocumentInvariant = consumeInvariant

crossProfileInvariant ::
     ProfileProjection firstProfile document
  -> ProfileInvariantEvidence secondProfile document
  -> ()
crossProfileInvariant = consumeInvariant

consumeActivation ::
     ProfileAssessmentUniverse profile document
  -> ActivationProvenance profile document
  -> ()
consumeActivation universe evidence = universe `seq` evidence `seq` ()

crossDocumentActivation ::
     ProfileAssessmentUniverse profile firstDocument
  -> ActivationProvenance profile secondDocument
  -> ()
crossDocumentActivation = consumeActivation

crossProfileActivation ::
     ProfileAssessmentUniverse firstProfile document
  -> ActivationProvenance secondProfile document
  -> ()
crossProfileActivation = consumeActivation

consumeClosure ::
     ProfileAssessmentUniverse profile document
  -> ClosureProvenance profile document
  -> ()
consumeClosure universe evidence = universe `seq` evidence `seq` ()

crossDocumentClosure ::
     ProfileAssessmentUniverse profile firstDocument
  -> ClosureProvenance profile secondDocument
  -> ()
crossDocumentClosure = consumeClosure

crossProfileClosure ::
     ProfileAssessmentUniverse firstProfile document
  -> ClosureProvenance secondProfile document
  -> ()
crossProfileClosure = consumeClosure
