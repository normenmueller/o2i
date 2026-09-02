{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed, invariant-preserving command errors for thin executables.
--
-- The executable owns grammar and human rendering. Operation validates the
-- exact CLI-supplied argument code and message, retains existing typed process
-- and preparation failures, retains every capability failure without erasing
-- its owner evidence, and owns their machine-document projection.
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
  , type CommandDiagnosticValue
  , foldCommandDiagnosticValue
  , type CommandDiagnosticField
  , foldCommandDiagnosticField
  , type CommandInputDiagnostic
  , foldCommandInputDiagnostic
  , supplementalCommandInputDiagnostic
  , readinessCommandInputDiagnostic
  , assessmentCommandInputDiagnostic
  , type CommandOwnerEvidence
  , foldCommandOwnerEvidence
  , type CommandOwnerDiagnostic
  , foldCommandOwnerDiagnostic
  , validateCommandOwnerDiagnostic
  , qualifyCommandOwnerDiagnostic
  , readinessCommandOwnerDiagnostic
  , assessCommandOwnerDiagnostic
  , type CommandError
  , argumentCommandError
  , processCommandError
  , commonCommandError
  , validateCommandError
  , qualifyCommandError
  , readinessCommandError
  , assessCommandError
  , commandErrorCode
  , foldCommandError
  ) where

import Data.Char (isAsciiLower, isDigit, ord)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Operation.Assess.Result (AssessFailure, foldAssessFailure)
import O2I.Operation.Command.Error.Branch.Generated (commandOwnerBranchToken)
import O2I.Operation.Command.Error.Internal
import O2I.Operation.Command.Error.Projection.Internal
import O2I.Operation.Failure
  ( CommandFailure
  , CommonFailure
  , PreparationFailure
  , commandFailureCode
  , commonFailureCode
  , foldCommonFailure
  , preparationFailureCode
  )
import O2I.Operation.Qualify.Result (QualifyFailure, foldQualifyFailure)
import O2I.Operation.Readiness.Result (ReadinessFailure, foldReadinessFailure)
import O2I.Operation.Validate.Result (ValidateFailure, foldValidateFailure)

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

-- | Consume one retained command-diagnostic value through its exact closed
-- representation. Compound identities remain atomic and cannot be
-- reassociated with another producer-selected field.
foldCommandDiagnosticValue ::
     (Text -> result)
  -> (Natural -> result)
  -> (Text -> result)
  -> (Text -> result)
  -> (Text -> result)
  -> (Text -> Natural -> result)
  -> (Text -> Natural -> Text -> Text -> result)
  -> (Text -> Text -> Text -> Text -> result)
  -> (Text -> Natural -> result)
  -> (Natural -> Natural -> result)
  -> CommandDiagnosticValue
  -> result
foldCommandDiagnosticValue text natural model occurrence qualified sourceKey source adapter canonical unicode value =
  case value of
    CommandDiagnosticText retained -> text retained
    CommandDiagnosticNatural retained -> natural retained
    CommandDiagnosticModelIdentity retained -> model retained
    CommandDiagnosticOccurrenceIdentity retained -> occurrence retained
    CommandDiagnosticQualifiedType retained -> qualified retained
    CommandDiagnosticSourceKey role ordinal -> sourceKey role ordinal
    CommandDiagnosticSourceIdentity role ordinal reference digest ->
      source role ordinal reference digest
    CommandDiagnosticAdapterDescriptor identifier name version notation ->
      adapter identifier name version notation
    CommandDiagnosticCanonicalOccurrence kind ordinal -> canonical kind ordinal
    CommandDiagnosticUnicodeScalar index codePoint -> unicode index codePoint

-- | Consume one producer-selected field name and its complete ordered values.
foldCommandDiagnosticField ::
     (Text -> [CommandDiagnosticValue] -> result)
  -> CommandDiagnosticField
  -> result
foldCommandDiagnosticField consume fieldValue =
  case fieldValue of
    CommandDiagnosticField name values -> consume name values

-- | Consume one complete capability-input diagnostic without exposing its
-- constructor or any authoring surface.
foldCommandInputDiagnostic ::
     (Text -> NonEmpty Natural -> Text -> [CommandDiagnosticField] -> result)
  -> CommandInputDiagnostic
  -> result
