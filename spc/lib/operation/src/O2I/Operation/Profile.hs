{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Static Profile bootstrap, exact model marker resolution, and adapter
-- compatibility.
--
-- Profile descriptors are immutable package contributions. Operation validates
-- their closed collection once, resolves accepted model-root marker evidence
-- without normalization, and checks the already selected adapter before any
-- Profile assessment runs.
module O2I.Operation.Profile
  ( type ProfileInventoryKey
  , foldProfileInventoryKey
  , type ProfileInventoryDefect
  , foldProfileInventoryDefect
  , type ProfileInventoryCompilation
  , foldProfileInventoryCompilation
  , compileProfileInventory
  , type ProfileInventory
  , profileInventoryDescriptors
  , type ProfileMarkerEvidence
  , type ProfileMarkerEvidenceOutcome
  , foldProfileMarkerEvidenceOutcome
  , prepareProfileMarkerEvidence
  , type ResolvedProfile
  , resolvedProfileDescriptor
  , resolvedProfileReference
  , foldResolvedProfile
  , type ProfileResolution
  , foldProfileResolution
  , resolveProfile
  , type ProfileCompatibility
  , foldProfileCompatibility
  , checkProfileCompatibility
  ) where

import Data.Char (isAsciiLower)
import Data.Function (on)
import Data.List (groupBy, sortBy)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Draft
  ( DraftScalar
  , DraftValueKind
  , draftScalarKind
  , draftScalarText
  , draftTextKind
  )
import O2I.ArchiMate.Profile.Notation
  ( CanonicalProperty
  , MarkerCandidate
  , MarkerEvidenceAssessment
  , canonicalPropertyValues
  , foldMarkerEvidenceAssessment
  )
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , foldProfileDescriptor
  , profileDescriptorAdapterIds
  , profileDescriptorIdentity
  , profileDescriptorNotation
  , profileDescriptorReference
  , profileDescriptorToken
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , SelectedAdapter
  , adapterDescriptorId
  , adapterDescriptorNotation
  , adapterIdText
  , selectedAdapterDescriptor
  )
import O2I.Operation.Profile.Internal
import O2I.Operation.Rule.Generated (GeneratedOperationRule(..))
import O2I.Operation.Rule.Internal.Catalog (OperationRule(..))

-- | Consume the descriptor-derived identity and token of one inventory key.
foldProfileInventoryKey ::
     (Text -> Text -> result) -> ProfileInventoryKey -> result
foldProfileInventoryKey consume (ProfileInventoryKey identity token) =
  consume identity token

-- | Consume every static Profile-inventory contract failure.
foldProfileInventoryDefect ::
     result
  -> (OperationRule -> ProfileInventoryKey -> result)
  -> ProfileInventoryDefect
  -> result
foldProfileInventoryDefect empty duplicate defect =
  case defect of
    EmptyProfileInventory -> empty
    DuplicateProfileInventoryKey rule key -> duplicate rule key

-- | Consume invalid or successfully compiled static Profile inventory.
foldProfileInventoryCompilation ::
     (NonEmpty ProfileInventoryDefect -> result)
  -> (ProfileInventory -> result)
  -> ProfileInventoryCompilation
  -> result
foldProfileInventoryCompilation failed compiled outcome =
  case outcome of
    ProfileInventoryCompilationFailed defects -> failed defects
    ProfileInventoryCompiled inventory -> compiled inventory

-- | Validate and canonically order one closed static Profile collection.
--
-- Construction is @O(P log P)@ for @P@ descriptors. Exact canonical-reference
-- lookup is @O(log P)@. References are always derived from descriptor identity
-- and token; no independent reference value is accepted.
compileProfileInventory :: [ProfileDescriptor] -> ProfileInventoryCompilation
compileProfileInventory supplied =
  case NonEmpty.nonEmpty supplied of
    Nothing -> ProfileInventoryCompilationFailed (EmptyProfileInventory :| [])
    Just entries ->
      case NonEmpty.nonEmpty (duplicateDefects canonical) of
        Just defects -> ProfileInventoryCompilationFailed defects
        Nothing ->
          ProfileInventoryCompiled
            ProfileInventory
              { profileInventoryEntriesValue = canonical
              , profileInventoryByReferenceValue =
                  Map.fromList
                    [ (profileDescriptorReference descriptor, descriptor)
                    | descriptor <- NonEmpty.toList canonical
                    ]
              }
      where canonical = NonEmpty.sortBy (comparing descriptorKey) entries

-- | Enumerate immutable Profile descriptors in canonical identity/token order.
profileInventoryDescriptors :: ProfileInventory -> NonEmpty ProfileDescriptor
profileInventoryDescriptors = profileInventoryEntriesValue

