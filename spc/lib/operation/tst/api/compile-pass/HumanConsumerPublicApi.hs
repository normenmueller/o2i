-- | Package-external proof that every opaque human projection has a total
-- public consumer. The proof deliberately imports no internal module.
module HumanConsumerPublicApi where

import qualified O2I.Operation.Assess.Human as Assess
import qualified O2I.Operation.Assess.Result as AssessResult
import qualified O2I.Operation.Discovery.View as ViewResult
import qualified O2I.Operation.Discovery.View.Human as Views
import qualified O2I.Operation.Human.Diagnostic as Diagnostic
import qualified O2I.Operation.Human.Value as Value
import O2I.Operation.Machine (ToolDescriptor)
import qualified O2I.Operation.Qualification.Subjects.Human as Subjects
import qualified O2I.Operation.Qualification.Subjects.Result as SubjectsResult
import qualified O2I.Operation.Qualify.Human as Qualify
import qualified O2I.Operation.Qualify.Result as QualifyResult
import qualified O2I.Operation.Readiness.Human as Readiness
import qualified O2I.Operation.Readiness.Result as ReadinessResult
import qualified O2I.Operation.Trace.Human as Trace
import qualified O2I.Operation.Trace.Result as TraceResult
import qualified O2I.Operation.Validate.Human as Validate
import qualified O2I.Operation.Validate.Result as ValidateResult

projectViewDiscovery ::
     ToolDescriptor -> ViewResult.ViewDiscovery -> Views.HumanViewDiscovery
projectViewDiscovery = Views.viewHumanDiscovery

projectQualificationSubjects ::
     ToolDescriptor
  -> SubjectsResult.QualificationSubjectsResult
  -> Subjects.HumanQualificationSubjectsReport
projectQualificationSubjects = Subjects.qualificationSubjectsHumanReport

projectValidate ::
     ToolDescriptor
  -> ValidateResult.ValidateResult
  -> Validate.HumanValidateReport
projectValidate = Validate.validateHumanReport

projectTrace ::
     ToolDescriptor -> TraceResult.TraceResult -> Trace.HumanTraceReport
projectTrace = Trace.traceHumanReport

projectQualify ::
     ToolDescriptor -> QualifyResult.QualifyResult -> Qualify.HumanQualifyReport
projectQualify = Qualify.qualifyHumanReport

projectReadiness ::
     ToolDescriptor
  -> ReadinessResult.ReadinessResult
  -> Readiness.HumanReadinessReport
projectReadiness = Readiness.readinessHumanReport

projectAssess ::
     ToolDescriptor -> AssessResult.AssessResult -> Assess.HumanAssessReport
projectAssess = Assess.assessHumanReport

consumeModelIdentity :: Value.HumanModelIdentity -> ()
consumeModelIdentity = Value.foldHumanModelIdentity (const ())

consumeOccurrenceIdentity :: Value.HumanOccurrenceIdentity -> ()
consumeOccurrenceIdentity = Value.foldHumanOccurrenceIdentity (const ())

consumeQualifiedType :: Value.HumanQualifiedType -> ()
consumeQualifiedType = Value.foldHumanQualifiedType (const ())

consumeSourceRole :: Value.HumanSourceRole -> ()
consumeSourceRole = Value.foldHumanSourceRole () () () ()

consumeSourceIdentity :: Value.HumanSourceIdentity -> ()
consumeSourceIdentity = Value.foldHumanSourceIdentity $ \_ _ _ _ -> ()

consumeInputSource :: Value.HumanInputSource -> ()
consumeInputSource = Value.foldHumanInputSource (\_ _ -> ()) (const ())

consumeViewSelector :: Value.HumanViewSelector -> ()
consumeViewSelector = Value.foldHumanViewSelector (const ()) (const ())

consumeAdapterSelection :: Value.HumanAdapterSelection -> ()
consumeAdapterSelection = Value.foldHumanAdapterSelection () (const ())

consumeAdapterDescriptor :: Value.HumanAdapterDescriptor -> ()
consumeAdapterDescriptor = Value.foldHumanAdapterDescriptor $ \_ _ _ _ -> ()

