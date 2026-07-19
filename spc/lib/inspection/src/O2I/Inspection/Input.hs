{-# LANGUAGE OverloadedStrings #-}

-- | Complete input acquisition for paths and non-seekable standard input.
module O2I.Inspection.Input
  ( InputSource(..)
  , InputFailure(..)
  , SourceDocument
  , acquireInput
  , sourceDocumentFromBytes
  , sourceDocumentBytes
  , sourceDocumentIdentity
  , sourceDocumentLocator
  ) where

import Control.Exception (IOException, displayException, try)
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Inspection.Provenance
import O2I.Inspection.Provenance.Internal
  ( SourceIdentity(..)
  , bindSourceLocator
  )
import System.IO (stdin)

-- | Source selected by a caller independently of CLI parsing.
data InputSource
  = InputPath FilePath
  | StandardInput
  deriving (Eq, Show)

-- | Acquisition failure before any model inspection can start.
data InputFailure = InputFailure
  { inputFailureSource :: InputSource
  , inputFailureMessage :: Text
  } deriving (Eq, Show)

-- | Complete acquired bytes and their immutable identity.
data SourceDocument =
  SourceDocument SourceIdentity ByteString

-- | Acquire the complete input without requiring seekability.
acquireInput :: InputSource -> IO (Either InputFailure SourceDocument)
acquireInput source =
  case source of
    InputPath path -> do
      result <- try (ByteString.readFile path)
      pure
        (case result of
           Left exception -> Left (failure source exception)
           Right bytes ->
             Right (sourceDocumentFromBytes (Text.pack path) FileSource bytes))
    StandardInput -> do
      result <- try (ByteString.hGetContents stdin)
      pure
        (case result of
           Left exception -> Left (failure source exception)
           Right bytes ->
             Right (sourceDocumentFromBytes "<stdin>" StandardInputSource bytes))
  where
    failure :: InputSource -> IOException -> InputFailure
    failure input exception =
      InputFailure input (Text.pack (displayException exception))

-- | Construct a complete source document from already acquired exact bytes.
sourceDocumentFromBytes ::
     Text -> SourceInputKind -> ByteString -> SourceDocument
sourceDocumentFromBytes label kind bytes =
  SourceDocument (SourceIdentity label kind (sourceHashFromBytes bytes)) bytes

-- | Access the exact acquired bytes.
sourceDocumentBytes :: SourceDocument -> ByteString
sourceDocumentBytes (SourceDocument _ bytes) = bytes

-- | Access the immutable source identity.
sourceDocumentIdentity :: SourceDocument -> SourceIdentity
sourceDocumentIdentity (SourceDocument identity _) = identity

-- | Obtain the only locator capability bound to this exact document.
sourceDocumentLocator :: SourceDocument -> SourceLocator
sourceDocumentLocator = bindSourceLocator . sourceDocumentIdentity
