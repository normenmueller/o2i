{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import O2I.Adapter.AMX (amxAdapter)
import O2I.Operation.Adapter
  ( Adapter
  , adapterDescriptorId
  , adapterIdText
  , foldAdapterSelection
  , selectAdapter
  , selectedAdapterDescriptor
  )
import O2I.Operation.Adapter.Authoring
  ( adapterBehavior
  , compileAdapter
  , compileAdapterCollection
  , decodeDiagnostic
  , decodeFailure
  , decodeRule
  , mkAdapterDescriptor
  , mkAdapterId
  , mkAdapterRuleDefinition
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
      (mkAdapterRuleDefinition
         "another-adapter.recognition"
         "Recognize the exact test representation."
         "The representation belongs to the other adapter."
         "Select the other adapter.")
  decodeDefinition <-
    require
      "invalid decode rule"
      (mkAdapterRuleDefinition
         "another-adapter.decode"
         "Decode is outside this selection regression."
         "The regression exercises adapter selection only."
         "Use a representation-specific decode test.")
  require
    "test adapter failed to compile"
    (compileAdapter
       descriptor
       ((\_ decode ->
           adapterBehavior
             (\input ->
                if input == unrelatedRepresentation
                  then recognitionMatch
                  else noRecognitionMatch)
             (const
                (decodeFailure
                   (decodeDiagnostic decode (unlocatedOccurrence :| []) :| []))))
          <$> recognitionRule recognitionDefinition
          <*> decodeRule decodeDefinition))

require :: String -> Either failure value -> IO value
require message result =
  case result of
    Left _ -> fail message
    Right value -> pure value

unrelatedRepresentation :: ByteString
unrelatedRepresentation = "{\"format\":\"another-adapter\"}"
