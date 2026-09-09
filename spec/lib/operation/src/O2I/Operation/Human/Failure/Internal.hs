{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Private construction of closed terminal-neutral human failures.
module O2I.Operation.Human.Failure.Internal where

import Control.Exception (IOException)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Numeric.Natural (Natural)
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity
  ( IdentityIndexDefect
  , OccurrenceIdentityDefect(..)
  , SelectedViewScopeDefect
  , SelectedViewScopeDefectKind(..)
  , identityIndexDefectModelIdentities
  , identityIndexDefectOccurrence
  , selectedViewScopeDefectCardinality
  , selectedViewScopeDefectKind
  , selectedViewScopeDefectOccurrence
  )
import O2I.Operation.Acquisition (foldAcquisitionFailure)
import O2I.Operation.Adapter
  ( AdapterDiagnostic
  , AdapterOccurrence
  , AdapterRule
  , AdapterSelectionError
  , NativeLocation
  , adapterDiagnosticOccurrences
  , adapterDiagnosticRule
  , adapterIdText
  , adapterRuleAction
  , adapterRuleExpectation
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleMeaning
  , adapterRuleStage
  , foldAdapterOccurrence
  , foldAdapterRuleStage
  , foldAdapterSelectionError
  , foldNativeLocation
  )
import O2I.Operation.Assess.Result
  ( AssessFailure
  , AssessInternalFailure
  , foldAssessFailure
  , foldAssessInternalFailure
  )
import O2I.Operation.Diagnostic.Owner
  ( AdapterNotationResolutionFailure
  , foldAdapterNotationResolutionFailure
  )
import O2I.Operation.Failure
  ( CommonFailure
  , PreparationFailure
  , ProfileCompatibilityFailure
  , ProfileResolutionFailure
  , commandFailureCode
  , foldCommandFailure
  , foldCommonFailure
  , foldPreparationFailure
  , foldProfileCompatibilityFailure
  , foldProfileResolutionFailure
  , preparationFailureCode
  )
import O2I.Operation.Human.Value
  ( HumanAdapterDescriptor
  , HumanCanonicalField
  , HumanCanonicalOccurrence
  , HumanDraftScalar
  , HumanIdentityOutcome
  , HumanInputSource
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanProfileDescriptor
  , HumanQualifiedType
  , HumanSourceIdentity
  , HumanSourceLocation
  , HumanViewDescriptor
  , HumanViewSelector
  )
import O2I.Operation.Human.Value.Internal
  ( projectAdapterDescriptor
  , projectCanonicalField
  , projectCanonicalOccurrence
  , projectDraftScalar
  , projectIdentityOutcome
  , projectInputSource
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectProfileDescriptor
  , projectQualifiedType
  , projectSourceIdentity
  , projectSourceLocation
  , projectViewDescriptor
  , projectViewSelector
  )
import O2I.Operation.Profile (resolvedProfileDescriptor)
import O2I.Operation.Provenance
  ( SourceRole(..)
  , SupplementalProvenanceDefect
  , foldSourceKey
  , foldSupplementalProvenanceDefect
  , sourceOrdinalValue
  )
import O2I.Operation.Qualification.Subjects.Result
  ( QualificationSubjectsFailure
  , QualificationSubjectsInternalFailure
  , foldQualificationSubjectsFailure
  , foldQualificationSubjectsInternalFailure
  )
import O2I.Operation.Qualify.Result
  ( QualifyFailure
  , QualifyInternalFailure
  , foldQualifyFailure
  , foldQualifyInternalFailure
  )
import O2I.Operation.Readiness.Result
  ( ReadinessFailure
  , ReadinessInternalFailure
  , foldReadinessFailure
  , foldReadinessInternalFailure
  )
import O2I.Operation.Rule.Catalog
  ( OperationRule
  , operationRuleIdText
  , operationRuleIdentity
  )
import O2I.Operation.Trace.Result
  ( TraceFailure
  , TraceInternalFailure
  , foldTraceFailure
  , foldTraceInternalFailure
  )
import O2I.Operation.Validate.Result
  ( ValidateFailure
  , ValidateInternalFailure
  , foldValidateFailure
  , foldValidateInternalFailure
  )
import O2I.Operation.View
  ( ViewSelectionCandidate
  , ViewSelectionFailure
  , foldViewSelectionCandidate
  , foldViewSelectionFailure
  )
import qualified O2I.Qualification as Qualification
import qualified O2I.Readiness as Readiness
import qualified O2I.Semantics.Input as Supplemental
import qualified O2I.Structure as Structure

-- | Closed stage of an Adapter rule retained by a preparation failure.
data HumanFailureAdapterRuleStage
  = HumanFailureAdapterPreparationStage
  | HumanFailureAdapterNotationStage

-- | Eliminate both Adapter rule stages.
foldHumanFailureAdapterRuleStage ::
     result -> result -> HumanFailureAdapterRuleStage -> result
foldHumanFailureAdapterRuleStage preparation notation stage =
  case stage of
    HumanFailureAdapterPreparationStage -> preparation
    HumanFailureAdapterNotationStage -> notation

-- | Complete Adapter rule retained by a preparation failure.
data HumanFailureAdapterRule =
  HumanFailureAdapterRule Text HumanFailureAdapterRuleStage Text Text Text

-- | Consume every retained Adapter rule field.
foldHumanFailureAdapterRule ::
     (Text -> HumanFailureAdapterRuleStage -> Text -> Text -> Text -> result)
  -> HumanFailureAdapterRule
  -> result
foldHumanFailureAdapterRule consume (HumanFailureAdapterRule identity stage expectation meaning action) =
  consume identity stage expectation meaning action

-- | Closed exact native location of an Adapter observation.
data HumanFailureNativeLocation
  = HumanFailureByteOffset Natural
  | HumanFailureLineColumn Natural Natural
  | HumanFailureNativePath (NonEmpty Text)

-- | Eliminate every native-location branch.
foldHumanFailureNativeLocation ::
     (Natural -> result)
  -> (Natural -> Natural -> result)
  -> (NonEmpty Text -> result)
  -> HumanFailureNativeLocation
  -> result
foldHumanFailureNativeLocation offset line path location =
  case location of
    HumanFailureByteOffset value -> offset value
    HumanFailureLineColumn row column -> line row column
    HumanFailureNativePath steps -> path steps

-- | Optional native location of one Adapter diagnostic occurrence.
newtype HumanFailureAdapterOccurrence =
  HumanFailureAdapterOccurrence (Maybe HumanFailureNativeLocation)

-- | Consume the optional exact Adapter occurrence location.
foldHumanFailureAdapterOccurrence ::
     (Maybe HumanFailureNativeLocation -> result)
  -> HumanFailureAdapterOccurrence
  -> result
foldHumanFailureAdapterOccurrence consume (HumanFailureAdapterOccurrence location) =
  consume location

-- | Adapter rule and non-empty diagnostic occurrences.
data HumanFailureAdapterDiagnostic =
  HumanFailureAdapterDiagnostic
    HumanFailureAdapterRule
    (NonEmpty HumanFailureAdapterOccurrence)

-- | Consume every Adapter diagnostic field.
foldHumanFailureAdapterDiagnostic ::
     (HumanFailureAdapterRule -> NonEmpty HumanFailureAdapterOccurrence -> result)
  -> HumanFailureAdapterDiagnostic
  -> result
foldHumanFailureAdapterDiagnostic consume (HumanFailureAdapterDiagnostic rule occurrences) =
  consume rule occurrences

-- | Closed exact Adapter-selection failure.
data HumanAdapterSelectionFailure
  = HumanUnknownAdapter Text
  | HumanAdapterRecognitionFailure
      (NonEmpty (HumanAdapterDescriptor, NonEmpty HumanFailureAdapterDiagnostic))
  | HumanNoAdapterMatched
  | HumanMultipleAdaptersMatched (NonEmpty HumanAdapterDescriptor)

-- | Eliminate every Adapter-selection branch.
foldHumanAdapterSelectionFailure ::
     (Text -> result)
  -> (NonEmpty (HumanAdapterDescriptor, NonEmpty HumanFailureAdapterDiagnostic) -> result)
  -> result
  -> (NonEmpty HumanAdapterDescriptor -> result)
  -> HumanAdapterSelectionFailure
  -> result
foldHumanAdapterSelectionFailure unknown recognition noMatch multiple failure =
  case failure of
    HumanUnknownAdapter identifier -> unknown identifier
    HumanAdapterRecognitionFailure diagnostics -> recognition diagnostics
    HumanNoAdapterMatched -> noMatch
    HumanMultipleAdaptersMatched descriptors -> multiple descriptors

-- | Closed native record family used by retained Profile evidence.
data HumanFailureRecordFamily
  = HumanFailureModelRoot
  | HumanFailurePropertyDefinition
  | HumanFailureElement
  | HumanFailureRelationship
  | HumanFailureView
  | HumanFailureViewNode
  | HumanFailureViewConnection

-- | Eliminate every native record family.
foldHumanFailureRecordFamily ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> HumanFailureRecordFamily
  -> result
foldHumanFailureRecordFamily root definition element relationship view node connection family =
  case family of
    HumanFailureModelRoot -> root
    HumanFailurePropertyDefinition -> definition
    HumanFailureElement -> element
    HumanFailureRelationship -> relationship
    HumanFailureView -> view
    HumanFailureViewNode -> node
    HumanFailureViewConnection -> connection

-- | Closed recognized field of a retained native reference.
data HumanFailureReferenceField
  = HumanFailurePropertyDefinitionReference
  | HumanFailureRelationshipSourceReference
  | HumanFailureRelationshipTargetReference
  | HumanFailureViewNodeElementReference
  | HumanFailureViewConnectionRelationshipReference
  | HumanFailureViewConnectionSourceReference
  | HumanFailureViewConnectionTargetReference

-- | Eliminate every native reference-field branch.
foldHumanFailureReferenceField ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> HumanFailureReferenceField
  -> result
foldHumanFailureReferenceField definition source target element relationship sourceNode targetNode field =
  case field of
    HumanFailurePropertyDefinitionReference -> definition
    HumanFailureRelationshipSourceReference -> source
    HumanFailureRelationshipTargetReference -> target
    HumanFailureViewNodeElementReference -> element
    HumanFailureViewConnectionRelationshipReference -> relationship
    HumanFailureViewConnectionSourceReference -> sourceNode
    HumanFailureViewConnectionTargetReference -> targetNode

-- | Complete resolved native-reference target.
data HumanFailureCanonicalTarget =
  HumanFailureCanonicalTarget
    HumanCanonicalOccurrence
    HumanFailureRecordFamily
    HumanModelIdentity
    HumanSourceLocation
    [HumanCanonicalField]

-- | Consume every retained reference-target field.
foldHumanFailureCanonicalTarget ::
     (HumanCanonicalOccurrence -> HumanFailureRecordFamily -> HumanModelIdentity -> HumanSourceLocation -> [HumanCanonicalField] -> result)
  -> HumanFailureCanonicalTarget
  -> result
foldHumanFailureCanonicalTarget consume (HumanFailureCanonicalTarget occurrence family identity location fields) =
  consume occurrence family identity location fields

-- | Closed native-reference resolution outcome.
data HumanFailureReferenceOutcome
  = HumanFailureReferenceIdentityInvalid HumanIdentityOutcome
  | HumanFailureReferenceTargetMissing HumanDraftScalar HumanModelIdentity
  | HumanFailureReferenceTargetWrongFamily
      HumanDraftScalar
      HumanModelIdentity
      HumanFailureRecordFamily
      [HumanFailureCanonicalTarget]
  | HumanFailureReferenceExpectedFamilyAmbiguous
      HumanDraftScalar
      HumanModelIdentity
      HumanFailureRecordFamily
      [HumanFailureCanonicalTarget]
  | HumanFailureReferenceResolved
      HumanDraftScalar
      HumanModelIdentity
      HumanFailureCanonicalTarget

-- | Eliminate every native-reference outcome with exact cardinality.
foldHumanFailureReferenceOutcome ::
     (HumanIdentityOutcome -> result)
  -> (HumanDraftScalar -> HumanModelIdentity -> result)
  -> (HumanDraftScalar -> HumanModelIdentity -> HumanFailureRecordFamily -> [HumanFailureCanonicalTarget] -> result)
  -> (HumanDraftScalar -> HumanModelIdentity -> HumanFailureRecordFamily -> [HumanFailureCanonicalTarget] -> result)
  -> (HumanDraftScalar -> HumanModelIdentity -> HumanFailureCanonicalTarget -> result)
  -> HumanFailureReferenceOutcome
  -> result
foldHumanFailureReferenceOutcome invalid missing wrong ambiguous resolved outcome =
  case outcome of
    HumanFailureReferenceIdentityInvalid identity -> invalid identity
    HumanFailureReferenceTargetMissing scalar identity ->
      missing scalar identity
    HumanFailureReferenceTargetWrongFamily scalar identity family targets ->
      wrong scalar identity family targets
    HumanFailureReferenceExpectedFamilyAmbiguous scalar identity family targets ->
      ambiguous scalar identity family targets
    HumanFailureReferenceResolved scalar identity target ->
      resolved scalar identity target

-- | Complete native reference retained by Profile preparation.
data HumanFailureCanonicalReference =
  HumanFailureCanonicalReference
    HumanCanonicalOccurrence
    HumanCanonicalOccurrence
    HumanFailureReferenceField
    HumanFailureRecordFamily
    HumanSourceLocation
    HumanFailureReferenceOutcome

-- | Consume every retained canonical-reference field.
foldHumanFailureCanonicalReference ::
     (HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> HumanFailureReferenceField -> HumanFailureRecordFamily -> HumanSourceLocation -> HumanFailureReferenceOutcome -> result)
  -> HumanFailureCanonicalReference
  -> result
foldHumanFailureCanonicalReference consume (HumanFailureCanonicalReference occurrence owner field family location outcome) =
  consume occurrence owner field family location outcome

-- | Closed position of unrecognized retained native evidence.
data HumanFailureOpaquePosition
  = HumanFailureOpaqueAttribute
  | HumanFailureOpaqueChild

-- | Eliminate both opaque-evidence positions.
foldHumanFailureOpaquePosition ::
     result -> result -> HumanFailureOpaquePosition -> result
foldHumanFailureOpaquePosition attribute child position =
  case position of
    HumanFailureOpaqueAttribute -> attribute
    HumanFailureOpaqueChild -> child

-- | Complete unrecognized native observation.
data HumanFailureOpaqueEvidence =
  HumanFailureOpaqueEvidence
    HumanFailureOpaquePosition
    (Maybe Text)
    Text
    [HumanDraftScalar]
    HumanSourceLocation

-- | Consume every retained opaque observation field.
foldHumanFailureOpaqueEvidence ::
     (HumanFailureOpaquePosition -> Maybe Text -> Text -> [HumanDraftScalar] -> HumanSourceLocation -> result)
  -> HumanFailureOpaqueEvidence
  -> result
foldHumanFailureOpaqueEvidence consume (HumanFailureOpaqueEvidence position namespace localName scalars location) =
  consume position namespace localName scalars location

-- | Direct or definition-backed canonical property key.
data HumanFailurePropertyKey
  = HumanFailureDirectPropertyKey [HumanDraftScalar]
  | HumanFailureReferencedPropertyKey HumanFailureCanonicalReference

-- | Eliminate both canonical property-key branches.
foldHumanFailurePropertyKey ::
     ([HumanDraftScalar] -> result)
  -> (HumanFailureCanonicalReference -> result)
  -> HumanFailurePropertyKey
  -> result
foldHumanFailurePropertyKey direct referenced key =
  case key of
    HumanFailureDirectPropertyKey values -> direct values
    HumanFailureReferencedPropertyKey reference -> referenced reference

-- | Complete canonical property retained by Profile preparation.
data HumanFailureCanonicalProperty =
  HumanFailureCanonicalProperty
    HumanCanonicalOccurrence
    HumanCanonicalOccurrence
    HumanFailureRecordFamily
    HumanSourceLocation
    [HumanDraftScalar]
    [HumanFailureOpaqueEvidence]
    HumanFailurePropertyKey

-- | Consume every retained canonical-property field.
foldHumanFailureCanonicalProperty ::
     (HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> HumanFailureRecordFamily -> HumanSourceLocation -> [HumanDraftScalar] -> [HumanFailureOpaqueEvidence] -> HumanFailurePropertyKey -> result)
  -> HumanFailureCanonicalProperty
  -> result
foldHumanFailureCanonicalProperty consume (HumanFailureCanonicalProperty occurrence owner family location values opaque key) =
  consume occurrence owner family location values opaque key

-- | Closed recognition outcome of one Profile-marker key.
data HumanFailureMarkerKeyOutcome
  = HumanFailureMarkerKeyMissing
  | HumanFailureMarkerKeyMultiple [HumanDraftScalar]
  | HumanFailureMarkerKeyNonText HumanDraftScalar
  | HumanFailureMarkerKeyExact HumanDraftScalar
  | HumanFailureMarkerKeyOther HumanDraftScalar
  | HumanFailureMarkerKeyReferenceRejected HumanFailureCanonicalReference

-- | Eliminate every Profile-marker key outcome.
foldHumanFailureMarkerKeyOutcome ::
     result
  -> ([HumanDraftScalar] -> result)
  -> (HumanDraftScalar -> result)
  -> (HumanDraftScalar -> result)
  -> (HumanDraftScalar -> result)
  -> (HumanFailureCanonicalReference -> result)
  -> HumanFailureMarkerKeyOutcome
  -> result
foldHumanFailureMarkerKeyOutcome missing multiple nonText exact other rejected outcome =
  case outcome of
    HumanFailureMarkerKeyMissing -> missing
    HumanFailureMarkerKeyMultiple values -> multiple values
    HumanFailureMarkerKeyNonText value -> nonText value
    HumanFailureMarkerKeyExact value -> exact value
    HumanFailureMarkerKeyOther value -> other value
    HumanFailureMarkerKeyReferenceRejected reference -> rejected reference

-- | Complete model-root property considered as Profile-marker evidence.
data HumanFailureMarkerCandidate =
  HumanFailureMarkerCandidate
    HumanFailureCanonicalProperty
    [HumanCanonicalField]
    HumanFailureMarkerKeyOutcome

-- | Consume every retained Profile-marker candidate field.
foldHumanFailureMarkerCandidate ::
     (HumanFailureCanonicalProperty -> [HumanCanonicalField] -> HumanFailureMarkerKeyOutcome -> result)
  -> HumanFailureMarkerCandidate
  -> result
foldHumanFailureMarkerCandidate consume (HumanFailureMarkerCandidate property fields outcome) =
  consume property fields outcome

-- | Closed scalar kind retained by Profile-resolution failure.
data HumanFailureDraftValueKind
  = HumanFailureDraftText
  | HumanFailureDraftBoolean
  | HumanFailureDraftNumber
  | HumanFailureDraftNativeName
  | HumanFailureDraftOther Text

-- | Eliminate every retained Draft scalar kind.
foldHumanFailureDraftValueKind ::
     result
  -> result
  -> result
  -> result
  -> (Text -> result)
  -> HumanFailureDraftValueKind
  -> result
foldHumanFailureDraftValueKind text boolean number nativeName other kind =
  case kind of
    HumanFailureDraftText -> text
    HumanFailureDraftBoolean -> boolean
    HumanFailureDraftNumber -> number
    HumanFailureDraftNativeName -> nativeName
    HumanFailureDraftOther value -> other value

-- | Closed rejected Profile-resolution branch.
data HumanProfileResolutionFailure
  = HumanProfileReferenceMissing Text Text
  | HumanProfileReferencePropertyMultiplicity
      Text
      Text
      [HumanFailureCanonicalProperty]
  | HumanProfileReferenceValueMultiplicity
      Text
      Text
      HumanFailureCanonicalProperty
      [HumanDraftScalar]
  | HumanProfileReferenceValueKindInvalid
      Text
      Text
      HumanDraftScalar
      HumanFailureDraftValueKind
  | HumanProfileReferenceGrammarInvalid Text Text HumanDraftScalar
  | HumanProfileReferenceUnknown Text Text Text

-- | Eliminate every rejected Profile-resolution branch.
foldHumanProfileResolutionFailure ::
     (Text -> Text -> result)
  -> (Text -> Text -> [HumanFailureCanonicalProperty] -> result)
  -> (Text -> Text -> HumanFailureCanonicalProperty -> [HumanDraftScalar] -> result)
  -> (Text -> Text -> HumanDraftScalar -> HumanFailureDraftValueKind -> result)
  -> (Text -> Text -> HumanDraftScalar -> result)
  -> (Text -> Text -> Text -> result)
  -> HumanProfileResolutionFailure
  -> result
foldHumanProfileResolutionFailure missing properties values kind grammar unknown failure =
  case failure of
    HumanProfileReferenceMissing rule key -> missing rule key
    HumanProfileReferencePropertyMultiplicity rule key occurrences ->
      properties rule key occurrences
    HumanProfileReferenceValueMultiplicity rule key occurrence occurrences ->
      values rule key occurrence occurrences
    HumanProfileReferenceValueKindInvalid rule key occurrence actual ->
      kind rule key occurrence actual
    HumanProfileReferenceGrammarInvalid rule key occurrence ->
      grammar rule key occurrence
    HumanProfileReferenceUnknown rule key reference ->
      unknown rule key reference

-- | Closed rejected Profile/Adapter compatibility branch.
data HumanProfileCompatibilityFailure
  = HumanProfileAdapterNotAdmitted
      Text
      HumanProfileDescriptor
      HumanAdapterDescriptor
      [Text]
  | HumanProfileAdapterNotationMismatch
      Text
      HumanProfileDescriptor
      HumanAdapterDescriptor
      Text
      Text

-- | Eliminate both rejected Profile/Adapter compatibility branches.
foldHumanProfileCompatibilityFailure ::
     (Text -> HumanProfileDescriptor -> HumanAdapterDescriptor -> [Text] -> result)
  -> (Text -> HumanProfileDescriptor -> HumanAdapterDescriptor -> Text -> Text -> result)
  -> HumanProfileCompatibilityFailure
  -> result
foldHumanProfileCompatibilityFailure notAdmitted mismatch failure =
  case failure of
    HumanProfileAdapterNotAdmitted rule profile adapter admitted ->
      notAdmitted rule profile adapter admitted
    HumanProfileAdapterNotationMismatch rule profile adapter profileNotation adapterNotation ->
      mismatch rule profile adapter profileNotation adapterNotation

-- | Complete profile-neutral candidate retained by View selection.
data HumanFailureViewSelectionCandidate =
  HumanFailureViewSelectionCandidate
    HumanCanonicalOccurrence
    HumanFailureRecordFamily
    (Maybe HumanModelIdentity)
    HumanSourceLocation

-- | Consume every retained View-selection candidate field.
foldHumanFailureViewSelectionCandidate ::
     (HumanCanonicalOccurrence -> HumanFailureRecordFamily -> Maybe
                                                                HumanModelIdentity -> HumanSourceLocation -> result)
  -> HumanFailureViewSelectionCandidate
  -> result
foldHumanFailureViewSelectionCandidate consume (HumanFailureViewSelectionCandidate occurrence family identity location) =
  consume occurrence family identity location

-- | Closed View-selection failure with exact candidates.
data HumanViewSelectionFailure
  = HumanViewSelectionUnknown HumanViewSelector
  | HumanViewNameSelectionAmbiguous
      HumanViewSelector
      (NonEmpty HumanViewDescriptor)
  | HumanViewIdentitySelectionAmbiguous
      HumanViewSelector
      (NonEmpty HumanFailureViewSelectionCandidate)
  | HumanViewSelectionWrongFamily
      HumanViewSelector
      HumanFailureViewSelectionCandidate

-- | Eliminate every View-selection failure branch.
foldHumanViewSelectionFailure ::
     (HumanViewSelector -> result)
  -> (HumanViewSelector -> NonEmpty HumanViewDescriptor -> result)
  -> (HumanViewSelector -> NonEmpty HumanFailureViewSelectionCandidate -> result)
  -> (HumanViewSelector -> HumanFailureViewSelectionCandidate -> result)
  -> HumanViewSelectionFailure
  -> result
foldHumanViewSelectionFailure unknown names identities wrongFamily failure =
  case failure of
    HumanViewSelectionUnknown selector -> unknown selector
    HumanViewNameSelectionAmbiguous selector candidates ->
      names selector candidates
    HumanViewIdentitySelectionAmbiguous selector candidates ->
      identities selector candidates
    HumanViewSelectionWrongFamily selector candidate ->
      wrongFamily selector candidate

-- | Closed complete cause of one preparation failure.
data HumanPreparationFailure
  = HumanAdapterSelectionPreparationFailure Text HumanAdapterSelectionFailure
  | HumanAdapterDecodePreparationFailure
      Text
      HumanAdapterDescriptor
      (NonEmpty HumanFailureAdapterDiagnostic)
  | HumanProfileMarkerPreparationFailure Text [HumanFailureMarkerCandidate]
  | HumanProfileResolutionPreparationFailure Text HumanProfileResolutionFailure
  | HumanProfileCompatibilityPreparationFailure
      Text
      HumanProfileCompatibilityFailure
  | HumanViewSelectionPreparationFailure Text HumanViewSelectionFailure

-- | Eliminate every preparation stage with its stable code and exact cause.
foldHumanPreparationFailure ::
     (Text -> HumanAdapterSelectionFailure -> result)
  -> (Text -> HumanAdapterDescriptor -> NonEmpty HumanFailureAdapterDiagnostic -> result)
  -> (Text -> [HumanFailureMarkerCandidate] -> result)
  -> (Text -> HumanProfileResolutionFailure -> result)
  -> (Text -> HumanProfileCompatibilityFailure -> result)
  -> (Text -> HumanViewSelectionFailure -> result)
  -> HumanPreparationFailure
  -> result
foldHumanPreparationFailure selection decode marker profile compatibility view failure =
  case failure of
    HumanAdapterSelectionPreparationFailure code value -> selection code value
    HumanAdapterDecodePreparationFailure code adapter diagnostics ->
      decode code adapter diagnostics
    HumanProfileMarkerPreparationFailure code candidates ->
      marker code candidates
    HumanProfileResolutionPreparationFailure code value -> profile code value
    HumanProfileCompatibilityPreparationFailure code value ->
      compatibility code value
    HumanViewSelectionPreparationFailure code value -> view code value

-- | Process or preparation failure before a prepared report exists.
data HumanCommonFailure
  = HumanInputAcquisitionFailure Text HumanInputSource IOException
  | HumanOperationPreparationFailure HumanPreparationFailure

-- | Consume the stable code and every retained common-failure field.
foldHumanCommonFailure ::
     (Text -> HumanInputSource -> IOException -> result)
  -> (HumanPreparationFailure -> result)
  -> HumanCommonFailure
  -> result
foldHumanCommonFailure acquisition preparation failure =
  case failure of
    HumanInputAcquisitionFailure code source exception ->
      acquisition code source exception
    HumanOperationPreparationFailure value -> preparation value

-- | Project one common failure without exposing Profile-owned causes.
projectCommonFailure :: CommonFailure -> HumanCommonFailure
projectCommonFailure failure =
  foldCommonFailure
    (\command ->
       foldCommandFailure
         (\acquisition ->
            foldAcquisitionFailure
              (\source exception ->
                 HumanInputAcquisitionFailure
                   (commandFailureCode command)
                   (projectInputSource source)
                   exception)
              acquisition)
         command)
    (HumanOperationPreparationFailure . projectHumanPreparationFailure)
    failure

projectHumanPreparationFailure :: PreparationFailure -> HumanPreparationFailure
projectHumanPreparationFailure failure =
  foldPreparationFailure
    (HumanAdapterSelectionPreparationFailure code
       . projectAdapterSelectionFailure)
    (\adapter diagnostics ->
       HumanAdapterDecodePreparationFailure
         code
         (projectAdapterDescriptor adapter)
         (fmap projectFailureAdapterDiagnostic diagnostics))
    (HumanProfileMarkerPreparationFailure code . map projectMarkerCandidate)
    (HumanProfileResolutionPreparationFailure code . projectResolutionFailure)
    (HumanProfileCompatibilityPreparationFailure code
       . projectCompatibilityFailure)
    (HumanViewSelectionPreparationFailure code . projectViewSelectionFailure)
    failure
  where
    code = preparationFailureCode failure

projectFailureAdapterRule :: AdapterRule -> HumanFailureAdapterRule
projectFailureAdapterRule rule =
  HumanFailureAdapterRule
    (adapterRuleIdText (adapterRuleId rule))
    (foldAdapterRuleStage
       HumanFailureAdapterPreparationStage
       HumanFailureAdapterNotationStage
       (adapterRuleStage rule))
    (adapterRuleExpectation rule)
    (adapterRuleMeaning rule)
    (adapterRuleAction rule)

projectFailureNativeLocation :: NativeLocation -> HumanFailureNativeLocation
projectFailureNativeLocation =
  foldNativeLocation
    HumanFailureByteOffset
    HumanFailureLineColumn
    HumanFailureNativePath

projectFailureAdapterOccurrence ::
     AdapterOccurrence -> HumanFailureAdapterOccurrence
projectFailureAdapterOccurrence =
  foldAdapterOccurrence
    (HumanFailureAdapterOccurrence Nothing)
    (HumanFailureAdapterOccurrence . Just . projectFailureNativeLocation)

projectFailureAdapterDiagnostic ::
     AdapterDiagnostic -> HumanFailureAdapterDiagnostic
projectFailureAdapterDiagnostic diagnostic =
  HumanFailureAdapterDiagnostic
    (projectFailureAdapterRule (adapterDiagnosticRule diagnostic))
    (fmap
       projectFailureAdapterOccurrence
       (adapterDiagnosticOccurrences diagnostic))

projectAdapterSelectionFailure ::
     AdapterSelectionError -> HumanAdapterSelectionFailure
projectAdapterSelectionFailure =
  foldAdapterSelectionError
    (HumanUnknownAdapter . adapterIdText)
    (HumanAdapterRecognitionFailure
       . fmap
           (\(adapter, diagnostics) ->
              ( projectAdapterDescriptor adapter
              , fmap projectFailureAdapterDiagnostic diagnostics)))
    HumanNoAdapterMatched
    (HumanMultipleAdaptersMatched . fmap projectAdapterDescriptor)

projectFailureRecordFamily ::
     Draft.DraftRecordFamilyValue -> HumanFailureRecordFamily
projectFailureRecordFamily =
  Draft.foldDraftRecordFamilyValue
    HumanFailureModelRoot
    HumanFailurePropertyDefinition
    HumanFailureElement
    HumanFailureRelationship
    HumanFailureView
    HumanFailureViewNode
    HumanFailureViewConnection

projectFailureReferenceField ::
     Draft.DraftReferenceFieldValue -> HumanFailureReferenceField
projectFailureReferenceField =
  Draft.foldDraftReferenceFieldValue
    HumanFailurePropertyDefinitionReference
    HumanFailureRelationshipSourceReference
    HumanFailureRelationshipTargetReference
    HumanFailureViewNodeElementReference
    HumanFailureViewConnectionRelationshipReference
    HumanFailureViewConnectionSourceReference
    HumanFailureViewConnectionTargetReference

projectFailureCanonicalTarget ::
     Notation.CanonicalTarget -> HumanFailureCanonicalTarget
projectFailureCanonicalTarget target =
  HumanFailureCanonicalTarget
    (projectCanonicalOccurrence (Notation.canonicalTargetOccurrence target))
    (projectFailureRecordFamily (Notation.canonicalTargetFamily target))
    (projectModelIdentity (Notation.canonicalTargetIdentity target))
    (projectSourceLocation (Notation.canonicalTargetLocation target))
    (map projectCanonicalField (Notation.canonicalTargetFields target))

projectFailureReferenceOutcome ::
     Notation.ReferenceOutcome -> HumanFailureReferenceOutcome
projectFailureReferenceOutcome =
  Notation.foldReferenceOutcome
    (HumanFailureReferenceIdentityInvalid . projectIdentityOutcome)
    (\scalar identity ->
       HumanFailureReferenceTargetMissing
         (projectDraftScalar scalar)
         (projectModelIdentity identity))
    (\scalar identity family targets ->
       HumanFailureReferenceTargetWrongFamily
         (projectDraftScalar scalar)
         (projectModelIdentity identity)
         (projectFailureRecordFamily family)
         (map projectFailureCanonicalTarget targets))
    (\scalar identity family targets ->
       HumanFailureReferenceExpectedFamilyAmbiguous
         (projectDraftScalar scalar)
         (projectModelIdentity identity)
         (projectFailureRecordFamily family)
         (map projectFailureCanonicalTarget targets))
    (\scalar identity target ->
       HumanFailureReferenceResolved
         (projectDraftScalar scalar)
         (projectModelIdentity identity)
         (projectFailureCanonicalTarget target))

projectFailureCanonicalReference ::
     Notation.CanonicalReference -> HumanFailureCanonicalReference
projectFailureCanonicalReference reference =
  HumanFailureCanonicalReference
    (projectCanonicalOccurrence
       (Notation.canonicalReferenceOccurrence reference))
    (projectCanonicalOccurrence (Notation.canonicalReferenceOwner reference))
    (projectFailureReferenceField (Notation.canonicalReferenceField reference))
    (projectFailureRecordFamily
       (Notation.canonicalReferenceExpectedFamily reference))
    (projectSourceLocation (Notation.canonicalReferenceLocation reference))
    (projectFailureReferenceOutcome
       (Notation.canonicalReferenceOutcome reference))

projectFailureOpaqueEvidence ::
     Draft.DraftOpaqueEvidence -> HumanFailureOpaqueEvidence
projectFailureOpaqueEvidence evidence =
  HumanFailureOpaqueEvidence
    (Draft.foldDraftOpaquePosition
       HumanFailureOpaqueAttribute
       HumanFailureOpaqueChild
       (Draft.draftOpaquePosition evidence))
    (Draft.draftNativeNamespace (Draft.draftOpaqueName evidence))
    (Draft.draftNativeLocalName (Draft.draftOpaqueName evidence))
    (map projectDraftScalar (Draft.draftOpaqueScalars evidence))
    (projectSourceLocation (Draft.draftOpaqueLocation evidence))

projectFailurePropertyKey ::
     Notation.CanonicalProperty -> HumanFailurePropertyKey
projectFailurePropertyKey =
  Notation.foldCanonicalPropertyKey
    (HumanFailureDirectPropertyKey . map projectDraftScalar)
    (HumanFailureReferencedPropertyKey . projectFailureCanonicalReference)

projectFailureCanonicalProperty ::
     Notation.CanonicalProperty -> HumanFailureCanonicalProperty
projectFailureCanonicalProperty property =
  HumanFailureCanonicalProperty
    (projectCanonicalOccurrence (Notation.canonicalPropertyOccurrence property))
    (projectCanonicalOccurrence (Notation.canonicalPropertyOwner property))
    (projectFailureRecordFamily (Notation.canonicalPropertyOwnerFamily property))
    (projectSourceLocation (Notation.canonicalPropertyLocation property))
    (map projectDraftScalar (Notation.canonicalPropertyValues property))
    (map
       projectFailureOpaqueEvidence
       (Notation.canonicalPropertyOpaqueEvidence property))
    (projectFailurePropertyKey property)

projectMarkerKeyOutcome ::
     Notation.MarkerKeyOutcome -> HumanFailureMarkerKeyOutcome
projectMarkerKeyOutcome =
  Notation.foldMarkerKeyOutcome
    HumanFailureMarkerKeyMissing
    (HumanFailureMarkerKeyMultiple . map projectDraftScalar)
    (HumanFailureMarkerKeyNonText . projectDraftScalar)
    (HumanFailureMarkerKeyExact . projectDraftScalar)
    (HumanFailureMarkerKeyOther . projectDraftScalar)
    (HumanFailureMarkerKeyReferenceRejected . projectFailureCanonicalReference)

projectMarkerCandidate ::
     Notation.MarkerCandidate -> HumanFailureMarkerCandidate
projectMarkerCandidate candidate =
  HumanFailureMarkerCandidate
    (projectFailureCanonicalProperty
       (Notation.markerCandidateProperty candidate))
    (map
       projectCanonicalField
       (Notation.markerCandidateDefinitionFields candidate))
    (projectMarkerKeyOutcome (Notation.markerCandidateKeyOutcome candidate))

projectFailureDraftValueKind ::
     Draft.DraftValueKind -> HumanFailureDraftValueKind
projectFailureDraftValueKind =
  Draft.foldDraftValueKind
    HumanFailureDraftText
    HumanFailureDraftBoolean
    HumanFailureDraftNumber
    HumanFailureDraftNativeName
    HumanFailureDraftOther

projectResolutionFailure ::
     ProfileResolutionFailure -> HumanProfileResolutionFailure
projectResolutionFailure =
  foldProfileResolutionFailure
    (\rule key -> HumanProfileReferenceMissing (projectRule rule) key)
    (\rule key properties ->
       HumanProfileReferencePropertyMultiplicity
         (projectRule rule)
         key
         (map projectFailureCanonicalProperty properties))
    (\rule key property values ->
       HumanProfileReferenceValueMultiplicity
         (projectRule rule)
         key
         (projectFailureCanonicalProperty property)
         (map projectDraftScalar values))
    (\rule key scalar kind ->
       HumanProfileReferenceValueKindInvalid
         (projectRule rule)
         key
         (projectDraftScalar scalar)
         (projectFailureDraftValueKind kind))
    (\rule key scalar ->
       HumanProfileReferenceGrammarInvalid
         (projectRule rule)
         key
         (projectDraftScalar scalar))
    (\rule key reference ->
       HumanProfileReferenceUnknown (projectRule rule) key reference)

projectCompatibilityFailure ::
     ProfileCompatibilityFailure -> HumanProfileCompatibilityFailure
projectCompatibilityFailure =
  foldProfileCompatibilityFailure
    (\rule profile adapter admitted ->
       HumanProfileAdapterNotAdmitted
         (projectRule rule)
         (projectProfileDescriptor (resolvedProfileDescriptor profile))
         (projectAdapterDescriptor adapter)
         admitted)
    (\rule profile adapter profileNotation adapterNotation ->
       HumanProfileAdapterNotationMismatch
         (projectRule rule)
         (projectProfileDescriptor (resolvedProfileDescriptor profile))
         (projectAdapterDescriptor adapter)
         profileNotation
         adapterNotation)

projectViewSelectionCandidate ::
     ViewSelectionCandidate document -> HumanFailureViewSelectionCandidate
projectViewSelectionCandidate =
  foldViewSelectionCandidate $ \occurrence family identity location ->
    HumanFailureViewSelectionCandidate
      (projectCanonicalOccurrence occurrence)
      (projectFailureRecordFamily family)
      (fmap projectModelIdentity identity)
      (projectSourceLocation location)

projectViewSelectionFailure ::
     ViewSelectionFailure document -> HumanViewSelectionFailure
projectViewSelectionFailure =
  foldViewSelectionFailure
    (HumanViewSelectionUnknown . projectViewSelector)
    (\selector candidates ->
       HumanViewNameSelectionAmbiguous
         (projectViewSelector selector)
         (fmap projectViewDescriptor candidates))
    (\selector candidates ->
       HumanViewIdentitySelectionAmbiguous
         (projectViewSelector selector)
         (fmap projectViewSelectionCandidate candidates))
    (\selector candidate ->
       HumanViewSelectionWrongFamily
         (projectViewSelector selector)
         (projectViewSelectionCandidate candidate))

projectRule :: OperationRule -> Text
projectRule = operationRuleIdText . operationRuleIdentity

-- | Exact typed subject of an evidence or assessment input defect.
data HumanInputDefectSubject
  = HumanInputTextSubject Text Text
  | HumanInputNaturalSubject Text Natural
  | HumanInputModelSubject Text HumanModelIdentity
  | HumanInputOccurrenceSubject Text HumanOccurrenceIdentity
  | HumanInputQualifiedTypeSubject Text HumanQualifiedType

-- | Consume every closed input-defect subject branch.
foldHumanInputDefectSubject ::
     (Text -> Text -> result)
  -> (Text -> Natural -> result)
  -> (Text -> HumanModelIdentity -> result)
  -> (Text -> HumanOccurrenceIdentity -> result)
  -> (Text -> HumanQualifiedType -> result)
  -> HumanInputDefectSubject
  -> result
foldHumanInputDefectSubject text natural model occurrence qualified subject =
  case subject of
    HumanInputTextSubject label value -> text label value
    HumanInputNaturalSubject label value -> natural label value
    HumanInputModelSubject label value -> model label value
    HumanInputOccurrenceSubject label value -> occurrence label value
    HumanInputQualifiedTypeSubject label value -> qualified label value

-- | Closed producer kind of an evidence or assessment input defect.
data HumanInputDefectKind
  = HumanInputInvalidUtf8
  | HumanInputInvalidJsonSyntax
  | HumanInputDuplicateObjectMember
  | HumanInputTopLevelObjectRequired
  | HumanInputDiscriminatorInvalid
  | HumanInputRequiredMemberMissing
  | HumanInputUnknownMember
  | HumanInputValueKindInvalid
  | HumanInputScalarGrammarInvalid
  | HumanInputArrayCardinalityInvalid
  | HumanInputArrayDistinctnessInvalid
  | HumanInputNormalizationCollision
  | HumanInputModelIdentityUnicodeScalarInvalid
  | HumanInputModelIdentityContainsNul
  | HumanInputIdentityUnknown
  | HumanInputIdentityAmbiguous
  | HumanInputIdentityOutOfSelectedView
  | HumanInputIdentityWrongType

-- | Eliminate all closed evidence-input producer kinds.
foldHumanInputDefectKind ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> HumanInputDefectKind
  -> result
foldHumanInputDefectKind utf8 syntax duplicate top discriminator required unknown value grammar cardinality distinctness collision unicode nul identityUnknown identityAmbiguous outOfView wrongType kind =
  case kind of
    HumanInputInvalidUtf8 -> utf8
    HumanInputInvalidJsonSyntax -> syntax
    HumanInputDuplicateObjectMember -> duplicate
    HumanInputTopLevelObjectRequired -> top
    HumanInputDiscriminatorInvalid -> discriminator
    HumanInputRequiredMemberMissing -> required
    HumanInputUnknownMember -> unknown
    HumanInputValueKindInvalid -> value
    HumanInputScalarGrammarInvalid -> grammar
    HumanInputArrayCardinalityInvalid -> cardinality
    HumanInputArrayDistinctnessInvalid -> distinctness
    HumanInputNormalizationCollision -> collision
    HumanInputModelIdentityUnicodeScalarInvalid -> unicode
    HumanInputModelIdentityContainsNul -> nul
    HumanInputIdentityUnknown -> identityUnknown
    HumanInputIdentityAmbiguous -> identityAmbiguous
    HumanInputIdentityOutOfSelectedView -> outOfView
    HumanInputIdentityWrongType -> wrongType

-- | Complete typed evidence or assessment input defect.
data HumanInputDefect =
  HumanInputDefect
    Text
    Natural
    HumanInputDefectKind
    Text
    (NonEmpty HumanInputDefectSubject)

-- | Consume every evidence-input defect field in owner order.
foldHumanInputDefect ::
     (Text -> Natural -> HumanInputDefectKind -> Text -> NonEmpty
                                                           HumanInputDefectSubject -> result)
  -> HumanInputDefect
  -> result
foldHumanInputDefect consume (HumanInputDefect rule ordinal kind pointer subjects) =
  consume rule ordinal kind pointer subjects

-- | Closed supplemental payload category.
data HumanSupplementalPayloadType
  = HumanStrategyFormulationPayload
  | HumanCollectiveFitPayload

-- | Eliminate both supplemental payload categories.
foldHumanSupplementalPayloadType ::
     result -> result -> HumanSupplementalPayloadType -> result
foldHumanSupplementalPayloadType strategy fit payload =
  case payload of
    HumanStrategyFormulationPayload -> strategy
    HumanCollectiveFitPayload -> fit

-- | Closed supplemental-input defects with branch-correlated typed evidence.
data HumanSupplementalInputDefect
  = HumanSupplementalInvalidUtf8 Text Natural
  | HumanSupplementalInvalidJsonSyntax Text Natural
  | HumanSupplementalDuplicateObjectMember Text Natural Text
  | HumanSupplementalTopLevelObjectRequired Text Natural Text Text
  | HumanSupplementalTypeMemberInvalid Text Natural Text Text
  | HumanSupplementalPayloadTypeNotAdmitted Text Natural Text Text
  | HumanSupplementalRequiredMemberMissing Text Natural Text Text
  | HumanSupplementalUnknownMember Text Natural Text Text
  | HumanSupplementalValueKindInvalid Text Natural Text Text
  | HumanSupplementalScalarGrammarInvalid Text Natural Text Text
  | HumanSupplementalArrayCardinalityInvalid Text Natural Text Text
  | HumanSupplementalArrayDistinctnessInvalid Text Natural Text Text
  | HumanSupplementalSubjectCardinalityInvalid
      Text
      (NonEmpty Natural)
      HumanSupplementalPayloadType
      HumanModelIdentity
  | HumanSupplementalIdentityUnknown Text Natural Text HumanModelIdentity
  | HumanSupplementalIdentityAmbiguous Text Natural Text HumanModelIdentity
  | HumanSupplementalIdentityWrongType Text Natural Text HumanModelIdentity
  | HumanSupplementalIdentityOutOfSelectedView
      Text
      Natural
      Text
      HumanModelIdentity
  | HumanSupplementalModelIdentityUnicodeScalarInvalid
      Text
      Natural
      Text
      Text
      (NonEmpty (Natural, Natural))
  | HumanSupplementalModelIdentityContainsNul
      Text
      Natural
      Text
      Text
      (NonEmpty Natural)

-- | Eliminate all producer branches with their exact correlated fields.
foldHumanSupplementalInputDefect ::
     (Text -> Natural -> result)
  -> (Text -> Natural -> result)
  -> (Text -> Natural -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> NonEmpty Natural -> HumanSupplementalPayloadType -> HumanModelIdentity -> result)
  -> (Text -> Natural -> Text -> HumanModelIdentity -> result)
  -> (Text -> Natural -> Text -> HumanModelIdentity -> result)
  -> (Text -> Natural -> Text -> HumanModelIdentity -> result)
  -> (Text -> Natural -> Text -> HumanModelIdentity -> result)
  -> (Text -> Natural -> Text -> Text -> NonEmpty (Natural, Natural) -> result)
  -> (Text -> Natural -> Text -> Text -> NonEmpty Natural -> result)
  -> HumanSupplementalInputDefect
  -> result
foldHumanSupplementalInputDefect invalidUtf8 invalidJson duplicate topLevel typeMember payloadType required unknown valueKind scalarGrammar arrayCardinality arrayDistinctness subjectCardinality identityUnknown identityAmbiguous identityWrongType identityOutOfView unicode nul defect =
  case defect of
    HumanSupplementalInvalidUtf8 rule ordinal -> invalidUtf8 rule ordinal
    HumanSupplementalInvalidJsonSyntax rule ordinal -> invalidJson rule ordinal
    HumanSupplementalDuplicateObjectMember rule ordinal pointer ->
      duplicate rule ordinal pointer
    HumanSupplementalTopLevelObjectRequired rule ordinal pointer expected ->
      topLevel rule ordinal pointer expected
    HumanSupplementalTypeMemberInvalid rule ordinal pointer expected ->
      typeMember rule ordinal pointer expected
    HumanSupplementalPayloadTypeNotAdmitted rule ordinal pointer expected ->
      payloadType rule ordinal pointer expected
    HumanSupplementalRequiredMemberMissing rule ordinal pointer expected ->
      required rule ordinal pointer expected
    HumanSupplementalUnknownMember rule ordinal pointer expected ->
      unknown rule ordinal pointer expected
    HumanSupplementalValueKindInvalid rule ordinal pointer expected ->
      valueKind rule ordinal pointer expected
    HumanSupplementalScalarGrammarInvalid rule ordinal pointer expected ->
      scalarGrammar rule ordinal pointer expected
    HumanSupplementalArrayCardinalityInvalid rule ordinal pointer expected ->
      arrayCardinality rule ordinal pointer expected
    HumanSupplementalArrayDistinctnessInvalid rule ordinal pointer expected ->
      arrayDistinctness rule ordinal pointer expected
    HumanSupplementalSubjectCardinalityInvalid rule ordinals payload subject ->
      subjectCardinality rule ordinals payload subject
    HumanSupplementalIdentityUnknown rule ordinal pointer identity ->
      identityUnknown rule ordinal pointer identity
    HumanSupplementalIdentityAmbiguous rule ordinal pointer identity ->
      identityAmbiguous rule ordinal pointer identity
    HumanSupplementalIdentityWrongType rule ordinal pointer identity ->
      identityWrongType rule ordinal pointer identity
    HumanSupplementalIdentityOutOfSelectedView rule ordinal pointer identity ->
      identityOutOfView rule ordinal pointer identity
    HumanSupplementalModelIdentityUnicodeScalarInvalid rule ordinal pointer expected occurrences ->
      unicode rule ordinal pointer expected occurrences
    HumanSupplementalModelIdentityContainsNul rule ordinal pointer expected indexes ->
      nul rule ordinal pointer expected indexes

-- | Adapter-notation contract mismatch without exposing Profile types.
data HumanNotationContractFailure
  = HumanNotationAuthorityMismatch HumanAdapterDescriptor HumanAdapterDescriptor
  | HumanNotationRuleMissing HumanAdapterDescriptor Text

-- | Eliminate both fixed notation-contract failures.
foldHumanNotationContractFailure ::
     (HumanAdapterDescriptor -> HumanAdapterDescriptor -> result)
  -> (HumanAdapterDescriptor -> Text -> result)
  -> HumanNotationContractFailure
  -> result
foldHumanNotationContractFailure mismatch missing failure =
  case failure of
    HumanNotationAuthorityMismatch authority contract ->
      mismatch authority contract
    HumanNotationRuleMissing adapter kind -> missing adapter kind

-- | Closed Profile-contract evidence.
data HumanProfileContractEvidence
  = HumanUnknownGeneratedProfileRule Text Text
  | HumanGeneratedProfileEvidenceMismatch Text Text
  | HumanMissingCoreContractBinding Text HumanCanonicalOccurrence
  | HumanImpossibleOccurrenceIdentity HumanCanonicalOccurrence Text

-- | Eliminate every fixed Profile-contract evidence branch.
foldHumanProfileContractEvidence ::
     (Text -> Text -> result)
  -> (Text -> Text -> result)
  -> (Text -> HumanCanonicalOccurrence -> result)
  -> (HumanCanonicalOccurrence -> Text -> result)
  -> HumanProfileContractEvidence
  -> result
foldHumanProfileContractEvidence unknown mismatch missing impossible evidence =
  case evidence of
    HumanUnknownGeneratedProfileRule rule kind -> unknown rule kind
    HumanGeneratedProfileEvidenceMismatch rule kind -> mismatch rule kind
    HumanMissingCoreContractBinding binding occurrence ->
      missing binding occurrence
    HumanImpossibleOccurrenceIdentity occurrence details ->
      impossible occurrence details

-- | Duplicate exact identity evidence.
data HumanIdentityIndexDefect =
  HumanIdentityIndexDefect HumanOccurrenceIdentity (NonEmpty HumanModelIdentity)

-- | Consume every duplicate-identity field.
foldHumanIdentityIndexDefect ::
     (HumanOccurrenceIdentity -> NonEmpty HumanModelIdentity -> result)
  -> HumanIdentityIndexDefect
  -> result
foldHumanIdentityIndexDefect consume (HumanIdentityIndexDefect occurrence identities) =
  consume occurrence identities

-- | Closed selected-View scope failure kind.
data HumanSelectedViewScopeDefectKind
  = HumanUnknownSelectedViewSubjectOccurrence
  | HumanSelectedViewSubjectIdentityMismatch
  | HumanUnknownSelectedViewOccurrence
  | HumanDuplicateSelectedViewOccurrence

-- | Eliminate every selected-View scope failure kind.
foldHumanSelectedViewScopeDefectKind ::
     result
  -> result
  -> result
  -> result
  -> HumanSelectedViewScopeDefectKind
  -> result
foldHumanSelectedViewScopeDefectKind unknownSubject mismatch unknown duplicate kind =
  case kind of
    HumanUnknownSelectedViewSubjectOccurrence -> unknownSubject
    HumanSelectedViewSubjectIdentityMismatch -> mismatch
    HumanUnknownSelectedViewOccurrence -> unknown
    HumanDuplicateSelectedViewOccurrence -> duplicate

-- | Exact selected-View scope failure evidence.
data HumanSelectedViewScopeDefect =
  HumanSelectedViewScopeDefect
    HumanSelectedViewScopeDefectKind
    HumanOccurrenceIdentity
    Natural

-- | Consume every selected-View scope field.
foldHumanSelectedViewScopeDefect ::
     (HumanSelectedViewScopeDefectKind -> HumanOccurrenceIdentity -> Natural -> result)
  -> HumanSelectedViewScopeDefect
  -> result
foldHumanSelectedViewScopeDefect consume (HumanSelectedViewScopeDefect kind occurrence cardinality) =
  consume kind occurrence cardinality

-- | Closed Structure-input evidence.
data HumanStructureInputDefect
  = HumanProjectionOutsideSelectedView HumanOccurrenceIdentity
  | HumanDuplicateStructureProjection HumanOccurrenceIdentity (NonEmpty Text)
  | HumanMissingCarrierProjection
      HumanOccurrenceIdentity
      Text
      HumanOccurrenceIdentity
  | HumanMissingStructuredPropositionProjection
      HumanOccurrenceIdentity
      HumanOccurrenceIdentity

-- | Eliminate every fixed Structure-input branch.
foldHumanStructureInputDefect ::
     (HumanOccurrenceIdentity -> result)
  -> (HumanOccurrenceIdentity -> NonEmpty Text -> result)
  -> (HumanOccurrenceIdentity -> Text -> HumanOccurrenceIdentity -> result)
  -> (HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result)
  -> HumanStructureInputDefect
  -> result
foldHumanStructureInputDefect outside duplicate carrier proposition defect =
  case defect of
    HumanProjectionOutsideSelectedView occurrence -> outside occurrence
    HumanDuplicateStructureProjection occurrence kinds ->
      duplicate occurrence kinds
    HumanMissingCarrierProjection owner role endpoint ->
      carrier owner role endpoint
    HumanMissingStructuredPropositionProjection identity occurrence ->
      proposition identity occurrence

-- | Closed supplemental provenance defect.
data HumanSupplementalProvenanceDefect
  = HumanModelSourceIsNotSupplemental HumanSourceIdentity
  | HumanDuplicateSupplementalSource Text Natural (NonEmpty HumanSourceIdentity)

-- | Eliminate both supplemental provenance failures.
foldHumanSupplementalProvenanceDefect ::
     (HumanSourceIdentity -> result)
  -> (Text -> Natural -> NonEmpty HumanSourceIdentity -> result)
  -> HumanSupplementalProvenanceDefect
  -> result
foldHumanSupplementalProvenanceDefect model duplicate defect =
  case defect of
    HumanModelSourceIsNotSupplemental source -> model source
    HumanDuplicateSupplementalSource role ordinal sources ->
      duplicate role ordinal sources

-- | Failure projection used by qualification-subject reports.
data HumanQualificationSubjectsFailure
  = HumanQualificationSubjectsCommonFailure HumanCommonFailure
  | HumanQualificationSubjectsSupplementalFailure
      (NonEmpty HumanSupplementalInputDefect)
  | HumanQualificationSubjectsModelRoleFailure HumanSourceIdentity
  | HumanQualificationSubjectsSupplementalRoleFailure HumanSourceIdentity
  | HumanQualificationSubjectsAdapterFailure HumanAdapterDescriptor
  | HumanQualificationSubjectsNotationFailure HumanNotationContractFailure
  | HumanQualificationSubjectsProfileFailure
      (NonEmpty HumanProfileContractEvidence)
  | HumanQualificationSubjectsIdentityFailure
      (NonEmpty HumanIdentityIndexDefect)
  | HumanQualificationSubjectsScopeFailure
      (NonEmpty HumanSelectedViewScopeDefect)
  | HumanQualificationSubjectsStructureFailure
      (NonEmpty HumanStructureInputDefect)
  | HumanQualificationSubjectsProvenanceFailure
      (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanQualificationSubjectsContextFailure
  | HumanQualificationSubjectsProjectionFailure HumanCanonicalOccurrence Text
  | HumanQualificationSubjectsJoinFailure
      HumanOccurrenceIdentity
      [HumanCanonicalOccurrence]

-- | Consume every qualification-subject failure branch.
foldHumanQualificationSubjectsFailure ::
     (HumanCommonFailure -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> result
  -> (HumanCanonicalOccurrence -> Text -> result)
  -> (HumanOccurrenceIdentity -> [HumanCanonicalOccurrence] -> result)
  -> HumanQualificationSubjectsFailure
  -> result
foldHumanQualificationSubjectsFailure common supplemental model supplementalRole adapter notation profile identity scope structure provenance context projection join failure =
  case failure of
    HumanQualificationSubjectsCommonFailure value -> common value
    HumanQualificationSubjectsSupplementalFailure value -> supplemental value
    HumanQualificationSubjectsModelRoleFailure value -> model value
    HumanQualificationSubjectsSupplementalRoleFailure value ->
      supplementalRole value
    HumanQualificationSubjectsAdapterFailure value -> adapter value
    HumanQualificationSubjectsNotationFailure value -> notation value
    HumanQualificationSubjectsProfileFailure value -> profile value
    HumanQualificationSubjectsIdentityFailure value -> identity value
    HumanQualificationSubjectsScopeFailure value -> scope value
    HumanQualificationSubjectsStructureFailure value -> structure value
    HumanQualificationSubjectsProvenanceFailure value -> provenance value
    HumanQualificationSubjectsContextFailure -> context
    HumanQualificationSubjectsProjectionFailure occurrence defect ->
      projection occurrence defect
    HumanQualificationSubjectsJoinFailure occurrence candidates ->
      join occurrence candidates

-- | Failure projection used by Validate reports.
data HumanValidateFailure
  = HumanValidateCommonFailure HumanCommonFailure
  | HumanValidateSupplementalFailure (NonEmpty HumanSupplementalInputDefect)
  | HumanValidateModelRoleFailure HumanSourceIdentity
  | HumanValidateSupplementalRoleFailure HumanSourceIdentity
  | HumanValidateAdapterFailure HumanAdapterDescriptor
  | HumanValidateNotationFailure HumanNotationContractFailure
  | HumanValidateProfileFailure (NonEmpty HumanProfileContractEvidence)
  | HumanValidateIdentityFailure (NonEmpty HumanIdentityIndexDefect)
  | HumanValidateScopeFailure (NonEmpty HumanSelectedViewScopeDefect)
  | HumanValidateStructureFailure (NonEmpty HumanStructureInputDefect)
  | HumanValidateProvenanceFailure (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanValidateSemanticFailure [HumanOccurrenceIdentity]

-- | Consume every Validate failure branch.
foldHumanValidateFailure ::
     (HumanCommonFailure -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> ([HumanOccurrenceIdentity] -> result)
  -> HumanValidateFailure
  -> result
foldHumanValidateFailure common supplemental model supplementalRole adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    HumanValidateCommonFailure value -> common value
    HumanValidateSupplementalFailure value -> supplemental value
    HumanValidateModelRoleFailure value -> model value
    HumanValidateSupplementalRoleFailure value -> supplementalRole value
    HumanValidateAdapterFailure value -> adapter value
    HumanValidateNotationFailure value -> notation value
    HumanValidateProfileFailure value -> profile value
    HumanValidateIdentityFailure value -> identity value
    HumanValidateScopeFailure value -> scope value
    HumanValidateStructureFailure value -> structure value
    HumanValidateProvenanceFailure value -> provenance value
    HumanValidateSemanticFailure value -> semantic value

-- | Failure projection used by Trace reports.
data HumanTraceFailure
  = HumanTraceCommonFailure HumanCommonFailure
  | HumanTraceModelRoleFailure HumanSourceIdentity
  | HumanTraceAdapterFailure HumanAdapterDescriptor
  | HumanTraceNotationFailure HumanNotationContractFailure
  | HumanTraceProfileFailure (NonEmpty HumanProfileContractEvidence)
  | HumanTraceIdentityFailure (NonEmpty HumanIdentityIndexDefect)
  | HumanTraceScopeFailure (NonEmpty HumanSelectedViewScopeDefect)
  | HumanTraceStructureFailure (NonEmpty HumanStructureInputDefect)
  | HumanTraceProvenanceFailure (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanTraceSupplementalInputFailure (NonEmpty HumanSupplementalInputDefect)
  | HumanTraceSemanticFailure [HumanOccurrenceIdentity]

-- | Consume every Trace failure branch.
foldHumanTraceFailure ::
     (HumanCommonFailure -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> ([HumanOccurrenceIdentity] -> result)
  -> HumanTraceFailure
  -> result
foldHumanTraceFailure common model adapter notation profile identity scope structure provenance input semantic failure =
  case failure of
    HumanTraceCommonFailure value -> common value
    HumanTraceModelRoleFailure value -> model value
    HumanTraceAdapterFailure value -> adapter value
    HumanTraceNotationFailure value -> notation value
    HumanTraceProfileFailure value -> profile value
    HumanTraceIdentityFailure value -> identity value
    HumanTraceScopeFailure value -> scope value
    HumanTraceStructureFailure value -> structure value
    HumanTraceProvenanceFailure value -> provenance value
    HumanTraceSupplementalInputFailure value -> input value
    HumanTraceSemanticFailure value -> semantic value

-- | Failure projection used by Qualify reports.
data HumanQualifyFailure
  = HumanQualifyCommonFailure HumanCommonFailure
  | HumanQualifySupplementalFailure (NonEmpty HumanSupplementalInputDefect)
  | HumanQualifyModelRoleFailure HumanSourceIdentity
  | HumanQualifySupplementalRoleFailure HumanSourceIdentity
  | HumanQualifyAdapterFailure HumanAdapterDescriptor
  | HumanQualifyNotationFailure HumanNotationContractFailure
  | HumanQualifyProfileFailure (NonEmpty HumanProfileContractEvidence)
  | HumanQualifyIdentityFailure (NonEmpty HumanIdentityIndexDefect)
  | HumanQualifyScopeFailure (NonEmpty HumanSelectedViewScopeDefect)
  | HumanQualifyStructureFailure (NonEmpty HumanStructureInputDefect)
  | HumanQualifyProvenanceFailure (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanQualifyContextFailure

-- | Consume every Qualify failure branch.
foldHumanQualifyFailure ::
     (HumanCommonFailure -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> result
  -> HumanQualifyFailure
  -> result
foldHumanQualifyFailure common supplemental model supplementalRole adapter notation profile identity scope structure provenance context failure =
  case failure of
    HumanQualifyCommonFailure value -> common value
    HumanQualifySupplementalFailure value -> supplemental value
    HumanQualifyModelRoleFailure value -> model value
    HumanQualifySupplementalRoleFailure value -> supplementalRole value
    HumanQualifyAdapterFailure value -> adapter value
    HumanQualifyNotationFailure value -> notation value
    HumanQualifyProfileFailure value -> profile value
    HumanQualifyIdentityFailure value -> identity value
    HumanQualifyScopeFailure value -> scope value
    HumanQualifyStructureFailure value -> structure value
    HumanQualifyProvenanceFailure value -> provenance value
    HumanQualifyContextFailure -> context

-- | Failure projection used by Readiness reports.
data HumanReadinessFailure
  = HumanReadinessCommonFailure HumanCommonFailure
  | HumanReadinessEvidenceInputFailure (NonEmpty HumanInputDefect)
  | HumanReadinessSupplementalFailure (NonEmpty HumanSupplementalInputDefect)
  | HumanReadinessModelRoleFailure HumanSourceIdentity
  | HumanReadinessEvidenceRoleFailure HumanSourceIdentity
  | HumanReadinessSupplementalRoleFailure HumanSourceIdentity
  | HumanReadinessAdapterFailure HumanAdapterDescriptor
  | HumanReadinessNotationFailure HumanNotationContractFailure
  | HumanReadinessProfileFailure (NonEmpty HumanProfileContractEvidence)
  | HumanReadinessIdentityFailure (NonEmpty HumanIdentityIndexDefect)
  | HumanReadinessScopeFailure (NonEmpty HumanSelectedViewScopeDefect)
  | HumanReadinessStructureFailure (NonEmpty HumanStructureInputDefect)
  | HumanReadinessProvenanceFailure (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanReadinessSemanticFailure [HumanOccurrenceIdentity]

-- | Consume every Readiness failure branch.
foldHumanReadinessFailure ::
     (HumanCommonFailure -> result)
  -> (NonEmpty HumanInputDefect -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> ([HumanOccurrenceIdentity] -> result)
  -> HumanReadinessFailure
  -> result
foldHumanReadinessFailure common evidence supplemental model evidenceRole supplementalRole adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    HumanReadinessCommonFailure value -> common value
    HumanReadinessEvidenceInputFailure value -> evidence value
    HumanReadinessSupplementalFailure value -> supplemental value
    HumanReadinessModelRoleFailure value -> model value
    HumanReadinessEvidenceRoleFailure value -> evidenceRole value
    HumanReadinessSupplementalRoleFailure value -> supplementalRole value
    HumanReadinessAdapterFailure value -> adapter value
    HumanReadinessNotationFailure value -> notation value
    HumanReadinessProfileFailure value -> profile value
    HumanReadinessIdentityFailure value -> identity value
    HumanReadinessScopeFailure value -> scope value
    HumanReadinessStructureFailure value -> structure value
    HumanReadinessProvenanceFailure value -> provenance value
    HumanReadinessSemanticFailure value -> semantic value

-- | Failure projection used by Assess reports.
data HumanAssessFailure
  = HumanAssessCommonFailure HumanCommonFailure
  | HumanAssessInputFailure (NonEmpty HumanInputDefect)
  | HumanAssessSupplementalFailure (NonEmpty HumanSupplementalInputDefect)
  | HumanAssessModelRoleFailure HumanSourceIdentity
  | HumanAssessBundleRoleFailure HumanSourceIdentity
  | HumanAssessSupplementalRoleFailure HumanSourceIdentity
  | HumanAssessAdapterFailure HumanAdapterDescriptor
  | HumanAssessNotationFailure HumanNotationContractFailure
  | HumanAssessProfileFailure (NonEmpty HumanProfileContractEvidence)
  | HumanAssessIdentityFailure (NonEmpty HumanIdentityIndexDefect)
  | HumanAssessScopeFailure (NonEmpty HumanSelectedViewScopeDefect)
  | HumanAssessStructureFailure (NonEmpty HumanStructureInputDefect)
  | HumanAssessProvenanceFailure (NonEmpty HumanSupplementalProvenanceDefect)
  | HumanAssessSemanticFailure [HumanOccurrenceIdentity]

-- | Consume every Assess failure branch.
foldHumanAssessFailure ::
     (HumanCommonFailure -> result)
  -> (NonEmpty HumanInputDefect -> result)
  -> (NonEmpty HumanSupplementalInputDefect -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanSourceIdentity -> result)
  -> (HumanAdapterDescriptor -> result)
  -> (HumanNotationContractFailure -> result)
  -> (NonEmpty HumanProfileContractEvidence -> result)
  -> (NonEmpty HumanIdentityIndexDefect -> result)
  -> (NonEmpty HumanSelectedViewScopeDefect -> result)
  -> (NonEmpty HumanStructureInputDefect -> result)
  -> (NonEmpty HumanSupplementalProvenanceDefect -> result)
  -> ([HumanOccurrenceIdentity] -> result)
  -> HumanAssessFailure
  -> result
foldHumanAssessFailure common assessment supplemental model bundle supplementalRole adapter notation profile identity scope structure provenance semantic failure =
  case failure of
    HumanAssessCommonFailure value -> common value
    HumanAssessInputFailure value -> assessment value
    HumanAssessSupplementalFailure value -> supplemental value
    HumanAssessModelRoleFailure value -> model value
    HumanAssessBundleRoleFailure value -> bundle value
    HumanAssessSupplementalRoleFailure value -> supplementalRole value
    HumanAssessAdapterFailure value -> adapter value
    HumanAssessNotationFailure value -> notation value
    HumanAssessProfileFailure value -> profile value
    HumanAssessIdentityFailure value -> identity value
    HumanAssessScopeFailure value -> scope value
    HumanAssessStructureFailure value -> structure value
    HumanAssessProvenanceFailure value -> provenance value
    HumanAssessSemanticFailure value -> semantic value

projectQualificationSubjectsFailure ::
     QualificationSubjectsFailure -> HumanQualificationSubjectsFailure
projectQualificationSubjectsFailure =
  foldQualificationSubjectsFailure
    (HumanQualificationSubjectsCommonFailure . projectCommonFailure)
    (HumanQualificationSubjectsSupplementalFailure
       . fmap projectSupplementalInputDefect)
    projectQualificationSubjectsOwnerFailure

projectValidateFailure :: ValidateFailure -> HumanValidateFailure
projectValidateFailure =
  foldValidateFailure
    (HumanValidateCommonFailure . projectCommonFailure)
    (HumanValidateSupplementalFailure . fmap projectSupplementalInputDefect)
    projectValidateOwnerFailure

projectTraceFailure :: TraceFailure -> HumanTraceFailure
projectTraceFailure =
  foldTraceFailure
    (HumanTraceCommonFailure . projectCommonFailure)
    projectTraceOwnerFailure

projectQualifyFailure :: QualifyFailure -> HumanQualifyFailure
projectQualifyFailure =
  foldQualifyFailure
    (HumanQualifyCommonFailure . projectCommonFailure)
    (HumanQualifySupplementalFailure . fmap projectSupplementalInputDefect)
    projectQualifyOwnerFailure

projectReadinessFailure :: ReadinessFailure -> HumanReadinessFailure
projectReadinessFailure =
  foldReadinessFailure
    (HumanReadinessCommonFailure . projectCommonFailure)
    (HumanReadinessEvidenceInputFailure . fmap projectReadinessInputDefect)
    (HumanReadinessSupplementalFailure . fmap projectSupplementalInputDefect)
    projectReadinessOwnerFailure

projectAssessFailure :: AssessFailure -> HumanAssessFailure
projectAssessFailure =
  foldAssessFailure
    (HumanAssessCommonFailure . projectCommonFailure)
    (HumanAssessInputFailure . fmap projectAssessmentInputDefect)
    (HumanAssessSupplementalFailure . fmap projectSupplementalInputDefect)
    projectAssessOwnerFailure

projectReadinessInputDefect :: Readiness.EvidenceInputDefect -> HumanInputDefect
projectReadinessInputDefect defect =
  projectInputDefect
    (coreRuleIdText (Readiness.evidenceInputDefectRule defect))
    (Readiness.readinessInputOrdinalValue
       (Readiness.evidenceInputDefectOrdinal defect))
    (Readiness.evidenceInputDefectKind defect)
    (Readiness.evidenceInputDefectPointer defect)
    (Readiness.evidenceInputDefectSubjects defect)

projectAssessmentInputDefect ::
     Assessment.AssessmentInputDefect -> HumanInputDefect
projectAssessmentInputDefect defect =
  projectInputDefect
    (coreRuleIdText (Assessment.assessmentInputDefectRule defect))
    (Assessment.assessmentInputOrdinalValue
       (Assessment.assessmentInputDefectOrdinal defect))
    (Assessment.assessmentInputDefectKind defect)
    (Assessment.assessmentInputDefectPointer defect)
    (Assessment.assessmentInputDefectSubjects defect)

projectInputDefect ::
     Text
  -> Natural
  -> Readiness.EvidenceInputDefectKind
  -> Text
  -> NonEmpty Readiness.EvidenceInputDiagnosticSubject
  -> HumanInputDefect
projectInputDefect rule ordinal kind pointer subjects =
  HumanInputDefect
    rule
    ordinal
    (projectInputDefectKind kind)
    pointer
    (fmap projectInputSubject subjects)

projectInputSubject ::
     Readiness.EvidenceInputDiagnosticSubject -> HumanInputDefectSubject
projectInputSubject =
  Readiness.foldEvidenceInputDiagnosticSubject
    HumanInputTextSubject
    HumanInputNaturalSubject
    (\label value -> HumanInputModelSubject label (projectModelIdentity value))
    (\label value ->
       HumanInputOccurrenceSubject label (projectOccurrenceIdentity value))
    (\label value ->
       HumanInputQualifiedTypeSubject label (projectQualifiedType value))

projectInputDefectKind ::
     Readiness.EvidenceInputDefectKind -> HumanInputDefectKind
projectInputDefectKind kind =
  case kind of
    Readiness.EvidenceInputInvalidUtf8 -> HumanInputInvalidUtf8
    Readiness.EvidenceInputInvalidJsonSyntax -> HumanInputInvalidJsonSyntax
    Readiness.EvidenceInputDuplicateObjectMember ->
      HumanInputDuplicateObjectMember
    Readiness.EvidenceInputTopLevelObjectRequired ->
      HumanInputTopLevelObjectRequired
    Readiness.EvidenceInputDiscriminatorInvalid ->
      HumanInputDiscriminatorInvalid
    Readiness.EvidenceInputRequiredMemberMissing ->
      HumanInputRequiredMemberMissing
    Readiness.EvidenceInputUnknownMember -> HumanInputUnknownMember
    Readiness.EvidenceInputValueKindInvalid -> HumanInputValueKindInvalid
    Readiness.EvidenceInputScalarGrammarInvalid ->
      HumanInputScalarGrammarInvalid
    Readiness.EvidenceInputArrayCardinalityInvalid ->
      HumanInputArrayCardinalityInvalid
    Readiness.EvidenceInputArrayDistinctnessInvalid ->
      HumanInputArrayDistinctnessInvalid
    Readiness.EvidenceInputNormalizationCollision ->
      HumanInputNormalizationCollision
    Readiness.EvidenceInputModelIdentityUnicodeScalarInvalid ->
      HumanInputModelIdentityUnicodeScalarInvalid
    Readiness.EvidenceInputModelIdentityContainsNul ->
      HumanInputModelIdentityContainsNul
    Readiness.EvidenceInputIdentityUnknown -> HumanInputIdentityUnknown
    Readiness.EvidenceInputIdentityAmbiguous -> HumanInputIdentityAmbiguous
    Readiness.EvidenceInputIdentityOutOfSelectedView ->
      HumanInputIdentityOutOfSelectedView
    Readiness.EvidenceInputIdentityWrongType -> HumanInputIdentityWrongType

projectSupplementalInputDefect ::
     Supplemental.SupplementalInputDefect -> HumanSupplementalInputDefect
projectSupplementalInputDefect defect =
  Supplemental.foldSupplementalInputDefect eliminator defect
  where
    rule = coreRuleIdText (Supplemental.supplementalInputDefectRule defect)
    ordinal = Supplemental.supplementalInputOrdinalValue
    schema constructor input pointer expected =
      constructor rule (ordinal input) pointer expected
    identity constructor input pointer model =
      constructor rule (ordinal input) pointer (projectModelIdentity model)
    eliminator =
      Supplemental.SupplementalInputDefectEliminator
        { Supplemental.eliminateSupplementalInvalidUtf8 =
            \value ->
              HumanSupplementalInvalidUtf8
                rule
                (ordinal
                   (Supplemental.supplementalInvalidUtf8InputOrdinal value))
        , Supplemental.eliminateSupplementalInvalidJsonSyntax =
            \value ->
              HumanSupplementalInvalidJsonSyntax
                rule
                (ordinal
                   (Supplemental.supplementalInvalidJsonSyntaxInputOrdinal value))
        , Supplemental.eliminateSupplementalDuplicateObjectMember =
            \value ->
              HumanSupplementalDuplicateObjectMember
                rule
                (ordinal
                   (Supplemental.supplementalDuplicateObjectMemberInputOrdinal
                      value))
                (Supplemental.supplementalDuplicateObjectMemberPointer value)
        , Supplemental.eliminateSupplementalTopLevelObjectRequired =
            \value ->
              schema
                HumanSupplementalTopLevelObjectRequired
                (Supplemental.supplementalTopLevelObjectInputOrdinal value)
                (Supplemental.supplementalTopLevelObjectInstancePointer value)
                (Supplemental.supplementalTopLevelObjectExpectedSchema value)
        , Supplemental.eliminateSupplementalTypeMemberInvalid =
            \value ->
              schema
                HumanSupplementalTypeMemberInvalid
                (Supplemental.supplementalTypeMemberInputOrdinal value)
                (Supplemental.supplementalTypeMemberInstancePointer value)
                (Supplemental.supplementalTypeMemberExpectedSchema value)
        , Supplemental.eliminateSupplementalPayloadTypeNotAdmitted =
            \value ->
              schema
                HumanSupplementalPayloadTypeNotAdmitted
                (Supplemental.supplementalPayloadTypeNotAdmittedInputOrdinal
                   value)
                (Supplemental.supplementalPayloadTypeNotAdmittedInstancePointer
                   value)
                (Supplemental.supplementalPayloadTypeNotAdmittedExpectedSchema
                   value)
        , Supplemental.eliminateSupplementalRequiredMemberMissing =
            \value ->
              schema
                HumanSupplementalRequiredMemberMissing
                (Supplemental.supplementalRequiredMemberMissingInputOrdinal
                   value)
                (Supplemental.supplementalRequiredMemberMissingInstancePointer
                   value)
                (Supplemental.supplementalRequiredMemberMissingExpectedSchema
                   value)
        , Supplemental.eliminateSupplementalUnknownMember =
            \value ->
              schema
                HumanSupplementalUnknownMember
                (Supplemental.supplementalUnknownMemberInputOrdinal value)
                (Supplemental.supplementalUnknownMemberInstancePointer value)
                (Supplemental.supplementalUnknownMemberExpectedSchema value)
        , Supplemental.eliminateSupplementalValueKindInvalid =
            \value ->
              schema
                HumanSupplementalValueKindInvalid
                (Supplemental.supplementalValueKindInputOrdinal value)
                (Supplemental.supplementalValueKindInstancePointer value)
                (Supplemental.supplementalValueKindExpectedSchema value)
        , Supplemental.eliminateSupplementalScalarGrammarInvalid =
            \value ->
              schema
                HumanSupplementalScalarGrammarInvalid
                (Supplemental.supplementalScalarGrammarInputOrdinal value)
                (Supplemental.supplementalScalarGrammarInstancePointer value)
                (Supplemental.supplementalScalarGrammarExpectedSchema value)
        , Supplemental.eliminateSupplementalArrayCardinalityInvalid =
            \value ->
              schema
                HumanSupplementalArrayCardinalityInvalid
                (Supplemental.supplementalArrayCardinalityInputOrdinal value)
                (Supplemental.supplementalArrayCardinalityInstancePointer value)
                (Supplemental.supplementalArrayCardinalityExpectedSchema value)
        , Supplemental.eliminateSupplementalArrayDistinctnessInvalid =
            \value ->
              schema
                HumanSupplementalArrayDistinctnessInvalid
                (Supplemental.supplementalArrayDistinctnessInputOrdinal value)
                (Supplemental.supplementalArrayDistinctnessInstancePointer value)
                (Supplemental.supplementalArrayDistinctnessExpectedSchema value)
        , Supplemental.eliminateSupplementalSubjectCardinalityInvalid =
            \value ->
              HumanSupplementalSubjectCardinalityInvalid
                rule
                (fmap
                   ordinal
                   (Supplemental.supplementalSubjectCardinalityFirstInputOrdinal
                      value
                      :| NonEmpty.toList
                           (Supplemental.supplementalSubjectCardinalityRemainingInputOrdinals
                              value)))
                (projectSupplementalPayloadType
                   (Supplemental.supplementalSubjectCardinalityPayloadType value))
                (projectModelIdentity
                   (Supplemental.supplementalSubjectCardinalitySubject value))
        , Supplemental.eliminateSupplementalIdentityUnknown =
            \value ->
              identity
                HumanSupplementalIdentityUnknown
                (Supplemental.supplementalIdentityUnknownInputOrdinal value)
                (Supplemental.supplementalIdentityUnknownInstancePointer value)
                (Supplemental.supplementalIdentityUnknownModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityAmbiguous =
            \value ->
              identity
                HumanSupplementalIdentityAmbiguous
                (Supplemental.supplementalIdentityAmbiguousInputOrdinal value)
                (Supplemental.supplementalIdentityAmbiguousInstancePointer value)
                (Supplemental.supplementalIdentityAmbiguousModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityWrongType =
            \value ->
              identity
                HumanSupplementalIdentityWrongType
                (Supplemental.supplementalIdentityWrongTypeInputOrdinal value)
                (Supplemental.supplementalIdentityWrongTypeInstancePointer value)
                (Supplemental.supplementalIdentityWrongTypeModelIdentity value)
        , Supplemental.eliminateSupplementalIdentityOutOfSelectedView =
            \value ->
              identity
                HumanSupplementalIdentityOutOfSelectedView
                (Supplemental.supplementalIdentityOutOfViewInputOrdinal value)
                (Supplemental.supplementalIdentityOutOfViewInstancePointer value)
                (Supplemental.supplementalIdentityOutOfViewModelIdentity value)
        , Supplemental.eliminateSupplementalModelIdentityUnicodeScalarInvalid =
            \value ->
              HumanSupplementalModelIdentityUnicodeScalarInvalid
                rule
                (ordinal
                   (Supplemental.supplementalUnicodeScalarInputOrdinal value))
                (Supplemental.supplementalUnicodeScalarInstancePointer value)
                (Supplemental.supplementalUnicodeScalarExpectedSchema value)
                (fmap
                   (\occurrence ->
                      ( Supplemental.supplementalUnicodeScalarIndex occurrence
                      , Supplemental.supplementalUnicodeScalarCodePoint
                          occurrence))
                   (Supplemental.supplementalUnicodeScalarOccurrences value))
        , Supplemental.eliminateSupplementalModelIdentityContainsNul =
            \value ->
              HumanSupplementalModelIdentityContainsNul
                rule
                (ordinal
                   (Supplemental.supplementalModelIdentityNulInputOrdinal value))
                (Supplemental.supplementalModelIdentityNulInstancePointer value)
                (Supplemental.supplementalModelIdentityNulExpectedSchema value)
                (Supplemental.supplementalModelIdentityNulIndexes value)
        }

projectSupplementalPayloadType ::
     Supplemental.SupplementalPayloadType -> HumanSupplementalPayloadType
projectSupplementalPayloadType payload =
  case payload of
    Supplemental.StrategyFormulationPayload -> HumanStrategyFormulationPayload
    Supplemental.CollectiveFitPayload -> HumanCollectiveFitPayload

projectNotationFailure ::
     AdapterNotationResolutionFailure -> HumanNotationContractFailure
projectNotationFailure =
  foldAdapterNotationResolutionFailure
    (\authority contract ->
       HumanNotationAuthorityMismatch
         (projectAdapterDescriptor authority)
         (projectAdapterDescriptor contract))
    (\descriptor kind ->
       HumanNotationRuleMissing
         (projectAdapterDescriptor descriptor)
         (Notation.archiMateNotationIssueKindToken kind))

projectProfileEvidence ::
     Profile.ProfileContractEvidence profile document
  -> HumanProfileContractEvidence
projectProfileEvidence =
  Profile.foldProfileContractEvidence
    (\rule kind ->
       HumanUnknownGeneratedProfileRule rule (profileEvidenceKindText kind))
    (\rule kind ->
       HumanGeneratedProfileEvidenceMismatch rule (profileEvidenceKindText kind))
    (\binding occurrence ->
       HumanMissingCoreContractBinding
         binding
         (projectCanonicalOccurrence occurrence))
    (\occurrence details ->
       HumanImpossibleOccurrenceIdentity
         (projectCanonicalOccurrence occurrence)
         details)

profileEvidenceKindText :: Profile.ProfileEvidenceKind -> Text
profileEvidenceKindText =
  Profile.foldProfileEvidenceKind
    "carrier-occurrence"
    "classification-occurrence"
    "metadata-owner-and-o2i-property-occurrences"
    "property-occurrence-evidence"
    "property-slot-evidence"
    "property-value-evidence"
    "proposal-carrier-occurrence"
    "proposal-reference-incidence"
    "relationship-occurrence"
    "reserved-property-occurrence"
    "structured-carrier-occurrence"
    "structured-incidence"

projectIdentityDefect :: IdentityIndexDefect -> HumanIdentityIndexDefect
projectIdentityDefect defect =
  HumanIdentityIndexDefect
    (projectOccurrenceIdentity (identityIndexDefectOccurrence defect))
    (fmap projectModelIdentity (identityIndexDefectModelIdentities defect))

projectScopeDefect :: SelectedViewScopeDefect -> HumanSelectedViewScopeDefect
projectScopeDefect defect =
  HumanSelectedViewScopeDefect
    (case selectedViewScopeDefectKind defect of
       UnknownSelectedViewSubjectOccurrence ->
         HumanUnknownSelectedViewSubjectOccurrence
       SelectedViewSubjectIdentityMismatch ->
         HumanSelectedViewSubjectIdentityMismatch
       UnknownSelectedViewOccurrence -> HumanUnknownSelectedViewOccurrence
       DuplicateSelectedViewOccurrence -> HumanDuplicateSelectedViewOccurrence)
    (projectOccurrenceIdentity (selectedViewScopeDefectOccurrence defect))
    (fromIntegral (selectedViewScopeDefectCardinality defect))

projectStructureDefect ::
     Structure.StructureInputDefect -> HumanStructureInputDefect
projectStructureDefect defect =
  case defect of
    Structure.ProjectionOutsideSelectedView occurrence ->
      HumanProjectionOutsideSelectedView (projectOccurrenceIdentity occurrence)
    Structure.DuplicateStructureProjection occurrence kinds ->
      HumanDuplicateStructureProjection
        (projectOccurrenceIdentity occurrence)
        (fmap structureProjectionKindText kinds)
    Structure.MissingCarrierProjection owner role endpoint ->
      HumanMissingCarrierProjection
        (projectOccurrenceIdentity owner)
        (structureEndpointRoleText role)
        (projectOccurrenceIdentity endpoint)
    Structure.MissingStructuredPropositionProjection proposition occurrence ->
      HumanMissingStructuredPropositionProjection
        (projectOccurrenceIdentity proposition)
        (projectOccurrenceIdentity occurrence)

structureProjectionKindText :: Structure.StructureProjectionKind -> Text
structureProjectionKindText kind =
  case kind of
    Structure.CarrierProjectionKind -> "carrier"
    Structure.ContextualizationProjectionKind -> "contextualization"
    Structure.RelationProjectionKind -> "relation"
    Structure.StructuredPropositionProjectionKind -> "structured-proposition"
    Structure.StructuredIncidenceProjectionKind -> "structured-incidence"

structureEndpointRoleText :: Structure.StructureEndpointRole -> Text
structureEndpointRoleText role =
  case role of
    Structure.RelationSourceRole -> "relation-source"
    Structure.RelationTargetRole -> "relation-target"
    Structure.ContextualizationOwnerRole -> "contextualization-owner"
    Structure.ContextualizationMemberRole -> "contextualization-member"
    Structure.StructuredIncidenceEndpointRole -> "structured-incidence-endpoint"

projectProvenanceDefect ::
     SupplementalProvenanceDefect -> HumanSupplementalProvenanceDefect
projectProvenanceDefect =
  foldSupplementalProvenanceDefect
    (HumanModelSourceIsNotSupplemental . projectSourceIdentity)
    (\key sources ->
       foldSourceKey
         (\role ordinal ->
            HumanDuplicateSupplementalSource
              (showSourceRole role)
              (sourceOrdinalValue ordinal)
              (fmap projectSourceIdentity sources))
         key)

showSourceRole :: SourceRole -> Text
showSourceRole role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

projectOccurrenceDefect :: OccurrenceIdentityDefect -> Text
projectOccurrenceDefect defect =
  case defect of
    EmptyOccurrenceIdentity -> "empty"
    OccurrenceIdentityContainsU0000 -> "contains-u0000"
    OccurrenceIdentityContainsSurrogate -> "contains-surrogate"

projectQualificationSubjectsOwnerFailure ::
     QualificationSubjectsInternalFailure -> HumanQualificationSubjectsFailure
projectQualificationSubjectsOwnerFailure =
  foldQualificationSubjectsInternalFailure
    (HumanQualificationSubjectsModelRoleFailure . projectSourceIdentity)
    (HumanQualificationSubjectsSupplementalRoleFailure . projectSourceIdentity)
    (HumanQualificationSubjectsAdapterFailure . projectAdapterDescriptor)
    (HumanQualificationSubjectsNotationFailure . projectNotationFailure)
    (HumanQualificationSubjectsProfileFailure . fmap projectProfileEvidence)
    (HumanQualificationSubjectsIdentityFailure . fmap projectIdentityDefect)
    (HumanQualificationSubjectsScopeFailure . fmap projectScopeDefect)
    (HumanQualificationSubjectsStructureFailure . fmap projectStructureDefect)
    (HumanQualificationSubjectsProvenanceFailure . fmap projectProvenanceDefect)
    (\context ->
       case context of
         Qualification.QualificationSemanticGraphMismatch ->
           HumanQualificationSubjectsContextFailure)
    (\occurrence defect ->
       HumanQualificationSubjectsProjectionFailure
         (projectCanonicalOccurrence occurrence)
         (projectOccurrenceDefect defect))
    (\identity occurrences ->
       HumanQualificationSubjectsJoinFailure
         (projectOccurrenceIdentity identity)
         (map projectCanonicalOccurrence occurrences))

projectValidateOwnerFailure :: ValidateInternalFailure -> HumanValidateFailure
projectValidateOwnerFailure =
  foldValidateInternalFailure
    (HumanValidateModelRoleFailure . projectSourceIdentity)
    (HumanValidateSupplementalRoleFailure . projectSourceIdentity)
    (HumanValidateAdapterFailure . projectAdapterDescriptor)
    (HumanValidateNotationFailure . projectNotationFailure)
    (HumanValidateProfileFailure . fmap projectProfileEvidence)
    (HumanValidateIdentityFailure . fmap projectIdentityDefect)
    (HumanValidateScopeFailure . fmap projectScopeDefect)
    (HumanValidateStructureFailure . fmap projectStructureDefect)
    (HumanValidateProvenanceFailure . fmap projectProvenanceDefect)
    (HumanValidateSemanticFailure . map projectOccurrenceIdentity)

projectTraceOwnerFailure :: TraceInternalFailure -> HumanTraceFailure
projectTraceOwnerFailure =
  foldTraceInternalFailure
    (HumanTraceModelRoleFailure . projectSourceIdentity)
    (HumanTraceAdapterFailure . projectAdapterDescriptor)
    (HumanTraceNotationFailure . projectNotationFailure)
    (HumanTraceProfileFailure . fmap projectProfileEvidence)
    (HumanTraceIdentityFailure . fmap projectIdentityDefect)
    (HumanTraceScopeFailure . fmap projectScopeDefect)
    (HumanTraceStructureFailure . fmap projectStructureDefect)
    (HumanTraceProvenanceFailure . fmap projectProvenanceDefect)
    (HumanTraceSupplementalInputFailure . fmap projectSupplementalInputDefect)
    (HumanTraceSemanticFailure . map projectOccurrenceIdentity)

projectQualifyOwnerFailure :: QualifyInternalFailure -> HumanQualifyFailure
projectQualifyOwnerFailure =
  foldQualifyInternalFailure
    (HumanQualifyModelRoleFailure . projectSourceIdentity)
    (HumanQualifySupplementalRoleFailure . projectSourceIdentity)
    (HumanQualifyAdapterFailure . projectAdapterDescriptor)
    (HumanQualifyNotationFailure . projectNotationFailure)
    (HumanQualifyProfileFailure . fmap projectProfileEvidence)
    (HumanQualifyIdentityFailure . fmap projectIdentityDefect)
    (HumanQualifyScopeFailure . fmap projectScopeDefect)
    (HumanQualifyStructureFailure . fmap projectStructureDefect)
    (HumanQualifyProvenanceFailure . fmap projectProvenanceDefect)
    (\context ->
       case context of
         Qualification.QualificationSemanticGraphMismatch ->
           HumanQualifyContextFailure)

projectReadinessOwnerFailure ::
     ReadinessInternalFailure -> HumanReadinessFailure
projectReadinessOwnerFailure =
  foldReadinessInternalFailure
    (HumanReadinessModelRoleFailure . projectSourceIdentity)
    (HumanReadinessEvidenceRoleFailure . projectSourceIdentity)
    (HumanReadinessSupplementalRoleFailure . projectSourceIdentity)
    (HumanReadinessAdapterFailure . projectAdapterDescriptor)
    (HumanReadinessNotationFailure . projectNotationFailure)
    (HumanReadinessProfileFailure . fmap projectProfileEvidence)
    (HumanReadinessIdentityFailure . fmap projectIdentityDefect)
    (HumanReadinessScopeFailure . fmap projectScopeDefect)
    (HumanReadinessStructureFailure . fmap projectStructureDefect)
    (HumanReadinessProvenanceFailure . fmap projectProvenanceDefect)
    (HumanReadinessSemanticFailure . map projectOccurrenceIdentity)

projectAssessOwnerFailure :: AssessInternalFailure -> HumanAssessFailure
projectAssessOwnerFailure =
  foldAssessInternalFailure
    (HumanAssessModelRoleFailure . projectSourceIdentity)
    (HumanAssessBundleRoleFailure . projectSourceIdentity)
    (HumanAssessSupplementalRoleFailure . projectSourceIdentity)
    (HumanAssessAdapterFailure . projectAdapterDescriptor)
    (HumanAssessNotationFailure . projectNotationFailure)
    (HumanAssessProfileFailure . fmap projectProfileEvidence)
    (HumanAssessIdentityFailure . fmap projectIdentityDefect)
    (HumanAssessScopeFailure . fmap projectScopeDefect)
    (HumanAssessStructureFailure . fmap projectStructureDefect)
    (HumanAssessProvenanceFailure . fmap projectProvenanceDefect)
    (HumanAssessSemanticFailure . map projectOccurrenceIdentity)
