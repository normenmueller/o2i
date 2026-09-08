{-# LANGUAGE OverloadedStrings #-}

-- | Total decoding of one explicit Assessment bundle.
module O2I.Assessment.Decode
  ( decodeAssessmentBundleInputInternal
  , decodeAssessmentBundleInputWithWorkInternal
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Assessment.Internal
import O2I.Input.Internal.Json
import O2I.Readiness.Decode
  ( Checked(..)
  , decodeCanonicalText
  , decodeDomainValue
  , decodeModelIdentity
  , decodeReadinessObjectAt
  , decodeTimestamp
  , decodeTraceIdentity
  , field
  , inputDefect
  , inputDefectKeyScalarLength
  , kindFailure
  , objectContract
  , withObject
  )
import O2I.Readiness.Internal
  ( EvidenceInputDefect(..)
  , EvidenceInputDefectKind(..)
  , ReadinessInputOrdinal(..)
  , sortEvidenceInputDefects
  )

decodeAssessmentBundleInputInternal ::
     AssessmentInputOrdinal
  -> ByteString
  -> Either (NonEmpty AssessmentInputDefect) AssessmentBundleInput
decodeAssessmentBundleInputInternal ordinal bytes =
  fst (decodeAssessmentBundleInputWithWorkInternal ordinal bytes)

decodeAssessmentBundleInputWithWorkInternal ::
     AssessmentInputOrdinal
  -> ByteString
  -> ( Either (NonEmpty AssessmentInputDefect) AssessmentBundleInput
     , AssessmentWork)
decodeAssessmentBundleInputWithWorkInternal ordinal bytes =
  case decodeUtf8Json bytes of
    Left _ -> failed EvidenceInputInvalidUtf8 "" "invalid-utf8" 0
    Right utf8 ->
      case parseJsonSyntaxWithWork utf8 of
        Left _ -> failed EvidenceInputInvalidJsonSyntax "" "invalid-json" 0
        Right (parsed, jsonWork) ->
          let visits = jsonSourceScalarVisits jsonWork
           in case rejectDuplicateMembers parsed of
                Left pointers ->
                  completeFailure
                    visits
                    [ inputDefect
                      readinessOrdinal
                      EvidenceInputDuplicateObjectMember
                      (jsonPointerText pointer)
                      "member"
                      (jsonPointerText pointer)
                    | pointer <- NonEmpty.toList pointers
                    ]
                Right duplicateFree ->
                  let root = duplicateFreeNode duplicateFree
                   in case assessmentObject root of
                        Left defects ->
                          completeFailure visits (NonEmpty.toList defects)
                        Right object ->
                          let Checked defects decoded =
                                decodeAssessmentObject ordinal object
                           in case (defects, decoded) of
                                ([], Just value) ->
                                  (Right value, inputWork visits [])
                                (_:_, _) -> completeFailure visits defects
                                ([], Nothing) ->
                                  error
                                    "Assessment decoder lost a value without evidence"
  where
    readinessOrdinal = toReadinessOrdinal ordinal
    failed kind pointer observed visits =
      completeFailure
        visits
        [inputDefect readinessOrdinal kind pointer "observed" observed]
    completeFailure visits defects =
      let ordered = sortEvidenceInputDefects defects
          assessmentDefects = map (assessmentInputDefect ordinal) ordered
       in ( Left (nonEmptyAssessmentDefects assessmentDefects)
          , inputWork visits ordered)
    inputWork visits defects =
      emptyAssessmentWork
        { assessmentInputOccurrences = visits
        , assessmentOrderingEntries = length defects
        , assessmentOrderingKeyScalars =
            sum (map inputDefectKeyScalarLength defects)
        , assessmentRetainedEntries = length defects
        }

assessmentObject :: JsonNode -> Either (NonEmpty EvidenceInputDefect) JsonObject
assessmentObject node =
  case jsonNodeValue node of
    JsonObjectValue object ->
      case Map.lookup "type" object of
        Just typeNode ->
          case jsonNodeValue typeNode of
            JsonStringValue value
              | null (jsonStringMalformedScalars value)
                  && jsonStringText value == "AssessmentBundleInput" ->
                Right object
            _ -> Left (discriminator :| [])
        Nothing -> Left (discriminator :| [])
    _ ->
      Left
        (inputDefect
           zero
           EvidenceInputTopLevelObjectRequired
           ""
           "expected"
           "object"
           :| [])
  where
    zero = ReadinessInputOrdinal 0
    discriminator =
      inputDefect
        zero
        EvidenceInputDiscriminatorInvalid
        "/type"
        "expected"
        "AssessmentBundleInput"

decodeAssessmentObject ::
     AssessmentInputOrdinal -> JsonObject -> Checked AssessmentBundleInput
decodeAssessmentObject ordinal object =
  AssessmentBundleInput ordinal
    <$> field readinessOrdinal root "readiness" decodeEmbeddedReadiness object
    <*> field readinessOrdinal root "assessedAt" decodeTimestamp object
    <*> field readinessOrdinal root "actualStart" decodeActualStart object
    <*> field readinessOrdinal root "observations" decodeObservations object
    <* objectContract readinessOrdinal root admitted admitted object
  where
    root = ""
    readinessOrdinal = toReadinessOrdinal ordinal
    admitted =
      ["type", "readiness", "assessedAt", "actualStart", "observations"]
    decodeEmbeddedReadiness _ pointer node =
      case jsonNodeValue node of
        JsonObjectValue readinessObject ->
          case Map.lookup "type" readinessObject of
            Just typeNode ->
              case jsonNodeValue typeNode of
                JsonStringValue value
                  | null (jsonStringMalformedScalars value)
                      && jsonStringText value == "ReadinessInput" ->
                    decodeReadinessObjectAt
                      readinessOrdinal
                      pointer
                      readinessObject
                _ -> invalidReadinessDiscriminator pointer
            Nothing -> invalidReadinessDiscriminator pointer
        value -> kindFailure readinessOrdinal pointer "object" value
    invalidReadinessDiscriminator pointer =
      Checked
        [ inputDefect
            readinessOrdinal
            EvidenceInputDiscriminatorInvalid
            (pointer <> "/type")
            "expected"
            "ReadinessInput"
        ]
        Nothing

decodeActualStart ::
     ReadinessInputOrdinal
  -> Text
  -> JsonNode
  -> Checked ActualInterventionStart
decodeActualStart ordinal pointer node =
  withObject ordinal pointer admitted admitted node $ \object ->
    ActualInterventionStart
      <$> field ordinal pointer "intervention" decodeModelIdentity object
      <*> field ordinal pointer "actualStartAt" decodeTimestamp object
  where
    admitted = ["intervention", "actualStartAt"]

decodeObservations ::
     ReadinessInputOrdinal -> Text -> JsonNode -> Checked [Observation]
decodeObservations ordinal pointer node =
  case jsonNodeValue node of
    JsonArrayValue values ->
      sequenceA
        [ decodeObservation ordinal (fromIntegral index) itemPointer value
        | (index, value) <- zip [0 :: Int ..] values
        , let itemPointer = pointer <> "/" <> Text.pack (show index)
        ]
    value -> kindFailure ordinal pointer "array" value

decodeObservation ::
     ReadinessInputOrdinal -> Natural -> Text -> JsonNode -> Checked Observation
decodeObservation ordinal sourceOrdinal pointer node =
  withObject ordinal pointer admitted admitted node $ \object ->
    Observation (ObservationOrdinal sourceOrdinal)
      <$> field ordinal pointer "trace" decodeTraceIdentity object
      <*> field ordinal pointer "observedAt" decodeTimestamp object
      <*> field ordinal pointer "source" decodeCanonicalText object
      <*> field ordinal pointer "value" decodeDomainValue object
  where
    admitted = ["trace", "observedAt", "source", "value"]

assessmentInputDefect ::
     AssessmentInputOrdinal -> EvidenceInputDefect -> AssessmentInputDefect
assessmentInputDefect ordinal defect =
  AssessmentInputDefect
    (storedEvidenceInputDefectRule defect)
    (storedEvidenceInputDefectKind defect)
    ordinal
    (storedEvidenceInputDefectPointer defect)
    (storedEvidenceInputDefectSubjects defect)

toReadinessOrdinal :: AssessmentInputOrdinal -> ReadinessInputOrdinal
toReadinessOrdinal (AssessmentInputOrdinal value) = ReadinessInputOrdinal value

nonEmptyAssessmentDefects ::
     [AssessmentInputDefect] -> NonEmpty AssessmentInputDefect
nonEmptyAssessmentDefects defects =
  case defects of
    first:remaining -> first :| remaining
    [] -> error "Assessment input failure must retain evidence"
