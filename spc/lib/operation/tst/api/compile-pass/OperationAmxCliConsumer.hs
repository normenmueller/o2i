{-# LANGUAGE OverloadedStrings #-}

-- | Package-external proof of the exact CLI composition dependency edge.
module OperationAmxCliConsumer where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX (amxAdapter, foldAMXAdapterDefect)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , InputSource
  , foldAcquisitionFailure
  , foldInputSource
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , AdapterDescriptor
  , AdapterDiagnostic
  , adapterDiagnosticOccurrences
  , adapterDiagnosticRule
  , adapterIdText
  , adapterRuleId
  , adapterRuleIdText
  , foldAdapterDescriptor
  , foldAdapterOccurrence
  , foldAdapterSelectionError
  , foldNativeLocation
  )
import O2I.Operation.Adapter.Authoring
  ( AdapterCollectionDefect(..)
  , compileAdapterCollection
  )
import qualified O2I.Operation.Assess.Human as HumanAssess
import O2I.Operation.Assess.Machine
import O2I.Operation.Assess.Result
import O2I.Operation.Command.Error
import O2I.Operation.Command.Error.Machine
import O2I.Operation.Diagnostic
import qualified O2I.Operation.Discovery.View as ViewResult
import qualified O2I.Operation.Discovery.View.Human as HumanViews
import O2I.Operation.Failure
import qualified O2I.Operation.Human.Diagnostic as HumanDiagnostic
import qualified O2I.Operation.Human.Failure as HumanFailure
import qualified O2I.Operation.Human.Value as HumanValue
import O2I.Operation.Identity
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile
import O2I.Operation.Provenance
  ( SourceIdentity
  , foldSourceIdentity
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import qualified O2I.Operation.Qualification.Subjects.Human as HumanSubjects
import qualified O2I.Operation.Qualification.Subjects.Result as SubjectsResult
import qualified O2I.Operation.Qualify.Human as HumanQualify
import O2I.Operation.Qualify.Machine
import O2I.Operation.Qualify.Result
import qualified O2I.Operation.Readiness.Human as HumanReadiness
import O2I.Operation.Readiness.Machine
import O2I.Operation.Readiness.Result
import O2I.Operation.Report (ReportEnvelope)
import O2I.Operation.Rule.Catalog (operationRuleIdText, operationRuleIdentity)
import O2I.Operation.Schema (MachineSchema, schemaVariantText)
import qualified O2I.Operation.Trace.Human as HumanTrace
import qualified O2I.Operation.Trace.Result as TraceResult
import qualified O2I.Operation.Validate.Human as HumanValidate
import O2I.Operation.Validate.Machine
import O2I.Operation.Validate.Request (validationLevelText)
import O2I.Operation.Validate.Result
import O2I.Operation.View (ViewSelector, viewByIdentity)
import OperationReportPublicObserver

-- | Compile the exact statically linked AMX and Profile composition.
staticComposition :: Either Text (AdapterCollection, ProfileInventory)
staticComposition =
  case amxAdapter of
    Left defects ->
      Left
        (renderNonEmpty
           (foldAMXAdapterDefect
              "amx-identifier"
              "amx-descriptor"
              "amx-rule"
              "amx-compilation")
           defects)
    Right adapter ->
      case compileAdapterCollection (adapter :| []) of
        Left defects ->
          Left
            (renderNonEmpty
               (\(DuplicateAdapterIdentifier identifier) ->
                  renderMany ["duplicate-adapter", adapterIdText identifier])
               defects)
        Right adapters ->
          foldProfileInventoryCompilation
            (Left . renderNonEmpty consumeProfileInventoryDefect)
            (\profiles -> Right (adapters, profiles))
            compiledProfileInventory

consumeProfileInventoryDefect :: ProfileInventoryDefect -> Text
consumeProfileInventoryDefect =
  foldProfileInventoryDefect
    "empty-profile-inventory"
    (\rule key ->
       foldProfileInventoryKey
         (\identity token ->
            renderMany
              [ "duplicate-profile"
              , operationRuleIdText (operationRuleIdentity rule)
              , identity
              , token
              ])
         key)

-- | Decode an exact lexical identity and retain the owned Core type opaquely.
identitySelector :: Text -> Either ModelIdentityDefect ViewSelector
identitySelector = fmap viewByIdentity . lexicalModelIdentity

-- | Author and encode a CLI-owned argument error without reconstructing JSON.
argumentErrorBytes ::
     ToolDescriptor
  -> Text
  -> Text
  -> Either (NonEmpty ArgumentFailureDefect) ByteString
argumentErrorBytes tool code message =
  fmap
    (encodeCommandErrorDocument
       . commandErrorDocument tool
       . argumentCommandError)
    (argumentFailure code message)

-- | Encode either existing common Operation failure through the same algebra.
commonErrorBytes :: ToolDescriptor -> CommonFailure -> ByteString
commonErrorBytes tool =
  encodeCommandErrorDocument . commandErrorDocument tool . commonCommandError

-- | Consume every command branch for human rendering without constructors.
consumeCommandError :: CommandError -> Text
consumeCommandError =
  foldCommandError
    argumentFailureMessage
    commandFailureCode
    preparationFailureCode
    consumeValidateFailure
    consumeQualifyFailure
    consumeReadinessFailure
    consumeAssessFailure

-- | Route a real Validate document failure through the closed error encoder.
validateResultOrErrorBytes :: ToolDescriptor -> ValidateResult -> ByteString
validateResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . validateCommandError)
    encodeValidateResultDocument
    (validateResultDocument tool result)

-- | Route a real Qualify document failure through the closed error encoder.
qualifyResultOrErrorBytes :: ToolDescriptor -> QualifyResult -> ByteString
qualifyResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . qualifyCommandError)
    encodeQualifyResultDocument
    (qualifyResultDocument tool result)

-- | Route a real Readiness document failure through the closed error encoder.
readinessResultOrErrorBytes :: ToolDescriptor -> ReadinessResult -> ByteString
readinessResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . readinessCommandError)
    encodeReadinessResultDocument
    (readinessResultDocument tool result)

-- | Route a real Assess document failure through the closed error encoder.
assessResultOrErrorBytes :: ToolDescriptor -> AssessResult -> ByteString
assessResultOrErrorBytes tool result =
  either
    (commandErrorBytes tool . assessCommandError)
    encodeAssessResultDocument
    (assessResultDocument tool result)

commandErrorBytes :: ToolDescriptor -> CommandError -> ByteString
commandErrorBytes tool = encodeCommandErrorDocument . commandErrorDocument tool

consumeValidateFailure :: ValidateFailure -> Text
consumeValidateFailure =
  foldValidateFailure
    consumeCommonFailure
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . validateCommandOwnerDiagnostic)

consumeQualifyFailure :: QualifyFailure -> Text
consumeQualifyFailure =
  foldQualifyFailure
    consumeCommonFailure
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . qualifyCommandOwnerDiagnostic)

consumeReadinessFailure :: ReadinessFailure -> Text
consumeReadinessFailure =
  foldReadinessFailure
    consumeCommonFailure
    (consumeInputDiagnostics readinessCommandInputDiagnostic)
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . readinessCommandOwnerDiagnostic)

consumeAssessFailure :: AssessFailure -> Text
consumeAssessFailure =
  foldAssessFailure
    consumeCommonFailure
    (consumeInputDiagnostics assessmentCommandInputDiagnostic)
    (consumeInputDiagnostics supplementalCommandInputDiagnostic)
    (consumeOwnerDiagnostic . assessCommandOwnerDiagnostic)

consumeCommonFailure :: CommonFailure -> Text
consumeCommonFailure =
  foldCommonFailure commandFailureCode preparationFailureCode

consumeInputDiagnostics ::
     (defect -> CommandInputDiagnostic) -> NonEmpty defect -> Text
consumeInputDiagnostics project =
  Text.intercalate "|"
    . map (consumeInputDiagnostic . project)
    . NonEmpty.toList

consumeInputDiagnostic :: CommandInputDiagnostic -> Text
consumeInputDiagnostic =
  foldCommandInputDiagnostic $ \rule ordinals reason fields ->
    Text.intercalate
      ":"
      [ rule
      , Text.intercalate "," (map (Text.pack . show) (NonEmpty.toList ordinals))
      , reason
      , Text.intercalate "," (map consumeDiagnosticField fields)
      ]

consumeOwnerDiagnostic :: CommandOwnerDiagnostic -> Text
consumeOwnerDiagnostic =
  foldCommandOwnerDiagnostic $ \branch evidence ->
    branch
      <> ":"
      <> Text.intercalate
           ","
           (map consumeOwnerEvidence (NonEmpty.toList evidence))

consumeOwnerEvidence :: CommandOwnerEvidence -> Text
consumeOwnerEvidence =
  foldCommandOwnerEvidence $ \kind fields ->
    kind <> ":" <> Text.intercalate "," (map consumeDiagnosticField fields)

consumeDiagnosticField :: CommandDiagnosticField -> Text
consumeDiagnosticField =
  foldCommandDiagnosticField $ \name values ->
    name <> "=" <> Text.intercalate "+" (map consumeDiagnosticValue values)

consumeDiagnosticValue :: CommandDiagnosticValue -> Text
consumeDiagnosticValue =
  foldCommandDiagnosticValue
    ("text:" <>)
    (("natural:" <>) . Text.pack . show)
    ("model:" <>)
    ("occurrence:" <>)
    ("qualified:" <>)
    (\role ordinal -> role <> ":" <> Text.pack (show ordinal))
    (\role ordinal reference digest ->
       Text.intercalate ":" [role, Text.pack (show ordinal), reference, digest])
    (\identifier name version notation ->
       Text.intercalate ":" [identifier, name, version, notation])
    (\kind ordinal -> kind <> ":" <> Text.pack (show ordinal))
    (\index codePoint ->
       Text.pack (show index) <> ":" <> Text.pack (show codePoint))

-- | Exact immutable Schema input available before the first output byte.
commandErrorPreflight :: (MachineSchema, ByteString)
commandErrorPreflight = (commandErrorSchema, commandErrorSchemaBytes)

-- | Consume all supplemental groups and all closed finding branches.
consumeSupplementalGroups ::
     SupplementalDiagnosticGroups authority profile document -> [Text]
consumeSupplementalGroups =
  foldSupplementalDiagnosticGroups
    (\source diagnostics -> fmap (consumeSupplemental source) diagnostics)
    concat

consumeSupplemental ::
     AcquiredSupplementalSource -> SupplementalDiagnostic -> Text
consumeSupplemental groupSource diagnostic =
  supplementalDiagnosticRuleIdentity diagnostic
    <> ":"
    <> foldSupplementalDiagnostic tagged tagged tagged tagged diagnostic
  where
    tagged retainedSource pointer identity
      | retainedSource == groupSource =
        pointer <> ":" <> modelIdentityText identity
      | otherwise = "source-mismatch"

