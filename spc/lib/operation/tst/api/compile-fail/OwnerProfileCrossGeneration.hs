module OwnerProfileCrossGeneration where

import O2I.ArchiMate.Profile.Closure
import O2I.ArchiMate.Profile.Projection
import O2I.ArchiMate.Profile.Resolution
import O2I.Operation.Diagnostic
import O2I.Operation.Diagnostic.Owner
import O2I.Operation.Provenance

consumeActivation ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> [Diagnostic]
consumeActivation = profileActivationDiagnostics

crossActivationProfile ::
     SourceIdentity
  -> SelectedArchiMateProfile firstProfile
  -> ProfileAssessmentUniverse secondProfile document
  -> [Diagnostic]
crossActivationProfile = consumeActivation

consumeAssessment ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile document
  -> ProfileProjectionAssessment profile document
  -> [Diagnostic]
consumeAssessment source selected universe assessment =
  foldProfileAssessmentDiagnostics
    (const [])
    id
    source
    selected
    universe
    assessment

crossAssessmentProfile ::
     SourceIdentity
  -> SelectedArchiMateProfile firstProfile
  -> ProfileAssessmentUniverse secondProfile document
  -> ProfileProjectionAssessment secondProfile document
  -> [Diagnostic]
crossAssessmentProfile = consumeAssessment

crossAssessmentDocument ::
     SourceIdentity
  -> SelectedArchiMateProfile profile
  -> ProfileAssessmentUniverse profile firstDocument
  -> ProfileProjectionAssessment profile secondDocument
  -> [Diagnostic]
crossAssessmentDocument = consumeAssessment
