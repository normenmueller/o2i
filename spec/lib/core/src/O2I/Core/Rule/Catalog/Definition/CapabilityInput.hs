{-# LANGUAGE OverloadedStrings #-}

-- | Core-owned definitions for capability-input rules.
module O2I.Core.Rule.Catalog.Definition.CapabilityInput
  ( capabilityInputDefinitions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Core.Rule.Catalog.Definition
  ( CoreRuleDefinition
  , CoreRuleStage(CapabilityInputStage)
  , ruleDefinition
  )

-- | Complete capability-input stage in explicit rule identity order.
capabilityInputDefinitions :: NonEmpty CoreRuleDefinition
capabilityInputDefinitions =
  define
    "core.evidence-input.decode.array-cardinality"
    "Every evidence-input array satisfies its schema cardinality."
    "Array size is valid before the payload can be bound."
    "Add or remove array members to meet the declared cardinality."
    :| [ define
           "core.evidence-input.decode.array-distinctness"
           "Every evidence-input array that requires distinct values is distinct after canonicalization."
           "Canonical duplicates make the evidence payload ambiguous."
           "Remove or differentiate values that canonicalize identically."
       , define
           "core.evidence-input.decode.discriminator"
           "The evidence-input root has one admitted exact type discriminator."
           "The discriminator selects one closed evidence-input payload shape."
           "Set type to the exact admitted readiness or assessment token."
       , define
           "core.evidence-input.decode.duplicate-object-member"
           "No evidence-input object repeats a member name."
           "Duplicate JSON members have no deterministic Core meaning."
           "Keep exactly one occurrence of each object member."
       , define
           "core.evidence-input.decode.json-syntax"
           "Evidence input is syntactically valid JSON."
           "Malformed JSON cannot be decoded as typed evidence input."
           "Correct the JSON syntax at the reported input location."
       , define
           "core.evidence-input.decode.model-identity.nul"
           "Evidence-input model identities contain no U+0000 code point."
           "NUL is outside the exact ModelIdentity scalar contract."
           "Remove the NUL code point from the reported model identity."
       , define
           "core.evidence-input.decode.model-identity.unicode-scalar"
           "Evidence-input model identities contain only Unicode scalar values."
           "Malformed surrogate content is not an exact model identity."
           "Replace malformed Unicode with the intended scalar value."
       , define
           "core.evidence-input.decode.normalization-collision"
           "Canonicalized evidence-input sets contain no value collision."
           "Distinct source values must remain distinct after canonicalization."
           "Remove or rename values that collapse to one canonical value."
       , define
           "core.evidence-input.decode.required-member"
           "Every evidence-input object contains each required member."
           "A missing required member prevents construction of the closed payload."
           "Provide the required member at the reported object path."
       , define
           "core.evidence-input.decode.scalar-grammar"
           "Every evidence-input scalar satisfies its exact closed grammar."
           "The scalar cannot be canonicalized into its declared Core type."
           "Replace the value with one accepted by the reported scalar grammar."
       , define
           "core.evidence-input.decode.top-level-object"
           "The evidence-input document root is a JSON object."
           "Only a closed object can carry an evidence-input payload."
           "Wrap the payload in the required top-level object shape."
       , define
           "core.evidence-input.decode.unknown-member"
           "Evidence-input objects contain only members admitted by their schema."
           "Unknown members are outside the closed evidence-input contract."
           "Remove the reported unknown member."
       , define
           "core.evidence-input.decode.utf8"
           "Evidence input is valid UTF-8."
           "Invalid bytes cannot represent the JSON evidence document."
           "Encode the complete evidence input as valid UTF-8."
       , define
           "core.evidence-input.decode.value-kind"
           "Every evidence-input value has the JSON kind required by its schema."
           "A value of the wrong JSON kind cannot populate the typed field."
           "Replace the value with the required object, array, string, or number kind."
       , define
           "core.evidence-input.identity.ambiguous"
           "Every evidence-input model identity resolves to at most one selected-View occurrence."
           "An ambiguous identity cannot bind one exact graph subject."
           "Make the reported model identity unique in the selected View."
       , define
           "core.evidence-input.identity.out-of-selected-view"
           "Every evidence-input model identity belongs to the selected View."
           "Evidence may bind only to the current selected-View subject."
           "Select the containing View or reference an identity within the selected View."
       , define
           "core.evidence-input.identity.unknown"
           "Every evidence-input model identity resolves in the current model."
           "An unknown identity cannot bind evidence to a graph element."
           "Correct the identity or add the intended element to the current model."
       , define
           "core.evidence-input.identity.wrong-type"
           "Every evidence-input model identity has its required qualified Core type."
           "The resolved element is not valid for the identity site."
           "Reference an element of the required qualified Core type."
       , define
           "core.supplemental.decode.duplicate-member"
           "No supplemental-input object repeats a member name."
           "Duplicate JSON members have no deterministic Core meaning."
           "Keep exactly one occurrence of each object member."
       , define
           "core.supplemental.decode.json-syntax"
           "Supplemental input is syntactically valid JSON."
           "Malformed JSON cannot be decoded as typed supplemental input."
           "Correct the JSON syntax at the reported input location."
       , define
           "core.supplemental.decode.utf8"
           "Supplemental input is valid UTF-8."
           "Invalid bytes cannot represent the JSON supplemental document."
           "Encode the complete supplemental input as valid UTF-8."
       , define
           "core.supplemental.identity.ambiguous"
           "Every supplemental subject identity resolves to at most one selected-View occurrence."
           "An ambiguous subject cannot bind one supplemental payload."
           "Make the reported subject identity unique in the selected View."
       , define
           "core.supplemental.identity.out-of-selected-view"
           "Every supplemental subject identity belongs to the selected View."
           "Supplemental input may bind only to the current selected-View subject."
           "Select the containing View or reference a subject within the selected View."
       , define
           "core.supplemental.identity.unknown"
           "Every supplemental subject identity resolves in the current model."
           "An unknown subject cannot receive supplemental semantic input."
           "Correct the subject identity or add the intended subject to the model."
       , define
           "core.supplemental.identity.wrong-type"
           "Every supplemental subject identity has the type required by its payload."
           "The resolved subject is incompatible with the supplemental payload type."
           "Reference a subject of the required Core type."
       , define
           "core.supplemental.schema.admitted-type"
           "Every supplemental payload type is admitted by the closed input algebra."
           "Only StrategyFormulationInput and CollectiveFitInput are admitted."
           "Use one of the exact admitted supplemental payload types."
       , define
           "core.supplemental.schema.array-cardinality"
           "Every supplemental-input array satisfies its schema cardinality."
           "Array size is invalid for the declared supplemental field."
           "Add or remove array members to meet the declared cardinality."
       , define
           "core.supplemental.schema.array-distinctness"
           "Every supplemental array that requires distinct values is distinct after canonicalization."
           "Canonical duplicates violate the supplemental field contract."
           "Remove or differentiate values that canonicalize identically."
       , define
           "core.supplemental.schema.model-identity.nul"
           "Supplemental model identities contain no U+0000 code point."
           "NUL is outside the exact ModelIdentity scalar contract."
           "Remove the NUL code point from the reported model identity."
       , define
           "core.supplemental.schema.model-identity.unicode-scalar"
           "Supplemental model identities contain only Unicode scalar values."
           "Malformed surrogate content is not an exact model identity."
           "Replace malformed Unicode with the intended scalar value."
       , define
           "core.supplemental.schema.required-member"
           "Every supplemental-input object contains each required member."
           "A missing required member prevents construction of the closed payload."
           "Provide the required member at the reported object path."
       , define
           "core.supplemental.schema.scalar-grammar"
           "Every supplemental scalar satisfies its exact closed grammar."
           "The scalar cannot be canonicalized into its declared Core type."
           "Replace the value with one accepted by the reported scalar grammar."
       , define
           "core.supplemental.schema.top-level-object"
           "The supplemental-input document root is a JSON object."
           "Only a closed object can carry a supplemental payload."
           "Wrap the payload in the required top-level object shape."
       , define
           "core.supplemental.schema.type-member"
           "Every supplemental payload has one string-valued type member."
           "The decoder requires an exact discriminator before schema selection."
           "Provide the required type member as an exact JSON string."
       , define
           "core.supplemental.schema.unknown-member"
           "Supplemental-input objects contain only members admitted by their schema."
           "Unknown members are outside the closed supplemental-input contract."
           "Remove the reported unknown member."
       , define
           "core.supplemental.schema.value-kind"
           "Every supplemental value has the JSON kind required by its schema."
           "A value of the wrong JSON kind cannot populate the typed field."
           "Replace the value with the required JSON value kind."
       , define
           "core.supplemental.subject.cardinality"
           "At most one supplemental payload of each type exists per subject."
           "Duplicate subject payloads would make semantic input selection ambiguous."
           "Keep one payload for the reported type and subject identity."
       ]

define :: Text -> Text -> Text -> Text -> CoreRuleDefinition
define identifier = ruleDefinition identifier CapabilityInputStage
