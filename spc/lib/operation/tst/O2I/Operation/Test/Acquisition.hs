{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Acquisition
  ( tests
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.IORef
import O2I.Operation.Acquisition
import O2I.Operation.Acquisition.Internal (acquireWith)
import O2I.Operation.Provenance
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "acquisition"
    [ testCase "file bytes are acquired exactly once" fileAcquiredOnceTest
    , testCase "standard input is acquired exactly once" stdinAcquiredOnceTest
    , testCase "admits only an acquired model role to preparation" modelRoleTest
    , testCase "file paths are validated explicitly" filePathValidationTest
    , testCase
        "IO failures preserve source and exception"
        acquisitionFailureTest
    ]

fileAcquiredOnceTest :: Assertion
fileAcquiredOnceTest = do
  calls <- newIORef (0 :: Int)
  input <- requireRight (fileInput reference "model.archimate")
  result <-
    acquireWith
      (countedRead calls "model.archimate" exactBytes)
      (assertFailure "standard input reader was selected"
         >> pure ByteString.empty)
      ModelRole
      (sourceOrdinal 0)
      input
  acquired <- requireRight result
  readIORef calls >>= (@?= 1)
  acquiredSourceBytes acquired @?= exactBytes
  let identity = acquiredSourceIdentity acquired
  sourceIdentityRole identity @?= ModelRole
  sourceOrdinalValue (sourceIdentityOrdinal identity) @?= 0
  sourceReferenceText (sourceIdentityReference identity) @?= "model"
  sourceSha256Text (sourceIdentitySha256 identity)
    @?= "3a100994c4e38751871e6e8eef9adad2b20177fdeaf650daacdcd74f4c9421e3"

stdinAcquiredOnceTest :: Assertion
stdinAcquiredOnceTest = do
  calls <- newIORef (0 :: Int)
  let input = standardInput reference
  result <-
    acquireWith
      (\_ -> assertFailure "file reader was selected" >> pure ByteString.empty)
      (modifyIORef' calls (+ 1) >> pure exactBytes)
      SupplementalRole
      (sourceOrdinal 1)
      input
  acquired <- requireRight result
  readIORef calls >>= (@?= 1)
  acquiredSourceBytes acquired @?= exactBytes

modelRoleTest :: Assertion
modelRoleTest = do
  input <- requireRight (fileInput reference "model.archimate")
  model <-
    requireRight
      =<< acquireWith
            (const (pure exactBytes))
            (pure exactBytes)
            ModelRole
            (sourceOrdinal 0)
            input
  supplemental <-
    requireRight
      =<< acquireWith
            (const (pure exactBytes))
            (pure exactBytes)
            SupplementalRole
            (sourceOrdinal 0)
            input
  case acquiredModelSource model of
    Nothing -> assertFailure "model source was rejected"
    Just _ -> pure ()
  acquiredModelSource supplemental @?= Nothing

filePathValidationTest :: Assertion
filePathValidationTest = do
  fileInput reference "" @?= Left EmptyInputPath
  fileInput reference "bad\NULpath" @?= Left InputPathContainsNul

acquisitionFailureTest :: Assertion
acquisitionFailureTest = do
  input <- requireRight (fileInput reference "missing.archimate")
  result <-
    acquireWith
      (\_ -> ioError (userError "unavailable"))
      (pure exactBytes)
      ModelRole
      (sourceOrdinal 0)
      input
  case result of
    Right _ -> assertFailure "expected an acquisition failure"
    Left failure -> do
      inputSourceReference (acquisitionFailureSource failure) @?= reference
      show (acquisitionFailureIOException failure)
        @?= "user error (unavailable)"

countedRead :: IORef Int -> FilePath -> ByteString -> FilePath -> IO ByteString
countedRead calls expected bytes actual = do
  actual @?= expected
  modifyIORef' calls (+ 1)
  pure bytes

reference :: SourceReference
reference =
  case mkSourceReference "model" of
    Right value -> value
    Left _ -> error "static non-empty source reference rejected"

exactBytes :: ByteString
exactBytes = "a\NULb\n"

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
