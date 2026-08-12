{-# LANGUAGE RoleAnnotations #-}

-- | Private representation of the static notation-adapter boundary.
module O2I.Operation.Adapter.Internal where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)

-- | Validated stable identity of one notation adapter.
newtype AdapterId =
  AdapterId Text
  deriving (Eq, Ord, Show)

-- | Immutable identity and format metadata of one compiled adapter.
data AdapterDescriptor = AdapterDescriptor
  { adapterDescriptorIdValue :: !AdapterId
  , adapterDescriptorNameValue :: !Text
  , adapterDescriptorVersionValue :: !Text
  , adapterDescriptorNotationValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Validated stable identity of one adapter-owned native rule.
newtype AdapterRuleId =
  AdapterRuleId Text
  deriving (Eq, Ord, Show)

-- | Closed execution stage owning one adapter rule.
data AdapterRuleStage
  = AdapterRecognitionStage
  | AdapterDecodeStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One compiled adapter-owned rule with discovery and explanation data.
data AdapterRule = AdapterRule
  { adapterRuleIdValue :: !AdapterRuleId
  , adapterRuleStageValue :: !AdapterRuleStage
  , adapterRuleExpectationValue :: !Text
  , adapterRuleMeaningValue :: !Text
  , adapterRuleActionValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Validated stage-neutral input for one compiled adapter rule.
data AdapterRuleDefinition = AdapterRuleDefinition
  { adapterRuleDefinitionIdValue :: !AdapterRuleId
  , adapterRuleDefinitionExpectationValue :: !Text
  , adapterRuleDefinitionMeaningValue :: !Text
  , adapterRuleDefinitionActionValue :: !Text
  } deriving (Eq, Ord, Show)

newtype ScopedRule scope =
  ScopedRule AdapterRule

type role ScopedRule nominal

-- | Recognition-stage rule handle confined to one adapter definition.
newtype RecognitionRule scope =
  RecognitionRule (ScopedRule scope)

type role RecognitionRule nominal

-- | Decode-stage rule handle confined to one adapter definition.
newtype DecodeRule scope =
  DecodeRule (ScopedRule scope)

type role DecodeRule nominal

-- | Exact address of one occurrence in a native source.
data NativeLocation
  = NativeByteOffset !Natural
  | NativeLineColumn !Natural !Natural
  | NativePath !(NonEmpty Text)
  deriving (Eq, Ord, Show)

-- | One native diagnostic occurrence, optionally carrying a location.
newtype AdapterOccurrence =
  AdapterOccurrence (Maybe NativeLocation)
  deriving (Eq, Ord, Show)

-- | One rule-owned adapter diagnostic with non-empty native occurrences.
data AdapterDiagnostic = AdapterDiagnostic
  { adapterDiagnosticRuleValue :: !AdapterRule
  , adapterDiagnosticOccurrencesValue :: !(NonEmpty AdapterOccurrence)
  } deriving (Eq, Ord, Show)

-- | Result of identifying whether a source belongs to an adapter format.
data Recognition
  = RecognitionNoMatch
  | RecognitionMatch
  | RecognitionFailed !(NonEmpty AdapterDiagnostic)
  deriving (Eq, Ord, Show)

-- | Final decode result produced by a selected adapter.
data DecodeOutcome
  = DecodeFailed !(NonEmpty AdapterDiagnostic)
  | DecodePassed !ProfileDraft

-- | Scoped recognition diagnostic that cannot cross adapter definitions.
newtype RecognitionDiagnostic scope =
  RecognitionDiagnostic AdapterDiagnostic

type role RecognitionDiagnostic nominal

-- | Scoped decode diagnostic that cannot cross adapter definitions.
newtype DecodeDiagnostic scope =
  DecodeDiagnostic AdapterDiagnostic

type role DecodeDiagnostic nominal

-- | Authoring result of recognition within one adapter scope.
data RecognitionResult scope
  = ScopedRecognitionNoMatch
  | ScopedRecognitionMatch
  | ScopedRecognitionFailed !(NonEmpty (RecognitionDiagnostic scope))

type role RecognitionResult nominal

-- | Authoring result of decoding within one adapter scope.
data DecodeResult scope
  = ScopedDecodeFailed !(NonEmpty (DecodeDiagnostic scope))
  | ScopedDecodePassed !ProfileDraft

type role DecodeResult nominal

-- | Pure recognition and decode functions bound to one adapter scope.
data AdapterBehavior scope = AdapterBehavior
  { adapterBehaviorRecognizeValue :: ByteString -> RecognitionResult scope
  , adapterBehaviorDecodeValue :: ByteString -> DecodeResult scope
  }

type role AdapterBehavior nominal

-- | Applicative authoring context collecting one scoped adapter contract.
data AdapterDefinition scope value = AdapterDefinition
  { adapterDefinitionRulesValue :: [AdapterRule] -> [AdapterRule]
  , adapterDefinitionResultValue :: value
  }

type role AdapterDefinition nominal representational

instance Functor (AdapterDefinition scope) where
  fmap transform definition =
    definition
      { adapterDefinitionResultValue =
          transform (adapterDefinitionResultValue definition)
      }

instance Applicative (AdapterDefinition scope) where
  pure = AdapterDefinition id
  functionDefinition <*> valueDefinition =
    AdapterDefinition
      { adapterDefinitionRulesValue =
          adapterDefinitionRulesValue functionDefinition
            . adapterDefinitionRulesValue valueDefinition
      , adapterDefinitionResultValue =
          adapterDefinitionResultValue
            functionDefinition
            (adapterDefinitionResultValue valueDefinition)
      }

-- | Compiled static adapter with its executable native behavior.
data Adapter = Adapter
  { adapterDescriptorValue :: !AdapterDescriptor
  , adapterRulesValue :: !(NonEmpty AdapterRule)
  , adapterRecognizeValue :: ByteString -> Recognition
  , adapterDecodeValue :: ByteString -> DecodeOutcome
  }

-- | Non-empty static adapter inventory with indexed identity lookup.
data AdapterCollection = AdapterCollection
  { adapterCollectionEntriesValue :: !(NonEmpty Adapter)
  , adapterCollectionByIdValue :: !(Map AdapterId Adapter)
  }

-- | Static contract projection of one compiled adapter without executable
-- recognition or decode behavior.
newtype CompiledAdapterContract =
  CompiledAdapterContract Adapter

-- | Adapter selected for exactly one subsequent decode execution.
newtype SelectedAdapter =
  SelectedAdapter Adapter

-- | One decode outcome intrinsically bound to the adapter contract that
-- produced it.
data AdapterExecution =
  AdapterExecution !AdapterDescriptor !(NonEmpty AdapterRule) !DecodeOutcome

-- | Closed failure from explicit or recognition-based adapter selection.
data AdapterSelectionError
  = UnknownAdapter !AdapterId
  | AdapterRecognitionFailed
      !(NonEmpty (AdapterDescriptor, NonEmpty AdapterDiagnostic))
  | NoAdapterMatched
  | MultipleAdaptersMatched !(NonEmpty AdapterDescriptor)

-- | Deterministic result of selecting one adapter from a static collection.
data AdapterSelection
  = AdapterSelectionFailed !AdapterSelectionError
  | AdapterSelected !SelectedAdapter

-- | Closed field classification for adapter-definition diagnostics.
data AdapterDefinitionField
  = AdapterIdentifierField
  | AdapterNameField
  | AdapterVersionField
  | AdapterNotationField
  | AdapterRuleIdentifierField
  | AdapterRuleExpectationField
  | AdapterRuleMeaningField
  | AdapterRuleActionField
  | AdapterPathStepField
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Invalid adapter authoring input rejected before compilation.
data AdapterDefinitionDefect
  = EmptyAdapterDefinitionField !AdapterDefinitionField
  | AdapterDefinitionFieldContainsNul !AdapterDefinitionField
  | InvalidNativeLineColumn !Natural !Natural
  deriving (Eq, Ord, Show)

-- | Invalid rule inventory rejected while compiling one adapter.
data AdapterCompilationDefect
  = EmptyAdapterRuleInventory
  | DuplicateAdapterRuleIdentifier !AdapterRuleId
  deriving (Eq, Ord, Show)

-- | Invalid duplicate identity rejected across compiled adapters.
data AdapterCollectionDefect =
  DuplicateAdapterIdentifier !AdapterId
  deriving (Eq, Ord, Show)
