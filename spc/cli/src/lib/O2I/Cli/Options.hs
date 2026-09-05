{-# LANGUAGE OverloadedStrings #-}

-- | Closed, exact command-line grammar for the O2I executable.
module O2I.Cli.Options
  ( CliOptions(..)
  , ReportOptions(..)
  , ModelOptions(..)
  , RuleAuthority(..)
  , ViewSelection(..)
  , ValidationLevel(..)
  , OutputMode(..)
  , Verbosity(..)
  , CliError(..)
  , parseCliOptions
  , commandHelp
  ) where

import Data.List (isPrefixOf, nub)
import Data.Text (Text)
import qualified Data.Text as Text

-- | One admitted top-level invocation. Help is retained as data so the
-- process boundary can emit it atomically like every other result.
data CliOptions
  = HelpCommand (Maybe [String])
  | VersionCommand
  | AdaptersCommand ReportOptions
  | ProfilesCommand ReportOptions
  | RulesCommand RuleAuthority ReportOptions
  | ExplainCommand RuleAuthority Text ReportOptions
  | ViewsCommand FilePath (Maybe Text) ReportOptions
  | QualificationSubjectsCommand ModelOptions [FilePath] ReportOptions
  | ValidateCommand ModelOptions ValidationLevel [FilePath] ReportOptions
  | TraceCommand ModelOptions ReportOptions
  | QualifyCommand ModelOptions [Text] [Text] [FilePath] ReportOptions
  | ReadinessCommand ModelOptions FilePath [FilePath] ReportOptions
  | AssessCommand ModelOptions FilePath [FilePath] ReportOptions
  deriving (Eq, Show)

-- | Output controls shared by every report command.
data ReportOptions = ReportOptions
  { reportOutputMode :: OutputMode
  , reportVerbosity :: Verbosity
  } deriving (Eq, Show)

-- | The common selected-View model request prefix.
data ModelOptions = ModelOptions
  { modelToken :: FilePath
  , modelView :: ViewSelection
  , modelAdapter :: Maybe Text
  } deriving (Eq, Show)

-- | Exact static rule owner selected by @rules@ or @explain@.
data RuleAuthority
  = AdapterRules Text
  | OperationRules
  | CoreRules
  | ProfileRules Text
  deriving (Eq, Show)

-- | Exactly one native View selector.
data ViewSelection
  = ViewName Text
  | ViewIdentifier Text
  deriving (Eq, Show)

-- | Last cumulative stage requested from Validate.
data ValidationLevel
  = NotationLevel
  | ProfileLevel
  | StructureLevel
  | SemanticsLevel
  deriving (Eq, Show)

-- | Human or stable machine-readable output intent.
data OutputMode
  = HumanOutput
  | JsonOutput
  deriving (Eq, Show)

-- | Human report detail. Debug is a strict extension of verbose.
data Verbosity
  = NormalVerbosity
  | VerboseVerbosity
  | DebugVerbosity
  deriving (Eq, Ord, Show)

-- | One deterministic invocation failure. Stable codes are CLI grammar
-- facts; canonical JSON projection remains an Operation-owned dependency.
data CliError = CliError
  { cliErrorCode :: Text
  , cliErrorMessage :: Text
  } deriving (Eq, Show)

data Parsed = Parsed
  { parsedPositionals :: [String]
  , parsedFlags :: [String]
  , parsedValues :: [(String, String)]
  } deriving (Eq, Show)

data Spec = Spec
  { specPositionals :: Int
  , specFlags :: [String]
  , specValues :: [String]
  , specRepeatedValues :: [String]
  }

-- | Parse the complete admitted grammar without performing I/O.
parseCliOptions :: [String] -> Either CliError CliOptions
parseCliOptions [] = Right (HelpCommand Nothing)
parseCliOptions ["--help"] = Right (HelpCommand Nothing)
parseCliOptions ["--version"] = Right VersionCommand
parseCliOptions ("adapters":arguments) =
  helpOr ["adapters"] arguments $ do
    parsed <- parseArguments reportSpec arguments
    AdaptersCommand <$> reportOptions parsed
parseCliOptions ("profiles":arguments) =
  helpOr ["profiles"] arguments $ do
    parsed <- parseArguments reportSpec arguments
    ProfilesCommand <$> reportOptions parsed
parseCliOptions ("rules":authority:arguments) =
  helpOr ["rules", authority] arguments $ do
    parsed <- parseArguments (authoritySpec authority 0) arguments
    selected <- ruleAuthority authority parsed
    RulesCommand selected <$> reportOptions parsed
parseCliOptions ("explain":authority:arguments) =
  helpOr ["explain", authority] arguments $ do
    parsed <- parseArguments (authoritySpec authority 1) arguments
    selected <- ruleAuthority authority parsed
    identifier <- positionalAt (authorityOperandOffset authority) parsed
    ExplainCommand selected (Text.pack identifier) <$> reportOptions parsed
parseCliOptions ("views":arguments) =
  helpOr ["views"] arguments $ do
    parsed <- parseArguments (modelFreeSpec 1) arguments
    model <- positionalAt 0 parsed
    adapter <- optionalOnce "--adapter" parsed
    reports <- reportOptions parsed
    pure (ViewsCommand model (Text.pack <$> adapter) reports)
parseCliOptions ("qualification-subjects":arguments) =
  helpOr ["qualification-subjects"] arguments $ do
    parsed <- parseArguments (modelSpec ["--supplement"]) arguments
    model <- selectedModel parsed
    supplements <- values "--supplement" parsed
    ensureAtMostOneStdin (modelToken model : supplements)
    reports <- reportOptions parsed
    pure (QualificationSubjectsCommand model supplements reports)
parseCliOptions ("validate":arguments) =
  helpOr ["validate"] arguments $ do
    parsed <- parseArguments (modelSpec ["--supplement", "--level"]) arguments
    model <- selectedModel parsed
    level <- requiredOnce "--level" parsed >>= validationLevel
    supplements <- values "--supplement" parsed
    if level /= SemanticsLevel && not (null supplements)
      then invalid
             "cli.argument.supplement-level"
             "--supplement is admitted only with --level semantics."
      else pure ()
    ensureAtMostOneStdin (modelToken model : supplements)
    reports <- reportOptions parsed
    pure (ValidateCommand model level supplements reports)
parseCliOptions ("trace":arguments) =
  helpOr ["trace"] arguments $ do
    parsed <- parseArguments (modelSpec []) arguments
    model <- selectedModel parsed
    reports <- reportOptions parsed
    pure (TraceCommand model reports)
parseCliOptions ("qualify":arguments) =
  helpOr ["qualify"] arguments $ do
    parsed <-
      parseArguments
        (modelSpec ["--strategy-id", "--need-id", "--supplement"])
        arguments
    model <- selectedModel parsed
    strategies <- map Text.pack <$> requiredMany "--strategy-id" parsed
    needs <- map Text.pack <$> values "--need-id" parsed
    ensureUnique "--strategy-id" strategies
    ensureUnique "--need-id" needs
    supplements <- values "--supplement" parsed
    ensureAtMostOneStdin (modelToken model : supplements)
    reports <- reportOptions parsed
    pure (QualifyCommand model strategies needs supplements reports)
parseCliOptions ("readiness":arguments) =
  helpOr ["readiness"] arguments $ do
    parsed <- parseArguments (modelSpec ["--input", "--supplement"]) arguments
    model <- selectedModel parsed
    input <- requiredOnce "--input" parsed
    supplements <- values "--supplement" parsed
    ensureAtMostOneStdin (modelToken model : input : supplements)
    reports <- reportOptions parsed
    pure (ReadinessCommand model input supplements reports)
parseCliOptions ("assess":arguments) =
  helpOr ["assess"] arguments $ do
    parsed <- parseArguments (modelSpec ["--input", "--supplement"]) arguments
    model <- selectedModel parsed
    input <- requiredOnce "--input" parsed
    supplements <- values "--supplement" parsed
    ensureAtMostOneStdin (modelToken model : input : supplements)
    reports <- reportOptions parsed
    pure (AssessCommand model input supplements reports)
parseCliOptions (command:_) =
  invalid "cli.argument.command" ("Unknown command: " <> Text.pack command)

helpOr ::
     [String]
  -> [String]
  -> Either CliError CliOptions
  -> Either CliError CliOptions
helpOr path ["--help"] _ = Right (HelpCommand (Just path))
helpOr _ _ parsed = parsed

reportSpec :: Spec
reportSpec = Spec 0 ["--json", "--verbose", "--debug"] [] []

modelFreeSpec :: Int -> Spec
modelFreeSpec count =
  Spec count ["--json", "--verbose", "--debug"] ["--adapter"] []

modelSpec :: [String] -> Spec
modelSpec extraValues =
  Spec
    1
    ["--json", "--verbose", "--debug"]
    (["--view", "--view-id", "--adapter"] <> extraValues)
    (filter (`elem` ["--supplement", "--strategy-id", "--need-id"]) extraValues)

authoritySpec :: String -> Int -> Spec
authoritySpec authority trailing =
  case authority of
    "operation" -> Spec trailing reportFlags [] []
    "core" -> Spec trailing reportFlags [] []
    "adapter" -> Spec (trailing + 1) reportFlags [] []
    "profile" -> Spec (trailing + 1) reportFlags [] []
    _ -> Spec (-1) [] [] []
  where
    reportFlags = ["--json", "--verbose", "--debug"]

authorityOperandOffset :: String -> Int
authorityOperandOffset authority =
  if authority `elem` ["adapter", "profile"]
    then 1
    else 0

parseArguments :: Spec -> [String] -> Either CliError Parsed
parseArguments spec arguments
  | specPositionals spec < 0 =
    invalid "cli.argument.authority" "Unknown rule authority."
  | otherwise = do
    parsed <- scan False [] [] [] arguments
    if length (parsedPositionals parsed) == specPositionals spec
      then pure parsed
      else invalid
             "cli.argument.positional-arity"
             "The command has the wrong number of positional operands."
  where
    scan _ positionals flags assigned [] =
      pure (Parsed (reverse positionals) (reverse flags) (reverse assigned))
    scan True positionals flags assigned remaining =
      pure
        (Parsed
           (reverse positionals <> remaining)
           (reverse flags)
           (reverse assigned))
    scan False positionals flags assigned ("--":remaining) =
      scan True positionals flags assigned remaining
    scan False positionals flags assigned (token:remaining)
      | token `elem` specFlags spec =
        if token `elem` flags
          then repeated token
          else scan False positionals (token : flags) assigned remaining
      | token `elem` specValues spec =
        case remaining of
          [] ->
            invalid
              "cli.argument.option-value"
              ("Missing value for " <> Text.pack token)
          value:rest ->
            if token `elem` specRepeatedValues spec
              then scan False positionals flags ((token, value) : assigned) rest
              else if any ((== token) . fst) assigned
                     then repeated token
                     else scan
                            False
                            positionals
                            flags
                            ((token, value) : assigned)
                            rest
      | token `elem` ["--help", "--version"] =
        invalid "cli.argument.option" ("Unknown option: " <> Text.pack token)
      | length positionals < specPositionals spec =
        scan False (token : positionals) flags assigned remaining
      | "--" `isPrefixOf` token && '=' `elem` token =
        invalid
          "cli.argument.name-value"
          ("name=value options are not admitted: " <> Text.pack token)
      | "-" `isPrefixOf` token =
        invalid "cli.argument.option" ("Unknown option: " <> Text.pack token)
      | otherwise = scan False (token : positionals) flags assigned remaining

ruleAuthority :: String -> Parsed -> Either CliError RuleAuthority
ruleAuthority authority parsed =
  case authority of
    "operation" -> pure OperationRules
    "core" -> pure CoreRules
    "adapter" -> AdapterRules . Text.pack <$> positionalAt 0 parsed
    "profile" -> ProfileRules . Text.pack <$> positionalAt 0 parsed
    _ -> invalid "cli.argument.authority" "Unknown rule authority."

selectedModel :: Parsed -> Either CliError ModelOptions
selectedModel parsed = do
  model <- positionalAt 0 parsed
  byName <- optionalOnce "--view" parsed
  byIdentity <- optionalOnce "--view-id" parsed
  view <-
    case (byName, byIdentity) of
      (Just name, Nothing) -> pure (ViewName (Text.pack name))
      (Nothing, Just identifier) -> pure (ViewIdentifier (Text.pack identifier))
      _ ->
        invalid
          "cli.argument.view-selector"
          "Exactly one of --view or --view-id is required."
  adapter <- optionalOnce "--adapter" parsed
  pure (ModelOptions model view (Text.pack <$> adapter))

reportOptions :: Parsed -> Either CliError ReportOptions
reportOptions parsed = do
  let verbose = "--verbose" `elem` parsedFlags parsed
      debug = "--debug" `elem` parsedFlags parsed
  if verbose && debug
    then invalid
           "cli.argument.verbosity"
           "--verbose and --debug are mutually exclusive."
    else pure
           (ReportOptions
              (if "--json" `elem` parsedFlags parsed
                 then JsonOutput
                 else HumanOutput)
              (if debug
                 then DebugVerbosity
                 else if verbose
                        then VerboseVerbosity
                        else NormalVerbosity))

validationLevel :: String -> Either CliError ValidationLevel
validationLevel value =
  case value of
    "notation" -> pure NotationLevel
    "profile" -> pure ProfileLevel
    "structure" -> pure StructureLevel
    "semantics" -> pure SemanticsLevel
    _ ->
      invalid
        "cli.argument.validation-level"
        "--level must be notation, profile, structure, or semantics."

positionalAt :: Int -> Parsed -> Either CliError String
positionalAt index parsed =
  case drop index (parsedPositionals parsed) of
    value:_ -> pure value
    [] ->
      invalid "cli.argument.positional-arity" "A positional operand is missing."

values :: String -> Parsed -> Either CliError [String]
values option parsed =
  pure [value | (name, value) <- parsedValues parsed, name == option]

optionalOnce :: String -> Parsed -> Either CliError (Maybe String)
optionalOnce option parsed = do
  found <- values option parsed
  case found of
    [] -> pure Nothing
    [value] -> pure (Just value)
    _ -> repeated option

requiredOnce :: String -> Parsed -> Either CliError String
requiredOnce option parsed = do
  found <- optionalOnce option parsed
  maybe
    (invalid
       "cli.argument.required-option"
       ("Missing required option " <> Text.pack option <> "."))
    pure
    found

requiredMany :: String -> Parsed -> Either CliError [String]
requiredMany option parsed = do
  found <- values option parsed
  if null found
    then invalid
           "cli.argument.required-option"
           ("At least one " <> Text.pack option <> " is required.")
    else pure found

ensureUnique :: Eq value => String -> [value] -> Either CliError ()
ensureUnique option supplied =
  if length supplied == length (nub supplied)
    then pure ()
    else repeated option

ensureAtMostOneStdin :: [FilePath] -> Either CliError ()
ensureAtMostOneStdin sources =
  if length (filter (== "-") sources) <= 1
    then pure ()
    else invalid
           "cli.argument.stdin-cardinality"
           "At most one physical input may use standard input."

repeated :: String -> Either CliError value
repeated option =
  invalid
    "cli.argument.repeated-option"
    ("Option may not be repeated: " <> Text.pack option)

invalid :: Text -> Text -> Either CliError value
invalid code message = Left (CliError code message)

-- | Exact human help for the root or one admitted command path.
commandHelp :: Maybe [String] -> Text
commandHelp Nothing =
  Text.unlines
    [ "Usage: o2i COMMAND"
    , ""
    , "Commands: adapters, profiles, rules, explain, views,"
    , "          qualification-subjects, validate, trace, qualify,"
    , "          readiness, assess"
    , ""
    , "Use o2i COMMAND --help for the exact command grammar."
    ]
commandHelp (Just path) =
  "Usage: o2i "
    <> Text.unwords (map Text.pack path)
    <> commandSuffix path
    <> "\n"

commandSuffix :: [String] -> Text
commandSuffix path =
  case path of
    ["adapters"] -> " [--json] [--verbose | --debug]"
    ["profiles"] -> " [--json] [--verbose | --debug]"
    ["rules", "adapter"] -> " ADAPTER [--json] [--verbose | --debug]"
    ["rules", "operation"] -> " [--json] [--verbose | --debug]"
    ["rules", "core"] -> " [--json] [--verbose | --debug]"
    ["rules", "profile"] -> " PROFILE-REF [--json] [--verbose | --debug]"
    ["explain", "adapter"] -> " ADAPTER RULE-ID [--json] [--verbose | --debug]"
    ["explain", "operation"] -> " RULE-ID [--json] [--verbose | --debug]"
    ["explain", "core"] -> " RULE-ID [--json] [--verbose | --debug]"
    ["explain", "profile"] ->
      " PROFILE-REF RULE-ID [--json] [--verbose | --debug]"
    ["views"] -> " MODEL [--adapter ID] [--json] [--verbose | --debug]"
    ["qualification-subjects"] -> modelUsage <> supplementUsage
    ["validate"] -> modelUsage <> " --level LEVEL" <> supplementUsage
    ["trace"] -> modelUsage
    ["qualify"] ->
      modelUsage <> " --strategy-id ID... [--need-id ID...]" <> supplementUsage
    ["readiness"] -> modelUsage <> " --input PATH|-" <> supplementUsage
    ["assess"] -> modelUsage <> " --input PATH|-" <> supplementUsage
    _ -> ""
  where
    modelUsage = " MODEL (--view NAME | --view-id ID) [--adapter ID]"
    supplementUsage =
      " [--supplement PATH|- ...] [--json] [--verbose | --debug]"
