-- | Exactly-once acquisition of complete Operation input bytes.
module O2I.Operation.Acquisition
  ( InputSource
  , InputSourceError(..)
  , fileInput
  , standardInput
  , inputSourceReference
  , foldInputSource
  , AcquisitionFailure
  , acquisitionFailureSource
  , acquisitionFailureIOException
  , foldAcquisitionFailure
  , AcquiredSource
  , acquireSource
  , acquiredSourceIdentity
  , acquiredSourceBytes
  , foldAcquiredSource
  , AcquiredModelSource
  , acquiredModelSource
  ) where

import Control.Exception (IOException)
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import O2I.Operation.Acquisition.Internal
import O2I.Operation.Provenance
import System.IO (stdin)

-- | Project the stable reference shared by every physical source form.
inputSourceReference :: InputSource -> SourceReference
inputSourceReference input =
  case input of
    FileInput reference _ -> reference
    StandardInput reference -> reference

-- | Eliminate an opaque physical input source.
foldInputSource ::
     (SourceReference -> FilePath -> value)
  -> (SourceReference -> value)
  -> InputSource
  -> value
foldInputSource onFile onStdin input =
  case input of
    FileInput reference path -> onFile reference path
    StandardInput reference -> onStdin reference

-- | Project the source whose acquisition failed.
acquisitionFailureSource :: AcquisitionFailure -> InputSource
acquisitionFailureSource (AcquisitionFailure input _) = input

-- | Project the original typed IO exception.
acquisitionFailureIOException :: AcquisitionFailure -> IOException
acquisitionFailureIOException (AcquisitionFailure _ exception) = exception

-- | Eliminate an opaque acquisition failure.
foldAcquisitionFailure ::
     (InputSource -> IOException -> value) -> AcquisitionFailure -> value
foldAcquisitionFailure project (AcquisitionFailure input exception) =
  project input exception

-- | Acquire a source once and retain its exact bytes in memory.
acquireSource ::
     SourceRole
  -> SourceOrdinal
  -> InputSource
  -> IO (Either AcquisitionFailure AcquiredSource)
acquireSource = acquireWith ByteString.readFile (ByteString.hGetContents stdin)

-- | Project the immutable identity of the acquired bytes.
acquiredSourceIdentity :: AcquiredSource -> SourceIdentity
acquiredSourceIdentity (AcquiredSource identity _) = identity

-- | Project the exact acquired bytes without reading the source again.
acquiredSourceBytes :: AcquiredSource -> ByteString
acquiredSourceBytes (AcquiredSource _ bytes) = bytes

-- | Eliminate an opaque acquired source.
foldAcquiredSource ::
     (SourceIdentity -> ByteString -> value) -> AcquiredSource -> value
foldAcquiredSource project (AcquiredSource identity bytes) =
  project identity bytes

-- | Retain an acquired source only when its immutable role is model.
acquiredModelSource :: AcquiredSource -> Maybe AcquiredModelSource
acquiredModelSource acquired
  | sourceIdentityRole (acquiredSourceIdentity acquired) == ModelRole =
    Just (AcquiredModelSource acquired)
  | otherwise = Nothing
