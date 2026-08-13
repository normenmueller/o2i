{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Generative public boundaries over the accepted canonical notation values.
module O2I.ArchiMate.Profile.Internal.Notation.Witness where

import O2I.ArchiMate.Profile.Internal.Draft (ProfileDraft)
import qualified O2I.ArchiMate.Profile.Internal.Notation as Raw

-- | One canonical document scoped to exactly one source Draft.
newtype CanonicalDocument document =
  CanonicalDocument Raw.CanonicalDocument

type role CanonicalDocument nominal

-- | One canonical View intrinsically bound to its source document.
newtype CanonicalView document =
  CanonicalView Raw.ViewDescriptor

type role CanonicalView nominal

-- | Introduce one fresh document scope around total canonical construction.
withCanonicalDocumentValue ::
     ProfileDraft
  -> (forall document. CanonicalDocument document -> result)
  -> result
withCanonicalDocumentValue draft consume =
  consume (CanonicalDocument (Raw.buildCanonicalDocument draft))

-- | Project the raw canonical value only inside the Profile package.
canonicalDocumentValue :: CanonicalDocument document -> Raw.CanonicalDocument
canonicalDocumentValue (CanonicalDocument document) = document

-- | Derive every View with the same document witness as its source.
canonicalViewsValue :: CanonicalDocument document -> [CanonicalView document]
canonicalViewsValue (CanonicalDocument document) =
  map CanonicalView (Raw.viewInventoryValue document)

-- | Project the raw View only inside the Profile package.
canonicalViewValue :: CanonicalView document -> Raw.ViewDescriptor
canonicalViewValue (CanonicalView view) = view
