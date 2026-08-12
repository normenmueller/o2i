-- | Private representation and indexed evaluation of exact profile-neutral
-- View selection.
module O2I.Operation.View.Internal where

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft
  ( DraftLocation
  , DraftRecordFamilyValue
  , draftScalarKind
  , draftScalarText
  , draftTextKind
  )
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , CanonicalOccurrence
  , CanonicalRecord
  , IdentityOutcome
  , ViewDescriptor
  , canonicalDocumentRecords
  , canonicalFieldScalars
  , foldCanonicalRecord
  , foldIdentityOutcome
  , viewDescriptorNameFields
  , viewDescriptorOccurrence
  , viewInventory
  )
import O2I.Core.Identity (ModelIdentity, modelIdentityText)

-- | Exact native View selector supplied after lexical CLI validation.
data ViewSelector
  = ViewNameSelector !Text
  | ViewIdentitySelector !ModelIdentity
  deriving (Eq, Ord, Show)

-- | One profile-neutral occurrence retained as selector evidence.
data ViewSelectionCandidate = ViewSelectionCandidate
  { viewSelectionCandidateOccurrenceValue :: !CanonicalOccurrence
  , viewSelectionCandidateFamilyValue :: !DraftRecordFamilyValue
  , viewSelectionCandidateIdentityValue :: !(Maybe ModelIdentity)
  , viewSelectionCandidateLocationValue :: !DraftLocation
  , viewSelectionCandidateDescriptorValue :: !(Maybe ViewDescriptor)
  }

-- | Closed reason why one exact View selector cannot resolve.
data ViewSelectionFailure
  = ViewSelectionUnknown !ViewSelector
  | ViewNameSelectionAmbiguous !ViewSelector !(NonEmpty ViewDescriptor)
  | ViewIdentitySelectionAmbiguous
      !ViewSelector
      !(NonEmpty ViewSelectionCandidate)
  | ViewSelectionWrongFamily !ViewSelector !ViewSelectionCandidate

-- | Exact selected native View descriptor.
newtype SelectedView =
  SelectedView ViewDescriptor

-- | Total exact-View selection result.
data ViewSelection
  = ViewSelectionFailed !ViewSelectionFailure
  | ViewSelected !SelectedView

-- | Deterministic private work evidence for identity-based View selection.
data ViewSelectionWork = ViewSelectionWork
  { viewSelectionIndexedDescriptors :: !Int
  , viewSelectionVisitedRecords :: !Int
  , viewSelectionDescriptorLookups :: !Int
  } deriving (Eq, Show)

-- | Resolve one exact selector and retain deterministic index-work evidence.
selectViewWithWork ::
     CanonicalDocument -> ViewSelector -> (ViewSelection, ViewSelectionWork)
selectViewWithWork document selector =
  case selector of
    ViewNameSelector name -> (selectByName name, ViewSelectionWork 0 0 0)
    ViewIdentitySelector identity -> (selectByIdentity identity, identityWork)
  where
    selectByName name =
      case filter (descriptorHasName name) descriptors of
        [] -> ViewSelectionFailed (ViewSelectionUnknown selector)
        [descriptor] -> ViewSelected (SelectedView descriptor)
        first:rest ->
          ViewSelectionFailed
            (ViewNameSelectionAmbiguous selector (first :| rest))
    selectByIdentity identity =
      case filter (candidateHasIdentity identity) allCandidates of
        [] -> ViewSelectionFailed (ViewSelectionUnknown selector)
        [candidate] ->
          case viewSelectionCandidateDescriptorValue candidate of
            Just descriptor -> ViewSelected (SelectedView descriptor)
            Nothing ->
              ViewSelectionFailed (ViewSelectionWrongFamily selector candidate)
        first:rest ->
          ViewSelectionFailed
            (ViewIdentitySelectionAmbiguous selector (first :| rest))
    descriptors = viewInventory document
    descriptorIndex =
      Map.fromList
        [ (viewDescriptorOccurrence descriptor, descriptor)
        | descriptor <- descriptors
        ]
    records = canonicalDocumentRecords document
    allCandidates = fmap (recordCandidate descriptorIndex) records
    identityWork =
      ViewSelectionWork (length descriptors) (length records) (length records)

descriptorHasName :: Text -> ViewDescriptor -> Bool
descriptorHasName expected descriptor =
  any
    (\scalar ->
       draftScalarKind scalar == draftTextKind
         && draftScalarText scalar == expected)
    [ scalar
    | field <- viewDescriptorNameFields descriptor
    , scalar <- canonicalFieldScalars field
    ]

candidateHasIdentity :: ModelIdentity -> ViewSelectionCandidate -> Bool
candidateHasIdentity expected candidate =
  fmap modelIdentityText (viewSelectionCandidateIdentityValue candidate)
    == Just (modelIdentityText expected)

recordCandidate ::
     Map.Map CanonicalOccurrence ViewDescriptor
  -> CanonicalRecord
  -> ViewSelectionCandidate
recordCandidate descriptors record =
  foldCanonicalRecord
    (\occurrence family identity location _ ->
       ViewSelectionCandidate
         occurrence
         family
         (resolvedIdentity identity)
         location
         (Map.lookup occurrence descriptors))
    record

resolvedIdentity :: IdentityOutcome -> Maybe ModelIdentity
resolvedIdentity identity =
  foldIdentityOutcome
    Nothing
    (const Nothing)
    (\_ _ -> Nothing)
    (\_ -> Just)
    identity
