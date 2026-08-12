{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Core-internal identity indexing and selected-View resolution.
--
-- Capability modules use the resolver after Structure has derived the exact
-- qualified identity kind of each selected occurrence. The resolver is not a
-- public query API.
module O2I.Core.Identity.Internal
  ( ModelIdentity(..)
  , ModelIdentityDefect(..)
  , modelIdentity
  , modelIdentityText
  , OccurrenceIdentity(..)
  , OccurrenceIdentityDefect(..)
  , occurrenceIdentity
  , occurrenceIdentityText
  , ModelOccurrence(..)
  , modelOccurrence
  , modelOccurrenceIdentity
  , modelOccurrenceModelIdentity
  , ModelIdentityIndex
  , IdentityIndexDefect
  , identityIndexDefectOccurrence
  , identityIndexDefectModelIdentities
  , buildModelIdentityIndex
  , SelectedViewScope
  , SelectedViewScopeDefect
  , SelectedViewScopeDefectKind(..)
  , selectedViewScopeDefectKind
  , selectedViewScopeDefectOccurrence
  , selectedViewScopeDefectCardinality
  , withSelectedViewScope
  , ScopedOccurrence
  , lookupScopedOccurrence
  , scopedOccurrenceIdentity
  , scopedOccurrenceModelIdentity
  , modelIdentityOccurrenceIdentities
  , SelectedIdentityKind(..)
  , IdentityResolution(..)
  , resolveIdentity
  ) where

import Data.Char (ord)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreStructuredPropositionFamilyId
  )

-- | Exact model identity preserved without normalization or classification.
newtype ModelIdentity =
  ModelIdentity Text
  deriving (Eq, Ord, Show)

-- | Invalid exact model identity.
data ModelIdentityDefect
  = EmptyModelIdentity
    -- ^ The supplied identity contains no Unicode scalar value.
  | ModelIdentityContainsU0000
    -- ^ The supplied identity contains the excluded scalar value U+0000.
  | ModelIdentityContainsSurrogate
    -- ^ The supplied identity contains a non-scalar surrogate code point.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Decode exact model-identity text from the canonical notation boundary.
--
-- This decoder requires a non-empty sequence of Unicode scalar values and
-- excludes U+0000. It explicitly rejects surrogate code points admitted by
-- Haskell 'Char'. It performs no normalization, trimming, case folding, or
-- replacement.
modelIdentity :: Text -> Either ModelIdentityDefect ModelIdentity
modelIdentity value
  | Text.null value = Left EmptyModelIdentity
  | Text.any (== '\NUL') value = Left ModelIdentityContainsU0000
  | Text.any isSurrogate value = Left ModelIdentityContainsSurrogate
  | otherwise = Right (ModelIdentity value)

-- | Project the exact retained model-identity text.
modelIdentityText :: ModelIdentity -> Text
modelIdentityText (ModelIdentity value) = value

-- | Canonical identity of one concrete model occurrence.
newtype OccurrenceIdentity =
  OccurrenceIdentity Text
  deriving (Eq, Ord, Show)

-- | Invalid canonical occurrence identity.
data OccurrenceIdentityDefect
  = EmptyOccurrenceIdentity
    -- ^ The supplied identity contains no Unicode scalar value.
  | OccurrenceIdentityContainsU0000
    -- ^ The supplied identity contains the excluded scalar value U+0000.
  | OccurrenceIdentityContainsSurrogate
    -- ^ The supplied identity contains a non-scalar surrogate code point.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Decode a canonical occurrence identity supplied by canonical notation.
--
-- The invariant and exact-preservation rules match 'modelIdentity'. Keeping a
-- separate defect algebra lets each notation decoder map this domain failure
-- without conflating occurrence and model identity.
occurrenceIdentity :: Text -> Either OccurrenceIdentityDefect OccurrenceIdentity
occurrenceIdentity value
  | Text.null value = Left EmptyOccurrenceIdentity
  | Text.any (== '\NUL') value = Left OccurrenceIdentityContainsU0000
  | Text.any isSurrogate value = Left OccurrenceIdentityContainsSurrogate
  | otherwise = Right (OccurrenceIdentity value)