-- | Recursively consume every View-discovery Human branch.
consumeHumanViews :: HumanViews.HumanViewDiscovery -> Text
consumeHumanViews =
  HumanViews.foldHumanViewDiscovery
    consumeViewDiscoveryFailure
    (\envelope source adapter views ->
       renderMany
         [ "discovered"
         , consumeHumanEnvelope envelope
         , consumeHumanSource source
         , consumeHumanAdapter adapter
         , renderMany (map consumeHumanView views)
         ])

consumeViewDiscoveryFailure :: ViewResult.ViewDiscoveryFailure -> Text
consumeViewDiscoveryFailure =
  ViewResult.foldViewDiscoveryFailure
    (foldAcquisitionFailure $ \input exception ->
       renderMany
         ["acquisition", consumeRawInput input, Text.pack (show exception)])
    (\source selection ->
       renderMany
         [ "selection"
         , consumeRawSource source
         , foldAdapterSelectionError
             (\identifier -> renderMany ["unknown", adapterIdText identifier])
             (\failures ->
                renderMany
                  (map
                     (\(descriptor, diagnostics) ->
                        renderMany
                          [ consumeRawAdapter descriptor
                          , renderMany
                              (map
                                 consumeRawAdapterDiagnostic
                                 (NonEmpty.toList diagnostics))
                          ])
                     (NonEmpty.toList failures)))
             "no-match"
             (renderMany . map consumeRawAdapter . NonEmpty.toList)
             selection
         ])
    (\source adapter diagnostics ->
       renderMany
         [ "decode"
         , consumeRawSource source
         , consumeRawAdapter adapter
         , renderMany
             (map consumeRawAdapterDiagnostic (NonEmpty.toList diagnostics))
         ])

consumeRawInput :: InputSource -> Text
consumeRawInput =
  foldInputSource
    (\reference path ->
       renderMany [sourceReferenceText reference, Text.pack path])
    sourceReferenceText

consumeRawSource :: SourceIdentity -> Text
consumeRawSource =
  foldSourceIdentity $ \role ordinal reference digest ->
    renderMany
      [ Text.pack (show role)
      , renderNatural (sourceOrdinalValue ordinal)
      , sourceReferenceText reference
      , sourceSha256Text digest
      ]

consumeRawAdapter :: AdapterDescriptor -> Text
consumeRawAdapter =
  foldAdapterDescriptor $ \identifier name version notation ->
    renderMany [adapterIdText identifier, name, version, notation]

consumeRawAdapterDiagnostic :: AdapterDiagnostic -> Text
consumeRawAdapterDiagnostic diagnostic =
  renderMany
    [ adapterRuleIdText (adapterRuleId (adapterDiagnosticRule diagnostic))
    , renderMany
        (map
           (foldAdapterOccurrence
              "unavailable"
              (foldNativeLocation
                 (\offset -> renderMany ["byte", renderNatural offset])
                 (\line column ->
                    renderMany
                      ["line-column", renderNatural line, renderNatural column])
                 (renderMany . NonEmpty.toList)))
           (NonEmpty.toList (adapterDiagnosticOccurrences diagnostic)))
    ]

-- | Recursively consume every qualification-subject Human branch.
consumeHumanSubjects :: HumanSubjects.HumanQualificationSubjectsReport -> Text
consumeHumanSubjects =
  HumanSubjects.foldHumanQualificationSubjectsReport
    consumeSubjectsFailure
    (\prerequisite context ->
       renderMany
         [ "prerequisite"
         , SubjectsResult.qualificationSubjectsPrerequisiteText prerequisite
         , consumeHumanSubjectsContext context
         ])
    (\needs strategies context ->
       renderMany
         [ "discovered"
         , renderMany (map consumeHumanSubject needs)
         , renderMany (map consumeHumanSubject strategies)
         , consumeHumanSubjectsContext context
         ])

consumeSubjectsFailure ::
     HumanSubjects.HumanQualificationSubjectsFailure -> Text
consumeSubjectsFailure =
  HumanSubjects.foldHumanQualificationSubjectsFailure
    consumeHumanCommonFailure
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    consumeHumanSource
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    "qualification-context"
    (\occurrence defect -> renderMany [consumeHumanCanonical occurrence, defect])
    (\identity occurrences ->
       renderMany
         [ consumeHumanOccurrence identity
         , renderMany (map consumeHumanCanonical occurrences)
         ])

consumeHumanValidateFailure :: HumanValidate.HumanValidateFailure -> Text
consumeHumanValidateFailure =
  HumanValidate.foldHumanValidateFailure
    consumeHumanCommonFailure
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    consumeHumanSource
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    (renderMany . map consumeHumanOccurrence)

consumeHumanQualifyFailure :: HumanQualify.HumanQualifyFailure -> Text
consumeHumanQualifyFailure =
  HumanQualify.foldHumanQualifyFailure
    consumeHumanCommonFailure
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    consumeHumanSource
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    "qualification-context"

consumeHumanTraceFailure :: HumanTrace.HumanTraceFailure -> Text
consumeHumanTraceFailure =
  HumanTrace.foldHumanTraceFailure
    consumeHumanCommonFailure
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    (renderMany . map consumeHumanOccurrence)

consumeHumanReadinessFailure :: HumanReadiness.HumanReadinessFailure -> Text
consumeHumanReadinessFailure =
  HumanReadiness.foldHumanReadinessFailure
    consumeHumanCommonFailure
    (renderNonEmpty consumeHumanInputDefect)
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    consumeHumanSource
    consumeHumanSource
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    (renderMany . map consumeHumanOccurrence)

consumeHumanAssessFailure :: HumanAssess.HumanAssessFailure -> Text
consumeHumanAssessFailure =
  HumanAssess.foldHumanAssessFailure
    consumeHumanCommonFailure
    (renderNonEmpty consumeHumanInputDefect)
    (renderNonEmpty consumeHumanSupplementalInputDefect)
    consumeHumanSource
    consumeHumanSource
    consumeHumanSource
    consumeHumanAdapter
    consumeHumanNotationContractFailure
    (renderNonEmpty consumeHumanProfileContractEvidence)
    (renderNonEmpty consumeHumanIdentityIndexDefect)
    (renderNonEmpty consumeHumanSelectedViewScopeDefect)
    (renderNonEmpty consumeHumanStructureInputDefect)
    (renderNonEmpty consumeHumanSupplementalProvenanceDefect)
    (renderMany . map consumeHumanOccurrence)

consumeHumanSubjectsContext ::
     HumanSubjects.HumanQualificationSubjectsContext -> Text
consumeHumanSubjectsContext =
  HumanSubjects.foldHumanQualificationSubjectsContext $ \envelope request model supplements view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanSubjects.foldHumanQualificationSubjectsRequest
          (\modelInput viewSelector adapter supplementalInputs ->
             renderMany
               [ consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               , renderMany (map consumeHumanInputSource supplementalInputs)
               ])
          request
      , consumeHumanSource model
      , renderMany (map consumeHumanSource supplements)
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanSubject :: HumanSubjects.HumanQualificationSubject -> Text
consumeHumanSubject =
  HumanSubjects.foldHumanQualificationSubject $ \category identity occurrence qualified display eligibility ->
    renderMany
      [ SubjectsResult.qualificationSubjectCategoryText category
      , consumeHumanModel identity
      , consumeHumanOccurrence occurrence
      , consumeHumanQualifiedType qualified
      , maybe "no-display-name" id display
      , SubjectsResult.qualificationSubjectEligibilityText eligibility
      ]

-- | Recursively consume every Validate Human branch.
consumeHumanValidate :: HumanValidate.HumanValidateReport -> Text
consumeHumanValidate =
  HumanValidate.foldHumanValidateReport
    consumeHumanValidateFailure
    (\context -> renderMany ["accepted", consumeHumanValidateContext context])
    (\context -> renderMany ["rejected", consumeHumanValidateContext context])
    (\witnesses context ->
       renderMany
         [ "unavailable"
         , renderMany
             (map consumeHumanValidateUnavailable (NonEmpty.toList witnesses))
         , consumeHumanValidateContext context
         ])

consumeHumanValidateContext :: HumanValidate.HumanValidateContext -> Text
consumeHumanValidateContext =
  HumanValidate.foldHumanValidateContext $ \envelope request completed model supplements view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanValidate.foldHumanValidateRequest
          (\level modelInput viewSelector adapter supplementalInputs ->
             renderMany
               [ validationLevelText level
               , consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               , renderMany (map consumeHumanInputSource supplementalInputs)
               ])
          request
      , validationLevelText completed
      , consumeHumanSource model
      , renderMany (map consumeHumanSource supplements)
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanValidateUnavailable ::
     HumanValidate.HumanValidateUnavailability -> Text
consumeHumanValidateUnavailable =
  HumanValidate.foldHumanValidateUnavailability
    (\ordinal -> renderMany ["binding", renderNatural ordinal])
    (\subject reason ->
       renderMany ["strategy", consumeHumanModel subject, reason])
    (\subject reasons blockers ->
       renderMany
         [ "fit"
         , consumeHumanModel subject
         , renderMany (NonEmpty.toList reasons)
         , renderMany (map consumeHumanModel blockers)
         ])
    (\subject blockers ->
       renderMany
         [ "coverage"
         , consumeHumanModel subject
         , renderMany (map consumeHumanModel blockers)
         ])
    (\subject participant reasons blockers ->
       renderMany
         [ "primitive"
         , consumeHumanModel subject
         , consumeHumanModel participant
         , renderMany (NonEmpty.toList reasons)
         , renderMany (map consumeHumanModel blockers)
         ])

-- | Recursively consume every Qualify Human branch.
consumeHumanQualify :: HumanQualify.HumanQualifyReport -> Text
consumeHumanQualify =
  HumanQualify.foldHumanQualifyReport
    consumeHumanQualifyFailure
    (\prerequisite context ->
       renderMany
         [ "prerequisite"
         , qualifyPrerequisiteText prerequisite
         , consumeHumanQualifyContext context
         ])
    (\assessment context ->
       renderMany
         [ "completed"
         , consumeHumanQualificationAssessment assessment
         , consumeHumanQualifyContext context
         ])

consumeHumanQualifyContext :: HumanQualify.HumanQualifyContext -> Text
consumeHumanQualifyContext =
  HumanQualify.foldHumanQualifyContext $ \envelope request model supplements view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanQualify.foldHumanQualifyRequest
          (\modelInput viewSelector adapter strategies needs supplementalInputs ->
             renderMany
               [ consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               , renderMany (map consumeHumanModel (NonEmpty.toList strategies))
               , renderMany (map consumeHumanModel needs)
               , renderMany (map consumeHumanInputSource supplementalInputs)
               ])
          request
      , consumeHumanSource model
      , renderMany (map consumeHumanSource supplements)
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanQualificationSubjectValue ::
     HumanQualify.HumanQualificationSubjectValue -> Text
consumeHumanQualificationSubjectValue =
  HumanQualify.foldHumanQualificationSubjectValue
    (\label value -> renderMany ["model", label, consumeHumanModel value])
    (\label value ->
       renderMany ["occurrence", label, consumeHumanOccurrence value])
    (\label value -> renderMany ["role", label, value])
    (\label value -> renderMany ["text", label, value])