-- | Consume notation rejection or accepted marker evidence without exposing
-- constructors.
foldProfileMarkerEvidenceOutcome ::
     ([MarkerCandidate] -> result)
  -> (ProfileMarkerEvidence -> result)
  -> ProfileMarkerEvidenceOutcome
  -> result
foldProfileMarkerEvidenceOutcome rejected accepted outcome =
  case outcome of
    ProfileMarkerEvidenceRejected candidates -> rejected candidates
    ProfileMarkerEvidenceAccepted evidence -> accepted evidence

-- | Preserve the notation assessment exactly once before Profile resolution.
prepareProfileMarkerEvidence ::
     MarkerEvidenceAssessment -> ProfileMarkerEvidenceOutcome
prepareProfileMarkerEvidence =
  foldMarkerEvidenceAssessment
    ProfileMarkerEvidenceRejected
    (\_ properties ->
       ProfileMarkerEvidenceAccepted (ProfileMarkerEvidence properties))

-- | Immutable descriptor selected by exact Profile resolution.
resolvedProfileDescriptor :: ResolvedProfile -> ProfileDescriptor
resolvedProfileDescriptor (ResolvedProfile descriptor) = descriptor

-- | Descriptor-derived canonical reference of the resolved Profile.
resolvedProfileReference :: ResolvedProfile -> Text
resolvedProfileReference =
  profileDescriptorReference . resolvedProfileDescriptor

-- | Consume every immutable field of the resolved descriptor.
foldResolvedProfile ::
     (Text -> Text -> Text -> Text -> [Text] -> Text -> result)
  -> ResolvedProfile
  -> result
foldResolvedProfile consume =
  foldProfileDescriptor consume . resolvedProfileDescriptor

-- | Consume the exact seven-way Profile resolution algebra.
foldProfileResolution ::
     (OperationRule -> Text -> result)
  -> (OperationRule -> Text -> [CanonicalProperty] -> result)
  -> (OperationRule -> Text -> CanonicalProperty -> [DraftScalar] -> result)
  -> (OperationRule -> Text -> DraftScalar -> DraftValueKind -> result)
  -> (OperationRule -> Text -> DraftScalar -> result)
  -> (OperationRule -> Text -> Text -> result)
  -> (ResolvedProfile -> result)
  -> ProfileResolution
  -> result
foldProfileResolution missing properties values kind grammar unknown resolved outcome =
  case outcome of
    ProfileReferenceMissing rule key -> missing rule key
    ProfileReferencePropertyMultiplicity rule key occurrences ->
      properties rule key occurrences
    ProfileReferenceValueMultiplicity rule key occurrence occurrences ->
      values rule key occurrence occurrences
    ProfileReferenceValueKindInvalid rule key occurrence actualKind ->
      kind rule key occurrence actualKind
    ProfileReferenceGrammarInvalid rule key occurrence ->
      grammar rule key occurrence
    ProfileReferenceUnknown rule key reference -> unknown rule key reference
    ProfileResolved profile -> resolved profile

-- | Resolve accepted model-root @o2i.profile@ evidence with exact precedence.
--
-- The evidence is consumed in source order, while inventory lookup is exact
-- @O(log P)@. No normalization, fallback, runtime loading, or Profile-level
-- reassessment occurs.
resolveProfile :: ProfileInventory -> ProfileMarkerEvidence -> ProfileResolution
resolveProfile inventory (ProfileMarkerEvidence properties) =
  case properties of
    [] -> ProfileReferenceMissing missingRule profileMarkerKey
    occurrences@(_:_:_) ->
      ProfileReferencePropertyMultiplicity
        propertyMultiplicityRule
        profileMarkerKey
        occurrences
    [property] -> resolveProperty property
  where
    resolveProperty property =
      case canonicalPropertyValues property of
        occurrences@[] ->
          ProfileReferenceValueMultiplicity
            valueMultiplicityRule
            profileMarkerKey
            property
            occurrences
        occurrences@(_:_:_) ->
          ProfileReferenceValueMultiplicity
            valueMultiplicityRule
            profileMarkerKey
            property
            occurrences
        [scalar]
          | draftScalarKind scalar /= draftTextKind ->
            ProfileReferenceValueKindInvalid
              valueKindRule
              profileMarkerKey
              scalar
              (draftScalarKind scalar)
          | not (validProfileReference reference) ->
            ProfileReferenceGrammarInvalid grammarRule profileMarkerKey scalar
          | otherwise ->
            case Map.lookup
                   reference
                   (profileInventoryByReferenceValue inventory) of
              Nothing ->
                ProfileReferenceUnknown unknownRule profileMarkerKey reference
              Just descriptor -> ProfileResolved (ResolvedProfile descriptor)
          where reference = draftScalarText scalar