consumeProfileDescriptor :: Value.HumanProfileDescriptor -> ()
consumeProfileDescriptor = Value.foldHumanProfileDescriptor $ \_ _ _ _ _ _ -> ()

consumeCanonicalOccurrenceKind :: Value.HumanCanonicalOccurrenceKind -> ()
consumeCanonicalOccurrenceKind = Value.foldHumanCanonicalOccurrenceKind () () ()

consumeCanonicalOccurrence :: Value.HumanCanonicalOccurrence -> ()
consumeCanonicalOccurrence = Value.foldHumanCanonicalOccurrence $ \_ _ -> ()

consumeNativeName :: Value.HumanNativeName -> ()
consumeNativeName = Value.foldHumanNativeName $ \_ _ -> ()

consumeSourcePosition :: Value.HumanSourcePosition -> ()
consumeSourcePosition = Value.foldHumanSourcePosition $ \_ _ _ -> ()

consumeSourceSpan :: Value.HumanSourceSpan -> ()
consumeSourceSpan = Value.foldHumanSourceSpan $ \_ _ -> ()

consumeSourcePathStep :: Value.HumanSourcePathStep -> ()
consumeSourcePathStep = Value.foldHumanSourcePathStep $ \_ _ -> ()

consumeSourceLocation :: Value.HumanSourceLocation -> ()
consumeSourceLocation = Value.foldHumanSourceLocation $ \_ _ -> ()

consumeScalarValue :: Value.HumanScalarValue -> ()
consumeScalarValue =
  Value.foldHumanScalarValue
    (const ())
    (const ())
    (const ())
    (const ())
    (\_ _ -> ())

consumeDraftScalar :: Value.HumanDraftScalar -> ()
consumeDraftScalar = Value.foldHumanDraftScalar $ \_ _ -> ()

consumeIdentityInvalidReason :: Value.HumanIdentityInvalidReason -> ()
consumeIdentityInvalidReason =
  Value.foldHumanIdentityInvalidReason (const ()) () () ()

consumeIdentityOutcome :: Value.HumanIdentityOutcome -> ()
consumeIdentityOutcome =
  Value.foldHumanIdentityOutcome () (const ()) (\_ _ -> ()) (\_ _ -> ())

consumeCanonicalField :: Value.HumanCanonicalField -> ()
consumeCanonicalField = Value.foldHumanCanonicalField $ \_ _ _ -> ()

consumeViewDescriptor :: Value.HumanViewDescriptor -> ()
consumeViewDescriptor = Value.foldHumanViewDescriptor $ \_ _ _ _ -> ()

consumeTraceBinding :: Value.HumanTraceBinding -> ()
consumeTraceBinding = Value.foldHumanTraceBinding $ \_ _ -> ()

consumeTraceIdentity :: Value.HumanTraceIdentity -> ()
consumeTraceIdentity = Value.foldHumanTraceIdentity $ \_ _ -> ()

consumeDiagnosticSeverity :: Diagnostic.HumanDiagnosticSeverity -> ()
consumeDiagnosticSeverity = Diagnostic.foldHumanDiagnosticSeverity (const ())

consumeDiagnosticDisposition :: Diagnostic.HumanDiagnosticDisposition -> ()
consumeDiagnosticDisposition =
  Diagnostic.foldHumanDiagnosticDisposition (const ())