consumeHumanQualificationOccurrenceGroup ::
     HumanQualify.HumanQualificationOccurrenceGroup -> Text
consumeHumanQualificationOccurrenceGroup =
  HumanQualify.foldHumanQualificationOccurrenceGroup $ \role occurrences ->
    renderMany [role, renderMany (map consumeHumanOccurrence occurrences)]

consumeHumanQualificationDiagnostic ::
     HumanQualify.HumanQualificationDiagnostic -> Text
consumeHumanQualificationDiagnostic =
  HumanQualify.foldHumanQualificationDiagnostic $ \rule kind subjects groups ->
    renderMany
      [ rule
      , kind
      , renderMany
          (map consumeHumanQualificationSubjectValue (NonEmpty.toList subjects))
      , renderMany
          (map consumeHumanQualificationOccurrenceGroup (NonEmpty.toList groups))
      ]

consumeHumanAdmissibleProposal :: HumanQualify.HumanAdmissibleProposal -> Text
consumeHumanAdmissibleProposal =
  HumanQualify.foldHumanAdmissibleProposal $ \proposal occurrence need strategy keyResult objective rationale sources witnesses ->
    renderMany
      [ consumeHumanModel proposal
      , consumeHumanOccurrence occurrence
      , consumeHumanModel need
      , consumeHumanModel strategy
      , consumeHumanModel keyResult
      , consumeHumanModel objective
      , rationale
      , renderMany (NonEmpty.toList sources)
      , renderMany (map consumeHumanOccurrence witnesses)
      ]

consumeHumanQualificationProposal ::
     HumanQualify.HumanQualificationProposal -> Text
consumeHumanQualificationProposal =
  HumanQualify.foldHumanQualificationProposal $ \identity occurrence disposition diagnostics admissible ->
    renderMany
      [ consumeHumanModel identity
      , consumeHumanOccurrence occurrence
      , disposition
      , renderMany (map consumeHumanQualificationDiagnostic diagnostics)
      , maybe "not-admissible" consumeHumanAdmissibleProposal admissible
      ]

consumeHumanQualificationPair :: HumanQualify.HumanQualificationPair -> Text
consumeHumanQualificationPair =
  HumanQualify.foldHumanQualificationPair $ \need strategy disposition diagnostics proposals ->
    renderMany
      [ consumeHumanModel need
      , consumeHumanModel strategy
      , disposition
      , renderMany (map consumeHumanQualificationDiagnostic diagnostics)
      , renderMany (map consumeHumanQualificationProposal proposals)
      ]

consumeHumanQualificationUnavailable ::
     HumanQualify.HumanQualificationUnavailable -> Text
consumeHumanQualificationUnavailable =
  HumanQualify.foldHumanQualificationUnavailable $ \category identity reason occurrences ->
    renderMany
      [ category
      , consumeHumanModel identity
      , reason
      , renderMany (map consumeHumanOccurrence occurrences)
      ]

consumeHumanQualificationAssessment ::
     HumanQualify.HumanQualificationAssessment -> Text
consumeHumanQualificationAssessment =
  HumanQualify.foldHumanQualificationAssessment $ \graph disposition needs strategies unavailable unrouted pairs ->
    renderMany
      [ consumeHumanModel graph
      , disposition
      , renderMany (map consumeHumanModel needs)
      , renderMany (map consumeHumanModel strategies)
      , renderMany (map consumeHumanQualificationUnavailable unavailable)
      , renderMany (map consumeHumanQualificationProposal unrouted)
      , renderMany (map consumeHumanQualificationPair pairs)
      ]

-- | Recursively consume every Trace Human branch and nested value.
consumeHumanTrace :: HumanTrace.HumanTraceReport -> Text
consumeHumanTrace =
  HumanTrace.foldHumanTraceReport
    consumeHumanTraceFailure
    (\prerequisite context ->
       renderMany
         [ TraceResult.tracePrerequisiteText prerequisite
         , consumeHumanTraceContext context
         ])
    (\assessment context ->
       renderMany
         [ "rejected"
         , consumeHumanTraceAssessment assessment
         , consumeHumanTraceContext context
         ])
    (\assessment context ->
       renderMany
         [ "accepted"
         , consumeHumanTraceAssessment assessment
         , consumeHumanTraceContext context
         ])

consumeHumanTraceContext :: HumanTrace.HumanTraceContext -> Text
consumeHumanTraceContext =
  HumanTrace.foldHumanTraceContext $ \envelope request model view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanTrace.foldHumanTraceRequest
          (\modelInput viewSelector adapter ->
             renderMany
               [ consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               ])
          request
      , consumeHumanSource model
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanTraceAssessment :: HumanTrace.HumanTraceAssessment -> Text
consumeHumanTraceAssessment =
  HumanTrace.foldHumanTraceAssessment $ \graph roots ->
    renderMany
      [consumeHumanModel graph, renderMany (map consumeHumanRootTrace roots)]

consumeHumanRootTrace :: HumanTrace.HumanRootTrace -> Text
consumeHumanRootTrace =
  HumanTrace.foldHumanRootTrace $ \graph intervention need support result ->
    renderMany
      [ consumeHumanModel graph
      , consumeHumanModel intervention
      , consumeHumanModel need
      , renderNonEmpty consumeHumanOccurrence support
      , consumeHumanRootTraceResult result
      ]

consumeHumanRootTraceResult :: HumanTrace.HumanRootTraceResult -> Text
consumeHumanRootTraceResult =
  HumanTrace.foldHumanRootTraceResult
    (\identity relations ownership ->
       renderMany
         [ "complete"
         , consumeHumanTraceIdentity identity
         , renderMany (map consumeHumanTraceSupport relations)
         , renderMany (map consumeHumanTraceSupport ownership)
         ])
    (\projections relations ownership gaps ->
       renderMany
         [ "partial"
         , renderMany (map consumeHumanTraceProjection projections)
         , renderMany (map consumeHumanTraceSupport relations)
         , renderMany (map consumeHumanTraceSupport ownership)
         , renderNonEmpty consumeHumanTraceGap gaps
         ])

consumeHumanTraceSupport :: HumanTrace.HumanTraceSupport -> Text
consumeHumanTraceSupport =
  HumanTrace.foldHumanTraceSupport $ \slot occurrences ->
    renderMany
      [ consumeHumanTraceSlot slot
      , renderMany (map consumeHumanOccurrence occurrences)
      ]

consumeHumanTraceSlot :: HumanTrace.HumanTraceSlot -> Text
consumeHumanTraceSlot =
  HumanTrace.foldHumanTraceSlot $ \kind identifier rule ->
    renderMany [kind, identifier, rule]

consumeHumanTraceProjection :: HumanTrace.HumanTraceProjection -> Text
consumeHumanTraceProjection =
  HumanTrace.foldHumanTraceProjection $ \variable identities ->
    renderMany [variable, renderMany (map consumeHumanModel identities)]

consumeHumanTraceGap :: HumanTrace.HumanTraceGap -> Text
consumeHumanTraceGap =
  HumanTrace.foldHumanTraceGap
    (\slot source target disposition ->
       renderMany
         [ "bound"
         , consumeHumanTraceSlot slot
         , consumeHumanTraceBinding source
         , consumeHumanTraceBinding target
         , disposition
         ])
    (\slot established unresolved disposition ->
       renderMany
         [ "unbound"
         , consumeHumanTraceSlot slot
         , renderMany (map consumeHumanTraceBinding established)
         , renderMany (NonEmpty.toList unresolved)
         , disposition
         ])
    (\slots disposition ->
       renderMany
         ["global", renderNonEmpty consumeHumanTraceSlot slots, disposition])

-- | Recursively consume every Readiness Human branch and nested value.
consumeHumanReadiness :: HumanReadiness.HumanReadinessReport -> Text
consumeHumanReadiness =
  HumanReadiness.foldHumanReadinessReport
    consumeHumanReadinessFailure
    (\prerequisite context ->
       renderMany
         [ readinessPrerequisiteText prerequisite
         , consumeHumanReadinessContext context
         ])
    (\unavailable context ->
       renderMany
         [ "unavailable"
         , consumeHumanReadinessUnavailable unavailable
         , consumeHumanReadinessContext context
         ])
    (\assessment context ->
       renderMany
         [ "not-ready"
         , consumeHumanReadinessAssessment assessment
         , consumeHumanReadinessContext context
         ])
    (\assessment context ->
       renderMany
         [ "ready"
         , consumeHumanReadinessAssessment assessment
         , consumeHumanReadinessContext context
         ])

consumeHumanReadinessContext :: HumanReadiness.HumanReadinessContext -> Text
consumeHumanReadinessContext =
  HumanReadiness.foldHumanReadinessContext $ \envelope request model evidence supplements view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanReadiness.foldHumanReadinessRequest
          (\modelInput viewSelector adapter evidenceInput supplementalInputs ->
             renderMany
               [ consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               , consumeHumanInputSource evidenceInput
               , renderMany (map consumeHumanInputSource supplementalInputs)
               ])
          request
      , consumeHumanSource model
      , maybe "no-evidence-source" consumeHumanSource evidence
      , renderMany (map consumeHumanSource supplements)
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanReadinessUnavailable ::
     HumanReadiness.HumanReadinessUnavailable -> Text
consumeHumanReadinessUnavailable =
  HumanReadiness.foldHumanReadinessUnavailable
    (\trace diagnostics ->
       renderMany
         [ "binding"
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanEvidenceInputDiagnostic diagnostics
         ])
    (\graph trace reasons ->
       renderMany
         [ "reconstruction"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanReadinessUnavailableReason reasons
         ])

consumeHumanEvidenceInputDiagnostic ::
     HumanReadiness.HumanEvidenceInputDiagnostic -> Text
consumeHumanEvidenceInputDiagnostic =
  HumanReadiness.foldHumanEvidenceInputDiagnostic $ \rule reason pointer subjects ->
    renderMany
      [ rule
      , reason
      , pointer
      , renderNonEmpty consumeHumanEvidenceInputSubject subjects
      ]

consumeHumanEvidenceInputSubject ::
     HumanReadiness.HumanEvidenceInputSubject -> Text
consumeHumanEvidenceInputSubject =
  HumanReadiness.foldHumanEvidenceInputSubject
    (\label value -> renderMany ["text", label, value])
    (\label value -> renderMany ["natural", label, renderNatural value])
    (\label value -> renderMany ["model", label, consumeHumanModel value])
    (\label value ->
       renderMany ["occurrence", label, consumeHumanOccurrence value])
    (\label value ->
       renderMany ["qualified-type", label, consumeHumanQualifiedType value])

consumeHumanReadinessUnavailableReason ::
     HumanReadiness.HumanReadinessUnavailableReason -> Text
