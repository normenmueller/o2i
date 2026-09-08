{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed selected-View Qualify requests.
--
-- The request makes Strategy selection mandatory and uses one identical
-- identity-selector representation for Need and Strategy. An empty Need list
-- alone denotes every discovered Need subject; explicit selectors always
-- retain their exact caller order for Core's canonical resolution.
module O2I.Operation.Qualify.Request
  ( type QualifySelectorCategory
  , needQualifySelectorCategory
  , strategyQualifySelectorCategory
  , qualifySelectorCategoryText
  , foldQualifySelectorCategory
  , type QualifyRequestDefect
  , qualifyRequestDefectCategory
  , qualifyRequestDefectIdentity
  , foldQualifyRequestDefect
  , type QualifyRequest
  , qualifyRequest
  , qualifyModelInput
  , qualifyViewSelector
  , qualifyAdapterId
  , qualifyStrategySelectors
  , qualifyNeedSelectors
  , qualifySupplementalInputs
  , foldQualifyRequest
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Qualify.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Request formal qualification for one or more Strategies.
--
-- An empty Need list selects all Need subjects in the prepared View. The
-- constructor performs no normalization or identity lookup. It rejects every
-- repeated exact identity within one selector category before a request
-- exists. The same exact identity may occur once in each category.
qualifyRequest ::
     InputSource
  -> ViewSelector
  -> Maybe AdapterId
  -> NonEmpty ModelIdentity
  -> [ModelIdentity]
  -> [InputSource]
  -> Either (NonEmpty QualifyRequestDefect) QualifyRequest
qualifyRequest model view adapter strategies needs supplements =
  case NonEmpty.nonEmpty defects of
    Nothing ->
      Right (QualifyRequest model view adapter strategies needs supplements)
    Just failures -> Left failures
  where
    defects =
      map
        (DuplicateQualifySelector QualifyNeedSelectorCategory)
        (duplicateIdentities needs)
        <> map
             (DuplicateQualifySelector QualifyStrategySelectorCategory)
             (duplicateIdentities (NonEmpty.toList strategies))

-- | Need selector category, ordered before Strategy for defect reporting.
needQualifySelectorCategory :: QualifySelectorCategory
needQualifySelectorCategory = QualifyNeedSelectorCategory

-- | Strategy selector category.
strategyQualifySelectorCategory :: QualifySelectorCategory
strategyQualifySelectorCategory = QualifyStrategySelectorCategory

-- | Stable machine token for one selector category.
qualifySelectorCategoryText :: QualifySelectorCategory -> Text
qualifySelectorCategoryText category =
  case category of
    QualifyNeedSelectorCategory -> "need"
    QualifyStrategySelectorCategory -> "strategy"

-- | Consume the complete closed selector-category vocabulary.
foldQualifySelectorCategory ::
     result -> result -> QualifySelectorCategory -> result
foldQualifySelectorCategory need strategy category =
  case category of
    QualifyNeedSelectorCategory -> need
    QualifyStrategySelectorCategory -> strategy

-- | Category containing the repeated exact identity.
qualifyRequestDefectCategory :: QualifyRequestDefect -> QualifySelectorCategory
qualifyRequestDefectCategory (DuplicateQualifySelector category _) = category

-- | Exact repeated identity, with no normalization or display fallback.
qualifyRequestDefectIdentity :: QualifyRequestDefect -> ModelIdentity
qualifyRequestDefectIdentity (DuplicateQualifySelector _ identity) = identity

-- | Consume the sole closed request-defect constructor.
foldQualifyRequestDefect ::
     (QualifySelectorCategory -> ModelIdentity -> result)
  -> QualifyRequestDefect
  -> result
foldQualifyRequestDefect duplicate (DuplicateQualifySelector category identity) =
  duplicate category identity

-- | Exact physical model source retained by the request.
qualifyModelInput :: QualifyRequest -> InputSource
qualifyModelInput (QualifyRequest model _ _ _ _ _) = model

-- | Exact mandatory View selector retained without normalization.
qualifyViewSelector :: QualifyRequest -> ViewSelector
qualifyViewSelector (QualifyRequest _ selector _ _ _ _) = selector

-- | Optional exact compiled Adapter identifier.
qualifyAdapterId :: QualifyRequest -> Maybe AdapterId
qualifyAdapterId (QualifyRequest _ _ adapter _ _ _) = adapter

-- | Mandatory Strategy identity selectors retained in caller order.
qualifyStrategySelectors :: QualifyRequest -> NonEmpty ModelIdentity
qualifyStrategySelectors (QualifyRequest _ _ _ strategies _ _) = strategies

-- | Optional explicit Need identity selectors retained in caller order.
qualifyNeedSelectors :: QualifyRequest -> [ModelIdentity]
qualifyNeedSelectors (QualifyRequest _ _ _ _ needs _) = needs

-- | Ordered Semantics supplemental sources retained without acquisition.
qualifySupplementalInputs :: QualifyRequest -> [InputSource]
qualifySupplementalInputs (QualifyRequest _ _ _ _ _ supplements) = supplements

-- | Consume the complete immutable request without exposing its constructor.
foldQualifyRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> NonEmpty ModelIdentity -> [ModelIdentity] -> [InputSource] -> result)
  -> QualifyRequest
  -> result
foldQualifyRequest consume (QualifyRequest model view adapter strategies needs supplements) =
  consume model view adapter strategies needs supplements

duplicateIdentities :: [ModelIdentity] -> [ModelIdentity]
duplicateIdentities =
  Map.keys
    . Map.filter (> (1 :: Int))
    . Map.fromListWith (+)
    . map (\identity -> (identity, 1))
