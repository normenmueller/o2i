module OwnerProfileCrossGeneration where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Diagnostic.Owner.Source

consumeActivation ::
     PreparedAuthority authority profile document
  -> ProfileAssessmentUniverse profile document
  -> [PreparedDiagnostic authority profile document]
consumeActivation = profileActivationDiagnostics

crossActivationProfile ::
     PreparedAuthority authority firstProfile document
  -> ProfileAssessmentUniverse secondProfile document
  -> [PreparedDiagnostic authority firstProfile document]
crossActivationProfile = consumeActivation

consumeAssessment ::
     PreparedAuthority authority profile document
  -> ProfileProjectionAssessment profile document
  -> [PreparedDiagnostic authority profile document]
consumeAssessment authority assessment =
  foldProfileAssessmentDiagnostics (const []) id authority assessment

crossAssessmentProfile ::
     PreparedAuthority authority firstProfile document
  -> ProfileProjectionAssessment secondProfile document
  -> [PreparedDiagnostic authority firstProfile document]
crossAssessmentProfile = consumeAssessment

crossAssessmentDocument ::
     PreparedAuthority authority profile firstDocument
  -> ProfileProjectionAssessment profile secondDocument
  -> [PreparedDiagnostic authority profile firstDocument]
crossAssessmentDocument = consumeAssessment
