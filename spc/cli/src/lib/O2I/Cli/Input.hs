{-# LANGUAGE OverloadedStrings #-}

-- | Total translation from exact CLI tokens to public Operation inputs.
module O2I.Cli.Input
  ( inputSourceFor
  , inputSourcesFor
  , adapterIdFor
  , viewSelectorFor
  , modelIdentityFor
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Cli.Options
import O2I.Operation.Acquisition (InputSource, fileInput, standardInput)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Adapter.Authoring (mkAdapterId)
import O2I.Operation.Identity (ModelIdentity, lexicalModelIdentity)
import O2I.Operation.Provenance (mkSourceReference)
import O2I.Operation.View (ViewSelector, viewByIdentity, viewByName)

-- | Interpret only the reserved standard-input token specially.
inputSourceFor :: FilePath -> Either CliError InputSource
inputSourceFor token = do
  reference <-
    mapLeft
      (const (inputError "The source reference is empty or contains U+0000."))
      (mkSourceReference (Text.pack token))
  if token == "-"
    then pure (standardInput reference)
    else mapLeft
           (const (inputError "The input path is empty or contains U+0000."))
           (fileInput reference token)

-- | Translate ordered physical source tokens without acquiring them.
inputSourcesFor :: [FilePath] -> Either CliError [InputSource]
inputSourcesFor = traverse inputSourceFor

-- | Validate one exact static Adapter identity.
adapterIdFor :: Text -> Either CliError AdapterId
adapterIdFor =
  mapLeft
    (const
       (CliError
          "cli.argument.adapter-id"
          "The adapter identity is empty or contains U+0000."))
    . mkAdapterId

-- | Preserve an exact View name or validate an exact model identity.
viewSelectorFor :: ViewSelection -> Either CliError ViewSelector
viewSelectorFor selection =
  case selection of
    ViewName name -> pure (viewByName name)
    ViewIdentifier identifier -> viewByIdentity <$> modelIdentityFor identifier

-- | Validate one exact identity without normalization.
modelIdentityFor :: Text -> Either CliError ModelIdentity
modelIdentityFor =
  mapLeft
    (const
       (CliError
          "cli.argument.model-identity"
          "A model identity must be non-empty Unicode scalar text without U+0000."))
    . lexicalModelIdentity

inputError :: Text -> CliError
inputError = CliError "cli.argument.input-source"

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
