{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Opaque static notation-adapter contract and deterministic selection.
module O2I.Operation.Adapter
  ( type AdapterId
  , adapterIdText
  , type AdapterDescriptor
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorVersion
  , adapterDescriptorNotation
  , foldAdapterDescriptor
  , type AdapterRuleId
  , adapterRuleIdText
  , type AdapterRuleStage
  , recognitionRuleStage
  , decodeRuleStage
  , adapterRuleStageText
  , foldAdapterRuleStage
  , type AdapterRule
  , adapterRuleId
  , adapterRuleStage
  , adapterRuleExpectation
  , adapterRuleMeaning
  , adapterRuleAction
  , foldAdapterRule
  , type NativeLocation
  , foldNativeLocation
  , type AdapterOccurrence
  , foldAdapterOccurrence
  , type AdapterDiagnostic
  , adapterDiagnosticRule
  , adapterDiagnosticOccurrences
  , type Recognition
  , foldRecognition
  , type DecodeOutcome
  , foldDecodeOutcome
  , type Adapter
  , type AdapterCollection
  , adapterCollectionDescriptors
  , type CompiledAdapterContract
  , adapterCollectionContracts
  , lookupAdapterContract
  , adapterContractDescriptor
  , adapterContractRules
  , foldAdapterContract
  , type SelectedAdapter
  , selectedAdapterDescriptor
  , selectedAdapterRules
  , type AdapterExecution
  , adapterExecutionDescriptor
  , adapterExecutionRules
  , adapterExecutionOutcome
  , foldAdapterExecution
  , runSelectedAdapter
  , type AdapterSelectionError
  , foldAdapterSelectionError
  , type AdapterSelection
  , foldAdapterSelection
  , selectAdapter
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.ArchiMate.Profile.Draft (ProfileDraft)
import O2I.Operation.Adapter.Internal

-- | Exact stable adapter identity.
adapterIdText :: AdapterId -> Text
adapterIdText (AdapterId value) = value

-- | Stable identity of one compiled adapter.
adapterDescriptorId :: AdapterDescriptor -> AdapterId
adapterDescriptorId = adapterDescriptorIdValue

-- | Human-readable compiled adapter name.
adapterDescriptorName :: AdapterDescriptor -> Text
adapterDescriptorName = adapterDescriptorNameValue

-- | Compiled adapter contract version.
adapterDescriptorVersion :: AdapterDescriptor -> Text
adapterDescriptorVersion = adapterDescriptorVersionValue

-- | Exact notation family emitted by the adapter Draft.
adapterDescriptorNotation :: AdapterDescriptor -> Text
adapterDescriptorNotation = adapterDescriptorNotationValue

-- | Consume every immutable adapter descriptor field in canonical order.
foldAdapterDescriptor ::
     (AdapterId -> Text -> Text -> Text -> result)
  -> AdapterDescriptor
  -> result
foldAdapterDescriptor consume descriptor =
  consume
    (adapterDescriptorIdValue descriptor)
    (adapterDescriptorNameValue descriptor)
    (adapterDescriptorVersionValue descriptor)
    (adapterDescriptorNotationValue descriptor)

-- | Exact adapter-owned native rule identity.
adapterRuleIdText :: AdapterRuleId -> Text
adapterRuleIdText (AdapterRuleId value) = value

-- | Recognition-stage rule for native format identification.
recognitionRuleStage :: AdapterRuleStage
recognitionRuleStage = AdapterRecognitionStage

-- | Decode-stage rule for lossless projection into a Profile-neutral Draft.
decodeRuleStage :: AdapterRuleStage
decodeRuleStage = AdapterDecodeStage

-- | Stable machine-readable stage identity.
adapterRuleStageText :: AdapterRuleStage -> Text
adapterRuleStageText stage =
  case stage of
    AdapterRecognitionStage -> "recognition"
    AdapterDecodeStage -> "decode"

-- | Consume either closed adapter rule stage.
foldAdapterRuleStage :: result -> result -> AdapterRuleStage -> result
foldAdapterRuleStage recognition decode stage =
  case stage of
    AdapterRecognitionStage -> recognition
    AdapterDecodeStage -> decode

-- | Identity of one adapter-owned native rule.
adapterRuleId :: AdapterRule -> AdapterRuleId
adapterRuleId = adapterRuleIdValue

-- | Closed execution stage owning one adapter rule.
adapterRuleStage :: AdapterRule -> AdapterRuleStage
adapterRuleStage = adapterRuleStageValue

-- | Normative expectation projected from the compiled adapter rule.
adapterRuleExpectation :: AdapterRule -> Text
adapterRuleExpectation = adapterRuleExpectationValue

-- | Non-normative explanation of why the rule matters.
adapterRuleMeaning :: AdapterRule -> Text
adapterRuleMeaning = adapterRuleMeaningValue

-- | Non-normative corrective action for the rule.
adapterRuleAction :: AdapterRule -> Text
adapterRuleAction = adapterRuleActionValue

-- | Consume one complete adapter rule explanation.
foldAdapterRule ::
     (AdapterRuleId -> AdapterRuleStage -> Text -> Text -> Text -> result)
  -> AdapterRule
  -> result
foldAdapterRule consume rule =
  consume
    (adapterRuleIdValue rule)
    (adapterRuleStageValue rule)
    (adapterRuleExpectationValue rule)
    (adapterRuleMeaningValue rule)
    (adapterRuleActionValue rule)

-- | Consume every closed native source-location shape.
foldNativeLocation ::
     (Natural -> result)
  -> (Natural -> Natural -> result)
  -> (NonEmpty Text -> result)
  -> NativeLocation
  -> result
foldNativeLocation byteOffset lineColumn path location =
  case location of
    NativeByteOffset offset -> byteOffset offset
    NativeLineColumn line column -> lineColumn line column
    NativePath steps -> path steps

-- | Consume an unavailable or exact native source location.
foldAdapterOccurrence ::
     result -> (NativeLocation -> result) -> AdapterOccurrence -> result
foldAdapterOccurrence unavailable located (AdapterOccurrence location) =
  maybe unavailable located location

-- | Adapter-owned rule that diagnosed one native failure.
adapterDiagnosticRule :: AdapterDiagnostic -> AdapterRule
adapterDiagnosticRule = adapterDiagnosticRuleValue

-- | Every exact occurrence of one adapter-owned diagnostic.
adapterDiagnosticOccurrences :: AdapterDiagnostic -> NonEmpty AdapterOccurrence
adapterDiagnosticOccurrences = adapterDiagnosticOccurrencesValue

-- | Consume no-match, match, or recognizer failure without exposing
-- constructors.
foldRecognition ::
     result
  -> result
  -> (NonEmpty AdapterDiagnostic -> result)
  -> Recognition
  -> result
foldRecognition noMatch matched failed recognition =
  case recognition of
    RecognitionNoMatch -> noMatch
    RecognitionMatch -> matched
    RecognitionFailed diagnostics -> failed diagnostics

-- | Consume final selected-adapter failure or one lossless Draft.
foldDecodeOutcome ::
     (NonEmpty AdapterDiagnostic -> result)
  -> (ProfileDraft -> result)
  -> DecodeOutcome
  -> result
foldDecodeOutcome failed passed outcome =
  case outcome of
    DecodeFailed diagnostics -> failed diagnostics
    DecodePassed draft -> passed draft

-- | Canonically ordered inventory of every compiled adapter descriptor.
adapterCollectionDescriptors :: AdapterCollection -> NonEmpty AdapterDescriptor
adapterCollectionDescriptors =
  fmap adapterDescriptorValue . adapterCollectionEntriesValue

-- | Canonically ordered static contracts of every compiled adapter.
--
-- The projection exposes no recognizer or decoder and therefore cannot execute
-- model-dependent adapter behavior.
adapterCollectionContracts ::
     AdapterCollection -> NonEmpty CompiledAdapterContract
adapterCollectionContracts =
  fmap CompiledAdapterContract . adapterCollectionEntriesValue

-- | Look up one exact compiled adapter contract in @O(log A)@.
lookupAdapterContract ::
     AdapterId -> AdapterCollection -> Maybe CompiledAdapterContract
lookupAdapterContract identifier collection =
  CompiledAdapterContract
    <$> Map.lookup identifier (adapterCollectionByIdValue collection)

-- | Descriptor bound to one compiled adapter contract.
adapterContractDescriptor :: CompiledAdapterContract -> AdapterDescriptor
adapterContractDescriptor (CompiledAdapterContract value) =
  adapterDescriptorValue value

-- | Complete canonical rule inventory bound to one compiled adapter contract.
adapterContractRules :: CompiledAdapterContract -> NonEmpty AdapterRule
adapterContractRules (CompiledAdapterContract value) = adapterRulesValue value

-- | Consume the complete non-executable contract projection.
foldAdapterContract ::
     (AdapterDescriptor -> NonEmpty AdapterRule -> result)
  -> CompiledAdapterContract
  -> result
foldAdapterContract consume contract =
  consume (adapterContractDescriptor contract) (adapterContractRules contract)

-- | Descriptor of the deterministically selected adapter.
selectedAdapterDescriptor :: SelectedAdapter -> AdapterDescriptor
selectedAdapterDescriptor (SelectedAdapter value) = adapterDescriptorValue value

-- | Complete canonically defined rule inventory of the selected adapter.
selectedAdapterRules :: SelectedAdapter -> NonEmpty AdapterRule
selectedAdapterRules (SelectedAdapter value) = adapterRulesValue value

-- | Descriptor intrinsically bound to one adapter execution.
adapterExecutionDescriptor :: AdapterExecution -> AdapterDescriptor
adapterExecutionDescriptor (AdapterExecution descriptor _ _) = descriptor

-- | Complete rule inventory intrinsically bound to one adapter execution.
adapterExecutionRules :: AdapterExecution -> NonEmpty AdapterRule
adapterExecutionRules (AdapterExecution _ rules _) = rules

-- | Final decode outcome produced by the bound adapter.
adapterExecutionOutcome :: AdapterExecution -> DecodeOutcome
adapterExecutionOutcome (AdapterExecution _ _ outcome) = outcome

-- | Consume one complete adapter execution without exposing its constructor.
foldAdapterExecution ::
     (AdapterDescriptor -> NonEmpty AdapterRule -> DecodeOutcome -> result)
  -> AdapterExecution
  -> result
foldAdapterExecution consume (AdapterExecution descriptor rules outcome) =
  consume descriptor rules outcome

-- | Invoke only the selected adapter and bind its final outcome to the exact
-- immutable adapter contract that produced it.
runSelectedAdapter :: SelectedAdapter -> ByteString -> AdapterExecution
runSelectedAdapter (SelectedAdapter value) bytes =
  AdapterExecution
    (adapterDescriptorValue value)
    (adapterRulesValue value)
    (adapterDecodeValue value bytes)

-- | Consume every closed adapter-selection failure.
foldAdapterSelectionError ::
     (AdapterId -> result)
  -> (NonEmpty (AdapterDescriptor, NonEmpty AdapterDiagnostic) -> result)
  -> result
  -> (NonEmpty AdapterDescriptor -> result)
  -> AdapterSelectionError
  -> result
foldAdapterSelectionError unknown failed noMatch multiple selectionError =
  case selectionError of
    UnknownAdapter identifier -> unknown identifier
    AdapterRecognitionFailed diagnostics -> failed diagnostics
    NoAdapterMatched -> noMatch
    MultipleAdaptersMatched descriptors -> multiple descriptors

-- | Consume selection failure or one exact selected adapter.
foldAdapterSelection ::
     (AdapterSelectionError -> result)
  -> (SelectedAdapter -> result)
  -> AdapterSelection
  -> result
foldAdapterSelection failed selected selection =
  case selection of
    AdapterSelectionFailed selectionError -> failed selectionError
    AdapterSelected value -> selected value

-- | Select one compiled adapter with the target architecture's exact
-- precedence.
--
-- Explicit selection performs one exact @O(log A)@ lookup and bypasses every
-- recognizer. Implicit selection invokes every pure recognizer exactly once on
-- the same immutable bytes in canonical adapter order and is @O(A + O)@ aside
-- from recognizer work, where @O@ is emitted diagnostic output.
selectAdapter ::
     AdapterCollection -> Maybe AdapterId -> ByteString -> AdapterSelection
selectAdapter collection requested bytes =
  case requested of
    Just identifier -> explicit identifier
    Nothing -> implicit
  where
    explicit identifier =
      case Map.lookup identifier (adapterCollectionByIdValue collection) of
        Nothing -> AdapterSelectionFailed (UnknownAdapter identifier)
        Just value -> AdapterSelected (SelectedAdapter value)
    implicit =
      case NonEmpty.nonEmpty failures of
        Just diagnostics ->
          AdapterSelectionFailed (AdapterRecognitionFailed diagnostics)
        Nothing ->
          case matches of
            [] -> AdapterSelectionFailed NoAdapterMatched
            [value] -> AdapterSelected (SelectedAdapter value)
            first:rest ->
              AdapterSelectionFailed
                (MultipleAdaptersMatched
                   (adapterDescriptorValue first
                      :| fmap adapterDescriptorValue rest))
    outcomes =
      [ (value, adapterRecognizeValue value bytes)
      | value <- NonEmpty.toList (adapterCollectionEntriesValue collection)
      ]
    failures =
      [ (adapterDescriptorValue value, diagnostics)
      | (value, RecognitionFailed diagnostics) <- outcomes
      ]
    matches = [value | (value, RecognitionMatch) <- outcomes]
