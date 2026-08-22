{-# LANGUAGE OverloadedStrings #-}

-- | Public Core inputs for the build-only Semantics owner corpus.
module O2I.Core.Conformance.SemanticsSource
  ( SemanticSource
  , semanticSourceOccurrences
  , semanticSourceProjection
  , semanticSourceInputs
  , semanticSources
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment(..))
import O2I.Core.Identity
import O2I.Structure

data SemanticSource = SemanticSource
  { semanticSourceOccurrences :: ![ModelOccurrence]
  , semanticSourceProjection :: !StructureProjection
  , semanticSourceInputs :: ![(Natural, ByteString)]
  }

-- | Independent public-input scenarios whose real Semantics outputs jointly
-- cover the closed owner catalog.  No expected rule or evidence map lives
-- here.
semanticSources :: [SemanticSource]
semanticSources =
  [ SemanticSource
      contextualizationDependencyModels
      contextualizationDependencyProjection
      []
  , SemanticSource
      (carrierModels ["need"])
      (structureProjection [contextCarrier "need" "Need" Asserted] [] [] [] [])
      []
  , SemanticSource needModelOccurrences needProjectionWithCandidateAnchor []
  , SemanticSource needModelOccurrences needProjectionWithoutGrounding []
  , SemanticSource
      strategyMismatchModelOccurrences
      strategyMismatchProjection
      [(0, strategyMismatchInput)]
  , SemanticSource
      (strategyModelOccurrences "a")
      (strategyProjectionMissingRelation "a" 0)
      [(0, strategyInput "a")]
  , SemanticSource
      (strategyModelOccurrences "a")
      (strategyProjectionMissingRelation "a" 1)
      [(0, strategyInput "a")]
  , SemanticSource
      (strategyModelOccurrences "a")
      (strategyProjectionMissingRelation "a" 2)
      [(0, strategyInput "a")]
  , SemanticSource
      (strategyModelOccurrences "a")
      (strategyProjectionMissingRelation "a" 3)
      [(0, strategyInput "a")]
  , SemanticSource
      (strategyModelOccurrences "a")
      (strategyProjectionWithoutVisionOrientation "a")
      [(0, strategyInput "a")]
  , SemanticSource
      completeModelOccurrences
      (completeProjection True)
      (strategyInputs <> [(3, collectiveInputAllFitDefects)])
  , SemanticSource
      completeModelOccurrences
      completeProjectionOpen
      completeInputs
  , SemanticSource
      completeModelOccurrences
      completeProjectionWithoutPrimitives
      completeInputs
  , SemanticSource
      completeModelOccurrences
      (completeProjection False)
      completeInputs
  ]

contextualizationDependencyProjection :: StructureProjection
contextualizationDependencyProjection =
  structureProjection
    [ strategyCarrier "a" Candidate
    , primitiveCarrier "strategy-a-principle" "Principle" Asserted
    , primitiveCarrier "strategy-a-action" "Action" Asserted
    ]
    [ ownership
        "owns-strategy-a-principle"
        "strategy-a"
        "strategy-a-principle"
        Candidate
    , ownership
        "owns-strategy-a-action"
        "strategy-a"
        "strategy-a-action"
        Asserted
    ]
    [ relation
        "relation-principle-guides-action"
        "strategy-a-principle"
        "guides"
        "strategy-a-action"
        Asserted
    ]
    []
    []

contextualizationDependencyModels :: [ModelOccurrence]
contextualizationDependencyModels =
  carrierModels ["strategy-a", "strategy-a-principle", "strategy-a-action"]
    <> segmentModels
         [ "owns-strategy-a-principle"
         , "owns-strategy-a-action"
         , "relation-principle-guides-action"
         ]

needProjectionWithCandidateAnchor :: StructureProjection
needProjectionWithCandidateAnchor =
  structureProjection
    [ contextCarrier "need" "Need" Asserted
    , contextCarrier "situation" "Situation" Asserted
    , anchorCarrier "anchor" "BusinessCapability" Candidate
    , primitiveCarrier "need-driver" "Driver" Asserted
    , primitiveCarrier "need-objective" "Objective" Asserted
    ]
    needContextualizations
    needRelations
    []
    []

needProjectionWithoutGrounding :: StructureProjection
needProjectionWithoutGrounding =
  structureProjection
    needCarriers
    needContextualizations
    (init needRelations)
    []
    []

needCarriers :: [CarrierProjection]
needCarriers =
  [ contextCarrier "need" "Need" Asserted
  , contextCarrier "situation" "Situation" Asserted
  , anchorCarrier "anchor" "BusinessCapability" Asserted
  , primitiveCarrier "need-driver" "Driver" Asserted
  , primitiveCarrier "need-objective" "Objective" Asserted
  ]

needContextualizations :: [ContextualizationProjection]
needContextualizations =
  [ ownership "owns-need-driver" "need" "need-driver" Asserted
  , ownership "owns-need-objective" "need" "need-objective" Asserted
  ]

needRelations :: [RelationProjection]
needRelations =
  [ relation "situation-surfaces-need" "situation" "surfaces" "need" Asserted
  , relation
      "situation-constituted-by-anchor"
      "situation"
      "is-constituted-by"
      "anchor"
      Asserted
  , relation "anchor-anchors-driver" "anchor" "anchors" "need-driver" Asserted
  , relation
      "need-driver-grounds-objective"
      "need-driver"
      "grounds"
      "need-objective"
      Asserted
  ]

needModelOccurrences :: [ModelOccurrence]
needModelOccurrences =
  carrierModels ["need", "situation", "anchor", "need-driver", "need-objective"]
    <> segmentModels
         [ "owns-need-driver"
         , "owns-need-objective"
         , "situation-surfaces-need"
         , "situation-constituted-by-anchor"
         , "anchor-anchors-driver"
         , "need-driver-grounds-objective"
         ]

strategyProjectionWithoutVisionOrientation :: String -> StructureProjection
strategyProjectionWithoutVisionOrientation label =
  structureProjection
    (visionCarriers <> strategyCarriers label)
    (visionContextualizations <> strategyContextualizations label)
    (strategyInternalRelations label)
    []
    []

strategyProjectionMissingRelation :: String -> Int -> StructureProjection
strategyProjectionMissingRelation label omitted =
  structureProjection
    (visionCarriers <> strategyCarriers label)
    (visionContextualizations <> strategyContextualizations label)
    (visionOrientation label
       : [ relationRow
         | (index, relationRow) <-
             zip [0 :: Int ..] (strategyInternalRelations label)
         , index /= omitted
         ])
    []
    []

strategyMismatchProjection :: StructureProjection
strategyMismatchProjection =
  structureProjection
    (visionCarriers <> strategyCarriers "a" <> strategyCarriers "b")
    (visionContextualizations
       <> strategyContextualizations "a"
       <> strategyContextualizations "b")
    (concatMap
       (\label -> visionOrientation label : strategyInternalRelations label)
       ["a", "b"])
    []
    []

strategyMismatchModelOccurrences :: [ModelOccurrence]
strategyMismatchModelOccurrences =
  carrierModels
    (visionCarrierNames <> strategyCarrierNames "a" <> strategyCarrierNames "b")
    <> segmentModels
         (visionContextualizationNames
            <> strategyContextualizationNames "a"
            <> strategyContextualizationNames "b"
            <> concatMap
                 (\label ->
                    visionOrientationName label
                      : strategyInternalRelationNames label)
                 ["a", "b"])

strategyModelOccurrences :: String -> [ModelOccurrence]
strategyModelOccurrences label =
  carrierModels (visionCarrierNames <> strategyCarrierNames label)
    <> segmentModels
         (visionContextualizationNames
            <> strategyContextualizationNames label
            <> (visionOrientationName label
                  : strategyInternalRelationNames label))

completeProjection :: Bool -> StructureProjection
completeProjection includeSecondMacro =
  structureProjection
    completeCarriers
    completeContextualizations
    relations
    [collectiveProposition]
    collectiveIncidences
  where
    relations =
      completeStrategyRelations
        <> [macroRelation "a"]
        <> [macroRelation "b" | includeSecondMacro]
        <> collectivePrimitiveRelations

completeProjectionOpen :: StructureProjection
completeProjectionOpen =
  structureProjection
    completeCarriers
    completeContextualizations
    (completeStrategyRelations
       <> [macroRelation "a", macroRelation "b"]
       <> collectivePrimitiveRelations)
    [ structuredPropositionProjection
        (occurrenceId "collective-claim")
        collectiveFamily
        completenessOpen
        Asserted
    ]
    collectiveIncidences

completeProjectionWithoutPrimitives :: StructureProjection
completeProjectionWithoutPrimitives =
  structureProjection
    completeCarriers
    completeContextualizations
    (completeStrategyRelations <> [macroRelation "a", macroRelation "b"])
    [collectiveProposition]
    collectiveIncidences

completeCarriers :: [CarrierProjection]
completeCarriers =
  visionCarriers <> concatMap strategyCarriers ["a", "b", "target"]

completeContextualizations :: [ContextualizationProjection]
completeContextualizations =
  visionContextualizations
    <> concatMap strategyContextualizations ["a", "b", "target"]

completeStrategyRelations :: [RelationProjection]
completeStrategyRelations =
  concatMap
    (\label -> visionOrientation label : strategyInternalRelations label)
    ["a", "b", "target"]

collectivePrimitiveRelations :: [RelationProjection]
collectivePrimitiveRelations =
  [ relation
      "primitive-a-contributes-target-action"
      "strategy-a-action"
      "contributes-to"
      "strategy-target-action"
      Asserted
  , relation
      "primitive-b-contributes-target-key-result"
      "strategy-b-key-result"
      "contributes-to"
      "strategy-target-key-result"
      Asserted
  ]

macroRelation :: String -> RelationProjection
macroRelation label =
  relation
    ("macro-" <> label <> "-contributes-target")
    ("strategy-" <> label)
    "contributes-to"
    "strategy-target"
    Asserted

collectiveProposition :: StructuredPropositionProjection
collectiveProposition =
  structuredPropositionProjection
    (occurrenceId "collective-claim")
    collectiveFamily
    completenessClosed
    Asserted

collectiveIncidences :: [StructuredIncidenceProjection]
collectiveIncidences =
  [ incidence "claim-participant-a" participantRole "strategy-a"
  , incidence "claim-participant-b" participantRole "strategy-b"
  , incidence "claim-target" targetRole "strategy-target"
  ]

completeModelOccurrences :: [ModelOccurrence]
completeModelOccurrences =
  carrierModels
    (visionCarrierNames
       <> concatMap strategyCarrierNames ["a", "b", "target"]
       <> ["collective-claim"])
    <> segmentModels
         (visionContextualizationNames
            <> concatMap strategyContextualizationNames ["a", "b", "target"]
            <> concatMap
                 (\label ->
                    visionOrientationName label
                      : strategyInternalRelationNames label)
                 ["a", "b", "target"]
            <> [ "macro-a-contributes-target"
               , "macro-b-contributes-target"
               , "primitive-a-contributes-target-action"
               , "primitive-b-contributes-target-key-result"
               , "claim-participant-a"
               , "claim-participant-b"
               , "claim-target"
               ])

visionCarriers :: [CarrierProjection]
visionCarriers =
  [ contextCarrier "vision" "Vision" Asserted
  , primitiveCarrier "vision-objective" "Objective" Asserted
  ]

visionContextualizations :: [ContextualizationProjection]
visionContextualizations =
  [ownership "owns-vision-objective" "vision" "vision-objective" Asserted]

visionCarrierNames :: [String]
visionCarrierNames = ["vision", "vision-objective"]

visionContextualizationNames :: [String]
visionContextualizationNames = ["owns-vision-objective"]

strategyCarriers :: String -> [CarrierProjection]
strategyCarriers label =
  strategyCarrier label Asserted
    : [ primitiveCarrier (strategyMember label member) o2iType Asserted
      | (member, o2iType) <-
          [ ("driver", "Driver")
          , ("objective", "Objective")
          , ("principle", "Principle")
          , ("action", "Action")
          , ("key-result", "KeyResult")
          ]
      ]

strategyContextualizations :: String -> [ContextualizationProjection]
strategyContextualizations label =
  [ ownership
    ("owns-" <> strategyMember label member)
    ("strategy-" <> label)
    (strategyMember label member)
    Asserted
  | member <- ["driver", "objective", "principle", "action", "key-result"]
  ]

strategyInternalRelations :: String -> [RelationProjection]
strategyInternalRelations label =
  [ relation
      (strategyRelation label "driver-grounds-objective")
      (strategyMember label "driver")
      "grounds"
      (strategyMember label "objective")
      Asserted
  , relation
      (strategyRelation label "principle-guides-action")
      (strategyMember label "principle")
      "guides"
      (strategyMember label "action")
      Asserted
  , relation
      (strategyRelation label "action-contributes-key-result")
      (strategyMember label "action")
      "contributes-to"
      (strategyMember label "key-result")
      Asserted
  , relation
      (strategyRelation label "key-result-substantiates-objective")
      (strategyMember label "key-result")
      "substantiates"
      (strategyMember label "objective")
      Asserted
  ]

visionOrientation :: String -> RelationProjection
visionOrientation label =
  relation
    (visionOrientationName label)
    "vision-objective"
    "orients"
    (strategyMember label "objective")
    Asserted

strategyCarrierNames :: String -> [String]
strategyCarrierNames label =
  ("strategy-" <> label)
    : map
        (strategyMember label)
        ["driver", "objective", "principle", "action", "key-result"]

strategyContextualizationNames :: String -> [String]
strategyContextualizationNames label =
  map
    (("owns-" <>) . strategyMember label)
    ["driver", "objective", "principle", "action", "key-result"]

strategyInternalRelationNames :: String -> [String]
strategyInternalRelationNames label =
  map
    (strategyRelation label)
    [ "driver-grounds-objective"
    , "principle-guides-action"
    , "action-contributes-key-result"
    , "key-result-substantiates-objective"
    ]

strategyRelation :: String -> String -> String
strategyRelation label suffix = "strategy-" <> label <> "-" <> suffix

visionOrientationName :: String -> String
visionOrientationName label = "vision-orients-strategy-" <> label

strategyMember :: String -> String -> String
strategyMember label member = "strategy-" <> label <> "-" <> member

strategyInputs :: [(Natural, ByteString)]
strategyInputs =
  [(0, strategyInput "a"), (1, strategyInput "b"), (2, strategyInput "target")]

completeInputs :: [(Natural, ByteString)]
completeInputs = strategyInputs <> [(3, collectiveInput)]

strategyInput :: String -> ByteString
strategyInput label =
  strategyInputWithMembers
    label
    (strategyMember label "driver")
    (strategyMember label "objective")
    (strategyMember label "principle")
    (strategyMember label "action")
    (strategyMember label "key-result")

strategyMismatchInput :: ByteString
strategyMismatchInput =
  strategyInputWithMembers
    "a"
    (strategyMember "b" "driver")
    (strategyMember "b" "objective")
    (strategyMember "b" "principle")
    (strategyMember "b" "action")
    (strategyMember "b" "key-result")

strategyInputWithMembers ::
     String -> String -> String -> String -> String -> String -> ByteString
strategyInputWithMembers label diagnosis intent guidingPolicy action keyResult =
  ByteString.pack
    (concat
       [ "{\"type\":\"StrategyFormulationInput\""
       , ",\"strategy\":\"strategy-"
       , label
       , "\""
       , ",\"scope\":[\"scope\"]"
       , ",\"anchoring\":{"
       , "\"period\":\"period\""
       , ",\"responsibilityScope\":\"responsibility scope\""
       , ",\"decisionLevel\":\"decision level\""
       , ",\"responsibilities\":[\"responsibility\"]"
       , ",\"decisionPaths\":[\"decision path\"]"
       , ",\"implementationLogic\":\"implementation logic\"}"
       , ",\"derivedGuardrails\":[\"guardrail\"]"
       , ",\"diagnosis\":\""
       , diagnosis
       , "\""
       , ",\"intent\":\""
       , intent
       , "\""
       , ",\"guidingPolicy\":\""
       , guidingPolicy
       , "\""
       , ",\"positioning\":[\"positioning\"]"
       , ",\"tradeOffs\":[\"trade-off\"]"
       , ",\"actions\":[\""
       , action
       , "\"]"
       , ",\"keyResults\":[\""
       , keyResult
       , "\"]"
       , ",\"fitRationale\":[\"fit rationale\"]}"
       ])

collectiveInput :: ByteString
collectiveInput =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-b\"]"
       , ",\"target\":\"strategy-target\""
       , ",\"targetGuidingPolicy\":\"strategy-target-principle\""
       , ",\"targetTradeOffs\":[\"trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-b\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-b\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

collectiveInputAllFitDefects :: ByteString
collectiveInputAllFitDefects =
  ByteString.pack
    (concat
       [ "{\"type\":\"CollectiveFitInput\""
       , ",\"claim\":\"collective-claim\""
       , ",\"participants\":[\"strategy-a\",\"strategy-target\"]"
       , ",\"target\":\"strategy-b\""
       , ",\"targetGuidingPolicy\":\"strategy-a-principle\""
       , ",\"targetTradeOffs\":[\"different-trade-off\"]"
       , ",\"pairwiseCoherence\":[{"
       , "\"participantA\":\"strategy-a\""
       , ",\"participantB\":\"strategy-target\""
       , ",\"rationale\":\"coherent\"}]"
       , ",\"participantCompatibility\":["
       , "{\"participant\":\"strategy-a\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}"
       , ",{\"participant\":\"strategy-target\""
       , ",\"guidingPolicyRationale\":\"compatible\""
       , ",\"tradeOffRationale\":\"compatible\"}]"
       , ",\"contributionInteraction\":[\"coordinated\"]}"
       ])

contextCarrier :: String -> Text -> Commitment -> CarrierProjection
contextCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    contextCategory
    (exactType o2iType)
    commitment

strategyCarrier :: String -> Commitment -> CarrierProjection
strategyCarrier label = contextCarrier ("strategy-" <> label) "Strategy"

primitiveCarrier :: String -> Text -> Commitment -> CarrierProjection
primitiveCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    primitiveCategory
    (exactType o2iType)
    commitment

anchorCarrier :: String -> Text -> Commitment -> CarrierProjection
anchorCarrier identifier o2iType commitment =
  carrierProjection
    (occurrenceId identifier)
    situationAnchorCategory
    (exactType o2iType)
    commitment

ownership ::
     String -> String -> String -> Commitment -> ContextualizationProjection
ownership identifier owner member commitment =
  contextualizationProjection
    (occurrenceId identifier)
    (occurrenceId owner)
    (occurrenceId member)
    commitment

relation ::
     String -> String -> Text -> String -> Commitment -> RelationProjection
relation identifier source token target commitment =
  relationProjection
    (occurrenceId identifier)
    (occurrenceId source)
    (exactRelationToken token)
    (occurrenceId target)
    commitment

incidence ::
     String
  -> CoreStructuredPropositionRoleId
  -> String
  -> StructuredIncidenceProjection
incidence identifier role endpoint =
  structuredIncidenceProjection
    (occurrenceId identifier)
    (occurrenceId "collective-claim")
    role
    (occurrenceId endpoint)

carrierModels :: [String] -> [ModelOccurrence]
carrierModels =
  map
    (\identifier ->
       modelOccurrence (occurrenceId identifier) (modelId identifier))

segmentModels :: [String] -> [ModelOccurrence]
segmentModels =
  map
    (\identifier ->
       modelOccurrence
         (occurrenceId identifier)
         (modelId ("segment-" <> identifier)))

contextCategory, primitiveCategory, situationAnchorCategory ::
     CoreCarrierCategory
contextCategory = exactCategory "Context"

primitiveCategory = exactCategory "Primitive"

situationAnchorCategory = exactCategory "SituationAnchor"

collectiveFamily :: CoreStructuredPropositionFamilyId
collectiveFamily = exactFamily "collective-strategy-realization"

participantRole, targetRole :: CoreStructuredPropositionRoleId
participantRole = exactRole "collective-strategy-realization.role.participant"

targetRole = exactRole "collective-strategy-realization.role.target"

completenessOpen, completenessClosed :: CoreParticipantCompleteness
completenessOpen = exactCompleteness "open"

completenessClosed = exactCompleteness "closed"

modelId :: String -> ModelIdentity
modelId identifier =
  case modelIdentity (Text.pack identifier) of
    Left problem ->
      error ("invalid conformance model identity: " <> show problem)
    Right value -> value

occurrenceId :: String -> OccurrenceIdentity
occurrenceId identifier =
  case occurrenceIdentity (Text.pack identifier) of
    Left problem ->
      error ("invalid conformance occurrence identity: " <> show problem)
    Right value -> value

exactCategory :: Text -> CoreCarrierCategory
exactCategory token =
  exactValue "carrier category" token (lookupCoreCarrierCategory token)

exactType :: Text -> CoreO2IType
exactType token = exactValue "O2I type" token (lookupCoreO2IType token)

exactRelationToken :: Text -> CoreRelationToken
exactRelationToken token =
  exactValue "relation token" token (lookupCoreRelationToken token)

exactFamily :: Text -> CoreStructuredPropositionFamilyId
exactFamily token =
  exactValue
    "structured proposition family"
    token
    (lookupCoreStructuredPropositionFamilyId token)

exactRole :: Text -> CoreStructuredPropositionRoleId
exactRole token =
  exactValue
    "structured proposition role"
    token
    (lookupCoreStructuredPropositionRoleId token)

exactCompleteness :: Text -> CoreParticipantCompleteness
exactCompleteness token =
  exactValue
    "participant completeness"
    token
    (lookupCoreParticipantCompletenessToken token)

exactValue :: String -> Text -> Maybe value -> value
exactValue label token value =
  case value of
    Nothing ->
      error ("compiled contract lacks " <> label <> ": " <> Text.unpack token)
    Just result -> result
