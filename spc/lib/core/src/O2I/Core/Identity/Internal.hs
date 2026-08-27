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
  , selectedViewScopeDefectIndexedModelIdentity
  , selectedViewScopeDefectSuppliedModelIdentity
  , withSelectedViewScope
  , selectedViewScopeGraphIdentity
  , selectedViewOccurrenceModelIdentity
  , sameSelectedViewScope
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

-- | Kind of invalid selected-View subject or membership evidence.
data SelectedViewScopeDefectKind
  = UnknownSelectedViewSubjectOccurrence
    -- ^ The selected View subject references no indexed model occurrence.
  | SelectedViewSubjectIdentityMismatch
    -- ^ The subject's supplied identity differs from its indexed identity.
  | UnknownSelectedViewOccurrence
    -- ^ Membership references no canonical model occurrence.
  | DuplicateSelectedViewOccurrence
    -- ^ Membership repeats one canonical model occurrence.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Invalid selected-View subject or membership evidence.
--
-- Constructors remain private. Subject failures and unknown membership have
-- cardinality one; duplicate membership retains its exact cardinality. Public
-- rendering intentionally includes only the projected kind, occurrence, and
-- cardinality, never the indexed identity that could replace a rejected
-- subject.
data SelectedViewScopeDefect
  = UnknownSelectedViewSubjectDefect !OccurrenceIdentity
  | SelectedViewSubjectIdentityMismatchDefect
      !OccurrenceIdentity
      !ModelIdentity
      !ModelIdentity
      -- ^ Occurrence, indexed identity, supplied identity.
  | SelectedViewMembershipDefect
      !SelectedViewScopeDefectKind
      !OccurrenceIdentity
      !Int
  deriving (Eq)

instance Show SelectedViewScopeDefect where
  showsPrec precedence defect =
    showParen (precedence > 10)
      $ showString "SelectedViewScopeDefect "
          . shows
              ( selectedViewScopeDefectKind defect
              , selectedViewScopeDefectOccurrence defect
              , selectedViewScopeDefectCardinality defect)

-- | Project the closed defect kind.
selectedViewScopeDefectKind ::
     SelectedViewScopeDefect -> SelectedViewScopeDefectKind
selectedViewScopeDefectKind defect =
  case defect of
    UnknownSelectedViewSubjectDefect _ -> UnknownSelectedViewSubjectOccurrence
    SelectedViewSubjectIdentityMismatchDefect {} ->
      SelectedViewSubjectIdentityMismatch
    SelectedViewMembershipDefect kind _ _ -> kind

-- | Project the affected canonical occurrence identity.
selectedViewScopeDefectOccurrence ::
     SelectedViewScopeDefect -> OccurrenceIdentity
selectedViewScopeDefectOccurrence defect =
  case defect of
    UnknownSelectedViewSubjectDefect occurrence -> occurrence
    SelectedViewSubjectIdentityMismatchDefect occurrence _ _ -> occurrence
    SelectedViewMembershipDefect _ occurrence _ -> occurrence

-- | Project its observed selected-View membership cardinality.
selectedViewScopeDefectCardinality :: SelectedViewScopeDefect -> Int
selectedViewScopeDefectCardinality defect =
  case defect of
    UnknownSelectedViewSubjectDefect _ -> 1
    SelectedViewSubjectIdentityMismatchDefect {} -> 1
    SelectedViewMembershipDefect _ _ cardinality -> cardinality

-- | Project the indexed identity for a selected-View subject mismatch.
selectedViewScopeDefectIndexedModelIdentity ::
     SelectedViewScopeDefect -> Maybe ModelIdentity
selectedViewScopeDefectIndexedModelIdentity defect =
  case defect of
    SelectedViewSubjectIdentityMismatchDefect _ indexed _ -> Just indexed
    _ -> Nothing

-- | Project the supplied identity for a selected-View subject mismatch.
selectedViewScopeDefectSuppliedModelIdentity ::
     SelectedViewScopeDefect -> Maybe ModelIdentity
selectedViewScopeDefectSuppliedModelIdentity defect =
  case defect of
    SelectedViewSubjectIdentityMismatchDefect _ _ supplied -> Just supplied
    _ -> Nothing

