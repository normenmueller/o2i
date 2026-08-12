-- | Private representation of the static notation-adapter boundary.
module O2I.Operation.Adapter.Internal where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)

newtype AdapterId =
  AdapterId Text
  deriving (Eq, Ord, Show)

data AdapterDescriptor = AdapterDescriptor
  { adapterDescriptorIdValue :: !AdapterId
  , adapterDescriptorNameValue :: !Text
  , adapterDescriptorVersionValue :: !Text
  , adapterDescriptorNotationValue :: !Text
  } deriving (Eq, Ord, Show)

newtype AdapterRuleId =
  AdapterRuleId Text
  deriving (Eq, Ord, Show)

data AdapterRuleStage
  = AdapterRecognitionStage
  | AdapterDecodeStage
  deriving (Bounded, Enum, Eq, Ord, Show)

data AdapterRule = AdapterRule
  { adapterRuleIdValue :: !AdapterRuleId
  , adapterRuleStageValue :: !AdapterRuleStage
  , adapterRuleExpectationValue :: !Text
  , adapterRuleMeaningValue :: !Text
  , adapterRuleActionValue :: !Text
  } deriving (Eq, Ord, Show)

data AdapterRuleDefinition = AdapterRuleDefinition
  { adapterRuleDefinitionIdValue :: !AdapterRuleId
  , adapterRuleDefinitionExpectationValue :: !Text
  , adapterRuleDefinitionMeaningValue :: !Text
  , adapterRuleDefinitionActionValue :: !Text
  } deriving (Eq, Ord, Show)

newtype ScopedRule scope =
  ScopedRule AdapterRule

newtype RecognitionRule scope =
  RecognitionRule (ScopedRule scope)

newtype DecodeRule scope =
  DecodeRule (ScopedRule scope)

data NativeLocation
  = NativeByteOffset !Natural
  | NativeLineColumn !Natural !Natural
  | NativePath !(NonEmpty Text)
  deriving (Eq, Ord, Show)

newtype AdapterOccurrence =
  AdapterOccurrence (Maybe NativeLocation)
  deriving (Eq, Ord, Show)

data AdapterDiagnostic = AdapterDiagnostic
  { adapterDiagnosticRuleValue :: !AdapterRule
  , adapterDiagnosticOccurrencesValue :: !(NonEmpty AdapterOccurrence)
  } deriving (Eq, Ord, Show)

data Recognition
  = RecognitionNoMatch
  | RecognitionMatch
  | RecognitionFailed !(NonEmpty AdapterDiagnostic)
  deriving (Eq, Ord, Show)

data DecodeOutcome
  = DecodeFailed !(NonEmpty AdapterDiagnostic)
  | DecodePassed !ProfileDraft

newtype RecognitionDiagnostic scope =
  RecognitionDiagnostic AdapterDiagnostic

newtype DecodeDiagnostic scope =
  DecodeDiagnostic AdapterDiagnostic

data RecognitionResult scope
  = ScopedRecognitionNoMatch
  | ScopedRecognitionMatch
  | ScopedRecognitionFailed !(NonEmpty (RecognitionDiagnostic scope))

data DecodeResult scope
  = ScopedDecodeFailed !(NonEmpty (DecodeDiagnostic scope))
  | ScopedDecodePassed !ProfileDraft

data AdapterBehavior scope = AdapterBehavior
  { adapterBehaviorRecognizeValue :: ByteString -> RecognitionResult scope
  , adapterBehaviorDecodeValue :: ByteString -> DecodeResult scope
  }

data AdapterDefinition scope value = AdapterDefinition
  { adapterDefinitionRulesValue :: [AdapterRule] -> [AdapterRule]
  , adapterDefinitionResultValue :: value
  }

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

data Adapter = Adapter
  { adapterDescriptorValue :: !AdapterDescriptor
  , adapterRulesValue :: !(NonEmpty AdapterRule)
  , adapterRecognizeValue :: ByteString -> Recognition
  , adapterDecodeValue :: ByteString -> DecodeOutcome
  }

data AdapterCollection = AdapterCollection
  { adapterCollectionEntriesValue :: !(NonEmpty Adapter)
  , adapterCollectionByIdValue :: !(Map AdapterId Adapter)
  }

-- | Static contract projection of one compiled adapter without executable
-- recognition or decode behavior.
newtype CompiledAdapterContract =
  CompiledAdapterContract Adapter

newtype SelectedAdapter =
  SelectedAdapter Adapter

-- | One decode outcome intrinsically bound to the adapter contract that
-- produced it.
data AdapterExecution =
  AdapterExecution !AdapterDescriptor !(NonEmpty AdapterRule) !DecodeOutcome

data AdapterSelectionError
  = UnknownAdapter !AdapterId
  | AdapterRecognitionFailed
      !(NonEmpty (AdapterDescriptor, NonEmpty AdapterDiagnostic))
  | NoAdapterMatched
  | MultipleAdaptersMatched !(NonEmpty AdapterDescriptor)

data AdapterSelection
  = AdapterSelectionFailed !AdapterSelectionError
  | AdapterSelected !SelectedAdapter

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

data AdapterDefinitionDefect
  = EmptyAdapterDefinitionField !AdapterDefinitionField
  | AdapterDefinitionFieldContainsNul !AdapterDefinitionField
  | InvalidNativeLineColumn !Natural !Natural
  deriving (Eq, Ord, Show)

data AdapterCompilationDefect
  = EmptyAdapterRuleInventory
  | DuplicateAdapterRuleIdentifier !AdapterRuleId
  deriving (Eq, Ord, Show)

data AdapterCollectionDefect =
  DuplicateAdapterIdentifier !AdapterId
  deriving (Eq, Ord, Show)
