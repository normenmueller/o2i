{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreRelationToken
  , coreQualifiedEndpointIdText
  , coreQualifiedEndpointIds
  , coreRelationTokenText
  , coreRelationTokens
  )
import O2I.Core.Graph.Commitment (Commitment(..))
import O2I.Core.Graph.Observation.Index
import O2I.Core.Graph.Observation.Internal
import O2I.Core.Identity
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

main :: IO ()
main =
  defaultMain
    (testGroup
       "canonical graph observations"
       [ canonicalConstruction
       , derivesCanonicalCarrierIdentity
       , permutationIndependent
       , rejectsInvalidScope
       , rejectsOutsideObservation
       , rejectsDuplicateObservation
       , rejectsCrossKindDuplicate
       , rejectsMissingCarrier
       , reportsEveryMissingEndpointRole
       ])

canonicalConstruction :: TestTree
canonicalConstruction =
  testCase "retains exact identities, canonical order, and exact work" $ do
    snapshot canonicalInputs @?= Right expectedSnapshot

derivesCanonicalCarrierIdentity :: TestTree
derivesCanonicalCarrierIdentity =
  testCase "derives carrier model identity from the canonical identity index" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           [occurrenceA]
           inputs
           inspect of
      Left defects -> assertFailure ("unexpected defects: " ++ show defects)
      Right modelIdentifiers -> modelIdentifiers @?= [modelId "model-a"]
  where
    inputs = [CarrierObservationInput occurrenceA endpointA Asserted]
    inspect _ index = map carrierModelIdentity (graphCarrierObservations index)

permutationIndependent :: TestTree
permutationIndependent =
  testCase "input permutation does not change canonical observations" $ do
    snapshot canonicalInputs @?= snapshot (reverse canonicalInputs)

rejectsInvalidScope :: TestTree
rejectsInvalidScope =
  testCase "rejects unknown selected-View membership before observations" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           [unknownOccurrence]
           []
           result of
      Left (SelectedViewScopeRejected defect NonEmpty.:| []) ->
        selectedViewScopeDefectOccurrence defect @?= unknownOccurrence
      other -> assertFailure ("unexpected result: " ++ show other)
  where
    result _ _ = ()

rejectsOutsideObservation :: TestTree
rejectsOutsideObservation =
  testCase "rejects observation occurrences outside the selected View" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           [occurrenceA]
           inputs
           result of
      Left (ObservationOutsideSelectedView occurrence NonEmpty.:| []) ->
        occurrence @?= occurrenceB
      other -> assertFailure ("unexpected result: " ++ show other)
  where
    inputs = [CarrierObservationInput occurrenceB endpointB Candidate]
    result _ _ = ()

rejectsDuplicateObservation :: TestTree
rejectsDuplicateObservation =
  testCase "rejects duplicate canonical observation occurrences" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           [occurrenceA]
           inputs
           result of
      Left (DuplicateGraphObservation occurrence kinds NonEmpty.:| []) -> do
        occurrence @?= occurrenceA
        NonEmpty.toList kinds
          @?= [CarrierObservationKind, CarrierObservationKind]
      other -> assertFailure ("unexpected result: " ++ show other)
  where
    inputs =
      [ CarrierObservationInput occurrenceA endpointA Candidate
      , CarrierObservationInput occurrenceA endpointA Asserted
      ]
    result _ _ = ()

rejectsCrossKindDuplicate :: TestTree
rejectsCrossKindDuplicate =
  testCase "rejects one occurrence observed through different graph kinds" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           selected
           inputs
           result of
      Left (DuplicateGraphObservation occurrence kinds NonEmpty.:| []) -> do
        occurrence @?= occurrenceA
        NonEmpty.toList kinds
          @?= [CarrierObservationKind, RelationObservationKind]
      other -> assertFailure ("unexpected result: " ++ show other)
  where
    selected = [occurrenceA, occurrenceB]
    inputs =
      [ CarrierObservationInput occurrenceA endpointA Asserted
      , CarrierObservationInput occurrenceB endpointB Asserted
      , RelationObservationInput
          occurrenceA
          occurrenceA
          relationTokenValue
          occurrenceB
          Asserted
      ]
    result _ _ = ()

