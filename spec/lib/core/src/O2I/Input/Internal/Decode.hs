{-# LANGUAGE OverloadedStrings #-}

-- | Total typed decoding of the two closed supplemental payloads.
module O2I.Input.Internal.Decode
  ( decodeSupplementalInput
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Core.Identity (ModelIdentity, modelIdentity)
import O2I.Input.Internal.Json
import O2I.Input.Internal.Text
import O2I.Input.Internal.Types

-- | Decode one exact source into one canonical closed payload.
--
-- Each failed phase suppresses every later phase for this input. Within the
-- schema phase, independent member defects accumulate deterministically.
decodeSupplementalInput ::
     provenance
  -> SupplementalInputOrdinal
  -> ByteString
  -> Either (NonEmpty SupplementalInputDefect) (SupplementalInput provenance)
decodeSupplementalInput provenance ordinal bytes = do
  utf8 <-
    mapSingle
      (const (SupplementalInvalidUtf8Defect ordinal))
      (decodeUtf8Json bytes)
  parsed <-
    mapSingle
      (const (SupplementalInvalidJsonSyntaxDefect ordinal))
      (parseJsonSyntax utf8)
  duplicateFree <-
    case rejectDuplicateMembers parsed of
      Left pointers ->
        Left (fmap (memberDefect ordinal . jsonPointerText) pointers)
      Right value -> Right value
  decodePayload provenance ordinal (duplicateFreeNode duplicateFree)

decodePayload ::
     provenance
  -> SupplementalInputOrdinal
  -> JsonNode
  -> Either (NonEmpty SupplementalInputDefect) (SupplementalInput provenance)
decodePayload provenance ordinal node =
  case jsonNodeValue node of
    JsonObjectValue object -> do
      payloadType <- decodePayloadType ordinal object
      checkedToEither
        (case payloadType of
           StrategyFormulationPayload ->
             StrategyFormulationSupplement provenance ordinal
               <$> decodeStrategyFormulation ordinal object
           CollectiveFitPayload ->
             CollectiveFitSupplement provenance ordinal
               <$> decodeCollectiveFit ordinal object)
    _ ->
      Left
        (schemaDefect
           TopLevelObjectRequiredSchemaDefect
           ordinal
           (jsonNodePath node)
           rootSchema
           :| [])

decodePayloadType ::
     SupplementalInputOrdinal
  -> JsonObject
  -> Either (NonEmpty SupplementalInputDefect) SupplementalPayloadType
decodePayloadType ordinal object =
  case Map.lookup "type" object of
    Nothing -> Left (invalidTypeMember :| [])
    Just node ->
      case jsonNodeValue node of
        JsonStringValue source
          | jsonStringMalformedScalars source == []
              && jsonStringText source == "StrategyFormulationInput" ->
            Right StrategyFormulationPayload
          | jsonStringMalformedScalars source == []
              && jsonStringText source == "CollectiveFitInput" ->
            Right CollectiveFitPayload
          | otherwise ->
            Left
              (schemaDefect
                 PayloadTypeNotAdmittedSchemaDefect
                 ordinal
                 (jsonNodePath node)
                 typeSchema
                 :| [])
        _ -> Left (invalidTypeMember :| [])
  where
    invalidTypeMember =
      schemaDefect
        TypeMemberInvalidSchemaDefect
        ordinal
        (appendJsonMember rootJsonPath "type")
        typeSchema

decodeStrategyFormulation ::
     SupplementalInputOrdinal -> JsonObject -> Checked StrategyFormulationInput
decodeStrategyFormulation ordinal object =
  StrategyFormulationInput
    <$> requiredModelIdentity ordinal rootJsonPath base object "strategy"
    <*> requiredTextSequence ordinal rootJsonPath base object "scope"
    <*> requiredAnchoring ordinal rootJsonPath base object "anchoring"
    <*> requiredTextSequence
          ordinal
          rootJsonPath
          base
          object
          "derivedGuardrails"
    <*> requiredModelIdentity ordinal rootJsonPath base object "diagnosis"
    <*> requiredModelIdentity ordinal rootJsonPath base object "intent"
    <*> requiredModelIdentity ordinal rootJsonPath base object "guidingPolicy"
    <*> requiredTextSequence ordinal rootJsonPath base object "positioning"
    <*> requiredDistinctTextSet ordinal rootJsonPath base object "tradeOffs"
    <*> requiredDistinctIdentitySet ordinal rootJsonPath base object "actions" 1
    <*> requiredDistinctIdentitySet
          ordinal
          rootJsonPath
          base
          object
          "keyResults"
          1
    <*> requiredTextSequence ordinal rootJsonPath base object "fitRationale"
    <* rejectUnknownMembers ordinal rootJsonPath base admitted object
  where
    base = "#/$defs/StrategyFormulationInput"
    admitted =
      [ "type"
      , "strategy"
      , "scope"
      , "anchoring"
      , "derivedGuardrails"
      , "diagnosis"
      , "intent"
      , "guidingPolicy"
      , "positioning"
      , "tradeOffs"
      , "actions"
      , "keyResults"
      , "fitRationale"
      ]

decodeCollectiveFit ::
     SupplementalInputOrdinal -> JsonObject -> Checked CollectiveFitInput
decodeCollectiveFit ordinal object =
  CollectiveFitInput
    <$> requiredModelIdentity ordinal rootJsonPath base object "claim"
    <*> requiredDistinctIdentitySet
          ordinal
          rootJsonPath
          base
          object
          "participants"
          2
    <*> requiredModelIdentity ordinal rootJsonPath base object "target"
    <*> requiredModelIdentity
          ordinal
          rootJsonPath
          base
          object
          "targetGuidingPolicy"
    <*> requiredDistinctTextSet
          ordinal
          rootJsonPath
          base
          object
          "targetTradeOffs"
    <*> requiredObjectSequence
          ordinal
          rootJsonPath
          base
          object
          "pairwiseCoherence"
          1
          decodePairwiseCoherence
    <*> requiredObjectSequence
          ordinal
          rootJsonPath
          base
          object
          "participantCompatibility"
          2
          decodeParticipantCompatibility
    <*> requiredTextSequence
          ordinal
          rootJsonPath
          base
          object
          "contributionInteraction"
    <* rejectUnknownMembers ordinal rootJsonPath base admitted object
  where
    base = "#/$defs/CollectiveFitInput"
    admitted =
      [ "type"
      , "claim"
      , "participants"
      , "target"
      , "targetGuidingPolicy"
      , "targetTradeOffs"
      , "pairwiseCoherence"
      , "participantCompatibility"
      , "contributionInteraction"
      ]

requiredAnchoring ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Checked StrategyAnchoring
requiredAnchoring ordinal objectPointer parent object member =
  requiredMember ordinal objectPointer parent object member $ \value ->
    let pointer = jsonNodePath value
     in case jsonNodeValue value of
          JsonObjectValue anchoring ->
            StrategyAnchoring
              <$> requiredFachlicheText ordinal pointer base anchoring "period"
              <*> requiredFachlicheText
                    ordinal
                    pointer
                    base
                    anchoring
                    "responsibilityScope"
              <*> requiredFachlicheText
                    ordinal
                    pointer
                    base
                    anchoring
                    "decisionLevel"
              <*> requiredTextSequence
                    ordinal
                    pointer
                    base
                    anchoring
                    "responsibilities"
              <*> requiredTextSequence
                    ordinal
                    pointer
                    base
                    anchoring
                    "decisionPaths"
              <*> requiredFachlicheText
                    ordinal
                    pointer
                    base
                    anchoring
                    "implementationLogic"
              <* rejectUnknownMembers ordinal pointer base admitted anchoring
          _ -> invalidValueKind ordinal pointer base
  where
    base = "#/$defs/StrategyAnchoring"
    admitted =
      [ "period"
      , "responsibilityScope"
      , "decisionLevel"
      , "responsibilities"
      , "decisionPaths"
      , "implementationLogic"
      ]

decodePairwiseCoherence ::
     SupplementalInputOrdinal -> JsonNode -> Checked PairwiseCoherence
decodePairwiseCoherence ordinal value =
  case jsonNodeValue value of
    JsonObjectValue object ->
      PairwiseCoherence
        <$> requiredModelIdentity ordinal path base object "participantA"
        <*> requiredModelIdentity ordinal path base object "participantB"
        <*> requiredFachlicheText ordinal path base object "rationale"
        <* rejectUnknownMembers ordinal path base admitted object
    _ -> invalidValueKind ordinal path base
  where
    path = jsonNodePath value
    base = "#/$defs/PairwiseCoherence"
    admitted = ["participantA", "participantB", "rationale"]

decodeParticipantCompatibility ::
     SupplementalInputOrdinal -> JsonNode -> Checked ParticipantCompatibility
decodeParticipantCompatibility ordinal value =
  case jsonNodeValue value of
    JsonObjectValue object ->
      ParticipantCompatibility
        <$> requiredModelIdentity ordinal path base object "participant"
        <*> requiredFachlicheText
              ordinal
              path
              base
              object
              "guidingPolicyRationale"
        <*> requiredFachlicheText ordinal path base object "tradeOffRationale"
        <* rejectUnknownMembers ordinal path base admitted object
    _ -> invalidValueKind ordinal path base
  where
    path = jsonNodePath value
    base = "#/$defs/ParticipantCompatibility"
    admitted = ["participant", "guidingPolicyRationale", "tradeOffRationale"]

requiredModelIdentity ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Checked ModelIdentity
requiredModelIdentity ordinal objectPointer base object member =
  requiredMember ordinal objectPointer base object member $ \value ->
    decodeModelIdentity ordinal value

decodeModelIdentity ::
     SupplementalInputOrdinal -> JsonNode -> Checked ModelIdentity
decodeModelIdentity ordinal node =
  case jsonNodeValue node of
    JsonStringValue source ->
      case modelIdentityDefects ordinal path source of
        defect:defects -> invalid (defect :| defects)
        [] ->
          case modelIdentity (jsonStringText source) of
            Right identifier -> valid identifier
            Left _ ->
              invalidOne
                (schemaDefect
                   ScalarGrammarInvalidSchemaDefect
                   ordinal
                   path
                   modelIdentitySchema)
    _ -> invalidValueKind ordinal path modelIdentitySchema
  where
    path = jsonNodePath node

modelIdentityDefects ::
     SupplementalInputOrdinal
  -> JsonPath
  -> JsonString
  -> [SupplementalInputDefect]
modelIdentityDefects ordinal path source =
  emptyDefect ++ unicodeDefect ++ nulDefect
  where
    unicodeOccurrences =
      [ SupplementalUnicodeScalarOccurrence index codePoint
      | JsonMalformedScalar index codePoint <- jsonStringMalformedScalars source
      ]
    nulIndexes =
      [ index
      | (index, value) <-
          zip [0 :: Natural ..] (Text.unpack (jsonStringText source))
      , value == '\NUL'
      ]
    emptyDefect =
      [ schemaDefect
        ScalarGrammarInvalidSchemaDefect
        ordinal
        path
        modelIdentitySchema
      | Text.null (jsonStringText source)
      ]
    unicodeDefect =
      case NonEmpty.nonEmpty unicodeOccurrences of
        Nothing -> []
        Just details ->
          [ SupplementalModelIdentityUnicodeScalarInvalidDefect
              ordinal
              (jsonPathText path)
              modelIdentitySchema
              details
          ]
    nulDefect =
      case NonEmpty.nonEmpty nulIndexes of
        Nothing -> []
        Just indexes ->
          [ SupplementalModelIdentityContainsNulDefect
              ordinal
              (jsonPathText path)
              modelIdentitySchema
              indexes
          ]

modelIdentitySchema :: Text
modelIdentitySchema = "#/$defs/ModelIdentity"

requiredFachlicheText ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Checked FachlicheText
requiredFachlicheText ordinal objectPointer base object member =
  requiredMember
    ordinal
    objectPointer
    base
    object
    member
    (decodeFachlicheText ordinal)

decodeFachlicheText ::
     SupplementalInputOrdinal -> JsonNode -> Checked FachlicheText
decodeFachlicheText ordinal node =
  case jsonNodeValue node of
    JsonStringValue source
      | jsonStringMalformedScalars source /= [] -> invalidGrammar
      | otherwise ->
        case canonicalizeFachlicheText (jsonStringText source) of
          Right canonical -> valid (FachlicheText canonical)
          Left _ -> invalidGrammar
    _ -> invalidValueKind ordinal path "#/$defs/FachlicheText"
  where
    path = jsonNodePath node
    invalidGrammar =
      invalidOne
        (schemaDefect
           ScalarGrammarInvalidSchemaDefect
           ordinal
           path
           "#/$defs/FachlicheText")

requiredTextSequence ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Checked (NonEmpty FachlicheText)
requiredTextSequence ordinal objectPointer base object member =
  requiredArray
    ordinal
    objectPointer
    base
    object
    member
    1
    False
    (decodeFachlicheText ordinal)

requiredDistinctTextSet ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Checked (NonEmpty FachlicheText)
requiredDistinctTextSet ordinal objectPointer base object member =
  requiredArray
    ordinal
    objectPointer
    base
    object
    member
    1
    True
    (decodeFachlicheText ordinal)

requiredDistinctIdentitySet ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Int
  -> Checked (NonEmpty ModelIdentity)
requiredDistinctIdentitySet ordinal objectPointer base object member minimumCardinality =
  requiredArray
    ordinal
    objectPointer
    base
    object
    member
    minimumCardinality
    True
    (decodeModelIdentity ordinal)

requiredObjectSequence ::
     Ord value
  => SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Int
  -> (SupplementalInputOrdinal -> JsonNode -> Checked value)
  -> Checked (NonEmpty value)
requiredObjectSequence ordinal objectPointer base object member minimumCardinality decoder =
  requiredArray
    ordinal
    objectPointer
    base
    object
    member
    minimumCardinality
    False
    (decoder ordinal)

requiredArray ::
     Ord value
  => SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> Int
  -> Bool
  -> (JsonNode -> Checked value)
  -> Checked (NonEmpty value)
requiredArray ordinal objectPointer base object member minimumCardinality distinct decoder =
  requiredMember ordinal objectPointer base object member $ \node ->
    case jsonNodeValue node of
      JsonArrayValue sources ->
        let pointer = jsonNodePath node
            checkedMembers = map decoder sources
            memberDefects = concatMap checkedDefects checkedMembers
            admittedMembers = foldr collectValue [] checkedMembers
            cardinalityDefects =
              [ schemaDefect
                ArrayCardinalityInvalidSchemaDefect
                ordinal
                pointer
                (propertySchema base member)
              | length sources < minimumCardinality
              ]
            distinctnessDefects =
              [ schemaDefect
                ArrayDistinctnessInvalidSchemaDefect
                ordinal
                pointer
                (propertySchema base member)
              | distinct
              , hasDuplicates admittedMembers
              ]
            defects = cardinalityDefects ++ distinctnessDefects ++ memberDefects
         in case defects of
              defect:remaining -> invalid (defect :| remaining)
              [] ->
                case NonEmpty.nonEmpty admittedMembers of
                  Just values -> valid values
                  Nothing ->
                    invalidOne
                      (schemaDefect
                         ArrayCardinalityInvalidSchemaDefect
                         ordinal
                         pointer
                         (propertySchema base member))
      _ ->
        invalidValueKind
          ordinal
          (jsonNodePath node)
          (propertySchema base member)

requiredMember ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> JsonObject
  -> Text
  -> (JsonNode -> Checked value)
  -> Checked value
requiredMember ordinal objectPointer base object member decoder =
  case Map.lookup member object of
    Nothing ->
      invalidOne
        (schemaDefect
           RequiredMemberMissingSchemaDefect
           ordinal
           (appendJsonMember objectPointer member)
           (base <> "/required"))
    Just value -> decoder value

rejectUnknownMembers ::
     SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> [Text]
  -> JsonObject
  -> Checked ()
rejectUnknownMembers ordinal objectPointer base admitted object =
  case defects of
    [] -> valid ()
    defect:remaining -> invalid (defect :| remaining)
  where
    admittedKeys = Set.fromList admitted
    defects =
      [ schemaDefect
        UnknownMemberSchemaDefect
        ordinal
        (appendJsonMember objectPointer member)
        (base <> "/additionalProperties")
      | member <- Set.toAscList (Set.fromList (Map.keys object))
      , Set.notMember member admittedKeys
      ]

invalidValueKind ::
     SupplementalInputOrdinal -> JsonPath -> Text -> Checked value
invalidValueKind ordinal pointer schemaPointer =
  invalidOne
    (schemaDefect ValueKindInvalidSchemaDefect ordinal pointer schemaPointer)

data Checked value
  = CheckedInvalid !(NonEmpty SupplementalInputDefect)
  | CheckedValid !value

instance Functor Checked where
  fmap transform checked =
    case checked of
      CheckedInvalid defects -> CheckedInvalid defects
      CheckedValid value -> CheckedValid (transform value)

instance Applicative Checked where
  pure = valid
  left <*> right =
    case (left, right) of
      (CheckedInvalid leftDefects, CheckedInvalid rightDefects) ->
        CheckedInvalid (leftDefects <> rightDefects)
      (CheckedInvalid defects, CheckedValid _) -> CheckedInvalid defects
      (CheckedValid _, CheckedInvalid defects) -> CheckedInvalid defects
      (CheckedValid transform, CheckedValid value) ->
        CheckedValid (transform value)

valid :: value -> Checked value
valid = CheckedValid

invalid :: NonEmpty SupplementalInputDefect -> Checked value
invalid = CheckedInvalid

invalidOne :: SupplementalInputDefect -> Checked value
invalidOne defect = CheckedInvalid (defect :| [])

checkedToEither ::
     Checked value -> Either (NonEmpty SupplementalInputDefect) value
checkedToEither checked =
  case checked of
    CheckedInvalid defects -> Left (NonEmpty.sort defects)
    CheckedValid value -> Right value

checkedDefects :: Checked value -> [SupplementalInputDefect]
checkedDefects checked =
  case checked of
    CheckedInvalid defects -> NonEmpty.toList defects
    CheckedValid _ -> []

collectValue :: Checked value -> [value] -> [value]
collectValue checked values =
  case checked of
    CheckedInvalid _ -> values
    CheckedValid value -> value : values

hasDuplicates :: Ord value => [value] -> Bool
hasDuplicates values = Set.size (Set.fromList values) /= length values

memberDefect :: SupplementalInputOrdinal -> Text -> SupplementalInputDefect
memberDefect = SupplementalDuplicateObjectMemberDefect

data SchemaDefectKind
  = TopLevelObjectRequiredSchemaDefect
  | TypeMemberInvalidSchemaDefect
  | PayloadTypeNotAdmittedSchemaDefect
  | RequiredMemberMissingSchemaDefect
  | UnknownMemberSchemaDefect
  | ValueKindInvalidSchemaDefect
  | ScalarGrammarInvalidSchemaDefect
  | ArrayCardinalityInvalidSchemaDefect
  | ArrayDistinctnessInvalidSchemaDefect

schemaDefect ::
     SchemaDefectKind
  -> SupplementalInputOrdinal
  -> JsonPath
  -> Text
  -> SupplementalInputDefect
schemaDefect kind ordinal instancePointer schemaPointer =
  constructor ordinal (jsonPathText instancePointer) schemaPointer
  where
    constructor =
      case kind of
        TopLevelObjectRequiredSchemaDefect ->
          SupplementalTopLevelObjectRequiredDefect
        TypeMemberInvalidSchemaDefect -> SupplementalTypeMemberInvalidDefect
        PayloadTypeNotAdmittedSchemaDefect ->
          SupplementalPayloadTypeNotAdmittedDefect
        RequiredMemberMissingSchemaDefect ->
          SupplementalRequiredMemberMissingDefect
        UnknownMemberSchemaDefect -> SupplementalUnknownMemberDefect
        ValueKindInvalidSchemaDefect -> SupplementalValueKindInvalidDefect
        ScalarGrammarInvalidSchemaDefect ->
          SupplementalScalarGrammarInvalidDefect
        ArrayCardinalityInvalidSchemaDefect ->
          SupplementalArrayCardinalityInvalidDefect
        ArrayDistinctnessInvalidSchemaDefect ->
          SupplementalArrayDistinctnessInvalidDefect

mapSingle ::
     (failure -> SupplementalInputDefect)
  -> Either failure value
  -> Either (NonEmpty SupplementalInputDefect) value
mapSingle transform = either (Left . (:| []) . transform) Right

propertySchema :: Text -> Text -> Text
propertySchema base member = base <> "/properties/" <> escapePointer member

rootSchema :: Text
rootSchema = "#"

typeSchema :: Text
typeSchema = rootSchema

escapePointer :: Text -> Text
escapePointer = Text.replace "/" "~1" . Text.replace "~" "~0"
