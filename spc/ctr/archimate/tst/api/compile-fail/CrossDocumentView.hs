{-# LANGUAGE RankNTypes #-}

module CrossDocumentView where

import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Resolution as Resolution

crossDocument :: Draft.ProfileDraft -> Draft.ProfileDraft -> ()
crossDocument first second =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument first $ \document ->
      Notation.withCanonicalDocument second $ \other ->
        case Notation.canonicalViews other of
          [] -> ()
          view:_ ->
            Closure.deriveProfileAssessmentUniverse profile document view
              `seq` ()