type role SelectedViewScope nominal

-- | Opaque identity and membership boundary of one final selected View.
--
-- The nominal phantom scope is generated by 'withSelectedViewScope'. Values
-- tied to different invocations cannot be combined accidentally, and the
-- graph identity cannot be detached from its membership proof.
data SelectedViewScope scope = SelectedViewScope
  { selectedModelIndex :: !ModelIdentityIndex
  , selectedGraphIdentity :: !ModelIdentity
  , selectedOccurrenceIdentities :: !(Set OccurrenceIdentity)
  }

-- | Validate the selected View subject and membership, then introduce one
-- fresh nominal scope.
--
-- The rank-2 continuation prevents its scope parameter from appearing in the
-- result. The selected View identity is derived from the same model index as
-- graph membership and cannot be supplied or replaced independently.
withSelectedViewScope ::
     ModelIdentityIndex
  -> ModelOccurrence
  -> [OccurrenceIdentity]
  -> (forall scope. SelectedViewScope scope -> result)
  -> Either (NonEmpty SelectedViewScopeDefect) result
withSelectedViewScope index selectedView identities action =
  case indexedSelectedViewIdentity index selectedView of
    Left defect -> Left (defect :| selectedViewDefects index identities)
    Right graphIdentity ->
      case selectedViewDefects index identities of
        defect:defects -> Left (defect :| defects)
        [] ->
          Right
            (action
               SelectedViewScope
                 { selectedModelIndex = index
                 , selectedGraphIdentity = graphIdentity
                 , selectedOccurrenceIdentities = Set.fromList identities
                 })

indexedSelectedViewIdentity ::
     ModelIdentityIndex
  -> ModelOccurrence
  -> Either SelectedViewScopeDefect ModelIdentity
indexedSelectedViewIdentity index selectedView =
  case Map.lookup occurrence (occurrencesByIdentity index) of
    Nothing -> Left (UnknownSelectedViewSubjectDefect occurrence)
    Just indexed
      | indexedIdentity == suppliedIdentity -> Right indexedIdentity
      | otherwise ->
        Left
          (SelectedViewSubjectIdentityMismatchDefect
             occurrence
             indexedIdentity
             suppliedIdentity)
      where indexedIdentity = modelOccurrenceModelIdentity indexed
  where
    occurrence = modelOccurrenceIdentity selectedView
    suppliedIdentity = modelOccurrenceModelIdentity selectedView

-- | Project the exact selected View identity inside Core only.
selectedViewScopeGraphIdentity :: SelectedViewScope scope -> ModelIdentity
selectedViewScopeGraphIdentity = selectedGraphIdentity

-- | Recover the profile-neutral model identity of one selected occurrence.
selectedViewOccurrenceModelIdentity ::
     SelectedViewScope scope -> OccurrenceIdentity -> Maybe ModelIdentity
selectedViewOccurrenceModelIdentity scope occurrence =
  modelOccurrenceModelIdentity
    <$> Map.lookup occurrence (occurrencesByIdentity (selectedModelIndex scope))

-- | Compare every fact retained by two selected-View boundaries.
sameSelectedViewScope ::
     SelectedViewScope scope -> SelectedViewScope scope -> Bool
sameSelectedViewScope left right =
  selectedGraphIdentity left == selectedGraphIdentity right
    && selectedOccurrenceIdentities left == selectedOccurrenceIdentities right
    && sameModelIdentityIndex
         (selectedModelIndex left)
         (selectedModelIndex right)

sameModelIdentityIndex :: ModelIdentityIndex -> ModelIdentityIndex -> Bool
sameModelIdentityIndex left right =
  occurrencesByIdentity left == occurrencesByIdentity right
    && occurrencesByModelIdentity left == occurrencesByModelIdentity right

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
          [ SelectedViewMembershipDefect
            UnknownSelectedViewOccurrence
            identifier
            1
          | Map.notMember identifier (occurrencesByIdentity index)
          ]
        duplicateDefect =
          [ SelectedViewMembershipDefect
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