consumeHumanReadinessUnavailableReason =
  HumanReadiness.foldHumanReadinessUnavailableReason
    (\expected supplied ->
       renderMany
         [ "graph-mismatch"
         , consumeHumanModel expected
         , consumeHumanModel supplied
         ])
    (\kind identifier rule source target disposition ->
       renderMany
         [ "slot-unsupported"
         , kind
         , identifier
         , rule
         , consumeHumanTraceBinding source
         , consumeHumanTraceBinding target
         , disposition
         ])
    (\reason -> renderMany ["promotion-unavailable", reason])

consumeHumanReadinessAssessment ::
     HumanReadiness.HumanReadinessAssessment -> Text
consumeHumanReadinessAssessment =
  HumanReadiness.foldHumanReadinessAssessment
    (\graph trace diagnostics ->
       renderMany
         [ "not-ready"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanReadinessDiagnostic diagnostics
         ])
    (\graph trace ->
       renderMany
         ["ready", consumeHumanModel graph, consumeHumanTraceIdentity trace])

consumeHumanReadinessDiagnostic ::
     HumanReadiness.HumanReadinessDiagnostic -> Text
consumeHumanReadinessDiagnostic =
  HumanReadiness.foldHumanReadinessDiagnostic $ \rule key ->
    renderMany [rule, consumeHumanReadinessEvidenceKey key]

consumeHumanReadinessEvidenceKey ::
     HumanReadiness.HumanReadinessEvidenceKey -> Text
consumeHumanReadinessEvidenceKey =
  HumanReadiness.foldHumanReadinessEvidenceKey
    (\graph trace ->
       renderMany
         ["subject", consumeHumanModel graph, consumeHumanTraceIdentity trace])
    (\identity -> renderMany ["kpi-definition", consumeHumanModel identity])
    (\identity -> renderMany ["planned-start", consumeHumanModel identity])
    (\trace -> renderMany ["evidence-plan", consumeHumanTraceIdentity trace])

-- | Recursively consume every Assess Human branch and nested value.
consumeHumanAssess :: HumanAssess.HumanAssessReport -> Text
consumeHumanAssess =
  HumanAssess.foldHumanAssessReport
    consumeHumanAssessFailure
    (\prerequisite context ->
       renderMany
         [ assessPrerequisiteText prerequisite
         , consumeHumanAssessContext context
         ])
    (\unavailable context ->
       renderMany
         [ "unavailable"
         , consumeHumanAssessUnavailable unavailable
         , consumeHumanAssessContext context
         ])
    (\result context ->
       renderMany
         [ "collection-invalid"
         , consumeHumanAssessmentResult result
         , consumeHumanAssessContext context
         ])
    (\result context ->
       renderMany
         [ "observations-invalid"
         , consumeHumanAssessmentResult result
         , consumeHumanAssessContext context
         ])
    (\result context ->
       renderMany
         [ "completed"
         , consumeHumanAssessmentResult result
         , consumeHumanAssessContext context
         ])

consumeHumanAssessContext :: HumanAssess.HumanAssessContext -> Text
consumeHumanAssessContext =
  HumanAssess.foldHumanAssessContext $ \envelope request model bundle supplements view diagnostics ->
    renderMany
      [ consumeHumanEnvelope envelope
      , HumanAssess.foldHumanAssessRequest
          (\modelInput viewSelector adapter bundleInput supplementalInputs ->
             renderMany
               [ consumeHumanInputSource modelInput
               , consumeHumanViewSelector viewSelector
               , consumeHumanAdapterSelection adapter
               , consumeHumanInputSource bundleInput
               , renderMany (map consumeHumanInputSource supplementalInputs)
               ])
          request
      , consumeHumanSource model
      , maybe "no-assessment-source" consumeHumanSource bundle
      , renderMany (map consumeHumanSource supplements)
      , consumeHumanView view
      , consumeHumanDiagnosticDocument diagnostics
      ]

consumeHumanAssessUnavailable :: HumanAssess.HumanAssessUnavailable -> Text
consumeHumanAssessUnavailable =
  HumanAssess.foldHumanAssessUnavailable
    (\trace diagnostics ->
       renderMany
         [ "binding"
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanAssessmentInputDiagnostic diagnostics
         ])
    (\graph trace reasons ->
       renderMany
         [ "reconstruction"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanAssessmentUnavailableReason reasons
         ])

consumeHumanAssessmentInputDiagnostic ::
     HumanAssess.HumanAssessmentInputDiagnostic -> Text
consumeHumanAssessmentInputDiagnostic =
  HumanAssess.foldHumanAssessmentInputDiagnostic $ \rule reason pointer subjects ->
    renderMany
      [ rule
      , reason
      , pointer
      , renderNonEmpty consumeHumanAssessmentSubject subjects
      ]

consumeHumanAssessmentSubject :: HumanAssess.HumanAssessmentSubjectValue -> Text
consumeHumanAssessmentSubject =
  HumanAssess.foldHumanAssessmentSubjectValue
    (\label value -> renderMany ["text", label, value])
    (\label value -> renderMany ["natural", label, renderNatural value])
    (\label value -> renderMany ["model", label, consumeHumanModel value])
    (\label value ->
       renderMany ["occurrence", label, consumeHumanOccurrence value])
    (\label value ->
       renderMany ["qualified-type", label, consumeHumanQualifiedType value])

consumeHumanAssessmentUnavailableReason ::
     HumanAssess.HumanAssessmentUnavailableReason -> Text
consumeHumanAssessmentUnavailableReason =
  HumanAssess.foldHumanAssessmentUnavailableReason
    (\expected supplied ->
       renderMany
         [ "graph-mismatch"
         , consumeHumanModel expected
         , consumeHumanModel supplied
         ])
    (\kind identifier rule source target disposition ->
       renderMany
         [ "slot-unsupported"
         , kind
         , identifier
         , rule
         , consumeHumanTraceBinding source
         , consumeHumanTraceBinding target
         , disposition
         ])
    (\reason -> renderMany ["promotion-unavailable", reason])
    (\rule key ->
       renderMany
         ["readiness-unavailable", rule, consumeHumanAssessmentReadinessKey key])

consumeHumanAssessmentReadinessKey ::
     HumanAssess.HumanAssessmentReadinessKey -> Text
consumeHumanAssessmentReadinessKey =
  HumanAssess.foldHumanAssessmentReadinessKey
    (\graph trace ->
       renderMany
         ["subject", consumeHumanModel graph, consumeHumanTraceIdentity trace])
    (\identity -> renderMany ["kpi-definition", consumeHumanModel identity])
    (\identity -> renderMany ["planned-start", consumeHumanModel identity])
    (\trace -> renderMany ["evidence-plan", consumeHumanTraceIdentity trace])

consumeHumanAssessmentResult :: HumanAssess.HumanAssessmentResult -> Text
consumeHumanAssessmentResult =
  HumanAssess.foldHumanAssessmentResult
    (\graph trace diagnostics ->
       renderMany
         [ "collection-invalid"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         , renderNonEmpty consumeHumanAssessmentDiagnostic diagnostics
         ])
    (\graph trace observations proof ->
       renderMany
         [ "observations"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         , renderMany (map consumeHumanObservationAssessment observations)
         , maybe "no-proof" consumeHumanEvidenceAssessedProof proof
         ])

consumeHumanAssessmentDiagnostic ::
     HumanAssess.HumanAssessmentDiagnostic -> Text
consumeHumanAssessmentDiagnostic =
  HumanAssess.foldHumanAssessmentDiagnostic $ \rule key ->
    renderMany [rule, consumeHumanAssessmentEvidenceKey key]

consumeHumanAssessmentEvidenceKey ::
     HumanAssess.HumanAssessmentEvidenceKey -> Text
consumeHumanAssessmentEvidenceKey =
  HumanAssess.foldHumanAssessmentEvidenceKey
    (\graph trace ->
       renderMany
         ["subject", consumeHumanModel graph, consumeHumanTraceIdentity trace])
    (\identity -> renderMany ["actual-start", consumeHumanModel identity])
    (\graph trace ->
       renderMany
         [ "observation-set"
         , consumeHumanModel graph
         , consumeHumanTraceIdentity trace
         ])
    (\trace observedAt ->
       renderMany ["observation", consumeHumanTraceIdentity trace, observedAt])

consumeHumanObservationAssessment ::
     HumanAssess.HumanObservationAssessment -> Text
consumeHumanObservationAssessment =
  HumanAssess.foldHumanObservationAssessment
    (\observation diagnostics ->
       renderMany
         [ "invalid"
         , consumeHumanObservation observation
         , renderNonEmpty consumeHumanAssessmentDiagnostic diagnostics
         ])
    (\observation effect target limitations ->
       renderMany
         [ "assessed"
         , consumeHumanObservation observation
         , effect
         , target
         , renderMany (NonEmpty.toList limitations)
         ])

consumeHumanObservation :: HumanAssess.HumanObservation -> Text
consumeHumanObservation =
  HumanAssess.foldHumanObservation $ \ordinal trace observedAt source value ->
    renderMany
      [ renderNatural ordinal
      , consumeHumanTraceIdentity trace
      , observedAt
      , source
      , HumanAssess.foldHumanDomainValue
          (\retained unit -> renderMany ["quantitative", retained, unit])
          (\scale level -> renderMany ["ordinal", scale, level])
          (\retained -> renderMany ["categorical", retained])
          value
      ]

consumeHumanEvidenceAssessedProof ::
     HumanAssess.HumanEvidenceAssessedProof -> Text
consumeHumanEvidenceAssessedProof =
  HumanAssess.foldHumanEvidenceAssessedProof $ \graph trace count ->
    renderMany
      [ consumeHumanModel graph
      , consumeHumanTraceIdentity trace
      , renderNatural count
      ]

consumeHumanCommonFailure :: HumanFailure.HumanCommonFailure -> Text
consumeHumanCommonFailure =
  HumanFailure.foldHumanCommonFailure
    (\code source exception ->
       renderMany
         [code, consumeHumanInputSource source, Text.pack (show exception)])
    consumeHumanPreparationFailure

consumeHumanPreparationFailure :: HumanFailure.HumanPreparationFailure -> Text
consumeHumanPreparationFailure =
  HumanFailure.foldHumanPreparationFailure
    (\code failure ->
       renderMany [code, consumeHumanAdapterSelectionFailure failure])
    (\code adapter diagnostics ->
       renderMany
         [ code
         , consumeHumanAdapter adapter
         , renderNonEmpty consumeHumanFailureAdapterDiagnostic diagnostics
         ])
    (\code candidates ->
       renderMany
         [code, renderMany (map consumeHumanMarkerCandidate candidates)])
    (\code failure ->
       renderMany [code, consumeHumanProfileResolutionFailure failure])
    (\code failure ->
       renderMany [code, consumeHumanProfileCompatibilityFailure failure])
    (\code failure ->
       renderMany [code, consumeHumanViewSelectionFailure failure])

consumeHumanAdapterSelectionFailure ::
     HumanFailure.HumanAdapterSelectionFailure -> Text
