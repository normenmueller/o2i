{-# LANGUAGE RankNTypes #-}

-- | Immutable descriptor material contributed by the compiled Profile.
--
-- Inventory validation, Profile resolution, adapter compatibility, and View
-- selection belong to Operation and are intentionally absent here.
module O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , compiledProfileDescriptor
  , profileDescriptorIdentity
  , profileDescriptorToken
  , profileDescriptorReference
  , profileDescriptorVersion
  , profileDescriptorNotation
  , profileDescriptorAdapterIds
  , profileDescriptorContractDigest
  , foldProfileDescriptor
  , SelectedArchiMateProfile
  , withSelectedArchiMateProfile
  , selectedArchiMateProfileDescriptor
  ) where

import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Resolution

-- | The one immutable descriptor compiled from the Profile companion.
compiledProfileDescriptor :: ProfileDescriptor
compiledProfileDescriptor = compiledDescriptor

-- | Stable identity of the compiled Profile contract.
profileDescriptorIdentity :: ProfileDescriptor -> Text
profileDescriptorIdentity = profileDescriptorIdentityValue

-- | Version token used to select this exact Profile descriptor.
profileDescriptorToken :: ProfileDescriptor -> Text
profileDescriptorToken = profileDescriptorTokenValue

-- | Canonical @identity@token@ reference for the descriptor.
profileDescriptorReference :: ProfileDescriptor -> Text
profileDescriptorReference = descriptorReference

-- | Declared O2I Framework version represented by the descriptor.
profileDescriptorVersion :: ProfileDescriptor -> Text
profileDescriptorVersion = profileDescriptorVersionValue

-- | Notation family to which the compiled mapping applies.
profileDescriptorNotation :: ProfileDescriptor -> Text
profileDescriptorNotation = profileDescriptorNotationValue

-- | Adapter identifiers admitted by the compiled Profile contract.
profileDescriptorAdapterIds :: ProfileDescriptor -> [Text]
profileDescriptorAdapterIds = profileDescriptorAdapterIdsValue

-- | Digest binding the descriptor to its generated contract material.
profileDescriptorContractDigest :: ProfileDescriptor -> Text
profileDescriptorContractDigest = profileDescriptorContractDigestValue

-- | Consume all immutable descriptor fields in canonical order.
foldProfileDescriptor ::
     (Text -> Text -> Text -> Text -> [Text] -> Text -> result)
  -> ProfileDescriptor
  -> result
foldProfileDescriptor consume descriptor =
  consume
    (profileDescriptorIdentityValue descriptor)
    (profileDescriptorTokenValue descriptor)
    (profileDescriptorVersionValue descriptor)
    (profileDescriptorNotationValue descriptor)
    (profileDescriptorAdapterIdsValue descriptor)
    (profileDescriptorContractDigestValue descriptor)

-- | Introduce one fresh nominal witness for the selected compiled Profile.
withSelectedArchiMateProfile ::
     ProfileDescriptor
  -> (forall profile. SelectedArchiMateProfile profile -> result)
  -> result
withSelectedArchiMateProfile = withSelectedArchiMateProfileValue

-- | Immutable descriptor carried by the selected-Profile witness.
selectedArchiMateProfileDescriptor ::
     SelectedArchiMateProfile profile -> ProfileDescriptor
selectedArchiMateProfileDescriptor = selectedArchiMateProfileDescriptorValue
