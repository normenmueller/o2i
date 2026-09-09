module ProfileDescriptorRecordUpdate where

import qualified O2I.ArchiMate.Profile as Profile

rewriteDescriptor :: Profile.ProfileDescriptor -> Profile.ProfileDescriptor
rewriteDescriptor descriptor =
  descriptor
    { Profile.profileDescriptorIdentity =
        Profile.profileDescriptorIdentity descriptor
    }