isSurrogate :: Char -> Bool
isSurrogate value =
  let codePoint = ord value
   in codePoint >= 0xd800 && codePoint <= 0xdfff

-- | Project the canonical occurrence-identity text.
occurrenceIdentityText :: OccurrenceIdentity -> Text
occurrenceIdentityText (OccurrenceIdentity value) = value

-- | One profile-neutral canonical occurrence.
--
-- No O2I kind can be stored in this value.
data ModelOccurrence = ModelOccurrence
  { storedOccurrenceIdentity :: !OccurrenceIdentity
  , storedModelIdentity :: !ModelIdentity
  } deriving (Eq, Ord, Show)

-- | Construct one profile-neutral canonical occurrence.
modelOccurrence :: OccurrenceIdentity -> ModelIdentity -> ModelOccurrence
modelOccurrence = ModelOccurrence

-- | Project the canonical identity of an occurrence.
modelOccurrenceIdentity :: ModelOccurrence -> OccurrenceIdentity
modelOccurrenceIdentity = storedOccurrenceIdentity

-- | Project the exact model identity carried by an occurrence.
modelOccurrenceModelIdentity :: ModelOccurrence -> ModelIdentity
modelOccurrenceModelIdentity = storedModelIdentity

-- | Duplicate canonical occurrence identity rejected during index construction.
--
-- The constructor is private so the non-empty evidence always contains at
-- least two occurrences in the implementation-produced value.
data IdentityIndexDefect = IdentityIndexDefect
  { duplicateOccurrenceIdentity :: !OccurrenceIdentity
  , duplicateOccurrenceModels :: !(NonEmpty ModelIdentity)
  } deriving (Eq, Show)

-- | Project the duplicated canonical occurrence identity.
identityIndexDefectOccurrence :: IdentityIndexDefect -> OccurrenceIdentity
identityIndexDefectOccurrence = duplicateOccurrenceIdentity

-- | Project the canonically ordered model identities of duplicate occurrences.
identityIndexDefectModelIdentities ::
     IdentityIndexDefect -> NonEmpty ModelIdentity
identityIndexDefectModelIdentities = duplicateOccurrenceModels

-- | Profile-neutral addressed model-wide identity index.
--
-- The first map establishes canonical occurrence identity. The second retains
-- every distinct occurrence of an exact model identity, so duplicate model
-- identities remain observable as ambiguity rather than construction failure.
data ModelIdentityIndex = ModelIdentityIndex
  { occurrencesByIdentity :: !(Map OccurrenceIdentity ModelOccurrence)
  , occurrencesByModelIdentity :: !(Map ModelIdentity (NonEmpty ModelOccurrence))
  }

-- | Build the complete model-wide identity index in @O(n log n)@ time.
--
-- Duplicate occurrence identities are rejected together and in canonical
-- occurrence order. Distinct occurrences with the same model identity are
-- retained for deterministic ambiguity resolution.
buildModelIdentityIndex ::
     [ModelOccurrence]
  -> Either (NonEmpty IdentityIndexDefect) ModelIdentityIndex
buildModelIdentityIndex occurrences =
  case duplicateOccurrenceDefects occurrences of
    defect:defects -> Left (defect :| defects)
    [] ->
      Right
        ModelIdentityIndex
          { occurrencesByIdentity =
              Map.fromList
                [ (modelOccurrenceIdentity occurrence, occurrence)
                | occurrence <- occurrences
                ]
          , occurrencesByModelIdentity =
              Map.map
                NonEmpty.sort
                (Map.fromListWith
                   (<>)
                   [ (modelOccurrenceModelIdentity occurrence, occurrence :| [])
                   | occurrence <- occurrences
                   ])
          }

duplicateOccurrenceDefects :: [ModelOccurrence] -> [IdentityIndexDefect]
duplicateOccurrenceDefects =
  foldr collect []
    . Map.toAscList
    . Map.fromListWith (++)
    . map (\occurrence -> (modelOccurrenceIdentity occurrence, [occurrence]))
  where
    collect (identifier, occurrences) defects =
      case occurrences of
        first:second:rest ->
          IdentityIndexDefect
            identifier
            (NonEmpty.sort
               (modelOccurrenceModelIdentity first
                  :| map modelOccurrenceModelIdentity (second : rest)))
            : defects
        _ -> defects

