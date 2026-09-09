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
  , CanonicalView
  , IdentityOutcome
  , canonicalDocumentRecords
  , canonicalFieldScalars
  , canonicalViewNameFields
  , canonicalViewOccurrence
  , canonicalViews
  , foldCanonicalRecord
  , foldIdentityOutcome
  )
import O2I.Core.Identity (ModelIdentity, modelIdentityText)

-- | Exact native View selector supplied after lexical CLI validation.
data ViewSelector
  = ViewNameSelector !Text
  | ViewIdentitySelector !ModelIdentity
  deriving (Eq, Ord, Show)

-- | One profile-neutral occurrence retained as selector evidence.
data ViewSelectionCandidate document = ViewSelectionCandidate
  { viewSelectionCandidateOccurrenceValue :: !CanonicalOccurrence
  , viewSelectionCandidateFamilyValue :: !DraftRecordFamilyValue
  , viewSelectionCandidateIdentityValue :: !(Maybe ModelIdentity)
  , viewSelectionCandidateLocationValue :: !DraftLocation
  , viewSelectionCandidateDescriptorValue :: !(Maybe (CanonicalView document))
  }

-- | Closed reason why one exact View selector cannot resolve.
data ViewSelectionFailure document
  = ViewSelectionUnknown !ViewSelector
  | ViewNameSelectionAmbiguous
      !ViewSelector
      !(NonEmpty (CanonicalView document))
  | ViewIdentitySelectionAmbiguous
      !ViewSelector
      !(NonEmpty (ViewSelectionCandidate document))
  | ViewSelectionWrongFamily !ViewSelector !(ViewSelectionCandidate document)

-- | Exact selected native View descriptor.
newtype SelectedView document =
  SelectedView (CanonicalView document)

-- | Total exact-View selection result.
data ViewSelection document
  = ViewSelectionFailed !(ViewSelectionFailure document)
  | ViewSelected !(SelectedView document)

-- | Deterministic private work evidence for identity-based View selection.
data ViewSelectionWork = ViewSelectionWork
  { viewSelectionIndexedDescriptors :: !Int
  , viewSelectionVisitedRecords :: !Int
  , viewSelectionDescriptorLookups :: !Int
  } deriving (Eq, Show)

-- | Resolve one exact selector and retain deterministic index-work evidence.
selectViewWithWork ::
     CanonicalDocument document
  -> ViewSelector
  -> (ViewSelection document, ViewSelectionWork)
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
    descriptors = canonicalViews document
    descriptorIndex =
      Map.fromList
        [ (canonicalViewOccurrence descriptor, descriptor)
        | descriptor <- descriptors
        ]
    records = canonicalDocumentRecords document
    allCandidates = fmap (recordCandidate descriptorIndex) records
    identityWork =
      ViewSelectionWork (length descriptors) (length records) (length records)

descriptorHasName :: Text -> CanonicalView document -> Bool
descriptorHasName expected descriptor =
  any
    (\scalar ->
       draftScalarKind scalar == draftTextKind
         && draftScalarText scalar == expected)
    [ scalar
    | field <- canonicalViewNameFields descriptor
    , scalar <- canonicalFieldScalars field
    ]

candidateHasIdentity :: ModelIdentity -> ViewSelectionCandidate document -> Bool
candidateHasIdentity expected candidate =
  fmap modelIdentityText (viewSelectionCandidateIdentityValue candidate)
    == Just (modelIdentityText expected)

recordCandidate ::
     Map.Map CanonicalOccurrence (CanonicalView document)
  -> CanonicalRecord
  -> ViewSelectionCandidate document
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
