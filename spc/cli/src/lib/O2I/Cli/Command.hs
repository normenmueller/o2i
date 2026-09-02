{-# LANGUAGE OverloadedStrings #-}

-- | Thin dispatch over public Operation command and machine APIs.
module O2I.Cli.Command
  ( ExecutionError(..)
  , executeCommand
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Cli.Input
import O2I.Cli.Options
import O2I.Cli.Output
import O2I.Cli.Static
import O2I.Cli.TerminalText (terminalLiteral)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterId
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorNotation
  , adapterDescriptorVersion
  , adapterIdText
  )
import O2I.Operation.Assess (runAssess)
import O2I.Operation.Assess.Machine
  ( assessResultDocument
  , encodeAssessResultDocument
  )
import O2I.Operation.Assess.Request (assessRequest)
import O2I.Operation.Assess.Result
  ( AssessFailure
  , assessExitClassText
  , assessExitCode
  , assessResultExitClass
  )
import O2I.Operation.Command.Error
  ( CommandError
  , assessCommandError
  , commonCommandError
  , qualifyCommandError
  , readinessCommandError
  , validateCommandError
  )
import O2I.Operation.Discovery.Adapter (discoverAdapters, foldAdapterDiscovery)
import O2I.Operation.Discovery.Adapter.Machine
  ( adapterInventoryDocument
  , encodeAdapterInventoryDocument
  )
import O2I.Operation.Discovery.Profile
  ( ProfileDiscoveryRow
  , discoverProfiles
  , foldProfileDiscovery
  , foldProfileDiscoveryCompilation
  , foldProfileDiscoveryRow
  )
import O2I.Operation.Discovery.Profile.Machine
  ( encodeProfileInventoryDocument
  , profileInventoryDocument
  )
import O2I.Operation.Discovery.Rule
  ( DiscoveredRule
  , RuleDiscoveryCompilation
  , discoverAdapterRules
  , discoverCoreRules
  , discoverOperationRules
  , explainDiscoveredRule
  , foldDiscoveredRule
  , foldRuleDiscovery
  , foldRuleDiscoveryCompilation
  )
import qualified O2I.Operation.Discovery.Rule as DiscoveredRule
import O2I.Operation.Discovery.Rule.Explanation.Machine
  ( encodeRuleExplanationDocument
  , ruleExplanationDocument
  )
import O2I.Operation.Discovery.Rule.Inventory.Machine
  ( encodeRuleInventoryDocument
  , ruleInventoryDocument
  )
import O2I.Operation.Discovery.View (discoverViews, foldViewDiscovery)
import O2I.Operation.Discovery.View.Machine
  ( encodeViewDiscoveryDocument
  , viewDiscoveryDocument
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Qualification.Subjects (runQualificationSubjects)
import O2I.Operation.Qualification.Subjects.Machine
  ( encodeQualificationSubjectsDocument
  , qualificationSubjectsDocument
  )
import O2I.Operation.Qualification.Subjects.Request
  ( qualificationSubjectsRequest
  )
import O2I.Operation.Qualification.Subjects.Result
  ( QualificationSubjectsFailure
  , foldQualificationSubjectsFailure
  , foldQualificationSubjectsResult
  )
import O2I.Operation.Qualify (runQualify)
import O2I.Operation.Qualify.Machine
  ( encodeQualifyResultDocument
  , qualifyResultDocument
  )
import O2I.Operation.Qualify.Request (QualifyRequest, qualifyRequest)
import O2I.Operation.Qualify.Result
  ( QualifyFailure
  , foldQualifyResult
  )
import O2I.Operation.Readiness (runReadiness)
import O2I.Operation.Readiness.Machine
  ( encodeReadinessResultDocument
  , readinessResultDocument
  )
import O2I.Operation.Readiness.Request (readinessRequest)
import O2I.Operation.Readiness.Result
  ( ReadinessFailure
  , foldReadinessResult
  )
import O2I.Operation.Trace (runTrace)
import O2I.Operation.Trace.Machine
  ( encodeTraceResultDocument
  , traceResultDocument
  )
import O2I.Operation.Trace.Request (traceRequest)
import O2I.Operation.Trace.Result
  ( TraceFailure
  , foldTraceFailure
  , foldTraceResult
  )
import O2I.Operation.Validate (runValidate)
import O2I.Operation.Validate.Machine
  ( encodeValidateResultDocument
  , validateResultDocument
  )
import O2I.Operation.Validate.Request
  ( notationValidateRequest
  , profileValidateRequest
  , semanticsValidateRequest
  , structureValidateRequest
  )
import O2I.Operation.Validate.Result
  ( ValidateFailure
  , foldValidateResult
  )
import O2I.Operation.View (ViewSelector)

-- | Pre-report failure retaining either exact CLI grammar evidence or one
-- closed Operation command failure.
data ExecutionError
  = ExecutionArgumentError CliError
  | ExecutionCommandError CommandError

-- | Execute one parsed report command. Help and version are process metadata
-- handled by 'O2I.Cli'; this function owns only report-producing commands.
executeCommand ::
     StaticComposition
  -> ToolDescriptor
  -> CliOptions
  -> IO (Either ExecutionError PrimaryReport)
executeCommand static tool command =
  case command of
    AdaptersCommand _ -> pure (Right (adapterReport static))
    ProfilesCommand _ -> pure (Right (profileReport static))
    RulesCommand authority _ ->
      pure (mapLeft ExecutionArgumentError (rulesReport static authority))
    ExplainCommand authority identifier _ ->
      pure
        (mapLeft
           ExecutionArgumentError
           (explainReport static authority identifier))
    ViewsCommand model adapter _ ->
      mapLeft ExecutionArgumentError <$> viewsReport static tool model adapter
    QualificationSubjectsCommand model supplements _ ->
      qualificationSubjectsReport static tool model supplements
    ValidateCommand model level supplements _ ->
      validateReport static tool model level supplements
    TraceCommand model _ -> traceReport static tool model
    QualifyCommand model strategies needs supplements _ ->
      qualifyReport static tool model strategies needs supplements
    ReadinessCommand model input supplements _ ->
      readinessReport static tool model input supplements
    AssessCommand model input supplements _ ->
      assessReport static tool model input supplements
    HelpCommand _ ->
      pure
        (Left
           (ExecutionArgumentError
              (internal "Help reached report dispatch.")))
    VersionCommand ->
      pure
        (Left
           (ExecutionArgumentError
              (internal "Version reached report dispatch.")))

adapterReport :: StaticComposition -> PrimaryReport
adapterReport static =
  foldAdapterDiscovery
    (\descriptors ->
       report
         ("O2I adapters:\n" <> foldMap adapterLine descriptors)
         (encodeAdapterInventoryDocument (adapterInventoryDocument discovery))
         0)
    discovery
  where
    discovery = discoverAdapters (staticAdapters static)

adapterLine :: AdapterDescriptor -> Text
adapterLine descriptor =
  "  "
    <> safe (adapterIdText (adapterDescriptorId descriptor))
    <> " | "
    <> safe (adapterDescriptorName descriptor)
    <> " | "
    <> safe (adapterDescriptorVersion descriptor)
    <> " | "
    <> safe (adapterDescriptorNotation descriptor)
    <> "\n"

profileReport :: StaticComposition -> PrimaryReport
profileReport static =
  foldProfileDiscoveryCompilation
    (const (report "O2I profiles: static definition invalid\n" machine 2))
    (\discovery ->
       foldProfileDiscovery
         (\rows ->
            report ("O2I profiles:\n" <> foldMap profileLine rows) machine 0)
         discovery)
    compilation
  where
    compilation = discoverProfiles (staticProfiles static)
    machine =
      encodeProfileInventoryDocument (profileInventoryDocument compilation)

profileLine :: ProfileDiscoveryRow -> Text
profileLine =
  foldProfileDiscoveryRow $ \identity token version notation adapters digest ->
    "  "
      <> safe identity
      <> "@"
      <> safe token
      <> " | "
      <> safe version
      <> " | "
      <> safe notation
      <> " | adapters="
      <> Text.intercalate "," (map safe (NonEmpty.toList adapters))
      <> " | sha256="
      <> safe digest
      <> "\n"

rulesReport ::
     StaticComposition -> RuleAuthority -> Either CliError PrimaryReport
rulesReport static authority = do
  compilation <- ruleCompilation static authority
  let machine = encodeRuleInventoryDocument (ruleInventoryDocument compilation)
  pure
    (foldRuleDiscoveryCompilation
       (const (report "O2I rules: static definition invalid\n" machine 2))
       (\discovery ->
          foldRuleDiscovery
            (\owner rows ->
               report
                 ("O2I rules "
                    <> safeAuthority owner
                    <> ":\n"
                    <> foldMap ruleLine rows)
                 machine
                 0)
            discovery)
       compilation)

ruleLine :: DiscoveredRule -> Text
ruleLine =
  foldDiscoveredRule $ \_ identity stage expectation meaning action ->
    "  "
      <> safe identity
      <> " | "
      <> safe stage
      <> " | expectation="
      <> safe expectation
      <> " | meaning="
      <> safe meaning
      <> " | action="
      <> safe action
      <> "\n"

explainReport ::
     StaticComposition -> RuleAuthority -> Text -> Either CliError PrimaryReport
explainReport static authority identifier = do
  compilation <- ruleCompilation static authority
  discovery <-
    foldRuleDiscoveryCompilation
      (const (Left (internal "The selected rule inventory is invalid.")))
      Right
      compilation
  explanation <-
    mapLeft
      (const (argument "Rule identity must not be empty."))
      (explainDiscoveredRule identifier discovery)
  let machine =
        encodeRuleExplanationDocument (ruleExplanationDocument explanation)
  pure (report ("O2I rule explanation: " <> safe identifier <> "\n") machine 0)

ruleCompilation ::
     StaticComposition
  -> RuleAuthority
  -> Either CliError RuleDiscoveryCompilation
ruleCompilation static authority =
  case authority of
    OperationRules -> pure discoverOperationRules
    CoreRules -> pure discoverCoreRules
    AdapterRules token -> do
      identifier <- adapterIdFor token
      contract <-
        maybe
          (Left (argument "Unknown Adapter identity."))
          Right
          (lookupStaticAdapterContract identifier static)
      pure (discoverAdapterRules contract)
    ProfileRules reference -> staticProfileRules reference static

viewsReport ::
     StaticComposition
  -> ToolDescriptor
  -> FilePath
  -> Maybe Text
  -> IO (Either CliError PrimaryReport)
viewsReport static tool model adapter =
  case buildViewDiscoveryInput model adapter of
    Left failure -> pure (Left failure)
    Right (source, identifier) -> do
      outcome <- discoverViews (staticAdapters static) identifier source
      let machine =
            encodeViewDiscoveryDocument (viewDiscoveryDocument tool outcome)
          exit = foldViewDiscovery (const 2) (const 0) outcome
          status =
            foldViewDiscovery (const "failed") (const "discovered") outcome
      pure (Right (report (statusLine "views" status) machine exit))

qualificationSubjectsReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> [FilePath]
  -> IO (Either ExecutionError PrimaryReport)
qualificationSubjectsReport static tool model supplements =
  case buildModel model supplements of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right (source, view, adapter, supplementSources) -> do
      result <-
        runQualificationSubjects
          (staticAdapters static)
          (staticProfiles static)
          (qualificationSubjectsRequest source view adapter supplementSources)
      case qualificationSubjectsDocument tool result of
        Left failure ->
          pure (Left (qualificationSubjectsExecutionError failure))
        Right document ->
          let exit =
                foldQualificationSubjectsResult
                  (const 2)
                  (\_ _ -> 3)
                  (\_ _ -> 0)
                  result
              status =
                foldQualificationSubjectsResult
                  (const "failed")
                  (\_ _ -> "unavailable")
                  (\_ _ -> "discovered")
                  result
           in pure
                (Right
                   (report
                      (statusLine "qualification-subjects" status)
                      (encodeQualificationSubjectsDocument document)
                      exit))

validateReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> ValidationLevel
  -> [FilePath]
  -> IO (Either ExecutionError PrimaryReport)
validateReport static tool model level supplements =
  case buildModel model supplements of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right (source, view, adapter, supplementSources) -> do
      let request =
            case level of
              NotationLevel -> notationValidateRequest source view adapter
              ProfileLevel -> profileValidateRequest source view adapter
              StructureLevel -> structureValidateRequest source view adapter
              SemanticsLevel ->
                semanticsValidateRequest source view adapter supplementSources
      result <-
        runValidate (staticAdapters static) (staticProfiles static) request
      case validateResultDocument tool result of
        Left failure -> pure (Left (validateExecutionError failure))
        Right document ->
          let exit =
                foldValidateResult
                  (const 2)
                  (const 0)
                  (const 1)
                  (\_ _ -> 3)
                  result
              status =
                foldValidateResult
                  (const "failed")
                  (const "accepted")
                  (const "rejected")
                  (\_ _ -> "unavailable")
                  result
           in pure
                (Right
                   (report
                      (statusLine "validate" status)
                      (encodeValidateResultDocument document)
                      exit))

traceReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> IO (Either ExecutionError PrimaryReport)
traceReport static tool model =
  case buildModel model [] of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right (source, view, adapter, _) -> do
      result <-
        runTrace
          (staticAdapters static)
          (staticProfiles static)
          (traceRequest source view adapter)
      case traceResultDocument tool result of
        Left failure -> pure (Left (traceExecutionError failure))
        Right document ->
          let exit =
                foldTraceResult
                  (const 2)
                  (\_ _ -> 3)
                  (\_ _ -> 1)
                  (\_ _ -> 0)
                  result
              status =
                foldTraceResult
                  (const "failed")
                  (\_ _ -> "unavailable")
                  (\_ _ -> "partial")
                  (\_ _ -> "accepted")
                  result
           in pure
                (Right
                   (report
                      (statusLine "trace" status)
                      (encodeTraceResultDocument document)
                      exit))

qualifyReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> [Text]
  -> [Text]
  -> [FilePath]
  -> IO (Either ExecutionError PrimaryReport)
qualifyReport static tool model strategies needs supplements =
  case buildQualify model strategies needs supplements of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right request -> do
      result <-
        runQualify (staticAdapters static) (staticProfiles static) request
      case qualifyResultDocument tool result of
        Left failure -> pure (Left (qualifyExecutionError failure))
        Right document ->
          let exit = foldQualifyResult (const 2) (\_ _ -> 3) (\_ _ -> 0) result
              status =
                foldQualifyResult
                  (const "failed")
                  (\_ _ -> "unavailable")
                  (\_ _ -> "completed")
                  result
           in pure
                (Right
                   (report
                      (statusLine "qualify" status)
                      (encodeQualifyResultDocument document)
                      exit))

readinessReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> FilePath
  -> [FilePath]
  -> IO (Either ExecutionError PrimaryReport)
readinessReport static tool model input supplements =
  case buildModelWithPrimary model input supplements of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right (source, view, adapter, primary, supplementSources) -> do
      result <-
        runReadiness
          (staticAdapters static)
          (staticProfiles static)
          (readinessRequest source view adapter primary supplementSources)
      case readinessResultDocument tool result of
        Left failure -> pure (Left (readinessExecutionError failure))
        Right document ->
          let exit =
                foldReadinessResult
                  (const 2)
                  (\_ _ -> 3)
                  (\_ _ -> 3)
                  (\_ _ -> 1)
                  (\_ _ -> 0)
                  result
              status =
                foldReadinessResult
                  (const "failed")
                  (\_ _ -> "unavailable")
                  (\_ _ -> "unavailable")
                  (\_ _ -> "not-ready")
                  (\_ _ -> "ready")
                  result
           in pure
                (Right
                   (report
                      (statusLine "readiness" status)
                      (encodeReadinessResultDocument document)
                      exit))

assessReport ::
     StaticComposition
  -> ToolDescriptor
  -> ModelOptions
  -> FilePath
  -> [FilePath]
  -> IO (Either ExecutionError PrimaryReport)
assessReport static tool model input supplements =
  case buildModelWithPrimary model input supplements of
    Left failure -> pure (Left (ExecutionArgumentError failure))
    Right (source, view, adapter, primary, supplementSources) -> do
      result <-
        runAssess
          (staticAdapters static)
          (staticProfiles static)
          (assessRequest source view adapter primary supplementSources)
      case assessResultDocument tool result of
        Left failure -> pure (Left (assessExecutionError failure))
        Right document ->
          let exitClass = assessResultExitClass result
           in pure
                (Right
                   (report
                      (statusLine "assess" (assessExitClassText exitClass))
                      (encodeAssessResultDocument document)
                      (fromIntegral (assessExitCode exitClass))))

buildViewDiscoveryInput ::
     FilePath -> Maybe Text -> Either CliError (InputSource, Maybe AdapterId)
buildViewDiscoveryInput model adapter =
  (,) <$> inputSourceFor model <*> traverse adapterIdFor adapter

buildModel ::
     ModelOptions
  -> [FilePath]
  -> Either CliError (InputSource, ViewSelector, Maybe AdapterId, [InputSource])
buildModel model supplements =
  (,,,)
    <$> inputSourceFor (modelToken model)
    <*> viewSelectorFor (modelView model)
    <*> traverse adapterIdFor (modelAdapter model)
    <*> inputSourcesFor supplements

buildModelWithPrimary ::
     ModelOptions
  -> FilePath
  -> [FilePath]
  -> Either
       CliError
       (InputSource, ViewSelector, Maybe AdapterId, InputSource, [InputSource])
buildModelWithPrimary model primary supplements = do
  (source, view, adapter, supplementSources) <- buildModel model supplements
  primarySource <- inputSourceFor primary
  pure (source, view, adapter, primarySource, supplementSources)

buildQualify ::
     ModelOptions
  -> [Text]
  -> [Text]
  -> [FilePath]
  -> Either CliError QualifyRequest
buildQualify model strategies needs supplements = do
  (source, view, adapter, supplementSources) <- buildModel model supplements
  strategyIdentities <- traverse modelIdentityFor strategies
  needIdentities <- traverse modelIdentityFor needs
  nonEmptyStrategies <-
    maybe
      (Left (argument "At least one Strategy identity is required."))
      Right
      (NonEmpty.nonEmpty strategyIdentities)
  mapLeft
    (const (argument "Qualification selectors must be unique."))
    (qualifyRequest
       source
       view
       adapter
       nonEmptyStrategies
       needIdentities
       supplementSources)

report :: Text -> ByteString -> Int -> PrimaryReport
report human machine exit =
  PrimaryReport (textBytes human) (machine <> "\n") exit

statusLine :: Text -> Text -> Text
statusLine command status = "O2I " <> command <> ": " <> status <> "\n"

safe :: Text -> Text
safe = terminalLiteral

safeAuthority :: DiscoveredRule.RuleAuthority -> Text
safeAuthority = safe . DiscoveredRule.ruleAuthorityText

argument :: Text -> CliError
argument = CliError "cli.argument.value"

qualificationSubjectsExecutionError ::
     QualificationSubjectsFailure -> ExecutionError
qualificationSubjectsExecutionError =
  foldQualificationSubjectsFailure
    (ExecutionCommandError . commonCommandError)
    (const (unsupportedExecutionFailure "supplemental input"))
    (const (unsupportedExecutionFailure "owner contract"))

validateExecutionError :: ValidateFailure -> ExecutionError
validateExecutionError = ExecutionCommandError . validateCommandError

traceExecutionError :: TraceFailure -> ExecutionError
traceExecutionError =
  foldTraceFailure
    (ExecutionCommandError . commonCommandError)
    (const (unsupportedExecutionFailure "owner contract"))

qualifyExecutionError :: QualifyFailure -> ExecutionError
qualifyExecutionError = ExecutionCommandError . qualifyCommandError

readinessExecutionError :: ReadinessFailure -> ExecutionError
readinessExecutionError = ExecutionCommandError . readinessCommandError

assessExecutionError :: AssessFailure -> ExecutionError
assessExecutionError = ExecutionCommandError . assessCommandError

unsupportedExecutionFailure :: Text -> ExecutionError
unsupportedExecutionFailure category =
  ExecutionArgumentError
    (internal
       ("Operation reported an unencodable " <> category <> " failure."))

internal :: Text -> CliError
internal = CliError "cli.internal.dispatch"

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
