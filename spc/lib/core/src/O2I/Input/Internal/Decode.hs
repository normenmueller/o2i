{-# LANGUAGE OverloadedStrings #-}

-- | Total typed decoding of the two closed supplemental payloads.
module O2I.Input.Internal.Decode
  ( decodeSupplementalInput
  ) where

import Data.Aeson (Object, Value(..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.ByteString (ByteString)
import Data.Foldable (toList)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Identity (ModelIdentity, ModelIdentityDefect(..), modelIdentity)
import O2I.Input.Internal.Json
import O2I.Input.Internal.Text
import O2I.Input.Internal.Types

-- | Decode one exact source into one canonical closed payload.
--
-- Each failed phase suppresses every later phase for this input. Within the
-- schema phase, independent member defects accumulate deterministically.
decodeSupplementalInput ::
     SupplementalInputOrdinal
  -> ByteString
  -> Either (NonEmpty SupplementalInputDefect) SupplementalInput
decodeSupplementalInput ordinal bytes = do
  utf8 <-
    mapSingle
      (inputDefect SupplementalInvalidUtf8 ordinal)
      (decodeUtf8Json bytes)
  parsed <-
    mapSingle
      (inputDefect SupplementalInvalidJsonSyntax ordinal)
      (parseJsonSyntax utf8)
  duplicateFree <-
    case rejectDuplicateMembers parsed of
      Left pointers ->
        Left (fmap (memberDefect ordinal . jsonPointerText) pointers)
      Right value -> Right value
  decodePayload ordinal (duplicateFreeValue duplicateFree)

decodePayload ::
     SupplementalInputOrdinal
  -> Value
  -> Either (NonEmpty SupplementalInputDefect) SupplementalInput
decodePayload ordinal value =
  case value of
    Object object -> do
      payloadType <- decodePayloadType ordinal object
      checkedToEither
        (case payloadType of
           StrategyFormulationPayload ->
             StrategyFormulationSupplement ordinal
               <$> decodeStrategyFormulation ordinal object
           CollectiveFitPayload ->
             CollectiveFitSupplement ordinal
               <$> decodeCollectiveFit ordinal object)
    _ ->
      Left
        (schemaDefect
           SupplementalTopLevelObjectRequired
           ordinal
           rootPointer
           rootSchema
           :| [])

decodePayloadType ::
     SupplementalInputOrdinal
  -> Object
  -> Either (NonEmpty SupplementalInputDefect) SupplementalPayloadType
decodePayloadType ordinal object =
  case KeyMap.lookup "type" object of
    Nothing -> Left (invalidTypeMember :| [])
    Just (String "StrategyFormulationInput") -> Right StrategyFormulationPayload
    Just (String "CollectiveFitInput") -> Right CollectiveFitPayload
    Just (String _) ->
      Left
        (schemaDefect
           SupplementalPayloadTypeNotAdmitted
           ordinal
           typePointer
           typeSchema
           :| [])
    Just _ -> Left (invalidTypeMember :| [])
  where
    invalidTypeMember =
      schemaDefect SupplementalTypeMemberInvalid ordinal typePointer typeSchema

decodeStrategyFormulation ::
     SupplementalInputOrdinal -> Object -> Checked StrategyFormulationInput
decodeStrategyFormulation ordinal object =
  StrategyFormulationInput
    <$> requiredModelIdentity ordinal rootPointer base object "strategy"
    <*> requiredTextSequence ordinal rootPointer base object "scope"
    <*> requiredAnchoring ordinal rootPointer base object "anchoring"
    <*> requiredTextSequence ordinal rootPointer base object "derivedGuardrails"
    <*> requiredModelIdentity ordinal rootPointer base object "diagnosis"
    <*> requiredModelIdentity ordinal rootPointer base object "intent"
    <*> requiredModelIdentity ordinal rootPointer base object "guidingPolicy"
    <*> requiredTextSequence ordinal rootPointer base object "positioning"
    <*> requiredDistinctTextSet ordinal rootPointer base object "tradeOffs"
    <*> requiredDistinctIdentitySet ordinal rootPointer base object "actions" 1
    <*> requiredDistinctIdentitySet
          ordinal
          rootPointer
          base
          object
          "keyResults"
          1
    <*> requiredTextSequence ordinal rootPointer base object "fitRationale"
    <* rejectUnknownMembers ordinal rootPointer base admitted object
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
     SupplementalInputOrdinal -> Object -> Checked CollectiveFitInput
decodeCollectiveFit ordinal object =
  CollectiveFitInput
    <$> requiredModelIdentity ordinal rootPointer base object "claim"
    <*> requiredDistinctIdentitySet
          ordinal
          rootPointer
          base
          object
          "participants"
          2
    <*> requiredModelIdentity ordinal rootPointer base object "target"
    <*> requiredModelIdentity
          ordinal
          rootPointer
          base
          object
          "targetGuidingPolicy"
    <*> requiredDistinctTextSet
          ordinal
          rootPointer
          base
          object
          "targetTradeOffs"
    <*> requiredObjectSequence
          ordinal
          rootPointer
          base
          object
          "pairwiseCoherence"
          1
          decodePairwiseCoherence
    <*> requiredObjectSequence
          ordinal
          rootPointer
          base
          object
          "participantCompatibility"
          2
          decodeParticipantCompatibility
    <*> requiredTextSequence
          ordinal
          rootPointer
          base
          object
          "contributionInteraction"
    <* rejectUnknownMembers ordinal rootPointer base admitted object
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
  -> Text
  -> Text
  -> Object
  -> Text
  -> Checked StrategyAnchoring
requiredAnchoring ordinal objectPointer parent object member =
  requiredMember ordinal objectPointer parent object member $ \pointer value ->
    case value of
      Object anchoring ->
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
     SupplementalInputOrdinal -> Text -> Value -> Checked PairwiseCoherence
decodePairwiseCoherence ordinal pointer value =
  case value of
    Object object ->
      PairwiseCoherence
        <$> requiredModelIdentity ordinal pointer base object "participantA"
        <*> requiredModelIdentity ordinal pointer base object "participantB"
        <*> requiredFachlicheText ordinal pointer base object "rationale"
        <* rejectUnknownMembers ordinal pointer base admitted object
    _ -> invalidValueKind ordinal pointer base
  where
    base = "#/$defs/PairwiseCoherence"
    admitted = ["participantA", "participantB", "rationale"]

decodeParticipantCompatibility ::
     SupplementalInputOrdinal
  -> Text
  -> Value
  -> Checked ParticipantCompatibility
decodeParticipantCompatibility ordinal pointer value =
  case value of
    Object object ->
      ParticipantCompatibility
        <$> requiredModelIdentity ordinal pointer base object "participant"
        <*> requiredFachlicheText
              ordinal
              pointer
              base
              object
              "guidingPolicyRationale"
        <*> requiredFachlicheText
              ordinal
              pointer
              base
              object
              "tradeOffRationale"
        <* rejectUnknownMembers ordinal pointer base admitted object
    _ -> invalidValueKind ordinal pointer base
  where
    base = "#/$defs/ParticipantCompatibility"
    admitted = ["participant", "guidingPolicyRationale", "tradeOffRationale"]

requiredModelIdentity ::
     SupplementalInputOrdinal
  -> Text
  -> Text
  -> Object
  -> Text
  -> Checked ModelIdentity
requiredModelIdentity ordinal objectPointer base object member =
  requiredMember ordinal objectPointer base object member $ \pointer value ->
    case value of
      String source ->
        case modelIdentity source of
          Right identifier -> valid identifier
          Left defect ->
            invalidOne
              (schemaDefect
                 (modelIdentityDefectKind defect)
                 ordinal
                 pointer
                 "#/$defs/ModelIdentity")
      _ -> invalidValueKind ordinal pointer "#/$defs/ModelIdentity"

requiredFachlicheText ::
     SupplementalInputOrdinal
  -> Text
  -> Text
  -> Object
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
     SupplementalInputOrdinal -> Text -> Value -> Checked FachlicheText
decodeFachlicheText ordinal pointer value =
  case value of
    String source ->
      case canonicalizeFachlicheText source of
        Right canonical -> valid (FachlicheText canonical)
        Left _ ->
          invalidOne
            (schemaDefect
               SupplementalScalarGrammarInvalid
               ordinal
               pointer
               "#/$defs/FachlicheText")
    _ -> invalidValueKind ordinal pointer "#/$defs/FachlicheText"

requiredTextSequence ::
     SupplementalInputOrdinal
  -> Text
  -> Text
  -> Object
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
  -> Text
  -> Text
  -> Object
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
  -> Text
  -> Text
  -> Object
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
    decodeIdentity
  where
    decodeIdentity pointer value =
      case value of
        String source ->
          case modelIdentity source of
            Right identifier -> valid identifier
            Left defect ->
              invalidOne
                (schemaDefect
                   (modelIdentityDefectKind defect)
                   ordinal
                   pointer
                   "#/$defs/ModelIdentity")
        _ -> invalidValueKind ordinal pointer "#/$defs/ModelIdentity"

requiredObjectSequence ::
     Ord value
  => SupplementalInputOrdinal
  -> Text
  -> Text
  -> Object
  -> Text
  -> Int
  -> (SupplementalInputOrdinal -> Text -> Value -> Checked value)
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
  -> Text
  -> Text
  -> Object
  -> Text
  -> Int
  -> Bool
  -> (Text -> Value -> Checked value)
  -> Checked (NonEmpty value)
requiredArray ordinal objectPointer base object member minimumCardinality distinct decoder =
  requiredMember ordinal objectPointer base object member $ \pointer value ->
    case value of
      Array array ->
        let sources = zip [0 :: Int ..] (toList array)
            checkedMembers =
              [ decoder (appendIndex pointer index) item
              | (index, item) <- sources
              ]
            memberDefects = concatMap checkedDefects checkedMembers
            admittedMembers = foldr collectValue [] checkedMembers
            cardinalityDefects =
              [ schemaDefect
                SupplementalArrayCardinalityInvalid
                ordinal
                pointer
                (propertySchema base member)
              | length sources < minimumCardinality
              ]
            distinctnessDefects =
              [ schemaDefect
                SupplementalArrayDistinctnessInvalid
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
                         SupplementalArrayCardinalityInvalid
                         ordinal
                         pointer
                         (propertySchema base member))
      _ -> invalidValueKind ordinal pointer (propertySchema base member)

requiredMember ::
     SupplementalInputOrdinal
  -> Text
  -> Text
  -> Object
  -> Text
  -> (Text -> Value -> Checked value)
  -> Checked value
requiredMember ordinal objectPointer base object member decoder =
  case KeyMap.lookup (Key.fromText member) object of
    Nothing ->
      invalidOne
        (schemaDefect
           SupplementalRequiredMemberMissing
           ordinal
           (appendMember objectPointer member)
           (base <> "/required"))
    Just value -> decoder (appendMember objectPointer member) value

rejectUnknownMembers ::
     SupplementalInputOrdinal -> Text -> Text -> [Text] -> Object -> Checked ()
rejectUnknownMembers ordinal objectPointer base admitted object =
  case defects of
    [] -> valid ()
    defect:remaining -> invalid (defect :| remaining)
  where
    admittedKeys = Set.fromList admitted
    defects =
      [ schemaDefect
        SupplementalUnknownMember
        ordinal
        (appendMember objectPointer member)
        (base <> "/additionalProperties")
      | member <-
          Set.toAscList (Set.fromList (map Key.toText (KeyMap.keys object)))
      , Set.notMember member admittedKeys
      ]

invalidValueKind :: SupplementalInputOrdinal -> Text -> Text -> Checked value
invalidValueKind ordinal pointer schemaPointer =
  invalidOne
    (schemaDefect SupplementalValueKindInvalid ordinal pointer schemaPointer)

modelIdentityDefectKind :: ModelIdentityDefect -> SupplementalInputDefectKind
modelIdentityDefectKind defect =
  case defect of
    EmptyModelIdentity -> SupplementalScalarGrammarInvalid
    ModelIdentityContainsU0000 -> SupplementalModelIdentityContainsNul
    ModelIdentityContainsSurrogate ->
      SupplementalModelIdentityUnicodeScalarInvalid

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

inputDefect ::
     SupplementalInputDefectKind
  -> SupplementalInputOrdinal
  -> ignored
  -> SupplementalInputDefect
inputDefect kind ordinal _ =
  SupplementalInputDefect kind (SupplementalInputKey ordinal)

memberDefect :: SupplementalInputOrdinal -> Text -> SupplementalInputDefect
memberDefect ordinal pointer =
  SupplementalInputDefect
    SupplementalDuplicateObjectMember
    (SupplementalMemberKey ordinal pointer)

schemaDefect ::
     SupplementalInputDefectKind
  -> SupplementalInputOrdinal
  -> Text
  -> Text
  -> SupplementalInputDefect
schemaDefect kind ordinal instancePointer schemaPointer =
  SupplementalInputDefect
    kind
    (SupplementalSchemaKey ordinal instancePointer schemaPointer)

mapSingle ::
     (failure -> SupplementalInputDefect)
  -> Either failure value
  -> Either (NonEmpty SupplementalInputDefect) value
mapSingle transform = either (Left . (:| []) . transform) Right

propertySchema :: Text -> Text -> Text
propertySchema base member = base <> "/properties/" <> escapePointer member

rootPointer :: Text
rootPointer = ""

typePointer :: Text
typePointer = "/type"

rootSchema :: Text
rootSchema = "#"

typeSchema :: Text
typeSchema = "#/properties/type"

appendMember :: Text -> Text -> Text
appendMember parent member = parent <> "/" <> escapePointer member

appendIndex :: Text -> Int -> Text
appendIndex parent = appendMember parent . Text.pack . show

escapePointer :: Text -> Text
escapePointer = Text.replace "/" "~1" . Text.replace "~" "~0"
