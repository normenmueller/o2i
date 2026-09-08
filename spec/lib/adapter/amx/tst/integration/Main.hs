{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Adapter.AMX (amxAdapter)
import O2I.ArchiMate.Profile.Notation
  ( ArchiMateNotationIssueKind
  , allArchiMateNotationIssueKinds
  , archiMateNotationIssueKindToken
  )
import O2I.Operation.Adapter
  ( Adapter
  , adapterDescriptorId
  , adapterIdText
  , foldAdapterSelection
  , notationRuleStage
  , preparationRuleStage
  , selectAdapter
  , selectedAdapterDescriptor
  )
import O2I.Operation.Adapter.Authoring
  ( AdapterRuleBinding
  , adapterBehavior
  , adapterRuleSpecId
  , archiMateNotationRule
  , compileAdapter
  , compileAdapterCollection
  , decodeDiagnostic
  , decodeFailure
  , decodeRule
  , lookupNativeAdapterRule
  , mkAdapterDescriptor
  , mkAdapterId
  , mkAdapterRuleSpec
  , nativeAdapterRule
  , noRecognitionMatch
  , recognitionMatch
  , recognitionRule
  , unlocatedOccurrence
  )

main :: IO ()
main = do
  amx <- require "static AMX adapter failed to compile" amxAdapter
  other <- unrelatedAdapter
  collection <-
    require
      "adapter collection failed to compile"
      (compileAdapterCollection (amx :| [other]))
  selected <-
    foldAdapterSelection
      (const (fail "unrelated adapter was not selected"))
      pure
      (selectAdapter collection Nothing unrelatedRepresentation)
  if adapterIdText (adapterDescriptorId (selectedAdapterDescriptor selected))
       == "another-adapter"
    then pure ()
    else fail "AMX shadowed the unrelated adapter"

unrelatedAdapter :: IO Adapter
unrelatedAdapter = do
  identifier <-
    require "invalid test adapter identifier" (mkAdapterId "another-adapter")
  descriptor <-
    require
      "invalid test adapter descriptor"
      (mkAdapterDescriptor identifier "Another adapter" "1" "another-notation")
  recognitionDefinition <-
    require
      "invalid recognition rule"
      (mkAdapterRuleSpec
         "another-adapter.recognition"
         preparationRuleStage
         "Recognize the exact test representation."
         "The representation belongs to the other adapter."
         "Select the other adapter.")
  decodeDefinition <-
    require
      "invalid decode rule"
      (mkAdapterRuleSpec
         "another-adapter.decode"
         preparationRuleStage
         "Decode is outside this selection regression."
         "The regression exercises adapter selection only."
         "Use a representation-specific decode test.")
  notation <-
    traverse notationBinding (NonEmpty.toList allArchiMateNotationIssueKinds)
  require
    "test adapter failed to compile"
    (compileAdapter
       descriptor
       (nativeAdapterRule recognitionDefinition
          :| nativeAdapterRule decodeDefinition
          : notation)
       (\rules -> do
          _ <-
            first
              pure
              (recognitionRule
                 <$> lookupNativeAdapterRule
                       rules
                       (adapterRuleSpecId recognitionDefinition))
          decode <-
            first
              pure
              (decodeRule
                 <$> lookupNativeAdapterRule
                       rules
                       (adapterRuleSpecId decodeDefinition))
          pure
            (adapterBehavior
               (\input ->
                  if input == unrelatedRepresentation
                    then recognitionMatch
                    else noRecognitionMatch)
               (const
                  (decodeFailure
                     (decodeDiagnostic decode (unlocatedOccurrence :| []) :| []))))))

notationBinding :: ArchiMateNotationIssueKind -> IO AdapterRuleBinding
notationBinding kind =
  archiMateNotationRule kind
    <$> require
          "invalid notation rule"
          (mkAdapterRuleSpec
             ("another-adapter.notation."
                <> archiMateNotationIssueKindToken kind)
             notationRuleStage
             "expectation"
             "meaning"
             "action")

require :: String -> Either failure value -> IO value
require message result =
  case result of
    Left _ -> fail message
    Right value -> pure value

unrelatedRepresentation :: ByteString
unrelatedRepresentation = "{\"format\":\"another-adapter\"}"
