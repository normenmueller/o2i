{-# LANGUAGE ExplicitNamespaces #-}

-- | Exact profile-neutral native View selection.
--
-- Name selectors compare exact native View names. Identity selectors decide
-- model-wide occurrence cardinality before testing the one remaining native
-- record family. Neither path applies Profile semantics or normalization.
module O2I.Operation.View
  ( type ViewSelector
  , viewByName
  , viewByIdentity
  , foldViewSelector
  , type ViewSelectionCandidate
  , viewSelectionCandidateOccurrence
  , viewSelectionCandidateFamily
  , viewSelectionCandidateIdentity
  , viewSelectionCandidateLocation
  , foldViewSelectionCandidate
  , type ViewSelectionFailure
  , foldViewSelectionFailure
  , type SelectedView
  , selectedViewDescriptor
  , foldSelectedView
  , type ViewSelection
  , foldViewSelection
  , selectView
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import Data.Text (Text)
import O2I.ArchiMate.Profile.Draft (DraftLocation, DraftRecordFamilyValue)
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , CanonicalOccurrence
  , ViewDescriptor
  )
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.View.Internal

-- | Select one View by exact native name.
viewByName :: Text -> ViewSelector
viewByName = ViewNameSelector

-- | Select one View by an already validated exact model identity.
viewByIdentity :: ModelIdentity -> ViewSelector
viewByIdentity = ViewIdentitySelector

-- | Consume both closed selector alternatives.
foldViewSelector ::
     (Text -> result) -> (ModelIdentity -> result) -> ViewSelector -> result
foldViewSelector name identity selector =
  case selector of
    ViewNameSelector value -> name value
    ViewIdentitySelector value -> identity value

-- | Canonical occurrence represented by one selection candidate.
viewSelectionCandidateOccurrence ::
     ViewSelectionCandidate -> CanonicalOccurrence
viewSelectionCandidateOccurrence = viewSelectionCandidateOccurrenceValue

-- | Profile-neutral native family of one selection candidate.
viewSelectionCandidateFamily :: ViewSelectionCandidate -> DraftRecordFamilyValue
viewSelectionCandidateFamily = viewSelectionCandidateFamilyValue

-- | Exact resolved native identity, when valid and present.
viewSelectionCandidateIdentity :: ViewSelectionCandidate -> Maybe ModelIdentity
viewSelectionCandidateIdentity = viewSelectionCandidateIdentityValue

-- | Exact native location of one selection candidate.
viewSelectionCandidateLocation :: ViewSelectionCandidate -> DraftLocation
viewSelectionCandidateLocation = viewSelectionCandidateLocationValue

-- | Consume all profile-neutral candidate evidence.
foldViewSelectionCandidate ::
     (CanonicalOccurrence -> DraftRecordFamilyValue -> Maybe ModelIdentity -> DraftLocation -> result)
  -> ViewSelectionCandidate
  -> result
foldViewSelectionCandidate consume candidate =
  consume
    (viewSelectionCandidateOccurrenceValue candidate)
    (viewSelectionCandidateFamilyValue candidate)
    (viewSelectionCandidateIdentityValue candidate)
    (viewSelectionCandidateLocationValue candidate)

-- | Consume every closed View-selection failure.
foldViewSelectionFailure ::
     (ViewSelector -> result)
  -> (ViewSelector -> NonEmpty ViewDescriptor -> result)
  -> (ViewSelector -> NonEmpty ViewSelectionCandidate -> result)
  -> (ViewSelector -> ViewSelectionCandidate -> result)
  -> ViewSelectionFailure
  -> result
foldViewSelectionFailure unknown ambiguousName ambiguousIdentity wrongFamily failure =
  case failure of
    ViewSelectionUnknown selector -> unknown selector
    ViewNameSelectionAmbiguous selector candidates ->
      ambiguousName selector candidates
    ViewIdentitySelectionAmbiguous selector candidates ->
      ambiguousIdentity selector candidates
    ViewSelectionWrongFamily selector candidate ->
      wrongFamily selector candidate

-- | Exact native View descriptor selected by Operation.
selectedViewDescriptor :: SelectedView -> ViewDescriptor
selectedViewDescriptor (SelectedView descriptor) = descriptor

-- | Consume one exact selected native View descriptor.
foldSelectedView :: (ViewDescriptor -> result) -> SelectedView -> result
foldSelectedView consume (SelectedView descriptor) = consume descriptor

-- | Consume failure or one exact selected View.
foldViewSelection ::
     (ViewSelectionFailure -> result)
  -> (SelectedView -> result)
  -> ViewSelection
  -> result
foldViewSelection failed selected outcome =
  case outcome of
    ViewSelectionFailed failure -> failed failure
    ViewSelected value -> selected value

-- | Resolve one exact View selector against one canonical notation document.
--
-- Name resolution is linear in View descriptors and their retained name
-- scalars. Identity resolution builds one occurrence index in @O(V log V)@
-- and resolves @N@ canonical records in @O(N log V)@.
-- Cardinality is decided before family for identity selectors, exactly as
-- required by the profile-neutral bootstrap contract.
selectView :: CanonicalDocument -> ViewSelector -> ViewSelection
selectView document selector = fst (selectViewWithWork document selector)
