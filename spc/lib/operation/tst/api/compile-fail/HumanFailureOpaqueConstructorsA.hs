module HumanFailureOpaqueConstructorsA where

import qualified O2I.Operation.Human.Failure as Failure

ruleStage :: Failure.HumanFailureAdapterRuleStage
ruleStage = Failure.HumanFailureAdapterPreparationStage

rule :: Failure.HumanFailureAdapterRule
rule =
  Failure.HumanFailureAdapterRule
    undefined
    undefined
    undefined
    undefined
    undefined

location :: Failure.HumanFailureNativeLocation
location = Failure.HumanFailureByteOffset undefined

occurrence :: Failure.HumanFailureAdapterOccurrence
occurrence = Failure.HumanFailureAdapterOccurrence undefined

diagnostic :: Failure.HumanFailureAdapterDiagnostic
diagnostic = Failure.HumanFailureAdapterDiagnostic undefined undefined

adapterSelection :: Failure.HumanAdapterSelectionFailure
adapterSelection = Failure.HumanUnknownAdapter undefined

recordFamily :: Failure.HumanFailureRecordFamily
recordFamily = Failure.HumanFailureModelRoot

referenceField :: Failure.HumanFailureReferenceField
referenceField = Failure.HumanFailurePropertyDefinitionReference

canonicalTarget :: Failure.HumanFailureCanonicalTarget
canonicalTarget =
  Failure.HumanFailureCanonicalTarget
    undefined
    undefined
    undefined
    undefined
    undefined

referenceOutcome :: Failure.HumanFailureReferenceOutcome
referenceOutcome = Failure.HumanFailureReferenceIdentityInvalid undefined

canonicalReference :: Failure.HumanFailureCanonicalReference
canonicalReference =
  Failure.HumanFailureCanonicalReference
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

opaquePosition :: Failure.HumanFailureOpaquePosition
opaquePosition = Failure.HumanFailureOpaqueAttribute

opaqueEvidence :: Failure.HumanFailureOpaqueEvidence
opaqueEvidence =
  Failure.HumanFailureOpaqueEvidence
    undefined
    undefined
    undefined
    undefined
    undefined

propertyKey :: Failure.HumanFailurePropertyKey
propertyKey = Failure.HumanFailureDirectPropertyKey undefined

canonicalProperty :: Failure.HumanFailureCanonicalProperty
canonicalProperty =
  Failure.HumanFailureCanonicalProperty
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

markerKey :: Failure.HumanFailureMarkerKeyOutcome
markerKey = Failure.HumanFailureMarkerKeyMissing

markerCandidate :: Failure.HumanFailureMarkerCandidate
markerCandidate =
  Failure.HumanFailureMarkerCandidate undefined undefined undefined

draftKind :: Failure.HumanFailureDraftValueKind
draftKind = Failure.HumanFailureDraftText

resolution :: Failure.HumanProfileResolutionFailure
resolution = Failure.HumanProfileReferenceMissing undefined undefined

compatibility :: Failure.HumanProfileCompatibilityFailure
compatibility =
  Failure.HumanProfileAdapterNotAdmitted undefined undefined undefined undefined
