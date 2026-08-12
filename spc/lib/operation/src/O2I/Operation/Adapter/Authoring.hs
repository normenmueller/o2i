{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE RankNTypes #-}

-- | Validated construction boundary for compiled notation adapters.
--
-- Adapter packages use these functions to define one static adapter. Runtime
-- model input can select from the resulting collection but can never extend it.
module O2I.Operation.Adapter.Authoring
  ( AdapterDefinitionField(..)
  , AdapterDefinitionDefect(..)
  , AdapterCompilationDefect(..)
  , AdapterCollectionDefect(..)
  , type AdapterRuleDefinition
  , type AdapterDefinition
  , type RecognitionRule
  , type DecodeRule
  , type RecognitionDiagnostic
  , type DecodeDiagnostic
  , type RecognitionResult
  , type DecodeResult
  , type AdapterBehavior
  , mkAdapterId
  , mkAdapterDescriptor
  , mkAdapterRuleDefinition
  , recognitionRule
  , decodeRule
  , nativeByteOffset
  , nativeLineColumn
  , nativePath
  , unlocatedOccurrence
  , locatedOccurrence
  , recognitionDiagnostic
  , decodeDiagnostic
  , noRecognitionMatch
  , recognitionMatch
  , recognitionFailure
  , decodeFailure
  , decodedDraft
  , adapterBehavior
  , compileAdapter
  , compileAdapterCollection
  ) where

import Data.ByteString (ByteString)
import Data.Function (on)
import Data.List (groupBy, sortBy)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)
import O2I.Operation.Adapter.Internal

-- | Validate one stable adapter identifier.
mkAdapterId :: Text -> Either AdapterDefinitionDefect AdapterId
mkAdapterId value = AdapterId <$> validateText AdapterIdentifierField value

-- | Validate all immutable fields of one compiled adapter descriptor.
mkAdapterDescriptor ::
     AdapterId
  -> Text
  -> Text
  -> Text
  -> Either (NonEmpty AdapterDefinitionDefect) AdapterDescriptor
mkAdapterDescriptor identifier name version notation =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        AdapterDescriptor
          { adapterDescriptorIdValue = identifier
          , adapterDescriptorNameValue = name
          , adapterDescriptorVersionValue = version
          , adapterDescriptorNotationValue = notation
          }
  where
    defects =
      validateTextDefects AdapterNameField name
        <> validateTextDefects AdapterVersionField version
        <> validateTextDefects AdapterNotationField notation

-- | Validate one stage-neutral native-rule definition.
--
-- The stage and owning adapter are assigned only inside one 'compileAdapter'
-- definition. A validated definition therefore carries no executable
-- authority by itself.
mkAdapterRuleDefinition ::
     Text
  -> Text
  -> Text
  -> Text
  -> Either (NonEmpty AdapterDefinitionDefect) AdapterRuleDefinition
mkAdapterRuleDefinition identifier expectation meaning action =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        AdapterRuleDefinition
          { adapterRuleDefinitionIdValue = AdapterRuleId identifier
          , adapterRuleDefinitionExpectationValue = expectation
          , adapterRuleDefinitionMeaningValue = meaning
          , adapterRuleDefinitionActionValue = action
          }
  where
    defects =
      validateTextDefects AdapterRuleIdentifierField identifier
        <> validateTextDefects AdapterRuleExpectationField expectation
        <> validateTextDefects AdapterRuleMeaningField meaning
        <> validateTextDefects AdapterRuleActionField action

-- | Declare one recognition-stage rule in the current adapter scope.
recognitionRule ::
     AdapterRuleDefinition -> AdapterDefinition scope (RecognitionRule scope)
recognitionRule definition =
  AdapterDefinition (rule :) (RecognitionRule (ScopedRule rule))
  where
    rule = materializeRule AdapterRecognitionStage definition

-- | Declare one decode-stage rule in the current adapter scope.
decodeRule ::
     AdapterRuleDefinition -> AdapterDefinition scope (DecodeRule scope)
decodeRule definition =
  AdapterDefinition (rule :) (DecodeRule (ScopedRule rule))
  where
    rule = materializeRule AdapterDecodeStage definition

