{-# LANGUAGE OverloadedStrings #-}

-- | Complete equality between the authoritative JSON and typed projection.
module O2I.ArchiMate.Profile.Test.Contract
  ( contractTests
  ) where

import Data.Aeson (Value, (.=), eitherDecodeStrict', object)
import qualified Data.ByteString as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import O2I (RelationName(..))
import O2I.ArchiMate.Profile.Internal
import Paths_o2i_archimate_profile (getDataFileName)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

contractTests :: TestTree
contractTests =
  testGroup
    "contract"
    [ testCase
        "Haskell projection equals the authoritative JSON contract"
        contractEqualityTest
    ]

contractEqualityTest :: Assertion
contractEqualityTest = do
  contractPath <- getDataFileName "archimate-profile.json"
  bytes <- ByteString.readFile contractPath
  authoritative <-
    case eitherDecodeStrict' bytes of
      Left failure ->
        assertFailure
          ("cannot decode authoritative ArchiMate profile: " <> failure)
      Right value -> pure value
  length (contractCarrierMappings profileContract) @?= 14
  length (contractRelationMappings profileContract) @?= 60
  profileContractValue profileContract @?= authoritative

profileContractValue :: ArchiMateProfileContract -> Value
profileContractValue contract =
  object
    [ "schema" .= contractSchema contract
    , "profileVersion" .= profileVersionText (contractProfileVersion contract)
    , "metadata" .= metadataValue (contractMetadata contract)
    , "carrierMappings" .= map carrierValue (contractCarrierMappings contract)
    , "relationMappings"
        .= map relationValue (contractRelationMappings contract)
    , "patternMappings"
        .= [ contextualizationValue (contractContextualization contract)
           , collectiveValue (contractCollectiveRealization contract)
           ]
    ]

metadataValue :: MetadataContract -> Value
metadataValue metadata =
  object
    [ "modelRoot"
        .= object
             [ "profileKey" .= modelProfileKey metadata
             , "cardinality"
                 .= cardinalityText (modelProfileCardinality metadata)
             , "additionalO2IProperties"
                 .= requirementText (modelAdditionalO2IProperties metadata)
             ]
    , "typedCarrier"
        .= object
             [ "kindKey" .= carrierKindKey metadata
             , "typeKey" .= carrierTypeKey metadata
             , "commitmentKey" .= carrierCommitmentKey metadata
             , "commitmentValues"
                 .= map
                      commitmentText
                      (NonEmpty.toList (carrierCommitmentValues metadata))
             , "cardinality"
                 .= cardinalityText (carrierMetadataCardinality metadata)
             , "additionalO2IProperties"
                 .= requirementText (carrierAdditionalO2IProperties metadata)
             ]
    , "semanticRelation"
        .= object
             [ "commitmentKey" .= relationCommitmentKey metadata
             , "commitmentValues"
                 .= map
                      commitmentText
                      (NonEmpty.toList (relationCommitmentValues metadata))
             , "cardinality"
                 .= cardinalityText (relationMetadataCardinality metadata)
             , "additionalO2IProperties"
                 .= requirementText (relationAdditionalO2IProperties metadata)
             ]
    ]

carrierValue :: CarrierMapping -> Value
carrierValue mapping =
  object
    [ "id" .= carrierMappingId mapping
    , "o2iKind" .= metadataKindText (carrierMappingKind mapping)
    , "o2iTypes"
        .= map carrierTypeText (NonEmpty.toList (carrierMappingTypes mapping))
    , "archimateElement" .= carrierMappingElement mapping
    , "contextOwnership" .= requirementText (carrierMappingOwnership mapping)
    ]

relationValue :: ArchiMateRelationMapping -> Value
relationValue signature =
  object
    [ "id" .= relationMappingId signature
    , "relationName" .= relationNameText (relationMappingName signature)
    , "source" .= nodeKindIdentifier (relationMappingSource signature)
    , "target" .= nodeKindIdentifier (relationMappingTarget signature)
    , "label" .= relationMappingLabel signature
    , "archimateRelationship"
        .= relationshipTypeName (relationMappingRepresentation signature)
    , "associationDirected"
        .= relationshipDirected (relationMappingRepresentation signature)
    ]

contextualizationValue :: ContextualizationContract -> Value
contextualizationValue contract =
  object
    [ "id" .= contextualizationId contract
    , "archimateRelationship"
        .= relationshipTypeName (contextualizationRepresentation contract)
    , "label" .= contextualizationLabel contract
    , "associationDirected"
        .= relationshipDirected (contextualizationRepresentation contract)
    , "sourceKind" .= metadataKindText (contextualizationSourceKind contract)
    , "targetKinds"
        .= map
             metadataKindText
             (NonEmpty.toList (contextualizationTargetKinds contract))
    , "targetIncomingCardinality"
        .= cardinalityText (contextualizationIncomingCardinality contract)
    , "o2iMetadata" .= requirementText (contextualizationMetadata contract)
    , "projection" .= contextualizationProjection contract
    ]

collectiveValue :: CollectiveContract -> Value
collectiveValue contract =
  object
    [ "id" .= collectiveId contract
    , "carrier" .= collectiveCarrierValue (collectiveCarrier contract)
    , "segments" .= collectiveSegmentValue (collectiveSegments contract)
    , "contributors"
        .= collectiveContributorsValue (collectiveContributors contract)
    , "target" .= collectiveTargetValue (collectiveTarget contract)
    , "junctionChains" .= requirementText (collectiveJunctionChains contract)
    , "projection" .= collectiveProjection contract
    ]

collectiveCarrierValue :: CollectiveCarrierContract -> Value
collectiveCarrierValue carrier =
  object
    [ "o2iKind" .= metadataKindText (collectiveCarrierKind carrier)
    , "o2iType" .= collectiveCarrierType carrier
    , "archimateElement" .= collectiveCarrierElement carrier
    , "junctionType" .= collectiveJunctionType carrier
    , "commitmentKey" .= collectiveCommitmentKey carrier
    , "commitmentValues"
        .= map
             commitmentText
             (NonEmpty.toList (collectiveCommitmentValues carrier))
    , "fitEvidenceKey" .= collectiveFitEvidenceKey carrier
    , "fitEvidenceCardinality"
        .= cardinalityText (collectiveFitEvidenceCardinality carrier)
    , "additionalO2IProperties"
        .= requirementText (collectiveAdditionalO2IProperties carrier)
    ]

collectiveSegmentValue :: CollectiveSegmentContract -> Value
collectiveSegmentValue segment =
  object
    [ "archimateRelationship"
        .= relationshipTypeName (collectiveSegmentRepresentation segment)
    , "label" .= collectiveSegmentLabel segment
    , "associationDirected"
        .= relationshipDirected (collectiveSegmentRepresentation segment)
    , "o2iMetadata" .= requirementText (collectiveSegmentMetadata segment)
    ]

collectiveContributorsValue :: CollectiveContributorsContract -> Value
collectiveContributorsValue contributors =
  object
    [ "endpoint"
        .= nodeKindIdentifier (collectiveContributorEndpoint contributors)
    , "cardinality"
        .= cardinalityText (collectiveContributorCardinality contributors)
    , "distinct"
        .= requirementText (collectiveContributorsDistinct contributors)
    ]

collectiveTargetValue :: CollectiveTargetContract -> Value
collectiveTargetValue target =
  object
    [ "endpoint" .= nodeKindIdentifier (collectiveTargetEndpoint target)
    , "cardinality" .= cardinalityText (collectiveTargetCardinality target)
    , "distinctFromContributors"
        .= requirementText (collectiveTargetDistinctFromContributors target)
    ]
