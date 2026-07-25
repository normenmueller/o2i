module Main where

import Control.Exception (IOException, try)
import Control.Monad (forM_)
import Data.Char (isHexDigit, toLower)
import Distribution.Simple
import Distribution.Simple.BuildPaths (autogenComponentModulesDir)
import Distribution.Simple.LocalBuildInfo
  ( LocalBuildInfo
  , allComponentsInBuildOrder
  )
import Distribution.Simple.Setup (BuildFlags, HaddockFlags, ReplFlags)
import Distribution.Simple.UserHooks (UserHooks)
import Distribution.Types.PackageDescription (PackageDescription)
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

main :: IO ()
main = defaultMainWithHooks revisionHooks

revisionHooks :: UserHooks
revisionHooks =
  simpleUserHooks
    { buildHook = withBuildRevision (buildHook simpleUserHooks)
    , haddockHook = withHaddockRevision (haddockHook simpleUserHooks)
    , replHook = withReplRevision (replHook simpleUserHooks)
    }

withBuildRevision ::
     (PackageDescription -> LocalBuildInfo -> UserHooks -> BuildFlags -> IO ())
  -> PackageDescription
  -> LocalBuildInfo
  -> UserHooks
  -> BuildFlags
  -> IO ()
withBuildRevision hook description localBuildInfo userHooks flags = do
  generateBuildRevision localBuildInfo
  hook description localBuildInfo userHooks flags

withHaddockRevision ::
     (PackageDescription -> LocalBuildInfo -> UserHooks -> HaddockFlags -> IO ())
  -> PackageDescription
  -> LocalBuildInfo
  -> UserHooks
  -> HaddockFlags
  -> IO ()
withHaddockRevision hook description localBuildInfo userHooks flags = do
  generateBuildRevision localBuildInfo
  hook description localBuildInfo userHooks flags

withReplRevision ::
     (PackageDescription -> LocalBuildInfo -> UserHooks -> ReplFlags -> [String] -> IO
                                                                                      ())
  -> PackageDescription
  -> LocalBuildInfo
  -> UserHooks
  -> ReplFlags
  -> [String]
  -> IO ()
withReplRevision hook description localBuildInfo userHooks flags arguments = do
  generateBuildRevision localBuildInfo
  hook description localBuildInfo userHooks flags arguments

generateBuildRevision :: LocalBuildInfo -> IO ()
generateBuildRevision localBuildInfo = do
  packageRoot <- getCurrentDirectory
  provenance <- resolveBuildRevision packageRoot
  forM_ (allComponentsInBuildOrder localBuildInfo) $ \component -> do
    let autogenDirectory = autogenComponentModulesDir localBuildInfo component
        moduleDirectory = autogenDirectory </> "O2I" </> "BuildProvenance"
        generatedPath = moduleDirectory </> "Generated.hs"
    createDirectoryIfMissing True moduleDirectory
    writeFileIfChanged generatedPath (renderGeneratedModule provenance)

data ResolvedBuildRevision
  = BoundRevision String String
  | UnboundRevision String

resolveBuildRevision :: FilePath -> IO ResolvedBuildRevision
resolveBuildRevision packageRoot = do
  explicitRevision <- lookupEnv "O2I_BUILD_REVISION"
  repository <- inspectRepository packageRoot
  case (explicitRevision, repository) of
    (Just supplied, RepositoryClean actual) -> do
      normalized <- requireRevision "O2I_BUILD_REVISION" supplied
      if normalized == actual
        then pure (BoundRevision normalized "explicit")
        else fail
               "O2I_BUILD_REVISION does not match the clean Git HEAD revision."
    (Just _, RepositoryDirty) ->
      fail "O2I_BUILD_REVISION cannot bind a dirty Git worktree."
    (Just supplied, RepositoryUnavailable) -> do
      normalized <- requireRevision "O2I_BUILD_REVISION" supplied
      pure (BoundRevision normalized "explicit")
    (Nothing, RepositoryClean revision) -> pure (BoundRevision revision "git")
    (Nothing, RepositoryDirty) -> pure (UnboundRevision "dirty-source-tree")
    (Nothing, RepositoryUnavailable) ->
      pure (UnboundRevision "revision-not-provided")

data RepositoryState
  = RepositoryClean String
  | RepositoryDirty
  | RepositoryUnavailable

inspectRepository :: FilePath -> IO RepositoryState
inspectRepository packageRoot = do
  headResult <- runGit packageRoot ["rev-parse", "--verify", "HEAD"]
  case headResult of
    Right (ExitSuccess, revisionOutput, _) ->
      case normalizeRevision revisionOutput of
        Nothing -> pure RepositoryUnavailable
        Just revision -> do
          statusResult <-
            runGit
              packageRoot
              ["status", "--porcelain", "--untracked-files=all"]
          pure
            (case statusResult of
               Right (ExitSuccess, "", _) -> RepositoryClean revision
               Right (ExitSuccess, _, _) -> RepositoryDirty
               _ -> RepositoryUnavailable)
    _ -> pure RepositoryUnavailable

runGit ::
     FilePath -> [String] -> IO (Either IOException (ExitCode, String, String))
runGit packageRoot arguments =
  try (readProcessWithExitCode "git" (["-C", packageRoot] <> arguments) "")

requireRevision :: String -> String -> IO String
requireRevision source value =
  case normalizeRevision value of
    Just revision -> pure revision
    Nothing ->
      fail
        (source
           <> " must contain one complete 40- or 64-character Git commit SHA.")

normalizeRevision :: String -> Maybe String
normalizeRevision value =
  let normalized = map toLower (trim value)
      lengthIsValid = length normalized == 40 || length normalized == 64
   in if lengthIsValid && all isHexDigit normalized
        then Just normalized
        else Nothing

trim :: String -> String
trim =
  reverse
    . dropWhile (`elem` [' ', '\n', '\r', '\t'])
    . reverse
    . dropWhile (`elem` [' ', '\n', '\r', '\t'])

renderGeneratedModule :: ResolvedBuildRevision -> String
renderGeneratedModule provenance =
  unlines
    [ "-- This module is generated by Setup.hs. Do not edit."
    , "module O2I.BuildProvenance.Generated"
    , "  ( generatedRevision"
    , "  , generatedRevisionOrigin"
    , "  , generatedRevisionIssue"
    , "  ) where"
    , ""
    , "generatedRevision :: Maybe String"
    , "generatedRevision = " <> revisionExpression
    , ""
    , "generatedRevisionOrigin :: Maybe String"
    , "generatedRevisionOrigin = " <> originExpression
    , ""
    , "generatedRevisionIssue :: Maybe String"
    , "generatedRevisionIssue = " <> issueExpression
    ]
  where
    (revisionExpression, originExpression, issueExpression) =
      case provenance of
        BoundRevision revision origin ->
          ("Just " <> show revision, "Just " <> show origin, "Nothing")
        UnboundRevision issue -> ("Nothing", "Nothing", "Just " <> show issue)

writeFileIfChanged :: FilePath -> String -> IO ()
writeFileIfChanged path content = do
  existing <- try (readFile path) :: IO (Either IOException String)
  case existing of
    Right current
      | current == content -> pure ()
    _ -> writeFile path content