foldCommandInputDiagnostic consume diagnostic =
  case diagnostic of
    CommandInputDiagnostic rule ordinals reason fields ->
      consume rule ordinals reason fields

-- | Consume one retained owner-evidence occurrence.
foldCommandOwnerEvidence ::
     (Text -> [CommandDiagnosticField] -> result)
  -> CommandOwnerEvidence
  -> result
foldCommandOwnerEvidence consume evidence =
  case evidence of
    CommandOwnerEvidence kind fields -> consume kind fields

-- | Consume the exact owner-contract branch and all of its ordered evidence.
foldCommandOwnerDiagnostic ::
     (Text -> NonEmpty CommandOwnerEvidence -> result)
  -> CommandOwnerDiagnostic
  -> result
foldCommandOwnerDiagnostic consume diagnostic =
  case diagnostic of
    CommandOwnerDiagnostic branch evidence ->
      consume (commandOwnerBranchToken branch) evidence

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

-- | Retain one complete Validate failure at the command boundary. Common
-- failures delegate immediately to their canonical command representation.
validateCommandError :: ValidateFailure -> CommandError
validateCommandError failure =
  foldValidateFailure
    commonCommandError
    (const (ValidateCommandError failure))
    (const (ValidateCommandError failure))
    failure

-- | Retain one complete Qualify failure at the command boundary. Common
-- failures delegate immediately to their canonical command representation.
qualifyCommandError :: QualifyFailure -> CommandError
qualifyCommandError failure =
  foldQualifyFailure
    commonCommandError
    (const (QualifyCommandError failure))
    (const (QualifyCommandError failure))
    failure

-- | Retain one complete Readiness failure at the command boundary. Common
-- failures delegate immediately to their canonical command representation.
readinessCommandError :: ReadinessFailure -> CommandError
readinessCommandError failure =
  foldReadinessFailure
    commonCommandError
    (const (ReadinessCommandError failure))
    (const (ReadinessCommandError failure))
    (const (ReadinessCommandError failure))
    failure

-- | Retain one complete Assess failure at the command boundary. Common
-- failures delegate immediately to their canonical command representation.
assessCommandError :: AssessFailure -> CommandError
assessCommandError failure =
  foldAssessFailure
    commonCommandError
    (const (AssessCommandError failure))
    (const (AssessCommandError failure))
    (const (AssessCommandError failure))
    failure

-- | Stable machine code of the exact retained command-error branch.
commandErrorCode :: CommandError -> Text
commandErrorCode commandError =
  case commandError of
    ArgumentCommandError failure -> argumentFailureCode failure
    ProcessCommandError failure -> commandFailureCode failure
    PreparationCommandError failure -> preparationFailureCode failure
    ValidateCommandError failure ->
      foldValidateFailure
        commonFailureCode
        (const "validate.supplemental-input")
        (const "validate.owner-contract")
        failure
    QualifyCommandError failure ->
      foldQualifyFailure
        commonFailureCode
        (const "qualify.supplemental-input")
        (const "qualify.owner-contract")
        failure
    ReadinessCommandError failure ->
      foldReadinessFailure
        commonFailureCode
        (const "readiness.evidence-input")
        (const "readiness.supplemental-input")
        (const "readiness.owner-contract")
        failure
    AssessCommandError failure ->
      foldAssessFailure
        commonFailureCode
        (const "assess.assessment-input")
        (const "assess.supplemental-input")
        (const "assess.owner-contract")
        failure

-- | Consume every closed command-error branch without exposing constructors.
foldCommandError ::
     (ArgumentFailure -> result)
  -> (CommandFailure -> result)
  -> (PreparationFailure -> result)
  -> (ValidateFailure -> result)
  -> (QualifyFailure -> result)
  -> (ReadinessFailure -> result)
  -> (AssessFailure -> result)
  -> CommandError
  -> result
foldCommandError argument process preparation validate qualify readiness assess commandError =
  case commandError of
    ArgumentCommandError failure -> argument failure
    ProcessCommandError failure -> process failure
    PreparationCommandError failure -> preparation failure
    ValidateCommandError failure -> validate failure
    QualifyCommandError failure -> qualify failure
    ReadinessCommandError failure -> readiness failure
    AssessCommandError failure -> assess failure

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
