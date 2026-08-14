{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Composition-owned metadata for closed Operation machine envelopes.
--
-- The executable supplies its own exact identity and version once. Capability
-- encoders bind that opaque descriptor to their internal operation identity;
-- callers can neither substitute an operation identity nor reconstruct JSON.
module O2I.Operation.Machine
  ( type ToolDescriptorField
  , toolIdentityField
  , toolVersionField
  , toolDescriptorFieldText
  , foldToolDescriptorField
  , type ToolDescriptorDefect
  , foldToolDescriptorDefect
  , type ToolDescriptor
  , mkToolDescriptor
  , toolDescriptorIdentity
  , toolDescriptorVersion
  , foldToolDescriptor
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Operation.Machine.Internal

-- | Identity field of a tool descriptor.
toolIdentityField :: ToolDescriptorField
toolIdentityField = ToolIdentityField

-- | Exact executable-version field of a tool descriptor.
toolVersionField :: ToolDescriptorField
toolVersionField = ToolVersionField

-- | Project the stable machine token for one descriptor field.
toolDescriptorFieldText :: ToolDescriptorField -> Text
toolDescriptorFieldText field =
  case field of
    ToolIdentityField -> "identity"
    ToolVersionField -> "version"

-- | Consume the complete closed descriptor-field vocabulary.
foldToolDescriptorField :: result -> result -> ToolDescriptorField -> result
foldToolDescriptorField identity version field =
  case field of
    ToolIdentityField -> identity
    ToolVersionField -> version

-- | Consume every closed invalid-descriptor outcome.
foldToolDescriptorDefect ::
     (ToolDescriptorField -> result)
  -> (ToolDescriptorField -> result)
  -> ToolDescriptorDefect
  -> result
foldToolDescriptorDefect empty nul defect =
  case defect of
    EmptyToolDescriptorField field -> empty field
    ToolDescriptorFieldContainsNul field -> nul field

-- | Validate exact executable composition metadata.
--
-- The authority defines identity and version as exact values, not as a second
-- package version or caller-configurable operation identity. Validation is
-- therefore limited to non-empty, NUL-free 'Text' required for a total
-- canonical machine encoding; it performs no normalization.
mkToolDescriptor ::
     Text -> Text -> Either (NonEmpty ToolDescriptorDefect) ToolDescriptor
mkToolDescriptor identity version =
  case NonEmpty.nonEmpty defects of
    Nothing -> Right (ToolDescriptor identity version)
    Just failures -> Left failures
  where
    defects =
      fieldDefects ToolIdentityField identity
        <> fieldDefects ToolVersionField version

-- | Project the exact composition-supplied tool identity.
toolDescriptorIdentity :: ToolDescriptor -> Text
toolDescriptorIdentity = toolDescriptorIdentityValue

-- | Project the exact composition-supplied tool version.
toolDescriptorVersion :: ToolDescriptor -> Text
toolDescriptorVersion = toolDescriptorVersionValue

-- | Consume both descriptor fields in canonical machine order.
foldToolDescriptor :: (Text -> Text -> result) -> ToolDescriptor -> result
foldToolDescriptor consume descriptor =
  consume
    (toolDescriptorIdentityValue descriptor)
    (toolDescriptorVersionValue descriptor)

fieldDefects :: ToolDescriptorField -> Text -> [ToolDescriptorDefect]
fieldDefects field value =
  [EmptyToolDescriptorField field | Text.null value]
    <> [ToolDescriptorFieldContainsNul field | Text.any (== '\NUL') value]
