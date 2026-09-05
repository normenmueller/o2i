{-# LANGUAGE OverloadedStrings #-}

-- | Thin dispatch over public Operation command and machine APIs.
module O2I.Cli.Command
  ( ExecutionError(..)
  , executeCommand
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import qualified O2I.Cli.Human as Human
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
import qualified O2I.Operation.Assess.Human as AssessHuman
import O2I.Operation.Assess.Machine
  ( assessResultDocument
  , encodeAssessResultDocument
  )
import O2I.Operation.Assess.Request (assessRequest)
import O2I.Operation.Assess.Result
  ( assessExitClassText
  , assessExitCode
  , assessResultExitClass
  )
import O2I.Operation.Command.Error
  ( CommandError
  , assessCommandError
  , qualificationSubjectsCommandError
  , qualifyCommandError
  , readinessCommandError
  , traceCommandError
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
  , foldRuleExplanation
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
import qualified O2I.Operation.Discovery.View.Human as ViewsHuman
import O2I.Operation.Discovery.View.Machine
  ( encodeViewDiscoveryDocument
  , viewDiscoveryDocument
  )
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Qualification.Subjects (runQualificationSubjects)
import qualified O2I.Operation.Qualification.Subjects.Human as SubjectsHuman
import O2I.Operation.Qualification.Subjects.Machine
  ( encodeQualificationSubjectsDocument
  , qualificationSubjectsDocument
  )
import O2I.Operation.Qualification.Subjects.Request
  ( qualificationSubjectsRequest
  )
import O2I.Operation.Qualification.Subjects.Result
  ( foldQualificationSubjectsResult
  )
import O2I.Operation.Qualify (runQualify)
import qualified O2I.Operation.Qualify.Human as QualifyHuman
import O2I.Operation.Qualify.Machine
  ( encodeQualifyResultDocument
  , qualifyResultDocument
  )
import O2I.Operation.Qualify.Request (QualifyRequest, qualifyRequest)
import O2I.Operation.Qualify.Result (foldQualifyResult)
import O2I.Operation.Readiness (runReadiness)
import qualified O2I.Operation.Readiness.Human as ReadinessHuman
import O2I.Operation.Readiness.Machine
  ( encodeReadinessResultDocument
  , readinessResultDocument
  )
import O2I.Operation.Readiness.Request (readinessRequest)
import O2I.Operation.Readiness.Result (foldReadinessResult)
import O2I.Operation.Trace (runTrace)
import qualified O2I.Operation.Trace.Human as TraceHuman
import O2I.Operation.Trace.Machine
  ( encodeTraceResultDocument
  , traceResultDocument
  )
import O2I.Operation.Trace.Request (traceRequest)
import O2I.Operation.Trace.Result (TraceFailure, foldTraceResult)
import O2I.Operation.Validate (runValidate)
import qualified O2I.Operation.Validate.Human as ValidateHuman
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
import O2I.Operation.Validate.Result (foldValidateResult)
import O2I.Operation.View (ViewSelector)

-- | Pre-report failure retaining either exact CLI grammar evidence or one
-- closed Operation command failure.
data ExecutionError
  = ExecutionArgumentError CliError
  | ExecutionCommandError CommandError Text

-- | Execute one parsed report command. Help and version are process metadata
-- handled by 'O2I.Cli'; this function owns only report-producing commands.
executeCommand ::
     StaticComposition
  -> ToolDescriptor
  -> CliOptions
  -> IO (Either ExecutionError PrimaryReport)
executeCommand static tool command =
  fmap
    (fmap (applyVerbosity (commandVerbosity command)))
    (executeReportCommand static tool command)

executeReportCommand ::
     StaticComposition
  -> ToolDescriptor
  -> CliOptions
  -> IO (Either ExecutionError PrimaryReport)
executeReportCommand static tool command =
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
           (ExecutionArgumentError (internal "Help reached report dispatch.")))
    VersionCommand ->
      pure
        (Left
           (ExecutionArgumentError (internal "Version reached report dispatch.")))

commandVerbosity :: CliOptions -> Verbosity
commandVerbosity command =
  case command of
    HelpCommand _ -> NormalVerbosity
    VersionCommand -> NormalVerbosity
    AdaptersCommand options -> reportVerbosity options
    ProfilesCommand options -> reportVerbosity options
    RulesCommand _ options -> reportVerbosity options
    ExplainCommand _ _ options -> reportVerbosity options
    ViewsCommand _ _ options -> reportVerbosity options
    QualificationSubjectsCommand _ _ options -> reportVerbosity options
    ValidateCommand _ _ _ options -> reportVerbosity options
    TraceCommand _ options -> reportVerbosity options
    QualifyCommand _ _ _ _ options -> reportVerbosity options
    ReadinessCommand _ _ _ options -> reportVerbosity options
    AssessCommand _ _ _ options -> reportVerbosity options

applyVerbosity :: Verbosity -> PrimaryReport -> PrimaryReport
applyVerbosity verbosity primary =
  primary
    { primaryHumanBytes =
        primaryHumanBytes primary
          <> case verbosity of
               NormalVerbosity -> ByteString.empty
               VerboseVerbosity -> verboseBytes
               DebugVerbosity -> verboseBytes <> debugBytes
    }
  where
    verboseBytes =
      lineBytes ("  exit=" <> Text.pack (show (primaryExitCode primary)))
    debugBytes =
      lineBytes
        ("  machine-utf8-hex=" <> byteStringHex (primaryJsonBytes primary))

byteStringHex :: ByteString -> Text
byteStringHex =
  Text.concat
    . map (Text.justifyRight 2 '0' . Text.pack . (`showHex` ""))
    . ByteString.unpack

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
                 ("O2I rules: discovered\n"
                    <> ruleAuthorityLine owner
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
  pure
    (foldRuleExplanation
       (\owner requested rule ->
          report
            ("O2I rule explanation: found\n"
               <> ruleAuthorityLine owner
               <> "  requested="
               <> safe requested
               <> "\n"
               <> ruleLine rule)
            machine
            0)
       (\owner requested ->
          report
            ("O2I rule explanation: not-found\n"
               <> ruleAuthorityLine owner
               <> "  requested="
               <> safe requested
               <> "\n")
            machine
            1)
       explanation)

ruleAuthorityLine :: DiscoveredRule.RuleAuthority -> Text
ruleAuthorityLine authority =
  DiscoveredRule.foldRuleAuthority
    (binding "operation" Nothing)
    (binding "core" Nothing)
    (\reference -> binding "profile" (Just reference))
    (\identifier -> binding "adapter" (Just (adapterIdText identifier)))
    authority
  where
    binding kind subject contract =
      DiscoveredRule.foldRuleContractBinding
        (\identity version digest ->
           "  authority="
             <> kind
             <> " | subject="
             <> maybe "unavailable" safe subject
             <> " | contract="
             <> safe identity
             <> " | version="
             <> safe version
             <> " | sha256="
             <> maybe "unavailable" safe digest
             <> "\n")
        contract

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
          human = Human.renderViews (ViewsHuman.viewHumanDiscovery tool outcome)
          exit = foldViewDiscovery (const 2) (const 0) outcome
          status =
            foldViewDiscovery (const "failed") (const "discovered") outcome
      pure (Right (report (humanOutput "views" status human) machine exit))

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
      let human =
            Human.renderQualificationSubjects
              (SubjectsHuman.qualificationSubjectsHumanReport tool result)
      case qualificationSubjectsDocument tool result of
        Left failure ->
          pure
            (Left
               (ExecutionCommandError
                  (qualificationSubjectsCommandError failure)
                  human))
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
                      (humanOutput "qualification-subjects" status human)
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
      let human =
            Human.renderValidate (ValidateHuman.validateHumanReport tool result)
      case validateResultDocument tool result of
        Left failure ->
          pure
            (Left (ExecutionCommandError (validateCommandError failure) human))
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
                      (humanOutput "validate" status human)
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
      let human = Human.renderTrace (TraceHuman.traceHumanReport tool result)
      case traceResultDocument tool result of
        Left failure -> pure (Left (traceExecutionError human failure))
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
                      (humanOutput "trace" status human)
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
      let human =
            Human.renderQualify (QualifyHuman.qualifyHumanReport tool result)
      case qualifyResultDocument tool result of
        Left failure ->
          pure
            (Left (ExecutionCommandError (qualifyCommandError failure) human))
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
                      (humanOutput "qualify" status human)
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
      let human =
            Human.renderReadiness
              (ReadinessHuman.readinessHumanReport tool result)
      case readinessResultDocument tool result of
        Left failure ->
          pure
            (Left (ExecutionCommandError (readinessCommandError failure) human))
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
                      (humanOutput "readiness" status human)
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
      let human = Human.renderAssess (AssessHuman.assessHumanReport tool result)
      case assessResultDocument tool result of
        Left failure ->
          pure (Left (ExecutionCommandError (assessCommandError failure) human))
        Right document ->
          let exitClass = assessResultExitClass result
           in pure
                (Right
                   (report
                      (humanOutput
                         "assess"
                         (assessExitClassText exitClass)
                         human)
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

humanOutput :: Text -> Text -> Text -> Text
humanOutput command status details =
  statusLine command status <> "  " <> details <> "\n"

safe :: Text -> Text
safe = terminalLiteral

argument :: Text -> CliError
argument = CliError "cli.argument.value"

traceExecutionError :: Text -> TraceFailure -> ExecutionError
traceExecutionError human failure =
  ExecutionCommandError (traceCommandError failure) human

internal :: Text -> CliError
internal = CliError "cli.internal.dispatch"

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
