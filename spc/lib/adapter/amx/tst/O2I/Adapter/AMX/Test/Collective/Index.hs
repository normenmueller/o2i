{-# LANGUAGE OverloadedStrings #-}

-- | Structural contracts for the projection-local collective index.
module O2I.Adapter.AMX.Test.Collective.Index
  ( collectiveIndexTests
  ) where

import Control.Monad (forM_)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Internal.Profile.Collective
import O2I.Adapter.AMX.Internal.Profile.Collective.Index
import O2I.Adapter.AMX.Internal.Profile.Collective.Syntax
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.View
import O2I.Adapter.AMX.Internal.XML
import O2I.Adapter.AMX.Test.Collective.Fixture
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

collectiveIndexTests :: TestTree
collectiveIndexTests =
  testGroup
    "collective index"
    [ testCase
        "multiple claims and repeated presentations preserve one projection"
        projectionEquivalenceTest
    , testCase
        "shared participants retain stable relationship adjacency"
        sharedParticipantAdjacencyTest
    , testCase
        "large synthetic input retains linear index cardinalities"
        largeIndexCardinalityTest
    ]

projectionEquivalenceTest :: Assertion
projectionEquivalenceTest = do
  single <- indexFor "Single" (collectiveIndexModel 3)
  repeated <- indexFor "Repeated" (collectiveIndexModel 3)
  claimIds (collectiveRawClaims single) @?= expectedClaimIds 3
  collectiveRawClaims repeated @?= collectiveRawClaims single
  collectiveSegmentOccurrences repeated @?= collectiveSegmentOccurrences single
  length (collectiveObservations repeated)
    @?= length (collectiveObservations single)

sharedParticipantAdjacencyTest :: Assertion
sharedParticipantAdjacencyTest = do
  index <- indexFor "Single" (collectiveIndexModel 3)
  map elementName (relationshipsAtEndpoint index (Just "contributor-a"))
    @?= replicate 3 "realizes"
  map displayId (relationshipsAtEndpoint index (Just "contributor-a"))
    @?= map incomingAId [0 .. 2]
  forM_ [0 .. 2] $ \number -> do
    length (collectiveObservationsById index (claimId number)) @?= 1
    case collectiveObservationsById index (claimId number) of
      [observation] ->
        fmap
          (displayId . observedJunction)
          (collectiveObservationByOccurrence
             index
             (nodeOccurrence (observedJunction observation)))
          @?= Just (claimId number)
      _ -> assertFailure "expected exactly one indexed observation"

largeIndexCardinalityTest :: Assertion
largeIndexCardinalityTest = do
  let claimCount = 96
      expectedSegments = claimCount * 3
      endpointIds =
        ["contributor-a", "contributor-b"]
          ++ map claimId [0 .. claimCount - 1]
          ++ map targetId [0 .. claimCount - 1]
  index <- indexFor "Single" (collectiveIndexModel claimCount)
  length (collectiveObservations index) @?= claimCount
  length (collectiveRawClaims index) @?= claimCount
  Set.size (collectiveSegmentOccurrences index) @?= expectedSegments
  sum
    [ length (relationshipsAtEndpoint index (Just identifier))
    | identifier <- endpointIds
    ]
    @?= expectedSegments
    * 2
  map displayId (relationshipsAtEndpoint index (Just "contributor-a"))
    @?= map incomingAId [0 .. claimCount - 1]

indexFor :: Text -> Text -> IO CollectiveIndex
indexFor viewName input =
  case decodeAMX (source input) of
    DecodePassed _ document ->
      case resolveAMXView document (ViewByName viewName) of
        ViewPassed _ selected ->
          pure (buildCollectiveIndex (buildEnvironment document selected))
        ViewFailed _ defects ->
          assertFailure ("unexpected View defects: " <> show defects)
    DecodeUnavailable _ defects ->
      assertFailure ("unexpected Decode defects: " <> show defects)
    DecodeRejected _ defects ->
      assertFailure ("unexpected Decode rejection: " <> show defects)

collectiveIndexModel :: Int -> Text
collectiveIndexModel count =
  model
    (Text.concat
       [ strategyElement "contributor-a"
       , strategyElement "contributor-b"
       , Text.concat (map (strategyElement . targetId) numbers)
       , Text.concat (map claimBundle numbers)
       , singleView
       , repeatedView'
       ])
    [profileProperty]
  where
    numbers = [0 .. count - 1]

claimBundle :: Int -> Text
claimBundle number =
  junctionElement identifier "AndJunction" metadata'
    <> Text.concat (map segmentElement segments)
  where
    identifier = claimId number
    metadata' =
      Text.concat
        [ property "o2i.kind" "StructuredProposition"
        , property "o2i.type" "CollectiveStrategyRealization"
        , property "o2i.commitment" "asserted"
        , property
            "o2i.collective-fit-evidence"
            ("fit-" <> Text.pack (show number))
        ]
    segments =
      [ Segment
          (incomingAId number)
          "RealizationRelationship"
          "realizes"
          "contributor-a"
          identifier
      , Segment
          (incomingBId number)
          "RealizationRelationship"
          "realizes"
          "contributor-b"
          identifier
      , Segment
          (outgoingId number)
          "RealizationRelationship"
          "realizes"
          identifier
          (targetId number)
      ]

singleView :: Text
singleView =
  view "single" "Single" (diagramObject "single-claim-object" (claimId 0))

repeatedView' :: Text
repeatedView' =
  view
    "repeated-index"
    "Repeated"
    (diagramObject "repeated-claim-object-a" (claimId 0)
       <> diagramObject "repeated-claim-object-b" (claimId 0))

claimIds :: [Claim RawCollectiveStrategyRealization] -> [Text]
claimIds = map (claimIdText . rawRealizationId . claimedProposition)

expectedClaimIds :: Int -> [Text]
expectedClaimIds count = map claimId [0 .. count - 1]

claimId, targetId, incomingAId, incomingBId, outgoingId :: Int -> Text
claimId = prefixedId "claim"

targetId = prefixedId "target"

incomingAId = prefixedId "incoming-a"

incomingBId = prefixedId "incoming-b"

outgoingId = prefixedId "outgoing"

prefixedId :: Text -> Int -> Text
prefixedId prefix number = prefix <> "-" <> Text.pack (show number)
