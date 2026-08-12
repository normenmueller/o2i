{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.Mapping where

import Data.Char (ord)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Normalize (NormalizationMode(NFC), normalize)
import O2I.ArchiMate.Profile.Internal.Generated

-- | Closed normalization failures for a concrete relationship label.
data RelationshipLabelDefect
  = RelationshipLabelContainsControl !Char
  | RelationshipLabelContainsTab
  | RelationshipLabelEmpty
  deriving (Eq, Ord, Show)

-- | One generated mapping from an O2I carrier family to ArchiMate notation.
data CarrierMapping = CarrierMapping
  { carrierMappingIdValue :: !Text
  , carrierMappingRuleIdValue :: !Text
  , carrierMappingElementValue :: !Text
  , carrierMappingCategoryValue :: !Text
  , carrierMappingTypesValue :: ![Text]
  } deriving (Eq, Ord, Show)

-- | One generated mapping from an O2I relation family to ArchiMate notation.
data RelationMapping = RelationMapping
  { relationMappingIdValue :: !Text
  , relationMappingRuleIdValue :: !Text
  , relationMappingRelationshipValue :: !Text
  , relationMappingAssociationDirectedValue :: !Bool
  , relationMappingLabelValue :: !Text
  , relationMappingTokenValue :: !Text
  } deriving (Eq, Ord, Show)

-- | Type witness for one generated runtime-expectation shape.
data PatternExpectation value where
  PatternTextExpectation :: PatternExpectation Text
  PatternTextsExpectation :: PatternExpectation [Text]
  PatternBooleanExpectation :: PatternExpectation Bool

carrierInventory :: [CarrierMapping]
carrierInventory =
  [ CarrierMapping identifier ruleId element category o2iTypes
  | GeneratedCarrierMapping identifier ruleId element category o2iTypes <-
      generatedCarrierMappings
  ]

relationInventory :: [RelationMapping]
relationInventory =
  [ RelationMapping identifier ruleId relationship directed label token
  | GeneratedRelationMapping identifier ruleId relationship directed label token _ <-
      generatedRelationMappings
  ]

relationProjectionInventory :: Set (Text, Text, Text)
relationProjectionInventory =
  Set.fromList
    [ (mappingId, sourceElement, targetElement)
    | GeneratedRelationProjectionPlan mappingId sourceElement targetElement <-
        generatedRelationProjectionPlans
    ]

relationMappingApplies :: RelationMapping -> Text -> Text -> Bool
relationMappingApplies mapping sourceElement targetElement =
  Set.member
    (relationMappingIdValue mapping, sourceElement, targetElement)
    relationProjectionInventory

lookupPatternExpectation ::
     PatternExpectation value -> Text -> Maybe (Text, value)
lookupPatternExpectation expectation subject =
  case filter
         ((== subject) . generatedPatternRuntimeSubject)
         generatedPatternRuntimeRules of
    [rule] ->
      fmap
        ((,) (generatedPatternRuntimeRuleId rule))
        (expectedValue expectation (generatedPatternRuntimeExpected rule))
    _ -> Nothing

patternExpectationValue :: PatternExpectation value -> Text -> Maybe value
patternExpectationValue expectation subject =
  snd <$> lookupPatternExpectation expectation subject

expectedValue ::
     PatternExpectation value -> GeneratedRuntimeExpected -> Maybe value
expectedValue expectation generated =
  case (expectation, generated) of
    (PatternTextExpectation, GeneratedExpectedText value) -> Just value
    (PatternTextsExpectation, GeneratedExpectedTexts value) -> Just value
    (PatternBooleanExpectation, GeneratedExpectedBoolean value) -> Just value
    _ -> Nothing

normalizeLabel :: Text -> Either RelationshipLabelDefect Text
normalizeLabel raw =
  case Text.find isRejectedControl raw of
    Just character -> Left (RelationshipLabelContainsControl character)
    Nothing ->
      let normalized = normalize NFC raw
          trimmed = Text.dropAround isEdgeWhitespace normalized
       in if Text.any (== '\t') trimmed
            then Left RelationshipLabelContainsTab
            else if Text.null trimmed
                   then Left RelationshipLabelEmpty
                   else Right trimmed
  where
    isEdgeWhitespace character = character == '\t' || character == ' '
    isRejectedControl character =
      let codepoint = ord character
       in (codepoint >= 0x00 && codepoint <= 0x08)
            || codepoint == 0x0A
            || (codepoint >= 0x0B && codepoint <= 0x1F)
            || codepoint == 0x7F

matchingCarriers :: Text -> Text -> [CarrierMapping]
matchingCarriers element o2iType =
  filter
    (\mapping ->
       carrierMappingElementValue mapping == element
         && o2iType `elem` carrierMappingTypesValue mapping)
    carrierInventory

matchingRelations ::
     Text -> Bool -> Text -> Either RelationshipLabelDefect [RelationMapping]
matchingRelations relationship directed rawLabel = do
  label <- normalizeLabel rawLabel
  pure
    (filter
       (\mapping ->
          relationMappingRelationshipValue mapping == relationship
            && relationMappingAssociationDirectedValue mapping == directed
            && relationMappingLabelValue mapping == label)
       relationInventory)

contextualizationMatch :: Text -> Bool -> Text -> Bool
contextualizationMatch relationship directed rawLabel =
  patternRelationshipMatch
    "contextualization.relationship.type"
    "contextualization.relationship.directed"
    "contextualization.relationship.label"
    relationship
    directed
    rawLabel

structuredSegmentMatch :: Text -> Bool -> Text -> Bool
structuredSegmentMatch relationship directed rawLabel =
  patternRelationshipMatch
    "collective.segments.relationship-type"
    "collective.segments.directed"
    "collective.segments.label"
    relationship
    directed
    rawLabel

patternRelationshipMatch :: Text -> Text -> Text -> Text -> Bool -> Text -> Bool
patternRelationshipMatch relationshipSubject directedSubject labelSubject relationship directed rawLabel =
  case ( patternExpectationValue PatternTextExpectation relationshipSubject
       , patternExpectationValue PatternBooleanExpectation directedSubject
       , patternExpectationValue PatternTextExpectation labelSubject) of
    (Just expectedRelationship, Just expectedDirected, Just expectedLabel) ->
      relationship == expectedRelationship
        && directed == expectedDirected
        && normalizeLabel rawLabel == Right expectedLabel
    _ -> False
