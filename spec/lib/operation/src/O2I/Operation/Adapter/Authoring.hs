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
  , type AdapterRuleSpec
  , type AdapterRuleBinding
  , type AdapterRules
  , type NativeAdapterRule
  , type RecognitionRule
  , type DecodeRule
  , type RecognitionDiagnostic
  , type DecodeDiagnostic
  , type RecognitionResult
  , type DecodeResult
  , type AdapterBehavior
  , mkAdapterId
  , mkAdapterDescriptor
  , mkAdapterRuleSpec
  , adapterRuleSpecId
  , nativeAdapterRule
  , archiMateNotationRule
  , lookupNativeAdapterRule
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
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)
import O2I.ArchiMate.Profile.Notation
  ( ArchiMateNotationIssueKind
  , allArchiMateNotationIssueKinds
  )
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

-- | Validate one inert static rule specification.
--
-- A specification carries no owner, executable predicate, or classification
-- authority. Its binding determines whether it is adapter-native or names one
-- Profile-owned notation issue kind.
mkAdapterRuleSpec ::
     Text
  -> AdapterRuleStage
  -> Text
  -> Text
  -> Text
  -> Either (NonEmpty AdapterDefinitionDefect) AdapterRuleSpec
mkAdapterRuleSpec identifier stage expectation meaning action =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        AdapterRuleSpec
          { adapterRuleSpecIdValue = AdapterRuleId identifier
          , adapterRuleSpecStageValue = stage
          , adapterRuleSpecExpectationValue = expectation
          , adapterRuleSpecMeaningValue = meaning
          , adapterRuleSpecActionValue = action
          }
  where
    defects =
      validateTextDefects AdapterRuleIdentifierField identifier
        <> validateTextDefects AdapterRuleExpectationField expectation
        <> validateTextDefects AdapterRuleMeaningField meaning
        <> validateTextDefects AdapterRuleActionField action

-- | Stable identifier carried by one validated rule specification.
adapterRuleSpecId :: AdapterRuleSpec -> AdapterRuleId
adapterRuleSpecId = adapterRuleSpecIdValue

-- | Bind one preparation-stage rule owned natively by the adapter.
nativeAdapterRule :: AdapterRuleSpec -> AdapterRuleBinding
nativeAdapterRule = NativeAdapterRuleBinding

-- | Bind one notation-stage rule to one Profile-owned closed issue kind.
--
-- The binding is a static catalog association only. Classification remains
-- entirely within the ArchiMate Profile.
archiMateNotationRule ::
     ArchiMateNotationIssueKind -> AdapterRuleSpec -> AdapterRuleBinding
archiMateNotationRule = ArchiMateNotationRuleBinding

-- | Resolve one adapter-native rule by stable identity within this compile
-- scope.
lookupNativeAdapterRule ::
     AdapterRules scope
  -> AdapterRuleId
  -> Either AdapterCompilationDefect (NativeAdapterRule scope)
lookupNativeAdapterRule rules identifier =
  maybe
    (Left (UnknownNativeAdapterRule identifier))
    Right
    (Map.lookup identifier (adapterRulesNativeValue rules))

-- | Restrict one scoped native rule to recognition diagnostics.
recognitionRule :: NativeAdapterRule scope -> RecognitionRule scope
recognitionRule = RecognitionRule

-- | Restrict one scoped native rule to decode diagnostics.
decodeRule :: NativeAdapterRule scope -> DecodeRule scope
decodeRule = DecodeRule

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
recognitionDiagnostic (RecognitionRule (NativeAdapterRule rule)) =
  RecognitionDiagnostic . AdapterDiagnostic rule

-- | Bind one decode-stage rule from this adapter definition to every exact
-- native occurrence it detected.
decodeDiagnostic ::
     DecodeRule scope -> NonEmpty AdapterOccurrence -> DecodeDiagnostic scope
decodeDiagnostic (DecodeRule (NativeAdapterRule rule)) =
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

