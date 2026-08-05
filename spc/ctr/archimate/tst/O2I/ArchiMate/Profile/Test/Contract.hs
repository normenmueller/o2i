{-# LANGUAGE OverloadedStrings #-}

-- | Complete equality between the authoritative JSON and typed projection.
module O2I.ArchiMate.Profile.Test.Contract
  ( contractTests
  ) where

import Data.Aeson (Value, (.=), eitherDecodeStrict', object)
import qualified Data.ByteString as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I
  ( Context(..)
  , FixedRelationCode(..)
  , NodeKindValue(..)
  , RelationCode(..)
  , RelationName(..)
  )
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
    , testCase
        "applicability provenance exposes the admitted exact source"
        applicabilityProvenanceTest
    , testCase
        "applicability decision derives typed mapping and carrier coordinates"
        applicabilityDecisionTest
    , testCase
        "only Strategy directs Strategy uses Influence"
        endpointSensitiveDirectsTest
    ]

contractEqualityTest :: Assertion
contractEqualityTest = do
  contractPath <- getDataFileName "profile.json"
  bytes <- ByteString.readFile contractPath
  authoritative <-
    case eitherDecodeStrict' bytes of
      Left failure ->
        assertFailure
          ("cannot decode authoritative ArchiMate profile: " <> failure)
      Right value -> pure value
  length (contractCarrierMappings profileContract) @?= 12
  length (contractRelationMappings profileContract) @?= 52
  profileContractValue profileContract @?= authoritative

applicabilityProvenanceTest :: Assertion
applicabilityProvenanceTest = do
  contractSchema profileContract @?= "o2i.archimate-profile/v2"
  profileVersionText (contractProfileVersion profileContract) @?= "0.3"
  let provenance = contractApplicabilityProvenance profileContract
      implementation = applicabilityMatrixImplementation provenance
      symbols = NonEmpty.toList (applicabilitySymbolInterpretations provenance)
      decisions = NonEmpty.toList (applicabilityDecisions provenance)
      revision = matrixImplementationRevision implementation
      relativePath = matrixImplementationRepositoryRelativePath implementation
  applicabilityArchiMateStandardVersion provenance @?= "3.2"
  matrixImplementationRepositoryUri implementation
    @?= "https://github.com/archimatetool/archi"
  relativePath @?= "com.archimatetool.model/model/relationships.xml"
  revision @?= "b5bd0038922ab68b26eb78c97ff7efc2ff0bba82"
  assertBool
    "matrix path must be repository-relative"
    (isRelativePath relativePath)
  Text.length revision @?= 40
  assertBool
    "matrix revision must be lowercase ASCII hex"
    (Text.all isHex revision)
  length symbols @?= 1
  length decisions @?= 1

applicabilityDecisionTest :: Assertion
applicabilityDecisionTest = do
  let provenance = contractApplicabilityProvenance profileContract
      symbol = NonEmpty.head (applicabilitySymbolInterpretations provenance)
      decision = NonEmpty.head (applicabilityDecisions provenance)
      mapping = applicabilityDecisionRelationMapping decision
  symbolInterpretationSymbol symbol @?= "n"
  relationshipTypeName (symbolInterpretationRelationship symbol)
    @?= "InfluenceRelationship"
  applicabilityDecisionRelationMappingId decision
    @?= "strategy-directs-strategy"
  applicabilityDecisionSourceElement decision @?= "Grouping"
  applicabilityDecisionTargetElement decision @?= "Grouping"
  applicabilityDecisionMatrixSymbol decision @?= "n"
  mapping `elem` contractRelationMappings profileContract @?= True
  relationMappingCode mapping @?= FixedRelation DirectsStrategyCode
  relationMappingSource mapping @?= ContextNodeKind Strategy
  relationMappingTarget mapping @?= ContextNodeKind Strategy
  relationMappingRepresentation mapping
    @?= symbolInterpretationRelationship symbol

endpointSensitiveDirectsTest :: Assertion
endpointSensitiveDirectsTest = do
  assertRepresentation DirectsStrategyCode "InfluenceRelationship" False
  assertRepresentation ContributesToStrategyCode "AssociationRelationship" True
  assertRepresentation DirectsInterventionCode "AssociationRelationship" True

assertRepresentation :: FixedRelationCode -> Text.Text -> Bool -> Assertion
assertRepresentation fixed expectedType expectedDirected =
  case filter hasCode (contractRelationMappings profileContract) of
    [mapping] -> do
      let representation = relationMappingRepresentation mapping
      relationshipTypeName representation @?= expectedType
      relationshipDirected representation @?= expectedDirected
    mappings ->
      assertFailure
        ("expected exactly one mapping for "
           <> show fixed
           <> ", found "
           <> show (length mappings))
  where
    hasCode mapping = relationMappingCode mapping == FixedRelation fixed

isRelativePath :: Text.Text -> Bool
isRelativePath path =
  not (Text.null path)
    && not (Text.isPrefixOf "/" path)
    && all validSegment (Text.splitOn "/" path)
  where
    validSegment segment =
      not (Text.null segment) && segment /= "." && segment /= ".."

isHex :: Char -> Bool
isHex character =
  ('0' <= character && character <= '9')
    || ('a' <= character && character <= 'f')

profileContractValue :: ArchiMateProfileContract -> Value
profileContractValue contract =
  object
    [ "schema" .= contractSchema contract
    , "profileVersion" .= profileVersionText (contractProfileVersion contract)
    , "applicabilityProvenance"
        .= applicabilityProvenanceValue
             (contractApplicabilityProvenance contract)
    , "metadata" .= metadataValue (contractMetadata contract)
    , "carrierMappings" .= map carrierValue (contractCarrierMappings contract)
    , "relationMappings"
        .= map relationValue (contractRelationMappings contract)
    , "patternMappings"
        .= [ contextualizationValue (contractContextualization contract)
           , collectiveValue (contractCollectiveRealization contract)
           ]
    ]

applicabilityProvenanceValue :: ApplicabilityProvenance -> Value
applicabilityProvenanceValue provenance =
  object
    [ "archimateStandardVersion"
        .= applicabilityArchiMateStandardVersion provenance
    , "matrixImplementation"
        .= matrixImplementationValue
             (applicabilityMatrixImplementation provenance)
    , "symbolInterpretations"
        .= map
             symbolInterpretationValue
             (NonEmpty.toList (applicabilitySymbolInterpretations provenance))
    , "decisions"
        .= map
             applicabilityDecisionValue
             (NonEmpty.toList (applicabilityDecisions provenance))
    ]

matrixImplementationValue :: MatrixImplementation -> Value
matrixImplementationValue implementation =
  object
    [ "repositoryUri" .= matrixImplementationRepositoryUri implementation
    , "repositoryRelativePath"
        .= matrixImplementationRepositoryRelativePath implementation
    , "revision" .= matrixImplementationRevision implementation
    ]

symbolInterpretationValue :: SymbolInterpretation -> Value
symbolInterpretationValue interpretation =
  object
    [ "symbol" .= symbolInterpretationSymbol interpretation
    , "archimateRelationship"
        .= relationshipTypeName
             (symbolInterpretationRelationship interpretation)
    ]

applicabilityDecisionValue :: ApplicabilityDecision -> Value
applicabilityDecisionValue decision =
  object
    [ "relationMappingId" .= applicabilityDecisionRelationMappingId decision
    , "sourceElement" .= applicabilityDecisionSourceElement decision
    , "targetElement" .= applicabilityDecisionTargetElement decision
    , "matrixSymbol" .= applicabilityDecisionMatrixSymbol decision
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