consumeSemanticEvidence :: Diagnostic.HumanSemanticDiagnosticEvidence -> ()
consumeSemanticEvidence =
  Diagnostic.foldHumanSemanticDiagnosticEvidence
    Diagnostic.HumanSemanticDiagnosticEliminator
      { Diagnostic.eliminateHumanCollectiveAssertedCollectiveCoverage =
          \claim values ->
            consume [consumeModelIdentity claim, occurrences values]
      , Diagnostic.eliminateHumanCollectiveAssertedCompleteness = field
      , Diagnostic.eliminateHumanCollectiveAssertedMacroSupport =
          \claim participant first second third ->
            consume
              [ consumeModelIdentity claim
              , consumeModelIdentity participant
              , occurrences [first, second, third]
              ]
      , Diagnostic.eliminateHumanCollectiveAssertedParticipantPrimitiveSupport =
          \claim participant first second third ->
            consume
              [ consumeModelIdentity claim
              , consumeModelIdentity participant
              , occurrences [first, second, third]
              ]
      , Diagnostic.eliminateHumanCollectiveFitPairwiseCoherence = field
      , Diagnostic.eliminateHumanCollectiveFitParticipantBinding = field
      , Diagnostic.eliminateHumanCollectiveFitParticipantCompatibility = field
      , Diagnostic.eliminateHumanCollectiveFitTargetBinding = field
      , Diagnostic.eliminateHumanCollectiveFitTargetGuidingPolicy = field
      , Diagnostic.eliminateHumanCollectiveFitTargetTradeOffs = field
      , Diagnostic.eliminateHumanContextualizationAssertedDependency =
          \dependent endpoint context first second third ->
            occurrences [dependent, endpoint, context, first, second, third]
      , Diagnostic.eliminateHumanSituatedNeedDriverAnchoring = member
      , Diagnostic.eliminateHumanSituatedNeedDriverCardinality =
          consumeModelIdentity
      , Diagnostic.eliminateHumanSituatedNeedObjectiveCardinality =
          consumeModelIdentity
      , Diagnostic.eliminateHumanSituatedNeedObjectiveGrounding = member
      , Diagnostic.eliminateHumanSituatedNeedSurfacingSituationAnchoring =
          member
      , Diagnostic.eliminateHumanSituatedNeedSurfacingSituationCardinality =
          consumeModelIdentity
      , Diagnostic.eliminateHumanStrategyFormulationActionContributions = member
      , Diagnostic.eliminateHumanStrategyFormulationActions =
          \strategy values ->
            consume [consumeModelIdentity strategy, occurrences values]
      , Diagnostic.eliminateHumanStrategyFormulationDiagnosis = fields
      , Diagnostic.eliminateHumanStrategyFormulationDiagnosisGrounding = pair
      , Diagnostic.eliminateHumanStrategyFormulationGuidingPolicy = fields
      , Diagnostic.eliminateHumanStrategyFormulationGuidingPolicyActions =
          memberPair
      , Diagnostic.eliminateHumanStrategyFormulationIntent = fields
      , Diagnostic.eliminateHumanStrategyFormulationKeyResultSubstantiation =
          memberPair
      , Diagnostic.eliminateHumanStrategyFormulationKeyResults =
          \strategy values ->
            consume [consumeModelIdentity strategy, occurrences values]
      , Diagnostic.eliminateHumanStrategyFormulationVisionOrientation =
          consumeModelIdentity
      }
  where
    consume = foldr seq ()
    occurrences values =
      foldr
        (\value result -> consumeOccurrenceIdentity value `seq` result)
        ()
        values
    field identity occurrence =
      consume
        [consumeModelIdentity identity, consumeOccurrenceIdentity occurrence]
    fields identity values =
      consume [consumeModelIdentity identity, occurrences values]
    pair identity first second =
      consume
        [ consumeModelIdentity identity
        , consumeOccurrenceIdentity first
        , consumeOccurrenceIdentity second
        ]
    member owner owned occurrence =
      consume
        [ consumeModelIdentity owner
        , consumeModelIdentity owned
        , consumeOccurrenceIdentity occurrence
        ]
    memberPair owner owned first second =
      consume
        [ consumeModelIdentity owner
        , consumeModelIdentity owned
        , consumeOccurrenceIdentity first
        , consumeOccurrenceIdentity second
        ]

consumeDiagnosticEvidence :: Diagnostic.HumanDiagnosticEvidence -> ()
consumeDiagnosticEvidence =
  Diagnostic.foldHumanDiagnosticEvidence
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    consumeSemanticEvidence
    (\_ _ _ -> ())
    (\_ _ _ -> ())
    (\_ _ _ -> ())
    (\_ _ _ -> ())

consumeDiagnostic :: Diagnostic.HumanDiagnostic -> ()
consumeDiagnostic = Diagnostic.foldHumanDiagnostic $ \_ _ _ _ _ _ _ _ -> ()

consumeNotationRuleBinding :: Diagnostic.HumanNotationRuleBinding -> ()
consumeNotationRuleBinding =
  Diagnostic.foldHumanNotationRuleBinding $ \_ _ -> ()

