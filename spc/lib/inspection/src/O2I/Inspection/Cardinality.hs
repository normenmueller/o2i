-- | Validated cardinalities shared by public inspection domains.
module O2I.Inspection.Cardinality
  ( AtLeastTwo
  , atLeastTwo
  , atLeastTwoFromList
  , atLeastTwoToList
  ) where

-- | A sequence whose first two elements are guaranteed to exist.
data AtLeastTwo value =
  AtLeastTwo value value [value]
  deriving (Eq, Ord, Show)

instance Functor AtLeastTwo where
  fmap function (AtLeastTwo first second rest) =
    AtLeastTwo (function first) (function second) (map function rest)

-- | Construct a sequence from its guaranteed first two elements.
atLeastTwo :: value -> value -> [value] -> AtLeastTwo value
atLeastTwo = AtLeastTwo

-- | Validate that a list contains at least two elements.
atLeastTwoFromList :: [value] -> Maybe (AtLeastTwo value)
atLeastTwoFromList values =
  case values of
    first:second:rest -> Just (AtLeastTwo first second rest)
    _ -> Nothing

-- | Read every element in source order.
atLeastTwoToList :: AtLeastTwo value -> [value]
atLeastTwoToList (AtLeastTwo first second rest) = first : second : rest
