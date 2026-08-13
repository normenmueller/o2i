{-# LANGUAGE RoleAnnotations #-}

-- | Private representation of the static notation-adapter boundary.
module O2I.Operation.Adapter.Internal where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)
import O2I.ArchiMate.Profile.Notation (ArchiMateNotationIssueKind)

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
  = AdapterPreparationStage
  | AdapterNotationStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One compiled adapter-owned rule with discovery and explanation data.
data AdapterRule = AdapterRule
  { adapterRuleIdValue :: !AdapterRuleId
  , adapterRuleStageValue :: !AdapterRuleStage
  , adapterRuleExpectationValue :: !Text
  , adapterRuleMeaningValue :: !Text
  , adapterRuleActionValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Validated inert input for one compiled adapter rule.
data AdapterRuleSpec = AdapterRuleSpec
  { adapterRuleSpecIdValue :: !AdapterRuleId
  , adapterRuleSpecStageValue :: !AdapterRuleStage
  , adapterRuleSpecExpectationValue :: !Text
  , adapterRuleSpecMeaningValue :: !Text
  , adapterRuleSpecActionValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Static association between one rule specification and its owner.
data AdapterRuleBinding
  = NativeAdapterRuleBinding !AdapterRuleSpec
  | ArchiMateNotationRuleBinding !ArchiMateNotationIssueKind !AdapterRuleSpec
  deriving (Eq, Ord, Show)

-- | Compiled preparation rule confined to one adapter implementation.
newtype NativeAdapterRule scope =
  NativeAdapterRule AdapterRule

type role NativeAdapterRule nominal

-- | Recognition-stage rule handle confined to one adapter definition.
newtype RecognitionRule scope =
  RecognitionRule (NativeAdapterRule scope)

type role RecognitionRule nominal

-- | Decode-stage rule handle confined to one adapter definition.
newtype DecodeRule scope =
  DecodeRule (NativeAdapterRule scope)

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

-- | Scoped lookup catalog for adapter-native preparation rules.
data AdapterRules scope = AdapterRules
  { adapterRulesNativeValue :: !(Map AdapterRuleId (NativeAdapterRule scope))
  , adapterRulesNotationValue :: !(Map ArchiMateNotationIssueKind AdapterRule)
  }

type role AdapterRules nominal

-- | Compiled static adapter with its executable native behavior.
data Adapter = Adapter
  { adapterDescriptorValue :: !AdapterDescriptor
  , adapterRulesValue :: !(NonEmpty AdapterRule)
  , adapterNotationRulesValue :: !(Map ArchiMateNotationIssueKind AdapterRule)
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
  = DuplicateAdapterRuleIdentifier !AdapterRuleId
  | MissingArchiMateNotationRule !ArchiMateNotationIssueKind
  | DuplicateArchiMateNotationRule !ArchiMateNotationIssueKind
  | AdapterRuleStageMismatch !AdapterRuleId !AdapterRuleStage !AdapterRuleStage
  | UnknownNativeAdapterRule !AdapterRuleId
  deriving (Eq, Ord, Show)

-- | Resolve one Profile-owned kind through the compiled static binding.
lookupArchiMateNotationRuleValue ::
     ArchiMateNotationIssueKind -> Adapter -> Maybe AdapterRule
lookupArchiMateNotationRuleValue kind =
  Map.lookup kind . adapterNotationRulesValue

-- | Invalid duplicate identity rejected across compiled adapters.
data AdapterCollectionDefect =
  DuplicateAdapterIdentifier !AdapterId
  deriving (Eq, Ord, Show)
