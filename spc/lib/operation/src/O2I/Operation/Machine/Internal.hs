{-# LANGUAGE OverloadedStrings #-}

-- | Private representation of Operation-owned machine-envelope metadata.
module O2I.Operation.Machine.Internal where

import Data.Text (Text)

-- | Closed fields validated at the executable composition boundary.
data ToolDescriptorField
  = ToolIdentityField
  | ToolVersionField
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why composition metadata cannot become a machine-safe tool descriptor.
data ToolDescriptorDefect
  = EmptyToolDescriptorField !ToolDescriptorField
  | ToolDescriptorFieldContainsNul !ToolDescriptorField
  deriving (Eq, Ord, Show)

-- | Immutable tool identity and exact executable version.
data ToolDescriptor = ToolDescriptor
  { toolDescriptorIdentityValue :: !Text
  , toolDescriptorVersionValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Package-internal exact operation identity for one machine envelope.
newtype OperationIdentity = OperationIdentity
  { operationIdentityValue :: Text
  } deriving (Eq, Ord, Show)

-- | Exact identity of the profile-neutral View discovery operation.
viewsOperationIdentity :: OperationIdentity
viewsOperationIdentity = OperationIdentity "views"

-- | Exact identity of cumulative selected-View validation.
validateOperationIdentity :: OperationIdentity
validateOperationIdentity = OperationIdentity "validate"
