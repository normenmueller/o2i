-- | Identity of the one compiled O2I ArchiMate Profile.
--
-- Import the capability modules @Draft@, @Notation@, @Resolution@, @Closure@,
-- @Mapping@ and @Projection@ for executable operations.
module O2I.ArchiMate.Profile
  ( ProfileDescriptor
  , compiledProfileInventory
  , profileDescriptorIdentity
  , profileDescriptorToken
  , profileDescriptorReference
  , profileDescriptorVersion
  , profileDescriptorNotation
  , profileDescriptorAdapterIds
  , profileDescriptorContractDigest
  ) where

import O2I.ArchiMate.Profile.Resolution

-- | The complete inventory of compiled Profile descriptors.
--
-- The inventory identifies the notation contract available to adapters; it
-- does not add independent O2I semantics.
compiledProfileInventory :: [ProfileDescriptor]
compiledProfileInventory = [compiledProfileDescriptor]