rejectsMissingCarrier :: TestTree
rejectsMissingCarrier =
  testCase "rejects relation endpoints without carrier observations" $ do
    case withGraphObservationIndex
           identityIndex
           selectedViewSubject
           selected
           inputs
           result of
      Left (MissingCarrierEndpoint owner role endpoint NonEmpty.:| []) -> do
        owner @?= relationOccurrence
        role @?= RelationTargetRole
        endpoint @?= occurrenceB
      other -> assertFailure ("unexpected result: " ++ show other)
  where
    selected = [occurrenceA, occurrenceB, relationOccurrence]
    inputs =
      [ CarrierObservationInput occurrenceA endpointA Asserted
      , RelationObservationInput
          relationOccurrence
          occurrenceA
          relationTokenValue
          occurrenceB
          Asserted
      ]
    result _ _ = ()

reportsEveryMissingEndpointRole :: TestTree
reportsEveryMissingEndpointRole =
  testCase "reports every missing relation and contextualization endpoint" $ do
    withGraphObservationIndex
      identityIndex
      selectedViewSubject
      selected
      inputs
      result
      @?= Left expected
  where
    selected =
      [ occurrenceA
      , occurrenceB
      , relationOccurrence
      , contextualizationOccurrence
      ]
    inputs =
      [ RelationObservationInput
          relationOccurrence
          occurrenceA
          relationTokenValue
          occurrenceB
          Asserted
      , ContextualizationObservationInput
          contextualizationOccurrence
          occurrenceA
          occurrenceB
          Asserted
      ]
    expected =
      MissingCarrierEndpoint
        contextualizationOccurrence
        ContextualizationOwnerRole
        occurrenceA
        NonEmpty.:| [ MissingCarrierEndpoint
                        contextualizationOccurrence
                        ContextualizationMemberRole
                        occurrenceB
                    , MissingCarrierEndpoint
                        relationOccurrence
                        RelationSourceRole
                        occurrenceA
                    , MissingCarrierEndpoint
                        relationOccurrence
                        RelationTargetRole
                        occurrenceB
                    ]
    result _ _ = ()

data Snapshot =
  Snapshot
    [(Text, Text, Text, Commitment)]
    [(Text, Text, Text, Text, Commitment)]
    [(Text, Text, Text, Commitment)]
    (Int, Int, Int, Int)
  deriving (Eq, Show)

snapshot :: [GraphObservationInput] -> Either String Snapshot
snapshot inputs =
  case withGraphObservationIndex
         identityIndex
         selectedViewSubject
         selectedOccurrences
         inputs
         inspect of
    Left defects -> Left (show defects)
    Right value -> Right value
  where
    inspect _ index =
      Snapshot
        [ ( occurrenceIdentityText (carrierOccurrenceIdentity carrier)
          , modelIdentityText (carrierModelIdentity carrier)
          , coreQualifiedEndpointIdText (carrierQualifiedEndpoint carrier)
          , carrierCommitment carrier)
        | carrier <- graphCarrierObservations index
        ]
        [ ( occurrenceIdentityText (relationOccurrenceIdentity relation)
          , occurrenceIdentityText (relationSourceOccurrence relation)
          , coreRelationTokenText (relationToken relation)
          , occurrenceIdentityText (relationTargetOccurrence relation)
          , relationCommitment relation)
        | relation <- graphRelationObservations index
        ]
        [ ( occurrenceIdentityText
              (contextualizationOccurrenceIdentity contextualization)
          , occurrenceIdentityText
              (contextualizationOwnerOccurrence contextualization)
          , occurrenceIdentityText
              (contextualizationMemberOccurrence contextualization)
          , contextualizationCommitment contextualization)
        | contextualization <- graphContextualizationObservations index
        ]
        ( graphBuildSelectedMemberships work
        , graphBuildObservationVisits work
        , graphBuildReferenceVisits work
        , graphBuildIndexEntries work)
      where
        work = graphObservationBuildWork index

