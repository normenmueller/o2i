{-# LANGUAGE OverloadedStrings #-}

-- | Purpose-built collective-claim scenarios for contract tests.
module O2I.Adapter.AMX.Test.Collective.Scenario where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Test.Collective.Fixture
import O2I.Adapter.AMX.Test.Support

expectedClaim :: Commitment -> Claim RawCollectiveStrategyRealization
expectedClaim commitment =
  claimWithCommitment
    commitment
    RawCollectiveStrategyRealization
      { rawRealizationId = ClaimId "claim"
      , rawContributors = [RawNodeId "contributor-a", RawNodeId "contributor-b"]
      , rawTarget = RawNodeId "target"
      , rawCollectiveFitEvidence = CollectiveFitEvidenceRef "fit-claim"
      }

assertedModel, candidateModel :: Text
assertedModel =
  collectiveModel
    "AndJunction"
    "asserted"
    standardParticipants
    standardSegments
    [partialView, fullView, repeatedView, claimOnlyView]

candidateModel =
  collectiveModel
    "AndJunction"
    "candidate"
    standardParticipants
    standardSegments
    [partialView]

missingClaimKindModel, missingClaimTypeModel, missingCommitmentModel :: Text
missingClaimKindModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.commitment" "asserted"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

missingClaimTypeModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.commitment" "asserted"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

missingCommitmentModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

invalidClaimKindModel, invalidClaimTypeModel :: Text
invalidClaimKindModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Primitive"
       , property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.commitment" "asserted"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

invalidClaimTypeModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.type" "Collective"
       , property "o2i.commitment" "asserted"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

duplicateClaimKindModel, duplicateClaimTypeModel :: Text
duplicateClaimKindModel =
  scopedCollectiveWithMetadata
    (collectiveClaimMetadata <> property "o2i.kind" "Claim")

duplicateClaimTypeModel =
  scopedCollectiveWithMetadata
    (collectiveClaimMetadata
       <> property "o2i.type" "CollectiveStrategyRealization")

unsupportedClaimMetadataModel :: Text
unsupportedClaimMetadataModel =
  scopedCollectiveWithMetadata
    (collectiveClaimMetadata <> property "o2i.role" "contributor")

invalidCommitmentModel, duplicateCommitmentModel, missingFitReferenceModel ::
     Text
invalidCommitmentModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.commitment" "tentative"
       , property "o2i.collective-fit-evidence" "fit-claim"
       ])

duplicateCommitmentModel =
  scopedCollectiveWithMetadata
    (collectiveMetadata "candidate" <> property "o2i.commitment" "asserted")

missingFitReferenceModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.commitment" "asserted"
       ])

emptyFitReferenceModel, duplicateFitReferenceModel :: Text
emptyFitReferenceModel =
  scopedCollectiveWithMetadata
    (Text.concat
       [ property "o2i.kind" "Claim"
       , property "o2i.type" "CollectiveStrategyRealization"
       , property "o2i.commitment" "asserted"
       , property "o2i.collective-fit-evidence" " "
       ])

duplicateFitReferenceModel =
  scopedCollectiveWithMetadata
    (collectiveClaimMetadata
       <> property "o2i.collective-fit-evidence" "fit-other")

blankClaimIdModel :: Text
blankClaimIdModel =
  model
    (Text.concat standardParticipants
       <> junctionElement "" "AndJunction" collectiveClaimMetadata
       <> Text.concat
            (map
               segmentElement
               [ Segment
                   "incoming-a"
                   "RealizationRelationship"
                   "realizes"
                   "contributor-a"
                   ""
               , Segment
                   "incoming-b"
                   "RealizationRelationship"
                   "realizes"
                   "contributor-b"
                   ""
               , Segment
                   "outgoing"
                   "RealizationRelationship"
                   "realizes"
                   ""
                   "target"
               ])
       <> view "scope" "Scope" (diagramObject "claim-object" ""))
    [profileProperty]

duplicateClaimIdModel :: Text
duplicateClaimIdModel =
  model
    (junctionElement "claim" "AndJunction" collectiveClaimMetadata
       <> junctionElement "claim" "AndJunction" collectiveClaimMetadata
       <> scopeView)
    [profileProperty]

orJunctionModel, mixedSegmentModel, wrongSegmentNameModel :: Text
orJunctionModel =
  scopedCollective "OrJunction" "asserted" standardParticipants standardSegments

mixedSegmentModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [ Segment
        "incoming-a"
        "InfluenceRelationship"
        "realizes"
        "contributor-a"
        "claim"
    , incomingB
    , outgoing
    ]

wrongSegmentNameModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [ Segment
        "incoming-a"
        "RealizationRelationship"
        "jointly-realizes"
        "contributor-a"
        "claim"
    , incomingB
    , outgoing
    ]

segmentMetadataModel :: Text
segmentMetadataModel =
  model
    (Text.concat standardParticipants
       <> junctionElement "claim" "AndJunction" collectiveClaimMetadata
       <> segmentElementWithMetadata
            incomingA
            (property "o2i.role" "contributor")
       <> segmentElement incomingB
       <> segmentElement outgoing
       <> scopeView)
    [profileProperty]

junctionChainModel, duplicateContributorModel, selfParticipationModel :: Text
junctionChainModel =
  collectiveModel
    "AndJunction"
    "asserted"
    (standardParticipants <> [junctionElement "junction-2" "AndJunction" ""])
    [ incomingA
    , incomingB
    , Segment
        "outgoing"
        "RealizationRelationship"
        "realizes"
        "claim"
        "junction-2"
    ]
    [scopeView]

duplicateContributorModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [ incomingA
    , Segment
        "incoming-a-again"
        "RealizationRelationship"
        "realizes"
        "contributor-a"
        "claim"
    , incomingB
    , outgoing
    ]

selfParticipationModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [ incomingA
    , incomingB
    , Segment
        "outgoing"
        "RealizationRelationship"
        "realizes"
        "claim"
        "contributor-a"
    ]

zeroTargetModel, multipleTargetModel, singletonContributorModel :: Text
zeroTargetModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [incomingA, incomingB]

multipleTargetModel =
  scopedCollective
    "AndJunction"
    "asserted"
    (standardParticipants <> [strategyElement "target-2"])
    (standardSegments
       <> [ Segment
              "outgoing-2"
              "RealizationRelationship"
              "realizes"
              "claim"
              "target-2"
          ])

singletonContributorModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [incomingA, outgoing]

unknownParticipantModel, nonStrategyParticipantModel :: Text
unknownParticipantModel =
  scopedCollective
    "AndJunction"
    "asserted"
    standardParticipants
    [ Segment
        "incoming-missing"
        "RealizationRelationship"
        "realizes"
        "missing"
        "claim"
    , incomingB
    , outgoing
    ]

nonStrategyParticipantModel =
  scopedCollective
    "AndJunction"
    "asserted"
    (standardParticipants <> [missionElement "mission"])
    [ Segment
        "incoming-mission"
        "RealizationRelationship"
        "realizes"
        "mission"
        "claim"
    , incomingB
    , outgoing
    ]

ambiguousParticipantModel :: Text
ambiguousParticipantModel =
  scopedCollective
    "AndJunction"
    "asserted"
    (standardParticipants <> [strategyElement "contributor-a"])
    standardSegments

incompleteCandidateModel :: Text
incompleteCandidateModel =
  collectiveModel
    "AndJunction"
    "candidate"
    standardParticipants
    [incomingA, incomingB]
    [completeLookingView]

directBinaryRealizesModel :: Text
directBinaryRealizesModel =
  model
    (strategyElement "source"
       <> strategyElement "target"
       <> relationship
            "direct-realization"
            "RealizationRelationship"
            "realizes"
            "source"
            "target"
            False
       <> connectedView "direct-realization" "source" "target")
    [profileProperty]

outsideScopeModel :: Text
outsideScopeModel =
  model
    (grouping "ethos" "Ethos" (Text.concat (metadata "Context" "Ethos"))
       <> principle "principle" principleMetadata
       <> contextualization "ownership" "ethos" "principle"
       <> Text.concat standardParticipants
       <> junctionElement "claim" "OrJunction" collectiveClaimMetadata
       <> Text.concat (map segmentElement standardSegments)
       <> view
            "scope"
            "Scope"
            (diagramObject "ethos-object" "ethos"
               <> diagramObject "principle-object" "principle")
       <> view "other" "Other" (diagramObject "claim-object" "claim"))
    [profileProperty]

participantOnlyScopeModel :: Text
participantOnlyScopeModel =
  collectiveModel
    "OrJunction"
    "asserted"
    standardParticipants
    standardSegments
    [ view
        "participant-only"
        "Participant only"
        (diagramObject "contributor-a-object" "contributor-a")
    ]
