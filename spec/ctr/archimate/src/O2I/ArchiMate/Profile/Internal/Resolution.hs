{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

module O2I.ArchiMate.Profile.Internal.Resolution where

import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Generated

-- | Immutable material contributed by one compiled Profile.
data ProfileDescriptor = ProfileDescriptor
  { profileDescriptorIdentityValue :: !Text
  , profileDescriptorTokenValue :: !Text
  , profileDescriptorVersionValue :: !Text
  , profileDescriptorNotationValue :: !Text
  , profileDescriptorAdapterIdsValue :: ![Text]
  , profileDescriptorContractDigestValue :: !Text
  } deriving (Eq, Ord, Show)

-- | One immutable compiled Profile carrying a fresh nominal witness.
newtype SelectedArchiMateProfile profile =
  SelectedArchiMateProfile ProfileDescriptor

type role SelectedArchiMateProfile nominal

compiledDescriptor :: ProfileDescriptor
compiledDescriptor =
  ProfileDescriptor
    (generatedProfileIdentity generatedProfileDescriptor)
    (generatedProfileToken generatedProfileDescriptor)
    (generatedProfileVersion generatedProfileDescriptor)
    (generatedProfileNotation generatedProfileDescriptor)
    (generatedProfileAdapterIds generatedProfileDescriptor)
    (generatedProfileContractDigest generatedProfileDescriptor)

descriptorReference :: ProfileDescriptor -> Text
descriptorReference descriptor =
  profileDescriptorIdentityValue descriptor
    <> "@"
    <> profileDescriptorTokenValue descriptor

withSelectedArchiMateProfileValue ::
     ProfileDescriptor
  -> (forall profile. SelectedArchiMateProfile profile -> result)
  -> result
withSelectedArchiMateProfileValue descriptor consume =
  consume (SelectedArchiMateProfile descriptor)

selectedArchiMateProfileDescriptorValue ::
     SelectedArchiMateProfile profile -> ProfileDescriptor
selectedArchiMateProfileDescriptorValue (SelectedArchiMateProfile descriptor) =
  descriptor
