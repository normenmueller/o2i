-- | Internal construction and test seam for exact-byte acquisition.
module O2I.Operation.Acquisition.Internal
  ( InputSource(..)
  , InputSourceError(..)
  , fileInput
  , standardInput
  , AcquisitionFailure(..)
  , AcquiredSource(..)
  , acquireWith
  ) where

import Control.Exception (IOException, try)
import Data.ByteString (ByteString)
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)

-- | Physical source from which exact bytes are acquired.
data InputSource
  = FileInput !SourceReference FilePath
  | StandardInput !SourceReference
  deriving (Eq, Show)

-- | Why a physical input source cannot be represented.
data InputSourceError
  = EmptyInputPath
  | InputPathContainsNul
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Construct a file input with an explicit stable reference.
fileInput :: SourceReference -> FilePath -> Either InputSourceError InputSource
fileInput reference path
  | null path = Left EmptyInputPath
  | '\NUL' `elem` path = Left InputPathContainsNul
  | otherwise = Right (FileInput reference path)

-- | Construct standard input with an explicit stable reference.
standardInput :: SourceReference -> InputSource
standardInput = StandardInput

-- | Expected IO failure while acquiring one complete source.
data AcquisitionFailure = AcquisitionFailure
  { failedInputSource :: !InputSource
  , acquisitionIOException :: !IOException
  } deriving (Show)

-- | Exact acquired bytes and their immutable identity.
data AcquiredSource = AcquiredSource
  { acquiredIdentity :: !SourceIdentity
  , acquiredBytes :: !ByteString
  } deriving (Eq, Show)

-- | Acquire through injected readers; used by the public IO boundary and
-- focused tests of exactly-once behavior.
acquireWith ::
     (FilePath -> IO ByteString)
  -> IO ByteString
  -> SourceRole
  -> SourceOrdinal
  -> InputSource
  -> IO (Either AcquisitionFailure AcquiredSource)
acquireWith readPath readStdin role ordinal input = do
  result <- tryRead selectedRead
  pure
    (case result of
       Left exception -> Left (AcquisitionFailure input exception)
       Right bytes ->
         Right
           (AcquiredSource
              (sourceIdentityFromBytes role ordinal (inputReference input) bytes)
              bytes))
  where
    selectedRead =
      case input of
        FileInput _ path -> readPath path
        StandardInput _ -> readStdin

tryRead :: IO ByteString -> IO (Either IOException ByteString)
tryRead = try

inputReference :: InputSource -> SourceReference
inputReference input =
  case input of
    FileInput reference _ -> reference
    StandardInput reference -> reference