-- | Kind of invalid selected-View membership evidence.
data SelectedViewScopeDefectKind
  = UnknownSelectedViewOccurrence
    -- ^ Membership references no canonical model occurrence.
  | DuplicateSelectedViewOccurrence
    -- ^ Membership repeats one canonical model occurrence.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Invalid selected-View membership evidence.
--
-- The constructor is private so the cardinality is exact: one for unknown
-- membership and at least two for duplicate membership.
data SelectedViewScopeDefect = SelectedViewScopeDefect
  { scopeDefectKind :: !SelectedViewScopeDefectKind
  , scopeDefectOccurrence :: !OccurrenceIdentity
  , scopeDefectCardinality :: !Int
  } deriving (Eq, Show)

-- | Project the closed defect kind.
selectedViewScopeDefectKind ::
     SelectedViewScopeDefect -> SelectedViewScopeDefectKind
selectedViewScopeDefectKind = scopeDefectKind

-- | Project the affected canonical occurrence identity.
selectedViewScopeDefectOccurrence ::
     SelectedViewScopeDefect -> OccurrenceIdentity
selectedViewScopeDefectOccurrence = scopeDefectOccurrence

-- | Project its observed selected-View membership cardinality.
selectedViewScopeDefectCardinality :: SelectedViewScopeDefect -> Int
selectedViewScopeDefectCardinality = scopeDefectCardinality

type role SelectedViewScope nominal

-- | Opaque membership boundary of one final selected View.
--
-- The nominal phantom scope is generated by 'withSelectedViewScope'. Values
-- tied to different invocations cannot be combined accidentally.
data SelectedViewScope scope = SelectedViewScope
  { selectedModelIndex :: !ModelIdentityIndex
  , selectedOccurrenceIdentities :: !(Set OccurrenceIdentity)
  }

-- | Validate selected-View membership and introduce one fresh nominal scope.
--
-- The rank-2 continuation prevents its scope parameter from appearing in the
-- result. All defects are returned in canonical occurrence order.
withSelectedViewScope ::
     ModelIdentityIndex
  -> [OccurrenceIdentity]
  -> (forall scope. SelectedViewScope scope -> result)
  -> Either (NonEmpty SelectedViewScopeDefect) result
withSelectedViewScope index identities action =
  case selectedViewDefects index identities of
    defect:defects -> Left (defect :| defects)
    [] ->
      Right
        (action
           SelectedViewScope
             { selectedModelIndex = index
             , selectedOccurrenceIdentities = Set.fromList identities
             })

selectedViewDefects ::
     ModelIdentityIndex -> [OccurrenceIdentity] -> [SelectedViewScopeDefect]
selectedViewDefects index =
  foldr collect []
    . Map.toAscList
    . Map.fromListWith (+)
    . map (\identifier -> (identifier, 1 :: Int))
  where
    collect (identifier, cardinality) defects =
      unknownDefect ++ duplicateDefect ++ defects
      where
        unknownDefect =
          [ SelectedViewScopeDefect UnknownSelectedViewOccurrence identifier 1
          | Map.notMember identifier (occurrencesByIdentity index)
          ]
        duplicateDefect =
          [ SelectedViewScopeDefect
            DuplicateSelectedViewOccurrence
            identifier
            cardinality
          | cardinality > 1
          ]

type role ScopedOccurrence nominal

-- | One occurrence proven to belong to exactly one selected-View scope.
newtype ScopedOccurrence scope =
  ScopedOccurrence ModelOccurrence
  deriving (Eq, Ord, Show)

-- | Resolve one canonical occurrence inside the validated selected View.
lookupScopedOccurrence ::
     SelectedViewScope scope
  -> OccurrenceIdentity
  -> Maybe (ScopedOccurrence scope)
