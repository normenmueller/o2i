{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.Output
  ( tests
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import O2I.Cli.Output
import O2I.Inspection
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, openBinaryTempFile)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "output"
    [ testCase "invocation errors prefix every line" prefixedInvocation
    , testCase "input errors do not enter stdout report syntax" inputError
    , testCase "human output contains no ANSI escape" ansiFree
    , testCase "closed output handle is normalized" closedHandle
    ]

prefixedInvocation :: Assertion
prefixedInvocation =
  renderHumanCommandError
    (InvocationCommandError InvalidInvocation "first line\nsecond line")
    @?= "[o2i|error] first line\n[o2i|error] second line\n"

inputError :: Assertion
inputError =
  renderHumanCommandError (InputCommandError "missing" "not found")
    @?= "[o2i|error] Cannot read missing: not found\n"

ansiFree :: Assertion
ansiFree =
  assertBool
    "unexpected ANSI control sequence"
    (not
       (ByteString.isInfixOf
          "\ESC["
          (LazyByteString.toStrict
             (renderHumanCommandError
                (InvocationCommandError InvalidInvocation "invalid")))))

closedHandle :: Assertion
closedHandle = do
  temporary <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile temporary "o2i-cli-output"
  hClose handle
  written <- writeHandleBytes handle "report"
  removeFile path
  assertBool "closed handle should reject output" (not written)
