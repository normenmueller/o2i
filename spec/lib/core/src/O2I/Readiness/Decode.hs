{-# LANGUAGE OverloadedStrings #-}

-- | Readiness-only evidence-input decoding owned by Core.
module O2I.Readiness.Decode
  ( decodeReadinessInputInternal
  , decodeReadinessInputWithWorkInternal
  , Checked(..)
  , decodeReadinessObject
  , decodeReadinessObjectAt
  , decodeCanonicalText
  , decodeDomainValue
  , decodeModelIdentity
  , decodeTraceIdentity
  , decodeTimestamp
  , field
  , withObject
  , objectContract
  , inputDefect
  , inputDefectKeyScalarLength
  , kindFailure
  , nonEmptyDefects
  ) where

import Data.ByteString (ByteString)
import Data.Char (GeneralCategory(Space), generalCategory)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Normalize (NormalizationMode(NFC), normalize)
import Numeric.Natural (Natural)
import O2I.Core.Contract (coreQualifiedEndpointIdText, coreRuleIdText)
import O2I.Core.Contract.Internal (CoreRuleId(..))
import O2I.Core.Identity
  ( ModelIdentity
  , modelIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Input.Internal.Json
import O2I.Readiness.Internal
import O2I.Trace (TraceIdentity, TraceVariable(..), mkTraceIdentity)
import Text.Read (readMaybe)

data Checked value =
  Checked [EvidenceInputDefect] (Maybe value)

instance Functor Checked where
  fmap transform (Checked defects value) = Checked defects (transform <$> value)

instance Applicative Checked where
  pure = Checked [] . Just
  Checked leftDefects transform <*> Checked rightDefects value =
    Checked (leftDefects <> rightDefects) (transform <*> value)

decodeReadinessInputInternal ::
     ReadinessInputOrdinal
  -> ByteString
  -> Either (NonEmpty EvidenceInputDefect) ReadinessInput
decodeReadinessInputInternal ordinal bytes =
  fst (decodeReadinessInputWithWorkInternal ordinal bytes)

decodeReadinessInputWithWorkInternal ::
     ReadinessInputOrdinal
  -> ByteString
  -> (Either (NonEmpty EvidenceInputDefect) ReadinessInput, ReadinessWork)
decodeReadinessInputWithWorkInternal ordinal bytes =
  case decodeUtf8Json bytes of
    Left _ -> failed EvidenceInputInvalidUtf8 "" "invalid-utf8" 0
    Right utf8 ->
      case parseJsonSyntaxWithWork utf8 of
        Left _ -> failed EvidenceInputInvalidJsonSyntax "" "invalid-json" 0
        Right (parsed, jsonWork) ->
          let visits = jsonSourceScalarVisits jsonWork
           in case rejectDuplicateMembers parsed of
                Left pointers ->
                  let defects =
                        [ inputDefect
                          ordinal
                          EvidenceInputDuplicateObjectMember
                          (jsonPointerText pointer)
                          "member"
                          (jsonPointerText pointer)
                        | pointer <- NonEmpty.toList pointers
                        ]
                   in (Left (nonEmptyDefects defects), work visits defects)
                Right duplicateFree ->
                  let root = duplicateFreeNode duplicateFree
                   in case rootDiscriminator ordinal root of
                        Left defects ->
                          (Left defects, work visits (NonEmpty.toList defects))
                        Right object ->
                          let Checked defects decoded =
                                decodeReadinessObject ordinal object
                              ordered = sortEvidenceInputDefects defects
                           in case (ordered, decoded) of
                                ([], Just value) ->
                                  (Right value, work visits [])
                                (first:remaining, _) ->
                                  ( Left (first :| remaining)
                                  , work visits ordered)
                                ([], Nothing) ->
                                  error
                                    "Readiness decoder lost a value without evidence"
  where
    failed kind pointer observed visits =
      let defect = inputDefect ordinal kind pointer "observed" observed
       in (Left (defect :| []), work visits [defect])
    work visits defects =
      emptyReadinessWork
        { readinessInputOccurrences = visits
        , readinessOrderingEntries = length defects
        , readinessOrderingKeyScalars =
            sum (map inputDefectKeyScalarLength defects)
        , readinessRetainedEntries = length defects
        }

inputDefectKeyScalarLength :: EvidenceInputDefect -> Int
inputDefectKeyScalarLength defect =
  Text.length (coreRuleIdText (storedEvidenceInputDefectRule defect))
    + Text.length (storedEvidenceInputDefectPointer defect)
    + sum
        (map
           subjectLength
           (NonEmpty.toList (storedEvidenceInputDefectSubjects defect)))
  where
    subjectLength subject =
      case subject of
        EvidenceInputTextSubject label value ->
          Text.length label + Text.length value
        EvidenceInputNaturalSubject label value ->
          Text.length label + length (show value)
        EvidenceInputModelSubject label value ->
          Text.length label + Text.length (modelIdentityText value)
        EvidenceInputOccurrenceSubject label value ->
          Text.length label + Text.length (occurrenceIdentityText value)
        EvidenceInputQualifiedTypeSubject label value ->
          Text.length label + Text.length (coreQualifiedEndpointIdText value)

rootDiscriminator ::
     ReadinessInputOrdinal
  -> JsonNode
  -> Either (NonEmpty EvidenceInputDefect) JsonObject
rootDiscriminator ordinal node =
  case jsonNodeValue node of
    JsonObjectValue object ->
      case Map.lookup "type" object of
        Just typeNode ->
          case jsonNodeValue typeNode of
            JsonStringValue value
              | null (jsonStringMalformedScalars value)
                  && jsonStringText value == "ReadinessInput" -> Right object
            _ -> Left (discriminator :| [])
        Nothing -> Left (discriminator :| [])
    _ ->
      Left
        (inputDefect
           ordinal
           EvidenceInputTopLevelObjectRequired
           ""
           "expected"
           "object"
           :| [])
  where
    discriminator =
      inputDefect
        ordinal
        EvidenceInputDiscriminatorInvalid
        "/type"
        "expected"
        "ReadinessInput"

decodeReadinessObject ::
     ReadinessInputOrdinal -> JsonObject -> Checked ReadinessInput
decodeReadinessObject ordinal = decodeReadinessObjectAt ordinal ""

decodeReadinessObjectAt ::
     ReadinessInputOrdinal -> Text -> JsonObject -> Checked ReadinessInput
decodeReadinessObjectAt ordinal root object =
  ReadinessInput ordinal
    <$> field ordinal root "readinessCheckedAt" decodeTimestamp object
    <*> field ordinal root "kpiDefinition" decodeKpiDefinition object
    <*> field ordinal root "plannedStart" decodePlannedStart object
    <*> field ordinal root "evidencePlan" decodeEvidencePlan object
    <* objectContract
         ordinal
         root
         [ "type"
         , "readinessCheckedAt"
         , "kpiDefinition"
         , "plannedStart"
         , "evidencePlan"
         ]
         [ "type"
         , "readinessCheckedAt"
         , "kpiDefinition"
         , "plannedStart"
         , "evidencePlan"
         ]
         object

decodeKpiDefinition ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked KPIDefinition
decodeKpiDefinition ordinal pointer node =
  withObject ordinal pointer required required node $ \object ->
    KPIDefinition
      <$> field ordinal pointer "kpi" decodeModelIdentity object
      <*> field ordinal pointer "domain" decodeValueDomain object
      <*> field ordinal pointer "measurementMethod" decodeCanonicalText object
      <*> field ordinal pointer "interpretation" decodeCanonicalText object
  where
    required = ["kpi", "domain", "measurementMethod", "interpretation"]

decodePlannedStart ::
     ReadinessInputOrdinal
  -> Text
  -> JsonNode
  -> Checked PlannedInterventionStart
decodePlannedStart ordinal pointer node =
  withObject ordinal pointer required required node $ \object ->
    PlannedInterventionStart
      <$> field ordinal pointer "intervention" decodeModelIdentity object
      <*> field ordinal pointer "plannedStartAt" decodeTimestamp object
  where
    required = ["intervention", "plannedStartAt"]

decodeEvidencePlan ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked EvidencePlan
decodeEvidencePlan ordinal pointer node =
  withObject ordinal pointer required required node $ \object ->
    EvidencePlan
      <$> field ordinal pointer "trace" decodeTraceIdentity object
      <*> field ordinal pointer "baseline" decodeBaseline object
      <*> field ordinal pointer "effectCriterion" decodeEffectCriterion object
      <*> field ordinal pointer "targetCriterion" decodeTargetCriterion object
      <*> field ordinal pointer "targetDueAt" decodeTimestamp object
      <*> field ordinal pointer "source" decodeCanonicalText object
      <*> field ordinal pointer "planEstablishedAt" decodeTimestamp object
  where
    required =
      [ "trace"
      , "baseline"
      , "effectCriterion"
      , "targetCriterion"
      , "targetDueAt"
      , "source"
      , "planEstablishedAt"
      ]

decodeBaseline ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked BaselineObservation
decodeBaseline ordinal pointer node =
  withObject ordinal pointer required required node $ \object ->
    BaselineObservation
      <$> field ordinal pointer "observedAt" decodeTimestamp object
      <*> field ordinal pointer "source" decodeCanonicalText object
      <*> field ordinal pointer "value" decodeDomainValue object
  where
    required = ["observedAt", "source", "value"]

decodeTraceIdentity ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked TraceIdentity
decodeTraceIdentity ordinal pointer node =
  withObject
    ordinal
    pointer
    ["graphIdentity", "bindings"]
    ["graphIdentity", "bindings"]
    node $ \object ->
    buildTrace
      <$> field ordinal pointer "graphIdentity" decodeModelIdentity object
      <*> field ordinal pointer "bindings" decodeBindings object
  where
    buildTrace graph bindings =
      case mkTraceIdentity graph bindings of
        Just identity -> identity
        Nothing ->
          error "Readiness decoder constructed an incomplete TraceIdentity"

decodeBindings ::
     ReadinessInputOrdinal
  -> Text
  -> JsonNode
  -> Checked [(TraceVariable, ModelIdentity)]
decodeBindings ordinal pointer node =
  withObject ordinal pointer names names node $ \object ->
    sequenceA
      [ (,) variable <$> field ordinal pointer name decodeModelIdentity object
      | (name, variable) <- bindingFields
      ]
  where
    names = map fst bindingFields

bindingFields :: [(Text, TraceVariable)]
bindingFields =
  [ ("vision", VisionVariable)
  , ("strategy", StrategyVariable)
  , ("need", NeedVariable)
  , ("intervention", InterventionVariable)
  , ("measure", MeasureVariable)
  , ("situation", SituationVariable)
  , ("visionObjective", VisionObjectiveVariable)
  , ("strategyDriver", StrategyDriverVariable)
  , ("strategyObjective", StrategyObjectiveVariable)
  , ("strategyAction", StrategyActionVariable)
  , ("strategyKeyResult", StrategyKeyResultVariable)
  , ("needDriver", NeedDriverVariable)
  , ("needObjective", NeedObjectiveVariable)
  , ("interventionAction", InterventionActionVariable)
  , ("interventionKeyResult", InterventionKeyResultVariable)
  , ("measurePerformanceDimension", MeasurePerformanceDimensionVariable)
  , ("measureKpi", MeasureKpiVariable)
  , ("situationAnchor", SituationAnchorVariable)
  ]

decodeValueDomain ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked ValueDomain
decodeValueDomain ordinal pointer node =
  discriminated ordinal pointer "kind" node $ \kind object ->
    case kind of
      "quantitative" ->
        QuantitativeDomain
          <$> field ordinal pointer "unit" decodeUnit object
          <*> field ordinal pointer "effectDirection" decodeDirection object
          <* objectContract
               ordinal
               pointer
               ["kind", "unit", "effectDirection"]
               ["kind", "unit", "effectDirection"]
               object
      "ordinal" ->
        OrdinalDomain
          <$> field ordinal pointer "scaleId" decodeCanonicalText object
          <*> field
                ordinal
                pointer
                "orderedLevels"
                (decodeTextArray False True 2)
                object
          <*> field ordinal pointer "effectDirection" decodeDirection object
          <* objectContract
               ordinal
               pointer
               ["kind", "scaleId", "orderedLevels", "effectDirection"]
               ["kind", "scaleId", "orderedLevels", "effectDirection"]
               object
      "categorical" ->
        CategoricalDomain
          <$> field
                ordinal
                pointer
                "admittedValues"
                (decodeTextArray True True 1)
                object
          <* objectContract
               ordinal
               pointer
               ["kind", "admittedValues"]
               ["kind", "admittedValues"]
               object
      _ ->
        scalarFailure
          ordinal
          (memberPointer pointer "kind")
          "ValueDomain.kind"
          kind

decodeDomainValue ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked DomainValue
decodeDomainValue ordinal pointer node =
  discriminated ordinal pointer "kind" node $ \kind object ->
    case kind of
      "quantitative" ->
        QuantitativeValue
          <$> field ordinal pointer "value" decodeDecimal object
          <*> field ordinal pointer "unit" decodeUnit object
          <* objectContract
               ordinal
               pointer
               ["kind", "value", "unit"]
               ["kind", "value", "unit"]
               object
      "ordinal" ->
        OrdinalValue
          <$> field ordinal pointer "scaleId" decodeCanonicalText object
          <*> field ordinal pointer "level" decodeCanonicalText object
          <* objectContract
               ordinal
               pointer
               ["kind", "scaleId", "level"]
               ["kind", "scaleId", "level"]
               object
      "categorical" ->
        CategoricalValue
          <$> field ordinal pointer "value" decodeCanonicalText object
          <* objectContract
               ordinal
               pointer
               ["kind", "value"]
               ["kind", "value"]
               object
      _ ->
        scalarFailure
          ordinal
          (memberPointer pointer "kind")
          "DomainValue.kind"
          kind

decodeEffectCriterion ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked EffectCriterion
decodeEffectCriterion ordinal pointer node =
  discriminated ordinal pointer "kind" node $ \kind object ->
    case kind of
      "quantitative-absolute" ->
        QuantitativeAbsoluteEffect
          <$> field
                ordinal
                pointer
                "minimumDirectionAdjustedDelta"
                decodePositiveDecimal
                object
          <* contract ["kind", "minimumDirectionAdjustedDelta"] object
      "quantitative-relative" ->
        QuantitativeRelativeEffect
          <$> field
                ordinal
                pointer
                "minimumDirectionAdjustedRatio"
                decodePositiveDecimal
                object
          <* contract ["kind", "minimumDirectionAdjustedRatio"] object
      "ordinal-steps" ->
        OrdinalStepsEffect
          <$> field
                ordinal
                pointer
                "minimumDirectionAdjustedSteps"
                decodePositiveInteger
                object
          <* contract ["kind", "minimumDirectionAdjustedSteps"] object
      "categorical-transition" ->
        CategoricalTransitionEffect
          <$> field
                ordinal
                pointer
                "acceptedValues"
                (decodeTextArray True True 1)
                object
          <* contract ["kind", "acceptedValues"] object
      _ ->
        scalarFailure
          ordinal
          (memberPointer pointer "kind")
          "EffectCriterion.kind"
          kind
  where
    contract names = objectContract ordinal pointer names names

decodeTargetCriterion ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked TargetCriterion
decodeTargetCriterion ordinal pointer node =
  discriminated ordinal pointer "kind" node $ \kind object ->
    case kind of
      "quantitative-threshold" ->
        QuantitativeThreshold
          <$> field
                ordinal
                pointer
                "comparison"
                decodeQuantitativeComparison
                object
          <*> field ordinal pointer "target" decodeDecimal object
          <*> field ordinal pointer "unit" decodeUnit object
          <* contract ["kind", "comparison", "target", "unit"] object
      "ordinal-threshold" ->
        OrdinalThreshold
          <$> field ordinal pointer "comparison" decodeOrdinalComparison object
          <*> field ordinal pointer "scaleId" decodeCanonicalText object
          <*> field ordinal pointer "targetLevel" decodeCanonicalText object
          <* contract ["kind", "comparison", "scaleId", "targetLevel"] object
      "categorical-membership" ->
        CategoricalMembership
          <$> field
                ordinal
                pointer
                "acceptedValues"
                (decodeTextArray True True 1)
                object
          <* contract ["kind", "acceptedValues"] object
      _ ->
        scalarFailure
          ordinal
          (memberPointer pointer "kind")
          "TargetCriterion.kind"
          kind
  where
    contract names = objectContract ordinal pointer names names

decodeDirection ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked EffectDirection
decodeDirection ordinal pointer =
  exactToken
    ordinal
    pointer
    "EffectDirection"
    [("increase", EffectIncrease), ("decrease", EffectDecrease)]

decodeQuantitativeComparison ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked QuantitativeComparison
decodeQuantitativeComparison ordinal pointer =
  exactToken
    ordinal
    pointer
    "QuantitativeComparison"
    [ ("at-least", QuantitativeAtLeast)
    , ("at-most", QuantitativeAtMost)
    , ("equal", QuantitativeEqual)
    ]

decodeOrdinalComparison ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked OrdinalComparison
decodeOrdinalComparison ordinal pointer =
  exactToken
    ordinal
    pointer
    "OrdinalComparison"
    [ ("at-least-rank", OrdinalAtLeastRank)
    , ("at-most-rank", OrdinalAtMostRank)
    , ("equal-rank", OrdinalEqualRank)
    ]

decodeModelIdentity ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked ModelIdentity
decodeModelIdentity ordinal pointer node =
  case jsonNodeValue node of
    JsonStringValue source
      | malformedDefects <> nulDefects /= [] ->
        Checked (malformedDefects <> nulDefects) Nothing
      | otherwise ->
        case modelIdentity decoded of
          Right identity -> pure identity
          Left _ -> grammar EvidenceInputScalarGrammarInvalid "ModelIdentity"
      where decoded = jsonStringText source
            malformedDefects =
              [ EvidenceInputDefect
                (rule "core.evidence-input.decode.model-identity.unicode-scalar")
                EvidenceInputModelIdentityUnicodeScalarInvalid
                ordinal
                pointer
                (EvidenceInputNaturalSubject "zeroBasedIndex" index
                   :| [EvidenceInputNaturalSubject "codePoint" codePoint])
              | JsonMalformedScalar index codePoint <-
                  jsonStringMalformedScalars source
              ]
            nulDefects =
              [ EvidenceInputDefect
                (rule "core.evidence-input.decode.model-identity.nul")
                EvidenceInputModelIdentityContainsNul
                ordinal
                pointer
                (EvidenceInputNaturalSubject "zeroBasedIndex" index :| [])
              | (index, value) <- zip [0 :: Natural ..] (Text.unpack decoded)
              , value == '\NUL'
              ]
    value -> kindFailure ordinal pointer "string" value
  where
    grammar kind expected =
      Checked [inputDefect ordinal kind pointer "expected" expected] Nothing

decodeCanonicalText ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked CanonicalText
decodeCanonicalText ordinal pointer node =
  CanonicalText <$> canonicalString ordinal pointer "CanonicalText" node

decodeUnit :: ReadinessInputOrdinal -> Text -> JsonNode -> Checked Unit
decodeUnit ordinal pointer node =
  Unit <$> canonicalString ordinal pointer "Unit" node

canonicalString ::
     ReadinessInputOrdinal -> Text -> Text -> JsonNode -> Checked Text
canonicalString ordinal pointer schema node =
  case jsonNodeValue node of
    JsonStringValue source
      | not (null (jsonStringMalformedScalars source)) ->
        scalarFailure ordinal pointer schema "malformed-unicode-scalar"
      | Text.null value || edgeWhitespace value ->
        scalarFailure ordinal pointer schema value
      | otherwise -> pure (normalize NFC value)
      where value = jsonStringText source
    value -> kindFailure ordinal pointer "string" value

decodeDecimal ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked CanonicalDecimal
decodeDecimal ordinal pointer node =
  checkedString ordinal pointer "CanonicalDecimal" parseCanonicalDecimal node

decodePositiveDecimal ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked PositiveDecimal
decodePositiveDecimal ordinal pointer node =
  PositiveDecimal
    <$> checkedString
          ordinal
          pointer
          "PositiveDecimal"
          parsePositiveDecimal
          node

decodeTimestamp ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked UtcTimestamp
decodeTimestamp ordinal pointer node =
  checkedString ordinal pointer "UtcTimestamp" parseTimestamp node

checkedString ::
     ReadinessInputOrdinal
  -> Text
  -> Text
  -> (Text -> Maybe value)
  -> JsonNode
  -> Checked value
checkedString ordinal pointer schema parse node =
  case jsonNodeValue node of
    JsonStringValue source
      | null (jsonStringMalformedScalars source) ->
        maybe
          (scalarFailure ordinal pointer schema (jsonStringText source))
          pure
          (parse (jsonStringText source))
      | otherwise ->
        scalarFailure ordinal pointer schema "malformed-unicode-scalar"
    value -> kindFailure ordinal pointer "string" value

decodePositiveInteger ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked Natural
decodePositiveInteger ordinal pointer node =
  case jsonNodeValue node of
    JsonNumberValue lexeme
      | Text.all (`elem` ['0' .. '9']) lexeme
      , Just value <- readMaybe (Text.unpack lexeme)
      , value >= (1 :: Integer) -> pure (fromInteger value)
      | otherwise -> scalarFailure ordinal pointer "positive-integer" lexeme
    value -> kindFailure ordinal pointer "integer" value

decodeTextArray ::
     Bool
  -> Bool
  -> Int
  -> ReadinessInputOrdinal
  -> Text
  -> JsonNode
  -> Checked (NonEmpty CanonicalText)
decodeTextArray sortedOutput distinct minimumLength ordinal pointer node =
  case jsonNodeValue node of
    JsonArrayValue values ->
      let decoded =
            sequenceA
              [ decodeCanonicalText ordinal (indexPointer pointer index) value
              | (index, value) <- zip [0 ..] values
              ]
          cardinalityDefects =
            [ inputDefect
              ordinal
              EvidenceInputArrayCardinalityInvalid
              pointer
              "minimum"
              (Text.pack (show minimumLength))
            | length values < minimumLength
            ]
       in validateArray values decoded cardinalityDefects
    value -> kindFailure ordinal pointer "array" value
  where
    validateArray source (Checked defects (Just decoded)) cardinalityDefects =
      let canonical =
            if sortedOutput
              then sort decoded
              else decoded
          sourceTexts = map sourceText source
          duplicates = duplicateTextValues sourceTexts
          normalizedTexts = map canonicalText decoded
          collision =
            distinct
              && length (Set.fromList sourceTexts)
                   > length (Set.fromList normalizedTexts)
          distinctDefects =
            [ inputDefect
              ordinal
              EvidenceInputArrayDistinctnessInvalid
              pointer
              "duplicate"
              value
            | value <- duplicates
            ]
          collisionDefects =
            [ inputDefect
              ordinal
              EvidenceInputNormalizationCollision
              pointer
              "schema"
              "CanonicalText"
            | collision
            ]
          allDefects =
            defects <> cardinalityDefects <> distinctDefects <> collisionDefects
       in Checked allDefects (NonEmpty.nonEmpty canonical)
    validateArray _ (Checked defects Nothing) cardinalityDefects =
      Checked (defects <> cardinalityDefects) Nothing
    sourceText value =
      case jsonNodeValue value of
        JsonStringValue text -> jsonStringText text
        _ -> ""
    canonicalText (CanonicalText value) = value

field ::
     ReadinessInputOrdinal
  -> Text
  -> Text
  -> (ReadinessInputOrdinal -> Text -> JsonNode -> Checked value)
  -> JsonObject
  -> Checked value
field ordinal parent name decode object =
  case Map.lookup name object of
    Just node -> decode ordinal (memberPointer parent name) node
    Nothing -> Checked [] Nothing

withObject ::
     ReadinessInputOrdinal
  -> Text
  -> [Text]
  -> [Text]
  -> JsonNode
  -> (JsonObject -> Checked value)
  -> Checked value
withObject ordinal pointer allowed required node consume =
  case jsonNodeValue node of
    JsonObjectValue object ->
      consume object <* objectContract ordinal pointer allowed required object
    value -> kindFailure ordinal pointer "object" value

objectContract ::
     ReadinessInputOrdinal
  -> Text
  -> [Text]
  -> [Text]
  -> JsonObject
  -> Checked ()
objectContract ordinal pointer allowed required object =
  Checked (missing <> unknown) (Just ())
  where
    missing =
      [ inputDefect
        ordinal
        EvidenceInputRequiredMemberMissing
        pointer
        "member"
        name
      | name <- required
      , Map.notMember name object
      ]
    unknown =
      [ inputDefect
        ordinal
        EvidenceInputUnknownMember
        (memberPointer pointer name)
        "member"
        name
      | name <- Map.keys object
      , name `notElem` allowed
      ]

discriminated ::
     ReadinessInputOrdinal
  -> Text
  -> Text
  -> JsonNode
  -> (Text -> JsonObject -> Checked value)
  -> Checked value
discriminated ordinal pointer member node consume =
  case jsonNodeValue node of
    JsonObjectValue object ->
      case Map.lookup member object of
        Nothing ->
          Checked
            [ inputDefect
                ordinal
                EvidenceInputRequiredMemberMissing
                pointer
                "member"
                member
            ]
            Nothing
        Just kindNode ->
          case jsonNodeValue kindNode of
            JsonStringValue value
              | null (jsonStringMalformedScalars value) ->
                consume (jsonStringText value) object
            value ->
              kindFailure ordinal (memberPointer pointer member) "string" value
    value -> kindFailure ordinal pointer "object" value

exactToken ::
     ReadinessInputOrdinal
  -> Text
  -> Text
  -> [(Text, value)]
  -> JsonNode
  -> Checked value
exactToken ordinal pointer schema admitted node =
  case jsonNodeValue node of
    JsonStringValue source
      | null (jsonStringMalformedScalars source)
      , Just value <- lookup (jsonStringText source) admitted -> pure value
      | otherwise ->
        scalarFailure ordinal pointer schema (jsonStringText source)
    value -> kindFailure ordinal pointer "string" value

kindFailure ::
     ReadinessInputOrdinal -> Text -> Text -> JsonValue -> Checked value
kindFailure ordinal pointer expected observed =
  Checked
    [ inputDefect
        ordinal
        EvidenceInputValueKindInvalid
        pointer
        "expected"
        (expected <> ":" <> jsonKind observed)
    ]
    Nothing

scalarFailure :: ReadinessInputOrdinal -> Text -> Text -> Text -> Checked value
scalarFailure ordinal pointer expected observed =
  Checked
    [ inputDefect
        ordinal
        EvidenceInputScalarGrammarInvalid
        pointer
        "expected"
        (expected <> ":" <> observed)
    ]
    Nothing

inputDefect ::
     ReadinessInputOrdinal
  -> EvidenceInputDefectKind
  -> Text
  -> Text
  -> Text
  -> EvidenceInputDefect
inputDefect ordinal kind pointer label value =
  EvidenceInputDefect
    (defectRule kind)
    kind
    ordinal
    pointer
    (EvidenceInputTextSubject label value :| [])

defectRule :: EvidenceInputDefectKind -> CoreRuleId
defectRule kind =
  rule
    $ case kind of
        EvidenceInputInvalidUtf8 -> "core.evidence-input.decode.utf8"
        EvidenceInputInvalidJsonSyntax ->
          "core.evidence-input.decode.json-syntax"
        EvidenceInputDuplicateObjectMember ->
          "core.evidence-input.decode.duplicate-object-member"
        EvidenceInputTopLevelObjectRequired ->
          "core.evidence-input.decode.top-level-object"
        EvidenceInputDiscriminatorInvalid ->
          "core.evidence-input.decode.discriminator"
        EvidenceInputRequiredMemberMissing ->
          "core.evidence-input.decode.required-member"
        EvidenceInputUnknownMember ->
          "core.evidence-input.decode.unknown-member"
        EvidenceInputValueKindInvalid -> "core.evidence-input.decode.value-kind"
        EvidenceInputScalarGrammarInvalid ->
          "core.evidence-input.decode.scalar-grammar"
        EvidenceInputArrayCardinalityInvalid ->
          "core.evidence-input.decode.array-cardinality"
        EvidenceInputArrayDistinctnessInvalid ->
          "core.evidence-input.decode.array-distinctness"
        EvidenceInputNormalizationCollision ->
          "core.evidence-input.decode.normalization-collision"
        EvidenceInputModelIdentityUnicodeScalarInvalid ->
          "core.evidence-input.decode.model-identity.unicode-scalar"
        EvidenceInputModelIdentityContainsNul ->
          "core.evidence-input.decode.model-identity.nul"
        EvidenceInputIdentityUnknown -> "core.evidence-input.identity.unknown"
        EvidenceInputIdentityAmbiguous ->
          "core.evidence-input.identity.ambiguous"
        EvidenceInputIdentityOutOfSelectedView ->
          "core.evidence-input.identity.out-of-selected-view"
        EvidenceInputIdentityWrongType ->
          "core.evidence-input.identity.wrong-type"

rule :: Text -> CoreRuleId
rule = CoreRuleId

jsonKind :: JsonValue -> Text
jsonKind value =
  case value of
    JsonObjectValue _ -> "object"
    JsonArrayValue _ -> "array"
    JsonStringValue _ -> "string"
    JsonNumberValue _ -> "number"
    JsonBooleanValue _ -> "boolean"
    JsonNullValue -> "null"

memberPointer :: Text -> Text -> Text
memberPointer parent member = parent <> "/" <> escapePointer member

indexPointer :: Text -> Int -> Text
indexPointer parent index = parent <> "/" <> Text.pack (show index)

escapePointer :: Text -> Text
escapePointer = Text.replace "/" "~1" . Text.replace "~" "~0"

duplicateTextValues :: [Text] -> [Text]
duplicateTextValues values =
  [value | (value, count) <- Map.toAscList counts, count > (1 :: Int)]
  where
    counts = Map.fromListWith (+) [(text, 1 :: Int) | text <- values]

edgeWhitespace :: Text -> Bool
edgeWhitespace value =
  maybe True (isEcmaWhitespace . fst) (Text.uncons value)
    || maybe True (isEcmaWhitespace . snd) (Text.unsnoc value)

isEcmaWhitespace :: Char -> Bool
isEcmaWhitespace value =
  value
    `elem` [ '\x0009'
           , '\x000b'
           , '\x000c'
           , '\x000a'
           , '\x000d'
           , '\x00a0'
           , '\x2028'
           , '\x2029'
           , '\xfeff'
           ]
    || generalCategory value == Space

parseCanonicalDecimal :: Text -> Maybe CanonicalDecimal
parseCanonicalDecimal source = do
  let (negative, unsigned) =
        case Text.uncons source of
          Just ('-', rest) -> (True, rest)
          _ -> (False, source)
      (integer, fractionWithDot) = Text.breakOn "." unsigned
      fraction = Text.drop 1 fractionWithDot
      canonicalInteger =
        integer == "0"
          || (not (Text.null integer)
                && Text.head integer /= '0'
                && Text.all isAsciiDigit integer)
      canonicalFraction =
        Text.null fractionWithDot
          || (not (Text.null fraction)
                && Text.all isAsciiDigit fraction
                && Text.last fraction /= '0')
      negativeZero = negative && integer == "0" && Text.null fractionWithDot
  if canonicalInteger && canonicalFraction && not negativeZero
    then do
      coefficient <- readMaybe (Text.unpack (integer <> fraction))
      let signed =
            if negative
              then negate coefficient
              else coefficient
      pure
        (CanonicalDecimal signed (fromIntegral (Text.length fraction)) source)
    else Nothing

parsePositiveDecimal :: Text -> Maybe CanonicalDecimal
parsePositiveDecimal source = do
  value <- parseCanonicalDecimal source
  if storedDecimalCoefficient value > 0
    then Just value
    else Nothing

parseTimestamp :: Text -> Maybe UtcTimestamp
parseTimestamp source = do
  let (whole, suffix) = Text.breakOn "." source
      fractionWithZ = Text.drop 1 suffix
      fractionDigits = Text.dropEnd 1 fractionWithZ
      noFraction = Text.null suffix
      validFraction =
        noFraction
          || (Text.isSuffixOf "Z" suffix
                && not (Text.null fractionDigits)
                && Text.all isAsciiDigit fractionDigits)
      wholeExpected = Text.length whole == 20 && Text.isSuffixOf "Z" whole
  if validFraction
       && (if noFraction
             then wholeExpected
             else Text.length whole == 19)
    then do
      guardChar whole 4 '-'
      guardChar whole 7 '-'
      guardChar whole 10 'T'
      guardChar whole 13 ':'
      guardChar whole 16 ':'
      year <- digitsAt whole 0 4
      month <- digitsAt whole 5 2
      day <- digitsAt whole 8 2
      hour <- digitsAt whole 11 2
      minute <- digitsAt whole 14 2
      second <- digitsAt whole 17 2
      if validCalendar year month day
           && hour <= 23
           && minute <= 59
           && second <= 59
        then let canonicalFraction = Text.dropWhileEnd (== '0') fractionDigits
                 canonicalText =
                   Text.take 19 whole
                     <> if Text.null canonicalFraction
                          then "Z"
                          else "." <> canonicalFraction <> "Z"
                 fractionValue =
                   if Text.null canonicalFraction
                     then CanonicalDecimal 0 0 "0"
                     else CanonicalDecimal
                            (readDigits canonicalFraction)
                            (fromIntegral (Text.length canonicalFraction))
                            ("0." <> canonicalFraction)
              in Just
                   (UtcTimestamp
                      canonicalText
                      year
                      month
                      day
                      hour
                      minute
                      second
                      fractionValue)
        else Nothing
    else Nothing

guardChar :: Text -> Int -> Char -> Maybe ()
guardChar source index expected =
  if Text.index source index == expected
    then Just ()
    else Nothing

digitsAt :: Text -> Int -> Int -> Maybe Int
digitsAt source start count =
  let digits = Text.take count (Text.drop start source)
   in if Text.length digits == count && Text.all isAsciiDigit digits
        then Just (fromInteger (readDigits digits))
        else Nothing

readDigits :: Text -> Integer
readDigits =
  Text.foldl'
    (\value digit -> value * 10 + fromIntegral (fromEnum digit - fromEnum '0'))
    0

isAsciiDigit :: Char -> Bool
isAsciiDigit value = value >= '0' && value <= '9'

validCalendar :: Int -> Int -> Int -> Bool
validCalendar year month day =
  month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth year month

daysInMonth :: Int -> Int -> Int
daysInMonth year month =
  case month of
    2 ->
      if leapYear year
        then 29
        else 28
    4 -> 30
    6 -> 30
    9 -> 30
    11 -> 30
    _ -> 31

leapYear :: Int -> Bool
leapYear year =
  year `mod` 400 == 0 || (year `mod` 4 == 0 && year `mod` 100 /= 0)

nonEmptyDefects :: [EvidenceInputDefect] -> NonEmpty EvidenceInputDefect
nonEmptyDefects defects =
  case defects of
    first:remaining -> first :| remaining
    [] -> error "Readiness decoder failure must retain evidence"