consumeDiagnosticAuthority :: Diagnostic.HumanDiagnosticAuthority -> ()
consumeDiagnosticAuthority =
  Diagnostic.foldHumanDiagnosticAuthority $ \_ _ _ _ -> ()

consumeSupplementalDiagnosticGroup ::
     Diagnostic.HumanSupplementalDiagnosticGroup -> ()
consumeSupplementalDiagnosticGroup =
  Diagnostic.foldHumanSupplementalDiagnosticGroup $ \_ _ -> ()

consumeDiagnosticDocument :: Diagnostic.HumanDiagnosticDocument -> ()
consumeDiagnosticDocument =
  Diagnostic.foldHumanDiagnosticDocument $ \_ _ _ -> ()

consumeViewDiscovery :: Views.HumanViewDiscovery -> ()
consumeViewDiscovery = Views.foldHumanViewDiscovery (const ()) $ \_ _ _ _ -> ()

consumeQualificationSubject :: Subjects.HumanQualificationSubject -> ()
consumeQualificationSubject =
  Subjects.foldHumanQualificationSubject $ \_ _ _ _ _ _ -> ()

consumeQualificationSubjectsRequest ::
     Subjects.HumanQualificationSubjectsRequest -> ()
consumeQualificationSubjectsRequest =
  Subjects.foldHumanQualificationSubjectsRequest $ \_ _ _ _ -> ()

consumeQualificationSubjectsContext ::
     Subjects.HumanQualificationSubjectsContext -> ()
consumeQualificationSubjectsContext =
  Subjects.foldHumanQualificationSubjectsContext $ \_ _ _ _ _ _ -> ()

consumeQualificationSubjectsReport ::
     Subjects.HumanQualificationSubjectsReport -> ()
consumeQualificationSubjectsReport =
  Subjects.foldHumanQualificationSubjectsReport
    (const ())
    (\_ _ -> ())
    (\_ _ _ -> ())

consumeValidateRequest :: Validate.HumanValidateRequest -> ()
consumeValidateRequest = Validate.foldHumanValidateRequest $ \_ _ _ _ _ -> ()

consumeValidateContext :: Validate.HumanValidateContext -> ()
consumeValidateContext =
  Validate.foldHumanValidateContext $ \_ _ _ _ _ _ _ -> ()

consumeValidateUnavailability :: Validate.HumanValidateUnavailability -> ()
consumeValidateUnavailability =
  Validate.foldHumanValidateUnavailability
    (const ())
    (\_ _ -> ())
    (\_ _ _ -> ())
    (\_ _ -> ())
    (\_ _ _ _ -> ())

consumeValidateReport :: Validate.HumanValidateReport -> ()
consumeValidateReport =
  Validate.foldHumanValidateReport (const ()) (const ()) (const ()) (\_ _ -> ())

consumeTraceRequest :: Trace.HumanTraceRequest -> ()
consumeTraceRequest = Trace.foldHumanTraceRequest $ \_ _ _ -> ()

consumeTraceContext :: Trace.HumanTraceContext -> ()
consumeTraceContext = Trace.foldHumanTraceContext $ \_ _ _ _ _ -> ()

consumeTraceSlot :: Trace.HumanTraceSlot -> ()
consumeTraceSlot = Trace.foldHumanTraceSlot $ \_ _ _ -> ()

consumeTraceSupport :: Trace.HumanTraceSupport -> ()
consumeTraceSupport = Trace.foldHumanTraceSupport $ \_ _ -> ()

consumeTraceProjection :: Trace.HumanTraceProjection -> ()
consumeTraceProjection = Trace.foldHumanTraceProjection $ \_ _ -> ()

consumeTraceGap :: Trace.HumanTraceGap -> ()
consumeTraceGap =
  Trace.foldHumanTraceGap (\_ _ _ _ -> ()) (\_ _ _ _ -> ()) (\_ _ -> ())

consumeRootTraceResult :: Trace.HumanRootTraceResult -> ()
consumeRootTraceResult =
  Trace.foldHumanRootTraceResult (\_ _ _ -> ()) (\_ _ _ _ -> ())

consumeRootTrace :: Trace.HumanRootTrace -> ()
consumeRootTrace = Trace.foldHumanRootTrace $ \_ _ _ _ _ -> ()

