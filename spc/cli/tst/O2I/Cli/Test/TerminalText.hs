{-# LANGUAGE OverloadedStrings #-}

module O2I.Cli.Test.TerminalText
  ( tests
  ) where

import Data.Char (chr)
import qualified Data.Text as Text
import Numeric (showHex)
import O2I.Cli.TerminalText (terminalLiteral, terminalSafeText)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, (@?=), testCase)

tests :: TestTree
tests =
  testGroup
    "terminal-safe text"
    [ testCase
        "preserves printable Unicode"
        (terminalSafeText "Wirkung Ä → Ziel" @?= "Wirkung Ä → Ziel")
    , testCase
        "encodes C0, DEL and C1 controls"
        (terminalSafeText "a\ESC\n\DEL\x0085z"
           @?= "a\\u{001B}\\u{000A}\\u{007F}\\u{0085}z")
    , testCase
        "escapes quotation marks and reverse solidus"
        (terminalSafeText "\"\\u{001B}" @?= "\\\"\\\\u{001B}")
    , testCase
        "quotes one complete literal"
        (terminalLiteral "A\"\\\x2028" @?= "\"A\\\"\\\\\\u{2028}\"")
    , testCase
        "escapes both Unicode line separators"
        (terminalSafeText "\x2028\x2029" @?= "\\u{2028}\\u{2029}")
    , testCase "escapes the exact Unicode 16.0 Cf table" exactFormatTable
    , testCase "preserves scalars adjacent to the Cf table" formatBoundaries
    ]

exactFormatTable :: Assertion
exactFormatTable = mapM_ assertEscaped formatScalars

formatBoundaries :: Assertion
formatBoundaries =
  terminalSafeText (Text.pack (map chr adjacentScalars))
    @?= Text.pack (map chr adjacentScalars)

assertEscaped :: Int -> Assertion
assertEscaped code =
  terminalSafeText (Text.singleton (chr code)) @?= "\\u{"
    <> scalarCode code
    <> "}"

scalarCode :: Int -> Text.Text
scalarCode code =
  Text.justifyRight 4 '0' (Text.pack (map toUpperAscii (showHex code "")))

toUpperAscii :: Char -> Char
toUpperAscii character =
  case character of
    'a' -> 'A'
    'b' -> 'B'
    'c' -> 'C'
    'd' -> 'D'
    'e' -> 'E'
    'f' -> 'F'
    _ -> character

formatScalars :: [Int]
formatScalars =
  [0x00ad]
    <> [0x0600 .. 0x0605]
    <> [0x061c, 0x06dd, 0x070f]
    <> [0x0890 .. 0x0891]
    <> [0x08e2, 0x180e]
    <> [0x200b .. 0x200f]
    <> [0x202a .. 0x202e]
    <> [0x2060 .. 0x2064]
    <> [0x2066 .. 0x206f]
    <> [0xfeff]
    <> [0xfff9 .. 0xfffb]
    <> [0x110bd, 0x110cd]
    <> [0x13430 .. 0x1343f]
    <> [0x1bca0 .. 0x1bca3]
    <> [0x1d173 .. 0x1d17a]
    <> [0xe0001]
    <> [0xe0020 .. 0xe007f]

adjacentScalars :: [Int]
adjacentScalars =
  [ 0x00ac
  , 0x00ae
  , 0x05ff
  , 0x0606
  , 0x061b
  , 0x061d
  , 0x06dc
  , 0x06de
  , 0x070e
  , 0x0710
  , 0x088f
  , 0x0892
  , 0x08e1
  , 0x08e3
  , 0x180d
  , 0x180f
  , 0x200a
  , 0x2010
  , 0x202f
  , 0x205f
  , 0x2065
  , 0x2070
  , 0xfefe
  , 0xff00
  , 0xfff8
  , 0xfffc
  , 0x110bc
  , 0x110be
  , 0x110cc
  , 0x110ce
  , 0x1342f
  , 0x13440
  , 0x1bc9f
  , 0x1bca4
  , 0x1d172
  , 0x1d17b
  , 0xe0000
  , 0xe0002
  , 0xe001f
  , 0xe0080
  ]
