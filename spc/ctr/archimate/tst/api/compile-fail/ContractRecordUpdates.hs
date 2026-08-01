module ContractRecordUpdates where

import qualified O2I.ArchiMate.Profile as Profile

rewriteContract ::
     Profile.ArchiMateProfileContract -> Profile.ArchiMateProfileContract
rewriteContract contract =
  contract
    { Profile.contractProfileVersion = Profile.contractProfileVersion contract
    , Profile.contractMetadata = Profile.contractMetadata contract
    , Profile.contractContextualization =
        Profile.contractContextualization contract
    , Profile.contractCollectiveRealization =
        Profile.contractCollectiveRealization contract
    }

rewriteMetadata :: Profile.MetadataContract -> Profile.MetadataContract
rewriteMetadata metadata =
  metadata
    { Profile.modelProfileKey = Profile.modelProfileKey metadata
    , Profile.modelProfileCardinality = Profile.modelProfileCardinality metadata
    , Profile.modelAdditionalO2IProperties =
        Profile.modelAdditionalO2IProperties metadata
    , Profile.carrierKindKey = Profile.carrierKindKey metadata
    , Profile.carrierTypeKey = Profile.carrierTypeKey metadata
    , Profile.carrierCommitmentKey = Profile.carrierCommitmentKey metadata
    , Profile.relationCommitmentKey = Profile.relationCommitmentKey metadata
    }

rewriteCarrierMapping :: Profile.CarrierMapping -> Profile.CarrierMapping
rewriteCarrierMapping mapping =
  mapping
    { Profile.carrierMappingElement = Profile.carrierMappingElement mapping
    , Profile.carrierMappingOwnership = Profile.carrierMappingOwnership mapping
    }
