{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed, invariant-preserving command errors for thin executables.
--
-- The executable owns grammar and human rendering. Operation validates the
-- exact CLI-supplied argument code and message, retains existing typed process
-- and preparation failures, and owns their machine-document projection.
module O2I.Operation.Command.Error
  ( type ArgumentFailureField
  , argumentFailureCodeField
  , argumentFailureMessageField
  , argumentFailureFieldText
  , foldArgumentFailureField
  , type ArgumentFailureDefect
  , foldArgumentFailureDefect
  , type ArgumentFailure
  , argumentFailure
  , argumentFailureCode
  , argumentFailureMessage
  , foldArgumentFailure
  , type CommandError
  , argumentCommandError
  , processCommandError
  , commonCommandError
  , commandErrorCode
  , foldCommandError
  ) where

import Data.Char (isAsciiLower, isDigit, ord)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Operation.Command.Error.Internal
import O2I.Operation.Failure
  ( CommandFailure
  , CommonFailure
  , PreparationFailure
  , commandFailureCode
  , foldCommonFailure
  , preparationFailureCode
  )

-- | Stable argument-code field.
argumentFailureCodeField :: ArgumentFailureField
argumentFailureCodeField = ArgumentFailureCodeField

-- | Exact human-message field.
argumentFailureMessageField :: ArgumentFailureField
argumentFailureMessageField = ArgumentFailureMessageField

-- | Stable machine token for one validated argument-failure field.
argumentFailureFieldText :: ArgumentFailureField -> Text
argumentFailureFieldText field =
  case field of
    ArgumentFailureCodeField -> "code"
    ArgumentFailureMessageField -> "message"

-- | Consume the complete argument-failure field vocabulary.
foldArgumentFailureField :: result -> result -> ArgumentFailureField -> result
foldArgumentFailureField code message field =
  case field of
    ArgumentFailureCodeField -> code
    ArgumentFailureMessageField -> message

-- | Consume every argument-failure authoring defect.
foldArgumentFailureDefect ::
     (Text -> result)
  -> (ArgumentFailureField -> result)
  -> (ArgumentFailureField -> result)
  -> (ArgumentFailureField -> result)
  -> ArgumentFailureDefect
  -> result
foldArgumentFailureDefect invalidCode empty nul surrogate defect =
  case defect of
    InvalidArgumentFailureCode code -> invalidCode code
    EmptyArgumentFailureField field -> empty field
    ArgumentFailureFieldContainsNul field -> nul field
    ArgumentFailureFieldContainsSurrogate field -> surrogate field

-- | Validate one exact CLI argument error without normalization or fallback.
--
-- Codes are closed to the @cli.argument.*@ namespace and one lower-case token;
-- both scalars must be non-empty Unicode scalar sequences excluding U+0000.
argumentFailure ::
     Text -> Text -> Either (NonEmpty ArgumentFailureDefect) ArgumentFailure
argumentFailure code message =
  case NonEmpty.nonEmpty defects of
    Nothing -> Right (ArgumentFailure code message)
    Just failures -> Left failures
  where
    codeDefects = fieldDefects ArgumentFailureCodeField code
    messageDefects = fieldDefects ArgumentFailureMessageField message
    grammarDefects =
      [ InvalidArgumentFailureCode code
      | null codeDefects
      , not (validArgumentCode code)
      ]
    defects = codeDefects <> grammarDefects <> messageDefects

-- | Project the validated stable argument-error code.
argumentFailureCode :: ArgumentFailure -> Text
argumentFailureCode (ArgumentFailure code _) = code

-- | Project the exact validated human message.
argumentFailureMessage :: ArgumentFailure -> Text
argumentFailureMessage (ArgumentFailure _ message) = message

-- | Consume both validated argument-failure fields in machine order.
foldArgumentFailure :: (Text -> Text -> result) -> ArgumentFailure -> result
foldArgumentFailure consume (ArgumentFailure code message) =
  consume code message

-- | Lift one validated CLI argument failure into the command boundary.
argumentCommandError :: ArgumentFailure -> CommandError
argumentCommandError = ArgumentCommandError

-- | Lift one process-level Operation failure into the command boundary.
processCommandError :: CommandFailure -> CommandError
processCommandError = ProcessCommandError

-- | Lift either common Operation failure without losing its closed branch.
commonCommandError :: CommonFailure -> CommandError
commonCommandError =
  foldCommonFailure ProcessCommandError PreparationCommandError

-- | Stable machine code of the exact retained command-error branch.
commandErrorCode :: CommandError -> Text
commandErrorCode commandError =
  case commandError of
    ArgumentCommandError failure -> argumentFailureCode failure
    ProcessCommandError failure -> commandFailureCode failure
    PreparationCommandError failure -> preparationFailureCode failure

-- | Consume every closed command-error branch without exposing constructors.
foldCommandError ::
     (ArgumentFailure -> result)
  -> (CommandFailure -> result)
  -> (PreparationFailure -> result)
  -> CommandError
  -> result
foldCommandError argument process preparation commandError =
  case commandError of
    ArgumentCommandError failure -> argument failure
    ProcessCommandError failure -> process failure
    PreparationCommandError failure -> preparation failure

fieldDefects :: ArgumentFailureField -> Text -> [ArgumentFailureDefect]
fieldDefects field value =
  [EmptyArgumentFailureField field | Text.null value]
    <> [ArgumentFailureFieldContainsNul field | Text.any (== '\NUL') value]
    <> [ ArgumentFailureFieldContainsSurrogate field
       | Text.any isSurrogate value
       ]

validArgumentCode :: Text -> Bool
validArgumentCode code =
  case Text.stripPrefix "cli.argument." code of
    Nothing -> False
    Just token -> validToken token

validToken :: Text -> Bool
validToken value =
  case Text.unpack value of
    [] -> False
    first:rest ->
      isAsciiLower first
        && all validTail rest
        && maybe False asciiAlphaNumeric (snd <$> Text.unsnoc value)
        && not ("--" `Text.isInfixOf` value)
  where
    validTail character = asciiAlphaNumeric character || character == '-'

asciiAlphaNumeric :: Char -> Bool
asciiAlphaNumeric character = isAsciiLower character || isDigit character

isSurrogate :: Char -> Bool
isSurrogate character =
  let codePoint = ord character
   in codePoint >= 0xd800 && codePoint <= 0xdfff