lookupScopedOccurrence scope identifier
  | Set.member identifier (selectedOccurrenceIdentities scope) =
    ScopedOccurrence <$> Map.lookup identifier (occurrencesByIdentity index)
  | otherwise = Nothing
  where
    index = selectedModelIndex scope

-- | Project its canonical occurrence identity without weakening scope proofs.
scopedOccurrenceIdentity :: ScopedOccurrence scope -> OccurrenceIdentity
scopedOccurrenceIdentity (ScopedOccurrence occurrence) =
  modelOccurrenceIdentity occurrence

-- | Project its exact model identity without exposing any O2I kind.
scopedOccurrenceModelIdentity :: ScopedOccurrence scope -> ModelIdentity
scopedOccurrenceModelIdentity (ScopedOccurrence occurrence) =
  modelOccurrenceModelIdentity occurrence

-- | Enumerate every model occurrence carrying an exact model identity.
--
-- This model-wide internal projection supports identity invariants. It is not
-- exposed as a graph query surface.
modelIdentityOccurrenceIdentities ::
     SelectedViewScope scope -> ModelIdentity -> [OccurrenceIdentity]
modelIdentityOccurrenceIdentities scope identifier =
  case Map.lookup identifier (occurrencesByModelIdentity index) of
    Nothing -> []
    Just occurrences ->
      NonEmpty.toList (modelOccurrenceIdentity <$> occurrences)
  where
    index = selectedModelIndex scope

-- | Closed kind of any identity after selected-View membership.
--
-- Capability input may name every selected model occurrence, including one
-- that is not an admitted O2I subject. Keeping these cases explicit makes
-- wrong-kind evidence total without exposing a model query surface.
data SelectedIdentityKind
  = SelectedCarrier !CoreQualifiedEndpointId
    -- ^ Exact qualified O2I element type established by Structure.
  | SelectedStructuredProposition !CoreStructuredPropositionFamilyId
    -- ^ Exact structured-proposition family established by Structure.
  | SelectedRelation
  | SelectedContextualization
  | SelectedStructuredIncidence
  | SelectedUnclassifiedOccurrence
  deriving (Eq, Ord, Show)

-- | Closed internal result of exact model-identity resolution.
data IdentityResolution scope
  = UnknownModelIdentity !ModelIdentity
  | AmbiguousModelIdentity !ModelIdentity !(NonEmpty OccurrenceIdentity)
  | ModelIdentityOutOfSelectedView !ModelIdentity !OccurrenceIdentity
  | WrongSelectedIdentityKind
      !(ScopedOccurrence scope)
      !SelectedIdentityKind
      !SelectedIdentityKind
      -- ^ Scoped occurrence, expected kind, actual kind.
  | ResolvedIdentity !(ScopedOccurrence scope) !SelectedIdentityKind
  deriving (Eq, Show)

-- | Resolve one exact model identity with the normative fixed precedence.
--
-- Classification is invoked only for a unique occurrence already proven to
-- belong to the selected View. Consequently the out-of-View result has no
-- field through which an inferred or actual O2I kind could leak.
resolveIdentity ::
     SelectedViewScope scope
  -> (ScopedOccurrence scope -> SelectedIdentityKind)
  -> SelectedIdentityKind
  -> ModelIdentity
  -> IdentityResolution scope
resolveIdentity scope classify expected identifier =
  case Map.lookup identifier (occurrencesByModelIdentity index) of
    Nothing -> UnknownModelIdentity identifier
    Just (occurrence :| []) -> resolveUnique occurrence
    Just occurrences ->
      AmbiguousModelIdentity
        identifier
        (modelOccurrenceIdentity <$> occurrences)
  where
    index = selectedModelIndex scope
    resolveUnique occurrence
      | Set.notMember
          (modelOccurrenceIdentity occurrence)
          (selectedOccurrenceIdentities scope) =
        ModelIdentityOutOfSelectedView
          identifier
          (modelOccurrenceIdentity occurrence)
      | otherwise =
        let scoped = ScopedOccurrence occurrence
            !actual = classify scoped
         in if actual == expected
              then ResolvedIdentity scoped actual
              else WrongSelectedIdentityKind scoped expected actual