consumeHumanAdapterSelectionFailure =
  HumanFailure.foldHumanAdapterSelectionFailure
    (\identifier -> renderMany ["unknown", identifier])
    (\failures ->
       renderNonEmpty
         (\(adapter, diagnostics) ->
            renderMany
              [ consumeHumanAdapter adapter
              , renderNonEmpty consumeHumanFailureAdapterDiagnostic diagnostics
              ])
         failures)
    "no-match"
    (renderNonEmpty consumeHumanAdapter)

consumeHumanFailureAdapterDiagnostic ::
     HumanFailure.HumanFailureAdapterDiagnostic -> Text
consumeHumanFailureAdapterDiagnostic =
  HumanFailure.foldHumanFailureAdapterDiagnostic $ \rule occurrences ->
    renderMany
      [ HumanFailure.foldHumanFailureAdapterRule
          (\identity stage expectation meaning action ->
             renderMany
               [ identity
               , HumanFailure.foldHumanFailureAdapterRuleStage
                   "preparation"
                   "notation"
                   stage
               , expectation
               , meaning
               , action
               ])
          rule
      , renderNonEmpty consumeHumanFailureAdapterOccurrence occurrences
      ]

consumeHumanFailureAdapterOccurrence ::
     HumanFailure.HumanFailureAdapterOccurrence -> Text
consumeHumanFailureAdapterOccurrence =
  HumanFailure.foldHumanFailureAdapterOccurrence $ \location ->
    maybe
      "unavailable"
      (HumanFailure.foldHumanFailureNativeLocation
         (\offset -> renderMany ["byte", renderNatural offset])
         (\line column ->
            renderMany ["line-column", renderNatural line, renderNatural column])
         (renderMany . NonEmpty.toList))
      location

consumeHumanProfileResolutionFailure ::
     HumanFailure.HumanProfileResolutionFailure -> Text
consumeHumanProfileResolutionFailure =
  HumanFailure.foldHumanProfileResolutionFailure
    (\rule key -> renderMany ["missing", rule, key])
    (\rule key properties ->
       renderMany
         [ "property-multiplicity"
         , rule
         , key
         , renderMany (map consumeHumanFailureCanonicalProperty properties)
         ])
    (\rule key property values ->
       renderMany
         [ "value-multiplicity"
         , rule
         , key
         , consumeHumanFailureCanonicalProperty property
         , renderMany (map consumeHumanDraftScalar values)
         ])
    (\rule key scalar kind ->
       renderMany
         [ "value-kind"
         , rule
         , key
         , consumeHumanDraftScalar scalar
         , HumanFailure.foldHumanFailureDraftValueKind
             "text"
             "boolean"
             "number"
             "native-name"
             ("other:" <>)
             kind
         ])
    (\rule key scalar ->
       renderMany ["grammar", rule, key, consumeHumanDraftScalar scalar])
    (\rule key reference -> renderMany ["unknown", rule, key, reference])

consumeHumanProfileCompatibilityFailure ::
     HumanFailure.HumanProfileCompatibilityFailure -> Text
consumeHumanProfileCompatibilityFailure =
  HumanFailure.foldHumanProfileCompatibilityFailure
    (\rule profile adapter admitted ->
       renderMany
         [ "adapter-not-admitted"
         , rule
         , consumeHumanProfile profile
         , consumeHumanAdapter adapter
         , renderMany admitted
         ])
    (\rule profile adapter profileNotation adapterNotation ->
       renderMany
         [ "notation-mismatch"
         , rule
         , consumeHumanProfile profile
         , consumeHumanAdapter adapter
         , profileNotation
         , adapterNotation
         ])

consumeHumanViewSelectionFailure ::
     HumanFailure.HumanViewSelectionFailure -> Text
consumeHumanViewSelectionFailure =
  HumanFailure.foldHumanViewSelectionFailure
    (\selector -> renderMany ["unknown", consumeHumanViewSelector selector])
    (\selector candidates ->
       renderMany
         [ "name-ambiguous"
         , consumeHumanViewSelector selector
         , renderNonEmpty consumeHumanView candidates
         ])
    (\selector candidates ->
       renderMany
         [ "identity-ambiguous"
         , consumeHumanViewSelector selector
         , renderNonEmpty consumeHumanViewSelectionCandidate candidates
         ])
    (\selector candidate ->
       renderMany
         [ "wrong-family"
         , consumeHumanViewSelector selector
         , consumeHumanViewSelectionCandidate candidate
         ])

consumeHumanViewSelectionCandidate ::
     HumanFailure.HumanFailureViewSelectionCandidate -> Text
consumeHumanViewSelectionCandidate =
  HumanFailure.foldHumanFailureViewSelectionCandidate $ \occurrence family identity location ->
    renderMany
      [ consumeHumanCanonical occurrence
      , consumeHumanFailureRecordFamily family
      , maybe "no-identity" consumeHumanModel identity
      , consumeHumanLocation location
      ]

consumeHumanFailureRecordFamily :: HumanFailure.HumanFailureRecordFamily -> Text
consumeHumanFailureRecordFamily =
  HumanFailure.foldHumanFailureRecordFamily
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

consumeHumanMarkerCandidate :: HumanFailure.HumanFailureMarkerCandidate -> Text
consumeHumanMarkerCandidate =
  HumanFailure.foldHumanFailureMarkerCandidate $ \property fields outcome ->
    renderMany
      [ consumeHumanFailureCanonicalProperty property
      , renderMany (map consumeHumanCanonicalField fields)
      , HumanFailure.foldHumanFailureMarkerKeyOutcome
          "missing"
          (\values ->
             renderMany ("multiple" : map consumeHumanDraftScalar values))
          (\value -> renderMany ["non-text", consumeHumanDraftScalar value])
          (\value -> renderMany ["exact", consumeHumanDraftScalar value])
          (\value -> renderMany ["other", consumeHumanDraftScalar value])
          (\reference ->
             renderMany
               [ "reference-rejected"
               , consumeHumanFailureCanonicalReference reference
               ])
          outcome
      ]

consumeHumanFailureCanonicalProperty ::
     HumanFailure.HumanFailureCanonicalProperty -> Text
consumeHumanFailureCanonicalProperty =
  HumanFailure.foldHumanFailureCanonicalProperty $ \occurrence owner family location values opaque key ->
    renderMany
      [ consumeHumanCanonical occurrence
      , consumeHumanCanonical owner
      , consumeHumanFailureRecordFamily family
      , consumeHumanLocation location
      , renderMany (map consumeHumanDraftScalar values)
      , renderMany (map consumeHumanFailureOpaqueEvidence opaque)
      , HumanFailure.foldHumanFailurePropertyKey
          (\direct -> renderMany ("direct" : map consumeHumanDraftScalar direct))
          (\reference ->
             renderMany
               ["referenced", consumeHumanFailureCanonicalReference reference])
          key
      ]

consumeHumanFailureOpaqueEvidence ::
     HumanFailure.HumanFailureOpaqueEvidence -> Text
consumeHumanFailureOpaqueEvidence =
  HumanFailure.foldHumanFailureOpaqueEvidence $ \position namespace localName values location ->
    renderMany
      [ HumanFailure.foldHumanFailureOpaquePosition "attribute" "child" position
      , maybe "no-namespace" id namespace
      , localName
      , renderMany (map consumeHumanDraftScalar values)
      , consumeHumanLocation location
      ]

consumeHumanFailureCanonicalReference ::
     HumanFailure.HumanFailureCanonicalReference -> Text
consumeHumanFailureCanonicalReference =
  HumanFailure.foldHumanFailureCanonicalReference $ \occurrence owner field family location outcome ->
    renderMany
      [ consumeHumanCanonical occurrence
      , consumeHumanCanonical owner
      , HumanFailure.foldHumanFailureReferenceField
          "property-definition"
          "relationship-source"
          "relationship-target"
          "view-node-element"
          "view-connection-relationship"
          "view-connection-source"
          "view-connection-target"
          field
      , consumeHumanFailureRecordFamily family
      , consumeHumanLocation location
      , consumeHumanFailureReferenceOutcome outcome
      ]

consumeHumanFailureReferenceOutcome ::
     HumanFailure.HumanFailureReferenceOutcome -> Text
consumeHumanFailureReferenceOutcome =
  HumanFailure.foldHumanFailureReferenceOutcome
    (\identity ->
       renderMany ["identity-invalid", consumeHumanIdentityOutcome identity])
    (\scalar identity ->
       renderMany
         [ "target-missing"
         , consumeHumanDraftScalar scalar
         , consumeHumanModel identity
         ])
    (\scalar identity family targets ->
       renderMany
         [ "wrong-family"
         , consumeHumanDraftScalar scalar
         , consumeHumanModel identity
         , consumeHumanFailureRecordFamily family
         , renderMany (map consumeHumanFailureCanonicalTarget targets)
         ])
    (\scalar identity family targets ->
       renderMany
         [ "expected-family-ambiguous"
         , consumeHumanDraftScalar scalar
         , consumeHumanModel identity
         , consumeHumanFailureRecordFamily family
         , renderMany (map consumeHumanFailureCanonicalTarget targets)
         ])
    (\scalar identity target ->
       renderMany
         [ "resolved"
         , consumeHumanDraftScalar scalar
         , consumeHumanModel identity
         , consumeHumanFailureCanonicalTarget target
         ])

consumeHumanFailureCanonicalTarget ::
     HumanFailure.HumanFailureCanonicalTarget -> Text
consumeHumanFailureCanonicalTarget =
  HumanFailure.foldHumanFailureCanonicalTarget $ \occurrence family identity location fields ->
    renderMany
      [ consumeHumanCanonical occurrence
      , consumeHumanFailureRecordFamily family
      , consumeHumanModel identity
      , consumeHumanLocation location
      , renderMany (map consumeHumanCanonicalField fields)
      ]

consumeHumanInputDefect :: HumanFailure.HumanInputDefect -> Text
consumeHumanInputDefect =
  HumanFailure.foldHumanInputDefect $ \rule ordinal kind pointer subjects ->
    renderMany
      [ rule
      , renderNatural ordinal
      , HumanFailure.foldHumanInputDefectKind
          "invalid-utf8"
          "invalid-json-syntax"
          "duplicate-object-member"
          "top-level-object-required"
          "discriminator-invalid"
          "required-member-missing"
          "unknown-member"
          "value-kind-invalid"
          "scalar-grammar-invalid"
          "array-cardinality-invalid"
          "array-distinctness-invalid"
          "normalization-collision"
          "model-identity-unicode-scalar-invalid"
          "model-identity-contains-nul"
          "identity-unknown"
          "identity-ambiguous"
          "identity-out-of-selected-view"
          "identity-wrong-type"
          kind
      , pointer
      , renderNonEmpty consumeHumanInputDefectSubject subjects
      ]

consumeHumanInputDefectSubject :: HumanFailure.HumanInputDefectSubject -> Text
consumeHumanInputDefectSubject =
  HumanFailure.foldHumanInputDefectSubject
    (\label value -> renderMany ["text", label, value])
    (\label value -> renderMany ["natural", label, renderNatural value])
    (\label value -> renderMany ["model", label, consumeHumanModel value])
    (\label value ->
       renderMany ["occurrence", label, consumeHumanOccurrence value])
    (\label value ->
       renderMany ["qualified-type", label, consumeHumanQualifiedType value])

