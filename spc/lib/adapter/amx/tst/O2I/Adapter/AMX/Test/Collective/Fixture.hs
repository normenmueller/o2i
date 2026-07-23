{-# LANGUAGE OverloadedStrings #-}

-- | Reusable native AMX builders for collective Strategy realization.
module O2I.Adapter.AMX.Test.Collective.Fixture where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Test.Support

data Segment =
  Segment Text Text Text Text Text

scopedCollective :: Text -> Text -> [Text] -> [Segment] -> Text
scopedCollective junctionType commitment participants segments =
  collectiveModel junctionType commitment participants segments [scopeView]

scopedCollectiveWithMetadata :: Text -> Text
scopedCollectiveWithMetadata claimMetadata =
  collectiveModelWithMetadata
    "AndJunction"
    claimMetadata
    standardParticipants
    standardSegments
    [scopeView]

collectiveModel :: Text -> Text -> [Text] -> [Segment] -> [Text] -> Text
collectiveModel junctionType commitment participants segments views =
  collectiveModelWithMetadata
    junctionType
    (collectiveMetadata commitment)
    participants
    segments
    views

collectiveModelWithMetadata ::
     Text -> Text -> [Text] -> [Segment] -> [Text] -> Text
collectiveModelWithMetadata junctionType claimMetadata participants segments views =
  model
    (Text.concat participants
       <> junctionElement "claim" junctionType claimMetadata
       <> Text.concat (map segmentElement segments)
       <> Text.concat views)
    [profileProperty]

standardParticipants :: [Text]
standardParticipants =
  map strategyElement ["contributor-a", "contributor-b", "target"]

standardSegments :: [Segment]
standardSegments = [incomingA, incomingB, outgoing]

incomingA, incomingB, outgoing :: Segment
incomingA =
  Segment
    "incoming-a"
    "RealizationRelationship"
    "realizes"
    "contributor-a"
    "claim"

incomingB =
  Segment
    "incoming-b"
    "RealizationRelationship"
    "realizes"
    "contributor-b"
    "claim"

outgoing =
  Segment "outgoing" "RealizationRelationship" "realizes" "claim" "target"

segmentElement :: Segment -> Text
segmentElement (Segment identifier segmentType name sourceId targetId) =
  relationship identifier segmentType name sourceId targetId False

segmentElementWithMetadata :: Segment -> Text -> Text
segmentElementWithMetadata (Segment identifier segmentType name sourceId targetId) segmentMetadata =
  "<element xsi:type=\"a:"
    <> segmentType
    <> "\" id=\""
    <> identifier
    <> "\" name=\""
    <> name
    <> "\" source=\""
    <> sourceId
    <> "\" target=\""
    <> targetId
    <> "\">"
    <> segmentMetadata
    <> "</element>"

strategyElement :: Text -> Text
strategyElement identifier =
  grouping identifier identifier (Text.concat (metadata "Context" "Strategy"))

missionElement :: Text -> Text
missionElement identifier =
  grouping identifier identifier (Text.concat (metadata "Context" "Mission"))

junctionElement :: Text -> Text -> Text -> Text
junctionElement identifier junctionType properties =
  "<element xsi:type=\"a:Junction\" id=\""
    <> identifier
    <> "\" name=\""
    <> identifier
    <> "\""
    <> (if junctionType == "OrJunction"
          then " type=\"or\">"
          else ">")
    <> properties
    <> "</element>"

collectiveMetadata :: Text -> Text
collectiveMetadata commitment =
  Text.concat
    [ property "o2i.kind" "Claim"
    , property "o2i.type" "CollectiveStrategyRealization"
    , property "o2i.commitment" commitment
    , property "o2i.collective-fit-evidence" "fit-claim"
    ]

collectiveClaimMetadata :: Text
collectiveClaimMetadata = collectiveMetadata "asserted"

partialView, fullView, repeatedView, claimOnlyView, scopeView, completeLookingView ::
     Text
partialView =
  view
    "partial"
    "Partial"
    (objectWithConnections
       "contributor-a-object"
       "contributor-a"
       [ connection
           "incoming-a-connection"
           "incoming-a"
           "contributor-a-object"
           "claim-object"
       ]
       <> objectWithConnections
            "claim-object"
            "claim"
            [ connection
                "outgoing-connection"
                "outgoing"
                "claim-object"
                "target-object"
            ]
       <> diagramObject "target-object" "target"
       <> note "omission-note" "*")

fullView =
  view
    "full"
    "Full"
    (objectWithConnections
       "full-contributor-a-object"
       "contributor-a"
       [ connection
           "full-incoming-a-connection"
           "incoming-a"
           "full-contributor-a-object"
           "full-claim-object"
       ]
       <> objectWithConnections
            "full-contributor-b-object"
            "contributor-b"
            [ connection
                "full-incoming-b-connection"
                "incoming-b"
                "full-contributor-b-object"
                "full-claim-object"
            ]
       <> objectWithConnections
            "full-claim-object"
            "claim"
            [ connection
                "full-outgoing-connection"
                "outgoing"
                "full-claim-object"
                "full-target-object"
            ]
       <> diagramObject "full-target-object" "target")

repeatedView =
  view
    "repeated"
    "Repeated"
    (objectWithConnections
       "repeated-contributor-object"
       "contributor-a"
       [ connection
           "repeated-incoming-a-1"
           "incoming-a"
           "repeated-contributor-object"
           "repeated-claim-object"
       , connection
           "repeated-incoming-a-2"
           "incoming-a"
           "repeated-contributor-object"
           "repeated-claim-object"
       ]
       <> diagramObject "repeated-claim-object" "claim")

claimOnlyView =
  view "claim-only" "Claim only" (diagramObject "claim-only-object" "claim")

scopeView =
  view "collective-scope" "Scope" (diagramObject "claim-object" "claim")

completeLookingView =
  view
    "complete-looking"
    "Scope"
    (diagramObject "contributor-a-object" "contributor-a"
       <> diagramObject "contributor-b-object" "contributor-b"
       <> diagramObject "claim-object" "claim"
       <> diagramObject "target-object" "target"
       <> note "completion-note" "* all contributors shown")

objectWithConnections :: Text -> Text -> [Text] -> Text
objectWithConnections identifier target connections =
  "<child xsi:type=\"a:DiagramObject\" id=\""
    <> identifier
    <> "\" archimateElement=\""
    <> target
    <> "\">"
    <> Text.concat connections
    <> "</child>"

connection :: Text -> Text -> Text -> Text -> Text
connection identifier relationId sourceId targetId =
  "<sourceConnection xsi:type=\"a:Connection\" id=\""
    <> identifier
    <> "\" archimateRelationship=\""
    <> relationId
    <> "\" source=\""
    <> sourceId
    <> "\" target=\""
    <> targetId
    <> "\"/>"

note :: Text -> Text -> Text
note identifier content =
  "<child xsi:type=\"a:Note\" id=\""
    <> identifier
    <> "\" content=\""
    <> content
    <> "\"/>"
