{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.BuildProvenance
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit

main :: IO ()
main =
  defaultMain
    (testGroup
       "o2i-build-provenance"
       [ testCase "accepts Git SHA-1"
           $ assertAccepted
               "0123456789abcdef0123456789abcdef01234567"
               "0123456789abcdef0123456789abcdef01234567"
       , testCase "accepts and normalizes Git SHA-256"
           $ assertAccepted
               "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
               "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
       , testCase "rejects abbreviated revisions"
           $ assertRejected "0123456789ab"
       , testCase "rejects non-hexadecimal revisions"
           $ assertRejected "g123456789abcdef0123456789abcdef01234567"
       ])

assertAccepted :: String -> String -> Assertion
assertAccepted input expected =
  case parseBuildRevision (fromString input) of
    Left issue -> assertFailure ("unexpected rejection: " <> show issue)
    Right revision -> buildRevisionText revision @?= fromString expected

assertRejected :: String -> Assertion
assertRejected input =
  case parseBuildRevision (fromString input) of
    Left InvalidGeneratedProvenance -> pure ()
    Left issue -> assertFailure ("unexpected issue: " <> show issue)
    Right revision -> assertFailure ("unexpected acceptance: " <> show revision)

fromString :: String -> Text
fromString = Text.pack
