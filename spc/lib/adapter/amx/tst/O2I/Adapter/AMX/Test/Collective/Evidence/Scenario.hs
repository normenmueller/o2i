{-# LANGUAGE OverloadedStrings #-}

-- | Purpose-built AMX models for collective evidence-closure tests.
module O2I.Adapter.AMX.Test.Collective.Evidence.Scenario where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Adapter.AMX.Test.Collective.Fixture
import O2I.Adapter.AMX.Test.Support
import O2I.Inspection

collectiveInputs :: InspectionInputs
collectiveInputs =
  noInputs
    { strategyInput =
        Supplied
          (sourcedFromDocument
             (source "strategy formulations")
             (StrategyFormulationBundle
                (map assertedClaim evidenceStrategyFormulations)))
    , collectiveFitInput =
        Supplied
          (sourcedFromDocument
             (source "collective Fit evidence")
             (CollectiveFitEvidenceBundle [collectiveFitEvidence]))
    }

evidenceStrategyFormulations :: [RawStrategyFormulation]
evidenceStrategyFormulations =
  [ strategyFormulation "a" "contributor-a"
  , strategyFormulation "b" "contributor-b"
  , strategyFormulation "target" "target"
  ]

strategyFormulation :: Text -> Text -> RawStrategyFormulation
strategyFormulation prefix strategy =
  RawStrategyFormulation
    { rawFormulationStrategy = rawId strategy
    , rawFormulationScope = "enterprise" :| []
    , rawFormulationAnchoring =
        StrategyAnchoring
          { anchoringPeriod = "2026"
          , anchoringResponsibilityScope = "enterprise"
          , anchoringDecisionLevel = "executive"
          , anchoringResponsibilities = "strategy owner" :| []
          , anchoringDecisionPaths = "governance" :| []
          , anchoringImplementationLogic = "coherent commitments"
          }
    , rawFormulationGuardrails = "evidence before assumption" :| []
    , rawFormulationDiagnosis = primitiveId prefix "driver"
    , rawFormulationIntent = primitiveId prefix "objective"
    , rawFormulationGuidingPolicy = primitiveId prefix "principle"
    , rawFormulationPositioning = "distinct contribution" :| []
    , rawFormulationTradeOffs = strategyTradeOffs prefix
    , rawFormulationActions = primitiveId prefix "action" :| []
    , rawFormulationKeyResults = primitiveId prefix "key-result" :| []
    , rawFormulationFitRationale = "coherent strategic formulation" :| []
    }

strategyTradeOffs :: Text -> NonEmpty Text
strategyTradeOffs prefix =
  if prefix == "target"
    then "target trade-off" :| []
    else "contributor trade-off" :| []

collectiveFitEvidence :: RawCollectiveFitEvidence
collectiveFitEvidence =
  RawCollectiveFitEvidence
    { rawFitEvidenceRef = CollectiveFitEvidenceRef "fit-claim"
    , rawFitContributors = map rawId ["contributor-a", "contributor-b"]
    , rawFitTarget = rawId "target"
    , rawMutualCoherenceEvidence =
        [ RawMutualCoherenceEvidence
            (rawId "contributor-a")
            (rawId "contributor-b")
            "The contributor commitments are mutually coherent."
        ]
    , rawFitTargetGuidingPolicy = primitiveId "target" "principle"
    , rawFitTargetTradeOffs = ["target trade-off"]
    , rawContributorCompatibilityEvidence =
        map compatibility ["contributor-a", "contributor-b"]
    , rawViableInteractionEvidence =
        ["The contributor actions interact viably."]
    }
  where
    compatibility contributor =
      RawContributorCompatibilityEvidence
        (rawId contributor)
        "Compatible with the target Guiding Policy."
        "Compatible with the target Trade-offs."

completeCollectiveModel, missingCollectiveModel, isolatedCollectiveModel :: Text
completeCollectiveModel = collectiveEvidenceModel True False

missingCollectiveModel = collectiveEvidenceModel False False

isolatedCollectiveModel = collectiveEvidenceModel True True

collectiveEvidenceModel :: Bool -> Bool -> Text
collectiveEvidenceModel includeSecondMacro includeIsolation =
  model
    (orientationElements
       <> Text.concat
            [ strategyElements "a" "contributor-a"
            , strategyElements "b" "contributor-b"
            , strategyElements "target" "target"
            ]
       <> Text.concat (map relationElement baselineRelations)
       <> Text.concat
            (map
               relationElement
               (filter
                  ((/= "macro-b") . relationIdentifier)
                  hiddenContributionRelations))
       <> (if includeSecondMacro
             then relationElement macroB
             else "")
       <> junctionElement "claim" "AndJunction" collectiveClaimMetadata
       <> Text.concat (map segmentElement standardSegments)
       <> (if includeIsolation
             then isolationElements
             else "")
       <> collectiveView)
    [profileProperty]

orientationElements :: Text
orientationElements =
  grouping "ethos" "Ethos" (Text.concat (metadata "Context" "Ethos"))
    <> principle "ethos-principle" (primitiveProperties "Principle")
    <> contextualization "ethos-principle-owner" "ethos" "ethos-principle"
    <> grouping "mission" "Mission" (Text.concat (metadata "Context" "Mission"))
    <> driver "mission-driver" (primitiveProperties "Driver")
    <> contextualization "mission-driver-owner" "mission" "mission-driver"
    <> grouping "vision" "Vision" (Text.concat (metadata "Context" "Vision"))
    <> element
         "Goal"
         "vision-objective"
         "Vision Objective"
         (primitiveProperties "Objective")
    <> contextualization "vision-objective-owner" "vision" "vision-objective"

strategyElements :: Text -> Text -> Text
strategyElements prefix strategy =
  grouping strategy strategy (Text.concat (metadata "Context" "Strategy"))
    <> driver
         (textId (primitiveId prefix "driver"))
         (primitiveProperties "Driver")
    <> element
         "Goal"
         (textId (primitiveId prefix "objective"))
         "Objective"
         (primitiveProperties "Objective")
    <> principle
         (textId (primitiveId prefix "principle"))
         (primitiveProperties "Principle")
    <> outcome
         (textId (primitiveId prefix "key-result"))
         (primitiveProperties "KeyResult")
    <> element
         "CourseOfAction"
         (textId (primitiveId prefix "action"))
         "Action"
         (primitiveProperties "Action")
    <> Text.concat
         [ contextualization
           (prefix <> "-owner-" <> suffix)
           strategy
           (textId (primitiveId prefix suffix))
         | suffix <-
             ["driver", "objective", "principle", "key-result", "action"]
         ]

primitiveProperties :: Text -> Text
primitiveProperties = Text.concat . metadata "Primitive"

data RelationFixture = RelationFixture
  { relationIdentifier :: Text
  , relationRepresentation :: Text
  , relationLabel :: Text
  , relationSource :: Text
  , relationTarget :: Text
  , relationDirected :: Bool
  }

baselineRelations :: [RelationFixture]
baselineRelations =
  orientationRelations
    ++ concatMap
         strategyRelations
         [("a", "contributor-a"), ("b", "contributor-b"), ("target", "target")]

orientationRelations :: [RelationFixture]
orientationRelations =
  [ relation
      "ethos-mission"
      "InfluenceRelationship"
      "guides"
      "ethos-principle"
      "mission-driver"
  , relation
      "mission-vision"
      "InfluenceRelationship"
      "grounds"
      "mission-driver"
      "vision-objective"
  , relation
      "ethos-vision"
      "InfluenceRelationship"
      "guides"
      "ethos-principle"
      "vision-objective"
  ]

strategyRelations :: (Text, Text) -> [RelationFixture]
strategyRelations (prefix, _strategy) =
  [ relation
      (prefix <> "-orientation")
      "InfluenceRelationship"
      "orients"
      "vision-objective"
      (textId (primitiveId prefix "objective"))
  , relation
      (prefix <> "-grounds")
      "InfluenceRelationship"
      "grounds"
      (textId (primitiveId prefix "driver"))
      (textId (primitiveId prefix "objective"))
  , relation
      (prefix <> "-substantiates")
      "RealizationRelationship"
      "substantiates"
      (textId (primitiveId prefix "key-result"))
      (textId (primitiveId prefix "objective"))
  , directedRelation
      (prefix <> "-guides")
      "AssociationRelationship"
      "guides"
      (textId (primitiveId prefix "principle"))
      (textId (primitiveId prefix "action"))
  , relation
      (prefix <> "-action-result")
      "RealizationRelationship"
      "contributes-to"
      (textId (primitiveId prefix "action"))
      (textId (primitiveId prefix "key-result"))
  ]

hiddenContributionRelations :: [RelationFixture]
hiddenContributionRelations = [macroA, macroB, premiseA, premiseB]

macroA, macroB, premiseA, premiseB :: RelationFixture
macroA =
  relation
    "macro-a"
    "InfluenceRelationship"
    "contributes-to"
    "contributor-a"
    "target"

macroB =
  relation
    "macro-b"
    "InfluenceRelationship"
    "contributes-to"
    "contributor-b"
    "target"

premiseA =
  relation
    "premise-a"
    "InfluenceRelationship"
    "contributes-to"
    (textId (primitiveId "a" "key-result"))
    (textId (primitiveId "target" "key-result"))

premiseB =
  directedRelation
    "premise-b"
    "AssociationRelationship"
    "contributes-to"
    (textId (primitiveId "b" "action"))
    (textId (primitiveId "target" "action"))

relation :: Text -> Text -> Text -> Text -> Text -> RelationFixture
relation identifier representation label sourceId targetId =
  RelationFixture identifier representation label sourceId targetId False

directedRelation :: Text -> Text -> Text -> Text -> Text -> RelationFixture
directedRelation identifier representation label sourceId targetId =
  RelationFixture identifier representation label sourceId targetId True

relationElement :: RelationFixture -> Text
relationElement relationFixture =
  relationship
    (relationIdentifier relationFixture)
    (relationRepresentation relationFixture)
    (relationLabel relationFixture)
    (relationSource relationFixture)
    (relationTarget relationFixture)
    (relationDirected relationFixture)

collectiveView :: Text
collectiveView =
  view
    "collective-view"
    collectiveViewName
    (Text.concat
       [ objectWithRelations identifier
       | identifier <- baselineNodeIds ++ ["claim"]
       ])
  where
    shownRelations = baselineRelations ++ map segmentRelation standardSegments
    objectWithRelations identifier =
      objectWithConnections
        (objectId identifier)
        identifier
        [ connection
          ("view-" <> relationIdentifier relationFixture)
          (relationIdentifier relationFixture)
          (objectId (relationSource relationFixture))
          (objectId (relationTarget relationFixture))
        | relationFixture <- shownRelations
        , relationSource relationFixture == identifier
        ]

segmentRelation :: Segment -> RelationFixture
segmentRelation (Segment identifier _ label sourceId targetId) =
  relation identifier "RealizationRelationship" label sourceId targetId

baselineNodeIds :: [Text]
baselineNodeIds =
  [ "ethos"
  , "ethos-principle"
  , "mission"
  , "mission-driver"
  , "vision"
  , "vision-objective"
  ]
    ++ concatMap
         (\(prefix, strategy) ->
            strategy
              : map
                  (textId . primitiveId prefix)
                  ["driver", "objective", "principle", "key-result", "action"])
         [("a", "contributor-a"), ("b", "contributor-b"), ("target", "target")]

isolationElements :: Text
isolationElements =
  grouping "unrelated" "Unrelated" (Text.concat (metadata "Context" "Strategy"))
    <> outcome "unrelated-key-result" (primitiveProperties "KeyResult")
    <> contextualization "unrelated-owner" "unrelated" "unrelated-key-result"
    <> relationElement
         (relation
            "unrelated-macro"
            "InfluenceRelationship"
            "contributes-to"
            "unrelated"
            "target")
    <> relationElement
         (relation
            "unrelated-premise"
            "InfluenceRelationship"
            "contributes-to"
            "unrelated-key-result"
            (textId (primitiveId "target" "key-result")))
    <> junctionElement
         "unselected-claim"
         "AndJunction"
         (Text.concat
            [ property "o2i.kind" "StructuredProposition"
            , property "o2i.type" "CollectiveStrategyRealization"
            , property "o2i.commitment" "asserted"
            , property "o2i.collective-fit-evidence" "unselected-fit"
            ])
    <> Text.concat
         (map
            segmentElement
            [ Segment
                "unselected-incoming-a"
                "RealizationRelationship"
                "realizes"
                "contributor-a"
                "unselected-claim"
            , Segment
                "unselected-incoming-b"
                "RealizationRelationship"
                "realizes"
                "contributor-b"
                "unselected-claim"
            , Segment
                "unselected-outgoing"
                "RealizationRelationship"
                "realizes"
                "unselected-claim"
                "target"
            ])

collectiveViewName :: Text
collectiveViewName = "Collective scope"

primitiveId :: Text -> Text -> RawNodeId
primitiveId prefix suffix = rawId (prefix <> "-" <> suffix)

rawId :: Text -> RawNodeId
rawId = RawNodeId

textId :: RawNodeId -> Text
textId (RawNodeId identifier) = identifier

objectId :: Text -> Text
objectId identifier = identifier <> "-object"