-- | Compile one static adapter from one closed binding inventory.
--
-- Compilation rejects incomplete or ambiguous Profile-kind bindings, duplicate
-- rule identities, and owner-stage mismatches before the rank-2 implementation
-- receives any scoped native witness. No runtime input can extend or alter the
-- resulting catalog. Compilation is @O(R log R)@.
compileAdapter ::
     AdapterDescriptor
  -> NonEmpty AdapterRuleBinding
  -> (forall scope. AdapterRules scope -> Either
                                            (NonEmpty AdapterCompilationDefect)
                                            (AdapterBehavior scope))
  -> Either (NonEmpty AdapterCompilationDefect) Adapter
compileAdapter descriptor bindings defineBehavior =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      case defineBehavior scopedRules of
        Left failures -> Left failures
        Right behavior ->
          Right
            Adapter
              { adapterDescriptorValue = descriptor
              , adapterRulesValue = canonicalRules
              , adapterNotationRulesValue = notationRules
              , adapterRecognizeValue =
                  eraseRecognition . adapterBehaviorRecognizeValue behavior
              , adapterDecodeValue =
                  eraseDecode . adapterBehaviorDecodeValue behavior
              }
  where
    suppliedBindings = NonEmpty.toList bindings
    canonicalBindings = sortBy (comparing bindingRuleId) suppliedBindings
    canonicalRules = fmap bindingRule bindingsSorted
    bindingsSorted = NonEmpty.fromList canonicalBindings
    nativeRules =
      Map.fromList
        [ (adapterRuleIdValue rule, NativeAdapterRule rule)
        | NativeAdapterRuleBinding spec <- canonicalBindings
        , let rule = materializeRule spec
        ]
    notationRules = Map.fromList (map materializeNotation notationBindings)
    scopedRules = AdapterRules nativeRules notationRules
    defects =
      [ DuplicateAdapterRuleIdentifier identifier
      | identifier <- duplicateKeys bindingRuleId canonicalBindings
      ]
        <> [ AdapterRuleStageMismatch
             (adapterRuleSpecIdValue spec)
             (adapterRuleSpecStageValue spec)
             expected
           | binding <- canonicalBindings
           , let spec = bindingRuleSpec binding
           , let expected = bindingExpectedStage binding
           , adapterRuleSpecStageValue spec /= expected
           ]
        <> [ DuplicateArchiMateNotationRule kind
           | kind <- duplicateKeys fst notationBindings
           ]
        <> [ MissingArchiMateNotationRule kind
           | kind <- NonEmpty.toList allArchiMateNotationIssueKinds
           , Set.notMember kind suppliedNotationKinds
           ]
    notationBindings =
      [ (kind, spec)
      | ArchiMateNotationRuleBinding kind spec <- canonicalBindings
      ]
    suppliedNotationKinds = Set.fromList (map fst notationBindings)

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

materializeRule :: AdapterRuleSpec -> AdapterRule
materializeRule spec =
  AdapterRule
    { adapterRuleIdValue = adapterRuleSpecIdValue spec
    , adapterRuleStageValue = adapterRuleSpecStageValue spec
    , adapterRuleExpectationValue = adapterRuleSpecExpectationValue spec
    , adapterRuleMeaningValue = adapterRuleSpecMeaningValue spec
    , adapterRuleActionValue = adapterRuleSpecActionValue spec
    }

bindingRuleSpec :: AdapterRuleBinding -> AdapterRuleSpec
bindingRuleSpec binding =
  case binding of
    NativeAdapterRuleBinding spec -> spec
    ArchiMateNotationRuleBinding _ spec -> spec

bindingRule :: AdapterRuleBinding -> AdapterRule
bindingRule = materializeRule . bindingRuleSpec

bindingRuleId :: AdapterRuleBinding -> AdapterRuleId
bindingRuleId = adapterRuleSpecIdValue . bindingRuleSpec

bindingExpectedStage :: AdapterRuleBinding -> AdapterRuleStage
bindingExpectedStage binding =
  case binding of
    NativeAdapterRuleBinding _ -> AdapterPreparationStage
    ArchiMateNotationRuleBinding {} -> AdapterNotationStage

materializeNotation ::
     (ArchiMateNotationIssueKind, AdapterRuleSpec)
  -> (ArchiMateNotationIssueKind, AdapterRule)
materializeNotation (kind, spec) = (kind, materializeRule spec)

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
