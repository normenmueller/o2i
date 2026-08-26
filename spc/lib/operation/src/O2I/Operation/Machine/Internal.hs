{-# LANGUAGE OverloadedStrings #-}

-- | Private representation of Operation-owned machine-envelope metadata.
module O2I.Operation.Machine.Internal
  ( ToolDescriptorField(..)
  , ToolDescriptorDefect(..)
  , ToolDescriptor(..)
  , OperationIdentity
  , viewsOperationIdentity
  , validateOperationIdentity
  , traceOperationIdentity
  , operationIdentityValue
  , operationIdentityInventory
  ) where

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

-- | Closed package-internal operation identity for one machine envelope.
data OperationIdentity
  = ViewsOperationIdentity
  | ValidateOperationIdentity
  | TraceOperationIdentity
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact identity of the profile-neutral View discovery operation.
viewsOperationIdentity :: OperationIdentity
viewsOperationIdentity = ViewsOperationIdentity

-- | Exact identity of cumulative selected-View validation.
validateOperationIdentity :: OperationIdentity
validateOperationIdentity = ValidateOperationIdentity

-- | Exact identity of selected-View effect tracing.
traceOperationIdentity :: OperationIdentity
traceOperationIdentity = TraceOperationIdentity

-- | Project the exact stable machine token by total case distinction.
operationIdentityValue :: OperationIdentity -> Text
operationIdentityValue identity =
  case identity of
    ViewsOperationIdentity -> "views"
    ValidateOperationIdentity -> "validate"
    TraceOperationIdentity -> "trace"

-- | Exhaustive inventory tied mechanically to the closed constructors.
operationIdentityInventory :: [OperationIdentity]
operationIdentityInventory = [minBound .. maxBound]