consumeHumanSupplementalInputDefect ::
     HumanFailure.HumanSupplementalInputDefect -> Text
consumeHumanSupplementalInputDefect =
  HumanFailure.foldHumanSupplementalInputDefect
    (sourceOrdinal "invalid-utf8")
    (sourceOrdinal "invalid-json-syntax")
    (sourceOrdinalText "duplicate-object-member")
    (sourceOrdinalTwoTexts "top-level-object-required")
    (sourceOrdinalTwoTexts "type-member-invalid")
    (sourceOrdinalTwoTexts "payload-type-not-admitted")
    (sourceOrdinalTwoTexts "required-member-missing")
    (sourceOrdinalTwoTexts "unknown-member")
    (sourceOrdinalTwoTexts "value-kind-invalid")
    (sourceOrdinalTwoTexts "scalar-grammar-invalid")
    (sourceOrdinalTwoTexts "array-cardinality-invalid")
    (sourceOrdinalTwoTexts "array-distinctness-invalid")
    (\rule ordinals payload subject ->
       renderMany
         [ "subject-cardinality-invalid"
         , rule
         , renderMany (map renderNatural (NonEmpty.toList ordinals))
         , HumanFailure.foldHumanSupplementalPayloadType
             "strategy-formulation"
             "collective-fit"
             payload
         , consumeHumanModel subject
         ])
    (sourceOrdinalIdentity "identity-unknown")
    (sourceOrdinalIdentity "identity-ambiguous")
    (sourceOrdinalIdentity "identity-wrong-type")
    (sourceOrdinalIdentity "identity-out-of-selected-view")
    (\rule ordinal pointer expected occurrences ->
       renderMany
         [ "model-identity-unicode-scalar-invalid"
         , rule
         , renderNatural ordinal
         , pointer
         , expected
         , renderNonEmpty
             (\(index, codePoint) ->
                renderMany [renderNatural index, renderNatural codePoint])
             occurrences
         ])
    (\rule ordinal pointer expected indexes ->
       renderMany
         [ "model-identity-contains-nul"
         , rule
         , renderNatural ordinal
         , pointer
         , expected
         , renderMany (map renderNatural (NonEmpty.toList indexes))
         ])
  where
    sourceOrdinal branch rule ordinal =
      renderMany [branch, rule, renderNatural ordinal]
    sourceOrdinalText branch rule ordinal retained =
      renderMany [branch, rule, renderNatural ordinal, retained]
    sourceOrdinalTwoTexts branch rule ordinal first second =
      renderMany [branch, rule, renderNatural ordinal, first, second]
    sourceOrdinalIdentity branch rule ordinal pointer identity =
      renderMany
        [ branch
        , rule
        , renderNatural ordinal
        , pointer
        , consumeHumanModel identity
        ]

consumeHumanNotationContractFailure ::
     HumanFailure.HumanNotationContractFailure -> Text
consumeHumanNotationContractFailure =
  HumanFailure.foldHumanNotationContractFailure
    (\authority contract ->
       renderMany
         [ "authority-mismatch"
         , consumeHumanAdapter authority
         , consumeHumanAdapter contract
         ])
    (\adapter kind ->
       renderMany ["rule-missing", consumeHumanAdapter adapter, kind])

consumeHumanProfileContractEvidence ::
     HumanFailure.HumanProfileContractEvidence -> Text
consumeHumanProfileContractEvidence =
  HumanFailure.foldHumanProfileContractEvidence
    (\rule kind -> renderMany ["unknown-rule", rule, kind])
    (\rule kind -> renderMany ["evidence-mismatch", rule, kind])
    (\binding occurrence ->
       renderMany ["missing-binding", binding, consumeHumanCanonical occurrence])
    (\occurrence detail ->
       renderMany
         ["impossible-identity", consumeHumanCanonical occurrence, detail])

consumeHumanIdentityIndexDefect :: HumanFailure.HumanIdentityIndexDefect -> Text
consumeHumanIdentityIndexDefect =
  HumanFailure.foldHumanIdentityIndexDefect $ \occurrence identities ->
    renderMany
      [ consumeHumanOccurrence occurrence
      , renderNonEmpty consumeHumanModel identities
      ]

consumeHumanSelectedViewScopeDefect ::
     HumanFailure.HumanSelectedViewScopeDefect -> Text
consumeHumanSelectedViewScopeDefect =
  HumanFailure.foldHumanSelectedViewScopeDefect $ \kind occurrence cardinality ->
    renderMany
      [ HumanFailure.foldHumanSelectedViewScopeDefectKind
          "unknown-subject-occurrence"
          "subject-identity-mismatch"
          "unknown-occurrence"
          "duplicate-occurrence"
          kind
      , consumeHumanOccurrence occurrence
      , renderNatural cardinality
      ]

consumeHumanStructureInputDefect ::
     HumanFailure.HumanStructureInputDefect -> Text
consumeHumanStructureInputDefect =
  HumanFailure.foldHumanStructureInputDefect
    (\occurrence ->
       renderMany ["outside-view", consumeHumanOccurrence occurrence])
    (\occurrence kinds ->
       renderMany
         [ "duplicate-projection"
         , consumeHumanOccurrence occurrence
         , renderMany (NonEmpty.toList kinds)
         ])
    (\owner role endpoint ->
       renderMany
         [ "missing-carrier"
         , consumeHumanOccurrence owner
         , role
         , consumeHumanOccurrence endpoint
         ])
    (\identity occurrence ->
       renderMany
         [ "missing-proposition"
         , consumeHumanOccurrence identity
         , consumeHumanOccurrence occurrence
         ])

consumeHumanSupplementalProvenanceDefect ::
     HumanFailure.HumanSupplementalProvenanceDefect -> Text
consumeHumanSupplementalProvenanceDefect =
  HumanFailure.foldHumanSupplementalProvenanceDefect
    (\source -> renderMany ["model-source", consumeHumanSource source])
    (\role ordinal sources ->
       renderMany
         [ "duplicate-source"
         , role
         , renderNatural ordinal
         , renderNonEmpty consumeHumanSource sources
         ])

-- | Render every common Human report-authority field at the CLI boundary.
consumeHumanEnvelope :: ReportEnvelope -> Text
consumeHumanEnvelope = renderObservedEnvelope . observeReportEnvelope

renderObservedEnvelope :: ObservedReportEnvelope -> Text
renderObservedEnvelope (ObservedReportEnvelope (ObservedSchemaAuthority schema version digest) variant operation (ObservedToolDescriptor tool toolVersion) authority) =
  renderMany
    [ schema
    , renderNatural version
    , digest
    , variant
    , renderObservedOperation operation
    , renderMany [tool, toolVersion]
    , renderObservedAuthority authority
    ]

renderObservedOperation :: ObservedReportOperation -> Text
renderObservedOperation operation =
  case operation of
    ObservedViewsReportOperation -> "views"
    ObservedQualificationSubjectsReportOperation -> "qualification-subjects"
    ObservedValidateReportOperation -> "validate"
    ObservedTraceReportOperation -> "trace"
    ObservedQualifyReportOperation -> "qualify"
    ObservedReadinessReportOperation -> "readiness"
    ObservedAssessReportOperation -> "assess"

renderObservedAuthority :: ObservedReportAuthority -> Text
renderObservedAuthority authority =
  case authority of
    ObservedViewReportAuthority adapter -> adapter
    ObservedPreparedReportAuthority contracts ->
      renderMany (map renderObservedContract (NonEmpty.toList contracts))

renderObservedContract :: ObservedReportContract -> Text
renderObservedContract contract =
  case contract of
    ObservedOperationReportContract identity version digest ->
      renderMany ["operation", identity, version, digest]
    ObservedAdapterReportContract -> "adapter"
    ObservedProfileReportContract -> "profile"
    ObservedCoreReportContract identity version digest ->
      renderMany ["core", identity, version, digest]

consumeHumanDiagnosticDocument ::
     HumanDiagnostic.HumanDiagnosticDocument -> Text
consumeHumanDiagnosticDocument =
  HumanDiagnostic.foldHumanDiagnosticDocument $ \authority diagnostics groups ->
    renderMany
      [ consumeHumanDiagnosticAuthority authority
      , renderMany (map consumeHumanDiagnostic diagnostics)
      , renderMany (map consumeHumanDiagnosticGroup groups)
      ]

consumeHumanDiagnosticAuthority ::
     HumanDiagnostic.HumanDiagnosticAuthority -> Text
consumeHumanDiagnosticAuthority =
  HumanDiagnostic.foldHumanDiagnosticAuthority $ \adapter rules profile model ->
    renderMany
      [ consumeHumanAdapter adapter
      , renderMany (map consumeHumanNotationRule rules)
      , consumeHumanProfile profile
      , consumeHumanSource model
      ]

consumeHumanNotationRule :: HumanDiagnostic.HumanNotationRuleBinding -> Text
consumeHumanNotationRule =
  HumanDiagnostic.foldHumanNotationRuleBinding $ \kind rule ->
    renderMany [kind, rule]

consumeHumanDiagnosticGroup ::
     HumanDiagnostic.HumanSupplementalDiagnosticGroup -> Text
consumeHumanDiagnosticGroup =
  HumanDiagnostic.foldHumanSupplementalDiagnosticGroup $ \source diagnostics ->
    renderMany
      [ consumeHumanSource source
      , renderMany (map consumeHumanDiagnostic diagnostics)
      ]

consumeHumanDiagnostic :: HumanDiagnostic.HumanDiagnostic -> Text
consumeHumanDiagnostic =
  HumanDiagnostic.foldHumanDiagnostic $ \producer owner stage rule severity disposition code evidence ->
    renderMany
      [ producer
      , owner
      , stage
      , rule
      , HumanDiagnostic.foldHumanDiagnosticSeverity ("severity:" <>) severity
      , HumanDiagnostic.foldHumanDiagnosticDisposition
          ("disposition:" <>)
          disposition
      , code
      , consumeHumanEvidence evidence
      ]

consumeHumanEvidence :: HumanDiagnostic.HumanDiagnosticEvidence -> Text
consumeHumanEvidence =
  HumanDiagnostic.foldHumanDiagnosticEvidence
    consumeHumanNotationEvidence
    consumeHumanActivationEvidence
    consumeHumanProfileEvidence
    consumeHumanProfileClassificationEvidence
    consumeHumanProfileMappingEvidence
    consumeHumanProfileInvariantEvidence
    consumeHumanStructureEvidence
    consumeHumanSemanticEvidence
    (supplemental "supplemental-identity-unknown")
    (supplemental "supplemental-identity-ambiguous")
    (supplemental "supplemental-identity-wrong-type")
    (supplemental "supplemental-identity-out-of-view")
  where
    supplemental branch source pointer identity =
      renderMany
        [branch, consumeHumanSource source, pointer, consumeHumanModel identity]

consumeHumanNotationEvidence ::
     HumanDiagnostic.HumanNotationDiagnosticEvidence -> Text
