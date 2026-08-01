{-# LANGUAGE TemplateHaskell #-}

-- | External-client contracts for the public ArchiMate profile API.
module Main
  ( main
  ) where

import ApiContractTH (assertAbstractTypes, assertOrdinaryFunctions)
import qualified O2I.ArchiMate.Profile as Profile

$(assertAbstractTypes
    [ "Profile.ArchiMateProfileContract"
    , "Profile.MetadataContract"
    , "Profile.CarrierMapping"
    , "Profile.Requirement"
    , "Profile.Cardinality"
    , "Profile.ArchiMateRelationshipRepresentation"
    , "Profile.ArchiMateRelationMapping"
    , "Profile.ContextualizationContract"
    , "Profile.CollectiveContract"
    , "Profile.CollectiveCarrierContract"
    , "Profile.CollectiveSegmentContract"
    , "Profile.CollectiveContributorsContract"
    , "Profile.CollectiveTargetContract"
    ])

$(assertOrdinaryFunctions
    [ 'Profile.contractProfileVersion
    , 'Profile.contractMetadata
    , 'Profile.contractContextualization
    , 'Profile.contractCollectiveRealization
    , 'Profile.modelProfileKey
    , 'Profile.modelProfileCardinality
    , 'Profile.modelAdditionalO2IProperties
    , 'Profile.carrierKindKey
    , 'Profile.carrierTypeKey
    , 'Profile.carrierCommitmentKey
    , 'Profile.relationCommitmentKey
    , 'Profile.carrierMappingElement
    , 'Profile.carrierMappingOwnership
    , 'Profile.relationMappingCode
    , 'Profile.relationMappingName
    , 'Profile.relationMappingLabel
    , 'Profile.relationMappingSource
    , 'Profile.relationMappingTarget
    , 'Profile.relationMappingRepresentation
    , 'Profile.relationshipTypeName
    , 'Profile.relationshipDirected
    , 'Profile.contextualizationRepresentation
    , 'Profile.contextualizationLabel
    , 'Profile.collectiveCarrier
    , 'Profile.collectiveSegments
    , 'Profile.collectiveContributors
    , 'Profile.collectiveTarget
    , 'Profile.collectiveJunctionChains
    , 'Profile.collectiveCarrierKind
    , 'Profile.collectiveCarrierType
    , 'Profile.collectiveCarrierElement
    , 'Profile.collectiveJunctionType
    , 'Profile.collectiveCommitmentKey
    , 'Profile.collectiveFitEvidenceKey
    , 'Profile.collectiveSegmentRepresentation
    , 'Profile.collectiveSegmentLabel
    , 'Profile.collectiveSegmentMetadata
    , 'Profile.collectiveContributorCardinality
    , 'Profile.collectiveContributorsDistinct
    , 'Profile.collectiveTargetCardinality
    , 'Profile.collectiveTargetDistinctFromContributors
    ])

main :: IO ()
main = pure ()
