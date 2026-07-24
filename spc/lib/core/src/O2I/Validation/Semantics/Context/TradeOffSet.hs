-- | Unordered semantic value of validated Strategy Trade-offs.
module O2I.Validation.Semantics.Context.TradeOffSet
  ( TradeOffSet
  , validatedTradeOffSet
  , matchesRawTradeOffs
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text

-- | Opaque normalized set of explicit strategic exclusions.
--
-- Order and repeated occurrences carry no semantic force. Text remains
-- case-sensitive, while surrounding whitespace is normalized.
newtype TradeOffSet =
  TradeOffSet (Set Text)
  deriving (Eq, Show)

-- | Project already nonblank Context input into its unordered semantic value.
--
-- 'O2I.Validation.Semantics.Context' calls this function only after validating
-- every source occurrence as nonblank.
validatedTradeOffSet :: NonEmpty Text -> TradeOffSet
validatedTradeOffSet =
  TradeOffSet . Set.fromList . map normalize . NonEmpty.toList

-- | Compare source-near Fit input with a validated Trade-off set.
--
-- Missing or blank source values are never equal to a validated set.
matchesRawTradeOffs :: [Text] -> TradeOffSet -> Bool
matchesRawTradeOffs raw expected =
  case NonEmpty.nonEmpty raw of
    Nothing -> False
    Just values
      | any (Text.null . normalize) values -> False
      | otherwise -> validatedTradeOffSet values == expected

normalize :: Text -> Text
normalize = Text.strip