-- | Consume both incompatibilities or exact compatibility.
foldProfileCompatibility ::
     (OperationRule -> ResolvedProfile -> AdapterDescriptor -> [Text] -> result)
  -> (OperationRule -> ResolvedProfile -> AdapterDescriptor -> Text -> Text -> result)
  -> (ResolvedProfile -> AdapterDescriptor -> Text -> result)
  -> ProfileCompatibility
  -> result
foldProfileCompatibility notAdmitted notationMismatch compatible outcome =
  case outcome of
    ProfileAdapterIdNotAdmitted rule profile adapter admitted ->
      notAdmitted rule profile adapter admitted
    ProfileAdapterNotationMismatch rule profile adapter profileNotation adapterNotation ->
      notationMismatch rule profile adapter profileNotation adapterNotation
    ProfileAdapterCompatible profile adapter notation ->
      compatible profile adapter notation

-- | Check the selected adapter descriptor against the resolved Profile.
--
-- Adapter admission precedes exact notation equality. Both checks are total
-- and run before any selected-Profile assessment.
checkProfileCompatibility ::
     ResolvedProfile -> SelectedAdapter -> ProfileCompatibility
checkProfileCompatibility profile selected
  | adapterIdentifier `notElem` admitted =
    ProfileAdapterIdNotAdmitted adapterIdRule profile adapter admitted
  | adapterNotation /= profileNotation =
    ProfileAdapterNotationMismatch
      adapterNotationRule
      profile
      adapter
      profileNotation
      adapterNotation
  | otherwise = ProfileAdapterCompatible profile adapter profileNotation
  where
    adapter = selectedAdapterDescriptor selected
    descriptor = resolvedProfileDescriptor profile
    admitted = profileDescriptorAdapterIds descriptor
    profileNotation = profileDescriptorNotation descriptor
    adapterIdentifier = adapterIdText (adapterDescriptorId adapter)
    adapterNotation = adapterDescriptorNotation adapter

profileMarkerKey :: Text
profileMarkerKey = "o2i.profile"

descriptorKey :: ProfileDescriptor -> ProfileInventoryKey
descriptorKey descriptor =
  ProfileInventoryKey
    (profileDescriptorIdentity descriptor)
    (profileDescriptorToken descriptor)

duplicateDefects :: NonEmpty ProfileDescriptor -> [ProfileInventoryDefect]
duplicateDefects descriptors =
  map
    (DuplicateProfileInventoryKey inventoryUniquenessRule)
    (duplicateKeys descriptorKey (NonEmpty.toList descriptors))

duplicateKeys :: Ord key => (value -> key) -> [value] -> [key]
duplicateKeys key =
  mapMaybe repeatedKey . groupBy ((==) `on` key) . sortBy (comparing key)
  where
    repeatedKey (first:_:_) = Just (key first)
    repeatedKey _ = Nothing

validProfileReference :: Text -> Bool
validProfileReference reference =
  case Text.splitOn "@" reference of
    [identity, token] -> validIdentity identity && validToken token
    _ -> False

validIdentity :: Text -> Bool
validIdentity identity =
  case Text.uncons identity of
    Nothing -> False
    Just (first, rest) ->
      isAsciiLower first && Text.all validIdentityCharacter rest

validIdentityCharacter :: Char -> Bool
validIdentityCharacter character =
  isAsciiLower character
    || asciiDigit character
    || character == '.'
    || character == '-'

validToken :: Text -> Bool
validToken token =
  case Text.splitOn "." token of
    [major, minor] -> asciiDigits major && asciiDigits minor
    _ -> False

asciiDigits :: Text -> Bool
asciiDigits value = not (Text.null value) && Text.all asciiDigit value

asciiDigit :: Char -> Bool
asciiDigit character = character >= '0' && character <= '9'

missingRule, propertyMultiplicityRule, valueMultiplicityRule :: OperationRule
missingRule = OperationRule GeneratedProfileReferenceMissing

propertyMultiplicityRule =
  OperationRule GeneratedProfileReferencePropertyMultiplicity

valueMultiplicityRule = OperationRule GeneratedProfileReferenceValueMultiplicity

valueKindRule, grammarRule, unknownRule :: OperationRule
valueKindRule = OperationRule GeneratedProfileReferenceValueKind

grammarRule = OperationRule GeneratedProfileReferenceGrammar

unknownRule = OperationRule GeneratedProfileReferenceUnknown

inventoryUniquenessRule, adapterIdRule, adapterNotationRule :: OperationRule
inventoryUniquenessRule =
  OperationRule GeneratedProfileInventoryIdentityTokenUniqueness

adapterIdRule = OperationRule GeneratedProfileAdapterId

adapterNotationRule = OperationRule GeneratedProfileAdapterNotation
