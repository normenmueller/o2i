{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Canonical machine document for closed command errors.
module O2I.Operation.Command.Error.Machine
  ( type CommandErrorDocument
  , commandErrorDocument
  , commandErrorSchema
  , commandErrorSchemaBytes
  , commandErrorDocumentVariant
  , encodeCommandErrorDocument
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Operation.Assess.Result (AssessFailure, foldAssessFailure)
import O2I.Operation.Command.Error
  ( ArgumentFailure
  , CommandError
  , foldArgumentFailure
  , foldCommandError
  )
import O2I.Operation.Command.Error.Projection.Internal
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , closedObjectFragment
  , requiredMember
  , textFragment
  , toolDescriptorFragment
  )
import O2I.Operation.Failure
  ( CommandFailure
  , CommonFailure
  , PreparationFailure
  , commandFailureCode
  , foldCommandFailure
  , foldCommonFailure
  , preparationFailureCode
  , preparationFailureStage
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal (acquisitionFailureFragment)
import O2I.Operation.Preparation (preparationStageText)
import O2I.Operation.Qualification.Subjects.Result
  ( QualificationSubjectsFailure
  , foldQualificationSubjectsFailure
  )
import O2I.Operation.Qualify.Result (QualifyFailure, foldQualifyFailure)
import O2I.Operation.Readiness.Result (ReadinessFailure, foldReadinessFailure)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.Trace.Result (TraceFailure, foldTraceFailure)
import O2I.Operation.Validate.Result (ValidateFailure, foldValidateFailure)

-- | One immutable command error sealed by Operation's generated contract.
newtype CommandErrorDocument =
  CommandErrorDocument MachineResult

-- | Seal one closed command error with exact executable metadata.
commandErrorDocument :: ToolDescriptor -> CommandError -> CommandErrorDocument
commandErrorDocument tool =
  foldCommandError
    argumentDocument
    processDocument
    preparationDocument
    validateDocument
    qualifyDocument
    readinessDocument
    assessDocument
    qualificationSubjectsDocument
    traceDocument
  where
    argumentDocument :: ArgumentFailure -> CommandErrorDocument
    argumentDocument failure =
      foldArgumentFailure
        (\code message ->
           CommandErrorDocument
             (closedMachineResult
                Generated.commandErrorMachineSchema
                Generated.argumentInvalidVariant
                [ requiredMember "tool" (toolDescriptorFragment tool)
                , requiredMember "code" (textFragment code)
                , requiredMember "message" (textFragment message)
                ]))
        failure
    processDocument :: CommandFailure -> CommandErrorDocument
    processDocument failure =
      foldCommandFailure
        (\acquisition ->
           CommandErrorDocument
             (closedMachineResult
                Generated.commandErrorMachineSchema
                Generated.commandFailedVariant
                [ requiredMember "tool" (toolDescriptorFragment tool)
                , requiredMember
                    "code"
                    (textFragment (commandFailureCode failure))
                , requiredMember
                    "failure"
                    (acquisitionFailureFragment acquisition)
                ]))
        failure
    preparationDocument :: PreparationFailure -> CommandErrorDocument
    preparationDocument failure =
      CommandErrorDocument
        (closedMachineResult
           Generated.commandErrorMachineSchema
           Generated.preparationFailedVariant
           [ requiredMember "tool" (toolDescriptorFragment tool)
           , requiredMember
               "code"
               (textFragment (preparationFailureCode failure))
           , requiredMember
               "stage"
               (textFragment
                  (preparationStageText (preparationFailureStage failure)))
           ])
    commonDocument :: CommonFailure -> CommandErrorDocument
    commonDocument = foldCommonFailure processDocument preparationDocument
    capabilityDocument variant code fragment =
      CommandErrorDocument
        (closedMachineResult
           Generated.commandErrorMachineSchema
           variant
           [ requiredMember "tool" (toolDescriptorFragment tool)
           , requiredMember "code" (textFragment code)
           , requiredMember "failure" fragment
           ])
    validateDocument :: ValidateFailure -> CommandErrorDocument
    validateDocument =
      foldValidateFailure
        commonDocument
        (capabilityDocument
           Generated.validateFailedVariant
           "validate.supplemental-input"
           . inputFailureFragment
               "supplemental-input"
               supplementalCommandInputDiagnostic)
        (capabilityDocument
           Generated.validateFailedVariant
           "validate.owner-contract"
           . validateCommandOwnerDiagnostic)
    qualifyDocument :: QualifyFailure -> CommandErrorDocument
    qualifyDocument =
      foldQualifyFailure
        commonDocument
        (capabilityDocument
           Generated.qualifyFailedVariant
           "qualify.supplemental-input"
           . inputFailureFragment
               "supplemental-input"
               supplementalCommandInputDiagnostic)
        (capabilityDocument
           Generated.qualifyFailedVariant
           "qualify.owner-contract"
           . qualifyCommandOwnerDiagnostic)
    readinessDocument :: ReadinessFailure -> CommandErrorDocument
    readinessDocument =
      foldReadinessFailure
        commonDocument
        (capabilityDocument
           Generated.readinessFailedVariant
           "readiness.evidence-input"
           . inputFailureFragment
               "evidence-input"
               readinessCommandInputDiagnostic)
        (capabilityDocument
           Generated.readinessFailedVariant
           "readiness.supplemental-input"
           . inputFailureFragment
               "supplemental-input"
               supplementalCommandInputDiagnostic)
        (capabilityDocument
           Generated.readinessFailedVariant
           "readiness.owner-contract"
           . readinessCommandOwnerDiagnostic)
    assessDocument :: AssessFailure -> CommandErrorDocument
    assessDocument =
      foldAssessFailure
        commonDocument
        (capabilityDocument
           Generated.assessFailedVariant
           "assess.assessment-input"
           . inputFailureFragment
               "assessment-input"
               assessmentCommandInputDiagnostic)
        (capabilityDocument
           Generated.assessFailedVariant
           "assess.supplemental-input"
           . inputFailureFragment
               "supplemental-input"
               supplementalCommandInputDiagnostic)
        (capabilityDocument
           Generated.assessFailedVariant
           "assess.owner-contract"
           . assessCommandOwnerDiagnostic)
    qualificationSubjectsDocument ::
         QualificationSubjectsFailure -> CommandErrorDocument
    qualificationSubjectsDocument =
      foldQualificationSubjectsFailure
        commonDocument
        (capabilityDocument
           Generated.qualificationSubjectsFailedVariant
           "qualification-subjects.supplemental-input"
           . inputFailureFragment
               "supplemental-input"
               supplementalCommandInputDiagnostic)
        (capabilityDocument
           Generated.qualificationSubjectsFailedVariant
           "qualification-subjects.owner-contract"
           . qualificationSubjectsCommandOwnerDiagnostic)
    traceDocument :: TraceFailure -> CommandErrorDocument
    traceDocument =
      foldTraceFailure
        commonDocument
        (capabilityDocument Generated.traceFailedVariant "trace.owner-contract"
           . traceCommandOwnerDiagnostic)

inputFailureFragment ::
     Text
  -> (defect -> CanonicalFragment)
  -> NonEmpty defect
  -> CanonicalFragment
inputFailureFragment category project diagnostics =
  closedObjectFragment
    [ requiredMember "category" (textFragment category)
    , requiredMember
        "diagnostics"
        (arrayFragment (map project (NonEmpty.toList diagnostics)))
    ]

-- | Exact generated Schema metadata and immutable bytes.
commandErrorSchema :: MachineSchema
commandErrorSchema = Generated.commandErrorMachineSchema

-- | Exact immutable generated JSON Schema bytes for pre-output validation.
commandErrorSchemaBytes :: ByteString
commandErrorSchemaBytes = Generated.commandErrorSchemaBytes

-- | Exact constructor discriminator selected by the retained error branch.
commandErrorDocumentVariant :: CommandErrorDocument -> SchemaVariant
commandErrorDocumentVariant (CommandErrorDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes for one complete error document.
encodeCommandErrorDocument :: CommandErrorDocument -> ByteString
encodeCommandErrorDocument (CommandErrorDocument result) =
  machineResultBytesValue result
