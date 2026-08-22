{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import Control.Monad (foldM, forM_)
import Data.Aeson (Value(Array, Object), eitherDecodeStrict')
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.ByteString as ByteString
import qualified Data.Foldable as Foldable
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Read as TextRead
import O2I.Core.Contract (CoreRuleId, coreRuleIdText, coreRuleIds)
import O2I.Core.Identity (ModelIdentity, modelIdentity, modelIdentityText)
import O2I.Input.Internal.Decode
import O2I.Input.Internal.Json
import O2I.Input.Internal.Set
import O2I.Input.Internal.Text
import O2I.Input.Internal.Types
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core supplemental-input boundary"
    [ testCase "invalid UTF-8 fails before JSON syntax" invalidUtf8
    , testCase "public decoder preserves exact phase precedence" phasePrecedence
    , testCase "one complete JSON value is required" jsonSyntax
    , testCase "UTF-8 BOM is not silently discarded" jsonBom
    , testCase
        "decoded duplicate keys share one canonical site"
        escapedDuplicate
    , testCase
        "nested duplicate sites use escaped RFC 6901 pointers"
        nestedDuplicates
    , testCase
        "repeated parents retain each structural duplicate path once"
        repeatedParentDuplicates
    , testCase
        "member and index origins share one RFC 6901 pointer identity"
        memberIndexPointerIdentity
    , testCase
        "numeric and escaped collision families deduplicate before rendering"
        escapedPointerIdentity
    , testCase "duplicate-free JSON reaches typed decoding" duplicateFree
    , testCase
        "fachliche text follows the exact canonicalization order"
        canonicalText
    , testCase
        "fachliche text rejects forbidden controls and empty output"
        invalidText
    , testCase "Strategy formulation payload decodes completely" strategyInput
    , testCase "Collective Fit payload decodes completely" collectiveInput
    , testCase
        "payload-discriminator failure suppresses schema assessment"
        discriminatorSuppression
    , testCase
        "independent schema defects accumulate canonically"
        schemaAccumulation
    , testCase
        "wrong array kind suppresses cardinality and distinctness"
        arrayKindSuppression
    , testCase
        "canonical-equivalent fachliche set members are duplicates"
        canonicalSetCollision
    , testCase
        "supplemental subjects are unique per payload type"
        subjectUniqueness
    , testCase "valid surrogate pair becomes one scalar" validSurrogatePair
    , testCase
        "malformed surrogate identity retains every exact occurrence"
        malformedSurrogateIdentity
    , testCase
        "surrogate runs pair only adjacent high-low units"
        surrogateRunResolution
    , testCase "ModelIdentity NUL details retain every scalar index" identityNul
    , testCase "surrogate keys are JSON syntax failures" surrogateKeySyntax
    , testCase "malformed Unicode escape is JSON syntax" malformedUnicodeEscape
    , testCase
        "Fachliche text owns malformed-surrogate grammar failure"
        fachlicheSurrogateGrammar
    , testCase
        "discriminator surrogates remain admitted-type failures"
        discriminatorSurrogate
    , testCase
        "every schema-defect branch points into the exact companion schema"
        schemaPointerResolution
    , testCase "all nineteen named defect handlers are total" defectEliminator
    , testCase
        "all fifteen real decode and set defects retain exact Core rules"
        decodeAndSetRules
    , testCase
        "diagnostic details do not change stable defect identity"
        stableDefectIdentity
    , testCase
        "depth scales source visits and persistent path extensions only"
        depthWork
    , testCase "distinct duplicates render one pointer each" duplicateCountWork
    , testCase
        "long duplicate keys add only exact pointer-output cost"
        longKeyWork
    , testCase "long values add no pointer-rendering work" longValueWork
    ]

invalidUtf8 :: IO ()
invalidUtf8 = decodeUtf8Json (ByteString.pack [0xc3, 0x28]) @?= Left InvalidUtf8

phasePrecedence :: IO ()
phasePrecedence = do
  decodeSupplementalInput () ordinal (ByteString.pack [0xc3, 0x28])
    @?= Left (SupplementalInvalidUtf8Defect ordinal :| [])
  decode ordinal "{"
    @?= Left (SupplementalInvalidJsonSyntaxDefect ordinal :| [])
  defectKinds (decode ordinal "{\"x\":1,\"x\":2}")
    @?= [SupplementalDuplicateObjectMember]
  defectKinds (decode ordinal "[]") @?= [SupplementalTopLevelObjectRequired]
  defectKinds (decode ordinal "{}") @?= [SupplementalTypeMemberInvalid]
  defectKinds (decode ordinal "{\"type\":0}")
    @?= [SupplementalTypeMemberInvalid]
  where
    ordinal = SupplementalInputOrdinal 16

jsonSyntax :: IO ()
jsonSyntax = do
  parse "{\"value\":1} \n\t" @?= Right []
  parse "{\"value\":1} trailing" @?= Left InvalidJsonSyntax
  parse "{\"value\":}" @?= Left InvalidJsonSyntax

jsonBom :: IO ()
jsonBom = parse "\xfeff{}" @?= Left InvalidJsonSyntax

escapedDuplicate :: IO ()
escapedDuplicate = parse "{\"name\":1,\"\\u006eame\":2}" @?= Right ["/name"]

nestedDuplicates :: IO ()
nestedDuplicates =
  parse "{\"a/b\":{\"~key\":1,\"~key\":2},\"items\":[{\"x\":1,\"x\":2}]}"
    @?= Right ["/a~1b/~0key", "/items/0/x"]

repeatedParentDuplicates :: IO ()
repeatedParentDuplicates = do
  let source = "{\"a\":{\"x\":1,\"x\":2},\"a\":{\"x\":3,\"x\":4}}"
  parse source @?= Right ["/a", "/a/x"]
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= 6
  jsonDistinctDuplicateRetentions evidence @?= 2
  jsonDuplicatePointerRenderings evidence @?= 2
  jsonDuplicatePointerTokenScalarVisits evidence @?= 3

memberIndexPointerIdentity :: IO ()
memberIndexPointerIdentity = do
  let source =
        "{\"a\":{\"0\":{\"x\":1,\"x\":2}}," <> "\"a\":[{\"x\":1,\"x\":2}]}"
  parse source @?= Right ["/a", "/a/0/x"]
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= 8
  jsonDistinctDuplicateRetentions evidence @?= 2
  jsonDuplicatePointerRenderings evidence @?= 2
  jsonDuplicatePointerTokenScalarVisits evidence @?= 4

escapedPointerIdentity :: IO ()
escapedPointerIdentity = do
  let source =
        "{\"a\":{\"0\":{\"~\":1,\"\\u007e\":2}},"
          <> "\"\\u0061\":[{\"~\":3,\"\\u007e\":4}]}"
  parse source @?= Right ["/a", "/a/0/~0"]
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= 8
  jsonDistinctDuplicateRetentions evidence @?= 2
  jsonDuplicatePointerRenderings evidence @?= 2
  jsonDuplicatePointerTokenScalarVisits evidence @?= 4

duplicateFree :: IO ()
duplicateFree = parse "{\"a\":1,\"nested\":[true,null]}" @?= Right []

canonicalText :: IO ()
canonicalText = do
  canonical " \tCafe\x301\r\nLine\r " @?= Right "Caf\xe9\nLine"
  canonical "internal\tspace" @?= Right "internal\tspace"

invalidText :: IO ()
invalidText = do
  canonicalizeFachlicheText "value\x7f"
    @?= Left FachlicheTextContainsForbiddenControl
  canonicalizeFachlicheText " \t\r\n " @?= Left FachlicheTextIsEmpty

strategyInput :: IO ()
strategyInput =
  case decode (SupplementalInputOrdinal 0) (strategyJson "strategy-1") of
    Left defects -> fail (show defects)
    Right input -> do
      supplementalInputOrdinalOf input @?= SupplementalInputOrdinal 0
      supplementalInputType input @?= StrategyFormulationPayload
      modelIdentityText (supplementalInputSubject input) @?= "strategy-1"

collectiveInput :: IO ()
collectiveInput =
  case decode (SupplementalInputOrdinal 1) (collectiveJson "claim-1") of
    Left defects -> fail (show defects)
    Right input -> do
      supplementalInputOrdinalOf input @?= SupplementalInputOrdinal 1
      supplementalInputType input @?= CollectiveFitPayload
      modelIdentityText (supplementalInputSubject input) @?= "claim-1"

discriminatorSuppression :: IO ()
discriminatorSuppression =
  defectKinds
    (decode (SupplementalInputOrdinal 2) "{\"type\":\"Unknown\",\"extra\":true}")
    @?= [SupplementalPayloadTypeNotAdmitted]

schemaAccumulation :: IO ()
schemaAccumulation = do
  let result =
        decode
          (SupplementalInputOrdinal 3)
          "{\"type\":\"StrategyFormulationInput\",\"strategy\":7,\"extra\":true}"
  defectKinds result
    @?= [ SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalRequiredMemberMissing
        , SupplementalUnknownMember
        , SupplementalValueKindInvalid
        ]
  schemaInstancePointers result
    @?= [ "/actions"
        , "/anchoring"
        , "/derivedGuardrails"
        , "/diagnosis"
        , "/fitRationale"
        , "/guidingPolicy"
        , "/intent"
        , "/keyResults"
        , "/positioning"
        , "/scope"
        , "/tradeOffs"
        , "/extra"
        , "/strategy"
        ]

arrayKindSuppression :: IO ()
arrayKindSuppression =
  defectKinds
    (decode
       (SupplementalInputOrdinal 4)
       (Text.replace
          "\"participants\":[\"strategy-a\",\"strategy-b\"]"
          "\"participants\":\"strategy-a\""
          (collectiveJson "claim-2")))
    @?= [SupplementalValueKindInvalid]

canonicalSetCollision :: IO ()
canonicalSetCollision =
  defectKinds
    (decode
       (SupplementalInputOrdinal 5)
       (Text.replace
          "\"tradeOffs\":[\"trade-off\"]"
          "\"tradeOffs\":[\"Caf\\u00e9\",\"Cafe\\u0301\"]"
          (strategyJson "strategy-2")))
    @?= [SupplementalArrayDistinctnessInvalid]

subjectUniqueness :: IO ()
subjectUniqueness = do
  first <-
    accepted (decode (SupplementalInputOrdinal 9) (strategyJson "strategy-3"))
  second <-
    accepted (decode (SupplementalInputOrdinal 7) (strategyJson "strategy-3"))
  collective <-
    accepted (decode (SupplementalInputOrdinal 8) (collectiveJson "strategy-3"))
  case assessSupplementalInputSet [first, collective, second] of
    Right _ -> fail "duplicate Strategy formulation subject was accepted"
    Left defects ->
      NonEmpty.toList defects
        @?= [ SupplementalSubjectCardinalityInvalidDefect
                StrategyFormulationPayload
                (supplementalInputSubject first)
                (SupplementalInputOrdinal 7)
                (SupplementalInputOrdinal 9 :| [])
            ]

validSurrogatePair :: IO ()
validSurrogatePair = do
  input <-
    accepted
      (decode
         (SupplementalInputOrdinal 10)
         (strategyJson "strategy-\\uD83D\\uDE00"))
  modelIdentityText (supplementalInputSubject input) @?= "strategy-\x1f600"

malformedSurrogateIdentity :: IO ()
malformedSurrogateIdentity =
  case decode (SupplementalInputOrdinal 11) (strategyJson "\\uDC00\\uD800x") of
    Right _ -> fail "malformed surrogate identity was accepted"
    Left defects ->
      [ (pointer, details)
      | SupplementalModelIdentityUnicodeScalarInvalidDefect _ pointer _ details <-
          NonEmpty.toList defects
      ]
        @?= [ ( "/strategy"
              , SupplementalUnicodeScalarOccurrence 0 0xdc00
                  :| [SupplementalUnicodeScalarOccurrence 1 0xd800])
            ]

surrogateRunResolution :: IO ()
surrogateRunResolution = do
  unicodeOccurrences
    (decode (SupplementalInputOrdinal 14) (strategyJson "\\uD800\\uD801\\uDC00"))
    @?= [SupplementalUnicodeScalarOccurrence 0 0xd800 :| []]
  unicodeOccurrences
    (decode (SupplementalInputOrdinal 15) (strategyJson "\\uD800\\u0061"))
    @?= [SupplementalUnicodeScalarOccurrence 0 0xd800 :| []]

identityNul :: IO ()
identityNul =
  case decode (SupplementalInputOrdinal 17) (strategyJson "a\\u0000b\\u0000") of
    Right _ -> fail "NUL-containing ModelIdentity was accepted"
    Left defects ->
      [ indexes
      | SupplementalModelIdentityContainsNulDefect _ pointer _ indexes <-
          NonEmpty.toList defects
      , pointer == "/strategy"
      ]
        @?= [1 :| [3]]

unicodeOccurrences ::
     Either (NonEmpty SupplementalInputDefect) value
  -> [NonEmpty SupplementalUnicodeScalarOccurrence]
unicodeOccurrences result =
  case result of
    Left defects ->
      [ details
      | SupplementalModelIdentityUnicodeScalarInvalidDefect _ _ _ details <-
          NonEmpty.toList defects
      ]
    Right _ -> []

surrogateKeySyntax :: IO ()
surrogateKeySyntax = parse "{\"\\uD800\":1}" @?= Left InvalidJsonSyntax

malformedUnicodeEscape :: IO ()
malformedUnicodeEscape = parse "\"\\uD80X\"" @?= Left InvalidJsonSyntax

fachlicheSurrogateGrammar :: IO ()
fachlicheSurrogateGrammar =
  defectKinds
    (decode
       (SupplementalInputOrdinal 12)
       (Text.replace
          "\"scope\":[\"scope\"]"
          "\"scope\":[\"\\uD800\"]"
          (strategyJson "strategy-4")))
    @?= [SupplementalScalarGrammarInvalid]

discriminatorSurrogate :: IO ()
discriminatorSurrogate =
  defectKinds (decode (SupplementalInputOrdinal 13) "{\"type\":\"\\uD800\"}")
    @?= [SupplementalPayloadTypeNotAdmitted]

schemaPointerResolution :: IO ()
schemaPointerResolution = do
  typeMemberPointers @?= ["#"]
  admittedTypePointers @?= ["#"]
  Set.fromList (map fst evidence) @?= expectedKinds
  contractBytes <- ByteString.readFile "semantics.json"
  contract <-
    either fail pure (eitherDecodeStrict' contractBytes :: Either String Value)
  schema <-
    case contract of
      Object members ->
        case AesonKeyMap.lookup "supplementalInputSchema" members of
          Nothing -> fail "the exact Core companion has no supplemental schema"
          Just value -> pure value
      _ -> fail "the exact Core companion is not a JSON object"
  case resolveJsonPointer schema "#/oneOf/0/$ref" of
    Nothing -> fail "the resolver did not traverse the companion schema array"
    Just _ -> pure ()
  unescapePointerToken "~0~1" @?= Just "~/"
  forM_ evidence $ \(kind, pointer) ->
    case resolveJsonPointer schema pointer of
      Nothing ->
        fail
          ("schema pointer does not resolve for "
             <> show kind
             <> ": "
             <> Text.unpack pointer)
      Just _ -> pure ()
  where
    typeMemberPointers =
      schemaPointers (decode (SupplementalInputOrdinal 18) "{}")
    admittedTypePointers =
      schemaPointers
        (decode (SupplementalInputOrdinal 19) "{\"type\":\"Unknown\"}")
    evidence = concatMap schemaEvidence branchResults
    branchResults =
      [ decode (SupplementalInputOrdinal 20) "[]"
      , decode (SupplementalInputOrdinal 21) "{}"
      , decode (SupplementalInputOrdinal 22) "{\"type\":\"Unknown\"}"
      , decode
          (SupplementalInputOrdinal 23)
          "{\"type\":\"StrategyFormulationInput\",\"strategy\":7,\"extra\":true}"
      , decode
          (SupplementalInputOrdinal 24)
          (Text.replace
             "\"scope\":[\"scope\"]"
             "\"scope\":[]"
             (strategyJson "strategy-cardinality"))
      , decode
          (SupplementalInputOrdinal 25)
          (Text.replace
             "\"tradeOffs\":[\"trade-off\"]"
             "\"tradeOffs\":[\"Caf\\u00e9\",\"Cafe\\u0301\"]"
             (strategyJson "strategy-distinctness"))
      , decode
          (SupplementalInputOrdinal 26)
          (Text.replace
             "\"scope\":[\"scope\"]"
             "\"scope\":[\"\\uD800\"]"
             (strategyJson "strategy-text"))
      , decode (SupplementalInputOrdinal 27) (strategyJson "\\uD800")
      , decode (SupplementalInputOrdinal 28) (strategyJson "identity\\u0000")
      ]
    expectedKinds =
      Set.fromList
        [ SupplementalTopLevelObjectRequired
        , SupplementalTypeMemberInvalid
        , SupplementalPayloadTypeNotAdmitted
        , SupplementalRequiredMemberMissing
        , SupplementalUnknownMember
        , SupplementalValueKindInvalid
        , SupplementalScalarGrammarInvalid
        , SupplementalArrayCardinalityInvalid
        , SupplementalArrayDistinctnessInvalid
        , SupplementalModelIdentityUnicodeScalarInvalid
        , SupplementalModelIdentityContainsNul
        ]

schemaPointers :: Either (NonEmpty SupplementalInputDefect) value -> [Text]
schemaPointers = map snd . schemaEvidence

schemaEvidence ::
     Either (NonEmpty SupplementalInputDefect) value
  -> [(SupplementalInputDefectKind, Text)]
schemaEvidence result =
  case result of
    Left defects -> mapMaybe schemaDefectEvidence (NonEmpty.toList defects)
    Right _ -> []

schemaDefectEvidence ::
     SupplementalInputDefect -> Maybe (SupplementalInputDefectKind, Text)
schemaDefectEvidence defect =
  case defect of
    SupplementalTopLevelObjectRequiredDefect _ _ schema -> present schema
    SupplementalTypeMemberInvalidDefect _ _ schema -> present schema
    SupplementalPayloadTypeNotAdmittedDefect _ _ schema -> present schema
    SupplementalRequiredMemberMissingDefect _ _ schema -> present schema
    SupplementalUnknownMemberDefect _ _ schema -> present schema
    SupplementalValueKindInvalidDefect _ _ schema -> present schema
    SupplementalScalarGrammarInvalidDefect _ _ schema -> present schema
    SupplementalArrayCardinalityInvalidDefect _ _ schema -> present schema
    SupplementalArrayDistinctnessInvalidDefect _ _ schema -> present schema
    SupplementalModelIdentityUnicodeScalarInvalidDefect _ _ schema _ ->
      present schema
    SupplementalModelIdentityContainsNulDefect _ _ schema _ -> present schema
    SupplementalInvalidUtf8Defect _ -> Nothing
    SupplementalInvalidJsonSyntaxDefect _ -> Nothing
    SupplementalDuplicateObjectMemberDefect _ _ -> Nothing
    SupplementalSubjectCardinalityInvalidDefect _ _ _ _ -> Nothing
    SupplementalIdentityUnknownDefect _ _ _ -> Nothing
    SupplementalIdentityAmbiguousDefect _ _ _ -> Nothing
    SupplementalIdentityWrongTypeDefect _ _ _ -> Nothing
    SupplementalIdentityOutOfSelectedViewDefect _ _ _ -> Nothing
  where
    present schema = Just (supplementalInputDefectKind defect, schema)

resolveJsonPointer :: Value -> Text -> Maybe Value
resolveJsonPointer root pointer
  | pointer == "#" = Just root
  | otherwise = do
    suffix <- Text.stripPrefix "#/" pointer
    tokens <- traverse unescapePointerToken (Text.splitOn "/" suffix)
    foldM resolveToken root tokens

resolveToken :: Value -> Text -> Maybe Value
resolveToken value token =
  case value of
    Object members -> AesonKeyMap.lookup (AesonKey.fromText token) members
    Array members -> do
      index <- parseArrayIndex token
      case drop index (Foldable.toList members) of
        resolved:_ -> Just resolved
        [] -> Nothing
    _ -> Nothing

parseArrayIndex :: Text -> Maybe Int
parseArrayIndex token
  | token == "0" = Just 0
  | Text.null token || Text.head token == '0' = Nothing
  | otherwise =
    case TextRead.decimal token :: Either String (Integer, Text) of
      Right (value, rest)
        | Text.null rest
        , value <= fromIntegral (maxBound :: Int) -> Just (fromInteger value)
      _ -> Nothing

unescapePointerToken :: Text -> Maybe Text
unescapePointerToken = fmap (Text.pack . reverse) . unescape [] . Text.unpack
  where
    unescape result source =
      case source of
        [] -> Just result
        '~':'0':remaining -> unescape ('~' : result) remaining
        '~':'1':remaining -> unescape ('/' : result) remaining
        '~':_ -> Nothing
        value:remaining -> unescape (value : result) remaining

defectEliminator :: IO ()
defectEliminator =
  map (foldSupplementalInputDefect eliminator) defectExamples
    @?= [(0 :: Int) .. 18]
  where
    eliminator =
      SupplementalInputDefectEliminator
        { eliminateSupplementalInvalidUtf8 = const 0
        , eliminateSupplementalInvalidJsonSyntax = const 1
        , eliminateSupplementalDuplicateObjectMember = const 2
        , eliminateSupplementalTopLevelObjectRequired = const 3
        , eliminateSupplementalTypeMemberInvalid = const 4
        , eliminateSupplementalPayloadTypeNotAdmitted = const 5
        , eliminateSupplementalRequiredMemberMissing = const 6
        , eliminateSupplementalUnknownMember = const 7
        , eliminateSupplementalValueKindInvalid = const 8
        , eliminateSupplementalScalarGrammarInvalid = const 9
        , eliminateSupplementalArrayCardinalityInvalid = const 10
        , eliminateSupplementalArrayDistinctnessInvalid = const 11
        , eliminateSupplementalSubjectCardinalityInvalid = const 12
        , eliminateSupplementalIdentityUnknown = const 13
        , eliminateSupplementalIdentityAmbiguous = const 14
        , eliminateSupplementalIdentityWrongType = const 15
        , eliminateSupplementalIdentityOutOfSelectedView = const 16
        , eliminateSupplementalModelIdentityUnicodeScalarInvalid = const 17
        , eliminateSupplementalModelIdentityContainsNul = const 18
        }

decodeAndSetRules :: IO ()
decodeAndSetRules = do
  defects <- realDecodeAndSetDefects
  let actual = map supplementalInputDefectRule defects
      expected = map exactCoreRule expectedRuleTexts
  actual @?= expected
  if actual == drop 1 expected ++ take 1 expected
    then fail "a Supplemental rule permutation preserved exact associations"
    else pure ()
  where
    expectedRuleTexts =
      [ "core.supplemental.decode.utf8"
      , "core.supplemental.decode.json-syntax"
      , "core.supplemental.decode.duplicate-member"
      , "core.supplemental.schema.top-level-object"
      , "core.supplemental.schema.type-member"
      , "core.supplemental.schema.admitted-type"
      , "core.supplemental.schema.required-member"
      , "core.supplemental.schema.unknown-member"
      , "core.supplemental.schema.value-kind"
      , "core.supplemental.schema.scalar-grammar"
      , "core.supplemental.schema.array-cardinality"
      , "core.supplemental.schema.array-distinctness"
      , "core.supplemental.subject.cardinality"
      , "core.supplemental.schema.model-identity.unicode-scalar"
      , "core.supplemental.schema.model-identity.nul"
      ]

realDecodeAndSetDefects :: IO [SupplementalInputDefect]
realDecodeAndSetDefects = do
  subjectFirst <-
    accepted (decode (SupplementalInputOrdinal 13) (strategyJson "duplicate"))
  subjectSecond <-
    accepted (decode (SupplementalInputOrdinal 14) (strategyJson "duplicate"))
  sequence
    [ selectDefect
        SupplementalInvalidUtf8
        (decodeSupplementalInput
           ()
           (SupplementalInputOrdinal 0)
           (ByteString.pack [0xc3, 0x28]))
    , selectDefect
        SupplementalInvalidJsonSyntax
        (decode (SupplementalInputOrdinal 1) "{")
    , selectDefect
        SupplementalDuplicateObjectMember
        (decode (SupplementalInputOrdinal 2) "{\"x\":1,\"x\":2}")
    , selectDefect
        SupplementalTopLevelObjectRequired
        (decode (SupplementalInputOrdinal 3) "[]")
    , selectDefect
        SupplementalTypeMemberInvalid
        (decode (SupplementalInputOrdinal 4) "{}")
    , selectDefect
        SupplementalPayloadTypeNotAdmitted
        (decode (SupplementalInputOrdinal 5) "{\"type\":\"Unknown\"}")
    , selectDefect
        SupplementalRequiredMemberMissing
        (decode
           (SupplementalInputOrdinal 6)
           (Text.replace
              ",\"fitRationale\":[\"rationale\"]"
              ""
              (strategyJson "required")))
    , selectDefect
        SupplementalUnknownMember
        (decode
           (SupplementalInputOrdinal 7)
           (Text.dropEnd 1 (strategyJson "unknown") <> ",\"extra\":true}"))
    , selectDefect
        SupplementalValueKindInvalid
        (decode
           (SupplementalInputOrdinal 8)
           (Text.replace
              "\"strategy\":\"value-kind\""
              "\"strategy\":7"
              (strategyJson "value-kind")))
    , selectDefect
        SupplementalScalarGrammarInvalid
        (decode
           (SupplementalInputOrdinal 9)
           (Text.replace
              "\"scope\":[\"scope\"]"
              "\"scope\":[\"\\uD800\"]"
              (strategyJson "scalar")))
    , selectDefect
        SupplementalArrayCardinalityInvalid
        (decode
           (SupplementalInputOrdinal 10)
           (Text.replace
              "\"scope\":[\"scope\"]"
              "\"scope\":[]"
              (strategyJson "cardinality")))
    , selectDefect
        SupplementalArrayDistinctnessInvalid
        (decode
           (SupplementalInputOrdinal 11)
           (Text.replace
              "\"tradeOffs\":[\"trade-off\"]"
              "\"tradeOffs\":[\"Caf\\u00e9\",\"Cafe\\u0301\"]"
              (strategyJson "distinctness")))
    , selectDefect
        SupplementalSubjectCardinalityInvalid
        (assessSupplementalInputSet [subjectFirst, subjectSecond])
    , selectDefect
        SupplementalModelIdentityUnicodeScalarInvalid
        (decode (SupplementalInputOrdinal 15) (strategyJson "\\uD800"))
    , selectDefect
        SupplementalModelIdentityContainsNul
        (decode (SupplementalInputOrdinal 16) (strategyJson "nul\\u0000"))
    ]

selectDefect ::
     SupplementalInputDefectKind
  -> Either (NonEmpty SupplementalInputDefect) value
  -> IO SupplementalInputDefect
selectDefect expected result =
  case result of
    Right _ -> fail ("expected Supplemental defect " ++ show expected)
    Left defects ->
      case filter
             ((== expected) . supplementalInputDefectKind)
             (NonEmpty.toList defects) of
        [defect] -> pure defect
        matches ->
          fail
            ("expected one Supplemental defect "
               ++ show expected
               ++ ", got "
               ++ show matches)

exactCoreRule :: Text -> CoreRuleId
exactCoreRule identifier =
  case filter ((== identifier) . coreRuleIdText) (NonEmpty.toList coreRuleIds) of
    [rule] -> rule
    rules ->
      error
        ("expected one Core rule " ++ show identifier ++ ", got " ++ show rules)

stableDefectIdentity :: IO ()
stableDefectIdentity = do
  firstSubject == secondSubject @?= True
  compare firstSubject secondSubject @?= EQ
  show firstSubject == show secondSubject @?= False
  firstUnicode == secondUnicode @?= True
  compare firstUnicode secondUnicode @?= EQ
  show firstUnicode == show secondUnicode @?= False
  where
    firstSubject =
      SupplementalSubjectCardinalityInvalidDefect
        StrategyFormulationPayload
        exampleIdentity
        (SupplementalInputOrdinal 1)
        (SupplementalInputOrdinal 3 :| [])
    secondSubject =
      SupplementalSubjectCardinalityInvalidDefect
        StrategyFormulationPayload
        exampleIdentity
        (SupplementalInputOrdinal 2)
        (SupplementalInputOrdinal 4 :| [])
    firstUnicode =
      SupplementalModelIdentityUnicodeScalarInvalidDefect
        (SupplementalInputOrdinal 0)
        "/strategy"
        "#/$defs/ModelIdentity"
        (SupplementalUnicodeScalarOccurrence 0 0xd800 :| [])
    secondUnicode =
      SupplementalModelIdentityUnicodeScalarInvalidDefect
        (SupplementalInputOrdinal 0)
        "/strategy"
        "#/$defs/ModelIdentity"
        (SupplementalUnicodeScalarOccurrence 1 0xdfff :| [])

defectExamples :: [SupplementalInputDefect]
defectExamples =
  [ SupplementalInvalidUtf8Defect ordinal
  , SupplementalInvalidJsonSyntaxDefect ordinal
  , SupplementalDuplicateObjectMemberDefect ordinal "/duplicate"
  , SupplementalTopLevelObjectRequiredDefect ordinal "" "#"
  , SupplementalTypeMemberInvalidDefect ordinal "/type" "#/type"
  , SupplementalPayloadTypeNotAdmittedDefect ordinal "/type" "#/type"
  , SupplementalRequiredMemberMissingDefect ordinal "/missing" "#/required"
  , SupplementalUnknownMemberDefect ordinal "/unknown" "#/additionalProperties"
  , SupplementalValueKindInvalidDefect ordinal "/value" "#/properties/value"
  , SupplementalScalarGrammarInvalidDefect ordinal "/scalar" "#/$defs/Scalar"
  , SupplementalArrayCardinalityInvalidDefect ordinal "/array" "#/minItems"
  , SupplementalArrayDistinctnessInvalidDefect ordinal "/array" "#/uniqueItems"
  , SupplementalSubjectCardinalityInvalidDefect
      StrategyFormulationPayload
      exampleIdentity
      ordinal
      (SupplementalInputOrdinal 1 :| [])
  , SupplementalIdentityUnknownDefect ordinal "/identity" exampleIdentity
  , SupplementalIdentityAmbiguousDefect ordinal "/identity" exampleIdentity
  , SupplementalIdentityWrongTypeDefect ordinal "/identity" exampleIdentity
  , SupplementalIdentityOutOfSelectedViewDefect
      ordinal
      "/identity"
      exampleIdentity
  , SupplementalModelIdentityUnicodeScalarInvalidDefect
      ordinal
      "/identity"
      "#/$defs/ModelIdentity"
      (SupplementalUnicodeScalarOccurrence 0 0xd800 :| [])
  , SupplementalModelIdentityContainsNulDefect
      ordinal
      "/identity"
      "#/$defs/ModelIdentity"
      (0 :| [])
  ]
  where
    ordinal = SupplementalInputOrdinal 0

exampleIdentity :: ModelIdentity
exampleIdentity =
  case modelIdentity "example" of
    Left failure -> error (show failure)
    Right value -> value

depthWork :: IO ()
depthWork = do
  let depth = 256
      source = Text.replicate depth "[" <> "0" <> Text.replicate depth "]"
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= depth
  jsonDistinctDuplicateRetentions evidence @?= 0
  jsonValueVisits evidence @?= depth + 1
  jsonDuplicatePointerRenderings evidence @?= 0
  jsonDuplicatePointerTokenScalarVisits evidence @?= 0

duplicateCountWork :: IO ()
duplicateCountWork = do
  let count = 128
      member index =
        let key = "k" <> Text.pack (show index)
         in "\"" <> key <> "\":0,\"" <> key <> "\":1"
      source = "{" <> Text.intercalate "," (map member [0 .. count - 1]) <> "}"
      expectedTokenVisits =
        sum
          [ Text.length ("k" <> Text.pack (show index))
          | index <- [0 .. count - 1]
          ]
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= 2 * count
  jsonDistinctDuplicateRetentions evidence @?= count
  jsonDuplicatePointerRenderings evidence @?= count
  jsonDuplicatePointerTokenScalarVisits evidence @?= expectedTokenVisits

longKeyWork :: IO ()
longKeyWork = do
  let key = Text.replicate 8192 "k"
      source = "{\"" <> key <> "\":0,\"" <> key <> "\":1}"
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonPathExtensions evidence @?= 2
  jsonDistinctDuplicateRetentions evidence @?= 1
  jsonDuplicatePointerRenderings evidence @?= 1
  jsonDuplicatePointerTokenScalarVisits evidence @?= Text.length key

longValueWork :: IO ()
longValueWork = do
  let value = Text.replicate 32768 "v"
      source = "{\"value\":\"" <> value <> "\"}"
  evidence <- work source
  jsonSourceScalarVisits evidence @?= Text.length source
  jsonDecodedScalarRetentions evidence @?= Text.length "value"
    + Text.length value
  jsonPathExtensions evidence @?= 1
  jsonDistinctDuplicateRetentions evidence @?= 0
  jsonDuplicatePointerRenderings evidence @?= 0

work :: Text -> IO JsonWork
work source =
  case decodeUtf8Json (encode source) of
    Left failure -> fail (show failure)
    Right utf8 ->
      case parseJsonSyntaxWithWork utf8 of
        Left failure -> fail (show failure)
        Right (_, evidence) -> pure evidence

parse :: Text -> Either JsonSyntaxFailure [Text]
parse source = do
  utf8 <-
    either
      (const (Left InvalidJsonSyntax))
      Right
      (decodeUtf8Json (encode source))
  parsed <- parseJsonSyntax utf8
  case rejectDuplicateMembers parsed of
    Left sites -> Right (map jsonPointerText (toList sites))
    Right _ -> Right []

canonical :: Text -> Either FachlicheTextFailure Text
canonical source = canonicalFachlicheText <$> canonicalizeFachlicheText source

encode :: Text -> ByteString.ByteString
encode = TextEncoding.encodeUtf8

decode ::
     SupplementalInputOrdinal
  -> Text
  -> Either (NonEmpty SupplementalInputDefect) (SupplementalInput ())
decode ordinal = decodeSupplementalInput () ordinal . encode

accepted :: Either (NonEmpty SupplementalInputDefect) value -> IO value
accepted result =
  case result of
    Left defects -> fail (show defects)
    Right value -> pure value

defectKinds ::
     Either (NonEmpty SupplementalInputDefect) value
  -> [SupplementalInputDefectKind]
defectKinds result =
  case result of
    Left defects -> map supplementalInputDefectKind (NonEmpty.toList defects)
    Right _ -> []

schemaInstancePointers ::
     Either (NonEmpty SupplementalInputDefect) value -> [Text]
schemaInstancePointers result =
  case result of
    Left defects -> mapMaybe schemaInstancePointer (NonEmpty.toList defects)
    Right _ -> []

schemaInstancePointer :: SupplementalInputDefect -> Maybe Text
schemaInstancePointer defect =
  case defect of
    SupplementalTopLevelObjectRequiredDefect _ pointer _ -> Just pointer
    SupplementalTypeMemberInvalidDefect _ pointer _ -> Just pointer
    SupplementalPayloadTypeNotAdmittedDefect _ pointer _ -> Just pointer
    SupplementalRequiredMemberMissingDefect _ pointer _ -> Just pointer
    SupplementalUnknownMemberDefect _ pointer _ -> Just pointer
    SupplementalValueKindInvalidDefect _ pointer _ -> Just pointer
    SupplementalScalarGrammarInvalidDefect _ pointer _ -> Just pointer
    SupplementalArrayCardinalityInvalidDefect _ pointer _ -> Just pointer
    SupplementalArrayDistinctnessInvalidDefect _ pointer _ -> Just pointer
    SupplementalModelIdentityUnicodeScalarInvalidDefect _ pointer _ _ ->
      Just pointer
    SupplementalModelIdentityContainsNulDefect _ pointer _ _ -> Just pointer
    SupplementalInvalidUtf8Defect _ -> Nothing
    SupplementalInvalidJsonSyntaxDefect _ -> Nothing
    SupplementalDuplicateObjectMemberDefect _ _ -> Nothing
    SupplementalSubjectCardinalityInvalidDefect _ _ _ _ -> Nothing
    SupplementalIdentityUnknownDefect _ _ _ -> Nothing
    SupplementalIdentityAmbiguousDefect _ _ _ -> Nothing
    SupplementalIdentityWrongTypeDefect _ _ _ -> Nothing
    SupplementalIdentityOutOfSelectedViewDefect _ _ _ -> Nothing

strategyJson :: Text -> Text
strategyJson strategy =
  Text.concat
    [ "{\"type\":\"StrategyFormulationInput\",\"strategy\":\""
    , strategy
    , "\",\"scope\":[\"scope\"],"
    , "\"anchoring\":{\"period\":\"2026\","
    , "\"responsibilityScope\":\"enterprise\","
    , "\"decisionLevel\":\"strategic\","
    , "\"responsibilities\":[\"responsibility\"],"
    , "\"decisionPaths\":[\"path\"],"
    , "\"implementationLogic\":\"logic\"},"
    , "\"derivedGuardrails\":[\"guardrail\"],"
    , "\"diagnosis\":\"driver-1\",\"intent\":\"objective-1\","
    , "\"guidingPolicy\":\"principle-1\","
    , "\"positioning\":[\"position\"],"
    , "\"tradeOffs\":[\"trade-off\"],"
    , "\"actions\":[\"action-1\"],"
    , "\"keyResults\":[\"key-result-1\"],"
    , "\"fitRationale\":[\"rationale\"]}"
    ]

collectiveJson :: Text -> Text
collectiveJson claim =
  Text.concat
    [ "{\"type\":\"CollectiveFitInput\",\"claim\":\""
    , claim
    , "\",\"participants\":[\"strategy-a\",\"strategy-b\"],"
    , "\"target\":\"strategy-target\","
    , "\"targetGuidingPolicy\":\"principle-target\","
    , "\"targetTradeOffs\":[\"trade-off\"],"
    , "\"pairwiseCoherence\":[{\"participantA\":\"strategy-a\","
    , "\"participantB\":\"strategy-b\",\"rationale\":\"coherent\"}],"
    , "\"participantCompatibility\":["
    , "{\"participant\":\"strategy-a\","
    , "\"guidingPolicyRationale\":\"compatible\","
    , "\"tradeOffRationale\":\"accepted\"},"
    , "{\"participant\":\"strategy-b\","
    , "\"guidingPolicyRationale\":\"compatible\","
    , "\"tradeOffRationale\":\"accepted\"}],"
    , "\"contributionInteraction\":[\"joint contribution\"]}"
    ]

toList :: NonEmpty value -> [value]
toList (first :| rest) = first : rest
