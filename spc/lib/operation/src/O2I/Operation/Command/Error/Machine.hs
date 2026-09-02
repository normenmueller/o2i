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
  , CommandDiagnosticField
  , CommandDiagnosticValue
  , CommandError
  , CommandInputDiagnostic
  , CommandOwnerDiagnostic
  , CommandOwnerEvidence
  , assessCommandOwnerDiagnostic
  , assessmentCommandInputDiagnostic
  , foldArgumentFailure
  , foldCommandDiagnosticField
  , foldCommandDiagnosticValue
  , foldCommandError
  , foldCommandInputDiagnostic
  , foldCommandOwnerDiagnostic
  , foldCommandOwnerEvidence
  , qualifyCommandOwnerDiagnostic
  , readinessCommandInputDiagnostic
  , readinessCommandOwnerDiagnostic
  , supplementalCommandInputDiagnostic
  , validateCommandOwnerDiagnostic
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , closedObjectFragment
  , naturalFragment
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
import O2I.Operation.Qualify.Result (QualifyFailure, foldQualifyFailure)
import O2I.Operation.Readiness.Result (ReadinessFailure, foldReadinessFailure)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
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
           . ownerFailureFragment
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
           . ownerFailureFragment
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
           . ownerFailureFragment
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
           . ownerFailureFragment
           . assessCommandOwnerDiagnostic)

inputFailureFragment ::
     Text
  -> (defect -> CommandInputDiagnostic)
  -> NonEmpty defect
  -> CanonicalFragment
inputFailureFragment category project diagnostics =
  closedObjectFragment
    [ requiredMember "category" (textFragment category)
    , requiredMember
        "diagnostics"
        (arrayFragment
           (map
              (inputDiagnosticFragment . project)
              (NonEmpty.toList diagnostics)))
    ]

inputDiagnosticFragment :: CommandInputDiagnostic -> CanonicalFragment
inputDiagnosticFragment =
  foldCommandInputDiagnostic $ \rule ordinals reason fields ->
    closedObjectFragment
      [ requiredMember "ruleId" (textFragment rule)
      , requiredMember
          "inputOrdinals"
          (arrayFragment (map naturalFragment (NonEmpty.toList ordinals)))
      , requiredMember "reason" (textFragment reason)
      , requiredMember
          "fields"
          (arrayFragment (map diagnosticFieldFragment fields))
      ]

ownerFailureFragment :: CommandOwnerDiagnostic -> CanonicalFragment
ownerFailureFragment =
  foldCommandOwnerDiagnostic $ \branch evidence ->
    closedObjectFragment
      [ requiredMember "category" (textFragment "owner-contract")
      , requiredMember "branch" (textFragment branch)
      , requiredMember
          "evidence"
          (arrayFragment (map ownerEvidenceFragment (NonEmpty.toList evidence)))
      ]

ownerEvidenceFragment :: CommandOwnerEvidence -> CanonicalFragment
ownerEvidenceFragment =
  foldCommandOwnerEvidence $ \kind fields ->
    closedObjectFragment
      [ requiredMember "kind" (textFragment kind)
      , requiredMember
          "fields"
          (arrayFragment (map diagnosticFieldFragment fields))
      ]

diagnosticFieldFragment :: CommandDiagnosticField -> CanonicalFragment
diagnosticFieldFragment =
  foldCommandDiagnosticField $ \name values ->
    closedObjectFragment
      [ requiredMember "name" (textFragment name)
      , requiredMember
          "values"
          (arrayFragment (map diagnosticValueFragment values))
      ]

diagnosticValueFragment :: CommandDiagnosticValue -> CanonicalFragment
diagnosticValueFragment =
  foldCommandDiagnosticValue
    (scalarValueFragment "text" textFragment)
    (scalarValueFragment "natural" naturalFragment)
    (scalarValueFragment "model-identity" textFragment)
    (scalarValueFragment "occurrence-identity" textFragment)
    (scalarValueFragment "qualified-type" textFragment)
    (\role ordinal ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "source-key")
         , requiredMember "role" (textFragment role)
         , requiredMember "ordinal" (naturalFragment ordinal)
         ])
    (\role ordinal reference digest ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "source-identity")
         , requiredMember "role" (textFragment role)
         , requiredMember "ordinal" (naturalFragment ordinal)
         , requiredMember "reference" (textFragment reference)
         , requiredMember "sha256" (textFragment digest)
         ])
    (\identifier name version notation ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "adapter-descriptor")
         , requiredMember "id" (textFragment identifier)
         , requiredMember "name" (textFragment name)
         , requiredMember "version" (textFragment version)
         , requiredMember "notation" (textFragment notation)
         ])
    (\kind ordinal ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "canonical-occurrence")
         , requiredMember "occurrenceKind" (textFragment kind)
         , requiredMember "ordinal" (naturalFragment ordinal)
         ])
    (\index codePoint ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "unicode-scalar")
         , requiredMember "index" (naturalFragment index)
         , requiredMember "codePoint" (naturalFragment codePoint)
         ])

scalarValueFragment ::
     Text -> (value -> CanonicalFragment) -> value -> CanonicalFragment
scalarValueFragment kind valueFragment value =
  closedObjectFragment
    [ requiredMember "kind" (textFragment kind)
    , requiredMember "value" (valueFragment value)
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
