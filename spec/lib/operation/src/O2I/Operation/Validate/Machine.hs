{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine documents for cumulative Validate results.
--
-- Expected failures remain typed command outcomes and therefore have no
-- Operation envelope. Every prepared terminal result becomes one immutable
-- Schema-bound document.
module O2I.Operation.Validate.Machine
  ( type ValidateResultDocument
  , validateResultDocument
  , validateResultSchema
  , validateResultDocumentVariant
  , encodeValidateResultDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Identity (ModelIdentity, modelIdentityText)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , InputSource
  , foldInputSource
  )
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , CanonicalMember
  , MachineResult(..)
  , arrayFragment
  , closedObjectFragment
  , closedOperationMachineResult
  , nullFragment
  , reportAuthorityMember
  , requiredMember
  , textFragment
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Machine.Fragment.Internal
  ( emptySupplementalDiagnosticGroupFragments
  , foldPreparedDiagnosticDocumentFragments
  , viewDescriptorFragment
  )
import O2I.Operation.Report.Internal (foldValidateReport)
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated
import O2I.Operation.Validate.Request
  ( ValidateRequest
  , ValidationLevel
  , foldValidateRequest
  , semanticsValidationLevel
  , structureValidationLevel
  , validateRequestLevel
  )
import O2I.Operation.Validate.Result
  ( ValidateFailure
  , ValidateResult
  , ValidateUnavailabilityWitness
  , foldPreparedValidation
  , foldValidateUnavailabilityWitness
  )
import O2I.Operation.View
  ( SelectedView
  , ViewSelector
  , foldViewSelector
  , selectedViewDescriptor
  )
import O2I.Semantics
  ( CollectiveFitUnavailableReason(..)
  , StrategyFormulationUnavailableReason(..)
  )

-- | One immutable completed Validate machine document.
newtype ValidateResultDocument =
  ValidateResultDocument MachineResult

-- | Preserve expected failure or close one prepared terminal result.
validateResultDocument ::
     ToolDescriptor
  -> ValidateResult
  -> Either ValidateFailure ValidateResultDocument
validateResultDocument tool =
  foldValidateReport
    tool
    Left
    (\envelope prepared ->
       Right (preparedDocument envelope "accepted" Nothing prepared))
    (\envelope prepared ->
       Right (preparedDocument envelope "rejected" Nothing prepared))
    (\envelope witnesses prepared ->
       Right
         (preparedDocument
            envelope
            "unavailable"
            (Just (NonEmpty.toList witnesses))
            prepared))
  where
    preparedDocument envelope status witnesses prepared =
      foldPreparedValidation
        (\request completed view acquired diagnostics ->
           foldPreparedDiagnosticDocumentFragments
             (\authority modelDiagnostics supplementalGroups ->
                ValidateResultDocument
                  (closedOperationMachineResult
                     envelope
                     [ requiredMember
                         "context"
                         (contextFragment
                            request
                            completed
                            view
                            acquired
                            supplementalGroups
                            authority)
                     , requiredMember "request" (requestFragment request)
                     , requiredMember
                         "execution"
                         (executionFragment status witnesses)
                     , requiredMember
                         "diagnostics"
                         (diagnosticsFragment modelDiagnostics)
                     , reportAuthorityMember envelope
                     ]))
             diagnostics)
        prepared

-- | Exact generated Schema authority for Validate result documents.
validateResultSchema :: MachineSchema
validateResultSchema = Generated.validateResultMachineSchema

-- | Exact terminal constructor discriminator selected by execution.
validateResultDocumentVariant :: ValidateResultDocument -> SchemaVariant
validateResultDocumentVariant (ValidateResultDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeValidateResultDocument :: ValidateResultDocument -> ByteString
encodeValidateResultDocument (ValidateResultDocument result) =
  machineResultBytesValue result

contextFragment ::
     ValidateRequest
  -> ValidationLevel
  -> SelectedView document
  -> [AcquiredSupplementalSource]
  -> [CanonicalFragment]
  -> CanonicalFragment
  -> CanonicalFragment
contextFragment request completed view acquired supplementalGroups authority =
  closedObjectFragment
    [ requiredMember "authority" authority
    , requiredMember
        "view"
        (viewDescriptorFragment (selectedViewDescriptor view))
    , requiredMember "supplements" (arrayFragment selectedSupplementalGroups)
    ]
  where
    selectedSupplementalGroups
      | validateRequestLevel request == semanticsValidationLevel
          && completed == structureValidationLevel =
        emptySupplementalDiagnosticGroupFragments acquired
      | otherwise = supplementalGroups

requestFragment :: ValidateRequest -> CanonicalFragment
requestFragment =
  foldValidateRequest
    (\_ selector adapter -> fixed "notation" selector adapter [])
    (\_ selector adapter -> fixed "profile" selector adapter [])
    (\_ selector adapter -> fixed "structure" selector adapter [])
    (\_ selector adapter supplements ->
       fixed "semantics" selector adapter supplements)
  where
    fixed level selector adapter supplements =
      closedObjectFragment
        [ requiredMember "level" (textFragment level)
        , requiredMember "view" (viewSelectorFragment selector)
        , requiredMember
            "adapterId"
            (maybe nullFragment (textFragment . adapterIdText) adapter)
        , requiredMember
            "supplements"
            (arrayFragment (map inputSourceFragment supplements))
        ]

viewSelectorFragment :: ViewSelector -> CanonicalFragment
viewSelectorFragment =
  foldViewSelector (selector "name") (selector "identity" . modelIdentityText)
  where
    selector kind value =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "value" (textFragment value)
        ]

inputSourceFragment :: InputSource -> CanonicalFragment
inputSourceFragment =
  foldInputSource
    (\_ path ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "file")
         , requiredMember "path" (textFragment (Text.pack path))
         ])
    (const (closedObjectFragment [requiredMember "kind" (textFragment "stdin")]))

