{-# LANGUAGE OverloadedStrings #-}

-- | Closed command-line grammar for the O2I executable.
module O2I.Cli.Options
  ( CliOptions(..)
  , InspectOptions(..)
  , ViewSelection(..)
  , OutputMode(..)
  , Verbosity(..)
  , cliParserInfo
  , parseCliOptions
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (showVersion)
import Options.Applicative
import qualified Paths_o2i_cli as Package

-- | One supported top-level operation.
data CliOptions
  = InspectCommand
      { inspectCommandOptions :: InspectOptions
      }
  | BuildRevisionCommand
  deriving (Eq, Show)

-- | Complete invocation data for one model inspection.
data InspectOptions = InspectOptions
  { inspectModelToken :: FilePath
  , inspectViewSelection :: ViewSelection
  , inspectVerbosity :: Verbosity
  , inspectOutputMode :: OutputMode
  } deriving (Eq, Show)

-- | Exact View selector spelling accepted by the CLI.
data ViewSelection
  = ViewName Text
  | ViewIdentifier Text
  deriving (Eq, Show)

-- | Human or stable machine-readable report output.
data OutputMode
  = HumanOutput
  | JsonOutput
  deriving (Eq, Show)

-- | Human diagnostic detail; debug is a strict extension of verbose.
data Verbosity
  = NormalVerbosity
  | VerboseVerbosity
  | DebugVerbosity
  deriving (Eq, Ord, Show)

-- | Complete parser metadata used by the executable and parser tests.
cliParserInfo :: ParserInfo CliOptions
cliParserInfo =
  info
    (operationParser <**> helper <**> versionOption)
    (fullDesc
       <> progDesc "Inspect an O2I model in one exact Archi View."
       <> header "O2I - From orientation to impact, © 2026 nemron")

-- | Parse arguments without performing I/O or terminating the process.
parseCliOptions :: [String] -> ParserResult CliOptions
parseCliOptions = execParserPure defaultPrefs cliParserInfo

operationParser :: Parser CliOptions
operationParser = buildRevisionParser <|> commandParser

commandParser :: Parser CliOptions
commandParser =
  hsubparser
    (command
       "inspect"
       (info
          (InspectCommand <$> inspectParser)
          (progDesc "Inspect one View of a native Archi model.")))

buildRevisionParser :: Parser CliOptions
buildRevisionParser =
  flag'
    BuildRevisionCommand
    (long "build-revision" <> help "Write the bound source commit SHA.")

inspectParser :: Parser InspectOptions
inspectParser =
  InspectOptions
    <$> strArgument
          (metavar "MODEL" <> help "Model path, or - for standard input.")
    <*> viewParser
    <*> verbosityParser
    <*> outputParser

viewParser :: Parser ViewSelection
viewParser =
  (ViewName . Text.pack
     <$> strOption
           (long "view" <> metavar "NAME" <> help "Select an exact View name."))
    <|> (ViewIdentifier . Text.pack
           <$> strOption
                 (long "view-id"
                    <> metavar "ID"
                    <> help "Select a stable View identifier."))

verbosityParser :: Parser Verbosity
verbosityParser =
  flag' DebugVerbosity (long "debug" <> help "Show diagnostic detail.")
    <|> flag'
          VerboseVerbosity
          (long "verbose" <> help "Show inspection progress.")
    <|> pure NormalVerbosity

outputParser :: Parser OutputMode
outputParser =
  flag
    HumanOutput
    JsonOutput
    (long "json" <> help "Write one stable JSON document.")

versionOption :: Parser (a -> a)
versionOption =
  infoOption
    ("o2i " <> showVersion Package.version)
    (long "version" <> help "Show the O2I version.")
