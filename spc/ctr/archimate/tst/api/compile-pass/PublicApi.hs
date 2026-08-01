module PublicApi where

import qualified O2I.ArchiMate.Profile as Profile

profileContractObservations contract =
  ( Profile.contractProfileVersion contract
  , Profile.contractMetadata contract
  , Profile.contractContextualization contract
  , Profile.contractCollectiveRealization contract)

metadataObservations metadata =
  ( Profile.modelProfileKey metadata
  , Profile.modelProfileCardinality metadata
  , Profile.modelAdditionalO2IProperties metadata
  , Profile.carrierKindKey metadata
  , Profile.carrierTypeKey metadata
  , Profile.carrierCommitmentKey metadata
  , Profile.relationCommitmentKey metadata)

carrierObservations mapping =
  ( Profile.carrierMappingElement mapping
  , Profile.carrierMappingOwnership mapping)

relationObservations mapping =
  ( Profile.relationMappingCode mapping
  , Profile.relationMappingName mapping
  , Profile.relationMappingLabel mapping
  , Profile.relationMappingSource mapping
  , Profile.relationMappingTarget mapping
  , Profile.relationMappingRepresentation mapping)

relationshipObservations representation =
  ( Profile.relationshipTypeName representation
  , Profile.relationshipDirected representation)

contextualizationObservations contextualization =
  ( Profile.contextualizationRepresentation contextualization
  , Profile.contextualizationLabel contextualization)

collectiveObservations collective =
  ( Profile.collectiveCarrier collective
  , Profile.collectiveSegments collective
  , Profile.collectiveContributors collective
  , Profile.collectiveTarget collective
  , Profile.collectiveJunctionChains collective)

collectiveCarrierObservations carrier =
  ( Profile.collectiveCarrierKind carrier
  , Profile.collectiveCarrierType carrier
  , Profile.collectiveCarrierElement carrier
  , Profile.collectiveJunctionType carrier
  , Profile.collectiveCommitmentKey carrier
  , Profile.collectiveFitEvidenceKey carrier)

collectiveSegmentObservations segment =
  ( Profile.collectiveSegmentRepresentation segment
  , Profile.collectiveSegmentLabel segment
  , Profile.collectiveSegmentMetadata segment)

collectiveContributorObservations contributors =
  ( Profile.collectiveContributorCardinality contributors
  , Profile.collectiveContributorsDistinct contributors)

collectiveTargetObservations target =
  ( Profile.collectiveTargetCardinality target
  , Profile.collectiveTargetDistinctFromContributors target)

profileControl = profileContractObservations Profile.profileContract
