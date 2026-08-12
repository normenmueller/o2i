{-# LANGUAGE OverloadedStrings #-}

-- | Static explanation ownership for every selected-Profile rule definition.
module O2I.ArchiMate.Profile.Rule.Internal.Definition
  ( RuleDefinition(..)
  , compiledProfileRuleDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Internal.Generated
import O2I.ArchiMate.Profile.Rule.Internal.Explanation
  ( NonEmptyRuleText
  , nonEmptyRuleText
  )

-- | One explicit static owner mapping for a selected-Profile rule.
data RuleDefinition =
  RuleDefinition !Text !NonEmptyRuleText !NonEmptyRuleText !NonEmptyRuleText
  deriving (Eq, Ord, Show)

-- | Complete typed/generated and explicit-static selected-Profile inventory.
compiledProfileRuleDefinitions :: NonEmpty RuleDefinition
compiledProfileRuleDefinitions =
  appendDefinitions
    classificationDefinitions
    (relationshipMappingSelectionDefinition
       : reservedPlacementDefinitions
       ++ fmap carrierDefinition generatedCarrierMappings
       ++ fmap relationDefinition generatedRelationMappings
       ++ mapMaybe relationAttributeDefinition generatedRelationMappings
       ++ concatMap propertyDefinitions generatedPropertyRuntimePlans
       ++ fmap patternDefinition generatedPatternRuntimeRules
       ++ fmap activationDefinition generatedActivationRules
       ++ fmap closureDefinition generatedClosureRules)

appendDefinitions :: NonEmpty value -> [value] -> NonEmpty value
appendDefinitions (first :| rest) additional = first :| (rest ++ additional)

classificationDefinitions :: NonEmpty RuleDefinition
classificationDefinitions =
  classificationDefinition "classification.both" True True "both"
    :| [ classificationDefinition
           "classification.graph-only"
           True
           False
           "graph-only"
       , classificationDefinition
           "classification.qualification-only"
           False
           True
           "qualification-only"
       , classificationDefinition "classification.neither" False False "neither"
       ]

classificationDefinition :: Text -> Bool -> Bool -> Text -> RuleDefinition
classificationDefinition identifier graph qualification classification =
  RuleDefinition
    identifier
    (nonEmptyRuleText
       'A'
       ("n occurrence with graph membership "
          <> renderBool graph
          <> " and qualification membership "
          <> renderBool qualification
          <> " must be classified as '"
          <> classification
          <> "'."))
    (nonEmptyRuleText
       'T'
       "he class reports the exact fixed-point branch membership of the occurrence.")
    (nonEmptyRuleText
       'A'
       "lign the occurrence's Profile markers and incidence with the intended branch membership.")

relationshipMappingSelectionDefinition :: RuleDefinition
relationshipMappingSelectionDefinition =
  RuleDefinition
    "graph.committed-relationship.mapping-selection"
    (nonEmptyRuleText
       'A'
       " committed graph relationship must select exactly one concrete syntax mapping by relationship kind, association direction, normalized label, and pattern discriminator.")
    (nonEmptyRuleText
       'E'
       "xactly one mapping keeps Profile projection deterministic without owning Core endpoint semantics.")
    (nonEmptyRuleText
       'A'
       "lign the relationship tuple with exactly one compiled relation or contextualization mapping.")

reservedPlacementDefinitions :: [RuleDefinition]
reservedPlacementDefinitions =
  [ reservedPlacementDefinition
      "reserved-placement:o2i.commitment"
      "o2i.commitment"
      ["claim-carrier", "semantic-relation"]
  , reservedPlacementDefinition
      "reserved-placement:o2i.participant-completeness"
      "o2i.participant-completeness"
      ["collective-strategy-realization-junction"]
  , reservedPlacementDefinition
      "reserved-placement:o2i.profile"
      "o2i.profile"
      ["model-root"]
  , reservedPlacementDefinition
      "reserved-placement:o2i.role"
      "o2i.role"
      ["qualification-proposal-reference-association"]
  , reservedPlacementDefinition
      "reserved-placement:o2i.source"
      "o2i.source"
      ["qualification-proposal-assessment"]
  , reservedPlacementDefinition
      "reserved-placement:o2i.type"
      "o2i.type"
      ["typed-carrier"]
  ]

reservedPlacementDefinition :: Text -> Text -> [Text] -> RuleDefinition
reservedPlacementDefinition identifier key owners =
  RuleDefinition
    identifier
    (nonEmptyRuleText
       'T'
       ("he reserved key '"
          <> key
          <> "' may occur only on compiled owner families "
          <> renderList owners
          <> "."))
    (nonEmptyRuleText
       'R'
       "eserved key placement preserves unambiguous Profile activation and interpretation.")
    (nonEmptyRuleText
       'M'
       ("ove '"
          <> key
          <> "' to an admitted owner or remove the misplaced occurrence."))

carrierDefinition :: GeneratedCarrierMapping -> RuleDefinition
carrierDefinition mapping =
  RuleDefinition
    (generatedCarrierRuleId mapping)
    (nonEmptyRuleText
       'A'
       (" displayed concept carrying an O2I type in "
          <> renderList (generatedCarrierO2ITypes mapping)
          <> " must use ArchiMate element '"
          <> generatedCarrierArchiMateElement mapping
          <> "' in carrier category '"
          <> generatedCarrierCategory mapping
          <> "'."))
    (nonEmptyRuleText
       'T'
       "he carrier tuple is the compiled notation representation of those O2I types.")
    (nonEmptyRuleText
       'U'
       ("se ArchiMate element '"
          <> generatedCarrierArchiMateElement mapping
          <> "' and an admitted o2i.type value."))

relationDefinition :: GeneratedRelationMapping -> RuleDefinition
relationDefinition mapping =
  RuleDefinition
    (generatedRelationRuleId mapping)
    (nonEmptyRuleText
       'A'
       (" relation with O2I token '"
          <> generatedRelationToken mapping
          <> "' must use ArchiMate relationship '"
          <> generatedRelationArchiMateRelationship mapping
          <> "', associationDirected="
          <> renderBool (generatedRelationAssociationDirected mapping)
          <> ", and normalized label '"
          <> generatedRelationLabel mapping
          <> "'."))
    (nonEmptyRuleText
       'T'
       "he exact relationship tuple distinguishes the compiled O2I relation notation.")
    (nonEmptyRuleText
       'S'
       ("et the relationship type, direction, and label to the compiled tuple for '"
          <> generatedRelationToken mapping
          <> "'."))

relationAttributeDefinition :: GeneratedRelationMapping -> Maybe RuleDefinition
relationAttributeDefinition mapping =
  fmap definition (generatedRelationAttributeRule mapping)
  where
    definition identifier =
      RuleDefinition
        identifier
        (nonEmptyRuleText
           'T'
           ("he strength attribute on relation mapping '"
              <> generatedRelationMappingId mapping
              <> "' must be absent or the empty string."))
        (nonEmptyRuleText
           'O'
           "2I assigns no strength semantics to this InfluenceRelationship mapping.")
        (nonEmptyRuleText
           'R'
           "emove the nonempty strength attribute from the relationship.")

propertyDefinitions :: GeneratedPropertyRuntimePlan -> [RuleDefinition]
propertyDefinitions plan =
  [ RuleDefinition
      (generatedPropertyRuntimePropertyCardinalityRuleId plan)
      (nonEmptyRuleText
         'O'
         ("wner family '"
            <> generatedPropertyRuntimeOwner plan
            <> "' must carry property '"
            <> generatedPropertyRuntimeKey plan
            <> "' with "
            <> renderCardinality
                 (generatedPropertyRuntimePropertyCardinality plan)
            <> " property occurrence."))
      (nonEmptyRuleText
         'P'
         "roperty cardinality keeps Profile metadata ownership deterministic.")
      (nonEmptyRuleText
         'A'
         ("djust the number of '"
            <> generatedPropertyRuntimeKey plan
            <> "' property occurrences to the compiled cardinality."))
  , RuleDefinition
      (generatedPropertyRuntimeValueCardinalityRuleId plan)
      (nonEmptyRuleText
         'E'
         ("ach present '"
            <> generatedPropertyRuntimeKey plan
            <> "' property occurrence on owner family '"
            <> generatedPropertyRuntimeOwner plan
            <> "' must contain "
            <> renderCardinality (generatedPropertyRuntimeValueCardinality plan)
            <> " value occurrence."))
      (nonEmptyRuleText
         'V'
         "alue cardinality preserves one unambiguous Profile metadata assertion.")
      (nonEmptyRuleText
         'A'
         ("djust the number of values in each '"
            <> generatedPropertyRuntimeKey plan
            <> "' property occurrence to the compiled cardinality."))
  , RuleDefinition
      (generatedPropertyRuntimeValueKindRuleId plan)
      (nonEmptyRuleText
         'E'
         ("ach value of property '"
            <> generatedPropertyRuntimeKey plan
            <> "' on owner family '"
            <> generatedPropertyRuntimeOwner plan
            <> "' must be a string."))
      (nonEmptyRuleText
         'T'
         "he compiled Profile grammar and domains operate on exact string values.")
      (nonEmptyRuleText
         'R'
         ("eplace each non-string '"
            <> generatedPropertyRuntimeKey plan
            <> "' value with its intended string value."))
  , propertyConstraintDefinition plan (generatedPropertyRuntimeConstraint plan)
  ]

propertyConstraintDefinition ::
     GeneratedPropertyRuntimePlan
  -> GeneratedPropertyConstraint
  -> RuleDefinition
propertyConstraintDefinition plan constraint =
  case constraint of
    GeneratedAdmittedValuesConstraint identifier expected ->
      constraintDefinition
        identifier
        "must be one of "
        expected
        "Only the closed admitted value set has Profile meaning."
        "Choose one of the compiled admitted values."
    GeneratedDomainConstraint identifier expected ->
      constraintDefinition
        identifier
        "must belong to domain "
        expected
        "The value domain binds metadata to the selected concrete carrier mapping."
        "Use a value admitted by the selected carrier mapping."
    GeneratedGrammarConstraint identifier expected ->
      constraintDefinition
        identifier
        "must satisfy grammar "
        expected
        "The grammar preserves a stable source identity without interpreting its text."
        "Replace the value with one satisfying the compiled grammar."
  where
    constraintDefinition identifier relation expected meaning action =
      RuleDefinition
        identifier
        (nonEmptyRuleText
           'E'
           ("ach string value of property '"
              <> generatedPropertyRuntimeKey plan
              <> "' on owner family '"
              <> generatedPropertyRuntimeOwner plan
              <> "' "
              <> relation
              <> renderExpected expected
              <> "."))
        (toNonEmpty meaning)
        (toNonEmpty action)

patternDefinition :: GeneratedPatternRuntimeRule -> RuleDefinition
patternDefinition rule =
  RuleDefinition
    (generatedPatternRuntimeRuleId rule)
    (nonEmptyRuleText
       'T'
       ("he compiled pattern subject '"
          <> generatedPatternRuntimeSubject rule
          <> "' must equal "
          <> renderExpected (generatedPatternRuntimeExpected rule)
          <> "."))
    (nonEmptyRuleText
       'T'
       "he pattern leaf preserves one exact structural or metadata condition of the Profile.")
    (nonEmptyRuleText
       'S'
       ("et '"
          <> generatedPatternRuntimeSubject rule
          <> "' to "
          <> renderExpected (generatedPatternRuntimeExpected rule)
          <> "."))

activationDefinition :: GeneratedActivationRule -> RuleDefinition
activationDefinition rule =
  case rule of
    ActivateGraphCarrier identifier ->
      activationRule
        identifier
        "A displayed concept matching a compiled carrier mapping must enter the graph branch."
        "Use a compiled carrier construct and o2i.type combination."
    ActivateGraphStructuredCarrier identifier ->
      activationRule
        identifier
        "A displayed junction matching a compiled structured carrier must enter the graph branch."
        "Use the compiled junction type, operator, and o2i.type tuple."
    ActivateGraphStructuredProperty identifier ->
      activationRule
        identifier
        "A displayed junction carrying the structured-family property key must enter the graph branch."
        "Place the compiled structured-family property on its admitted junction owner."
    ActivateGraphCommittedElement identifier ->
      activationRule
        identifier
        "A displayed concept carrying o2i.commitment must enter the graph branch."
        "Place o2i.commitment only on an admitted displayed concept."
    ActivateGraphCommittedStructuredCarrier identifier ->
      activationRule
        identifier
        "A displayed junction carrying o2i.commitment must enter the graph branch."
        "Place o2i.commitment only on an admitted structured junction carrier."
    ActivateGraphCommittedRelationship identifier ->
      activationRule
        identifier
        "A displayed relationship carrying o2i.commitment must enter the graph branch."
        "Place o2i.commitment only on an admitted semantic relationship."
    ActivateQualificationProposalType identifier ->
      activationRule
        identifier
        "A displayed concept matching the qualification proposal carrier tuple must enter the qualification branch."
        "Use the compiled qualification proposal carrier type tuple."
    ActivateQualificationProposalSourceKey identifier ->
      activationRule
        identifier
        "A displayed concept carrying o2i.source must enter the qualification branch as a proposal carrier."
        "Place o2i.source only on an admitted qualification proposal carrier."
    ActivateQualificationRoleKey identifier ->
      activationRule
        identifier
        "A displayed relationship carrying o2i.role must enter the qualification branch."
        "Place o2i.role only on an admitted qualification reference association."
    ActivateSharedUnknownProperty identifier ->
      activationRule
        identifier
        "A scope-seed owner carrying an unknown o2i.* property must enter both branches for complete assessment."
        "Remove the unknown reserved key or replace it with a known key on an admitted owner."
    ActivateSharedTypeKey identifier ->
      activationRule
        identifier
        "A displayed concept or junction carrying o2i.type must enter both applicable branch classifications."
        "Use an admitted o2i.type value on a compiled typed carrier."
    ActivateGraphRelation identifier ->
      activationRule
        identifier
        "A displayed relationship matching a compiled relation mapping and incident to a graph member must enter the graph branch."
        "Use a compiled relation tuple incident to the intended graph member."
    ActivateGraphContextualizationLabel identifier ->
      activationRule
        identifier
        "A displayed relationship matching the contextualization tuple and incident to a graph member must enter the graph branch."
        "Use the compiled contextualization relationship type, direction, and label."
    ActivateGraphContextualizationShape identifier ->
      activationRule
        identifier
        "A relationship from a Context carrier to a contextualizable graph member must enter the graph branch as contextualization."
        "Connect an admitted Context carrier to the intended contextualizable graph member."
    ActivateGraphStructuredSegment identifier ->
      activationRule
        identifier
        "A compiled structured segment incident to exactly one bound family junction must enter the graph branch."
        "Use the compiled segment tuple with one bound structured-family junction."
    ActivateQualificationProposalIncidence identifier ->
      activationRule
        identifier
        "A compiled qualification reference incident from a proposal carrier must enter the qualification branch."
        "Connect the proposal carrier with a compiled role-labelled qualification reference."

activationRule :: Text -> Text -> Text -> RuleDefinition
activationRule identifier expectation action =
  RuleDefinition
    identifier
    (toNonEmpty expectation)
    (nonEmptyRuleText
       'T'
       "he activation constructor defines branch membership before fixed-point closure.")
    (toNonEmpty action)

closureDefinition :: GeneratedClosureRule -> RuleDefinition
closureDefinition rule =
  case rule of
    CloseGraphStableConcept identifier ->
      closureRule
        identifier
        "A graph-seed View concept occurrence must include its uniquely resolved concept record in the graph branch."
        "Repair the View concept reference so it resolves exactly once to a concept."
    CloseGraphRelationshipSourceEndpoint identifier ->
      closureRule
        identifier
        "A graph relationship must include its uniquely resolved source endpoint in the graph branch."
        "Repair the source reference to one endpoint of the declared family."
    CloseGraphRelationshipTargetEndpoint identifier ->
      closureRule
        identifier
        "A graph relationship must include its uniquely resolved target endpoint in the graph branch."
        "Repair the target reference to one endpoint of the declared family."
    CloseGraphStructuredIncidenceByTarget identifier ->
      closureRule
        identifier
        "A relationship targeting a graph structured-family junction must enter that family's graph incidence."
        "Target the intended structured-family junction with the segment relationship."
    CloseGraphStructuredIncidenceBySource identifier ->
      closureRule
        identifier
        "A relationship sourced at a graph structured-family junction must enter that family's graph incidence."
        "Source the intended segment relationship at the structured-family junction."
    CloseGraphJunctionSourceEndpoint identifier ->
      closureRule
        identifier
        "A structured-family incidence relationship must include its uniquely resolved source endpoint in the graph branch."
        "Repair the incidence source reference to one endpoint of the declared family."
    CloseGraphJunctionTargetEndpoint identifier ->
      closureRule
        identifier
        "A structured-family incidence relationship must include its uniquely resolved target endpoint in the graph branch."
        "Repair the incidence target reference to one endpoint of the declared family."
    CloseGraphContextualization identifier ->
      closureRule
        identifier
        "A contextualizable graph carrier must include each incoming compiled contextualization relationship."
        "Use one compiled contextualization relationship targeting the intended carrier."
    CloseGraphContextOwner identifier ->
      closureRule
        identifier
        "A graph contextualization must include its uniquely resolved Context source carrier."
        "Repair the contextualization source reference to one Context carrier."
    CloseGraphStructuredCarrierFromParticipantSegment identifier ->
      closureRule
        identifier
        "A participant segment must include its uniquely resolved bound structured-family junction target."
        "Target the bound structured-family junction from the participant segment."
    CloseGraphStructuredCarrierFromTargetSegment identifier ->
      closureRule
        identifier
        "A target segment must include its uniquely resolved bound structured-family junction source."
        "Source the target segment at the bound structured-family junction."
    CloseGraphStructuredParticipant identifier ->
      closureRule
        identifier
        "A participant segment must include its uniquely resolved concept source as a graph member."
        "Repair the participant segment source reference to one concept."
    CloseGraphStructuredTarget identifier ->
      closureRule
        identifier
        "A target segment must include its uniquely resolved concept target as a graph member."
        "Repair the target segment target reference to one concept."
    CloseGraphOwnedPropertyValue identifier ->
      closureRule
        identifier
        "Every property value owned by a graph member must enter the graph branch."
        "Keep graph-member property values attached to their exact owner occurrence."
    CloseGraphPropertyDefinition identifier ->
      closureRule
        identifier
        "A graph property value keyed by a definition reference must include that property definition."
        "Repair the property-definition key reference used by the graph value."
    CloseQualificationRoleIncidenceBySource identifier ->
      closureRule
        identifier
        "A relationship sourced at a qualification proposal carrier must enter its role incidence."
        "Source the qualification reference relationship at the proposal carrier."
    CloseQualificationRoleIncidenceByTarget identifier ->
      closureRule
        identifier
        "A role-labelled relationship targeting a qualification proposal carrier must enter its role incidence."
        "Target the proposal carrier with a relationship carrying an admitted o2i.role."
    CloseQualificationRoleSourceEndpoint identifier ->
      closureRule
        identifier
        "A qualification role incidence must include its uniquely resolved concept source as a proposal endpoint."
        "Repair the role incidence source reference to one concept."
    CloseQualificationRoleTargetEndpoint identifier ->
      closureRule
        identifier
        "A qualification role incidence must include its uniquely resolved concept target as a proposal endpoint."
        "Repair the role incidence target reference to one concept."
    CloseQualificationOwnerContextualization identifier ->
      closureRule
        identifier
        "A contextualizable proposal endpoint must include each incoming compiled contextualization relationship."
        "Use a compiled contextualization relationship targeting the proposal endpoint."
    CloseQualificationContextOwner identifier ->
      closureRule
        identifier
        "A proposal endpoint contextualization must include its uniquely resolved Context source owner."
        "Repair the contextualization source reference to one Context carrier."
    CloseQualificationEndpointContextualization identifier ->
      closureRule
        identifier
        "A required proposal Context owner must include contextualizations to exact endpoints referenced by that proposal."
        "Contextualize the exact referenced endpoint from the required Context owner."
    CloseQualificationOwnedEndpoint identifier ->
      closureRule
        identifier
        "An exact proposal endpoint contextualization must include its uniquely resolved referenced endpoint."
        "Repair the contextualization target to the endpoint referenced by the proposal."
    CloseQualificationOwnedPropertyValue identifier ->
      closureRule
        identifier
        "Every property value owned by a qualification member must enter the qualification branch."
        "Keep qualification-member property values attached to their exact owner occurrence."
    CloseQualificationPropertyDefinition identifier ->
      closureRule
        identifier
        "A qualification property value keyed by a definition reference must include that property definition."
        "Repair the property-definition key reference used by the qualification value."

closureRule :: Text -> Text -> Text -> RuleDefinition
closureRule identifier expectation action =
  RuleDefinition
    identifier
    (toNonEmpty expectation)
    (nonEmptyRuleText
       'T'
       "he closure constructor preserves complete branch-local evidence and provenance.")
    (toNonEmpty action)

toNonEmpty :: Text -> NonEmptyRuleText
toNonEmpty value =
  case Text.uncons value of
    Nothing -> nonEmptyRuleText ' ' ""
    Just (first, rest) -> nonEmptyRuleText first rest

renderCardinality :: GeneratedCardinalityExpectation -> Text
renderCardinality GeneratedExactlyOne = "exactly one"
renderCardinality GeneratedZeroOrMany = "zero or more"

renderExpected :: GeneratedRuntimeExpected -> Text
renderExpected expected =
  case expected of
    GeneratedExpectedText value -> "'" <> value <> "'"
    GeneratedExpectedBoolean value -> renderBool value
    GeneratedExpectedTexts values -> renderList values

renderList :: [Text] -> Text
renderList values = "[" <> Text.intercalate ", " values <> "]"

renderBool :: Bool -> Text
renderBool False = "false"
renderBool True = "true"
