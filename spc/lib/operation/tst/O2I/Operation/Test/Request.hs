{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Request
  ( tests
  ) where

import Data.Text (Text)
import O2I.Operation.Provenance
import O2I.Operation.Request
import O2I.Operation.View
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "request"
    [ testCase "enumerates every closed capability" capabilityCases
    , testCase "keeps capability-owned references exact" referenceCases
    , testCase "keeps the mandatory View selector exact" selectorCase
    , testCase "folds every request field" requestFoldCase
    ]

capabilityCases :: Assertion
capabilityCases = do
  fmap capabilityIdentityText capabilities
    @?= ["validate", "trace", "qualify", "readiness", "assess"]
  fmap capabilityTag capabilities @?= [0, 1, 2, 3, 4]
  where
    capabilities =
      [ validationCapability
      , traceCapability
      , qualificationCapability
      , readinessCapability
      , assessmentCapability
      ]
    capabilityTag :: CapabilityIdentity -> Int
    capabilityTag = foldCapabilityIdentity 0 1 2 3 4

referenceCases :: Assertion
referenceCases = do
  first <- reference "first"
  second <- reference "second"
  let selector = viewByName "Target"
      requests =
        [ validationRequest selector [first, second]
        , traceRequest selector
        , qualificationRequest selector [first, second]
        , readinessRequest selector first [second]
        , assessmentRequest selector first [second]
        ]
  fmap (referenceTexts . requestedInputs) requests
    @?= [ ["first", "second"]
        , []
        , ["first", "second"]
        , ["first", "second"]
        , ["first", "second"]
        ]
  fmap inputTag (fmap requestedInputs requests) @?= [0, 1, 2, 3, 4]
  where
    inputTag :: CapabilityInputReferences -> Int
    inputTag =
      foldCapabilityInputReferences
        (const 0)
        1
        (const 2)
        (\_ _ -> 3)
        (\_ _ -> 4)

selectorCase :: Assertion
selectorCase = do
  let request = traceRequest (viewByName "Exact View")
  selectorText (requestedViewSelector request) @?= "Exact View"
  where
    selectorText = foldViewSelector id (const "unexpected-identity")

requestFoldCase :: Assertion
requestFoldCase = do
  input <- reference "qualification-input"
  let request = qualificationRequest (viewByName "Target") [input]
      projected =
        foldRequestedContract
          (\selector references -> projection "validate" selector references)
          (\selector -> projection "trace" selector [])
          (\selector references -> projection "qualify" selector references)
          (\selector primary references ->
             projection "readiness" selector (primary : references))
          (\selector primary references ->
             projection "assess" selector (primary : references))
          request
  projected @?= ("qualify", "Target", ["qualification-input"])
  where
    selectorText = foldViewSelector id (const "unexpected-identity")
    projection ::
         Text -> ViewSelector -> [SourceReference] -> (Text, Text, [Text])
    projection capability selector references =
      (capability, selectorText selector, fmap sourceReferenceText references)

referenceTexts :: CapabilityInputReferences -> [Text]
referenceTexts = fmap sourceReferenceText . capabilityInputReferences

reference :: Text -> IO SourceReference
reference value =
  case mkSourceReference value of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right result -> pure result