expectedSnapshot :: Snapshot
expectedSnapshot =
  Snapshot
    [ ("carrier-a", "model-a", "context.strategy", Candidate)
    , ("carrier-b", "model-b", "primitive.strategy.action", Asserted)
    ]
    [("relation-r", "carrier-a", "contributes-to", "carrier-b", Asserted)]
    [("contextualization-x", "carrier-a", "carrier-b", Candidate)]
    (4, 4, 8, 4)

canonicalInputs :: [GraphObservationInput]
canonicalInputs =
  [ RelationObservationInput
      relationOccurrence
      occurrenceA
      relationTokenValue
      occurrenceB
      Asserted
  , CarrierObservationInput occurrenceB endpointB Asserted
  , ContextualizationObservationInput
      contextualizationOccurrence
      occurrenceA
      occurrenceB
      Candidate
  , CarrierObservationInput occurrenceA endpointA Candidate
  ]

selectedOccurrences :: [OccurrenceIdentity]
selectedOccurrences =
  [relationOccurrence, occurrenceB, contextualizationOccurrence, occurrenceA]

identityIndex :: ModelIdentityIndex
identityIndex =
  expectRight
    (buildModelIdentityIndex
       [ selectedViewSubject
       , modelOccurrenceA
       , modelOccurrenceB
       , modelOccurrence relationOccurrence (modelId "model-relation")
       , modelOccurrence
           contextualizationOccurrence
           (modelId "model-contextualization")
       ])

selectedViewSubject :: ModelOccurrence
selectedViewSubject =
  modelOccurrence (occurrenceId "selected-view") (modelId "selected-view-id")

modelOccurrenceA :: ModelOccurrence
modelOccurrenceA = modelOccurrence occurrenceA (modelId "model-a")

modelOccurrenceB :: ModelOccurrence
modelOccurrenceB = modelOccurrence occurrenceB (modelId "model-b")

occurrenceA, occurrenceB, relationOccurrence, contextualizationOccurrence ::
     OccurrenceIdentity
occurrenceA = occurrenceId "carrier-a"

occurrenceB = occurrenceId "carrier-b"

relationOccurrence = occurrenceId "relation-r"

contextualizationOccurrence = occurrenceId "contextualization-x"

unknownOccurrence :: OccurrenceIdentity
unknownOccurrence = occurrenceId "unknown"

endpointA, endpointB :: CoreQualifiedEndpointId
endpointA = endpointByText "context.strategy"

endpointB = endpointByText "primitive.strategy.action"

relationTokenValue :: CoreRelationToken
relationTokenValue = relationTokenByText "contributes-to"

endpointByText :: Text -> CoreQualifiedEndpointId
endpointByText expected =
  findExact coreQualifiedEndpointIdText expected coreQualifiedEndpointIds

relationTokenByText :: Text -> CoreRelationToken
relationTokenByText expected =
  findExact coreRelationTokenText expected coreRelationTokens

findExact :: (value -> Text) -> Text -> NonEmpty value -> value
findExact project expected values =
  case filter ((== expected) . project) (NonEmpty.toList values) of
    value:[] -> value
    _ -> error ("missing exact contract value: " ++ show expected)

occurrenceId :: Text -> OccurrenceIdentity
occurrenceId = expectRight . occurrenceIdentity

modelId :: Text -> ModelIdentity
modelId = expectRight . modelIdentity

expectRight :: Show defect => Either defect value -> value
expectRight outcome =
  case outcome of
    Right value -> value
    Left defect -> error (show defect)