consumeHumanNotationEvidence =
  HumanDiagnostic.foldHumanNotationDiagnosticEvidence $ \adapter rule kind subject observations ->
    renderMany
      [ "notation"
      , consumeHumanAdapter adapter
      , HumanDiagnostic.foldHumanAdapterRule
          (\identity stage expectation meaning action ->
             renderMany
               [ identity
               , HumanDiagnostic.foldHumanAdapterRuleStage
                   "preparation"
                   "notation"
                   stage
               , expectation
               , meaning
               , action
               ])
          rule
      , HumanDiagnostic.foldHumanNotationIssueKind
          (HumanDiagnostic.foldHumanViewInventoryIssueKind
             ("view-inventory:" <>))
          (HumanDiagnostic.foldHumanProfileMarkerIssueKind
             ("profile-marker:" <>))
          (HumanDiagnostic.foldHumanSelectedUniverseIssueKind
             ("selected-universe:" <>))
          kind
      , consumeHumanLocation subject
      , renderMany
          (map consumeHumanNotationObservation (NonEmpty.toList observations))
      ]

consumeHumanNotationObservation ::
     HumanDiagnostic.HumanNotationObservation -> Text
consumeHumanNotationObservation =
  HumanDiagnostic.foldHumanNotationObservation
    (("occurrence:" <>) . consumeHumanLocation)
    (\location kind retained ->
       renderMany
         [ "value"
         , consumeHumanLocation location
         , HumanDiagnostic.foldHumanDraftValueKind
             "text"
             "boolean"
             "number"
             "native-name"
             ("other:" <>)
             kind
         , retained
         ])
    (\location retained targets ->
       renderMany
         [ "reference"
         , consumeHumanLocation location
         , retained
         , renderMany (map consumeHumanLocation targets)
         ])

consumeHumanActivationEvidence ::
     HumanDiagnostic.HumanActivationDiagnosticEvidence -> Text
consumeHumanActivationEvidence =
  HumanDiagnostic.foldHumanActivationDiagnosticEvidence $ \profile digest branch rule owner trigger sources ->
    renderMany
      [ "activation"
      , profile
      , digest
      , HumanDiagnostic.foldHumanClosureBranch "graph" "qualification" branch
      , rule
      , consumeHumanCanonical owner
      , consumeHumanCanonical trigger
      , renderMany sources
      ]

consumeHumanProfileEvidence ::
     HumanDiagnostic.HumanProfileDiagnosticEvidence -> Text
consumeHumanProfileEvidence =
  HumanDiagnostic.foldHumanProfileDiagnosticEvidence
    HumanDiagnostic.HumanProfileDiagnosticEliminator
      { HumanDiagnostic.eliminateHumanProfileCarrierOccurrence = one "carrier"
      , HumanDiagnostic.eliminateHumanProfileClassificationOccurrence =
          one "classification"
      , HumanDiagnostic.eliminateHumanProfileMetadataOwnerAndO2iPropertyOccurrences =
          many "metadata"
      , HumanDiagnostic.eliminateHumanProfilePropertyOccurrence = two "property"
      , HumanDiagnostic.eliminateHumanProfilePropertySlot =
          \rule owner slot values ->
            renderMany
              [ "slot"
              , rule
              , consumeHumanCanonical owner
              , slot
              , renderMany (map consumeHumanCanonical values)
              ]
      , HumanDiagnostic.eliminateHumanProfilePropertyValue =
          \rule property value drafts ->
            renderMany
              [ "value"
              , rule
              , consumeHumanCanonical property
              , consumeHumanCanonical value
              , renderMany (map consumeHumanDraftScalar drafts)
              ]
      , HumanDiagnostic.eliminateHumanProfileProposalCarrierOccurrence =
          one "proposal"
      , HumanDiagnostic.eliminateHumanProfileProposalReferenceIncidence =
          many2 "reference"
      , HumanDiagnostic.eliminateHumanProfileRelationshipOccurrence =
          one "relationship"
      , HumanDiagnostic.eliminateHumanProfileReservedPropertyOccurrence =
          \rule property owner reserved ->
            renderMany
              [ "reserved"
              , rule
              , consumeHumanCanonical property
              , consumeHumanCanonical owner
              , reserved
              ]
      , HumanDiagnostic.eliminateHumanProfileStructuredCarrierOccurrence =
          one "structured"
      , HumanDiagnostic.eliminateHumanProfileStructuredIncidence =
          many "incidence"
      }
  where
    one branch rule value =
      renderMany [branch, rule, consumeHumanCanonical value]
    two branch rule first second =
      renderMany
        [ branch
        , rule
        , consumeHumanCanonical first
        , consumeHumanCanonical second
        ]
    many branch rule owner values =
      renderMany
        [ branch
        , rule
        , consumeHumanCanonical owner
        , renderMany (map consumeHumanCanonical values)
        ]
    many2 branch rule first second values =
      renderMany
        [ branch
        , rule
        , consumeHumanCanonical first
        , consumeHumanCanonical second
        , renderMany (map consumeHumanCanonical values)
        ]

consumeHumanProfileClassificationEvidence ::
     HumanDiagnostic.HumanProfileClassificationDiagnosticEvidence -> Text
consumeHumanProfileClassificationEvidence =
  HumanDiagnostic.foldHumanProfileClassificationDiagnosticEvidence $ \graph qualification rule occurrence ->
    renderMany
      [ "profile-classification"
      , renderBool graph
      , renderBool qualification
      , rule
      , consumeHumanCanonical occurrence
      ]

consumeHumanProfileMappingEvidence ::
     HumanDiagnostic.HumanProfileMappingDiagnosticEvidence -> Text
consumeHumanProfileMappingEvidence =
  HumanDiagnostic.foldHumanProfileMappingDiagnosticEvidence
    (\rule occurrence mapping ->
       renderMany ["carrier", rule, consumeHumanOccurrence occurrence, mapping])
    (\rule occurrence mapping source target ->
       renderMany
         [ "relation"
         , rule
         , consumeHumanOccurrence occurrence
         , mapping
         , consumeHumanOccurrence source
         , consumeHumanOccurrence target
         ])
    (\rule occurrence mapping kind ->
       renderMany
         [ "construction"
         , rule
         , consumeHumanOccurrence occurrence
         , mapping
         , consumeHumanProfileKind kind
         ])

consumeHumanProfileInvariantEvidence ::
     HumanDiagnostic.HumanProfileInvariantDiagnosticEvidence -> Text
consumeHumanProfileInvariantEvidence =
  HumanDiagnostic.foldHumanProfileInvariantDiagnosticEvidence $ \rule occurrence ->
    renderMany ["profile-invariant", rule, consumeHumanCanonical occurrence]

consumeHumanProfileKind :: HumanDiagnostic.HumanProfileEvidenceKind -> Text
consumeHumanProfileKind =
  HumanDiagnostic.foldHumanProfileEvidenceKind
    "carrier"
    "classification"
    "metadata"
    "property"
    "slot"
    "value"
    "proposal"
    "reference"
    "relationship"
    "reserved"
    "structured"
    "incidence"

consumeHumanStructureEvidence ::
     HumanDiagnostic.HumanStructureDiagnosticEvidence -> Text
consumeHumanStructureEvidence =
  HumanDiagnostic.foldHumanStructureDiagnosticEvidence
    HumanDiagnostic.HumanStructureDiagnosticEliminator
      { HumanDiagnostic.eliminateHumanQualifiedEndpointCatalogMembership =
          one "catalog"
      , HumanDiagnostic.eliminateHumanContextualizationSourceCategory =
          two "source-category"
      , HumanDiagnostic.eliminateHumanContextualizationTargetCategory =
          two "target-category"
      , HumanDiagnostic.eliminateHumanContextualizationTargetOwnerCardinality =
          zeroMany "owner-cardinality"
      , HumanDiagnostic.eliminateHumanSemanticRelationCompatibility =
          three "relation"
      , HumanDiagnostic.eliminateHumanStructuredPropositionIdentity =
          \owner source target identities ->
            renderMany
              [ "identity"
              , consumeHumanOccurrence owner
              , consumeHumanOccurrence source
              , consumeHumanOccurrence target
              , renderMany (map consumeHumanOccurrence identities)
              ]
      , HumanDiagnostic.eliminateHumanCollectiveParticipantType =
          three "participant-type"
      , HumanDiagnostic.eliminateHumanCollectiveParticipantCardinality =
          \owner participant ->
            renderMany
              [ "participant-cardinality"
              , consumeHumanOccurrence owner
              , maybe "none" consumeHumanOccurrence participant
              ]
      , HumanDiagnostic.eliminateHumanCollectiveParticipantUniqueness =
          \owner participants ->
            renderMany
              [ "participant-uniqueness"
              , consumeHumanOccurrence owner
              , renderMany
                  (map consumeHumanOccurrence (NonEmpty.toList participants))
              ]
      , HumanDiagnostic.eliminateHumanCollectiveTargetType = three "target-type"
      , HumanDiagnostic.eliminateHumanCollectiveTargetCardinality =
          zeroMany "target-cardinality"
      , HumanDiagnostic.eliminateHumanCollectiveTargetDistinctness =
          \owner targets ->
            renderMany
              [ "target-distinctness"
              , consumeHumanOccurrence owner
              , renderMany
                  (map consumeHumanOccurrence (NonEmpty.toList targets))
              ]
      }
  where
    one branch value = renderMany [branch, consumeHumanOccurrence value]
    two branch first second =
      renderMany
        [branch, consumeHumanOccurrence first, consumeHumanOccurrence second]
    three branch first second third =
      renderMany
        [ branch
        , consumeHumanOccurrence first
        , consumeHumanOccurrence second
        , consumeHumanOccurrence third
        ]
    zeroMany branch owner values =
      renderMany
        [ branch
        , consumeHumanOccurrence owner
        , HumanDiagnostic.foldHumanStructureZeroOrMultipleOccurrences
            "zero"
            (\first second remaining ->
               renderMany
                 (map consumeHumanOccurrence (first : second : remaining)))
            values
        ]

consumeHumanSemanticEvidence ::
     HumanDiagnostic.HumanSemanticDiagnosticEvidence -> Text