-- | Address one exact byte offset in the acquired native source.
nativeByteOffset :: Natural -> NativeLocation
nativeByteOffset = NativeByteOffset

-- | Address a one-based line and column in the acquired native source.
nativeLineColumn ::
     Natural -> Natural -> Either AdapterDefinitionDefect NativeLocation
nativeLineColumn line column
  | line == 0 || column == 0 = Left (InvalidNativeLineColumn line column)
  | otherwise = Right (NativeLineColumn line column)

-- | Validate one non-empty native source path.
nativePath ::
     NonEmpty Text -> Either (NonEmpty AdapterDefinitionDefect) NativeLocation
nativePath steps =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing -> Right (NativePath steps)
  where
    defects =
      concatMap
        (validateTextDefects AdapterPathStepField)
        (NonEmpty.toList steps)

-- | Record a diagnostic occurrence for which the native format has no
-- addressable position.
unlocatedOccurrence :: AdapterOccurrence
unlocatedOccurrence = AdapterOccurrence Nothing

-- | Bind a diagnostic occurrence to one native source location.
locatedOccurrence :: NativeLocation -> AdapterOccurrence
locatedOccurrence = AdapterOccurrence . Just

-- | Bind one recognition-stage rule from this adapter definition to every
-- exact native occurrence it detected.
recognitionDiagnostic ::
     RecognitionRule scope
  -> NonEmpty AdapterOccurrence
  -> RecognitionDiagnostic scope
recognitionDiagnostic (RecognitionRule (ScopedRule rule)) =
  RecognitionDiagnostic . AdapterDiagnostic rule

-- | Bind one decode-stage rule from this adapter definition to every exact
-- native occurrence it detected.
decodeDiagnostic ::
     DecodeRule scope -> NonEmpty AdapterOccurrence -> DecodeDiagnostic scope
decodeDiagnostic (DecodeRule (ScopedRule rule)) =
  DecodeDiagnostic . AdapterDiagnostic rule

-- | Report that a recognizer found no evidence for its native format.
noRecognitionMatch :: RecognitionResult scope
noRecognitionMatch = ScopedRecognitionNoMatch

-- | Report that a recognizer identified its native format.
recognitionMatch :: RecognitionResult scope
recognitionMatch = ScopedRecognitionMatch

-- | Report that recognition itself could not complete.
recognitionFailure ::
     NonEmpty (RecognitionDiagnostic scope) -> RecognitionResult scope
recognitionFailure = ScopedRecognitionFailed

-- | Report a final selected-adapter decode failure.
decodeFailure :: NonEmpty (DecodeDiagnostic scope) -> DecodeResult scope
decodeFailure = ScopedDecodeFailed

-- | Return one observation-complete profile-neutral Draft.
decodedDraft :: ProfileDraft -> DecodeResult scope
decodedDraft = ScopedDecodePassed

-- | Bind pure recognition and decode behavior to the scoped rules declared by
-- one adapter definition.
adapterBehavior ::
     (ByteString -> RecognitionResult scope)
  -> (ByteString -> DecodeResult scope)
  -> AdapterBehavior scope
adapterBehavior = AdapterBehavior

-- | Compile one static adapter from one closed, applicative definition.
--
-- The rank-2 scope prevents rule handles from escaping or crossing adapter
-- definitions. Separate recognition and decode handles make wrong-stage
-- diagnostics unrepresentable. Compilation derives the canonical inventory
-- and executable behavior from the same definition in @O(R log R)@.
compileAdapter ::
     AdapterDescriptor
  -> (forall scope. AdapterDefinition scope (AdapterBehavior scope))
  -> Either (NonEmpty AdapterCompilationDefect) Adapter
