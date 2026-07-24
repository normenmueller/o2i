{-# LANGUAGE OverloadedStrings #-}

-- | Total access to direct persisted AMX properties.
module O2I.Adapter.AMX.Internal.Profile.Property
  ( directProperties
  , o2iProperties
  , singlePropertyValue
  , propertyKey
  , propertyValue
  , propertyLocation
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Provenance

-- | Read every direct property with the requested key in document order.
directProperties :: Text -> AMXElement -> [(AMXElement, Text)]
directProperties key element =
  [ (property, propertyValue property)
  | property <- elementDirectProperties element
  , propertyKey property == key
  ]

-- | Read every direct @o2i.*@ property in document order.
o2iProperties :: AMXElement -> [(AMXElement, Text, Text)]
o2iProperties element =
  [ (property, key, propertyValue property)
  | property <- elementDirectProperties element
  , let key = propertyKey property
  , "o2i." `Text.isPrefixOf` key
  ]

-- | Resolve one property value only when it occurs exactly once.
singlePropertyValue :: Text -> AMXElement -> Maybe Text
singlePropertyValue key element =
  case directProperties key element of
    [(_, value)] -> Just value
    _ -> Nothing

-- | Read the direct AMX property key, or the empty value when it is absent.
propertyKey :: AMXElement -> Text
propertyKey = maybe "" id . elementAttribute (expandedQName Nothing 'k' "ey")

-- | Read the direct AMX property value, or the empty value when it is absent.
propertyValue :: AMXElement -> Text
propertyValue =
  maybe "" id . elementAttribute (expandedQName Nothing 'v' "alue")

-- | Locate a direct property by its semantic key.
propertyLocation :: Text -> AMXElement -> SourcePosition
propertyLocation key property =
  sourcePosition
    (positionPath location)
    (PropertyTarget key)
    (positionSpan location)
  where
    location = amxElementLocation property
