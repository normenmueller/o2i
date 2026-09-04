{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Private closed report authority and branch derivation.
module O2I.Operation.Report.Internal
  ( ReportOperation(..)
  , ReportContract(..)
  , ReportAuthority(..)
  , ReportEnvelope(..)
  , reportOperationText
  , foldViewReport
  , foldQualificationSubjectsReport
  , foldValidateReport
  , foldTraceReport
  , foldQualifyReport
  , foldReadinessReport
  , foldAssessReport
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import qualified O2I.Assessment as Assessment
import O2I.Core.Contract
  ( coreContractIdentity
  , coreContractIdentityText
  , coreContractSha256
  , coreContractSha256Text
  , coreContractVersion
  , coreContractVersionText
  )
import O2I.Operation.Adapter (AdapterId, adapterDescriptorId)
import O2I.Operation.Assess.Result
  ( AssessFailure
  , AssessPrerequisite
  , AssessResult
  , AssessUnavailable
  , PreparedAssess
  , foldAssessResult
  )
import O2I.Operation.Discovery.View
  ( ViewDiscovery
  , ViewDiscoveryFailure
  , ViewDiscoveryResult
  , foldViewDiscovery
  , viewDiscoveryAdapter
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Qualification.Subjects.Result
  ( PreparedQualificationSubjects
  , QualificationSubjectsFailure
  , QualificationSubjectsInventory
  , QualificationSubjectsPrerequisite
  , QualificationSubjectsResult
  , foldQualificationSubjectsResult
  )
import O2I.Operation.Qualify.Result
  ( PreparedQualify
  , QualifyFailure
  , QualifyPrerequisite
  , QualifyResult
  , foldQualifyResult
  )
import O2I.Operation.Readiness.Result
  ( PreparedReadiness
  , ReadinessFailure
  , ReadinessPrerequisite
  , ReadinessResult
  , ReadinessUnavailable
  , foldReadinessResult
  )
import qualified O2I.Operation.Rule.Generated as Rule
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.Trace.Result
  ( PreparedTrace
  , TraceFailure
  , TracePrerequisite
  , TraceResult
  , foldTracePrerequisite
  , foldTraceResult
  )
import O2I.Operation.Validate.Request
  ( foldValidationLevel
  , validateRequestLevel
  )
import O2I.Operation.Validate.Result
  ( PreparedValidation
  , ValidateFailure
  , ValidateResult
  , ValidateUnavailabilityWitness
  , foldPreparedValidation
  , foldValidateResult
  )
import qualified O2I.Qualification as Qualification
import qualified O2I.Readiness as Readiness
import qualified O2I.Trace as Trace

-- | Exactly one of the seven public model-operation reports.
data ReportOperation
  = ViewsReportOperation
  | QualificationSubjectsReportOperation
  | ValidateReportOperation
  | TraceReportOperation
  | QualifyReportOperation
  | ReadinessReportOperation
  | AssessReportOperation

-- | One exact contract authority selected for a report branch.
data ReportContract
  = OperationReportContract Text Text Text
  | AdapterReportContract
  | ProfileReportContract
  | CoreReportContract Text Text Text

-- | Exact authority shape selected by the report family.
data ReportAuthority
  = ViewReportAuthority AdapterId
  | PreparedReportAuthority (NonEmpty ReportContract)

-- | Schema, branch, operation, tool, and contract authority derived together.
data ReportEnvelope =
  ReportEnvelope
    MachineSchema
    SchemaVariant
    ReportOperation
    ToolDescriptor
    ReportAuthority

-- | Stable operation token shared by Human and Machine consumers.
reportOperationText :: ReportOperation -> Text
reportOperationText operation =
  case operation of
    ViewsReportOperation -> "views"
    QualificationSubjectsReportOperation -> "qualification-subjects"
    ValidateReportOperation -> "validate"
    TraceReportOperation -> "trace"
    QualifyReportOperation -> "qualify"
    ReadinessReportOperation -> "readiness"
    AssessReportOperation -> "assess"

-- | Fold View discovery once and attach authority only to completed success.
foldViewReport ::
     ToolDescriptor
  -> (ViewDiscoveryFailure -> result)
  -> (ReportEnvelope -> ViewDiscoveryResult -> result)
  -> ViewDiscovery
  -> result
foldViewReport tool failed discovered =
  foldViewDiscovery failed $ \result ->
    discovered
      (ReportEnvelope
         Generated.viewDiscoveryMachineSchema
         Generated.viewsDiscoveredVariant
         ViewsReportOperation
         tool
         (ViewReportAuthority
            (adapterDescriptorId (viewDiscoveryAdapter result))))
      result

-- | Fold qualification-subject discovery once with exact branch authority.
foldQualificationSubjectsReport ::
     ToolDescriptor
  -> (QualificationSubjectsFailure -> result)
  -> (ReportEnvelope -> QualificationSubjectsPrerequisite -> PreparedQualificationSubjects -> result)
  -> (ReportEnvelope -> QualificationSubjectsInventory -> PreparedQualificationSubjects -> result)
  -> QualificationSubjectsResult
  -> result
foldQualificationSubjectsReport tool failed prerequisite discovered =
  foldQualificationSubjectsResult
    failed
    (\stage prepared ->
       prerequisite
         (preparedEnvelope
            Generated.qualificationSubjectsMachineSchema
            Generated.qualificationSubjectsPrerequisiteRejectedVariant
            QualificationSubjectsReportOperation
            tool
            contractsWithCore)
         stage
         prepared)
    (\subjects prepared ->
       discovered
         (preparedEnvelope
            Generated.qualificationSubjectsMachineSchema
            Generated.qualificationSubjectsDiscoveredVariant
            QualificationSubjectsReportOperation
            tool
            contractsWithCore)
         subjects
         prepared)

-- | Fold Validate once and derive its requested contract boundary once.
foldValidateReport ::
     ToolDescriptor
  -> (ValidateFailure -> result)
  -> (ReportEnvelope -> PreparedValidation -> result)
  -> (ReportEnvelope -> PreparedValidation -> result)
  -> (ReportEnvelope -> NonEmpty ValidateUnavailabilityWitness -> PreparedValidation -> result)
  -> ValidateResult
  -> result
foldValidateReport tool failed accepted rejected unavailable =
  foldValidateResult
    failed
    (prepared
       accepted
       Generated.notationValidationAcceptedVariant
       Generated.profileValidationAcceptedVariant
       Generated.structureValidationAcceptedVariant
       Generated.semanticsValidationAcceptedVariant)
    (prepared
       rejected
       Generated.notationValidationRejectedVariant
       Generated.profileValidationRejectedVariant
       Generated.structureValidationRejectedVariant
       Generated.semanticsValidationRejectedVariant)
    (\witnesses value ->
       unavailable
         (validateEnvelope
            tool
            Generated.semanticsValidationUnavailableVariant
            value)
         witnesses
         value)
  where
    prepared consume notation profile structure semantics value =
      consume
        (validateEnvelope
           tool
           (foldPreparedValidation
              (\_ completed _ _ _ ->
                 foldValidationLevel
                   notation
                   profile
                   structure
                   semantics
                   completed)
              value)
           value)
        value

-- | Fold Trace once and derive branch-selected Core participation once.
foldTraceReport ::
     ToolDescriptor
  -> (TraceFailure -> result)
  -> (ReportEnvelope -> TracePrerequisite -> PreparedTrace -> result)
  -> (forall scope. ReportEnvelope -> Trace.TraceAssessment scope -> PreparedTrace -> result)
  -> (forall scope. ReportEnvelope -> Trace.TraceAssessment scope -> PreparedTrace -> result)
  -> TraceResult
  -> result
foldTraceReport tool failed prerequisite rejected accepted =
  foldTraceResult
    failed
    (\stage prepared ->
       prerequisite
         (traceEnvelope
            tool
            Generated.tracePrerequisiteRejectedVariant
            (Just stage))
         stage
         prepared)
    (\assessment prepared ->
       rejected
         (traceEnvelope tool Generated.traceRejectedVariant Nothing)
         assessment
         prepared)
    (\assessment prepared ->
       accepted
         (traceEnvelope tool Generated.traceAcceptedVariant Nothing)
         assessment
         prepared)

-- | Fold Qualify once with the exact prepared authority.
foldQualifyReport ::
     ToolDescriptor
  -> (QualifyFailure -> result)
  -> (ReportEnvelope -> QualifyPrerequisite -> PreparedQualify -> result)
  -> (forall scope. ReportEnvelope -> Qualification.QualificationAssessment
                                        scope -> PreparedQualify -> result)
  -> QualifyResult
  -> result
foldQualifyReport tool failed prerequisite completed =
  foldQualifyResult
    failed
    (\stage prepared ->
       prerequisite
         (envelope Generated.qualifyPrerequisiteRejectedVariant)
         stage
         prepared)
    (\assessment prepared ->
       completed
         (envelope Generated.qualifyCompletedVariant)
         assessment
         prepared)
  where
    envelope variant =
      preparedEnvelope
        Generated.qualifyResultMachineSchema
        variant
        QualifyReportOperation
        tool
        contractsWithCore

-- | Fold Readiness once with the exact prepared authority.
foldReadinessReport ::
     ToolDescriptor
  -> (ReadinessFailure -> result)
  -> (ReportEnvelope -> ReadinessPrerequisite -> PreparedReadiness -> result)
  -> (ReportEnvelope -> ReadinessUnavailable -> PreparedReadiness -> result)
  -> (forall scope. ReportEnvelope -> Readiness.ReadinessAssessment scope -> PreparedReadiness -> result)
  -> (forall scope. ReportEnvelope -> Readiness.ReadinessAssessment scope -> PreparedReadiness -> result)
  -> ReadinessResult
  -> result
foldReadinessReport tool failed prerequisite unavailable notReady ready =
  foldReadinessResult
    failed
    (\stage prepared ->
       prerequisite
         (envelope Generated.readinessPrerequisiteRejectedVariant)
         stage
         prepared)
    (\reason prepared ->
       unavailable
         (envelope Generated.readinessSubjectUnavailableVariant)
         reason
         prepared)
    (\assessment prepared ->
       notReady
         (envelope Generated.readinessNotReadyVariant)
         assessment
         prepared)
    (\assessment prepared ->
       ready (envelope Generated.readinessReadyVariant) assessment prepared)
  where
    envelope variant =
      preparedEnvelope
        Generated.readinessResultMachineSchema
        variant
        ReadinessReportOperation
        tool
        contractsWithCore

-- | Fold Assess once with the exact prepared authority.
foldAssessReport ::
     ToolDescriptor
  -> (AssessFailure -> result)
  -> (ReportEnvelope -> AssessPrerequisite -> PreparedAssess -> result)
  -> (ReportEnvelope -> AssessUnavailable -> PreparedAssess -> result)
  -> (forall scope. ReportEnvelope -> Assessment.AssessmentResult scope -> PreparedAssess -> result)
  -> (forall scope. ReportEnvelope -> Assessment.AssessmentResult scope -> PreparedAssess -> result)
  -> (forall scope. ReportEnvelope -> Assessment.AssessmentResult scope -> PreparedAssess -> result)
  -> AssessResult
  -> result
foldAssessReport tool failed prerequisite unavailable collection invalid completed =
  foldAssessResult
    failed
    (\stage prepared ->
       prerequisite
         (envelope Generated.assessPrerequisiteRejectedVariant)
         stage
         prepared)
    (\reason prepared ->
       unavailable
         (envelope Generated.assessSubjectUnavailableVariant)
         reason
         prepared)
    (\assessment prepared ->
       collection
         (envelope Generated.assessCollectionInvalidVariant)
         assessment
         prepared)
    (\assessment prepared ->
       invalid
         (envelope Generated.assessObservationsInvalidVariant)
         assessment
         prepared)
    (\assessment prepared ->
       completed (envelope Generated.assessCompletedVariant) assessment prepared)
  where
    envelope variant =
      preparedEnvelope
        Generated.assessResultMachineSchema
        variant
        AssessReportOperation
        tool
        contractsWithCore

validateEnvelope ::
     ToolDescriptor -> SchemaVariant -> PreparedValidation -> ReportEnvelope
validateEnvelope tool variant prepared =
  preparedEnvelope
    Generated.validateResultMachineSchema
    variant
    ValidateReportOperation
    tool
    (foldPreparedValidation
       (\request _ _ _ _ ->
          foldValidationLevel
            contractsWithoutCore
            contractsWithoutCore
            contractsWithCore
            contractsWithCore
            (validateRequestLevel request))
       prepared)

traceEnvelope ::
     ToolDescriptor
  -> SchemaVariant
  -> Maybe TracePrerequisite
  -> ReportEnvelope
traceEnvelope tool variant prerequisite =
  preparedEnvelope
    Generated.traceResultMachineSchema
    variant
    TraceReportOperation
    tool
    (case prerequisite of
       Nothing -> contractsWithCore
       Just stage ->
         foldTracePrerequisite
           contractsWithoutCore
           contractsWithoutCore
           contractsWithCore
           contractsWithCore
           stage)

preparedEnvelope ::
     MachineSchema
  -> SchemaVariant
  -> ReportOperation
  -> ToolDescriptor
  -> NonEmpty ReportContract
  -> ReportEnvelope
preparedEnvelope schema variant operation tool contracts =
  ReportEnvelope
    schema
    variant
    operation
    tool
    (PreparedReportAuthority contracts)

contractsWithoutCore :: NonEmpty ReportContract
contractsWithoutCore =
  operationContract :| [AdapterReportContract, ProfileReportContract]

contractsWithCore :: NonEmpty ReportContract
contractsWithCore = contractsWithoutCore <> (coreContract :| [])

operationContract :: ReportContract
operationContract =
  OperationReportContract
    Rule.operationContractIdentity
    Rule.operationContractVersion
    Rule.operationContractSha256

coreContract :: ReportContract
coreContract =
  CoreReportContract
    (coreContractIdentityText coreContractIdentity)
    (coreContractVersionText coreContractVersion)
    (coreContractSha256Text coreContractSha256)
