-- | Revision-closed source provenance for O2I build artifacts.
module O2I.BuildProvenance
  ( BuildRevision
  , BuildRevisionOrigin(..)
  , BuildRevisionIssue(..)
  , BuildRevisionStatus(..)
  , buildRevisionStatus
  , buildRevisionText
  , parseBuildRevision
  ) where

import Data.Char (isHexDigit, toLower)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.BuildProvenance.Generated

-- | One complete, normalized Git commit identifier.
newtype BuildRevision =
  BuildRevision Text
  deriving (Eq, Show)

-- | Authority from which the build obtained its revision.
data BuildRevisionOrigin
  = GitWorktree
  | ExplicitBuildInput
  deriving (Eq, Show)

-- | Why the executable cannot claim a source revision.
data BuildRevisionIssue
  = RevisionNotProvided
  | DirtySourceTree
  | InvalidGeneratedProvenance
  deriving (Eq, Show)

-- | Complete provenance state embedded at build time.
data BuildRevisionStatus
  = RevisionBound BuildRevisionOrigin BuildRevision
  | RevisionUnbound BuildRevisionIssue
  deriving (Eq, Show)

-- | Provenance embedded by the Cabal setup hook.
buildRevisionStatus :: BuildRevisionStatus
buildRevisionStatus =
  case (generatedRevisionOrigin, generatedRevision, generatedRevisionIssue) of
    (Just origin, Just revision, Nothing) ->
      case (parseOrigin origin, parseBuildRevision (Text.pack revision)) of
        (Just parsedOrigin, Right parsedRevision) ->
          RevisionBound parsedOrigin parsedRevision
        _ -> RevisionUnbound InvalidGeneratedProvenance
    (Nothing, Nothing, Just "revision-not-provided") ->
      RevisionUnbound RevisionNotProvided
    (Nothing, Nothing, Just "dirty-source-tree") ->
      RevisionUnbound DirtySourceTree
    _ -> RevisionUnbound InvalidGeneratedProvenance

-- | Extract the normalized commit identifier.
buildRevisionText :: BuildRevision -> Text
buildRevisionText (BuildRevision revision) = revision

-- | Validate and normalize one complete Git SHA-1 or SHA-256 commit ID.
parseBuildRevision :: Text -> Either BuildRevisionIssue BuildRevision
parseBuildRevision value =
  let normalized = Text.toLower (Text.strip value)
      validLength = Text.length normalized == 40 || Text.length normalized == 64
   in if validLength && Text.all isHexDigit normalized
        then Right (BuildRevision normalized)
        else Left InvalidGeneratedProvenance

parseOrigin :: String -> Maybe BuildRevisionOrigin
parseOrigin value =
  case map toLower value of
    "git" -> Just GitWorktree
    "explicit" -> Just ExplicitBuildInput
    _ -> Nothing
