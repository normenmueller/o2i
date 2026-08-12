{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import qualified Data.ByteString as ByteString
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Core.Identity (modelIdentityText)
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
    , testCase "one complete JSON value is required" jsonSyntax
    , testCase "UTF-8 BOM is not silently discarded" jsonBom
    , testCase
        "decoded duplicate keys share one canonical site"
        escapedDuplicate
    , testCase
        "nested duplicate sites use escaped RFC 6901 pointers"
        nestedDuplicates
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
    ]

invalidUtf8 :: IO ()
invalidUtf8 = decodeUtf8Json (ByteString.pack [0xc3, 0x28]) @?= Left InvalidUtf8

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
        @?= [ SupplementalInputDefect
                SupplementalSubjectCardinalityInvalid
                (SupplementalSubjectKey
                   StrategyFormulationPayload
                   (supplementalInputSubject first)
                   (SupplementalInputOrdinal 7 :| [SupplementalInputOrdinal 9]))
            ]

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
  -> Either (NonEmpty SupplementalInputDefect) SupplementalInput
decode ordinal = decodeSupplementalInput ordinal . encode

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
    Left defects ->
      [ instancePointer
      | SupplementalInputDefect _ (SupplementalSchemaKey _ instancePointer _) <-
          NonEmpty.toList defects
      ]
    Right _ -> []

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
