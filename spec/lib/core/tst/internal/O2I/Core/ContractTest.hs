{-# LANGUAGE OverloadedStrings #-}

-- | Focused laws for the closed Core companion catalogs.
module Main
  ( main
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Contract
import qualified O2I.Core.Contract.Generated as Generated
import qualified O2I.Core.Contract.Internal as Internal
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "closed Core companion catalogs"
    [ testCase "carrier categories are an exact closed projection" $ do
        coreCarrierCategories
          @?= (Internal.CoreCarrierCategory
                 <$> Generated.generatedCarrierCategories)
        assertExactCatalog
          coreCarrierCategories
          coreCarrierCategoryText
          lookupCoreCarrierCategory
          (Generated.generatedCarrierCategoryText
             <$> Generated.generatedCarrierCategories)
    , testCase "O2I types are an exact closed projection" $ do
        coreO2ITypes @?= (Internal.CoreO2IType <$> Generated.generatedO2ITypes)
        assertExactCatalog
          coreO2ITypes
          coreO2ITypeText
          lookupCoreO2IType
          (Generated.generatedO2ITypeText <$> Generated.generatedO2ITypes)
    , testCase "qualified endpoints are an exact closed projection" $ do
        coreQualifiedEndpointIds
          @?= (Internal.CoreQualifiedEndpointId
                 <$> Generated.generatedQualifiedEndpoints)
        assertExactCatalog
          coreQualifiedEndpointIds
          coreQualifiedEndpointIdText
          lookupCoreQualifiedEndpointId
          (Generated.generatedQualifiedEndpointText
             <$> Generated.generatedQualifiedEndpoints)
    , testCase "relation tokens are an exact closed projection" $ do
        coreRelationTokens
          @?= (Internal.CoreRelationToken <$> Generated.generatedRelationTokens)
        assertExactCatalog
          coreRelationTokens
          coreRelationTokenText
          lookupCoreRelationToken
          (Generated.generatedRelationTokenText
             <$> Generated.generatedRelationTokens)
    , testCase "structured families are an exact closed projection" $ do
        coreStructuredPropositionFamilyIds
          @?= (Internal.CoreStructuredPropositionFamilyId
                 <$> Generated.generatedStructuredPropositionFamilies)
        assertExactCatalog
          coreStructuredPropositionFamilyIds
          coreStructuredPropositionFamilyIdText
          lookupCoreStructuredPropositionFamilyId
          (Generated.generatedStructuredPropositionFamilyText
             <$> Generated.generatedStructuredPropositionFamilies)
    , testCase "structured roles are an exact closed projection" $ do
        coreStructuredPropositionRoleIds
          @?= (Internal.CoreStructuredPropositionRoleId
                 <$> Generated.generatedStructuredPropositionRoles)
        assertExactCatalog
          coreStructuredPropositionRoleIds
          coreStructuredPropositionRoleIdText
          lookupCoreStructuredPropositionRoleId
          (Generated.generatedStructuredPropositionRoleText
             <$> Generated.generatedStructuredPropositionRoles)
    , testCase "qualification roles are an exact closed projection" $ do
        coreQualificationProposalRoleIds
          @?= (Internal.CoreQualificationProposalRoleId
                 <$> Generated.generatedQualificationProposalRoles)
        assertExactCatalog
          coreQualificationProposalRoleIds
          coreQualificationProposalRoleIdText
          lookupCoreQualificationProposalRoleId
          (Generated.generatedQualificationProposalRoleText
             <$> Generated.generatedQualificationProposalRoles)
    , testCase "participant completeness has exact identities and tokens" $ do
        coreParticipantCompletenessValues
          @?= (Internal.CoreParticipantCompleteness
                 <$> Generated.generatedParticipantCompletenessValues)
        assertExactCatalog
          coreParticipantCompletenessValues
          coreParticipantCompletenessIdText
          lookupCoreParticipantCompletenessId
          (Generated.generatedParticipantCompletenessIdText
             <$> Generated.generatedParticipantCompletenessValues)
        assertExactCatalog
          coreParticipantCompletenessValues
          coreParticipantCompletenessToken
          lookupCoreParticipantCompletenessToken
          (Generated.generatedParticipantCompletenessToken
             <$> Generated.generatedParticipantCompletenessValues)
    , testCase "semantic lookups reject non-canonical text" $ do
        assertExactLookup lookupCoreCarrierCategory "Context"
        assertExactLookup lookupCoreO2IType "Strategy"
        assertExactLookup lookupCoreQualifiedEndpointId "context.strategy"
        assertExactLookup lookupCoreRelationToken "directs"
        assertExactLookup
          lookupCoreStructuredPropositionFamilyId
          "collective-strategy-realization"
        assertExactLookup
          lookupCoreStructuredPropositionRoleId
          "collective-strategy-realization.role.participant"
        assertExactLookup
          lookupCoreQualificationProposalRoleId
          "need-qualification-proposal.role.need"
        assertExactLookup lookupCoreParticipantCompletenessToken "closed"
        assertExactLookup
          lookupCoreParticipantCompletenessId
          "collective-strategy-realization.participant-completeness.closed"
    ]

assertExactCatalog ::
     (Eq value, Show value)
  => NonEmpty.NonEmpty value
  -> (value -> Text)
  -> (Text -> Maybe value)
  -> NonEmpty.NonEmpty Text
  -> Assertion
assertExactCatalog values project lookupValue generatedTexts = do
  let canonicalTexts = project <$> values
  canonicalTexts @?= generatedTexts
  traverse lookupValue canonicalTexts @?= Just values

assertExactLookup ::
     (Eq value, Show value) => (Text -> Maybe value) -> Text -> Assertion
assertExactLookup lookupValue canonicalText = do
  lookupValue (" " <> canonicalText) @?= Nothing
  lookupValue (canonicalText <> " ") @?= Nothing
  lookupValue "UNKNOWN" @?= Nothing