compileAdapter descriptor definition =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      case NonEmpty.nonEmpty canonicalRules of
        Nothing -> Left (EmptyAdapterRuleInventory NonEmpty.:| [])
        Just rules ->
          Right
            Adapter
              { adapterDescriptorValue = descriptor
              , adapterRulesValue = rules
              , adapterRecognizeValue =
                  eraseRecognition . adapterBehaviorRecognizeValue behavior
              , adapterDecodeValue =
                  eraseDecode . adapterBehaviorDecodeValue behavior
              }
  where
    AdapterDefinition collectRules behavior = definition
    suppliedRules = collectRules []
    canonicalRules = sortBy (comparing adapterRuleIdValue) suppliedRules
    defects =
      [ DuplicateAdapterRuleIdentifier identifier
      | identifier <- duplicateKeys adapterRuleIdValue canonicalRules
      ]

-- | Validate and canonically order one non-empty static adapter collection.
--
-- Collection construction is @O(A log A)@ for @A@ already compiled adapters.
-- Exact adapter lookup is @O(log A)@.
compileAdapterCollection ::
     NonEmpty Adapter
  -> Either (NonEmpty AdapterCollectionDefect) AdapterCollection
compileAdapterCollection supplied =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        AdapterCollection
          { adapterCollectionEntriesValue = canonical
          , adapterCollectionByIdValue =
              Map.fromList
                [ (descriptorId (adapterDescriptorValue value), value)
                | value <- NonEmpty.toList canonical
                ]
          }
  where
    canonical =
      NonEmpty.sortBy
        (comparing (descriptorId . adapterDescriptorValue))
        supplied
    defects = duplicateAdapterDefects canonical

validateText ::
     AdapterDefinitionField -> Text -> Either AdapterDefinitionDefect Text
validateText field value =
  case validateTextDefects field value of
    [] -> Right value
    defect:_ -> Left defect

validateTextDefects ::
     AdapterDefinitionField -> Text -> [AdapterDefinitionDefect]
validateTextDefects field value =
  [EmptyAdapterDefinitionField field | Text.null value]
    <> [AdapterDefinitionFieldContainsNul field | Text.any (== '\NUL') value]

descriptorId :: AdapterDescriptor -> AdapterId
descriptorId = adapterDescriptorIdValue

duplicateAdapterDefects :: NonEmpty Adapter -> [AdapterCollectionDefect]
duplicateAdapterDefects values =
  [ DuplicateAdapterIdentifier identifier
  | identifier <-
      duplicateKeys
        (descriptorId . adapterDescriptorValue)
        (NonEmpty.toList values)
  ]

duplicateKeys :: Ord key => (value -> key) -> [value] -> [key]
duplicateKeys key =
  mapMaybe repeatedKey . groupBy ((==) `on` key) . sortBy (comparing key)
  where
    repeatedKey (first:_:_) = Just (key first)
    repeatedKey _ = Nothing

materializeRule :: AdapterRuleStage -> AdapterRuleDefinition -> AdapterRule
materializeRule stage definition =
  AdapterRule
    { adapterRuleIdValue = adapterRuleDefinitionIdValue definition
    , adapterRuleStageValue = stage
    , adapterRuleExpectationValue =
        adapterRuleDefinitionExpectationValue definition
    , adapterRuleMeaningValue = adapterRuleDefinitionMeaningValue definition
    , adapterRuleActionValue = adapterRuleDefinitionActionValue definition
    }

eraseRecognition :: RecognitionResult scope -> Recognition
eraseRecognition result =
  case result of
    ScopedRecognitionNoMatch -> RecognitionNoMatch
    ScopedRecognitionMatch -> RecognitionMatch
    ScopedRecognitionFailed diagnostics ->
      RecognitionFailed (fmap eraseRecognitionDiagnostic diagnostics)

eraseRecognitionDiagnostic :: RecognitionDiagnostic scope -> AdapterDiagnostic
eraseRecognitionDiagnostic (RecognitionDiagnostic diagnostic) = diagnostic

eraseDecode :: DecodeResult scope -> DecodeOutcome
eraseDecode result =
  case result of
    ScopedDecodeFailed diagnostics ->
      DecodeFailed (fmap eraseDecodeDiagnostic diagnostics)
    ScopedDecodePassed draft -> DecodePassed draft

eraseDecodeDiagnostic :: DecodeDiagnostic scope -> AdapterDiagnostic
eraseDecodeDiagnostic (DecodeDiagnostic diagnostic) = diagnostic
