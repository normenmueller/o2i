-- | Canonical fachliche text used by Core-owned supplemental inputs.
{-# LANGUAGE OverloadedStrings #-}

module O2I.Input.Internal.Text
  ( FachlicheTextFailure(..)
  , CanonicalFachlicheText
  , canonicalizeFachlicheText
  , canonicalFachlicheText
  ) where

import Data.Char (ord)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Normalize (NormalizationMode(NFC), normalize)

-- | Failure of the closed fachliche-text canonicalization contract.
data FachlicheTextFailure
  = FachlicheTextContainsForbiddenControl
  | FachlicheTextIsEmpty
  deriving (Eq, Ord, Show)

-- | Fachliche text after exact line-ending, control, NFC, and edge handling.
newtype CanonicalFachlicheText =
  CanonicalFachlicheText Text
  deriving (Eq, Ord, Show)

-- | Canonicalize one fachliche text value in the normative phase order.
canonicalizeFachlicheText ::
     Text -> Either FachlicheTextFailure CanonicalFachlicheText
canonicalizeFachlicheText source
  | Text.any isForbiddenControl normalizedLines =
    Left FachlicheTextContainsForbiddenControl
  | Text.null canonical = Left FachlicheTextIsEmpty
  | otherwise = Right (CanonicalFachlicheText canonical)
  where
    normalizedLines = normalizeLineEndings source
    canonical = trimAdmittedEdges (normalize NFC normalizedLines)

-- | Project the canonical text.
canonicalFachlicheText :: CanonicalFachlicheText -> Text
canonicalFachlicheText (CanonicalFachlicheText value) = value

normalizeLineEndings :: Text -> Text
normalizeLineEndings = Text.replace "\r" "\n" . Text.replace "\r\n" "\n"

isForbiddenControl :: Char -> Bool
isForbiddenControl value =
  let codePoint = ord value
   in (codePoint >= 0x00 && codePoint <= 0x1f && value /= '\t' && value /= '\n')
        || (codePoint >= 0x7f && codePoint <= 0x9f)

trimAdmittedEdges :: Text -> Text
trimAdmittedEdges = Text.dropAround isAdmittedEdge

isAdmittedEdge :: Char -> Bool
isAdmittedEdge value = value == '\t' || value == '\n' || value == ' '
