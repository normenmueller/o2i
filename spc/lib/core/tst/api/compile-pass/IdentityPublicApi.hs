{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module IdentityPublicApi where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Identity

data BuildIdentityDefect
  = InvalidOccurrenceIdentity !OccurrenceIdentityDefect
  | InvalidModelIdentity !ModelIdentityDefect
  | InvalidOccurrenceIndex !(NonEmpty IdentityIndexDefect)

buildIndex :: [(Text, Text)] -> Either BuildIdentityDefect ModelIdentityIndex
buildIndex values = do
  occurrences <- traverse decodeOccurrence values
  case buildModelIdentityIndex occurrences of
    Left defects -> Left (InvalidOccurrenceIndex defects)
    Right index -> Right index

decodeOccurrence :: (Text, Text) -> Either BuildIdentityDefect ModelOccurrence
decodeOccurrence (occurrenceText, modelText) = do
  occurrenceId <-
    case occurrenceIdentity occurrenceText of
      Left defect -> Left (InvalidOccurrenceIdentity defect)
      Right identifier -> Right identifier
  modelId <-
    case modelIdentity modelText of
      Left defect -> Left (InvalidModelIdentity defect)
      Right identifier -> Right identifier
  Right (modelOccurrence occurrenceId modelId)

consumeModelIdentityDefect :: ModelIdentityDefect -> Text
consumeModelIdentityDefect EmptyModelIdentity = "empty-model-identity"
consumeModelIdentityDefect ModelIdentityContainsU0000 =
  "model-identity-contains-u0000"
consumeModelIdentityDefect ModelIdentityContainsSurrogate =
  "model-identity-contains-surrogate"

consumeOccurrenceIdentityDefect :: OccurrenceIdentityDefect -> Text
consumeOccurrenceIdentityDefect EmptyOccurrenceIdentity =
  "empty-occurrence-identity"
consumeOccurrenceIdentityDefect OccurrenceIdentityContainsU0000 =
  "occurrence-identity-contains-u0000"
consumeOccurrenceIdentityDefect OccurrenceIdentityContainsSurrogate =
  "occurrence-identity-contains-surrogate"

consumeIndexDefect :: IdentityIndexDefect -> (Text, [Text])
consumeIndexDefect defect =
  ( occurrenceIdentityText (identityIndexDefectOccurrence defect)
  , map
      modelIdentityText
      (NonEmpty.toList (identityIndexDefectModelIdentities defect)))

consumeScopeDefect ::
     SelectedViewScopeDefect -> (SelectedViewScopeDefectKind, Text, Int)
consumeScopeDefect defect =
  ( selectedViewScopeDefectKind defect
  , occurrenceIdentityText (selectedViewScopeDefectOccurrence defect)
  , selectedViewScopeDefectCardinality defect)

consumeScope ::
     ModelIdentityIndex
  -> ModelOccurrence
  -> [OccurrenceIdentity]
  -> Either (NonEmpty SelectedViewScopeDefect) ()
consumeScope index selectedView identities =
  withSelectedViewScope index selectedView identities (\_ -> ())
