{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Static discovery of compiled Profile descriptors.
--
-- A discovery row contains only descriptor-owned data. Its canonical Profile
-- reference is derived from identity and token and is never stored as an
-- independent input.
module O2I.Operation.Discovery.Profile
  ( type ProfileDiscoveryDefect
  , foldProfileDiscoveryDefect
  , type ProfileDiscoveryCompilation
  , foldProfileDiscoveryCompilation
  , discoverProfiles
  , type ProfileDiscovery
  , discoveredProfiles
  , lookupDiscoveredProfile
  , foldProfileDiscovery
  , type ProfileDiscoveryRow
  , profileDiscoveryIdentity
  , profileDiscoveryToken
  , profileDiscoveryReference
  , profileDiscoveryVersion
  , profileDiscoveryNotation
  , profileDiscoveryAdapterIds
  , profileDiscoveryContractDigest
  , foldProfileDiscoveryRow
  ) where

import Data.Function (on)
import Data.List (groupBy, sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Text (Text)
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , foldProfileDescriptor
  )
import O2I.Operation.Discovery.Profile.Internal
import O2I.Operation.Profile (ProfileInventory, profileInventoryDescriptors)

-- | Consume every Profile discovery-definition defect.
foldProfileDiscoveryDefect ::
     (Text -> result)
  -> (Text -> Text -> result)
  -> ProfileDiscoveryDefect
  -> result
foldProfileDiscoveryDefect missing duplicate defect =
  case defect of
    MissingProfileAdapterId reference -> missing reference
    DuplicateProfileAdapterId reference identifier ->
      duplicate reference identifier

-- | Consume invalid definition data or the complete Profile inventory.
foldProfileDiscoveryCompilation ::
     (NonEmpty ProfileDiscoveryDefect -> result)
  -> (ProfileDiscovery -> result)
  -> ProfileDiscoveryCompilation
  -> result
foldProfileDiscoveryCompilation failed compiled outcome =
  case outcome of
    ProfileDiscoveryCompilationFailed defects -> failed defects
    ProfileDiscoveryCompiled discovery -> compiled discovery

-- | Stable Profile identity.
profileDiscoveryIdentity :: ProfileDiscoveryRow -> Text
profileDiscoveryIdentity (ProfileDiscoveryRow identity _ _ _ _ _) = identity

-- | Exact Profile-selection token.
profileDiscoveryToken :: ProfileDiscoveryRow -> Text
profileDiscoveryToken (ProfileDiscoveryRow _ token _ _ _ _) = token

-- | Canonical descriptor-derived @identity@token@ reference.
profileDiscoveryReference :: ProfileDiscoveryRow -> Text
profileDiscoveryReference row =
  profileDiscoveryIdentity row <> "@" <> profileDiscoveryToken row

-- | O2I Framework version represented by the Profile.
profileDiscoveryVersion :: ProfileDiscoveryRow -> Text
profileDiscoveryVersion (ProfileDiscoveryRow _ _ version _ _ _) = version

-- | Exact notation family admitted by the Profile.
profileDiscoveryNotation :: ProfileDiscoveryRow -> Text
profileDiscoveryNotation (ProfileDiscoveryRow _ _ _ notation _ _) = notation

-- | Non-empty unique adapter identities in canonical order.
profileDiscoveryAdapterIds :: ProfileDiscoveryRow -> NonEmpty Text
profileDiscoveryAdapterIds (ProfileDiscoveryRow _ _ _ _ identifiers _) =
  identifiers

-- | Digest binding the row to its exact compiled Profile contract.
profileDiscoveryContractDigest :: ProfileDiscoveryRow -> Text
profileDiscoveryContractDigest (ProfileDiscoveryRow _ _ _ _ _ digest) = digest

-- | Consume every immutable row field in canonical order.
foldProfileDiscoveryRow ::
     (Text -> Text -> Text -> Text -> NonEmpty Text -> Text -> result)
  -> ProfileDiscoveryRow
  -> result
foldProfileDiscoveryRow consume (ProfileDiscoveryRow identity token version notation adapters digest) =
  consume identity token version notation adapters digest

-- | Validate and materialize the complete static Profile inventory.
--
-- Construction is @O(P log P + A log A)@ for @P@ profiles and @A@ admitted
-- adapter identifiers. Definition defects are accumulated deterministically.
discoverProfiles :: ProfileInventory -> ProfileDiscoveryCompilation
discoverProfiles inventory =
  case compileRows (profileInventoryDescriptors inventory) of
    Left defects -> ProfileDiscoveryCompilationFailed defects
    Right compiledRows ->
      let rows =
            NonEmpty.sortBy (comparing profileDiscoveryReference) compiledRows
       in ProfileDiscoveryCompiled
            (ProfileDiscovery
               rows
               (Map.fromList
                  [ (profileDiscoveryReference row, row)
                  | row <- NonEmpty.toList rows
                  ]))

-- | Enumerate every compiled Profile in canonical derived-reference order.
discoveredProfiles :: ProfileDiscovery -> NonEmpty ProfileDiscoveryRow
discoveredProfiles (ProfileDiscovery rows _) = rows

-- | Look up one exact canonical Profile reference in @O(log P)@.
lookupDiscoveredProfile :: Text -> ProfileDiscovery -> Maybe ProfileDiscoveryRow
lookupDiscoveredProfile reference (ProfileDiscovery _ byReference) =
  Map.lookup reference byReference

-- | Consume the complete canonical Profile inventory.
foldProfileDiscovery ::
     (NonEmpty ProfileDiscoveryRow -> result) -> ProfileDiscovery -> result
foldProfileDiscovery consume (ProfileDiscovery rows _) = consume rows

compileRow ::
     ProfileDescriptor
  -> Either (NonEmpty ProfileDiscoveryDefect) ProfileDiscoveryRow
compileRow =
  foldProfileDescriptor $ \identity token version notation adapters digest ->
    let reference = identity <> "@" <> token
        canonicalAdapters = sort adapters
        defects = adapterDefects reference canonicalAdapters
     in case (defects, NonEmpty.nonEmpty canonicalAdapters) of
          ([], Just identifiers) ->
            Right
              (ProfileDiscoveryRow
                 identity
                 token
                 version
                 notation
                 identifiers
                 digest)
          (first:rest, _) -> Left (first :| rest)
          ([], Nothing) -> Left (MissingProfileAdapterId reference :| [])

compileRows ::
     NonEmpty ProfileDescriptor
  -> Either (NonEmpty ProfileDiscoveryDefect) (NonEmpty ProfileDiscoveryRow)
compileRows (first :| rest) =
  combineRows (compileRow first) (compileRowList rest)

compileRowList ::
     [ProfileDescriptor]
  -> Either (NonEmpty ProfileDiscoveryDefect) [ProfileDiscoveryRow]
compileRowList [] = Right []
compileRowList (descriptor:rest) =
  combineLists (compileRow descriptor) (compileRowList rest)

combineRows ::
     Either (NonEmpty defect) row
  -> Either (NonEmpty defect) [row]
  -> Either (NonEmpty defect) (NonEmpty row)
combineRows first rest =
  case (first, rest) of
    (Right firstRow, Right restRows) -> Right (firstRow :| restRows)
    (Left firstDefects, Left restDefects) -> Left (firstDefects <> restDefects)
    (Left defects, Right _) -> Left defects
    (Right _, Left defects) -> Left defects

combineLists ::
     Either (NonEmpty defect) row
  -> Either (NonEmpty defect) [row]
  -> Either (NonEmpty defect) [row]
combineLists first rest =
  case (first, rest) of
    (Right firstRow, Right restRows) -> Right (firstRow : restRows)
    (Left firstDefects, Left restDefects) -> Left (firstDefects <> restDefects)
    (Left defects, Right _) -> Left defects
    (Right _, Left defects) -> Left defects

adapterDefects :: Text -> [Text] -> [ProfileDiscoveryDefect]
adapterDefects reference identifiers =
  [MissingProfileAdapterId reference | null identifiers]
    <> map (DuplicateProfileAdapterId reference) (duplicateValues identifiers)

duplicateValues :: Ord value => [value] -> [value]
duplicateValues = mapMaybe repeated . groupBy ((==) `on` id) . sort
  where
    repeated (first:_:_) = Just first
    repeated _ = Nothing