consumeHumanSemanticEvidence =
  HumanDiagnostic.foldHumanSemanticDiagnosticEvidence
    HumanDiagnostic.HumanSemanticDiagnosticEliminator
      { HumanDiagnostic.eliminateHumanCollectiveAssertedCollectiveCoverage =
          nonEmpty "collective-coverage"
      , HumanDiagnostic.eliminateHumanCollectiveAssertedCompleteness =
          field "collective-completeness"
      , HumanDiagnostic.eliminateHumanCollectiveAssertedMacroSupport =
          member3 "macro-support"
      , HumanDiagnostic.eliminateHumanCollectiveAssertedParticipantPrimitiveSupport =
          member3 "primitive-support"
      , HumanDiagnostic.eliminateHumanCollectiveFitPairwiseCoherence =
          field "pairwise-coherence"
      , HumanDiagnostic.eliminateHumanCollectiveFitParticipantBinding =
          field "participant-binding"
      , HumanDiagnostic.eliminateHumanCollectiveFitParticipantCompatibility =
          field "participant-compatibility"
      , HumanDiagnostic.eliminateHumanCollectiveFitTargetBinding =
          field "target-binding"
      , HumanDiagnostic.eliminateHumanCollectiveFitTargetGuidingPolicy =
          field "target-guiding-policy"
      , HumanDiagnostic.eliminateHumanCollectiveFitTargetTradeOffs =
          field "target-trade-offs"
      , HumanDiagnostic.eliminateHumanContextualizationAssertedDependency =
          \dependent endpoint context first second third ->
            renderMany
              [ "asserted-dependency"
              , renderMany
                  (map
                     consumeHumanOccurrence
                     [dependent, endpoint, context, first, second, third])
              ]
      , HumanDiagnostic.eliminateHumanSituatedNeedDriverAnchoring =
          member "driver-anchoring"
      , HumanDiagnostic.eliminateHumanSituatedNeedDriverCardinality =
          model "driver-cardinality"
      , HumanDiagnostic.eliminateHumanSituatedNeedObjectiveCardinality =
          model "objective-cardinality"
      , HumanDiagnostic.eliminateHumanSituatedNeedObjectiveGrounding =
          member "objective-grounding"
      , HumanDiagnostic.eliminateHumanSituatedNeedSurfacingSituationAnchoring =
          member "situation-anchoring"
      , HumanDiagnostic.eliminateHumanSituatedNeedSurfacingSituationCardinality =
          model "situation-cardinality"
      , HumanDiagnostic.eliminateHumanStrategyFormulationActionContributions =
          member "action-contributions"
      , HumanDiagnostic.eliminateHumanStrategyFormulationActions =
          nonEmpty "actions"
      , HumanDiagnostic.eliminateHumanStrategyFormulationDiagnosis =
          many "diagnosis"
      , HumanDiagnostic.eliminateHumanStrategyFormulationDiagnosisGrounding =
          pair "diagnosis-grounding"
      , HumanDiagnostic.eliminateHumanStrategyFormulationGuidingPolicy =
          many "guiding-policy"
      , HumanDiagnostic.eliminateHumanStrategyFormulationGuidingPolicyActions =
          memberPair "guiding-policy-actions"
      , HumanDiagnostic.eliminateHumanStrategyFormulationIntent = many "intent"
      , HumanDiagnostic.eliminateHumanStrategyFormulationKeyResultSubstantiation =
          memberPair "key-result-substantiation"
      , HumanDiagnostic.eliminateHumanStrategyFormulationKeyResults =
          nonEmpty "key-results"
      , HumanDiagnostic.eliminateHumanStrategyFormulationVisionOrientation =
          model "vision-orientation"
      }
  where
    model branch identity = renderMany [branch, consumeHumanModel identity]
    field branch identity occurrence =
      renderMany
        [branch, consumeHumanModel identity, consumeHumanOccurrence occurrence]
    many branch identity occurrences =
      renderMany
        [ branch
        , consumeHumanModel identity
        , renderMany (map consumeHumanOccurrence occurrences)
        ]
    nonEmpty branch identity occurrences =
      renderMany
        [ branch
        , consumeHumanModel identity
        , renderMany (map consumeHumanOccurrence (NonEmpty.toList occurrences))
        ]
    pair branch identity first second =
      renderMany
        [ branch
        , consumeHumanModel identity
        , consumeHumanOccurrence first
        , consumeHumanOccurrence second
        ]
    member branch owner owned occurrence =
      renderMany
        [ branch
        , consumeHumanModel owner
        , consumeHumanModel owned
        , consumeHumanOccurrence occurrence
        ]
    memberPair branch owner owned first second =
      renderMany
        [ branch
        , consumeHumanModel owner
        , consumeHumanModel owned
        , consumeHumanOccurrence first
        , consumeHumanOccurrence second
        ]
    member3 branch owner owned first second third =
      renderMany
        [ branch
        , consumeHumanModel owner
        , consumeHumanModel owned
        , consumeHumanOccurrence first
        , consumeHumanOccurrence second
        , consumeHumanOccurrence third
        ]

consumeHumanModel :: HumanValue.HumanModelIdentity -> Text
consumeHumanModel = HumanValue.foldHumanModelIdentity ("model:" <>)

consumeHumanOccurrence :: HumanValue.HumanOccurrenceIdentity -> Text
consumeHumanOccurrence =
  HumanValue.foldHumanOccurrenceIdentity ("occurrence:" <>)

consumeHumanCanonical :: HumanValue.HumanCanonicalOccurrence -> Text
consumeHumanCanonical =
  HumanValue.foldHumanCanonicalOccurrence $ \kind ordinal ->
    renderMany
      [ HumanValue.foldHumanCanonicalOccurrenceKind
          "node"
          "relation"
          "view"
          kind
      , renderNatural ordinal
      ]

consumeHumanAdapter :: HumanValue.HumanAdapterDescriptor -> Text
consumeHumanAdapter =
  HumanValue.foldHumanAdapterDescriptor $ \identifier name version notation ->
    renderMany [identifier, name, version, notation]

consumeHumanProfile :: HumanValue.HumanProfileDescriptor -> Text
consumeHumanProfile =
  HumanValue.foldHumanProfileDescriptor $ \identifier name version notation adapters digest ->
    renderMany
      [identifier, name, version, notation, renderMany adapters, digest]

consumeHumanSource :: HumanValue.HumanSourceIdentity -> Text
consumeHumanSource =
  HumanValue.foldHumanSourceIdentity $ \role ordinal reference digest ->
    renderMany
      [ HumanValue.foldHumanSourceRole
          "model"
          "supplemental"
          "readiness"
          "assessment"
          role
      , renderNatural ordinal
      , reference
      , digest
      ]

consumeHumanLocation :: HumanValue.HumanSourceLocation -> Text
consumeHumanLocation =
  HumanValue.foldHumanSourceLocation $ \path sourceSpan ->
    renderMany
      [ renderMany (map consumeHumanPathStep (NonEmpty.toList path))
      , maybe "no-span" consumeHumanSpan sourceSpan
      ]

consumeHumanPathStep :: HumanValue.HumanSourcePathStep -> Text
consumeHumanPathStep =
  HumanValue.foldHumanSourcePathStep $ \name ordinal ->
    renderMany [consumeHumanNativeName name, renderNatural ordinal]

consumeHumanNativeName :: HumanValue.HumanNativeName -> Text
consumeHumanNativeName =
  HumanValue.foldHumanNativeName $ \namespace value ->
    renderMany [maybe "no-namespace" id namespace, value]

consumeHumanSpan :: HumanValue.HumanSourceSpan -> Text
consumeHumanSpan =
  HumanValue.foldHumanSourceSpan $ \start end ->
    renderMany [consumeHumanPosition start, consumeHumanPosition end]

consumeHumanPosition :: HumanValue.HumanSourcePosition -> Text
consumeHumanPosition =
  HumanValue.foldHumanSourcePosition $ \line column offset ->
    renderMany
      [ renderNatural line
      , renderNatural column
      , maybe "no-offset" renderNatural offset
      ]

consumeHumanDraftScalar :: HumanValue.HumanDraftScalar -> Text
consumeHumanDraftScalar =
  HumanValue.foldHumanDraftScalar $ \value location ->
    renderMany [consumeHumanScalar value, consumeHumanLocation location]

consumeHumanScalar :: HumanValue.HumanScalarValue -> Text
consumeHumanScalar =
  HumanValue.foldHumanScalarValue
    ("text:" <>)
    (\value -> "boolean:" <> renderBool value)
    ("number:" <>)
    (("native-name:" <>) . consumeHumanNativeName)
    (\kind value -> renderMany ["other", kind, value])

consumeHumanQualifiedType :: HumanValue.HumanQualifiedType -> Text
consumeHumanQualifiedType =
  HumanValue.foldHumanQualifiedType ("qualified-type:" <>)

consumeHumanInputSource :: HumanValue.HumanInputSource -> Text
consumeHumanInputSource =
  HumanValue.foldHumanInputSource
    (\reference path -> renderMany ["file", reference, Text.pack path])
    (\reference -> renderMany ["standard-input", reference])

consumeHumanViewSelector :: HumanValue.HumanViewSelector -> Text
consumeHumanViewSelector =
  HumanValue.foldHumanViewSelector
    (\name -> renderMany ["name", name])
    (\identity -> renderMany ["identity", consumeHumanModel identity])

consumeHumanAdapterSelection :: HumanValue.HumanAdapterSelection -> Text
consumeHumanAdapterSelection =
  HumanValue.foldHumanAdapterSelection
    "automatic"
    (\identifier -> renderMany ["requested", identifier])

consumeHumanIdentityOutcome :: HumanValue.HumanIdentityOutcome -> Text
consumeHumanIdentityOutcome =
  HumanValue.foldHumanIdentityOutcome
    "missing"
    (\values -> renderMany ("multiple" : map consumeHumanDraftScalar values))
    (\value reason ->
       renderMany
         [ "invalid"
         , consumeHumanDraftScalar value
         , HumanValue.foldHumanIdentityInvalidReason
             (\kind -> renderMany ["non-text", kind])
             "empty"
             "nul"
             "surrogate"
             reason
         ])
    (\value identity ->
       renderMany
         ["resolved", consumeHumanDraftScalar value, consumeHumanModel identity])

consumeHumanCanonicalField :: HumanValue.HumanCanonicalField -> Text
consumeHumanCanonicalField =
  HumanValue.foldHumanCanonicalField $ \kind values location ->
    renderMany
      [ kind
      , renderMany (map consumeHumanDraftScalar values)
      , consumeHumanLocation location
      ]

consumeHumanView :: HumanValue.HumanViewDescriptor -> Text
consumeHumanView =
  HumanValue.foldHumanViewDescriptor $ \occurrence identity names location ->
    renderMany
      [ consumeHumanCanonical occurrence
      , consumeHumanIdentityOutcome identity
      , renderMany (map consumeHumanCanonicalField names)
      , consumeHumanLocation location
      ]

consumeHumanTraceBinding :: HumanValue.HumanTraceBinding -> Text
consumeHumanTraceBinding =
  HumanValue.foldHumanTraceBinding $ \variable identity ->
    renderMany [variable, consumeHumanModel identity]

consumeHumanTraceIdentity :: HumanValue.HumanTraceIdentity -> Text
consumeHumanTraceIdentity =
  HumanValue.foldHumanTraceIdentity $ \graph bindings ->
    renderMany
      [ consumeHumanModel graph
      , renderMany (map consumeHumanTraceBinding bindings)
      ]

renderMany :: [Text] -> Text
renderMany = Text.intercalate "|"

renderNonEmpty :: (value -> Text) -> NonEmpty value -> Text
renderNonEmpty consume = renderMany . map consume . NonEmpty.toList

renderNatural :: Show value => value -> Text
renderNatural = Text.pack . show

renderBool :: Bool -> Text
renderBool value =
  if value
    then "true"
    else "false"