consumeTraceAssessment :: Trace.HumanTraceAssessment -> ()
consumeTraceAssessment = Trace.foldHumanTraceAssessment $ \_ _ -> ()

consumeTraceReport :: Trace.HumanTraceReport -> ()
consumeTraceReport =
  Trace.foldHumanTraceReport (const ()) (\_ _ -> ()) (\_ _ -> ()) (\_ _ -> ())

consumeQualifyRequest :: Qualify.HumanQualifyRequest -> ()
consumeQualifyRequest = Qualify.foldHumanQualifyRequest $ \_ _ _ _ _ _ -> ()

consumeQualifyContext :: Qualify.HumanQualifyContext -> ()
consumeQualifyContext = Qualify.foldHumanQualifyContext $ \_ _ _ _ _ _ -> ()

consumeQualificationSubjectValue :: Qualify.HumanQualificationSubjectValue -> ()
consumeQualificationSubjectValue =
  Qualify.foldHumanQualificationSubjectValue
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())

consumeQualificationOccurrenceGroup ::
     Qualify.HumanQualificationOccurrenceGroup -> ()
consumeQualificationOccurrenceGroup =
  Qualify.foldHumanQualificationOccurrenceGroup $ \_ _ -> ()

consumeQualificationDiagnostic :: Qualify.HumanQualificationDiagnostic -> ()
consumeQualificationDiagnostic =
  Qualify.foldHumanQualificationDiagnostic $ \_ _ _ _ -> ()

consumeAdmissibleProposal :: Qualify.HumanAdmissibleProposal -> ()
consumeAdmissibleProposal =
  Qualify.foldHumanAdmissibleProposal $ \_ _ _ _ _ _ _ _ _ -> ()

consumeQualificationProposal :: Qualify.HumanQualificationProposal -> ()
consumeQualificationProposal =
  Qualify.foldHumanQualificationProposal $ \_ _ _ _ _ -> ()

consumeQualificationPair :: Qualify.HumanQualificationPair -> ()
consumeQualificationPair = Qualify.foldHumanQualificationPair $ \_ _ _ _ _ -> ()

consumeQualificationUnavailable :: Qualify.HumanQualificationUnavailable -> ()
consumeQualificationUnavailable =
  Qualify.foldHumanQualificationUnavailable $ \_ _ _ _ -> ()

consumeQualificationAssessment :: Qualify.HumanQualificationAssessment -> ()
consumeQualificationAssessment =
  Qualify.foldHumanQualificationAssessment $ \_ _ _ _ _ _ _ -> ()

consumeQualifyReport :: Qualify.HumanQualifyReport -> ()
consumeQualifyReport =
  Qualify.foldHumanQualifyReport (const ()) (\_ _ -> ()) (\_ _ -> ())

consumeReadinessRequest :: Readiness.HumanReadinessRequest -> ()
consumeReadinessRequest = Readiness.foldHumanReadinessRequest $ \_ _ _ _ _ -> ()

consumeReadinessContext :: Readiness.HumanReadinessContext -> ()
consumeReadinessContext =
  Readiness.foldHumanReadinessContext $ \_ _ _ _ _ _ _ -> ()

consumeEvidenceInputSubject :: Readiness.HumanEvidenceInputSubject -> ()
consumeEvidenceInputSubject =
  Readiness.foldHumanEvidenceInputSubject
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())

consumeEvidenceInputDiagnostic :: Readiness.HumanEvidenceInputDiagnostic -> ()
consumeEvidenceInputDiagnostic =
  Readiness.foldHumanEvidenceInputDiagnostic $ \_ _ _ _ -> ()

consumeReadinessEvidenceKey :: Readiness.HumanReadinessEvidenceKey -> ()
consumeReadinessEvidenceKey =
  Readiness.foldHumanReadinessEvidenceKey
    (\_ _ -> ())
    (const ())
    (const ())
    (const ())

consumeReadinessDiagnostic :: Readiness.HumanReadinessDiagnostic -> ()
consumeReadinessDiagnostic = Readiness.foldHumanReadinessDiagnostic $ \_ _ -> ()

consumeReadinessUnavailableReason ::
     Readiness.HumanReadinessUnavailableReason -> ()