executionFragment ::
     Text -> Maybe [ValidateUnavailabilityWitness] -> CanonicalFragment
executionFragment status witnesses =
  closedObjectFragment
    ([requiredMember "status" (textFragment status)]
       <> maybe
            []
            (pure
               . requiredMember "coreWitnesses"
               . arrayFragment
               . mapMaybe coreWitnessFragment)
            witnesses)

coreWitnessFragment :: ValidateUnavailabilityWitness -> Maybe CanonicalFragment
coreWitnessFragment =
  foldValidateUnavailabilityWitness
    (const Nothing)
    (\subject reason ->
       Just
         (closedObjectFragment
            [ requiredMember "kind" (textFragment "strategy-formulation")
            , requiredMember "subject" (modelIdentityFragment subject)
            , requiredMember "reason" (textFragment (strategyReasonText reason))
            ]))
    (\subject reasons blockers ->
       Just
         (collectiveFragment
            "collective-fit"
            subject
            [ requiredMember
                "reasons"
                (arrayFragment
                   (map
                      (textFragment . collectiveReasonText)
                      (NonEmpty.toList reasons)))
            , requiredMember "blockers" (modelIdentityArray blockers)
            ]))
    (\subject blockers ->
       Just
         (collectiveFragment
            "collective-coverage"
            subject
            [requiredMember "blockers" (modelIdentityArray blockers)]))
    (\subject participant reasons blockers ->
       Just
         (collectiveFragment
            "primitive-support"
            subject
            [ requiredMember "participant" (modelIdentityFragment participant)
            , requiredMember
                "reasons"
                (arrayFragment
                   (map
                      (textFragment . collectiveReasonText)
                      (NonEmpty.toList reasons)))
            , requiredMember "blockers" (modelIdentityArray blockers)
            ]))

collectiveFragment ::
     Text -> ModelIdentity -> [CanonicalMember] -> CanonicalFragment
collectiveFragment kind subject members =
  closedObjectFragment
    ([ requiredMember "kind" (textFragment kind)
     , requiredMember "subject" (modelIdentityFragment subject)
     ]
       <> members)

modelIdentityArray :: [ModelIdentity] -> CanonicalFragment
modelIdentityArray = arrayFragment . map modelIdentityFragment

modelIdentityFragment :: ModelIdentity -> CanonicalFragment
modelIdentityFragment = textFragment . modelIdentityText

strategyReasonText :: StrategyFormulationUnavailableReason -> Text
strategyReasonText reason =
  case reason of
    StrategyFormulationInputMissing -> "input-missing"
    StrategyFormulationIdentityUnresolved -> "identity-unresolved"

collectiveReasonText :: CollectiveFitUnavailableReason -> Text
collectiveReasonText reason =
  case reason of
    CollectiveFitInputMissing -> "collective-fit-input-missing"
    CollectiveFitIdentityUnresolved -> "collective-fit-identity-unresolved"
    ParticipantStrategyFormulationUnavailable ->
      "participant-strategy-formulation-unavailable"
    ParticipantStrategyFormulationInvalid ->
      "participant-strategy-formulation-invalid"
    TargetStrategyFormulationUnavailable ->
      "target-strategy-formulation-unavailable"
    TargetStrategyFormulationInvalid -> "target-strategy-formulation-invalid"

diagnosticsFragment :: [CanonicalFragment] -> CanonicalFragment
diagnosticsFragment diagnostics =
  closedObjectFragment
    [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
    , requiredMember "modelDiagnostics" (arrayFragment diagnostics)
    ]