consumeReadinessUnavailableReason =
  Readiness.foldHumanReadinessUnavailableReason
    (\_ _ -> ())
    (\_ _ _ _ _ _ -> ())
    (const ())

consumeReadinessUnavailable :: Readiness.HumanReadinessUnavailable -> ()
consumeReadinessUnavailable =
  Readiness.foldHumanReadinessUnavailable (\_ _ -> ()) (\_ _ _ -> ())

consumeReadinessAssessment :: Readiness.HumanReadinessAssessment -> ()
consumeReadinessAssessment =
  Readiness.foldHumanReadinessAssessment (\_ _ _ -> ()) (\_ _ -> ())

consumeReadinessReport :: Readiness.HumanReadinessReport -> ()
consumeReadinessReport =
  Readiness.foldHumanReadinessReport
    (const ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())

consumeAssessRequest :: Assess.HumanAssessRequest -> ()
consumeAssessRequest = Assess.foldHumanAssessRequest $ \_ _ _ _ _ -> ()

consumeAssessContext :: Assess.HumanAssessContext -> ()
consumeAssessContext = Assess.foldHumanAssessContext $ \_ _ _ _ _ _ _ -> ()

consumeAssessmentSubjectValue :: Assess.HumanAssessmentSubjectValue -> ()
consumeAssessmentSubjectValue =
  Assess.foldHumanAssessmentSubjectValue
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())

consumeAssessmentInputDiagnostic :: Assess.HumanAssessmentInputDiagnostic -> ()
consumeAssessmentInputDiagnostic =
  Assess.foldHumanAssessmentInputDiagnostic $ \_ _ _ _ -> ()

consumeAssessmentEvidenceKey :: Assess.HumanAssessmentEvidenceKey -> ()
consumeAssessmentEvidenceKey =
  Assess.foldHumanAssessmentEvidenceKey
    (\_ _ -> ())
    (const ())
    (\_ _ -> ())
    (\_ _ -> ())

consumeAssessmentDiagnostic :: Assess.HumanAssessmentDiagnostic -> ()
consumeAssessmentDiagnostic = Assess.foldHumanAssessmentDiagnostic $ \_ _ -> ()

consumeAssessmentReadinessKey :: Assess.HumanAssessmentReadinessKey -> ()
consumeAssessmentReadinessKey =
  Assess.foldHumanAssessmentReadinessKey
    (\_ _ -> ())
    (const ())
    (const ())
    (const ())

consumeAssessmentUnavailableReason ::
     Assess.HumanAssessmentUnavailableReason -> ()
consumeAssessmentUnavailableReason =
  Assess.foldHumanAssessmentUnavailableReason
    (\_ _ -> ())
    (\_ _ _ _ _ _ -> ())
    (const ())
    (\_ _ -> ())

consumeAssessUnavailable :: Assess.HumanAssessUnavailable -> ()
consumeAssessUnavailable =
  Assess.foldHumanAssessUnavailable (\_ _ -> ()) (\_ _ _ -> ())

consumeDomainValue :: Assess.HumanDomainValue -> ()
consumeDomainValue =
  Assess.foldHumanDomainValue (\_ _ -> ()) (\_ _ -> ()) (const ())

consumeObservation :: Assess.HumanObservation -> ()
consumeObservation = Assess.foldHumanObservation $ \_ _ _ _ _ -> ()

consumeObservationAssessment :: Assess.HumanObservationAssessment -> ()
consumeObservationAssessment =
  Assess.foldHumanObservationAssessment (\_ _ -> ()) (\_ _ _ _ -> ())

consumeEvidenceAssessedProof :: Assess.HumanEvidenceAssessedProof -> ()
consumeEvidenceAssessedProof =
  Assess.foldHumanEvidenceAssessedProof $ \_ _ _ -> ()

consumeAssessmentResult :: Assess.HumanAssessmentResult -> ()
consumeAssessmentResult =
  Assess.foldHumanAssessmentResult (\_ _ _ -> ()) (\_ _ _ _ -> ())

consumeAssessReport :: Assess.HumanAssessReport -> ()
consumeAssessReport =
  Assess.foldHumanAssessReport
    (const ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
    (\_ _ -> ())
